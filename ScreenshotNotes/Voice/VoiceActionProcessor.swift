import Foundation
import SwiftUI

/// Processes recognized voice commands and triggers app actions (Enhanced Interface)
/// Single-tap activation: tap → listen → process → complete → return to inactive
@MainActor
class VoiceActionProcessor: ObservableObject {
    static let shared = VoiceActionProcessor()
    @Published var lastAction: VoiceCommand.Intent? = nil
    @Published var feedback: String? = nil
    @Published var isProcessing: Bool = false
    private init() {}

    /// Process a recognized voice command (from transcript)
    /// - Parameters:
    ///   - transcript: The recognized speech text
    ///   - onShowSettings: Closure to call for "show settings" action
    ///   - onModeSwitched: Closure to call after mode switch (optional, for UI feedback)
    func process(transcript: String, onShowSettings: @escaping () -> Void, onModeSwitched: ((InterfaceMode) -> Void)? = nil) {
        isProcessing = true
        feedback = nil
        lastAction = nil
        guard let command = VoiceCommandRegistry.shared.matchCommand(for: transcript) else {
            feedback = "Sorry, I didn't understand that command."
            isProcessing = false
            return
        }
        switch command.intent {
        case .showSettings:
            feedback = "Opening Settings."
            lastAction = .showSettings
            onShowSettings()
        case .switchToGallery:
            handleModeSwitch(.gallery, onModeSwitched)
        case .switchToConstellation:
            handleModeSwitch(.constellation, onModeSwitched)
        case .switchToExploration:
            handleModeSwitch(.exploration, onModeSwitched)
        case .switchToSearch:
            handleModeSwitch(.search, onModeSwitched)
        }
        // Automatically reset after short delay (simulate session termination)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isProcessing = false
            self.feedback = nil
            self.lastAction = nil
        }
    }

    /// Helper to robustly switch modes with feedback
    private func handleModeSwitch(_ mode: InterfaceMode, _ onModeSwitched: ((InterfaceMode) -> Void)?) {
        let manager = InterfaceModeManager.shared
        guard manager.isModeSwitchingEnabled else {
            feedback = "Mode switching is not available."
            return
        }
        if manager.currentMode == mode {
            feedback = "Already in \(mode.displayName) mode."
            return
        }
        if !manager.getAvailableModes().contains(mode) {
            feedback = "\(mode.displayName) mode is not available."
            return
        }
        feedback = "Switching to \(mode.displayName) mode."
        lastAction = VoiceCommand.Intent(rawValue: "switchTo\(mode.displayName)")
        manager.switchToMode(mode, trigger: .voiceCommand)
        onModeSwitched?(mode)
    }
} 