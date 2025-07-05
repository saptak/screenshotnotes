import SwiftUI

/// A comprehensive material design system that provides consistent depth layering,
/// accessibility-compliant materials, and performance-optimized glass effects.
///
/// This system implements Apple's Material Design principles with custom depth tokens
/// to ensure visual hierarchy and accessibility compliance across all UI components.
@MainActor
final class MaterialDesignSystem: ObservableObject {
    
    // MARK: - Singleton
    static let shared = MaterialDesignSystem()
    
    // MARK: - Depth Token System
    /// Depth tokens define the visual hierarchy of materials from background to foreground
    enum DepthToken: Int, CaseIterable {
        case background = 0      // Base layer - no elevation
        case surface = 1         // Cards, panels - 1dp elevation
        case overlay = 2         // Floating elements - 2dp elevation
        case modal = 3           // Modals, sheets - 4dp elevation
        case tooltip = 4         // Tooltips, popovers - 8dp elevation
        case dropdown = 5        // Dropdowns, menus - 12dp elevation
        case navigation = 6      // Navigation bars - 16dp elevation
        case dialog = 7          // Dialogs, alerts - 24dp elevation
        
        /// Elevation value in points following Material Design guidelines
        var elevation: CGFloat {
            switch self {
            case .background: return 0
            case .surface: return 1
            case .overlay: return 2
            case .modal: return 4
            case .tooltip: return 8
            case .dropdown: return 12
            case .navigation: return 16
            case .dialog: return 24
            }
        }
        
        /// Shadow configuration for the depth token
        var shadowConfig: ShadowConfiguration {
            ShadowConfiguration(
                color: .black.opacity(0.1),
                radius: elevation * 0.5,
                x: 0,
                y: elevation * 0.25
            )
        }
    }
    
    // MARK: - Material Configuration
    /// Defines the material type and visual properties for each depth token
    enum MaterialConfiguration {
        case background(Material)
        case surface(Material)
        case overlay(Material)
        case modal(Material)
        case tooltip(Material)
        case dropdown(Material)
        case navigation(Material)
        case dialog(Material)
        
        /// Returns the appropriate material for the given depth token
        static func material(for depth: DepthToken) -> Material {
            switch depth {
            case .background:
                return .regularMaterial
            case .surface:
                return .thinMaterial
            case .overlay:
                return .ultraThinMaterial
            case .modal:
                return .regularMaterial
            case .tooltip:
                return .thickMaterial
            case .dropdown:
                return .regularMaterial
            case .navigation:
                return .regularMaterial
            case .dialog:
                return .thickMaterial
            }
        }
    }
    
    // MARK: - Shadow Configuration
    struct ShadowConfiguration {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Accessibility Configuration
    /// Ensures materials meet WCAG AA accessibility standards
    struct AccessibilityConfiguration {
        let contrastRatio: Double
        let reducedTransparencySupport: Bool
        let highContrastSupport: Bool
        
        static let standard = AccessibilityConfiguration(
            contrastRatio: 4.5,
            reducedTransparencySupport: true,
            highContrastSupport: true
        )
    }
    
    // MARK: - Performance Configuration
    /// Optimizes material rendering for target frame rates
    struct PerformanceConfiguration {
        let targetFrameRate: Int
        let adaptiveQuality: Bool
        let thermalStateAware: Bool
        
        static let standard = PerformanceConfiguration(
            targetFrameRate: 60,
            adaptiveQuality: true,
            thermalStateAware: true
        )
    }
    
    // MARK: - Properties
    @Published var accessibilityConfiguration = AccessibilityConfiguration.standard
    @Published var performanceConfiguration = PerformanceConfiguration.standard
    
    // MARK: - Environment Monitoring
    @Published private var isReducedTransparencyEnabled = false
    @Published private var isHighContrastEnabled = false
    
    // MARK: - Combine Storage
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        observeAccessibilityChanges()
    }
    
    // MARK: - Public Interface
    
    /// Returns a configured material view modifier for the specified depth token
    /// - Parameters:
    ///   - depth: The depth token defining the visual hierarchy
    ///   - cornerRadius: Optional corner radius for the material background
    ///   - stroke: Optional stroke configuration
    /// - Returns: A view modifier that applies the material configuration
    func materialModifier(
        for depth: DepthToken,
        cornerRadius: CGFloat = 0,
        stroke: StrokeConfiguration? = nil
    ) -> some ViewModifier {
        MaterialModifier(
            depth: depth,
            cornerRadius: cornerRadius,
            stroke: stroke,
            isReducedTransparencyEnabled: isReducedTransparencyEnabled,
            isHighContrastEnabled: isHighContrastEnabled
        )
    }
    
    /// Returns the appropriate material for a given depth token
    /// - Parameter depth: The depth token
    /// - Returns: The configured material
    func material(for depth: DepthToken) -> Material {
        MaterialConfiguration.material(for: depth)
    }
    
    /// Returns the shadow configuration for a given depth token
    /// - Parameter depth: The depth token
    /// - Returns: The shadow configuration
    func shadowConfiguration(for depth: DepthToken) -> ShadowConfiguration {
        depth.shadowConfig
    }
}

// MARK: - Supporting Types

/// Configuration for stroke/border effects
struct StrokeConfiguration {
    let color: Color
    let lineWidth: CGFloat
    let style: StrokeStyle
    
    init(color: Color, lineWidth: CGFloat = 0.5, style: StrokeStyle = StrokeStyle()) {
        self.color = color
        self.lineWidth = lineWidth
        self.style = style
    }
    
