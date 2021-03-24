let getToday: unit => string = %raw(`
function() {
  let date = new Date();
  return new Date(date.getTime() - (date.getTimezoneOffset() * 60000))
    .toISOString()
    .split("T")[0];
}
  `)

type fsConfig = {encoding: string, flag: string}

/* https://nodejs.org/api/fs.html#fs_fs_existssync_path */
@bs.module("fs") external existsSync: string => bool = "existsSync"

/* https://nodejs.org/api/fs.html#fs_fs_readfilesync_path_options */
@bs.module("fs")
external readFileSync: (string, fsConfig) => string = "readFileSync"

/* https://nodejs.org/api/fs.html#fs_fs_writefilesync_file_data_options */
@bs.module("fs")
external appendFileSync: (string, string, fsConfig) => unit = "appendFileSync"

@bs.module("fs")
external writeFileSync: (string, string, fsConfig) => unit = "writeFileSync"

/* https://nodejs.org/api/os.html#os_os_eol */
@bs.module("os") external eol: string = "EOL"

// Make binding for command-line arguments
@bs.module("process") @bs.val external argv: array<string> = "argv"


let encoding = "utf8"

type command =
  | Help
  | Ls
  | Add(option<string>)
  | Del(option<int>)
  | Done(option<int>)
  | Report

let getCommandConstructor = (~command: string, ~param: option<string>): command => {
  let command = command->Js.String.trim->Js.String.toLocaleLowerCase
  // fromString returns option<a>. Needs flatmap
  let pos = param->Belt.Option.flatMap(str => str->Belt.Int.fromString)
  switch command {
  | "help" => Help
  | "ls" => Ls
  | "add" => Add(param)
  | "del" => Del(pos)
  | "done" => Done(pos)
  | "report" => Report
  | _ => Help      // Any invalid string should show help message
  }
}

let todos_file =  "todo.txt"
let completed_file = "done.txt"

let help_string = `
Usage :-
$ ./todo add "todo item"  # Add a new todo
$ ./todo ls               # Show remaining todos
$ ./todo del NUMBER       # Delete a todo
$ ./todo done NUMBER      # Complete a todo
$ ./todo help             # Show usage
$ ./todo report           # Statistics`


let readFile = (filename: string): array<string> => {
  if !existsSync(filename) {
    []
  } else {
    let text = readFileSync(filename, {encoding: encoding, flag: "r"})
    let lines = Js.String.split(eol, text)
    let lines = Js.Array.filter(todo => todo !== "", lines)
    lines
  }
}

// Wrapper for writeFileSync
let writeRecord = (file: string, lines: array<string>) => {
    let text = Belt.Array.joinWith(lines, eol, dummy => dummy)
    writeFileSync(file,
      text,
      {encoding: encoding, flag: "w"})
}

// Wrapper for appendFileSync
let addToRecord = (file: string, content: string) => {
  appendFileSync(file,
                content++eol,
                {encoding: encoding, flag: "a"})
}


// Display help-string
let commHelp = () => {
  Js.log(help_string);
}


// List pending todos (reverse order)
let commLs = () => {
  let todos = readFile(todos_file)
  let size = todos->Belt.Array.length
  if (size == 0) {
    Js.log("There are no pending todos!")
  }
  else{
    // Display in most-recent first
    todos
      ->Belt.Array.reverse
      ->Belt.Array.reduceWithIndex("", (acc, todo, index) => {
          acc ++ `[${Belt.Int.toString(size-index)}] ${todo}${eol}`
        })
      ->Js.String.trim
      ->Js.log
  }
}


// Add new todo
let commAdd = (todo: option<string>) => {
  switch todo {
  | None => Js.log("Error: Missing todo string. Nothing added!")
  | Some(todo) =>
    addToRecord(todos_file, todo)
    Js.log(`Added todo: "${todo}"`)
  }
}


// Delete a todo
let commDelete = (todo_num: option<int>) => {
  switch todo_num {
  | None => Js.log("Error: Missing NUMBER for deleting todo.")
  | Some(todo_num) =>
      let todos = readFile(todos_file)
      if (todo_num>Belt.Array.length(todos) || todo_num<1) {
        Js.log(`Error: todo #${Belt.Int.toString(todo_num)} does not exist. Nothing deleted.`)
      } else {
        // Remove the target todo
        let todos = Js.Array.filteri(
          (_, idx) => {
            idx!=(todo_num-1)
          },
          todos
        )
        // Replace existing file with new contents
        writeRecord(todos_file, todos)
        Js.log(`Deleted todo #${Belt.Int.toString(todo_num)}`)
      }
  }
}


// Mark todo completion
let commMarkCompletion = (todo_num: option<int>) => {
  switch todo_num {
  | None => Js.log("Error: Missing NUMBER for marking todo as done.")
  | Some(todo_num) =>
    let todos = readFile(todos_file)
    if (todo_num>Belt.Array.length(todos) || todo_num<1) {
      Js.log(`Error: todo #${Belt.Int.toString(todo_num)} does not exist. Nothing Marked as done.`)
    } else {
      let target = todos[todo_num-1]
      // Remove the target todo
      let todos = Js.Array.filteri(
        (_, idx) => {
          idx!=(todo_num-1)
        },
        todos
      )
      // Replace existing file with new contents
      writeRecord(todos_file, todos)
      addToRecord(completed_file, `x ${getToday()} ${target}`)
      Js.log(`Marked todo #${Belt.Int.toString(todo_num)} as done.`)
    }
  }
}


// Display a report
let commReport = () => {
  let pending_cnt = readFile(todos_file)->Belt.Array.length->Belt.Int.toString
  let completed_cnt = readFile(completed_file)->Belt.Array.length->Belt.Int.toString
  Js.log(`${getToday()} Pending : ${pending_cnt} Completed : ${completed_cnt}`)
}


// Get Command-Line args
let work = argv->Belt.Array.get(2)->Belt.Option.getWithDefault("help")
let cliParam = argv->Belt.Array.get(3)
// Convert to variant-type constructor
let work: command = getCommandConstructor(~command=work, ~param=cliParam)
// Decide the work type and execute
switch work {
| Help => commHelp()
| Ls => commLs()
| Add(todo) => commAdd(todo)
| Del(todo_num) => commDelete(todo_num)
| Done(todo_num) => commMarkCompletion(todo_num)
| Report => commReport()
}
