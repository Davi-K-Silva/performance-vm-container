#!/usr/bin/env bash
# scripts/run_master.sh
#
# Orchestrate running benchmarks/*/run.sh and aggregate results under:
#   results/<YYYYMMDD_HHMMSS>/<benchmark>/run-XXX/
#
# Options:
#   --all                   Run all benchmarks found under benchmarks/
#   --bench a,b,c           Run only these benchmark names (comma or space separated)
#   --repeat N              Repeat each selected benchmark N times (default: 1)
#   --out DIR               Override root results dir (default: <repo>/results)
#   --list                  List available benchmarks and exit
#   --stop-on-error         Stop on first failure
#   --dry-run               Show what would happen, do not execute
#   -h, --help              Show help
#
# Env:
#   BENCH_DIR               Override benchmarks directory (default: <repo>/benchmarks)

set -uo pipefail

# --- defaults ---
REPEAT=1
STOP_ON_ERROR=0
DRY_RUN=0
SELECT_ALL=0
EXPLICIT_BENCHES=()
OUT_DIR=""
# ---------------

print_help() {
  sed -n '1,100p' "$0" | sed -n '1,60p' | sed 's/^# //;t;d'
}

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repeat)
      REPEAT="${2:-}"; shift 2 ;;
    --repeat=*)
      REPEAT="${1#*=}"; shift ;;
    --all)
      SELECT_ALL=1; shift ;;
    --bench)
      IFS=',' read -r -a EXPLICIT_BENCHES <<< "${2:-}"
      shift 2 ;;
    --bench=*)
      IFS=',' read -r -a EXPLICIT_BENCHES <<< "${1#*=}"
      shift ;;
    --out)
      OUT_DIR="${2:-}"; shift 2 ;;
    --out=*)
      OUT_DIR="${1#*=}"; shift ;;
    --list)
      LIST_ONLY=1; shift ;;
    --stop-on-error)
      STOP_ON_ERROR=1; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    -h|--help)
      print_help; exit 0 ;;
    *)
      # treat as additional bench names (space-separated)
      EXPLICIT_BENCHES+=("$1"); shift ;;
  esac
done

# --- validate repeat ---
if ! [[ "$REPEAT" =~ ^[0-9]+$ ]] || (( REPEAT < 1 )); then
  echo "ERROR: --repeat must be a positive integer. Got: $REPEAT" >&2
  exit 2
fi

# --- paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCH_DIR="${BENCH_DIR:-$REPO_ROOT/benchmarks}"
if [[ ! -d "$BENCH_DIR" ]]; then
  echo "ERROR: Benchmarks directory not found: $BENCH_DIR" >&2
  exit 1
fi

