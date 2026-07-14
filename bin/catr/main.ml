open Cmdliner

type numbering = Off | All | Nonblank

let format_line i line = Printf.sprintf "%6d\t%s" i line

let open_input = function
  | "-" -> Ok (stdin, false)
  | path -> (
      try Ok (In_channel.open_text path, true)
      with Sys_error msg -> Error msg)

let print_lines numbering ic =
  let rec loop i =
    match In_channel.input_line ic with
    | None -> ()
    | Some line ->
        let next =
          match numbering with
          | Off ->
              print_endline line;
              i
          | All ->
              print_endline (format_line i line);
              i + 1
          | Nonblank when String.length line = 0 ->
              print_newline ();
              i
          | Nonblank ->
              print_endline (format_line i line);
              i + 1
        in
        loop next
  in
  loop 1

let cat_file numbering path =
  match open_input path with
  | Error msg -> prerr_endline msg
  | Ok (ic, close) ->
      Fun.protect
        ~finally:(fun () -> if close then In_channel.close_noerr ic)
        (fun () -> print_lines numbering ic)

let run files numbering =
  match files with
  | [] -> cat_file numbering "-"
  | _ -> List.iter (cat_file numbering) files

let files =
  let doc = "Input file(s). Use - for standard input." in
  Arg.(value & pos_all string [] & info [] ~docv:"FILE" ~doc)

let number =
  let doc = "Number all output lines" in
  Arg.(value & flag & info [ "n"; "number" ] ~doc)

let number_nonblank =
  let doc = "Number nonempty output lines" in
  Arg.(value & flag & info [ "b"; "number-nonblank" ] ~doc)

let numbering =
  let combine number number_nonblank =
    match (number, number_nonblank) with
    | true, true ->
        `Error
          ( true,
            "can only use one of -n/--number or -b/--number-nonblank" )
    | true, false -> `Ok All
    | false, true -> `Ok Nonblank
    | false, false -> `Ok Off
  in
  Term.(ret (const combine $ number $ number_nonblank))

let cmd =
  let doc = "Concatenate and print files" in
  let info = Cmd.info "catr" ~version:"0.1.0" ~doc in
  Cmd.v info Term.(const run $ files $ numbering)

let () = exit (Cmd.eval cmd)
