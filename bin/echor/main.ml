open Cmdliner

let run texts omit_newline =
  let out = String.concat " " texts in
  if omit_newline then print_string out else print_endline out

let texts =
  let doc = "Text to print" in
  Arg.(non_empty & pos_all string [] & info [] ~docv:"TEXT" ~doc)

let omit_newline =
  let doc = "Do not print a trailing newline" in
  Arg.(value & flag & info [ "n" ] ~doc)

let cmd =
  let doc = "Print arguments to standard output" in
  let info = Cmd.info "echor" ~version:"0.1.0" ~doc in
  Cmd.v info Term.(const run $ texts $ omit_newline)

let () = exit (Cmd.eval cmd)
