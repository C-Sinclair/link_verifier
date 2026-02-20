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
