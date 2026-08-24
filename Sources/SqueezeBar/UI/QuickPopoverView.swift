import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing

public struct QuickPopoverView: View {
    @EnvironmentObject var state: AppState
    public var isDetachedWindow: Bool = false
    @State private var selectedTab: PopoverTab = .activity
    @State private var isWindowDropTargeted: Bool = false
    @State private var settingsCategory: SettingsCategory = .images
    
    // Project Folders & Batch Edit State
    @State private var isEditMode: Bool = false
    @State private var selectedResultIds: Set<UUID> = []
    @State private var isCreatingFolder: Bool = false
    @State private var newFolderName: String = ""
    @State private var isBatchRenaming: Bool = false
    @State private var renamePattern: String = ""
    @State private var isMovingToFolder: Bool = false
    @State private var showClearConfirmation: Bool = false
    
    @Namespace private var presetGliderNamespace
    @Namespace private var mainTabGliderNamespace
    @Namespace private var settingsCategoryGliderNamespace
    @Namespace private var targetLimitGliderNamespace
    @Namespace private var imgQualityGliderNamespace
    @Namespace private var imgResGliderNamespace
    @Namespace private var imgFormatGliderNamespace
    @Namespace private var vidQualityGliderNamespace
    @Namespace private var vidResGliderNamespace
    @Namespace private var vidCodecGliderNamespace
    @Namespace private var vidFpsGliderNamespace
    @Namespace private var gifFpsGliderNamespace
    @Namespace private var audioBitrateGliderNamespace
    
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
                        .strokeBorder(state.accentColor, lineWidth: 2)
                        .background(state.accentColor.opacity(0.08))
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
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text("SqueezeBar")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                    if isDetachedWindow {
                        Text("PRO")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(state.accentColor))
                    }
                }
                
                Text("Universal Media Optimizer")
                    .font(.system(size: 9, weight: .regular, design: .serif))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isDetachedWindow {
                // Compact Pill Dock button (Only shown in detached floating window)
                Button {
                    FloatingDropWindowController.shared.dockToMenuBar()
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left.square")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("Dock")
                            .font(.system(size: 9.5, weight: .semibold, design: .serif))
                    }
                    .foregroundColor(state.contrastTextColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(state.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .help("Dock to Menu Bar")
            } else {
                // Compact Pill Undock button (Only shown in Menu Bar popover)
                Button {
                    StatusBarController.sharedInstance?.closePopover(sender: nil)
                    FloatingDropWindowController.shared.showFloatingWindow()
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right.square")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("Undock")
                            .font(.system(size: 9.5, weight: .semibold, design: .serif))
                    }
                    .foregroundColor(state.contrastTextColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(state.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .help("Undock as Floating Window")
            }
            
            if state.isProcessing {
                HStack(spacing: 5) {
                    ProgressView()
                        .scaleEffect(0.60)
                        .frame(width: 12, height: 12)
                    Text("Optimizing...")
                        .font(.system(size: 10, weight: .medium, design: .serif))
                        .foregroundColor(state.accentColor)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(state.accentColor.opacity(0.12)))
            } else if state.showSuccessBadge {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("Complete")
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.green.opacity(0.12)))
            }
        }
        .padding(.leading, isDetachedWindow ? 76 : 14)
        .padding(.trailing, 12)
        .padding(.top, isDetachedWindow ? 11 : 8)
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Selector (Liquid Frosted Pill Glider with Cursor Glow)
    private var tabSelectorView: some View {
        HStack(spacing: 4) {
            ForEach(PopoverTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
                        selectedTab = tab
                        if tab == .settings {
                            FloatingDropWindowController.shared.ensureMinimumDimensions(width: 480, height: 640)
                            StatusBarController.sharedInstance?.ensurePopoverDimensions(width: 480, height: 640)
                        }
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium, design: .serif))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                if isSelected {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.19), Color.white.opacity(0.09)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .matchedGeometryEffect(id: "MainTabGlider", in: mainTabGliderNamespace)
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 0.75
                                                )
                                        )
                                        .shadow(color: Color.black.opacity(0.25), radius: 4, y: 1.5)
                                }
                            }
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3.5)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.24))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }
    
    // MARK: - Quick Presets Bar (Pill Gliders with Sliding Spring Matched Geometry & Cursor Glow)
    private var quickPresetBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TargetSizeMode.allCases, id: \.self) { mode in
                    InteractivePresetPill(
                        mode: mode,
                        isSelected: state.targetSizeMode == mode,
                        accentColor: state.accentColor,
                        contrastTextColor: state.contrastTextColor,
                        namespace: presetGliderNamespace
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            state.targetSizeMode = mode
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Stats Summary Cards (Editorial Health/Bloodwork Inspired 3-Tile Row with Proximity & Near-Cursor Light-Leak Glow)
    private var statsSummaryCard: some View {
        ProximityGlowContainer {
            HStack(spacing: 8) {
                InteractiveGlowTile(
                    title: "Space Saved",
                    value: state.formattedTotalSaved,
                    badge: state.overallPercentageSaved > 0 ? String(format: "-%.0f%%", state.overallPercentageSaved) : nil,
                    icon: "arrow.down.circle.fill",
                    accentColor: state.accentColor
                )
                
                InteractiveGlowTile(
                    title: "Efficiency",
                    value: String(format: "%.0f%%", state.overallPercentageSaved),
                    badge: "Avg",
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    accentColor: .green
                )
                
                InteractiveGlowTile(
                    title: "Optimized",
                    value: "\(state.totalFilesProcessed)",
                    badge: "Files",
                    icon: "sparkles.rectangle.stack.fill",
                    accentColor: .purple
                )
            }
        }
    }
    
    // MARK: - Active Queue Section
    private var activeQueueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CURRENT QUEUE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            ForEach(state.activeJobs) { job in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        FileThumbnailView(url: job.fileURL, mediaType: job.mediaType, size: 26)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(job.fileURL.lastPathComponent)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Text(job.statusText)
                                .font(.system(size: 9))
                                .foregroundColor(state.accentColor)
                        }
                        
                        Spacer()
                    }
                    
                    ProgressView(value: job.progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .accentColor(state.accentColor)
                        .scaleEffect(x: 1, y: 0.8, anchor: .center)
                }
                .padding(9)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(state.accentColor.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(state.accentColor.opacity(0.2), lineWidth: 0.5)
                        )
                )
            }
        }
    }
    
    // MARK: - Recent History Section with Collapsible Folders & Batch Edit
    private var recentHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar
            HStack(spacing: 6) {
                Text("PROJECTS & RECENT")
                    .font(.system(size: 9.5, weight: .bold, design: .serif))
                    .foregroundColor(.secondary.opacity(0.9))
                
                Spacer()
                
                // New Folder Button
                Button {
                    newFolderName = "Project \(state.customFolders.count + 1)"
                    isCreatingFolder = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 9))
                        Text("New Folder")
                            .font(.system(size: 9.5, weight: .medium, design: .serif))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Create Project Folder")
                
                if !state.recentResults.isEmpty {
                    // Edit Mode Toggle Button
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isEditMode.toggle()
                            if !isEditMode {
                                selectedResultIds.removeAll()
                            }
                        }
                    } label: {
                        Text(isEditMode ? "Done" : "Edit")
                            .font(.system(size: 9.5, weight: .semibold, design: .serif))
                            .foregroundColor(isEditMode ? state.contrastTextColor : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(
                                Capsule().fill(isEditMode ? state.accentColor : Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    
                    if !isEditMode {
                        Button("Clear") {
                            showClearConfirmation = true
                        }
                        .font(.system(size: 9.5, weight: .medium, design: .serif))
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary.opacity(0.7))
                        .confirmationDialog("Clear Recent Compressions?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                            Button("Clear All History", role: .destructive) {
                                state.clearHistory()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will remove recent items from your activity log. Original files on disk will not be deleted.")
                        }
                    }
                }
            }
            
            // Batch Action Toolbar (Visible in Edit Mode)
            if isEditMode {
                batchActionToolbar
            }
            
            if state.recentResults.isEmpty && state.customFolders.isEmpty {
                emptyHistoryView
            } else {
                // 1. Custom Project Folders
                ForEach(state.customFolders) { folder in
                    folderSectionView(folder: folder)
                }
                
                // 2. Uncategorized Recent Items
                let uncategorized = state.recentResults.filter { $0.folderId == nil }
                if !uncategorized.isEmpty || state.customFolders.isEmpty {
                    if !state.customFolders.isEmpty {
                        HStack {
                            Text("Uncategorized")
                                .font(.system(size: 10, weight: .semibold, design: .serif))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if isEditMode {
                                Button("Select All") {
                                    let ids = Set(uncategorized.map { $0.id })
                                    if selectedResultIds.isSuperset(of: ids) {
                                        selectedResultIds.subtract(ids)
                                    } else {
                                        selectedResultIds.formUnion(ids)
                                    }
                                }
                                .font(.system(size: 9, design: .serif))
                                .buttonStyle(.plain)
                                .foregroundColor(state.accentColor)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    ForEach(uncategorized) { item in
                        historyRow(item: item)
                    }
                }
            }
        }
        .sheet(isPresented: $isCreatingFolder) {
            newFolderModal
        }
        .sheet(isPresented: $isBatchRenaming) {
            batchRenameModal
        }
    }
    
    // MARK: - Batch Action Toolbar (Select All, Delete, Move, Rename)
    private var batchActionToolbar: some View {
        HStack(spacing: 8) {
            Button {
                if selectedResultIds.count == state.recentResults.count {
                    selectedResultIds.removeAll()
                } else {
                    selectedResultIds = Set(state.recentResults.map { $0.id })
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedResultIds.count == state.recentResults.count && !state.recentResults.isEmpty ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10))
                        .foregroundColor(selectedResultIds.isEmpty ? .secondary : state.accentColor)
                    Text(selectedResultIds.count == state.recentResults.count && !state.recentResults.isEmpty ? "Deselect All" : "Select All")
                        .font(.system(size: 9.5, weight: .medium, design: .serif))
                }
            }
            .buttonStyle(.plain)
            
            Text("(\(selectedResultIds.count) selected)")
                .font(.system(size: 9, design: .serif))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if !selectedResultIds.isEmpty {
                // Batch Rename Button
                Button {
                    renamePattern = "Compressed_#"
                    isBatchRenaming = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 9))
                        Text("Rename")
                            .font(.system(size: 9.5, weight: .medium, design: .serif))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.blue))
                }
                .buttonStyle(.plain)
                
                // Move to Folder Menu
                Menu {
                    Button("None (Uncategorized)") {
                        state.assignResultsToFolder(resultIds: selectedResultIds, folderId: nil)
                    }
                    ForEach(state.customFolders) { f in
                        Button(f.name) {
                            state.assignResultsToFolder(resultIds: selectedResultIds, folderId: f.id)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                            .font(.system(size: 9))
                        Text("Move")
                            .font(.system(size: 9.5, weight: .medium, design: .serif))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .menuStyle(.borderlessButton)
                
                // Batch Delete Button
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        state.batchDeleteResults(ids: selectedResultIds)
                        selectedResultIds.removeAll()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9.5))
                        .foregroundColor(.red.opacity(0.9))
                        .padding(5)
                        .background(Capsule().fill(Color.red.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("Delete Selected")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        )
    }
    
    // MARK: - Collapsible Folder Section View with Direct Drag & Drop Support
    @ViewBuilder
    private func folderSectionView(folder: CompressionFolder) -> some View {
        FolderSectionItemView(
            folder: folder,
            isEditMode: isEditMode,
            selectedResultIds: $selectedResultIds
        )
    }
    
    // MARK: - Modals (New Folder & Format Rename)
    private var newFolderModal: some View {
        VStack(spacing: 12) {
            Text("Create Project Folder")
                .font(.system(size: 13, weight: .bold, design: .serif))
            
            TextField("Folder Name", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
            
            HStack(spacing: 10) {
                Button("Cancel") {
                    isCreatingFolder = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button("Create") {
                    state.addFolder(name: newFolderName)
                    isCreatingFolder = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(state.accentColor))
            }
        }
        .padding(20)
        .frame(width: 280)
    }
    
    private var batchRenameModal: some View {
        let previewExample1 = renamePattern.replacingOccurrences(of: "{index}", with: "1").replacingOccurrences(of: "{i}", with: "1").replacingOccurrences(of: "#", with: "1")
        let previewExample2 = renamePattern.replacingOccurrences(of: "{index}", with: "2").replacingOccurrences(of: "{i}", with: "2").replacingOccurrences(of: "#", with: "2")
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Batch Format Rename (\(selectedResultIds.count) files)")
                .font(.system(size: 13, weight: .bold, design: .serif))
            
            Text("Enter a format pattern. Use '#' or '{index}' for auto-incrementing numbers.")
                .font(.system(size: 10, design: .serif))
                .foregroundColor(.secondary)
            
            TextField("e.g. Homerenovation_# or Project_{index}", text: $renamePattern)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            
            // Live Format Preview Box
            VStack(alignment: .leading, spacing: 3) {
                Text("LIVE PREVIEW:")
                    .font(.system(size: 8.5, weight: .bold, design: .serif))
                    .foregroundColor(.secondary.opacity(0.8))
                
                HStack(spacing: 4) {
                    Text("\(previewExample1).mp4,  \(previewExample2).mp4 ...")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(state.accentColor)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(state.accentColor.opacity(0.3), lineWidth: 0.5))
            }
            
            // Quick preset tokens
            HStack(spacing: 6) {
                Button("Homerenovation_#") {
                    renamePattern = "Homerenovation_#"
                }
                .font(.system(size: 9))
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                
                Button("Optimized_{index}") {
                    renamePattern = "Optimized_{index}"
                }
                .font(.system(size: 9))
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") {
                    isBatchRenaming = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button("Rename Files") {
                    state.batchRenameResults(ids: selectedResultIds, pattern: renamePattern)
                    isBatchRenaming = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(state.accentColor))
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 320)
    }
    
    @State private var isDropTargeted: Bool = false
    
    private var emptyHistoryView: some View {
        VStack(spacing: 10) {
            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "square.and.arrow.down.on.square")
                .font(.system(size: 26))
                .foregroundColor(isDropTargeted ? .blue : .secondary.opacity(0.5))
                .scaleEffect(isDropTargeted ? 1.08 : 1.0)
                .animation(.spring(response: 0.25), value: isDropTargeted)
            
            Text(isDropTargeted ? "Drop Files to Compress" : "Ready to Squeeze")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundColor(.primary)
            
            Text("Drop high-res images, 4K video clips, or audio tracks here to instantly optimize.")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            // Clipboard Squeeze Button (Frosted Pill Style)
            Button {
                state.squeezeClipboard()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 9.5))
                    Text("Squeeze from Clipboard")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isDropTargeted ? state.accentColor.opacity(0.08) :
                    Color.white.opacity(0.02)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isDropTargeted ? state.accentColor.opacity(0.6) : Color.white.opacity(0.06),
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
        QuickPopoverHistoryRowItem(
            item: item,
            isEditMode: isEditMode,
            selectedResultIds: $selectedResultIds
        )
    }    
    // MARK: - Settings Tab View
    private var settingsSection: some View {
        VStack(spacing: 12) {
            // Category Switcher (Liquid Pill Gliders with Cursor Glow)
            HStack(spacing: 4) {
                ForEach(SettingsCategory.allCases, id: \.self) { cat in
                    UniversalPillGliderItem(
                        item: cat,
                        title: cat.rawValue,
                        icon: cat == .images ? "photo" : (cat == .videos ? "film" : (cat == .audio ? "waveform" : "gearshape")),
                        isSelected: settingsCategory == cat,
                        accentColor: state.accentColor,
                        contrastTextColor: state.contrastTextColor,
                        namespace: settingsCategoryGliderNamespace,
                        gliderId: "SettingsCategoryGlider"
                    ) {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                            settingsCategory = cat
                        }
                    }
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.22))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
            
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Target Size Limit", systemImage: "target")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                Spacer()
                if let targetMB = state.targetSizeMode.targetMegabytes ?? (state.targetSizeMode == .custom ? state.customTargetSizeMB : nil) {
                    Text(String(format: "≤ %.0f MB", targetMB))
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(state.accentColor)
                } else {
                    Text("Manual Quality")
                        .font(.system(size: 10, weight: .regular, design: .serif))
                        .foregroundColor(.secondary)
                }
            }
            
            // Preset pills with matched geometry glider
            HStack(spacing: 4) {
                ForEach(TargetSizeMode.allCases, id: \.self) { mode in
                    UniversalPillGliderItem(
                        item: mode,
                        title: mode == .off ? "Manual" : (mode == .custom ? "Custom" : (mode.targetMegabytes.map { "\(Int($0))MB" } ?? mode.rawValue)),
                        icon: state.targetSizeMode == mode ? "checkmark" : nil,
                        isSelected: state.targetSizeMode == mode,
                        accentColor: state.accentColor,
                        contrastTextColor: state.contrastTextColor,
                        namespace: targetLimitGliderNamespace,
                        gliderId: "TargetLimitGlider"
                    ) {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                            state.targetSizeMode = mode
                        }
                    }
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
                            .foregroundColor(state.accentColor)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { state.customTargetSizeMB },
                            set: { newVal in
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    state.customTargetSizeMB = newVal
                                }
                            }
                        ),
                        in: 1.0...200.0,
                        step: 1.0
                    )
                    .accentColor(state.accentColor)
                }
                .padding(.top, 2)
            }
            
            // Lock Original Resolution & Lock Audio Bitrate Toggles (Liquid Glass Style)
            if state.targetSizeMode != .off {
                Divider()
                    .opacity(0.12)
                    .padding(.vertical, 2)
                
                VStack(spacing: 6) {
                    LiquidGlassToggleRow(
                        title: "Lock Original Resolution",
                        subtitle: state.preserveResolutionInTargetMode ? "Keeps 100% dimensions and compresses bitrate/CRF aggressively" : "Allows smart downscaling + bitrate reduction for optimal balance",
                        icon: "aspectratio",
                        isOn: $state.preserveResolutionInTargetMode
                    )
                    
                    LiquidGlassToggleRow(
                        title: "Lock Original Audio Quality",
                        subtitle: state.preserveAudioQualityInTargetMode ? "Keeps standard 128 kbps audio (takes more video budget)" : "Dynamically scales audio (48k–64k) to maximize video quality",
                        icon: "waveform",
                        isOn: $state.preserveAudioQualityInTargetMode
                    )
                }
                .padding(.top, 1)
            }
            
            if state.targetSizeMode != .off {
                let mb = state.targetSizeMode.targetMegabytes ?? state.customTargetSizeMB
                Text("Automatic Mode: Sliders adjust automatically to guarantee output stays under \(Int(mb)) MB.")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            } else {
                Text("Select a preset to auto-adjust sliders for Discord (25MB), Nitro (50MB), Email (10MB), or Fast Web (2MB).")
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
                        .stroke(state.targetSizeMode != .off ? state.accentColor.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
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
                        .foregroundColor(state.accentColor)
                }
                
                Slider(value: $state.imageQualitySlider, in: 0.30...1.0, step: 0.05)
                    .accentColor(state.accentColor)
                
                HStack {
                    Text("Smaller Size")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Original Quality")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                // Quick preset pills with matched geometry glider
                HStack(spacing: 4) {
                    ForEach(QualityPreset.allCases, id: \.self) { preset in
                        UniversalPillGliderItem(
                            item: preset,
                            title: preset.rawValue,
                            icon: nil,
                            isSelected: state.imageQualityPreset == preset,
                            accentColor: state.accentColor,
                            contrastTextColor: state.contrastTextColor,
                            namespace: imgQualityGliderNamespace,
                            gliderId: "ImgQualityGlider"
                        ) {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                                state.imageQualityPreset = preset
                            }
                        }
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
                        .font(.system(size: 11, weight: .bold, design: .serif))
                    Spacer()
                    Text(state.imageResolutionScale >= 0.99 ? "Original (100%)" : String(format: "%.0f%% Scale", state.imageResolutionScale * 100))
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(state.accentColor)
                }
                
                Slider(value: $state.imageResolutionScale, in: 0.25...1.0, step: 0.05)
                    .accentColor(state.accentColor)
                
                HStack {
                    Text("25% Scale")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100% (Original)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                // Quick resolution pills with matched geometry glider
                HStack(spacing: 4) {
                    ForEach([0.25, 0.50, 0.75, 1.0], id: \.self) { scale in
                        UniversalPillGliderItem(
                            item: scale,
                            title: scale >= 0.99 ? "Original" : "\(Int(scale * 100))%",
                            icon: nil,
                            isSelected: abs(state.imageResolutionScale - scale) < 0.01,
                            accentColor: state.accentColor,
                            contrastTextColor: state.contrastTextColor,
                            namespace: imgResGliderNamespace,
                            gliderId: "ImgResGlider"
                        ) {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                                state.imageResolutionScale = scale
                            }
                        }
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
                    .font(.system(size: 11, weight: .bold, design: .serif))
                
                HStack(spacing: 4) {
                    ForEach(ImageFormatPolicy.allCases, id: \.self) { policy in
                        UniversalPillGliderItem(
                            item: policy,
                            title: policy.rawValue.replacingOccurrences(of: "Modern ", with: ""),
                            icon: nil,
                            isSelected: state.imageFormatPolicy == policy,
                            accentColor: state.accentColor,
                            contrastTextColor: state.contrastTextColor,
                            namespace: imgFormatGliderNamespace,
                            gliderId: "ImgFormatGlider"
                        ) {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                                state.imageFormatPolicy = policy
                            }
                        }
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
                        .foregroundColor(state.accentColor)
                }
                
                Slider(value: $state.videoQualitySlider, in: 0.30...1.0, step: 0.05)
                    .accentColor(state.accentColor)
                
                HStack {
                    Text("Smaller Size")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Higher Quality")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                             // Quick preset pills with matched geometry glider
                HStack(spacing: 4) {
                    ForEach(QualityPreset.allCases, id: \.self) { preset in
                        UniversalPillGliderItem(
                            item: preset,
                            title: preset.rawValue,
                            icon: nil,
                            isSelected: state.videoQualityPreset == preset,
                            accentColor: state.accentColor,
                            contrastTextColor: state.contrastTextColor,
                            namespace: vidQualityGliderNamespace,
                            gliderId: "VidQualityGlider"
                        ) {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                                state.videoQualityPreset = preset
                            }
                        }
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
                        .font(.system(size: 11, weight: .bold, design: .serif))
                    Spacer()
                    Text(state.videoResolutionScale >= 0.99 ? "Original (100%)" : String(format: "%.0f%% Scale", state.videoResolutionScale * 100))
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(state.accentColor)
                }
                
                Slider(value: $state.videoResolutionScale, in: 0.25...1.0, step: 0.05)
                    .accentColor(state.accentColor)
                
                HStack {
                    Text("25% Scale")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100% (Original)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                // Quick resolution pills with matched geometry glider
                HStack(spacing: 4) {
                    ForEach([0.25, 0.50, 0.75, 1.0], id: \.self) { scale in
                        UniversalPillGliderItem(
                            item: scale,
                            title: scale >= 0.99 ? "Original" : "\(Int(scale * 100))%",
                            icon: nil,
                            isSelected: abs(state.videoResolutionScale - scale) < 0.01,
                            accentColor: state.accentColor,
                            contrastTextColor: state.contrastTextColor,
                            namespace: vidResGliderNamespace,
                            gliderId: "VidResGlider"
                        ) {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                                state.videoResolutionScale = scale
                            }
                        }
                    }
                }
                
                Text("Resizes video dimensions keeping exact aspect ratio without cropping")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            
            // Video Framerate Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Framerate (FPS)", systemImage: "speedometer")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                    Spacer()
                    Text(state.videoFramerate.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(state.accentColor)
                }
                
                // Framerate pills with matched geometry glider
                HStack(spacing: 3.5) {
                    ForEach(VideoFramerateOption.allCases, id: \.self) { opt in
                        UniversalPillGliderItem(
                            item: opt,
                            title: opt == .original ? "Original" : opt.rawValue.replacingOccurrences(of: " FPS", with: ""),
                            icon: nil,
                            isSelected: state.videoFramerate == opt,
                            accentColor: state.accentColor,
                            contrastTextColor: state.contrastTextColor,
                            namespace: vidFpsGliderNamespace,
                            gliderId: "VidFpsGlider"
                        ) {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                                state.videoFramerate = opt
                            }
                        }
                    }
                }
                
                Text(state.videoFramerate == .original ? "Preserves native source framerate (e.g. 60fps, 59.94fps, 24fps)" : "Converts video cadence to \(state.videoFramerate.rawValue) to drastically reduce bitrate")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            
            // Video Format / Codec Card
            VStack(alignment: .leading, spacing: 8) {
                Text("Format / Codec")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                
                HStack(spacing: 4) {
                    ForEach(VideoCodecPreference.allCases, id: \.self) { codec in
                        UniversalPillGliderItem(
                            item: codec,
                            title: codec.rawValue,
                            icon: nil,
                            isSelected: state.videoCodec == codec,
                            accentColor: state.accentColor,
                            contrastTextColor: state.contrastTextColor,
                            namespace: vidCodecGliderNamespace,
                            gliderId: "VidCodecGlider"
                        ) {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                                state.videoCodec = codec
                            }
                        }
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
                                .font(.system(size: 10, weight: .semibold, design: .serif))
                            Spacer()
                            Text(state.gifFramerate.rawValue)
                                .font(.system(size: 10, weight: .semibold, design: .serif))
                                .foregroundColor(state.accentColor)
                        }
                        
                        HStack(spacing: 4) {
                            ForEach(GIFFramerateOption.allCases, id: \.self) { opt in
                                UniversalPillGliderItem(
                                    item: opt,
                                    title: opt.rawValue,
                                    icon: nil,
                                    isSelected: state.gifFramerate == opt,
                                    accentColor: state.accentColor,
                                    contrastTextColor: state.contrastTextColor,
                                    namespace: gifFpsGliderNamespace,
                                    gliderId: "GifFpsGlider"
                                ) {
                                    withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                                        state.gifFramerate = opt
                                    }
                                }
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
        if state.videoCodec == .hevc {
            if q >= 0.85 {
                return "HEVC (H.265): Next-gen efficiency, ~50% smaller than H.264 at pristine visual quality"
            } else if q >= 0.65 {
                return "HEVC (H.265): High compression Apple Silicon Media Engine encoding"
            } else {
                return "HEVC (H.265): Extreme compression with modern bitrate savings (70–85% smaller)"
            }
        } else {
            // H.264
            if q >= 0.85 {
                return "H.264 (AVC): Universal compatibility across all legacy browsers, Discord & Android"
            } else if q >= 0.65 {
                return "H.264 (AVC): Balanced standard compression with guaranteed playback everywhere"
            } else {
                return "H.264 (AVC): High size reduction while maintaining broad device playback"
            }
        }
    }
    
    // MARK: - Audio Settings
    private var audioSettingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Audio Bitrate", systemImage: "waveform")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                    Spacer()
                    Text(state.audioBitrate.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(state.accentColor)
                }
                
                // Bitrate pills with matched geometry glider
                HStack(spacing: 4) {
                    ForEach(AudioBitratePreference.allCases, id: \.self) { rate in
                        UniversalPillGliderItem(
                            item: rate,
                            title: rate.rawValue.components(separatedBy: " ").first ?? rate.rawValue,
                            icon: nil,
                            isSelected: state.audioBitrate == rate,
                            accentColor: state.accentColor,
                            contrastTextColor: state.contrastTextColor,
                            namespace: audioBitrateGliderNamespace,
                            gliderId: "AudioBitrateGlider"
                        ) {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                                state.audioBitrate = rate
                            }
                        }
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
            // Apple Minimalist Theme Accent Color Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Theme Accent Color", systemImage: "paintpalette.fill")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                    Spacer()
                    Text(state.accentTheme == .custom ? "#\(state.customAccentHex)" : state.accentTheme.rawValue)
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundColor(state.accentColor)
                }
                
                // Native macOS Style Swatch Circles
                HStack(spacing: 8) {
                    ForEach(AccentColorTheme.allCases, id: \.self) { theme in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                state.accentTheme = theme
                            }
                        } label: {
                            ZStack {
                                if theme == .custom {
                                    // Angular rainbow gradient colorwheel circle with live center pip
                                    ZStack {
                                        AngularGradient(
                                            gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .pink, .red]),
                                            center: .center
                                        )
                                        .clipShape(Circle())
                                        .frame(width: 22, height: 22)
                                        
                                        // Center preview orb of current custom color
                                        Circle()
                                            .fill(state.accentColor)
                                            .frame(width: 10, height: 10)
                                            .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.5))
                                    }
                                } else {
                                    Circle()
                                        .fill(themeColor(for: theme))
                                        .frame(width: 22, height: 22)
                                }
                                
                                // Selected Ring
                                if state.accentTheme == theme {
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2)
                                        .frame(width: 28, height: 28)
                                        .shadow(color: Color.black.opacity(0.3), radius: 2)
                                }
                            }
                            .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                
                // Custom HEX Color Tab (Expands when Custom Color Wheel is active)
                if state.accentTheme == .custom {
                    VStack(alignment: .leading, spacing: 6) {
                        Divider().opacity(0.15)
                        
                        HStack(spacing: 8) {
                            Text("HEX Code")
                                .font(.system(size: 9.5, weight: .semibold, design: .serif))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 3) {
                                Text("#")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                TextField("007AFF", text: Binding(
                                    get: { state.customAccentHex },
                                    set: { newHex in
                                        let filtered = newHex.filter { "0123456789abcdefABCDEF".contains($0) }.prefix(6)
                                        state.customAccentHex = String(filtered).uppercased()
                                    }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .frame(width: 65)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(state.accentColor.opacity(0.4), lineWidth: 0.75)
                                    )
                            )
                            
                            // Native macOS Color Wheel / Spectrum Pop-out Picker
                            ColorPicker("", selection: Binding(
                                get: { state.accentColor },
                                set: { newColor in
                                    state.customAccentHex = AppState.hexFromColor(newColor)
                                }
                            ), supportsOpacity: false)
                            .labelsHidden()
                            .scaleEffect(0.9)
                            .frame(width: 28, height: 20)
                            .help("Open System Color Wheel")
                            
                            Spacer()
                            
                            // Quick Popular Hex Swatches
                            HStack(spacing: 4) {
                                ForEach(["FF2D55", "5856D6", "00C7BE", "30D158", "FF9500"], id: \.self) { quickHex in
                                    Button {
                                        withAnimation(.spring(response: 0.25)) {
                                            state.customAccentHex = quickHex
                                        }
                                    } label: {
                                        Circle()
                                            .fill(AppState.colorFromHex(quickHex) ?? .blue)
                                            .frame(width: 14, height: 14)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Text("Personalize highlight colors, buttons, active toggles, and glow indicators.")
                    .font(.system(size: 8.5))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            
            // Watch Folder Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Auto-Squeeze Watch Folder", systemImage: "folder.badge.gearshape")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                    Spacer()
                    Toggle("", isOn: $state.isWatchFolderEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: state.isWatchFolderEnabled) { _, enabled in
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
            Text("SqueezeBar v0.8 • SirJameTV")
                .font(.system(size: 9, design: .serif))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 10, weight: .medium, design: .serif))
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
    
    private func themeColor(for theme: AccentColorTheme) -> Color {
        switch theme {
        case .custom:
            return state.accentColor
        case .blue:
            return Color(red: 0.1, green: 0.5, blue: 1.0)
        case .purple:
            return Color(red: 0.65, green: 0.32, blue: 0.88)
        case .pink:
            return Color(red: 0.98, green: 0.32, blue: 0.58)
        case .red:
            return Color(red: 0.95, green: 0.28, blue: 0.28)
        case .orange:
            return Color(red: 0.98, green: 0.55, blue: 0.18)
        case .yellow:
            return Color(red: 0.98, green: 0.78, blue: 0.12)
        case .green:
            return Color(red: 0.32, green: 0.82, blue: 0.42)
        case .graphite:
            return Color(red: 0.58, green: 0.60, blue: 0.64)
        }
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

// MARK: - Premium Liquid Glass Toggle Row
private struct LiquidGlassToggleRow: View {
    @EnvironmentObject var state: AppState
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                isOn.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                // Left text block
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.system(size: 9.5))
                            .foregroundColor(isOn ? state.accentColor : .secondary)
                        Text(title)
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                            .foregroundColor(.primary)
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 8)
                
                // Right Liquid Glass Toggle Switch
                LiquidGlassSwitch(isOn: $isOn)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isOn ? state.accentColor.opacity(0.06) : Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isOn ? state.accentColor.opacity(0.18) : Color.white.opacity(0.04), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Liquid Glass Switch
private struct LiquidGlassSwitch: View {
    @EnvironmentObject var state: AppState
    @Binding var isOn: Bool
    
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            // Track Capsule with Glassmorphism
            Capsule()
                .fill(
                    isOn ?
                    LinearGradient(
                        colors: [state.accentColor.opacity(0.95), state.accentColor.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 21)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isOn ?
                            LinearGradient(colors: [Color.white.opacity(0.5), state.accentColor.opacity(0.3)], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 0.75
                        )
                )
                .shadow(color: isOn ? state.accentColor.opacity(0.4) : Color.black.opacity(0.2), radius: isOn ? 4 : 1, y: 1)
            
            // Thumb Orb with Frosted Glass Reflection & Shadow
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(white: 0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 17, height: 17)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.28), radius: 2.5, x: isOn ? -1 : 1, y: 1)
                .padding(2)
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isOn)
    }
}

// MARK: - Proximity Glow Container & Interactive Tile with Seamless Cursor Falloff
private struct ProximityGlowContainer<Content: View>: View {
    let content: Content
    @State private var cursorPosition: CGPoint = .zero
    @State private var isCursorNearby: Bool = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let loc):
                                withAnimation(.linear(duration: 0.04)) {
                                    cursorPosition = loc
                                    isCursorNearby = true
                                }
                            case .ended:
                                withAnimation(.easeOut(duration: 0.35)) {
                                    isCursorNearby = false
                                }
                            }
                        }
                }
            )
    }
}

