import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/result
import link_verifier/parser

pub fn main() -> Nil {
  case argv.load().arguments {
    [filepath] -> {
      case
        parser.parse_file_for_links(filepath)
        |> result.unwrap([])
        |> parser.find_missing_files()
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
