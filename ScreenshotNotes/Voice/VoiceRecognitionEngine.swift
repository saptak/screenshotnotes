import Foundation
import Speech
import AVFoundation
import os.log

/// Core voice recognition engine for Enhanced Interface mode (single-tap activation)
/// Robust, beautiful, and reliable voice recognition with clear state management
@MainActor
class VoiceRecognitionEngine: ObservableObject {
    static let shared = VoiceRecognitionEngine()
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "VoiceRecognitionEngine")
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    @Published private(set) var state: State = .inactive
    @Published private(set) var transcript: String = ""
    @Published private(set) var error: String? = nil
    private init() {}

    /// Voice recognition states
    enum State: String, Equatable {
        case inactive      // Not listening
        case active        // Ready to listen (mic tapped)
        case listening     // Actively listening for speech
        case processing    // Processing result
        case error         // Error occurred
    }

    /// Request permission for speech recognition and microphone
    func requestPermissions() async -> Bool {
        let speechStatus = await SFSpeechRecognizer.requestAuthorization()
        let audioStatus = await AVAudioApplication.requestRecordPermission()
        let granted = (speechStatus == .authorized) && audioStatus
        logger.info("Speech permission: \(speechStatus.rawValue), Audio permission: \(audioStatus)")
        return granted
    }

    /// Start a single voice recognition session (tap-to-activate)
    func startRecognition() async {
        guard state == .inactive || state == .error else { return }
        state = .active
        transcript = ""
        error = nil
        logger.info("🎤 Voice recognition activated")
        do {
            guard await requestPermissions() else {
                state = .error
                error = "Microphone or speech recognition permission denied."
                logger.error("❌ Permission denied for voice recognition")
                return
            }
            try await startListening()
        } catch {
            state = .error
            self.error = error.localizedDescription
            logger.error("❌ Voice recognition error: \(error.localizedDescription)")
        }
    }

    /// Stop the current recognition session (user or system action)
    func stopRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        state = .inactive
        logger.info("🛑 Voice recognition stopped")
    }

    /// Internal: Start listening and process speech
    private func startListening() async throws {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "VoiceRecognition", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"])
        }
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw NSError(domain: "VoiceRecognition", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create recognition request"])
        }
        let inputNode = audioEngine.inputNode
        request.shouldReportPartialResults = true
        state = .listening
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                if result.isFinal {
                    self.state = .processing
                    self.stopRecognition()
                }
            }
            if let error = error {
                self.state = .error
                self.error = error.localizedDescription
                self.stopRecognition()
            }
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        logger.info("🎧 Audio engine started for voice recognition")
    }
}

extension AVAudioApplication {
    /// Async wrapper for AVAudioSession.sharedInstance().requestRecordPermission
    static func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
} 