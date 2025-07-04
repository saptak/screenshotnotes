import SwiftUI
import Combine

/// Multi-touch gesture service providing advanced gesture recognition and simultaneous interaction support
/// Handles complex gesture combinations with accessibility considerations
@MainActor
final class MultiTouchGestureService: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var activeGestures: Set<GestureType> = []
    @Published private(set) var gestureState: GestureState = .idle
    @Published private(set) var multiTouchCount: Int = 0
    
    // MARK: - Private Properties
    private let hapticService: HapticFeedbackService
    private var gestureStartTime: Date?
    private var lastGestureEndTime: Date?
    private let doubleTapTimeWindow: TimeInterval = 0.5
    private let longPressMinimumDuration: TimeInterval = 0.6
    
    // MARK: - Gesture Types
    enum GestureType: Hashable {
        case singleTap
        case doubleTap
        case longPress
        case twoFingerTap
        case threeFingerTap
        case pinch
        case rotation
        case pan
        case swipe(direction: SwipeDirection)
        case force3DTouch
        
        enum SwipeDirection {
            case up, down, left, right
        }
    }
    
    // MARK: - Gesture State
    enum GestureState {
        case idle
        case recognizing(GestureType)
        case active(Set<GestureType>)
        case completed(GestureType)
        case cancelled
    }
    
    // MARK: - Gesture Result
    struct GestureResult {
        let type: GestureType
        let location: CGPoint
        let translation: CGSize
        let velocity: CGSize
        let scale: CGFloat
        let rotation: Angle
        let timestamp: Date
        
        init(
            type: GestureType,
            location: CGPoint = .zero,
            translation: CGSize = .zero,
            velocity: CGSize = .zero,
            scale: CGFloat = 1.0,
            rotation: Angle = .zero
        ) {
            self.type = type
            self.location = location
            self.translation = translation
            self.velocity = velocity
            self.scale = scale
            self.rotation = rotation
            self.timestamp = Date()
        }
    }
    
    // MARK: - Action Handlers
    typealias GestureHandler = (GestureResult) -> Void
    
    private var gestureHandlers: [GestureType: GestureHandler] = [:]
    
    // MARK: - Initialization
    init(hapticService: HapticFeedbackService) {
        self.hapticService = hapticService
    }
    
    // MARK: - Public Methods
    
    /// Registers a handler for a specific gesture type
    /// - Parameters:
    ///   - gestureType: The gesture type to handle
    ///   - handler: The handler function to execute
    func registerGestureHandler(_ gestureType: GestureType, handler: @escaping GestureHandler) {
        gestureHandlers[gestureType] = handler
    }
    
    /// Removes a gesture handler
    /// - Parameter gestureType: The gesture type to remove
    func removeGestureHandler(_ gestureType: GestureType) {
        gestureHandlers.removeValue(forKey: gestureType)
    }
    
    /// Processes a tap gesture with multi-tap detection
    /// - Parameters:
    ///   - location: The tap location
    ///   - touchCount: Number of simultaneous touches
    func processTapGesture(location: CGPoint, touchCount: Int = 1) {
        let currentTime = Date()
        multiTouchCount = touchCount
        
        let gestureType: GestureType
        
        switch touchCount {
        case 1:
            gestureType = isDoubleTap(at: currentTime) ? .doubleTap : .singleTap
        case 2:
            gestureType = .twoFingerTap
        case 3:
            gestureType = .threeFingerTap
        default:
            gestureType = .singleTap
        }
        
        executeGesture(gestureType, at: location)
        lastGestureEndTime = currentTime
    }
    
    /// Processes a long press gesture
    /// - Parameters:
    ///   - location: The press location
    ///   - duration: The press duration
    func processLongPressGesture(location: CGPoint, duration: TimeInterval) {
        guard duration >= longPressMinimumDuration else { return }
        
        executeGesture(.longPress, at: location)
        triggerHaptic(.longPress)
    }
    
    /// Processes a drag gesture with velocity tracking
    /// - Parameters:
    ///   - translation: The drag translation
    ///   - velocity: The drag velocity
    ///   - location: The current location
    func processDragGesture(translation: CGSize, velocity: CGSize, location: CGPoint) {
        let gestureType: GestureType = .pan
        
        updateGestureState(.active([gestureType]))
        
        let result = GestureResult(
            type: gestureType,
            location: location,
            translation: translation,
            velocity: velocity
        )
        
        gestureHandlers[gestureType]?(result)
    }
    
    /// Processes a swipe gesture with direction detection
    /// - Parameters:
    ///   - translation: The swipe translation
    ///   - velocity: The swipe velocity
    ///   - location: The swipe location
    func processSwipeGesture(translation: CGSize, velocity: CGSize, location: CGPoint) {
        let direction = determineSwipeDirection(translation: translation, velocity: velocity)
        let gestureType: GestureType = .swipe(direction: direction)
        
        executeGesture(gestureType, at: location, translation: translation, velocity: velocity)
        triggerHaptic(direction)
    }
    
    /// Processes a pinch gesture
    /// - Parameters:
    ///   - scale: The pinch scale
    ///   - location: The pinch center location
    func processPinchGesture(scale: CGFloat, location: CGPoint) {
        let gestureType: GestureType = .pinch
        
        updateGestureState(.active([gestureType]))
        
        let result = GestureResult(
            type: gestureType,
            location: location,
            scale: scale
        )
        
        gestureHandlers[gestureType]?(result)
    }
    
    /// Processes a rotation gesture
    /// - Parameters:
    ///   - rotation: The rotation angle
    ///   - location: The rotation center location
    func processRotationGesture(rotation: Angle, location: CGPoint) {
        let gestureType: GestureType = .rotation
        
        updateGestureState(.active([gestureType]))
        
        let result = GestureResult(
            type: gestureType,
            location: location,
            rotation: rotation
        )
        
        gestureHandlers[gestureType]?(result)
    }
    
    /// Processes simultaneous gestures (e.g., pinch + rotation)
    /// - Parameters:
    ///   - scale: The pinch scale
    ///   - rotation: The rotation angle
    ///   - location: The gesture center location
    func processSimultaneousGestures(scale: CGFloat, rotation: Angle, location: CGPoint) {
        let activeGestures: Set<GestureType> = [.pinch, .rotation]
        
        updateGestureState(.active(activeGestures))
        
        // Execute both gestures
        let pinchResult = GestureResult(type: .pinch, location: location, scale: scale)
        let rotationResult = GestureResult(type: .rotation, location: location, rotation: rotation)
        
        gestureHandlers[.pinch]?(pinchResult)
        gestureHandlers[.rotation]?(rotationResult)
    }
    
    /// Resets all gesture states
    func resetGestureState() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            gestureState = .idle
            activeGestures.removeAll()
            multiTouchCount = 0
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Creates a comprehensive gesture recognizer for screenshot thumbnails
    /// - Parameters:
    ///   - onTap: Single tap handler
    ///   - onDoubleTap: Double tap handler
    ///   - onLongPress: Long press handler
    ///   - onTwoFingerTap: Two finger tap handler (batch selection)
    ///   - onThreeFingerTap: Three finger tap handler (select all)
    /// - Returns: A view modifier with all gesture recognizers
    func createScreenshotThumbnailGestures(
        onTap: @escaping (CGPoint) -> Void,
        onDoubleTap: @escaping (CGPoint) -> Void,
        onLongPress: @escaping (CGPoint) -> Void,
        onTwoFingerTap: @escaping (CGPoint) -> Void,
        onThreeFingerTap: @escaping (CGPoint) -> Void
    ) -> some ViewModifier {
        registerGestureHandler(.singleTap) { result in onTap(result.location) }
        registerGestureHandler(.doubleTap) { result in onDoubleTap(result.location) }
        registerGestureHandler(.longPress) { result in onLongPress(result.location) }
        registerGestureHandler(.twoFingerTap) { result in onTwoFingerTap(result.location) }
        registerGestureHandler(.threeFingerTap) { result in onThreeFingerTap(result.location) }
        
        return MultiTouchGestureModifier(gestureService: self)
    }
    
    // MARK: - Private Methods
    
    private func isDoubleTap(at currentTime: Date) -> Bool {
        guard let lastTime = lastGestureEndTime else { return false }
        return currentTime.timeIntervalSince(lastTime) < doubleTapTimeWindow
    }
    
    private func determineSwipeDirection(translation: CGSize, velocity: CGSize) -> GestureType.SwipeDirection {
        let absX = abs(translation.width)
        let absY = abs(translation.height)
        
        if absX > absY {
            return velocity.width > 0 ? .right : .left
        } else {
            return velocity.height > 0 ? .down : .up
        }
    }
    
    private func executeGesture(
        _ gestureType: GestureType,
        at location: CGPoint,
        translation: CGSize = .zero,
        velocity: CGSize = .zero,
        scale: CGFloat = 1.0,
        rotation: Angle = .zero
    ) {
        updateGestureState(.completed(gestureType))
        
        let result = GestureResult(
            type: gestureType,
            location: location,
            translation: translation,
            velocity: velocity,
            scale: scale,
            rotation: rotation
        )
        
        gestureHandlers[gestureType]?(result)
        
        // Reset to idle after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.resetGestureState()
        }
    }
    
    private func updateGestureState(_ newState: GestureState) {
        gestureState = newState
        
        switch newState {
        case .active(let gestures):
            activeGestures = gestures
        case .completed(let gesture):
            activeGestures = [gesture]
        case .idle, .cancelled:
            activeGestures.removeAll()
        case .recognizing(let gesture):
            activeGestures = [gesture]
        }
    }
    
    private func triggerHaptic(_ gestureType: GestureType) {
        switch gestureType {
        case .singleTap:
            hapticService.triggerHaptic(.light, intensity: 0.3)
        case .doubleTap:
            hapticService.triggerHaptic(.light, intensity: 0.5)
        case .longPress:
            hapticService.triggerHaptic(.medium, intensity: 0.8)
        case .twoFingerTap:
            hapticService.triggerHaptic(.medium, intensity: 0.6)
        case .threeFingerTap:
            hapticService.triggerHaptic(.heavy, intensity: 0.8)
        case .pinch:
            hapticService.triggerHaptic(.light, intensity: 0.2)
        case .rotation:
            hapticService.triggerHaptic(.light, intensity: 0.2)
        case .pan:
            hapticService.triggerHaptic(.light, intensity: 0.1)
        case .swipe(let direction):
            triggerHaptic(direction)
        case .force3DTouch:
            hapticService.triggerHaptic(.heavy, intensity: 1.0)
        }
    }
    
    private func triggerHaptic(_ swipeDirection: GestureType.SwipeDirection) {
        switch swipeDirection {
        case .up, .down:
            hapticService.triggerHaptic(.medium, intensity: 0.6)
        case .left, .right:
            hapticService.triggerHaptic(.light, intensity: 0.4)
        }
    }
}

