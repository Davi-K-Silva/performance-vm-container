#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

CONTAINER_NAME="iperf-lxc-on-demand"
IMAGE_NAME="ubuntu:24.04"

# Step 1: Launch the LXC container (creates and starts)
echo "Launching container '$CONTAINER_NAME' from $IMAGE_NAME..."
# We check if the container already exists. If not, launch it.
if ! lxc list -c n --format csv | grep -q "^$CONTAINER_NAME$"; then
    lxc launch $IMAGE_NAME $CONTAINER_NAME
else
    echo "Container '$CONTAINER_NAME' already exists. Starting it..."
    lxc start $CONTAINER_NAME
fi

# Step 2: Wait for the container's network to be ready
echo "Waiting for container network to be online..."
while ! lxc exec $CONTAINER_NAME -- /bin/bash -c "systemctl is-active network-online.target | grep -q 'active'"; do
    echo "Waiting for network..."
    sleep 2
done
echo "Container network is ready."

# Step 3: Update package lists inside the container
echo "Updating package lists in container..."
# The '--' separates lxc exec options from the command to be run
lxc exec $CONTAINER_NAME -- apt-get update

# Step 4: Install iperf3 inside the container
echo "Installing iperf3 in container..."
lxc exec $CONTAINER_NAME -- apt-get install -y iperf3

# Step 5: Set up port forwarding (proxy)
# This maps host ports 5201 (TCP/UDP) to the container's ports
echo "Setting up port forwarding..."

# Remove existing devices if they exist, to avoid errors on re-run
lxc config device remove $CONTAINER_NAME iperf-tcp 2>/dev/null || true
lxc config device remove $CONTAINER_NAME iperf-udp 2>/dev/null || true

# Add the proxy devices
lxc config device add $CONTAINER_NAME iperf-tcp proxy listen=tcp:0.0.0.0:5201 connect=tcp:127.0.0.1:5201
lxc config device add $CONTAINER_NAME iperf-udp proxy listen=udp:0.0.0.0:5201 connect=udp:127.0.0.1:5201

# Step 6: Run the iperf3 server
echo "Starting iperf3 server inside the container..."
echo "You can now connect to this server from another machine using: iperf3 -c <server-ip>"
echo "Press Ctrl+C to stop the server."
lxc exec $CONTAINER_NAME -- iperf3 -s

