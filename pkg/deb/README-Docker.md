# Building KeyDB DEB Packages with Docker

This directory contains Docker-based build scripts for creating KeyDB debian packages in isolated environments.

## Ubuntu 24.04 (Noble Numbat)

### Prerequisites

- Docker must be installed and running
- No other dependencies needed on the host machine

### Quick Start

From the project root directory, run:

```bash
./pkg/deb/build-docker-24.04.sh
```

This script will:
1. Build a Docker image with all necessary build dependencies for Ubuntu 24.04
2. Create a clean build environment inside the container
3. Build the KeyDB debian packages
4. Copy the resulting `.deb` files to `pkg/deb/deb_files_generated/`

### What Gets Built

The build process creates the following packages:
- `keydb_*.deb` - Metapackage
- `keydb-server_*.deb` - KeyDB server
- `keydb-sentinel_*.deb` - KeyDB Sentinel for monitoring
- `keydb-tools_*.deb` - Command-line tools (keydb-cli, keydb-benchmark, etc.)

### Output Location

All generated `.deb` packages will be in:
```
pkg/deb/deb_files_generated/
```

### Manual Docker Build

If you want to build the Docker image manually:

```bash
# Build the Docker image
docker build -t keydb-deb-builder-noble -f pkg/deb/Dockerfile.ubuntu24.04 .

# Run interactively to debug
docker run -it --rm \
  -v "$(pwd):/build/KeyDB:ro" \
  -v "$(pwd)/pkg/deb/deb_files_generated:/output" \
  keydb-deb-builder-noble /bin/bash
```

### Troubleshooting

**Docker not found:**
```
Error: Docker is not installed. Please install Docker first.
```
Install Docker for your platform from https://docs.docker.com/get-docker/

**Docker daemon not running:**
```
Error: Docker daemon is not running. Please start Docker.
```
Start Docker Desktop or the Docker daemon on your system.

**Build failures:**
Check the output for specific error messages. Common issues:
- Missing build dependencies (should be handled by the Dockerfile)
- Insufficient disk space
- Network issues when installing packages

### Comparison with Traditional Build

The traditional `deb-buildsource.sh` script uses `pbuilder` and requires:
- Installation of build tools on the host machine
- `pbuilder` setup and maintenance
- Running with `sudo` permissions

The Docker-based build:
- Runs in complete isolation
- No host system modifications needed
- No `sudo` required (except for Docker daemon itself)
- Easier to reproduce and debug
- Can build for different Ubuntu versions on any host OS

### Building for Other Ubuntu Versions

To create builds for other Ubuntu versions:
1. Copy `Dockerfile.ubuntu24.04` to `Dockerfile.ubuntu<version>`
2. Update the base image: `FROM ubuntu:<version>`
3. Copy `build-docker-24.04.sh` and update version references
4. Adjust the `codename` and `distname` variables in the build script
