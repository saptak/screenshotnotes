import Foundation
import Speech
import AVFoundation
import Combine

/// Voice search service providing speech recognition and transcription capabilities
@MainActor
public class VoiceSearchService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isListening = false
    @Published public private(set) var transcribedText = ""
    @Published public private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published public private(set) var audioLevel: Float = 0.0
    @Published public private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode { audioEngine.inputNode }
    
    // MARK: - Configuration
    private let bufferSize: AVAudioFrameCount = 1024
    
    private var audioFormat: AVAudioFormat {
        return inputNode.outputFormat(forBus: 0)
    }
    
    // MARK: - Initialization
    public override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        
        super.init()
        
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        setupAudioSession()
    }
    
    deinit {
        Task { [weak self] in
            await self?.stopListening()
        }
    }
    
    // MARK: - Public Methods
    
    /// Request necessary permissions for speech recognition and microphone access
    public func requestPermissions() async -> Bool {
        // Request speech recognition authorization
        let speechStatus = await requestSpeechRecognitionAuthorization()
        await MainActor.run {
            authorizationStatus = speechStatus
        }
        
        guard speechStatus == .authorized else {
            await MainActor.run {
                errorMessage = "Speech recognition permission denied"
            }
            return false
        }
        
        // Request microphone permission
        let microphonePermissionGranted = await requestMicrophonePermission()
        if !microphonePermissionGranted {
            await MainActor.run {
                errorMessage = "Microphone permission denied"
            }
            return false
        }
        
        return true
    }
    
    /// Start continuous speech recognition
    public func startListening() async throws {
        guard authorizationStatus == .authorized else {
            throw VoiceSearchError.notAuthorized
        }
        
        guard !audioEngine.isRunning else {
            throw VoiceSearchError.alreadyListening
        }
        
        // Activate audio session
        do {
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
        } catch {
            print("⚠️ Failed to activate audio session: \(error)")
            throw VoiceSearchError.audioEngineError(error)
        }
        
        // Reset state
        recognitionTask?.cancel()
        recognitionTask = nil
        transcribedText = ""
        errorMessage = nil
        
        // Setup recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceSearchError.recognitionSetupFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Install tap on audio input
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: audioFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.updateAudioLevel(from: buffer)
        }
        
        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    // Handle specific speech recognition errors
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
                        self.errorMessage = "Speech recognition is not available in the simulator. Please test on a physical device."
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                    
                    print("⚠️ Speech recognition error: \(error)")
                    Task { [weak self] in
                        await self?.stopListening()
                    }
                }
            }
        }
        
        isListening = true
    }
    
    /// Stop speech recognition
    public func stopListening() async {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Deactivate audio session
        do {
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
        
        isListening = false
        audioLevel = 0.0
    }
    
    /// Get the final transcribed text and optimize it for search
    public func getFinalTranscription() -> String {
        return optimizeForSearch(transcribedText)
    }
    
    /// Clear the transcribed text
    public func clearTranscription() {
        transcribedText = ""
    }
    
    /// Set an error message
    public func setErrorMessage(_ message: String) {
        errorMessage = message
    }
    
    /// Clear the error message
    public func clearErrorMessage() {
        errorMessage = nil
    }
    
    /// Check if speech recognition is available
    public func isSpeechRecognitionAvailable() -> Bool {
        guard speechRecognizer.isAvailable else { return false }
        guard authorizationStatus == .authorized else { return false }
        
        #if targetEnvironment(simulator)
        // Speech recognition often doesn't work in the simulator
        return false
        #else
        return true
        #endif
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            
            if #available(iOS 17.0, *) {
                // iOS 17+ approach - use more permissive settings
                try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            } else {
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            }
            
            // Don't activate the session here - let the audio engine handle it
            #endif
        } catch {
            print("⚠️ Failed to setup audio session: \(error)")
        }
    }
    
    private func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            #if os(iOS)
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            #else
            // On macOS, assume permission is granted for now
            continuation.resume(returning: true)
            #endif
        }
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frames = Int(buffer.frameLength)
        var sum: Float = 0.0
        
        for i in 0..<frames {
            sum += abs(channelData[i])
        }
        
        let averageLevel = sum / Float(frames)
        let normalizedLevel = min(max(averageLevel * 20, 0), 1) // Normalize and amplify
        
        Task { @MainActor [weak self] in
            self?.audioLevel = normalizedLevel
        }
    }
    
    /// Optimize transcribed text for search queries
    private func optimizeForSearch(_ text: String) -> String {
        var optimized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common speech patterns that don't add to search intent
        let fillerWords = ["um", "uh", "like", "you know", "well", "so"]
        for filler in fillerWords {
            optimized = optimized.replacingOccurrences(
                of: "\\b\(filler)\\b",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Clean up multiple spaces
        optimized = optimized.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        // Convert common speech commands to search terms
        let speechCommands = [
            ("find", ""),
            ("search for", ""),
            ("look for", ""),
            ("show me", "")
        ]
        
        for (command, _) in speechCommands {
            if optimized.lowercased().hasPrefix(command) {
                optimized = String(optimized.dropFirst(command.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return optimized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types
public enum VoiceSearchError: LocalizedError {
    case notAuthorized
    case microphonePermissionDenied
    case recognitionSetupFailed
    case alreadyListening
    case audioEngineError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized."
        case .microphonePermissionDenied:
            return "Microphone permission denied."
        case .recognitionSetupFailed:
            return "Failed to setup speech recognition."
        case .alreadyListening:
            return "Already listening for speech input."
        case .audioEngineError(let error):
            return "Audio engine error: \(error.localizedDescription)"
        }
    }
}
