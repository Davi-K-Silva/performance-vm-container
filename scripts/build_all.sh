#!/usr/bin/env bash
# scripts/build_all.sh
#
# Run every benchmarks/*/build.sh that exists.
# Continues on errors and prints a summary.

set -uo pipefail

# --- Options ---
STOP_ON_ERROR=0   # set to 1 to stop on first failure
DRY_RUN=0         # set to 1 to only show what would be executed

print_help() {
  cat <<'EOF'
Usage: scripts/build_all.sh [--stop-on-error] [--dry-run] [--help]

  --stop-on-error   Stop at the first failing build.sh
  --dry-run         Only print what would be executed
  --help            Show this help

Environment:
  BENCH_DIR         Override benchmarks directory (default: <repo>/benchmarks)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --stop-on-error) STOP_ON_ERROR=1 ;;
    --dry-run)       DRY_RUN=1 ;;
    --help|-h)       print_help; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; print_help; exit 2 ;;
  esac
done

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCH_DIR="${BENCH_DIR:-$REPO_ROOT/benchmarks}"

if [[ ! -d "$BENCH_DIR" ]]; then
  echo "ERROR: Benchmarks directory not found: $BENCH_DIR" >&2
  exit 1
fi

echo "==> Benchmarks root: $BENCH_DIR"

# --- Track results ---
declare -a SUCCESS=()
declare -a SKIPPED=()
declare -a FAILED=()

# --- Iterate benchmarks ---
while IFS= read -r -d '' BENCH_PATH; do
  BENCH_NAME="$(basename "$BENCH_PATH")"
  BUILD="$BENCH_PATH/build.sh"

  if [[ -f "$BUILD" ]]; then
    echo ""
    echo "--> [$BENCH_NAME] Found build.sh"

    if (( DRY_RUN )); then
      echo "DRY-RUN: bash \"$BUILD\""
      SKIPPED+=("$BENCH_NAME (dry-run)")
      continue
    fi

    if bash "$BUILD"; then
      echo "<-- [$BENCH_NAME] OK"
      SUCCESS+=("$BENCH_NAME")
    else
      echo "<-- [$BENCH_NAME] FAILED" >&2
      FAILED+=("$BENCH_NAME")
      if (( STOP_ON_ERROR )); then
        echo "Stopping due to --stop-on-error." >&2
        break
      fi
    fi
  else
    SKIPPED+=("$BENCH_NAME")
  fi
done < <(find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

# --- Summary ---
echo ""
echo "================ Summary ================"
printf "Success: %d\n" "${#SUCCESS[@]}"
((${#SUCCESS[@]})) && printf '  - %s\n' "${SUCCESS[@]}"

printf "Skipped (no build.sh or dry-run): %d\n" "${#SKIPPED[@]}"
((${#SKIPPED[@]})) && printf '  - %s\n' "${SKIPPED[@]}"

printf "Failed: %d\n" "${#FAILED[@]}"
((${#FAILED[@]})) && printf '  - %s\n' "${FAILED[@]}"
echo "========================================="
(( ${#FAILED[@]} )) && exit 1 || exit 0

