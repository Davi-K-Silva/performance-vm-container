#!/usr/bin/env bash
set -euo pipefail
echo "==> Installing dependencies for LINPACK (Fortran)..."

# Ensure compilers are installed
sudo apt-get update -y
sudo apt-get install -y gfortran make
echo "==> Dependencies installed."
