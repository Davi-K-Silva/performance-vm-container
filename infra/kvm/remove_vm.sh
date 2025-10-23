#!/usr/bin/env bash
set -euo pipefail

VM_NAME="ubuntu24"
IMG_DIR="/var/lib/libvirt/images"

# Stop VM if running
if sudo virsh list --name | grep -q "^${VM_NAME}$"; then
  sudo virsh destroy "$VM_NAME"
fi

# Remove definition
if sudo virsh list --all --name | grep -q "^${VM_NAME}$"; then
  sudo virsh undefine "$VM_NAME"
fi

# Delete storage
sudo rm -f "${IMG_DIR}/${VM_NAME}.qcow2"
sudo rm -f "${IMG_DIR}/${VM_NAME}-seed.iso"

echo "VM $VM_NAME removed completely."

