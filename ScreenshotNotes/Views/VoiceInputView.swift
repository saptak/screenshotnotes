import SwiftUI
import Combine
import Speech
import AVFoundation

/// Voice input view providing speech recognition interface
struct VoiceInputView: View {
    @Binding var searchText: String
    @Binding var isPresented: Bool
    let onSearchSubmitted: (String) -> Void
    
    // Speech recognition properties
    @State private var speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    
    @State private var isListening = false
    @State private var transcribedText = ""
    @State private var isInitialized = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var audioLevel: Float = 0.0
    
    // Visual feedback states
    @State private var wavePhase: CGFloat = 0
    @State private var showTranscription = false
    @State private var manualText = ""
    @State private var hasPermissions = false
    
    // Computed properties
    private var isSpeechRecognitionAvailable: Bool {
        speechRecognizer?.isAvailable == true
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            VStack(spacing: 30) {
                // Header
                headerView
                
                // Main content area
                VStack(spacing: 20) {
                    // Audio visualization (only show if speech recognition is available)
                    if isSpeechRecognitionAvailable {
                        audioVisualizationView
                    }
                    
                    // Transcription display
                    transcriptionView
                    
                    // Manual input fallback (when speech recognition not available)
                    if !isSpeechRecognitionAvailable {
                        manualInputView
                    }
                    
                    // Control buttons
                    controlButtonsView
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.top, 60)
        }
        .onAppear {
            requestPermissions()
        }
        .onDisappear {
            stopListening()
        }
        .alert("Voice Input Error", isPresented: $showError) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text(errorMessage.isEmpty ? "Unknown error occurred" : errorMessage)
        }
        .animation(.easeInOut(duration: 0.3), value: isListening)
        .animation(.easeInOut(duration: 0.5), value: showTranscription)
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.purple.opacity(0.3),
                Color.blue.opacity(0.2),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Button("Done") {
                    finishVoiceInput()
                }
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .medium))
            }
            .padding(.horizontal, 20)
            
            Text("Voice Search")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(getStatusText())
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Audio Visualization
    private var audioVisualizationView: some View {
        ZStack {
            // Outer pulse rings
            ForEach(0..<3, id: \.self) { index in
                let opacity = 0.3 - Double(index) * 0.1
                let scale = pulseScale + CGFloat(index) * 0.3
                
                Circle()
                    .stroke(
                        Color.white.opacity(opacity),
                        lineWidth: 2
                    )
                    .scaleEffect(scale)
                    .opacity(isListening ? 1 : 0)
            }
            
            // Main microphone button
            microphoneButton
            
            // Audio level indicator
            if isListening {
                audioLevelIndicator
            }
        }
        .frame(width: 200, height: 200)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if isListening {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.0 + CGFloat(audioLevel) * 0.5
                }
            }
        }
    }
    
    private var microphoneButton: some View {
        Button(action: toggleListening) {
            ZStack {
                Circle()
                    .fill(isListening ? Color.red : Color.white.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isListening ? 1.1 : 1.0)
        .disabled(!isInitialized || !isSpeechRecognitionAvailable)
        .opacity((!isInitialized || !isSpeechRecognitionAvailable) ? 0.5 : 1.0)
    }
    
    private var audioLevelIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                let barHeight = CGFloat(20 + index * 10)
                let threshold = Float(index) * 0.2
                let scaleY: CGFloat = audioLevel > threshold ? 1.0 : 0.3
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 4, height: barHeight)
                    .scaleEffect(y: scaleY)
                    .animation(
                        .easeInOut(duration: 0.1),
                        value: audioLevel
                    )
            }
        }
        .offset(y: 80)
    }
    
    // MARK: - Transcription
    private var transcriptionView: some View {
        VStack(spacing: 10) {
            if !transcribedText.isEmpty {
                Text("Transcription:")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                
                ScrollView {
                    Text(transcribedText)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .frame(maxHeight: 120)
            } else if isListening {
                Text("Speak now...")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
            }
        }
        .opacity(showTranscription ? 1 : 0)
        .onChange(of: transcribedText) { _, newValue in
            showTranscription = !newValue.isEmpty
        }
    }
    
    // MARK: - Manual Input
    private var manualInputView: some View {
        VStack(spacing: 15) {
            Text("Enter your search query:")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            TextField("Type your search...", text: $manualText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.body)
                .padding(.horizontal, 20)
                .onSubmit {
                    performManualSearch()
                }
            
            if !manualText.isEmpty {
                Button("Search") {
                    performManualSearch()
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - Control Buttons
    private var controlButtonsView: some View {
        HStack(spacing: 30) {
            // Clear button
            if !transcribedText.isEmpty || !manualText.isEmpty {
                Button(action: clearAll) {
                    VStack {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Clear")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Search button
            if !transcribedText.isEmpty || !manualText.isEmpty {
                Button(action: performBestSearch) {
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                        Text("Search")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    if #available(iOS 17.0, *) {
                        AVAudioApplication.requestRecordPermission { granted in
                            DispatchQueue.main.async {
                                hasPermissions = granted
                                isInitialized = granted
                                if !granted {
                                    errorMessage = "Microphone access is required for voice search"
                                    showError = true
                                }
                            }
                        }
                    } else {
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            DispatchQueue.main.async {
                                hasPermissions = granted
                                isInitialized = granted
                                if !granted {
                                    errorMessage = "Microphone access is required for voice search"
                                    showError = true
                                }
                            }
                        }
                    }
                } else {
                    hasPermissions = false
                    isInitialized = false
                    errorMessage = "Speech recognition permission is required"
                    showError = true
                }
            }
        }
    }
    
    private func toggleListening() {
        guard isSpeechRecognitionAvailable else {
            errorMessage = "Speech recognition is not available in the simulator. Please test on a physical device."
            showError = true
            return
        }
        
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    private func startListening() {
        guard hasPermissions else {
            errorMessage = "Please grant microphone permissions"
            showError = true
            return
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            showError = true
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
            
            // Calculate audio level for visualization
            let channelData = buffer.floatChannelData?[0]
            let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelData?[$0] ?? 0 }
            let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataValueArray.count))
            
            DispatchQueue.main.async {
                audioLevel = min(rms * 10, 1.0) // Normalize and cap at 1.0
            }
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            showError = true
            return
        }
        
        // Start recognition
        guard let speechRecognizer = speechRecognizer else { return }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    transcribedText = result.bestTranscription.formattedString
                }
                
                if error != nil || result?.isFinal == true {
                    stopListening()
                }
            }
        }
        
        isListening = true
    }
    
    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isListening = false
        audioLevel = 0.0
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    private func clearAll() {
        transcribedText = ""
        manualText = ""
        showTranscription = false
        stopListening()
    }
    
    private func performManualSearch() {
        if !manualText.isEmpty {
            searchText = manualText
            onSearchSubmitted(manualText)
            isPresented = false
        }
    }
    
    private func finishVoiceInput() {
        if !transcribedText.isEmpty {
            searchText = transcribedText
            onSearchSubmitted(transcribedText)
        } else if !manualText.isEmpty {
            performManualSearch()
        }
        isPresented = false
    }
    
    private func performBestSearch() {
        if !transcribedText.isEmpty {
            searchText = transcribedText
            onSearchSubmitted(transcribedText)
        } else if !manualText.isEmpty {
            searchText = manualText
            onSearchSubmitted(manualText)
        }
        isPresented = false
    }
    
    // MARK: - Helper Methods
    
    private func getStatusText() -> String {
        if !isInitialized {
            return "Initializing..."
        } else if !isSpeechRecognitionAvailable {
            return "Speech recognition not available in simulator.\nPlease test on a physical device."
        } else if isListening {
            return "Listening..."
        } else {
            return "Tap to speak"
        }
    }
}

#Preview {
    VoiceInputView(
        searchText: .constant(""),
        isPresented: .constant(true)
    ) { query in
        print("Search: \(query)")
    }
}
