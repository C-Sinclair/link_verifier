import gleam/list
import gleam/option.{type Option, Some}
import gleam/regexp
import gleam/result
import simplifile

pub type LinksList =
  List(String)

pub type ParseFileError {
  FileReadError(simplifile.FileError)
}

pub fn parse_file_for_links(
  filepath: String,
) -> Result(LinksList, ParseFileError) {
  use contents <- result.try(
    simplifile.read(filepath)
    |> result.map_error(FileReadError),
  )

  Ok(parse_links_from_string(contents))
}

pub fn parse_links_from_string(contents: String) -> LinksList {
  let assert Ok(re) =
    regexp.compile(
      "\\[.*?\\]\\(((?!https?://).*?)\\)",
      regexp.Options(case_insensitive: False, multi_line: True),
    )

  regexp.scan(re, contents)
  |> list.filter_map(fn(match) {
    case match.submatches {
      [Some(path)] -> Ok(path)
      _ -> Error(Nil)
    }
  })
}

pub fn find_missing_files(links: LinksList) -> Option(LinksList) {
  todo
}
