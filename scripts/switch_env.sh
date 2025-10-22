#!/usr/bin/env bash
# switch_env.sh — stop all envs (KVM/libvirt, Docker, Podman, LXD) and start only one
set -euo pipefail

# --- helpers ---
SUDO='' ; [[ $(id -u) -ne 0 ]] && SUDO='sudo'

log(){ printf "\033[1;36m==>\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m!!\033[0m %s\n" "$*"; }
err(){ printf "\033[1;31m**\033[0m %s\n" "$*"; }

have(){ command -v "$1" >/dev/null 2>&1; }

# --- Stop functions (idempotent) ---
stop_kvm(){
  if have virsh; then
    log "Stopping running libvirt domains…"
    while read -r vm; do
      [[ -z "$vm" ]] && continue
      warn "Destroying VM: $vm"
      $SUDO virsh --connect qemu:///system destroy "$vm" >/dev/null 2>&1 || true
      $SUDO virsh --connect qemu:///system shutdown "$vm" >/dev/null 2>&1 || true
    done < <($SUDO virsh --connect qemu:///system list --state-running --name 2>/dev/null || true)
  fi
  # Stop services (names vary by distro)
  for svc in libvirtd virtlogd; do
    $SUDO systemctl stop "$svc" 2>/dev/null || true
  done
}

stop_docker(){
  # If docker CLI isn't present, nothing to do.
  have docker || return 0

  log "Stopping Docker containers (if docker is running)…"

  # Only try to stop containers if the daemon is reachable
  if docker info >/dev/null 2>&1; then
    # Collect IDs safely (won't crash with pipefail)
    mapfile -t _ids < <(docker ps -q 2>/dev/null || true)
    if [[ ${#_ids[@]} -gt 0 ]]; then
      docker stop "${_ids[@]}" >/dev/null 2>&1 || true
    fi
  fi

  # Stop services quietly if present (no error if already stopped)
  $SUDO systemctl stop docker.socket 2>/dev/null || true
  $SUDO systemctl stop docker         2>/dev/null || true
}

stop_podman(){
  if have podman; then
    log "Stopping Podman containers & pods (rootless if present)…"
    # Try user session first (won’t fail the script on headless)
    systemctl --user stop podman.socket 2>/dev/null || true
    podman pod stop -a >/dev/null 2>&1 || true
    podman stop -a >/dev/null 2>&1 || true

    # Also handle root-managed pods/containers
    $SUDO podman pod stop -a >/dev/null 2>&1 || true
    $SUDO podman stop -a >/dev/null 2>&1 || true
  fi
  # Stop sockets/services (both user and system scopes)
  $SUDO systemctl stop podman.socket podman 2>/dev/null || true
}

stop_lxd(){
  if have lxc; then
    log "Stopping LXD instances…"
    lxc stop --all --timeout 30 >/dev/null 2>&1 || true
  fi
  # Service names: snap.lxd.daemon (snap) or lxd (pkg)
  $SUDO systemctl stop snap.lxd.daemon 2>/dev/null || true
  $SUDO systemctl stop lxd 2>/dev/null || true
}

stop_all(){
  log "Stopping ALL environments…"
  stop_kvm
  stop_docker
  stop_podman
  stop_lxd
}

# --- Start functions ---
start_kvm(){
  log "Starting libvirt (KVM)…"
  $SUDO systemctl start virtlogd 2>/dev/null || true
  $SUDO systemctl start libvirtd
}

start_docker(){
  log "Starting Docker…"
  $SUDO systemctl start docker
}

start_podman(){
  log "Starting Podman socket(s)…"
  # Start root socket (useful for system services)
  $SUDO systemctl start podman.socket 2>/dev/null || true
  # Try to start user socket if a user session is present
  systemctl --user start podman.socket 2>/dev/null || true
  warn "Note: Podman doesn't require a daemon; this just enables the REST socket."
}

start_lxd(){
  log "Starting LXD…"
  $SUDO systemctl start snap.lxd.daemon 2>/dev/null || true
  $SUDO systemctl start lxd 2>/dev/null || true
}

# --- Status (quick view) ---
status(){
  echo ""
  echo "Service status (active=running):"
  for svc in libvirtd virtlogd docker podman podman.socket snap.lxd.daemon lxd; do
    $SUDO systemctl is-active "$svc" >/dev/null 2>&1 \
      && printf "  %-18s : active\n" "$svc" \
      || printf "  %-18s : inactive\n" "$svc"
  done
  echo ""
  have virsh  && { echo "[KVM] running domains:"; $SUDO virsh --connect qemu:///system list 2>/dev/null || true; echo ""; }
  have docker && { echo "[Docker] running containers:"; docker ps || true; echo ""; }
  have podman && { echo "[Podman] running containers:"; podman ps || true; echo ""; }
  have lxc    && { echo "[LXD] running instances:"; lxc list --format table || true; echo ""; }
}

# --- Main ---
usage(){
  cat <<EOF
Usage: $0 <kvm|docker|podman|lxd|none|status>

  kvm     Stop everything, then start libvirt/KVM only
  docker  Stop everything, then start Docker only
  podman  Stop everything, then start Podman socket only
  lxd     Stop everything, then start LXD only
  none    Stop everything and leave all stacks down
  status  Show quick status for all stacks

Examples:
  $0 docker
  $0 none
  $0 status
EOF
}

choice="${1:-}"
case "$choice" in
  kvm)
    stop_all
    start_kvm
    ;;
  docker)
    stop_all
    start_docker
    ;;
  podman)
    stop_all
    start_podman
    ;;
  lxd)
    stop_all
    start_lxd
    ;;
  none)
    stop_all
    ;;
  status)
    status
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
esac

log "Done. Current status:"
status

