#!/usr/bin/env bash

set -u
set -o pipefail

usage() {
  cat <<'USAGE'
Run all Exdantic examples with the correct runner per file.

Usage:
  bash examples/run_all.sh [--match <substring>] [--fail-fast] [--help]

Options:
  --match <substring>  Run only examples whose filename contains substring.
  --fail-fast          Stop at the first failed example.
  --help               Show this message.
USAGE
}

fail_fast=false
match_pattern=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --match)
      if [[ $# -lt 2 ]]; then
        echo "error: --match requires a value" >&2
        usage
        exit 2
      fi
      match_pattern="$2"
      shift 2
      ;;
    --fail-fast)
      fail_fast=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

mapfile -t examples < <(find "$script_dir" -maxdepth 1 -type f -name '*.exs' | sort)

if [[ -n "$match_pattern" ]]; then
  filtered=()
  for file in "${examples[@]}"; do
    if [[ "$(basename "$file")" == *"$match_pattern"* ]]; then
      filtered+=("$file")
    fi
  done
  examples=("${filtered[@]}")
fi

if [[ ${#examples[@]} -eq 0 ]]; then
  echo "No examples matched the current filter." >&2
  exit 1
fi

successes=()
failures=()
index=0
total=${#examples[@]}

run_one() {
  local file="$1"
  local rel="examples/$(basename "$file")"
  local -a cmd
  local runner

  if grep -Eq '^[[:space:]]*Mix\.install\(' "$file"; then
    runner="elixir"
    cmd=(elixir "$rel")
  else
    runner="mix run"
    cmd=(mix run "$rel")
  fi

  echo
  printf '[%d/%d] %s (%s)\n' "$index" "$total" "$rel" "$runner"
  printf 'Command: %s\n' "${cmd[*]}"

  if (cd "$repo_root" && "${cmd[@]}"); then
    echo "Result: PASS"
    successes+=("$rel")
    return 0
  fi

  local status=$?
  echo "Result: FAIL (exit $status)"
  failures+=("$rel")
  return "$status"
}

for file in "${examples[@]}"; do
  index=$((index + 1))
  if ! run_one "$file"; then
    if [[ "$fail_fast" == true ]]; then
      break
    fi
  fi
done

echo
echo "=== Example Run Summary ==="
echo "Passed: ${#successes[@]}"
for rel in "${successes[@]}"; do
  echo "  - $rel"
done

echo "Failed: ${#failures[@]}"
for rel in "${failures[@]}"; do
  echo "  - $rel"
done

if [[ ${#failures[@]} -gt 0 ]]; then
  exit 1
fi

exit 0
