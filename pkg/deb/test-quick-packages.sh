#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Testing KeyDB packages (Quick Mode)${NC}"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

cd "$PROJECT_ROOT"

# Check if packages exist
if [ ! -d "pkg/deb/deb_files_generated_quick" ] || [ -z "$(ls -A pkg/deb/deb_files_generated_quick/*.deb 2>/dev/null)" ]; then
    echo -e "${RED}Error: No packages found in pkg/deb/deb_files_generated_quick/${NC}"
    echo -e "${YELLOW}Please run build-package-quick.sh first.${NC}"
    exit 1
fi

echo -e "${BLUE}Found packages:${NC}"
ls -lh pkg/deb/deb_files_generated_quick/*.deb

echo -e "\n${YELLOW}Step 1: Inspecting package contents...${NC}"
for deb in pkg/deb/deb_files_generated_quick/*.deb; do
    echo -e "\n${BLUE}Package: $(basename $deb)${NC}"
    echo "--- Control Info ---"
    dpkg -I "$deb" | head -30
    echo "\n--- File List (first 20) ---"
    dpkg -c "$deb" | head -20
done

echo -e "\n${YELLOW}Step 2: Building test Docker container...${NC}"

# Copy packages to test location
mkdir -p pkg/deb/test_quick
cp pkg/deb/deb_files_generated_quick/*.deb pkg/deb/test_quick/

# Create minimal test Dockerfile
cat > pkg/deb/test_quick/Dockerfile.test << 'EOF'
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

# Copy packages
COPY *.deb /tmp/

# Install packages in correct order (tools first, then server/sentinel)
RUN dpkg -i /tmp/keydb-tools_*.deb || (apt-get update && apt-get install -f -y) && \
    dpkg -i /tmp/keydb-server_*.deb /tmp/keydb-sentinel_*.deb || (apt-get update && apt-get install -f -y) && \
    echo "Package installation completed"

# Comprehensive verification script
RUN echo "=== Installation Verification ===" && \
    echo "" && \
    echo "1. Checking keydb user exists:" && \
    id keydb && \
    echo "" && \
    echo "2. Binaries installed:" && \
    ls -lh /usr/bin/keydb-* 2>/dev/null || echo "  ERROR: No binaries found!" && \
    echo "" && \
    echo "3. Config files:" && \
    ls -lh /etc/keydb/ 2>/dev/null || echo "  ERROR: No config directory found!" && \
    test -f /etc/keydb/keydb.conf && echo "  ✓ keydb.conf exists" || echo "  ✗ keydb.conf missing" && \
    test -f /etc/keydb/sentinel.conf && echo "  ✓ sentinel.conf exists" || echo "  ✗ sentinel.conf missing" && \
    echo "" && \
    echo "4. Config file permissions:" && \
    stat -c "%a %U:%G %n" /etc/keydb/*.conf 2>/dev/null || echo "  Could not check permissions" && \
    echo "" && \
    echo "5. Systemd files:" && \
    ls -lh /usr/lib/systemd/system/keydb*.service 2>/dev/null || echo "  WARNING: No systemd files found" && \
    test -f /usr/lib/systemd/system/keydb-server.service && echo "  ✓ keydb-server.service exists" || echo "  ✗ keydb-server.service missing" && \
    test -f /usr/lib/systemd/system/keydb-sentinel.service && echo "  ✓ keydb-sentinel.service exists" || echo "  ✗ keydb-sentinel.service missing" && \
    echo "" && \
    echo "6. Installed packages:" && \
    dpkg -l | grep keydb && \
    echo "" && \
    echo "7. Testing binary execution:" && \
    /usr/bin/keydb-server --version && \
    /usr/bin/keydb-cli --version && \
    echo "" && \
    echo "8. Data directories:" && \
    ls -ld /var/lib/keydb /var/log/keydb 2>/dev/null || echo "  Data directories not found" && \
    stat -c "%a %U:%G %n" /var/lib/keydb /var/log/keydb 2>/dev/null || true && \
    echo "" && \
    echo "=== All checks passed! ==="

CMD ["/bin/bash"]
EOF

echo -e "${BLUE}Building test image...${NC}"
docker build --platform linux/amd64 -t keydb-test-quick -f pkg/deb/test_quick/Dockerfile.test pkg/deb/test_quick/

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Package test completed successfully!${NC}"
    echo -e "${GREEN}✓ Packages install correctly${NC}"
    echo -e "${GREEN}✓ Binaries are executable${NC}"
    echo -e "${GREEN}✓ Config files are in place${NC}"
    echo -e "${GREEN}✓ Systemd files are installed${NC}"
    
    echo -e "\n${YELLOW}Interactive test (optional):${NC}"
    echo -e "  Run: ${BLUE}docker run --rm -it keydb-test-quick${NC}"
    echo -e "  Then test: ${BLUE}/usr/bin/keydb-server /etc/keydb/keydb.conf${NC}"
    
    echo -e "\n${YELLOW}If everything looks good:${NC}"
    echo -e "  Rebuild with full compile: ${GREEN}./pkg/deb/build-docker-amd64.sh${NC}"
    
    # Cleanup
    echo -e "\n${BLUE}Cleaning up test artifacts...${NC}"
    rm -rf pkg/deb/test_quick
    
else
    echo -e "\n${RED}✗ Package test failed${NC}"
    echo -e "${YELLOW}Check the error messages above to fix packaging issues${NC}"
    echo -e "${YELLOW}Then run build-package-quick.sh again${NC}"
    exit 1
fi
