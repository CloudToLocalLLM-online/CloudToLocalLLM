#!/bin/bash
# Install Chisel binary for tunnel server
# Supports Linux (amd64/arm64), macOS (amd64/arm64), and Windows

set -e

CHISEL_VERSION="${CHISEL_VERSION:-1.9.1}"
ARCH="${ARCH:-amd64}"
OS="${OS:-linux}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# Determine OS
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="darwin"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS="linux"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
  OS="windows"
fi

# Determine architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# Download URL
if [ "$OS" = "windows" ]; then
  CHISEL_FILE="chisel_${CHISEL_VERSION}_windows_${ARCH}.zip"
  CHISEL_BINARY="chisel.exe"
else
  CHISEL_FILE="chisel_${CHISEL_VERSION}_${OS}_${ARCH}.gz"
  CHISEL_BINARY="chisel"
fi

CHISEL_URL="https://github.com/jpillora/chisel/releases/download/v${CHISEL_VERSION}/${CHISEL_FILE}"

echo "Installing Chisel v${CHISEL_VERSION} for ${OS}/${ARCH}..."

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download Chisel
echo "Downloading from: $CHISEL_URL"
if command -v curl &> /dev/null; then
  curl -L -o "$TMP_DIR/$CHISEL_FILE" "$CHISEL_URL"
elif command -v wget &> /dev/null; then
  wget -O "$TMP_DIR/$CHISEL_FILE" "$CHISEL_URL"
else
  echo "Error: curl or wget required"
  exit 1
fi

# Extract and install
if [ "$OS" = "windows" ]; then
  # Windows - unzip
  if command -v unzip &> /dev/null; then
    unzip -q "$TMP_DIR/$CHISEL_FILE" -d "$TMP_DIR"
    mv "$TMP_DIR/$CHISEL_BINARY" "$INSTALL_DIR/$CHISEL_BINARY"
  else
    echo "Error: unzip required for Windows"
    exit 1
  fi
else
  # Linux/macOS - gunzip
  gunzip -c "$TMP_DIR/$CHISEL_FILE" > "$TMP_DIR/$CHISEL_BINARY"
  chmod +x "$TMP_DIR/$CHISEL_BINARY"
  sudo mv "$TMP_DIR/$CHISEL_BINARY" "$INSTALL_DIR/$CHISEL_BINARY"
fi

# Verify installation
if [ -f "$INSTALL_DIR/$CHISEL_BINARY" ]; then
  echo "Chisel installed successfully to $INSTALL_DIR/$CHISEL_BINARY"
  "$INSTALL_DIR/$CHISEL_BINARY" --version || echo "Version check failed (binary may be correct)"
else
  echo "Error: Installation failed"
  exit 1
fi

