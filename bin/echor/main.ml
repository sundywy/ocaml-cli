open Cmdliner

let echor msg omit_newline =
  String.concat " " msg |> if omit_newline then print_string else print_endline

let omit_newline =
  let doc = "Do not print newline" in
  Arg.(value & flag & info [ "n" ] ~doc)

let msg =
  let doc = "Input text" in
  Arg.(non_empty & pos_all string [] & info [] ~docv:"TEXT" ~doc)

let cmd =
  let doc = "Rust echo in Ocaml" in
  let info = Cmd.info "echor" ~version:"0.1.0" ~doc in
  Cmd.v info Term.(const echor $ msg $ omit_newline)

let () = exit (Cmd.eval cmd)
