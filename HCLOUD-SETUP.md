# Hetzner Cloud Build Server Setup for AMD64 Packages

This guide explains how to create and use a Hetzner Cloud server for building KeyDB AMD64 Debian packages.

## Prerequisites

1. **Install hcloud CLI**:
   ```bash
   # macOS
   brew install hcloud
   
   # Linux
   # Download from https://github.com/hetznercloud/cli/releases
   ```

2. **Create Hetzner Cloud Account**:
   - Sign up at https://console.hetzner.cloud
   - Create an API token in your project settings

3. **Configure hcloud CLI**:
   ```bash
   hcloud context create keydb
   # Paste your API token when prompted
   ```

4. **Upload SSH Key** (optional but recommended):
   ```bash
   # Upload your public SSH key
   hcloud ssh-key create --name default --public-key-from-file ~/.ssh/id_rsa.pub
   ```

## Server Specifications

The build server uses these specifications (optimized for C++ compilation):

- **Type**: CCX13 (Dedicated vCPU)
- **CPU**: 4 dedicated vCores (AMD EPYC)
- **RAM**: 16 GB
- **Storage**: 80 GB NVMe SSD
- **OS**: Debian 12 (Bookworm)
- **Location**: Nuremberg (nbg1)
- **Cost**: ~€0.04/hour (~€30/month if left running)

### Why Dedicated vCPU?

Dedicated vCPU servers (CCX line) provide guaranteed CPU resources without "noisy neighbor" effects, ensuring consistent build times. This is crucial for CPU-intensive compilation tasks.

## Quick Start

### 1. Create the Build Server

```bash
./hcloud-create-build-server.sh
```

This script will:
- Create a Hetzner Cloud server named `keydb-build-amd64`
- Install Docker, git, build tools, and security software
- Configure firewall (ufw) and fail2ban
- Optimize system for builds
- Display the server IP address

**Wait 1-2 minutes** after creation for cloud-init to complete the setup.

### 2. Build Packages

```bash
./hcloud-build-remote.sh
```

This script will:
- Connect to your Hetzner Cloud server
- Clone the KeyDB repository
- Copy any local changes (version.h, build scripts, etc.)
- Run the Docker build process
- Copy the built .deb packages back to `built-packages/`
- Clean up the build directory on the server

Build time: ~15-20 minutes for a full build

### 3. Delete the Server (when done)

```bash
./hcloud-delete-build-server.sh
```

**Important**: Remember to delete the server when you're done to avoid ongoing charges!

## Manual Server Usage

If you prefer to build manually:

```bash
# SSH to the server
ssh root@<SERVER_IP>

# Clone the repository
cd /root/builds
git clone --recursive https://github.com/ozanturksever/KeyDB.git
cd KeyDB

# Run the build
./pkg/deb/build-docker-24.04.sh

# Download packages from your local machine
scp root@<SERVER_IP>:/root/builds/KeyDB/pkg/deb/deb_files_generated/*.deb ./built-packages/
```

## Cost Optimization

### Pay-per-Use

Hetzner Cloud bills by the hour. To minimize costs:

1. **Create server only when needed**:
   ```bash
   ./hcloud-create-build-server.sh
   ```

2. **Build packages**:
   ```bash
   ./hcloud-build-remote.sh
   ```

3. **Delete server immediately after**:
   ```bash
   ./hcloud-delete-build-server.sh
   ```

**Cost per build**: ~€0.01-0.02 (15-20 minutes)

### Keep Server Running

If you build frequently, keep the server running:
- Cost: ~€30/month
- Benefit: Instant builds, no setup wait

## Customization

Edit `hcloud-create-build-server.sh` to customize:

- **Server name**: Change `SERVER_NAME`
- **Server type**: Change `SERVER_TYPE` (e.g., `ccx23` for 8 cores/32GB)
- **Location**: Change `LOCATION` (e.g., `fsn1`, `hel1`, `ash`)
- **SSH key**: Change `SSH_KEY_NAME` to match your uploaded key

## Security Features

The server is automatically configured with:

- **UFW Firewall**: Only SSH (port 22) is allowed
- **Fail2ban**: Automatic IP blocking after failed SSH attempts
- **SSH Key Authentication**: Password login should be disabled

## Troubleshooting

### Server Creation Fails

```bash
# Check hcloud context
hcloud context list

# Check quota
hcloud server list
```

### Build Fails

```bash
# SSH to server and check logs
ssh root@<SERVER_IP>
cd /root/keydb-build
./pkg/deb/build-docker-24.04.sh
```

### Cannot Connect to Server

```bash
# Get server status
hcloud server describe keydb-build-amd64

# Check if cloud-init is complete (wait 1-2 minutes after creation)
ssh root@<SERVER_IP> "cloud-init status"
```

## Comparison with Alternatives

| Method | Build Time | Setup Time | Cost | Pros | Cons |
|--------|-----------|------------|------|------|------|
| **Hetzner Cloud** | 15-20 min | 2 min | €0.01/build | Fast, clean, reproducible | Requires hcloud setup |
| **Local ARM64 + QEMU** | 2-4 hours | 0 min | Free | No setup | Extremely slow |
| **GitHub Actions** | 15-20 min | 5 min | Free | Automated | Requires workflow setup |
| **Existing Remote Server** | 15-20 min | 0 min | Fixed | Always available | Requires maintenance |

## Best Practices

1. **Always delete servers after use** to avoid charges
2. **Use the automated scripts** rather than manual setup
3. **Keep local changes minimal** - commit to git when possible
4. **Verify packages locally** after downloading
5. **Monitor build logs** for any warnings or errors

## Next Steps

- Set up GitHub Actions for automated builds
- Create a package repository for hosting .deb files
- Add ARM64 build server support
