import Foundation
import AppKit
import SwiftUI

// MARK: - Liquid Ball Physical Model
@MainActor
public final class LiquidBallModel: ObservableObject {
    public static let shared = LiquidBallModel()
    
    public enum DockEdge: String {
        case left
        case right
    }
    
    @Published public var scaleX: CGFloat = 1.0
    @Published public var scaleY: CGFloat = 1.0
    @Published public var rotationAngle: Double = 0.0
    @Published public var isMoving: Bool = false
    @Published public var dockEdge: DockEdge = .right
    @Published public var isTucked: Bool = true
    
    private var tuckTimerTask: Task<Void, Never>?
    
    public func applyMotionVelocity(dx: CGFloat, dy: CGFloat) {
        isMoving = true
        isTucked = false
        cancelTuckTimer()
        
        let speed = sqrt(dx * dx + dy * dy)
        let intensity = min(1.0, speed / 24.0)
        let absDx = abs(dx)
        let absDy = abs(dy)
        
        var targetScaleX: CGFloat = 1.0
        var targetScaleY: CGFloat = 1.0
        var targetAngle: Double = 0.0
        
        if absDx >= absDy {
            // Horizontal drag: stretch wide, squash tall
            targetScaleX = 1.0 + (0.24 * intensity)
            targetScaleY = 1.0 - (0.14 * intensity)
            targetAngle = Double(dx > 0 ? 5.0 : -5.0) * intensity
        } else {
            // Vertical drag: stretch tall, squash wide
            targetScaleX = 1.0 - (0.14 * intensity)
            targetScaleY = 1.0 + (0.24 * intensity)
            targetAngle = Double(dx * 0.15)
        }
        
        withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.70)) {
            self.scaleX = targetScaleX
            self.scaleY = targetScaleY
            self.rotationAngle = targetAngle
        }
    }
    
    public func releaseMotion() {
        isMoving = false
        withAnimation(.spring(response: 0.38, dampingFraction: 0.56, blendDuration: 0.1)) {
            self.scaleX = 1.0
            self.scaleY = 1.0
            self.rotationAngle = 0.0
        }
    }
    
    public func revealFromTuck() {
        cancelTuckTimer()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
            self.isTucked = false
        }
    }
    
    public func scheduleAutoTuck(afterSeconds: Double = 1.8) {
        cancelTuckTimer()
        tuckTimerTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(afterSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if !self.isMoving && !AppState.shared.isProcessing {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
                    self.isTucked = true
                }
            }
        }
    }
    
    public func cancelTuckTimer() {
        tuckTimerTask?.cancel()
        tuckTimerTask = nil
    }
}

