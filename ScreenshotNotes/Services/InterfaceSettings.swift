//
//  InterfaceSettings.swift
//  ScreenshotNotes
//
//  Sprint 8.1.1: Enhanced Interface Settings Toggle
//  Created by Assistant on 7/13/25.
//

import Foundation
import SwiftUI

/// Interface type selection for user experience
enum InterfaceType: String, CaseIterable {
    case legacy = "Legacy Interface"
    case enhanced = "Enhanced Interface (Beta)"
    
    var description: String {
        switch self {
        case .legacy:
            return "The proven, reliable interface with all current features."
        case .enhanced:
            return "Advanced Liquid Glass design with voice controls and content constellation features."
        }
    }
    
    var icon: String {
        switch self {
        case .legacy:
            return "rectangle.grid.2x2"
        case .enhanced:
            return "sparkles.rectangle.stack"
        }
    }
}

/// Settings management for Enhanced Interface toggle and configuration
/// This service manages the transition between Legacy and Enhanced interfaces
@MainActor
class InterfaceSettings: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the Enhanced Interface is enabled (enabled by default)
    @Published var isEnhancedInterfaceEnabled: Bool = true
    
    /// User's preferred interface type
    @Published var interfacePreference: InterfaceType = .enhanced
    
    /// Whether user has seen the Enhanced Interface introduction
    @Published var hasSeenEnhancedInterfaceIntro: Bool = false {
        didSet {
            UserDefaults.standard.set(hasSeenEnhancedInterfaceIntro, forKey: "hasSeenEnhancedInterfaceIntro")
        }
    }
    
    /// Whether to show Enhanced Interface features in Settings (for debugging)
    @Published var showEnhancedInterfaceOptions: Bool = true {
        didSet {
            UserDefaults.standard.set(showEnhancedInterfaceOptions, forKey: "showEnhancedInterfaceOptions")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether the user is currently using the Enhanced Interface
    var isUsingEnhancedInterface: Bool {
        return isEnhancedInterfaceEnabled && interfacePreference == .enhanced
    }
    
    /// Whether the Legacy Interface is active
    var isUsingLegacyInterface: Bool {
        return !isUsingEnhancedInterface
    }
    
    // MARK: - Initialization
    
    init() {
        // Load saved preferences - default to Enhanced Interface for new users
        let savedEnabled = UserDefaults.standard.object(forKey: "isEnhancedInterfaceEnabled") as? Bool ?? true
        let savedPreference = UserDefaults.standard.string(forKey: "interfacePreference")
        let preference = InterfaceType(rawValue: savedPreference ?? InterfaceType.enhanced.rawValue) ?? .enhanced
        
        // Set values directly to avoid triggering observers during initialization
        self.isEnhancedInterfaceEnabled = savedEnabled
        self.interfacePreference = preference
        
        self.hasSeenEnhancedInterfaceIntro = UserDefaults.standard.bool(forKey: "hasSeenEnhancedInterfaceIntro")
        
        // Show Enhanced Interface options in Settings for Sprint 8 development
        // In production, this would be false by default
        self.showEnhancedInterfaceOptions = UserDefaults.standard.object(forKey: "showEnhancedInterfaceOptions") as? Bool ?? true
        
        // Load A/B testing settings (Sprint 8.1.2)
        self.isABTestingEnabled = UserDefaults.standard.bool(forKey: "isABTestingEnabled")
        let savedMaterialType = UserDefaults.standard.string(forKey: "abTestMaterialType")
        self.abTestMaterialType = LiquidGlassMaterial.MaterialType(rawValue: savedMaterialType ?? "crystal") ?? .crystal
        self.abTestRating = UserDefaults.standard.integer(forKey: "abTestRating")
        self.enhancedInterfaceFeedback = UserDefaults.standard.string(forKey: "enhancedInterfaceFeedback") ?? ""
        self.wantsBetaParticipation = UserDefaults.standard.bool(forKey: "wantsBetaParticipation")
        
        // Ensure consistency between properties
        if savedEnabled && preference == .legacy {
            self.isEnhancedInterfaceEnabled = false
            UserDefaults.standard.set(false, forKey: "isEnhancedInterfaceEnabled")
        } else if !savedEnabled && preference == .enhanced {
            self.interfacePreference = .legacy
            UserDefaults.standard.set(InterfaceType.legacy.rawValue, forKey: "interfacePreference")
        }
    }
    
    // MARK: - Interface Management
    
    /// Safely updates interface preference and enabled state together
    func updateInterfacePreference(_ newPreference: InterfaceType, withAnimation: Bool = true) {
        let isEnabled = (newPreference == .enhanced)
        
        if withAnimation {
            SwiftUI.withAnimation(.easeInOut(duration: 0.3)) {
                self.interfacePreference = newPreference
                self.isEnhancedInterfaceEnabled = isEnabled
            }
        } else {
            self.interfacePreference = newPreference
            self.isEnhancedInterfaceEnabled = isEnabled
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(newPreference.rawValue, forKey: "interfacePreference")
        UserDefaults.standard.set(isEnabled, forKey: "isEnhancedInterfaceEnabled")
    }
    
    /// Switches to Enhanced Interface with optional animation
    func enableEnhancedInterface(withAnimation: Bool = true) {
        updateInterfacePreference(.enhanced, withAnimation: withAnimation)
    }
    
    /// Switches to Legacy Interface with optional animation
    func enableLegacyInterface(withAnimation: Bool = true) {
        updateInterfacePreference(.legacy, withAnimation: withAnimation)
    }
    
    /// Toggles between interfaces
    func toggleInterface() {
        switch interfacePreference {
        case .legacy:
            enableEnhancedInterface()
        case .enhanced:
            enableLegacyInterface()
        }
    }
    
    /// Marks that user has seen the Enhanced Interface introduction
    func markIntroductionSeen() {
        hasSeenEnhancedInterfaceIntro = true
    }
    
    /// Resets all interface settings to defaults
    func resetToDefaults() {
        SwiftUI.withAnimation(.easeInOut(duration: 0.3)) {
            updateInterfacePreference(.enhanced, withAnimation: false) // Avoid double animation
            hasSeenEnhancedInterfaceIntro = false
            showEnhancedInterfaceOptions = true
        }
        // Save additional settings
        UserDefaults.standard.set(false, forKey: "hasSeenEnhancedInterfaceIntro")
        UserDefaults.standard.set(true, forKey: "showEnhancedInterfaceOptions")
    }
    
    // MARK: - Feature Availability
    
    /// Whether voice features are available (Enhanced Interface only)
    var isVoiceEnabled: Bool {
        return isUsingEnhancedInterface
    }
    
    /// Whether content constellation features are available (Enhanced Interface only)
    var isContentConstellationEnabled: Bool {
        return isUsingEnhancedInterface
    }
    
    /// Whether intelligent triage features are available (Enhanced Interface only)
    var isIntelligentTriageEnabled: Bool {
        return isUsingEnhancedInterface
    }
    
    /// Whether Liquid Glass materials are available (Enhanced Interface only)
    var isLiquidGlassEnabled: Bool {
        return isUsingEnhancedInterface
    }
    
    // MARK: - A/B Testing Support (Sprint 8.1.2)
    
    /// Whether A/B testing mode is enabled for material comparison
    @Published var isABTestingEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isABTestingEnabled, forKey: "isABTestingEnabled")
        }
    }
    
    /// Current material being tested in A/B mode
    @Published var abTestMaterialType: LiquidGlassMaterial.MaterialType = .crystal {
        didSet {
            UserDefaults.standard.set(abTestMaterialType.rawValue, forKey: "abTestMaterialType")
        }
    }
    
    /// User rating for current A/B test (1-5 stars)
    @Published var abTestRating: Int = 0 {
        didSet {
            UserDefaults.standard.set(abTestRating, forKey: "abTestRating")
        }
    }
    
    /// Whether user has provided feedback for current A/B test
    var hasProvidedABTestFeedback: Bool {
        return abTestRating > 0
    }
    
    /// User feedback comments for Enhanced Interface
    @Published var enhancedInterfaceFeedback: String = "" {
        didSet {
            UserDefaults.standard.set(enhancedInterfaceFeedback, forKey: "enhancedInterfaceFeedback")
        }
    }
    
    /// Whether user wants to participate in future beta testing
    @Published var wantsBetaParticipation: Bool = false {
        didSet {
            UserDefaults.standard.set(wantsBetaParticipation, forKey: "wantsBetaParticipation")
        }
    }
}

