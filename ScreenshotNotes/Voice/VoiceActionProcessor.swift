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
    func process(transcript: String, onShowSettings: @escaping () -> Void) {
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
            feedback = "Switching to Gallery."
            lastAction = .switchToGallery
            // For demo: no-op or add closure for gallery switching in future
        }
        // Automatically reset after short delay (simulate session termination)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isProcessing = false
            self.feedback = nil
            self.lastAction = nil
        }
    }
} 