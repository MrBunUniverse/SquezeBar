import Foundation
import Combine

public final class FolderWatchService: @unchecked Sendable {
    public static let shared = FolderWatchService()
    
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let queue = DispatchQueue(label: "com.squeezebar.folderwatch.queue", qos: .utility)
    private var knownFiles: Set<String> = []
    private var debounceTimer: Task<Void, Never>?
    
    private init() {}
    
    public func startMonitoring(path: String) {
        stopMonitoring()
        
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return
        }
        
        // Populate existing files so we only process new arrivals
        if let contents = try? fileManager.contentsOfDirectory(atPath: path) {
            knownFiles = Set(contents)
        }
        
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .link],
            queue: queue
        )
        
        src.setEventHandler { [weak self] in
            self?.handleFolderEvent(path: path)
        }
        
        src.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        
        self.source = src
        src.resume()
    }
    
    public func stopMonitoring() {
        source?.cancel()
        source = nil
        knownFiles.removeAll()
    }
    
    private func handleFolderEvent(path: String) {
        debounceTimer?.cancel()
        debounceTimer = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 sec debounce for file write completion
            guard !Task.isCancelled else { return }
            
            let fileManager = FileManager.default
            guard let currentContents = try? fileManager.contentsOfDirectory(atPath: path) else { return }
            
            let currentSet = Set(currentContents)
            let newItems = currentSet.subtracting(self.knownFiles)
            self.knownFiles = currentSet
            
            let config = await AppState.shared.currentConfiguration()
            let suffix = config.suffix.isEmpty ? "_min" : config.suffix
            
            var urlsToProcess: [URL] = []
            for item in newItems {
                if item.hasPrefix(".") || item.contains(suffix) || item.hasPrefix("clipboard_") {
                    continue
                }
                
                let itemURL = URL(fileURLWithPath: path).appendingPathComponent(item)
                if MediaType.classify(url: itemURL) != .unsupported {
                    urlsToProcess.append(itemURL)
                }
            }
            
            if !urlsToProcess.isEmpty {
                await MediaCompressionEngine.shared.processDroppedURLs(urlsToProcess)
            }
        }
    }
}
