//
//  LiquidGlassMaterial.swift
//  ScreenshotNotes
//
//  Sprint 8.1.1: Basic Liquid Glass Material System
//  Created by Assistant on 7/13/25.
//

import SwiftUI
import UIKit

/// Advanced Liquid Glass Material System for Enhanced Interface
/// Builds upon the existing Glass Design System with enhanced physics-based rendering
/// Only available when Enhanced Interface is enabled
@MainActor
class LiquidGlassMaterial: ObservableObject {
    
    // MARK: - Core Material Properties
    
    /// Enhanced Liquid Glass material types with real-time environmental adaptation
    enum MaterialType: String, CaseIterable {
        case ethereal = "ethereal"          // Ultra-light, almost invisible
        case gossamer = "gossamer"          // Light and airy
        case crystal = "crystal"            // Clear and defined
        case prism = "prism"               // Refractive and colorful
        case mercury = "mercury"           // Reflective and fluid
        
        /// Base opacity for the material
        var baseOpacity: Double {
            switch self {
            case .ethereal: return 0.05
            case .gossamer: return 0.12
            case .crystal: return 0.25
            case .prism: return 0.35
            case .mercury: return 0.45
            }
        }
        
        /// Blur radius for the material
        var blurRadius: CGFloat {
            switch self {
            case .ethereal: return 2
            case .gossamer: return 4
            case .crystal: return 8
            case .prism: return 12
            case .mercury: return 16
            }
        }
        
        /// Vibrancy intensity
        var vibrancyIntensity: Double {
            switch self {
            case .ethereal: return 0.95
            case .gossamer: return 0.85
            case .crystal: return 0.75
            case .prism: return 0.65
            case .mercury: return 0.55
            }
        }
        
        /// Corresponding SwiftUI Material for fallback
        var swiftUIMaterial: Material {
            switch self {
            case .ethereal: return .ultraThinMaterial
            case .gossamer: return .thinMaterial
            case .crystal: return .regularMaterial
            case .prism: return .thickMaterial
            case .mercury: return .ultraThickMaterial
            }
        }
    }
    
    // MARK: - Environmental Adaptation
    
    /// Environmental factors that affect material appearance
    struct EnvironmentalContext {
        let colorScheme: ColorScheme
        let isReduceTransparencyEnabled: Bool
        let isIncreaseContrastEnabled: Bool
        let ambientLightLevel: AmbientLightLevel
        
        enum AmbientLightLevel {
            case bright
            case normal
            case dim
            
            var adaptationFactor: Double {
                switch self {
                case .bright: return 1.2  // Increase opacity in bright light
                case .normal: return 1.0
                case .dim: return 0.8     // Reduce opacity in dim light
                }
            }
        }
        
        init(colorScheme: ColorScheme = .light) {
            self.colorScheme = colorScheme
            // Access UIAccessibility properties safely on main actor
            self.isReduceTransparencyEnabled = MainActor.assumeIsolated { UIAccessibility.isReduceTransparencyEnabled }
            self.isIncreaseContrastEnabled = MainActor.assumeIsolated { UIAccessibility.isDarkerSystemColorsEnabled }
            // For now, assume normal ambient light (real implementation would use camera/sensors)
            self.ambientLightLevel = .normal
        }
    }
    
    // MARK: - Specular Highlights
    
    /// Specular highlight configuration for enhanced visual depth
    struct SpecularHighlight {
        let intensity: Double
        let position: CGPoint
        let radius: CGFloat
        let color: Color
        
        static let subtle = SpecularHighlight(
            intensity: 0.15,
            position: CGPoint(x: 0.3, y: 0.2),
            radius: 20,
            color: .white
        )
        
        static let prominent = SpecularHighlight(
            intensity: 0.3,
            position: CGPoint(x: 0.25, y: 0.15),
            radius: 35,
            color: .white
        )
        
        static let none = SpecularHighlight(
            intensity: 0.0,
            position: .zero,
            radius: 0,
            color: .clear
        )
    }
    
    // MARK: - Adaptive Material Configuration
    
    /// Computes adapted material properties based on environment
    func adaptedMaterialProperties(
        for materialType: MaterialType,
        in environment: EnvironmentalContext
    ) -> AdaptedMaterialProperties {
        
        var opacity = materialType.baseOpacity
        var blurRadius = materialType.blurRadius
        var vibrancy = materialType.vibrancyIntensity
        var specularHighlight = SpecularHighlight.subtle
        
        // Accessibility adaptations
        if environment.isReduceTransparencyEnabled {
            opacity = min(0.95, opacity * 3.0) // Much more opaque
            blurRadius = max(1, blurRadius * 0.3) // Reduce blur
            vibrancy = 0.1 // Minimal vibrancy
            specularHighlight = .none
        }
        
        if environment.isIncreaseContrastEnabled {
            opacity = min(0.9, opacity * 1.5) // Increase opacity for contrast
            vibrancy = max(0.1, vibrancy * 0.7) // Reduce vibrancy
        }
        
        // Ambient light adaptation
        opacity *= environment.ambientLightLevel.adaptationFactor
        
        // Dark mode adaptations
        if environment.colorScheme == .dark {
            opacity = min(0.8, opacity * 1.3) // Slightly more opaque in dark mode
            specularHighlight = SpecularHighlight(
                intensity: specularHighlight.intensity * 0.7,
                position: specularHighlight.position,
                radius: specularHighlight.radius,
                color: Color.white.opacity(0.8)
            )
        }
        
        return AdaptedMaterialProperties(
            opacity: opacity,
            blurRadius: blurRadius,
            vibrancyIntensity: vibrancy,
            specularHighlight: specularHighlight,
            fallbackMaterial: materialType.swiftUIMaterial
        )
    }
    
