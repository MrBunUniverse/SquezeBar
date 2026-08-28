import SwiftUI
import AppKit

// MARK: - Onboarding Window Controller
@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    public static let shared = OnboardingWindowController()
    
    private var window: NSWindow?
    
    public func show(forceReplay: Bool = false) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let onboardingView = OnboardingView(onComplete: { [weak self] in
            self?.closeWindow()
        })
        .environmentObject(AppState.shared)
        
        let hostingView = NSHostingView(rootView: onboardingView)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        win.title = "Welcome to SqueezeBar"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.backgroundColor = NSColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1.0)
        win.contentView = hostingView
        win.delegate = self
        win.center()
        win.isReleasedWhenClosed = false
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func closeWindow() {
        window?.close()
        window = nil
        
        // Open the popover to show user where the app lives in the menu bar
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            StatusBarController.sharedInstance?.showPopover(sender: nil)
        }
    }
    
    public func windowWillClose(_ notification: Notification) {
        self.window = nil
    }
}

// MARK: - Apple Keynote Style Onboarding Presentation View
public struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    let onComplete: () -> Void
    
    @State private var currentStep: Int = 0
    private let totalSteps = 5
    
    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    public var body: some View {
        ZStack {
            // Background Dark Metallic Atmosphere
            Color(red: 0.09, green: 0.09, blue: 0.10)
                .ignoresSafeArea()
            
            // Keynote Subtle Ambient Top Light
            RadialGradient(
                colors: [
                    state.accentColor.opacity(0.12),
                    Color.clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Window Bar Spacer
                HStack {
                    Spacer()
                }
                .frame(height: 32)
                
                // Keynote Slide Deck
                ZStack {
                    switch currentStep {
                    case 0:
                        heroVisionSlide
                            .transition(keynoteTransition)
                    case 1:
                        floatingBasketSlide
                            .transition(keynoteTransition)
                    case 2:
                        universalFormatsSlide
                            .transition(keynoteTransition)
                    case 3:
                        targetSizeAndInspectorSlide
                            .transition(keynoteTransition)
                    default:
                        tailoredSetupSlide
                            .transition(keynoteTransition)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Keynote Navigation Bar
                bottomNavigationBar
            }
        }
        .frame(width: 640, height: 500)
    }
    
    private var keynoteTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)),
            removal: .opacity.combined(with: .scale(scale: 1.04))
        )
    }
    
    // MARK: - Slide 1: Hero & Vision
    private var heroVisionSlide: some View {
        VStack(spacing: 22) {
            Spacer()
            
            // App Icon Container with Specular Ambient Glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                state.accentColor.opacity(0.28),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)
                
                if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: Color.black.opacity(0.5), radius: 14, y: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        )
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(LinearGradient(colors: [state.accentColor, state.accentColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 96, height: 96)
                        
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            VStack(spacing: 8) {
                Text("SqueezeBar")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.white.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Hardware-accelerated media compression. Built for Apple Silicon.")
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
            }
            
            // Clean Spec Badges
            HStack(spacing: 8) {
                keynoteBadge(text: "100% On-Device", icon: "lock.shield.fill")
                keynoteBadge(text: "Apple Silicon Native", icon: "cpu")
                keynoteBadge(text: "Lossless Precision", icon: "sparkles")
            }
            .padding(.top, 4)
            
            Spacer()
        }
        .padding(.horizontal, 36)
    }
    
    // MARK: - Slide 2: Floating Drop Target (Desktop Basket)
    private var floatingBasketSlide: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 6) {
                Text("Floating Drop Target.")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                
                Text("Compress media files from any workspace without navigating to the menu bar.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            // Hero Floating Ball Showcase Card
            VStack(spacing: 16) {
                // Interactive Visual Target Representation
                HStack(spacing: 24) {
                    ZStack {
                        // Ambient Radial Glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        state.accentColor.opacity(0.35),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 8,
                                    endRadius: 46
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        // Glass Outer Ball
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.22), Color(white: 0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 62, height: 62)
                            .overlay(
                                Circle()
                                    .strokeBorder(state.accentColor.opacity(0.65), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
                        
                        // Center Icon
                        Image(systemName: "archivebox.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(state.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Instant Desktop Accessibility")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Stays quietly available across all full-screen workspaces. Drag any image, video, audio, or PDF directly onto the ball to begin compression.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.65))
                            .lineSpacing(2)
                    }
                }
                
                Divider()
                    .opacity(0.12)
                
                // 3 Concise Feature Bullets
                HStack(spacing: 16) {
                    floatingSpecItem(
                        icon: "drop.fill",
                        title: "Liquid Glass",
                        description: "Fluid inertia & bounce"
                    )
                    
                    floatingSpecItem(
                        icon: "arrow.up.and.down.and.arrow.left.and.right",
                        title: "Free Mobility",
                        description: "Draggable anywhere"
                    )
                    
                    floatingSpecItem(
                        icon: "bolt.fill",
                        title: "Live Progress",
                        description: "Direct circumference arc"
                    )
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 28)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func floatingSpecItem(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(state.accentColor)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Slide 3: All Formats (Universal Engine)
    private var universalFormatsSlide: some View {
        VStack(spacing: 18) {
            Spacer()
            
            VStack(spacing: 6) {
                Text("Every Format. Instant Speed.")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                
                Text("Hardware acceleration across photos, 4K videos, audio, and documents.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            // 2x2 Clean Monochrome Media Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                formatFeatureCell(icon: "photo", title: "Images", subtitle: "WebP, AVIF, PNG, JPEG with vImage acceleration")
                formatFeatureCell(icon: "film", title: "Video", subtitle: "HEVC & H.264 encoding via Apple VideoToolbox")
                formatFeatureCell(icon: "waveform", title: "Audio", subtitle: "High-efficiency AAC with custom bitrate control")
                formatFeatureCell(icon: "doc.text.fill", title: "PDF", subtitle: "Vector DPI scaling and metadata compression")
            }
            .padding(.horizontal, 28)
            
            Spacer()
        }
    }
    
    // MARK: - Slide 4: Target Sizes & Inspector
    private var targetSizeAndInspectorSlide: some View {
        VStack(spacing: 18) {
            Spacer()
            
            VStack(spacing: 6) {
                Text("Smart Targets & Clarity.")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                
                Text("Fit file limits instantly and inspect results with pixel precision.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            VStack(spacing: 12) {
                // Interactive Target Limit Preset Pills Visual
                HStack(spacing: 8) {
                    targetPresetVisualPill(label: "Discord 25 MB", isSelected: false)
                    targetPresetVisualPill(label: "Email 10 MB", isSelected: true)
                    targetPresetVisualPill(label: "Slack 50 MB", isSelected: false)
                }
                
                // Before/After Inspector Showcase
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Original")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.50))
                        Text("48.2 MB")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.80))
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(state.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Optimized")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(state.accentColor.opacity(0.70))
                        Text("4.1 MB")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(state.accentColor)
                    }
                    
                    Spacer()
                    
                    Text("-91%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(state.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(state.accentColor.opacity(0.15)))
                        .overlay(Capsule().strokeBorder(state.accentColor.opacity(0.30), lineWidth: 0.5))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
            }
            .padding(.horizontal, 28)
            
            Spacer()
        }
    }
    
    // MARK: - Slide 5: Tailored Preferences & Launch
    private var tailoredSetupSlide: some View {
        VStack(spacing: 16) {
            Spacer()
            
            VStack(spacing: 6) {
                Text("Ready in Your Flow.")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                
                Text("Configure your setup and start compressing.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            VStack(spacing: 10) {
                // Desktop Floating Drop Ball Toggle Card
                setupToggleCard(
                    icon: "archivebox.circle.fill",
                    title: "Desktop Floating Drop Ball",
                    subtitle: "Liquid glass drop basket for instant media compression.",
                    isOn: $state.floatingBallEnabled
                )
                
                // Haptic Feedback Toggle Card
                setupToggleCard(
                    icon: "hand.tap.fill",
                    title: "Trackpad Haptic Feedback",
                    subtitle: "Subtle tactile click sensation on compression completion.",
                    isOn: $state.hapticEnabled
                )
                
                // Full Disk Access Action Card
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "folder.fill.badge.gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Files & Watch Folders")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Grant permission for automatic folder monitoring.")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.60))
                    }
                    
                    Spacer()
                    
                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.035))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5))
                )
            }
            .padding(.horizontal, 28)
            
            Spacer()
        }
    }
    
    // MARK: - Bottom Navigation Bar
    private var bottomNavigationBar: some View {
        HStack {
            // Left Action: Skip or Back
            if currentStep == 0 {
                Button("Skip") {
                    completeOnboarding()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.50))
                .buttonStyle(.plain)
            } else {
                Button("Back") {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        currentStep -= 1
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Keynote Frosted Dot Indicators
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentStep ? state.accentColor : Color.white.opacity(0.20))
                        .frame(width: idx == currentStep ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: currentStep)
                }
            }
            
            Spacer()
            
            // Right Action: Next or Get Started
            if currentStep < totalSteps - 1 {
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        currentStep += 1
                    }
                } label: {
                    Text("Next")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(state.accentColor)
                                .shadow(color: state.accentColor.opacity(0.35), radius: 6, y: 2)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    completeOnboarding()
                } label: {
                    HStack(spacing: 5) {
                        Text("Get Started")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(state.contrastTextColor)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(state.accentColor)
                            .shadow(color: state.accentColor.opacity(0.40), radius: 8, y: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(
            Color.black.opacity(0.25)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }
    
    // MARK: - Reusable Presentation Components
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding_v1")
        onComplete()
    }
    
    @ViewBuilder
    private func keynoteBadge(text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .bold))
            Text(text)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
        }
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, 10)
        .padding(.vertical, 4.5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        )
    }
    
    @ViewBuilder
    private func formatFeatureCell(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.90))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.60))
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5))
        )
    }
    
    @ViewBuilder
    private func targetPresetVisualPill(label: String, isSelected: Bool) -> some View {
        Text(label)
            .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
            .foregroundColor(isSelected ? state.contrastTextColor : .white.opacity(0.80))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? state.accentColor : Color.white.opacity(0.06))
                    .overlay(Capsule().strokeBorder(isSelected ? state.accentColor.opacity(0.6) : Color.white.opacity(0.10), lineWidth: 0.5))
            )
    }
    
    @ViewBuilder
    private func setupToggleCard(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.90))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.60))
                }
                
                Spacer()
                
                LiquidGlassSwitch(isOn: isOn)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.035))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
