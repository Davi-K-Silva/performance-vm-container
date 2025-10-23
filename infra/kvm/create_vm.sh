#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create_vm.sh [vcpus] [ram_MB]
# Example: ./create_vm.sh 4 8192

VM_NAME="ubuntu24"
IMG_DIR="/var/lib/libvirt/images"

# Local base image path (qcow2). If it doesn't exist, we'll fetch and convert it.
BASE_IMG="./ubuntu24.qcow2"

# Cloud-init files dir (must contain user-data and meta-data)
CLOUD_DIR="./cloud-init"

# Parameters (defaults if empty)
VCPUS="${1:-2}"
RAM_MB="${2:-4096}"

# You can override the source image via env var if you want a different build/arch.
# Default is Ubuntu 24.04 LTS (Noble) amd64 cloud image.
CLOUD_IMG_URL="${CLOUD_IMG_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"

echo "VM configuration:"
echo "  Name:    $VM_NAME"
echo "  vCPUs:   $VCPUS"
echo "  RAM:     ${RAM_MB} MB"
echo "  Base QCOW2: $BASE_IMG"
echo "  Cloud image URL (fallback): $CLOUD_IMG_URL"

# --- Check required tools ---
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }
need_cmd curl
need_cmd qemu-img
need_cmd cloud-localds
need_cmd sudo
need_cmd virt-install
need_cmd virsh

# --- Ensure base image exists or download/convert it ---
if [[ ! -f "$BASE_IMG" ]]; then
  echo "Base image '$BASE_IMG' not found. Downloading cloud image..."
  TMP_IMG="$(mktemp)"
  # Download (follow redirects, fail on HTTP errors)
  curl -L --fail -o "$TMP_IMG" "$CLOUD_IMG_URL"

  echo "Converting downloaded image to qcow2: $BASE_IMG"
  # Convert to qcow2 regardless of source format
  qemu-img convert -O qcow2 "$TMP_IMG" "$BASE_IMG"
  rm -f "$TMP_IMG"

  # Optional: show info
  echo "Base image ready:"
  qemu-img info "$BASE_IMG" || true
fi

# --- Check for required cloud-init files ---
if [[ ! -f "$CLOUD_DIR/user-data" ]]; then
  echo "Missing file: $CLOUD_DIR/user-data"
  exit 1
fi

if [[ ! -f "$CLOUD_DIR/meta-data" ]]; then
  echo "Missing file: $CLOUD_DIR/meta-data"
  exit 1
fi

# --- Generate seed ISO ---
echo "Generating cloud-init seed ISO..."
cloud-localds "$CLOUD_DIR/seed.iso" "$CLOUD_DIR/user-data" "$CLOUD_DIR/meta-data"

# --- Copy base image and seed ISO to libvirt images directory ---
echo "Copying images to $IMG_DIR ..."
sudo cp "$BASE_IMG" "$IMG_DIR/${VM_NAME}.qcow2"
sudo cp "$CLOUD_DIR/seed.iso" "$IMG_DIR/${VM_NAME}-seed.iso"

# --- Run virt-install ---
echo "Creating VM with virt-install..."
sudo virt-install \
  --name "$VM_NAME" \
  --ram "$RAM_MB" \
  --vcpus "$VCPUS" \
  --disk path=${IMG_DIR}/${VM_NAME}.qcow2,format=qcow2 \
  --disk path=${IMG_DIR}/${VM_NAME}-seed.iso,device=cdrom \
  --os-variant ubuntu24.04 \
  --network network=default \
  --import \
  --graphics none \
  --noautoconsole 

echo "VM $VM_NAME created successfully with $VCPUS vCPUs and ${RAM_MB} MB RAM."
echo "Waiting for IP address..."

# --- Poll for IP (with or without QEMU guest agent) ---
for i in {1..20}; do
  IP_LINE=$(sudo virsh domifaddr "$VM_NAME" --source agent 2>/dev/null | grep ipv4 || true)
  if [[ -z "$IP_LINE" ]]; then
    IP_LINE=$(sudo virsh domifaddr "$VM_NAME" 2>/dev/null | grep ipv4 || true)
  fi

  if [[ -n "$IP_LINE" ]]; then
    IP=$(echo "$IP_LINE" | awk '{print $4}' | cut -d'/' -f1)
    echo "VM IP address: $IP"
    exit 0
  fi

  sleep 3
done

echo "Could not determine VM IP (network or cloud-init not ready)."
exit 1

