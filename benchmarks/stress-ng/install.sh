#!/usr/bin/env bash
set -euo pipefail

echo "==> Updating package list..."
sudo apt update -y

echo "==> Installing build dependencies for stress-ng..."
sudo apt install -y \
    build-essential \
    make \
    gcc \
    git \
    pkg-config \
    libaio-dev \
    libattr1-dev \
    libbsd-dev \
    libcap-dev \
    libgcrypt20-dev \
    libkeyutils-dev \
    libncurses5-dev \
    libnuma-dev \
    libsensors-dev \
    libssl-dev \
    zlib1g-dev \
    python3 \
    python3-pip

echo
echo "✅ Dependencies installed successfully."
echo "You can now build stress-ng using: ./build.sh"

