(* Integration tests for lsr — port of test-harness/tests/lsr/cli.rs *)

open Bos

let lsr_bin =
  match Sys.getenv_opt "LSR_BIN" with
  | Some p -> p
  | None -> "lsr"

let hidden = "inputs/.hidden"
let empty = "inputs/empty.txt"
let bustle = "inputs/bustle.txt"
let fox = "inputs/fox.txt"

let lsr_cmd args = Cmd.(v lsr_bin %% of_list args)

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

(* set-test-perms: dir 755, fox.txt 600, others 644 *)
let set_test_perms () =
  let chmod path mode =
    try Unix.chmod path mode
    with Unix.Unix_error (e, _, _) ->
      Alcotest.failf "chmod %s: %s" path (Unix.error_message e)
  in
  chmod "inputs/dir" 0o755;
  chmod "inputs/fox.txt" 0o600;
  List.iter
    (fun p -> chmod p 0o644)
    [
      "inputs/.hidden";
      "inputs/empty.txt";
      "inputs/bustle.txt";
      "inputs/dir/.gitkeep";
      "inputs/dir/spiders.txt";
    ]

let () = set_test_perms ()

let run_out ~err cmd =
  let err = Option.value err ~default:OS.Cmd.err_stderr in
  OS.Cmd.run_out ~err cmd

let bad_file () =
  let bad = gen_bad_file () in
  let expected =
    Printf.sprintf "%s: No such file or directory (os error 2)" bad
  in
  let err_path = Fpath.v (Filename.temp_file "lsr" "err") in
  let cmd = lsr_cmd [ bad ] in
  match
    OS.Cmd.out_string ~trim:false
      (run_out ~err:(Some (OS.Cmd.err_file err_path)) cmd)
  with
  | Ok (_, (_, `Exited 0)) -> (
      match OS.File.read err_path with
      | Ok stderr ->
          Alcotest.(check bool) "stderr contains" true
            (contains ~affix:expected stderr)
      | Error (`Msg m) -> Alcotest.fail m)
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let no_args () =
  let cmd = lsr_cmd [] in
  match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check bool) "stdout contains Cargo.toml" true
        (contains ~affix:"Cargo.toml" stdout)
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let run_short arg () =
  let cmd = lsr_cmd [ arg ] in
  match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      Alcotest.(check string) "stdout" (arg ^ "\n") stdout
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let split_whitespace s =
  let buf = Buffer.create 64 in
  let flush acc =
    if Buffer.length buf = 0 then acc
    else
      let t = Buffer.contents buf in
      Buffer.clear buf;
      t :: acc
  in
  let acc = ref [] in
  String.iter
    (fun c ->
      if c = ' ' || c = '\t' || c = '\n' || c = '\r' then acc := flush !acc
      else Buffer.add_char buf c)
    s;
  List.rev (flush !acc)

