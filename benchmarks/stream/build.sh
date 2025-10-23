#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/content"

echo "==> Building STREAM (Fortran)..."
make clean || true

# To enable OpenMP, you can run: USE_OMP=1 ./build.sh
if [[ "${USE_OMP:-0}" == "1" ]]; then
  echo "==> Compiling with OpenMP enabled"
  make USE_OMP=1
else
  make
fi

echo "==> Build complete."

