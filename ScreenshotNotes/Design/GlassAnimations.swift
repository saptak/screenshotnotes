//
//  GlassAnimations.swift
//  ScreenshotNotes
//
//  Sprint 5.4.1: Bottom Glass Search Bar Implementation
//  Created by Assistant on 7/6/25.
//

import SwiftUI
import UIKit

/// Physics-based Glass animations following Apple's design principles
/// Provides natural, delightful interactions for Glass components
struct GlassAnimations {
    
    // MARK: - Animation Timing Functions
    
    /// Custom easing curves for Glass interactions
    enum GlassEasing {
        case natural
        case snappy
        case fluid
        case conversational
        
        var timingFunction: Animation {
            switch self {
            case .natural:
                return .interpolatingSpring(stiffness: 300, damping: 30)
            case .snappy:
                return .interpolatingSpring(stiffness: 400, damping: 25)
            case .fluid:
                return .interpolatingSpring(stiffness: 200, damping: 35)
            case .conversational:
                return .interpolatingSpring(stiffness: 250, damping: 28)
            }
        }
    }
    
    // MARK: - Microphone Button Animations
    
    /// Microphone button state animations
    static func microphoneButtonState(
        to state: GlassMicrophoneButtonState,
        completion: @escaping () -> Void = {}
    ) -> Animation {
        let baseAnimation: Animation
        
        switch state {
        case .ready:
            baseAnimation = GlassEasing.natural.timingFunction
        case .listening:
            baseAnimation = GlassEasing.snappy.timingFunction
        case .processing:
            baseAnimation = GlassEasing.fluid.timingFunction
        case .results:
            baseAnimation = GlassEasing.conversational.timingFunction
        case .error:
            baseAnimation = GlassEasing.snappy.timingFunction
        case .conversation:
            baseAnimation = GlassEasing.conversational.timingFunction
        }
        
        return baseAnimation
    }
    
    /// Microphone button breathing effect for ready state
    static func microphoneBreathing() -> Animation {
        .easeInOut(duration: 2.0)
        .repeatForever(autoreverses: true)
    }
    
    /// Microphone button pulse for listening state
    static func microphonePulse(intensity: Double) -> Animation {
        let duration = max(0.3, 1.0 - intensity * 0.7) // Faster pulse with higher intensity
        return .easeInOut(duration: duration)
            .repeatForever(autoreverses: true)
    }
    
    /// Microphone button ripple effect
    static func microphoneRipple() -> Animation {
        .easeOut(duration: 0.6)
    }
    
    // MARK: - Search Bar Animations
    
    /// Search bar expand animation
    static func searchBarExpand() -> Animation {
        .interpolatingSpring(stiffness: 280, damping: 25)
    }
    
    /// Search bar collapse animation
    static func searchBarCollapse() -> Animation {
        .interpolatingSpring(stiffness: 320, damping: 30)
    }
    
    /// Search bar material intensity change
    static func searchBarMaterialChange() -> Animation {
        .easeInOut(duration: 0.4)
    }
    
    /// Search bar typing feedback
    static func searchBarTyping() -> Animation {
        .interpolatingSpring(stiffness: 400, damping: 20)
    }
    
    // MARK: - Conversational Animations
    
    /// Conversation turn transition
    static func conversationTurn() -> Animation {
        .interpolatingSpring(stiffness: 250, damping: 28)
    }
    
    /// Processing indicator animation
    static func processingIndicator() -> Animation {
        .linear(duration: 1.0)
        .repeatForever(autoreverses: false)
    }
    
    /// Results appearance animation
    static func resultsAppear() -> Animation {
        .interpolatingSpring(stiffness: 220, damping: 30)
    }
    
    /// Error state animation
    static func errorState() -> Animation {
        .interpolatingSpring(stiffness: 400, damping: 15)
    }
    
    // MARK: - Glass Material Animations
    
    /// Glass material opacity animation
    static func materialOpacity() -> Animation {
        .easeInOut(duration: 0.3)
    }
    
    /// Glass vibrancy strength animation
    static func vibrancyStrength() -> Animation {
        .easeInOut(duration: 0.5)
    }
    
    /// Glass blur radius animation
    static func blurRadius() -> Animation {
        .easeInOut(duration: 0.4)
    }
    
    // MARK: - Haptic Coordination
    
    /// Coordinates haptic feedback with Glass animations
    static func coordinateHaptic(
        with animation: Animation,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle,
        delay: TimeInterval = 0
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let generator = UIImpactFeedbackGenerator(style: hapticStyle)
            generator.impactOccurred()
        }
    }
    
    /// Complex haptic pattern for conversation states
    static func conversationHapticPattern(for state: GlassMicrophoneButtonState) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        
        switch state {
        case .ready:
            // No haptic for energy conservation
            break
        case .listening:
            generator.impactOccurred(intensity: 0.7)
        case .processing:
            // Gentle pulse pattern
            generator.impactOccurred(intensity: 0.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                generator.impactOccurred(intensity: 0.3)
            }
        case .results:
            // Success pattern
            generator.impactOccurred(intensity: 0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                generator.impactOccurred(intensity: 0.5)
            }
        case .error:
            // Error pattern
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)
        case .conversation:
            // Conversation feedback
            generator.impactOccurred(intensity: 0.6)
        }
    }
    
    // MARK: - Accessibility Adaptations
    
    /// Returns accessibility-adapted animation
    static func accessibilityAdapted(_ animation: Animation) -> Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .linear(duration: 0.1) // Minimal animation
        }
        
        if UIAccessibility.prefersCrossFadeTransitions {
            return .easeInOut(duration: 0.3) // Gentle cross-fade
        }
        
        return animation
    }
    
    /// Creates a reduced motion version of complex animations
    static func reducedMotion(duration: TimeInterval = 0.2) -> Animation {
        .easeInOut(duration: duration)
    }
}

