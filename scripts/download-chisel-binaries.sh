#!/bin/bash
# Download Chisel binaries for Flutter app bundling
# This script downloads Chisel for Windows, macOS, and Linux (amd64 and arm64)

set -e

CHISEL_VERSION="${CHISEL_VERSION:-1.9.1}"
ASSETS_DIR="${ASSETS_DIR:-assets/chisel}"

echo "Downloading Chisel v${CHISEL_VERSION} binaries for Flutter app..."

# Create assets directory
mkdir -p "$ASSETS_DIR"

# Platforms and architectures to download
PLATFORMS=(
  "windows_amd64"
  "windows_arm64"
  "darwin_amd64"
  "darwin_arm64"
  "linux_amd64"
  "linux_arm64"
)

for platform in "${PLATFORMS[@]}"; do
  IFS='_' read -r os arch <<< "$platform"
  
  if [ "$os" = "windows" ]; then
    FILE="chisel_${CHISEL_VERSION}_${os}_${arch}.zip"
    BINARY="chisel.exe"
    EXTRACT_CMD="unzip"
  else
    FILE="chisel_${CHISEL_VERSION}_${os}_${arch}.gz"
    BINARY="chisel"
    EXTRACT_CMD="gunzip"
  fi
  
  URL="https://github.com/jpillora/chisel/releases/download/v${CHISEL_VERSION}/${FILE}"
  TARGET="$ASSETS_DIR/chisel-$os${arch#amd64}"
  if [ "$os" = "windows" ]; then
    TARGET="${TARGET}.exe"
  fi
  
  echo "Downloading $platform..."
  
  if command -v curl &> /dev/null; then
    curl -L -o "$ASSETS_DIR/$FILE" "$URL"
  elif command -v wget &> /dev/null; then
    wget -O "$ASSETS_DIR/$FILE" "$URL"
  else
    echo "Error: curl or wget required"
    exit 1
  fi
  
  # Extract
  if [ "$os" = "windows" ]; then
    if command -v unzip &> /dev/null; then
      unzip -q -o "$ASSETS_DIR/$FILE" -d "$ASSETS_DIR"
      mv "$ASSETS_DIR/$BINARY" "$TARGET" 2>/dev/null || true
      rm -f "$ASSETS_DIR/$FILE"
    fi
  else
    gunzip -c "$ASSETS_DIR/$FILE" > "$TARGET"
    chmod +x "$TARGET"
    rm -f "$ASSETS_DIR/$FILE"
  fi
  
  echo "✓ $platform -> $TARGET"
done

echo ""
echo "Chisel binaries downloaded to $ASSETS_DIR/"
echo "Don't forget to update pubspec.yaml to include these assets!"

