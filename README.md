# WSL2 dxgkrnl DRM Integration Patches

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

This repository contains patches to integrate DRM (Direct Rendering Manager) subsystem with Microsoft's `dxgkrnl` driver for WSL2. These patches enable standard `/dev/dri/renderD*` nodes for GPU access, improving compatibility with Linux graphics applications.

## 🎯 What This Does

The `dxgkrnl` driver is Microsoft's virtual GPU driver for WSL2 that provides GPU acceleration through Hyper-V. By default, it only exposes `/dev/dxg` device node.

**This patch adds:**
- `/dev/dri/card0`, `/dev/dri/card1`, ... (DRM card devices)
- `/dev/dri/renderD128`, `/dev/dri/renderD129`, ... (DRM render nodes)
- Standard DRM subsystem integration
- Per-adapter DRM device registration

## 📁 Repository Structure

```
wsl-dxgkrnl-drm-patches/
├── README.md                 # This file
├── LICENSE                   # GPL-2.0
├── patches/
│   ├── 0001-dxgkrnl-add-drm-headers-and-device.patch
│   ├── 0002-dxgkrnl-add-drm-to-adapter-lifecycle.patch
│   ├── 0003-dxgkrnl-export-get-current-process.patch
│   └── 0004-dxgkrnl-add-dxgdrm-to-makefile.patch
├── scripts/
│   ├── apply-patches.sh      # Apply patches to kernel source
│   └── create-patches.sh     # Regenerate patches from modified source
└── src/
    └── dxgdrm.c              # New DRM integration source file
```

## 🔧 Requirements

- WSL2 with Windows 10/11
- Linux kernel source (Microsoft WSL2-Linux-Kernel recommended)
- Build dependencies:
  ```bash
  sudo apt-get install build-essential flex bison libssl-dev libelf-dev \
                       bc dwarves cpio libncurses-dev
  ```

## 📖 Usage

### Method 1: Quick Apply (Recommended)

```bash
# 1. Clone WSL2 kernel source
git clone https://github.com/microsoft/WSL2-Linux-Kernel.git
cd WSL2-Linux-Kernel
git checkout linux-msft-wsl-6.6.y  # or your preferred version

# 2. Clone this patches repository
git clone https://github.com/0deep/wsl-dxgkrnl-drm-patches.git

# 3. Apply patches
wsl-dxgkrnl-drm-patches/scripts/apply-patches.sh .

# 4. Configure kernel

# Option A: Use current running kernel config (Recommended)
zcat /proc/config.gz > .config
make olddefconfig

# Option B: Use Microsoft's default config
# cp Microsoft/config-wsl .config
# make olddefconfig

# 5. Build kernel
make -j$(nproc)

# 6. Copy kernel to Windows and configure
cp arch/x86/boot/bzImage /mnt/c/Users/YOUR_USERNAME/bzImage
```

**Note**: Using Option A (current kernel config) is recommended as it preserves your existing kernel configuration and only adds DRM support.

### Method 2: Manual Apply

```bash
# Apply patches one by one
cd WSL2-Linux-Kernel

# 1. Apply header modifications
patch -p1 < ../wsl-dxgkrnl-drm-patches/patches/0001-dxgkrnl-add-drm-headers-and-device.patch

# 2. Apply adapter lifecycle changes
patch -p1 < ../wsl-dxgkrnl-drm-patches/patches/0002-dxgkrnl-add-drm-to-adapter-lifecycle.patch

# 3. Apply module changes
patch -p1 < ../wsl-dxgkrnl-drm-patches/patches/0003-dxgkrnl-export-get-current-process.patch

# 4. Apply Makefile changes
patch -p1 < ../wsl-dxgkrnl-drm-patches/patches/0004-dxgkrnl-add-dxgdrm-to-makefile.patch

# 5. Copy new source file
cp ../wsl-dxgkrnl-drm-patches/src/dxgdrm.c drivers/hv/dxgkrnl/
```

### Configuring WSL to Use Custom Kernel

Create or edit `C:\Users\YOUR_USERNAME\.wslconfig`:

```ini
[wsl2]
kernel=C:\\Users\\YOUR_USERNAME\\bzImage
```

Then restart WSL:
```powershell
wsl --shutdown
wsl
```

## ✅ Verification

After booting with the new kernel:

```bash
# Check kernel version
uname -r
# Expected: 6.6.x-microsoft-standard-WSL2+

# Verify DRM nodes
ls -la /dev/dri/
# Expected:
# crw-rw---- 1 root video  226,   0 ... card0
# crw-rw---- 1 root video  226,   1 ... card1
# crw-rw---- 1 root render 226, 128 ... renderD128
# crw-rw---- 1 root render 226, 129 ... renderD129

# Check dmesg for DRM initialization
dmesg | grep -i "drm.*initialized"
# Expected:
# [drm] Initialized dxgkrnl 2.0.3 20221201 for XXXX:00:00.0 on minor 0

# Legacy device still works
ls -la /dev/dxg
```

