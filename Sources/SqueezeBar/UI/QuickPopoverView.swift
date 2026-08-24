import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing

public struct QuickPopoverView: View {
    @EnvironmentObject var state: AppState
    public var isDetachedWindow: Bool = false
    @State private var selectedTab: PopoverTab = .activity
    @State private var isWindowDropTargeted: Bool = false
    @State private var settingsCategory: SettingsCategory = .images
    
    enum PopoverTab: String, CaseIterable {
        case activity = "Activity"
        case settings = "Settings"
    }
    
    enum SettingsCategory: String, CaseIterable {
        case images = "Images"
        case videos = "Video"
        case audio = "Audio"
        case general = "General"
    }
    
    public init(isDetachedWindow: Bool = false) {
        self.isDetachedWindow = isDetachedWindow
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerView
            
            Divider()
                .opacity(0.3)
            
            // Tab Selector
            tabSelectorView
            
            // Tab Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 14) {
                    if selectedTab == .activity {
                        statsSummaryCard
                        
                        // 1-Click Quick Preset Selector Bar
                        quickPresetBar
                        
                        if !state.activeJobs.isEmpty {
                            activeQueueSection
                        }
                        
                        recentHistorySection
                    } else {
                        settingsSection
                    }
                }
                .padding(14)
            }
            
            Divider()
                .opacity(0.3)
            
            // Bottom Action Bar
            footerView
        }
        .frame(minWidth: 440, maxWidth: .infinity, minHeight: 540, maxHeight: .infinity)
        .background(
            ZStack {
                VisualEffectView(
                    material: isDetachedWindow ? .hudWindow : .popover,
                    blendingMode: isDetachedWindow ? .withinWindow : .behindWindow
                )
                
                if isWindowDropTargeted {
                    RoundedRectangle(cornerRadius: isDetachedWindow ? 14 : 0)
                        .strokeBorder(Color.blue, lineWidth: 2)
                        .background(Color.blue.opacity(0.08))
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: isDetachedWindow ? 14 : 0))
        .ignoresSafeArea()
        .onDrop(of: [.fileURL], isTargeted: $isWindowDropTargeted) { providers in
            extractAndProcess(providers: providers)
        }
        .sheet(item: $state.inspectedResult) { result in
            BeforeAfterInspectorView(result: result) {
                state.inspectedResult = nil
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 8) {
            // Pin / Always on Top button
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    state.isPinned.toggle()
                    StatusBarController.sharedInstance?.updatePinState(pinned: state.isPinned)
                    FloatingDropWindowController.shared.updatePinState(pinned: state.isPinned)
                }
            } label: {
                Image(systemName: state.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(state.isPinned ? .white : .secondary)
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(state.isPinned ? Color.blue : Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .help(state.isPinned ? "Unpin Window (Allow backgrounding)" : "Pin Window on Top (Stay visible over Finder)")
            
            if !isDetachedWindow {
                // Detach Button
                Button {
                    StatusBarController.sharedInstance?.closePopover(sender: nil)
                    FloatingDropWindowController.shared.showFloatingWindow()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Detach as floating window")
            }
            
            // Icon / Logo
            SqueezeClampLogoView(size: 24, color: .white, showBackground: true)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text("SqueezeBar")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    if isDetachedWindow {
                        Text("PRO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.blue))
                    }
                }
                Text("Universal Media Optimizer")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isDetachedWindow {
                // Dock button
                Button {
                    FloatingDropWindowController.shared.dockToMenuBar()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left.square")
                            .font(.system(size: 10, weight: .bold))
                        Text("Dock")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(.plain)
                .help("Dock to Menu Bar")
            }
            
            if state.isProcessing {
                HStack(spacing: 5) {
                    ProgressView()
                        .scaleEffect(0.60)
                        .frame(width: 12, height: 12)
                    Text("Optimizing...")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.blue.opacity(0.12)))
            } else if state.showSuccessBadge {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("Complete")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.green.opacity(0.12)))
            }
        }
        .padding(.leading, isDetachedWindow ? 76 : 12)
        .padding(.trailing, 12)
        .padding(.top, isDetachedWindow ? 11 : 8)
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Selector
    private var tabSelectorView: some View {
        HStack(spacing: 4) {
            ForEach(PopoverTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                        selectedTab = tab
                        if tab == .settings {
                            FloatingDropWindowController.shared.ensureMinimumDimensions(width: 480, height: 640)
                            StatusBarController.sharedInstance?.ensurePopoverDimensions(width: 480, height: 640)
                        }
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == tab ?
                            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12)) :
                            RoundedRectangle(cornerRadius: 6).fill(Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }
    
    // MARK: - Quick Presets Bar
    private var quickPresetBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(TargetSizeMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation {
                            state.targetSizeMode = mode
                        }
                    } label: {
                        HStack(spacing: 3) {
                            if state.targetSizeMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            Text(mode == .off ? "Manual" : (mode == .custom ? "Custom" : (mode.targetMegabytes.map { "\(Int($0))MB" } ?? mode.rawValue)))
                                .font(.system(size: 9, weight: state.targetSizeMode == mode ? .semibold : .regular))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            state.targetSizeMode == mode ?
                            Color.blue.opacity(0.25) :
                            Color.white.opacity(0.03)
                        )
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(state.targetSizeMode == mode ? Color.blue.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Stats Summary Card
    private var statsSummaryCard: some View {
        HStack(spacing: 12) {
            statItem(
                title: "Space Saved",
                value: state.formattedTotalSaved,
                icon: "arrow.down.to.line.circle",
                color: .blue
            )
            
            Divider()
                .frame(height: 28)
                .opacity(0.2)
            
            statItem(
                title: "Reduction",
                value: String(format: "%.0f%%", state.overallPercentageSaved),
                icon: "percent",
                color: .green
            )
            
            Divider()
                .frame(height: 28)
                .opacity(0.2)
            
            statItem(
                title: "Processed",
                value: "\(state.totalFilesProcessed)",
                icon: "doc.on.doc",
                color: .secondary
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Active Queue Section
    private var activeQueueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT QUEUE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            
            ForEach(state.activeJobs) { job in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        FileThumbnailView(url: job.fileURL, mediaType: job.mediaType, size: 24)
                        
                        Text(job.fileURL.lastPathComponent)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(job.statusText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: job.progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .scaleEffect(x: 1, y: 0.8, anchor: .center)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Recent History Section
    private var recentHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECENT COMPRESSIONS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !state.recentResults.isEmpty {
                    Button("Clear") {
                        state.clearHistory()
                    }
                    .font(.system(size: 10, weight: .regular))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            
            if state.recentResults.isEmpty {
                emptyHistoryView
            } else {
                ForEach(state.recentResults) { item in
                    historyRow(item: item)
                }
            }
        }
    }
    
    @State private var isDropTargeted: Bool = false
    
    private var emptyHistoryView: some View {
        VStack(spacing: 10) {
            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "square.and.arrow.down.on.square")
                .font(.system(size: 26))
                .foregroundColor(isDropTargeted ? .blue : .secondary.opacity(0.5))
                .scaleEffect(isDropTargeted ? 1.08 : 1.0)
                .animation(.spring(response: 0.25), value: isDropTargeted)
            
            Text(isDropTargeted ? "Drop Files to Compress" : "Drop Media to Optimize")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Drag single files, audio tracks, or entire folders directly here or onto the menu bar.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            // Clipboard Squeeze Button
            Button {
                state.squeezeClipboard()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10))
                    Text("Squeeze from Clipboard")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(isDropTargeted ? Color.blue.opacity(0.08) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(
                            isDropTargeted ? Color.blue.opacity(0.6) : Color.white.opacity(0.08),
                            style: StrokeStyle(lineWidth: 1, dash: isDropTargeted ? [] : [4])
                        )
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            extractAndProcess(providers: providers)
        }
    }
    
    private func extractAndProcess(providers: [NSItemProvider]) -> Bool {
        var collectedURLs: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    collectedURLs.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !collectedURLs.isEmpty {
                Task {
                    await MediaCompressionEngine.shared.processDroppedURLs(collectedURLs)
                }
            }
        }
        return true
    }
    
    private func historyRow(item: CompressionResult) -> some View {
        HStack(spacing: 8) {
            FileThumbnailView(url: item.outputURL, mediaType: item.mediaType, size: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(item.formattedOriginalSize)
                        .foregroundColor(.secondary)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary.opacity(0.7))
                    Text(item.formattedCompressedSize)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .font(.system(size: 9))
            }
            
            Spacer()
            
            Text(String(format: "-%.0f%%", item.percentSaved))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green.opacity(0.12)))
            
            // Before / After Inspector Button
            Button {
                state.inspectedResult = item
            } label: {
                Image(systemName: "slider.horizontal.below.rectangle")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Open Before/After Comparison Inspector")
            
            Button {
                state.revealInFinder(url: item.outputURL)
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                )
        )
        .onDrag {
            NSItemProvider(object: item.outputURL as NSURL)
        }
    }
    
    // MARK: - Settings Tab View
    private var settingsSection: some View {
        VStack(spacing: 12) {
            // Category Switcher
            HStack(spacing: 4) {
                ForEach(SettingsCategory.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(.spring(response: 0.22)) {
                            settingsCategory = cat
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: cat == .images ? "photo" : (cat == .videos ? "film" : (cat == .audio ? "waveform" : "gearshape")))
                                .font(.system(size: 9))
                            Text(cat.rawValue)
                                .font(.system(size: 10, weight: settingsCategory == cat ? .semibold : .regular))
                        }
                        .foregroundColor(settingsCategory == cat ? .white : .secondary)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(
                            settingsCategory == cat ?
                            RoundedRectangle(cornerRadius: 6).fill(Color.blue) :
                            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            
            // Smart Target Size Automation Card
            targetSizeAutomationCard
            
            if settingsCategory == .images {
                imageSettingsCard
            } else if settingsCategory == .videos {
                videoSettingsCard
            } else if settingsCategory == .audio {
                audioSettingsCard
            } else {
                generalSettingsCard
            }
        }
    }
    
    // MARK: - Smart Target Size Automation Card
    private var targetSizeAutomationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Target Size Limit", systemImage: "target")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                if let targetMB = state.targetSizeMode.targetMegabytes ?? (state.targetSizeMode == .custom ? state.customTargetSizeMB : nil) {
                    Text(String(format: "≤ %.0f MB", targetMB))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                } else {
                    Text("Manual Quality")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            
            // Preset pills
            HStack(spacing: 4) {
                ForEach(TargetSizeMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation {
                            state.targetSizeMode = mode
                        }
                    } label: {
                        Text(mode == .off ? "Manual" : (mode == .custom ? "Custom" : (mode.targetMegabytes.map { "\(Int($0))MB" } ?? mode.rawValue)))
                            .font(.system(size: 9, weight: state.targetSizeMode == mode ? .semibold : .regular))
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(
                                state.targetSizeMode == mode ?
                                Color.blue.opacity(0.25) :
                                Color.white.opacity(0.04)
                            )
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if state.targetSizeMode == .custom {
                VStack(spacing: 4) {
                    HStack {
                        Text("Custom Max Size")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.0f MB", state.customTargetSizeMB))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    
                    Slider(value: $state.customTargetSizeMB, in: 1.0...200.0, step: 1.0)
                        .accentColor(.blue)
                }
                .padding(.top, 2)
            }
            
            if state.targetSizeMode != .off {
                let mb = state.targetSizeMode.targetMegabytes ?? state.customTargetSizeMB
                Text("Automatic Mode: Bitrates and dimensions will be dynamically optimized to guarantee output is under \(Int(mb)) MB.")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            } else {
                Text("Select a limit to automatically compute bitrates and resolutions for Discord (25MB), Nitro (50MB), or Email.")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(state.targetSizeMode != .off ? Color.blue.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Image Settings
    private var imageSettingsCard: some View {
        VStack(spacing: 10) {
            // Quality Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Image Quality", systemImage: "photo")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(String(format: "%.0f%%", state.imageQualitySlider * 100))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                Slider(value: $state.imageQualitySlider, in: 0.30...1.0, step: 0.05)
                    .accentColor(.blue)
                
                HStack {
                    Text("Smaller Size")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Original Quality")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                // Quick preset pills
                HStack(spacing: 5) {
                    ForEach(QualityPreset.allCases, id: \.self) { preset in
                        Button {
                            withAnimation {
                                state.imageQualityPreset = preset
                            }
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 9, weight: state.imageQualityPreset == preset ? .semibold : .regular))
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(
                                    state.imageQualityPreset == preset ?
                                    Color.blue.opacity(0.25) :
                                    Color.white.opacity(0.04)
                                )
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(imageStrategyHint)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.top, 1)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            
            // Resolution Slider Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Resolution Scale", systemImage: "aspectratio")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(state.imageResolutionScale >= 0.99 ? "Original (100%)" : String(format: "%.0f%% Scale", state.imageResolutionScale * 100))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                Slider(value: $state.imageResolutionScale, in: 0.25...1.0, step: 0.05)
                    .accentColor(.blue)
                
                HStack {
                    Text("25% Scale")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100% (Original)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                // Quick resolution pills
                HStack(spacing: 5) {
                    ForEach([0.25, 0.50, 0.75, 1.0], id: \.self) { scale in
                        Button {
                            withAnimation {
                                state.imageResolutionScale = scale
                            }
                        } label: {
                            Text(scale >= 0.99 ? "Original" : "\(Int(scale * 100))%")
                                .font(.system(size: 9, weight: abs(state.imageResolutionScale - scale) < 0.01 ? .semibold : .regular))
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(
                                    abs(state.imageResolutionScale - scale) < 0.01 ?
                                    Color.blue.opacity(0.25) :
                                    Color.white.opacity(0.04)
                                )
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text("Downscales pixel dimensions while preserving aspect ratio with zero cropping")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            
            // Format Policy Card
            VStack(alignment: .leading, spacing: 8) {
                Text("Format Target")
                    .font(.system(size: 11, weight: .bold))
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                    ForEach(ImageFormatPolicy.allCases, id: \.self) { policy in
                        Button {
                            withAnimation {
                                state.imageFormatPolicy = policy
                            }
                        } label: {
                            Text(policy.rawValue)
                                .font(.system(size: 9, weight: state.imageFormatPolicy == policy ? .semibold : .regular))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(
                                    state.imageFormatPolicy == policy ?
                                    Color.blue.opacity(0.25) :
                                    Color.white.opacity(0.04)
                                )
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(state.imageFormatPolicy == policy ? Color.blue.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(state.imageFormatPolicy.description)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
        }
    }
    
    private var imageStrategyHint: String {
        let q = state.imageQualitySlider
        let fmt = state.imageFormatPolicy
        
        switch fmt {
        case .heicModern, .jpegStandard, .webpModern, .avifModern:
            let fmtName = fmt.rawValue
            if q >= 0.85 {
                return "\(fmtName) at \(Int(q * 100))%: near-lossless visual quality, balanced file size"
            } else if q >= 0.65 {
                return "\(fmtName) at \(Int(q * 100))%: high compression with clean visual clarity"
            } else {
                return "\(fmtName) at \(Int(q * 100))%: maximum size reduction for quick web sharing"
            }
        case .preserveOriginal:
            if q >= 0.85 {
                return "Lossless re-encode: original quality preserved, metadata optimized"
            } else if q >= 0.65 {
                return "Optimized re-encode with high-dimension downscaling (>3840px)"
            } else {
                return "Maximum compression with adaptive resolution scaling"
            }
        }
    }
    
    // MARK: - Video Settings
    private var videoSettingsCard: some View {
        VStack(spacing: 10) {
            // Video Quality / Bitrate Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Video Bitrate", systemImage: "film")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(String(format: "%.0f%% of source", state.videoQualitySlider * 90))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                Slider(value: $state.videoQualitySlider, in: 0.30...1.0, step: 0.05)
                    .accentColor(.blue)
                
                HStack {
                    Text("Smaller Size")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Higher Quality")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                // Quick preset pills
                HStack(spacing: 5) {
                    ForEach(QualityPreset.allCases, id: \.self) { preset in
                        Button {
                            withAnimation {
                                state.videoQualityPreset = preset
                            }
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 9, weight: state.videoQualityPreset == preset ? .semibold : .regular))
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(
                                    state.videoQualityPreset == preset ?
                                    Color.blue.opacity(0.25) :
                                    Color.white.opacity(0.04)
                                )
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(videoStrategyHint)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.top, 1)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            
            // Video Resolution Slider Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Resolution Scale", systemImage: "aspectratio")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(state.videoResolutionScale >= 0.99 ? "Original (100%)" : String(format: "%.0f%% Scale", state.videoResolutionScale * 100))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                Slider(value: $state.videoResolutionScale, in: 0.25...1.0, step: 0.05)
                    .accentColor(.blue)
                
                HStack {
                    Text("25% Scale")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100% (Original)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                // Quick resolution pills
                HStack(spacing: 5) {
                    ForEach([0.25, 0.50, 0.75, 1.0], id: \.self) { scale in
                        Button {
                            withAnimation {
                                state.videoResolutionScale = scale
                            }
                        } label: {
                            Text(scale >= 0.99 ? "Original" : "\(Int(scale * 100))%")
                                .font(.system(size: 9, weight: abs(state.videoResolutionScale - scale) < 0.01 ? .semibold : .regular))
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(
                                    abs(state.videoResolutionScale - scale) < 0.01 ?
                                    Color.blue.opacity(0.25) :
                                    Color.white.opacity(0.04)
                                )
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text("Resizes video dimensions keeping exact aspect ratio without cropping")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            
            // Video Format / Codec Card
            VStack(alignment: .leading, spacing: 8) {
                Text("Format / Codec")
                    .font(.system(size: 11, weight: .bold))
                
                HStack(spacing: 5) {
                    ForEach(VideoCodecPreference.allCases, id: \.self) { codec in
                        Button {
                            withAnimation {
                                state.videoCodec = codec
                            }
                        } label: {
                            Text(codec.rawValue)
                                .font(.system(size: 9, weight: state.videoCodec == codec ? .semibold : .regular))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(
                                    state.videoCodec == codec ?
                                    Color.blue.opacity(0.25) :
                                    Color.white.opacity(0.04)
                                )
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(state.videoCodec == codec ? Color.blue.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(state.videoCodec.description)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                if state.videoCodec == .gif {
                    Divider().opacity(0.2)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("GIF Framerate", systemImage: "speedometer")
                                .font(.system(size: 10, weight: .semibold))
                            Spacer()
                            Text(state.gifFramerate.rawValue)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        
                        HStack(spacing: 4) {
                            ForEach(GIFFramerateOption.allCases, id: \.self) { opt in
                                Button {
                                    withAnimation {
                                        state.gifFramerate = opt
                                    }
                                } label: {
                                    Text(opt.rawValue)
                                        .font(.system(size: 9, weight: state.gifFramerate == opt ? .semibold : .regular))
                                        .padding(.vertical, 3)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            state.gifFramerate == opt ?
                                            Color.blue.opacity(0.25) :
                                            Color.white.opacity(0.04)
                                        )
                                        .cornerRadius(5)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Divider().opacity(0.2)
                    
                    Toggle("Mute / Remove Audio Track", isOn: $state.videoRemoveAudio)
                        .font(.system(size: 10))
                        .toggleStyle(.switch)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
        }
    }
    
    private var videoStrategyHint: String {
        if state.videoCodec == .gif {
            return "Animated GIF: Infinite loop, hardware extracted, auto-scaled for chat apps"
        }
        let q = state.videoQualitySlider
        let codec = state.videoCodec == .hevc ? "HEVC" : "H.264"
        if q >= 0.85 {
            return "\(codec) Hardware encoder: near-original quality, moderate size reduction"
        } else if q >= 0.65 {
            return "\(codec) Hardware encoder: high efficiency, approximately 50% smaller"
        } else {
            return "\(codec) Hardware encoder: aggressive compression, 70-80% smaller"
        }
    }
    
    // MARK: - Audio Settings
    private var audioSettingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Audio Bitrate", systemImage: "waveform")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(state.audioBitrate.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                // Bitrate pills
                HStack(spacing: 4) {
                    ForEach(AudioBitratePreference.allCases, id: \.self) { rate in
                        Button {
                            withAnimation {
                                state.audioBitrate = rate
                            }
                        } label: {
                            Text(rate.rawValue.components(separatedBy: " ").first ?? rate.rawValue)
                                .font(.system(size: 9, weight: state.audioBitrate == rate ? .semibold : .regular))
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(
                                    state.audioBitrate == rate ?
                                    Color.blue.opacity(0.25) :
                                    Color.white.opacity(0.04)
                                )
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text("Converts audio (.mp3, .wav, .flac, .aiff) to high-efficiency MPEG-4 AAC (.m4a).")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
        }
    }
    
    // MARK: - General Settings
    private var generalSettingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Watch Folder Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Auto-Squeeze Watch Folder", systemImage: "folder.badge.gearshape")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Toggle("", isOn: $state.isWatchFolderEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: state.isWatchFolderEnabled) { enabled in
                            if enabled, let path = state.watchFolderPath {
                                FolderWatchService.shared.startMonitoring(path: path)
                            } else {
                                FolderWatchService.shared.stopMonitoring()
                            }
                        }
                }
                
                if let path = state.watchFolderPath {
                    Text(path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Button {
                    selectWatchFolder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 9))
                        Text(state.watchFolderPath == nil ? "Select Folder to Watch..." : "Change Watch Folder...")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                
                Text("Monitors folder and automatically compresses any new image, video, or audio file dropped in.")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            
            VStack(spacing: 8) {
                HStack {
                    Text("Output File Suffix")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                    TextField("_min", text: $state.outputSuffix)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                
                Divider().opacity(0.2)
                
                Toggle("Strip EXIF / Metadata", isOn: $state.stripMetadata)
                    .font(.system(size: 10))
                    .toggleStyle(.switch)
                
                Divider().opacity(0.2)
                
                Toggle("Sound Chime on Completion", isOn: $state.soundEnabled)
                    .font(.system(size: 10))
                    .toggleStyle(.switch)
                
                Divider().opacity(0.2)
                
                Toggle("Haptic Feedback on Completion", isOn: $state.hapticEnabled)
                    .font(.system(size: 10))
                    .toggleStyle(.switch)
                
                Divider().opacity(0.2)
                
                Button("Reset All Compression Stats") {
                    state.resetAllStats()
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.red.opacity(0.80))
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
        }
    }
    
    private func selectWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Watch Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            state.watchFolderPath = url.path
            state.isWatchFolderEnabled = true
            FolderWatchService.shared.startMonitoring(path: url.path)
        }
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Text("SqueezeBar alpha v0.50 • SirJameTV")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 10, weight: .medium))
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

// MARK: - AppKit Visual Effect Background Helper
public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - File Thumbnail View
public struct FileThumbnailView: View {
    let url: URL
    let mediaType: MediaType
    var size: CGFloat = 28
    
    @State private var thumbnail: NSImage?
    
    public init(url: URL, mediaType: MediaType, size: CGFloat = 28) {
        self.url = url
        self.mediaType = mediaType
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: mediaType == .video ? "film" : (mediaType == .audio ? "waveform" : "photo"))
                            .font(.system(size: size * 0.42))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(width: size, height: size)
        .task(id: url) {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        if let cached = ThumbnailCache.shared.image(for: url) {
            self.thumbnail = cached
            return
        }
        
        let loaded = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            let targetSize = CGSize(width: size * 2, height: size * 2)
            
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: targetSize,
                scale: 2.0,
                representationTypes: .thumbnail
            )
            
            if let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                return representation.nsImage
            }
            
            if mediaType == .image, let img = NSImage(contentsOf: url) {
                return img
            }
            
            return NSWorkspace.shared.icon(forFile: url.path)
        }.value
        
        if let loaded = loaded {
            ThumbnailCache.shared.setImage(loaded, for: url)
            self.thumbnail = loaded
        }
    }
}

// MARK: - Thumbnail Cache
private final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()
    
    private init() {
        cache.countLimit = 150
    }
    
    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func setImage(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
