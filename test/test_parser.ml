(* Parser and percent-decoding unit tests. *)
open Link_verifier_lib

let test_single_local_link () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "[some page](./other.md)"
  in
  Alcotest.(check int) "one link" 1 (List.length links);
  let link = List.hd links in
  Alcotest.(check string) "path" "./other.md" link.path;
  Alcotest.(check string) "source" "file.md" link.source_file;
  Alcotest.(check int) "line" 1 link.line

let test_ignores_http_links () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "[google](https://google.com)"
  in
  Alcotest.(check int) "no links" 0 (List.length links)

let test_ignores_http_no_s_links () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "[google](http://google.com)"
  in
  Alcotest.(check int) "no links" 0 (List.length links)

let test_multiple_links () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "[first](./a.md) some text [second](./b.md) more text \
       [external](https://example.com)"
  in
  Alcotest.(check int) "two links" 2 (List.length links);
  Alcotest.(check string) "first" "./a.md" (List.nth links 0).path;
  Alcotest.(check string) "second" "./b.md" (List.nth links 1).path

let test_empty_string () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md" ""
  in
  Alcotest.(check int) "no links" 0 (List.length links)

let test_no_links () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "just some plain text with no links"
  in
  Alcotest.(check int) "no links" 0 (List.length links)

let test_tracks_line_numbers () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "line one\n[link](./a.md)\nline three"
  in
  Alcotest.(check int) "one link" 1 (List.length links);
  Alcotest.(check int) "line 2" 2 (List.hd links).line

let test_balanced_parentheses () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "[sheet](files/Alembic (NEW).xlsx)"
  in
  Alcotest.(check int) "one link" 1 (List.length links);
  Alcotest.(check string) "path" "files/Alembic (NEW).xlsx" (List.hd links).path

let test_nested_parens_in_filename () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "[sheet](spreadsheets/Onboarding Sheet (1).xlsx)"
  in
  Alcotest.(check int) "one link" 1 (List.length links);
  Alcotest.(check string) "path" "spreadsheets/Onboarding Sheet (1).xlsx"
    (List.hd links).path

let test_ignores_mailto () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "[email](mailto:user@example.com)"
  in
  Alcotest.(check int) "no links" 0 (List.length links)

let test_ignores_tel () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "[call](tel:+1234567890)"
  in
  Alcotest.(check int) "no links" 0 (List.length links)

let test_strips_fragment () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "[section](./doc.md#heading)"
  in
  Alcotest.(check int) "one link" 1 (List.length links);
  Alcotest.(check string) "path" "./doc.md" (List.hd links).path

let test_ignores_bare_anchor () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "[section](#some-heading)"
  in
  Alcotest.(check int) "no links" 0 (List.length links)

let test_skips_fenced_code_block () =
  let links =
    Parser.parse_links_from_string ~skip_code:true ~source_file:"file.md"
      "```\n[link](./inside.md)\n```\n[link](./outside.md)"
  in
  Alcotest.(check int) "one link" 1 (List.length links);
  Alcotest.(check string) "path" "./outside.md" (List.hd links).path

let test_skips_fenced_code_block_with_lang () =
  let links =
    Parser.parse_links_from_string ~skip_code:true ~source_file:"file.md"
      "```markdown\n[link](./inside.md)\n```\n[link](./outside.md)"
  in
  Alcotest.(check int) "one link" 1 (List.length links);
  Alcotest.(check string) "path" "./outside.md" (List.hd links).path

let test_skips_inline_code () =
  let links =
    Parser.parse_links_from_string ~skip_code:true ~source_file:"file.md"
      "see `[link](./inline.md)` and [real](./real.md)"
  in
  Alcotest.(check int) "one link" 1 (List.length links);
  Alcotest.(check string) "path" "./real.md" (List.hd links).path

let test_skip_code_default_off () =
  let links =
    Parser.parse_links_from_string ~source_file:"file.md"
      "```\n[link](./inside.md)\n```"
  in
  Alcotest.(check int) "one link" 1 (List.length links)

