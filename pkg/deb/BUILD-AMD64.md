# Building KeyDB AMD64 DEB Packages

## Issue with Cross-Platform Builds

Building AMD64 packages on ARM64 systems (like Apple Silicon Macs) using Docker with QEMU emulation is extremely slow and can take several hours due to the emulation overhead.

## Recommended Approaches

### Option 1: Native AMD64 System (Fastest)

Build on a native AMD64/x86_64 system:

```bash
# On an AMD64 Ubuntu 24.04 system
cd /path/to/KeyDB
./pkg/deb/build-docker-24.04.sh
```

This will generate packages in `pkg/deb/deb_files_generated/`

### Option 2: Cloud Build (AWS EC2, Google Cloud, etc.)

1. Launch an AMD64 Ubuntu 24.04 instance
2. Install Docker:
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker.io git
   sudo usermod -aG docker $USER
   # Log out and back in
   ```
3. Clone the repository and build:
   ```bash
   git clone <your-repo-url>
   cd KeyDB
   ./pkg/deb/build-docker-24.04.sh
   ```
4. Download the packages using `scp` or similar

### Option 3: GitHub Actions / GitLab CI

Create a CI workflow that builds on AMD64 runners:

```yaml
name: Build AMD64 Packages
on: [push, workflow_dispatch]
jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: true
      - name: Build packages
        run: ./pkg/deb/build-docker-24.04.sh
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: keydb-amd64-packages
          path: pkg/deb/deb_files_generated/*.deb
```

### Option 4: Use the AMD64 Build Script (Slow)

If you must build on ARM64, you can use the provided script, but be prepared to wait:

```bash
./pkg/deb/build-docker-amd64.sh
```

**Note:** This can take 2-4 hours due to QEMU emulation overhead.

## Package Verification

After building, verify the packages:

```bash
# Check architecture
dpkg-deb --info pkg/deb/deb_files_generated/keydb-server_*.deb | grep Architecture

# Should show: Architecture: amd64
```

## Current Status

The postinst/postrm scripts have been fixed for both ARM64 and AMD64 packages:
- ✅ ARM64 packages built successfully
- ⏳ AMD64 packages require native AMD64 system or cloud build

Both architectures will have the same fixed scripts with proper systemctl daemon-reload handling.