## 🔬 Technical Details

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Space Applications                   │
│              (Mesa, Vulkan, OpenGL, CUDA, etc.)             │
└──────────────────────────┬──────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│  /dev/dxg     │  │/dev/dri/card* │  │/dev/dri/      │
│  (legacy)     │  │  (DRM card)   │  │  renderD*     │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │      dxgkrnl driver    │
              │  ┌──────────────────┐  │
              │  │    dxgdrm.c      │  │  ← NEW
              │  │  (DRM wrapper)   │  │
              │  └────────┬─────────┘  │
              │           │            │
              │  ┌────────▼─────────┐  │
              │  │  dxgadapter.c    │  │
              │  │  (GPU adapters)  │  │
              │  └────────┬─────────┘  │
              └───────────┼────────────┘
                          │
                          ▼
              ┌────────────────────────┐
              │    Hyper-V VM Bus      │
              └────────────────────────┘
                          │
                          ▼
              ┌────────────────────────┐
              │   Windows Host GPU     │
              │   (NVIDIA/AMD/Intel)   │
              └────────────────────────┘
```

### Modified Files

| File | Changes |
|------|---------|
| `dxgkrnl.h` | Added DRM headers, `drm_device` pointer in `dxgadapter` struct, function declarations |
| `dxgadapter.c` | Added DRM device init/destroy in adapter start/stop |
| `dxgmodule.c` | Exported `dxgglobal_get_current_process()` function |
| `Makefile` | Added `dxgdrm.o` to build |
| `dxgdrm.c` | **NEW** - DRM driver integration (open, close, ioctl handlers) |

### DRM Driver Features

- **Driver name**: `dxgkrnl`
- **Driver features**: `DRIVER_RENDER` (render node only, no display)
- **Version**: 2.0.3
- **Date**: 20221201

## 🛠️ Development Guide

### Adding New Features

1. **Fork this repository**
2. **Create feature branch**: `git checkout -b feature/my-feature`
3. **Modify source files** in WSL2-Linux-Kernel
4. **Regenerate patches**:
   ```bash
   ./scripts/create-patches.sh /path/to/WSL2-Linux-Kernel
   ```
5. **Test thoroughly**
6. **Submit pull request**

### Porting to New Kernel Versions

When a new WSL2 kernel version is released:

1. Clone new kernel source
2. Attempt to apply patches:
   ```bash
   ./scripts/apply-patches.sh /path/to/new-kernel
   ```
3. If conflicts occur:
   - Manually resolve conflicts
   - Update patches using `create-patches.sh`
4. Test and verify DRM functionality
5. Update version compatibility in README

### Testing Checklist

- [ ] Kernel compiles without errors
- [ ] `/dev/dri/` nodes created on boot
- [ ] `/dev/dxg` still works (backward compatibility)
- [ ] `dmesg` shows DRM initialization
- [ ] GPU applications can detect devices
- [ ] No kernel panics or oops

## 🐛 Troubleshooting

### DRM nodes not appearing

```bash
# Check if dxgkrnl is loaded
dmesg | grep dxgkrnl

# Verify kernel version
uname -r  # Should show your custom kernel

# Check for errors
dmesg | grep -i error | grep -i drm
```

### Build errors

```bash
# Missing DRM headers
sudo apt-get install libdrm-dev

# Ensure CONFIG_DRM is enabled in kernel config
grep CONFIG_DRM .config
# Should show: CONFIG_DRM=y or CONFIG_DRM=m
```

### IOCTL errors in dmesg

Some IOCTL errors (`-22`, `-2`) are normal and do not affect DRM functionality. These are related to feature queries that may not be supported by the host driver.

## 📋 Compatibility

| WSL2 Kernel Version | Status | Notes |
|---------------------|--------|-------|
| 6.6.x | ✅ Tested | Fully compatible |
| 6.1.x | ⚠️ Untested | Should work with minor adjustments |
| 5.15.x | ❌ Not supported | API differences |

| Host GPU | Status |
|----------|--------|
| NVIDIA | ⚠️ Should work |
| AMD | ⚠️ Should work |
| Intel | ✅ Tested |

## 🤝 Contributing

Contributions are welcome! Please:

1. Open an issue for discussion before major changes
2. Follow kernel coding style
3. Test on multiple configurations if possible
4. Update documentation as needed

## 📄 License

This project is licensed under GPL-2.0, same as the Linux kernel.

The original `dxgkrnl` driver is Copyright (c) Microsoft Corporation.

## 🔗 Related Projects

- [microsoft/WSL2-Linux-Kernel](https://github.com/microsoft/WSL2-Linux-Kernel) - Official WSL2 kernel
- [thexperiments/dxgkrnl-dkms-git](https://github.com/thexperiments/dxgkrnl-dkms-git) - DKMS module for Hyper-V GPU partitioning
- [Nevuly/WSL2-Linux-Kernel-Rolling](https://github.com/Nevuly/WSL2-Linux-Kernel-Rolling) - Rolling release WSL2 kernel

## 📞 Support

- **Issues**: Open a GitHub issue
- **Discussions**: Use GitHub Discussions for questions

---

*This project is not affiliated with Microsoft. WSL2 and dxgkrnl are trademarks of Microsoft Corporation.*
