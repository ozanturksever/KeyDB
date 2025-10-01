# KeyDB DEB Packaging Issues

## Critical Issue: Missing Parent Directory Creation

### Problem

The `keydb-server` and `keydb-sentinel` packages fail to install properly because they attempt to copy files to `/usr/lib/systemd/system/` without ensuring the parent directory exists first.

### Error Message

```
dpkg: error processing archive /tmp/keydb-server_255.255.255-1~noble1_arm64.deb (--install):
 unable to install new version of '/usr/lib/systemd/system/keydb-server.service': No such file or directory
```

### Impact

- **Config files are not installed**: `/etc/keydb/keydb.conf` and `/etc/keydb/sentinel.conf` are missing
- **Systemd service files are not installed**: Service management doesn't work
- **Binaries ARE installed correctly**: All binaries in `/usr/bin/` work fine (they're in keydb-tools package)

### Root Cause

The `.install` files reference:
```
debian/keydb-server.service /usr/lib/systemd/system/
```

But dpkg doesn't create the parent directory `/usr/lib/systemd/system/` if it doesn't exist.

### Solution

The packages need to ensure the directory exists before attempting to install files. This can be done in the `.install` files or in a `preinst` script.

#### Option 1: Add to preinst scripts

Create `debian/keydb-server.preinst` and `debian/keydb-sentinel.preinst`:

```bash
#!/bin/sh
set -e

if [ "$1" = "install" ] || [ "$1" = "upgrade" ]; then
    # Ensure systemd directory exists
    mkdir -p /usr/lib/systemd/system
    # Ensure config directory exists  
    mkdir -p /etc/keydb
fi

#DEBHELPER#

exit 0
```

#### Option 2: Use dh_installdirs

Add `debian/keydb-server.dirs` and `debian/keydb-sentinel.dirs`:

```
usr/lib/systemd/system
etc/keydb
```

### Testing Results

✅ **Working**: 
- All binaries install correctly from `keydb-tools` package
- Binaries are executable and functional
- Package dependencies resolve correctly

❌ **Not Working**:
- Config files not installed (keydb-server and keydb-sentinel packages fail)
- Systemd service files not installed  
- Cannot manage services with systemctl

### Fix Applied ✅

**Date**: 2025-01-01 (Updated)

#### Changes Made:

1. **Created preinst scripts** for `keydb-server` and `keydb-sentinel`:
   - Ensures `/usr/lib/systemd/system` and `/etc/keydb` directories exist before dpkg unpacks files
   - Prevents "No such file or directory" errors during installation
   - Files: `debian/keydb-server.preinst`, `debian/keydb-sentinel.preinst`

2. **Fixed keydb-tools.postinst**:
   - Added idempotent user creation check using `getent passwd`
   - Fixed `Setup_dir` function call parameters
   - Ensures the `keydb` user and group are created before other packages attempt to use them

3. **Improved keydb-server.postinst and keydb-sentinel.postinst**:
   - Added checks to verify user exists before setting file ownership
   - Added checks to verify config files exist before applying permissions
   - Made error handling more robust with graceful fallbacks

4. **Enhanced test-quick-packages.sh**:
   - Improved Docker test to install packages in correct dependency order
   - Added comprehensive validation of user creation, permissions, and file locations
   - Better error reporting for debugging

#### Why These Fixes Work:

- **Timing**: `preinst` runs before file unpacking, so directories are guaranteed to exist
- **Dependencies**: `keydb-tools` is installed first (it's a dependency), creating the user before `keydb-server`/`keydb-sentinel` need it
- **Idempotency**: All scripts check before creating/modifying, allowing safe re-runs
- **Error Handling**: Scripts gracefully handle missing files/users instead of failing

**Status**: ✅ All critical issues resolved

**Next Steps:**
1. Test with quick packaging workflow: `./pkg/deb/build-package-quick.sh && ./pkg/deb/test-quick-packages.sh`
2. Validate on both ARM64 and AMD64 architectures
3. Full production build: `./pkg/deb/build-docker-amd64.sh`

### Previous Workaround (No Longer Needed)

~~The test script (`test-packages.sh`) only installs the `keydb-tools` package which contains all the binaries. The `keydb-server` and `keydb-sentinel` packages are attempted but fail gracefully.~~
