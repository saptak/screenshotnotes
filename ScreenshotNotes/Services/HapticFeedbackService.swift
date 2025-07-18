import SwiftUI
import UIKit

/// Advanced haptic feedback service for sophisticated tactile responses
/// Provides contextual haptic patterns for different interaction types
@MainActor
final class HapticFeedbackService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = HapticFeedbackService()
    
    // MARK: - Haptic Feedback Types
    
    enum HapticPattern: String, CaseIterable {
        case menuAppear = "menu_appear"
        case menuSelection = "menu_selection"
        case menuDismiss = "menu_dismiss"
        case longPressStart = "long_press_start"
        case longPressTriggered = "long_press_triggered"
        case batchSelectionStart = "batch_selection_start"
        case batchSelectionAdd = "batch_selection_add"
        case batchSelectionRemove = "batch_selection_remove"
        case quickActionTrigger = "quick_action_trigger"
        case deleteConfirmation = "delete_confirmation"
        case shareAction = "share_action"
        case copyAction = "copy_action"
        case tagAction = "tag_action"
        case errorFeedback = "error_feedback"
        case successFeedback = "success_feedback"
        
        // Enhanced patterns for beautiful interactions
        case duplicateDetected = "duplicate_detected"
        case batchOperationStart = "batch_operation_start"
        case batchOperationProgress = "batch_operation_progress"
        case batchOperationComplete = "batch_operation_complete"
        case suggestionPresented = "suggestion_presented"
        case suggestionAccepted = "suggestion_accepted"
        case collectionAdded = "collection_added"
        case exportComplete = "export_complete"
        case processingStart = "processing_start"
        case processingComplete = "processing_complete"
        case visualSimilarityFound = "visual_similarity_found"
        case intelligentGrouping = "intelligent_grouping"
        case workflowComplete = "workflow_complete"
        case smartRecommendation = "smart_recommendation"
        case dataRecovery = "data_recovery"
        case systemOptimization = "system_optimization"
        
        // Basic impact patterns for gesture services
        case light = "light"
        case medium = "medium"
        case heavy = "heavy"
        case success = "success"
        case error = "error"
        
        var description: String {
            switch self {
            case .menuAppear:
                return "Contextual menu appears"
            case .menuSelection:
                return "Menu item selection"
            case .menuDismiss:
                return "Menu dismissal"
            case .longPressStart:
                return "Long press gesture begins"
            case .longPressTriggered:
                return "Long press threshold reached"
            case .batchSelectionStart:
                return "Batch selection mode activated"
            case .batchSelectionAdd:
                return "Item added to selection"
            case .batchSelectionRemove:
                return "Item removed from selection"
            case .quickActionTrigger:
                return "Quick action executed"
            case .deleteConfirmation:
                return "Delete action confirmation"
            case .shareAction:
                return "Share action triggered"
            case .copyAction:
                return "Copy action triggered"
            case .tagAction:
                return "Tag action triggered"
            case .errorFeedback:
                return "Error or invalid action"
            case .successFeedback:
                return "Successful action completion"
            case .duplicateDetected:
                return "Duplicate screenshot detected"
            case .batchOperationStart:
                return "Batch operation starting"
            case .batchOperationProgress:
                return "Batch operation in progress"
            case .batchOperationComplete:
                return "Batch operation completed"
            case .suggestionPresented:
                return "Intelligent suggestion presented"
            case .suggestionAccepted:
                return "Suggestion accepted"
            case .collectionAdded:
                return "Added to collection"
            case .exportComplete:
                return "Export completed successfully"
            case .processingStart:
                return "Processing started"
            case .processingComplete:
                return "Processing completed"
            case .visualSimilarityFound:
                return "Visual similarity detected"
            case .intelligentGrouping:
                return "Intelligent grouping applied"
            case .workflowComplete:
                return "Workflow sequence completed"
            case .smartRecommendation:
                return "Smart recommendation triggered"
            case .dataRecovery:
                return "Data recovery successful"
            case .systemOptimization:
                return "System optimization applied"
            case .light:
                return "Light impact feedback"
            case .medium:
                return "Medium impact feedback"
            case .heavy:
                return "Heavy impact feedback"
            case .success:
                return "Success notification"
            case .error:
                return "Error notification"
            }
        }
    }
    
    // MARK: - Haptic Configuration
    
    struct HapticConfiguration {
        let pattern: HapticPattern
        let intensity: CGFloat
        let duration: TimeInterval
        let delay: TimeInterval
        let repeatCount: Int
        
        static let menuAppear = HapticConfiguration(
            pattern: .menuAppear,
            intensity: 0.7,
            duration: 0.1,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let menuSelection = HapticConfiguration(
            pattern: .menuSelection,
            intensity: 0.5,
            duration: 0.05,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let longPressTriggered = HapticConfiguration(
            pattern: .longPressTriggered,
            intensity: 0.8,
            duration: 0.15,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let batchSelectionStart = HapticConfiguration(
            pattern: .batchSelectionStart,
            intensity: 0.9,
            duration: 0.2,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let quickActionTrigger = HapticConfiguration(
            pattern: .quickActionTrigger,
            intensity: 0.6,
            duration: 0.08,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let deleteConfirmation = HapticConfiguration(
            pattern: .deleteConfirmation,
            intensity: 1.0,
            duration: 0.25,
            delay: 0.0,
            repeatCount: 2
        )
        
        static let successFeedback = HapticConfiguration(
            pattern: .successFeedback,
            intensity: 0.7,
            duration: 0.12,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let errorFeedback = HapticConfiguration(
            pattern: .errorFeedback,
            intensity: 0.9,
            duration: 0.3,
            delay: 0.0,
            repeatCount: 3
        )
        
        static let duplicateDetected = HapticConfiguration(
            pattern: .duplicateDetected,
            intensity: 0.6,
            duration: 0.08,
            delay: 0.0,
            repeatCount: 2
        )
        
        static let batchOperationStart = HapticConfiguration(
            pattern: .batchOperationStart,
            intensity: 0.8,
            duration: 0.15,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let batchOperationProgress = HapticConfiguration(
            pattern: .batchOperationProgress,
            intensity: 0.4,
            duration: 0.05,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let batchOperationComplete = HapticConfiguration(
            pattern: .batchOperationComplete,
            intensity: 0.9,
            duration: 0.2,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let suggestionPresented = HapticConfiguration(
            pattern: .suggestionPresented,
            intensity: 0.5,
            duration: 0.08,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let intelligentGrouping = HapticConfiguration(
            pattern: .intelligentGrouping,
            intensity: 0.7,
            duration: 0.12,
            delay: 0.0,
            repeatCount: 1
        )
        
        static let workflowComplete = HapticConfiguration(
            pattern: .workflowComplete,
            intensity: 0.8,
            duration: 0.15,
            delay: 0.0,
            repeatCount: 2
        )
    }
    
    // MARK: - Haptic Generators
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - State Management
    
    @Published var isHapticEnabled = true
    @Published var hapticIntensityMultiplier: CGFloat = 1.0
    
    private var hapticHistory: [HapticEvent] = []
    private var lastHapticTime: Date = .distantPast
    
    struct HapticEvent {
        let pattern: HapticPattern
        let timestamp: Date
        let intensity: CGFloat
        let successful: Bool
    }
    
    private init() {
        setupHapticGenerators()
        loadHapticSettings()
    }
    
    // MARK: - Public Interface
    
    /// Triggers haptic feedback for a specific pattern
    /// - Parameters:
    ///   - pattern: The haptic pattern to trigger
    ///   - intensity: Optional intensity override (0.0-1.0)
    func triggerHaptic(_ pattern: HapticPattern, intensity: CGFloat? = nil) {
        guard isHapticEnabled else { return }
        
        let config = getConfiguration(for: pattern)
        let finalIntensity = (intensity ?? config.intensity) * hapticIntensityMultiplier
        
        // Prevent haptic spam
        let now = Date()
        if now.timeIntervalSince(lastHapticTime) < 0.05 {
            return
        }
        lastHapticTime = now
        
        Task {
            await performHapticFeedback(config, intensity: finalIntensity)
            
            await MainActor.run {
                recordHapticEvent(pattern, intensity: finalIntensity, successful: true)
            }
        }
    }
    
    /// Triggers haptic feedback with custom configuration
    /// - Parameter configuration: Custom haptic configuration
    func triggerCustomHaptic(_ configuration: HapticConfiguration) {
        guard isHapticEnabled else { return }
        
        Task {
            await performHapticFeedback(configuration, intensity: configuration.intensity * hapticIntensityMultiplier)
            
            await MainActor.run {
                recordHapticEvent(configuration.pattern, intensity: configuration.intensity, successful: true)
            }
        }
    }
    
    /// Triggers a sequence of haptic patterns
    /// - Parameter patterns: Array of patterns to trigger in sequence
    func triggerHapticSequence(_ patterns: [HapticPattern]) {
        guard isHapticEnabled else { return }
        
        Task {
            for (index, pattern) in patterns.enumerated() {
                let config = getConfiguration(for: pattern)
                await performHapticFeedback(config, intensity: config.intensity * hapticIntensityMultiplier)
                
                // Add delay between patterns except for the last one
                if index < patterns.count - 1 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
            
            await MainActor.run {
                for pattern in patterns {
                    recordHapticEvent(pattern, intensity: hapticIntensityMultiplier, successful: true)
                }
            }
        }
    }
    
    /// Triggers contextual haptic feedback based on operation type and result
    /// - Parameters:
    ///   - operationType: The type of operation being performed
    ///   - isSuccess: Whether the operation was successful
    ///   - itemCount: Number of items affected (for scaling intensity)
    func triggerContextualFeedback(
        for operationType: ContextualOperation,
        isSuccess: Bool,
        itemCount: Int = 1
    ) {
        guard isHapticEnabled else { return }
        
        let patterns = getContextualPatterns(for: operationType, isSuccess: isSuccess, itemCount: itemCount)
        triggerHapticSequence(patterns)
    }
    
    /// Enhanced workflow completion feedback with celebration pattern
    /// - Parameter workflowType: The type of workflow completed
    func triggerWorkflowCompletionCelebration(_ workflowType: WorkflowType) {
        guard isHapticEnabled else { return }
        
        let celebrationPatterns: [HapticPattern] = switch workflowType {
        case .batchProcessing:
            [.batchOperationComplete, .successFeedback]
        case .duplicateCleanup:
            [.duplicateDetected, .batchOperationComplete, .systemOptimization]
        case .intelligentOrganization:
            [.intelligentGrouping, .collectionAdded, .workflowComplete]
        case .exportWorkflow:
            [.processingStart, .exportComplete, .successFeedback]
        }
        
        triggerHapticSequence(celebrationPatterns)
    }
    
    /// Prepares haptic generators for immediate use
    func prepareHapticGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Settings Management
    
    func setHapticEnabled(_ enabled: Bool) {
        isHapticEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "haptic_feedback_enabled")
    }
    
    func setHapticIntensity(_ intensity: CGFloat) {
        hapticIntensityMultiplier = max(0.0, min(1.0, intensity))
        UserDefaults.standard.set(hapticIntensityMultiplier, forKey: "haptic_intensity_multiplier")
    }
    
    // MARK: - Private Methods
    
    private func setupHapticGenerators() {
        // Prepare all generators for optimal performance
        prepareHapticGenerators()
    }
    
    private func loadHapticSettings() {
        isHapticEnabled = UserDefaults.standard.object(forKey: "haptic_feedback_enabled") as? Bool ?? true
        hapticIntensityMultiplier = UserDefaults.standard.object(forKey: "haptic_intensity_multiplier") as? CGFloat ?? 1.0
    }
    
    private func getConfiguration(for pattern: HapticPattern) -> HapticConfiguration {
        switch pattern {
        case .menuAppear:
            return .menuAppear
        case .menuSelection:
            return .menuSelection
        case .menuDismiss:
            return .menuSelection
        case .longPressStart:
            return .menuSelection
        case .longPressTriggered:
            return .longPressTriggered
        case .batchSelectionStart:
            return .batchSelectionStart
        case .batchSelectionAdd, .batchSelectionRemove:
            return .menuSelection
        case .quickActionTrigger:
            return .quickActionTrigger
        case .deleteConfirmation:
            return .deleteConfirmation
        case .shareAction, .copyAction, .tagAction:
            return .quickActionTrigger
        case .errorFeedback:
            return .errorFeedback
        case .successFeedback:
            return .successFeedback
        case .duplicateDetected:
            return .duplicateDetected
        case .batchOperationStart:
            return .batchOperationStart
        case .batchOperationProgress:
            return .batchOperationProgress
        case .batchOperationComplete:
            return .batchOperationComplete
        case .suggestionPresented:
            return .suggestionPresented
        case .suggestionAccepted:
            return .successFeedback
        case .collectionAdded:
            return .successFeedback
        case .exportComplete:
            return .batchOperationComplete
        case .processingStart:
            return .batchOperationStart
        case .processingComplete:
            return .batchOperationComplete
        case .visualSimilarityFound:
            return .duplicateDetected
        case .intelligentGrouping:
            return .intelligentGrouping
        case .workflowComplete:
            return .workflowComplete
        case .smartRecommendation:
            return .suggestionPresented
        case .dataRecovery:
            return .successFeedback
        case .systemOptimization:
            return .workflowComplete
        case .light:
            return HapticConfiguration(
                pattern: .light,
                intensity: 0.5,
                duration: 0.05,
                delay: 0.0,
                repeatCount: 1
            )
        case .medium:
            return HapticConfiguration(
                pattern: .medium,
                intensity: 0.7,
                duration: 0.1,
                delay: 0.0,
                repeatCount: 1
            )
        case .heavy:
            return HapticConfiguration(
                pattern: .heavy,
                intensity: 0.9,
                duration: 0.15,
                delay: 0.0,
                repeatCount: 1
            )
        case .success:
            return HapticConfiguration(
                pattern: .success,
                intensity: 0.8,
                duration: 0.12,
                delay: 0.0,
                repeatCount: 1
            )
        case .error:
            return HapticConfiguration(
                pattern: .error,
                intensity: 0.9,
                duration: 0.2,
                delay: 0.0,
                repeatCount: 2
            )
        }
    }
    
    private func performHapticFeedback(_ configuration: HapticConfiguration, intensity: CGFloat) async {
        let adjustedIntensity = max(0.0, min(1.0, intensity))
        
        switch configuration.pattern {
        case .menuAppear, .longPressTriggered, .batchSelectionStart:
            await triggerImpactFeedback(.medium, intensity: adjustedIntensity)
            
        case .menuSelection, .menuDismiss, .longPressStart, .batchSelectionAdd, .batchSelectionRemove:
            await triggerSelectionFeedback()
            
        case .quickActionTrigger, .shareAction, .copyAction, .tagAction:
            await triggerImpactFeedback(.light, intensity: adjustedIntensity)
            
        case .deleteConfirmation:
            await triggerNotificationFeedback(.warning)
            
        case .successFeedback, .suggestionAccepted, .collectionAdded, .dataRecovery:
            await triggerNotificationFeedback(.success)
            
        case .errorFeedback, .error:
            await triggerNotificationFeedback(.error)
            
        case .duplicateDetected, .visualSimilarityFound:
            await triggerImpactFeedback(.light, intensity: adjustedIntensity * 0.8)
            
        case .batchOperationStart, .processingStart:
            await triggerImpactFeedback(.medium, intensity: adjustedIntensity)
            
        case .batchOperationProgress:
            await triggerImpactFeedback(.light, intensity: adjustedIntensity * 0.6)
            
        case .batchOperationComplete, .exportComplete, .processingComplete:
            await triggerNotificationFeedback(.success)
            
        case .suggestionPresented, .smartRecommendation:
            await triggerSelectionFeedback()
            
        case .intelligentGrouping:
            await triggerImpactFeedback(.medium, intensity: adjustedIntensity * 0.9)
            
        case .workflowComplete, .systemOptimization:
            await triggerImpactFeedback(.heavy, intensity: adjustedIntensity)
            
        case .light:
            await triggerImpactFeedback(.light, intensity: adjustedIntensity)
            
        case .medium:
            await triggerImpactFeedback(.medium, intensity: adjustedIntensity)
            
        case .heavy:
            await triggerImpactFeedback(.heavy, intensity: adjustedIntensity)
            
        case .success:
            await triggerNotificationFeedback(.success)
        }
        
        // Handle repeat patterns
        if configuration.repeatCount > 1 {
            for _ in 1..<configuration.repeatCount {
                try? await Task.sleep(nanoseconds: UInt64(configuration.duration * 1_000_000_000))
                await performSingleHapticFeedback(configuration.pattern, intensity: adjustedIntensity)
            }
        }
    }
    
    private func triggerImpactFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) async {
        await MainActor.run {
            switch style {
            case .light:
                impactLight.impactOccurred(intensity: intensity)
            case .medium:
                impactMedium.impactOccurred(intensity: intensity)
            case .heavy:
                impactHeavy.impactOccurred(intensity: intensity)
            case .soft:
                impactLight.impactOccurred(intensity: intensity * 0.7)
            case .rigid:
                impactHeavy.impactOccurred(intensity: intensity)
            @unknown default:
                impactMedium.impactOccurred(intensity: intensity)
            }
        }
    }
    
    private func triggerSelectionFeedback() async {
        await MainActor.run {
            selectionFeedback.selectionChanged()
        }
    }
    
    private func triggerNotificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) async {
        await MainActor.run {
            notificationFeedback.notificationOccurred(type)
        }
    }
    
    private func performSingleHapticFeedback(_ pattern: HapticPattern, intensity: CGFloat) async {
        switch pattern {
        case .deleteConfirmation:
            await triggerImpactFeedback(.heavy, intensity: intensity)
        case .errorFeedback:
            await triggerImpactFeedback(.heavy, intensity: intensity)
        default:
            await triggerImpactFeedback(.medium, intensity: intensity)
        }
    }
    
    private func recordHapticEvent(_ pattern: HapticPattern, intensity: CGFloat, successful: Bool) {
        let event = HapticEvent(
            pattern: pattern,
            timestamp: Date(),
            intensity: intensity,
            successful: successful
        )
        
        hapticHistory.append(event)
        
        // Keep history manageable
        if hapticHistory.count > 100 {
            hapticHistory.removeFirst(50)
        }
    }
    
    // MARK: - Contextual Feedback Helpers
    
    private func getContextualPatterns(
        for operation: ContextualOperation,
        isSuccess: Bool,
        itemCount: Int
    ) -> [HapticPattern] {
        let basePatterns: [HapticPattern] = switch operation {
        case .quickAction:
            [.quickActionTrigger]
        case .batchOperation:
            [.batchOperationStart, .batchOperationComplete]
        case .duplicateDetection:
            [.duplicateDetected, .visualSimilarityFound]
        case .smartSuggestion:
            [.suggestionPresented, .smartRecommendation]
        case .intelligentGrouping:
            [.intelligentGrouping]
        case .dataProcessing:
            [.processingStart, .processingComplete]
        }
        
        let resultPattern: HapticPattern = isSuccess ? .successFeedback : .errorFeedback
        
        // Scale patterns based on item count for batch operations
        if itemCount > 10 && operation == .batchOperation {
            return basePatterns + [.batchOperationProgress, resultPattern]
        } else {
            return basePatterns + [resultPattern]
        }
    }
}

// MARK: - Supporting Types

public enum ContextualOperation {
    case quickAction
    case batchOperation
    case duplicateDetection
    case smartSuggestion
    case intelligentGrouping
    case dataProcessing
}

public enum WorkflowType {
    case batchProcessing
    case duplicateCleanup
    case intelligentOrganization
    case exportWorkflow
}

// MARK: - Haptic Feedback Extensions

extension View {
    /// Adds haptic feedback to tap gestures
    /// - Parameter pattern: The haptic pattern to trigger
    /// - Returns: View with haptic feedback attached
    func hapticFeedback(_ pattern: HapticFeedbackService.HapticPattern) -> some View {
        self.onTapGesture {
            HapticFeedbackService.shared.triggerHaptic(pattern)
        }
    }
    
    /// Adds haptic feedback to long press gestures
    /// - Parameters:
    ///   - startPattern: Pattern for long press start
    ///   - triggeredPattern: Pattern for long press triggered
    /// - Returns: View with haptic long press feedback
    func hapticLongPress(
        start startPattern: HapticFeedbackService.HapticPattern = .longPressStart,
        triggered triggeredPattern: HapticFeedbackService.HapticPattern = .longPressTriggered
    ) -> some View {
        self.onLongPressGesture(
            minimumDuration: 0.5,
            perform: {
                HapticFeedbackService.shared.triggerHaptic(triggeredPattern)
            },
            onPressingChanged: { pressing in
                if pressing {
                    HapticFeedbackService.shared.triggerHaptic(startPattern)
                }
            }
        )
    }
}

// MARK: - Debug View for Haptic Testing

#if DEBUG
struct HapticFeedbackTestView: View {
    @StateObject private var hapticService = HapticFeedbackService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Settings Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Haptic Settings")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Toggle("Enable Haptic Feedback", isOn: $hapticService.isHapticEnabled)
                            .onChange(of: hapticService.isHapticEnabled) { _, enabled in
                                hapticService.setHapticEnabled(enabled)
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Intensity: \(Int(hapticService.hapticIntensityMultiplier * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Slider(value: $hapticService.hapticIntensityMultiplier, in: 0.1...1.0)
                                .onChange(of: hapticService.hapticIntensityMultiplier) { _, intensity in
                                    hapticService.setHapticIntensity(intensity)
                                }
                        }
                    }
                    .padding()
                    .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
                    
                    // Test Patterns Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Haptic Patterns")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(HapticFeedbackService.HapticPattern.allCases, id: \.rawValue) { pattern in
                                Button(action: {
                                    hapticService.triggerHaptic(pattern)
                                }) {
                                    VStack(spacing: 4) {
                                        Text(pattern.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .multilineTextAlignment(.center)
                                        
                                        Text(pattern.description)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .frame(maxWidth: .infinity)
                                    .glassBackground(material: .regular, cornerRadius: 8, shadow: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
                    
                    // Sequence Test Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sequence Tests")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Button("Test Menu Flow") {
                            hapticService.triggerHapticSequence([
                                .longPressStart,
                                .longPressTriggered,
                                .menuAppear,
                                .menuSelection,
                                .successFeedback
                            ])
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Test Batch Selection") {
                            hapticService.triggerHapticSequence([
                                .longPressTriggered,
                                .batchSelectionStart,
                                .batchSelectionAdd,
                                .batchSelectionAdd,
                                .quickActionTrigger
                            ])
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Test Error Flow") {
                            hapticService.triggerHapticSequence([
                                .quickActionTrigger,
                                .errorFeedback
                            ])
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
                }
                .padding()
            }
            .navigationTitle("Haptic Feedback")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HapticFeedbackTestView()
}
#endif