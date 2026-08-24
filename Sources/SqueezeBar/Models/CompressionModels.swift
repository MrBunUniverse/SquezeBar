import Foundation
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Media Type Classification
public enum MediaType: String, Codable, Sendable, CaseIterable {
    case image
    case video
    case audio
    case unsupported
    
    public static func classify(url: URL) -> MediaType {
        if let type = UTType(filenameExtension: url.pathExtension) {
            if type.conforms(to: .image) {
                return .image
            } else if type.conforms(to: .movie) || type.conforms(to: .video) {
                return .video
            } else if type.conforms(to: .audio) {
                return .audio
            }
        }
        
        let ext = url.pathExtension.lowercased()
        let imageExtensions = ["jpg", "jpeg", "png", "webp", "heic", "heif", "tiff", "tif", "bmp", "gif", "avif"]
        let videoExtensions = ["mov", "mp4", "m4v", "mkv", "webm", "avi", "wmv", "flv", "ts"]
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "aiff", "aif", "caf", "alac", "ogg"]
        
        if imageExtensions.contains(ext) {
            return .image
        } else if videoExtensions.contains(ext) {
            return .video
        } else if audioExtensions.contains(ext) {
            return .audio
        }
        
        return .unsupported
    }
}

// MARK: - Image Format Policy
public enum ImageFormatPolicy: String, Codable, Sendable, CaseIterable {
    case preserveOriginal = "Preserve Original"
    case heicModern = "Modern HEIC"
    case webpModern = "Modern WebP"
    case avifModern = "Modern AVIF"
    case jpegStandard = "Web JPEG"
    
    public var description: String {
        switch self {
        case .preserveOriginal:
            return "Keep original format with resolution and quality optimization"
        case .heicModern:
            return "Hardware-accelerated Apple HEIC encoding (up to 90% size reduction)"
        case .webpModern:
            return "Modern WebP encoding for lightweight web deployment"
        case .avifModern:
            return "Next-generation AVIF encoding with high visual compression"
        case .jpegStandard:
            return "Standard JPEG format for universal web compatibility"
        }
    }
}

// MARK: - Audio Bitrate Preference
public enum AudioBitratePreference: String, Codable, Sendable, CaseIterable {
    case k64 = "64 kbps (Voice)"
    case k128 = "128 kbps (Standard)"
    case k192 = "192 kbps (High)"
    case k256 = "256 kbps (Studio)"
    case k320 = "320 kbps (Max)"
    
    public var bitrateInBps: Int {
        switch self {
        case .k64: return 64_000
        case .k128: return 128_000
        case .k192: return 192_000
        case .k256: return 256_000
        case .k320: return 320_000
        }
    }
}

// MARK: - Video Codec Preference
public enum VideoCodecPreference: String, Codable, Sendable, CaseIterable {
    case hevc = "HEVC / H.265"
    case h264 = "H.264 / AVC"
    case gif = "Animated GIF"
    
    public var description: String {
        switch self {
        case .hevc:
            return "Apple Silicon Media Engine Hardware HEVC (high efficiency)"
        case .h264:
            return "Hardware H.264 video encoding (broadest device compatibility)"
        case .gif:
            return "Optimized animated GIF with looping for chat and web sharing"
        }
    }
    
    public var avCodecType: AVVideoCodecType {
        switch self {
        case .hevc: return .hevc
        case .h264: return .h264
        case .gif: return .hevc
        }
    }
}

// MARK: - GIF Framerate Options
public enum GIFFramerateOption: String, Codable, Sendable, CaseIterable {
    case full = "Full FPS"
    case smooth24 = "24 FPS"
    case half15 = "15 FPS (Half)"
    case compact10 = "10 FPS"
    
    public var maxFPS: Double? {
        switch self {
        case .full: return nil
        case .smooth24: return 24.0
        case .half15: return 15.0
        case .compact10: return 10.0
        }
    }
}

// MARK: - Legacy Format Conversion Policy (for compatibility)
public enum FormatPolicy: String, Codable, Sendable, CaseIterable {
    case preserveOriginal = "Preserve Original"
    case modernOptimized = "Modern (WebP / HEVC)"
    
    public var description: String {
        switch self {
        case .preserveOriginal:
            return "Keep same extension & container"
        case .modernOptimized:
            return "Auto-convert images to HEIC and videos to HEVC/MP4"
        }
    }
}

// MARK: - Quality Preset
public enum QualityPreset: String, Codable, Sendable, CaseIterable {
    case maxCompression = "Max Compression"
    case balanced = "Balanced"
    case visuallyLossless = "Visually Lossless"
    
    public var normalizedQuality: Double {
        switch self {
        case .maxCompression: return 0.50
        case .balanced: return 0.75
        case .visuallyLossless: return 0.90
        }
    }
    
    public var videoCRF: Double {
        switch self {
        case .maxCompression: return 30.0
        case .balanced: return 26.0
        case .visuallyLossless: return 20.0
        }
    }
}

// MARK: - Compression Result
public struct CompressionResult: Identifiable, Codable, Sendable {
    public let id: UUID
    public let originalURL: URL
    public let outputURL: URL
    public let originalSize: Int64
    public let compressedSize: Int64
    public let duration: TimeInterval
    public let mediaType: MediaType
    public let timestamp: Date
    public let originalDimensions: String?
    public let outputDimensions: String?
    