    /// Final computed material properties
    struct AdaptedMaterialProperties {
        let opacity: Double
        let blurRadius: CGFloat
        let vibrancyIntensity: Double
        let specularHighlight: SpecularHighlight
        let fallbackMaterial: Material
    }
    
    // MARK: - Public Interface
    
    /// Creates an adapted material for the current environment
    func createMaterial(
        type: MaterialType,
        environment: EnvironmentalContext
    ) -> AdaptedMaterialProperties {
        return adaptedMaterialProperties(for: type, in: environment)
    }
}

// MARK: - Liquid Glass View Modifiers

/// Primary Liquid Glass background modifier for Enhanced Interface
struct LiquidGlassBackgroundModifier: ViewModifier {
    let materialType: LiquidGlassMaterial.MaterialType
    let cornerRadius: CGFloat
    let enableSpecularHighlights: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var liquidGlass = LiquidGlassMaterial()
    
    func body(content: Content) -> some View {
        let environment = LiquidGlassMaterial.EnvironmentalContext(colorScheme: colorScheme)
        let properties = liquidGlass.createMaterial(type: materialType, environment: environment)
        
        content
            .background {
                liquidGlassBackground(properties: properties)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                // Subtle border for definition
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            }
            .overlay {
                // Specular highlights if enabled
                if enableSpecularHighlights && properties.specularHighlight.intensity > 0 {
                    specularHighlightOverlay(
                        highlight: properties.specularHighlight,
                        cornerRadius: cornerRadius
                    )
                }
            }
    }
    
    @ViewBuilder
    private func liquidGlassBackground(properties: LiquidGlassMaterial.AdaptedMaterialProperties) -> some View {
        if properties.opacity >= 0.9 {
            // High-opacity fallback for accessibility
            Color(.systemBackground)
                .opacity(properties.opacity)
        } else {
            // Standard Liquid Glass implementation
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(properties.fallbackMaterial)
                .opacity(properties.opacity)
                .background(
                    // Base background with subtle color adaptation
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.systemBackground).opacity(0.15),
                                    Color(.systemBackground).opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
    }
    
    @ViewBuilder
    private func specularHighlightOverlay(
        highlight: LiquidGlassMaterial.SpecularHighlight,
        cornerRadius: CGFloat
    ) -> some View {
        GeometryReader { geometry in
            let highlightPosition = CGPoint(
                x: geometry.size.width * highlight.position.x,
                y: geometry.size.height * highlight.position.y
            )
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            highlight.color.opacity(highlight.intensity),
                            highlight.color.opacity(highlight.intensity * 0.5),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: highlight.radius
                    )
                )
                .frame(width: highlight.radius * 2, height: highlight.radius * 2)
                .position(highlightPosition)
                .blendMode(.overlay)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }
}

// MARK: - View Extensions for Enhanced Interface

extension View {
    /// Applies Liquid Glass background (Enhanced Interface only)
    func liquidGlassBackground(
        material: LiquidGlassMaterial.MaterialType = .crystal,
        cornerRadius: CGFloat = 12,
        specularHighlights: Bool = true
    ) -> some View {
        modifier(LiquidGlassBackgroundModifier(
            materialType: material,
            cornerRadius: cornerRadius,
            enableSpecularHighlights: specularHighlights
        ))
    }
}

// MARK: - Preview Support

#if DEBUG
#Preview("Liquid Glass Materials") {
    VStack(spacing: 24) {
        Text("Liquid Glass Material System")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
        
        Text("Enhanced Interface Foundation")
            .font(.headline)
            .foregroundStyle(.secondary)
        
        // Material type examples
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            ForEach(LiquidGlassMaterial.MaterialType.allCases, id: \.self) { materialType in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .frame(height: 80)
                        .liquidGlassBackground(material: materialType, cornerRadius: 16)
                        .overlay {
                            VStack {
                                Image(systemName: "sparkles")
                                    .font(.title2)
                                    .foregroundStyle(.primary)
                                Text(materialType.rawValue.capitalized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
        }
        
        // Example interface element
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            Text("Enhanced search...")
                .foregroundStyle(.tertiary)
            
            Spacer()
            
            Circle()
                .frame(width: 40, height: 40)
                .liquidGlassBackground(material: .prism, cornerRadius: 20)
                .overlay {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 18, weight: .medium))
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .liquidGlassBackground(material: .crystal, cornerRadius: 20)
        .padding(.horizontal)
        
        Spacer()
    }
    .padding()
    .background {
        LinearGradient(
            colors: [
                .cyan.opacity(0.2),
                .blue.opacity(0.3),
                .purple.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
#endif