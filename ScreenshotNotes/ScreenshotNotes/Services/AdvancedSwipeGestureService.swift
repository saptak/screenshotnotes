import SwiftUI
import Combine

/// Advanced swipe gesture service providing contextual swipe actions with fluid animations
/// Supports multiple swipe directions and customizable action sets
@MainActor
final class AdvancedSwipeGestureService: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var activeSwipeState: SwipeState = .idle
    @Published private(set) var swipeProgress: Double = 0.0
    @Published private(set) var revealedAction: SwipeAction?
    
    // MARK: - Private Properties
    private let hapticService: HapticFeedbackService
    private let actionThreshold: Double = 80.0
    private let maxRevealDistance: Double = 120.0
    private var lastHapticThreshold: Double = 0.0
    
    // MARK: - Swipe State
    enum SwipeState {
        case idle
        case swiping(direction: SwipeDirection)
        case actionRevealed(SwipeAction)
        case actionTriggered(SwipeAction)
        case completing
    }
    
    // MARK: - Swipe Direction
    enum SwipeDirection {
        case left
        case right
        case up
        case down
        
        var isHorizontal: Bool {
            switch self {
            case .left, .right: return true
            case .up, .down: return false
            }
        }
    }
    
    // MARK: - Swipe Action
    struct SwipeAction: Identifiable, Equatable {
        let id = UUID()
        let type: ActionType
        let icon: String
        let title: String
        let color: Color
        let direction: SwipeDirection
        let action: () -> Void
        
        enum ActionType {
            case share
            case copy
            case favorite
            case unfavorite
            case tag
            case delete
            case archive
            case duplicate
            case export
            case info
        }
        
        static func == (lhs: SwipeAction, rhs: SwipeAction) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // MARK: - Initialization
    init(hapticService: HapticFeedbackService) {
        self.hapticService = hapticService
    }
    
    // MARK: - Public Methods
    
    /// Updates swipe gesture state based on drag translation
    /// - Parameters:
    ///   - translation: The drag translation
    ///   - availableActions: Available swipe actions for the current context
    func updateSwipeState(translation: CGSize, availableActions: [SwipeAction]) {
        let direction = determineSwipeDirection(translation: translation)
        let progress = calculateSwipeProgress(translation: translation, direction: direction)
        
        // Update progress
        swipeProgress = progress
        
        // Determine revealed action
        let newRevealedAction = determineRevealedAction(
            direction: direction,
            progress: progress,
            availableActions: availableActions
        )
        
        // Update state
        updateSwipeState(direction: direction, progress: progress, revealedAction: newRevealedAction)
        
        // Trigger haptic feedback
        triggerProgressHaptics(progress: progress, revealedAction: newRevealedAction)
    }
    
    /// Completes the swipe gesture, executing action if threshold is met
    /// - Parameter translation: The final drag translation
    func completeSwipe(translation: CGSize) {
        let direction = determineSwipeDirection(translation: translation)
        let progress = calculateSwipeProgress(translation: translation, direction: direction)
        
        if progress >= 1.0, let action = revealedAction {
            // Execute action
            activeSwipeState = .actionTriggered(action)
            triggerActionHaptic(action.type)
            
            // Execute action after brief delay for visual feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action.action()
                self.resetSwipeState()
            }
        } else {
            // Reset to idle
            resetSwipeState()
        }
    }
    
    /// Cancels the current swipe gesture
    func cancelSwipe() {
        resetSwipeState()
    }
    
    /// Resets swipe state to idle
    func resetSwipeState() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            activeSwipeState = .idle
            swipeProgress = 0.0
            revealedAction = nil
        }
        lastHapticThreshold = 0.0
    }
    
    // MARK: - Action Factories
    
    /// Creates standard swipe actions for screenshots
    /// - Parameters:
    ///   - isFavorite: Whether the item is currently favorited
    ///   - onShare: Share action handler
    ///   - onCopy: Copy action handler
    ///   - onFavorite: Favorite toggle action handler
    ///   - onTag: Tag action handler
    ///   - onDelete: Delete action handler
    ///   - onArchive: Archive action handler
    /// - Returns: Array of configured swipe actions
    func createScreenshotActions(
        isFavorite: Bool = false,
        onShare: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onFavorite: @escaping () -> Void,
        onTag: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onArchive: @escaping () -> Void
    ) -> [SwipeAction] {
        return [
            SwipeAction(
                type: .share,
                icon: "square.and.arrow.up",
                title: "Share",
                color: .blue,
                direction: .right,
                action: onShare
            ),
            SwipeAction(
                type: .copy,
                icon: "doc.on.doc",
                title: "Copy",
                color: .green,
                direction: .right,
                action: onCopy
            ),
            SwipeAction(
                type: isFavorite ? .unfavorite : .favorite,
                icon: isFavorite ? "heart.fill" : "heart",
                title: isFavorite ? "Unfavorite" : "Favorite",
                color: .pink,
                direction: .left,
                action: onFavorite
            ),
            SwipeAction(
                type: .tag,
                icon: "tag",
                title: "Tag",
                color: .orange,
                direction: .left,
                action: onTag
            ),
            SwipeAction(
                type: .archive,
                icon: "archivebox",
                title: "Archive",
                color: .purple,
                direction: .down,
                action: onArchive
            ),
            SwipeAction(
                type: .delete,
                icon: "trash",
                title: "Delete",
                color: .red,
                direction: .down,
                action: onDelete
            )
        ]
    }
    
    // MARK: - Private Methods
    
    private func determineSwipeDirection(translation: CGSize) -> SwipeDirection? {
        let absX = abs(translation.x)
        let absY = abs(translation.y)
        
        // Minimum threshold to register as swipe
        guard max(absX, absY) > 10 else { return nil }
        
        // Determine primary direction
        if absX > absY {
            return translation.x > 0 ? .right : .left
        } else {
            return translation.y > 0 ? .down : .up
        }
    }
    
    private func calculateSwipeProgress(translation: CGSize, direction: SwipeDirection?) -> Double {
        guard let direction = direction else { return 0.0 }
        
        let distance: Double
        switch direction {
        case .left:
            distance = max(0, -translation.x)
        case .right:
            distance = max(0, translation.x)
        case .up:
            distance = max(0, -translation.y)
        case .down:
            distance = max(0, translation.y)
        }
        
        return min(distance / actionThreshold, 1.5)
    }
    
    private func determineRevealedAction(
        direction: SwipeDirection?,
        progress: Double,
        availableActions: [SwipeAction]
    ) -> SwipeAction? {
        guard let direction = direction, progress > 0.2 else { return nil }
        
        return availableActions.first { $0.direction == direction }
    }
    
    private func updateSwipeState(direction: SwipeDirection?, progress: Double, revealedAction: SwipeAction?) {
        let newState: SwipeState
        
        if let action = revealedAction, progress >= 1.0 {
            newState = .actionRevealed(action)
        } else if let direction = direction, progress > 0.1 {
            newState = .swiping(direction: direction)
        } else {
            newState = .idle
        }
        
        if case .actionTriggered = activeSwipeState {
            // Don't change state if action is being triggered
            return
        }
        
        activeSwipeState = newState
        self.revealedAction = revealedAction
    }
    
    private func triggerProgressHaptics(progress: Double, revealedAction: SwipeAction?) {
        let thresholds: [Double] = [0.3, 0.6, 1.0]
        
        for threshold in thresholds {
            if progress >= threshold && lastHapticThreshold < threshold {
                let intensity = 0.3 + (threshold * 0.4)
                
                if threshold >= 1.0 && revealedAction != nil {
                    hapticService.triggerHaptic(.medium, intensity: 0.8)
                } else {
                    hapticService.triggerHaptic(.light, intensity: intensity)
                }
                
                lastHapticThreshold = threshold
                break
            }
        }
        
        // Reset haptic threshold when swiping back
        if progress < lastHapticThreshold - 0.2 {
            lastHapticThreshold = max(0.0, progress)
        }
    }
    
    private func triggerActionHaptic(_ actionType: SwipeAction.ActionType) {
        switch actionType {
        case .delete:
            hapticService.triggerHaptic(.error, intensity: 0.8)
        case .favorite, .unfavorite:
            hapticService.triggerHaptic(.success, intensity: 0.7)
        case .share, .copy, .export:
            hapticService.triggerHaptic(.success, intensity: 0.6)
        case .tag, .archive, .duplicate, .info:
            hapticService.triggerHaptic(.medium, intensity: 0.5)
        }
    }
}

