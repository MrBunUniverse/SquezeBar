# SqueezeBar for Windows (Planned / In Development)

This directory houses the upcoming Windows version of **SqueezeBar**, designed for Windows 11 with Fluent Design and hardware-accelerated media pipelines.

---

## Target Architecture

- **UI & Shell**: C# / .NET 8 (WinUI 3 / WPF with Mica & Acrylic translucent styling) or Tauri 2.0 (Rust + Web).
- **Video & Audio**: Bundled FFmpeg with hardware acceleration auto-detection (Nvidia NVENC, Intel QuickSync, AMD AMF).
- **Images**: SkiaSharp / libwebp / libheif for WebP, HEIC, AVIF, and JPEG.
- **PDFs**: PDFium for vector-preserving DPI downsampling.
- **System Integration**:
  - System Tray flyout anchored at bottom-right.
  - Floating Desktop Drop Basket with magnetic edge snapping.

---

## Planned Directory Structure

```text
windows/
├── src/                    # Application source code
├── assets/                 # App icons, background assets
├── build/                  # Build scripts & MSIX / InnoSetup packaging
└── README.md
```
