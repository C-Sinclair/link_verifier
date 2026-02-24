import gleeunit/should
import link_verifier/parser.{Link}

pub fn parse_links_from_string_single_local_link_test() {
  parser.parse_links_from_string("file.md", "[some page](./other.md)")
  |> should.equal([Link(source_file: "file.md", line: 1, path: "./other.md")])
}

pub fn parse_links_from_string_ignores_http_links_test() {
  parser.parse_links_from_string("file.md", "[google](https://google.com)")
  |> should.equal([])
}

pub fn parse_links_from_string_ignores_http_no_s_links_test() {
  parser.parse_links_from_string("file.md", "[google](http://google.com)")
  |> should.equal([])
}

pub fn parse_links_from_string_multiple_links_test() {
  let content =
    "[first](./a.md) some text [second](./b.md) more text [external](https://example.com)"
  parser.parse_links_from_string("file.md", content)
  |> should.equal([
    Link(source_file: "file.md", line: 1, path: "./a.md"),
    Link(source_file: "file.md", line: 1, path: "./b.md"),
  ])
}

pub fn parse_links_from_string_empty_string_test() {
  parser.parse_links_from_string("file.md", "")
  |> should.equal([])
}

pub fn parse_links_from_string_no_links_test() {
  parser.parse_links_from_string("file.md", "just some plain text with no links")
  |> should.equal([])
}

pub fn parse_links_from_string_tracks_line_numbers_test() {
  let content = "line one\n[link](./a.md)\nline three"
  parser.parse_links_from_string("file.md", content)
  |> should.equal([Link(source_file: "file.md", line: 2, path: "./a.md")])
}

pub fn parse_links_handles_balanced_parentheses_test() {
  parser.parse_links_from_string(
    "file.md",
    "[sheet](files/Alembic (NEW).xlsx)",
  )
  |> should.equal([
    Link(source_file: "file.md", line: 1, path: "files/Alembic (NEW).xlsx"),
  ])
}

pub fn parse_links_handles_nested_parens_in_filename_test() {
  parser.parse_links_from_string(
    "file.md",
    "[sheet](spreadsheets/Onboarding Sheet (1).xlsx)",
  )
  |> should.equal([
    Link(
      source_file: "file.md",
      line: 1,
      path: "spreadsheets/Onboarding Sheet (1).xlsx",
    ),
  ])
}

pub fn parse_links_ignores_mailto_test() {
  parser.parse_links_from_string("file.md", "[email](mailto:user@example.com)")
  |> should.equal([])
}

pub fn parse_links_ignores_tel_test() {
  parser.parse_links_from_string("file.md", "[call](tel:+1234567890)")
  |> should.equal([])
}

pub fn parse_links_strips_fragment_test() {
  parser.parse_links_from_string("file.md", "[section](./doc.md#heading)")
  |> should.equal([
    Link(source_file: "file.md", line: 1, path: "./doc.md"),
  ])
}

pub fn parse_links_ignores_bare_anchor_test() {
  parser.parse_links_from_string("file.md", "[section](#some-heading)")
  |> should.equal([])
}

pub fn percent_decode_basic_test() {
  parser.percent_decode("Scope%20Doc.md")
  |> should.equal("Scope Doc.md")
}

pub fn percent_decode_multiple_test() {
  parser.percent_decode("a%20b%20c.md")
  |> should.equal("a b c.md")
}

pub fn percent_decode_parens_test() {
  parser.percent_decode("file%28name%29.md")
  |> should.equal("file(name).md")
}

pub fn percent_decode_no_encoding_test() {
  parser.percent_decode("plain-file.md")
  |> should.equal("plain-file.md")
}
