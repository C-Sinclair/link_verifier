(* Resolver unit tests. *)
open Link_verifier_lib

let with_tmp_dir f =
  let dir = Filename.temp_dir "lv_test" "" in
  Fun.protect ~finally:(fun () ->
    ignore (Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote dir))))
    (fun () -> f dir)

let write_file path contents =
  let dir = Filename.dirname path in
  ignore (Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir)));
  let oc = open_out path in
  output_string oc contents;
  close_out oc

let test_resolve_relative () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "sibling.md") "ok";
    let source = Filename.concat dir "index.md" in
    write_file source "[link](sibling.md)";
    let links = Parser.parse_file_for_links source in
    let missing = Resolver.find_missing_files links in
    Alcotest.(check int) "no missing" 0 (List.length missing))

let test_resolve_parent_dir () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "root.md") "ok";
    let sub = Filename.concat dir "sub" in
    let source = Filename.concat sub "child.md" in
    write_file source "[up](../root.md)";
    let links = Parser.parse_file_for_links source in
    let missing = Resolver.find_missing_files links in
    Alcotest.(check int) "no missing" 0 (List.length missing))

let test_missing_file () =
  with_tmp_dir (fun dir ->
    let source = Filename.concat dir "index.md" in
    write_file source "[bad](missing.md)";
    let links = Parser.parse_file_for_links source in
    let missing = Resolver.find_missing_files links in
    Alcotest.(check int) "one missing" 1 (List.length missing);
    Alcotest.(check string) "path" "missing.md" (List.hd missing).path)

let test_percent_encoded_spaces () =
  with_tmp_dir (fun dir ->
    write_file (Filename.concat dir "Scope Doc.md") "ok";
    let source = Filename.concat dir "index.md" in
    write_file source "[scope](Scope%20Doc.md)";
    let links = Parser.parse_file_for_links source in
    let missing = Resolver.find_missing_files links in
    Alcotest.(check int) "no missing" 0 (List.length missing))

let test_directory_link () =
  with_tmp_dir (fun dir ->
    let sub = Filename.concat dir "assessment" in
    ignore (Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote sub)));
    let source = Filename.concat dir "readme.md" in
    write_file source "[assessment](assessment/)";
    let links = Parser.parse_file_for_links source in
    let missing = Resolver.find_missing_files links in
    Alcotest.(check int) "no missing" 0 (List.length missing))

let () =
  Alcotest.run "resolver"
    [
      ( "resolve",
        [
          Alcotest.test_case "relative" `Quick test_resolve_relative;
          Alcotest.test_case "parent dir" `Quick test_resolve_parent_dir;
          Alcotest.test_case "missing" `Quick test_missing_file;
          Alcotest.test_case "percent encoded" `Quick
            test_percent_encoded_spaces;
          Alcotest.test_case "directory link" `Quick test_directory_link;
        ] );
    ]