// MARK: - SwiftUI Integration

/// Swipe gesture modifier with customizable actions and animations
struct SwipeGestureModifier: ViewModifier {
    let availableActions: [AdvancedSwipeGestureService.SwipeAction]
    @StateObject private var swipeService: AdvancedSwipeGestureService
    @State private var dragOffset: CGSize = .zero
    
    init(availableActions: [AdvancedSwipeGestureService.SwipeAction], hapticService: HapticFeedbackService) {
        self.availableActions = availableActions
        self._swipeService = StateObject(wrappedValue: AdvancedSwipeGestureService(hapticService: hapticService))
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset.x * 0.3, y: dragOffset.y * 0.3)
            .scaleEffect(1.0 - (abs(dragOffset.x) + abs(dragOffset.y)) * 0.0002)
            .background(
                SwipeActionBackground(
                    revealedAction: swipeService.revealedAction,
                    progress: swipeService.swipeProgress
                )
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                        swipeService.updateSwipeState(
                            translation: value.translation,
                            availableActions: availableActions
                        )
                    }
                    .onEnded { value in
                        swipeService.completeSwipe(translation: value.translation)
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipeService.swipeProgress)
    }
}

// MARK: - Swipe Action Background
private struct SwipeActionBackground: View {
    let revealedAction: AdvancedSwipeGestureService.SwipeAction?
    let progress: Double
    
    var body: some View {
        if let action = revealedAction {
            HStack {
                if action.direction == .right {
                    Spacer()
                }
                
                actionIndicator(action)
                    .scaleEffect(0.8 + (progress * 0.4))
                    .opacity(min(progress * 2, 1.0))
                
                if action.direction == .left {
                    Spacer()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(action.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(action.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    private func actionIndicator(_ action: AdvancedSwipeGestureService.SwipeAction) -> some View {
        VStack(spacing: 4) {
            Image(systemName: action.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(action.color)
            
            Text(action.title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(action.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - View Extension
extension View {
    /// Adds advanced swipe gesture functionality with customizable actions
    /// - Parameters:
    ///   - actions: Available swipe actions
    ///   - hapticService: Haptic feedback service
    /// - Returns: View with swipe gesture support
    func advancedSwipeGesture(
        actions: [AdvancedSwipeGestureService.SwipeAction],
        hapticService: HapticFeedbackService
    ) -> some View {
        self.modifier(SwipeGestureModifier(availableActions: actions, hapticService: hapticService))
    }
}