open Cmdliner

type print_option = Lines of int | Bytes of int

let config =
  let open Cmdliner.Term.Syntax in
  let t =
    let+ lines =
      let doc = "Print the first n lines of the file" in
      Arg.(value & opt (some int) None & info [ "n"; "lines" ] ~doc)
    and+ bytes =
      let doc = "Print the first n bytes of the file" in
      Arg.(value & opt (some int) None & info [ "c"; "bytes" ] ~doc)
    in
    match (lines, bytes) with
    | None, None -> `Ok (Lines 10)
    | Some x, None -> `Ok (Lines x)
    | None, Some y -> `Ok (Bytes y)
    | _, _ -> `Error (true, "can only use one of -n/--lines or -c/--bytes")
  in
  Term.ret t

let files =
  let doc = "Input file(s). Use - for standard input." in
  Arg.(value & pos_all string [] & info [] ~docv:"FILE" ~doc)

let open_input = function
  | "-" -> Ok (stdin, false)
  | path -> (
      try Ok (In_channel.open_text path, true) with Sys_error msg -> Error msg)

let print_file config ic =
  let rec loop config =
    match In_channel.input_line ic with
    | None -> ()
    | Some line -> (
        match config with
        | Lines x when x > 0 ->
            print_endline line;
            loop (Lines (x - 1))
        | Bytes x when x > 0 ->
            let line_bytes = String.to_bytes line in
            print_bytes (Bytes.sub line_bytes 0 x);
            loop (Bytes (x - Bytes.length line_bytes))
        | _ -> ())
  in
  loop config

let head_file config path =
  match open_input path with
  | Error msg -> prerr_endline msg
  | Ok (ic, close) ->
      Fun.protect
        ~finally:(fun () -> if close then In_channel.close_noerr ic)
        (fun () -> print_file config ic)

let rec head_files config paths =
  match paths with
  | [] -> ()
  | [ path ] -> head_file config path
  | path :: paths' ->
      print_endline ("==> " ^ path ^ " <==");
      head_file config path;
      head_files config paths'

let run config = function
  | [] | [ "-" ] -> head_file config "-"
  | files -> head_files config files

let cmd =
  let doc = "Rust Headr" in
  let info = Cmd.info "headr" ~version:"0.1.0" ~doc in
  Cmd.v info Term.(const run $ config $ files)

let () = exit (Cmd.eval cmd)
