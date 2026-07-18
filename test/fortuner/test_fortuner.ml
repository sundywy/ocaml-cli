(* Integration tests for fortuner — port of test-harness/tests/fortuner/cli.rs *)

open Bos

let fortuner_bin =
  match Sys.getenv_opt "FORTUNER_BIN" with
  | Some p -> p
  | None -> "fortuner"

let fortune_dir = "./inputs"
let empty_dir = "./inputs/empty"
let jokes = "./inputs/jokes"
let literature = "./inputs/literature"
let quotes = "./inputs/quotes"

let fortuner args = Cmd.(v fortuner_bin %% of_list args)

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

let run_out ~err cmd =
  let err = Option.value err ~default:OS.Cmd.err_stderr in
  OS.Cmd.run_out ~err cmd

let run args expected () =
  let cmd = fortuner args in
  match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout" expected stdout
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let run_outfiles args out_file err_file () =
  let expected_out = read_expected out_file in
  let expected_err = read_expected err_file in
  let err_path = Fpath.v (Filename.temp_file "fortuner" "err") in
  let cmd = fortuner args in
  match
    OS.Cmd.out_string ~trim:false
      (run_out ~err:(Some (OS.Cmd.err_file err_path)) cmd)
  with
  | Ok (stdout, (_, `Exited 0)) -> (
      Alcotest.(check string) "stdout" expected_out stdout;
      match OS.File.read err_path with
      | Ok stderr -> Alcotest.(check string) "stderr" expected_err stderr
      | Error (`Msg m) -> Alcotest.fail m)
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let dies ~args ~stderr_contains () =
  let err_path = Fpath.v (Filename.temp_file "fortuner" "err") in
  let cmd = fortuner args in
  match
    OS.Cmd.out_string ~trim:false
      (run_out ~err:(Some (OS.Cmd.err_file err_path)) cmd)
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

let dies_bad_file () =
  let bad = gen_bad_file () in
  let err_path = Fpath.v (Filename.temp_file "fortuner" "err") in
  let cmd = fortuner [ literature; bad ] in
  match
    OS.Cmd.out_string ~trim:false
      (run_out ~err:(Some (OS.Cmd.err_file err_path)) cmd)
  with
  | Ok (_, (_, `Exited 0)) -> Alcotest.fail "expected non-zero exit"
  | Ok (_, _) -> (
      match OS.File.read err_path with
      | Ok stderr ->
          (* Rust: "{}: .* [(]os error 2[)]" *)
          Alcotest.(check bool) "stderr mentions bad file" true
            (contains ~affix:(bad ^ ":") stderr
            && contains ~affix:"(os error 2)" stderr)
      | Error (`Msg m) -> Alcotest.fail m)
  | Error (`Msg m) -> Alcotest.fail m

let dies_bad_seed () =
  let bad = random_string () in
  dies
    ~args:[ literature; "--seed"; bad ]
    ~stderr_contains:(Printf.sprintf "\"%s\" not a valid integer" bad)
    ()

let () =
  Alcotest.run "fortuner"
    [
      ( "cli",
        [
          ("dies_bad_file", `Quick, dies_bad_file);
          ("dies_bad_seed", `Quick, dies_bad_seed);
          ("no_fortunes_found", `Quick, run [ empty_dir ] "No fortunes found\n");
          ( "quotes_seed_1",
            `Quick,
            run [ quotes; "-s"; "1" ]
              "You can observe a lot just by watching.\n-- Yogi Berra\n" );
          ( "jokes_seed_1",
            `Quick,
            run [ jokes; "-s"; "1" ]
              "Q: What happens when frogs park illegally?\nA: They get toad.\n"
          );
          ( "dir_seed_10",
            `Quick,
            run [ fortune_dir; "-s"; "10" ]
              "Q: Why did the fungus and the alga marry?\n\
               A: Because they took a lichen to each other!\n" );
          ( "yogi_berra_cap",
            `Quick,
            run_outfiles
              [ "--pattern"; "Yogi Berra"; fortune_dir ]
              "berra_cap.out" "berra_cap.err" );
          ( "mark_twain_cap",
            `Quick,
            run_outfiles
              [ "-m"; "Mark Twain"; fortune_dir ]
              "twain_cap.out" "twain_cap.err" );
          ( "yogi_berra_lower",
            `Quick,
            run_outfiles
              [ "--pattern"; "yogi berra"; fortune_dir ]
              "berra_lower.out" "berra_lower.err" );
          ( "mark_twain_lower",
            `Quick,
            run_outfiles
              [ "-m"; "will twain"; fortune_dir ]
              "twain_lower.out" "twain_lower.err" );
          ( "yogi_berra_lower_i",
            `Quick,
            run_outfiles
              [ "--insensitive"; "--pattern"; "yogi berra"; fortune_dir ]
              "berra_lower_i.out" "berra_lower_i.err" );
          ( "mark_twain_lower_i",
            `Quick,
            run_outfiles
              [ "-i"; "-m"; "mark twain"; fortune_dir ]
              "twain_lower_i.out" "twain_lower_i.err" );
        ] );
    ]
