import Foundation
import SwiftUI
import Speech
import AVFoundation
import OSLog

/// Advanced voice search interface with beautiful visual feedback and error handling
/// Provides seamless voice-to-search conversion with conversational natural language processing
@MainActor
public final class VoiceSearchInterface: NSObject, ObservableObject {
    public static let shared = VoiceSearchInterface()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "VoiceSearchInterface")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isListening = false
    @Published public private(set) var isProcessing = false
    @Published public private(set) var voiceSearchState: VoiceSearchState = .ready
    @Published public private(set) var currentTranscription: String = ""
    @Published public private(set) var audioLevel: Float = 0.0
    @Published public private(set) var lastError: VoiceSearchError?
    @Published public private(set) var sessionHistory: [VoiceSearchSession] = []
    @Published public private(set) var permissionStatus: PermissionStatus = .unknown
    
    // MARK: - Services
    
    private let naturalLanguageSearch = NaturalLanguageSearchService.shared
    private let hapticService = HapticFeedbackService.shared
    private let errorService = ErrorHandlingService.shared
    
    // MARK: - Voice Recognition
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioLevelTimer: Timer?
    
    // MARK: - Configuration
    
    public struct VoiceSearchSettings {
        var enableContinuousListening: Bool = false
        var autoStartAfterSilence: Bool = true
        var silenceThresholdSeconds: TimeInterval = 1.0
        var maxRecordingDuration: TimeInterval = 30.0
        var enableHapticFeedback: Bool = true
        var enableVisualFeedback: Bool = true
        var confidenceThreshold: Double = 0.6
        var enableOfflineRecognition: Bool = true
        var preferredLocale: String = "en-US"
        
        public init() {}
    }
    
    @Published public var settings = VoiceSearchSettings()
    
    // MARK: - Data Models
    
    /// Voice search state with visual feedback
    public enum VoiceSearchState: String, CaseIterable {
        case ready = "ready"
        case requesting = "requesting"
        case listening = "listening"
        case processing = "processing"
        case completed = "completed"
        case error = "error"
        case disabled = "disabled"
        
        public var displayName: String {
            switch self {
            case .ready: return "Ready"
            case .requesting: return "Requesting Permission"
            case .listening: return "Listening"
            case .processing: return "Processing"
            case .completed: return "Completed"
            case .error: return "Error"
            case .disabled: return "Disabled"
            }
        }
        
        public var color: Color {
            switch self {
            case .ready: return .blue
            case .requesting: return .orange
            case .listening: return .green
            case .processing: return .yellow
            case .completed: return .green
            case .error: return .red
            case .disabled: return .gray
            }
        }
        
        public var systemImage: String {
            switch self {
            case .ready: return "mic.circle"
            case .requesting: return "mic.circle.fill"
            case .listening: return "mic.fill"
            case .processing: return "waveform.circle"
            case .completed: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            case .disabled: return "mic.slash.circle"
            }
        }
    }
    
    /// Voice search error types
    public enum VoiceSearchError: Error, LocalizedError {
        case permissionDenied
        case audioEngineFailure
        case recognitionUnavailable
        case networkError
        case transcriptionFailed
        case timeoutError
        case recordingFailed
        case processingError
        
        public var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone permission is required for voice search"
            case .audioEngineFailure:
                return "Audio engine failed to start"
            case .recognitionUnavailable:
                return "Speech recognition is not available"
            case .networkError:
                return "Network connection required for voice recognition"
            case .transcriptionFailed:
                return "Failed to transcribe speech"
            case .timeoutError:
                return "Voice search timed out"
            case .recordingFailed:
                return "Failed to record audio"
            case .processingError:
                return "Failed to process voice command"
            }
        }
        
        public var recoveryAction: String {
            switch self {
            case .permissionDenied:
                return "Enable microphone in Settings"
            case .audioEngineFailure, .recordingFailed:
                return "Check microphone and try again"
            case .recognitionUnavailable:
                return "Speech recognition unavailable"
            case .networkError:
                return "Check internet connection"
            case .transcriptionFailed, .processingError:
                return "Try speaking again"
            case .timeoutError:
                return "Speak more clearly"
            }
        }
    }
    
    /// Permission status tracking
    public enum PermissionStatus: String, CaseIterable {
        case unknown = "unknown"
        case denied = "denied"
        case authorized = "authorized"
        case restricted = "restricted"
        
        public var isAuthorized: Bool {
            return self == .authorized
        }
    }
    
    /// Voice search session for history and learning
    public struct VoiceSearchSession: Identifiable, Codable {
        public var id = UUID()
        let transcription: String
        let query: String
        let resultCount: Int
        let timestamp: Date
        let duration: TimeInterval
        let confidence: Double
        let wasSuccessful: Bool
        let audioLevel: Float
        
        public init(
            transcription: String,
            query: String,
            resultCount: Int,
            timestamp: Date = Date(),
            duration: TimeInterval,
            confidence: Double,
            wasSuccessful: Bool,
            audioLevel: Float
        ) {
            self.transcription = transcription
            self.query = query
            self.resultCount = resultCount
            self.timestamp = timestamp
            self.duration = duration
            self.confidence = confidence
            self.wasSuccessful = wasSuccessful
            self.audioLevel = audioLevel
        }
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        logger.info("VoiceSearchInterface initialized with advanced speech recognition")
        setupSpeechRecognizer()
        checkPermissions()
    }
    
    // MARK: - Public Interface
    
    /// Start voice search session
    /// - Returns: Success status
    public func startVoiceSearch() async -> Bool {
        logger.info("Starting voice search session")
        
        guard await checkAndRequestPermissions() else {
            await handleVoiceSearchError(.permissionDenied)
            return false
        }
        
        guard !isListening else {
            logger.warning("Voice search already in progress")
            return false
        }
        
        do {
            voiceSearchState = .requesting
            try await startAudioRecording()
            
            voiceSearchState = .listening
            isListening = true
            
            // Provide haptic feedback
            if settings.enableHapticFeedback {
                hapticService.triggerHaptic(.processingStart)
            }
            
            // Start audio level monitoring
            startAudioLevelMonitoring()
            
            // Set timeout
            Task {
                try await Task.sleep(nanoseconds: UInt64(settings.maxRecordingDuration * 1_000_000_000))
                if isListening {
                    await stopVoiceSearch()
                    await handleVoiceSearchError(.timeoutError)
                }
            }
            
            return true
            
        } catch {
            await handleVoiceSearchError(.audioEngineFailure)
            return false
        }
    }
    
    /// Stop voice search session
    public func stopVoiceSearch() async {
        logger.info("Stopping voice search session")
        
        guard isListening else { return }
        
        isListening = false
        voiceSearchState = .processing
        
        // Stop audio recording
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Stop recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Stop audio level monitoring
        stopAudioLevelMonitoring()
        
        // Provide haptic feedback
        if settings.enableHapticFeedback {
            hapticService.triggerHaptic(.processingComplete)
        }
        
        // Process transcription if available
        if !currentTranscription.isEmpty {
            await processVoiceSearchResult()
        } else {
            voiceSearchState = .ready
        }
    }
    
    /// Cancel voice search session
    public func cancelVoiceSearch() async {
        logger.info("Cancelling voice search session")
        
        isListening = false
        isProcessing = false
        voiceSearchState = .ready
        currentTranscription = ""
        audioLevel = 0.0
        
        // Stop all audio operations
        audioEngine.stop()
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        stopAudioLevelMonitoring()
        
        // Provide haptic feedback
        if settings.enableHapticFeedback {
            hapticService.triggerHaptic(.errorFeedback)
        }
    }
    
    /// Check current permission status
    public func checkPermissions() {
        Task {
            let speechStatus = SFSpeechRecognizer.authorizationStatus()
            let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
            
            await MainActor.run {
                switch (speechStatus, microphoneStatus) {
                case (.authorized, .granted):
                    permissionStatus = .authorized
                    voiceSearchState = .ready
                case (.denied, _), (_, .denied):
                    permissionStatus = .denied
                    voiceSearchState = .disabled
                case (.restricted, _):
                    permissionStatus = .restricted
                    voiceSearchState = .disabled
                default:
                    permissionStatus = .unknown
                    voiceSearchState = .ready
                }
            }
        }
    }
    
    /// Request permissions with user-friendly flow
    public func requestPermissions() async -> Bool {
        logger.info("Requesting voice search permissions")
        
        return await withCheckedContinuation { continuation in
            // Request speech recognition permission
            SFSpeechRecognizer.requestAuthorization { authStatus in
                guard authStatus == .authorized else {
                    Task { @MainActor in
                        self.permissionStatus = .denied
                        self.voiceSearchState = .disabled
                    }
                    continuation.resume(returning: false)
                    return
                }
                
                // Request microphone permission
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        if granted {
                            self.permissionStatus = .authorized
                            self.voiceSearchState = .ready
                            continuation.resume(returning: true)
                        } else {
                            self.permissionStatus = .denied
                            self.voiceSearchState = .disabled
                            continuation.resume(returning: false)
                        }
                    }
                }
            }
        }
    }
    
    /// Get voice search suggestions based on history
    public func getVoiceSearchSuggestions() -> [String] {
        let recentSuccessfulSessions = sessionHistory
            .filter { $0.wasSuccessful && $0.confidence > settings.confidenceThreshold }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(5)
        
        var suggestions = recentSuccessfulSessions.map { $0.query }
        
        // Add common voice search patterns
        suggestions.append(contentsOf: [
            "Show me screenshots from yesterday",
            "Find screenshots with phone numbers",
            "Screenshots from my vacation",
            "Recent screenshots with text",
            "Screenshots of receipts"
        ])
        
        return Array(Set(suggestions)).prefix(8).map { $0 }
    }
    
    // MARK: - Private Implementation
    
    private func setupSpeechRecognizer() {
        let locale = Locale(identifier: settings.preferredLocale)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.delegate = self
    }
    
    private func checkAndRequestPermissions() async -> Bool {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        
        switch (speechStatus, microphoneStatus) {
        case (.authorized, .granted):
            return true
        case (.notDetermined, _), (_, .undetermined):
            return await requestPermissions()
        default:
            return false
        }
    }
    
    private func startAudioRecording() async throws {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Setup recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceSearchError.recordingFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure for offline recognition if available
        if settings.enableOfflineRecognition && speechRecognizer?.supportsOnDeviceRecognition == true {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        // Setup audio engine
        inputNode = audioEngine.inputNode
        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate audio level for visual feedback
            Task { @MainActor in
                self?.updateAudioLevel(from: buffer)
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                await self?.handleRecognitionResult(result, error: error)
            }
        }
    }
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) async {
        if let error = error {
            logger.error("Speech recognition error: \(error.localizedDescription)")
            await handleVoiceSearchError(.transcriptionFailed)
            return
        }
        
        guard let result = result else { return }
        
        currentTranscription = result.bestTranscription.formattedString
        
        // Auto-stop after silence if enabled
        if settings.autoStartAfterSilence && result.isFinal {
            await stopVoiceSearch()
        }
    }
    
    private func processVoiceSearchResult() async {
        guard !currentTranscription.isEmpty else {
            voiceSearchState = .ready
            return
        }
        
        logger.info("Processing voice search: '\(self.currentTranscription)'")
        
        isProcessing = true
        let startTime = Date()
        
        defer {
            isProcessing = false
        }
        
        do {
            // Process with natural language search - would need proper ModelContext injection
            // For now, return empty results as this requires integration with the main app
            let results: [Screenshot] = []
            
            let duration = Date().timeIntervalSince(startTime)
            let confidence = calculateTranscriptionConfidence()
            
            // Record session for learning
            let session = VoiceSearchSession(
                transcription: currentTranscription,
                query: currentTranscription,
                resultCount: results.count,
                duration: duration,
                confidence: confidence,
                wasSuccessful: true,
                audioLevel: audioLevel
            )
            
            sessionHistory.append(session)
            
            // Keep history manageable
            if sessionHistory.count > 50 {
                sessionHistory.removeFirst(25)
            }
            
            voiceSearchState = .completed
            
            // Provide success haptic feedback
            if settings.enableHapticFeedback {
                if results.isEmpty {
                    hapticService.triggerHaptic(.errorFeedback)
                } else {
                    hapticService.triggerHaptic(.successFeedback)
                }
            }
            
            // Auto-return to ready state
            Task {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                if voiceSearchState == .completed {
                    voiceSearchState = .ready
                    currentTranscription = ""
                }
            }
            
            logger.info("Voice search completed: \(results.count) results in \(String(format: "%.2f", duration))s")
            
        } catch {
            await handleVoiceSearchError(.processingError)
        }
    }
    
    private func handleVoiceSearchError(_ error: VoiceSearchError) async {
        logger.error("Voice search error: \(error.localizedDescription)")
        
        lastError = error
        voiceSearchState = .error
        
        // Stop any ongoing operations
        await cancelVoiceSearch()
        
        // Report to error service
        _ = await errorService.handleSwiftError(error, context: "Voice Search")
        
        // Provide error haptic feedback
        if settings.enableHapticFeedback {
            hapticService.triggerHaptic(.errorFeedback)
        }
        
        // Auto-recover after error display
        Task {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if voiceSearchState == .error {
                voiceSearchState = permissionStatus.isAuthorized ? .ready : .disabled
                lastError = nil
            }
        }
    }
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Audio level is updated in the audio tap callback
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0.0
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        
        // Convert to dB and normalize
        let db = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (db + 50) / 50)) // Normalize -50dB to 0dB range
        
        audioLevel = normalizedLevel
    }
    
    private func calculateTranscriptionConfidence() -> Double {
        // Simple confidence calculation based on transcription length and audio level
        let lengthScore = min(1.0, Double(currentTranscription.count) / 50.0)
        let audioScore = min(1.0, Double(audioLevel) * 2.0)
        return (lengthScore + audioScore) / 2.0
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension VoiceSearchInterface: SFSpeechRecognizerDelegate {
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                voiceSearchState = .disabled
            } else if permissionStatus.isAuthorized {
                voiceSearchState = .ready
            }
        }
    }
}

