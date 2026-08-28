import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct FloatingBallView: View {
    @ObservedObject private var state = AppState.shared
    @ObservedObject private var liquidModel = LiquidBallModel.shared
    
    @State private var isHovered: Bool = false
    @State private var isDropTargeted: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if liquidModel.isTucked && !isHovered && !isDropTargeted && !state.isProcessing && !liquidModel.isMoving {
                // MARK: - Crisp, Luminous Bezel Edge Tab
                bezelEdgeTab
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.90)),
                        removal: .opacity.combined(with: .scale(scale: 1.10))
                    ))
            } else {
                // MARK: - Full Liquid Glass Sphere
                fullLiquidSphere
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.90)),
                        removal: .opacity.combined(with: .scale(scale: 1.10))
                    ))
            }
        }
        .frame(width: 100, height: 100, alignment: .center)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.30, dampingFraction: 0.74), value: liquidModel.isTucked)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isHovered)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isDropTargeted)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: state.isProcessing)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovered = hovering
            }
            if hovering {
                liquidModel.revealFromTuck()
            } else {
                liquidModel.scheduleAutoTuck(afterSeconds: 1.8)
            }
        }
        // File Drop Support (Desktop Basket)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            handleDroppedProviders(providers)
        }
        .onChange(of: isDropTargeted) { _, targeted in
            if targeted {
                liquidModel.revealFromTuck()
            }
        }
        .contextMenu {
            Button("Open SqueezeBar") {
                FloatingBallController.shared.toggleMainPopover()
            }
            
            Divider()
            
            Button("Hide Floating Drop Ball") {
                withAnimation {
                    AppState.shared.floatingBallEnabled = false
                }
            }
        }
    }
    
    // MARK: - Crisp Luminous Edge Tab (Tucked Idle Mode)
    private var bezelEdgeTab: some View {
        let isRight = (liquidModel.dockEdge == .right)
        
        return ZStack {
            // High-Contrast Dark Glass Base
            UnevenRoundedRectangle(
                topLeadingRadius: isRight ? 15 : 0,
                bottomLeadingRadius: isRight ? 15 : 0,
                bottomTrailingRadius: isRight ? 0 : 15,
                topTrailingRadius: isRight ? 0 : 15
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color(white: 0.22).opacity(0.95),
                        Color(white: 0.12).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: isRight ? 15 : 0,
                    bottomLeadingRadius: isRight ? 15 : 0,
                    bottomTrailingRadius: isRight ? 0 : 15,
                    topTrailingRadius: isRight ? 0 : 15
                )
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.50),
                            state.accentColor.opacity(0.40)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
            )
            .shadow(color: Color.black.opacity(0.45), radius: 8, y: 3)
            
            // Luminous Theme Emblem / Grip Indicator
            HStack(spacing: 0) {
                if isRight {
                    Image(systemName: "archivebox.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(state.accentColor)
                        .padding(.leading, 3)
                } else {
                    Image(systemName: "archivebox.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(state.accentColor)
                        .padding(.trailing, 3)
                }
            }
        }
        .frame(width: 28, height: 48)
        .offset(x: isRight ? 24 : -24)
        .opacity(0.85)
    }
    
    // MARK: - Full Liquid Glass Sphere (Revealed Active Mode)
    private var fullLiquidSphere: some View {
        return ZStack {
            // Base Circular Glass Card
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.22).opacity(isDropTargeted ? 0.98 : 0.90),
                            Color(white: 0.10).opacity(isDropTargeted ? 0.98 : 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(isHovered || isDropTargeted || liquidModel.isMoving ? 0.50 : 0.30), radius: isDropTargeted ? 14 : 9, y: 4)
            
            // Theme Accent Ambient Underglow
            if isDropTargeted || state.isProcessing || liquidModel.isMoving || isHovered {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                state.accentColor.opacity(isDropTargeted ? 0.45 : (liquidModel.isMoving ? 0.35 : 0.25)),
                                state.accentColor.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 34
                        )
                    )
            }
            
            // Specular Outer Rim Stroke
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            isDropTargeted ? state.accentColor : (isHovered || liquidModel.isMoving ? Color.white.opacity(0.65) : Color.white.opacity(0.30)),
                            isDropTargeted ? state.accentColor.opacity(0.50) : Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isDropTargeted ? 2.0 : 1.0
                )
            
            // Circular Progress Arc while processing
            if state.isProcessing {
                Circle()
                    .trim(from: 0.0, to: max(0.05, CGFloat(min(1.0, state.overallProgress))))
                    .stroke(
                        state.accentColor,
                        style: StrokeStyle(lineWidth: 3.0, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(2)
                    .animation(.linear(duration: 0.2), value: state.overallProgress)
            }
            
            // Center Dynamic Content / Icon
            centerContent
        }
        .frame(width: 56, height: 56)
        // Liquid Glass Squash & Stretch Physics
        .scaleEffect(
            x: liquidModel.scaleX * (isDropTargeted ? 1.14 : (isHovered ? 1.05 : 1.0)),
            y: liquidModel.scaleY * (isDropTargeted ? 1.14 : (isHovered ? 1.05 : 1.0))
        )
        .rotationEffect(.degrees(liquidModel.rotationAngle))
        .opacity(1.0)
    }
    
    @ViewBuilder
    private var centerContent: some View {
        if state.showSuccessBadge {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.green)
                .transition(.scale.combined(with: .opacity))
        } else if state.isProcessing {
            VStack(spacing: 1) {
                Text("\(Int(state.overallProgress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(state.accentColor)
                
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(state.accentColor.opacity(0.85))
            }
        } else if isDropTargeted {
            VStack(spacing: 2) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(state.accentColor)
                Text("Drop")
                    .font(.system(size: 8, weight: .bold, design: .serif))
                    .foregroundColor(.white)
            }
        } else {
            // High-Visibility SqueezeBar Emblem
            Image(systemName: "archivebox.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(state.accentColor)
                .shadow(color: state.accentColor.opacity(0.40), radius: 4)
        }
    }
    
    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let url = item as? URL {
                    urls.append(url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            
            if self.state.hapticEnabled {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            
            Task {
                await MediaCompressionEngine.shared.processDroppedURLs(urls)
            }
        }
        
        return true
    }
}
