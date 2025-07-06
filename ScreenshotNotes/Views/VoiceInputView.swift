import SwiftUI
import Combine
import Speech
import AVFoundation

/// Voice input view providing speech recognition interface
struct VoiceInputView: View {
    @Binding var searchText: String
    @Binding var isPresented: Bool
    let onSearchSubmitted: (String) -> Void
    
    @StateObject private var voiceService = VoiceSearchService()
    @State private var isInitialized = false
    @State private var showError = false
    @State private var animationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    // Visual feedback states
    @State private var wavePhase: CGFloat = 0
    @State private var showTranscription = false
    @State private var manualText = ""
    
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
                    if voiceService.isSpeechRecognitionAvailable() {
                        audioVisualizationView
                    }
                    
                    // Transcription display
                    transcriptionView
                    
                    // Manual input fallback (when speech recognition not available)
                    if !voiceService.isSpeechRecognitionAvailable() {
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
            initializeVoiceService()
        }
        .onDisappear {
            Task {
                await voiceService.stopListening()
            }
        }
        .alert("Voice Input Error", isPresented: $showError) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text(voiceService.errorMessage ?? "Unknown error occurred")
        }
        .animation(.easeInOut(duration: 0.3), value: voiceService.isListening)
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
                    .opacity(voiceService.isListening ? 1 : 0)
            }
            
            // Main microphone button
            microphoneButton
            
            // Audio level indicator
            if voiceService.isListening {
                audioLevelIndicator
            }
        }
        .frame(width: 200, height: 200)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if voiceService.isListening {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.0 + CGFloat(voiceService.audioLevel) * 0.5
                }
            }
        }
    }
    
    private var microphoneButton: some View {
        Button(action: toggleListening) {
            ZStack {
                Circle()
                    .fill(voiceService.isListening ? Color.red : Color.white.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: voiceService.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(voiceService.isListening ? 1.1 : 1.0)
        .disabled(!isInitialized || !voiceService.isSpeechRecognitionAvailable())
        .opacity((!isInitialized || !voiceService.isSpeechRecognitionAvailable()) ? 0.5 : 1.0)
    }
    
    private var audioLevelIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                let barHeight = CGFloat(20 + index * 10)
                let threshold = Float(index) * 0.2
                let scaleY: CGFloat = voiceService.audioLevel > threshold ? 1.0 : 0.3
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 4, height: barHeight)
                    .scaleEffect(y: scaleY)
                    .animation(
                        .easeInOut(duration: 0.1),
                        value: voiceService.audioLevel
                    )
            }
        }
        .offset(y: 80)
    }
    
    // MARK: - Transcription
    private var transcriptionView: some View {
        VStack(spacing: 10) {
            if !voiceService.transcribedText.isEmpty {
                Text("Transcription:")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                
                ScrollView {
                    Text(voiceService.transcribedText)
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
            } else if voiceService.isListening {
                Text("Speak now...")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
            }
        }
        .opacity(showTranscription ? 1 : 0)
        .onChange(of: voiceService.transcribedText) { _, newValue in
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
            if !voiceService.transcribedText.isEmpty || !manualText.isEmpty {
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
            if !voiceService.transcribedText.isEmpty || !manualText.isEmpty {
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
    private func initializeVoiceService() {
        Task {
            let success = await voiceService.requestPermissions()
            await MainActor.run {
                isInitialized = success
                if !success {
                    showError = true
                }
            }
        }
    }
    
    private func toggleListening() {
        // Check if speech recognition is available
        guard voiceService.isSpeechRecognitionAvailable() else {
            voiceService.setErrorMessage("Speech recognition is not available in the simulator. Please test on a physical device.")
            showError = true
            return
        }
        
        Task {
            if voiceService.isListening {
                await voiceService.stopListening()
            } else {
                do {
                    try await voiceService.startListening()
                } catch {
                    await MainActor.run {
                        showError = true
                    }
                }
            }
        }
    }
    
    private func clearTranscription() {
        voiceService.clearTranscription()
        showTranscription = false
        Task {
            await voiceService.stopListening()
        }
    }
    
    private func performSearch() {
        let finalTranscription = voiceService.getFinalTranscription()
        if !finalTranscription.isEmpty {
            searchText = finalTranscription
            onSearchSubmitted(finalTranscription)
        }
        isPresented = false
    }
    
    private func performManualSearch() {
        if !manualText.isEmpty {
            searchText = manualText
            onSearchSubmitted(manualText)
            isPresented = false
        }
    }
    
    private func finishVoiceInput() {
        if !voiceService.transcribedText.isEmpty {
            performSearch()
        } else if !manualText.isEmpty {
            performManualSearch()
        } else {
            isPresented = false
        }
    }
    
    private func clearAll() {
        voiceService.clearTranscription()
        manualText = ""
        showTranscription = false
        Task {
            await voiceService.stopListening()
        }
    }
    
    private func performBestSearch() {
        let finalTranscription = voiceService.getFinalTranscription()
        if !finalTranscription.isEmpty {
            searchText = finalTranscription
            onSearchSubmitted(finalTranscription)
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
        } else if !voiceService.isSpeechRecognitionAvailable() {
            return "Speech recognition not available in simulator.\nPlease test on a physical device."
        } else if voiceService.isListening {
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
