#!/usr/bin/env bash
set -euo pipefail

# STREAM often uses large local arrays; avoid stack overflows
# The unlimited stack is crucial to prevent core dumps
ulimit -s unlimited || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/content"

RESULTS_DIR="${SCRIPT_DIR}/results"
mkdir -p "$RESULTS_DIR"

# Default: use all CPUs unless OMP_NUM_THREADS is already set
if [[ -z "${OMP_NUM_THREADS:-}" ]]; then
  if command -v nproc >/dev/null 2>&1; then
    export OMP_NUM_THREADS="$(nproc)"
  else
    export OMP_NUM_THREADS=1
  fi
fi

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
OUTFILE="${RESULTS_DIR}/stream_${TIMESTAMP}.out"

echo "==> Running STREAM (Fortran) with OMP_NUM_THREADS=${OMP_NUM_THREADS}"
./streamf > "$OUTFILE" 2>&1

echo "==> Results saved to: $OUTFILE"

