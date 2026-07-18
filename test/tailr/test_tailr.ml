(* Integration tests for tailr — port of test-harness/tests/tailr/cli.rs *)

open Bos

let tailr_bin =
  match Sys.getenv_opt "TAILR_BIN" with
  | Some p -> p
  | None -> "tailr"

let empty = "inputs/empty.txt"
let one = "inputs/one.txt"
let two = "inputs/two.txt"
let three = "inputs/three.txt"
let ten = "inputs/ten.txt"

let tailr args = Cmd.(v tailr_bin %% of_list args)

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

let run_success args expected_file () =
  let expected = read_expected expected_file in
  let cmd = tailr args in
  match OS.Cmd.out_string ~trim:false (run_out cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout" expected stdout
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let dies ~args ~stderr_contains () =
  let err_path = Fpath.v (Filename.temp_file "tailr" "err") in
  let cmd = tailr args in
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
  let err_path = Fpath.v (Filename.temp_file "tailr" "err") in
  let cmd = tailr [ one; bad; two ] in
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
  Alcotest.run "tailr"
    [
      ( "cli",
        [
          ("dies_no_args", `Quick, dies_no_args);
          ("dies_bad_bytes", `Quick, dies_bad_bytes);
          ("dies_bad_lines", `Quick, dies_bad_lines);
          ("dies_bytes_and_lines", `Quick, dies_bytes_and_lines);
          ("skips_bad_file", `Quick, skips_bad_file);
          ("empty", `Quick, run_success [ empty ] "empty.txt.out");
          ("empty_n0", `Quick, run_success [ empty; "-n"; "0" ] "empty.txt.n0.out");
          ("empty_n1", `Quick, run_success [ empty; "-n"; "1" ] "empty.txt.n1.out");
          ("empty_n_minus_1", `Quick, run_success [ empty; "-n=-1" ] "empty.txt.n1.out");
          ("empty_n3", `Quick, run_success [ empty; "-n"; "3" ] "empty.txt.n3.out");
          ("empty_n_minus_3", `Quick, run_success [ empty; "-n=-3" ] "empty.txt.n3.out");
          ("empty_n4", `Quick, run_success [ empty; "-n"; "4" ] "empty.txt.n4.out");
          ("empty_n200", `Quick, run_success [ empty; "-n"; "200" ] "empty.txt.n200.out");
          ( "empty_n_minus_200",
            `Quick,
            run_success [ empty; "-n=-200" ] "empty.txt.n200.out" );
          ("empty_n_minus_4", `Quick, run_success [ empty; "-n=-4" ] "empty.txt.n4.out");
          ( "empty_n_plus_0",
            `Quick,
            run_success [ empty; "-n"; "+0" ] "empty.txt.n+0.out" );
          ( "empty_n_plus_1",
            `Quick,
            run_success [ empty; "-n"; "+1" ] "empty.txt.n+1.out" );
          ( "empty_n_plus_2",
            `Quick,
            run_success [ empty; "-n"; "+2" ] "empty.txt.n+2.out" );
          ("empty_c3", `Quick, run_success [ empty; "-c"; "3" ] "empty.txt.c3.out");
          ("empty_c_minus_3", `Quick, run_success [ empty; "-c=-3" ] "empty.txt.c3.out");
          ("empty_c8", `Quick, run_success [ empty; "-c"; "8" ] "empty.txt.c8.out");
          ("empty_c_minus_8", `Quick, run_success [ empty; "-c=8" ] "empty.txt.c8.out");
          ("empty_c12", `Quick, run_success [ empty; "-c"; "12" ] "empty.txt.c12.out");
          ( "empty_c_minus_12",
            `Quick,
            run_success [ empty; "-c=-12" ] "empty.txt.c12.out" );
          ("empty_c200", `Quick, run_success [ empty; "-c"; "200" ] "empty.txt.c200.out");
          ( "empty_c_minus_200",
            `Quick,
            run_success [ empty; "-c=-200" ] "empty.txt.c200.out" );
          ( "empty_c_plus_0",
            `Quick,
            run_success [ empty; "-c"; "+0" ] "empty.txt.c+0.out" );
          ( "empty_c_plus_1",
            `Quick,
            run_success [ empty; "-c"; "+1" ] "empty.txt.c+1.out" );
          ( "empty_c_plus_2",
            `Quick,
            run_success [ empty; "-c"; "+2" ] "empty.txt.c+2.out" );
          ("one", `Quick, run_success [ one ] "one.txt.out");
          ("one_n0", `Quick, run_success [ one; "-n"; "0" ] "one.txt.n0.out");
          ("one_n1", `Quick, run_success [ one; "-n"; "1" ] "one.txt.n1.out");
          ("one_n_minus_1", `Quick, run_success [ one; "-n=-1" ] "one.txt.n1.out");
          ("one_n3", `Quick, run_success [ one; "-n"; "3" ] "one.txt.n3.out");
          ("one_n_minus_3", `Quick, run_success [ one; "-n=-3" ] "one.txt.n3.out");
          ("one_n4", `Quick, run_success [ one; "-n"; "4" ] "one.txt.n4.out");
          ("one_n_minus_4", `Quick, run_success [ one; "-n=-4" ] "one.txt.n4.out");
          ("one_n200", `Quick, run_success [ one; "-n"; "200" ] "one.txt.n200.out");
          ("one_n_minus_200", `Quick, run_success [ one; "-n=-200" ] "one.txt.n200.out");
          ("one_n_plus_0", `Quick, run_success [ one; "-n"; "+0" ] "one.txt.n+0.out");
          ("one_n_plus_1", `Quick, run_success [ one; "-n"; "+1" ] "one.txt.n+1.out");
          ("one_n_plus_2", `Quick, run_success [ one; "-n"; "+2" ] "one.txt.n+2.out");
          ("one_c3", `Quick, run_success [ one; "-c"; "3" ] "one.txt.c3.out");
          ("one_c_minus_3", `Quick, run_success [ one; "-c=-3" ] "one.txt.c3.out");
          ("one_c8", `Quick, run_success [ one; "-c"; "8" ] "one.txt.c8.out");
          ("one_c_minus_8", `Quick, run_success [ one; "-c=8" ] "one.txt.c8.out");
          ("one_c12", `Quick, run_success [ one; "-c"; "12" ] "one.txt.c12.out");
          ("one_c_minus_12", `Quick, run_success [ one; "-c=-12" ] "one.txt.c12.out");
          ("one_c200", `Quick, run_success [ one; "-c"; "200" ] "one.txt.c200.out");
          ("one_c_minus_200", `Quick, run_success [ one; "-c=-200" ] "one.txt.c200.out");
          ("one_c_plus_0", `Quick, run_success [ one; "-c"; "+0" ] "one.txt.c+0.out");
          ("one_c_plus_1", `Quick, run_success [ one; "-c"; "+1" ] "one.txt.c+1.out");
          ("one_c_plus_2", `Quick, run_success [ one; "-c"; "+2" ] "one.txt.c+2.out");
          ("two", `Quick, run_success [ two ] "two.txt.out");
          ("two_n0", `Quick, run_success [ two; "-n"; "0" ] "two.txt.n0.out");
          ("two_n1", `Quick, run_success [ two; "-n"; "1" ] "two.txt.n1.out");
          ("two_n_minus_1", `Quick, run_success [ two; "-n=-1" ] "two.txt.n1.out");
          ("two_n3", `Quick, run_success [ two; "-n"; "3" ] "two.txt.n3.out");
          ("two_n_minus_3", `Quick, run_success [ two; "-n=-3" ] "two.txt.n3.out");
          ("two_n4", `Quick, run_success [ two; "-n"; "4" ] "two.txt.n4.out");
          ("two_n_minus_4", `Quick, run_success [ two; "-n=-4" ] "two.txt.n4.out");
          ("two_n200", `Quick, run_success [ two; "-n"; "200" ] "two.txt.n200.out");
          ("two_n_minus_200", `Quick, run_success [ two; "-n=-200" ] "two.txt.n200.out");
          ("two_n_plus_0", `Quick, run_success [ two; "-n"; "+0" ] "two.txt.n+0.out");
          ("two_n_plus_1", `Quick, run_success [ two; "-n"; "+1" ] "two.txt.n+1.out");
          ("two_n_plus_2", `Quick, run_success [ two; "-n"; "+2" ] "two.txt.n+2.out");
          ("two_c3", `Quick, run_success [ two; "-c"; "3" ] "two.txt.c3.out");
          ("two_c_minus_3", `Quick, run_success [ two; "-c=-3" ] "two.txt.c3.out");
          ("two_c8", `Quick, run_success [ two; "-c"; "8" ] "two.txt.c8.out");
          ("two_c_minus_8", `Quick, run_success [ two; "-c=8" ] "two.txt.c8.out");
          ("two_c12", `Quick, run_success [ two; "-c"; "12" ] "two.txt.c12.out");
          ("two_c_minus_12", `Quick, run_success [ two; "-c=-12" ] "two.txt.c12.out");
          ("two_c200", `Quick, run_success [ two; "-c"; "200" ] "two.txt.c200.out");
          ("two_c_minus_200", `Quick, run_success [ two; "-c=-200" ] "two.txt.c200.out");
          ("two_c_plus_0", `Quick, run_success [ two; "-c"; "+0" ] "two.txt.c+0.out");
          ("two_c_plus_1", `Quick, run_success [ two; "-c"; "+1" ] "two.txt.c+1.out");
          ("two_c_plus_2", `Quick, run_success [ two; "-c"; "+2" ] "two.txt.c+2.out");
          ("three", `Quick, run_success [ three ] "three.txt.out");
          ("three_n0", `Quick, run_success [ three; "-n"; "0" ] "three.txt.n0.out");
          ("three_n1", `Quick, run_success [ three; "-n"; "1" ] "three.txt.n1.out");
          ("three_n_minus_1", `Quick, run_success [ three; "-n=-1" ] "three.txt.n1.out");
          ("three_n3", `Quick, run_success [ three; "-n"; "3" ] "three.txt.n3.out");
          ("three_n_minus_3", `Quick, run_success [ three; "-n=-3" ] "three.txt.n3.out");
          ("three_n4", `Quick, run_success [ three; "-n"; "4" ] "three.txt.n4.out");
          ("three_n_minus_4", `Quick, run_success [ three; "-n=-4" ] "three.txt.n4.out");
          ("three_n200", `Quick, run_success [ three; "-n"; "200" ] "three.txt.n200.out");
          ( "three_n_minus_200",
            `Quick,
            run_success [ three; "-n=-200" ] "three.txt.n200.out" );
          ( "three_n_plus_0",
            `Quick,
            run_success [ three; "-n"; "+0" ] "three.txt.n+0.out" );
          ( "three_n_plus_1",
            `Quick,
            run_success [ three; "-n"; "+1" ] "three.txt.n+1.out" );
          ( "three_n_plus_2",
            `Quick,
            run_success [ three; "-n"; "+2" ] "three.txt.n+2.out" );
          ("three_c3", `Quick, run_success [ three; "-c"; "3" ] "three.txt.c3.out");
          ("three_c_minus_3", `Quick, run_success [ three; "-c=-3" ] "three.txt.c3.out");
          ("three_c8", `Quick, run_success [ three; "-c"; "8" ] "three.txt.c8.out");
          ("three_c_minus_8", `Quick, run_success [ three; "-c=8" ] "three.txt.c8.out");
          ("three_c12", `Quick, run_success [ three; "-c"; "12" ] "three.txt.c12.out");
          ( "three_c_minus_12",
            `Quick,
            run_success [ three; "-c=-12" ] "three.txt.c12.out" );
          ("three_c200", `Quick, run_success [ three; "-c"; "200" ] "three.txt.c200.out");
          ( "three_c_minus_200",
            `Quick,
            run_success [ three; "-c=-200" ] "three.txt.c200.out" );
          ( "three_c_plus_0",
            `Quick,
            run_success [ three; "-c"; "+0" ] "three.txt.c+0.out" );
          ( "three_c_plus_1",
            `Quick,
            run_success [ three; "-c"; "+1" ] "three.txt.c+1.out" );
          ( "three_c_plus_2",
            `Quick,
            run_success [ three; "-c"; "+2" ] "three.txt.c+2.out" );
          ("ten", `Quick, run_success [ ten ] "ten.txt.out");
          ("ten_n0", `Quick, run_success [ ten; "-n"; "0" ] "ten.txt.n0.out");
          ("ten_n1", `Quick, run_success [ ten; "-n"; "1" ] "ten.txt.n1.out");
          ("ten_n_minus_1", `Quick, run_success [ ten; "-n=-1" ] "ten.txt.n1.out");
          ("ten_n3", `Quick, run_success [ ten; "-n"; "3" ] "ten.txt.n3.out");
          ("ten_n_minus_3", `Quick, run_success [ ten; "-n=-3" ] "ten.txt.n3.out");
          ("ten_n4", `Quick, run_success [ ten; "-n"; "4" ] "ten.txt.n4.out");
          ("ten_n_minus_4", `Quick, run_success [ ten; "-n=-4" ] "ten.txt.n4.out");
          ("ten_n200", `Quick, run_success [ ten; "-n"; "200" ] "ten.txt.n200.out");
          ("ten_n_minus_200", `Quick, run_success [ ten; "-n=-200" ] "ten.txt.n200.out");
          ("ten_c3", `Quick, run_success [ ten; "-c"; "3" ] "ten.txt.c3.out");
          ("ten_c_minus_3", `Quick, run_success [ ten; "-c=-3" ] "ten.txt.c3.out");
          ("ten_c8", `Quick, run_success [ ten; "-c"; "8" ] "ten.txt.c8.out");
          ("ten_c_minus_8", `Quick, run_success [ ten; "-c=8" ] "ten.txt.c8.out");
          ("ten_c12", `Quick, run_success [ ten; "-c"; "12" ] "ten.txt.c12.out");
          ("ten_c_minus_12", `Quick, run_success [ ten; "-c=-12" ] "ten.txt.c12.out");
          ("ten_c200", `Quick, run_success [ ten; "-c"; "200" ] "ten.txt.c200.out");
          ("ten_c_minus_200", `Quick, run_success [ ten; "-c=-200" ] "ten.txt.c200.out");
          ("ten_n_plus_0", `Quick, run_success [ ten; "-n"; "+0" ] "ten.txt.n+0.out");
          ("ten_n_plus_1", `Quick, run_success [ ten; "-n"; "+1" ] "ten.txt.n+1.out");
          ("ten_n_plus_2", `Quick, run_success [ ten; "-n"; "+2" ] "ten.txt.n+2.out");
          ("ten_c_plus_0", `Quick, run_success [ ten; "-c"; "+0" ] "ten.txt.c+0.out");
          ("ten_c_plus_1", `Quick, run_success [ ten; "-c"; "+1" ] "ten.txt.c+1.out");
          ("ten_c_plus_2", `Quick, run_success [ ten; "-c"; "+2" ] "ten.txt.c+2.out");
          ( "multiple_files",
            `Quick,
            run_success [ ten; empty; one; three; two ] "all.out" );
          ( "multiple_files_n0",
            `Quick,
            run_success [ "-n"; "0"; ten; empty; one; three; two ] "all.n0.out" );
          ( "multiple_files_n1",
            `Quick,
            run_success [ "-n"; "1"; ten; empty; one; three; two ] "all.n1.out" );
          ( "multiple_files_n1_q",
            `Quick,
            run_success [ "-n"; "1"; "-q"; ten; empty; one; three; two ] "all.n1.q.out" );
          ( "multiple_files_n1_quiet",
            `Quick,
            run_success [ "-n"; "1"; "--quiet"; ten; empty; one; three; two ] "all.n1.q.out" );
          ( "multiple_files_n_minus_1",
            `Quick,
            run_success [ "-n=-1"; ten; empty; one; three; two ] "all.n1.out" );
          ( "multiple_files_n_plus_1",
            `Quick,
            run_success [ "-n"; "+1"; ten; empty; one; three; two ] "all.n+1.out" );
          ( "multiple_files_n3",
            `Quick,
            run_success [ "-n"; "3"; ten; empty; one; three; two ] "all.n3.out" );
          ( "multiple_files_n_minus_3",
            `Quick,
            run_success [ "-n=-3"; ten; empty; one; three; two ] "all.n3.out" );
          ( "multiple_files_n_plus_3",
            `Quick,
            run_success [ "-n"; "+3"; ten; empty; one; three; two ] "all.n+3.out" );
          ( "multiple_files_c0",
            `Quick,
            run_success [ "-c"; "0"; ten; empty; one; three; two ] "all.c0.out" );
          ( "multiple_files_c3",
            `Quick,
            run_success [ "-c"; "3"; ten; empty; one; three; two ] "all.c3.out" );
          ( "multiple_files_c_minus_3",
            `Quick,
            run_success [ "-c=-3"; ten; empty; one; three; two ] "all.c3.out" );
          ( "multiple_files_c_plus_3",
            `Quick,
            run_success [ "-c"; "+3"; ten; empty; one; three; two ] "all.c+3.out" );
        ] );
    ]
