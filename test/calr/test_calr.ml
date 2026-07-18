(* Integration tests for calr — port of test-harness/tests/calr/cli.rs *)

open Bos

let calr_bin =
  match Sys.getenv_opt "CALR_BIN" with
  | Some p -> p
  | None -> "calr"

let calr args = Cmd.(v calr_bin %% of_list args)

let read_file path =
  match OS.File.read (Fpath.v path) with
  | Ok s -> s
  | Error (`Msg m) -> Alcotest.fail m

let read_expected name = read_file (Filename.concat "expected" name)

let contains ~affix s = Astring.String.is_infix ~affix s

let run_out ~err cmd =
  let err = Option.value err ~default:OS.Cmd.err_stderr in
  OS.Cmd.run_out ~err cmd

let run args expected_file () =
  let expected = read_expected expected_file in
  let cmd = calr args in
  match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout" expected stdout
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let dies ~args ?stderr_exact ?stderr_contains () =
  let err_path = Fpath.v (Filename.temp_file "calr" "err") in
  let cmd = calr args in
  match
    OS.Cmd.out_string ~trim:false
      (run_out ~err:(Some (OS.Cmd.err_file err_path)) cmd)
  with
  | Ok (_, (_, `Exited 0)) -> Alcotest.fail "expected non-zero exit"
  | Ok (_, _) -> (
      match OS.File.read err_path with
      | Ok stderr -> (
          match (stderr_exact, stderr_contains) with
          | Some expected, _ ->
              Alcotest.(check string) "stderr" expected stderr
          | None, Some affix ->
              Alcotest.(check bool)
                (Printf.sprintf "stderr contains %S" affix)
                true (contains ~affix stderr)
          | None, None -> ())
      | Error (`Msg m) -> Alcotest.fail m)
  | Error (`Msg m) -> Alcotest.fail m

let dies_year_0 () =
  dies ~args:[ "0" ]
    ~stderr_exact:"year \"0\" not in the range 1 through 9999\n" ()

let dies_year_13 () =
  dies ~args:[ "10000" ]
    ~stderr_exact:"year \"10000\" not in the range 1 through 9999\n" ()

let dies_invalid_year () =
  dies ~args:[ "foo" ] ~stderr_exact:"Invalid integer \"foo\"\n" ()

let dies_month_0 () =
  dies ~args:[ "-m"; "0" ]
    ~stderr_exact:"month \"0\" not in the range 1 through 12\n" ()

let dies_month_13 () =
  dies ~args:[ "-m"; "13" ]
    ~stderr_exact:"month \"13\" not in the range 1 through 12\n" ()

let dies_invalid_month () =
  dies ~args:[ "-m"; "foo" ] ~stderr_exact:"Invalid month \"foo\"\n" ()

let dies_y_and_month () =
  dies ~args:[ "-m"; "1"; "-y" ]
    ~stderr_contains:"The argument '-m <MONTH>' cannot be used with '--year'"
    ()

let dies_y_and_year () =
  dies ~args:[ "-y"; "2000" ]
    ~stderr_contains:"The argument '<YEAR>' cannot be used with '--year'" ()

let month_num () =
  let expected =
    [
      ("1", "January");
      ("2", "February");
      ("3", "March");
      ("4", "April");
      ("5", "May");
      ("6", "June");
      ("7", "July");
      ("8", "August");
      ("9", "September");
      ("10", "October");
      ("11", "November");
      ("12", "December");
    ]
  in
  List.iter
    (fun (num, month) ->
      let cmd = calr [ "-m"; num ] in
      match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
      | Ok (stdout, (_, `Exited 0)) ->
          Alcotest.(check bool)
            (Printf.sprintf "-m %s contains %s" num month)
            true (contains ~affix:month stdout)
      | Ok (_, (_, status)) ->
          Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
      | Error (`Msg m) -> Alcotest.fail m)
    expected

let partial_month () =
  let expected =
    [
      ("ja", "January");
      ("f", "February");
      ("mar", "March");
      ("ap", "April");
      ("may", "May");
      ("jun", "June");
      ("jul", "July");
      ("au", "August");
      ("s", "September");
      ("n", "November");
      ("d", "December");
    ]
  in
  List.iter
    (fun (arg, month) ->
      let cmd = calr [ "-m"; arg ] in
      match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
      | Ok (stdout, (_, `Exited 0)) ->
          Alcotest.(check bool)
            (Printf.sprintf "-m %s contains %s" arg month)
            true (contains ~affix:month stdout)
      | Ok (_, (_, status)) ->
          Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
      | Error (`Msg m) -> Alcotest.fail m)
    expected

let default_one_month () =
  let cmd = calr [] in
  match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      let lines = String.split_on_char '\n' stdout in
      Alcotest.(check int) "line count" 9 (List.length lines);
      Alcotest.(check int) "first line width" 22 (String.length (List.hd lines))
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let year () =
  let cmd = calr [ "-y" ] in
  match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      let lines = String.split_on_char '\n' stdout in
      Alcotest.(check int) "line count" 37 (List.length lines)
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let () =
  Alcotest.run "calr"
    [
      ( "cli",
        [
          ("dies_year_0", `Quick, dies_year_0);
          ("dies_year_13", `Quick, dies_year_13);
          ("dies_invalid_year", `Quick, dies_invalid_year);
          ("dies_month_0", `Quick, dies_month_0);
          ("dies_month_13", `Quick, dies_month_13);
          ("dies_invalid_month", `Quick, dies_invalid_month);
          ("dies_y_and_month", `Quick, dies_y_and_month);
          ("dies_y_and_year", `Quick, dies_y_and_year);
          ("month_num", `Quick, month_num);
          ("partial_month", `Quick, partial_month);
          ("default_one_month", `Quick, default_one_month);
          ("test_2_2020_leap_year", `Quick, run [ "-m"; "2"; "2020" ] "2-2020.txt");
          ("test_4_2020", `Quick, run [ "-m"; "4"; "2020" ] "4-2020.txt");
          ( "test_april_2020",
            `Quick,
            run [ "2020"; "-m"; "april" ] "4-2020.txt" );
          ("test_2020", `Quick, run [ "2020" ] "2020.txt");
          ("year", `Quick, year);
        ] );
    ]
