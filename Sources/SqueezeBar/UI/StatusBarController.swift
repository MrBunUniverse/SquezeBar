import Foundation
import AppKit
import SwiftUI

@MainActor
public final class StatusBarController: NSObject {
    public static weak var sharedInstance: StatusBarController?
    
    // MARK: - Dimensions
    private let normalWidth: CGFloat = 34.0
    private let expandedWidth: CGFloat = 165.0
    private let barHeight: CGFloat = 24.0
    
    // MARK: - Properties
    private var statusItem: NSStatusItem!
    private var dropView: StatusItemDropView!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    
    // MARK: - Init
    public override init() {
        super.init()
        StatusBarController.sharedInstance = self
        setupStatusItem()
        setupPopover()
    }
    
    // MARK: - Status Item Setup
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: normalWidth)
        
        let customView = StatusItemDropView(frame: NSRect(x: 0, y: 0, width: normalWidth, height: barHeight))
        customView.controller = self
        self.dropView = customView
        
        if let button = statusItem.button {
            button.title = ""
            button.image = nil
            button.addSubview(customView)
            customView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                customView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                customView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                customView.topAnchor.constraint(equalTo: button.topAnchor),
                customView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
            
            button.registerForDraggedTypes([
                .fileURL,
                NSPasteboard.PasteboardType("NSFilenamesPboardType"),
                NSPasteboard.PasteboardType("public.file-url")
            ])
        }
    }
    
    // MARK: - Smooth Spring Expansion
    public func animateExpansion(expanded: Bool) {
        let targetWidth = expanded ? expandedWidth : normalWidth
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            self.statusItem.length = targetWidth
            self.dropView.layoutSubtreeIfNeeded()
        }
    }
    
    // MARK: - Popover Setup
    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 440, height: 560)
        pop.behavior = .transient
        pop.animates = true
        
        let contentView = QuickPopoverView(isDetachedWindow: false)
            .environmentObject(AppState.shared)
        
        pop.contentViewController = NSHostingController(rootView: contentView)
        self.popover = pop
    }
    
    public func ensurePopoverDimensions(width: CGFloat, height: CGFloat) {
        guard let pop = popover, pop.isShown else { return }
        let currentSize = pop.contentSize
        let targetW = max(currentSize.width, width)
        let targetH = max(currentSize.height, height)
        if targetW != currentSize.width || targetH != currentSize.height {
            pop.contentSize = NSSize(width: targetW, height: targetH)
        }
    }
    
    // MARK: - Popover Presentation
    public func togglePopover(sender: NSView) {
        if AppState.shared.isDetached {
            FloatingDropWindowController.shared.showFloatingWindow()
            return
        }
        
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }
    
    public func showPopover(sender: NSView) {
        if AppState.shared.isDetached {
            FloatingDropWindowController.shared.showFloatingWindow()
            return
        }
        
        if let button = statusItem.button {
            popover.behavior = AppState.shared.isPinned ? .applicationDefined : .transient
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            
            if let window = popover.contentViewController?.view.window {
                window.level = .floating
            }
            
            // Monitor clicks outside to dismiss (only if not pinned)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                guard let self = self else { return }
                if !AppState.shared.isPinned {
                    self.closePopover(sender: nil)
                }
            }
        }
    }
    
    public func updatePinState(pinned: Bool) {
        popover.behavior = pinned ? .applicationDefined : .transient
        if let window = popover.contentViewController?.view.window {
            window.level = pinned ? .floating : .normal
        }
    }
    
    public func closePopover(sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        }
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    // MARK: - Right Click Context Menu
    public func showContextMenu(for view: NSView, with event: NSEvent) {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "SqueezeBar", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let openItem = NSMenuItem(title: "Open SqueezeBar Hub", action: #selector(menuOpenHub), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        
        let detachItem = NSMenuItem(
            title: AppState.shared.isDetached ? "Dock to Menu Bar" : "Detach Floating Window",
            action: #selector(menuToggleDetach),
            keyEquivalent: "d"
        )
        detachItem.target = self
        menu.addItem(detachItem)
        
        let clearItem = NSMenuItem(title: "Clear Compression History", action: #selector(menuClearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit SqueezeBar", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // restore custom click handler
    }
    
    @objc private func menuOpenHub() {
        if AppState.shared.isDetached {
            FloatingDropWindowController.shared.showFloatingWindow()
        } else if let button = statusItem.button {
            showPopover(sender: button)
        }
    }
    
    @objc private func menuToggleDetach() {
        FloatingDropWindowController.shared.toggleWindow()
    }
    
    @objc private func menuClearHistory() {
        AppState.shared.clearHistory()
    }
    
    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }
}
