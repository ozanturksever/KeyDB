#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Quick packaging mode - Using cached binaries${NC}"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

cd "$PROJECT_ROOT"

# Check if cached binaries exist
if [ ! -d "pkg/deb/binary_cache_amd64" ] || [ -z "$(ls -A pkg/deb/binary_cache_amd64)" ]; then
    echo -e "${RED}Error: Cached binaries not found!${NC}"
    echo -e "${YELLOW}Please run build-binaries-once.sh first to build and cache the binaries.${NC}"
    exit 1
fi

echo -e "${YELLOW}Using cached binaries from: pkg/deb/binary_cache_amd64/${NC}"
ls -lh pkg/deb/binary_cache_amd64/

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Increment version for easy reinstall testing
TIMESTAMP=$(date +%s)
ITERATION="quick${TIMESTAMP}"

echo -e "${YELLOW}Building package with iteration: ${ITERATION}${NC}"

# Create output directory
mkdir -p pkg/deb/deb_files_generated_quick

# Quick package build using cached binaries
docker run --rm --platform linux/amd64 \
    -v "$PROJECT_ROOT:/build/KeyDB:ro" \
    -v "$PROJECT_ROOT/pkg/deb/binary_cache_amd64:/binaries:ro" \
    -v "$PROJECT_ROOT/pkg/deb/deb_files_generated_quick:/output" \
    keydb-binary-builder-noble-amd64 \
    /bin/bash -c "
        set -e
        
        # Get version from source
        version=\$(grep KEYDB_REAL_VERSION /build/KeyDB/src/version.h | awk '{ printf \$3 }' | tr -d '\"')
        majorv=\"\${version:0:1}\"
        build=1
        codename=\"noble\"
        distname=\"~noble1~${ITERATION}\"
        
        echo \"Building KeyDB version: \$version for \$codename (Quick Mode)\" 
        echo \"Using cached binaries - NO COMPILATION\" 
        
        # Create build directory structure
        cd /tmp
        cp -r /build/KeyDB ./KeyDB
        cd KeyDB
        
        # Create original tarball (minimal, since we're not building)
        cd ..
        tar -czf keydb_\${version}.orig.tar.gz KeyDB
        
        cd KeyDB/pkg/deb
        pkg_name=\"keydb-\${majorv}:\${version}\${distname}\"
        mkdir -p \"\${pkg_name}/tmp\"
        
        # Copy debian files
        cp -r debian \"\${pkg_name}/tmp/\"
        cp master_changelog \"\${pkg_name}/tmp/debian/changelog\"
        
        # Copy README and other required files
        cp ../../README.md \"\${pkg_name}/tmp/\"
        cp ../../00-RELEASENOTES \"\${pkg_name}/tmp/\"
        
        # Copy utils directory
        mkdir -p \"\${pkg_name}/tmp/utils\"
        cp -r ../../utils/lru \"\${pkg_name}/tmp/utils/\"
        
        # Copy CACHED binaries (no build step!)
        mkdir -p \"\${pkg_name}/tmp/src\"
        echo \"Using cached binaries...\"
        cp /binaries/keydb-server \"\${pkg_name}/tmp/src/\"
        cp /binaries/keydb-sentinel \"\${pkg_name}/tmp/src/\"
        cp /binaries/keydb-cli \"\${pkg_name}/tmp/src/\"
        cp /binaries/keydb-benchmark \"\${pkg_name}/tmp/src/\"
        cp /binaries/keydb-check-aof \"\${pkg_name}/tmp/src/\"
        cp /binaries/keydb-check-rdb \"\${pkg_name}/tmp/src/\"
        cp /binaries/keydb-diagnostic-tool \"\${pkg_name}/tmp/src/\"
        
        # Copy config files
        mkdir -p \"\${pkg_name}/tmp/pkg/deb/conf\"
        cp ../../keydb.conf \"\${pkg_name}/tmp/pkg/deb/conf/keydb.conf\"
        cp ../../sentinel.conf \"\${pkg_name}/tmp/pkg/deb/conf/sentinel.conf\"
        
        # Move tarball
        mv /tmp/keydb_\${version}.orig.tar.gz \"\${pkg_name}/\"
        
        # Update changelog
        cd \"\${pkg_name}/tmp\"
        date=\$(date +'%a, %d %b %Y %T')
        changelog_str=\"keydb (\$majorv:\$version-\$build\$distname) \$codename; urgency=medium\\n\\n  * Quick packaging iteration (cached binaries)\\n\\n -- Ben Schermel <ben@eqalpha.com>  \$date +0000\\n\\n\"
        sed -i \"1s/^/\$changelog_str\\n/\" debian/changelog
        sed -i \"s/distribution_placeholder/\$distname/g\" debian/changelog
        sed -i \"s/codename_placeholder/\$codename/g\" debian/changelog
        
        # Create a marker file to indicate this used QUICK mode
        echo \"QUICK_BUILD=1\" > debian/QUICK_MODE
        
        # Modify debian/rules to skip build steps
        cat > debian/rules.quick << 'EORULES'
#!/usr/bin/make -f

include /usr/share/dpkg/buildflags.mk

export BUILD_TLS=yes
export USE_SYSTEMD=yes
export ENABLE_FLASH=yes
export CFLAGS CPPFLAGS LDFLAGS
export DEB_BUILD_MAINT_OPTIONS = hardening=+all
export DEB_LDFLAGS_MAINT_APPEND = -ldl -latomic $(LUA_LDFLAGS)

%:
	dh $@

override_dh_auto_build:
	@echo "Skipping build - using cached binaries"

override_dh_auto_install:
	cp pkg/deb/debian/keydb-server.service debian/keydb-server.service
	cp pkg/deb/debian/keydb-sentinel.service debian/keydb-sentinel.service
	dh_installsystemd --restart-after-upgrade

override_dh_auto_test:
	@echo "Skipping tests in quick mode"

override_dh_auto_clean:
	dh_auto_clean
	rm -f src/release.h debian/*.service debian/QUICK_MODE debian/rules.quick

override_dh_compress:
	dh_compress -Xredis-trib.rb

override_dh_installchangelogs:
	dh_installchangelogs --keep 00-RELEASENOTES
EORULES
        
        # Replace rules with quick version
        mv debian/rules debian/rules.original
        mv debian/rules.quick debian/rules
        chmod +x debian/rules
        
        # Build the package (FAST - no compilation!)
        echo \"Building debian package (quick mode - packaging only)...\"
        dpkg-buildpackage -us -uc -b -nc
        
        # Copy built packages to output
        cd ..
        cp *.deb /output/ 2>/dev/null || echo \"No .deb files found to copy\"
        
        echo \"Quick build complete! Packages copied to pkg/deb/deb_files_generated_quick/\"
        ls -lh /output/*.deb 2>/dev/null || echo \"Warning: No .deb files in output\"
    "

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Quick package build completed successfully!${NC}"
    echo -e "${GREEN}Packages are in: pkg/deb/deb_files_generated_quick/${NC}"
    echo -e "${YELLOW}These packages use cached binaries - only packaging changes were applied${NC}"
    ls -lh "$PROJECT_ROOT/pkg/deb/deb_files_generated_quick/"*.deb 2>/dev/null
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Test installation: ${GREEN}./pkg/deb/test-quick-packages.sh${NC}"
    echo -e "  2. If packaging is good, rebuild with full compile: ${GREEN}./pkg/deb/build-docker-amd64.sh${NC}"
else
    echo -e "${RED}Quick build failed${NC}"
    exit 1
fi