// MARK: - Voice Search UI Components

public struct VoiceSearchButton: View {
    @StateObject private var voiceInterface = VoiceSearchInterface.shared
    @State private var isPressed = false
    @State private var pulseAnimation = false
    
    public var body: some View {
        Button(action: {
            Task {
                if voiceInterface.isListening {
                    await voiceInterface.stopVoiceSearch()
                } else {
                    _ = await voiceInterface.startVoiceSearch()
                }
            }
        }) {
            ZStack {
                // Outer ring for listening state
                if voiceInterface.isListening {
                    Circle()
                        .stroke(voiceInterface.voiceSearchState.color, lineWidth: 3)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.8)
                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: pulseAnimation)
                }
                
                // Main button
                Circle()
                    .fill(voiceInterface.voiceSearchState.color.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: voiceInterface.voiceSearchState.systemImage)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(voiceInterface.voiceSearchState.color)
                    )
                
                // Audio level indicator
                if voiceInterface.isListening {
                    Circle()
                        .fill(voiceInterface.voiceSearchState.color.opacity(Double(voiceInterface.audioLevel) * 0.3))
                        .frame(width: 50, height: 50)
                        .animation(.easeInOut(duration: 0.1), value: voiceInterface.audioLevel)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0.0,
            maximumDistance: .infinity,
            perform: { },
            onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }
        )
        .onAppear {
            if voiceInterface.isListening {
                pulseAnimation = true
            }
        }
        .onChange(of: voiceInterface.isListening) { _, isListening in
            withAnimation {
                pulseAnimation = isListening
            }
        }
        .disabled(!voiceInterface.permissionStatus.isAuthorized && voiceInterface.voiceSearchState != .ready)
    }
}

