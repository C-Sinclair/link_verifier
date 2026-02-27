# ADR 0001: Rewrite link_verifier from Gleam to OCaml

## Status

Accepted

## Date

2026-02-27

## Context

link_verifier is a CLI tool (~400 lines of Gleam) that scans markdown files for
local links and verifies that the referenced files exist. It is used in CI
pipelines, git pre-commit hooks, and editor integrations where startup latency
and distribution simplicity matter.

The current implementation compiles to an Erlang escript. This works but carries
trade-offs that increasingly friction the tool's primary use cases.

## Options Considered

### 1. Stay with Gleam/escript

**Pros:**
- No rewrite effort.
- Gleam is pleasant to write and has good pattern matching / ADTs.
- Erlang ecosystem is battle-tested for concurrency (irrelevant here).

**Cons:**
- **Startup overhead:** Every invocation boots the BEAM VM. Benchmarks show
  ~110-170 ms for trivial runs. In a pre-commit hook checking a single file,
  the VM startup dominates wall-clock time.
- **Distribution:** Users must have Erlang/OTP installed. This is a non-trivial
  dependency for a single-purpose CLI tool. It creates friction for adoption
  and makes `gh release download` insufficient on its own.
- **Binary size:** The escript bundles the BEAM bytecode but still depends on
  the system Erlang installation.

### 2. Rewrite in OCaml with ocamlopt

**Pros:**
- **True native binary:** ocamlopt compiles to machine code with no runtime
  dependency. Sub-millisecond startup, ~2-5 MB self-contained binary.
- **Domain fit:** The tool's workflow (parse args, walk filesystem, regex-match
  markdown, check file existence, report errors) is bread-and-butter OCaml.
  Pattern matching, ADTs, and the `Re` library are excellent fits.
- **Library ecosystem:** `Cmdliner` for CLI (auto-generates help/man pages),
  `Re` for DFA-based linear-time regex, `Unix` module for filesystem. All
  mature and well-maintained.
- **Language similarity:** OCaml is a functional language with pattern matching,
  algebraic data types, and immutable-by-default semantics -- very similar feel
  to Gleam. The rewrite is a natural translation, not a paradigm shift.
- **Cross-compilation:** GitHub Actions can build native binaries for Linux
  x86_64, macOS arm64, and macOS x86_64 with no extra tooling.
- **Zero runtime dependency for end users.**

**Cons:**
- One-time rewrite effort (~400 lines, straightforward port).
- OCaml is less widely known than some alternatives (Go, Rust).
- The opam/dune toolchain is heavier to set up than `gleam build`.

### 3. Rewrite in Go

**Pros:**
- Easy cross-compilation to many targets.
- Large community, easy to find contributors.

**Cons:**
- Verbose error handling compared to Result types with pattern matching.
- No algebraic data types; the current code structure relies heavily on them.
- Larger binary sizes (~8-15 MB).
- Garbage collector pauses (irrelevant at this scale, but still overhead).

### 4. Rewrite in Rust

**Pros:**
- Excellent performance, small binaries.
- Strong type system with enums/pattern matching.

**Cons:**
- Significantly higher complexity for a ~400-line tool.
- Longer compile times.
- Ownership model is overkill; this tool does no concurrent mutation.

## Decision

Rewrite in OCaml.

The tool is a pure function from (CLI args, filesystem state) to (exit code,
stderr output). OCaml's type system, pattern matching, and native compilation
are the best fit for this specific problem shape. The rewrite eliminates the
Erlang/OTP runtime dependency and reduces startup from ~110 ms to
sub-millisecond.

## Benchmark comparison

Same dataset and script as the Gleam version (depth=3, files_per_level=100,
BROKEN_RATE=0.35). Runs=15 on macOS 15.7.1 (arm64).

- single-file-mixed avg: 112.39ms (Gleam) -> 3.39ms (OCaml) ~33x faster
- directory-recursive-mixed avg: 151.00ms (Gleam) -> 9.58ms (OCaml) ~15.8x faster
- wildcard-pattern-mixed avg: 173.11ms (Gleam) -> 5.84ms (OCaml) ~29.7x faster

## Consequences

### Positive

- **No runtime dependency.** Users download a single binary. No Erlang, no
  BEAM, no escript.
- **Sub-millisecond startup.** Pre-commit hooks and editor integrations feel
  instant.
- **~2.5 MB binary.** Down from escript + OTP requirement.
- **Deterministic output.** File paths are sorted for stable CI diffs.
- **Cross-platform releases.** GitHub Actions builds native binaries for
  Linux x86_64, macOS arm64, and macOS x86_64.

### Negative

- **Build toolchain.** Contributors need opam + dune + OCaml 5.x. This is
  heavier than `gleam build` but only affects developers, not users.
- **Smaller contributor pool.** OCaml is less common than Go/Rust/TypeScript.
  For a ~400-line tool with infrequent changes, this is acceptable.

### Neutral

- **Feature parity.** The OCaml version implements identical CLI behavior
  (flags, exit codes, output format) with two small improvements: invalid
  `--except` regex patterns fail fast with a clear error, and file output
  ordering is deterministic.
