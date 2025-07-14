//
//  InterfaceModeManager.swift
//  ScreenshotNotes
//
//  Sprint 8.2.1: Interface Mode Management Service for Adaptive Content Hub
//  Created by Assistant on 7/14/25.
//

import Foundation
import SwiftUI
import Combine
import OSLog

/// Service managing interface mode state, transitions, and user preferences
/// Implements progressive disclosure with intelligent mode suggestions
@MainActor
final class InterfaceModeManager: ObservableObject {
    static let shared = InterfaceModeManager()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "InterfaceModeManager")
    
    // MARK: - Published State
    
    /// Current active interface mode
    @Published var currentMode: InterfaceMode = .gallery
    
    /// Previous mode for back navigation
    @Published var previousMode: InterfaceMode?
    
    /// Whether mode switching is available (only in Enhanced Interface)
    @Published var isModeSwitchingEnabled: Bool = false
    
    /// Configuration for each mode
    @Published var modeConfigurations: [InterfaceMode: InterfaceModeConfiguration] = [:]
    
    /// Recent mode transitions for analytics
    @Published var recentTransitions: [InterfaceModeTransition] = []
    
    /// Whether a mode transition is currently in progress
    @Published var isTransitioning: Bool = false
    
    /// Current transition animation progress (0.0 - 1.0)
    @Published var transitionProgress: Double = 0.0
    
    // MARK: - Dependencies
    
    private let interfaceSettings = InterfaceSettings()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Private State
    
    private let defaultTransitionDuration: TimeInterval = 0.4
    private let maxRecentTransitions = 50
    private var transitionStartTime: Date?
    
    private init() {
        setupDefaultConfigurations()
        observeInterfaceSettings()
        loadPersistedState()
    }
    
    // MARK: - Mode Management
    
    /// Switch to a specific interface mode with animation
    func switchToMode(_ newMode: InterfaceMode, trigger: InterfaceModeTransition.TransitionTrigger = .userTap) {
        guard isModeSwitchingEnabled else {
            logger.info("Mode switching is disabled (Legacy Interface active)")
            return
        }
        
        guard newMode != currentMode else {
            logger.debug("Already in mode \(newMode.rawValue)")
            return
        }
        
        logger.info("Switching from \(self.currentMode.rawValue) to \(newMode.rawValue) via \(trigger.rawValue)")
        
        let transition = InterfaceModeTransition(
            fromMode: currentMode,
            toMode: newMode,
            trigger: trigger,
            timestamp: Date(),
            duration: defaultTransitionDuration
        )
        
        // Start transition
        isTransitioning = true
        transitionProgress = 0.0
        transitionStartTime = Date()
        previousMode = currentMode
        
        // Update usage tracking
        updateModeUsage(newMode)
        
        // Animate transition
        withAnimation(.easeInOut(duration: defaultTransitionDuration)) {
            currentMode = newMode
            transitionProgress = 1.0
        }
        
        // Complete transition after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + defaultTransitionDuration) {
            self.isTransitioning = false
            self.transitionProgress = 0.0
            self.transitionStartTime = nil
            
            // Record completed transition
            self.recordTransition(transition)
            self.persistState()
        }
    }
    
    /// Go to next mode in progressive disclosure sequence
    func progressToNextMode() {
        guard let nextMode = currentMode.nextMode else {
            logger.debug("Already at most advanced mode (\(self.currentMode.rawValue))")
            return
        }
        
        switchToMode(nextMode, trigger: .automaticProgression)
    }
    
    /// Go to previous mode in progressive disclosure sequence
    func simplifyToPreviousMode() {
        guard let prevMode = currentMode.previousMode else {
            logger.debug("Already at simplest mode (\(self.currentMode.rawValue))")
            return
        }
        
        switchToMode(prevMode, trigger: .automaticProgression)
    }
    
    /// Get suggested mode based on current context and user behavior
    func getSuggestedMode(for context: ModeContext) -> InterfaceMode {
        // For Sprint 8.2.1, return simple suggestions
        // This will be enhanced in future sprints with AI-powered suggestions
        
        switch context {
        case .browsing:
            return .gallery
        case .organizing:
            return .constellation
        case .exploring:
            return .exploration
        case .searching:
            return .search
        case .firstTime:
            return .gallery // Always start with simplest mode
        }
    }
    
    // MARK: - Configuration Management
    
    /// Enable or disable a specific mode
    func setModeEnabled(_ mode: InterfaceMode, enabled: Bool) {
        let config = modeConfigurations[mode] ?? InterfaceModeConfiguration(mode: mode)
        modeConfigurations[mode] = InterfaceModeConfiguration(
            mode: mode,
            isEnabled: enabled,
            lastUsed: config.lastUsed,
            usageCount: config.usageCount,
            userPreference: enabled ? .preferred : .hidden
        )
        
        persistState()
        logger.info("Mode \(mode.rawValue) \(enabled ? "enabled" : "disabled")")
    }
    
    /// Set user preference for a mode
    func setModePreference(_ mode: InterfaceMode, preference: InterfaceModeConfiguration.UserPreference) {
        let config = modeConfigurations[mode] ?? InterfaceModeConfiguration(mode: mode)
        modeConfigurations[mode] = InterfaceModeConfiguration(
            mode: mode,
            isEnabled: config.isEnabled,
            lastUsed: config.lastUsed,
            usageCount: config.usageCount,
            userPreference: preference
        )
        
        persistState()
        logger.info("Mode \(mode.rawValue) preference set to \(preference.rawValue)")
    }
    
    /// Get available modes based on user preferences and Enhanced Interface status
    func getAvailableModes() -> [InterfaceMode] {
        guard isModeSwitchingEnabled else {
            return [.gallery] // Only gallery available in Legacy Interface
        }
        
        return InterfaceMode.allCases.filter { mode in
            let config = modeConfigurations[mode]
            return config?.isEnabled ?? true
        }
    }
    
    // MARK: - Analytics and Insights
    
    /// Get mode usage statistics
    func getModeUsageStats() -> [InterfaceMode: (count: Int, lastUsed: Date)] {
        return modeConfigurations.compactMapValues { config in
            (count: config.usageCount, lastUsed: config.lastUsed)
        }
    }
    
    /// Get transition patterns for UX optimization
    func getTransitionPatterns() -> [String: Int] {
        var patterns: [String: Int] = [:]
        
        for transition in recentTransitions {
            let pattern = "\(transition.fromMode.rawValue)_to_\(transition.toMode.rawValue)"
            patterns[pattern, default: 0] += 1
        }
        
        return patterns
    }
    
    /// Get user's preferred complexity level based on usage
    func getPreferredComplexityLevel() -> Int {
        let stats = getModeUsageStats()
        
        // Find most used mode's complexity level
        let mostUsedMode = stats.max { $0.value.count < $1.value.count }?.key ?? .gallery
        return mostUsedMode.complexityLevel
    }
    
    // MARK: - Private Implementation
    
    private func setupDefaultConfigurations() {
        for mode in InterfaceMode.allCases {
            modeConfigurations[mode] = InterfaceModeConfiguration(mode: mode)
        }
    }
    
    private func observeInterfaceSettings() {
        // Observe Enhanced Interface toggle
        interfaceSettings.$isEnhancedInterfaceEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.isModeSwitchingEnabled = isEnabled
                
                if !isEnabled {
                    // Switch back to gallery if Enhanced Interface is disabled
                    self?.currentMode = .gallery
                }
                
                self?.logger.info("Mode switching \(isEnabled ? "enabled" : "disabled")")
            }
            .store(in: &cancellables)
    }
    
    private func updateModeUsage(_ mode: InterfaceMode) {
        let currentConfig = modeConfigurations[mode] ?? InterfaceModeConfiguration(mode: mode)
        
        modeConfigurations[mode] = InterfaceModeConfiguration(
            mode: mode,
            isEnabled: currentConfig.isEnabled,
            lastUsed: Date(),
            usageCount: currentConfig.usageCount + 1,
            userPreference: currentConfig.userPreference
        )
    }
    
    private func recordTransition(_ transition: InterfaceModeTransition) {
        recentTransitions.append(transition)
        
        // Keep only recent transitions
        if recentTransitions.count > maxRecentTransitions {
            recentTransitions.removeFirst(recentTransitions.count - maxRecentTransitions)
        }
    }
    
    private func persistState() {
        // Persist mode configurations and current state
        let encoder = JSONEncoder()
        
        if let configData = try? encoder.encode(modeConfigurations) {
            UserDefaults.standard.set(configData, forKey: "interfaceModeConfigurations")
        }
        
        UserDefaults.standard.set(currentMode.rawValue, forKey: "currentInterfaceMode")
    }
    
    private func loadPersistedState() {
        // Load mode configurations
        if let configData = UserDefaults.standard.data(forKey: "interfaceModeConfigurations") {
            let decoder = JSONDecoder()
            if let configurations = try? decoder.decode([InterfaceMode: InterfaceModeConfiguration].self, from: configData) {
                modeConfigurations = configurations
            }
        }
        
        // Load current mode
        if let modeString = UserDefaults.standard.object(forKey: "currentInterfaceMode") as? String,
           let mode = InterfaceMode(rawValue: modeString) {
            currentMode = mode
        }
    }
}

// MARK: - Supporting Types

/// Context for mode suggestions
enum ModeContext {
    case browsing       // User is casually looking through content
    case organizing     // User wants to group and organize content
    case exploring      // User wants to discover relationships
    case searching      // User has specific content to find
    case firstTime      // First time using Enhanced Interface
}

