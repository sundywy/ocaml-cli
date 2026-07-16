open Cmdliner

type print_option = Lines of int | Bytes of int

let config =
  let open Cmdliner.Term.Syntax in
  let+ lines =
    let doc = "Print the first n lines of the file" in
    Arg.(value & opt int 0 & info [ "n"; "lines" ] ~doc)
  and+ bytes =
    let doc = "Print the first n bytes of the file" in
    Arg.(value & opt int 0 & info [ "c"; "bytes" ] ~doc)
  in
  Term.(
    const
      (match (lines, bytes) with
      | 0, 0 -> `Ok (Lines 10)
      | x, 0 -> `Ok (Lines x)
      | 0, y -> `Ok (Bytes y)
      | _, _ -> `Error (true, "can only use one of -n/--lines or -c/--bytes")))

let files =
  let doc = "Input file(s). Use - for standard input." in
  Arg.(value & pos_all string [] & info [] ~docv:"FILE" ~doc)

let run files config =
  (match (files, config) with
  | _, Lines x -> print_int x
  | _, Bytes x -> print_int x);
  print_newline ()

let cmd =
  let doc = "Rust Headr" in
  let info = Cmd.info "headr" ~version:"0.1.0" ~doc in
  Cmd.v info Term.(const run $ files $ config)

let () = exit (Cmd.eval cmd)
