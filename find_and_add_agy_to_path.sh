#!/bin/bash

# This script helps to find the 'agy' executable and add it to your PATH.

echo "This script will help you find the 'agy' executable from your Antigravity IDE installation."
echo "I will ask you for the installation path of your Antigravity IDE."
echo ""

read -p "Please enter the full path to your Antigravity IDE installation directory: " ide_path

if [ ! -d "$ide_path" ]; then
    echo "Error: The directory '$ide_path' does not exist."
    exit 1
fi

echo "Searching for 'agy' in '$ide_path'..."
agy_path=$(find "$ide_path" -name agy -type f 2>/dev/null)

if [ -z "$agy_path" ]; then
    echo "Error: Could not find the 'agy' executable in '$ide_path'."
    echo "Please make sure you have provided the correct installation directory."
    exit 1
fi

agy_dir=$(dirname "$agy_path")

echo "Found 'agy' at: $agy_path"
echo "The directory to add to your PATH is: $agy_dir"
echo ""

echo "This script will attempt to add the 'agy' directory to your shell's configuration file."
echo "It will try to detect your shell and modify the correct file (~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish)."
echo ""

# Detect shell
shell_name=$(basename "$SHELL")
config_file=""

if [ "$shell_name" = "bash" ]; then
    config_file="$HOME/.bashrc"
elif [ "$shell_name" = "zsh" ]; then
    config_file="$HOME/.zshrc"
elif [ "$shell_name" = "fish" ]; then
    config_file="$HOME/.config/fish/config.fish"
else
    echo "Unsupported shell: $shell_name. Please add the following line to your shell's configuration file manually:"
    echo "export PATH=\"
$PATH:$agy_dir\""
    exit 1
fi

echo "Your shell is '$shell_name'. The configuration file is '$config_file'."

# Add to path if it's not already there
if ! grep -q "PATH.*$agy_dir" "$config_file"; then
    if [ "$shell_name" = "fish" ]; then
        echo "set -gx PATH \"$agy_dir\" $PATH" >> "$config_file"
        echo "The following line has been added to your '$config_file':"
        echo "set -gx PATH \"$agy_dir\" $PATH"
    else
        echo "export PATH=\"
$PATH:$agy_dir\"" >> "$config_file"
        echo "The following line has been added to your '$config_file':"
        echo "export PATH=\"
$PATH:$agy_dir\""
    fi
    echo ""
    echo "To apply the changes, please run the following command or restart your terminal:"
    if [ "$shell_name" = "fish" ]; then
        echo "source $config_file"
    else
        echo "source $config_file"
    fi
else
    echo "The directory '$agy_dir' is already in your PATH in '$config_file'."
fi
