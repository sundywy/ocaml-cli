(* Integration tests for commr — port of test-harness/tests/commr/cli.rs *)

open Bos

let commr_bin =
  match Sys.getenv_opt "COMMR_BIN" with
  | Some p -> p
  | None -> "commr"

let empty = "inputs/empty.txt"
let file1 = "inputs/file1.txt"
let file2 = "inputs/file2.txt"
let blank = "inputs/blank.txt"

let commr args = Cmd.(v commr_bin %% of_list args)

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

let run_success ?stdin args expected_file () =
  let expected = read_expected expected_file in
  let cmd = commr args in
  match OS.Cmd.out_string ~trim:false (run_out ?stdin cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout" expected stdout
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let run_stdin args input_file expected_file () =
  let input = read_file input_file in
  run_success ~stdin:input args expected_file ()

let dies ~args ~stderr_contains () =
  let err_path = Fpath.v (Filename.temp_file "commr" "err") in
  let cmd = commr args in
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

let dies_bad_file1 () =
  let bad = gen_bad_file () in
  dies ~args:[ bad; file1 ] ~stderr_contains:"No such file or directory" ()

let dies_bad_file2 () =
  let bad = gen_bad_file () in
  dies ~args:[ file1; bad ] ~stderr_contains:"No such file or directory" ()

let dies_both_stdin () =
  dies ~args:[ "-"; "-" ]
    ~stderr_contains:"Both input files cannot be STDIN (\"-\")" ()

let () =
  Alcotest.run "commr"
    [
      ( "cli",
        [
          ("dies_no_args", `Quick, dies_no_args);
          ("dies_bad_file1", `Quick, dies_bad_file1);
          ("dies_bad_file2", `Quick, dies_bad_file2);
          ("dies_both_stdin", `Quick, dies_both_stdin);
          ("empty_empty", `Quick, run_success [ empty; empty ] "empty_empty.out");
          ("file1_file1", `Quick, run_success [ file1; file1 ] "file1_file1.out");
          ("file1_file2", `Quick, run_success [ file1; file2 ] "file1_file2.out");
          ("file1_empty", `Quick, run_success [ file1; empty ] "file1_empty.out");
          ("empty_file2", `Quick, run_success [ empty; file2 ] "empty_file2.out");
          ( "file1_file2_1",
            `Quick,
            run_success [ "-1"; file1; file2 ] "file1_file2.1.out" );
          ( "file1_file2_2",
            `Quick,
            run_success [ "-2"; file1; file2 ] "file1_file2.2.out" );
          ( "file1_file2_3",
            `Quick,
            run_success [ "-3"; file1; file2 ] "file1_file2.3.out" );
          ( "file1_file2_1_2",
            `Quick,
            run_success [ "-12"; file1; file2 ] "file1_file2.12.out" );
          ( "file1_file2_2_3",
            `Quick,
            run_success [ "-23"; file1; file2 ] "file1_file2.23.out" );
          ( "file1_file2_13",
            `Quick,
            run_success [ "-13"; file1; file2 ] "file1_file2.13.out" );
          ( "file1_file2_123",
            `Quick,
            run_success [ "-123"; file1; file2 ] "file1_file2.123.out" );
          ( "file1_file2_1_i",
            `Quick,
            run_success [ "-1"; "-i"; file1; file2 ] "file1_file2.1.i.out" );
          ( "file1_file2_2_i",
            `Quick,
            run_success [ "-2"; "-i"; file1; file2 ] "file1_file2.2.i.out" );
          ( "file1_file2_3_i",
            `Quick,
            run_success [ "-3"; "-i"; file1; file2 ] "file1_file2.3.i.out" );
          ( "file1_file2_1_2_i",
            `Quick,
            run_success [ "-12"; "-i"; file1; file2 ] "file1_file2.12.i.out" );
          ( "file1_file2_2_3_i",
            `Quick,
            run_success [ "-23"; "-i"; file1; file2 ] "file1_file2.23.i.out" );
          ( "file1_file2_13_i",
            `Quick,
            run_success [ "-13"; "-i"; file1; file2 ] "file1_file2.13.i.out" );
          ( "file1_file2_123_i",
            `Quick,
            run_success [ "-123"; "-i"; file1; file2 ] "file1_file2.123.i.out"
          );
          ( "stdin_file1",
            `Quick,
            run_stdin [ "-123"; "-i"; "-"; file2 ] file1
              "file1_file2.123.i.out" );
          ( "stdin_file2",
            `Quick,
            run_stdin [ "-123"; "-i"; file1; "-" ] file2
              "file1_file2.123.i.out" );
          ( "file1_file2_delim",
            `Quick,
            run_success [ file1; file2; "-d"; ":" ] "file1_file2.delim.out" );
          ( "file1_file2_1_delim",
            `Quick,
            run_success
              [ file1; file2; "-1"; "-d"; ":" ]
              "file1_file2.1.delim.out" );
          ( "file1_file2_2_delim",
            `Quick,
            run_success
              [ file1; file2; "-2"; "-d"; ":" ]
              "file1_file2.2.delim.out" );
          ( "file1_file2_3_delim",
            `Quick,
            run_success
              [ file1; file2; "-3"; "-d"; ":" ]
              "file1_file2.3.delim.out" );
          ( "file1_file2_12_delim",
            `Quick,
            run_success
              [ file1; file2; "-12"; "-d"; ":" ]
              "file1_file2.12.delim.out" );
          ( "file1_file2_23_delim",
            `Quick,
            run_success
              [ file1; file2; "-23"; "-d"; ":" ]
              "file1_file2.23.delim.out" );
          ( "file1_file2_13_delim",
            `Quick,
            run_success
              [ file1; file2; "-13"; "-d"; ":" ]
              "file1_file2.13.delim.out" );
          ( "file1_file2_123_delim",
            `Quick,
            run_success
              [ file1; file2; "-123"; "-d"; ":" ]
              "file1_file2.123.delim.out" );
          ("blank_file1", `Quick, run_success [ blank; file1 ] "blank_file1.out");
        ] );
    ]
