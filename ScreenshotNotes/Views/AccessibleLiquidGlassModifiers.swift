//
//  AccessibleLiquidGlassModifiers.swift
//  ScreenshotNotes
//
//  Sprint 8.1.4: Accessible View Modifiers for Liquid Glass
//  Created by Assistant on 7/13/25.
//

import SwiftUI
import Combine

// MARK: - Accessible Liquid Glass Background Modifier

/// Enhanced Liquid Glass background modifier with comprehensive accessibility support
struct AccessibleLiquidGlassBackgroundModifier: ViewModifier {
    let materialType: LiquidGlassMaterial.MaterialType
    let cornerRadius: CGFloat
    let enableSpecularHighlights: Bool
    let accessibilityLabel: String?
    let accessibilityHint: String?
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var liquidGlass = LiquidGlassMaterial()
    @StateObject private var accessibilityService = LiquidGlassAccessibilityService.shared
    @StateObject private var renderer = LiquidGlassRenderer.shared
    
    func body(content: Content) -> some View {
        let environment = LiquidGlassMaterial.EnvironmentalContext(colorScheme: colorScheme)
        let properties = accessibilityService.createAccessibleMaterialProperties(
            for: materialType,
            environment: environment
        )
        
        content
            .background {
                accessibleLiquidGlassBackground(properties: properties)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                // Enhanced border for accessibility
                accessibleBorderOverlay
            }
            .overlay {
                // Conditional specular highlights based on accessibility settings
                if enableSpecularHighlights && 
                   !accessibilityService.shouldDisableSpecularHighlights &&
                   properties.specularHighlight.intensity > 0 {
                    accessibleSpecularHighlightOverlay(
                        highlight: properties.specularHighlight,
                        cornerRadius: cornerRadius
                    )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityLabel ?? defaultAccessibilityLabel)
            .accessibilityHint(accessibilityHint ?? "")
            .accessibilityAddTraits(.isStaticText)
            .dynamicTypeSize(...DynamicTypeSize.accessibility5) // Limit extreme sizes for layout stability
    }
    
    private var defaultAccessibilityLabel: String {
        return GlassDescriptions.liquidGlassBackgroundDescription(
            material: materialType,
            hasSpecularHighlights: enableSpecularHighlights && !accessibilityService.shouldDisableSpecularHighlights
        )
    }
    
    @ViewBuilder
    private func accessibleLiquidGlassBackground(properties: LiquidGlassMaterial.AdaptedMaterialProperties) -> some View {
        if accessibilityService.shouldDisableMaterialEffects() {
            // High accessibility fallback
            highContrastBackground(properties: properties)
        } else if properties.opacity >= 0.9 {
            // Medium accessibility - solid colors
            mediumContrastBackground(properties: properties)
        } else {
            // Standard Liquid Glass with accessibility enhancements
            standardLiquidGlassBackground(properties: properties)
        }
    }
    
    @ViewBuilder
    private func highContrastBackground(properties: LiquidGlassMaterial.AdaptedMaterialProperties) -> some View {
        let backgroundColor = accessibilityService.shouldUseHighContrast ? 
            Color(.systemBackground) : Color(.secondarySystemBackground)
        
        backgroundColor
            .opacity(min(0.95, properties.opacity))
            .overlay {
                // High contrast border for definition
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        .primary.opacity(accessibilityService.shouldUseHighContrast ? 0.3 : 0.1),
                        lineWidth: accessibilityService.shouldUseHighContrast ? 2.0 : 1.0
                    )
            }
            .overlay {
                // Subtle pattern for texture without transparency
                if accessibilityService.shouldUseHighContrast {
                    Rectangle()
                        .fill(.primary.opacity(0.03))
                        .blendMode(.overlay)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
    }
    
    @ViewBuilder
    private func mediumContrastBackground(properties: LiquidGlassMaterial.AdaptedMaterialProperties) -> some View {
        Color(.systemBackground)
            .opacity(properties.opacity)
            .overlay {
                // Medium contrast enhancement
                if accessibilityService.shouldUseHighContrast {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.primary.opacity(0.05))
                        .blendMode(.overlay)
                }
            }
    }
    
    @ViewBuilder
    private func standardLiquidGlassBackground(properties: LiquidGlassMaterial.AdaptedMaterialProperties) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(properties.fallbackMaterial)
            .opacity(properties.opacity)
            .background {
                // Enhanced base background for accessibility
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: accessibleBackgroundColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }
    
    private var accessibleBackgroundColors: [Color] {
        let baseOpacity = accessibilityService.shouldUseHighContrast ? 0.3 : 0.15
        let secondaryOpacity = accessibilityService.shouldUseHighContrast ? 0.15 : 0.05
        
        return [
            Color(.systemBackground).opacity(baseOpacity),
            Color(.systemBackground).opacity(secondaryOpacity)
        ]
    }
    
    @ViewBuilder
    private var accessibleBorderOverlay: some View {
        let borderOpacity = accessibilityService.shouldUseHighContrast ? 0.2 : 0.08
        let borderWidth = accessibilityService.shouldUseHighContrast ? 1.0 : 0.5
        
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(.primary.opacity(borderOpacity), lineWidth: borderWidth)
    }
    
    @ViewBuilder
    private func accessibleSpecularHighlightOverlay(
        highlight: LiquidGlassMaterial.SpecularHighlight,
        cornerRadius: CGFloat
    ) -> some View {
        GeometryReader { geometry in
            let adjustedHighlight = LiquidGlassMaterial.SpecularHighlight(
                intensity: highlight.intensity * (accessibilityService.shouldUseHighContrast ? 0.5 : 1.0),
                position: highlight.position,
                radius: highlight.radius,
                color: highlight.color
            )
            
            if renderer.isGPUAccelerationEnabled && !accessibilityService.isReduceMotionEnabled {
                // GPU-accelerated with accessibility considerations
                AsyncImage(url: nil) { _ in
                    standardSpecularHighlightOverlay(highlight: adjustedHighlight, cornerRadius: cornerRadius)
                } placeholder: {
                    standardSpecularHighlightOverlay(highlight: adjustedHighlight, cornerRadius: cornerRadius)
                }
                .task {
                    _ = renderer.renderSpecularHighlight(
                        intensity: Float(adjustedHighlight.intensity),
                        position: adjustedHighlight.position,
                        radius: Float(adjustedHighlight.radius),
                        size: geometry.size
                    )
                }
                .animation(
                    .easeInOut(duration: accessibilityService.getAccessibleAnimationDuration(0.1)),
                    value: renderer.renderingQuality
                )
            } else {
                // Fallback with accessibility considerations
                standardSpecularHighlightOverlay(highlight: adjustedHighlight, cornerRadius: cornerRadius)
            }
        }
    }
    
    @ViewBuilder
    private func standardSpecularHighlightOverlay(
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
                .accessibilityHidden(true) // Hide decorative elements from VoiceOver
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }
}

// MARK: - Accessible Performance Metric Card Modifier

/// Accessible modifier for performance metric cards with VoiceOver support
struct AccessiblePerformanceMetricModifier: ViewModifier {
    let title: String
    let value: String
    let isOptimal: Bool
    let accessibilityAction: (() -> Void)?
    
