import Foundation
import AppKit

@main
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app operates strictly as an accessory utility without a dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize menu bar status item and drop controller
        statusBarController = StatusBarController()
        
        // Start watch folder monitoring if enabled
        let state = AppState.shared
        if state.isWatchFolderEnabled, let path = state.watchFolderPath {
            FolderWatchService.shared.startMonitoring(path: path)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        FolderWatchService.shared.stopMonitoring()
    }
    
    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    public static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
