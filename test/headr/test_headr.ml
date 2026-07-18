(* Integration tests for headr — port of test-harness/tests/headr/cli.rs *)

open Bos

let headr_bin =
  match Sys.getenv_opt "HEADR_BIN" with
  | Some p -> p
  | None -> "headr"

let empty = "inputs/empty.txt"
let one = "inputs/one.txt"
let two = "inputs/two.txt"
let three = "inputs/three.txt"
let ten = "inputs/ten.txt"

let headr args = Cmd.(v headr_bin %% of_list args)

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
  let cmd = headr args in
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
  let err_path = Fpath.v (Filename.temp_file "headr" "err") in
  let cmd = headr args in
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

let dies_bad_bytes () =
  let bad = random_string () in
  dies
    ~args:[ "-c"; bad; empty ]
    ~stderr_contains:("illegal byte count -- " ^ bad)
    ()

let dies_bad_lines () =
  let bad = random_string () in
  dies
    ~args:[ "-n"; bad; empty ]
    ~stderr_contains:("illegal line count -- " ^ bad)
    ()

let dies_bytes_and_lines () =
  dies
    ~args:[ "-n"; "1"; "-c"; "2" ]
    ~stderr_contains:
      "The argument '--lines <LINES>' cannot be used with '--bytes <BYTES>'"
    ()

let skips_bad_file () =
  let bad = gen_bad_file () in
  let err_path = Fpath.v (Filename.temp_file "headr" "err") in
  let cmd = headr [ empty; bad; one ] in
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