    @StateObject private var accessibilityService = LiquidGlassAccessibilityService.shared
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(GlassDescriptions.performanceMetricDescription(
                title: title,
                value: value,
                isOptimal: isOptimal,
                additionalContext: isOptimal ? "Performance is good" : "Tap for details"
            ))
            .accessibilityHint(isOptimal ? "Performance is good" : "Tap for details")
            .accessibilityAddTraits(isOptimal ? .isStaticText : .isButton)
            .onTapGesture {
                if !isOptimal {
                    accessibilityAction?()
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility3) // Prevent layout breaking
    }
}

// MARK: - Accessible Star Rating Modifier

/// Accessible modifier for star rating components
struct AccessibleStarRatingModifier: ViewModifier {
    let currentRating: Int
    let maxRating: Int
    let onRatingChanged: (Int) -> Void
    
    @StateObject private var accessibilityService = LiquidGlassAccessibilityService.shared
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(GlassDescriptions.materialRatingDescription(
                rating: currentRating,
                maxRating: maxRating,
                materialType: .crystal // Default material type for generic ratings
            ))
            .accessibilityValue("\(currentRating) out of \(maxRating)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    if currentRating < maxRating {
                        onRatingChanged(currentRating + 1)
                    }
                case .decrement:
                    if currentRating > 0 {
                        onRatingChanged(currentRating - 1)
                    }
                @unknown default:
                    break
                }
            }
    }
}

// MARK: - Accessible Material Selection Modifier

/// Accessible modifier for material selection grids
struct AccessibleMaterialSelectionModifier: ViewModifier {
    let materialType: LiquidGlassMaterial.MaterialType
    let isSelected: Bool
    let onSelection: () -> Void
    
    @StateObject private var accessibilityService = LiquidGlassAccessibilityService.shared
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(GlassDescriptions.liquidGlassMaterialDescription(
                type: materialType,
                context: "selection option",
                isActive: isSelected
            ))
            .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
            .accessibilityAddTraits(isSelected ? .isSelected : .isButton)
            .onTapGesture {
                onSelection()
            }
    }
}

// MARK: - View Extensions for Accessible Liquid Glass

extension View {
    /// Applies accessible Liquid Glass background with comprehensive accessibility support
    func accessibleLiquidGlassBackground(
        material: LiquidGlassMaterial.MaterialType = .crystal,
        cornerRadius: CGFloat = 12,
        specularHighlights: Bool = true,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) -> some View {
        modifier(AccessibleLiquidGlassBackgroundModifier(
            materialType: material,
            cornerRadius: cornerRadius,
            enableSpecularHighlights: specularHighlights,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint
        ))
    }
    
