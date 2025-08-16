#!/bin/sh
echo "--- Starting yay installation script ---"

echo "--- Removing old yay directory... ---"
rm -rf /tmp/yay

echo "--- Cloning yay repository... ---"
git clone https://aur.archlinux.org/yay.git /tmp/yay

echo "--- Changing to yay directory... ---"
cd /tmp/yay

echo "--- Building and installing yay (password may be required)... ---"
makepkg -si

echo "--- Checking if yay is in the PATH... ---"
if command -v yay >/dev/null 2>&1; then
  echo "--- yay has been installed successfully. ---"
else
  echo "--- ERROR: yay installation failed. The 'yay' command was not found. ---"
  exit 1
fi
