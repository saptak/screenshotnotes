//
//  GlassNavigationOverlay.swift
//  ScreenshotNotes
//
//  Sprint 8.1.5: Beautiful, Fluid, Reliable Liquid Glass Navigation Bar Overlay
//  Created by Assistant on 7/13/25.
//
//  Usage:
//  Add `GlassNavigationOverlay(isEnabled: ...)` as a background or overlay in your NavigationStack or NavigationView.
//  Control with feature flag and settings toggle. Fully accessibility compliant.
//

import SwiftUI
import UIKit

/// Beautiful, fluid, and reliable Liquid Glass navigation bar overlay
struct GlassNavigationOverlay: View {
    /// Feature flag to enable/disable the glass navigation overlay
    @AppStorage("isGlassNavigationEnabled") private var isEnabled: Bool = false
    /// Contextual adaptation (color, vibrancy, opacity)
    var color: Color = Color.blue.opacity(0.12)
    var vibrancy: Double = 0.7
    var opacity: Double = 1.0
    var blurRadius: CGFloat = 24
    var cornerRadius: CGFloat = 0
    var height: CGFloat = 56
    var accessibilityLabel: String = "Navigation bar background"
    var accessibilityHint: String = "Provides a beautiful, accessible glass navigation bar background"
    
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var accessibilityDifferentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    
    var body: some View {
        if isEnabled {
            ZStack {
                // Glass material base
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: height)
                // Glass color and vibrancy overlay
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color)
                    .opacity(opacity)
                    .blur(radius: blurRadius)
                    .overlay(
                        Rectangle()
                            .fill(color)
                            .blendMode(.screen)
                            .opacity(vibrancy)
                    )
                    .frame(height: height)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityHint(accessibilityHint)
                    .accessibilityAddTraits(.isHeader)
                    // High contrast overlay
                    .overlay(
                        Group {
                            if accessibilityDifferentiateWithoutColor {
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke(Color.primary.opacity(0.25), lineWidth: 2)
                            }
                        }
                    )
                    // Animation for reduced motion
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.35),
                        value: isEnabled
                    )
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - View Modifier for Easy Integration

extension View {
    /// Adds a beautiful, fluid, and reliable Liquid Glass navigation bar overlay if enabled
    func glassNavigationOverlay(
        isEnabled: Bool = UserDefaults.standard.bool(forKey: "isGlassNavigationEnabled"),
        color: Color = Color.blue.opacity(0.12),
        vibrancy: Double = 0.7,
        opacity: Double = 1.0,
        blurRadius: CGFloat = 24,
        cornerRadius: CGFloat = 0,
        height: CGFloat = 56
    ) -> some View {
        ZStack(alignment: .top) {
            if isEnabled {
                GlassNavigationOverlay(
                    color: color,
                    vibrancy: vibrancy,
                    opacity: opacity,
                    blurRadius: blurRadius,
                    cornerRadius: cornerRadius,
                    height: height
                )
            }
            self
        }
    }
} 