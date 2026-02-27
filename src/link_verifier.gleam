import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/regexp
import link_verifier/parser
import link_verifier/resolver
import simplifile

const version = "0.2.1"

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
    ErrorMissingExceptPattern -> {
      io.println_error("--except / -x requires a pattern argument")
      halt(1)
    }
    VerifyTargets(targets, except) -> verify_targets(targets, except)
  }
}

type Command {
  ShowHelp
  ShowVersion
  ErrorMissingTargets
  ErrorMissingExceptPattern
  VerifyTargets(targets: List(String), except: List(String))
}

fn parse_arguments(args: List(String)) -> Command {
  case args {
    [] -> ErrorMissingTargets
    ["-h"] | ["--help"] -> ShowHelp
    ["-v"] | ["--version"] -> ShowVersion
    _ -> {
      case split_args(args, [], []) {
        Error(Nil) -> ErrorMissingExceptPattern
        Ok(#([], _)) -> ErrorMissingTargets
        Ok(#(targets, except)) -> VerifyTargets(targets, except)
      }
    }
  }
}

fn split_args(
  args: List(String),
  targets: List(String),
  except: List(String),
) -> Result(#(List(String), List(String)), Nil) {
  case args {
    [] -> Ok(#(list.reverse(targets), list.reverse(except)))
    ["-x", pattern, ..rest] | ["--except", pattern, ..rest] ->
      split_args(rest, targets, [pattern, ..except])
    ["-x"] | ["--except"] -> Error(Nil)
    [target, ..rest] -> split_args(rest, [target, ..targets], except)
  }
}

fn verify_targets(targets: List(String), except: List(String)) -> Nil {
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
    Ok(filepaths) -> verify_files(filter_except(filepaths, except))
  }
}

fn filter_except(
  filepaths: List(String),
  except_patterns: List(String),
) -> List(String) {
  case except_patterns {
    [] -> filepaths
    _ -> {
      let compiled =
        list.filter_map(except_patterns, fn(p) { regexp.from_string(p) })
      list.filter(filepaths, fn(path) {
        !list.any(compiled, fn(re) { regexp.check(re, path) })
      })
    }
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
          collect_missing_links(
            rest,
            prepend_links(list.reverse(missing), collected),
          )
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

      let link_count = list.length(bad_links)
      let file_count =
        bad_links
        |> list.map(fn(link) { link.source_file })
        |> list.unique
        |> list.length

      io.println_error(
        "\n"
        <> int.to_string(link_count)
        <> " broken "
        <> pluralize(link_count, "link", "links")
        <> " in "
        <> int.to_string(file_count)
        <> " "
        <> pluralize(file_count, "file", "files"),
      )
      halt(2)
    }
  }
}

fn pluralize(count: Int, singular: String, plural: String) -> String {
  case count {
    1 -> singular
    _ -> plural
  }
}

fn help_text() -> String {
  "usage: link_verifier <target> [target ...] [options]\n"
  <> "\n"
  <> "targets can be files, directories, or wildcard patterns such as *.md\n"
  <> "\n"
  <> "options:\n"
  <> "  -h, --help              show this help\n"
  <> "  -v, --version           show version\n"
  <> "  -x, --except <pattern>  exclude files matching regex (repeatable)"
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
