(* Backlink graph tests. *)
open Link_verifier_lib
let link source_file line path = { Parser.source_file; line; path }

let test_reciprocal_pair_passes () =
  let missing =
    Backlinks.find_missing
      [ ("a.md", [ link "a.md" 1 "b.md" ]); ("b.md", [ link "b.md" 1 "a.md" ]) ]
  in
  Alcotest.(check int) "none missing" 0 (List.length missing)

let test_one_way_link_reported () =
  let missing =
    Backlinks.find_missing
      [ ("a.md", [ link "a.md" 3 "b.md" ]); ("b.md", []) ]
  in
  Alcotest.(check int) "one missing" 1 (List.length missing);
  Alcotest.(check string) "target" "b.md" (List.hd missing).Backlinks.target;
  Alcotest.(check int) "line" 3 (List.hd missing).Backlinks.link.Parser.line

let test_unscanned_target_skipped () =
  let missing =
    Backlinks.find_missing [ ("a.md", [ link "a.md" 1 "../outside.md" ]) ]
  in
  Alcotest.(check int) "none missing" 0 (List.length missing)

let test_self_link_skipped () =
  let missing =
    Backlinks.find_missing [ ("a.md", [ link "a.md" 1 "a.md" ]) ]
  in
  Alcotest.(check int) "none missing" 0 (List.length missing)

(* The reciprocal link is spelled with a "..", so the graph only joins the
   two nodes if keys are normalized. *)
let test_parent_dir_link_is_reciprocal () =
  let missing =
    Backlinks.find_missing
      [ ("docs/a.md", [ link "docs/a.md" 1 "sub/b.md" ]);
        ("docs/sub/b.md", [ link "docs/sub/b.md" 1 "../a.md" ]) ]
  in
  Alcotest.(check int) "none missing" 0 (List.length missing)

let test_dot_slash_link_is_reciprocal () =
  let missing =
    Backlinks.find_missing
      [ ("./a.md", [ link "./a.md" 1 "./b.md" ]);
        ("b.md", [ link "b.md" 1 "./a.md" ]) ]
  in
  Alcotest.(check int) "none missing" 0 (List.length missing)

let test_normalize_path () =
  Alcotest.(check string) "parent" "docs/a.md"
    (Resolver.normalize_path "docs/sub/../a.md");
  Alcotest.(check string) "dot" "a.md" (Resolver.normalize_path "./a.md");
  Alcotest.(check string) "absolute" "/a/b.md"
    (Resolver.normalize_path "/a/c/../b.md");
  Alcotest.(check string) "leading parent" "../a.md"
    (Resolver.normalize_path "../a.md");
  Alcotest.(check string) "above root" "/a.md"
    (Resolver.normalize_path "/../a.md");
  Alcotest.(check string) "empty" "." (Resolver.normalize_path "")

let () =
  Alcotest.run "backlinks"
    [ ( "find_missing",
        [ Alcotest.test_case "reciprocal pair" `Quick
            test_reciprocal_pair_passes;
          Alcotest.test_case "one-way reported" `Quick
            test_one_way_link_reported;
          Alcotest.test_case "unscanned target skipped" `Quick
            test_unscanned_target_skipped;
          Alcotest.test_case "self link skipped" `Quick test_self_link_skipped;
          Alcotest.test_case "parent dir reciprocal" `Quick
            test_parent_dir_link_is_reciprocal;
          Alcotest.test_case "dot slash reciprocal" `Quick
            test_dot_slash_link_is_reciprocal ] );
      ("normalize", [ Alcotest.test_case "segments" `Quick test_normalize_path ])
    ]
