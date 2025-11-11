#!/bin/bash
# Script to run benchmarks 10 times on LXC, Docker/Podman, and KVM VM
# Make sure your 'vmubuntu' alias is defined in this shell

# Paths
SCRIPT_PATH="~/performance-vm-container/scripts/run_master.sh --bench fio stream linpack"
ITERATIONS=10

# --- LXC container ---
LXC_CONTAINER="lxc-container"
echo "Running benchmark on LXC container ($ITERATIONS iterations)..."
for ((i=1; i<=ITERATIONS; i++)); do
    echo "--- LXC Iteration $i/$ITERATIONS ---"
    lxc start "$LXC_CONTAINER"
    sleep 5  # wait for container to start
    lxc exec "$LXC_CONTAINER" -- bash -c "$SCRIPT_PATH"
    lxc stop "$LXC_CONTAINER"
done
echo "Finished LXC benchmark."
echo "-------------------------"

# --- Docker container ---
DOCKER_CONTAINER="iperf-on-demand"
echo "Running benchmark on Docker container ($ITERATIONS iterations)..."
for ((i=1; i<=ITERATIONS; i++)); do
    echo "--- Docker Iteration $i/$ITERATIONS ---"
    docker start "$DOCKER_CONTAINER"
    sleep 3
    docker exec "$DOCKER_CONTAINER" bash -c "$SCRIPT_PATH"
    docker stop "$DOCKER_CONTAINER"
done
echo "Finished Docker benchmark."
echo "-------------------------"

# --- Podman container ---
PODMAN_CONTAINER="iperf-on-demand"
echo "Running benchmark on Podman container ($ITERATIONS iterations)..."
for ((i=1; i<=ITERATIONS; i++)); do
    echo "--- Podman Iteration $i/$ITERATIONS ---"
    podman start "$PODMAN_CONTAINER"
    sleep 3
    podman exec "$PODMAN_CONTAINER" bash -c "$SCRIPT_PATH"
    podman stop "$PODMAN_CONTAINER"
done
echo "Finished Podman benchmark."
echo "-------------------------"

# --- KVM VM ---
KVM_VM="ubuntu24"
echo "Running benchmark on KVM VM ($ITERATIONS iterations)..."
for ((i=1; i<=ITERATIONS; i++)); do
    echo "--- KVM Iteration $i/$ITERATIONS ---"
    virsh start "$KVM_VM"
    sleep 10  # wait for VM to boot
    vmubuntu "$SCRIPT_PATH"
    virsh shutdown "$KVM_VM"
done
echo "Finished KVM benchmark."
echo "-------------------------"

echo "All benchmarks done."
