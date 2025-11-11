#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if container runtime is provided (docker or podman)
if [ -z "$1" ]; then
    echo "Usage: $0 [docker|podman]"
    exit 1
fi

CONTAINER_RUNTIME=$1
CONTAINER_NAME="iperf-on-demand"
IMAGE_NAME="ubuntu:24.04"

# Step 1: Create the container
# -p 5201:5201/tcp and -p 5201:5201/udp map the ports for iperf3
echo "Creating container '$CONTAINER_NAME' using $CONTAINER_RUNTIME..."
$CONTAINER_RUNTIME create --name $CONTAINER_NAME \
  -p 5201:5201/tcp \
  -p 5201:5201/udp \
  $IMAGE_NAME \
  sleep infinity

# Step 2: Start the container
echo "Starting container '$CONTAINER_NAME'..."
$CONTAINER_RUNTIME start $CONTAINER_NAME

# Step 3: Update package lists inside the container
echo "Updating package lists in container..."
$CONTAINER_RUNTIME exec $CONTAINER_NAME apt-get update

# Step 4: Install iperf3 inside the container
# The -y flag automatically answers "yes" to prompts
echo "Installing iperf3 in container..."
$CONTAINER_RUNTIME exec $CONTAINER_NAME apt-get install -y iperf3

# Step 5: Run the iperf3 server
# -it attaches an interactive terminal
# -s runs iperf3 in server mode
echo "Starting iperf3 server inside the container..."
echo "You can now connect to this server from another machine using: iperf3 -c <server-ip>"
echo "Press Ctrl+C to stop the server."
$CONTAINER_RUNTIME exec -it $CONTAINER_NAME iperf3 -s


