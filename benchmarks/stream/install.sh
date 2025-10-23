#!/usr/bin/env bash
set -euo pipefail
echo "==> Installing dependencies for STREAM (Fortran)..."

# Basic toolchain
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y gfortran make
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y gcc-gfortran make
elif command -v yum >/dev/null 2>&1; then
  sudo yum install -y gcc-gfortran make
else
  echo "ERROR: Supported package manager not found (apt/dnf/yum). Install gfortran and make manually." >&2
  exit 1
fi

echo "==> Dependencies installed."

