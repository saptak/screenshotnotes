import SwiftUI
import Foundation

/// Comprehensive edge case handler for hero animations
/// Manages complex scenarios like rapid transitions, memory pressure, and device rotation
@MainActor
final class HeroAnimationEdgeCaseHandler: ObservableObject {
    
    // MARK: - Singleton
    static let shared = HeroAnimationEdgeCaseHandler()
    
    // MARK: - Edge Case Types
    
    enum EdgeCaseType: String, CaseIterable {
        case rapidTransition = "rapid_transition"
        case memoryPressure = "memory_pressure"
        case deviceRotation = "device_rotation"
        case backgroundTransition = "background_transition"
        case thermalThrottling = "thermal_throttling"
        case lowBattery = "low_battery"
        case accessibilityMotionReduction = "accessibility_motion_reduction"
        case networkConnectivityChange = "network_connectivity_change"
        
        var description: String {
            switch self {
            case .rapidTransition:
                return "Multiple rapid animation requests"
            case .memoryPressure:
                return "Device under memory pressure"
            case .deviceRotation:
                return "Device orientation change during animation"
            case .backgroundTransition:
                return "App backgrounded during animation"
            case .thermalThrottling:
                return "Device thermal throttling active"
            case .lowBattery:
                return "Device in low power mode"
            case .accessibilityMotionReduction:
                return "Reduce motion accessibility setting enabled"
            case .networkConnectivityChange:
                return "Network connectivity changed during animation"
            }
        }
    }
    
    // MARK: - Edge Case Configuration
    
    struct EdgeCaseConfiguration {
        let shouldCancelAnimation: Bool
        let shouldReduceQuality: Bool
        let fallbackDuration: Double
        let alternativeAnimation: Animation?
        let memoryThreshold: Double // MB
        let recoveryStrategy: RecoveryStrategy
        
        enum RecoveryStrategy {
            case immediate
            case delayed(TimeInterval)
            case onNextFrame
            case userInitiated
        }
    }
    
    // MARK: - State Management
    
    @Published var activeEdgeCases: Set<EdgeCaseType> = []
    @Published var edgeCaseHistory: [EdgeCaseEvent] = []
    @Published var isRecovering = false
    
    struct EdgeCaseEvent {
        let type: EdgeCaseType
        let timestamp: Date
        let resolved: Bool
        let recoveryTime: TimeInterval?
    }
    
    // MARK: - Configuration
    
    private let configurations: [EdgeCaseType: EdgeCaseConfiguration] = [
        .rapidTransition: EdgeCaseConfiguration(
            shouldCancelAnimation: false,
            shouldReduceQuality: true,
            fallbackDuration: 0.3,
            alternativeAnimation: .easeInOut(duration: 0.3),
            memoryThreshold: 50.0,
            recoveryStrategy: .immediate
        ),
        .memoryPressure: EdgeCaseConfiguration(
            shouldCancelAnimation: true,
            shouldReduceQuality: true,
            fallbackDuration: 0.2,
            alternativeAnimation: .linear(duration: 0.2),
            memoryThreshold: 80.0,
            recoveryStrategy: .delayed(1.0)
        ),
        .deviceRotation: EdgeCaseConfiguration(
            shouldCancelAnimation: false,
            shouldReduceQuality: false,
            fallbackDuration: 0.5,
            alternativeAnimation: .spring(response: 0.5, dampingFraction: 1.0),
            memoryThreshold: 30.0,
            recoveryStrategy: .onNextFrame
        ),
        .backgroundTransition: EdgeCaseConfiguration(
            shouldCancelAnimation: true,
            shouldReduceQuality: true,
            fallbackDuration: 0.1,
            alternativeAnimation: .linear(duration: 0.1),
            memoryThreshold: 20.0,
            recoveryStrategy: .userInitiated
        ),
        .thermalThrottling: EdgeCaseConfiguration(
            shouldCancelAnimation: false,
            shouldReduceQuality: true,
            fallbackDuration: 0.4,
            alternativeAnimation: .easeOut(duration: 0.4),
            memoryThreshold: 40.0,
            recoveryStrategy: .delayed(2.0)
        ),
        .lowBattery: EdgeCaseConfiguration(
            shouldCancelAnimation: false,
            shouldReduceQuality: true,
            fallbackDuration: 0.3,
            alternativeAnimation: .easeInOut(duration: 0.3),
            memoryThreshold: 25.0,
            recoveryStrategy: .immediate
        ),
        .accessibilityMotionReduction: EdgeCaseConfiguration(
            shouldCancelAnimation: true,
            shouldReduceQuality: true,
            fallbackDuration: 0.1,
            alternativeAnimation: .linear(duration: 0.1),
            memoryThreshold: 10.0,
            recoveryStrategy: .immediate
        ),
        .networkConnectivityChange: EdgeCaseConfiguration(
            shouldCancelAnimation: false,
            shouldReduceQuality: false,
            fallbackDuration: 0.6,
            alternativeAnimation: nil,
            memoryThreshold: 30.0,
            recoveryStrategy: .immediate
        )
    ]
    
