# Quick Packaging Workflow

This workflow allows you to iterate on Debian packaging (systemd files, postinst scripts, file layouts, etc.) **without rebuilding the entire codebase** each time.

## Overview

The workflow separates binary compilation from packaging:

1. **Build once** - Compile KeyDB binaries and cache them (~30-45 minutes)
2. **Iterate fast** - Test packaging changes using cached binaries (~2-3 minutes per iteration)
3. **Final build** - When packaging is perfect, do a full clean rebuild

## Quick Start

### Step 1: Build and Cache Binaries (ONE TIME)

```bash
cd /path/to/KeyDB2
./pkg/deb/build-binaries-once.sh
```

This will:
- Build KeyDB with all dependencies (RocksDB, etc.)
- Cache the compiled binaries in `pkg/deb/binary_cache_amd64/`
- Take 30-45 minutes (only needs to be done once)

### Step 2: Iterate on Packaging (FAST)

Now you can quickly test packaging changes:

```bash
./pkg/deb/build-package-quick.sh
```

This will:
- Use cached binaries (no compilation!)
- Build .deb packages with your latest packaging changes
- Take only 2-3 minutes
- Output packages to `pkg/deb/deb_files_generated_quick/`

### Step 3: Test the Packages (FAST)

```bash
./pkg/deb/test-quick-packages.sh
```

This will:
- Inspect package contents
- Build a test Docker container
- Install the packages
- Verify binaries, configs, and systemd files
- Take only 1-2 minutes

### Step 4: Repeat Steps 2-3 Until Perfect

Make changes to:
- `pkg/deb/debian/rules`
- `pkg/deb/debian/keydb-server.install`
- `pkg/deb/debian/keydb-server.service`
- `pkg/deb/debian/*.postinst`, `*.preinst`, etc.
- Any other packaging files

Then run:
```bash
./pkg/deb/build-package-quick.sh && ./pkg/deb/test-quick-packages.sh
```

Each iteration takes only **3-5 minutes total** instead of 30-45 minutes!

### Step 5: Final Clean Build

Once packaging is perfect:

```bash
./pkg/deb/build-docker-amd64.sh
```

This does a complete clean rebuild with:
- Fresh compilation
- Full test suite
- Production-ready packages

## File Locations

- **Cached binaries**: `pkg/deb/binary_cache_amd64/`
- **Quick packages**: `pkg/deb/deb_files_generated_quick/`
- **Final packages**: `pkg/deb/deb_files_generated_amd64/`

## What Gets Tested in Quick Mode?

✓ Debian package structure
✓ File installation paths
✓ Systemd service files
✓ Config file locations
✓ Maintainer scripts (postinst, preinst, etc.)
✓ Package dependencies
✓ Package metadata

✗ Binary functionality (uses cached, already tested binaries)
✗ Test suite (skipped for speed)

## Workflow Diagram

```
┌─────────────────────────────────────┐
│  build-binaries-once.sh             │  ← Run ONCE (30-45 min)
│  Compiles KeyDB + deps              │
│  Caches binaries                    │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│  Edit packaging files:              │
│  - debian/rules                     │  ← Make changes
│  - *.service files                  │
│  - *.install files                  │
│  - maintainer scripts               │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│  build-package-quick.sh             │  ← Iterate FAST (2-3 min)
│  Uses cached binaries               │
│  Builds .deb packages               │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│  test-quick-packages.sh             │  ← Test FAST (1-2 min)
│  Validates package installation     │
└──────────────┬──────────────────────┘
               │
          ┌────┴────┐
          │         │
     NOT OK?      OK?
          │         │
          └────┬────┘
          (Loop back to edit)
               │
               ↓
┌─────────────────────────────────────┐
│  build-docker-amd64.sh              │  ← Final build (30-45 min)
│  Full clean rebuild                 │
│  Production packages                │
└─────────────────────────────────────┘
```

## Advanced: Manual Package Inspection

Inspect package contents without installing:

```bash
# View package info
dpkg -I pkg/deb/deb_files_generated_quick/keydb-server_*.deb

# List files in package
dpkg -c pkg/deb/deb_files_generated_quick/keydb-server_*.deb

# Extract package for manual inspection
dpkg-deb -R pkg/deb/deb_files_generated_quick/keydb-server_*.deb /tmp/inspect
```

## Troubleshooting

**Problem**: `build-package-quick.sh` fails with "cached binaries not found"
**Solution**: Run `./pkg/deb/build-binaries-once.sh` first

**Problem**: Packages install but files are in wrong locations
**Solution**: Check `debian/*.install` files and `debian/rules`

**Problem**: Systemd services not found after install
**Solution**: Verify `debian/keydb-server.service` path is `/usr/lib/systemd/system/` not `/lib/systemd/system/`

**Problem**: Want to rebuild binaries after code changes
**Solution**: Run `./pkg/deb/build-binaries-once.sh` again to refresh the cache

## Time Savings

| Task | Old Method | Quick Method | Savings |
|------|-----------|--------------|----------|
| Initial build | 30-45 min | 30-45 min | 0 min (same) |
| Each packaging iteration | 30-45 min | 2-3 min | **27-42 min per iteration!** |
| Testing installation | 2-3 min | 1-2 min | 1 min |

With 5 packaging iterations:
- **Old way**: 150-225 minutes (2.5-3.75 hours)
- **Quick way**: 45 + (5 × 3) = **60 minutes (1 hour)**
- **Savings**: **90-165 minutes!**

## Notes

- Quick packages are tagged with a timestamp (e.g., `~noble1~quick1234567890`) to allow easy reinstallation during testing
- The cached binaries are only used for packaging iterations - final production packages always use a fresh build
- If you modify KeyDB source code, rebuild the binary cache with `build-binaries-once.sh`