let test_skips_tilde_fenced_code_block () =
  let links =
    Parser.parse_links_from_string ~skip_code:true ~source_file:"file.md"
      "~~~\n[link](./inside.md)\n~~~\n[link](./outside.md)"
  in
  Alcotest.(check int) "one link" 1 (List.length links);
  Alcotest.(check string) "path" "./outside.md" (List.hd links).path

let test_percent_decode_basic () =
  Alcotest.(check string)
    "decoded" "Scope Doc.md"
    (Resolver.percent_decode "Scope%20Doc.md")

let test_percent_decode_multiple () =
  Alcotest.(check string)
    "decoded" "a b c.md"
    (Resolver.percent_decode "a%20b%20c.md")

let test_percent_decode_parens () =
  Alcotest.(check string)
    "decoded" "file(name).md"
    (Resolver.percent_decode "file%28name%29.md")

let test_percent_decode_utf8_en_dash () =
  Alcotest.(check string)
    "decoded" "Plan \xe2\x80\x93 Draft.md"
    (Resolver.percent_decode "Plan%20%E2%80%93%20Draft.md")

let test_percent_decode_lowercase_hex () =
  Alcotest.(check string)
    "decoded" "Plan \xe2\x80\x93 Draft.md"
    (Resolver.percent_decode "Plan%20%e2%80%93%20Draft.md")

let test_percent_decode_malformed () =
  Alcotest.(check string)
    "decoded" "100%25 and %zz and %"
    (Resolver.percent_decode "100%2525 and %zz and %")

let test_percent_decode_no_encoding () =
  Alcotest.(check string)
    "decoded" "plain-file.md"
    (Resolver.percent_decode "plain-file.md")

let () =
  Alcotest.run "parser"
    [
      ( "parse_links",
        [
          Alcotest.test_case "single local link" `Quick test_single_local_link;
          Alcotest.test_case "ignores http" `Quick test_ignores_http_links;
          Alcotest.test_case "ignores http no s" `Quick
            test_ignores_http_no_s_links;
          Alcotest.test_case "multiple links" `Quick test_multiple_links;
          Alcotest.test_case "empty string" `Quick test_empty_string;
          Alcotest.test_case "no links" `Quick test_no_links;
          Alcotest.test_case "line numbers" `Quick test_tracks_line_numbers;
          Alcotest.test_case "balanced parens" `Quick test_balanced_parentheses;
          Alcotest.test_case "nested parens" `Quick
            test_nested_parens_in_filename;
          Alcotest.test_case "ignores mailto" `Quick test_ignores_mailto;
          Alcotest.test_case "ignores tel" `Quick test_ignores_tel;
          Alcotest.test_case "strips fragment" `Quick test_strips_fragment;
          Alcotest.test_case "bare anchor" `Quick test_ignores_bare_anchor;
          Alcotest.test_case "skips fenced code block" `Quick
            test_skips_fenced_code_block;
          Alcotest.test_case "skips fenced code with lang" `Quick
            test_skips_fenced_code_block_with_lang;
          Alcotest.test_case "skips inline code" `Quick test_skips_inline_code;
          Alcotest.test_case "skip_code default off" `Quick
            test_skip_code_default_off;
          Alcotest.test_case "skips tilde fence" `Quick
            test_skips_tilde_fenced_code_block;
        ] );
      ( "percent_decode",
        [
          Alcotest.test_case "basic" `Quick test_percent_decode_basic;
          Alcotest.test_case "multiple" `Quick test_percent_decode_multiple;
          Alcotest.test_case "parens" `Quick test_percent_decode_parens;
          Alcotest.test_case "no encoding" `Quick test_percent_decode_no_encoding;
          Alcotest.test_case "utf8 en dash" `Quick
            test_percent_decode_utf8_en_dash;
          Alcotest.test_case "lowercase hex" `Quick
            test_percent_decode_lowercase_hex;
          Alcotest.test_case "malformed" `Quick test_percent_decode_malformed;
        ] );
    ]