    public init(
        id: UUID = UUID(),
        originalURL: URL,
        outputURL: URL,
        originalSize: Int64,
        compressedSize: Int64,
        duration: TimeInterval,
        mediaType: MediaType,
        timestamp: Date = Date(),
        originalDimensions: String? = nil,
        outputDimensions: String? = nil
    ) {
        self.id = id
        self.originalURL = originalURL
        self.outputURL = outputURL
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.duration = duration
        self.mediaType = mediaType
        self.timestamp = timestamp
        self.originalDimensions = originalDimensions
        self.outputDimensions = outputDimensions
    }
    
    public var bytesSaved: Int64 {
        max(0, originalSize - compressedSize)
    }
    
    public var percentSaved: Double {
        guard originalSize > 0 else { return 0.0 }
        let diff = Double(originalSize - compressedSize)
        return max(0.0, (diff / Double(originalSize)) * 100.0)
    }
    
    public var fileName: String {
        originalURL.lastPathComponent
    }
    
    public var outputFileName: String {
        outputURL.lastPathComponent
    }
    
    public var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    public var formattedCompressedSize: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }
    
    public var formattedSaved: String {
        ByteCountFormatter.string(fromByteCount: bytesSaved, countStyle: .file)
    }
}

// MARK: - Job Item
public struct CompressionJob: Identifiable, Sendable {
    public let id: UUID
    public let fileURL: URL
    public let mediaType: MediaType
    public var progress: Double
    public var statusText: String
    public var isFinished: Bool
    public var error: String?
    
    public init(
        id: UUID = UUID(),
        fileURL: URL,
        mediaType: MediaType,
        progress: Double = 0.0,
        statusText: String = "Queued",
        isFinished: Bool = false,
        error: String? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.mediaType = mediaType
        self.progress = progress
        self.statusText = statusText
        self.isFinished = isFinished
        self.error = error
    }
}

// MARK: - Target Size Automation Mode
public enum TargetSizeMode: String, Codable, Sendable, CaseIterable {
    case off = "Manual Mode"
    case discord25 = "25 MB (Discord)"
    case discord50 = "50 MB (Nitro / Slack)"
    case email10 = "10 MB (Email)"
    case web2 = "2 MB (Fast Web)"
    case custom = "Custom MB Limit"
    
    public var targetMegabytes: Double? {
        switch self {
        case .off: return nil
        case .discord25: return 25.0
        case .discord50: return 50.0
        case .email10: return 10.0
        case .web2: return 2.0
        case .custom: return nil
        }
    }
}

// MARK: - Comprehensive Compression Configuration
public struct CompressionConfiguration: Sendable {
    public var imageQuality: Double
    public var imageResolutionScale: Double
    public var imageFormatPolicy: ImageFormatPolicy
    public var videoQuality: Double
    public var videoResolutionScale: Double
    public var videoCodec: VideoCodecPreference
    public var videoRemoveAudio: Bool
    public var gifFramerate: GIFFramerateOption
    public var audioBitrate: AudioBitratePreference
    public var targetSizeMode: TargetSizeMode
    public var customTargetSizeMB: Double
    public var suffix: String
    public var stripMetadata: Bool
    
    public var effectiveTargetSizeMB: Double? {
        if targetSizeMode == .off {
            return nil
        }
        return targetSizeMode.targetMegabytes ?? customTargetSizeMB
    }
    
    // Legacy support initializer
    public init(
        formatPolicy: FormatPolicy = .preserveOriginal,
        qualityPreset: QualityPreset = .visuallyLossless,
        customQuality: Double = 0.85,
        suffix: String = "_min",
        stripMetadata: Bool = false
    ) {
        self.imageQuality = customQuality
        self.imageResolutionScale = 1.0
        self.imageFormatPolicy = (formatPolicy == .modernOptimized) ? .heicModern : .preserveOriginal
        self.videoQuality = customQuality
        self.videoResolutionScale = 1.0
        self.videoCodec = (formatPolicy == .modernOptimized) ? .hevc : .hevc
        self.videoRemoveAudio = false
        self.gifFramerate = .half15
        self.audioBitrate = .k128
        self.targetSizeMode = .off
        self.customTargetSizeMB = 25.0
        self.suffix = suffix
        self.stripMetadata = stripMetadata
    }
    
    public init(
        imageQuality: Double = 0.85,
        imageResolutionScale: Double = 1.0,
        imageFormatPolicy: ImageFormatPolicy = .preserveOriginal,
        videoQuality: Double = 0.80,
        videoResolutionScale: Double = 1.0,
        videoCodec: VideoCodecPreference = .hevc,
        videoRemoveAudio: Bool = false,
        gifFramerate: GIFFramerateOption = .half15,
        audioBitrate: AudioBitratePreference = .k128,
        targetSizeMode: TargetSizeMode = .off,
        customTargetSizeMB: Double = 25.0,
        suffix: String = "_min",
        stripMetadata: Bool = false
    ) {
        self.imageQuality = imageQuality
        self.imageResolutionScale = imageResolutionScale
        self.imageFormatPolicy = imageFormatPolicy
        self.videoQuality = videoQuality
        self.videoResolutionScale = videoResolutionScale
        self.videoCodec = videoCodec
        self.videoRemoveAudio = videoRemoveAudio
        self.gifFramerate = gifFramerate
        self.audioBitrate = audioBitrate
        self.targetSizeMode = targetSizeMode
        self.customTargetSizeMB = customTargetSizeMB
        self.suffix = suffix
        self.stripMetadata = stripMetadata
    }
    
    // Convenience property for legacy call sites
    public var formatPolicy: FormatPolicy {
        return imageFormatPolicy == .preserveOriginal ? .preserveOriginal : .modernOptimized
    }
    
    public var customQuality: Double {
        return imageQuality
    }
}
