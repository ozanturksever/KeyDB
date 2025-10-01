# KeyDB Systemd Service File Fix

## Issue
KeyDB packages failed to install with the error:
```
Failed to start keydb-server.service: Unit keydb-server.service not found.
```

## Root Cause
The debian package configuration files (`debian/*.install` and `debian_dh9/*.install`) referenced systemd service files that didn't exist:
- `debian/keydb-server.service`
- `debian/keydb-sentinel.service`

These files need to exist in the `debian/` and `debian_dh9/` directories during the build process so they can be packaged and installed to `/lib/systemd/system/`.

## Solution
Created proper systemd service unit files for both KeyDB server and sentinel:

### Files Created
1. `pkg/deb/debian/keydb-server.service`
2. `pkg/deb/debian/keydb-sentinel.service`
3. `pkg/deb/debian_dh9/keydb-server.service`
4. `pkg/deb/debian_dh9/keydb-sentinel.service`

### Service File Features
- **Type:** `notify` - Uses systemd notification protocol
- **User/Group:** Runs as `keydb` user for security
- **Supervised:** Properly configured for systemd supervision
- **Runtime Directory:** Creates `/var/run/keydb` with appropriate permissions
- **File Limits:** Sets `NOFILE` limit to 65535
- **Security:** Enables `NoNewPrivileges` and `PrivateTmp`
- **Auto-restart:** Configured to restart on failure

## Installation Path
The service files are installed to `/lib/systemd/system/` (which is typically symlinked to `/usr/lib/systemd/system/` on modern systems).

## Building Packages
After this fix, the debian packages can be built normally:
```bash
cd pkg/deb
./build-docker-amd64.sh  # or ./build-docker-24.04.sh
```

## Verification
After installing the packages:
```bash
# Check if service files exist
ls -l /lib/systemd/system/keydb-*.service

# Reload systemd
systemctl daemon-reload

# Check service status
systemctl status keydb-server
systemctl status keydb-sentinel

# Enable and start services
systemctl enable keydb-server
systemctl start keydb-server
```

## Related Issues
This fix addresses the missing systemd service files issue. The postinst/postrm script fixes (documented in `POSTINST-FIX-VALIDATION.md`) ensure that systemctl daemon-reload is called safely.
