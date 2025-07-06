//
//  GlassDesignSystem.swift
//  ScreenshotNotes
//
//  Sprint 5.4.1: Bottom Glass Search Bar Implementation
//  Created by Assistant on 7/6/25.
//

import SwiftUI
import UIKit

/// Apple Glass UX Design System - Premium Glass materials, effects, and animations
/// Following Apple's Glass design guidelines for sophisticated visual hierarchy
@MainActor
class GlassDesignSystem: ObservableObject {
    static let shared = GlassDesignSystem()
    
    // MARK: - Glass Material Configuration
    
    /// Glass Material types with proper Apple UX compliance
    enum GlassMaterial: CaseIterable {
        case ultraThin
        case thin
        case regular
        case thick
        case chrome
        
        /// Returns the appropriate SwiftUI Material
        var material: Material {
            switch self {
            case .ultraThin: return .ultraThinMaterial
            case .thin: return .thinMaterial
            case .regular: return .regularMaterial
            case .thick: return .thickMaterial
            case .chrome: return .ultraThickMaterial
            }
        }
        
        /// Vibrancy strength for the material
        var vibrancyStrength: Double {
            switch self {
            case .ultraThin: return 1.0
            case .thin: return 0.85
            case .regular: return 0.7
            case .thick: return 0.55
            case .chrome: return 0.4
            }
        }
        
        /// Shadow configuration for depth
        var shadowConfig: GlassShadowConfiguration {
            switch self {
            case .ultraThin: return GlassShadowConfiguration(radius: 8, opacity: 0.05, y: 2)
            case .thin: return GlassShadowConfiguration(radius: 12, opacity: 0.08, y: 3)
            case .regular: return GlassShadowConfiguration(radius: 16, opacity: 0.12, y: 4)
            case .thick: return GlassShadowConfiguration(radius: 20, opacity: 0.15, y: 6)
            case .chrome: return GlassShadowConfiguration(radius: 24, opacity: 0.2, y: 8)
            }
        }
    }
    
    // MARK: - Glass Animation Configuration
    
    /// Physics-based animation presets for Glass interactions
    enum GlassAnimation {
        case gentle
        case responsive
        case dramatic
        case conversational
        case microphone
        
        var springConfig: (response: Double, dampingFraction: Double) {
            switch self {
            case .gentle: return (0.6, 0.85)
            case .responsive: return (0.3, 0.75)
            case .dramatic: return (0.8, 0.6)
            case .conversational: return (0.4, 0.8)
            case .microphone: return (0.25, 0.9)
            }
        }
        
        var duration: Double {
            switch self {
            case .gentle: return 0.6
            case .responsive: return 0.3
            case .dramatic: return 0.8
            case .conversational: return 0.4
            case .microphone: return 0.25
            }
        }
    }
    
    // MARK: - Glass Color System
    
    /// Semantic Glass colors with dynamic adaptation
    enum GlassColor {
        case primary
        case secondary
        case accent
        case success
        case warning
        case error
        case conversation
        case microphone
        case processing
        
        var color: Color {
            switch self {
            case .primary: return Color.primary
            case .secondary: return Color.secondary
            case .accent: return Color.accentColor
            case .success: return Color.green
            case .warning: return Color.orange
            case .error: return Color.red
            case .conversation: return Color.blue
            case .microphone: return Color.cyan
            case .processing: return Color.purple
            }
        }
        
        /// Glass-appropriate opacity for the color
        var glassOpacity: Double {
            switch self {
            case .primary, .secondary: return 0.8
            case .accent, .conversation, .microphone: return 0.9
            case .success, .warning, .error: return 0.85
            case .processing: return 0.7
            }
        }
    }
    
    // MARK: - Accessibility Support
    
    /// Accessibility-aware Glass configuration
    struct GlassAccessibilityConfiguration {
        let reduceTransparency: Bool
        let increaseContrast: Bool
        let reduceMotion: Bool
        let prefersCrossFadeTransitions: Bool
        
        init() {
            // Access UIAccessibility properties on main actor
            self.reduceTransparency = MainActor.assumeIsolated { UIAccessibility.isReduceTransparencyEnabled }
            self.increaseContrast = MainActor.assumeIsolated { UIAccessibility.isDarkerSystemColorsEnabled }
            self.reduceMotion = MainActor.assumeIsolated { UIAccessibility.isReduceMotionEnabled }
            self.prefersCrossFadeTransitions = MainActor.assumeIsolated { UIAccessibility.prefersCrossFadeTransitions }
        }
        
        /// Adjusted material for accessibility
        func adaptedMaterial(for material: GlassMaterial) -> Material {
            if reduceTransparency {
                return .regularMaterial // Fallback to less transparent material
            }
            return material.material
        }
        
