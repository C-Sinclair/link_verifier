(* CLI integration tests. *)
let binary =
  let exe = Sys.executable_name in
  let test_dir = Filename.dirname exe in
  let build_dir = Filename.dirname test_dir in
  Filename.concat (Filename.concat build_dir "bin") "main.exe"

let with_tmp_dir f =
  let dir = Filename.temp_dir "lv_cli" "" in
  Fun.protect ~finally:(fun () ->
    ignore (Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote dir))))
    (fun () -> f dir)

let write_file path contents =
  let dir = Filename.dirname path in
  ignore (Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir)));
  let oc = open_out path in
  output_string oc contents;
  close_out oc

type result = { exit_code : int; stdout : string; stderr : string }

let run_cli args =
  let stdout_file = Filename.temp_file "lv_out" ".txt" in
  let stderr_file = Filename.temp_file "lv_err" ".txt" in
  let cmd =
    Printf.sprintf "%s %s >%s 2>%s" (Filename.quote binary)
      (String.concat " " (List.map Filename.quote args))
      (Filename.quote stdout_file)
      (Filename.quote stderr_file)
  in
  let exit_code = Sys.command cmd in
  let read_file path =
    let ic = open_in path in
    let s = In_channel.input_all ic in
    close_in ic;
    Sys.remove path;
    s
  in
  let stdout = read_file stdout_file in
  let stderr = read_file stderr_file in
  { exit_code; stdout; stderr }

let contains haystack needle =
  let re = Re.compile (Re.str needle) in
  Re.execp re haystack

let test_no_args_returns_usage_error () =
  let r = run_cli [] in
  Alcotest.(check int) "exit 1" 1 r.exit_code;
  Alcotest.(check bool) "has usage" true (contains r.stderr "usage: link_verifier")

let test_help_flag () =
  let r = run_cli [ "--help" ] in
  Alcotest.(check int) "exit 0" 0 r.exit_code;
  Alcotest.(check bool) "has usage" true (contains r.stdout "link_verifier")

let test_version_flag () =
  let r = run_cli [ "--version" ] in
  Alcotest.(check int) "exit 0" 0 r.exit_code;
  Alcotest.(check bool) "has version" true (contains r.stdout "0.3.0")

let test_multiple_file_targets () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "existing.md") "ok";
    write_file (Filename.concat dir "a.md") "[ok](existing.md)";
    write_file (Filename.concat dir "b.md") "[bad](missing.md)";
    let r =
      run_cli [ Filename.concat dir "a.md"; Filename.concat dir "b.md" ]
    in
    Alcotest.(check int) "exit 2" 2 r.exit_code;
    Alcotest.(check bool) "broken link" true (contains r.stderr "broken link"))

let test_directory_target () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "one.md") "[bad](missing.md)";
    let r = run_cli [ dir ] in
    Alcotest.(check int) "exit 2" 2 r.exit_code;
    Alcotest.(check bool) "broken link" true (contains r.stderr "broken link"))

let test_skips_mailto () =
  with_tmp_dir (fun dir ->
    write_file
      (Filename.concat dir "contacts.md")
      "[email](mailto:user@example.com)";
    let r = run_cli [ Filename.concat dir "contacts.md" ] in
    Alcotest.(check int) "exit 0" 0 r.exit_code)

let test_skips_anchor () =
  with_tmp_dir (fun dir ->
    write_file
      (Filename.concat dir "toc.md")
      "[section](#overview)\n[other](#details)";
    let r = run_cli [ Filename.concat dir "toc.md" ] in
    Alcotest.(check int) "exit 0" 0 r.exit_code)

let test_directory_links () =
  with_tmp_dir (fun dir ->
    let sub = Filename.concat dir "assessment" in
    ignore (Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote sub)));
    write_file (Filename.concat dir "readme.md") "[assessment](assessment/)";
    let r = run_cli [ Filename.concat dir "readme.md" ] in
    Alcotest.(check int) "exit 0" 0 r.exit_code)

let test_deduplicates_targets () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "dup.md") "[missing](gone.md)";
    let target = Filename.concat dir "dup.md" in
    let r = run_cli [ target; target ] in
    Alcotest.(check int) "exit 2" 2 r.exit_code;
    Alcotest.(check bool) "1 broken" true
      (contains r.stderr "1 broken link in 1 file"))

