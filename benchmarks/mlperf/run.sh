#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="${SCRIPT_DIR}/results/ressult_${TIMESTAMP}"
mkdir -p "$RESULTS_DIR"
export MLC_MLPERF_RESULTS_DIR=$RESULTS_DIR
MLC_MLPERF_RESULTS_DIR=$RESULTS_DIR

echo "==> Running MLperf benchmark..."

python3 -m venv mlc
source mlc/bin/activate

mlcr run-mlperf,inference,_full,_r5.1-dev,_performance-only \
   --model=resnet50 \
   --implementation=reference \
   --framework=onnxruntime \
   --category=datacenter \
   --scenario=Offline \
   --execution_mode=valid \
   --device=cuda \
   --output_dir=$RESULTS_DIR \
   --quiet

echo "==> Results saved to: $RESULTS_DIR"
