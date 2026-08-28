import Cocoa
import CoreGraphics

// ==============================================================================
// Generate Minimalist Retina DMG Background Image (1080x720 for 540x360 pt)
// ==============================================================================

let width: CGFloat = 1080
let height: CGFloat = 720
let size = NSSize(width: width, height: height)

let image = NSImage(size: size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Failed to get CGContext")
}

// 1. Sleek Flat / Minimalist Dark Obsidian Background
let topColor = NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.14, alpha: 1.0)
let bottomColor = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.10, alpha: 1.0)
let bgGradient = NSGradient(starting: topColor, ending: bottomColor)
bgGradient?.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

// 2. Subtle ambient glow between icons
context.saveGState()
let glowColor = NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.90, alpha: 0.06).cgColor
context.setFillColor(glowColor)
context.addEllipse(in: CGRect(x: width / 2 - 160, y: height / 2 - 100, width: 320, height: 200))
context.fillPath()
context.restoreGState()

// Center Y for icons (Cocoa bottom-left origin = 350)
let iconCenterY: CGFloat = 350
let arrowStartX: CGFloat = 460
let arrowEndX: CGFloat = 620

// 3. Draw Sleek Modern Arrow
let arrowPath = NSBezierPath()
arrowPath.lineWidth = 5
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round

// Main stem
arrowPath.move(to: NSPoint(x: arrowStartX, y: iconCenterY))
arrowPath.line(to: NSPoint(x: arrowEndX, y: iconCenterY))

// Arrow chevrons
arrowPath.move(to: NSPoint(x: arrowEndX - 24, y: iconCenterY + 20))
arrowPath.line(to: NSPoint(x: arrowEndX, y: iconCenterY))
arrowPath.line(to: NSPoint(x: arrowEndX - 24, y: iconCenterY - 20))

// Glow layer
NSColor(calibratedRed: 0.30, green: 0.60, blue: 1.0, alpha: 0.30).setStroke()
arrowPath.lineWidth = 9
arrowPath.stroke()

// Core crisp arrow line
NSColor(calibratedWhite: 0.90, alpha: 0.95).setStroke()
arrowPath.lineWidth = 4.5
arrowPath.stroke()

// 4. Clean Minimalist Instructional Header (Top Center)
let titleFont = NSFont.systemFont(ofSize: 24, weight: .semibold)
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 0.95),
    .paragraphStyle: {
        let ps = NSMutableParagraphStyle()
        ps.alignment = .center
        return ps
    }()
]

let titleText = "Install SqueezeBar"
let titleRect = NSRect(x: 0, y: height - 110, width: width, height: 36)
(titleText as NSString).draw(in: titleRect, withAttributes: titleAttributes)

// Subtitle (Top below title)
let subtitleFont = NSFont.systemFont(ofSize: 15, weight: .regular)
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: subtitleFont,
    .foregroundColor: NSColor(calibratedWhite: 0.55, alpha: 0.80),
    .paragraphStyle: {
        let ps = NSMutableParagraphStyle()
        ps.alignment = .center
        return ps
    }()
]

let subtitleText = "Drag the SqueezeBar icon to the Applications folder to install"
let subtitleRect = NSRect(x: 0, y: height - 145, width: width, height: 26)
(subtitleText as NSString).draw(in: subtitleRect, withAttributes: subtitleAttributes)

// 5. Minimalist Target Guides
// Subtle dashed receiver frame around Applications Folder (x=800, y=iconCenterY)
let receiverBox = NSBezierPath(roundedRect: NSRect(x: 800 - 105, y: iconCenterY - 95, width: 210, height: 200), xRadius: 26, yRadius: 26)
receiverBox.lineWidth = 2
let dashPattern: [CGFloat] = [7, 7]
receiverBox.setLineDash(dashPattern, count: 2, phase: 0)
NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.0, alpha: 0.25).setStroke()
receiverBox.stroke()

// Subtle source frame around SqueezeBar (x=280, y=iconCenterY)
let sourceBox = NSBezierPath(roundedRect: NSRect(x: 280 - 105, y: iconCenterY - 95, width: 210, height: 200), xRadius: 26, yRadius: 26)
sourceBox.lineWidth = 1.5
NSColor(calibratedWhite: 1.0, alpha: 0.08).setStroke()
sourceBox.stroke()

image.unlockFocus()

// Save PNG
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to convert image to PNG")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/dmg_background.png"
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Successfully generated Retina DMG background at \(outputPath)")
