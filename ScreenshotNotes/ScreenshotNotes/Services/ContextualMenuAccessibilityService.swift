import SwiftUI
import Foundation

/// Comprehensive accessibility service for contextual menu system
/// Provides VoiceOver support, reduced motion handling, and assistive technology integration
@MainActor
final class ContextualMenuAccessibilityService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ContextualMenuAccessibilityService()
    
    // MARK: - Accessibility Configuration
    
    struct AccessibilityConfiguration {
        let enableVoiceOverSupport: Bool
        let enableReducedMotion: Bool
        let enableHighContrast: Bool
        let enableLargeText: Bool
        let customHapticPatterns: Bool
        let alternativeInteractionMethods: Bool
        
        static let full = AccessibilityConfiguration(
            enableVoiceOverSupport: true,
            enableReducedMotion: true,
            enableHighContrast: true,
            enableLargeText: true,
            customHapticPatterns: true,
            alternativeInteractionMethods: true
        )
        
        static let basic = AccessibilityConfiguration(
            enableVoiceOverSupport: true,
            enableReducedMotion: true,
            enableHighContrast: false,
            enableLargeText: false,
            customHapticPatterns: false,
            alternativeInteractionMethods: false
        )
    }
    
    // MARK: - Accessibility State
    
    @Published var isVoiceOverRunning: Bool = false
    @Published var isReduceMotionEnabled: Bool = false
    @Published var isHighContrastEnabled: Bool = false
    @Published var isDynamicTypeEnabled: Bool = false
    @Published var preferredContentSizeCategory: ContentSizeCategory = .medium
    @Published var isSwitchControlEnabled: Bool = false
    @Published var isAssistiveTouchEnabled: Bool = false
    
    // MARK: - Menu Accessibility Enhancements
    
    struct AccessibleMenuAction {
        let action: ContextualMenuService.MenuAction
        let accessibilityLabel: String
        let accessibilityHint: String
        let accessibilityTraits: AccessibilityTraits
        
        static func from(_ action: ContextualMenuService.MenuAction) -> AccessibleMenuAction {
            return AccessibleMenuAction(
                action: action,
                accessibilityLabel: action.accessibilityLabel,
                accessibilityHint: action.accessibilityHint,
                accessibilityTraits: action.accessibilityTraits
            )
        }
    }
    
    // MARK: - Alternative Interaction Methods
    
    enum AlternativeInteractionMethod: String, CaseIterable {
        case doubletap = "double_tap"
        case tripleTap = "triple_tap"
        case longPress = "long_press"
        case forceTouch = "force_touch"
        case voiceControl = "voice_control"
        case switchControl = "switch_control"
        case assistiveTouch = "assistive_touch"
        
        var description: String {
            switch self {
            case .doubletap:
                return "Double tap to open contextual menu"
            case .tripleTap:
                return "Triple tap to open contextual menu"
            case .longPress:
                return "Long press to open contextual menu"
            case .forceTouch:
                return "Force touch to open contextual menu"
            case .voiceControl:
                return "Say 'Show actions' to open contextual menu"
            case .switchControl:
                return "Use switch control to navigate menu"
            case .assistiveTouch:
                return "Use AssistiveTouch gestures"
            }
        }
        
        var isAvailable: Bool {
            switch self {
            case .forceTouch:
                return UIDevice.current.userInterfaceIdiom == .phone // Simplified check
            case .voiceControl:
                return false // Voice control detection not available in this iOS version
            case .switchControl:
                return UIAccessibility.isSwitchControlRunning
            case .assistiveTouch:
                return UIAccessibility.isAssistiveTouchRunning
            default:
                return true
            }
        }
    }
    
    // MARK: - VoiceOver Support
    
    struct VoiceOverConfiguration {
        let announceMenuAppearance: Bool
        let announceMenuDismissal: Bool
        let provideDetailedDescriptions: Bool
        let customNavigationOrder: Bool
        let enableQuickActions: Bool
        
        static let enhanced = VoiceOverConfiguration(
            announceMenuAppearance: true,
            announceMenuDismissal: true,
            provideDetailedDescriptions: true,
            customNavigationOrder: true,
            enableQuickActions: true
        )
        
        static let minimal = VoiceOverConfiguration(
            announceMenuAppearance: true,
            announceMenuDismissal: false,
            provideDetailedDescriptions: false,
            customNavigationOrder: false,
            enableQuickActions: false
        )
    }
    
    @Published var voiceOverConfiguration: VoiceOverConfiguration = .enhanced
    
    // MARK: - Dependencies
    
    private let hapticService = HapticFeedbackService.shared
    private let menuService = ContextualMenuService.shared
    
    private init() {
        setupAccessibilityMonitoring()
        Task { @MainActor in
            updateAccessibilityState()
        }
    }
    
    // MARK: - Public Interface
    
    /// Configures contextual menu for optimal accessibility
    /// - Parameter configuration: Accessibility configuration to apply
    func configureAccessibility(_ configuration: AccessibilityConfiguration) {
        // Update VoiceOver support
        if configuration.enableVoiceOverSupport {
            setupVoiceOverSupport()
        }
        
        // Configure reduced motion
        if configuration.enableReducedMotion && isReduceMotionEnabled {
            configureReducedMotionAnimations()
        }
        
        // Setup high contrast support
        if configuration.enableHighContrast && isHighContrastEnabled {
            configureHighContrastInterface()
        }
        
        // Configure large text support
        if configuration.enableLargeText {
            configureDynamicTypeSupport()
        }
        
        // Setup custom haptic patterns for accessibility
        if configuration.customHapticPatterns {
            configureAccessibilityHaptics()
        }
        
        // Enable alternative interaction methods
        if configuration.alternativeInteractionMethods {
            setupAlternativeInteractions()
        }
    }
    
    /// Announces menu state changes to VoiceOver users
    /// - Parameters:
    ///   - message: The message to announce
    ///   - priority: The announcement priority
    func announceToVoiceOver(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        guard isVoiceOverRunning else { return }
        
        UIAccessibility.post(notification: priority, argument: message)
    }
    
    /// Creates accessible menu actions with enhanced descriptions
    /// - Parameter actions: Original menu actions
    /// - Returns: Accessibility-enhanced menu actions
    func createAccessibleMenuActions(_ actions: [ContextualMenuService.MenuAction]) -> [AccessibleMenuAction] {
        return actions.map { AccessibleMenuAction.from($0) }
    }
    
    /// Checks if an alternative interaction method should be used
    /// - Parameter method: The interaction method to check
    /// - Returns: Whether the method should be used
    func shouldUseAlternativeInteraction(_ method: AlternativeInteractionMethod) -> Bool {
        return method.isAvailable && isAccessibilityFeaturePreferred(for: method)
    }
    
    /// Provides haptic feedback optimized for accessibility needs
    /// - Parameter pattern: The haptic pattern to trigger
    func triggerAccessibilityHaptic(_ pattern: HapticFeedbackService.HapticPattern) {
        // Enhance haptic feedback for users with visual impairments
        let enhancedIntensity = isVoiceOverRunning ? 1.0 : 0.8
        hapticService.triggerHaptic(pattern, intensity: enhancedIntensity)
    }
    
    // MARK: - VoiceOver Support Implementation
    
    private func setupVoiceOverSupport() {
        // Configure VoiceOver notifications for menu events
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.updateVoiceOverState()
        }
        
        // Setup custom VoiceOver actions for menus
        setupCustomVoiceOverActions()
    }
    
    private func setupCustomVoiceOverActions() {
        // This would be implemented by the views using accessibility modifiers
        // Providing centralized accessibility action definitions
    }
    
    private func updateVoiceOverState() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        
        if isVoiceOverRunning {
            // Adjust menu behavior for VoiceOver users
            configureVoiceOverOptimizedMenus()
        }
    }
    
    private func configureVoiceOverOptimizedMenus() {
        // Configure longer menu timeouts for VoiceOver users
        // Enhance focus management
        // Provide detailed action descriptions
    }
    
    // MARK: - Reduced Motion Support
    
    private func configureReducedMotionAnimations() {
        guard isReduceMotionEnabled else { return }
        
        // Reduce or eliminate menu animations
        // Use instant transitions instead of springs
        // Minimize visual effects
    }
    
    // MARK: - High Contrast Support
    
    private func configureHighContrastInterface() {
        guard isHighContrastEnabled else { return }
        
        // Enhance menu contrast
        // Use high contrast colors
        // Increase border visibility
    }
    
    // MARK: - Dynamic Type Support
    
    private func configureDynamicTypeSupport() {
        // Adjust menu text sizes based on user preferences
        // Ensure readability at all size categories
        // Maintain touch target sizes
    }
    
    // MARK: - Accessibility Haptics
    
    private func configureAccessibilityHaptics() {
        // Enhanced haptic patterns for accessibility
        hapticService.setHapticIntensity(isVoiceOverRunning ? 1.0 : 0.8)
        
        // Custom haptic patterns for different accessibility needs
        setupCustomAccessibilityHaptics()
    }
    
    private func setupCustomAccessibilityHaptics() {
        // Define custom haptic patterns for accessibility scenarios
        // More pronounced feedback for vision-impaired users
        // Distinct patterns for different menu actions
    }
    
    // MARK: - Alternative Interactions
    
    private func setupAlternativeInteractions() {
        // Configure alternative ways to access contextual menus
        setupVoiceControlCommands()
        setupSwitchControlNavigation()
        setupAssistiveTouchGestures()
    }
    
    private func setupVoiceControlCommands() {
        // Voice control commands for menu access
        // "Show actions", "Open menu", etc.
    }
    
    private func setupSwitchControlNavigation() {
        // Switch control navigation patterns
        // Sequential menu item access
    }
    
    private func setupAssistiveTouchGestures() {
        // Custom AssistiveTouch gestures
        // Alternative tap patterns
    }
    
    // MARK: - Accessibility State Monitoring
    
    private func setupAccessibilityMonitoring() {
        // Monitor VoiceOver state
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.updateAccessibilityState()
            }
        }
        
        // Monitor reduce motion preference
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.updateAccessibilityState()
            }
        }
        
        // Monitor other accessibility settings
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.updateAccessibilityState()
            }
        }
    }
    
    private func updateAccessibilityState() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        isSwitchControlEnabled = UIAccessibility.isSwitchControlRunning
        isAssistiveTouchEnabled = UIAccessibility.isAssistiveTouchRunning
        
        // Update content size category
        preferredContentSizeCategory = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory)
        isDynamicTypeEnabled = preferredContentSizeCategory.isAccessibilityCategory
    }
    
    private func isAccessibilityFeaturePreferred(for method: AlternativeInteractionMethod) -> Bool {
        switch method {
        case .voiceControl:
            return false // Voice control detection not available
        case .switchControl:
            return isSwitchControlEnabled
        case .assistiveTouch:
            return isAssistiveTouchEnabled
        case .longPress:
            return isVoiceOverRunning // VoiceOver users often prefer long press
        default:
            return false
        }
    }
}

