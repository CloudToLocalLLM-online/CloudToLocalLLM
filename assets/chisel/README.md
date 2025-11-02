# Chisel Binaries

This directory contains Chisel tunnel binaries for different platforms.

## Binaries

The following binaries should be placed here:

- `chisel-windows.exe` - Windows x64
- `chisel-windowsarm64.exe` - Windows ARM64
- `chisel-darwin` - macOS x64
- `chisel-darwinarm64` - macOS ARM64 (Apple Silicon)
- `chisel-linux` - Linux x64
- `chisel-linuxarm64` - Linux ARM64

## Download Scripts

Use the provided scripts to download binaries:

- **Linux/macOS**: `scripts/download-chisel-binaries.sh`
- **Windows**: `scripts/setup-chisel-flutter-assets.ps1`

These scripts download the binaries from the official Chisel releases.

## Windows Defender Warning

Windows Defender may flag the Chisel binary as potentially unwanted software. This is a false positive because Chisel is a legitimate network tunneling tool. 

**Note:** The Chisel binary is now extracted to a persistent location at `Documents\CloudToLocalLLM\chisel\` instead of a temp folder, so you only need to allow it once when first extracted.

### Automatic Exclusion (Development)

If running the download script as Administrator, it will automatically add a Windows Defender exclusion for the `assets/chisel/` directory:

```powershell
# Run with admin privileges
powershell -ExecutionPolicy Bypass -File scripts/setup-chisel-flutter-assets.ps1
```

### Manual Exclusion (Users)

For end users who download the binaries, they can add an exclusion for the app directory:
```powershell
Add-MpPreference -ExclusionPath "$env:USERPROFILE\Documents\CloudToLocalLLM\chisel"
```

## Building from Source (Alternative)

If you prefer to build Chisel from source to avoid detection issues, follow the instructions at:
https://github.com/jpillora/chisel#install-from-source

