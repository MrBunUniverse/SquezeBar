import SwiftUI
import AppKit
import AVFoundation
import QuickLookThumbnailing

public struct BeforeAfterInspectorView: View {
    public let result: CompressionResult
    public let onClose: () -> Void
    
    @State private var splitOffset: CGFloat = 0.5 // 0.0 ... 1.0
    @State private var originalImage: NSImage?
    @State private var compressedImage: NSImage?
    @State private var inspectorMode: InspectorMode = .split
    @State private var showOnlyAfter: Bool = false
    
    // Zoom & Pan State (Shared and Synchronized across modes)
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var activeDragOffset: CGSize = .zero
    
    enum InspectorMode: String, CaseIterable {
        case split = "Split Slider"
        case sideBySide = "Side by Side"
        case toggle = "A / B Flip"
    }
    
    public init(result: CompressionResult, onClose: @escaping () -> Void) {
        self.result = result
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar (Acts as window drag handle while keeping buttons clickable)
            headerBar
                .background(WindowDragRepresentable())
            
            Divider()
                .opacity(0.25)
            
            // Comparison Canvas (Captures Pan & Zoom locally, NOT dragging window)
            comparisonCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.6))
                .clipped()
            
            Divider()
                .opacity(0.25)
            
            // Bottom Metadata & Actions Bar
            bottomBar
        }
        .frame(minWidth: 640, idealWidth: 840, minHeight: 500, idealHeight: 600)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        .task {
            await loadImages()
        }
    }
    
    // Total effective pan
    private var currentPan: CGSize {
        CGSize(
            width: panOffset.width + activeDragOffset.width,
            height: panOffset.height + activeDragOffset.height
        )
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 12) {
            // Spacer to accommodate native macOS window traffic lights inside the standard titlebar area
            Spacer()
                .frame(width: 68)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.fileName)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(result.formattedOriginalSize)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(result.formattedCompressedSize)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Saved \(result.formattedSaved)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                }
            }
            
            Spacer()
            
            // Zoom Controls Indicator
            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        zoomScale = max(1.0, zoomScale - 0.5)
                        if zoomScale <= 1.0 { panOffset = .zero; activeDragOffset = .zero }
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 11))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .disabled(zoomScale <= 1.0)
                
                Text(String(format: "%.0f%%", zoomScale * 100))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .frame(width: 38)
                    .onTapGesture(count: 2) {
                        resetZoom()
                    }
                
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        zoomScale = min(5.0, zoomScale + 0.5)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 11))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .disabled(zoomScale >= 5.0)
                
                if zoomScale > 1.0 {
                    Button {
                        resetZoom()
                    } label: {
                        Text("Reset")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
            
            // Mode Selector
            Picker("Mode", selection: $inspectorMode) {
                ForEach(InspectorMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    private func resetZoom() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            zoomScale = 1.0
            panOffset = .zero
            activeDragOffset = .zero
        }
    }
    
    // MARK: - Comparison Canvas
    @ViewBuilder
    private var comparisonCanvas: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Interactive Scroll/Pinch/Pan Container
                ZoomPanCanvas(
                    zoomScale: $zoomScale,
                    panOffset: $panOffset,
                    activeDragOffset: $activeDragOffset
                ) {
                    Group {
                        switch inspectorMode {
                        case .split:
                            splitComparisonView(width: w, height: h)
                                .scaleEffect(zoomScale)
                                .offset(x: currentPan.width, y: currentPan.height)
                                
                        case .sideBySide:
                            sideBySideComparisonView(width: w, height: h)
                            
                        case .toggle:
                            toggleComparisonView(width: w, height: h)
                                .scaleEffect(zoomScale)
                                .offset(x: currentPan.width, y: currentPan.height)
                        }
                    }
                }
                
                // Overlay controls that stay crisp in screen coordinates (Split divider line)
                if inspectorMode == .split {
                    splitHandleOverlay(width: w, height: h)
                }
            }
        }
    }
    
    // MARK: - Split Slider View
    @ViewBuilder
    private func splitComparisonView(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Original (Full width underneath)
            if let orig = originalImage {
                Image(nsImage: orig)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: width, height: height)
            }
            
            // Compressed (Clipped dynamically by splitOffset)
            if let comp = compressedImage {
                Image(nsImage: comp)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: width, height: height)
                    .clipShape(
                        UnitRectClipShape(offset: splitOffset)
                    )
            }
        }
    }
    
    // Split Handle & Divider Line (Positioned in Screen Space)
    @ViewBuilder
    private func splitHandleOverlay(width: CGFloat, height: CGFloat) -> some View {
        let lineX = width * splitOffset
        
        ZStack {
            // Vertical Divider Line
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 2)
                .position(x: lineX, y: height / 2)
                .shadow(color: .black.opacity(0.6), radius: 3)
            
            // Center Pill Handle
            Circle()
                .fill(Color.white)
                .frame(width: 26, height: 26)
                .shadow(color: .black.opacity(0.5), radius: 4)
                .overlay(
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                )
                .position(x: lineX, y: height / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newOffset = max(0.02, min(0.98, value.location.x / width))
                            splitOffset = newOffset
                        }
                )
            
            // Labels
            VStack {
                Spacer()
                HStack {
                    Text("ORIGINAL")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.65)))
                        .foregroundColor(.white)
                        .padding(12)
                    
                    Spacer()
                    
                    Text("OPTIMIZED")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue.opacity(0.85)))
                        .foregroundColor(.white)
                        .padding(12)
                }
            }
        }
    }
    
    // MARK: - True Synchronized Dual-Viewport Side By Side (Split-Screen)
    @ViewBuilder
    private func sideBySideComparisonView(width: CGFloat, height: CGFloat) -> some View {
        let halfWidth = (width - 12) / 2
        
        HStack(spacing: 8) {
            // Left Viewport: Original
            ZStack(alignment: .topLeading) {
                if let orig = originalImage {
                    Image(nsImage: orig)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: halfWidth, height: height)
                        .scaleEffect(zoomScale)
                        .offset(x: currentPan.width, y: currentPan.height)
                }
                
                Text("ORIGINAL")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.75)))
                    .foregroundColor(.white)
                    .padding(10)
            }
            .frame(width: halfWidth, height: height)
            .background(Color.black.opacity(0.3))
            .clipped()
            .cornerRadius(8)
            
            // Right Viewport: Optimized (Mirrors same zoom & pan transformation)
            ZStack(alignment: .topLeading) {
                if let comp = compressedImage {
                    Image(nsImage: comp)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: halfWidth, height: height)
                        .scaleEffect(zoomScale)
                        .offset(x: currentPan.width, y: currentPan.height)
                }
                
                Text("OPTIMIZED")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.85)))
                    .foregroundColor(.white)
                    .padding(10)
            }
            .frame(width: halfWidth, height: height)
            .background(Color.black.opacity(0.3))
            .clipped()
            .cornerRadius(8)
        }
        .padding(.horizontal, 2)
    }
    
    // MARK: - Toggle View (A / B Flip)
    @ViewBuilder
    private func toggleComparisonView(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if showOnlyAfter {
                if let comp = compressedImage {
                    Image(nsImage: comp)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: width, height: height)
                }
            } else {
                if let orig = originalImage {
                    Image(nsImage: orig)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: width, height: height)
                }
            }
            
            VStack {
                Spacer()
                Button {
                    showOnlyAfter.toggle()
                } label: {
                    Text(showOnlyAfter ? "Showing: OPTIMIZED (Click or Space to Flip)" : "Showing: ORIGINAL (Click or Space to Flip)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(showOnlyAfter ? Color.blue : Color.black.opacity(0.75)))
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .padding(.bottom, 12)
            }
        }
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack(spacing: 12) {
            if let origDim = result.originalDimensions, let outDim = result.outputDimensions {
                HStack(spacing: 4) {
                    Text(origDim)
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(outDim)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .font(.system(size: 10, design: .rounded))
            }
            
            Text("Pinch / Scroll to zoom • Drag to pan • Double-click to toggle zoom")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.leading, 8)
            
            Spacer()
            
            Button {
                AppState.shared.revealInFinder(url: result.outputURL)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                    Text("Reveal in Finder")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([result.outputURL as NSURL])
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10))
                    Text("Copy File")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private func loadImages() async {
        let orig = await loadMediaPreview(url: result.originalURL, mediaType: result.mediaType)
        let comp = await loadMediaPreview(url: result.outputURL, mediaType: result.mediaType)
        
        await MainActor.run {
            self.originalImage = orig
            self.compressedImage = comp
        }
    }
    
    private func loadMediaPreview(url: URL, mediaType: MediaType) async -> NSImage? {
        if mediaType == .image, let img = NSImage(contentsOf: url) {
            return img
        }
        
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 1600, height: 1600),
            scale: 2.0,
            representationTypes: .all
        )
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            return rep.nsImage
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Isolated Zoom & Pan Canvas Container with AppKit Event Handling
private struct ZoomPanCanvas<Content: View>: View {
    @Binding var zoomScale: CGFloat
    @Binding var panOffset: CGSize
    @Binding var activeDragOffset: CGSize
    let content: () -> Content
    
