import argv
import gleam/int
import gleam/io
import gleam/list
import link_verifier/parser
import link_verifier/resolver
import simplifile

const version = "1.0.0"

pub fn main() -> Nil {
  case argv.load().arguments |> parse_arguments {
    ShowHelp -> {
      io.println(help_text())
      halt(0)
    }
    ShowVersion -> {
      io.println("link_verifier " <> version)
      halt(0)
    }
    ErrorMissingTargets -> {
      io.println_error(help_text())
      halt(1)
    }
    VerifyTargets(targets) -> verify_targets(targets)
  }
}

type Command {
  ShowHelp
  ShowVersion
  ErrorMissingTargets
  VerifyTargets(List(String))
}

fn parse_arguments(args: List(String)) -> Command {
  case args {
    [] -> ErrorMissingTargets
    ["-h"] -> ShowHelp
    ["--help"] -> ShowHelp
    ["-v"] -> ShowVersion
    ["--version"] -> ShowVersion
    _ -> VerifyTargets(args)
  }
}

fn verify_targets(targets: List(String)) -> Nil {
  case resolver.expand_targets(targets) {
    Error(resolver.TargetNotFound(target)) -> {
      io.println_error("target not found: " <> target)
      halt(1)
    }
    Error(resolver.TargetReadError(target, error)) -> {
      io.println_error(
        "could not read target: "
        <> target
        <> " ("
        <> simplifile.describe_error(error)
        <> ")",
      )
      halt(1)
    }
    Ok(filepaths) -> verify_files(filepaths)
  }
}

fn verify_files(filepaths: List(String)) -> Nil {
  case collect_missing_links(filepaths, []) {
    Error(#(filepath, e)) -> {
      io.println_error(
        "error reading file: " <> filepath <> " (" <> simplifile_error(e) <> ")",
      )
      halt(1)
    }
    Ok(bad_links) -> report(bad_links)
  }
}

fn collect_missing_links(
  filepaths: List(String),
  collected: List(parser.Link),
) -> Result(List(parser.Link), #(String, simplifile.FileError)) {
  case filepaths {
    [] -> Ok(list.reverse(collected))
    [filepath, ..rest] -> {
      case parser.parse_file_for_links(filepath) {
        Error(parser.FileReadError(e)) -> Error(#(filepath, e))
        Ok(links) -> {
          let missing = parser.find_missing_files(links)
          collect_missing_links(rest, prepend_links(list.reverse(missing), collected))
        }
      }
    }
  }
}

fn prepend_links(
  values: List(parser.Link),
  collected: List(parser.Link),
) -> List(parser.Link) {
  case values {
    [] -> collected
    [value, ..rest] -> prepend_links(rest, [value, ..collected])
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

fn help_text() -> String {
  "usage: link_verifier <target> [target ...]\n"
  <> "\n"
  <> "targets can be files, directories, or wildcard patterns such as *.md\n"
  <> "\n"
  <> "options:\n"
  <> "  -h, --help     show this help\n"
  <> "  -v, --version  show version"
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