let () =
  Alcotest.run "headr"
    [
      ( "cli",
        [
          ("dies_bad_bytes", `Quick, dies_bad_bytes);
          ("dies_bad_lines", `Quick, dies_bad_lines);
          ("dies_bytes_and_lines", `Quick, dies_bytes_and_lines);
          ("skips_bad_file", `Quick, skips_bad_file);
          ("empty", `Quick, run_success [ empty ] "empty.txt.out");
          ("empty_n2", `Quick, run_success [ empty; "-n"; "2" ] "empty.txt.n2.out");
          ("empty_n4", `Quick, run_success [ empty; "-n"; "4" ] "empty.txt.n4.out");
          ("empty_c2", `Quick, run_success [ empty; "-c"; "2" ] "empty.txt.c2.out");
          ("empty_c4", `Quick, run_success [ empty; "-c"; "4" ] "empty.txt.c4.out");
          ("one", `Quick, run_success [ one ] "one.txt.out");
          ("one_n2", `Quick, run_success [ one; "-n"; "2" ] "one.txt.n2.out");
          ("one_n4", `Quick, run_success [ one; "-n"; "4" ] "one.txt.n4.out");
          ("one_c1", `Quick, run_success [ one; "-c"; "1" ] "one.txt.c1.out");
          ("one_c2", `Quick, run_success [ one; "-c"; "2" ] "one.txt.c2.out");
          ("one_c4", `Quick, run_success [ one; "-c"; "4" ] "one.txt.c4.out");
          ("one_stdin", `Quick, run_stdin [] one "one.txt.out");
          ("one_n2_stdin", `Quick, run_stdin [ "-n"; "2" ] one "one.txt.n2.out");
          ("one_n4_stdin", `Quick, run_stdin [ "-n"; "4" ] one "one.txt.n4.out");
          ("one_c1_stdin", `Quick, run_stdin [ "-c"; "1" ] one "one.txt.c1.out");
          ("one_c2_stdin", `Quick, run_stdin [ "-c"; "2" ] one "one.txt.c2.out");
          ("one_c4_stdin", `Quick, run_stdin [ "-c"; "4" ] one "one.txt.c4.out");
          ("two", `Quick, run_success [ two ] "two.txt.out");
          ("two_n2", `Quick, run_success [ two; "-n"; "2" ] "two.txt.n2.out");
          ("two_n4", `Quick, run_success [ two; "-n"; "4" ] "two.txt.n4.out");
          ("two_c2", `Quick, run_success [ two; "-c"; "2" ] "two.txt.c2.out");
          ("two_c4", `Quick, run_success [ two; "-c"; "4" ] "two.txt.c4.out");
          ("two_stdin", `Quick, run_stdin [] two "two.txt.out");
          ("two_n2_stdin", `Quick, run_stdin [ "-n"; "2" ] two "two.txt.n2.out");
          ("two_n4_stdin", `Quick, run_stdin [ "-n"; "4" ] two "two.txt.n4.out");
          ("two_c2_stdin", `Quick, run_stdin [ "-c"; "2" ] two "two.txt.c2.out");
          ("two_c4_stdin", `Quick, run_stdin [ "-c"; "4" ] two "two.txt.c4.out");
          ("three", `Quick, run_success [ three ] "three.txt.out");
          ("three_n2", `Quick, run_success [ three; "-n"; "2" ] "three.txt.n2.out");
          ("three_n4", `Quick, run_success [ three; "-n"; "4" ] "three.txt.n4.out");
          ("three_c2", `Quick, run_success [ three; "-c"; "2" ] "three.txt.c2.out");
          ("three_c4", `Quick, run_success [ three; "-c"; "4" ] "three.txt.c4.out");
          ("three_stdin", `Quick, run_stdin [] three "three.txt.out");
          ( "three_n2_stdin",
            `Quick,
            run_stdin [ "-n"; "2" ] three "three.txt.n2.out" );
          ( "three_n4_stdin",
            `Quick,
            run_stdin [ "-n"; "4" ] three "three.txt.n4.out" );
          ( "three_c2_stdin",
            `Quick,
            run_stdin [ "-c"; "2" ] three "three.txt.c2.out" );
          ( "three_c4_stdin",
            `Quick,
            run_stdin [ "-c"; "4" ] three "three.txt.c4.out" );
          ("ten", `Quick, run_success [ ten ] "ten.txt.out");
          ("ten_n2", `Quick, run_success [ ten; "-n"; "2" ] "ten.txt.n2.out");
          ("ten_n4", `Quick, run_success [ ten; "-n"; "4" ] "ten.txt.n4.out");
          ("ten_c2", `Quick, run_success [ ten; "-c"; "2" ] "ten.txt.c2.out");
          ("ten_c4", `Quick, run_success [ ten; "-c"; "4" ] "ten.txt.c4.out");
          ("ten_stdin", `Quick, run_stdin [] ten "ten.txt.out");
          ("ten_n2_stdin", `Quick, run_stdin [ "-n"; "2" ] ten "ten.txt.n2.out");
          ("ten_n4_stdin", `Quick, run_stdin [ "-n"; "4" ] ten "ten.txt.n4.out");
          ("ten_c2_stdin", `Quick, run_stdin [ "-c"; "2" ] ten "ten.txt.c2.out");
          ("ten_c4_stdin", `Quick, run_stdin [ "-c"; "4" ] ten "ten.txt.c4.out");
          ( "multiple_files",
            `Quick,
            run_success [ empty; one; two; three; ten ] "all.out" );
          ( "multiple_files_n2",
            `Quick,
            run_success
              [ empty; one; two; three; ten; "-n"; "2" ]
              "all.n2.out" );
          ( "multiple_files_n4",
            `Quick,
            run_success
              [ "-n"; "4"; empty; one; two; three; ten ]
              "all.n4.out" );
          ( "multiple_files_c1",
            `Quick,
            run_success
              [ empty; one; two; three; ten; "-c"; "1" ]
              "all.c1.out" );
          ( "multiple_files_c2",
            `Quick,
            run_success
              [ empty; one; two; three; ten; "-c"; "2" ]
              "all.c2.out" );
          ( "multiple_files_c4",
            `Quick,
            run_success
              [ "-c"; "4"; empty; one; two; three; ten ]
              "all.c4.out" );
        ] );
    ]
