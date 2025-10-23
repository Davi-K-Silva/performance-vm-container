# Containerfile
# Build context must include: scripts/ and benchmarks/
FROM ubuntu:24.04

# Avoid interactive prompts (e.g., tzdata)
ENV DEBIAN_FRONTEND=noninteractive

# Install only what is needed so your install scripts can use 'sudo'
# (they run as root here, but many scripts call sudo explicitly)
RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo ca-certificates bash coreutils findutils make \
 && rm -rf /var/lib/apt/lists/*

# Create workspace
WORKDIR /app

# Copy scripts first (better layer caching), then benchmarks
COPY scripts/ /app/scripts/
COPY benchmarks/ /app/benchmarks/

# Ensure all scripts are executable
RUN chmod +x /app/scripts/*.sh || true \
 && find /app/benchmarks -type f -name "*.sh" -exec chmod +x {} +

# (Optional) let scripts find the benchmarks directory via BENCH_DIR
ENV BENCH_DIR=/app/benchmarks

# Run all installs and builds during image build
# If any install/build fails, the build will fail (good for CI)
RUN /app/scripts/install_all.sh \
 && /app/scripts/build_all.sh

# Default workdir and command
WORKDIR /app
CMD ["/bin/bash"]

