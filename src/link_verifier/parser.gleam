import gleam/list
import gleam/option.{Some}
import gleam/regexp
import gleam/result
import gleam/string
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
  // Handles one level of balanced parentheses in link URLs, e.g. [text](file (1).md)
  let assert Ok(re) =
    regexp.compile(
      "\\[.*?\\]\\(((?!https?://)[^()]*(?:\\([^()]*\\)[^()]*)*)\\)",
      regexp.Options(case_insensitive: False, multi_line: False),
    )

  contents
  |> string.split("\n")
  |> list.index_map(fn(line_content, idx) {
    regexp.scan(re, line_content)
    |> list.filter_map(fn(match) {
      case match.submatches {
        [Some(raw_path)] -> {
          let path = strip_fragment(raw_path)
          case should_check(path) {
            True ->
              Ok(Link(source_file: source_file, line: idx + 1, path: path))
            False -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    })
  })
  |> list.flatten
}

fn strip_fragment(path: String) -> String {
  case string.split_once(path, "#") {
    Ok(#(before, _)) -> before
    Error(_) -> path
  }
}

fn should_check(path: String) -> Bool {
  case path {
    "" -> False
    "mailto:" <> _ -> False
    "tel:" <> _ -> False
    "?" <> _ -> False
    _ -> True
  }
}

pub fn find_missing_files(links: List(Link)) -> List(Link) {
  list.filter(links, fn(link) {
    let resolved = resolve_path(link.source_file, link.path)
    case simplifile.is_file(resolved) {
      Ok(True) -> False
      _ ->
        case simplifile.is_directory(resolved) {
          Ok(True) -> False
          _ -> True
        }
    }
  })
}

fn resolve_path(source_file: String, link_path: String) -> String {
  let decoded = percent_decode(link_path)
  case string.starts_with(decoded, "/") {
    True -> decoded
    False -> directory_of(source_file) <> "/" <> decoded
  }
}

fn directory_of(filepath: String) -> String {
  let parts = string.split(filepath, "/")
  case parts {
    [_] -> "."
    _ -> {
      let dir_parts = list.take(parts, list.length(parts) - 1)
      case dir_parts {
        [] -> "."
        _ -> string.join(dir_parts, "/")
      }
    }
  }
}

pub fn percent_decode(input: String) -> String {
  percent_decode_loop(string.to_graphemes(input), [])
}

fn percent_decode_loop(chars: List(String), acc: List(String)) -> String {
  case chars {
    [] -> list.reverse(acc) |> string.join("")
    ["%", h1, h2, ..rest] ->
      case hex_value(h1, h2) {
        Ok(cp) -> percent_decode_loop(rest, [cp, ..acc])
        Error(_) -> percent_decode_loop([h1, h2, ..rest], ["%", ..acc])
      }
    [ch, ..rest] -> percent_decode_loop(rest, [ch, ..acc])
  }
}

fn hex_value(h1: String, h2: String) -> Result(String, Nil) {
  use v1 <- result.try(hex_digit(h1))
  use v2 <- result.try(hex_digit(h2))
  let n = v1 * 16 + v2
  case n >= 32 && n <= 126 {
    True ->
      case string.utf_codepoint(n) {
        Ok(cp) -> Ok(string.from_utf_codepoints([cp]))
        Error(_) -> Error(Nil)
      }
    False -> Error(Nil)
  }
}

fn hex_digit(ch: String) -> Result(Int, Nil) {
  case ch {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)
    "a" | "A" -> Ok(10)
    "b" | "B" -> Ok(11)
    "c" | "C" -> Ok(12)
    "d" | "D" -> Ok(13)
    "e" | "E" -> Ok(14)
    "f" | "F" -> Ok(15)
    _ -> Error(Nil)
  }
}
