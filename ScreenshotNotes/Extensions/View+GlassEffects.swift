//
//  View+GlassEffects.swift
//  ScreenshotNotes
//
//  Sprint 5.4.1: Bottom Glass Search Bar Implementation
//  Created by Assistant on 7/6/25.
//

import SwiftUI
import UIKit

/// SwiftUI View extensions for Glass effects and interactions
/// Provides convenient modifiers for applying Glass design system
extension View {
    
    // MARK: - Glass Material Effects
    
    /// Applies premium Glass background with automatic accessibility adaptation
    func glassEffect(
        material: GlassDesignSystem.GlassMaterial = .regular,
        cornerRadius: CGFloat = 12,
        shadow: Bool = true,
        vibrancy: Double = 1.0
    ) -> some View {
        self
            .background {
                GlassEffectBackground(
                    material: material,
                    cornerRadius: cornerRadius,
                    shadow: shadow,
                    vibrancy: vibrancy
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    /// Applies Glass vibrancy effect
    func glassVibrancy(
        strength: Double = 1.0
    ) -> some View {
        modifier(GlassVibrancyModifier(
            strength: strength
        ))
    }
    
    /// Applies Glass overlay effect for floating elements
    func glassOverlay(
        material: GlassDesignSystem.GlassMaterial = .ultraThin,
        cornerRadius: CGFloat = 8
    ) -> some View {
        self
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material.material)
                    .allowsHitTesting(false)
            }
    }
    
    /// Applies Glass border effect
    func glassBorder(
        color: Color = .primary,
        width: CGFloat = 0.5,
        opacity: Double = 0.3,
        cornerRadius: CGFloat = 12
    ) -> some View {
        self
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(opacity), lineWidth: width)
            }
    }
    
    // MARK: - Glass State Effects
    
    /// Applies Glass press effect with haptic feedback
    func glassPressEffect(
        isPressed: Bool,
        scale: CGFloat = 0.97,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) -> some View {
        self
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(GlassAnimations.GlassEasing.snappy.timingFunction, value: isPressed)
            .onChange(of: isPressed) { _, newValue in
                if newValue {
                    GlassAccessibility.accessibleHapticFeedback(for: .microphoneActivated, intensity: 0.6)
                }
            }
    }
    
    /// Applies Glass hover effect (for iPad pointer interactions)
    func glassHoverEffect(
        isHovered: Bool,
        scale: CGFloat = 1.02,
        shadowIntensity: Double = 1.5
    ) -> some View {
        self
            .scaleEffect(isHovered ? scale : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.15 * shadowIntensity : 0.08),
                radius: isHovered ? 12 : 6,
                x: 0,
                y: isHovered ? 6 : 3
            )
            .animation(GlassAnimations.GlassEasing.fluid.timingFunction, value: isHovered)
    }
    
    /// Applies Glass focus effect for accessibility
    func glassFocusEffect(
        isFocused: Bool,
        color: Color = .accentColor
    ) -> some View {
        self
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(color, lineWidth: 3)
                        .animation(GlassAnimations.GlassEasing.natural.timingFunction, value: isFocused)
                }
            }
    }
    
    // MARK: - Glass Animation Effects
    
    /// Applies Glass breathing animation for idle states
    func glassBreathing(
        isActive: Bool,
        intensity: Double = 0.1,
        duration: TimeInterval = 2.0
    ) -> some View {
        self
            .opacity(isActive ? 1.0 - intensity : 1.0)
            .animation(
                isActive ? 
                    .easeInOut(duration: duration).repeatForever(autoreverses: true) :
                    .easeOut(duration: 0.3),
                value: isActive
            )
    }
    
    /// Applies Glass pulse animation for active states
    func glassPulse(
        isActive: Bool,
        color: Color = .blue,
        intensity: Double = 0.3,
        speed: Double = 1.0
    ) -> some View {
        self
            .overlay {
                if isActive {
                    Circle()
                        .stroke(color.opacity(intensity), lineWidth: 2)
                        .scaleEffect(isActive ? 1.5 : 1.0)
                        .opacity(isActive ? 0.0 : 1.0)
                        .animation(
                            .easeOut(duration: 1.0 / speed).repeatForever(autoreverses: false),
                            value: isActive
                        )
                }
            }
    }
    
    /// Applies Glass shimmer effect for loading states
    func glassShimmer(
        isActive: Bool,
        duration: TimeInterval = 1.5
    ) -> some View {
        self
            .overlay {
                if isActive {
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(45))
                    .offset(x: isActive ? 200 : -200)
                    .animation(
                        .linear(duration: duration).repeatForever(autoreverses: false),
                        value: isActive
                    )
                    .allowsHitTesting(false)
                }
            }
            .clipped()
    }
    
    // MARK: - Glass Layout Effects
    
    /// Applies Glass floating effect with proper spacing
    func glassFloating(
        elevation: GlassElevation = .medium
    ) -> some View {
        let config = elevation.configuration
        
        return self
            .shadow(
                color: .black.opacity(config.shadowOpacity),
                radius: config.shadowRadius,
                x: 0,
                y: config.shadowY
            )
            .offset(y: -config.offsetY)
    }
    
    /// Applies Glass container styling with proper spacing
    func glassContainer(
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        material: GlassDesignSystem.GlassMaterial = .regular
    ) -> some View {
        self
            .padding(padding)
            .glassEffect(material: material)
    }
    
    // MARK: - Glass Interaction Effects
    
    /// Applies Glass tap animation with proper feedback
    func glassTapAnimation() -> some View {
        self
            .onTapGesture {
                // Tap is handled by parent, just provide feedback
                GlassAccessibility.accessibleHapticFeedback(for: .microphoneActivated)
            }
    }
    
    /// Applies Glass long press effect
    func glassLongPress(
        minimumDuration: TimeInterval = 0.5,
        onLongPress: @escaping () -> Void
    ) -> some View {
        self
            .onLongPressGesture(minimumDuration: minimumDuration) {
                GlassAccessibility.accessibleHapticFeedback(for: .conversationTurn)
                onLongPress()
            }
    }
    
    // MARK: - Glass Responsive Design
    
    /// Applies responsive Glass layout based on device size
    func glassResponsive<Content: View>(
        compact: @escaping () -> Content,
        regular: @escaping () -> Content
    ) -> some View {
        GeometryReader { geometry in
            if geometry.size.width < 400 {
                compact()
            } else {
                regular()
            }
        }
    }
    
    /// Applies Glass layout that adapts to content size category
    func glassAdaptiveLayout() -> some View {
        self
            .dynamicTypeSize(.large ... .accessibility1) // Constrain extreme scaling
    }
}

