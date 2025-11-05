#!/usr/bin/env bash
set -euo pipefail
echo "==> Installing dependencies for FIO benchmark (no fio itself)..."

sudo apt-get update -y
sudo apt-get install -y \
  make \
  gcc \
  libaio-dev \
  zlib1g-dev \
  libnuma-dev \
  libssl-dev \
  libibverbs-dev \
  pkg-config \
  git

echo "==> Dependencies installed successfully."

