//
//  GlassSearchBar.swift
//  ScreenshotNotes
//
//  Sprint 5.4.1: Bottom Glass Search Bar Implementation
//  Created by Assistant on 7/6/25.
//

import SwiftUI
import Combine

/// Premium bottom-mounted Glass search bar with Apple UX compliance
/// Serves as the central hub for all conversational search interactions
struct GlassSearchBar: View {
    
    // MARK: - Bindings and State
    
    @Binding var searchText: String
    @Binding var isActive: Bool
    @Binding var microphoneState: GlassMicrophoneButtonState
    
    let placeholder: String
    let onMicrophoneTapped: () -> Void
    let onSearchSubmitted: (String) -> Void
    let onClearTapped: () -> Void
    
    // MARK: - Internal State
    
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var glassIntensity: Double = 1.0
    @State private var searchBarHeight: CGFloat = GlassDesignSystem.GlassLayout.searchBarHeight
    @State private var animationTask: Task<Void, Never>?
    
    
    // MARK: - Environment and System
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var glassSystem = GlassDesignSystem.shared
    
    // MARK: - Computed Properties
    
    private var adaptiveHeight: CGFloat {
        GlassAccessibility.adaptiveGlassLayout(
            baseHeight: searchBarHeight,
            contentSizeCategory: ContentSizeCategory(dynamicTypeSize)
        )
    }
    
    private var currentGlassMaterial: GlassDesignSystem.GlassMaterial {
        switch microphoneState {
        case .ready: return .regular
        case .listening: return .thin
        case .processing: return .thick
        case .results: return .ultraThin
        case .error: return .regular
        case .conversation: return .regular
        }
    }
    
    private var shouldShowClearButton: Bool {
        !searchText.isEmpty
    }
    
    // MARK: - Main Body
    
