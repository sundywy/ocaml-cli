open Cmdliner

let format_line i line = Format.sprintf "%6d\t%s" i line

exception Catr of string

let term =
  let open Cmdliner.Term.Syntax in
  let+ files =
    let doc = "Input file(s)" in
    Arg.(value & pos_all string [] & info [] ~docv:"FILE" ~doc)
  and+ number_lines =
    let doc = "Number lines" in
    Arg.(value & flag & info [ "n"; "number" ] ~doc)
  and+ number_nonblank_lines =
    let doc = "Number nonblank lines" in
    Arg.(value & flag & info [ "b"; "number-nonblank-lines" ] ~doc)
  in
  if number_lines && number_nonblank_lines then
    raise (Catr "Only use number_lines or number_nonblank_lines")
  else
    let print_stdin filename =
      try
        let f =
          match filename with
          | Some filename' -> In_channel.open_text filename'
          | None -> stdin
        in
        let rec print_with_index i =
          match In_channel.(input_line f) with
          | Some line ->
              let j =
                if number_nonblank_lines && String.length line = 0 then (
                  print_newline ();
                  i)
                else if number_lines || number_nonblank_lines then (
                  print_endline (format_line i line);
                  i + 1)
                else (
                  print_endline line;
                  i + 1)
              in
              print_with_index j
          | None -> ()
        in
        print_with_index 1;
        In_channel.close_noerr f
      with Sys_error str ->
        prerr_endline str;
        ()
    in
    let rec print_files files =
      match files with
      | file :: files' ->
          print_stdin (Some file);
          print_files files'
      | [] -> ()
    in
    match files with [] | [ "-" ] -> print_stdin None | _ -> print_files files

let cmd =
  let doc = "Rust cat in ocaml" in
  let info = Cmd.info "catr" ~version:"0.1.0" ~doc in
  Cmd.v info term

let () = exit (Cmd.eval cmd)
