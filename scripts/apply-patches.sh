#!/bin/bash
#
# apply-patches.sh - Apply DRM integration patches to WSL2 kernel source
#
# Usage: ./apply-patches.sh /path/to/WSL2-Linux-Kernel
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/../patches"
SRC_DIR="$SCRIPT_DIR/../src"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/WSL2-Linux-Kernel"
    echo ""
    echo "This script applies DRM integration patches to the WSL2 kernel source."
    exit 1
fi

# Convert to absolute path
KERNEL_DIR="$(cd "$1" && pwd)"

# Verify kernel directory
if [ ! -f "$KERNEL_DIR/drivers/hv/dxgkrnl/dxgkrnl.h" ]; then
    print_error "Cannot find dxgkrnl driver in $KERNEL_DIR"
    print_error "Make sure you're pointing to a valid WSL2 kernel source directory"
    exit 1
fi

echo "=============================================="
echo "  WSL2 dxgkrnl DRM Integration Patch Applier"
echo "=============================================="
echo ""
echo "Kernel directory: $KERNEL_DIR"
echo ""

# Apply patches
cd "$KERNEL_DIR"

echo "Applying patches..."
echo ""

for patch in "$PATCHES_DIR"/*.patch; do
    if [ -f "$patch" ]; then
        patch_name=$(basename "$patch")
        echo -n "Applying $patch_name... "
        
        if patch -p1 --dry-run < "$patch" > /dev/null 2>&1; then
            patch -p1 < "$patch" > /dev/null 2>&1
            print_status "OK"
        else
            print_warning "Already applied or conflict"
        fi
    fi
done

echo ""

# Copy new source file
echo -n "Copying dxgdrm.c... "
if [ -f "$SRC_DIR/dxgdrm.c" ]; then
    cp "$SRC_DIR/dxgdrm.c" "$KERNEL_DIR/drivers/hv/dxgkrnl/"
    print_status "OK"
else
    print_error "dxgdrm.c not found in $SRC_DIR"
    exit 1
fi

echo ""
echo "=============================================="
print_status "All patches applied successfully!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Configure kernel: cp Microsoft/config-wsl .config && make olddefconfig"
echo "  2. Build kernel:     make -j\$(nproc)"
echo "  3. Copy to Windows:  cp arch/x86/boot/bzImage /mnt/c/Users/YOUR_USER/"
echo "  4. Configure WSL:    Edit C:\\Users\\YOUR_USER\\.wslconfig"
echo "  5. Restart WSL:      wsl --shutdown && wsl"
echo ""
