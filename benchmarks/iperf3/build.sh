#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/content"

echo "==> Building iperf3 from source..."

# Configure, build, and install
./configure
make
sudo make install

echo "==> Registering /usr/local/lib for iperf3 shared library..."
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/iperf3.conf >/dev/null
sudo ldconfig

echo "==> Verifying library installation..."
if ldconfig -p | grep -q libiperf; then
  echo "✅ libiperf.so found and registered successfully."
else
  echo "⚠️  Warning: libiperf.so not found in linker cache!"
fi

echo "==> iperf3 build and setup completed!"

