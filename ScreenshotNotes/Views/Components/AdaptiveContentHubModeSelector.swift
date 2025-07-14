//
//  AdaptiveContentHubModeSelector.swift
//  ScreenshotNotes
//
//  Sprint 8.2.1: Beautiful Mode Switching UI with Liquid Glass Animations
//  Created by Assistant on 7/14/25.
//

import SwiftUI

/// Beautiful mode selector for Adaptive Content Hub with Liquid Glass materials
/// Provides smooth transitions between Gallery, Constellation, Exploration, and Search modes
struct AdaptiveContentHubModeSelector: View {
    @StateObject private var modeManager = InterfaceModeManager.shared
    @StateObject private var interfaceSettings = InterfaceSettings()
    @StateObject private var liquidGlassMaterial = LiquidGlassMaterial()
    
    // Animation state
    @State private var selectedModeOffset: CGFloat = 0
    @State private var isAnimating = false
    @Namespace private var modeAnimation
    
    // Haptic feedback
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        if interfaceSettings.isEnhancedInterfaceEnabled {
            VStack(spacing: 0) {
                // Mode selector tabs
                HStack(spacing: 0) {
                    ForEach(modeManager.getAvailableModes()) { mode in
                        ModeTabButton(
                            mode: mode,
                            isSelected: mode == modeManager.currentMode,
                            isTransitioning: modeManager.isTransitioning,
                            transitionProgress: modeManager.transitionProgress
                        ) {
                            selectMode(mode)
                        }
                    }
                }
                .background(
                    // Liquid Glass background with selection indicator
                    ZStack {
                        // Base glass material
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.ultraThinMaterial, lineWidth: 0.5)
                            )
                        
                        // Selection indicator
                        HStack {
                            ForEach(modeManager.getAvailableModes()) { mode in
                                if mode == modeManager.currentMode {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(mode.accentColor.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(.regularMaterial)
                                        )
                                        .matchedGeometryEffect(id: "modeSelection", in: modeAnimation)
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale.combined(with: .opacity)
                                        ))
                                } else {
                                    Color.clear
                                }
                            }
                        }
                        .padding(4)
                    }
                )
                .frame(height: 40)
                .padding(.horizontal, 16)
                
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2), value: modeManager.currentMode)
            .onChange(of: modeManager.currentMode) { oldMode, newMode in
                // Provide haptic feedback for mode changes
                if oldMode != newMode {
                    impactFeedback.impactOccurred()
                }
            }
        }
    }
    
    private func selectMode(_ mode: InterfaceMode) {
        guard mode != modeManager.currentMode else { return }
        
        // Prepare haptic feedback
        selectionFeedback.prepare()
        
        // Trigger selection feedback
        selectionFeedback.selectionChanged()
        
        // Switch mode with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)) {
            modeManager.switchToMode(mode, trigger: .userTap)
        }
    }
}

/// Individual mode tab button with Liquid Glass styling
private struct ModeTabButton: View {
    let mode: InterfaceMode
    let isSelected: Bool
    let isTransitioning: Bool
    let transitionProgress: Double
    let action: () -> Void
    
    @StateObject private var liquidGlassMaterial = LiquidGlassMaterial()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Mode icon with selection state
                Image(systemName: mode.icon)
                    .font(.system(size: isSelected ? 18 : 15, weight: .medium))
                    .foregroundColor(isSelected ? mode.accentColor : .secondary)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                
                // Mode label
                Text(mode.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? mode.accentColor : .secondary)
                    .opacity(isSelected ? 1.0 : 0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(ModeButtonStyle(
            isSelected: isSelected,
            accentColor: mode.accentColor
        ))
        .accessibilityLabel("\(mode.displayName) mode")
        .accessibilityHint(mode.description)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Custom button style for mode selection
private struct ModeButtonStyle: ButtonStyle {
    let isSelected: Bool
    let accentColor: Color
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        Color.clear
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Mode Transition Overlay

/// Beautiful transition overlay during mode switches
struct ModeTransitionOverlay: View {
    let fromMode: InterfaceMode
    let toMode: InterfaceMode
    let progress: Double
    
    @StateObject private var liquidGlassMaterial = LiquidGlassMaterial()
    
    var body: some View {
        ZStack {
            // Gradient transition background
            LinearGradient(
                colors: [
                    fromMode.accentColor.opacity(0.1 * (1 - progress)),
                    toMode.accentColor.opacity(0.1 * progress)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .overlay(
                .ultraThinMaterial
            )
            
            // Transition progress indicator
            VStack(spacing: 16) {
                // Icon transition
                HStack(spacing: 20) {
                    Image(systemName: fromMode.icon)
                        .font(.title)
                        .foregroundColor(fromMode.accentColor)
                        .opacity(1 - progress)
                        .scaleEffect(1 - progress * 0.5)
                    
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .opacity(progress)
                    
                    Image(systemName: toMode.icon)
                        .font(.title)
                        .foregroundColor(toMode.accentColor)
                        .opacity(progress)
                        .scaleEffect(0.5 + progress * 0.5)
                }
                
                // Mode names
                Text("Switching to \(toMode.displayName)")
                    .font(.headline)
                    .foregroundColor(toMode.accentColor)
                    .opacity(progress)
            }
        }
        .opacity(progress > 0.1 ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: progress)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Mode Selector") {
    VStack(spacing: 40) {
        AdaptiveContentHubModeSelector()
        
        Spacer()
    }
    .padding()
    .background(.regularMaterial)
    .environmentObject(InterfaceSettings())
}

#Preview("Mode Transition") {
    ModeTransitionOverlay(
        fromMode: .gallery,
        toMode: .constellation,
        progress: 0.7
    )
}
#endif