#!/bin/bash
#
# create-patches.sh - Generate patch files from modified kernel source
#
# Usage: ./create-patches.sh /path/to/WSL2-Linux-Kernel
#
# This script creates patch files by comparing the modified kernel source
# against the original git repository state.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/../patches"
SRC_DIR="$SCRIPT_DIR/../src"

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/WSL2-Linux-Kernel"
    echo ""
    echo "This script generates patch files from a modified kernel source."
    echo "The kernel source should have uncommitted changes for dxgkrnl DRM integration."
    exit 1
fi

KERNEL_DIR="$1"

# Verify kernel directory
if [ ! -d "$KERNEL_DIR/.git" ]; then
    echo "Error: $KERNEL_DIR is not a git repository"
    exit 1
fi

echo "=============================================="
echo "  WSL2 dxgkrnl DRM Patch Generator"
echo "=============================================="
echo ""

cd "$KERNEL_DIR"

# Clear old patches
rm -f "$PATCHES_DIR"/*.patch

# Generate patches
echo "Generating patches..."
echo ""

git diff HEAD -- drivers/hv/dxgkrnl/dxgkrnl.h > "$PATCHES_DIR/0001-dxgkrnl-add-drm-headers-and-device.patch"
print_status "0001-dxgkrnl-add-drm-headers-and-device.patch"

git diff HEAD -- drivers/hv/dxgkrnl/dxgadapter.c > "$PATCHES_DIR/0002-dxgkrnl-add-drm-to-adapter-lifecycle.patch"
print_status "0002-dxgkrnl-add-drm-to-adapter-lifecycle.patch"

git diff HEAD -- drivers/hv/dxgkrnl/dxgmodule.c > "$PATCHES_DIR/0003-dxgkrnl-export-get-current-process.patch"
print_status "0003-dxgkrnl-export-get-current-process.patch"

git diff HEAD -- drivers/hv/dxgkrnl/Makefile > "$PATCHES_DIR/0004-dxgkrnl-add-dxgdrm-to-makefile.patch"
print_status "0004-dxgkrnl-add-dxgdrm-to-makefile.patch"

# Copy new source file
if [ -f "$KERNEL_DIR/drivers/hv/dxgkrnl/dxgdrm.c" ]; then
    cp "$KERNEL_DIR/drivers/hv/dxgkrnl/dxgdrm.c" "$SRC_DIR/"
    print_status "Copied dxgdrm.c to src/"
fi

echo ""
echo "=============================================="
print_status "Patches generated successfully!"
echo "=============================================="
echo ""
echo "Generated files:"
ls -la "$PATCHES_DIR"/*.patch
echo ""
ls -la "$SRC_DIR"/*.c 2>/dev/null || true
echo ""
