(* Shared helpers for CLI integration tests. *)

open Bos

let () = Random.self_init ()

let bin_from_env name =
  match Sys.getenv_opt name with
  | Some p -> p
  | None ->
      (* Strip _BIN suffix for default executable name, e.g. WCR_BIN -> wcr *)
      let len = String.length name in
      if len > 4 && String.sub name (len - 4) 4 = "_BIN" then
        String.lowercase_ascii (String.sub name 0 (len - 4))
      else name

let cmd bin args = Cmd.(v bin %% of_list args)

let read_file path =
  match OS.File.read (Fpath.v path) with
  | Ok s -> s
  | Error (`Msg m) -> Alcotest.fail m

let read_expected name = read_file (Filename.concat "expected" name)

let contains ~affix s = Astring.String.is_infix ~affix s

let random_string () =
  String.init 7 (fun _ ->
      match Random.int (10 + 26) with
      | n when n < 10 -> Char.chr (Char.code '0' + n)
      | n -> Char.chr (Char.code 'a' + n - 10))

let gen_bad_file () =
  let rec loop () =
    let name = random_string () in
    match OS.File.must_exist (Fpath.v name) with
    | Ok _ -> loop ()
    | Error _ -> name
  in
  loop ()

let run_out ?stdin ?err cmd =
  let err = Option.value err ~default:OS.Cmd.err_stderr in
  match stdin with
  | None -> OS.Cmd.run_out ~err cmd
  | Some input -> OS.Cmd.(in_string input |> run_io ~err cmd)

let run_success_path ?stdin ~bin args expected_path () =
  let expected = read_file expected_path in
  let c = cmd bin args in
  match OS.Cmd.out_string ~trim:false (run_out ?stdin c) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout" expected stdout
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let run_success ?stdin ~bin args expected_file () =
  run_success_path ?stdin ~bin args
    (Filename.concat "expected" expected_file)
    ()

let dies ?stderr_contains ~bin ~args () =
  let err_path = Fpath.v (Filename.temp_file "cli_test" "err") in
  let c = cmd bin args in
  match
    OS.Cmd.out_string ~trim:false
      (run_out ~err:(OS.Cmd.err_file err_path) c)
  with
  | Ok (_, (_, `Exited 0)) -> Alcotest.fail "expected non-zero exit"
  | Ok (_, _) -> (
      match stderr_contains with
      | None -> ()
      | Some affix -> (
          match OS.File.read err_path with
          | Ok stderr ->
              Alcotest.(check bool)
                (Printf.sprintf "stderr contains %S" affix)
                true (contains ~affix stderr)
          | Error (`Msg m) -> Alcotest.fail m))
  | Error (`Msg m) -> Alcotest.fail m

let stderr_matches ~bin ~args ~check () =
  let err_path = Fpath.v (Filename.temp_file "cli_test" "err") in
  let c = cmd bin args in
  match
    OS.Cmd.out_string ~trim:false
      (run_out ~err:(OS.Cmd.err_file err_path) c)
  with
  | Ok (stdout, (_, status)) -> (
      match OS.File.read err_path with
      | Ok stderr -> check ~stdout ~stderr ~status
      | Error (`Msg m) -> Alcotest.fail m)
  | Error (`Msg m) -> Alcotest.fail m

let sort_nonempty_lines s =
  s
  |> String.split_on_char '\n'
  |> List.filter (fun line -> line <> "")
  |> List.sort String.compare

let run_sorted ~bin args expected_file () =
  let expected = sort_nonempty_lines (read_expected expected_file) in
  let c = cmd bin args in
  match OS.Cmd.out_string ~trim:false (run_out c) with
  | Ok (stdout, (_, `Exited 0)) ->
      let lines = sort_nonempty_lines stdout in
      Alcotest.(check (list string)) "sorted lines" expected lines
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m
