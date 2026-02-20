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
      contents: "[ok](./test/.tmp_cli/existing.md)",
    )
  let assert Ok(Nil) =
    simplifile.write(
      to: "test/.tmp_cli/b.md",
      contents: "[bad](./test/.tmp_cli/missing.md)",
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
      contents: "[bad](./test/.tmp_cli/dir/missing.md)",
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
      contents: "[bad](./test/.tmp_cli/glob/missing.md)",
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

fn reset_tmp() -> Nil {
  case simplifile.delete("test/.tmp_cli") {
    Ok(Nil) -> Nil
    Error(_) -> Nil
  }

  let assert Ok(Nil) = simplifile.create_directory_all("test/.tmp_cli")
  Nil
}
