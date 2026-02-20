import gleam/list
import gleam/result
import gleam/string
import simplifile

pub type ExpandError {
  TargetNotFound(String)
  TargetReadError(target: String, error: simplifile.FileError)
}

pub fn expand_targets(targets: List(String)) -> Result(List(String), ExpandError) {
  expand_targets_loop(targets, [])
  |> result.map(list.reverse)
}

fn expand_targets_loop(
  targets: List(String),
  collected: List(String),
) -> Result(List(String), ExpandError) {
  case targets {
    [] -> Ok(collected)
    [target, ..rest] -> {
      use expanded <- result.try(expand_target(target))
      expand_targets_loop(rest, prepend_all(list.reverse(expanded), collected))
    }
  }
}

fn prepend_all(values: List(String), collected: List(String)) -> List(String) {
  case values {
    [] -> collected
    [value, ..rest] -> prepend_all(rest, [value, ..collected])
  }
}

fn expand_target(target: String) -> Result(List(String), ExpandError) {
  case has_wildcards(target) {
    True -> {
      use files <- result.try(
        simplifile.get_files(".")
        |> result.map_error(fn(error) { TargetReadError(target: ".", error: error) }),
      )

      let matches = list.filter(files, fn(path) { wildcard_match(target, path) })
      case matches {
        [] -> Error(TargetNotFound(target))
        _ -> Ok(matches)
      }
    }
    False -> {
      case simplifile.is_file(target) {
        Ok(True) -> Ok([target])
        Ok(False) -> {
          case simplifile.is_directory(target) {
            Ok(True) -> {
              simplifile.get_files(target)
              |> result.map_error(fn(error) {
                TargetReadError(target: target, error: error)
              })
            }
            Ok(False) -> Error(TargetNotFound(target))
            Error(error) -> Error(TargetReadError(target: target, error: error))
          }
        }
        Error(error) -> Error(TargetReadError(target: target, error: error))
      }
    }
  }
}

fn has_wildcards(value: String) -> Bool {
  has_wildcards_graphemes(string.to_graphemes(value))
}

fn has_wildcards_graphemes(chars: List(String)) -> Bool {
  case chars {
    [] -> False
    [char, ..rest] ->
      { char == "*" || char == "?" } || has_wildcards_graphemes(rest)
  }
}

fn wildcard_match(pattern: String, path: String) -> Bool {
  wildcard_match_parts(string.to_graphemes(pattern), string.to_graphemes(path))
}

fn wildcard_match_parts(pattern: List(String), path: List(String)) -> Bool {
  case pattern, path {
    [], [] -> True
    [], _ -> False
    ["*", ..rest], _ -> wildcard_match_star(rest, path)
    ["?", ..rest], [_, ..path_rest] -> wildcard_match_parts(rest, path_rest)
    [part, ..rest], [path_part, ..path_rest] -> {
      part == path_part && wildcard_match_parts(rest, path_rest)
    }
    _, _ -> False
  }
}

fn wildcard_match_star(pattern_rest: List(String), path: List(String)) -> Bool {
  wildcard_match_parts(pattern_rest, path)
  || case path {
    [_, ..path_rest] -> wildcard_match_star(pattern_rest, path_rest)
    [] -> False
  }
}
