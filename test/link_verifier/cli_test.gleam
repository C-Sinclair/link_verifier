import gleam/string
import gleeunit/should
import shellout
import simplifile

pub fn cli_no_args_returns_usage_error_test() {
  let assert Error(#(1, output)) =
    shellout.command(run: "gleam", with: ["run", "--"], in: ".", opt: [])

  string.contains(does: output, contain: "usage: link_verifier")
  |> should.equal(True)
}

pub fn cli_help_flag_prints_usage_test() {
  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "--help"],
      in: ".",
      opt: [],
    )

  string.contains(does: output, contain: "usage: link_verifier")
  |> should.equal(True)
}

pub fn cli_version_flag_prints_version_test() {
  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "--version"],
      in: ".",
      opt: [],
    )

  string.contains(does: output, contain: "link_verifier 0.2.1")
  |> should.equal(True)
}

pub fn cli_supports_multiple_file_targets_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/existing.md", contents: "ok")
  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/a.md", contents: "[ok](existing.md)")
  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/b.md", contents: "[bad](missing.md)")

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/a.md", "test/.tmp_cli/b.md"],
      in: ".",
      opt: [],
    )

  string.contains(does: output, contain: "test/.tmp_cli/b.md:1: broken link")
  |> should.equal(True)
}

pub fn cli_supports_directory_targets_test() {
  reset_tmp()

  let assert Ok(Nil) = simplifile.create_directory_all("test/.tmp_cli/dir")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/dir/one.md",
      contents: "[bad](missing.md)",
    )

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/dir"],
      in: ".",
      opt: [],
    )

  string.contains(
    does: output,
    contain: "test/.tmp_cli/dir/one.md:1: broken link",
  )
  |> should.equal(True)
}

pub fn cli_supports_glob_targets_test() {
  reset_tmp()

  let assert Ok(Nil) = simplifile.create_directory_all("test/.tmp_cli/glob")
  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/glob/a.md", contents: "plain text")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/glob/b.md",
      contents: "[bad](missing.md)",
    )

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "*test/.tmp_cli/glob/*.md"],
      in: ".",
      opt: [],
    )

  string.contains(
    does: output,
    contain: "test/.tmp_cli/glob/b.md:1: broken link",
  )
  |> should.equal(True)
}

pub fn cli_resolves_relative_to_source_file_test() {
  reset_tmp()

  let assert Ok(Nil) = simplifile.create_directory_all("test/.tmp_cli/sub")
  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/sub/sibling.md", contents: "ok")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/sub/index.md",
      contents: "[link](sibling.md)",
    )

  let assert Ok(_output) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/sub/index.md"],
      in: ".",
      opt: [],
    )

  // Should pass with no broken links (exit 0)
  True |> should.equal(True)
}

pub fn cli_resolves_parent_directory_links_test() {
  reset_tmp()

  let assert Ok(Nil) = simplifile.create_directory_all("test/.tmp_cli/docs/sub")
  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/docs/root.md", contents: "ok")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/docs/sub/child.md",
      contents: "[up](../root.md)",
    )

  let assert Ok(_output) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/docs/sub/child.md"],
      in: ".",
      opt: [],
    )

  True |> should.equal(True)
}

pub fn cli_handles_percent_encoded_spaces_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/Scope Doc.md", contents: "ok")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/index.md",
      contents: "[scope](Scope%20Doc.md)",
    )

  let assert Ok(_output) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/index.md"],
      in: ".",
      opt: [],
    )

  True |> should.equal(True)
}

pub fn cli_handles_parentheses_in_filenames_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/Sheet (1).md", contents: "ok")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/index.md",
      contents: "[sheet](Sheet (1).md)",
    )

  let assert Ok(_output) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/index.md"],
      in: ".",
      opt: [],
    )

  True |> should.equal(True)
}

pub fn cli_skips_mailto_links_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/contacts.md",
      contents: "[email](mailto:user@example.com)",
    )

  let assert Ok(_output) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/contacts.md"],
      in: ".",
      opt: [],
    )

  True |> should.equal(True)
}

pub fn cli_skips_anchor_only_links_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/toc.md",
      contents: "[section](#overview)\n[other](#details)",
    )

  let assert Ok(_output) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/toc.md"],
      in: ".",
      opt: [],
    )

  True |> should.equal(True)
}

