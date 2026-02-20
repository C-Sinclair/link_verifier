#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

BINARY="${BINARY:-$ROOT_DIR/link_verifier}"
DEPTH="${DEPTH:-3}"
FILES_PER_LEVEL="${FILES_PER_LEVEL:-100}"
RUNS="${RUNS:-5}"
SEED="${SEED:-42}"
BROKEN_RATE="${BROKEN_RATE:-0.35}"

gleam build >/dev/null
gleam run -m gleescript >/dev/null

TMP_DIR="$(mktemp -d "$ROOT_DIR/.bench_tmp.XXXXXX")"
TMP_REL="${TMP_DIR#"$ROOT_DIR"/}"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 - "$TMP_DIR" "$DEPTH" "$FILES_PER_LEVEL" "$SEED" "$BROKEN_RATE" <<'PY'
import os
import random
import sys

tmp_dir = sys.argv[1]
depth = int(sys.argv[2])
files_per_level = int(sys.argv[3])
seed = int(sys.argv[4])
broken_rate = float(sys.argv[5])

rng = random.Random(seed)

readme = os.path.join(tmp_dir, "README.md")
with open(readme, "w", encoding="utf-8") as f:
    f.write("# benchmark root\n")

targets_dir = os.path.join(tmp_dir, "targets")
os.makedirs(targets_dir, exist_ok=True)
valid_targets = []
for idx in range(1, 11):
    path = os.path.join(targets_dir, f"target_{idx}.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(f"# target {idx}\n")
    valid_targets.append(path)

files = []
current = tmp_dir
for level in range(1, depth + 1):
    current = os.path.join(current, f"level_{level}")
    os.makedirs(current, exist_ok=True)
    for idx in range(1, files_per_level + 1):
        files.append(os.path.join(current, f"file_{idx}.md"))

word_bank = [
    "alpha", "beta", "gamma", "delta", "link", "verify", "docs", "comment",
    "module", "parser", "runtime", "benchmark", "output", "target", "path",
]

broken_count = 0
for i, path in enumerate(files):
    lines = [f"# synthetic file {i + 1}"]
    for _ in range(rng.randint(5, 12)):
        sentence = " ".join(rng.choice(word_bank) for _ in range(rng.randint(8, 20)))
        lines.append(sentence)

    links_total = rng.randint(3, 8)
    has_broken = False
    for link_idx in range(links_total):
        valid = rng.random() >= broken_rate
        if valid:
            target = rng.choice(valid_targets + [readme])
        else:
            target = os.path.join(tmp_dir, "missing", f"missing_{i}_{link_idx}.md")
            has_broken = True
            broken_count += 1
        lines.append(f"See [reference {link_idx + 1}]({target}) for details.")

    if not has_broken and i % 4 == 0:
        forced = os.path.join(tmp_dir, "missing", f"forced_missing_{i}.md")
        lines.append(f"Forced [broken link]({forced})")
        broken_count += 1

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

if broken_count == 0:
    forced = os.path.join(tmp_dir, "missing", "forced_missing_global.md")
    with open(files[0], "a", encoding="utf-8") as f:
        f.write(f"Forced [broken global]({forced})\n")
PY

SINGLE_FILE="$TMP_REL/level_1/file_1.md"
GLOB_PATTERN="./$TMP_REL/level_*/*.md"

run_benchmark() {
  local label="$1"
  local expected_exit="$2"
  shift
  shift

  python3 - "$RUNS" "$label" "$expected_exit" "$@" <<'PY'
import statistics
import subprocess
import sys
import time

runs = int(sys.argv[1])
label = sys.argv[2]
expected_exit = int(sys.argv[3])
cmd = sys.argv[4:]
times = []

for _ in range(runs):
    start = time.perf_counter()
    result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elapsed_ms = (time.perf_counter() - start) * 1000
    if result.returncode != expected_exit:
        print(
            f"{label}: expected exit {expected_exit}, got {result.returncode}",
            file=sys.stderr,
        )
        sys.exit(result.returncode)
    times.append(elapsed_ms)

times_sorted = sorted(times)
p95_index = max(0, int(len(times_sorted) * 0.95) - 1)
p95 = times_sorted[p95_index]

print(
    f"{label}: min={min(times):.2f}ms avg={statistics.mean(times):.2f}ms "
    f"p95={p95:.2f}ms runs={runs} exit={expected_exit}"
)
PY
}

echo "Benchmark dataset: depth=$DEPTH files_per_level=$FILES_PER_LEVEL total_files=$((DEPTH * FILES_PER_LEVEL)) seed=$SEED broken_rate=$BROKEN_RATE"
run_benchmark "single-file-mixed" 2 "$BINARY" "$SINGLE_FILE"
run_benchmark "directory-recursive-mixed" 2 "$BINARY" "$TMP_REL"
run_benchmark "wildcard-pattern-mixed" 2 "$BINARY" "$GLOB_PATTERN"