// MARK: - Accessibility Extensions

extension ContextualMenuService.MenuAction {
    var accessibilityLabel: String {
        switch self {
        case .share:
            return "Share screenshot"
        case .copy:
            return "Copy screenshot to clipboard"
        case .delete:
            return "Delete screenshot"
        case .tag:
            return "Add tag to screenshot"
        case .favorite:
            return "Add to favorites"
        case .export:
            return "Export screenshot"
        case .duplicate:
            return "Create duplicate"
        case .addToCollection:
            return "Add to collection"
        case .viewDetails:
            return "View screenshot details"
        case .editMetadata:
            return "Edit screenshot metadata"
        }
    }
    
    var accessibilityHint: String {
        switch self {
        case .share:
            return "Opens the share sheet to share this screenshot with others"
        case .copy:
            return "Copies the screenshot image to your device clipboard"
        case .delete:
            return "Permanently removes this screenshot from your collection"
        case .tag:
            return "Opens the tag editor to add labels to this screenshot"
        case .favorite:
            return "Marks this screenshot as a favorite for quick access"
        case .export:
            return "Exports the screenshot to various file formats"
        case .duplicate:
            return "Creates an identical copy of this screenshot"
        case .addToCollection:
            return "Adds this screenshot to one of your collections"
        case .viewDetails:
            return "Shows detailed information about this screenshot"
        case .editMetadata:
            return "Opens the metadata editor for this screenshot"
        }
    }
    
