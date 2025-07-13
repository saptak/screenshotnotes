//
//  GlassDescriptions.swift
//  ScreenshotNotes
//
//  Sprint 8.1.4: Comprehensive VoiceOver Descriptions for Liquid Glass
//  Created by Assistant on 7/13/25.
//

import SwiftUI
import UIKit

/// Comprehensive VoiceOver descriptions for Liquid Glass interface elements
/// Provides rich, contextual descriptions that help users understand the interface
@MainActor
struct GlassDescriptions {
    
    // MARK: - Liquid Glass Materials
    
    /// Provides detailed VoiceOver descriptions for Liquid Glass material types
    static func liquidGlassMaterialDescription(
        type: LiquidGlassMaterial.MaterialType,
        context: String = "",
        isActive: Bool = false
    ) -> String {
        let materialQuality = switch type {
        case .ethereal: "ultra-light and nearly transparent"
        case .gossamer: "light and airy with subtle texture"
        case .crystal: "clear and well-defined"
        case .prism: "refractive with subtle color shifts"
        case .mercury: "reflective and fluid-like"
        }
        
        let contextualDescription = context.isEmpty ? "" : " \(context)"
        let activeState = isActive ? "currently active" : "available"
        
        return "Liquid Glass \(type.rawValue) material\(contextualDescription). \(materialQuality.capitalized), \(activeState)."
    }
    
    /// Describes the visual effect of Liquid Glass backgrounds
    static func liquidGlassBackgroundDescription(
        material: LiquidGlassMaterial.MaterialType,
        hasSpecularHighlights: Bool = false
    ) -> String {
        let baseDescription = "Liquid Glass background with \(material.rawValue) material"
        let highlightInfo = hasSpecularHighlights ? " featuring subtle light reflections for enhanced depth" : ""
        
        return "\(baseDescription)\(highlightInfo). Provides visual depth while maintaining excellent readability."
    }
    
    // MARK: - Interface States
    
    /// Describes Enhanced Interface vs Legacy Interface states
    static func interfaceStateDescription(
        isEnhancedInterface: Bool,
        isABTesting: Bool = false
    ) -> String {
        if isABTesting {
            return "Enhanced Interface in testing mode. Comparing different Liquid Glass materials for optimal user experience."
        }
        
        if isEnhancedInterface {
            return "Enhanced Interface active. Features Liquid Glass design, voice commands, and intelligent content organization."
        } else {
            return "Legacy Interface active. Standard interface with proven functionality and familiar interactions."
        }
    }
    
    /// Describes voice interaction states
    static func voiceInteractionDescription(
        state: GlassMicrophoneButtonState,
        hasVoicePermission: Bool = true
    ) -> String {
        if !hasVoicePermission {
            return "Voice search unavailable. Microphone permission required. Tap to request permission."
        }
        
        switch state {
        case .ready:
            return "Voice search ready. Tap to start voice input. Microphone is prepared to listen for your search query."
        case .listening:
            return "Voice search listening. Speak your search query now. The system is actively capturing your voice input."
        case .processing:
            return "Voice search processing. Analyzing your speech and extracting search terms. Please wait a moment."
        case .results:
            return "Voice search completed successfully. Results are now available. Tap to start a new search or continue with conversation."
        case .error:
            return "Voice search error occurred. There was a problem processing your voice input. Tap to try again."
        case .conversation:
            return "Conversation mode active. The system is ready for follow-up questions. Continue speaking or tap to end conversation."
        }
    }
    
    // MARK: - Performance and Settings
    
    /// Describes performance metrics in an accessible way
    static func performanceMetricDescription(
        title: String,
        value: String,
        isOptimal: Bool,
        additionalContext: String = ""
    ) -> String {
        let statusDescription = isOptimal ? "performing optimally" : "needs attention"
        let actionHint = isOptimal ? "" : " Double tap for optimization suggestions."
        let contextInfo = additionalContext.isEmpty ? "" : " \(additionalContext)"
        
        return "\(title): \(value), \(statusDescription)\(contextInfo).\(actionHint)"
    }
    
    /// Describes A/B testing material selection
    static func abTestingMaterialDescription(
        currentMaterial: LiquidGlassMaterial.MaterialType,
        rating: Int,
        isSelected: Bool = false
    ) -> String {
        let selectionState = isSelected ? "currently selected" : "available for selection"
        let ratingInfo = rating > 0 ? " Rated \(rating) out of 5 stars." : " No rating yet."
        
        return "\(liquidGlassMaterialDescription(type: currentMaterial, isActive: isSelected))\(ratingInfo) \(selectionState.capitalized). Double tap to select and test this material."
    }
    
    /// Describes material rating controls
    static func materialRatingDescription(
        rating: Int,
        maxRating: Int = 5,
        materialType: LiquidGlassMaterial.MaterialType
    ) -> String {
        if rating == 0 {
            return "Rate \(materialType.rawValue) material. No rating provided yet. Use adjustable actions to set rating from 1 to \(maxRating) stars."
        } else {
            return "\(materialType.rawValue) material rated \(rating) out of \(maxRating) stars. Use adjustable actions to change rating."
        }
    }
    
    // MARK: - Settings and Configuration
    
    /// Describes Enhanced Interface settings
    static func enhancedInterfaceSettingsDescription(
        isEnabled: Bool,
        featuresAvailable: [String] = []
    ) -> String {
        let enabledState = isEnabled ? "enabled" : "disabled"
        let featuresList = featuresAvailable.isEmpty ? "" : " Available features: \(featuresAvailable.joined(separator: ", "))"
        
        return "Enhanced Interface \(enabledState). Provides advanced Liquid Glass design and voice interactions.\(featuresList)"
    }
    
