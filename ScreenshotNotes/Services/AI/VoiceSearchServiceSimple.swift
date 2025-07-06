import Foundation
import Speech
import AVFoundation
import Combine

/// Simplified voice search service for testing compilation
@MainActor
public class VoiceSearchServiceSimple: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isListening = false
    @Published public private(set) var transcribedText = ""
    @Published public private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    // MARK: - Private Properties
    private let speechRecognizer: SFSpeechRecognizer
    
    // MARK: - Initialization
    public override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        super.init()
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }
    
    // MARK: - Public Methods
    public func requestPermissions() async -> Bool {
        let status = await requestSpeechRecognitionAuthorization()
        await MainActor.run {
            authorizationStatus = status
        }
        return status == .authorized
    }
    
    public func startListening() async throws {
        guard authorizationStatus == .authorized else {
            throw VoiceSearchErrorSimple.notAuthorized
        }
        isListening = true
    }
    
    public func stopListening() {
        isListening = false
    }
    
    // MARK: - Private Methods
    private func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - Supporting Types
public enum VoiceSearchErrorSimple: LocalizedError {
    case notAuthorized
    
    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized."
        }
    }
}
