import Foundation

/// Registry for voice commands and their associated actions/intents (Enhanced Interface)
/// Supports synonyms, natural language variations, and robust matching
@MainActor
class VoiceCommandRegistry: ObservableObject {
    static let shared = VoiceCommandRegistry()
    @Published private(set) var commands: [VoiceCommand] = []
    private var commandMap: [String: VoiceCommand] = [:] // Lowercased phrase -> command
    private init() {
        // Register basic demo commands
        register(
            VoiceCommand(phrases: ["show settings", "open settings", "settings"], intent: .showSettings)
        )
        register(
            VoiceCommand(phrases: ["switch to gallery", "gallery mode", "show gallery"], intent: .switchToGallery)
        )
        register(
            VoiceCommand(phrases: ["switch to constellation", "constellation mode", "show constellation", "show my workspaces", "activity mode"], intent: .switchToConstellation)
        )
        register(
            VoiceCommand(phrases: ["switch to exploration", "exploration mode", "show exploration", "explore content", "relationship mode"], intent: .switchToExploration)
        )
        register(
            VoiceCommand(phrases: ["switch to search", "search mode", "show search", "find content", "search for screenshots"], intent: .switchToSearch)
        )
    }

    /// Register a new voice command (with synonyms/variations)
    func register(_ command: VoiceCommand) {
        commands.append(command)
        for phrase in command.phrases {
            commandMap[phrase.lowercased()] = command
        }
    }

    /// Unregister a command (by intent)
    func unregister(intent: VoiceCommand.Intent) {
        commands.removeAll { $0.intent == intent }
        commandMap = [:]
        for command in commands {
            for phrase in command.phrases {
                commandMap[phrase.lowercased()] = command
            }
        }
    }

    /// Find a matching command for recognized text (case-insensitive, robust)
    func matchCommand(for recognizedText: String) -> VoiceCommand? {
        let normalized = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Exact match
        if let cmd = commandMap[normalized] { return cmd }
        // Fuzzy: check if any phrase is contained in the text
        for (phrase, cmd) in commandMap {
            if normalized.contains(phrase) { return cmd }
        }
        return nil
    }
}

/// Represents a voice command with synonyms/variations and an associated intent/action
struct VoiceCommand: Identifiable, Hashable {
    let id = UUID()
    let phrases: [String] // All recognized variations
    let intent: Intent
    
    enum Intent: String, Hashable, CaseIterable {
        case showSettings
        case switchToGallery
        case switchToConstellation
        case switchToExploration
        case switchToSearch
        // Add more intents as needed
    }
} 