// MARK: - Floating Ball Hosting View with Proximity Snapping & Drag Physics
public final class FloatingBallHostingView: NSHostingView<FloatingBallView> {
    private var initialMouseLocation: CGPoint = .zero
    private var initialWindowOrigin: CGPoint = .zero
    private var lastMouseLocation: CGPoint = .zero
    private var isDraggingWindow = false
    private var trackingArea: NSTrackingArea?
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }
    
    public override func mouseEntered(with event: NSEvent) {
        Task { @MainActor in
            LiquidBallModel.shared.revealFromTuck()
        }
    }
    
    public override func mouseMoved(with event: NSEvent) {
        Task { @MainActor in
            LiquidBallModel.shared.revealFromTuck()
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        Task { @MainActor in
            LiquidBallModel.shared.scheduleAutoTuck(afterSeconds: 1.8)
        }
    }
    
    public override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        lastMouseLocation = initialMouseLocation
        initialWindowOrigin = window?.frame.origin ?? .zero
        isDraggingWindow = false
        Task { @MainActor in
            LiquidBallModel.shared.revealFromTuck()
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - initialMouseLocation.x
        let deltaY = currentMouse.y - initialMouseLocation.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        if distance > 2.0 {
            isDraggingWindow = true
            
            // Move window directly on GPU
            let newOrigin = CGPoint(
                x: initialWindowOrigin.x + deltaX,
                y: initialWindowOrigin.y + deltaY
            )
            window?.setFrameOrigin(newOrigin)
            
            // Update dynamic liquid squash and stretch physics
            let stepDx = currentMouse.x - lastMouseLocation.x
            let stepDy = currentMouse.y - lastMouseLocation.y
            Task { @MainActor in
                LiquidBallModel.shared.applyMotionVelocity(dx: stepDx, dy: stepDy)
            }
            lastMouseLocation = currentMouse
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        if isDraggingWindow {
            Task { @MainActor in
                LiquidBallModel.shared.releaseMotion()
                FloatingBallController.shared.snapToNearestScreenEdge()
            }
            isDraggingWindow = false
        } else {
            // Click without drag toggles the main popover/window
            Task { @MainActor in
                FloatingBallController.shared.toggleMainPopover()
                LiquidBallModel.shared.scheduleAutoTuck(afterSeconds: 2.5)
            }
        }
    }
}

// MARK: - Floating Ball Window Controller
@MainActor
public final class FloatingBallController: NSObject, NSWindowDelegate {
    public static let shared = FloatingBallController()
    
    private var ballPanel: NSPanel?
    private let ballSize: CGFloat = 100
    private var snapTimer: Timer?
    
    private struct Keys {
        static let ballOriginX = "squeezebar.floatingBallOriginX"
        static let ballOriginY = "squeezebar.floatingBallOriginY"
        static let dockEdge = "squeezebar.dockEdge"
    }
    
    public override init() {
        super.init()
    }
    
    public var currentPanelOrigin: CGPoint? {
        return ballPanel?.frame.origin
    }
    
    public func setPanelOrigin(_ origin: CGPoint) {
        guard let panel = ballPanel else { return }
        panel.setFrameOrigin(origin)
    }
    
    public func saveCurrentPosition() {
        guard let panel = ballPanel else { return }
        let origin = panel.frame.origin
        UserDefaults.standard.set(Double(origin.x), forKey: Keys.ballOriginX)
        UserDefaults.standard.set(Double(origin.y), forKey: Keys.ballOriginY)
        UserDefaults.standard.set(LiquidBallModel.shared.dockEdge.rawValue, forKey: Keys.dockEdge)
    }
    
    public func snapToNearestScreenEdge() {
        guard let panel = ballPanel else { return }
        let currentOrigin = panel.frame.origin
        
        // Find exact screen under the ball's center
        let ballCenter = CGPoint(x: currentOrigin.x + (ballSize / 2), y: currentOrigin.y + (ballSize / 2))
        let screen = NSScreen.screens.first(where: { NSPointInRect(ballCenter, $0.frame) }) ?? panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        
        let dockEdge: LiquidBallModel.DockEdge = (ballCenter.x < visibleFrame.midX) ? .left : .right
        LiquidBallModel.shared.dockEdge = dockEdge
        
        // Target physical coordinate anchored right to the monitor border
        let targetX: CGFloat = (dockEdge == .left) ? visibleFrame.minX - 22 : visibleFrame.maxX - ballSize + 22
        let targetY: CGFloat = max(visibleFrame.minY + 12, min(visibleFrame.maxY - ballSize - 12, currentOrigin.y))
        let targetOrigin = CGPoint(x: targetX, y: targetY)
        
        // Smooth frame interpolation animation
        snapTimer?.invalidate()
        let startOrigin = currentOrigin
        let startTime = CACurrentMediaTime()
        let duration: Double = 0.24
        
        snapTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self, let panel = self.ballPanel else {
                    timer.invalidate()
                    return
                }
                
                let elapsed = CACurrentMediaTime() - startTime
                let progress = min(1.0, elapsed / duration)
                let t = 1.0 - pow(1.0 - progress, 3.0)
                
                let curX = startOrigin.x + (targetOrigin.x - startOrigin.x) * CGFloat(t)
                let curY = startOrigin.y + (targetOrigin.y - startOrigin.y) * CGFloat(t)
                panel.setFrameOrigin(CGPoint(x: curX, y: curY))
                
                if progress >= 1.0 {
                    timer.invalidate()
                    panel.setFrameOrigin(targetOrigin)
                    self.saveCurrentPosition()
                    LiquidBallModel.shared.scheduleAutoTuck(afterSeconds: 1.2)
                }
            }
        }
    }
    
    public func updateVisibility() {
        if AppState.shared.floatingBallEnabled {
            show()
        } else {
            hide()
        }
    }
    
    public func show() {
        if ballPanel == nil {
            createPanel()
        }
        
        ballPanel?.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.snapToNearestScreenEdge()
        }
    }
    
    public func hide() {
        snapTimer?.invalidate()
        ballPanel?.orderOut(nil)
    }
    
    public func toggle() {
        if let panel = ballPanel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }
    
    public func toggleMainPopover() {
        if AppState.shared.isDetached {
            FloatingDropWindowController.shared.showFloatingWindow()
        } else {
            StatusBarController.sharedInstance?.showPopover(sender: nil)
        }
    }
    
    private func createPanel() {
        let initialRect = calculateInitialFrame()
        
        let panel = NSPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "SqueezeBar Floating Basket"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.delegate = self
        
        let hostingView = FloatingBallHostingView(rootView: FloatingBallView())
        hostingView.frame = NSRect(x: 0, y: 0, width: ballSize, height: ballSize)
        panel.contentView = hostingView
        
        self.ballPanel = panel
    }
    
    public func windowDidMove(_ notification: Notification) {
        saveCurrentPosition()
    }
    
    private func calculateInitialFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        let savedY = UserDefaults.standard.double(forKey: Keys.ballOriginY)
        let initialY = savedY > 0 ? CGFloat(savedY) : (visibleFrame.midY - (ballSize / 2))
        
        let rawEdge = UserDefaults.standard.string(forKey: Keys.dockEdge) ?? "right"
        let dockEdge = LiquidBallModel.DockEdge(rawValue: rawEdge) ?? .right
        LiquidBallModel.shared.dockEdge = dockEdge
        
        let initialX: CGFloat = (dockEdge == .left) ? visibleFrame.minX - 22 : visibleFrame.maxX - ballSize + 22
        
        return NSRect(x: initialX, y: initialY, width: ballSize, height: ballSize)
    }
}