// MARK: - Interactive Cursor-Following Glow & Light Leak Tile
private struct InteractiveGlowTile: View {
    let title: String
    let value: String
    let badge: String?
    let icon: String
    let accentColor: Color
    
    @State private var isHovered = false
    @State private var mouseLocation: CGPoint = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5))
                    .foregroundColor(accentColor)
                
                Text(title)
                    .font(.system(size: 8.5, weight: .semibold, design: .default))
                    .foregroundColor(.secondary.opacity(0.85))
                
                Spacer(minLength: 0)
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                }
            }
            
            // Editorial Serif Value
            Text(value)
                .font(.system(size: 19, weight: .medium, design: .serif))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Base Glass Slab
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isHovered ? 0.085 : 0.055), Color.white.opacity(isHovered ? 0.03 : 0.015)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Cursor-Following Light Leak / Specular Bloom (Gentle Faded White with Smooth Proximity Falloff)
                if isHovered {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.11),
                            Color.white.opacity(0.04),
                            Color.clear
                        ]),
                        center: UnitPoint(
                            x: mouseLocation.x / 140.0,
                            y: mouseLocation.y / 60.0
                        ),
                        startRadius: 0,
                        endRadius: 95
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity)
                }
            }
        )
        .overlay(
            ZStack {
                // Base Specular Border
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(isHovered ? 0.26 : 0.14), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
                
                // Cursor-Following Border Glint (Subtle Faded White Light Leak)
                if isHovered {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.42),
                                    Color.white.opacity(0.10),
                                    Color.clear
                                ]),
                                center: UnitPoint(
                                    x: mouseLocation.x / 140.0,
                                    y: mouseLocation.y / 60.0
                                ),
                                startRadius: 0,
                                endRadius: 75
                            ),
                            lineWidth: 0.75
                        )
                }
            }
        )
        .shadow(
            color: Color.black.opacity(isHovered ? 0.25 : 0.12),
            radius: isHovered ? 5 : 2,
            y: 1.5
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                withAnimation(.linear(duration: 0.04)) {
                    mouseLocation = location
                    isHovered = true
                }
            case .ended:
                withAnimation(.easeOut(duration: 0.32)) {
                    isHovered = false
                }
            }
        }
    }
}

