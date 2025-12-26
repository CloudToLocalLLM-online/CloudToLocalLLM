#!/bin/bash

# CloudToLocalLLM AUR PKGBUILD Update Script
# Updates PKGBUILD to use AppImage distribution instead of source builds

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PKGBUILD_TEMPLATE="$PROJECT_ROOT/build-tools/packaging/aur/PKGBUILD"
AUR_OUTPUT_DIR="$PROJECT_ROOT/dist/aur"
GITHUB_REPO="CloudToLocalLLM-online/CloudToLocalLLM"

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get version from pubspec.yaml
get_version() {
    if [[ -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1
    else
        print_error "pubspec.yaml not found"
        exit 1
    fi
}

# Download and verify AppImage checksum
get_appimage_checksum() {
    local version="$1"
    local appimage_url="https://github.com/$GITHUB_REPO/releases/download/v$version/cloudtolocalllm-$version-x86_64.AppImage"
    local checksum_url="https://github.com/$GITHUB_REPO/releases/download/v$version/cloudtolocalllm-$version-x86_64.AppImage.sha256"
    
    print_status "Downloading checksum for version $version..."
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    
    # Download checksum file
    if curl -L -f "$checksum_url" -o "$temp_dir/checksum.sha256" 2>/dev/null; then
        # Extract just the hash (first field)
        local checksum=$(cut -d' ' -f1 "$temp_dir/checksum.sha256")
        rm -rf "$temp_dir"
        echo "$checksum"
    else
        print_warning "Could not download checksum from GitHub releases"
        print_warning "Using SKIP for checksum - manual verification required"
        rm -rf "$temp_dir"
        echo "SKIP"
    fi
}

# Update PKGBUILD with version and checksums
update_pkgbuild() {
    local version="$1"
    local appimage_checksum="$2"
    
    print_status "Updating PKGBUILD for version $version..."
    
    # Create output directory
    mkdir -p "$AUR_OUTPUT_DIR"
    
    # Copy template
    cp "$PKGBUILD_TEMPLATE" "$AUR_OUTPUT_DIR/PKGBUILD"
    
    # Update version
    sed -i "s/^pkgver=.*/pkgver=$version/" "$AUR_OUTPUT_DIR/PKGBUILD"
    
    # Update checksums
    if [[ "$appimage_checksum" != "SKIP" ]]; then
        sed -i "s/sha256sums=('SKIP'/sha256sums=('$appimage_checksum'/" "$AUR_OUTPUT_DIR/PKGBUILD"
        print_success "Updated PKGBUILD with verified checksum"
    else
        print_warning "PKGBUILD uses SKIP for checksum - manual verification required"
    fi
    
    print_success "PKGBUILD updated successfully"
    print_status "Output: $AUR_OUTPUT_DIR/PKGBUILD"
}

# Generate .SRCINFO file
generate_srcinfo() {
    print_status "Generating .SRCINFO file..."
    
    cd "$AUR_OUTPUT_DIR"
    
    # Check if makepkg is available
    if command -v makepkg &> /dev/null; then
        if makepkg --printsrcinfo > .SRCINFO; then
            print_success "Generated .SRCINFO file"
        else
            print_warning "Failed to generate .SRCINFO - makepkg error"
            print_warning "You may need to generate this manually on an Arch system"
        fi
    else
        print_warning "makepkg not available - .SRCINFO not generated"
        print_warning "Generate .SRCINFO on an Arch Linux system with: makepkg --printsrcinfo > .SRCINFO"
    fi
}

# Validate PKGBUILD
validate_pkgbuild() {
    print_status "Validating PKGBUILD..."
    
    cd "$AUR_OUTPUT_DIR"
    
    # Basic validation
    if [[ ! -f "PKGBUILD" ]]; then
        print_error "PKGBUILD not found"
        return 1
    fi
    
    # Check required fields
    local required_fields=("pkgname" "pkgver" "pkgrel" "pkgdesc" "arch" "url" "license")
    for field in "${required_fields[@]}"; do
        if ! grep -q "^$field=" PKGBUILD; then
            print_error "Missing required field: $field"
            return 1
        fi
    done
    
    print_success "PKGBUILD validation passed"
}

# Create installation instructions
create_instructions() {
    local version="$1"
    
    cat > "$AUR_OUTPUT_DIR/INSTALL.md" << EOF
# CloudToLocalLLM AUR Package Installation

## Version: $version

This AUR package installs CloudToLocalLLM using the AppImage distribution format.

## Installation

### Using an AUR helper (recommended):
\`\`\`bash
yay -S cloudtolocalllm
# or
paru -S cloudtolocalllm
\`\`\`

### Manual installation:
\`\`\`bash
git clone https://aur.archlinux.org/cloudtolocalllm.git
cd cloudtolocalllm
makepkg -si
\`\`\`

## Dependencies

The package will automatically install required dependencies:
- fuse2 (for AppImage support)
- gtk3 (GUI framework)
- libayatana-appindicator (system tray support)

## Optional Dependencies

- docker: For containerized LLM execution
- ollama: For local LLM management
- curl: For API interactions
- wget: For model downloads

## Usage

After installation, run:
\`\`\`bash
cloudtolocalllm
\`\`\`

The application will also be available in your desktop environment's application menu.

## Notes

- This package uses the AppImage distribution format for better compatibility
- The AppImage is installed to /opt/cloudtolocalllm/
- A wrapper script is created in /usr/bin/cloudtolocalllm
- Desktop integration is automatically configured

## Troubleshooting

If you encounter issues with AppImage execution, ensure FUSE is properly configured:
\`\`\`bash
sudo modprobe fuse
\`\`\`

For system tray support, ensure you have a compatible desktop environment and system tray.
EOF

    print_success "Created installation instructions: $AUR_OUTPUT_DIR/INSTALL.md"
}

# Main execution function
main() {
    print_status "CloudToLocalLLM AUR PKGBUILD Update"
    print_status "===================================="
    
    # Get current version
    local version=$(get_version)
    print_status "Current version: $version"
    
    # Get AppImage checksum
    local appimage_checksum=$(get_appimage_checksum "$version")
    
    # Update PKGBUILD
    update_pkgbuild "$version" "$appimage_checksum"
    
    # Generate .SRCINFO
    generate_srcinfo
    
    # Validate PKGBUILD
    validate_pkgbuild
    
    # Create installation instructions
    create_instructions "$version"
    
    print_success "AUR PKGBUILD update completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Review the generated PKGBUILD: $AUR_OUTPUT_DIR/PKGBUILD"
    print_status "2. Test the package on an Arch Linux system"
    print_status "3. Submit to AUR repository"
    print_status ""
    print_status "Files generated:"
    print_status "- $AUR_OUTPUT_DIR/PKGBUILD"
    print_status "- $AUR_OUTPUT_DIR/.SRCINFO (if makepkg available)"
    print_status "- $AUR_OUTPUT_DIR/INSTALL.md"
}

# Execute main function
main "$@"