# --- discover benches ---
mapfile -d '' ALL_BENCH_DIRS < <(find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
ALL_BENCHES=()
for p in "${ALL_BENCH_DIRS[@]}"; do
  [[ -z "$p" ]] && continue
  ALL_BENCHES+=("$(basename "$p")")
done

if [[ "${LIST_ONLY:-0}" -eq 1 ]]; then
  echo "Available benchmarks in $BENCH_DIR:"
  for b in "${ALL_BENCHES[@]}"; do echo "  - $b"; done
  exit 0
fi

# selection
SELECTED=()
if (( SELECT_ALL )); then
  SELECTED=("${ALL_BENCHES[@]}")
elif ((${#EXPLICIT_BENCHES[@]})); then
  # accept spaces inside --bench and positional items; split any with whitespace
  TMP=()
  for x in "${EXPLICIT_BENCHES[@]}"; do
    for y in $x; do TMP+=("$y"); done
  done
  # de-dup while preserving order
  declare -A seen=()
  for b in "${TMP[@]}"; do
    if [[ -n "${seen[$b]:-}" ]]; then continue; fi
    seen[$b]=1
    SELECTED+=("$b")
  done
else
  echo "ERROR: choose benchmarks with --all or --bench name1[,name2...] (or positional names)." >&2
  exit 2
fi

# validate selected exist
VALID=()
MISSING=()
for b in "${SELECTED[@]}"; do
  if [[ -d "$BENCH_DIR/$b" ]]; then
    VALID+=("$b")
  else
    MISSING+=("$b")
  fi
done
if ((${#MISSING[@]})); then
  echo "WARNING: missing benchmark dirs (skipping): ${MISSING[*]}" >&2
fi
if ((${#VALID[@]}==0)); then
  echo "ERROR: no valid benchmarks to run." >&2
  exit 1
fi

# --- results root and aggregate dir ---
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
RESULTS_ROOT="${OUT_DIR:-$REPO_ROOT/results}"
AGG_DIR="$RESULTS_ROOT/$TIMESTAMP"
if (( DRY_RUN )); then
  echo "DRY-RUN: would create results dir: $AGG_DIR"
else
  mkdir -p "$AGG_DIR"
fi

# choose copy tool
COPY_TOOL="cp"
if command -v rsync >/dev/null 2>&1; then
  COPY_TOOL="rsync"
fi

# trackers
declare -a OK_LIST=()
declare -a FAIL_LIST=()

echo "==> Benchmarks root: $BENCH_DIR"
echo "==> Results aggregate: $AGG_DIR"
echo "==> Selected: ${VALID[*]}"
echo "==> Repeat: $REPEAT"

# --- run loop ---
for b in "${VALID[@]}"; do
  BENCH_PATH="$BENCH_DIR/$b"
  RUN_SH="$BENCH_PATH/run.sh"
  BENCH_RESULTS="$BENCH_PATH/results"

  if [[ ! -f "$RUN_SH" ]]; then
    echo "--> [$b] No run.sh found. Skipping."
    FAIL_LIST+=("$b (no run.sh)")
    (( STOP_ON_ERROR )) && { echo "Stopping due to --stop-on-error."; break; }
    continue
  fi

  for ((i=1; i<=REPEAT; i++)); do
    printf "\n--> [%s] Run %03d/%03d\n" "$b" "$i" "$REPEAT"

    if (( DRY_RUN )); then
      echo "DRY-RUN: bash \"$RUN_SH\""
    else
      if ! bash "$RUN_SH"; then
        echo "<-- [$b] Run $i FAILED" >&2
        FAIL_LIST+=("$b (run $i)")
        (( STOP_ON_ERROR )) && { echo "Stopping due to --stop-on-error."; break 2; }
        # continue to next run/bench
        continue
      fi
    fi

    # aggregate copy
    DEST="$AGG_DIR/$b/run-$(printf '%03d' "$i")"
    if (( DRY_RUN )); then
      echo "DRY-RUN: would aggregate from \"$BENCH_RESULTS\" to \"$DEST\""
    else
      mkdir -p "$DEST"
      if [[ -d "$BENCH_RESULTS" ]]; then
        if [[ "$COPY_TOOL" == "rsync" ]]; then
          rsync -a --delete "$BENCH_RESULTS"/ "$DEST"/
        else
          # cp fallback; no --delete equivalent
          cp -a "$BENCH_RESULTS"/. "$DEST"/ 2>/dev/null || true
        fi
      else
        echo "NOTE: [$b] results dir not found at '$BENCH_RESULTS' (benchmark may not produce files)." >&2
      fi
    fi
  done

  # if we got here without failing all repeats, mark as OK
  OK_LIST+=("$b")
done

# --- write summary file ---
if (( DRY_RUN )); then
  echo "DRY-RUN: would write summary to $AGG_DIR/summary.txt"
else
  {
    echo "Run date: $(date -Iseconds)"
    echo "Repo root: $REPO_ROOT"
    echo "Bench root: $BENCH_DIR"
    echo "Repeat: $REPEAT"
    echo "Selected: ${VALID[*]}"
    echo ""
    echo "Succeeded: ${OK_LIST[*]}"
    echo "Failed: ${FAIL_LIST[*]}"
  } > "$AGG_DIR/summary.txt"
fi

# --- final summary ---
echo ""
echo "================== Summary =================="
echo "Aggregate dir: $AGG_DIR"
echo "Succeeded: ${#OK_LIST[@]}"
((${#OK_LIST[@]})) && printf '  - %s\n' "${OK_LIST[@]}"
echo "Failed: ${#FAIL_LIST[@]}"
((${#FAIL_LIST[@]})) && printf '  - %s\n' "${FAIL_LIST[@]}"
echo "============================================="

# exit code: 1 if any failures
(( ${#FAIL_LIST[@]} )) && exit 1 || exit 0

