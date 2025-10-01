#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVER_NAME="keydb-build-amd64"
REPO_URL="https://github.com/ozanturksever/KeyDB.git"
BRANCH="main"
REMOTE_DIR="/root/keydb-build"

echo -e "${GREEN}Building KeyDB AMD64 packages on Hetzner Cloud server${NC}"

# Check if hcloud CLI is installed
if ! command -v hcloud &> /dev/null; then
    echo -e "${RED}Error: hcloud CLI is not installed.${NC}"
    exit 1
fi

# Get server IP
if ! hcloud server describe "$SERVER_NAME" &> /dev/null; then
    echo -e "${RED}Server '$SERVER_NAME' not found. Create it first with ./hcloud-create-build-server.sh${NC}"
    exit 1
fi

SERVER_IP=$(hcloud server ip "$SERVER_NAME")
REMOTE_SERVER="root@$SERVER_IP"

echo -e "${YELLOW}Using server: $SERVER_NAME ($SERVER_IP)${NC}"

# Create local changes tarball if there are any
LOCAL_CHANGES=""
if [ -f pkg/deb/build-docker-amd64.sh ] || [ -f src/version.h ]; then
    echo -e "${YELLOW}Packaging local changes...${NC}"
    tar czf /tmp/local-changes.tar.gz \
        pkg/deb/BUILD-AMD64.md \
        pkg/deb/POSTINST-FIX-VALIDATION.md \
        pkg/deb/SYSTEMD-SERVICE-FIX.md \
        pkg/deb/build-docker-amd64.sh \
        pkg/deb/build-docker-24.04.sh \
        pkg/deb/debian/keydb-server.service \
        pkg/deb/debian/keydb-sentinel.service \
        pkg/deb/debian_dh9/keydb-server.service \
        pkg/deb/debian_dh9/keydb-sentinel.service \
        src/version.h 2>/dev/null || true
    LOCAL_CHANGES="yes"
fi

# Build on remote server
echo -e "${YELLOW}Connecting to server and building...${NC}"

ssh -o StrictHostKeyChecking=no $REMOTE_SERVER << 'ENDSSH'
set -e

cd /root
rm -rf keydb-build
mkdir -p keydb-build
cd keydb-build

echo "Cloning repository..."
git clone --recursive https://github.com/ozanturksever/KeyDB.git .
git checkout main

ENDSSH

# Copy local changes if any
if [ "$LOCAL_CHANGES" = "yes" ]; then
    echo -e "${YELLOW}Copying local changes to server...${NC}"
    scp /tmp/local-changes.tar.gz $REMOTE_SERVER:/root/keydb-build/
    ssh $REMOTE_SERVER "cd /root/keydb-build && tar xzf local-changes.tar.gz && rm local-changes.tar.gz"
    rm /tmp/local-changes.tar.gz
fi

# Continue build on remote
ssh $REMOTE_SERVER << 'ENDSSH'
set -e

cd /root/keydb-build

echo "Ensuring Docker is running..."
if ! systemctl is-active --quiet docker; then
    systemctl start docker
fi

echo "Building packages..."
chmod +x pkg/deb/build-docker-24.04.sh
./pkg/deb/build-docker-24.04.sh

echo "Build complete on remote server!"
ls -lh pkg/deb/deb_files_generated/*.deb

ENDSSH

# Copy packages back
echo -e "${YELLOW}Copying packages back to local machine...${NC}"
mkdir -p built-packages
scp $REMOTE_SERVER:/root/keydb-build/pkg/deb/deb_files_generated/*.deb built-packages/

echo -e "${GREEN}Build complete! Packages are in built-packages/${NC}"
ls -lh built-packages/*.deb

echo -e "${YELLOW}Cleaning up remote server...${NC}"
ssh $REMOTE_SERVER "rm -rf /root/keydb-build"

echo -e "${GREEN}Done!${NC}"
