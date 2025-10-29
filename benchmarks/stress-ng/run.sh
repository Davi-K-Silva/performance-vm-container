#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/content"

RESULTS_DIR="${SCRIPT_DIR}/results"
mkdir -p "$RESULTS_DIR"

# Default: use all CPUs if not set
if [[ -z "${OMP_NUM_THREADS:-}" ]]; then
  if command -v nproc >/dev/null 2>&1; then
    export OMP_NUM_THREADS="$(nproc)"
  else
    export OMP_NUM_THREADS=1
  fi
fi

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
OUTFILE="${RESULTS_DIR}/stressng_${TIMESTAMP}.out"

echo "==> Running stress-ng with ${OMP_NUM_THREADS} CPU workers for 60s..."
stress-ng --cpu "${OMP_NUM_THREADS}" --timeout 60s --metrics-brief > "$OUTFILE" 2>&1

echo "==> Results saved to: $OUTFILE"