// MARK: - Multi-Touch Gesture Modifier
private struct MultiTouchGestureModifier: ViewModifier {
    let gestureService: MultiTouchGestureService
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                // Single tap gesture
                TapGesture(count: 1)
                    .onEnded {
                        let location = CGPoint(x: 0, y: 0) // Would need proper location tracking
                        gestureService.processTapGesture(location: location, touchCount: 1)
                    }
            )
            .simultaneousGesture(
                // Double tap gesture
                TapGesture(count: 2)
                    .onEnded {
                        let location = CGPoint(x: 0, y: 0) // Would need proper location tracking
                        gestureService.processTapGesture(location: location, touchCount: 1)
                    }
            )
            .simultaneousGesture(
                // Long press gesture
                LongPressGesture(minimumDuration: 0.6)
                    .onEnded { _ in
                        let location = CGPoint(x: 0, y: 0) // Would need proper location tracking
                        gestureService.processLongPressGesture(location: location, duration: 0.6)
                    }
            )
            .simultaneousGesture(
                // Drag gesture
                DragGesture()
                    .onChanged { value in
                        gestureService.processDragGesture(
                            translation: value.translation,
                            velocity: value.velocity,
                            location: value.location
                        )
                    }
                    .onEnded { value in
                        // Check if it's a swipe based on velocity
                        let velocityThreshold: CGFloat = 500
                        if abs(value.velocity.width) > velocityThreshold || abs(value.velocity.height) > velocityThreshold {
                            gestureService.processSwipeGesture(
                                translation: value.translation,
                                velocity: value.velocity,
                                location: value.location
                            )
                        }
                        gestureService.resetGestureState()
                    }
            )
            .simultaneousGesture(
                // Magnification gesture
                MagnificationGesture()
                    .onChanged { value in
                        let location = CGPoint(x: 0, y: 0) // Would need proper location tracking
                        gestureService.processPinchGesture(scale: value, location: location)
                    }
                    .onEnded { _ in
                        gestureService.resetGestureState()
                    }
            )
            .simultaneousGesture(
                // Rotation gesture
                RotationGesture()
                    .onChanged { value in
                        let location = CGPoint(x: 0, y: 0) // Would need proper location tracking
                        gestureService.processRotationGesture(rotation: value, location: location)
                    }
                    .onEnded { _ in
                        gestureService.resetGestureState()
                    }
            )
    }
}

// MARK: - View Extension
extension View {
    /// Adds comprehensive multi-touch gesture support
    /// - Parameter gestureService: The multi-touch gesture service
    /// - Returns: View with multi-touch gesture support
    func multiTouchGestures(gestureService: MultiTouchGestureService) -> some View {
        self.modifier(MultiTouchGestureModifier(gestureService: gestureService))
    }
}