        /// Adjusted animation for accessibility
        func adaptedAnimation(for animation: GlassAnimation) -> (response: Double, dampingFraction: Double) {
            if reduceMotion {
                return (0.1, 1.0) // Minimal animation
            }
            return animation.springConfig
        }
    }
    
    // MARK: - Glass Shadow Configuration
    
    struct GlassShadowConfiguration {
        let radius: CGFloat
        let opacity: Double
        let x: CGFloat
        let y: CGFloat
        
        init(radius: CGFloat, opacity: Double, x: CGFloat = 0, y: CGFloat) {
            self.radius = radius
            self.opacity = opacity
            self.x = x
            self.y = y
        }
    }
    
    // MARK: - Glass Layout Configuration
    
    /// Layout constants following Apple's spacing guidelines
    enum GlassLayout {
        static let searchBarHeight: CGFloat = 56
        static let searchBarHeightExpanded: CGFloat = 120
        static let searchBarCornerRadius: CGFloat = 16
        static let microphoneButtonSize: CGFloat = 44
        static let bottomSafeAreaPadding: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let minimumTouchTarget: CGFloat = 44
    }
    
    // MARK: - Public Interface
    
    @Published var accessibilityConfiguration = GlassAccessibilityConfiguration()
    
    /// Updates accessibility configuration when system settings change
    func updateAccessibilityConfiguration() {
        accessibilityConfiguration = GlassAccessibilityConfiguration()
    }
    
    /// Creates a Glass spring animation
    static func glassSpring(_ animation: GlassAnimation) -> Animation {
        let config = animation.springConfig
        return .spring(response: config.response, dampingFraction: config.dampingFraction)
    }
    
    /// Creates an accessibility-aware Glass spring animation
    func adaptedGlassSpring(_ animation: GlassAnimation) -> Animation {
        let config = accessibilityConfiguration.adaptedAnimation(for: animation)
        return .spring(response: config.response, dampingFraction: config.dampingFraction)
    }
}

// MARK: - Glass View Modifiers

/// Primary Glass background modifier
struct GlassBackgroundModifier: ViewModifier {
    let material: GlassDesignSystem.GlassMaterial
    let cornerRadius: CGFloat
    let shadow: Bool
    
    @StateObject private var glassSystem = GlassDesignSystem.shared
    
    func body(content: Content) -> some View {
        content
            .background {
                glassBackground
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                // Subtle border for definition
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
            }
            .shadow(
                color: .black.opacity(shadow ? material.shadowConfig.opacity : 0),
                radius: shadow ? material.shadowConfig.radius : 0,
                x: shadow ? material.shadowConfig.x : 0,
                y: shadow ? material.shadowConfig.y : 0
            )
    }
    
    @ViewBuilder
    private var glassBackground: some View {
        let adaptedMaterial = glassSystem.accessibilityConfiguration.adaptedMaterial(for: material)
        
        if glassSystem.accessibilityConfiguration.reduceTransparency {
            // High contrast fallback
            Color(.systemBackground)
                .opacity(0.95)
        } else {
            // Standard Glass implementation
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(adaptedMaterial)
        }
    }
}

/// Glass vibrancy effect modifier
struct GlassVibrancyModifier: ViewModifier {
    let strength: Double
    
    @StateObject private var glassSystem = GlassDesignSystem.shared
    
    func body(content: Content) -> some View {
        if glassSystem.accessibilityConfiguration.reduceTransparency {
            content // Skip vibrancy for accessibility
        } else {
            content
                .foregroundStyle(.primary.opacity(strength))
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies Glass background with material and corner radius
    func glassBackground(
        material: GlassDesignSystem.GlassMaterial = .regular,
        cornerRadius: CGFloat = 12,
        shadow: Bool = true
    ) -> some View {
        modifier(GlassBackgroundModifier(
            material: material,
            cornerRadius: cornerRadius,
            shadow: shadow
        ))
    }
    
    /// Applies Glass spring animation
    func glassAnimation(_ animation: GlassDesignSystem.GlassAnimation) -> some View {
        self.animation(GlassDesignSystem.glassSpring(animation), value: UUID())
    }
}

// MARK: - Preview Support

#if DEBUG
#Preview("Glass Design System") {
    VStack(spacing: 20) {
        Text("Glass Design System")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        // Material examples
        HStack(spacing: 12) {
            ForEach(GlassDesignSystem.GlassMaterial.allCases, id: \.self) { material in
                VStack {
                    Rectangle()
                        .frame(width: 60, height: 60)
                        .glassBackground(material: material)
                    
                    Text(String(describing: material))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        
        // Glass search bar preview
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            Text("Search with Glass...")
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Circle()
                .frame(width: 36, height: 36)
                .glassBackground(material: .regular, cornerRadius: 18)
                .overlay {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 16, weight: .medium))
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassBackground(material: .regular, cornerRadius: 16)
        .padding(.horizontal)
        
        Spacer()
    }
    .padding()
    .background {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
#endif
