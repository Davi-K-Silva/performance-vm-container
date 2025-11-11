#!/usr/bin/env bash
set -euo pipefail
echo "==> Installing dependencies for MLperf..."

# Ensure compilers are installed
sudo apt-get update -y
sudo apt-get install -y git python3 python3-pip python3-venv

python3 -m venv mlc
source mlc/bin/activate
pip install --no-input mlc-scripts

mlc pull repo mlcommons@mlperf-automations
export MLC_SCRIPT_EXTRA_CMD="--adr.python.name=mlperf" 
mlcr install,python-venv --name=mlperf

mlcr get,dataset,original,imagenet,_full
mlcr get,dataset-aux,imagenet-aux
mlcr get,ml-model,resnet50,_fp32,_onnx,_opset-8

echo "==> Dependencies installed."