// MARK: - Generic Universal Pill Glider with Sliding Animation & Cursor Glow
private struct UniversalPillGliderItem<T: Equatable>: View {
    let item: T
    let title: String
    let icon: String?
    let isSelected: Bool
    let accentColor: Color
    let contrastTextColor: Color
    let namespace: Namespace.ID
    let gliderId: String
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var mouseLocation: CGPoint = .zero
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 8.5, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .serif))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? contrastTextColor : (isHovered ? .white : .primary.opacity(0.85)))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.95), accentColor.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .matchedGeometryEffect(id: gliderId, in: namespace)
                            .shadow(color: accentColor.opacity(0.38), radius: 5, y: 1.5)
                    } else {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(isHovered ? 0.12 : 0.08), Color.white.opacity(isHovered ? 0.05 : 0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    // Subtle Faded White Cursor Light Leak
                    if isHovered && !isSelected {
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.14),
                                Color.white.opacity(0.04),
                                Color.clear
                            ]),
                            center: UnitPoint(
                                x: mouseLocation.x / 65.0,
                                y: mouseLocation.y / 24.0
                            ),
                            startRadius: 1,
                            endRadius: 35
                        )
                        .clipShape(Capsule())
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                ZStack {
                    if isSelected {
                        Capsule()
                            .strokeBorder(accentColor.opacity(0.6), lineWidth: 0.5)
                    } else {
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(isHovered ? 0.28 : 0.10), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    
                    if isHovered && !isSelected {
                        Capsule()
                            .strokeBorder(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.40),
                                        Color.white.opacity(0.10),
                                        Color.clear
                                    ]),
                                    center: UnitPoint(
                                        x: mouseLocation.x / 65.0,
                                        y: mouseLocation.y / 24.0
                                    ),
                                    startRadius: 1,
                                    endRadius: 30
                                ),
                                lineWidth: 0.75
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                withAnimation(.linear(duration: 0.05)) {
                    mouseLocation = location
                    isHovered = true
                }
            case .ended:
                withAnimation(.easeOut(duration: 0.25)) {
                    isHovered = false
                }
            }
        }
    }
}

