# Changelog

## 0.5.1

- Skip links carrying any URI scheme, not just `http`, `https`, `mailto` and `tel`. An application scheme such as `shortcutapp://members/...` or `obsidian://open?vault=notes` was treated as a relative path and reported as a broken link.
- Keep checking a path whose filename contains a colon, such as `Meeting: notes.md` or `C:/Users/a.md`.

## 0.5.0

- Add `--assert-backlinks` to require that a link between two scanned files is reciprocated by a link back, so bidirectional traversal cannot dead-end. Off by default; a missing backlink exits 2 like a broken link.
- Add `Resolver.normalize_path`, which collapses `.` and `..` segments so two links naming the same file compare equal.

## 0.4.0

- Decode percent-encoded bytes above 126, so links to files with en dashes or other non-ASCII characters (`%E2%80%93`) resolve instead of reporting a false positive.
- Check the undecoded path as well, so a filename that literally contains `%` still resolves.
- Add `--no-code-links` flag to skip links inside fenced code blocks (`` ``` ``, `~~~`) and inline code (`` ` ``).

## 0.3.1

- Drop macOS x86_64 release target.
- Refactor to idiomatic OCaml stdlib patterns.

## 0.3.0

- Rewrite from Gleam/Erlang to native OCaml.
- Add `-x` / `--except` regex-based file exclusion.
- Add directory link support.
- Add percent-decoding of link paths.
