
//
//  GlassConversationalMicrophoneButton.swift
//  ScreenshotNotes
//
//  Sprint 5.4.2: Glass Conversational Experience
//  Created by Assistant on 7/6/25.
//

import SwiftUI

/// A premium, state-aware microphone button for the Glass conversational interface.
/// This component encapsulates the complex visual effects, animations, and haptics
/// required for a polished, intuitive voice search experience.
struct GlassConversationalMicrophoneButton: View {
    @Binding var state: GlassMicrophoneButtonState
    let onTap: () -> Void
    
    // Environment properties for accessibility and animation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    
    var body: some View {
        Button(action: {
            // Trigger the tap action and coordinated haptic feedback
            onTap()
            GlassAnimations.conversationHapticPattern(for: state)
        }) {
            ZStack {
                // Base circle with Glass material
                Circle()
                    .glassBackground(
                        material: state.glassMaterial,
                        cornerRadius: GlassDesignSystem.GlassLayout.microphoneButtonSize / 2
                    )
                
                // Animated sound wave/ripple effect for listening state
                if state == .listening {
                    Circle()
                        .stroke(state.displayProperties.color.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isBreathing ? 1.8 : 1.0)
                        .opacity(isBreathing ? 0.0 : 1.0)
                        .animation(
                            reduceMotion ? .none : GlassAnimations.microphoneRipple().repeatForever(autoreverses: false),
                            value: isBreathing
                        )
                }
                
                // Processing indicator (rotating)
                if state == .processing {
                    Image(systemName: state.displayProperties.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(state.displayProperties.color)
                        .glassRotation(isActive: true, speed: 1.0)
                } else {
                    // Standard icon with scale and opacity animations
                    Image(systemName: state.displayProperties.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(state.displayProperties.color)
                        .opacity(state.displayProperties.opacity)
                        .scaleEffect(state.displayProperties.scale)
                        .animation(
                            reduceMotion ? .none : GlassAnimations.microphoneButtonState(to: state),
                            value: state
                        )
                }
            }
        }
        .frame(
            width: GlassDesignSystem.GlassLayout.microphoneButtonSize,
            height: GlassDesignSystem.GlassLayout.microphoneButtonSize
        )
        .glassAccessibility(
            label: GlassAccessibility.microphoneButtonAccessibilityLabel(for: state),
            traits: .button,
            customActions: GlassAccessibility.alternativeInteraction(for: .microphoneButton)
        )
        .onAppear {
            // Start breathing animation for ready/listening states
            if state == .ready || state == .listening {
                isBreathing = true
            }
        }
        .onChange(of: state) { _, newState in
            // Manage breathing animation based on state changes
            withAnimation(GlassAnimations.microphoneBreathing()) {
                if newState == .listening {
                    isBreathing = true
                } else {
                    isBreathing = false
                }
            }
        }
    }
}

#if DEBUG
#Preview("Glass Conversational Microphone Button") {
    struct PreviewWrapper: View {
        @State private var state: GlassMicrophoneButtonState = .ready
        
        var body: some View {
            VStack(spacing: 30) {
                Text("Microphone States")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                GlassConversationalMicrophoneButton(state: $state, onTap: {
                    // Cycle through states for preview
                    let allStates = GlassMicrophoneButtonState.allCases
                    if let currentIndex = allStates.firstIndex(of: state) {
                        let nextIndex = (currentIndex + 1) % allStates.count
                        state = allStates[nextIndex]
                    }
                })
                
                Picker("State", selection: $state) {
                    ForEach(GlassMicrophoneButtonState.allCases, id: \.self) { state in
                        Text(String(describing: state)).tag(state)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                LinearGradient(
                    colors: [.cyan.opacity(0.2), .blue.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
    
    return PreviewWrapper()
}
#endif
