import SwiftUI
import Combine

/// Comprehensive gesture state management service for coordinating complex gesture interactions
/// Provides centralized state management and conflict resolution for multiple simultaneous gestures
@MainActor
final class GestureStateManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var activeGestureStates: Set<GestureState> = []
    @Published private(set) var primaryGestureState: GestureState?
    @Published private(set) var gestureConflictResolution: ConflictResolution = .automatic
    @Published private(set) var transitionAnimationState: TransitionState = .idle
    
    // MARK: - Gesture State
    enum GestureState: Hashable {
        case idle
        case longPress(location: CGPoint, duration: TimeInterval)
        case swipe(direction: SwipeDirection, progress: Double)
        case pinch(scale: CGFloat, location: CGPoint)
        case rotation(angle: Angle, location: CGPoint)
        case drag(translation: CGSize, velocity: CGSize)
        case tap(location: CGPoint, count: Int)
        case pullToRefresh(progress: Double)
        case contextualMenu(visible: Bool, location: CGPoint)
        case batchSelection(active: Bool, selectedCount: Int)
        
        enum SwipeDirection {
            case up, down, left, right
        }
        
        var priority: Int {
            switch self {
            case .idle: return 0
            case .tap: return 1
            case .longPress: return 5
            case .swipe: return 4
            case .pinch: return 6
            case .rotation: return 6
            case .drag: return 3
            case .pullToRefresh: return 7
            case .contextualMenu: return 8
            case .batchSelection: return 9
            }
        }
        
        var isExclusive: Bool {
            switch self {
            case .contextualMenu(let visible, _): return visible
            case .batchSelection(let active, _): return active
            case .pullToRefresh: return true
            default: return false
            }
        }
    }
    
    // MARK: - Transition State
    enum TransitionState {
        case idle
        case entering(GestureState)
        case active(GestureState)
        case exiting(GestureState)
        case conflicted([GestureState])
    }
    
    // MARK: - Conflict Resolution
    enum ConflictResolution {
        case automatic
        case priorityBased
        case userChoice
        case firstGestureWins
        case lastGestureWins
    }
    
    // MARK: - Gesture Interaction Rules
    private struct InteractionRules {
        let canCoexist: Bool
        let requiresResolution: Bool
        let resolutionStrategy: ConflictResolution
        
        static let compatible = InteractionRules(canCoexist: true, requiresResolution: false, resolutionStrategy: .automatic)
        static let conflicting = InteractionRules(canCoexist: false, requiresResolution: true, resolutionStrategy: .priorityBased)
        static let exclusive = InteractionRules(canCoexist: false, requiresResolution: true, resolutionStrategy: .firstGestureWins)
    }
    
    // MARK: - Private Properties
    private var gestureStartTimes: [GestureState: Date] = [:]
    private var gestureTransitions: [GestureState: TransitionConfiguration] = [:]
    private let hapticService: HapticFeedbackService
    
    // MARK: - Transition Configuration
    private struct TransitionConfiguration {
        let animation: Animation
        let hapticPattern: HapticFeedbackService.HapticPattern?
        let completion: (() -> Void)?
        
        static let `default` = TransitionConfiguration(
            animation: .spring(response: 0.3, dampingFraction: 0.8),
            hapticPattern: .light,
            completion: nil
        )
        
        static let smooth = TransitionConfiguration(
            animation: .spring(response: 0.2, dampingFraction: 0.9),
            hapticPattern: nil,
            completion: nil
        )
        
        static let emphatic = TransitionConfiguration(
            animation: .spring(response: 0.4, dampingFraction: 0.7),
            hapticPattern: .medium,
            completion: nil
        )
    }
    
    // MARK: - Initialization
    init(hapticService: HapticFeedbackService) {
        self.hapticService = hapticService
        setupGestureTransitions()
    }
    
    // MARK: - Public Methods
    
    /// Registers a new gesture state
    /// - Parameters:
    ///   - gestureState: The gesture state to register
    ///   - force: Whether to force registration despite conflicts
    /// - Returns: Whether the gesture was successfully registered
    @discardableResult
    func registerGestureState(_ gestureState: GestureState, force: Bool = false) -> Bool {
        let currentTime = Date()
        
        // Check for conflicts
        if !force && hasConflicts(with: gestureState) {
            return resolveConflict(with: gestureState)
        }
        
        // Register the gesture
        gestureStartTimes[gestureState] = currentTime
        activeGestureStates.insert(gestureState)
        
        // Update primary gesture if this has higher priority
        updatePrimaryGesture()
        
        // Trigger transition
        triggerGestureTransition(to: gestureState)
        
        return true
    }
    
    /// Updates an existing gesture state
    /// - Parameters:
    ///   - oldState: The previous gesture state
    ///   - newState: The new gesture state
    func updateGestureState(from oldState: GestureState, to newState: GestureState) {
        guard activeGestureStates.contains(oldState) else { return }
        
        // Preserve start time
        if let startTime = gestureStartTimes[oldState] {
            gestureStartTimes[newState] = startTime
        }
        
        // Update state
        activeGestureStates.remove(oldState)
        activeGestureStates.insert(newState)
        gestureStartTimes.removeValue(forKey: oldState)
        
        // Update primary gesture
        updatePrimaryGesture()
        
        // Trigger transition
        triggerGestureTransition(from: oldState, to: newState)
    }
    
    /// Unregisters a gesture state
    /// - Parameter gestureState: The gesture state to unregister
    func unregisterGestureState(_ gestureState: GestureState) {
        activeGestureStates.remove(gestureState)
        gestureStartTimes.removeValue(forKey: gestureState)
        
        // Update primary gesture
        updatePrimaryGesture()
        
        // Trigger exit transition
        triggerGestureExit(from: gestureState)
    }
    
    /// Clears all gesture states
    func clearAllGestureStates() {
        let previousStates = activeGestureStates
        
        activeGestureStates.removeAll()
        gestureStartTimes.removeAll()
        primaryGestureState = nil
        
        // Trigger exit transitions for all previous states
        for state in previousStates {
            triggerGestureExit(from: state)
        }
        
        transitionAnimationState = .idle
    }
    
    /// Checks if a specific gesture type is currently active
    /// - Parameter gestureType: The gesture type to check
    /// - Returns: Whether the gesture is active
    func isGestureActive(_ gestureType: GestureState) -> Bool {
        return activeGestureStates.contains(gestureType)
    }
    
    /// Gets the duration of an active gesture
    /// - Parameter gestureState: The gesture state
    /// - Returns: Duration since the gesture started
    func getGestureDuration(_ gestureState: GestureState) -> TimeInterval? {
        guard let startTime = gestureStartTimes[gestureState] else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    /// Provides smooth animation for gesture transitions
    /// - Parameter gestureState: The gesture state
    /// - Returns: Appropriate animation for the gesture
    func animationForGesture(_ gestureState: GestureState) -> Animation {
        return gestureTransitions[gestureState]?.animation ?? .default
    }
    
    /// Creates coordinated gesture modifiers for a view
    /// - Parameters:
    ///   - view: The view to apply gestures to
    ///   - availableGestures: Available gesture types
    ///   - onGestureChange: Callback for gesture changes
    /// - Returns: View with coordinated gesture support
    func coordinatedGestureModifier<Content: View>(
        for view: Content,
        availableGestures: Set<GestureState>,
        onGestureChange: @escaping (GestureState, Bool) -> Void
    ) -> some View {
        view
            .onChange(of: activeGestureStates) { oldStates, newStates in
                for gesture in availableGestures {
                    let isActive = newStates.contains(gesture)
                    onGestureChange(gesture, isActive)
                }
            }
            .animation(
                primaryGestureState.map { animationForGesture($0) } ?? .default,
                value: activeGestureStates
            )
    }
    
    // MARK: - Private Methods
    
    private func setupGestureTransitions() {
        gestureTransitions = [
            .idle: .default,
            .tap(location: .zero, count: 1): .smooth,
            .longPress(location: .zero, duration: 0): .emphatic,
            .swipe(direction: .up, progress: 0): .smooth,
            .pinch(scale: 1.0, location: .zero): .smooth,
            .rotation(angle: .zero, location: .zero): .smooth,
            .drag(translation: .zero, velocity: .zero): .smooth,
            .pullToRefresh(progress: 0): .emphatic,
            .contextualMenu(visible: false, location: .zero): .emphatic,
            .batchSelection(active: false, selectedCount: 0): .emphatic
        ]
    }
    
    private func hasConflicts(with gestureState: GestureState) -> Bool {
        for activeState in activeGestureStates {
            let rules = getInteractionRules(between: activeState, and: gestureState)
            if !rules.canCoexist {
                return true
            }
        }
        return false
    }
    
    private func getInteractionRules(between state1: GestureState, and state2: GestureState) -> InteractionRules {
        // Define interaction rules between different gesture types
        switch (state1, state2) {
        case (.contextualMenu(let visible, _), _) where visible:
            return .exclusive
        case (_, .contextualMenu(let visible, _)) where visible:
            return .exclusive
        case (.batchSelection(let active, _), _) where active:
            return .exclusive
        case (_, .batchSelection(let active, _)) where active:
            return .exclusive
        case (.pullToRefresh, _), (_, .pullToRefresh):
            return .exclusive
        case (.pinch, .rotation), (.rotation, .pinch):
            return .compatible
        case (.longPress, .drag), (.drag, .longPress):
            return .conflicting
        case (.swipe, .drag), (.drag, .swipe):
            return .conflicting
        default:
            return .compatible
        }
    }
    
    private func resolveConflict(with newGestureState: GestureState) -> Bool {
        switch gestureConflictResolution {
        case .automatic:
            return resolveAutomatically(with: newGestureState)
        case .priorityBased:
            return resolvePriorityBased(with: newGestureState)
        case .firstGestureWins:
            return false // Reject new gesture
        case .lastGestureWins:
            clearConflictingGestures(with: newGestureState)
            return true
        case .userChoice:
            // In a real implementation, this would present a choice to the user
            return resolveAutomatically(with: newGestureState)
        }
    }
    
    private func resolveAutomatically(with newGestureState: GestureState) -> Bool {
        let conflictingStates = activeGestureStates.filter { state in
            !getInteractionRules(between: state, and: newGestureState).canCoexist
        }
        
        // If new gesture has higher priority, replace conflicting gestures
        let highestActivePriority = conflictingStates.map(\.priority).max() ?? 0
        if newGestureState.priority > highestActivePriority {
            for state in conflictingStates {
                unregisterGestureState(state)
            }
            return true
        }
        
        return false
    }
    
    private func resolvePriorityBased(with newGestureState: GestureState) -> Bool {
        let conflictingStates = activeGestureStates.filter { state in
            !getInteractionRules(between: state, and: newGestureState).canCoexist
        }
        
        for state in conflictingStates {
            if newGestureState.priority > state.priority {
                unregisterGestureState(state)
            } else {
                return false
            }
        }
        
        return true
    }
    
    private func clearConflictingGestures(with newGestureState: GestureState) {
        let conflictingStates = activeGestureStates.filter { state in
            !getInteractionRules(between: state, and: newGestureState).canCoexist
        }
        
        for state in conflictingStates {
            unregisterGestureState(state)
        }
    }
    
    private func updatePrimaryGesture() {
        primaryGestureState = activeGestureStates.max { $0.priority < $1.priority }
    }
    
    private func triggerGestureTransition(to newState: GestureState) {
        transitionAnimationState = .entering(newState)
        
        if let config = gestureTransitions[newState] {
            if let hapticPattern = config.hapticPattern {
                hapticService.triggerHaptic(hapticPattern)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.transitionAnimationState = .active(newState)
                config.completion?()
            }
        }
    }
    
    private func triggerGestureTransition(from oldState: GestureState, to newState: GestureState) {
        transitionAnimationState = .entering(newState)
        
        if let config = gestureTransitions[newState] {
            if let hapticPattern = config.hapticPattern {
                hapticService.triggerHaptic(hapticPattern, intensity: 0.5)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.transitionAnimationState = .active(newState)
            }
        }
    }
    
    private func triggerGestureExit(from state: GestureState) {
        transitionAnimationState = .exiting(state)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if self.activeGestureStates.isEmpty {
                self.transitionAnimationState = .idle
            }
        }
    }
}

