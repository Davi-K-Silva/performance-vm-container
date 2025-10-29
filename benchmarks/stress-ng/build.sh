#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/content"

echo "==> Building stress-ng..."
make
sudo make install
echo "==> stress-ng successfully built and installed!"

