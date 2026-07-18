(* Integration tests for findr — port of test-harness/tests/findr/cli.rs *)

open Bos

let bin = Cli_test.bin_from_env "FINDR_BIN"

let inputs = "inputs"

let skips_bad_dir () =
  let bad = Cli_test.gen_bad_file () in
  Cli_test.stderr_matches ~bin ~args:[ bad ]
    ~check:(fun ~stdout:_ ~stderr ~status ->
      (match status with
      | `Exited 0 -> ()
      | s -> Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status s);
      Alcotest.(check bool) "stderr mentions missing dir" true
        (Cli_test.contains ~affix:(bad ^ ":") stderr
        && Cli_test.contains ~affix:"No such file or directory" stderr))
    ()

let dies_bad_name () =
  Cli_test.dies ~bin
    ~args:[ "--name"; "*.csv" ]
    ~stderr_contains:"Invalid --name \"*.csv\""
    ()

let dies_bad_type () =
  Cli_test.dies ~bin
    ~args:[ "--type"; "x" ]
    ~stderr_contains:"error: 'x' isn't a valid value for '--type <TYPE>...'"
    ()

let run args expected = Cli_test.run_sorted ~bin args expected

let unreadable_dir () =
  let dirname = "inputs/cant-touch-this" in
  (match OS.Dir.exists (Fpath.v dirname) with
  | Ok true -> ()
  | Ok false -> (
      match OS.Dir.create (Fpath.v dirname) with
      | Ok _ -> ()
      | Error (`Msg m) -> Alcotest.fail m)
  | Error (`Msg m) -> Alcotest.fail m);
  (match
     OS.Cmd.run Cmd.(v "chmod" % "000" % dirname)
   with
  | Ok () -> ()
  | Error (`Msg m) -> Alcotest.fail m);
  let err_path = Fpath.v (Filename.temp_file "findr" "err") in
  let c = Cli_test.cmd bin [ inputs ] in
  let result =
    OS.Cmd.out_string ~trim:false
      (Cli_test.run_out ~err:(OS.Cmd.err_file err_path) c)
  in
  let () =
    match OS.Cmd.run Cmd.(v "chmod" % "755" % dirname) with
    | Ok () | Error _ -> ()
  in
  let () =
    match OS.Dir.delete (Fpath.v dirname) with
    | Ok () | Error _ -> ()
  in
  match result with
  | Ok (stdout, (_, `Exited 0)) -> (
      let lines =
        stdout
        |> String.split_on_char '\n'
        |> List.filter (fun line -> line <> "")
      in
      Alcotest.(check int) "line count" 17 (List.length lines);
      match OS.File.read err_path with
      | Ok stderr ->
          Alcotest.(check bool) "permission denied" true
            (Cli_test.contains ~affix:"cant-touch-this: Permission denied"
               stderr)
      | Error (`Msg m) -> Alcotest.fail m)
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let () =
  Alcotest.run "findr"
    [
      ( "cli",
        [
          ("skips_bad_dir", `Quick, skips_bad_dir);
          ("dies_bad_name", `Quick, dies_bad_name);
          ("dies_bad_type", `Quick, dies_bad_type);
          ("path1", `Quick, run [ inputs ] "path1.txt");
          ("path_a", `Quick, run [ "inputs/a" ] "path_a.txt");
          ("path_a_b", `Quick, run [ "inputs/a/b" ] "path_a_b.txt");
          ("path_d", `Quick, run [ "inputs/d" ] "path_d.txt");
          ( "path_a_b_d",
            `Quick,
            run [ "inputs/a/b"; "inputs/d" ] "path_a_b_d.txt" );
          ("type_f", `Quick, run [ inputs; "-t"; "f" ] "type_f.txt");
          ( "type_f_path_a",
            `Quick,
            run [ "inputs/a"; "-t"; "f" ] "type_f_path_a.txt" );
          ( "type_f_path_a_b",
            `Quick,
            run [ "inputs/a/b"; "--type"; "f" ] "type_f_path_a_b.txt" );
          ( "type_f_path_d",
            `Quick,
            run [ "inputs/d"; "--type"; "f" ] "type_f_path_d.txt" );
          ( "type_f_path_a_b_d",
            `Quick,
            run
              [ "inputs/a/b"; "inputs/d"; "--type"; "f" ]
              "type_f_path_a_b_d.txt" );
          ("type_d", `Quick, run [ inputs; "-t"; "d" ] "type_d.txt");
          ( "type_d_path_a",
            `Quick,
            run [ "inputs/a"; "-t"; "d" ] "type_d_path_a.txt" );
          ( "type_d_path_a_b",
            `Quick,
            run [ "inputs/a/b"; "--type"; "d" ] "type_d_path_a_b.txt" );
          ( "type_d_path_d",
            `Quick,
            run [ "inputs/d"; "--type"; "d" ] "type_d_path_d.txt" );
          ( "type_d_path_a_b_d",
            `Quick,
            run
              [ "inputs/a/b"; "inputs/d"; "--type"; "d" ]
              "type_d_path_a_b_d.txt" );
          ("type_l", `Quick, run [ inputs; "-t"; "l" ] "type_l.txt");
          ("type_f_l", `Quick, run [ inputs; "-t"; "l"; "f" ] "type_f_l.txt");
          ("name_csv", `Quick, run [ inputs; "-n"; ".*[.]csv" ] "name_csv.txt");
          ( "name_csv_mp3",
            `Quick,
            run
              [ inputs; "-n"; ".*[.]csv"; "-n"; ".*[.]mp3" ]
              "name_csv_mp3.txt" );
          ( "name_txt_path_a_d",
            `Quick,
            run
              [ "inputs/a"; "inputs/d"; "--name"; ".*.txt" ]
              "name_txt_path_a_d.txt" );
          ("name_a", `Quick, run [ inputs; "-n"; "a" ] "name_a.txt");
          ( "type_f_name_a",
            `Quick,
            run [ inputs; "-t"; "f"; "-n"; "a" ] "type_f_name_a.txt" );
          ( "type_d_name_a",
            `Quick,
            run [ inputs; "--type"; "d"; "--name"; "a" ] "type_d_name_a.txt" );
          ("path_g", `Quick, run [ "inputs/g.csv" ] "path_g.txt");
          ("unreadable_dir", `Quick, unreadable_dir);
        ] );
    ]
