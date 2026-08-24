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
    
    // Synchronized Video Playback Engine
    @StateObject private var videoEngine = SynchronizedVideoEngine()
    
    // Zoom & Pan State (Shared and Synchronized across modes)
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var activeDragOffset: CGSize = .zero
    
    enum InspectorMode: String, CaseIterable {
        case split = "Split Slider"
        case sideBySide = "Side by Side"
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
            
            // Video Playback Controls Bar (if media is video)
            if result.mediaType == .video && videoEngine.isLoaded {
                videoTransportBar
                Divider()
                    .opacity(0.25)
            }
            
            Divider()
                .opacity(0.25)
            
            // Bottom Metadata & Actions Bar
            bottomBar
        }
        .frame(minWidth: 680, idealWidth: 860, minHeight: 520, idealHeight: 640)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        .task {
            await loadMedia()
        }
        .onDisappear {
            videoEngine.cleanup()
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
            // Spacer to accommodate native macOS window traffic lights inside standard titlebar
            Spacer()
                .frame(width: 68)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.fileName)
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(result.formattedOriginalSize)
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(.secondary)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(result.formattedCompressedSize)
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundColor(.primary)
                    
                    Text("Saved \(result.formattedSaved)")
                        .font(.system(size: 9, weight: .semibold, design: .serif))
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
                    .font(.system(size: 10, weight: .medium, design: .serif))
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
                            .font(.system(size: 9, weight: .medium, design: .serif))
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
            .background(Capsule().fill(Color.white.opacity(0.06)))
            
            // Mode Selector (Pill Glider)
            HStack(spacing: 3) {
                ForEach(InspectorMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                            inspectorMode = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 10, weight: inspectorMode == mode ? .semibold : .medium, design: .serif))
                            .foregroundColor(inspectorMode == mode ? .white : .secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(inspectorMode == mode ? Color.white.opacity(0.18) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2.5)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.25))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
            )
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
                                
                        case .sideBySide:
                            sideBySideComparisonView(width: w, height: h)
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
    
    // MARK: - Split Slider View (Supports Live Video or Still Image)
    @ViewBuilder
    private func splitComparisonView(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Layer 1: Original (Bottom Layer) - Scaled and panned
            Group {
                if result.mediaType == .video, let origPlayer = videoEngine.originalPlayer {
                    SynchronizedVideoPlayerLayer(player: origPlayer)
                } else if let orig = originalImage {
                    Image(nsImage: orig)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: width, height: height)
            .scaleEffect(zoomScale)
            .offset(x: currentPan.width, y: currentPan.height)
            
            // Layer 2: Optimized (Top Layer) - Scaled and panned with identical transform
            Group {
                if result.mediaType == .video, let compPlayer = videoEngine.compressedPlayer {
                    SynchronizedVideoPlayerLayer(player: compPlayer)
                } else if let comp = compressedImage {
                    Image(nsImage: comp)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: width, height: height)
            .scaleEffect(zoomScale)
            .offset(x: currentPan.width, y: currentPan.height)
            // Clip in viewport space: The clip boundary is exactly at screen coordinate (width * splitOffset)
            .clipShape(ScreenSpaceSplitClip(screenSplitX: width * splitOffset, totalWidth: width, totalHeight: height))
        }
        .frame(width: width, height: height)
    }
    
    // Split Handle & Divider Line (Positioned in Screen Space)
    @ViewBuilder
    private func splitHandleOverlay(width: CGFloat, height: CGFloat) -> some View {
        let lineX = width * splitOffset
        
        ZStack {
            // Vertical Divider Line
            Rectangle()
                .fill(Color.white.opacity(0.92))
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
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.65)))
                        .foregroundColor(.white)
                        .padding(12)
                    
                    Spacer()
                    
                    Text("OPTIMIZED")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.blue.opacity(0.85)))
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
                if result.mediaType == .video, let origPlayer = videoEngine.originalPlayer {
                    SynchronizedVideoPlayerLayer(player: origPlayer)
                        .frame(width: halfWidth, height: height)
                        .scaleEffect(zoomScale)
                        .offset(x: currentPan.width, y: currentPan.height)
                } else if let orig = originalImage {
                    Image(nsImage: orig)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: halfWidth, height: height)
                        .scaleEffect(zoomScale)
                        .offset(x: currentPan.width, y: currentPan.height)
                }
                
                Text("ORIGINAL")
                    .font(.system(size: 9, weight: .bold, design: .serif))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .foregroundColor(.white)
                    .padding(10)
            }
            .frame(width: halfWidth, height: height)
            .background(Color.black.opacity(0.3))
            .clipped()
            .cornerRadius(8)
            
            // Right Viewport: Optimized (Mirrors same zoom & pan transformation)
            ZStack(alignment: .topLeading) {
                if result.mediaType == .video, let compPlayer = videoEngine.compressedPlayer {
                    SynchronizedVideoPlayerLayer(player: compPlayer)
                        .frame(width: halfWidth, height: height)
                        .scaleEffect(zoomScale)
                        .offset(x: currentPan.width, y: currentPan.height)
                } else if let comp = compressedImage {
                    Image(nsImage: comp)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: halfWidth, height: height)
                        .scaleEffect(zoomScale)
                        .offset(x: currentPan.width, y: currentPan.height)
                }
                
                Text("OPTIMIZED")
                    .font(.system(size: 9, weight: .bold, design: .serif))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.blue.opacity(0.85)))
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
    
    // MARK: - Video Transport Controls Bar (Play/Pause, Scrubbing, Audio Volume, Timestamp)
    private var videoTransportBar: some View {
        HStack(spacing: 12) {
            Button {
                videoEngine.togglePlayPause()
            } label: {
                Image(systemName: videoEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            
            Text(videoEngine.formattedCurrentTime)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            // Time Scrub Slider
            Slider(
                value: Binding(
                    get: { videoEngine.currentTimeSeconds },
                    set: { newTime in
                        videoEngine.seek(to: newTime)
                    }
                ),
                in: 0...max(0.1, videoEngine.durationSeconds)
            )
            .accentColor(.blue)
            
            Text(videoEngine.formattedDuration)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
            
            // Loop toggle
            Button {
                videoEngine.isLooping.toggle()
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(videoEngine.isLooping ? .blue : .secondary)
                    .padding(4)
                    .background(Capsule().fill(videoEngine.isLooping ? Color.blue.opacity(0.15) : Color.clear))
            }
            .buttonStyle(.plain)
            .help("Loop Playback")
            
            Divider()
                .frame(height: 14)
                .opacity(0.3)
            
            // Audio Volume Control
            HStack(spacing: 5) {
                Button {
                    videoEngine.isMuted.toggle()
                } label: {
                    Image(systemName: videoEngine.isMuted || videoEngine.volume == 0 ? "speaker.slash.fill" : (videoEngine.volume < 0.5 ? "speaker.1.fill" : "speaker.3.fill"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(videoEngine.isMuted ? .red.opacity(0.8) : .secondary)
                }
                .buttonStyle(.plain)
                .help(videoEngine.isMuted ? "Unmute" : "Mute")
                
                Slider(
                    value: Binding(
                        get: { Double(videoEngine.volume) },
                        set: { newVol in
                            videoEngine.volume = Float(newVol)
                            if videoEngine.isMuted && newVol > 0 {
                                videoEngine.isMuted = false
                            }
                        }
                    ),
                    in: 0.0...1.0
                )
                .frame(width: 65)
                .accentColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.35))
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack(spacing: 12) {
            if let origDim = result.originalDimensions, let outDim = result.outputDimensions {
                HStack(spacing: 6) {
                    Text(origDim)
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    
                    Text(outDim)
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.blue.opacity(0.18)))
                }
            }
            
            Text("Pinch / Scroll to zoom • Drag to pan • Drag center handle to split")
                .font(.system(size: 9, design: .serif))
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.leading, 4)
            
            Spacer()
            
            Button {
                AppState.shared.revealInFinder(url: result.outputURL)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                    Text("Reveal in Finder")
                        .font(.system(size: 10, weight: .medium, design: .serif))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.06)))
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
                        .font(.system(size: 10, weight: .medium, design: .serif))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.blue))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private func loadMedia() async {
        if result.mediaType == .video {
            await videoEngine.load(originalURL: result.originalURL, compressedURL: result.outputURL)
        }
        
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

// MARK: - Synchronized Dual-AVPlayer Engine for Video Inspection
@MainActor
private final class SynchronizedVideoEngine: ObservableObject {
    @Published var originalPlayer: AVPlayer?
    @Published var compressedPlayer: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var isLoaded: Bool = false
    @Published var currentTimeSeconds: Double = 0.0
    @Published var durationSeconds: Double = 0.0
    @Published var isLooping: Bool = true
    @Published var volume: Float = 1.0 {
        didSet {
            compressedPlayer?.volume = isMuted ? 0.0 : volume
        }
    }
    @Published var isMuted: Bool = false {
        didSet {
            compressedPlayer?.isMuted = isMuted
            compressedPlayer?.volume = isMuted ? 0.0 : volume
        }
    }
    
    private var timeObserverToken: Any?
    private var endObserverToken: Any?
    
    var formattedCurrentTime: String {
        formatTime(currentTimeSeconds)
    }
    
    var formattedDuration: String {
        formatTime(durationSeconds)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds) % 60
        let m = Int(seconds) / 60
        return String(format: "%02d:%02d", m, s)
    }
    
    func load(originalURL: URL, compressedURL: URL) async {
        let origAsset = AVURLAsset(url: originalURL)
        let compAsset = AVURLAsset(url: compressedURL)
        
        let origItem = AVPlayerItem(asset: origAsset)
        let compItem = AVPlayerItem(asset: compAsset)
        
        let p1 = AVPlayer(playerItem: origItem)
        let p2 = AVPlayer(playerItem: compItem)
        
        // Mute original to prevent dual audio echo, keep compressed audio active
        p1.isMuted = true
        p2.isMuted = false
        
        self.originalPlayer = p1
        self.compressedPlayer = p2
        
        if let dur = try? await origAsset.load(.duration) {
            let durSec = CMTimeGetSeconds(dur)
            if durSec.isFinite && durSec > 0 {
                self.durationSeconds = durSec
            }
        }
        
        self.isLoaded = true
        
        // Add Synchronized Time Observer (30 updates/sec for smooth slider)
        let interval = CMTime(value: 1, timescale: 30)
        timeObserverToken = p2.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let sec = CMTimeGetSeconds(time)
            Task { @MainActor [weak self] in
                guard let self = self, sec.isFinite else { return }
                self.currentTimeSeconds = sec
            }
        }
        
        // Loop when video reaches end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: compItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isLooping {
                    self.seek(to: 0.0)
                    self.play()
                } else {
                    self.isPlaying = false
                }
            }
        }
        
        // Autoplay initial preview
        play()
    }
    
    func play() {
        originalPlayer?.play()
        compressedPlayer?.play()
        isPlaying = true
    }
    
    func pause() {
        originalPlayer?.pause()
        compressedPlayer?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to seconds: Double) {
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
        originalPlayer?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        compressedPlayer?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTimeSeconds = seconds
    }
    
    func cleanup() {
        pause()
        if let token = timeObserverToken {
            compressedPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        originalPlayer = nil
        compressedPlayer = nil
    }
}

// MARK: - Native AppKit AVPlayerLayer Wrapper (Zero CPU Copy & Metal Accelerated)
private struct SynchronizedVideoPlayerLayer: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> PlayerNSView {
        let view = PlayerNSView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }
    
    func updateNSView(_ nsView: PlayerNSView, context: Context) {
        if nsView.playerLayer.player != player {
            nsView.playerLayer.player = player
        }
    }
}

private final class PlayerNSView: NSView {
    let playerLayer = AVPlayerLayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
    }
    
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
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

// Helper Shape for Split View Right Side Clipping in Screen Space
private struct ScreenSpaceSplitClip: Shape {
    var screenSplitX: CGFloat
    var totalWidth: CGFloat
    var totalHeight: CGFloat
    
    var animatableData: CGFloat {
        get { screenSplitX }
        set { screenSplitX = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Compute clip rect covering right side of the screen boundary
        let w = max(totalWidth, rect.width)
        let h = max(totalHeight, rect.height)
        let clipRect = CGRect(x: screenSplitX, y: -h * 4, width: max(0, w * 5 - screenSplitX), height: h * 9)
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