    // MARK: - Monitoring Properties
    
    private var lastTransitionTime: Date = Date.distantPast
    private var transitionCount = 0
    private var monitoringTimer: Timer?
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Checks for edge cases before starting an animation
    /// - Parameters:
    ///   - transitionType: The type of transition being attempted
    ///   - completion: Completion handler with edge case information
    /// - Returns: Whether the animation should proceed
    func checkEdgeCasesBeforeAnimation(
        for transitionType: HeroAnimationService.TransitionType,
        completion: @escaping (Bool, [EdgeCaseType], EdgeCaseConfiguration?) -> Void
    ) {
        let detectedEdgeCases = detectActiveEdgeCases()
        
        if detectedEdgeCases.isEmpty {
            completion(true, [], nil)
            return
        }
        
        // Find the most restrictive edge case
        let criticalEdgeCase = detectedEdgeCases.first { edgeCase in
            configurations[edgeCase]?.shouldCancelAnimation == true
        }
        
        if let criticalCase = criticalEdgeCase,
           let config = configurations[criticalCase] {
            recordEdgeCase(criticalCase)
            completion(false, detectedEdgeCases, config)
        } else {
            // Non-critical edge cases - proceed with modifications
            guard let primaryEdgeCase = detectedEdgeCases.first,
                  let config = configurations[primaryEdgeCase] else {
                // If no edge cases or no configuration found, use default
                let defaultConfig = EdgeCaseConfiguration(
                    shouldCancelAnimation: false,
                    shouldReduceQuality: false,
                    fallbackDuration: 0.3,
                    alternativeAnimation: nil,
                    memoryThreshold: 100.0,
                    recoveryStrategy: .immediate
                )
                completion(true, detectedEdgeCases, defaultConfig)
                return
            }
            recordEdgeCase(primaryEdgeCase)
            completion(true, detectedEdgeCases, config)
        }
    }
    
    /// Handles animation interruption due to edge cases
    /// - Parameters:
    ///   - edgeCases: The edge cases that caused the interruption
    ///   - currentAnimation: The currently running animation
    func handleAnimationInterruption(
        for edgeCases: [EdgeCaseType],
        currentAnimation: HeroAnimationService.TransitionType
    ) {
        for edgeCase in edgeCases {
            if let config = configurations[edgeCase] {
                switch config.recoveryStrategy {
                case .immediate:
                    recoverFromEdgeCase(edgeCase)
                case .delayed(let delay):
                    scheduleRecovery(for: edgeCase, after: delay)
                case .onNextFrame:
                    DispatchQueue.main.async {
                        self.recoverFromEdgeCase(edgeCase)
                    }
                case .userInitiated:
                    // Wait for user to bring app to foreground or take action
                    break
                }
            }
        }
    }
    