// MARK: - Interactive Preset Pill with Sliding Glider & Cursor Light Leak
private struct InteractivePresetPill: View {
    let mode: TargetSizeMode
    let isSelected: Bool
    let accentColor: Color
    let contrastTextColor: Color
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        UniversalPillGliderItem(
            item: mode,
            title: mode == .off ? "Manual" : (mode == .custom ? "Custom" : (mode.targetMegabytes.map { "\(Int($0))MB" } ?? mode.rawValue)),
            icon: isSelected ? "checkmark" : nil,
            isSelected: isSelected,
            accentColor: accentColor,
            contrastTextColor: contrastTextColor,
            namespace: namespace,
            gliderId: "ActivePresetGlider",
            action: action
        )
    }
}

// MARK: - Dedicated Folder Section Item View with Drag & Drop Targeting & Inline Customization
private struct FolderSectionItemView: View {
    @EnvironmentObject var state: AppState
    let folder: CompressionFolder
    let isEditMode: Bool
    @Binding var selectedResultIds: Set<UUID>
    
    @State private var isFolderDropTargeted: Bool = false
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""
    @State private var showColorPicker: Bool = false
    
    private var effectiveFolderColor: Color {
        if let hex = folder.colorHex, !hex.isEmpty {
            return AppState.colorFromHex(hex) ?? state.accentColor
        }
        return state.accentColor
    }
    