    var body: some View {
        InteractiveZoomPanRepresentable(
            zoomScale: $zoomScale,
            panOffset: $panOffset,
            activeDragOffset: $activeDragOffset
        ) {
            content()
        }
    }
}

// AppKit Native Interactive Zoom/Pan View for Precise macOS Pinch, Scroll & Trackpad Events
private struct InteractiveZoomPanRepresentable<Content: View>: NSViewRepresentable {
    @Binding var zoomScale: CGFloat
    @Binding var panOffset: CGSize
    @Binding var activeDragOffset: CGSize
    let content: () -> Content
    
    func makeNSView(context: Context) -> InteractiveZoomPanNSView {
        let view = InteractiveZoomPanNSView()
        view.onMagnify = { delta in
            let newScale = max(1.0, min(8.0, zoomScale * (1.0 + delta)))
            zoomScale = newScale
            if newScale <= 1.0 {
                panOffset = .zero
                activeDragOffset = .zero
            }
        }
        view.onScrollPan = { dx, dy in
            if zoomScale > 1.0 {
                panOffset.width += dx
                panOffset.height -= dy
            }
        }
        view.onMouseDrag = { dx, dy in
            if zoomScale > 1.0 {
                panOffset.width += dx
                panOffset.height -= dy
            }
        }
        view.onDoubleClick = {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if zoomScale > 1.0 {
                    zoomScale = 1.0
                    panOffset = .zero
                    activeDragOffset = .zero
                } else {
                    zoomScale = 2.5
                }
            }
        }
        