pub fn cli_accepts_directory_links_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.create_directory_all("test/.tmp_cli/assessment")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/readme.md",
      contents: "[assessment](assessment/)",
    )

  let assert Ok(_output) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/readme.md"],
      in: ".",
      opt: [],
    )

  True |> should.equal(True)
}

pub fn cli_dot_directory_target_test() {
  reset_tmp()

  let assert Ok(Nil) = simplifile.create_directory_all("test/.tmp_cli/dotdir")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/dotdir/good.md",
      contents: "no links here",
    )
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/dotdir/bad.md",
      contents: "[missing](nope.md)",
    )
  // Also create a non-md file that should be ignored
  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/dotdir/data.json", contents: "{}")

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/dotdir"],
      in: ".",
      opt: [],
    )

  string.contains(does: output, contain: "bad.md:1: broken link")
  |> should.equal(True)
  // Should not mention the json file
  string.contains(does: output, contain: "data.json")
  |> should.equal(False)
}

pub fn cli_deduplicates_targets_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/dup.md", contents: "[missing](gone.md)")

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/dup.md", "test/.tmp_cli/dup.md"],
      in: ".",
      opt: [],
    )

  // Should only report the broken link once, not twice
  string.contains(does: output, contain: "1 broken link in 1 file")
  |> should.equal(True)
}

pub fn cli_shows_summary_line_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/one.md",
      contents: "[a](missing-a.md)\n[b](missing-b.md)",
    )
  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/two.md", contents: "[c](missing-c.md)")

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/one.md", "test/.tmp_cli/two.md"],
      in: ".",
      opt: [],
    )

  string.contains(does: output, contain: "3 broken links in 2 files")
  |> should.equal(True)
}

pub fn cli_summary_singular_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/solo.md", contents: "[x](nope.md)")

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/solo.md"],
      in: ".",
      opt: [],
    )

  string.contains(does: output, contain: "1 broken link in 1 file")
  |> should.equal(True)
}

pub fn cli_except_excludes_matching_files_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/keep.md", contents: "[bad](missing.md)")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/skip.md",
      contents: "[bad](also-missing.md)",
    )

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli", "-x", "skip"],
      in: ".",
      opt: [],
    )

  string.contains(does: output, contain: "keep.md:1: broken link")
  |> should.equal(True)
  string.contains(does: output, contain: "skip.md")
  |> should.equal(False)
}

pub fn cli_except_long_flag_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/include.md",
      contents: "[bad](missing.md)",
    )
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/exclude.md",
      contents: "[bad](also-missing.md)",
    )

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli", "--except", "exclude"],
      in: ".",
      opt: [],
    )

  string.contains(does: output, contain: "include.md:1: broken link")
  |> should.equal(True)
  string.contains(does: output, contain: "exclude.md")
  |> should.equal(False)
}

pub fn cli_except_multiple_patterns_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/a.md", contents: "[x](missing.md)")
  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/b.md", contents: "[x](missing.md)")
  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/c.md", contents: "[x](missing.md)")

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli", "-x", "/a\\.md$", "-x", "/b\\.md$"],
      in: ".",
      opt: [],
    )

  string.contains(does: output, contain: "c.md:1: broken link")
  |> should.equal(True)
  string.contains(does: output, contain: "a.md")
  |> should.equal(False)
  string.contains(does: output, contain: "b.md")
  |> should.equal(False)
}

pub fn cli_except_all_excluded_passes_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/only.md", contents: "[x](missing.md)")

  let assert Ok(_output) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli/only.md", "-x", "only"],
      in: ".",
      opt: [],
    )

  True |> should.equal(True)
}

pub fn cli_except_regex_pattern_test() {
  reset_tmp()

  let assert Ok(Nil) = simplifile.create_directory_all("test/.tmp_cli/vendor")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/vendor/lib.md",
      contents: "[x](missing.md)",
    )
  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/app.md", contents: "[x](missing.md)")

  let assert Error(#(2, output)) =
    shellout.command(
      run: "gleam",
      with: ["run", "--", "test/.tmp_cli", "-x", "vendor/"],
      in: ".",
      opt: [],
    )

  string.contains(does: output, contain: "app.md:1: broken link")
  |> should.equal(True)
  string.contains(does: output, contain: "vendor")
  |> should.equal(False)
}

fn reset_tmp() -> Nil {
  case simplifile.delete("test/.tmp_cli") {
    Ok(Nil) -> Nil
    Error(_) -> Nil
  }

  let assert Ok(Nil) = simplifile.create_directory_all("test/.tmp_cli")
  Nil
}