// MARK: - Environment Values

/// Environment key for interface settings
private struct InterfaceSettingsKey: @preconcurrency EnvironmentKey {
    @MainActor
    static let defaultValue = InterfaceSettings()
}

extension EnvironmentValues {
    var interfaceSettings: InterfaceSettings {
        get { self[InterfaceSettingsKey.self] }
        set { self[InterfaceSettingsKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Provides interface settings to child views
    func interfaceSettings(_ settings: InterfaceSettings) -> some View {
        environment(\.interfaceSettings, settings)
    }
}

// MARK: - Interface Type Selection View

/// SwiftUI view for interface type selection in Settings
struct InterfaceTypeSelectionView: View {
    @ObservedObject var settings: InterfaceSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(InterfaceType.allCases, id: \.self) { interfaceType in
                InterfaceOptionRow(
                    interfaceType: interfaceType,
                    isSelected: settings.interfacePreference == interfaceType,
                    action: {
                        settings.updateInterfacePreference(interfaceType)
                    }
                )
            }
        }
    }
}

/// Individual interface option row
private struct InterfaceOptionRow: View {
    let interfaceType: InterfaceType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: interfaceType.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(interfaceType.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(interfaceType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Support

#if DEBUG
#Preview("Interface Settings") {
    NavigationView {
        VStack(spacing: 20) {
            Text("Interface Selection")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            InterfaceTypeSelectionView(settings: InterfaceSettings())
                .padding()
            
            Spacer()
        }
        .padding()
        .navigationTitle("Settings")
    }
}
#endif