        let hosting = NSHostingView(rootView: content())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        view.hostingView = hosting
        
        return view
    }
    
    func updateNSView(_ nsView: InteractiveZoomPanNSView, context: Context) {
        if let hosting = nsView.hostingView as? NSHostingView<Content> {
            hosting.rootView = content()
        }
        nsView.onMagnify = { delta in
            let newScale = max(1.0, min(8.0, zoomScale * (1.0 + delta)))
            zoomScale = newScale
            if newScale <= 1.0 {
                panOffset = .zero
                activeDragOffset = .zero
            }
        }
        nsView.onScrollPan = { dx, dy in
            if zoomScale > 1.0 {
                panOffset.width += dx
                panOffset.height -= dy
            }
        }
        nsView.onMouseDrag = { dx, dy in
            if zoomScale > 1.0 {
                panOffset.width += dx
                panOffset.height -= dy
            }
        }
    }
}

private class InteractiveZoomPanNSView: NSView {
    var hostingView: NSView?
    var onMagnify: ((CGFloat) -> Void)?
    var onScrollPan: ((CGFloat, CGFloat) -> Void)?
    var onMouseDrag: ((CGFloat, CGFloat) -> Void)?
    var onDoubleClick: (() -> Void)?
    
    private var lastMouseLocation: NSPoint = .zero
    private var isDraggingMouse: Bool = false
    
    override var acceptsFirstResponder: Bool { true }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    // Native macOS Trackpad 2-Finger Pinch Gesture
    override func magnify(with event: NSEvent) {
        onMagnify?(event.magnification)
    }
    
    // Mouse Scroll Wheel or Trackpad 2-Finger Scroll
    override func scrollWheel(with event: NSEvent) {
        // If holding Option or Command (or pure vertical wheel on external mouse), allow zoom
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
            let zoomDelta = event.deltaY * 0.05
            onMagnify?(zoomDelta)
        } else {
            // Trackpad 2-finger swipe / pan or regular scroll
            onScrollPan?(event.scrollingDeltaX * 1.2, event.scrollingDeltaY * 1.2)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        lastMouseLocation = event.locationInWindow
        isDraggingMouse = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDraggingMouse else { return }
        let currentLocation = event.locationInWindow
        let dx = currentLocation.x - lastMouseLocation.x
        let dy = currentLocation.y - lastMouseLocation.y
        lastMouseLocation = currentLocation
        onMouseDrag?(dx, -dy)
    }
    
    override func mouseUp(with event: NSEvent) {
        isDraggingMouse = false
    }
}

// MARK: - Window Drag Handler (Only header drags the window)
private struct WindowDragRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragView {
        WindowDragView()
    }
    
    func updateNSView(_ nsView: WindowDragView, context: Context) {}
}

private class WindowDragView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}

// Helper Shape for Split View Right Side Clipping
private struct UnitRectClipShape: Shape {
    var offset: CGFloat // 0.0 ... 1.0
    
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startX = rect.width * offset
        let clipRect = CGRect(x: startX, y: 0, width: rect.width - startX, height: rect.height)
        path.addRect(clipRect)
        return path
    }
}

// Dedicated floating window controller for comparison view
@MainActor
public final class InspectorWindowController: NSObject, NSWindowDelegate {
    public static let shared = InspectorWindowController()
    private var window: NSWindow?
    
    public func show(result: CompressionResult) {
        if let existing = window {
            existing.close()
        }
        
        let inspectorView = BeforeAfterInspectorView(result: result) { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        
        let hostingController = NSHostingController(rootView: inspectorView)
        let win = NSWindow(contentViewController: hostingController)
        
        // Standard macOS unified titlebar: traffic lights inside the window frame
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        
        // Disable full-window background dragging so image panning works without moving window
        win.isMovableByWindowBackground = false
        
        win.level = .floating
        win.backgroundColor = .windowBackgroundColor
        win.isOpaque = true
        win.hasShadow = true
        win.setContentSize(NSSize(width: 840, height: 600))
        win.center()
        win.delegate = self
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