let run_long filename permissions size () =
  let cmd = lsr_cmd [ "--long"; filename ] in
  match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      let parts = split_whitespace stdout in
      (match parts with
      | p0 :: _ -> Alcotest.(check string) "permissions" permissions p0
      | [] -> Alcotest.fail "empty output");
      (match List.nth_opt parts 4 with
      | Some s -> Alcotest.(check string) "size" size s
      | None -> Alcotest.fail "missing size field");
      (match List.rev parts with
      | last :: _ -> Alcotest.(check string) "path" filename last
      | [] -> Alcotest.fail "empty parts")
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let dir_short args expected () =
  let cmd = lsr_cmd args in
  match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      let lines =
        stdout |> String.split_on_char '\n' |> List.filter (fun s -> s <> "")
      in
      Alcotest.(check int) "line count" (List.length expected) (List.length lines);
      List.iter
        (fun filename ->
          Alcotest.(check bool)
            (Printf.sprintf "contains %s" filename)
            true
            (List.mem filename lines))
        expected
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let dir_long args expected () =
  let cmd = lsr_cmd args in
  match OS.Cmd.out_string ~trim:false (run_out ~err:None cmd) with
  | Ok (stdout, (_, `Exited 0)) ->
      let lines =
        stdout |> String.split_on_char '\n' |> List.filter (fun s -> s <> "")
      in
      Alcotest.(check int) "line count" (List.length expected) (List.length lines);
      let check =
        List.map
          (fun line ->
            let parts = split_whitespace line in
            let path = List.hd (List.rev parts) in
            let permissions = List.hd parts in
            let size =
              match permissions.[0] with
              | 'd' -> ""
              | _ -> List.nth parts 4
            in
            (path, permissions, size))
          lines
      in
      List.iter
        (fun entry ->
          Alcotest.(check bool)
            (Printf.sprintf "contains %s" (let p, _, _ = entry in p))
            true (List.mem entry check))
        expected
  | Ok (_, (_, status)) ->
      Alcotest.failf "expected exit 0, got %a" OS.Cmd.pp_status status
  | Error (`Msg m) -> Alcotest.fail m

let () =
  Alcotest.run "lsr"
    [
      ( "cli",
        [
          ("bad_file", `Quick, bad_file);
          ("no_args", `Quick, no_args);
          ("empty", `Quick, run_short empty);
          ("empty_long", `Quick, run_long empty "-rw-r--r--" "0");
          ("bustle", `Quick, run_short bustle);
          ("bustle_long", `Quick, run_long bustle "-rw-r--r--" "193");
          ("fox", `Quick, run_short fox);
          ("fox_long", `Quick, run_long fox "-rw-------" "45");
          ("hidden", `Quick, run_short hidden);
          ("hidden_long", `Quick, run_long hidden "-rw-r--r--" "0");
          ( "dir1",
            `Quick,
            dir_short [ "inputs" ]
              [
                "inputs/empty.txt";
                "inputs/bustle.txt";
                "inputs/fox.txt";
                "inputs/dir";
              ] );
          ( "dir1_all",
            `Quick,
            dir_short [ "inputs"; "--all" ]
              [
                "inputs/empty.txt";
                "inputs/bustle.txt";
                "inputs/fox.txt";
                "inputs/.hidden";
                "inputs/dir";
              ] );
          ( "dir2",
            `Quick,
            dir_short [ "inputs/dir" ] [ "inputs/dir/spiders.txt" ] );
          ( "dir2_all",
            `Quick,
            dir_short [ "-a"; "inputs/dir" ]
              [ "inputs/dir/spiders.txt"; "inputs/dir/.gitkeep" ] );
          ( "dir1_long",
            `Quick,
            dir_long [ "-l"; "inputs" ]
              [
                ("inputs/empty.txt", "-rw-r--r--", "0");
                ("inputs/bustle.txt", "-rw-r--r--", "193");
                ("inputs/fox.txt", "-rw-------", "45");
                ("inputs/dir", "drwxr-xr-x", "");
              ] );
          ( "dir1_long_all",
            `Quick,
            dir_long [ "-la"; "inputs" ]
              [
                ("inputs/empty.txt", "-rw-r--r--", "0");
                ("inputs/bustle.txt", "-rw-r--r--", "193");
                ("inputs/fox.txt", "-rw-------", "45");
                ("inputs/dir", "drwxr-xr-x", "");
                ("inputs/.hidden", "-rw-r--r--", "0");
              ] );
          ( "dir2_long",
            `Quick,
            dir_long [ "--long"; "inputs/dir" ]
              [ ("inputs/dir/spiders.txt", "-rw-r--r--", "45") ] );
          ( "dir2_long_all",
            `Quick,
            dir_long
              [ "inputs/dir"; "--long"; "--all" ]
              [
                ("inputs/dir/spiders.txt", "-rw-r--r--", "45");
                ("inputs/dir/.gitkeep", "-rw-r--r--", "0");
              ] );
        ] );
    ]