    var body: some View {
        let itemsInFolder = state.recentResults.filter { $0.folderId == folder.id }
        let totalFolderSavedBytes = itemsInFolder.reduce(0) { $0 + max(0, $1.originalSize - $1.compressedSize) }
        let formattedFolderSaved = ByteCountFormatter.string(fromByteCount: totalFolderSavedBytes, countStyle: .file)
        
        VStack(alignment: .leading, spacing: 6) {
            // Folder Header
            HStack(spacing: 6) {
                // Collapse Chevron
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                        state.toggleFolderCollapse(id: folder.id)
                    }
                } label: {
                    Image(systemName: folder.isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Folder Icon (Double Click to Change Folder Color)
                Image(systemName: isFolderDropTargeted ? "folder.badge.plus" : folder.icon)
                    .font(.system(size: 12))
                    .foregroundColor(isFolderDropTargeted ? .green : effectiveFolderColor)
                    .scaleEffect(isFolderDropTargeted ? 1.2 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        showColorPicker = true
                    }
                    .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                        folderColorPaletteView
                    }
                    .help("Double-click to change folder color")
                
                // Folder Name (Double Click to Inline Edit)
                if isEditingName {
                    TextField("Folder Name", text: $editedName, onCommit: {
                        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            state.renameFolder(id: folder.id, newName: trimmed)
                        }
                        isEditingName = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)))
                    .frame(maxWidth: 140)
                } else {
                    Text(folder.name)
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editedName = folder.name
                            isEditingName = true
                        }
                        .help("Double-click to rename folder")
                }
                
                // Folder item count & space saved badge
                HStack(spacing: 3) {
                    Text("(\(itemsInFolder.count))")
                        .font(.system(size: 9.5, design: .serif))
                        .foregroundColor(.secondary)
                    
                    if totalFolderSavedBytes > 0 {
                        Text("• -\(formattedFolderSaved)")
                            .font(.system(size: 9, weight: .semibold, design: .serif))
                            .foregroundColor(.green.opacity(0.9))
                    }
                }
                
                if isFolderDropTargeted {
                    Text("Drop to Add")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                }
                
                Spacer()
                
                if isEditMode {
                    Button("Select All") {
                        let ids = Set(itemsInFolder.map { $0.id })
                        if selectedResultIds.isSuperset(of: ids) {
                            selectedResultIds.subtract(ids)
                        } else {
                            selectedResultIds.formUnion(ids)
                        }
                    }
                    .font(.system(size: 9, design: .serif))
                    .buttonStyle(.plain)
                    .foregroundColor(effectiveFolderColor)
                }
                
                // Folder Options Menu
                Menu {
                    Button("Rename Folder") {
                        editedName = folder.name
                        isEditingName = true
                    }
                    Button("Change Color") {
                        showColorPicker = true
                    }
                    Divider()
                    Button("Delete Folder") {
                        state.deleteFolder(id: folder.id)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isFolderDropTargeted ? Color.green.opacity(0.12) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isFolderDropTargeted ? Color.green.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
            )
            
            // Folder Contents (Collapsible)
            if !folder.isCollapsed {
                if itemsInFolder.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: isFolderDropTargeted ? "arrow.down.doc.fill" : "plus.square.dashed")
                            .font(.system(size: 14))
                            .foregroundColor(isFolderDropTargeted ? .green : effectiveFolderColor.opacity(0.6))
                        
                        Text(isFolderDropTargeted ? "Release to drop into \(folder.name)" : "Drop files here or use 'Move' in Edit mode")
                            .font(.system(size: 9, weight: .medium, design: .serif))
                            .foregroundColor(isFolderDropTargeted ? .green : .secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isFolderDropTargeted ? Color.green.opacity(0.08) : Color.white.opacity(0.015))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        isFolderDropTargeted ? Color.green.opacity(0.5) : effectiveFolderColor.opacity(0.2),
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                    )
                            )
                    )
                    .padding(.leading, 12)
                } else {
                    HStack(spacing: 6) {
                        // Vertical hierarchy tree line
                        Rectangle()
                            .fill(effectiveFolderColor.opacity(0.25))
                            .frame(width: 2)
                            .cornerRadius(1)
                            .padding(.leading, 10)
                        
                        VStack(spacing: 6) {
                            ForEach(itemsInFolder) { item in
                                QuickPopoverHistoryRowItem(
                                    item: item,
                                    isEditMode: isEditMode,
                                    selectedResultIds: $selectedResultIds
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .onDrop(of: [.fileURL], isTargeted: $isFolderDropTargeted) { providers in
            extractAndProcessFolderDrop(providers: providers, targetFolderId: folder.id)
        }
    }
    
    // MARK: - Folder Color Palette Popover (Matches Settings Theme Tab)
    private var folderColorPaletteView: some View {
        let presetThemes: [(AccentColorTheme, String, Color)] = [
            (.blue, "1A80FF", Color(red: 0.1, green: 0.5, blue: 1.0)),
            (.purple, "A652E0", Color(red: 0.65, green: 0.32, blue: 0.88)),
            (.pink, "FA5294", Color(red: 0.98, green: 0.32, blue: 0.58)),
            (.red, "F24747", Color(red: 0.95, green: 0.28, blue: 0.28)),
            (.orange, "FA8C2E", Color(red: 0.98, green: 0.55, blue: 0.18)),
            (.yellow, "FAC71F", Color(red: 0.98, green: 0.78, blue: 0.12)),
            (.green, "52D16B", Color(red: 0.32, green: 0.82, blue: 0.42)),
            (.graphite, "9499A3", Color(red: 0.58, green: 0.60, blue: 0.64))
        ]
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Folder Color")
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                // Default theme accent option
                Button {
                    state.updateFolderColor(id: folder.id, colorHex: nil)
                    showColorPicker = false
                } label: {
                    ZStack {
                        Circle()
                            .fill(state.accentColor)
                            .frame(width: 20, height: 20)
                        
                        if folder.colorHex == nil {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Default App Theme Color")
                
                // Color presets from theme palette
                ForEach(presetThemes, id: \.1) { item in
                    let hex = item.1
                    let col = item.2
                    Button {
                        state.updateFolderColor(id: folder.id, colorHex: hex)
                        showColorPicker = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(col)
                                .frame(width: 20, height: 20)
                            
                            if folder.colorHex?.uppercased() == hex.uppercased() {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(item.0.rawValue)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
    }
    
    private func extractAndProcessFolderDrop(providers: [NSItemProvider], targetFolderId: UUID) -> Bool {
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
                    await MediaCompressionEngine.shared.processDroppedURLs(collectedURLs, targetFolderId: targetFolderId)
                }
            }
        }
        return true
    }
}

// MARK: - Reusable History Row Item
private struct QuickPopoverHistoryRowItem: View {
    @EnvironmentObject var state: AppState
    let item: CompressionResult
    let isEditMode: Bool
    @Binding var selectedResultIds: Set<UUID>
    
    var body: some View {
        let isSelected = selectedResultIds.contains(item.id)
        
        HStack(spacing: 9) {
            if isEditMode {
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        if isSelected {
                            selectedResultIds.remove(item.id)
                        } else {
                            selectedResultIds.insert(item.id)
                        }
                    }
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? state.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            FileThumbnailView(url: item.outputURL, mediaType: item.mediaType, size: 30)
            
            VStack(alignment: .leading, spacing: 2.5) {
                Text(item.fileName)
                    .font(.system(size: 11.5, weight: .semibold, design: .serif))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 5) {
                    Text(item.formattedOriginalSize)
                        .font(.system(size: 9.5, design: .serif))
                        .foregroundColor(.secondary.opacity(0.8))
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(item.formattedCompressedSize)
                        .font(.system(size: 9.5, weight: .medium, design: .serif))
                        .foregroundColor(state.accentColor.opacity(0.95))
                }
            }
            
            Spacer(minLength: 4)
            
            // Percentage Pill
            Text(String(format: "-%.0f%%", item.percentSaved))
                .font(.system(size: 10.5, weight: .bold, design: .serif))
                .foregroundColor(.green)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.18), Color.green.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 0.5)
                )
            
            // Action Buttons in Frosted Mini Glass
            HStack(spacing: 2) {
                Button {
                    InspectorWindowController.shared.show(result: item)
                } label: {
                    Image(systemName: "slider.horizontal.below.rectangle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open Before/After Comparison Inspector")
                
                Button {
                    state.revealInFinder(url: item.outputURL)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.045), Color.white.opacity(0.015)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? state.accentColor.opacity(0.5) : Color.white.opacity(0.06), lineWidth: isSelected ? 1.0 : 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
        .onDrag {
            NSItemProvider(object: item.outputURL as NSURL)
        }
    }
}


