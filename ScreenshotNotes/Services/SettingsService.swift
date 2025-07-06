import Foundation
import SwiftUI

protocol SettingsServiceProtocol {
    var automaticImportEnabled: Bool { get set }
    var deleteOriginalScreenshots: Bool { get set }
    var backgroundProcessingEnabled: Bool { get set }
    var ocrEnabled: Bool { get set }
}

@MainActor
class SettingsService: @preconcurrency SettingsServiceProtocol, ObservableObject {
    static let shared = SettingsService()
    
    @Published var automaticImportEnabled: Bool {
        didSet {
            UserDefaults.standard.set(automaticImportEnabled, forKey: "automaticImportEnabled")
        }
    }
    
    @Published var deleteOriginalScreenshots: Bool {
        didSet {
            UserDefaults.standard.set(deleteOriginalScreenshots, forKey: "deleteOriginalScreenshots")
        }
    }
    
    @Published var backgroundProcessingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(backgroundProcessingEnabled, forKey: "backgroundProcessingEnabled")
        }
    }
    
    @Published var ocrEnabled: Bool {
        didSet {
            UserDefaults.standard.set(ocrEnabled, forKey: "ocrEnabled")
        }
    }
    
    @Published var autoSubmitVoiceSearch: Bool {
        didSet {
            UserDefaults.standard.set(autoSubmitVoiceSearch, forKey: "autoSubmitVoiceSearch")
        }
    }
    
    private init() {
        self.automaticImportEnabled = UserDefaults.standard.bool(forKey: "automaticImportEnabled")
        self.deleteOriginalScreenshots = UserDefaults.standard.bool(forKey: "deleteOriginalScreenshots")
        self.backgroundProcessingEnabled = UserDefaults.standard.bool(forKey: "backgroundProcessingEnabled")
        self.ocrEnabled = UserDefaults.standard.bool(forKey: "ocrEnabled")
        self.autoSubmitVoiceSearch = UserDefaults.standard.bool(forKey: "autoSubmitVoiceSearch")
        
        // Set defaults for first launch
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            self.automaticImportEnabled = true
            self.deleteOriginalScreenshots = false
            self.backgroundProcessingEnabled = true
            self.ocrEnabled = true
            self.autoSubmitVoiceSearch = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
    
    func resetToDefaults() {
        automaticImportEnabled = true
        deleteOriginalScreenshots = false
        backgroundProcessingEnabled = true
        ocrEnabled = true
        autoSubmitVoiceSearch = true
    }
}