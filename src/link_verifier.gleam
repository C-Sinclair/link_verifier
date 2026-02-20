import argv
import gleam/int
import gleam/io
import gleam/list
import link_verifier/parser
import simplifile

pub fn main() -> Nil {
  case argv.load().arguments {
    [filepath] -> verify(filepath)
    _ -> halt(0)
  }
}

fn verify(filepath: String) -> Nil {
  case parser.parse_file_for_links(filepath) {
    Error(parser.FileReadError(e)) -> {
      io.println_error("error reading file: " <> simplifile_error(e))
      halt(1)
    }
    Ok(links) -> report(parser.find_missing_files(links))
  }
}

fn report(bad_links: List(parser.Link)) -> Nil {
  case bad_links {
    [] -> halt(0)
    _ -> {
      list.each(bad_links, fn(link) {
        io.println_error(
          link.source_file
          <> ":"
          <> int.to_string(link.line)
          <> ": broken link -> "
          <> link.path,
        )
      })
      halt(2)
    }
  }
}

fn simplifile_error(e: simplifile.FileError) -> String {
  case e {
    simplifile.Enoent -> "file not found"
    simplifile.Eacces -> "permission denied"
    _ -> "unknown error"
  }
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil
