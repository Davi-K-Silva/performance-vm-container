#!/usr/bin/env bash
set -euo pipefail

echo "==> Building FIO"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/content"

echo "==> Running make..."
make -j"$(nproc)"

echo "==> Installing FIO system-wide..."
sudo make install

echo "==> FIO successfully built and installed!"
fio --version