    var body: some View {
        VStack(spacing: 0) {
            searchBarContent
                .frame(height: adaptiveHeight)
                .glassEffect(
                    material: currentGlassMaterial,
                    cornerRadius: GlassDesignSystem.GlassLayout.searchBarCornerRadius,
                    vibrancy: glassIntensity
                )
                .glassPressEffect(isPressed: isPressed)
                .glassHoverEffect(isHovered: isHovered)
                .glassFocusEffect(isFocused: isSearchFieldFocused)
                .glassBreathing(
                    isActive: microphoneState == .ready && !isActive,
                    intensity: 0.05
                )
                .glassPulse(
                    isActive: microphoneState == .listening,
                    color: .red,
                    intensity: 0.4
                )
                .glassShimmer(isActive: microphoneState == .processing)
                .animation(
                    glassSystem.adaptedGlassSpring(.conversational),
                    value: microphoneState
                )
                .animation(
                    glassSystem.adaptedGlassSpring(.responsive),
                    value: isActive
                )
                .animation(
                    glassSystem.adaptedGlassSpring(.gentle),
                    value: searchText.isEmpty
                )
                .onHover { hovering in
                    withAnimation(glassSystem.adaptedGlassSpring(.responsive)) {
                        isHovered = hovering
                    }
                }
        }
        .padding(.horizontal, GlassDesignSystem.GlassLayout.horizontalPadding)
        .padding(.bottom, GlassDesignSystem.GlassLayout.bottomSafeAreaPadding)
        .glassAccessibility(
            label: "Glass search bar",
            hint: GlassAccessibility.searchBarAccessibilityHint(),
            value: searchText.isEmpty ? "Empty" : searchText,
            customActions: GlassAccessibility.alternativeInteraction(for: .searchBar)
        )
        .onChange(of: microphoneState) { oldState, newState in
            handleMicrophoneStateChange(from: oldState, to: newState)
        }
        .onChange(of: isActive) { _, newValue in
            handleActiveStateChange(newValue)
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - Search Bar Content
    
    private var searchBarContent: some View {
        HStack(spacing: 12) {
            // Search icon with dynamic state
            searchIcon
                .frame(width: 20, height: 20)
            
            // Main search input
            searchTextField
            
            // Action buttons
            HStack(spacing: 8) {
                if shouldShowClearButton {
                    clearButton
                        .transition(.scale.combined(with: .opacity))
                }
                
                microphoneButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Search Icon
    
    private var searchIcon: some View {
        Image(systemName: searchIconName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(searchIconColor.color)
            .glassVibrancy(strength: 0.8)
            .scaleEffect(isActive ? 1.1 : 1.0)
            .animation(glassSystem.adaptedGlassSpring(.responsive), value: isActive)
    }
    
    private var searchIconName: String {
        switch microphoneState {
        case .ready: return "magnifyingglass"
        case .listening: return "waveform"
        case .processing: return "gearshape"
        case .results: return "checkmark.circle"
        case .error: return "exclamationmark.triangle"
        case .conversation: return "message"
        }
    }
    
    private var searchIconColor: GlassDesignSystem.GlassColor {
        switch microphoneState {
        case .ready: return .secondary
        case .listening: return .microphone
        case .processing: return .processing
        case .results: return .success
        case .error: return .error
        case .conversation: return .conversation
        }
    }
    
    // MARK: - Search Text Field
    
    private var searchTextField: some View {
        TextField(placeholder, text: $searchText)
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium, design: .default))
            .foregroundStyle(.primary)
            .glassVibrancy(strength: 1.0)
            .focused($isSearchFieldFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .onSubmit {
                handleSearchSubmission()
            }
            .onChange(of: searchText) { _, newValue in
                handleSearchTextChange(newValue)
            }
            .glassAccessibility(
                label: "Search text field",
                hint: "Enter your search query here or use the microphone for voice search",
                value: searchText.isEmpty ? "Empty" : searchText
            )
    }
    
    // MARK: - Clear Button
    
    private var clearButton: some View {
        Button(action: handleClearTapped) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .glassVibrancy(strength: 0.7)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 20, height: 20)
        .glassAccessibility(
            label: "Clear search",
            hint: "Tap to clear the search text",
            traits: .button
        )
    }
    
    // MARK: - Microphone Button
    
    private var microphoneButton: some View {
        Button(action: handleMicrophoneTapped) {
            microphoneButtonContent
        }
        .buttonStyle(PlainButtonStyle())
        .frame(
            width: GlassDesignSystem.GlassLayout.microphoneButtonSize,
            height: GlassDesignSystem.GlassLayout.microphoneButtonSize
        )
        .glassEffect(
            material: microphoneState.glassMaterial,
            cornerRadius: GlassDesignSystem.GlassLayout.microphoneButtonSize / 2
        )
        .glassPressEffect(isPressed: isPressed)
        .scaleEffect(microphoneState == .listening ? 1.05 : 1.0)
        .animation(glassSystem.adaptedGlassSpring(.microphone), value: microphoneState)
        .glassAccessibility(
            label: GlassAccessibility.microphoneButtonAccessibilityLabel(for: microphoneState),
            traits: .button,
            customActions: GlassAccessibility.alternativeInteraction(for: .microphoneButton)
        )
    }
    
    private var microphoneButtonContent: some View {
        let props = microphoneState.displayProperties
        
        return Image(systemName: props.icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(
                GlassAccessibility.accessibleColor(
                    base: props.color,
                    context: .accent
                )
            )
            .glassVibrancy(strength: props.opacity)
            .scaleEffect(props.scale)
            .glassRotation(
                isActive: microphoneState == .processing,
                speed: 2.0
            )
    }
    
    // MARK: - Action Handlers
    
    private func handleMicrophoneTapped() {
        withAnimation(glassSystem.adaptedGlassSpring(.microphone)) {
            isPressed = true
        }
        
        // Provide immediate haptic feedback
        GlassAnimations.conversationHapticPattern(for: microphoneState)
        
        // Execute the action
        onMicrophoneTapped()
        
        // Reset press state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(glassSystem.adaptedGlassSpring(.microphone)) {
                isPressed = false
            }
        }
    }
    
    private func handleSearchSubmission() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearchFieldFocused = false
        onSearchSubmitted(searchText)
        
        // Provide success haptic feedback
        GlassAccessibility.accessibleHapticFeedback(for: .searchCompleted)
    }
    
    private func handleClearTapped() {
        withAnimation(glassSystem.adaptedGlassSpring(.responsive)) {
            searchText = ""
            isActive = false
        }
        
        onClearTapped()
        
        // Remove focus to dismiss keyboard when clearing
        isSearchFieldFocused = false
        
        // Provide clear haptic feedback
        GlassAccessibility.accessibleHapticFeedback(for: .conversationTurn, intensity: 0.5)
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        withAnimation(glassSystem.adaptedGlassSpring(.responsive)) {
            isActive = !newValue.isEmpty
        }
        
        // Update glass intensity based on content
        let intensity = newValue.isEmpty ? 1.0 : 1.2
        withAnimation(glassSystem.adaptedGlassSpring(.gentle)) {
            glassIntensity = intensity
        }
    }
    
    // MARK: - State Management
    
    private func handleMicrophoneStateChange(
        from oldState: GlassMicrophoneButtonState,
        to newState: GlassMicrophoneButtonState
    ) {
        // Announce state change for accessibility
        GlassAccessibility.announceStateChange(from: oldState, to: newState)
        
        // Update glass material and effects
        withAnimation(glassSystem.adaptedGlassSpring(.conversational)) {
            switch newState {
            case .ready:
                glassIntensity = 1.0
                searchBarHeight = GlassDesignSystem.GlassLayout.searchBarHeight
            case .listening:
                glassIntensity = 1.3
                searchBarHeight = GlassDesignSystem.GlassLayout.searchBarHeight
            case .processing:
                glassIntensity = 0.8
                searchBarHeight = GlassDesignSystem.GlassLayout.searchBarHeight
            case .results:
                glassIntensity = 1.1
                searchBarHeight = GlassDesignSystem.GlassLayout.searchBarHeight
            case .error:
                glassIntensity = 1.0
                searchBarHeight = GlassDesignSystem.GlassLayout.searchBarHeight
            case .conversation:
                glassIntensity = 1.2
                searchBarHeight = GlassDesignSystem.GlassLayout.searchBarHeightExpanded
            }
        }
        
        // Start/stop breathing animation for ready state
        if newState == .ready && oldState != .ready {
            startBreathingAnimation()
        } else if newState != .ready && oldState == .ready {
            stopBreathingAnimation()
        }
    }
    
    private func handleActiveStateChange(_ isActive: Bool) {
        withAnimation(glassSystem.adaptedGlassSpring(.responsive)) {
            glassIntensity = isActive ? 1.2 : 1.0
        }
    }
    
    private func setupInitialState() {
        // Configure initial accessibility
        glassSystem.updateAccessibilityConfiguration()
        
        // Set initial glass intensity
        glassIntensity = isActive ? 1.2 : 1.0
        
        // Start breathing if in ready state
        if microphoneState == .ready {
            startBreathingAnimation()
        }
    }
    
    private func startBreathingAnimation() {
        stopBreathingAnimation() // Ensure no duplicate tasks

        animationTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    guard microphoneState == .ready else {
                        stopBreathingAnimation()
                        return
                    }
                    
                    withAnimation(GlassAnimations.microphoneBreathing()) {
                        // Breathing effect is handled by the glassBreathing modifier
                    }
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func stopBreathingAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}

// MARK: - ContentSizeCategory Extension

private extension ContentSizeCategory {
    init(_ dynamicTypeSize: DynamicTypeSize) {
        switch dynamicTypeSize {
        case .xSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .xLarge: self = .extraLarge
        case .xxLarge: self = .extraExtraLarge
        case .xxxLarge: self = .extraExtraExtraLarge
        case .accessibility1: self = .accessibilityMedium
        case .accessibility2: self = .accessibilityLarge
        case .accessibility3: self = .accessibilityExtraLarge
        case .accessibility4: self = .accessibilityExtraExtraLarge
        case .accessibility5: self = .accessibilityExtraExtraExtraLarge
        @unknown default: self = .large
        }
    }
}

// MARK: - Preview Support

#if DEBUG
#Preview("Glass Search Bar") {
    struct SearchBarPreview: View {
        @State private var searchText = ""
        @State private var isActive = false
        @State private var microphoneState: GlassMicrophoneButtonState = .ready
        
        var body: some View {
            VStack {
                Spacer()
                
                // Main search bar
                GlassSearchBar(
                    searchText: $searchText,
                    isActive: $isActive,
                    microphoneState: $microphoneState,
                    placeholder: "Search screenshots...",
                    onMicrophoneTapped: {
                        cycleMicrophoneState()
                    },
                    onSearchSubmitted: { query in
                        print("Search submitted: \(query)")
                    },
                    onClearTapped: {
                        print("Clear tapped")
                    }
                )
                
                // State controls for preview
                VStack(spacing: 12) {
                    Text("Microphone State: \(String(describing: microphoneState))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Button("Cycle State") { cycleMicrophoneState() }
                        Button("Toggle Active") { isActive.toggle() }
                        Button("Add Text") { searchText = "blue dress" }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .glassContainer()
                .padding()
            }
            .background {
                LinearGradient(
                    colors: [.blue.opacity(0.4), .purple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        
        private func cycleMicrophoneState() {
            let states: [GlassMicrophoneButtonState] = [.ready, .listening, .processing, .results, .conversation, .error]
            if let currentIndex = states.firstIndex(of: microphoneState) {
                let nextIndex = (currentIndex + 1) % states.count
                microphoneState = states[nextIndex]
            }
        }
    }
    
    return SearchBarPreview()
}
#endif