    /// Describes accessibility level status
    static func accessibilityLevelDescription(
        level: LiquidGlassAccessibilityService.AccessibilityLevel,
        adaptationsApplied: [String] = []
    ) -> String {
        let levelDescription = switch level {
        case .standard: "Standard accessibility with system defaults"
        case .enhanced: "Enhanced accessibility with additional adaptations"
        case .maximum: "Maximum accessibility with comprehensive adaptations"
        }
        
        let adaptationsInfo = adaptationsApplied.isEmpty ? "" : " Applied adaptations: \(adaptationsApplied.joined(separator: ", "))"
        
        return "\(levelDescription).\(adaptationsInfo)"
    }
    
    // MARK: - Content Organization
    
    /// Describes content constellation features
    static func contentConstellationDescription(
        workspaceName: String,
        itemCount: Int,
        completionPercentage: Int
    ) -> String {
        let itemText = itemCount == 1 ? "item" : "items"
        return "\(workspaceName) workspace. Contains \(itemCount) \(itemText). \(completionPercentage)% complete. Double tap to open workspace."
    }
    
    /// Describes triage functionality
    static func triageDescription(
        candidateCount: Int,
        category: String = "items"
    ) -> String {
        let itemText = candidateCount == 1 ? "item" : "items"
        return "Triage mode. Found \(candidateCount) \(category) \(itemText) for review. Use voice commands or touch to keep, delete, or archive items."
    }
    
    // MARK: - Navigation and Interaction
    
    /// Describes mode switching
    static func modeSwitchingDescription(
        currentMode: String,
        availableModes: [String] = []
    ) -> String {
        let modesInfo = availableModes.isEmpty ? "" : " Available modes: \(availableModes.joined(separator: ", "))"
        return "Current mode: \(currentMode).\(modesInfo) Double tap to switch modes."
    }
    
    /// Describes gesture alternatives
    static func gestureAlternativeDescription(
        action: String,
        alternatives: [String] = []
    ) -> String {
        let alternativesList = alternatives.isEmpty ? "" : " Alternative methods: \(alternatives.joined(separator: ", "))"
        return "\(action) gesture available.\(alternativesList)"
    }
    
    // MARK: - Error States and Recovery
    
    /// Describes error states with recovery options
    static func errorStateDescription(
        error: String,
        recoveryOptions: [String] = []
    ) -> String {
        let optionsInfo = recoveryOptions.isEmpty ? "" : " Recovery options: \(recoveryOptions.joined(separator: ", "))"
        return "Error: \(error).\(optionsInfo)"
    }
    
    /// Describes loading states
    static func loadingStateDescription(
        task: String,
        progress: Double? = nil
    ) -> String {
        let progressInfo = if let progress = progress {
            " Progress: \(Int(progress * 100))% complete"
        } else {
            ""
        }
        
        return "Loading \(task).\(progressInfo) Please wait."
    }
    
    // MARK: - Contextual Hints
    
    /// Provides contextual hints for complex interactions
    static func contextualHintDescription(
        element: String,
        primaryAction: String,
        secondaryActions: [String] = []
    ) -> String {
        let secondaryInfo = secondaryActions.isEmpty ? "" : " Additional actions: \(secondaryActions.joined(separator: ", "))"
        return "\(element). \(primaryAction).\(secondaryInfo)"
    }
    
    /// Describes keyboard navigation
    static func keyboardNavigationDescription(
        currentFocus: String,
        navigationInstructions: [String] = []
    ) -> String {
        let instructionsInfo = navigationInstructions.isEmpty ? "" : " Navigation: \(navigationInstructions.joined(separator: ", "))"
        return "Currently focused on \(currentFocus).\(instructionsInfo)"
    }
    
    // MARK: - Dynamic Content
    
    /// Describes dynamic content changes
    static func dynamicContentDescription(
        change: String,
        newState: String,
        additionalInfo: String = ""
    ) -> String {
        let infoSuffix = additionalInfo.isEmpty ? "" : " \(additionalInfo)"
        return "\(change) \(newState).\(infoSuffix)"
    }
    
    /// Describes search results
    static func searchResultDescription(
        resultCount: Int,
        searchTerm: String,
        hasFilters: Bool = false
    ) -> String {
        let resultText = resultCount == 1 ? "result" : "results"
        let filterInfo = hasFilters ? " with active filters" : ""
        
        return "Found \(resultCount) \(resultText) for '\(searchTerm)'\(filterInfo). Navigate through results using standard gestures."
    }
}

// MARK: - Accessibility Action Descriptions

extension GlassDescriptions {
    
    /// Describes available accessibility actions
    static func accessibilityActionDescription(
        actionName: String,
        description: String,
        gesture: String = "double tap"
    ) -> String {
        return "\(actionName): \(description) Activate with \(gesture)."
    }
    
    /// Describes custom accessibility actions
    static func customActionDescription(
        actions: [String: String]
    ) -> String {
        let actionDescriptions = actions.map { "\($0.key): \($0.value)" }
        return "Custom actions available: \(actionDescriptions.joined(separator: ", "))"
    }
}

// MARK: - Localization Support

extension GlassDescriptions {
    
    /// Provides localized descriptions (foundation for future localization)
    static func localizedDescription(
        key: String,
        fallback: String,
        arguments: [String] = []
    ) -> String {
        // For now, return fallback. In future, implement proper localization
        let formattedString = arguments.isEmpty ? fallback : String(format: fallback, arguments.joined(separator: ", "))
        return formattedString
    }
} 