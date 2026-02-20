import gleam/list
import gleam/regexp
import gleam/result
import gleam/string
import gleam/option.{Some}
import simplifile

pub type Link {
  Link(source_file: String, line: Int, path: String)
}

pub type ParseFileError {
  FileReadError(simplifile.FileError)
}

pub fn parse_file_for_links(
  filepath: String,
) -> Result(List(Link), ParseFileError) {
  use contents <- result.try(
    simplifile.read(filepath)
    |> result.map_error(FileReadError),
  )

  Ok(parse_links_from_string(filepath, contents))
}

pub fn parse_links_from_string(
  source_file: String,
  contents: String,
) -> List(Link) {
  let assert Ok(re) =
    regexp.compile(
      "\\[.*?\\]\\(((?!https?://).*?)\\)",
      regexp.Options(case_insensitive: False, multi_line: False),
    )

  contents
  |> string.split("\n")
  |> list.index_map(fn(line_content, idx) {
    regexp.scan(re, line_content)
    |> list.filter_map(fn(match) {
      case match.submatches {
        [Some(path)] ->
          Ok(Link(source_file: source_file, line: idx + 1, path: path))
        _ -> Error(Nil)
      }
    })
  })
  |> list.flatten
}

pub fn find_missing_files(links: List(Link)) -> List(Link) {
  list.filter(links, fn(link) {
    case simplifile.is_file(link.path) {
      Ok(False) -> True
      _ -> False
    }
  })
}
