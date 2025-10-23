#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create_vm.sh [vcpus] [ram_MB]
# Example: ./create_vm.sh 4 8192

VM_NAME="ubuntu24"
IMG_DIR="/var/lib/libvirt/images"
BASE_IMG="./ubuntu24.qcow2"
CLOUD_DIR="./cloud-init"

# Parameters (defaults if empty)
VCPUS="${1:-2}"
RAM_MB="${2:-4096}"

echo "VM configuration:"
echo "  Name:  $VM_NAME"
echo "  vCPUs: $VCPUS"
echo "  RAM:   ${RAM_MB} MB"

# Check for required cloud-init files
if [[ ! -f "$CLOUD_DIR/user-data" ]]; then
  echo "Missing file: $CLOUD_DIR/user-data"
  exit 1
fi

if [[ ! -f "$CLOUD_DIR/meta-data" ]]; then
  echo "Missing file: $CLOUD_DIR/meta-data"
  exit 1
fi

# Generate seed ISO
cloud-localds "$CLOUD_DIR/seed.iso" "$CLOUD_DIR/user-data" "$CLOUD_DIR/meta-data"

# Copy base image and seed ISO to libvirt images directory
sudo cp "$BASE_IMG" "$IMG_DIR/${VM_NAME}.qcow2"
sudo cp "$CLOUD_DIR/seed.iso" "$IMG_DIR/${VM_NAME}-seed.iso"

# Run virt-install
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

# Poll for IP
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


