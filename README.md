# SqueezeBar

A lightweight, hardware-accelerated macOS menu bar utility for fast, effortless media compression.

SqueezeBar runs as an accessory in the macOS menu bar. Drag and drop single or multiple images, videos, or audio files over the menu bar icon to compress them in the background using Apple Silicon hardware acceleration. Optimized files are saved alongside the originals without replacing them.

---

## Features

- **Expandable Drop Target**: Minimal menu bar icon that expands into an active drop zone during drag operations.
- **Hardware-Accelerated Compression**:
  - **Video**: HEVC (H.265) and H.264 encoding via `AVFoundation` and `VideoToolbox`.
  - **Images**: Accelerated resizing and conversion using `Accelerate` (vImage) and `ImageIO` (WebP, HEIC, JPEG, PNG).
  - **Audio**: Fast AAC encoding via `AVFoundation`.
- **Batch Processing & Folder Monitoring**: Queue multiple files at once or set watched folders for automatic compression.
- **Privacy First**: All processing takes place locally on your Mac. No network requests or telemetry.
- **Statistics & Customization**: Track total space saved, configure compression quality presets, strip EXIF metadata, and customize output file suffixes.

---

## Installation

### Direct Download (Release)

1. Download the latest `SqueezeBar.zip` from the [Releases](https://github.com/MrBunUniverse/SquezeBar/releases) section.
2. Unzip and drag `SqueezeBar.app` into your `/Applications` folder.
3. Open the app. 

> **First Launch on macOS:**
> Since this build is not notarized through an Apple Developer ID, macOS Gatekeeper may show a warning on first open. To open:
> - Right-click (or Control-click) `SqueezeBar.app` and choose **Open**.
> - Or go to **System Settings > Privacy & Security** and click **Open Anyway**.

---

## Building from Source

### Requirements
- macOS 13.0 or later
- Swift 5.9+ / Xcode command line tools

### Build & Run
```bash
# Clone the repository
git clone https://github.com/MrBunUniverse/SquezeBar.git
cd SquezeBar

# Build release application bundle
./scripts/bundle_app.sh

# Launch the app
open SqueezeBar.app
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
