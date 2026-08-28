# SqueezeBar

A lightweight, hardware-accelerated media compression utility for **macOS** *(Windows version in active development)*.

SqueezeBar provides effortless 1-drop batch media compression, a desktop floating drop basket, and per-file fine-tuning with zero telemetry and 100% on-device processing.

---

## Project Structure

```text
Project ShrinkDrop/
├── macOS/                   # 🍏 macOS Native Swift / SwiftUI Application (v0.98 Released)
│   ├── Package.swift
│   ├── Sources/
│   ├── Resources/
│   ├── Tests/
│   └── scripts/
│       ├── bundle_app.sh    # Builds SqueezeBar.app
│       └── create_dmg.sh    # Builds SqueezeBar-0.98.dmg with custom background
├── windows/                 # 🪟 Windows Application (🚧 In Active Development)
│   └── README.md
├── LICENSE                  # GPLv3 License
└── README.md
```

---

## macOS Version (v0.98 • Available Now)

### Features
- **Desktop Floating Drop Ball**: Edge-docking magnetic liquid glass basket with Apple bezel edge-tab morphing and proximity cursor detection.
- **Dual-Zone Popover Interface**: Instant Quick Squeeze + Custom Staged Queue with per-file sliders.
- **Individual Per-File Settings**: Custom quality, scale, format/codec, target size limits (Discord 25MB, Email 10MB), and metadata privacy toggles.
- **100% Native & Lightweight (~2.3 MB)**: Powered by Apple Silicon Hardware Media Engines (`AVFoundation`, `VideoToolbox`, `ImageIO`, `PDFKit`).

### Download macOS Installer
Download the latest drag-and-drop installer: **[`SqueezeBar-0.98.dmg`](https://github.com/MrBunUniverse/SquezeBar/releases/latest)**

### Build from Source (macOS)
```bash
cd macOS
# Build production bundle
./scripts/bundle_app.sh

# Or create the DMG installer
./scripts/create_dmg.sh
```

---

## Windows Version (🚧 In Active Development)

> [!NOTE]
> **Status:** The Windows version is currently under active development and is **not yet released**. Pre-built binaries are currently available for macOS only.

The upcoming Windows edition is being designed for Windows 11 with Fluent Design (Mica/Acrylic translucent materials), System Tray integration, and multi-vendor GPU hardware acceleration (Nvidia NVENC, Intel QuickSync, AMD AMF). See [`windows/README.md`](windows/README.md) for architectural details and progress.

---

## License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**. See the [LICENSE](LICENSE) file for details.
