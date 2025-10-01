#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building KeyDB binaries for caching (one-time operation)${NC}"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

cd "$PROJECT_ROOT"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Building Docker image...${NC}"
docker build --platform linux/amd64 -t keydb-binary-builder-noble-amd64 -f pkg/deb/Dockerfile.ubuntu24.04 .

echo -e "${YELLOW}Building binaries in Docker container...${NC}"

# Create cache directory
mkdir -p pkg/deb/binary_cache_amd64

# Build binaries
docker run --rm --platform linux/amd64 \
    -v "$PROJECT_ROOT:/build/KeyDB:ro" \
    -v "$PROJECT_ROOT/pkg/deb/binary_cache_amd64:/output" \
    keydb-binary-builder-noble-amd64 \
    /bin/bash -c '
        set -e
        
        echo "Copying source..."
        cd /tmp
        cp -r /build/KeyDB ./KeyDB
        cd KeyDB
        
        echo "Initializing git submodules..."
        git submodule init && git submodule update
        
        echo "Building dependencies (including RocksDB)..."
        cd deps && make hiredis linenoise lua jemalloc hdr_histogram rocksdb && cd ..
        
        echo "Compiling KeyDB with FLASH storage enabled..."
        make -j$(nproc) BUILD_TLS=yes ENABLE_FLASH=yes
        
        echo "Copying binaries to cache..."
        cp src/keydb-server /output/
        cp src/keydb-sentinel /output/
        cp src/keydb-cli /output/
        cp src/keydb-benchmark /output/
        cp src/keydb-check-aof /output/
        cp src/keydb-check-rdb /output/
        cp src/keydb-diagnostic-tool /output/
        
        echo "Binaries cached successfully!"
        ls -lh /output/
    '

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Binaries built and cached successfully!${NC}"
    echo -e "${GREEN}Cached binaries location: pkg/deb/binary_cache_amd64/${NC}"
    echo -e "${YELLOW}You can now use build-package-quick.sh for fast packaging iterations${NC}"
    ls -lh "$PROJECT_ROOT/pkg/deb/binary_cache_amd64/"
else
    echo -e "${RED}Binary build failed${NC}"
    exit 1
fi
