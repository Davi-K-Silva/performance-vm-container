#!/usr/bin/env bash
set -euo pipefail

echo "==> Updating package lists..."
sudo apt update -y

echo "==> Installing iperf3 build dependencies..."

# Core development tools and libraries
sudo apt install -y \
  build-essential \
  make \
  gcc \
  git \
  libssl-dev \
  autoconf \
  automake \
  libtool \
  pkg-config

echo "==> All dependencies for iperf3 successfully installed."

