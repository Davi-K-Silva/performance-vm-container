#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/content"

RESULTS_DIR="${SCRIPT_DIR}/results"
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${RESULTS_DIR}/fio_${TIMESTAMP}.out"

echo "==> Running FIO benchmark..."

# Example benchmark — sequential read & write test
fio --name=storage_test \
    --rw=randrw \
    --rwmixread=70 \
    --bs=4k \
    --size=2G \
    --numjobs=4 \
    --runtime=60 \
    --time_based \
    --filename=fio_testfile \
    --group_reporting > "$OUTPUT_FILE" 2>&1

# Removing testfile
rm fio_testfile

echo "==> Results saved to: $OUTPUT_FILE"

