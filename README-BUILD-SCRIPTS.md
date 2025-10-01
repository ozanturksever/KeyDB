# KeyDB Build Scripts Reference

Quick reference for all build scripts in this repository.

## Hetzner Cloud Build Scripts (Recommended for AMD64)

### 🚀 Quick Start - Build AMD64 Packages in 3 Commands

```bash
# 1. Create build server (~2 min)
./hcloud-create-build-server.sh

# 2. Build packages (~15-20 min)
./hcloud-build-remote.sh

# 3. Clean up server
./hcloud-delete-build-server.sh
```

**Result**: AMD64 .deb packages in `built-packages/`  
**Cost**: ~€0.01-0.02 per build

### Hetzner Cloud Scripts

| Script | Purpose | Time |
|--------|---------|------|
| `hcloud-create-build-server.sh` | Create Hetzner Cloud build server (CCX13, 4 cores, 16GB RAM) | ~2 min |
| `hcloud-build-remote.sh` | Build packages on Hetzner Cloud server | ~15-20 min |
| `hcloud-delete-build-server.sh` | Delete the build server | ~30 sec |

**Prerequisites**: Install hcloud CLI (`brew install hcloud`) and configure with API token

**See**: `HCLOUD-SETUP.md` for detailed setup instructions

## Local Docker Build Scripts

### AMD64 Builds

| Script | Purpose | Platform | Time |
|--------|---------|----------|------|
| `pkg/deb/build-docker-amd64.sh` | Build AMD64 packages using Docker (Ubuntu 24.04) | ARM64 with QEMU | 2-4 hours ⚠️ |
| `pkg/deb/build-docker-24.04.sh` | Build for Ubuntu 24.04 (native platform) | AMD64 or ARM64 | ~15-20 min |

⚠️ **Warning**: `build-docker-amd64.sh` is extremely slow on ARM64 (Apple Silicon) due to QEMU emulation. Use Hetzner Cloud scripts instead.

### Output Directories

- `pkg/deb/deb_files_generated/` - Native platform builds
- `pkg/deb/deb_files_generated_amd64/` - AMD64 cross-platform builds
- `built-packages/` - Hetzner Cloud builds

## Remote Server Build Scripts

| Script | Purpose | Server |
|--------|---------|--------|
| `remote-build-amd64.sh` | Build on existing remote server (46.62.207.220) | Fixed IP |
| `hcloud-build-remote.sh` | Build on Hetzner Cloud server | Dynamic IP |

## Build Process Overview

All build scripts follow this process:

1. **Clone Repository**: Get KeyDB source code
2. **Initialize Submodules**: RocksDB and other dependencies
3. **Build Dependencies**: hiredis, lua, jemalloc, rocksdb, etc.
4. **Compile KeyDB**: With FLASH storage and TLS enabled
5. **Package**: Create .deb files using dpkg-buildpackage
6. **Copy Back**: Download packages to local machine

## Architecture Support

| Architecture | Native Build | Docker Build | Hetzner Cloud |
|-------------|--------------|--------------|---------------|
| **AMD64** | ✅ Fast | ⚠️ Slow on ARM64 | ✅ Fast |
| **ARM64** | ✅ Fast | ✅ Fast | ❌ Not yet |

## Package Contents

Each build produces these packages:

- `keydb_*.deb` - Metapackage (depends on keydb-server)
- `keydb-server_*.deb` - Main KeyDB server
- `keydb-sentinel_*.deb` - KeyDB Sentinel (monitoring)
- `keydb-tools_*.deb` - CLI tools (keydb-cli, keydb-benchmark, etc.)

## Verification

After building, verify packages:

```bash
# Check architecture
dpkg-deb --info built-packages/keydb-server_*.deb | grep Architecture

# Expected output:
# Architecture: amd64
# or
# Architecture: arm64

# List package contents
dpkg-deb --contents built-packages/keydb-server_*.deb
```

## Build Options

All builds include:

- ✅ TLS support (`BUILD_TLS=yes`)
- ✅ FLASH storage (`ENABLE_FLASH=yes`)
- ✅ Systemd integration (`USE_SYSTEMD=yes`)
- ✅ Multi-threading (uses all available cores)

## Troubleshooting

### Build Fails

```bash
# Check Docker is running
docker info

# Check disk space
df -h

# Re-initialize submodules
git submodule update --init --recursive
```

### Slow Build on ARM64

**Solution**: Use Hetzner Cloud scripts instead of `build-docker-amd64.sh`

### Package Installation Fails

```bash
# Check dependencies
sudo apt-get install -f

# Install manually
sudo dpkg -i built-packages/keydb-*.deb
sudo apt-get install -f  # Fix dependencies
```

## Cost Comparison

| Method | Time | Cost | Best For |
|--------|------|------|----------|
| **Hetzner Cloud** | 15-20 min | €0.01/build | Production AMD64 builds |
| **Native AMD64** | 15-20 min | Free | If you have AMD64 machine |
| **ARM64 Local** | 15-20 min | Free | ARM64 packages |
| **ARM64→AMD64 QEMU** | 2-4 hours | Free | When you have time to waste |
| **GitHub Actions** | 15-20 min | Free | CI/CD automation |

## Recommended Workflow

### For Development (ARM64 Mac)

```bash
# Build ARM64 packages locally for testing
./pkg/deb/build-docker-24.04.sh
```

### For Production Release (AMD64)

```bash
# Use Hetzner Cloud for fast AMD64 builds
./hcloud-create-build-server.sh
./hcloud-build-remote.sh
./hcloud-delete-build-server.sh
```

### For CI/CD

Set up GitHub Actions to build automatically on push (see `pkg/deb/BUILD-AMD64.md`)

## Additional Documentation

- `HCLOUD-SETUP.md` - Detailed Hetzner Cloud setup guide
- `pkg/deb/BUILD-AMD64.md` - AMD64 build strategies
- `pkg/deb/SYSTEMD-SERVICE-FIX.md` - Systemd service details
- `pkg/deb/POSTINST-FIX-VALIDATION.md` - Package script details
