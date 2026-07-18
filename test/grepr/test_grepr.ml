(* Integration tests for grepr — port of test-harness/tests/grepr/cli.rs *)

open Bos

let grepr_bin =
  match Sys.getenv_opt "GREPR_BIN" with
  | Some p -> p
  | None -> "grepr"

let bustle = "inputs/bustle.txt"
let empty = "inputs/empty.txt"
let fox = "inputs/fox.txt"
let nobody = "inputs/nobody.txt"
let inputs_dir = "inputs"

let grepr args = Cmd.(v grepr_bin %% of_list args)

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

let () = Random.self_init ()

let run_out ?stdin ?err cmd =
  let err = Option.value err ~default:OS.Cmd.err_stderr in
  match stdin with
  | None -> OS.Cmd.run_out ~err cmd
  | Some input -> OS.Cmd.(in_string input |> run_io ~err cmd)

let expected_path name =
  let windows = name ^ ".windows" in
  let windows_full = Filename.concat "expected" windows in
  if Sys.os_type = "Win32" && Sys.file_exists windows_full then windows
  else name

let run_success ?stdin args expected_file () =
  let expected = read_expected (expected_path expected_file) in
  let cmd = grepr args in
  match OS.Cmd.out_string ~trim:false (run_out ?stdin cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout" expected stdout
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let dies ~args ~stderr_contains () =
  let err_path = Fpath.v (Filename.temp_file "grepr" "err") in
  let cmd = grepr args in
  match
    OS.Cmd.out_string ~trim:false
      (run_out ~err:(OS.Cmd.err_file err_path) cmd)
  with
  | Ok (_, (_, `Exited 0)) -> Alcotest.fail "expected non-zero exit"
  | Ok (_, _) -> (
      match OS.File.read err_path with
      | Ok stderr ->
          Alcotest.(check bool)
            (Printf.sprintf "stderr contains %S" stderr_contains)
            true
            (contains ~affix:stderr_contains stderr)
      | Error (`Msg m) -> Alcotest.fail m)
  | Error (`Msg m) -> Alcotest.fail m

let dies_no_args () = dies ~args:[] ~stderr_contains:"Usage" ()

let dies_bad_pattern () =
  dies ~args:[ "*foo"; fox ] ~stderr_contains:"Invalid pattern \"*foo\"" ()

let warns_bad_file () =
  let bad = gen_bad_file () in
  let err_path = Fpath.v (Filename.temp_file "grepr" "err") in
  let cmd = grepr [ "foo"; bad ] in
  match
    OS.Cmd.out_string ~trim:false
      (run_out ~err:(OS.Cmd.err_file err_path) cmd)
  with
  | Ok (_, _) -> (
      match OS.File.read err_path with
      | Ok stderr ->
          Alcotest.(check bool)
            "stderr mentions missing file" true
            (contains ~affix:(bad ^ ":") stderr
            && contains ~affix:"No such file or directory" stderr)
      | Error (`Msg m) -> Alcotest.fail m)
  | Error (`Msg m) -> Alcotest.fail m

let warns_dir_not_recursive () =
  let stdout_affix =
    "inputs/fox.txt:The quick brown fox jumps over the lazy dog."
  in
  let err_path = Fpath.v (Filename.temp_file "grepr" "err") in
  let cmd = grepr [ "fox"; inputs_dir; fox ] in
  match
    OS.Cmd.out_string ~trim:false
      (run_out ~err:(OS.Cmd.err_file err_path) cmd)
  with
  | Ok (stdout, _) -> (
      match OS.File.read err_path with
      | Ok stderr ->
          Alcotest.(check bool)
            "stderr mentions directory" true
            (contains ~affix:"inputs is a directory" stderr);
          Alcotest.(check bool)
            "stdout contains fox match" true
            (contains ~affix:stdout_affix stdout)
      | Error (`Msg m) -> Alcotest.fail m)
  | Error (`Msg m) -> Alcotest.fail m

let stdin () =
  let input = read_file bustle in
  run_success ~stdin:input [ "The" ] "bustle.txt.the.capitalized" ()

let stdin_insensitive_count () =
  let input =
    String.concat ""
      (List.map read_file [ bustle; empty; fox; nobody ])
  in
  run_success ~stdin:input [ "-ci"; "the"; "-" ]
    "the.recursive.insensitive.count.stdin" ()

let () =
  Alcotest.run "grepr"
    [
      ( "cli",
        [
          ("dies_no_args", `Quick, dies_no_args);
          ("dies_bad_pattern", `Quick, dies_bad_pattern);
          ("warns_bad_file", `Quick, warns_bad_file);
          ("empty_file", `Quick, run_success [ "foo"; empty ] "empty.foo");
          ( "empty_regex",
            `Quick,
            run_success [ ""; fox ] "empty_regex.fox.txt" );
          ( "bustle_capitalized",
            `Quick,
            run_success [ "The"; bustle ] "bustle.txt.the.capitalized" );
          ( "bustle_lowercase",
            `Quick,
            run_success [ "the"; bustle ] "bustle.txt.the.lowercase" );
          ( "bustle_insensitive",
            `Quick,
            run_success
              [ "--insensitive"; "the"; bustle ]
              "bustle.txt.the.lowercase.insensitive" );
          ("nobody", `Quick, run_success [ "nobody"; nobody ] "nobody.txt");
          ( "nobody_insensitive",
            `Quick,
            run_success [ "-i"; "nobody"; nobody ] "nobody.txt.insensitive" );
          ( "multiple_files",
            `Quick,
            run_success
              [ "The"; bustle; empty; fox; nobody ]
              "all.the.capitalized" );
          ( "multiple_files_insensitive",
            `Quick,
            run_success
              [ "-i"; "the"; bustle; empty; fox; nobody ]
              "all.the.lowercase.insensitive" );
          ( "recursive",
            `Quick,
            run_success [ "--recursive"; "dog"; inputs_dir ] "dog.recursive" );
          ( "recursive_insensitive",
            `Quick,
            run_success
              [ "-ri"; "then"; inputs_dir ]
              "the.recursive.insensitive" );
          ( "sensitive_count_capital",
            `Quick,
            run_success
              [ "--count"; "The"; bustle ]
              "bustle.txt.the.capitalized.count" );
          ( "sensitive_count_lower",
            `Quick,
            run_success
              [ "--count"; "the"; bustle ]
              "bustle.txt.the.lowercase.count" );
          ( "insensitive_count",
            `Quick,
            run_success
              [ "-ci"; "the"; bustle ]
              "bustle.txt.the.lowercase.insensitive.count" );
          ( "nobody_count",
            `Quick,
            run_success [ "-c"; "nobody"; nobody ] "nobody.txt.count" );
          ( "nobody_count_insensitive",
            `Quick,
            run_success
              [ "-ci"; "nobody"; nobody ]
              "nobody.txt.insensitive.count" );
          ( "sensitive_count_multiple",
            `Quick,
            run_success
              [ "-c"; "The"; bustle; empty; fox; nobody ]
              "all.the.capitalized.count" );
          ( "insensitive_count_multiple",
            `Quick,
            run_success
              [ "-ic"; "the"; bustle; empty; fox; nobody ]
              "all.the.lowercase.insensitive.count" );
          ("warns_dir_not_recursive", `Quick, warns_dir_not_recursive);
          ("stdin", `Quick, stdin);
          ("stdin_insensitive_count", `Quick, stdin_insensitive_count);
        ] );
    ]
