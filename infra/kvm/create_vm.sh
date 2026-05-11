#!/usr/bin/env bash
set -euo pipefail

VM_NAME="ubuntu24-study"
IMG_DIR="/var/lib/libvirt/images"
BASE_IMG="./ubuntu24.qcow2"
CLOUD_DIR="./cloud-init"
DISK_SIZE="40G"  # Definindo o tamanho mínimo solicitado
CLOUD_IMG_URL="${CLOUD_IMG_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"

install_dependencies() {
  echo "Verificando dependencias..."
  DEPS=(curl qemu-system-x86 libvirt-daemon-system libvirt-clients virtinst cloud-image-utils)
  for dep in "${DEPS[@]}"; do
    dpkg -s "$dep" >/dev/null 2>&1 || sudo apt install -y "$dep"
  done
}

install_dependencies

VCPUS="${1:-2}"
RAM_MB="${2:-4096}"
OPTIMIZED=false

for arg in "$@"; do
  [[ "$arg" == "-optimized" ]] && OPTIMIZED=true
done

if [[ ! -f "$BASE_IMG" ]]; then
  echo "Baixando imagem base..."
  TMP_IMG=$(mktemp)
  curl -L --fail -o "$TMP_IMG" "$CLOUD_IMG_URL"
  qemu-img convert -O qcow2 "$TMP_IMG" "$BASE_IMG"
  rm -f "$TMP_IMG"
fi

mkdir -p "$CLOUD_DIR"
touch "$CLOUD_DIR/meta-data"

echo "Gerando seed ISO..."
cloud-localds "$CLOUD_DIR/seed.iso" "$CLOUD_DIR/user-data" "$CLOUD_DIR/meta-data"

echo "Preparando disco de $DISK_SIZE..."
sudo cp "$BASE_IMG" "$IMG_DIR/${VM_NAME}.qcow2"
# Redimensiona o arquivo de disco antes de criar a VM
sudo qemu-img resize "$IMG_DIR/${VM_NAME}.qcow2" "$DISK_SIZE"
sudo cp "$CLOUD_DIR/seed.iso" "$IMG_DIR/${VM_NAME}-seed.iso"

if [ "$OPTIMIZED" = true ]; then
  CPU_OPTS="host-passthrough,cache.mode=passthrough"
  DISK_OPTS="path=${IMG_DIR}/${VM_NAME}.qcow2,format=qcow2,bus=virtio,cache=none,io=native"
else
  CPU_OPTS="host-model"
  DISK_OPTS="path=${IMG_DIR}/${VM_NAME}.qcow2,format=qcow2,bus=virtio"
fi

sudo virt-install \
  --name "$VM_NAME" \
  --ram "$RAM_MB" \
  --vcpus "$VCPUS" \
  --cpu "$CPU_OPTS" \
  --disk "$DISK_OPTS" \
  --disk path=${IMG_DIR}/${VM_NAME}-seed.iso,device=cdrom \
  --os-variant ubuntu24.04 \
  --network network=default,model=virtio \
  --import \
  --graphics none \
  --noautoconsole \
  --check all=off

echo "VM $VM_NAME pronta com $DISK_SIZE de disco."
