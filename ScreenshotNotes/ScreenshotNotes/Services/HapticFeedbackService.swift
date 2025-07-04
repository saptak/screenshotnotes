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
            
        case .successFeedback:
            await triggerNotificationFeedback(.success)
            
        case .errorFeedback:
            await triggerNotificationFeedback(.error)
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
                    .surfaceMaterial(cornerRadius: 12)
                    
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
                                    .surfaceMaterial(cornerRadius: 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .surfaceMaterial(cornerRadius: 12)
                    
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
                    .surfaceMaterial(cornerRadius: 12)
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