// MARK: - Microphone Button States

/// Glass microphone button states with visual and haptic coordination
enum GlassMicrophoneButtonState: CaseIterable {
    case ready
    case listening
    case processing
    case results
    case error
    case conversation
    
    /// Display properties for each state
    var displayProperties: (icon: String, color: Color, scale: CGFloat, opacity: Double) {
        switch self {
        case .ready:
            return ("mic.fill", .blue, 1.0, 0.8)
        case .listening:
            return ("mic.fill", .red, 1.1, 1.0)
        case .processing:
            return ("waveform", .purple, 1.05, 0.9)
        case .results:
            return ("checkmark.circle.fill", .green, 1.0, 1.0)
        case .error:
            return ("exclamationmark.triangle.fill", .red, 1.0, 1.0)
        case .conversation:
            return ("message.fill", .blue, 1.0, 0.9)
        }
    }
    
    /// Glass material for each state
    var glassMaterial: GlassDesignSystem.GlassMaterial {
        switch self {
        case .ready: return .ultraThin
        case .listening: return .regular
        case .processing: return .thick
        case .results: return .ultraThin
        case .error: return .regular
        case .conversation: return .regular
        }
    }
    
    /// Animation duration for state transition
    var transitionDuration: TimeInterval {
        switch self {
        case .ready: return 0.3
        case .listening: return 0.25
        case .processing: return 0.4
        case .results: return 0.35
        case .error: return 0.2
        case .conversation: return 0.3
        }
    }
}

// MARK: - Animation View Modifiers

/// Glass scale animation modifier
struct GlassScaleAnimationModifier: ViewModifier {
    let isActive: Bool
    let scale: CGFloat
    let animation: Animation
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? scale : 1.0)
            .animation(animation, value: isActive)
    }
}

/// Glass opacity animation modifier
struct GlassOpacityAnimationModifier: ViewModifier {
    let isVisible: Bool
    let animation: Animation
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(animation, value: isVisible)
    }
}

/// Glass rotation animation modifier for processing states
struct GlassRotationAnimationModifier: ViewModifier {
    let isActive: Bool
    let speed: Double
    
    @State private var rotation: Double = 0
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                if isActive {
                    startRotation()
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    startRotation()
                } else {
                    stopRotation()
                }
            }
    }
    
    private func startRotation() {
        withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
    
    private func stopRotation() {
        withAnimation(.easeOut(duration: 0.3)) {
            rotation = 0
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies Glass scale animation
    func glassScale(
        isActive: Bool,
        scale: CGFloat = 1.05,
        animation: Animation = GlassAnimations.GlassEasing.natural.timingFunction
    ) -> some View {
        modifier(GlassScaleAnimationModifier(
            isActive: isActive,
            scale: scale,
            animation: animation
        ))
    }
    
    /// Applies Glass opacity animation
    func glassOpacity(
        isVisible: Bool,
        animation: Animation = GlassAnimations.GlassEasing.natural.timingFunction
    ) -> some View {
        modifier(GlassOpacityAnimationModifier(
            isVisible: isVisible,
            animation: animation
        ))
    }
    
    /// Applies Glass rotation animation for processing states
    func glassRotation(
        isActive: Bool,
        speed: Double = 2.0
    ) -> some View {
        modifier(GlassRotationAnimationModifier(
            isActive: isActive,
            speed: speed
        ))
    }
}

// MARK: - Preview Support

#if DEBUG
#Preview("Glass Animations") {
    struct AnimationPreview: View {
        @State private var microphoneState: GlassMicrophoneButtonState = .ready
        @State private var isSearchActive = false
        
        var body: some View {
            VStack(spacing: 30) {
                Text("Glass Animations")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Microphone button states
                VStack(spacing: 20) {
                    Text("Microphone States")
                        .font(.headline)
                    
                    HStack(spacing: 15) {
                        ForEach(GlassMicrophoneButtonState.allCases, id: \.self) { state in
                            Button(action: {
                                withAnimation(GlassAnimations.microphoneButtonState(to: state)) {
                                    microphoneState = state
                                    GlassAnimations.conversationHapticPattern(for: state)
                                }
                            }) {
                                let props = state.displayProperties
                                Circle()
                                    .frame(width: 50, height: 50)
                                    .glassBackground(
                                        material: state.glassMaterial,
                                        cornerRadius: 25
                                    )
                                    .overlay {
                                        Image(systemName: props.icon)
                                            .foregroundStyle(props.color)
                                            .font(.system(size: 20, weight: .medium))
                                    }
                                    .scaleEffect(microphoneState == state ? 1.1 : 1.0)
                                    .glassOpacity(isVisible: microphoneState == state ? true : props.opacity < 1.0)
                            }
                        }
                    }
                }
                
                // Search bar animation
                VStack(spacing: 15) {
                    Text("Search Bar States")
                        .font(.headline)
                    
                    Button(action: {
                        withAnimation(GlassAnimations.searchBarExpand()) {
                            isSearchActive.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search with Glass...")
                            Spacer()
                            Image(systemName: "mic.fill")
                                .foregroundStyle(.blue)
                        }
                        .padding()
                        .glassBackground(cornerRadius: 16)
                        .scaleEffect(isSearchActive ? 1.02 : 1.0)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .background {
                LinearGradient(
                    colors: [.cyan.opacity(0.3), .blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
    
    return AnimationPreview()
}
#endif
