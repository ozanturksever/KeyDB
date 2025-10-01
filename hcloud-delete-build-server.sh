#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVER_NAME="keydb-build-amd64"

echo -e "${YELLOW}Deleting Hetzner Cloud build server: $SERVER_NAME${NC}"

# Check if hcloud CLI is installed
if ! command -v hcloud &> /dev/null; then
    echo -e "${RED}Error: hcloud CLI is not installed.${NC}"
    exit 1
fi

# Check if server exists
if ! hcloud server describe "$SERVER_NAME" &> /dev/null; then
    echo -e "${RED}Server '$SERVER_NAME' not found.${NC}"
    exit 1
fi

# Get server details before deletion
SERVER_IP=$(hcloud server ip "$SERVER_NAME")

echo -e "${YELLOW}Server to be deleted:${NC}"
echo "  Name: $SERVER_NAME"
echo "  IP: $SERVER_IP"
echo ""

read -p "Are you sure you want to delete this server? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${GREEN}Deletion cancelled.${NC}"
    exit 0
fi

hcloud server delete "$SERVER_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Server '$SERVER_NAME' deleted successfully.${NC}"
else
    echo -e "${RED}Failed to delete server.${NC}"
    exit 1
fi
