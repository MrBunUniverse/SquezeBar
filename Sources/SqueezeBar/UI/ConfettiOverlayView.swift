import SwiftUI
import AppKit

// MARK: - Confetti Particle Model
public struct ConfettiParticle: Identifiable {
    public let id = UUID()
    public var x: CGFloat
    public var y: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var rotation: Double
    public var rotationSpeed: Double
    public var color: Color
    public var scale: CGFloat
    public var opacity: Double
    public var shapeType: Int // 0: rectangle, 1: circle, 2: star
}

// MARK: - Confetti Cannon Controller (Multi-Screen Overlay Cannon)
@MainActor
public final class ConfettiCannonController {
    public static let shared = ConfettiCannonController()
    
    private var overlayWindows: [NSWindow] = []
    
    private init() {}
    
    public func explode() {
        // Dismiss previous explosion windows
        dismiss()
        
        // Play triumphant glass sparkle sound
        NSSound(named: "Hero")?.play()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        
        let screens = NSScreen.screens
        for screen in screens {
            let win = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            win.level = .floating
            win.ignoresMouseEvents = true
            win.hasShadow = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let hostingView = NSHostingView(rootView: FullScreenConfettiView(screenFrame: screen.frame) { [weak self] in
                self?.dismiss()
            })
            win.contentView = hostingView
            win.makeKeyAndOrderFront(nil)
            overlayWindows.append(win)
        }
    }
    
    public func dismiss() {
        for win in overlayWindows {
            win.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}

// MARK: - Full Screen Physics Confetti Canvas View
public struct FullScreenConfettiView: View {
    let screenFrame: CGRect
    let onFinished: () -> Void
    
    @State private var particles: [ConfettiParticle] = []
    @State private var timer: Timer? = nil
    
    private let colors: [Color] = [
        Color(red: 1.0, green: 0.45, blue: 0.1),  // Orange
        Color(red: 1.0, green: 0.8, blue: 0.15), // Gold
        Color(red: 0.2, green: 0.6, blue: 1.0),  // Vivid Blue
        Color(red: 0.95, green: 0.25, blue: 0.5),// Magenta Pink
        Color(red: 0.3, green: 0.85, blue: 0.4), // Emerald
        Color(red: 0.65, green: 0.35, blue: 0.95),// Purple
        Color.white
    ]
    
    public var body: some View {
        Canvas { context, size in
            for p in particles {
                var c = context
                c.opacity = p.opacity
                c.translateBy(x: p.x, y: p.y)
                c.rotate(by: Angle(degrees: p.rotation))
                c.scaleBy(x: p.scale, y: p.scale)
                
                let rect = CGRect(x: -6, y: -4, width: 12, height: 8)
                if p.shapeType == 0 {
                    c.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(p.color))
                } else if p.shapeType == 1 {
                    c.fill(Circle().path(in: CGRect(x: -5, y: -5, width: 10, height: 10)), with: .color(p.color))
                } else {
                    // Small ribbon / star
                    let starRect = CGRect(x: -7, y: -2, width: 14, height: 4)
                    c.fill(Capsule().path(in: starRect), with: .color(p.color))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            spawnParticles()
            startPhysics()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func spawnParticles() {
        let originX = screenFrame.width / 2.0
        let originY = screenFrame.height * 0.45
        
        var generated: [ConfettiParticle] = []
        let count = 200
        
        for _ in 0..<count {
            let angle = Double.random(in: -Double.pi * 0.98 ... -Double.pi * 0.02)
            let speed = Double.random(in: 14.0...36.0)
            let color = colors.randomElement() ?? .orange
            let shape = Int.random(in: 0...2)
            
            let particle = ConfettiParticle(
                x: originX + CGFloat.random(in: -100...100),
                y: originY + CGFloat.random(in: -50...50),
                vx: CGFloat(cos(angle) * speed * Double.random(in: 0.8...1.3)),
                vy: CGFloat(sin(angle) * speed),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -16...16),
                color: color,
                scale: CGFloat.random(in: 0.8...1.4),
                opacity: 1.0,
                shapeType: shape
            )
            generated.append(particle)
        }
        particles = generated
    }
    
    private func startPhysics() {
        var ticks = 0
        let maxTicks = 160 // ~2.6 seconds at 60fps
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { t in
            ticks += 1
            
            for i in 0..<particles.count {
                particles[i].x += particles[i].vx
                particles[i].y += particles[i].vy
                particles[i].vy += 0.58 // Gravity
                particles[i].vx *= 0.985 // Air drag
                particles[i].rotation += particles[i].rotationSpeed
                
                if ticks > 60 {
                    particles[i].opacity = max(0.0, particles[i].opacity - 0.016)
                }
            }
            
            if ticks >= maxTicks {
                t.invalidate()
                onFinished()
            }
        }
    }
}