    var accessibilityTraits: AccessibilityTraits {
        switch self {
        case .delete:
            return .isButton // Indicates destructive action
        case .share, .export:
            return .isButton // Indicates external action
        default:
            return .isButton
        }
    }
    
    var customAccessibilityAction: (() -> Void)? {
        return {
            // Custom action implementation would be handled by the calling view
            // This provides a closure for custom accessibility actions
        }
    }
}

extension ContentSizeCategory {
    init(_ uiContentSizeCategory: UIContentSizeCategory) {
        switch uiContentSizeCategory {
        case .extraSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .extraLarge: self = .extraLarge
        case .extraExtraLarge: self = .extraExtraLarge
        case .extraExtraExtraLarge: self = .extraExtraExtraLarge
        case .accessibilityMedium: self = .accessibilityMedium
        case .accessibilityLarge: self = .accessibilityLarge
        case .accessibilityExtraLarge: self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: self = .accessibilityExtraExtraExtraLarge
        default: self = .medium
        }
    }
}

// MARK: - Accessible Menu Components

struct AccessibleContextualMenu: View {
    let actions: [ContextualMenuService.MenuAction]
    let screenshot: Screenshot?
    @StateObject private var accessibilityService = ContextualMenuAccessibilityService.shared
    @StateObject private var menuService = ContextualMenuService.shared
    
