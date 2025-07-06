//
//  ConversationalSearchView.swift
//  ScreenshotNotes
//
//  Sub-Sprint 5.3.3: Conversational Search UI & Siri Response Interface
//  Created by Assistant on 7/5/25.
//

import SwiftUI
import Combine
import Speech

/// Enhanced conversational search interface with voice feedback and intelligent suggestions
struct ConversationalSearchView: View {
    @Binding var searchText: String
    @Binding var isPresented: Bool
    let onSearchSubmitted: (String) -> Void
    
    @StateObject private var conversationService = ConversationalSearchService()
    
    // UI State
    @State private var showingSuggestions = false
    @State private var currentSuggestions: [SearchSuggestion] = []
    @State private var queryUnderstanding: QueryUnderstanding?
    @State private var isProcessingQuery = false
    @State private var showVoiceInput = false
    
    // Animation states
    @State private var suggestionOpacity: Double = 0
    @State private var understandingScale: CGFloat = 0.95
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                backgroundGradient
                
                VStack(spacing: 24) {
                    // Header with intelligent status
                    headerView
                    
                    // Main search interface
                    searchInterfaceView
                    
                    // Query understanding feedback
                    if let understanding = queryUnderstanding {
                        queryUnderstandingView(understanding)
                    }
                    
                    // Smart suggestions
                    if showingSuggestions && !currentSuggestions.isEmpty {
                        suggestionsView
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle("Intelligent Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showVoiceInput = true
                    }) {
                        Image(systemName: "mic.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                }
            }
        }
        .sheet(isPresented: $showVoiceInput) {
            VoiceInputView(
                searchText: $searchText,
                isPresented: $showVoiceInput,
                onSearchSubmitted: handleSearchSubmission
            )
        }
        .onAppear {
            setupConversationalSearch()
        }
        .onChange(of: searchText) { _, newValue in
            handleSearchTextChange(newValue)
        }
    }
    
    // MARK: - Background Gradient
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemBackground),
                Color(.systemGray6).opacity(0.3)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack {
                Circle()
                    .fill(conversationService.isReady ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(conversationService.isReady ? "AI Assistant Ready" : "Initializing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Query processing indicator
                if isProcessingQuery {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Conversational prompt
            Text("What would you like to find?")
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Search Interface
    
    private var searchInterfaceView: some View {
        VStack(spacing: 16) {
            // Enhanced search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .imageScale(.medium)
                
                TextField("Try: 'blue dress receipts' or 'documents from yesterday'", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .onSubmit {
                        handleSearchSubmission(searchText)
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: queryUnderstanding != nil ? 2 : 0)
                    )
            )
            
            // Action buttons
            HStack(spacing: 16) {
                // Voice input button
                Button(action: { showVoiceInput = true }) {
                    HStack {
                        Image(systemName: "mic")
                        Text("Voice")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(20)
                }
                
                // Smart suggestions button
                Button(action: toggleSuggestions) {
                    HStack {
                        Image(systemName: "lightbulb")
                        Text("Suggestions")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                }
            }
        }
    }
    
    // MARK: - Query Understanding View
    
    private func queryUnderstandingView(_ understanding: QueryUnderstanding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("I understand you're looking for:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                // Intent icon and text
                Label(understanding.intent.displayText, systemImage: understanding.intent.icon)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(understanding.intent.color)
                
                Spacer()
                
                // Confidence indicator
                Text("\(Int(understanding.confidence * 100))% confident")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Extracted entities
            if !understanding.entities.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100))
                ], spacing: 8) {
                    ForEach(understanding.entities, id: \.type) { entity in
                        HStack {
                            Text(entity.type.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(entity.value)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(entity.type.color.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
        .scaleEffect(understandingScale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: understandingScale)
        .onAppear {
            withAnimation {
                understandingScale = 1.0
            }
        }
    }
    
    // MARK: - Suggestions View
    
    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Suggestions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150))
            ], spacing: 12) {
                ForEach(currentSuggestions) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .opacity(suggestionOpacity)
        .animation(.easeInOut(duration: 0.3), value: suggestionOpacity)
        .onAppear {
            withAnimation {
                suggestionOpacity = 1.0
            }
        }
    }
    
    private func suggestionCard(_ suggestion: SearchSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: suggestion.icon)
                    .foregroundColor(suggestion.category.color)
                    .imageScale(.medium)
                
                Spacer()
                
                if suggestion.isRecent {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .imageScale(.small)
                }
            }
            
            Text(suggestion.query)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Text(suggestion.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(suggestion.category.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(suggestion.category.color.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture {
            searchText = suggestion.query
            handleSearchSubmission(suggestion.query)
        }
    }
    
    // MARK: - Actions
    
    private func setupConversationalSearch() {
        conversationService.initialize()
        loadSmartSuggestions()
    }
    
    private func handleSearchTextChange(_ newText: String) {
        // Debounce query understanding
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if searchText == newText && !newText.isEmpty {
                updateQueryUnderstanding(newText)
            } else if newText.isEmpty {
                queryUnderstanding = nil
            }
        }
    }
    
    private func updateQueryUnderstanding(_ query: String) {
        isProcessingQuery = true
        
        Task {
            let understanding = await conversationService.analyzeQuery(query)
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.queryUnderstanding = understanding
                    self.isProcessingQuery = false
                }
            }
        }
    }
    
    private func toggleSuggestions() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingSuggestions.toggle()
        }
        
        if showingSuggestions {
            loadSmartSuggestions()
        }
    }
    
    private func loadSmartSuggestions() {
        Task {
            let suggestions = await conversationService.generateSuggestions()
            
            await MainActor.run {
                self.currentSuggestions = suggestions
            }
        }
    }
    
    private func handleSearchSubmission(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Record usage for learning
        conversationService.recordSearchQuery(query)
        
        // Close suggestions
        showingSuggestions = false
        
        // Execute search
        onSearchSubmitted(query)
        
        // Close view
        isPresented = false
    }
}

// MARK: - Preview

struct ConversationalSearchView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationalSearchView(
            searchText: .constant(""),
            isPresented: .constant(true),
            onSearchSubmitted: { _ in }
        )
    }
}
