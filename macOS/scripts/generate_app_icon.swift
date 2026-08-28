#!/usr/bin/env swift
import Foundation
import AppKit
import CoreGraphics

func createIconImage(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }
    
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    
    // 1. macOS Squircle Background Container (App Icon Squircle)
    let margin = size * 0.08
    let squircleRect = rect.insetBy(dx: margin, dy: margin)
    let cornerRadius = squircleRect.width * 0.224
    let squirclePath = CGPath(
        roundedRect: squircleRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )
    
    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.035),
        blur: size * 0.07,
        color: NSColor.black.withAlphaComponent(0.45).cgColor
    )
    ctx.setFillColor(NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1.0).cgColor)
    ctx.addPath(squirclePath)
    ctx.fillPath()
    ctx.restoreGState()
    
    // Gradient fill for background tile
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(red: 0.18, green: 0.19, blue: 0.22, alpha: 1.0).cgColor,
        NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1.0).cgColor
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: squircleRect.midX, y: squircleRect.maxY),
            end: CGPoint(x: squircleRect.midX, y: squircleRect.minY),
            options: []
        )
    }
    
    // Top inner rim highlight
    ctx.setLineWidth(size * 0.008)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
    ctx.addPath(squirclePath)
    ctx.strokePath()
    ctx.restoreGState()
    
    // 2. Draw Minimalist Flat White C-Clamp Logo in Center
    let logoScale = squircleRect.width * 0.62
    let ox = squircleRect.midX - logoScale / 2.0
    let oy = squircleRect.midY - logoScale / 2.0
    
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: ox + x * logoScale, y: oy + y * logoScale)
    }
    func r(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat) -> CGRect {
        CGRect(x: ox + x * logoScale, y: oy + y * logoScale, width: rw * logoScale, height: rh * logoScale)
    }
    
    ctx.saveGState()
    ctx.setFillColor(NSColor.white.cgColor)
    
    // C-Frame Path
    let cFrame = CGMutablePath()
    let outerR = 0.22 * logoScale
    let innerR = 0.12 * logoScale
    
    cFrame.move(to: p(0.66, 0.20))
    cFrame.addLine(to: p(0.66, 0.28))
    cFrame.addLine(to: p(0.56, 0.28))
    cFrame.addLine(to: p(0.44, 0.28))
    cFrame.addArc(tangent1End: p(0.36, 0.28), tangent2End: p(0.36, 0.40), radius: innerR)
    cFrame.addLine(to: p(0.36, 0.60))
    cFrame.addArc(tangent1End: p(0.36, 0.72), tangent2End: p(0.48, 0.72), radius: innerR)
    cFrame.addLine(to: p(0.56, 0.72))
    cFrame.addLine(to: p(0.56, 0.80))
    cFrame.addLine(to: p(0.44, 0.80))
    cFrame.addArc(tangent1End: p(0.20, 0.80), tangent2End: p(0.20, 0.58), radius: outerR)
    cFrame.addLine(to: p(0.20, 0.42))
    cFrame.addArc(tangent1End: p(0.20, 0.20), tangent2End: p(0.42, 0.20), radius: outerR)
    cFrame.closeSubpath()
    
    ctx.addPath(cFrame)
    ctx.fillPath()
    
    // Top Anvil Post & Head
    let topPost = CGPath(roundedRect: r(0.57, 0.27, 0.08, 0.08), cornerWidth: 0.015 * logoScale, cornerHeight: 0.015 * logoScale, transform: nil)
    ctx.addPath(topPost)
    ctx.fillPath()
    
    let topAnvil = CGPath(roundedRect: r(0.51, 0.35, 0.20, 0.045), cornerWidth: 0.018 * logoScale, cornerHeight: 0.018 * logoScale, transform: nil)
    ctx.addPath(topAnvil)
    ctx.fillPath()
    
    // Bottom Clamp Plate & Threaded Screw
    let bottomPlate = CGPath(roundedRect: r(0.46, 0.58, 0.30, 0.05), cornerWidth: 0.02 * logoScale, cornerHeight: 0.02 * logoScale, transform: nil)
    ctx.addPath(bottomPlate)
    ctx.fillPath()
    
    // Screw threads
    let threadX: CGFloat = 0.55
    let threadW: CGFloat = 0.12
    let threadH: CGFloat = 0.022
    for i in 0..<3 {
        let ty: CGFloat = 0.64 + CGFloat(i) * 0.040
        let thread = CGPath(roundedRect: r(threadX, ty, threadW, threadH), cornerWidth: 0.01 * logoScale, cornerHeight: 0.01 * logoScale, transform: nil)
        ctx.addPath(thread)
        ctx.fillPath()
    }
    
    // Bottom handle knob
    let knob = CGPath(roundedRect: r(0.53, 0.77, 0.16, 0.035), cornerWidth: 0.015 * logoScale, cornerHeight: 0.015 * logoScale, transform: nil)
    ctx.addPath(knob)
    ctx.fillPath()
    
    ctx.restoreGState()
    
    img.unlockFocus()
    return img
}

func savePNG(image: NSImage, to url: URL) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to get PNG data")
        return
    }
    try? pngData.write(to: url)
}

let fm = FileManager.default
let resourcesDir = URL(fileURLWithPath: "Resources")
let iconsetDir = resourcesDir.appendingPathComponent("AppIcon.iconset")
try? fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// Sizes for iconset
let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    let img = createIconImage(size: size)
    let fileURL = iconsetDir.appendingPathComponent(name)
    savePNG(image: img, to: fileURL)
}

// Master 1024x1024
let master = createIconImage(size: 1024)
savePNG(image: master, to: resourcesDir.appendingPathComponent("AppIcon.png"))

print("Generating AppIcon.icns via iconutil...")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir.path, "-o", resourcesDir.appendingPathComponent("AppIcon.icns").path]
try? task.run()
task.waitUntilExit()

print("AppIcon.icns created successfully!")
