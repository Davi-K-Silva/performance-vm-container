#!/bin/bash
# Script to run iperf3 benchmarks 10 times.
# It starts the iperf3 server INSIDE each environment (LXC, Docker, Podman, KVM, Native)
# and runs the iperf3 client from the BARE METAL host against it.
#
# Make sure your 'vmubuntu' alias is defined in this shell
# and that 'run_iperf_client.sh' is in the CLIENT_SCRIPT_PATH.

set -euo pipefail

# --- Configuration ---
ITERATIONS=10
TEST_DURATION=60       # Duration for each iperf3 test in seconds
PARALLEL_STREAMS=4   # Number of parallel streams for iperf3

# Path to the client script (the second file you provided, modified)
CLIENT_SCRIPT_PATH="run_iperf_client.sh"

# Main directory to store all results
MAIN_RESULTS_DIR="~/performance-vm-container/results/iperf_$(date +"%Y%m%d_%H%M%S")"
mkdir -p "$MAIN_RESULTS_DIR"

# --- Environment Names ---
LXC_CONTAINER="lxc-container"
DOCKER_CONTAINER="iperf-on-demand"
PODMAN_CONTAINER="iperf-on-demand"
KVM_VM="ubuntu24"

# !!! IMPORTANT !!!
# You must set the IP address for your KVM VM here.
# This script cannot easily guess it.
KVM_IP="192.168.122.158" # <--- SET THIS TO YOUR VM's IP

# Ensure client script is executable
chmod +x "$CLIENT_SCRIPT_PATH"

echo "Running iperf3 benchmarks for $ITERATIONS iterations..."
echo "Results will be saved in: $MAIN_RESULTS_DIR"

for ((i=1; i<=ITERATIONS; i++)); do
    echo
    echo "=========== Iteration $i/$ITERATIONS ==========="
    ITER_RESULTS_DIR="$MAIN_RESULTS_DIR/iter_$i"
    mkdir -p "$ITER_RESULTS_DIR"

    # --- Native (Bare Metal) ---
    echo "--- Running Native (127.0.0.1) benchmark... ---"
    NATIVE_RESULTS_DIR="$ITER_RESULTS_DIR/native"
    mkdir -p "$NATIVE_RESULTS_DIR"
    "$CLIENT_SCRIPT_PATH" "127.0.0.1" "$TEST_DURATION" "$PARALLEL_STREAMS" "$NATIVE_RESULTS_DIR"
    echo "Finished Native benchmark."
    sleep 2

    # --- LXC container ---
    echo "--- Running LXC ($LXC_CONTAINER) benchmark... ---"
    LXC_RESULTS_DIR="$ITER_RESULTS_DIR/lxc"
    mkdir -p "$LXC_RESULTS_DIR"
    lxc start "$LXC_CONTAINER"
    sleep 5 # wait for container to start
    LXC_IP=$(lxc info "$LXC_CONTAINER" | grep 'eth0:' -A 1 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 || true)
    if [ -z "$LXC_IP" ]; then
        echo "ERROR: Could not get LXC IP. Skipping."
    else
        echo "LXC IP: $LXC_IP"
        lxc exec "$LXC_CONTAINER" -- iperf3 -s -D
        sleep 2 # wait for server to start
        "$CLIENT_SCRIPT_PATH" "$LXC_IP" "$TEST_DURATION" "$PARALLEL_STREAMS" "$LXC_RESULTS_DIR"
        lxc exec "$LXC_CONTAINER" -- pkill iperf3 || true
    fi
    lxc stop "$LXC_CONTAINER"
    echo "Finished LXC benchmark."
    sleep 2

    # --- Docker container ---
    echo "--- Running Docker ($DOCKER_CONTAINER) benchmark... ---"
    DOCKER_RESULTS_DIR="$ITER_RESULTS_DIR/docker"
    mkdir -p "$DOCKER_RESULTS_DIR"
    docker start "$DOCKER_CONTAINER"
    sleep 3
    DOCKER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DOCKER_CONTAINER" || true)
     if [ -z "$DOCKER_IP" ]; then
        echo "ERROR: Could not get Docker IP. Skipping."
    else
        echo "Docker IP: $DOCKER_IP"
        docker exec "$DOCKER_CONTAINER" iperf3 -s -D
        sleep 2
        "$CLIENT_SCRIPT_PATH" "$DOCKER_IP" "$TEST_DURATION" "$PARALLEL_STREAMS" "$DOCKER_RESULTS_DIR"
        docker exec "$DOCKER_CONTAINER" pkill iperf3 || true
    fi
    docker stop "$DOCKER_CONTAINER"
    echo "Finished Docker benchmark."
    sleep 2

    # --- Podman container ---
    echo "--- Running Podman ($PODMAN_CONTAINER) benchmark... ---"
    PODMAN_RESULTS_DIR="$ITER_RESULTS_DIR/podman"
    mkdir -p "$PODMAN_RESULTS_DIR"
    podman start "$PODMAN_CONTAINER"
    sleep 3
    # Use simpler query for rootful podman
    PODMAN_IP=$(podman inspect -f '{{.NetworkSettings.IPAddress}}' "$PODMAN_CONTAINER" || true)
     if [ -z "$PODMAN_IP" ]; then
        echo "ERROR: Could not get Podman IP. Skipping."
    else
        echo "Podman IP: $PODMAN_IP"
        podman exec "$PODMAN_CONTAINER" iperf3 -s -D
        sleep 2
        "$CLIENT_SCRIPT_PATH" "$PODMAN_IP" "$TEST_DURATION" "$PARALLEL_STREAMS" "$PODMAN_RESULTS_DIR"
        podman exec "$PODMAN_CONTAINER" pkill iperf3 || true
    fi
    podman stop "$PODMAN_CONTAINER"
    echo "Finished Podman benchmark."
    sleep 2

    # --- KVM VM ---
    echo "--- Running KVM ($KVM_VM) benchmark... ---"
    KVM_RESULTS_DIR="$ITER_RESULTS_DIR/kvm"
    mkdir -p "$KVM_RESULTS_DIR"
    if [ -z "$KVM_IP" ]; then
        echo "ERROR: KVM_IP variable is not set in the script. Skipping."
    else
        echo "KVM IP: $KVM_IP (Using pre-configured IP)"
        virsh start "$KVM_VM"
        echo "Waiting 15s for KVM VM to boot..."
        sleep 15
        # Assuming 'vmubuntu' is an SSH alias like 'ssh user@$KVM_IP'
        vmubuntu "iperf3 -s -D"
        sleep 2
        "$CLIENT_SCRIPT_PATH" "$KVM_IP" "$TEST_DURATION" "$PARALLEL_STREAMS" "$KVM_RESULTS_DIR"
        vmubuntu "pkill iperf3" || true
        virsh shutdown "$KVM_VM"
        echo "Waiting for KVM to shut down..."
        # Wait until the VM is no longer in the running list
        while virsh list --state-running | grep -q " $KVM_VM "; do
            sleep 2
        done
    fi
    echo "Finished KVM benchmark."

done

echo
echo "==============================="
echo "All benchmarks complete."
echo "Results are in $MAIN_RESULTS_DIR"
