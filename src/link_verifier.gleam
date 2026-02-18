import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, Some}
import gleam/regexp
import gleam/result
import simplifile

pub fn main() -> Nil {
  case argv.load().arguments {
    [filepath] -> {
      case
        parse_file_for_links(filepath)
        |> result.unwrap([])
        |> find_missing_files()
      {
        Some(bad_links) -> {
          let total =
            bad_links
            |> list.length
            |> int.to_string
          io.println("done. Found " <> total <> " missing links")
        }
        _ -> io.println("all good!")
      }
    }
    _ -> io.println("none")
  }
}

type LinksList =
  List(String)

type ParseFileError {
  FileReadError(simplifile.FileError)
}

fn parse_file_for_links(filepath: String) -> Result(LinksList, ParseFileError) {
  use contents <- result.try(
    simplifile.read(filepath)
    |> result.map_error(FileReadError),
  )

  let assert Ok(re) =
    regexp.compile(
      "\\[.*?\\]\\(((?!https?://).*?)\\)",
      regexp.Options(case_insensitive: False, multi_line: True),
    )

  let links =
    regexp.scan(re, contents)
    |> list.filter_map(fn(match) {
      case match.submatches {
        [Some(path)] -> Ok(path)
        _ -> Error(Nil)
      }
    })

  Ok(links)
}

fn find_missing_files(links: LinksList) -> Option(LinksList) {
  todo
}
