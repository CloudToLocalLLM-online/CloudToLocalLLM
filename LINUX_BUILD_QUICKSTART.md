# Linux Build Quick Start

This document provides a quick reference for enabling Linux builds in CloudToLocalLLM.

## Current Status

✅ **Infrastructure Ready** - All files and configuration are in place
❌ **Builds Disabled** - Linux builds are currently commented out in the workflow

## Quick Enable (3 Steps)

### 1. Uncomment Linux Build in Workflow

Edit `.github/workflows/build-release.yml` line ~280:

```yaml
# Change from:
# - platform: linux
#   os: ubuntu-latest
#   build-command: flutter build linux --release
#   artifact-name: linux-desktop

# To:
- platform: linux
  os: ubuntu-latest
  build-command: flutter build linux --release
  artifact-name: linux-desktop
```

### 2. Add Linux Build Steps

See `docs/LINUX_BUILD_GUIDE.md` section "Step 2: Add Linux Build Steps" for the complete build steps to add to the workflow.

### 3. Update Release Processing

Uncomment Linux artifact processing in the `create-release` job (see `docs/LINUX_BUILD_GUIDE.md` section "Step 3").

## Files Already Created

✅ `com.cloudtolocalllm.CloudToLocalLLM.yml` - Flatpak manifest
✅ `linux/com.cloudtolocalllm.CloudToLocalLLM.desktop` - Desktop entry
✅ `linux/com.cloudtolocalllm.CloudToLocalLLM.metainfo.xml` - AppStream metadata
✅ `docs/LINUX_BUILD_GUIDE.md` - Complete documentation

## Test Locally First

Before enabling in CI/CD:

```bash
# Install dependencies
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev

# Configure Flutter
flutter config --enable-linux-desktop

# Build
flutter build linux --release

# Test
./build/linux/x64/release/bundle/cloudtolocalllm
```

## Full Documentation

For complete instructions, troubleshooting, and advanced configuration:
📖 **See: `docs/LINUX_BUILD_GUIDE.md`**

## Cost

**$0/month** - GitHub-hosted runners are FREE for public repositories

## Support

Linux builds will work on:
- Ubuntu / Debian / Linux Mint
- Fedora / RHEL / CentOS
- Arch Linux / Manjaro
- openSUSE
- Pop!_OS
- Elementary OS
- And all major Linux distributions
