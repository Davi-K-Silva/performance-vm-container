#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/content"

RESULTS_DIR="${SCRIPT_DIR}/results"
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${RESULTS_DIR}/linpack_${TIMESTAMP}.out"

echo "==> Running LINPACK benchmark..."
./linpackd > "$OUTPUT_FILE" 2>&1
echo "==> Results saved to: $OUTPUT_FILE"
