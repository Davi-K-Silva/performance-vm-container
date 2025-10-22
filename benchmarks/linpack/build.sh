#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/content"

echo "==> Building LINPACK benchmark..."
make clean || true
make
echo "==> Build complete."
