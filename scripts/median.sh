#!/usr/bin/env bash
# scripts/aggregate_medians.sh
#
# Usage: ./aggregate_medians.sh <results_root>
# Example: ./aggregate_medians.sh results/20251106_120000
#
# Produces: results/<timestamp>/median/<benchmark>.out
#

set -euo pipefail

RESULTS_ROOT="${1:-}"
if [[ -z "$RESULTS_ROOT" || ! -d "$RESULTS_ROOT" ]]; then
  echo "Usage: $0 <results_root>" >&2
  echo "Example: $0 results/20251106_120000" >&2
  exit 1
fi

MEDIAN_DIR="$RESULTS_ROOT/median"
mkdir -p "$MEDIAN_DIR"

median() {
  # $1 = array of numbers
  local arr=($(printf '%s\n' "$@" | sort -n))
  local len=${#arr[@]}
  if (( len == 0 )); then
    echo "NaN"
    return
  fi
  if (( len % 2 == 1 )); then
    # odd
    echo "${arr[$((len/2))]}"
  else
    # even
    local mid=$((len/2))
    awk "BEGIN {print (${arr[$mid-1]}+${arr[$mid]})/2}"
  fi
}

for bench_dir in "$RESULTS_ROOT"/*/; do
  bench_name="$(basename "$bench_dir")"
  # skip median dir itself
  [[ "$bench_name" == "median" ]] && continue

  declare -A out_values

  # collect all .out files across all runs
  for run_dir in "$bench_dir"/run-*/; do
    [[ ! -d "$run_dir" ]] && continue
    for out_file in "$run_dir"/*.out; do
      [[ ! -f "$out_file" ]] && continue
      file_name="$(basename "$out_file")"
      while IFS= read -r line; do
        # line format: value or key value (optional parsing can be added)
        # assume numeric values
        [[ "$line" =~ ^[0-9.+-eE]+$ ]] || continue
        out_values["$file_name"]+="$line "
      done < "$out_file"
    done
  done

  # compute medians
  echo "Benchmark: $bench_name"
  MEDIAN_FILE="$MEDIAN_DIR/$bench_name.out"
  > "$MEDIAN_FILE"
  for f in "${!out_values[@]}"; do
    med=$(median ${out_values[$f]})
    echo "$f $med" >> "$MEDIAN_FILE"
  done
  echo "-> Wrote medians to $MEDIAN_FILE"
done

