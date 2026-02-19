import gleeunit/should
import link_verifier/parser

pub fn parse_links_from_string_single_local_link_test() {
  parser.parse_links_from_string("[some page](./other.md)")
  |> should.equal(["./other.md"])
}

pub fn parse_links_from_string_ignores_http_links_test() {
  parser.parse_links_from_string("[google](https://google.com)")
  |> should.equal([])
}

pub fn parse_links_from_string_ignores_http_no_s_links_test() {
  parser.parse_links_from_string("[google](http://google.com)")
  |> should.equal([])
}

pub fn parse_links_from_string_multiple_links_test() {
  let content =
    "[first](./a.md) some text [second](./b.md) more text [external](https://example.com)"
  parser.parse_links_from_string(content)
  |> should.equal(["./a.md", "./b.md"])
}

pub fn parse_links_from_string_empty_string_test() {
  parser.parse_links_from_string("")
  |> should.equal([])
}

pub fn parse_links_from_string_no_links_test() {
  parser.parse_links_from_string("just some plain text with no links")
  |> should.equal([])
}
