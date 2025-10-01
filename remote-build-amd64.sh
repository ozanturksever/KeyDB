#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

REMOTE_SERVER="root@46.62.207.220"
REPO_URL="https://github.com/ozanturksever/KeyDB.git"
BRANCH="main"
REMOTE_DIR="/root/keydb-build"

echo -e "${GREEN}Building KeyDB AMD64 packages on remote server${NC}"

# Create local changes tarball if there are any
LOCAL_CHANGES=""
echo -e "${YELLOW}Packaging local changes...${NC}"
tar czf /tmp/local-changes.tar.gz \
    pkg/deb/BUILD-AMD64.md \
    pkg/deb/POSTINST-FIX-VALIDATION.md \
    pkg/deb/SYSTEMD-SERVICE-FIX.md \
    pkg/deb/build-docker-amd64.sh \
    pkg/deb/build-docker-24.04.sh \
    pkg/deb/debian/keydb-server.service \
    pkg/deb/debian/keydb-sentinel.service \
    pkg/deb/debian/keydb-server.install \
    pkg/deb/debian/keydb-sentinel.install \
    pkg/deb/debian/rules \
    pkg/deb/debian_dh9/keydb-server.service \
    pkg/deb/debian_dh9/keydb-sentinel.service \
    src/version.h 2>/dev/null || true
LOCAL_CHANGES="yes"

# Build on remote server
echo -e "${YELLOW}Connecting to remote server and building...${NC}"

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
    echo -e "${YELLOW}Copying local changes to remote server...${NC}"
    scp /tmp/local-changes.tar.gz $REMOTE_SERVER:/root/keydb-build/
    ssh $REMOTE_SERVER "cd /root/keydb-build && tar xzf local-changes.tar.gz && rm local-changes.tar.gz"
    rm /tmp/local-changes.tar.gz
fi

# Continue build on remote
ssh $REMOTE_SERVER << 'ENDSSH'
set -e

cd /root/keydb-build

echo "Installing Docker if not present..."
if ! command -v docker &> /dev/null; then
    apt-get update
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
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