    /// Gets the appropriate animation configuration for edge cases
    /// - Parameter edgeCases: Active edge cases
    /// - Returns: Modified animation configuration
    func getAnimationConfiguration(for edgeCases: [EdgeCaseType]) -> HeroAnimationService.AnimationConfiguration {
        guard let primaryEdgeCase = edgeCases.first,
              let config = configurations[primaryEdgeCase] else {
            return .standard
        }
        
        let animation = config.alternativeAnimation ?? .spring(response: config.fallbackDuration, dampingFraction: 0.9)
        
        return HeroAnimationService.AnimationConfiguration(
            duration: config.fallbackDuration,
            timing: animation,
            delay: 0.0,
            dampingFraction: 0.9,
            response: config.fallbackDuration
        )
    }
    
    // MARK: - Edge Case Detection
    
    private func detectActiveEdgeCases() -> [EdgeCaseType] {
        var edgeCases: [EdgeCaseType] = []
        
        // Check for rapid transitions
        if isRapidTransition() {
            edgeCases.append(.rapidTransition)
        }
        
        // Check memory pressure
        if isMemoryPressureHigh() {
            edgeCases.append(.memoryPressure)
        }
        
        // Check thermal state
        if isThermalThrottling() {
            edgeCases.append(.thermalThrottling)
        }
        
        // Check low power mode
        if isLowPowerMode() {
            edgeCases.append(.lowBattery)
        }
        
        // Check accessibility settings
        if isMotionReduced() {
            edgeCases.append(.accessibilityMotionReduction)
        }
        
        return edgeCases
    }
    
    private func isRapidTransition() -> Bool {
        let now = Date()
        let timeSinceLastTransition = now.timeIntervalSince(lastTransitionTime)
        
        if timeSinceLastTransition < 0.5 {
            transitionCount += 1
            if transitionCount > 3 {
                return true
            }
        } else {
            transitionCount = 0
        }
        
        lastTransitionTime = now
        return false
    }
    
    private func isMemoryPressureHigh() -> Bool {
        // Get current memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
            return memoryUsageMB > 200.0 // Threshold for high memory usage
        }
        
        return false
    }
    
    private func isThermalThrottling() -> Bool {
        let thermalState = ProcessInfo.processInfo.thermalState
        return thermalState == .serious || thermalState == .critical
    }
    
    private func isLowPowerMode() -> Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    private func isMotionReduced() -> Bool {
        return UIAccessibility.isReduceMotionEnabled
    }
    
    // MARK: - Recovery Management
    
    private func recordEdgeCase(_ edgeCase: EdgeCaseType) {
        let event = EdgeCaseEvent(
            type: edgeCase,
            timestamp: Date(),
            resolved: false,
            recoveryTime: nil
        )
        
        edgeCaseHistory.append(event)
        activeEdgeCases.insert(edgeCase)
        
        // Keep history manageable
        if edgeCaseHistory.count > 50 {
            edgeCaseHistory.removeFirst(10)
        }
    }
    
    private func recoverFromEdgeCase(_ edgeCase: EdgeCaseType) {
        isRecovering = true
        
        _ = withAnimation(.easeOut(duration: 0.2)) {
            activeEdgeCases.remove(edgeCase)
        }
        
        // Update history
        if let index = edgeCaseHistory.lastIndex(where: { $0.type == edgeCase && !$0.resolved }) {
            let originalEvent = edgeCaseHistory[index]
            let recoveryTime = Date().timeIntervalSince(originalEvent.timestamp)
            
            edgeCaseHistory[index] = EdgeCaseEvent(
                type: originalEvent.type,
                timestamp: originalEvent.timestamp,
                resolved: true,
                recoveryTime: recoveryTime
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isRecovering = false
        }
    }
    
    private func scheduleRecovery(for edgeCase: EdgeCaseType, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.recoverFromEdgeCase(edgeCase)
        }
    }
    
    // MARK: - Monitoring Setup
    
    private func setupMonitoring() {
        // Monitor app lifecycle events
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.recordEdgeCase(.backgroundTransition)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if self.activeEdgeCases.contains(.backgroundTransition) {
                    self.recoverFromEdgeCase(.backgroundTransition)
                }
            }
        }
        
        // Monitor device orientation changes
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.recordEdgeCase(.deviceRotation)
                
                // Auto-recover after orientation settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Task { @MainActor in
                        self.recoverFromEdgeCase(.deviceRotation)
                    }
                }
            }
        }
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                self.performPeriodicCheck()
            }
        }
    }
    
    private func performPeriodicCheck() {
        // Check for thermal throttling recovery
        if activeEdgeCases.contains(.thermalThrottling) && !isThermalThrottling() {
            recoverFromEdgeCase(.thermalThrottling)
        }
        
        // Check for memory pressure recovery
        if activeEdgeCases.contains(.memoryPressure) && !isMemoryPressureHigh() {
            recoverFromEdgeCase(.memoryPressure)
        }
        
        // Check for low power mode recovery
        if activeEdgeCases.contains(.lowBattery) && !isLowPowerMode() {
            recoverFromEdgeCase(.lowBattery)
        }
    }
    
    deinit {
        monitoringTimer?.invalidate()
    }
}