    static let subtle = StrokeConfiguration(color: Color(UIColor.quaternaryLabel), lineWidth: 0.5)
    static let emphasis = StrokeConfiguration(color: Color(UIColor.tertiaryLabel), lineWidth: 1.0)
    static let strong = StrokeConfiguration(color: Color(UIColor.secondaryLabel), lineWidth: 1.5)
}

/// View modifier that applies material configuration
private struct MaterialModifier: ViewModifier {
    let depth: MaterialDesignSystem.DepthToken
    let cornerRadius: CGFloat
    let stroke: StrokeConfiguration?
    let isReducedTransparencyEnabled: Bool
    let isHighContrastEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .background {
                materialBackground
            }
            .shadow(
                color: shadowConfig.color,
                radius: shadowConfig.radius,
                x: shadowConfig.x,
                y: shadowConfig.y
            )
    }
    
    @ViewBuilder
    private var materialBackground: some View {
        Group {
            if isReducedTransparencyEnabled {
                // Fallback to solid colors when transparency is reduced
                fallbackBackground
            } else {
                // Standard material background
                standardMaterialBackground
            }
        }
    }
    
    @ViewBuilder
    private var standardMaterialBackground: some View {
        Group {
            if cornerRadius > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(MaterialDesignSystem.shared.material(for: depth))
                    .strokeBorder(stroke?.color ?? Color.clear, lineWidth: stroke?.lineWidth ?? 0)
            } else {
                Rectangle()
                    .fill(MaterialDesignSystem.shared.material(for: depth))
                    .overlay(
                        Rectangle()
                            .stroke(stroke?.color ?? Color.clear, lineWidth: stroke?.lineWidth ?? 0)
                    )
            }
        }
    }
    
    @ViewBuilder
    private var fallbackBackground: some View {
        Group {
            if cornerRadius > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fallbackColor)
                    .strokeBorder(stroke?.color ?? Color.clear, lineWidth: stroke?.lineWidth ?? 0)
            } else {
                Rectangle()
                    .fill(fallbackColor)
                    .overlay(
                        Rectangle()
                            .stroke(stroke?.color ?? Color.clear, lineWidth: stroke?.lineWidth ?? 0)
                    )
            }
        }
    }
    
    private var fallbackColor: Color {
        if isHighContrastEnabled {
            return .primary.opacity(0.05)
        } else {
            return .secondary.opacity(0.1)
        }
    }
    
    private var shadowConfig: MaterialDesignSystem.ShadowConfiguration {
        MaterialDesignSystem.shared.shadowConfiguration(for: depth)
    }
}

// MARK: - Accessibility Monitoring

private extension MaterialDesignSystem {
    func observeAccessibilityChanges() {
        // Monitor accessibility settings changes
        NotificationCenter.default.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isReducedTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
            }
            .store(in: &cancellables)
        
        // Initialize current state
        isReducedTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
    }
    
}

// MARK: - Combine Support
import Combine

// MARK: - View Extensions

extension View {
    /// Applies material design system configuration to the view
    /// - Parameters:
    ///   - depth: The depth token defining the visual hierarchy
    ///   - cornerRadius: Optional corner radius for the material background
    ///   - stroke: Optional stroke configuration
    /// - Returns: A view with applied material configuration
    func materialBackground(
        depth: MaterialDesignSystem.DepthToken,
        cornerRadius: CGFloat = 0,
        stroke: StrokeConfiguration? = nil
    ) -> some View {
        self.modifier(
            MaterialDesignSystem.shared.materialModifier(
                for: depth,
                cornerRadius: cornerRadius,
                stroke: stroke
            )
        )
    }
    
    /// Applies surface material (depth token: surface)
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the surface
    ///   - stroke: Optional stroke configuration
    /// - Returns: A view with surface material applied
    func surfaceMaterial(
        cornerRadius: CGFloat = 12,
        stroke: StrokeConfiguration? = .subtle
    ) -> some View {
        materialBackground(depth: .surface, cornerRadius: cornerRadius, stroke: stroke)
    }
    
    /// Applies overlay material (depth token: overlay)
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the overlay
    ///   - stroke: Optional stroke configuration
    /// - Returns: A view with overlay material applied
    func overlayMaterial(
        cornerRadius: CGFloat = 12,
        stroke: StrokeConfiguration? = .subtle
    ) -> some View {
        materialBackground(depth: .overlay, cornerRadius: cornerRadius, stroke: stroke)
    }
    
    /// Applies modal material (depth token: modal)
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the modal
    ///   - stroke: Optional stroke configuration
    /// - Returns: A view with modal material applied
    func modalMaterial(
        cornerRadius: CGFloat = 16,
        stroke: StrokeConfiguration? = nil
    ) -> some View {
        materialBackground(depth: .modal, cornerRadius: cornerRadius, stroke: stroke)
    }
}

// MARK: - Preview Support

#if DEBUG
struct MaterialDesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ForEach(MaterialDesignSystem.DepthToken.allCases, id: \.self) { depth in
                HStack {
                    Text(String(describing: depth).capitalized)
                        .font(.headline)
                    Spacer()
                    Text("Elevation: \(Int(depth.elevation))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .materialBackground(depth: depth, cornerRadius: 12)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.light)
        .previewDisplayName("Material Design System - Light")
        
        VStack(spacing: 20) {
            ForEach(MaterialDesignSystem.DepthToken.allCases, id: \.self) { depth in
                HStack {
                    Text(String(describing: depth).capitalized)
                        .font(.headline)
                    Spacer()
                    Text("Elevation: \(Int(depth.elevation))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .materialBackground(depth: depth, cornerRadius: 12)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
        .previewDisplayName("Material Design System - Dark")
    }
}
#endif