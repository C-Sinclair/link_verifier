import gleam/list
import gleam/result
import gleam/set
import gleam/string
import simplifile

pub type ExpandError {
  TargetNotFound(String)
  TargetReadError(target: String, error: simplifile.FileError)
}

pub fn expand_targets(
  targets: List(String),
) -> Result(List(String), ExpandError) {
  use all <- result.try(
    expand_targets_loop(targets, [])
    |> result.map(list.reverse),
  )
  Ok(deduplicate(all))
}

fn deduplicate(paths: List(String)) -> List(String) {
  deduplicate_loop(paths, set.new(), [])
  |> list.reverse
}

fn deduplicate_loop(
  paths: List(String),
  seen: set.Set(String),
  acc: List(String),
) -> List(String) {
  case paths {
    [] -> acc
    [path, ..rest] ->
      case set.contains(seen, path) {
        True -> deduplicate_loop(rest, seen, acc)
        False -> deduplicate_loop(rest, set.insert(seen, path), [path, ..acc])
      }
  }
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
      let files = walk_all_files(".")
      let matches = list.filter(files, fn(path) { wildcard_match(target, path) })
      case matches {
        [] -> Error(TargetNotFound(target))
        _ -> Ok(matches)
      }
    }
    False -> expand_literal_target(target)
  }
}

fn expand_literal_target(target: String) -> Result(List(String), ExpandError) {
  case simplifile.is_file(target) {
    Ok(True) -> Ok([target])
    _ ->
      case simplifile.is_directory(target) {
        Ok(True) -> {
          let files = walk_md_files(target)
          case files {
            [] -> Error(TargetNotFound(target))
            _ -> Ok(files)
          }
        }
        Ok(False) -> Error(TargetNotFound(target))
        Error(error) -> Error(TargetReadError(target: target, error: error))
      }
  }
}

fn walk_all_files(dir: String) -> List(String) {
  case simplifile.read_directory(dir) {
    Error(_) -> []
    Ok(entries) ->
      list.flat_map(entries, fn(entry) {
        let path = case dir {
          "." -> entry
          _ -> dir <> "/" <> entry
        }
        case simplifile.is_directory(path) {
          Ok(True) -> walk_all_files(path)
          _ -> [path]
        }
      })
  }
}

fn walk_md_files(dir: String) -> List(String) {
  case simplifile.read_directory(dir) {
    Error(_) -> []
    Ok(entries) ->
      list.flat_map(entries, fn(entry) {
        case is_hidden(entry) {
          True -> []
          False -> {
            let path = case dir {
              "." -> entry
              _ -> dir <> "/" <> entry
            }
            case simplifile.is_directory(path) {
              Ok(True) -> walk_md_files(path)
              _ ->
                case string.ends_with(path, ".md") {
                  True -> [path]
                  False -> []
                }
            }
          }
        }
      })
  }
}

fn is_hidden(name: String) -> Bool {
  string.starts_with(name, ".")
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
