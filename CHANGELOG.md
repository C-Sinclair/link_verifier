# Changelog

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
