(* Integration tests for uniqr — port of test-harness/tests/uniqr/cli.rs *)

open Bos

type test = { input : string; out : string; out_count : string }

let bin = Cli_test.bin_from_env "UNIQR_BIN"

let empty =
  {
    input = "inputs/empty.txt";
    out = "empty.txt.out";
    out_count = "empty.txt.c.out";
  }

let one =
  {
    input = "inputs/one.txt";
    out = "one.txt.out";
    out_count = "one.txt.c.out";
  }

let two =
  {
    input = "inputs/two.txt";
    out = "two.txt.out";
    out_count = "two.txt.c.out";
  }

let three =
  {
    input = "inputs/three.txt";
    out = "three.txt.out";
    out_count = "three.txt.c.out";
  }

let skip =
  {
    input = "inputs/skip.txt";
    out = "skip.txt.out";
    out_count = "skip.txt.c.out";
  }

let t1 =
  { input = "inputs/t1.txt"; out = "t1.txt.out"; out_count = "t1.txt.c.out" }

let t2 =
  { input = "inputs/t2.txt"; out = "t2.txt.out"; out_count = "t2.txt.c.out" }

let t3 =
  { input = "inputs/t3.txt"; out = "t3.txt.out"; out_count = "t3.txt.c.out" }

let t4 =
  { input = "inputs/t4.txt"; out = "t4.txt.out"; out_count = "t4.txt.c.out" }

let t5 =
  { input = "inputs/t5.txt"; out = "t5.txt.out"; out_count = "t5.txt.c.out" }

let t6 =
  { input = "inputs/t6.txt"; out = "t6.txt.out"; out_count = "t6.txt.c.out" }

let dies_bad_file () =
  let bad = Cli_test.gen_bad_file () in
  Cli_test.stderr_matches ~bin ~args:[ bad ]
    ~check:(fun ~stdout:_ ~stderr ~status ->
      (match status with
      | `Exited 0 -> Alcotest.fail "expected non-zero exit"
      | _ -> ());
      Alcotest.(check bool) "stderr mentions bad file" true
        (Cli_test.contains ~affix:bad stderr
        && Cli_test.contains ~affix:"No such file or directory" stderr))
    ()

let run (t : test) () = Cli_test.run_success ~bin [ t.input ] t.out ()

let run_count (t : test) () =
  Cli_test.run_success ~bin [ t.input; "-c" ] t.out_count ()

let run_stdin (t : test) () =
  let input = Cli_test.read_file t.input in
  Cli_test.run_success ~stdin:input ~bin [] t.out ()

let run_stdin_count (t : test) () =
  let input = Cli_test.read_file t.input in
  Cli_test.run_success ~stdin:input ~bin [ "--count" ] t.out_count ()

let run_outfile (t : test) () =
  let expected = Cli_test.read_expected t.out in
  let outpath = Filename.temp_file "uniqr" "out" in
  let c = Cli_test.cmd bin [ t.input; outpath ] in
  match OS.Cmd.out_string ~trim:false (Cli_test.run_out c) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout empty" "" stdout;
      Alcotest.(check string) "outfile" expected (Cli_test.read_file outpath)
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let run_outfile_count (t : test) () =
  let expected = Cli_test.read_expected t.out_count in
  let outpath = Filename.temp_file "uniqr" "out" in
  let c = Cli_test.cmd bin [ t.input; outpath; "--count" ] in
  match OS.Cmd.out_string ~trim:false (Cli_test.run_out c) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout empty" "" stdout;
      Alcotest.(check string) "outfile" expected (Cli_test.read_file outpath)
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let run_stdin_outfile_count (t : test) () =
  let input = Cli_test.read_file t.input in
  let expected = Cli_test.read_expected t.out_count in
  let outpath = Filename.temp_file "uniqr" "out" in
  let c = Cli_test.cmd bin [ "-"; outpath; "-c" ] in
  match
    OS.Cmd.out_string ~trim:false (Cli_test.run_out ~stdin:input c)
  with
  | Ok (stdout, _) ->
      Alcotest.(check string) "stdout empty" "" stdout;
      Alcotest.(check string) "outfile" expected (Cli_test.read_file outpath)
  | Error (`Msg m) -> Alcotest.fail m

let cases name t =
  [
    (name, `Quick, run t);
    (name ^ "_count", `Quick, run_count t);
    (name ^ "_stdin", `Quick, run_stdin t);
    (name ^ "_stdin_count", `Quick, run_stdin_count t);
    (name ^ "_outfile", `Quick, run_outfile t);
    (name ^ "_outfile_count", `Quick, run_outfile_count t);
    (name ^ "_stdin_outfile_count", `Quick, run_stdin_outfile_count t);
  ]

let () =
  Alcotest.run "uniqr"
    [
      ( "cli",
        ("dies_bad_file", `Quick, dies_bad_file)
        :: List.concat
             [
               cases "empty" empty;
               cases "one" one;
               cases "two" two;
               cases "three" three;
               cases "skip" skip;
               cases "t1" t1;
               cases "t2" t2;
               cases "t3" t3;
               cases "t4" t4;
               cases "t5" t5;
               cases "t6" t6;
             ] );
    ]
