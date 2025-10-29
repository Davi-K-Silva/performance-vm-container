#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/content"

RESULTS_DIR="${SCRIPT_DIR}/results"
mkdir -p "$RESULTS_DIR"

# Default parameters
SERVER_IP="${1:-127.0.0.1}"   # Default to localhost
TEST_DURATION="${2:-60}"       # Default 60 seconds
PARALLEL_STREAMS="${3:-4}"     # Default 4 parallel connections

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
OUTFILE="${RESULTS_DIR}/iperf3_${TIMESTAMP}.out"

echo "==> Starting iperf3 benchmark"
echo "    Server:   ${SERVER_IP}"
echo "    Duration: ${TEST_DURATION}s"
echo "    Streams:  ${PARALLEL_STREAMS}"
echo "    Output:   ${OUTFILE}"
echo

# If running locally, start a background server
if [[ "$SERVER_IP" == "127.0.0.1" || "$SERVER_IP" == "localhost" ]]; then
  echo "==> Starting local iperf3 server in background..."
  iperf3 -s > "${RESULTS_DIR}/iperf3_server_${TIMESTAMP}.log" 2>&1 &
  SERVER_PID=$!
  sleep 1  # Give the server a moment to start
fi

# Run the benchmark
echo "==> Running iperf3 client..."
iperf3 -c "${SERVER_IP}" -P "${PARALLEL_STREAMS}" -t "${TEST_DURATION}" --logfile "$OUTFILE"

# Stop local server if one was started
if [[ "${SERVER_PID:-}" != "" ]]; then
  echo "==> Stopping local iperf3 server..."
  kill "$SERVER_PID" 2>/dev/null || true
fi

echo
echo "✅ Benchmark complete. Results saved to: $OUTFILE"