// MARK: - Integration with HeroAnimationService

extension HeroAnimationService {
    
    /// Enhanced transition method with edge case handling
    func startTransitionWithEdgeCaseHandling(
        _ transitionType: TransitionType,
        from sourceId: String,
        to destinationId: String,
        completion: (() -> Void)? = nil
    ) {
        let edgeCaseHandler = HeroAnimationEdgeCaseHandler.shared
        
        edgeCaseHandler.checkEdgeCasesBeforeAnimation(for: transitionType) { shouldProceed, edgeCases, config in
            if shouldProceed {
                if config != nil {
                    // Use modified animation configuration
                    let modifiedConfig = edgeCaseHandler.getAnimationConfiguration(for: edgeCases)
                    self.startTransitionWithCustomConfiguration(
                        transitionType,
                        configuration: modifiedConfig,
                        from: sourceId,
                        to: destinationId,
                        completion: completion
                    )
                } else {
                    // Normal transition
                    self.startTransition(transitionType, from: sourceId, to: destinationId, completion: completion)
                }
            } else {
                // Animation cancelled due to edge cases
                edgeCaseHandler.handleAnimationInterruption(for: edgeCases, currentAnimation: transitionType)
                completion?()
            }
        }
    }
    
    private func startTransitionWithCustomConfiguration(
        _ transitionType: TransitionType,
        configuration: AnimationConfiguration,
        from sourceId: String,
        to destinationId: String,
        completion: (() -> Void)? = nil
    ) {
        guard !isAnimating else {
            handleAnimationInterruption(newTransition: transitionType)
            return
        }
        
        let startTime = CACurrentMediaTime()
        
        withAnimation(configuration.timing.delay(configuration.delay)) {
            isAnimating = true
            currentTransition = transitionType
            activeAnimations.insert("\(sourceId)_to_\(destinationId)")
        }
        
        // Monitor performance during animation
        monitorPerformance(for: transitionType, startTime: startTime)
        
        // Schedule completion
        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.duration + configuration.delay) {
            self.completeTransition(sourceId: sourceId, destinationId: destinationId, completion: completion)
        }
    }
}

#if DEBUG
/// Debug view for monitoring edge cases
struct HeroAnimationEdgeCaseMonitor: View {
    @StateObject private var edgeCaseHandler = HeroAnimationEdgeCaseHandler.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if edgeCaseHandler.activeEdgeCases.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        
                        Text("No Active Edge Cases")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Hero animations operating normally")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Edge Cases")
                            .font(.headline)
                        
                        ForEach(Array(edgeCaseHandler.activeEdgeCases), id: \.self) { edgeCase in
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(edgeCase.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(edgeCase.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .surfaceMaterial(cornerRadius: 8)
                        }
                    }
                }
                
                if !edgeCaseHandler.edgeCaseHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Edge Cases")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(edgeCaseHandler.edgeCaseHistory.suffix(10).reversed(), id: \.timestamp) { event in
                                    HStack {
                                        Image(systemName: event.resolved ? "checkmark.circle" : "clock")
                                            .foregroundColor(event.resolved ? .green : .orange)
                                        
                                        Text(event.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.caption)
                                        
                                        Spacer()
                                        
                                        Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding()
                    .surfaceMaterial(cornerRadius: 12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edge Case Monitor")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HeroAnimationEdgeCaseMonitor()
}
#endif