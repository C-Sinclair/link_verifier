import gleeunit/should
import gleam/string
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

  string.contains(does: output, contain: "link_verifier 1.0.0")
  |> should.equal(True)
}

pub fn cli_supports_multiple_file_targets_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.write(to: "test/.tmp_cli/existing.md", contents: "ok")
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/a.md",
      contents: "[ok](existing.md)",
    )
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/b.md",
      contents: "[bad](missing.md)",
    )

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

  let assert Ok(Nil) =
    simplifile.create_directory_all("test/.tmp_cli/dir")
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

  string.contains(does: output, contain: "test/.tmp_cli/dir/one.md:1: broken link")
  |> should.equal(True)
}

pub fn cli_supports_glob_targets_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.create_directory_all("test/.tmp_cli/glob")
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

  string.contains(does: output, contain: "test/.tmp_cli/glob/b.md:1: broken link")
  |> should.equal(True)
}

pub fn cli_resolves_relative_to_source_file_test() {
  reset_tmp()

  let assert Ok(Nil) =
    simplifile.create_directory_all("test/.tmp_cli/sub")
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

  let assert Ok(Nil) =
    simplifile.create_directory_all("test/.tmp_cli/docs/sub")
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

fn reset_tmp() -> Nil {
  case simplifile.delete("test/.tmp_cli") {
    Ok(Nil) -> Nil
    Error(_) -> Nil
  }

  let assert Ok(Nil) = simplifile.create_directory_all("test/.tmp_cli")
  Nil
}
