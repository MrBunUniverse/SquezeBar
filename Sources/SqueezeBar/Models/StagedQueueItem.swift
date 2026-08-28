import Foundation
import SwiftUI
import Combine

// MARK: - Staged Queue Item with Per-File Compression Settings
public final class StagedQueueItem: Identifiable, ObservableObject {
    public let id: UUID
    public let fileURL: URL
    public let originalSize: Int64
    public let mediaType: MediaType
    
    // Per-file individual settings
    @Published public var customQuality: Double
    @Published public var customResolutionScale: Double
    @Published public var customImageFormat: ImageFormatPolicy
    @Published public var customVideoCodec: VideoCodecPreference
    @Published public var customVideoFramerate: VideoFramerateOption
    @Published public var customVideoRemoveAudio: Bool
    @Published public var customAudioBitrate: AudioBitratePreference
    @Published public var customPDFDPI: PDFDPIOption
    @Published public var customPDFImageQuality: Double
    @Published public var customPDFGrayscale: Bool
    @Published public var customTargetSizeMode: TargetSizeMode
    @Published public var customTargetSizeMB: Double
    @Published public var stripMetadata: Bool
    
    public init(
        id: UUID = UUID(),
        fileURL: URL,
        originalSize: Int64,
        mediaType: MediaType,
        baseConfig: CompressionConfiguration
    ) {
        self.id = id
        self.fileURL = fileURL
        self.originalSize = originalSize
        self.mediaType = mediaType
        
        switch mediaType {
        case .image:
            self.customQuality = baseConfig.imageQuality
            self.customResolutionScale = baseConfig.imageResolutionScale
        case .video:
            self.customQuality = baseConfig.videoQuality
            self.customResolutionScale = baseConfig.videoResolutionScale
        case .pdf:
            self.customQuality = baseConfig.pdfImageQuality
            self.customResolutionScale = 1.0
        default:
            self.customQuality = 0.80
            self.customResolutionScale = 1.0
        }
        
        self.customImageFormat = baseConfig.imageFormatPolicy
        self.customVideoCodec = baseConfig.videoCodec
        self.customVideoFramerate = baseConfig.videoFramerate
        self.customVideoRemoveAudio = baseConfig.videoRemoveAudio
        self.customAudioBitrate = baseConfig.audioBitrate
        self.customPDFDPI = baseConfig.pdfDPI
        self.customPDFImageQuality = baseConfig.pdfImageQuality
        self.customPDFGrayscale = baseConfig.pdfGrayscale
        self.customTargetSizeMode = baseConfig.targetSizeMode
        self.customTargetSizeMB = baseConfig.customTargetSizeMB
        self.stripMetadata = baseConfig.stripMetadata
    }
    
    public var fileName: String {
        fileURL.lastPathComponent
    }
    
    public var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    public var formatExtension: String {
        fileURL.pathExtension.uppercased()
    }
    
    public func buildConfiguration(baseConfig: CompressionConfiguration) -> CompressionConfiguration {
        var config = baseConfig
        
        switch mediaType {
        case .image:
            config.imageQuality = customQuality
            config.imageResolutionScale = customResolutionScale
            config.imageFormatPolicy = customImageFormat
        case .video:
            config.videoQuality = customQuality
            config.videoResolutionScale = customResolutionScale
            config.videoCodec = customVideoCodec
            config.videoFramerate = customVideoFramerate
            config.videoRemoveAudio = customVideoRemoveAudio
        case .audio:
            config.audioBitrate = customAudioBitrate
        case .pdf:
            config.pdfDPI = customPDFDPI
            config.pdfImageQuality = customPDFImageQuality
            config.pdfGrayscale = customPDFGrayscale
        case .unsupported:
            break
        }
        
        config.targetSizeMode = customTargetSizeMode
        config.customTargetSizeMB = customTargetSizeMB
        config.stripMetadata = stripMetadata
        
        return config
    }
}
