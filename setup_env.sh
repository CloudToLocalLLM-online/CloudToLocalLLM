#!/bin/bash
set -e

echo "Starting environment setup update..."

# 1. Install System Packages
echo "Installing system packages (requires sudo)..."
# Added: docker, docker-compose
sudo pacman -S --noconfirm git nodejs npm base-devel jdk-openjdk android-tools unzip zip cmake ninja github-cli azure-cli sentry-cli docker docker-compose

# 2. Install AUR Packages
echo "Installing AUR packages (requires user interaction)..."
paru -S --noconfirm google-chrome android-studio android-sdk-cmdline-tools-latest supabase-bin

# 3. Install Flutter via FVM (if not already done)
if ! command -v fvm &> /dev/null; then
    echo "Installing FVM..."
    sudo pacman -S --noconfirm fvm
    echo "Installing Flutter Stable..."
    fvm install stable
    fvm global stable
else
    echo "FVM already installed."
fi

# Add FVM to PATH in fish config if not present
if ! grep -q "fvm" ~/.config/fish/config.fish; then
    echo "Adding FVM to fish path..."
    mkdir -p ~/.config/fish
    echo 'set -gx PATH $HOME/fvm/default/bin $PATH' >> ~/.config/fish/config.fish
fi

# Set CHROME_EXECUTABLE for Flutter
if ! grep -q "CHROME_EXECUTABLE" ~/.config/fish/config.fish; then
    echo "Setting CHROME_EXECUTABLE..."
    echo 'set -gx CHROME_EXECUTABLE /usr/bin/google-chrome-stable' >> ~/.config/fish/config.fish
fi

# Set ANDROID_HOME if installing via AUR package
if ! grep -q "ANDROID_HOME" ~/.config/fish/config.fish; then
    echo "Setting ANDROID_HOME..."
    echo 'set -gx ANDROID_HOME /opt/android-sdk' >> ~/.config/fish/config.fish
fi

# 4. Copy Configuration Files
echo "Copying configuration files..."
SOURCE_DIR="/run/media/rightguy/OS/Users/rightguy"

if [ -f "$SOURCE_DIR/.gitconfig" ]; then
    cp "$SOURCE_DIR/.gitconfig" ~/.gitconfig
    echo "Copied .gitconfig"
else
    echo "WARNING: $SOURCE_DIR/.gitconfig not found"
fi

if [ -d "$SOURCE_DIR/.ssh" ]; then
    mkdir -p ~/.ssh
    cp -r "$SOURCE_DIR/.ssh/"* ~/.ssh/
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/id_rsa* 2>/dev/null || true
    echo "Copied .ssh keys"
else
    echo "WARNING: $SOURCE_DIR/.ssh directory not found"
fi

echo "----------------------------------------------------------------"
echo "Setup update complete!"
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. Enable and start Docker:"
echo "   sudo systemctl enable --now docker"
echo "   sudo usermod -aG docker \$USER"
echo "   newgrp docker"
echo ""
echo "2. Authenticate CLI Tools:"
echo "   gh auth login"
echo "   az login"
echo "   sentry-cli login"
echo "   supabase login"
echo ""
echo "3. Restart your shell."
echo "----------------------------------------------------------------"
