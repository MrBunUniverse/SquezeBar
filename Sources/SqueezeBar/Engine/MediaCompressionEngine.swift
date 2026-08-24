import Foundation
import AppKit
import UniformTypeIdentifiers
import AVFoundation
import CoreMedia

public actor MediaCompressionEngine {
    public static let shared = MediaCompressionEngine()
    
    private let imageCompressor = AcceleratedImageCompressor()
    private let videoCompressor = HardwareVideoCompressor()
    private let audioCompressor = HardwareAudioCompressor()
    
    private init() {}
    
    // MARK: - Batch Processing Entry Point
    public func processDroppedURLs(_ urls: [URL]) async {
        // 1. Gather all individual media files (recursively expanding folders)
        let resolvedFiles = gatherMediaFiles(from: urls)
        guard !resolvedFiles.isEmpty else { return }
        
        // 2. Fetch current config from main actor
        let config = await AppState.shared.currentConfiguration()
        
        // 3. Register jobs in AppState
        var jobsToRun: [(url: URL, type: MediaType, jobId: UUID, origSize: Int64)] = []
        for url in resolvedFiles {
            let mediaType = MediaType.classify(url: url)
            guard mediaType != .unsupported else { continue }
            
            let originalSize = fileSize(of: url)
            let jobId = UUID()
            let job = CompressionJob(
                id: jobId,
                fileURL: url,
                mediaType: mediaType,
                progress: 0.0,
                statusText: "Queued"
            )
            
            await AppState.shared.addJob(job)
            jobsToRun.append((url: url, type: mediaType, jobId: jobId, origSize: originalSize))
        }
        
        guard !jobsToRun.isEmpty else { return }
        
        // 4. Run batch with bounded concurrency (tuned for Apple Silicon hardware media engines)
        let maxConcurrent = 3
        await withTaskGroup(of: Void.self) { group in
            var running = 0
            for item in jobsToRun {
                if running >= maxConcurrent {
                    await group.next()
                    running -= 1
                }
                
                running += 1
                group.addTask {
                    await self.processSingleFile(
                        url: item.url,
                        mediaType: item.type,
                        jobId: item.jobId,
                        originalSize: item.origSize,
                        config: config
                    )
                }
            }
            
            await group.waitForAll()
        }
        
        // 5. Trigger success feedback on UI
        await AppState.shared.triggerSuccessBadge()
    }
    
    // MARK: - Single File Processing
    private func processSingleFile(
        url: URL,
        mediaType: MediaType,
        jobId: UUID,
        originalSize: Int64,
        config: CompressionConfiguration
    ) async {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let origDim = probeDimensions(for: url, mediaType: mediaType)
        let startTime = Date()
        var destinationURL = generateDestinationURL(for: url, mediaType: mediaType, config: config)
        
        await AppState.shared.updateJob(id: jobId, progress: 0.05, statusText: "Compressing...")
        
        do {
            try await executeCompression(
                sourceURL: url,
                destinationURL: destinationURL,
                mediaType: mediaType,
                config: config,
                jobId: jobId
            )
        } catch {
            // Permission or write error fallback: attempt writing to ~/Downloads
            let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            let fallbackURL = generateDestinationURL(for: url, inFolder: downloadsFolder, mediaType: mediaType, config: config)
            
            do {
                destinationURL = fallbackURL
                try await executeCompression(
                    sourceURL: url,
                    destinationURL: destinationURL,
                    mediaType: mediaType,
                    config: config,
                    jobId: jobId
                )
            } catch {
                await AppState.shared.finishJob(id: jobId, result: nil, error: error.localizedDescription)
                return
            }
        }
        
        let compressedSize = fileSize(of: destinationURL)
        let duration = Date().timeIntervalSince(startTime)
        let outDim = probeDimensions(for: destinationURL, mediaType: mediaType)
        
        let result = CompressionResult(
            originalURL: url,
            outputURL: destinationURL,
            originalSize: originalSize,
            compressedSize: compressedSize,
            duration: duration,
            mediaType: mediaType,
            originalDimensions: origDim,
            outputDimensions: outDim
        )
        
        await AppState.shared.finishJob(id: jobId, result: result, error: nil)
    }
    
    private func executeCompression(
        sourceURL: URL,
        destinationURL: URL,
        mediaType: MediaType,
        config: CompressionConfiguration,
        jobId: UUID
    ) async throws {
        switch mediaType {
        case .image:
            try imageCompressor.compressImage(
                from: sourceURL,
                to: destinationURL,
                config: config
            ) { progress in
                Task { @MainActor in
                    AppState.shared.updateJob(id: jobId, progress: progress, statusText: "Compressing \(Int(progress * 100))%")
                }
            }
            
        case .video:
            try await videoCompressor.compressVideo(
                from: sourceURL,
                to: destinationURL,
                config: config
            ) { progress in
                Task { @MainActor in
                    AppState.shared.updateJob(id: jobId, progress: progress, statusText: "Encoding \(Int(progress * 100))%")
                }
            }
            
        case .audio:
            try await audioCompressor.compressAudio(
                from: sourceURL,
                to: destinationURL,
                config: config
            ) { progress in
                Task { @MainActor in
                    AppState.shared.updateJob(id: jobId, progress: progress, statusText: "Encoding \(Int(progress * 100))%")
                }
            }
            
        case .unsupported:
            throw NSError(domain: "SqueezeBar", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported media format"])
        }
    }
    
    // MARK: - Destination Path Generation
    private func generateDestinationURL(
        for sourceURL: URL,
        inFolder customFolder: URL? = nil,
        mediaType: MediaType,
        config: CompressionConfiguration
    ) -> URL {
        let folder = customFolder ?? sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        
        let targetExt: String
        switch mediaType {
        case .image:
            targetExt = imageCompressor.outputExtension(for: sourceURL, config: config)
        case .video:
            targetExt = videoCompressor.outputExtension(for: sourceURL, config: config)
        case .audio:
            targetExt = audioCompressor.outputExtension(for: sourceURL, config: config)
        case .unsupported:
            targetExt = sourceURL.pathExtension
        }
        
        let suffix = config.suffix.isEmpty ? "_min" : config.suffix
        var candidateName = "\(baseName)\(suffix).\(targetExt)"
        var candidateURL = folder.appendingPathComponent(candidateName)
        
        // Avoid overwriting if candidate already exists
        var counter = 1
        while FileManager.default.fileExists(atPath: candidateURL.path) && candidateURL.path != sourceURL.path {
            candidateName = "\(baseName)\(suffix) (\(counter)).\(targetExt)"
            candidateURL = folder.appendingPathComponent(candidateName)
            counter += 1
        }
        
        return candidateURL
    }
    
    // MARK: - Dimension & Format Probing
    private func probeDimensions(for url: URL, mediaType: MediaType) -> String? {
        switch mediaType {
        case .image:
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return nil }
            if let w = props[kCGImagePropertyPixelWidth] as? Int,
               let h = props[kCGImagePropertyPixelHeight] as? Int {
                return "\(w) × \(h)"
            }
            return nil
        case .video:
            let asset = AVURLAsset(url: url)
            if let track = asset.tracks(withMediaType: .video).first {
                let size = track.naturalSize.applying(track.preferredTransform)
                let w = Int(abs(size.width))
                let h = Int(abs(size.height))
                return "\(w) × \(h)"
            }
            return nil
        case .audio:
            let asset = AVURLAsset(url: url)
            let sec = CMTimeGetSeconds(asset.duration)
            if sec > 0 {
                let m = Int(sec) / 60
                let s = Int(sec) % 60
                return String(format: "%d:%02d", m, s)
            }
            return nil
        case .unsupported:
            return nil
        }
    }
    
    // MARK: - File & Directory Traversal (Batch Folder Support)
    private func gatherMediaFiles(from urls: [URL]) -> [URL] {
        var result: [URL] = []
        let fileManager = FileManager.default
        
        for url in urls {
            let isScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    // Recursive directory enumerator for folders
                    if let enumerator = fileManager.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) {
                        for case let fileURL as URL in enumerator {
                            if MediaType.classify(url: fileURL) != .unsupported {
                                result.append(fileURL)
                            }
                        }
                    }
                } else {
                    if MediaType.classify(url: url) != .unsupported {
                        result.append(url)
                    }
                }
            }
        }
        
        var seen = Set<String>()
        return result.filter { seen.insert($0.path).inserted }
    }
    
    private func fileSize(of url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? Int64) ?? 0
    }
}
