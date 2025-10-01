#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building KeyDB deb package for Ubuntu 24.04 using Docker${NC}"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

cd "$PROJECT_ROOT"

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

echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t keydb-deb-builder-noble -f pkg/deb/Dockerfile.ubuntu24.04 .

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build Docker image${NC}"
    exit 1
fi

echo -e "${YELLOW}Running build in Docker container...${NC}"

# Create output directory if it doesn't exist
mkdir -p pkg/deb/deb_files_generated

# Run the build inside Docker
docker run --rm \
    -v "$PROJECT_ROOT:/build/KeyDB:ro" \
    -v "$PROJECT_ROOT/pkg/deb/deb_files_generated:/output" \
    keydb-deb-builder-noble \
    /bin/bash -c '
        set -e
        
        # Get version from source
        version=$(grep KEYDB_REAL_VERSION /build/KeyDB/src/version.h | awk "{ printf \$3 }" | tr -d \")
        majorv="${version:0:1}"
        build=1
        codename="noble"
        distname="~noble1"
        
        echo "Building KeyDB version: $version for $codename"
        
        # Create build directory structure
        cd /tmp
        cp -r /build/KeyDB ./KeyDB
        cd KeyDB
        
        # Create original tarball
        cd ..
        tar -czf keydb_${version}.orig.tar.gz KeyDB
        
        # Build KeyDB first
        cd KeyDB
        echo "Initializing git submodules..."
        git submodule init && git submodule update
        echo "Building dependencies (including RocksDB)..."
        cd deps && make hiredis linenoise lua jemalloc hdr_histogram rocksdb && cd ..
        echo "Compiling KeyDB with FLASH storage enabled..."
        make -j$(nproc) BUILD_TLS=yes ENABLE_FLASH=yes
        
        # Set up debian directory
        cd pkg/deb
        pkg_name="keydb-${majorv}:${version}${distname}"
        mkdir -p "${pkg_name}/tmp"
        
        # Copy debian files (use regular debian, not dh9 for noble)
        cp -r debian "${pkg_name}/tmp/"
        cp master_changelog "${pkg_name}/tmp/debian/changelog"
        
        # Copy README and other required files
        cp ../../README.md "${pkg_name}/tmp/"
        cp ../../00-RELEASENOTES "${pkg_name}/tmp/"
        
        # Copy utils directory for examples
        mkdir -p "${pkg_name}/tmp/utils"
        cp -r ../../utils/lru "${pkg_name}/tmp/utils/"
        
        # Copy built binaries and config files
        mkdir -p "${pkg_name}/tmp/src"
        cp ../../src/keydb-server "${pkg_name}/tmp/src/"
        cp ../../src/keydb-sentinel "${pkg_name}/tmp/src/"
        cp ../../src/keydb-cli "${pkg_name}/tmp/src/"
        cp ../../src/keydb-benchmark "${pkg_name}/tmp/src/"
        cp ../../src/keydb-check-aof "${pkg_name}/tmp/src/"
        cp ../../src/keydb-check-rdb "${pkg_name}/tmp/src/"
        cp ../../src/keydb-diagnostic-tool "${pkg_name}/tmp/src/"
        
        mkdir -p "${pkg_name}/tmp/pkg/deb/conf"
        cp ../../keydb.conf "${pkg_name}/tmp/pkg/deb/conf/keydb.conf"
        cp ../../sentinel.conf "${pkg_name}/tmp/pkg/deb/conf/sentinel.conf"
        
        # Move tarball
        mv /tmp/keydb_${version}.orig.tar.gz "${pkg_name}/"
        
        # Update changelog
        cd "${pkg_name}/tmp"
        date=$(date +"%a, %d %b %Y %T")
        changelog_str="keydb ($majorv:$version-$build$distname) $codename; urgency=medium\n\n  * Build for Ubuntu 24.04 (Noble Numbat)\n\n -- Ben Schermel <ben@eqalpha.com>  $date +0000\n\n"
        sed -i "1s/^/$changelog_str\n/" debian/changelog
        sed -i "s/distribution_placeholder/$distname/g" debian/changelog
        sed -i "s/codename_placeholder/$codename/g" debian/changelog
        
        # Build the package
        echo "Building debian package..."
        dpkg-buildpackage -us -uc -b
        
        # Copy built packages to output
        cd ..
        cp *.deb /output/ 2>/dev/null || echo "No .deb files found to copy"
        
        echo "Build complete! Packages copied to pkg/deb/deb_files_generated/"
        ls -lh /output/*.deb 2>/dev/null || echo "Warning: No .deb files in output"
    '

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Build completed successfully!${NC}"
    echo -e "${GREEN}Packages are in: pkg/deb/deb_files_generated/${NC}"
    ls -lh "$PROJECT_ROOT/pkg/deb/deb_files_generated/"*.deb 2>/dev/null
else
    echo -e "${RED}Build failed${NC}"
    exit 1
fi
