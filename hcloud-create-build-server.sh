#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Creating Hetzner Cloud build server for KeyDB AMD64 packages${NC}"

# Configuration
SERVER_NAME="keydb-build-amd64"
SERVER_TYPE="ccx13"  # 4 vCPU, 16GB RAM, Dedicated CPU
IMAGE="debian-12"     # Debian 12 (Bookworm)
LOCATION="nbg1"       # Nuremberg datacenter
SSH_KEY_NAME="default" # Change to your SSH key name in Hetzner

# Check if hcloud CLI is installed
if ! command -v hcloud &> /dev/null; then
    echo -e "${RED}Error: hcloud CLI is not installed.${NC}"
    echo -e "Install it with: brew install hcloud (macOS) or see https://github.com/hetznercloud/cli"
    exit 1
fi

# Check if context is set
if ! hcloud context list | grep -q active; then
    echo -e "${RED}Error: No active hcloud context. Run 'hcloud context create <name>' first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Server configuration:${NC}"
echo "  Name: $SERVER_NAME"
echo "  Type: $SERVER_TYPE (Dedicated vCPU, 4 cores, 16GB RAM)"
echo "  Image: $IMAGE"
echo "  Location: $LOCATION"
echo ""

# Check if SSH key exists
if ! hcloud ssh-key list | grep -q "$SSH_KEY_NAME"; then
    echo -e "${YELLOW}Warning: SSH key '$SSH_KEY_NAME' not found in your Hetzner account.${NC}"
    echo -e "${YELLOW}Server will be created without SSH key. You can add it later.${NC}"
    SSH_KEY_ARG=""
else
    SSH_KEY_ARG="--ssh-key $SSH_KEY_NAME"
fi

# Create cloud-init user data for automated setup
cat > /tmp/cloud-init.yaml << 'EOF'
#cloud-config
package_update: true
package_upgrade: true

packages:
  - docker.io
  - git
  - build-essential
  - cmake
  - dpkg-dev
  - debhelper
  - fail2ban
  - ufw

runcmd:
  # Configure firewall
  - ufw allow ssh
  - ufw --force enable
  
  # Start and enable Docker
  - systemctl start docker
  - systemctl enable docker
  
  # Configure fail2ban for SSH protection
  - systemctl start fail2ban
  - systemctl enable fail2ban
  
  # Optimize for builds
  - echo "vm.swappiness=10" >> /etc/sysctl.conf
  - sysctl -p
  
  # Create build directory
  - mkdir -p /root/builds
  - chmod 755 /root/builds

final_message: "KeyDB build server setup complete! Ready for AMD64 package builds."
EOF

echo -e "${YELLOW}Creating server with cloud-init configuration...${NC}"

# Create the server
hcloud server create \
    --name "$SERVER_NAME" \
    --type "$SERVER_TYPE" \
    --image "$IMAGE" \
    --location "$LOCATION" \
    $SSH_KEY_ARG \
    --user-data-from-file /tmp/cloud-init.yaml

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create server${NC}"
    rm /tmp/cloud-init.yaml
    exit 1
fi

# Clean up cloud-init file
rm /tmp/cloud-init.yaml

# Get server IP
SERVER_IP=$(hcloud server ip "$SERVER_NAME")

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Failed to get server IP address${NC}"
    exit 1
fi

echo -e "${GREEN}Server created successfully!${NC}"
echo ""
echo -e "${GREEN}Server Details:${NC}"
echo "  Name: $SERVER_NAME"
echo "  IP: $SERVER_IP"
echo "  SSH: ssh root@$SERVER_IP"
echo ""
echo -e "${YELLOW}Note: Server is being set up with cloud-init. Wait 1-2 minutes before connecting.${NC}"
echo -e "${YELLOW}Docker, git, and build tools will be installed automatically.${NC}"
echo ""
echo -e "${GREEN}To build KeyDB packages on this server:${NC}"
echo "  1. SSH to the server: ssh root@$SERVER_IP"
echo "  2. Clone the repo: git clone --recursive https://github.com/ozanturksever/KeyDB.git"
echo "  3. cd KeyDB"
echo "  4. Run the build: ./pkg/deb/build-docker-24.04.sh"
echo ""
echo -e "${GREEN}Or update remote-build-amd64.sh with this IP: $SERVER_IP${NC}"
