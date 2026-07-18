(* Integration tests for wcr — port of test-harness/tests/wcr/cli.rs *)

let bin = Cli_test.bin_from_env "WCR_BIN"

let empty = "inputs/empty.txt"
let fox = "inputs/fox.txt"
let atlamal = "inputs/atlamal.txt"

let run args expected = Cli_test.run_success ~bin args expected
let run_stdin input_file args expected () =
  let input = Cli_test.read_file input_file in
  Cli_test.run_success ~stdin:input ~bin args expected ()

let dies_chars_and_bytes () =
  Cli_test.dies ~bin ~args:[ "-m"; "-c" ]
    ~stderr_contains:"The argument '--bytes' cannot be used with '--chars'"
    ()

let skips_bad_file () =
  let bad = Cli_test.gen_bad_file () in
  Cli_test.stderr_matches ~bin ~args:[ bad ]
    ~check:(fun ~stdout:_ ~stderr ~status ->
      (match status with
      | `Exited 0 -> ()
      | s -> Alcotest.failf "expected exit 0, got %a" Bos.OS.Cmd.pp_status s);
      Alcotest.(check bool) "stderr mentions missing file" true
        (Cli_test.contains ~affix:(bad ^ ":") stderr
        && Cli_test.contains ~affix:"No such file or directory" stderr))
    ()

let () =
  Alcotest.run "wcr"
    [
      ( "cli",
        [
          ("dies_chars_and_bytes", `Quick, dies_chars_and_bytes);
          ("skips_bad_file", `Quick, skips_bad_file);
          ("empty", `Quick, run [ empty ] "empty.txt.out");
          ("fox", `Quick, run [ fox ] "fox.txt.out");
          ("fox_bytes", `Quick, run [ "--bytes"; fox ] "fox.txt.c.out");
          ("fox_chars", `Quick, run [ "--chars"; fox ] "fox.txt.m.out");
          ("fox_words", `Quick, run [ "--words"; fox ] "fox.txt.w.out");
          ("fox_lines", `Quick, run [ "--lines"; fox ] "fox.txt.l.out");
          ("fox_words_bytes", `Quick, run [ "-w"; "-c"; fox ] "fox.txt.wc.out");
          ("fox_words_lines", `Quick, run [ "-w"; "-l"; fox ] "fox.txt.wl.out");
          ("fox_bytes_lines", `Quick, run [ "-l"; "-c"; fox ] "fox.txt.cl.out");
          ("atlamal", `Quick, run [ atlamal ] "atlamal.txt.out");
          ("atlamal_bytes", `Quick, run [ "-c"; atlamal ] "atlamal.txt.c.out");
          ("atlamal_words", `Quick, run [ "-w"; atlamal ] "atlamal.txt.w.out");
          ("atlamal_lines", `Quick, run [ "-l"; atlamal ] "atlamal.txt.l.out");
          ( "atlamal_words_bytes",
            `Quick,
            run [ "-w"; "-c"; atlamal ] "atlamal.txt.wc.out" );
          ( "atlamal_words_lines",
            `Quick,
            run [ "-w"; "-l"; atlamal ] "atlamal.txt.wl.out" );
          ( "atlamal_bytes_lines",
            `Quick,
            run [ "-l"; "-c"; atlamal ] "atlamal.txt.cl.out" );
          ("atlamal_stdin", `Quick, run_stdin atlamal [] "atlamal.txt.stdin.out");
          ("test_all", `Quick, run [ empty; fox; atlamal ] "all.out");
          ( "test_all_lines",
            `Quick,
            run [ "-l"; empty; fox; atlamal ] "all.l.out" );
          ( "test_all_words",
            `Quick,
            run [ "-w"; empty; fox; atlamal ] "all.w.out" );
          ( "test_all_bytes",
            `Quick,
            run [ "-c"; empty; fox; atlamal ] "all.c.out" );
          ( "test_all_words_bytes",
            `Quick,
            run [ "-cw"; empty; fox; atlamal ] "all.wc.out" );
          ( "test_all_words_lines",
            `Quick,
            run [ "-wl"; empty; fox; atlamal ] "all.wl.out" );
          ( "test_all_bytes_lines",
            `Quick,
            run [ "-cl"; empty; fox; atlamal ] "all.cl.out" );
        ] );
    ]
