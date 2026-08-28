import Foundation
import AppKit
import SwiftUI
import Combine

public final class StatusItemDropView: NSView {
    
    // MARK: - Delegate / Callback
    public weak var controller: StatusBarController?
    
    // MARK: - State
    public enum DisplayMode {
        case idle
        case dragHover
        case processing(progress: Double)
        case success
    }
    
    public var mode: DisplayMode = .idle {
        didSet {
            needsDisplay = true
        }
    }
    
    private var isHighlighted: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false
        
        // Register for all File Drag Types
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"),
            NSPasteboard.PasteboardType("public.item")
        ])
        
        // Observe AppState
        Publishers.CombineLatest4(
            AppState.shared.$isProcessing,
            AppState.shared.$overallProgress,
            AppState.shared.$showSuccessBadge,
            AppState.shared.$menuBarDisplayStyle
        )
        .combineLatest(AppState.shared.$totalBytesSaved, AppState.shared.$isProUser)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] baseTuple, totalSaved, isPro in
            let (isProc, prog, isSuccess, _) = baseTuple
            guard let self = self else { return }
            
            // Dynamically adjust item length based on display style when idle
            if !self.isHoveringDrag {
                self.controller?.updateStatusItemLength()
            }
            
            if isSuccess {
                self.mode = .success
            } else if isProc {
                self.mode = .processing(progress: prog)
            } else {
                self.mode = .idle
            }
        }
        .store(in: &cancellables)
    }
    
    private var isHoveringDrag: Bool = false
    
    // MARK: - Mouse Click Handling
    public override func mouseDown(with event: NSEvent) {
        isHighlighted = true
    }
    
    public override func mouseUp(with event: NSEvent) {
        isHighlighted = false
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            controller?.togglePopover(sender: self)
        }
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        controller?.showContextMenu(for: self, with: event)
    }
    
    // MARK: - NSDraggingDestination
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasValidMediaFiles(in: sender) else {
            return []
        }
        
        isHoveringDrag = true
        mode = .dragHover
        return .copy
    }
    
    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let isValid = hasValidMediaFiles(in: sender)
        if isValid && !isHoveringDrag {
            isHoveringDrag = true
            mode = .dragHover
        }
        return isValid ? .copy : []
    }
    
    public override func draggingExited(_ sender: NSDraggingInfo?) {
        isHoveringDrag = false
        controller?.updateStatusItemLength()
        updateCurrentMode()
    }
    
    public override func draggingEnded(_ sender: NSDraggingInfo) {
        isHoveringDrag = false
        controller?.updateStatusItemLength()
        updateCurrentMode()
    }
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = extractFileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        
        isHoveringDrag = false
        controller?.updateStatusItemLength()
        
        Task {
            await MediaCompressionEngine.shared.processDroppedURLs(urls)
        }
        
        return true
    }
    
    private func updateCurrentMode() {
        let state = AppState.shared
        if state.showSuccessBadge {
            mode = .success
        } else if state.isProcessing {
            mode = .processing(progress: state.overallProgress)
        } else {
            mode = .idle
        }
    }
    
    // MARK: - Drag Helpers
    private func hasValidMediaFiles(in sender: NSDraggingInfo) -> Bool {
        let urls = extractFileURLs(from: sender)
        if !urls.isEmpty {
            return true
        }
        let types = sender.draggingPasteboard.types ?? []
        return types.contains(.fileURL) ||
               types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType")) ||
               types.contains(NSPasteboard.PasteboardType("public.file-url"))
    }
    
    private func extractFileURLs(from sender: NSDraggingInfo) -> [URL] {
        var urls: [URL] = []
        let pb = sender.draggingPasteboard
        
        // 1. NSURL reading
        if let items = pb.readObjects(
            forClasses: [NSURL.self],
            options: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true]
        ) as? [URL], !items.isEmpty {
            urls.append(contentsOf: items)
        }
        
        // 2. Filenames array fallback
        if urls.isEmpty, let filenames = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls.append(contentsOf: filenames.map { URL(fileURLWithPath: $0) })
        }
        
        // 3. Pasteboard items fallback
        if urls.isEmpty, let pasteboardItems = pb.pasteboardItems {
            for item in pasteboardItems {
                if let urlString = item.string(forType: .fileURL), let url = URL(string: urlString) {
                    urls.append(url)
                }
            }
        }
        
        var seen = Set<String>()
        return urls.filter { seen.insert($0.path).inserted }
    }
    
    // MARK: - Custom Drawing
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let rect = bounds
        
        switch mode {
        case .idle:
            drawIdleState(in: rect, context: context)
            
        case .dragHover:
            drawDragHoverPill(in: rect, context: context)
            
        case .processing(let progress):
            drawProcessingState(in: rect, progress: progress, context: context)
            
        case .success:
            drawSuccessState(in: rect, context: context)
        }
    }
    
    // MARK: - Render: Idle Icon & Supporter Menu Bar Styles
    private func drawIdleState(in rect: NSRect, context: CGContext) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let iconColor: NSColor = isHighlighted ? .systemBlue : (isDark ? .white : .white)
        let state = AppState.shared
        
        let style = state.menuBarDisplayStyle
        
        switch style {
        case .iconOnly:
            let iconSize: CGFloat = 17.0
            let clampImage = NSImage.squeezeClampImage(size: iconSize, color: iconColor)
            let iconRect = NSRect(
                x: (rect.width - iconSize) / 2,
                y: (rect.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            clampImage.draw(in: iconRect)
            
        case .minimalMonochrome:
            // Sleek minimalist dot / diamond clamp
            let dotSize: CGFloat = 7.0
            let dotRect = NSRect(
                x: (rect.width - dotSize) / 2,
                y: (rect.height - dotSize) / 2,
                width: dotSize,
                height: dotSize
            )
            let dotPath = NSBezierPath(ovalIn: dotRect)
            (isHighlighted ? NSColor.systemBlue : (isDark ? NSColor.white : NSColor.black)).setFill()
            dotPath.fill()
            
        case .liveSavings:
            // Squeeze clamp icon on left + crisp formatted saved MB on right
            let iconSize: CGFloat = 14.0
            let clampImage = NSImage.squeezeClampImage(size: iconSize, color: iconColor)
            let iconRect = NSRect(
                x: 6,
                y: (rect.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            clampImage.draw(in: iconRect)
            
            let savedStr = ByteCountFormatter.string(fromByteCount: state.totalBytesSaved, countStyle: .file)
            let textFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
            let textColor = isHighlighted ? NSColor.systemBlue : (isDark ? NSColor.white.withAlphaComponent(0.92) : NSColor.black.withAlphaComponent(0.85))
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: textColor
            ]
            let textSize = (savedStr as NSString).size(withAttributes: attrs)
            let textRect = NSRect(
                x: iconRect.maxX + 5,
                y: (rect.height - textSize.height) / 2 + 0.5,
                width: textSize.width,
                height: textSize.height
            )
            (savedStr as NSString).draw(in: textRect, withAttributes: attrs)
        }
    }
    
    // MARK: - Render: In-Place Drop Hover Indicator
    private func drawDragHoverPill(in rect: NSRect, context: CGContext) {
        let pillInset: CGFloat = 2.5
        let pillRect = rect.insetBy(dx: pillInset, dy: pillInset)
        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: min(6.0, pillRect.height / 2), yRadius: min(6.0, pillRect.height / 2))
        
        // Background fill with vibrant glass accent tint
        NSColor.systemBlue.withAlphaComponent(0.35).setFill()
        pillPath.fill()
        
        // Stroke outline with glowing blue border
        NSColor.systemBlue.setStroke()
        pillPath.lineWidth = 1.5
        pillPath.stroke()
        
        // Icon rendering
        let iconSize: CGFloat = 16.0
        let clampImage = NSImage.squeezeClampImage(size: iconSize, color: .white)
        let iconRect = NSRect(
            x: (rect.width - iconSize) / 2,
            y: (rect.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        clampImage.draw(in: iconRect)
    }
    
    // MARK: - Render: Circular Progress Indicator
    private func drawProcessingState(in rect: NSRect, progress: Double, context: CGContext) {
        let size: CGFloat = 16.0
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = (size - 2.5) / 2.0
        
        context.saveGState()
        
        // Background track (semi-transparent white)
        context.setLineWidth(2.0)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor)
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.strokePath()
        
        // Progress arc (vibrant bright cyan/blue)
        let startAngle: CGFloat = -.pi / 2.0
        let currentProg = max(0.05, min(progress, 1.0))
        let endAngle: CGFloat = startAngle + CGFloat(currentProg * .pi * 2.0)
        
        context.setLineWidth(2.2)
        context.setLineCap(.round)
        context.setStrokeColor(NSColor(red: 0.25, green: 0.75, blue: 1.0, alpha: 1.0).cgColor)
        context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        context.strokePath()
        
        context.restoreGState()
    }
    
    // MARK: - Render: Success Checkmark Badge
    private func drawSuccessState(in rect: NSRect, context: CGContext) {
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)]))
        if let checkImage = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Completed")?.withSymbolConfiguration(iconConfig) {
            let iconRect = NSRect(
                x: (rect.width - 18) / 2,
                y: (rect.height - 18) / 2,
                width: 18,
                height: 18
            )
            checkImage.draw(in: iconRect)
        }
    }
}
