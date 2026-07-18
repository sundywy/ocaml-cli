(* Integration tests for echor — port of test-harness/tests/echor/cli.rs *)

open Bos

let echor_bin =
  match Sys.getenv_opt "ECHOR_BIN" with
  | Some p -> p
  | None -> "echor"

let echor args = Cmd.(v echor_bin %% of_list args)

let read_expected name =
  let path = Fpath.(v "expected" / name) in
  match OS.File.read path with
  | Ok s -> s
  | Error (`Msg m) -> Alcotest.fail m

let contains ~affix s = Astring.String.is_infix ~affix s

let run_success args expected_file () =
  let expected = read_expected expected_file in
  let cmd = echor args in
  match OS.Cmd.(run_out cmd |> out_string ~trim:false) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout" expected stdout
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let dies_no_args () =
  let cmd = echor [] in
  match OS.Cmd.(run_out ~err:err_run_out cmd |> out_string ~trim:false) with
  | Ok (_, (_, `Exited 0)) -> Alcotest.fail "expected non-zero exit"
  | Ok (out, _) ->
      Alcotest.(check bool) "stderr contains Usage" true
        (contains ~affix:"Usage" out)
  | Error (`Msg m) -> Alcotest.fail m

let () =
  Alcotest.run "echor"
    [
      ( "cli",
        [
          ("dies_no_args", `Quick, dies_no_args);
          ("hello1", `Quick, run_success [ "Hello there" ] "hello1.txt");
          ("hello2", `Quick, run_success [ "Hello"; "there" ] "hello2.txt");
          ( "hello1_no_newline",
            `Quick,
            run_success [ "Hello  there"; "-n" ] "hello1.n.txt" );
          ( "hello2_no_newline",
            `Quick,
            run_success [ "-n"; "Hello"; "there" ] "hello2.n.txt" );
        ] );
    ]
