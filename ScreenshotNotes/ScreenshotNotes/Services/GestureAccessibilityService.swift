import SwiftUI
import Combine

/// Gesture accessibility service providing alternative interaction methods and accommodations
/// Ensures all gesture-based functionality is accessible to users with diverse abilities
@MainActor
final class GestureAccessibilityService: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isVoiceOverRunning: Bool = false
    @Published private(set) var isReduceMotionEnabled: Bool = false
    @Published private(set) var isAssistiveTouchEnabled: Bool = false
    @Published private(set) var preferredGestureTimeout: TimeInterval = 0.5
    
    // MARK: - Configuration
    struct AccessibilityConfiguration {
        let allowLongPressAlternatives: Bool
        let enableVoiceOverGestures: Bool
        let provideTapAlternatives: Bool
        let useExtendedGestureTimeouts: Bool
        let enableAudioFeedback: Bool
        let simplifyAnimations: Bool
        
        static let `default` = AccessibilityConfiguration(
            allowLongPressAlternatives: true,
            enableVoiceOverGestures: true,
            provideTapAlternatives: true,
            useExtendedGestureTimeouts: true,
            enableAudioFeedback: true,
            simplifyAnimations: true
        )
    }
    
    // MARK: - Alternative Action Types
    enum AlternativeActionType {
        case doubleTapForLongPress
        case singleTapWithHold
        case voiceOverCustomAction
        case buttonAlternative
        case keyboardShortcut
        case assistiveTouchGesture
    }
    
    // MARK: - Alternative Action
    struct AlternativeAction {
        let type: AlternativeActionType
        let title: String
        let description: String
        let action: () -> Void
        let accessibilityLabel: String
        let accessibilityHint: String?
        
        init(
            type: AlternativeActionType,
            title: String,
            description: String,
            action: @escaping () -> Void,
            accessibilityLabel: String? = nil,
            accessibilityHint: String? = nil
        ) {
            self.type = type
            self.title = title
            self.description = description
            self.action = action
            self.accessibilityLabel = accessibilityLabel ?? title
            self.accessibilityHint = accessibilityHint
        }
    }
    
    // MARK: - Private Properties
    private let configuration: AccessibilityConfiguration
    private var accessibilityNotificationCancellables: Set<AnyCancellable> = []
    
    // MARK: - Initialization
    init(configuration: AccessibilityConfiguration = .default) {
        self.configuration = configuration
        setupAccessibilityMonitoring()
        updateAccessibilityState()
    }
    
    // MARK: - Public Methods
    
    /// Creates alternative actions for a gesture-based interaction
    /// - Parameters:
    ///   - primaryAction: The main gesture action
    ///   - gestureType: The type of gesture being replaced
    ///   - context: Context description for accessibility
    /// - Returns: Array of alternative actions
    func createAlternativeActions(
        for primaryAction: @escaping () -> Void,
        gestureType: String,
        context: String
    ) -> [AlternativeAction] {
        var alternatives: [AlternativeAction] = []
        
        // Voice Over custom action
        if isVoiceOverRunning && configuration.enableVoiceOverGestures {
            alternatives.append(
                AlternativeAction(
                    type: .voiceOverCustomAction,
                    title: "Activate \(gestureType)",
                    description: "Perform \(gestureType) action on \(context)",
                    action: primaryAction,
                    accessibilityLabel: "Activate \(gestureType)",
                    accessibilityHint: "Double-tap to \(gestureType.lowercased()) \(context)"
                )
            )
        }
        
        // Button alternative for complex gestures
        if configuration.provideTapAlternatives {
            alternatives.append(
                AlternativeAction(
                    type: .buttonAlternative,
                    title: "\(gestureType) Button",
                    description: "Tap to perform \(gestureType) action",
                    action: primaryAction,
                    accessibilityLabel: "\(gestureType) \(context)",
                    accessibilityHint: "Activates \(gestureType.lowercased()) action"
                )
            )
        }
        
        // Extended timeout alternative for users who need more time
        if configuration.useExtendedGestureTimeouts {
            alternatives.append(
                AlternativeAction(
                    type: .singleTapWithHold,
                    title: "Tap and Hold",
                    description: "Tap and hold for extended time",
                    action: primaryAction,
                    accessibilityLabel: "Extended \(gestureType)",
                    accessibilityHint: "Hold for \(preferredGestureTimeout) seconds"
                )
            )
        }
        
        return alternatives
    }
    
    /// Provides accessible swipe alternatives
    /// - Parameters:
    ///   - swipeActions: Available swipe actions
    ///   - itemDescription: Description of the item being swiped
    /// - Returns: VoiceOver custom actions for each swipe option
    func createSwipeAlternatives(
        swipeActions: [AdvancedSwipeGestureService.SwipeAction],
        itemDescription: String
    ) -> [AccessibilityCustomAction] {
        return swipeActions.map { action in
            AccessibilityCustomAction(
                name: "\(action.title) \(itemDescription)",
                action: {
                    // Provide audio feedback if enabled
                    if configuration.enableAudioFeedback {
                        announceAction(action.title)
                    }
                    
                    action.action()
                    return true
                }
            )
        }
    }
    
    /// Adjusts gesture timing based on accessibility needs
    /// - Parameter baseTimeout: The default gesture timeout
    /// - Returns: Adjusted timeout for accessibility
    func adjustedGestureTimeout(_ baseTimeout: TimeInterval) -> TimeInterval {
        if configuration.useExtendedGestureTimeouts {
            return max(baseTimeout, preferredGestureTimeout)
        }
        return baseTimeout
    }
    
    /// Provides accessible description for gesture interactions
    /// - Parameters:
    ///   - gestureType: Type of gesture
    ///   - targetDescription: Description of the target
    ///   - availableActions: Available actions from the gesture
    /// - Returns: Comprehensive accessibility description
    func gestureAccessibilityDescription(
        gestureType: String,
        targetDescription: String,
        availableActions: [String]
    ) -> String {
        if isVoiceOverRunning {
            let actionsText = availableActions.joined(separator: ", ")
            return "\(targetDescription). \(gestureType) to access actions: \(actionsText)"
        } else {
            return "\(targetDescription). \(gestureType) for options."
        }
    }
    
    /// Creates accessibility-enhanced pull-to-refresh description
    /// - Returns: Accessible description for pull-to-refresh
    func pullToRefreshAccessibilityDescription() -> String {
        if isVoiceOverRunning {
            return "Pull down to refresh content. Alternative: use refresh button in navigation bar."
        } else {
            return "Pull to refresh"
        }
    }
    
    /// Provides animation settings based on accessibility preferences
    /// - Returns: Animation configuration respecting accessibility settings
    func accessibilityRespectingAnimation() -> Animation {
        if isReduceMotionEnabled && configuration.simplifyAnimations {
            return .linear(duration: 0.1)
        } else {
            return .spring(response: 0.3, dampingFraction: 0.8)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAccessibilityMonitoring() {
        // Monitor VoiceOver status
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateVoiceOverStatus()
            }
            .store(in: &accessibilityNotificationCancellables)
        
        // Monitor Reduce Motion preference
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateReduceMotionStatus()
            }
            .store(in: &accessibilityNotificationCancellables)
        
        // Monitor assistive touch
        NotificationCenter.default.publisher(for: UIAccessibility.assistiveTouchStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAssistiveTouchStatus()
            }
            .store(in: &accessibilityNotificationCancellables)
    }
    
    private func updateAccessibilityState() {
        updateVoiceOverStatus()
        updateReduceMotionStatus()
        updateAssistiveTouchStatus()
        updatePreferredGestureTimeout()
    }
    
    private func updateVoiceOverStatus() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    }
    
    private func updateReduceMotionStatus() {
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    }
    
    private func updateAssistiveTouchStatus() {
        isAssistiveTouchEnabled = UIAccessibility.isAssistiveTouchRunning
    }
    
    private func updatePreferredGestureTimeout() {
        // Adjust gesture timeout based on accessibility needs
        if isVoiceOverRunning || isAssistiveTouchEnabled {
            preferredGestureTimeout = 1.0 // Longer timeout for assistive technologies
        } else {
            preferredGestureTimeout = 0.5 // Standard timeout
        }
    }
    
    private func announceAction(_ actionName: String) {
        guard configuration.enableAudioFeedback else { return }
        
        let announcement = "\(actionName) activated"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

// MARK: - SwiftUI Integration

/// Accessibility-enhanced gesture modifier
struct AccessibleGestureModifier: ViewModifier {
    let gestureDescription: String
    let primaryAction: () -> Void
    let alternativeActions: [GestureAccessibilityService.AlternativeAction]
    
    @StateObject private var accessibilityService = GestureAccessibilityService()
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement()
            .accessibilityLabel(gestureDescription)
            .accessibilityHint("Double-tap to activate")
            .accessibilityActions {
                ForEach(alternativeActions.indices, id: \.self) { index in
                    let action = alternativeActions[index]
                    Button(action.title) {
                        action.action()
                    }
                    .accessibilityLabel(action.accessibilityLabel)
                    .accessibilityHint(action.accessibilityHint ?? "")
                }
            }
            .onTapGesture {
                primaryAction()
            }
    }
}

