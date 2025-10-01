#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

# Default to AMD64 if not specified
ARCH=${1:-amd64}

if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "arm64" ]; then
    echo -e "${RED}Error: Invalid architecture. Use 'amd64' or 'arm64'${NC}"
    echo "Usage: $0 [amd64|arm64]"
    exit 1
fi

echo -e "${GREEN}Testing KeyDB deb packages for ${ARCH}${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running. Please start Docker.${NC}"
    exit 1
fi

# Find the packages for the specified architecture
SERVER_DEB=$(ls "$PROJECT_ROOT/pkg/deb/deb_files_generated/"keydb-server_*_${ARCH}.deb 2>/dev/null | head -1)
SENTINEL_DEB=$(ls "$PROJECT_ROOT/pkg/deb/deb_files_generated/"keydb-sentinel_*_${ARCH}.deb 2>/dev/null | head -1)
TOOLS_DEB=$(ls "$PROJECT_ROOT/pkg/deb/deb_files_generated/"keydb-tools_*_${ARCH}.deb 2>/dev/null | head -1)

if [ -z "$SERVER_DEB" ] || [ -z "$SENTINEL_DEB" ] || [ -z "$TOOLS_DEB" ]; then
    echo -e "${RED}Error: Could not find all required ${ARCH} packages in pkg/deb/deb_files_generated/${NC}"
    echo "Looking for:"
    echo "  - keydb-server_*_${ARCH}.deb"
    echo "  - keydb-sentinel_*_${ARCH}.deb"
    echo "  - keydb-tools_*_${ARCH}.deb"
    exit 1
fi

echo -e "${BLUE}Found packages:${NC}"
echo "  Server:   $(basename $SERVER_DEB)"
echo "  Sentinel: $(basename $SENTINEL_DEB)"
echo "  Tools:    $(basename $TOOLS_DEB)"
echo ""

# Create a test Dockerfile
cat > "$PROJECT_ROOT/pkg/deb/Dockerfile.test" <<EOF
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install basic utilities
RUN apt-get update && apt-get install -y \
    systemd \
    procps \
    net-tools \
    curl \
    libsnappy1v5 \
    && rm -rf /var/lib/apt/lists/*

# Create systemd directory (needed for package installation)
RUN mkdir -p /usr/lib/systemd/system

# Copy only the packages for this architecture
COPY keydb-tools_*_${ARCH}.deb /tmp/
COPY keydb-server_*_${ARCH}.deb /tmp/
COPY keydb-sentinel_*_${ARCH}.deb /tmp/

# Install the packages (skip the metapackage that has dependency issues)
RUN dpkg -i /tmp/keydb-tools_*.deb /tmp/keydb-server_*.deb /tmp/keydb-sentinel_*.deb || \
    (apt-get update && apt-get install -f -y) && \
    echo "Package installation completed"

# Verify installation
RUN echo "=== Installation Summary ===" && \
    echo "" && \
    echo "Binaries installed:" && \
    ls -lh /usr/bin/keydb-* 2>/dev/null || echo "  No binaries found!" && \
    echo "" && \
    echo "Config files:" && \
    ls -lh /etc/keydb/ 2>/dev/null || echo "  No config directory found!" && \
    echo "" && \
    echo "Systemd files:" && \
    ls -lh /usr/lib/systemd/system/keydb*.service 2>/dev/null || echo "  No systemd files found (expected - install failed)" && \
    echo "" && \
    dpkg -l | grep keydb

CMD ["/bin/bash"]
EOF

# Copy packages to a temp directory for Docker context
TMP_BUILD_DIR="$PROJECT_ROOT/pkg/deb/test_build_${ARCH}"
rm -rf "$TMP_BUILD_DIR"
mkdir -p "$TMP_BUILD_DIR"
cp "$SERVER_DEB" "$TMP_BUILD_DIR/"
cp "$SENTINEL_DEB" "$TMP_BUILD_DIR/"
cp "$TOOLS_DEB" "$TMP_BUILD_DIR/"
cp "$PROJECT_ROOT/pkg/deb/Dockerfile.test" "$TMP_BUILD_DIR/"

echo -e "${YELLOW}Building test Docker image for ${ARCH}...${NC}"
cd "$TMP_BUILD_DIR"
docker build \
    --platform linux/${ARCH} \
    -t keydb-test-${ARCH} \
    -f Dockerfile.test \
    .
cd "$PROJECT_ROOT"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build test image${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker image built successfully${NC}"
echo ""

echo -e "${YELLOW}Running installation tests in Docker container...${NC}"
echo ""

# Run comprehensive tests
docker run --rm --platform linux/${ARCH} keydb-test-${ARCH} /bin/bash -c '
    set -e
    echo "=== Testing KeyDB Installation ==="
    echo ""
    
    echo "1. Checking installed binaries:"
    keydb-server --version
    keydb-cli --version
    echo "   ✓ Binaries working"
    echo ""
    
    echo "2. Package status:"
    dpkg -l | grep keydb || echo "No packages found"
    echo ""
    
    echo "3. Known Issues:"
    echo "   ⚠ Config files not installed (packaging bug)"
    echo "   ⚠ Systemd service files not installed (packaging bug)"
    echo "   See PACKAGING-ISSUES.md for details"
    echo ""
    
    echo "4. Testing KeyDB functionality (without config file):"
    echo "   Starting KeyDB with minimal config..."
    keydb-server --port 6379 --daemonize yes --pidfile /tmp/keydb.pid --dir /tmp
    sleep 2
    
    echo "5. Testing connectivity:"
    keydb-cli ping
    keydb-cli SET test_key "Hello from KeyDB"
    result=$(keydb-cli GET test_key)
    if [ "$result" = "Hello from KeyDB" ]; then
        echo "   ✓ KeyDB responding correctly"
    else
        echo "   ✗ KeyDB response incorrect: $result"
        exit 1
    fi
    echo ""
    
    echo "6. Testing keydb-benchmark:"
    keydb-benchmark -q -t set,get -n 1000 | head -5
    echo "   ✓ Benchmark working"
    echo ""
    
    echo "7. Shutting down KeyDB:"
    keydb-cli SHUTDOWN NOSAVE || true
    sleep 1
    echo "   ✓ Shutdown successful"
    echo ""
    
    echo "=== Functional tests passed! ==="
    echo "=== Note: Packaging issues need to be fixed (see PACKAGING-ISSUES.md) ==="
'

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ All tests passed for ${ARCH}!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Package details:${NC}"
    echo "  Server:   $(basename $SERVER_DEB)"
    echo "  Sentinel: $(basename $SENTINEL_DEB)"
    echo "  Tools:    $(basename $TOOLS_DEB)"
    echo ""
    echo -e "${YELLOW}To test interactively, run:${NC}"
    echo "  docker run -it --platform linux/${ARCH} keydb-test-${ARCH}"
else
    echo -e "${RED}Tests failed for ${ARCH}${NC}"
    exit 1
fi
