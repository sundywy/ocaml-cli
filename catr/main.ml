open Cmdliner

let open_file_to_string filename =
  try In_channel.(open_text filename |> input_lines)
  with Sys_error str -> [ str ]

let format_line i line = Format.sprintf "%6d\t%s" i line

let print_files files number_lines number_nonblank_lines =
  let rec print_with_index i lines =
    match lines with
    | l :: ls ->
        if number_lines then (
          print_endline (format_line i l);
          print_with_index (i + 1) ls)
        else if number_nonblank_lines then
          if String.length l = 0 then (
            print_newline ();
            print_with_index i ls)
          else (
            print_endline (format_line i l);
            print_with_index (i + 1) ls)
        else (
          print_endline l;
          print_with_index (i + 1) ls)
    | [] -> ()
  in
  List.map open_file_to_string files |> List.iter (print_with_index 1)

let print_stdin number_lines number_nonblank_lines =
  let rec print_with_index i =
    match In_channel.(input_line stdin) with
    | Some line ->
        if number_lines then (
          print_endline (format_line i line);
          print_with_index (i + 1))
        else if number_nonblank_lines then
          if String.length line = 0 then (
            print_newline ();
            print_with_index i)
          else (
            print_endline (format_line i line);
            print_with_index (i + 1))
        else (
          print_endline line;
          print_with_index (i + 1))
    | None -> ()
  in
  print_with_index 1

exception Catr of string

let term =
  let open Cmdliner.Term.Syntax in
  let+ files =
    let doc = "Input file(s)" in
    Arg.(value & pos_all string [] & info [] ~docv:"FILE" ~doc)
  and+ number_lines =
    let doc = "Number lines" in
    Arg.(value & flag & info [ "n"; "number-lines" ] ~doc)
  and+ number_nonblank_lines =
    let doc = "Number nonblank lines" in
    Arg.(value & flag & info [ "b"; "number-nonblank-lines" ] ~doc)
  in
  if number_lines && number_nonblank_lines then
    raise (Catr "Only use number_lines or number_nonblank_lines")
  else
    match files with
    | [] -> print_stdin number_lines number_nonblank_lines
    | _ -> print_files files number_lines number_nonblank_lines

let cmd =
  let doc = "Rust cat in ocaml" in
  let info = Cmd.info "catr" ~version:"0.1.0" ~doc in
  Cmd.v info term

let () = exit (Cmd.eval cmd)