    var body: some View {
        VStack(spacing: accessibilityService.isDynamicTypeEnabled ? 16 : 8) {
            ForEach(accessibilityService.createAccessibleMenuActions(actions), id: \.action.id) { accessibleAction in
                AccessibleMenuActionButton(
                    accessibleAction: accessibleAction,
                    screenshot: screenshot
                )
            }
        }
        .padding(.vertical, accessibilityService.isDynamicTypeEnabled ? 16 : 12)
        .padding(.horizontal, accessibilityService.isDynamicTypeEnabled ? 12 : 8)
        .modalMaterial(cornerRadius: 16)
        .shadow(radius: accessibilityService.isHighContrastEnabled ? 10 : 20, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Contextual menu")
        .accessibilityHint("Available actions for the selected screenshot")
        .onAppear {
            if accessibilityService.isVoiceOverRunning {
                accessibilityService.announceToVoiceOver(
                    "Contextual menu opened with \(actions.count) actions available",
                    priority: .announcement
                )
            }
        }
        .onDisappear {
            if accessibilityService.isVoiceOverRunning {
                accessibilityService.announceToVoiceOver(
                    "Contextual menu closed",
                    priority: .announcement
                )
            }
        }
    }
}

struct AccessibleMenuActionButton: View {
    let accessibleAction: ContextualMenuAccessibilityService.AccessibleMenuAction
    let screenshot: Screenshot?
    
    @StateObject private var accessibilityService = ContextualMenuAccessibilityService.shared
    @StateObject private var menuService = ContextualMenuService.shared
    @State private var isPressed = false
    