public struct VoiceSearchStatusView: View {
    @StateObject private var voiceInterface = VoiceSearchInterface.shared
    
    public var body: some View {
        if voiceInterface.voiceSearchState != .ready {
            HStack(spacing: 12) {
                Image(systemName: voiceInterface.voiceSearchState.systemImage)
                    .foregroundColor(voiceInterface.voiceSearchState.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(voiceInterface.voiceSearchState.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !voiceInterface.currentTranscription.isEmpty {
                        Text(voiceInterface.currentTranscription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else if let error = voiceInterface.lastError {
                        Text(error.recoveryAction)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if voiceInterface.isListening {
                    VoiceSearchWaveform(audioLevel: voiceInterface.audioLevel)
                }
            }
            .padding()
            .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

public struct VoiceSearchWaveform: View {
    let audioLevel: Float
    @State private var waveOffsets: [CGFloat] = [0, 0, 0, 0, 0]
    
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue)
                    .frame(width: 2)
                    .frame(height: max(4, CGFloat(audioLevel) * 20 + waveOffsets[index]))
                    .animation(.easeInOut(duration: 0.3), value: audioLevel)
            }
        }
        .onAppear {
            startWaveAnimation()
        }
    }
    
    private func startWaveAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                for i in 0..<waveOffsets.count {
                    waveOffsets[i] = CGFloat.random(in: 0...10)
                }
            }
        }
    }
}

#if DEBUG
public struct VoiceSearchTestView: View {
    @StateObject private var voiceInterface = VoiceSearchInterface.shared
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VoiceSearchStatusView()
                
                VStack(spacing: 16) {
                    Text("Voice Search")
                        .font(.headline)
                    
                    VoiceSearchButton()
                    
                    Text("Tap to start voice search")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !voiceInterface.sessionHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Sessions")
                            .font(.headline)
                        
                        ForEach(voiceInterface.sessionHistory.suffix(3), id: \.id) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.transcription)
                                    .font(.body)
                                
                                HStack {
                                    Text("\(session.resultCount) results")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("Confidence: \(Int(session.confidence * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .glassBackground(material: .thin, cornerRadius: 8, shadow: false)
                        }
                    }
                    .padding()
                    .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Voice Search")
        }
    }
}

#Preview {
    VoiceSearchTestView()
}
#endif