// MARK: - SwiftUI Integration

/// View modifier for coordinated gesture state management
struct CoordinatedGestureModifier: ViewModifier {
    @ObservedObject var gestureStateManager: GestureStateManager
    let availableGestures: Set<GestureStateManager.GestureState>
    let onGestureChange: (GestureStateManager.GestureState, Bool) -> Void
    
    func body(content: Content) -> some View {
        gestureStateManager.coordinatedGestureModifier(
            for: content,
            availableGestures: availableGestures,
            onGestureChange: onGestureChange
        )
    }
}

// MARK: - View Extension
extension View {
    /// Adds coordinated gesture state management
    /// - Parameters:
    ///   - gestureStateManager: The gesture state manager
    ///   - availableGestures: Available gesture types
    ///   - onGestureChange: Callback for gesture state changes
    /// - Returns: View with coordinated gesture management
    func coordinatedGestures(
        manager gestureStateManager: GestureStateManager,
        availableGestures: Set<GestureStateManager.GestureState>,
        onGestureChange: @escaping (GestureStateManager.GestureState, Bool) -> Void = { _, _ in }
    ) -> some View {
        self.modifier(
            CoordinatedGestureModifier(
                gestureStateManager: gestureStateManager,
                availableGestures: availableGestures,
                onGestureChange: onGestureChange
            )
        )
    }
}