    /// Applies accessible performance metric styling with VoiceOver support
    func accessiblePerformanceMetric(
        title: String,
        value: String,
        isOptimal: Bool,
        onTap: (() -> Void)? = nil
    ) -> some View {
        modifier(AccessiblePerformanceMetricModifier(
            title: title,
            value: value,
            isOptimal: isOptimal,
            accessibilityAction: onTap
        ))
    }
    
    /// Applies accessible star rating with adjustable actions
    func accessibleStarRating(
        currentRating: Int,
        maxRating: Int = 5,
        onRatingChanged: @escaping (Int) -> Void
    ) -> some View {
        modifier(AccessibleStarRatingModifier(
            currentRating: currentRating,
            maxRating: maxRating,
            onRatingChanged: onRatingChanged
        ))
    }
    
    /// Applies accessible material selection with enhanced focus
    func accessibleMaterialSelection(
        materialType: LiquidGlassMaterial.MaterialType,
        isSelected: Bool,
        onSelection: @escaping () -> Void
    ) -> some View {
        modifier(AccessibleMaterialSelectionModifier(
            materialType: materialType,
            isSelected: isSelected,
            onSelection: onSelection
        ))
    }
    
    /// Applies dynamic text scaling with accessibility limits
    func accessibleDynamicText(maxSize: DynamicTypeSize = .accessibility3) -> some View {
        self.dynamicTypeSize(...maxSize)
    }
    
    /// Conditionally applies animations based on accessibility settings
    @ViewBuilder
    func accessibleAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        let accessibilityService = LiquidGlassAccessibilityService.shared
        
        if !accessibilityService.isReduceMotionEnabled {
            self.animation(animation, value: value)
        } else {
            self // No animation for reduce motion
        }
    }
    
    /// Applies reduced motion-aware transitions
    @ViewBuilder
    func accessibleTransition<T: Transition>(_ transition: T, reducedMotionFallback: T) -> some View {
        let accessibilityService = LiquidGlassAccessibilityService.shared
        
        if accessibilityService.isReduceMotionEnabled {
            self.transition(reducedMotionFallback)
        } else {
            self.transition(transition)
        }
    }
    
    /// Applies scale effects with reduced motion considerations
    @ViewBuilder
    func accessibleScaleEffect(_ scale: CGFloat, anchor: UnitPoint = .center) -> some View {
        let accessibilityService = LiquidGlassAccessibilityService.shared
        
        if accessibilityService.isReduceMotionEnabled {
            // Minimal scale change for reduced motion
            self.scaleEffect(1.0 + (scale - 1.0) * 0.1, anchor: anchor)
        } else {
            self.scaleEffect(scale, anchor: anchor)
        }
    }
    
    /// Applies rotation effects with reduced motion considerations
    @ViewBuilder
    func accessibleRotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View {
        let accessibilityService = LiquidGlassAccessibilityService.shared
        
        if accessibilityService.isReduceMotionEnabled {
            // No rotation for reduced motion
            self
        } else {
            self.rotationEffect(angle, anchor: anchor)
        }
    }
    
    /// Applies opacity animations with reduced motion considerations
    @ViewBuilder
    func accessibleOpacity(_ opacity: Double, duration: Double = 0.3) -> some View {
        let accessibilityService = LiquidGlassAccessibilityService.shared
        let accessibleDuration = accessibilityService.getAccessibleAnimationDuration(duration)
        
        if accessibleDuration > 0 {
            self.opacity(opacity)
                .animation(.easeInOut(duration: accessibleDuration), value: opacity)
        } else {
            self.opacity(opacity)
        }
    }
    
    /// Applies offset animations with reduced motion considerations
    @ViewBuilder
    func accessibleOffset(_ offset: CGSize, duration: Double = 0.3) -> some View {
        let accessibilityService = LiquidGlassAccessibilityService.shared
        let accessibleDuration = accessibilityService.getAccessibleAnimationDuration(duration)
        
        if accessibilityService.isReduceMotionEnabled {
            // No offset for reduced motion
            self
        } else {
            self.offset(offset)
                .animation(.easeInOut(duration: accessibleDuration), value: offset)
        }
    }
    
    /// Provides haptic feedback with accessibility considerations
    func accessibleHapticFeedback(_ intensity: CGFloat = 1.0, type: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        let accessibilityService = LiquidGlassAccessibilityService.shared
        
        // Reduce haptic intensity for users with motor disabilities
        let adjustedIntensity = accessibilityService.isSwitchControlRunning ? intensity * 0.5 : intensity
        
        let generator = UIImpactFeedbackGenerator(style: type)
        generator.impactOccurred(intensity: adjustedIntensity)
        
        return self
    }
}