let test_summary_line () =
  with_tmp_dir (fun dir ->
    write_file
      (Filename.concat dir "one.md")
      "[a](missing-a.md)\n[b](missing-b.md)";
    write_file (Filename.concat dir "two.md") "[c](missing-c.md)";
    let r =
      run_cli [ Filename.concat dir "one.md"; Filename.concat dir "two.md" ]
    in
    Alcotest.(check int) "exit 2" 2 r.exit_code;
    Alcotest.(check bool) "3 broken" true
      (contains r.stderr "3 broken links in 2 files"))

let test_summary_singular () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "solo.md") "[x](nope.md)";
    let r = run_cli [ Filename.concat dir "solo.md" ] in
    Alcotest.(check int) "exit 2" 2 r.exit_code;
    Alcotest.(check bool) "1 broken" true
      (contains r.stderr "1 broken link in 1 file"))

let test_except_excludes () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "keep.md") "[bad](missing.md)";
    write_file (Filename.concat dir "skip.md") "[bad](also-missing.md)";
    let r = run_cli [ dir; "-x"; "skip" ] in
    Alcotest.(check int) "exit 2" 2 r.exit_code;
    Alcotest.(check bool) "has keep" true (contains r.stderr "keep.md");
    Alcotest.(check bool) "no skip" false (contains r.stderr "skip.md"))

let test_except_long_flag () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "include.md") "[bad](missing.md)";
    write_file (Filename.concat dir "exclude.md") "[bad](also-missing.md)";
    let r = run_cli [ dir; "--except"; "exclude" ] in
    Alcotest.(check int) "exit 2" 2 r.exit_code;
    Alcotest.(check bool) "has include" true (contains r.stderr "include.md");
    Alcotest.(check bool) "no exclude" false (contains r.stderr "exclude.md"))

let test_except_multiple () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "a.md") "[x](missing.md)";
    write_file (Filename.concat dir "b.md") "[x](missing.md)";
    write_file (Filename.concat dir "c.md") "[x](missing.md)";
    let r = run_cli [ dir; "-x"; "/a\\.md$"; "-x"; "/b\\.md$" ] in
    Alcotest.(check int) "exit 2" 2 r.exit_code;
    Alcotest.(check bool) "has c" true (contains r.stderr "c.md");
    Alcotest.(check bool) "no a" false (contains r.stderr "a.md");
    Alcotest.(check bool) "no b" false (contains r.stderr "b.md"))

let test_except_all_excluded () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "only.md") "[x](missing.md)";
    let r = run_cli [ Filename.concat dir "only.md"; "-x"; "only" ] in
    Alcotest.(check int) "exit 0" 0 r.exit_code)

let test_except_regex () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "vendor/lib.md") "[x](missing.md)";
    write_file (Filename.concat dir "app.md") "[x](missing.md)";
    let r = run_cli [ dir; "-x"; "vendor/" ] in
    Alcotest.(check int) "exit 2" 2 r.exit_code;
    Alcotest.(check bool) "has app" true (contains r.stderr "app.md");
    Alcotest.(check bool) "no vendor" false (contains r.stderr "vendor"))

let () =
  Alcotest.run "cli"
    [
      ( "cli",
        [
          Alcotest.test_case "no args" `Quick test_no_args_returns_usage_error;
          Alcotest.test_case "help" `Quick test_help_flag;
          Alcotest.test_case "version" `Quick test_version_flag;
          Alcotest.test_case "multiple targets" `Quick
            test_multiple_file_targets;
          Alcotest.test_case "directory target" `Quick test_directory_target;
          Alcotest.test_case "skips mailto" `Quick test_skips_mailto;
          Alcotest.test_case "skips anchor" `Quick test_skips_anchor;
          Alcotest.test_case "directory links" `Quick test_directory_links;
          Alcotest.test_case "deduplicates" `Quick test_deduplicates_targets;
          Alcotest.test_case "summary line" `Quick test_summary_line;
          Alcotest.test_case "summary singular" `Quick test_summary_singular;
          Alcotest.test_case "except excludes" `Quick test_except_excludes;
          Alcotest.test_case "except long" `Quick test_except_long_flag;
          Alcotest.test_case "except multiple" `Quick test_except_multiple;
          Alcotest.test_case "except all excluded" `Quick
            test_except_all_excluded;
          Alcotest.test_case "except regex" `Quick test_except_regex;
        ] );
    ]
