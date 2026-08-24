import SwiftUI
import AppKit
import AVFoundation
import QuickLookThumbnailing

public struct BeforeAfterInspectorView: View {
    public let result: CompressionResult
    public let onClose: () -> Void
    
    @State private var splitOffset: CGFloat = 0.5 // 0.0 ... 1.0
    @State private var isDragging: Bool = false
    @State private var originalImage: NSImage?
    @State private var compressedImage: NSImage?
    @State private var inspectorMode: InspectorMode = .split
    @State private var showOnlyAfter: Bool = false
    
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
            // Header Bar
            headerBar
            
            Divider()
                .opacity(0.3)
            
            // Comparison Canvas
            comparisonCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.4))
            
            Divider()
                .opacity(0.3)
            
            // Bottom Metadata & Actions Bar
            bottomBar
        }
        .frame(minWidth: 540, idealWidth: 680, minHeight: 460, idealHeight: 520)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await loadImages()
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.fileName)
                    .font(.system(size: 13, weight: .bold))
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
                        .background(Capsule().fill(Color.green.opacity(0.12)))
                }
            }
            
            Spacer()
            
            // Mode Selector
            Picker("Mode", selection: $inspectorMode) {
                ForEach(InspectorMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
            
            // Close Button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Comparison Canvas
    @ViewBuilder
    private var comparisonCanvas: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            switch inspectorMode {
            case .split:
                ZStack {
                    // Original (Left / Underneath)
                    if let orig = originalImage {
                        Image(nsImage: orig)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: w, height: h)
                    }
                    
                    // Compressed (Right / Clipped on Top)
                    if let comp = compressedImage {
                        Image(nsImage: comp)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: w, height: h)
                            .clipShape(
                                UnitRectClipShape(offset: splitOffset)
                            )
                    }
                    
                    // Vertical Divider Line & Handle
                    let lineX = w * splitOffset
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2)
                        .position(x: lineX, y: h / 2)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                    
                    // Center Pill Handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                        )
                        .position(x: lineX, y: h / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let newOffset = max(0.02, min(0.98, value.location.x / w))
                                    splitOffset = newOffset
                                }
                        )
                    
                    // Floating Labels
                    VStack {
                        Spacer()
                        HStack {
                            Text("ORIGINAL")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.6)))
                                .foregroundColor(.white)
                                .padding(10)
                            
                            Spacer()
                            
                            Text("OPTIMIZED")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.8)))
                                .foregroundColor(.white)
                                .padding(10)
                        }
                    }
                }
                
            case .sideBySide:
                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Text("ORIGINAL")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        if let orig = originalImage {
                            Image(nsImage: orig)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(8)
                    
                    VStack(spacing: 4) {
                        Text("OPTIMIZED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue)
                        
                        if let comp = compressedImage {
                            Image(nsImage: comp)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(8)
                }
                .padding(10)
                
            case .toggle:
                ZStack {
                    if showOnlyAfter {
                        if let comp = compressedImage {
                            Image(nsImage: comp)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: w, height: h)
                        }
                    } else {
                        if let orig = originalImage {
                            Image(nsImage: orig)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: w, height: h)
                        }
                    }
                    
                    VStack {
                        Spacer()
                        Button {
                            showOnlyAfter.toggle()
                        } label: {
                            Text(showOnlyAfter ? "Showing: OPTIMIZED (Click to Flip)" : "Showing: ORIGINAL (Click to Flip)")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(showOnlyAfter ? Color.blue : Color.black.opacity(0.7)))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 12)
                    }
                }
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
        // Load original frame
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
            size: CGSize(width: 1200, height: 1200),
            scale: 2.0,
            representationTypes: .all
        )
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            return rep.nsImage
        }
        return NSWorkspace.shared.icon(forFile: url.path)
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
