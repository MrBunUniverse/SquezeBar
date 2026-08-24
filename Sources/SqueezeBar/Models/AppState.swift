import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // MARK: - User Settings Keys
    private enum Keys {
        static let imageFormatPolicy = "squeezebar.imageFormatPolicy"
        static let imageQualityPreset = "squeezebar.imageQualityPreset"
        static let imageQualitySlider = "squeezebar.imageQualitySlider"
        static let imageResolutionScale = "squeezebar.imageResolutionScale"
        
        static let videoCodec = "squeezebar.videoCodec"
        static let videoQualityPreset = "squeezebar.videoQualityPreset"
        static let videoQualitySlider = "squeezebar.videoQualitySlider"
        static let videoResolutionScale = "squeezebar.videoResolutionScale"
        static let videoRemoveAudio = "squeezebar.videoRemoveAudio"
        static let gifFramerate = "squeezebar.gifFramerate"
        
        static let audioBitrate = "squeezebar.audioBitrate"
        
        static let targetSizeMode = "squeezebar.targetSizeMode"
        static let customTargetSizeMB = "squeezebar.customTargetSizeMB"
        
        static let watchFolderPath = "squeezebar.watchFolderPath"
        static let isWatchFolderEnabled = "squeezebar.isWatchFolderEnabled"
        
        static let outputSuffix = "squeezebar.outputSuffix"
        static let stripMetadata = "squeezebar.stripMetadata"
        static let hapticEnabled = "squeezebar.hapticEnabled"
        static let soundEnabled = "squeezebar.soundEnabled"
        static let historyList = "squeezebar.historyList"
        static let totalBytesSaved = "squeezebar.totalBytesSaved"
        static let totalOriginalBytes = "squeezebar.totalOriginalBytes"
        static let totalFilesProcessed = "squeezebar.totalFilesProcessed"
    }
    
    // MARK: - Image Settings
    @Published public var imageFormatPolicy: ImageFormatPolicy {
        didSet {
            UserDefaults.standard.set(imageFormatPolicy.rawValue, forKey: Keys.imageFormatPolicy)
        }
    }
    
    @Published public var imageQualityPreset: QualityPreset {
        didSet {
            UserDefaults.standard.set(imageQualityPreset.rawValue, forKey: Keys.imageQualityPreset)
            imageQualitySlider = imageQualityPreset.normalizedQuality
        }
    }
    
    @Published public var imageQualitySlider: Double {
        didSet {
            UserDefaults.standard.set(imageQualitySlider, forKey: Keys.imageQualitySlider)
        }
    }
    
    @Published public var imageResolutionScale: Double {
        didSet {
            UserDefaults.standard.set(imageResolutionScale, forKey: Keys.imageResolutionScale)
        }
    }
    
    // MARK: - Video Settings
    @Published public var videoCodec: VideoCodecPreference {
        didSet {
            UserDefaults.standard.set(videoCodec.rawValue, forKey: Keys.videoCodec)
        }
    }
    
    @Published public var videoQualityPreset: QualityPreset {
        didSet {
            UserDefaults.standard.set(videoQualityPreset.rawValue, forKey: Keys.videoQualityPreset)
            videoQualitySlider = videoQualityPreset.normalizedQuality
        }
    }
    
    @Published public var videoQualitySlider: Double {
        didSet {
            UserDefaults.standard.set(videoQualitySlider, forKey: Keys.videoQualitySlider)
        }
    }
    
    @Published public var videoResolutionScale: Double {
        didSet {
            UserDefaults.standard.set(videoResolutionScale, forKey: Keys.videoResolutionScale)
        }
    }
    
    @Published public var videoRemoveAudio: Bool {
        didSet {
            UserDefaults.standard.set(videoRemoveAudio, forKey: Keys.videoRemoveAudio)
        }
    }
    
    @Published public var gifFramerate: GIFFramerateOption {
        didSet {
            UserDefaults.standard.set(gifFramerate.rawValue, forKey: Keys.gifFramerate)
        }
    }
    
    // MARK: - Audio Settings
    @Published public var audioBitrate: AudioBitratePreference {
        didSet {
            UserDefaults.standard.set(audioBitrate.rawValue, forKey: Keys.audioBitrate)
        }
    }
    
    // MARK: - Watch Folder Settings
    @Published public var watchFolderPath: String? {
        didSet {
            UserDefaults.standard.set(watchFolderPath, forKey: Keys.watchFolderPath)
        }
    }
    
    @Published public var isWatchFolderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isWatchFolderEnabled, forKey: Keys.isWatchFolderEnabled)
        }
    }
    
    // MARK: - Automation & Target Size
    @Published public var targetSizeMode: TargetSizeMode {
        didSet {
            UserDefaults.standard.set(targetSizeMode.rawValue, forKey: Keys.targetSizeMode)
        }
    }
    
    @Published public var customTargetSizeMB: Double {
        didSet {
            UserDefaults.standard.set(customTargetSizeMB, forKey: Keys.customTargetSizeMB)
        }
    }
    
    // MARK: - General Settings
    @Published public var outputSuffix: String {
        didSet {
            UserDefaults.standard.set(outputSuffix, forKey: Keys.outputSuffix)
        }
    }
    
    @Published public var stripMetadata: Bool {
        didSet {
            UserDefaults.standard.set(stripMetadata, forKey: Keys.stripMetadata)
        }
    }
    
    @Published public var hapticEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticEnabled, forKey: Keys.hapticEnabled)
        }
    }
    
    @Published public var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled)
        }
    }
    
    @Published public var isPinned: Bool = false
    @Published public var isDetached: Bool = false
    @Published public var inspectedResult: CompressionResult? = nil
    
    // MARK: - Runtime State
    @Published public var isProcessing: Bool = false
    @Published public var overallProgress: Double = 0.0
    @Published public var activeJobs: [CompressionJob] = []
    @Published public var recentResults: [CompressionResult] = []
    @Published public var showSuccessBadge: Bool = false
    
    // MARK: - Cumulative Stats
    @Published public var totalBytesSaved: Int64
    @Published public var totalOriginalBytes: Int64
    @Published public var totalFilesProcessed: Int
    
    public var overallPercentageSaved: Double {
        guard totalOriginalBytes > 0 else { return 0.0 }
        return (Double(totalBytesSaved) / Double(totalOriginalBytes)) * 100.0
    }
    
    public var formattedTotalSaved: String {
        ByteCountFormatter.string(fromByteCount: totalBytesSaved, countStyle: .file)
    }
    
    // MARK: - Initialization
    private init() {
        // Load Image Settings
        let savedImgFormat = UserDefaults.standard.string(forKey: Keys.imageFormatPolicy) ?? ""
        self.imageFormatPolicy = ImageFormatPolicy(rawValue: savedImgFormat) ?? .preserveOriginal
        
        let savedImgPreset = UserDefaults.standard.string(forKey: Keys.imageQualityPreset) ?? ""
        self.imageQualityPreset = QualityPreset(rawValue: savedImgPreset) ?? .visuallyLossless
        
        let savedImgQuality = UserDefaults.standard.double(forKey: Keys.imageQualitySlider)
        self.imageQualitySlider = savedImgQuality > 0 ? savedImgQuality : 0.85
        
        let savedImgRes = UserDefaults.standard.double(forKey: Keys.imageResolutionScale)
        self.imageResolutionScale = savedImgRes > 0 ? savedImgRes : 1.0
        
        // Load Video Settings
        let savedVidCodec = UserDefaults.standard.string(forKey: Keys.videoCodec) ?? ""
        self.videoCodec = VideoCodecPreference(rawValue: savedVidCodec) ?? .hevc
        
        let savedVidPreset = UserDefaults.standard.string(forKey: Keys.videoQualityPreset) ?? ""
        self.videoQualityPreset = QualityPreset(rawValue: savedVidPreset) ?? .visuallyLossless
        
        let savedVidQuality = UserDefaults.standard.double(forKey: Keys.videoQualitySlider)
        self.videoQualitySlider = savedVidQuality > 0 ? savedVidQuality : 0.80
        
        let savedVidRes = UserDefaults.standard.double(forKey: Keys.videoResolutionScale)
        self.videoResolutionScale = savedVidRes > 0 ? savedVidRes : 1.0
        
        self.videoRemoveAudio = UserDefaults.standard.bool(forKey: Keys.videoRemoveAudio)
        
        let savedGIFFPS = UserDefaults.standard.string(forKey: Keys.gifFramerate) ?? ""
        self.gifFramerate = GIFFramerateOption(rawValue: savedGIFFPS) ?? .half15
        
        // Load Audio Settings
        let savedAudioBitrate = UserDefaults.standard.string(forKey: Keys.audioBitrate) ?? ""
        self.audioBitrate = AudioBitratePreference(rawValue: savedAudioBitrate) ?? .k128
        
        // Load Watch Folder Settings
        self.watchFolderPath = UserDefaults.standard.string(forKey: Keys.watchFolderPath)
        self.isWatchFolderEnabled = UserDefaults.standard.bool(forKey: Keys.isWatchFolderEnabled)
        
        // Load Automation & Target Size
        let savedTargetMode = UserDefaults.standard.string(forKey: Keys.targetSizeMode) ?? ""
        self.targetSizeMode = TargetSizeMode(rawValue: savedTargetMode) ?? .off
        
        let savedCustomSize = UserDefaults.standard.double(forKey: Keys.customTargetSizeMB)
        self.customTargetSizeMB = savedCustomSize > 0 ? savedCustomSize : 25.0
        
        // Load General Settings
        let savedSuffix = UserDefaults.standard.string(forKey: Keys.outputSuffix)
        self.outputSuffix = savedSuffix ?? "_min"
        
        self.stripMetadata = UserDefaults.standard.bool(forKey: Keys.stripMetadata)
        
        if UserDefaults.standard.object(forKey: Keys.hapticEnabled) == nil {
            self.hapticEnabled = true
        } else {
            self.hapticEnabled = UserDefaults.standard.bool(forKey: Keys.hapticEnabled)
        }
        
        if UserDefaults.standard.object(forKey: Keys.soundEnabled) == nil {
            self.soundEnabled = true
        } else {
            self.soundEnabled = UserDefaults.standard.bool(forKey: Keys.soundEnabled)
        }
        
        self.totalBytesSaved = Int64(UserDefaults.standard.integer(forKey: Keys.totalBytesSaved))
        self.totalOriginalBytes = Int64(UserDefaults.standard.integer(forKey: Keys.totalOriginalBytes))
        self.totalFilesProcessed = UserDefaults.standard.integer(forKey: Keys.totalFilesProcessed)
        
        loadHistory()
    }
    
    // MARK: - Configuration Getter
    public func currentConfiguration() -> CompressionConfiguration {
        CompressionConfiguration(
            imageQuality: imageQualitySlider,
            imageResolutionScale: imageResolutionScale,
            imageFormatPolicy: imageFormatPolicy,
            videoQuality: videoQualitySlider,
            videoResolutionScale: videoResolutionScale,
            videoCodec: videoCodec,
            videoRemoveAudio: videoRemoveAudio,
            gifFramerate: gifFramerate,
            audioBitrate: audioBitrate,
            targetSizeMode: targetSizeMode,
            customTargetSizeMB: customTargetSizeMB,
            suffix: outputSuffix.isEmpty ? "_min" : outputSuffix,
            stripMetadata: stripMetadata
        )
    }
    
    // MARK: - Clipboard Squeeze Action
    @MainActor
    public func squeezeClipboard() {
        let pasteboard = NSPasteboard.general
        
        // 1. Check for file URLs first
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            Task {
                await MediaCompressionEngine.shared.processDroppedURLs(urls)
            }
            return
        }
        
        // 2. Check for image data (e.g. screenshot copied to clipboard)
        if let imgData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            let tempSource = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard_temp_\(UUID().uuidString).png")
            let config = currentConfiguration()
            let tempDest = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard_squeezed_\(UUID().uuidString).\(AcceleratedImageCompressor().outputExtension(for: tempSource, config: config))")
            
            do {
                try imgData.write(to: tempSource)
                let originalSize = Int64(imgData.count)
                let startTime = Date()
                
                try AcceleratedImageCompressor().compressImage(from: tempSource, to: tempDest, config: config)
                let compressedData = try Data(contentsOf: tempDest)
                let compressedSize = Int64(compressedData.count)
                
                // Write compressed data back to clipboard
                pasteboard.clearContents()
                if let compressedImage = NSImage(data: compressedData) {
                    pasteboard.writeObjects([compressedImage, tempDest as NSURL])
                }
                
                let duration = Date().timeIntervalSince(startTime)
                let result = CompressionResult(
                    originalURL: tempSource,
                    outputURL: tempDest,
                    originalSize: originalSize,
                    compressedSize: compressedSize,
                    duration: duration,
                    mediaType: .image
                )
                
                recordResult(result)
                triggerSuccessBadge()
            } catch {
                print("Clipboard squeeze failed: \(error)")
            }
        }
    }
    
    // MARK: - Job Management
    public func addJob(_ job: CompressionJob) {
        activeJobs.append(job)
        updateProcessingState()
    }
    
    public func updateJob(id: UUID, progress: Double, statusText: String) {
        if let idx = activeJobs.firstIndex(where: { $0.id == id }) {
            activeJobs[idx].progress = progress
            activeJobs[idx].statusText = statusText
            updateProcessingState()
        }
    }
    
    public func finishJob(id: UUID, result: CompressionResult?, error: String?) {
        if let idx = activeJobs.firstIndex(where: { $0.id == id }) {
            activeJobs[idx].isFinished = true
            activeJobs[idx].error = error
            if let result = result {
                activeJobs[idx].statusText = "Saved \(result.formattedSaved) (-\(Int(result.percentSaved))%)"
                activeJobs[idx].progress = 1.0
                recordResult(result)
            } else {
                activeJobs[idx].statusText = error ?? "Failed"
            }
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.activeJobs.removeAll { $0.id == id }
            self.updateProcessingState()
        }
        
        updateProcessingState()
    }
    
    private func updateProcessingState() {
        let unfinished = activeJobs.filter { !$0.isFinished }
        isProcessing = !unfinished.isEmpty
        if unfinished.isEmpty {
            overallProgress = 0.0
        } else {
            let total = unfinished.reduce(0.0) { $0 + $1.progress }
            overallProgress = total / Double(unfinished.count)
        }
    }
    
    public func triggerSuccessBadge() {
        showSuccessBadge = true
        
        // Play pleasing native completion sound
        if soundEnabled {
            NSSound(named: "Glass")?.play()
        }
        
        if hapticEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .default
            )
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self.showSuccessBadge = false
        }
    }
    
    // MARK: - History & Persistence
    public func recordResult(_ result: CompressionResult) {
        recentResults.insert(result, at: 0)
        if recentResults.count > 50 {
            recentResults.removeLast()
        }
        
        totalBytesSaved += result.bytesSaved
        totalOriginalBytes += result.originalSize
        totalFilesProcessed += 1
        
        UserDefaults.standard.set(totalBytesSaved, forKey: Keys.totalBytesSaved)
        UserDefaults.standard.set(totalOriginalBytes, forKey: Keys.totalOriginalBytes)
        UserDefaults.standard.set(totalFilesProcessed, forKey: Keys.totalFilesProcessed)
        
        saveHistory()
    }
    
    public func clearHistory() {
        recentResults.removeAll()
        saveHistory()
    }
    
    public func resetAllStats() {
        totalBytesSaved = 0
        totalOriginalBytes = 0
        totalFilesProcessed = 0
        recentResults.removeAll()
        UserDefaults.standard.removeObject(forKey: Keys.totalBytesSaved)
        UserDefaults.standard.removeObject(forKey: Keys.totalOriginalBytes)
        UserDefaults.standard.removeObject(forKey: Keys.totalFilesProcessed)
        UserDefaults.standard.removeObject(forKey: Keys.historyList)
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(recentResults) {
            UserDefaults.standard.set(data, forKey: Keys.historyList)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: Keys.historyList),
           let list = try? JSONDecoder().decode([CompressionResult].self, from: data) {
            self.recentResults = list
        }
    }
    
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
