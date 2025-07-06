
//
//  GlassConversationalSearchOrchestrator.swift
//  ScreenshotNotes
//
//  Sprint 5.4.2: Glass Conversational Experience
//  Created by Assistant on 7/6/25.
//

import SwiftUI
import Combine

/// Orchestrates the state and interactions of the Glass conversational search experience.
/// This class acts as the central state machine, managing the flow between different
/// microphone states, handling timeouts, and coordinating with other services.
@MainActor
class GlassConversationalSearchOrchestrator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var microphoneState: GlassMicrophoneButtonState = .ready
    @Published var isSearchBarActive: Bool = false
    @Published var showingVoiceInput: Bool = false
    @Published var showingConversationalSearch: Bool = false
    
    // MARK: - Private Properties
    
    private var stateTransitionTimer: AnyCancellable?
    private let settingsService: SettingsService
    
    // MARK: - Initialization
    
    init(settingsService: SettingsService) {
        self.settingsService = settingsService
    }
    
    // MARK: - Public API
    
    /// Handles a tap on the microphone button, transitioning the state accordingly.
    func handleMicrophoneTapped() {
        // Cancel any pending state transitions
        cancelTimer()
        
        switch microphoneState {
        case .ready:
            startListening()
        case .listening:
            stopListening()
        case .processing:
            // Allow cancellation of processing if implemented in the future
            transition(to: .ready)
        case .results:
            startConversation()
        case .conversation:
            endConversation()
        case .error:
            startListening() // Retry on error
        }
    }
    
    /// Handles the submission of a search query (from text or voice).
    func handleSearchSubmitted(query: String) {
        guard !query.isEmpty else {
            transition(to: .ready)
            return
        }
        
        transition(to: .processing)
        
        // Simulate processing and transition to results
        scheduleStateTransition(to: .results, after: 2.0)
    }
    
    /// Handles the clearing of the search bar.
    func handleSearchCleared() {
        transition(to: .ready)
        isSearchBarActive = false
    }
    
    /// Notifies the orchestrator that the voice input view has been dismissed.
    func voiceInputDismissed() {
        if microphoneState == .listening {
            stopListening()
        }
    }
    
    // MARK: - State Machine Logic
    
    private func startListening() {
        transition(to: .listening)
        showingVoiceInput = true
        
        // Automatically transition to processing after a timeout
        if settingsService.autoSubmitVoiceSearch {
            scheduleStateTransition(to: .processing, after: 10.0) // 10-second listening timeout
        }
    }
    
    private func stopListening() {
        transition(to: .ready)
        showingVoiceInput = false
    }
    
    private func startConversation() {
        transition(to: .conversation)
        showingConversationalSearch = true
    }
    
    private func endConversation() {
        transition(to: .ready)
        showingConversationalSearch = false
    }
    
    /// Centralized state transition method to ensure consistency.
    private func transition(to newState: GlassMicrophoneButtonState) {
        guard microphoneState != newState else { return }
        
        let oldState = microphoneState
        microphoneState = newState
        
        // Announce accessibility state changes
        GlassAccessibility.announceStateChange(from: oldState, to: newState)
        
        // Cancel any timers if we move to a non-transient state
        if ![.listening, .processing, .results].contains(newState) {
            cancelTimer()
        }
    }
    
    // MARK: - Timer Management
    
    /// Schedules a state transition to occur after a specified delay.
    /// - Parameters:
    ///   - state: The target state to transition to.
    ///   - delay: The time interval to wait before transitioning.
    private func scheduleStateTransition(to state: GlassMicrophoneButtonState, after delay: TimeInterval) {
        cancelTimer()
        
        stateTransitionTimer = Just(state)
            .delay(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { [weak self] nextState in
                self?.transition(to: nextState)
            }
    }
    
    /// Cancels any pending state transition timer.
    private func cancelTimer() {
        stateTransitionTimer?.cancel()
        stateTransitionTimer = nil
    }
}
