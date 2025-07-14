//
//  InterfaceMode.swift
//  ScreenshotNotes
//
//  Sprint 8.2.1: Interface Mode Infrastructure for Adaptive Content Hub Foundation
//  Created by Assistant on 7/14/25.
//

import Foundation
import SwiftUI

/// 4-level progressive disclosure system for Enhanced Interface
/// Gallery → Constellation → Exploration → Search
enum InterfaceMode: String, CaseIterable, Identifiable, Codable {
    case gallery = "gallery"
    case constellation = "constellation"
    case exploration = "exploration"
    case search = "search"
    
    var id: String { rawValue }
    
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .gallery:
            return "Gallery"
        case .constellation:
            return "Constellation"
        case .exploration:
            return "Exploration"
        case .search:
            return "Search"
        }
    }
    
    /// Detailed description of the mode
    var description: String {
        switch self {
        case .gallery:
            return "Browse your screenshots in a beautiful grid layout with smart organization"
        case .constellation:
            return "Discover smart content groupings and activity workspaces with AI insights"
        case .exploration:
            return "Explore relationships and connections between your content with interactive visualization"
        case .search:
            return "Find specific content with powerful conversational search and AI assistance"
        }
    }
    
    /// SF Symbol icon for the mode
    var icon: String {
        switch self {
        case .gallery:
            return "square.grid.2x2"
        case .constellation:
            return "sparkles"
        case .exploration:
            return "map"
        case .search:
            return "magnifyingglass"
        }
    }
    
    /// Accent color for the mode
    var accentColor: Color {
        switch self {
        case .gallery:
            return .blue
        case .constellation:
            return .purple
        case .exploration:
            return .orange
        case .search:
            return .green
        }
    }
    
    /// Complexity level (1-4, where 1 is simplest)
    var complexityLevel: Int {
        switch self {
        case .gallery:
            return 1
        case .constellation:
            return 2
        case .exploration:
            return 3
        case .search:
            return 4
        }
    }
    
    /// Whether this mode supports voice commands
    var supportsVoiceCommands: Bool {
        switch self {
        case .gallery:
            return true // "Show recent", "Switch to grid view"
        case .constellation:
            return true // "Show my travel workspace", "Create project constellation"
        case .exploration:
            return true // "Explore this content", "Show relationships"
        case .search:
            return true // "Find my receipts", "Search for meetings"
        }
    }
    
    /// Typical voice commands for this mode
    var voiceCommands: [String] {
        switch self {
        case .gallery:
            return ["Show recent screenshots", "Switch to gallery", "Browse my photos"]
        case .constellation:
            return ["Show my workspaces", "Create new constellation", "Find my project"]
        case .exploration:
            return ["Explore this content", "Show connections", "Find related items"]
        case .search:
            return ["Find my receipts", "Search for meetings", "Look for travel documents"]
        }
    }
    
    /// Primary workflow supported by this mode
    var primaryWorkflow: String {
        switch self {
        case .gallery:
            return "Quick browsing and visual scanning"
        case .constellation:
            return "Activity and project organization"
        case .exploration:
            return "Relationship discovery and pattern recognition"
        case .search:
            return "Targeted content retrieval and question answering"
        }
    }
    
    /// Next logical mode progression
    var nextMode: InterfaceMode? {
        switch self {
        case .gallery:
            return .constellation
        case .constellation:
            return .exploration
        case .exploration:
            return .search
        case .search:
            return nil // Search is the most advanced mode
        }
    }
    
    /// Previous mode in progression
    var previousMode: InterfaceMode? {
        switch self {
        case .gallery:
            return nil // Gallery is the simplest mode
        case .constellation:
            return .gallery
        case .exploration:
            return .constellation
        case .search:
            return .exploration
        }
    }
}

/// Configuration and state for interface mode behavior
struct InterfaceModeConfiguration: Codable {
    let mode: InterfaceMode
    let isEnabled: Bool
    let lastUsed: Date
    let usageCount: Int
    let userPreference: UserPreference
    
    enum UserPreference: String, CaseIterable, Codable {
        case auto = "auto"          // Let AI decide the best mode
        case preferred = "preferred" // User has explicitly chosen this mode
        case hidden = "hidden"      // User has disabled this mode
    }
    
    init(mode: InterfaceMode, isEnabled: Bool = true, lastUsed: Date = Date(), usageCount: Int = 0, userPreference: UserPreference = .auto) {
        self.mode = mode
        self.isEnabled = isEnabled
        self.lastUsed = lastUsed
        self.usageCount = usageCount
        self.userPreference = userPreference
    }
}

/// Interface mode transition metadata
struct InterfaceModeTransition {
    let fromMode: InterfaceMode
    let toMode: InterfaceMode
    let trigger: TransitionTrigger
    let timestamp: Date
    let duration: TimeInterval
    
    enum TransitionTrigger: String, CaseIterable {
        case userTap = "user_tap"
        case voiceCommand = "voice_command"
        case aiSuggestion = "ai_suggestion"
        case automaticProgression = "automatic_progression"
        case contextualSwitch = "contextual_switch"
    }
    
    /// Whether this transition represents progressive disclosure advancement
    var isProgression: Bool {
        return toMode.complexityLevel > fromMode.complexityLevel
    }
    
    /// Whether this transition represents simplification
    var isSimplification: Bool {
        return toMode.complexityLevel < fromMode.complexityLevel
    }
}