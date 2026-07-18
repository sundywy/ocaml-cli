(* Integration tests for catr — port of test-harness/tests/catr/cli.rs *)

open Bos

let catr_bin =
  match Sys.getenv_opt "CATR_BIN" with
  | Some p -> p
  | None -> "catr"

let empty = "inputs/empty.txt"
let fox = "inputs/fox.txt"
let spiders = "inputs/spiders.txt"
let bustle = "inputs/the-bustle.txt"

let catr args = Cmd.(v catr_bin %% of_list args)

let read_file path =
  match OS.File.read (Fpath.v path) with
  | Ok s -> s
  | Error (`Msg m) -> Alcotest.fail m

let read_expected name = read_file (Filename.concat "expected" name)

let gen_bad_file () =
  let rec loop () =
    let name =
      String.init 7 (fun _ ->
          match Random.int (10 + 26) with
          | n when n < 10 -> Char.chr (Char.code '0' + n)
          | n -> Char.chr (Char.code 'a' + n - 10))
    in
    match OS.File.must_exist (Fpath.v name) with
    | Ok _ -> loop ()
    | Error _ -> name
  in
  Random.self_init ();
  loop ()

let run_success ?stdin args expected_file () =
  let expected = read_expected expected_file in
  let cmd = catr args in
  let output =
    match stdin with
    | None -> OS.Cmd.run_out cmd
    | Some input -> OS.Cmd.(in_string input |> run_io cmd)
  in
  match OS.Cmd.out_string ~trim:false output with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout" expected stdout
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let run_stdin input_file args expected_file () =
  let input = read_file input_file in
  run_success ~stdin:input args expected_file ()

let skips_bad_file () =
  let bad = gen_bad_file () in
  let expected = bad ^ ": No such file or directory\n" in
  let err_path = Fpath.v (Filename.temp_file "catr" "err") in
  let cmd = catr [ bad ] in
  match
    OS.Cmd.(run_out ~err:(err_file err_path) cmd |> out_string ~trim:false)
  with
  | Ok (_, (_, `Exited 0)) -> (
      match OS.File.read err_path with
      | Ok stderr -> Alcotest.(check string) "stderr" expected stderr
      | Error (`Msg m) -> Alcotest.fail m)
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let () =
  Alcotest.run "catr"
    [
      ( "cli",
        [
          ("skips_bad_file", `Quick, skips_bad_file);
          ("bustle_stdin", `Quick, run_stdin bustle [ "-" ] "the-bustle.txt.stdin.out");
          ( "bustle_stdin_n",
            `Quick,
            run_stdin bustle [ "-n"; "-" ] "the-bustle.txt.n.stdin.out" );
          ( "bustle_stdin_b",
            `Quick,
            run_stdin bustle [ "-b"; "-" ] "the-bustle.txt.b.stdin.out" );
          ("empty", `Quick, run_success [ empty ] "empty.txt.out");
          ("empty_n", `Quick, run_success [ "-n"; empty ] "empty.txt.n.out");
          ("empty_b", `Quick, run_success [ "-b"; empty ] "empty.txt.b.out");
          ("fox", `Quick, run_success [ fox ] "fox.txt.out");
          ("fox_n", `Quick, run_success [ "-n"; fox ] "fox.txt.n.out");
          ("fox_b", `Quick, run_success [ "-b"; fox ] "fox.txt.b.out");
          ("spiders", `Quick, run_success [ spiders ] "spiders.txt.out");
          ( "spiders_n",
            `Quick,
            run_success [ "--number"; spiders ] "spiders.txt.n.out" );
          ( "spiders_b",
            `Quick,
            run_success [ "--number-nonblank"; spiders ] "spiders.txt.b.out" );
          ("bustle", `Quick, run_success [ bustle ] "the-bustle.txt.out");
          ("bustle_n", `Quick, run_success [ "-n"; bustle ] "the-bustle.txt.n.out");
          ("bustle_b", `Quick, run_success [ "-b"; bustle ] "the-bustle.txt.b.out");
          ( "all",
            `Quick,
            run_success [ fox; spiders; bustle ] "all.out" );
          ( "all_n",
            `Quick,
            run_success [ fox; spiders; bustle; "-n" ] "all.n.out" );
          ( "all_b",
            `Quick,
            run_success [ fox; spiders; bustle; "-b" ] "all.b.out" );
        ] );
    ]
