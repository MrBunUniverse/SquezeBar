# SqueezeBar ⚡️ (alpha v0.50)
> Ultra-minimal, hardware-accelerated macOS Menu Bar drop utility for instant media compression by SirJameTV.

SqueezeBar lives entirely in your macOS menu bar as an accessory status item (`LSUIElement = true`). Drag single or multiple images or videos over the menu bar icon, and it dynamically **expands into an interactive drop pill** with smooth AppKit/SwiftUI springs. Once dropped, SqueezeBar compresses all media in the background leveraging Apple Silicon hardware acceleration and saves the optimized files right beside the originals (`photo.png` -> `photo_min.png`).

---

## ✨ Features

- **Dynamic Growing Tab Drop Target (`NSDraggingDestination`)**:
  - Idle state: Clean, minimal status bar symbol (`arrow.down.circle.fill`).
  - Drag hover: Status item smoothly expands with spring physics from 34pt to 165pt into a glowing pill displaying `"Drop to Compress"`.
  - Drag exit / drop: Snaps back seamlessly.
- **Apple Silicon Hardware Acceleration**:
  - **Video (`AVFoundation` / `VideoToolbox`)**: Hardware-accelerated HEVC (H.265) & H.264 video encoding utilizing Apple Silicon Media Engines (`kVTProfileLevel_HEVC_Main_AutoLevel`), target bitrate modeling, and AAC audio transcoding.
  - **Images (`Accelerate` & `ImageIO`)**: SIMD-accelerated resizing and color transforms using `vImage` and `CGImageDestination` with high-efficiency WebP, HEIC, PNG, and JPEG encoding.
- **Progress & Completion Feedback**:
  - During processing: Circular progress ring with live percentage.
  - Completion: Green checkmark badge with native macOS haptic pulse.
  - Output naming: Automatically saves optimized files adjacent to source files (`[name]_min.[ext]`).
- **Quick Popover Hub (SwiftUI)**:
  - Space saved metrics (Total MB saved, percentage reduction, processed files counter).
  - Live processing queue.
  - Recent compression history with one-click "Reveal in Finder".
  - Quality presets (Max Compression, Balanced, Visually Lossless) & target format switch (Preserve Original vs Modern WebP/HEVC).
  - Advanced options: Custom suffix, EXIF metadata stripping, and haptics toggle.

---

## 🛠 Project Structure

```
Project ShrinkDrop/
├── Package.swift                                # Swift Package configuration
├── Resources/
│   ├── Info.plist                              # LSUIElement accessory configuration
│   └── SqueezeBar.entitlements                 # App Sandbox read/write entitlements
├── Sources/
│   └── SqueezeBar/
│       ├── App/
│       │   └── AppDelegate.swift               # Application lifecycle & entry point
│       ├── Engine/
│       │   ├── AcceleratedImageCompressor.swift# Accelerate (vImage) & ImageIO compressor
│       │   ├── HardwareVideoCompressor.swift   # AVFoundation & VideoToolbox hardware encoder
│       │   └── MediaCompressionEngine.swift    # Actor-based queue orchestrator & naming logic
│       ├── Models/
│       │   ├── AppState.swift                  # Central state, persistence & history
│       │   └── CompressionModels.swift         # Data structures, enums, & configuration
│       └── UI/
│           ├── QuickPopoverView.swift          # SwiftUI statistics & settings popover
│           ├── StatusBarController.swift       # NSStatusItem coordinator & spring animator
│           └── StatusItemDropView.swift        # NSDraggingDestination view & custom canvas
├── Tests/
│   └── SqueezeBarTests/
│       └── SqueezeBarTests.swift               # Test suite for compressors & classifications
└── scripts/
    └── bundle_app.sh                           # Script to generate signed SqueezeBar.app bundle
```

---

## 🚀 Building & Running

### 1. Build and Run via Swift Package Manager
```bash
# Build debug
swift build

# Run executable directly
swift run
```

### 2. Run Test Suite
```bash
swift test
```

### 3. Build Signed `.app` Bundle
```bash
./scripts/bundle_app.sh
open SqueezeBar.app
```
