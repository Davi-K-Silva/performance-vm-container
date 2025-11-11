#!/usr/bin/env bash
# This script runs the iperf3 CLIENT.
# It is called by 'run_all_benchmarks.sh'
#
# Arguments:
# 1: Server IP
# 2: Test Duration (seconds)
# 3: Parallel Streams
# 4: Base Results Directory

set -euo pipefail

# --- Parameters ---
SERVER_IP="${1:-127.0.0.1}"      # Default to localhost
TEST_DURATION="${2:-60}"         # Default 60 seconds
PARALLEL_STREAMS="${3:-4}"       # Default 4 parallel connections
# Base directory to store results, default to current dir
BASE_RESULTS_DIR="${4:-.}"

mkdir -p "$BASE_RESULTS_DIR"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
OUTFILE="${BASE_RESULTS_DIR}/iperf3_client_${TIMESTAMP}.json"
SERVER_LOG="${BASE_RESULTS_DIR}/iperf3_server_${TIMESTAMP}.log"

echo "  -> Starting iperf3 client test"
echo "     Server:   ${SERVER_IP}"
echo "     Duration: ${TEST_DURATION}s"
echo "     Streams:  ${PARALLEL_STREAMS}"
echo "     Output:   ${OUTFILE}"

# If running locally (Native test), start a background server
SERVER_PID=""
if [[ "$SERVER_IP" == "127.0.0.1" || "$SERVER_IP" == "localhost" ]]; then
  echo "  -> Starting local iperf3 server in background (for native test)..."
  iperf3 -s > "$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  sleep 1  # Give the server a moment to start
fi

# Run the benchmark
echo "  -> Running iperf3 client..."
# Run with --json for easier parsing later
iperf3 -c "${SERVER_IP}" -P "${PARALLEL_STREAMS}" -t "${TEST_DURATION}" --json > "$OUTFILE"

# Stop local server if one was started
if [[ -n "$SERVER_PID" ]]; then
  echo "  -> Stopping local iperf3 server (PID: $SERVER_PID)..."
  kill "$SERVER_PID" 2>/dev/null || true
fi

echo "  -> Client test complete. Results: $OUTFILE"
