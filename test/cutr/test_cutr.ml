(* Integration tests for cutr — port of test-harness/tests/cutr/cli.rs *)

let bin = Cli_test.bin_from_env "CUTR_BIN"

let csv = "inputs/movies1.csv"
let tsv = "inputs/movies1.tsv"
let books = "inputs/books.tsv"

let skips_bad_file () =
  let bad = Cli_test.gen_bad_file () in
  Cli_test.stderr_matches ~bin ~args:[ "-f"; "1"; csv; bad; tsv ]
    ~check:(fun ~stdout:_ ~stderr ~status ->
      (match status with
      | `Exited 0 -> ()
      | s -> Alcotest.failf "expected exit 0, got %a" Bos.OS.Cmd.pp_status s);
      Alcotest.(check bool) "stderr mentions missing file" true
        (Cli_test.contains ~affix:(bad ^ ":") stderr
        && Cli_test.contains ~affix:"No such file or directory" stderr))
    ()

let dies ~args ~stderr_contains () =
  Cli_test.dies ~bin ~args ~stderr_contains ()

let dies_not_enough_args () =
  dies ~args:[ csv ] ~stderr_contains:"Must have --fields, --bytes, or --chars"
    ()

let dies_bad_digit_field () =
  let bad = Cli_test.random_string () in
  dies ~args:[ csv; "-f"; bad ]
    ~stderr_contains:(Printf.sprintf "illegal list value: \"%s\"" bad)
    ()

let dies_bad_digit_bytes () =
  let bad = Cli_test.random_string () in
  dies ~args:[ csv; "-b"; bad ]
    ~stderr_contains:(Printf.sprintf "illegal list value: \"%s\"" bad)
    ()

let dies_bad_digit_chars () =
  let bad = Cli_test.random_string () in
  dies ~args:[ csv; "-c"; bad ]
    ~stderr_contains:(Printf.sprintf "illegal list value: \"%s\"" bad)
    ()

let dies_empty_delimiter () =
  dies ~args:[ csv; "-f"; "1"; "-d"; "" ]
    ~stderr_contains:"--delim \"\" must be a single byte"
    ()

let dies_bad_delimiter () =
  dies ~args:[ csv; "-f"; "1"; "-d"; ",," ]
    ~stderr_contains:"--delim \",,\" must be a single byte"
    ()

let dies_chars_bytes_fields () =
  Cli_test.dies ~bin ~args:[ csv; "-c"; "1"; "-f"; "1"; "-b"; "1" ] ()

let dies_bytes_fields () =
  Cli_test.dies ~bin ~args:[ csv; "-f"; "1"; "-b"; "1" ] ()

let dies_chars_fields () =
  Cli_test.dies ~bin ~args:[ csv; "-c"; "1"; "-f"; "1" ] ()

let dies_chars_bytes () =
  Cli_test.dies ~bin ~args:[ csv; "-c"; "1"; "-b"; "1" ] ()

let run args expected = Cli_test.run_success ~bin args expected

(* run_lossy in Rust uses from_utf8_lossy; OCaml strings are bytes — same as run. *)
let run_lossy = run

let () =
  Alcotest.run "cutr"
    [
      ( "cli",
        [
          ("skips_bad_file", `Quick, skips_bad_file);
          ("dies_not_enough_args", `Quick, dies_not_enough_args);
          ("dies_bad_digit_field", `Quick, dies_bad_digit_field);
          ("dies_bad_digit_bytes", `Quick, dies_bad_digit_bytes);
          ("dies_bad_digit_chars", `Quick, dies_bad_digit_chars);
          ("dies_empty_delimiter", `Quick, dies_empty_delimiter);
          ("dies_bad_delimiter", `Quick, dies_bad_delimiter);
          ("dies_chars_bytes_fields", `Quick, dies_chars_bytes_fields);
          ("dies_bytes_fields", `Quick, dies_bytes_fields);
          ("dies_chars_fields", `Quick, dies_chars_fields);
          ("dies_chars_bytes", `Quick, dies_chars_bytes);
          ("tsv_f1", `Quick, run [ tsv; "-f"; "1" ] "movies1.tsv.f1.out");
          ("tsv_f2", `Quick, run [ tsv; "-f"; "2" ] "movies1.tsv.f2.out");
          ("tsv_f3", `Quick, run [ tsv; "-f"; "3" ] "movies1.tsv.f3.out");
          ("tsv_f1_2", `Quick, run [ tsv; "-f"; "1-2" ] "movies1.tsv.f1-2.out");
          ("tsv_f2_3", `Quick, run [ tsv; "-f"; "2-3" ] "movies1.tsv.f2-3.out");
          ("tsv_f1_3", `Quick, run [ tsv; "-f"; "1-3" ] "movies1.tsv.f1-3.out");
          ( "csv_f1",
            `Quick,
            run [ csv; "-f"; "1"; "-d"; "," ] "movies1.csv.f1.dcomma.out" );
          ( "csv_f2",
            `Quick,
            run [ csv; "-f"; "2"; "-d"; "," ] "movies1.csv.f2.dcomma.out" );
          ( "csv_f3",
            `Quick,
            run [ csv; "-f"; "3"; "-d"; "," ] "movies1.csv.f3.dcomma.out" );
          ( "csv_f1_2",
            `Quick,
            run [ csv; "-f"; "1-2"; "-d"; "," ] "movies1.csv.f1-2.dcomma.out" );
          ( "csv_f2_3",
            `Quick,
            run [ csv; "-f"; "2-3"; "-d"; "," ] "movies1.csv.f2-3.dcomma.out" );
          ( "csv_f1_3",
            `Quick,
            run [ csv; "-f"; "1-3"; "-d"; "," ] "movies1.csv.f1-3.dcomma.out" );
          ("tsv_b1", `Quick, run [ tsv; "-b"; "1" ] "movies1.tsv.b1.out");
          ("tsv_b2", `Quick, run [ tsv; "-b"; "2" ] "movies1.tsv.b2.out");
          ("tsv_b8", `Quick, run_lossy [ tsv; "-b"; "8" ] "movies1.tsv.b8.out");
          ("tsv_b1_2", `Quick, run [ tsv; "-b"; "1-2" ] "movies1.tsv.b1-2.out");
          ("tsv_b2_3", `Quick, run [ tsv; "-b"; "2-3" ] "movies1.tsv.b2-3.out");
          ( "tsv_b1_8",
            `Quick,
            run_lossy [ tsv; "-b"; "1-8" ] "movies1.tsv.b1-8.out" );
          ("tsv_c1", `Quick, run [ tsv; "-c"; "1" ] "movies1.tsv.c1.out");
          ("tsv_c2", `Quick, run [ tsv; "-c"; "2" ] "movies1.tsv.c2.out");
          ("tsv_c8", `Quick, run [ tsv; "-c"; "8" ] "movies1.tsv.c8.out");
          ("tsv_c1_2", `Quick, run [ tsv; "-c"; "1-2" ] "movies1.tsv.c1-2.out");
          ("tsv_c2_3", `Quick, run [ tsv; "-c"; "2-3" ] "movies1.tsv.c2-3.out");
          ("tsv_c1_8", `Quick, run [ tsv; "-c"; "1-8" ] "movies1.tsv.c1-8.out");
          ("repeated_value", `Quick, run [ books; "-c"; "1,1" ] "books.c1,1.out");
        ] );
    ]