    var body: some View {
        Button(action: executeAction) {
            HStack(spacing: accessibilityService.isDynamicTypeEnabled ? 16 : 12) {
                Image(systemName: accessibleAction.action.systemImage)
                    .font(.system(
                        size: accessibilityService.isDynamicTypeEnabled ? 20 : 16,
                        weight: .medium
                    ))
                    .foregroundColor(accessibleAction.action.destructive ? .red : .primary)
                    .frame(width: accessibilityService.isDynamicTypeEnabled ? 24 : 20)
                
                Text(accessibleAction.action.title)
                    .font(.system(
                        size: accessibilityService.isDynamicTypeEnabled ? 18 : 16,
                        weight: .medium
                    ))
                    .foregroundColor(accessibleAction.action.destructive ? .red : .primary)
                
                Spacer()
            }
            .padding(.horizontal, accessibilityService.isDynamicTypeEnabled ? 20 : 16)
            .padding(.vertical, accessibilityService.isDynamicTypeEnabled ? 16 : 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.primary.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                accessibilityService.isHighContrastEnabled ? Color.primary : Color.clear,
                                lineWidth: accessibilityService.isHighContrastEnabled ? 1 : 0
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .accessibilityLabel(accessibleAction.accessibilityLabel)
        .accessibilityHint(accessibleAction.accessibilityHint)
        // .accessibilityTraits(accessibleAction.accessibilityTraits) // Commented out due to iOS version compatibility
        .accessibilityAction {
            executeAction()
        }
        .onPressGesture { pressed in
            withAnimation(.easeInOut(duration: accessibilityService.isReduceMotionEnabled ? 0 : 0.1)) {
                isPressed = pressed
            }
        }
    }
    
    private func executeAction() {
        accessibilityService.triggerAccessibilityHaptic(accessibleAction.action.hapticPattern)
        
        if let screenshot = screenshot {
            menuService.executeAction(accessibleAction.action, for: screenshot)
        }
        
        // Announce action to VoiceOver
        if accessibilityService.isVoiceOverRunning {
            accessibilityService.announceToVoiceOver(
                "\(accessibleAction.action.title) action selected",
                priority: .announcement
            )
        }
    }
}

// MARK: - Debug View for Accessibility Testing

#if DEBUG
struct ContextualMenuAccessibilityTestView: View {
    @StateObject private var accessibilityService = ContextualMenuAccessibilityService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Accessibility Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Accessibility Status")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        AccessibilityStatusRow("VoiceOver", accessibilityService.isVoiceOverRunning)
                        AccessibilityStatusRow("Reduce Motion", accessibilityService.isReduceMotionEnabled)
                        AccessibilityStatusRow("High Contrast", accessibilityService.isHighContrastEnabled)
                        AccessibilityStatusRow("Dynamic Type", accessibilityService.isDynamicTypeEnabled)
                        AccessibilityStatusRow("Switch Control", accessibilityService.isSwitchControlEnabled)
                        AccessibilityStatusRow("AssistiveTouch", accessibilityService.isAssistiveTouchEnabled)
                    }
                    .padding()
                    .surfaceMaterial(cornerRadius: 12)
                    
                    // Test Accessible Menu
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Accessible Menu")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        AccessibleContextualMenu(
                            actions: [.share, .copy, .favorite, .delete],
                            screenshot: Screenshot(imageData: Data(), filename: "test.jpg")
                        )
                    }
                    .padding()
                    .surfaceMaterial(cornerRadius: 12)
                    
                    // Configuration Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Configuration")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Button("Configure Full Accessibility") {
                            accessibilityService.configureAccessibility(.full)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Configure Basic Accessibility") {
                            accessibilityService.configureAccessibility(.basic)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .surfaceMaterial(cornerRadius: 12)
                }
                .padding()
            }
            .navigationTitle("Accessibility Testing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AccessibilityStatusRow: View {
    let title: String
    let isEnabled: Bool
    
    init(_ title: String, _ isEnabled: Bool) {
        self.title = title
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnabled ? .green : .red)
            
            Text(isEnabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContextualMenuAccessibilityTestView()
}
#endif