// MARK: - Glass Elevation System

enum GlassElevation {
    case low
    case medium
    case high
    case floating
    
    var configuration: (shadowRadius: CGFloat, shadowOpacity: Double, shadowY: CGFloat, offsetY: CGFloat) {
        switch self {
        case .low:
            return (4, 0.08, 2, 1)
        case .medium:
            return (8, 0.12, 4, 2)
        case .high:
            return (16, 0.16, 8, 4)
        case .floating:
            return (24, 0.2, 12, 6)
        }
    }
}

// MARK: - Glass Background Component

private struct GlassEffectBackground: View {
    let material: GlassDesignSystem.GlassMaterial
    let cornerRadius: CGFloat
    let shadow: Bool
    let vibrancy: Double
    
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @StateObject private var glassSystem = GlassDesignSystem.shared
    
    var body: some View {
        Group {
            if reduceTransparency {
                // Accessibility fallback
                accessibilityBackground
            } else {
                // Standard Glass effect
                standardGlassBackground
            }
        }
        .overlay {
            // Subtle border for definition
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(
            color: shadow ? .black.opacity(material.shadowConfig.opacity) : .clear,
            radius: shadow ? material.shadowConfig.radius : 0,
            x: shadow ? material.shadowConfig.x : 0,
            y: shadow ? material.shadowConfig.y : 0
        )
    }
    
    @ViewBuilder
    private var standardGlassBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(material.material)
            .opacity(vibrancy * material.vibrancyStrength)
    }
    
    @ViewBuilder
    private var accessibilityBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                glassSystem.accessibilityConfiguration.increaseContrast ?
                    Color.primary.opacity(0.05) :
                    Color.secondary.opacity(0.1)
            )
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    let material: GlassDesignSystem.GlassMaterial
    let cornerRadius: CGFloat
    
    init(
        material: GlassDesignSystem.GlassMaterial = .regular,
        cornerRadius: CGFloat = 12
    ) {
        self.material = material
        self.cornerRadius = cornerRadius
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(material: material, cornerRadius: cornerRadius)
            .glassPressEffect(isPressed: configuration.isPressed)
            .glassAccessibility(
                label: "Glass button",
                traits: .button
            )
    }
}

// MARK: - Glass TextField Style

struct GlassTextFieldStyle: TextFieldStyle {
    let material: GlassDesignSystem.GlassMaterial
    let cornerRadius: CGFloat
    
    init(
        material: GlassDesignSystem.GlassMaterial = .thin,
        cornerRadius: CGFloat = 12
    ) {
        self.material = material
        self.cornerRadius = cornerRadius
    }
    
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding()
            .glassEffect(material: material, cornerRadius: cornerRadius)
            .glassAccessibility(
                label: "Glass text field",
                hint: "Enter text here"
            )
    }
}

// MARK: - Preview Support

#if DEBUG
#Preview("Glass Effects") {
    struct EffectsPreview: View {
        @State private var isPressed = false
        @State private var isHovered = false
        @State private var isPulsing = false
        @State private var isShimmering = false
        @State private var text = ""
        
        var body: some View {
            ScrollView {
                VStack(spacing: 30) {
                    Text("Glass Effects")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Glass materials
                    VStack(spacing: 15) {
                        Text("Glass Materials")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(GlassDesignSystem.GlassMaterial.allCases, id: \.self) { material in
                                VStack {
                                    Rectangle()
                                        .frame(width: 60, height: 60)
                                        .glassEffect(material: material)
                                    
                                    Text(String(describing: material))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Interactive effects
                    VStack(spacing: 15) {
                        Text("Interactive Effects")
                            .font(.headline)
                        
                        Button("Press Effect") {
                            withAnimation {
                                isPressed.toggle()
                            }
                        }
                        .buttonStyle(GlassButtonStyle())
                        .glassPressEffect(isPressed: isPressed)
                        
                        Button("Pulse Effect") {
                            isPulsing.toggle()
                        }
                        .buttonStyle(GlassButtonStyle())
                        .glassPulse(isActive: isPulsing)
                        
                        Button("Shimmer Effect") {
                            isShimmering.toggle()
                        }
                        .buttonStyle(GlassButtonStyle())
                        .glassShimmer(isActive: isShimmering)
                    }
                    
                    // Glass text field
                    VStack(spacing: 15) {
                        Text("Glass Text Field")
                            .font(.headline)
                        
                        TextField("Enter text...", text: $text)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    // Glass containers
                    VStack(spacing: 15) {
                        Text("Glass Containers")
                            .font(.headline)
                        
                        VStack {
                            Text("Floating Container")
                            Text("This container has elevated shadow")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .glassContainer()
                        .glassFloating(elevation: .floating)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .background {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
    
    return EffectsPreview()
}
#endif