/// Accessible swipe gesture modifier
struct AccessibleSwipeGestureModifier: ViewModifier {
    let itemDescription: String
    let swipeActions: [AdvancedSwipeGestureService.SwipeAction]
    
    @StateObject private var accessibilityService = GestureAccessibilityService()
    
    func body(content: Content) -> some View {
        content
            .accessibilityCustomActions(
                accessibilityService.createSwipeAlternatives(
                    swipeActions: swipeActions,
                    itemDescription: itemDescription
                )
            )
            .accessibilityLabel(itemDescription)
            .accessibilityHint("Available actions: \(swipeActions.map(\.title).joined(separator: ", "))")
    }
}

// MARK: - View Extensions
extension View {
    /// Adds accessibility support for gesture interactions
    /// - Parameters:
    ///   - gestureDescription: Description of the gesture
    ///   - primaryAction: The main action to perform
    ///   - gestureType: Type of gesture for alternative creation
    ///   - context: Context for the gesture
    /// - Returns: View with accessibility enhancements
    func accessibleGesture(
        gestureDescription: String,
        primaryAction: @escaping () -> Void,
        gestureType: String = "gesture",
        context: String = "item"
    ) -> some View {
        let accessibilityService = GestureAccessibilityService()
        let alternativeActions = accessibilityService.createAlternativeActions(
            for: primaryAction,
            gestureType: gestureType,
            context: context
        )
        
        return self.modifier(
            AccessibleGestureModifier(
                gestureDescription: gestureDescription,
                primaryAction: primaryAction,
                alternativeActions: alternativeActions
            )
        )
    }
    
    /// Adds accessibility support for swipe gestures
    /// - Parameters:
    ///   - itemDescription: Description of the item being swiped
    ///   - swipeActions: Available swipe actions
    /// - Returns: View with swipe accessibility enhancements
    func accessibleSwipeGesture(
        itemDescription: String,
        swipeActions: [AdvancedSwipeGestureService.SwipeAction]
    ) -> some View {
        self.modifier(
            AccessibleSwipeGestureModifier(
                itemDescription: itemDescription,
                swipeActions: swipeActions
            )
        )
    }
    
    /// Applies accessibility-respecting animations
    /// - Returns: View with accessibility-appropriate animations
    func accessibilityRespectingAnimation() -> some View {
        let accessibilityService = GestureAccessibilityService()
        return self.animation(accessibilityService.accessibilityRespectingAnimation(), value: UUID())
    }
}