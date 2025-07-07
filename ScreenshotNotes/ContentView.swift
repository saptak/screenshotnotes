import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    @StateObject private var photoLibraryService = PhotoLibraryService()
    @StateObject private var queryParser = QueryParserService()
    @StateObject private var backgroundVisionProcessor = BackgroundVisionProcessor()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingImportSheet = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var lastParsedQuery: SearchQuery?
    @State private var showingQueryAnalysis = false
    @State private var searchRobustnessService = SearchRobustnessService()
    @State private var enhancedSearchResult: EnhancedSearchResult?
    @State private var showingSearchSuggestions = false
    @State private var searchTask: Task<Void, Never>?
    @State private var isRefreshing = false
    
    // 🎯 Sprint 5.4.1: Glass Search Bar State
    @StateObject private var searchOrchestrator: GlassConversationalSearchOrchestrator
    
    // 🧠 Sprint 6.1.1: Mind Map Navigation State
    @State private var showingMindMap = false

    init() {
        _searchOrchestrator = StateObject(wrappedValue: GlassConversationalSearchOrchestrator(settingsService: SettingsService.shared))
    }
    
    private var filteredScreenshots: [Screenshot] {
        if searchText.isEmpty {
            return screenshots
        } else {
            // Use natural language understanding for enhanced search
            if let parsedQuery = lastParsedQuery, parsedQuery.isActionable {
                return screenshots.filter { screenshot in
                    // Apply temporal filtering if query has temporal context
                    if parsedQuery.hasTemporalContext {
                        if !matchesTemporalContext(screenshot: screenshot, query: parsedQuery) {
                            return false
                        }
                    }
                    
                    // Apply entity-based filtering first (Sub-Sprint 5.1.2 enhancement)
                    if let entityResult = parsedQuery.entityExtractionResult, !entityResult.entities.isEmpty {
                        if matchesEntityContext(screenshot: screenshot, entityResult: entityResult) {
                            return true // Entity match found, return immediately
                        }
                    }
                    
                    // Apply text-based filtering
                    let enhancedTerms = parsedQuery.searchTerms.filter { term in
                        !isTemporalTerm(term) // Exclude temporal terms from text search
                    }
                    
                    if enhancedTerms.isEmpty {
                        return true // If only temporal terms, return true (temporal filter already applied)
                    }
                    
                    // Filter out generic content type terms and intent words
                    let meaningfulTerms = enhancedTerms.filter { term in
                        let genericTerms = ["screenshots", "screenshot", "images", "image", "photos", "photo", "pictures", "picture"]
                        let intentTerms = ["find", "search", "show", "get", "lookup", "locate", "where", "look", "give", "tell", "display"]
                        return !genericTerms.contains(term.lowercased()) && !intentTerms.contains(term.lowercased())
                    }
                    
                    if meaningfulTerms.isEmpty {
                        return true // If only generic content type terms, temporal filter is sufficient
                    }
                    
                    return meaningfulTerms.allSatisfy { term in
                        screenshot.filename.localizedCaseInsensitiveContains(term) ||
                        (screenshot.extractedText?.localizedCaseInsensitiveContains(term) ?? false)
                    }
                }
            } else {
                // Phase 5.1.4: Enhanced search robustness with progressive fallback
                if let enhancedResult = enhancedSearchResult, enhancedResult.originalQuery == searchText {
                    return enhancedResult.results
                } else {
                    // Fallback to traditional search if enhanced search hasn't completed yet
                    return screenshots.filter { screenshot in
                        screenshot.filename.localizedCaseInsensitiveContains(searchText) ||
                        (screenshot.extractedText?.localizedCaseInsensitiveContains(searchText) ?? false)
                    }
                }
            }
        }
    }
    
    // MARK: - 🎯 Sprint 5.4.1: Glass Search Bar View Components
    
    /// Main content area with proper padding for bottom Glass search bar
    private var mainContentArea: some View {
        Group {
            if screenshots.isEmpty && !isImporting {
                EmptyStateView(
                    onImportTapped: {
                        showingImportSheet = true
                    },
                    photoLibraryService: photoLibraryService,
                    isRefreshing: $isRefreshing
                )
            } else if isSearchActive {
                ScreenshotGridView(
                    screenshots: filteredScreenshots,
                    photoLibraryService: photoLibraryService,
                    isRefreshing: $isRefreshing
                )
            } else {
                ScreenshotGridView(
                    screenshots: screenshots,
                    photoLibraryService: photoLibraryService,
                    isRefreshing: $isRefreshing
                )
            }
        }
        .padding(.bottom, 100) // Space for Glass search bar
    }
    
    /// Overlay content including progress, analysis, and suggestions
    private var overlayContent: some View {
        ZStack {
            if isImporting {
                ImportProgressOverlay(progress: importProgress)
            }
            
            // AI Query Analysis Indicator - repositioned for Glass search bar
            if showingQueryAnalysis, let query = lastParsedQuery {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AIQueryIndicator(query: query)
                            .padding(.trailing, 16)
                            .padding(.bottom, 150) // Adjusted for Glass search bar
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
            }
            
            // Search Suggestions (Phase 5.1.4) - repositioned for Glass search bar
            if showingSearchSuggestions, let enhancedResult = enhancedSearchResult {
                VStack {
                    HStack {
                        SearchSuggestionsView(
                            suggestions: enhancedResult.suggestions,
                            metrics: enhancedResult.metrics,
                            onSuggestionTapped: { suggestion in
                                // Extract the quoted text from suggestions like "Did you mean: \"receipt\"?"
                                let suggestionText = extractSuggestionText(from: suggestion)
                                searchText = suggestionText
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        Spacer()
                    }
                    Spacer()
                    
                    // Add space for Glass search bar
                    Rectangle()
                        .fill(.clear)
                        .frame(height: 100)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }
    
    /// Bottom Glass search bar with conversational microphone integration
    private var bottomGlassSearchBar: some View {
        GlassSearchBar(
            searchText: $searchText,
            isActive: $searchOrchestrator.isSearchBarActive,
            microphoneState: $searchOrchestrator.microphoneState,
            placeholder: "Search screenshots with voice or text...",
            onMicrophoneTapped: searchOrchestrator.handleMicrophoneTapped,
            onSearchSubmitted: { query in
                searchOrchestrator.handleSearchSubmitted(query: query)
                Task {
                    await performSearch(query)
                }
            },
            onClearTapped: searchOrchestrator.handleSearchCleared
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content area
                mainContentArea
                
                // Overlays
                overlayContent
                
                // 🎯 Sprint 5.4.1: Bottom Glass Search Bar
                VStack {
                    Spacer()
                    bottomGlassSearchBar
                }
            }
            .navigationTitle("Screenshot Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Conversational AI Search - Remove since we have Glass search bar
                    // Button(action: {
                    //     showingConversationalSearch = true
                    // }) {
                    //     Image(systemName: "sparkles.rectangle.stack")
                    //         .foregroundColor(.blue)
                    // }
                    
                    // 🧠 Sprint 6.1.1: Mind Map Navigation
                    Button(action: {
                        showingMindMap = true
                    }) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    Button(action: {
                        showingImportSheet = true
                    }) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .disabled(isImporting)
                    .opacity(isImporting ? 0.5 : 1.0)
                }
            }
            // Remove the old .searchable modifier since we're using Glass search bar
            .onChange(of: searchText) { _, newValue in
                withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
                    isSearchActive = !newValue.isEmpty
                    searchOrchestrator.isSearchBarActive = !newValue.isEmpty // 🎯 Sprint 5.4.1: Update Glass search bar state
                }
                
                // 🔧 Sprint 5.2.4: Search Race Condition Fix
                // Cancel previous search task to prevent race conditions
                searchTask?.cancel()
                
                if !newValue.isEmpty && newValue.count > 2 {
                    // Combine query parser and enhanced search into single task with debouncing
                    searchTask = Task {
                        do {
                            // Debounce: wait 300ms before processing to avoid excessive requests
                            try await Task.sleep(for: .milliseconds(300))
                            try Task.checkCancellation()
                            
                            // Process query parser first
                            let parsedQuery = await queryParser.parseQuery(newValue)
                            try Task.checkCancellation()
                            
                            // Process enhanced search robustness
                            let enhancedResult = await searchRobustnessService.enhanceSearchQuery(newValue, screenshots: screenshots)
                            try Task.checkCancellation()
                            
                            // Update UI on main actor atomically
                            await MainActor.run {
                                lastParsedQuery = parsedQuery
                                showingQueryAnalysis = parsedQuery.isActionable
                                enhancedSearchResult = enhancedResult
                                showingSearchSuggestions = !enhancedResult.suggestions.isEmpty
                            }
                        } catch {
                            // Task was cancelled - this is expected behavior during rapid typing
                            // No need to log or handle this error
                        }
                    }
                } else {
                    // Clear state immediately for empty/short search
                    lastParsedQuery = nil
                    showingQueryAnalysis = false
                    enhancedSearchResult = nil
                    showingSearchSuggestions = false
                }
            }
            .photosPicker(
                isPresented: $showingImportSheet,
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images
            )
            .onChange(of: selectedItems) { _, newItems in
                if !newItems.isEmpty {
                    Task {
                        await importImages(from: newItems)
                        selectedItems = []
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(photoLibraryService: photoLibraryService)
            }
            .sheet(isPresented: $searchOrchestrator.showingConversationalSearch) {
                ConversationalSearchView(
                    searchText: $searchText,
                    isPresented: $searchOrchestrator.showingConversationalSearch,
                    onSearchSubmitted: processConversationalSearchResult
                )
            }
            .fullScreenCover(isPresented: $searchOrchestrator.showingVoiceInput) {
                VoiceInputView(
                    searchText: $searchText,
                    isPresented: $searchOrchestrator.showingVoiceInput,
                    onSearchSubmitted: processVoiceSearchResult
                )
            }
            .fullScreenCover(isPresented: $showingMindMap) {
                MindMapView()
            }
            .onAppear {
                photoLibraryService.setModelContext(modelContext)
                
                // Initialize enhanced vision processing
                backgroundVisionProcessor.setModelContext(modelContext)
                
                // Start background vision processing for screenshots that need analysis
                Task {
                    await backgroundVisionProcessor.startProcessing()
                }
                
                // Schedule periodic background processing
                backgroundVisionProcessor.scheduleBackgroundVisionProcessing()
            }
            .onDisappear {
                // 🔧 Sprint 5.2.4: Cleanup search task to prevent memory leaks
                searchTask?.cancel()
                searchTask = nil
            }
        }
    }
    
    private func performSearch(_ query: String) async {
        searchOrchestrator.microphoneState = .results
        
        // Trigger UI update for search
        await MainActor.run {
            searchText = query
            isSearchActive = true
        }
        
        // Reset state after a short delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        await MainActor.run {
            if searchOrchestrator.microphoneState == .results {
                searchOrchestrator.microphoneState = .ready
            }
        }
    }
    
    private func importImages(from items: [PhotosPickerItem]) async {
        isImporting = true
        importProgress = 0.0
        
        for (index, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let screenshot = Screenshot(
                    imageData: data,
                    filename: item.supportedContentTypes.first?.description ?? "Screenshot"
                )
                modelContext.insert(screenshot)
            }
            
            await MainActor.run {
                importProgress = Double(index + 1) / Double(items.count)
            }
        }
        
        try? modelContext.save()
        isImporting = false
    }
    
    // MARK: - Entity-Based Search Helpers (Sub-Sprint 5.1.2)
    
    private func matchesEntityContext(screenshot: Screenshot, entityResult: EntityExtractionResult) -> Bool {
        let entities = entityResult.entities
        
        // Check visual entities (colors, objects) against filename, extracted text, and object tags
        let visualEntities = entities.filter { entity in
            entity.type == .color || entity.type == .object || entity.type == .documentType
        }
        
        if !visualEntities.isEmpty {
            for entity in visualEntities {
                let normalizedValue = entity.normalizedValue.lowercased()
                
                // Check filename
                if screenshot.filename.localizedCaseInsensitiveContains(normalizedValue) {
                    return true
                }
                
                // Check extracted text (OCR)
                if let extractedText = screenshot.extractedText,
                   extractedText.localizedCaseInsensitiveContains(normalizedValue) {
                    return true
                }
                
                // Check object tags (if available)
                if let objectTags = screenshot.objectTags {
                    for tag in objectTags {
                        if tag.localizedCaseInsensitiveContains(normalizedValue) {
                            return true
                        }
                    }
                }
                
                // For clothing/object entities, also check if the filename suggests it's a shopping screenshot
                if entity.type == .object && ["dress", "shirt", "pants", "jacket", "shoes"].contains(normalizedValue) {
                    let filenameWords = screenshot.filename.lowercased().components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
                    let shoppingKeywords = ["shop", "store", "buy", "purchase", "cart", "wishlist", "fashion", "clothes", "clothing"]
                    if !Set(filenameWords).intersection(Set(shoppingKeywords)).isEmpty {
                        return true
                    }
                }
            }
        }
        
        // Check person/organization entities
        let namedEntities = entities.filter { entity in
            entity.type == .person || entity.type == .organization || entity.type == .place
        }
        
        for entity in namedEntities {
            let normalizedValue = entity.normalizedValue.lowercased()
            
            // Check filename and extracted text for named entities
            if screenshot.filename.localizedCaseInsensitiveContains(normalizedValue) ||
               (screenshot.extractedText?.localizedCaseInsensitiveContains(normalizedValue) ?? false) {
                return true
            }
        }
        
        // Check structured data entities (phone, email, URL)
        let structuredEntities = entities.filter { entity in
            entity.type == .phoneNumber || entity.type == .email || entity.type == .url
        }
        
        for entity in structuredEntities {
            if let extractedText = screenshot.extractedText,
               extractedText.contains(entity.text) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Temporal Query Helpers
    
    private func matchesTemporalContext(screenshot: Screenshot, query: SearchQuery) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let screenshotDate = screenshot.timestamp
        
        for term in query.searchTerms {
            switch term.lowercased() {
            case "today":
                if calendar.isDate(screenshotDate, inSameDayAs: now) {
                    return true
                }
            case "yesterday":
                if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                   calendar.isDate(screenshotDate, inSameDayAs: yesterday) {
                    return true
                }
            case "week", "this week":
                if calendar.isDate(screenshotDate, equalTo: now, toGranularity: .weekOfYear) {
                    return true
                }
            case "last week":
                if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
                   calendar.isDate(screenshotDate, equalTo: lastWeek, toGranularity: .weekOfYear) {
                    return true
                }
            case "month", "this month":
                if calendar.isDate(screenshotDate, equalTo: now, toGranularity: .month) {
                    return true
                }
            case "last month":
                if let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
                   calendar.isDate(screenshotDate, equalTo: lastMonth, toGranularity: .month) {
                    return true
                }
            case "recent":
                // Define recent as within the last 7 days
                if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                   screenshotDate >= weekAgo {
                    return true
                }
            default:
                continue
            }
        }
        
        return false
    }
    
    private func isTemporalTerm(_ term: String) -> Bool {
        let temporalTerms: Set<String> = [
            "today", "yesterday", "tomorrow", "week", "this week", "last week",
            "month", "this month", "last month", "year", "this year", "last year",
            "recent", "lately"
        ]
        return temporalTerms.contains(term.lowercased())
    }
    
    // MARK: - Phase 5.1.4: Search Robustness Helpers
    
    private func extractSuggestionText(from suggestion: String) -> String {
        // Extract quoted text from suggestions like "Did you mean: \"receipt\"?"
        let pattern = #""([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: suggestion.utf16.count)
            if let match = regex.firstMatch(in: suggestion, options: [], range: range) {
                if let swiftRange = Range(match.range(at: 1), in: suggestion) {
                    return String(suggestion[swiftRange])
                }
            }
        }
        
        // If no quoted text found, return the original suggestion
        return suggestion
    }
    
    // MARK: - Voice Search Integration
    
    /// Process voice search result and trigger appropriate search actions
    private func processVoiceSearchResult(_ optimizedQuery: String) {
        // Update search text to trigger existing search pipeline
        searchText = optimizedQuery
        
        // Provide immediate visual feedback
        withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
            isSearchActive = !optimizedQuery.isEmpty
        }
        
        // Add haptic feedback for successful voice search
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        print("🎤 Voice search processed: '\(optimizedQuery)'")
    }
    
    /// Process conversational search result with enhanced feedback
    private func processConversationalSearchResult(_ optimizedQuery: String) {
        // Update search text to trigger existing search pipeline
        searchText = optimizedQuery
        
        // Provide immediate visual feedback
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSearchActive = !optimizedQuery.isEmpty
        }
        
        // Add haptic feedback for successful conversational search
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // Close the conversational search view
        searchOrchestrator.showingConversationalSearch = false
        
        print("✨ Conversational search processed: '\(optimizedQuery)'")
    }
}

struct EmptyStateView: View {
    let onImportTapped: () -> Void
    let photoLibraryService: PhotoLibraryService
    @Binding var isRefreshing: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("No Screenshots Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Import your first screenshot to get started organizing your visual notes")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("Pull down to import all past screenshots from Apple Photos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
                
                Button(action: {
                    onImportTapped()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                        Text("Import Photos")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.tint)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .refreshable {
            await refreshScreenshots()
        }
    }
    
    private func refreshScreenshots() async {
        isRefreshing = true
        
        // Provide haptic feedback for pull-to-refresh
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Import all past screenshots from Photo Library
        let result = await photoLibraryService.importAllPastScreenshots()
        
        // Provide success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        if result.imported > 0 {
            notificationFeedback.notificationOccurred(.success)
        } else {
            notificationFeedback.notificationOccurred(.warning)
        }
        
        print("📸 Pull-to-refresh import completed: \(result.imported) imported, \(result.skipped) skipped")
        
        isRefreshing = false
    }
}

struct ScreenshotGridView: View {
    let screenshots: [Screenshot]
    let photoLibraryService: PhotoLibraryService
    @Binding var isRefreshing: Bool
    @State private var selectedScreenshot: Screenshot?
    @Namespace private var heroNamespace
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(screenshots, id: \.id) { screenshot in
                    ScreenshotThumbnailView(
                        screenshot: screenshot,
                        onTap: {
                            selectedScreenshot = screenshot
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .refreshable {
            await refreshScreenshots()
        }
        .fullScreenCover(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(
                screenshot: screenshot,
                heroNamespace: heroNamespace,
                allScreenshots: screenshots,
                onDelete: nil
            )
        }
    }
    
    private func refreshScreenshots() async {
        isRefreshing = true
        
        // Provide haptic feedback for pull-to-refresh
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Import all past screenshots from Photo Library
        let result = await photoLibraryService.importAllPastScreenshots()
        
        // Provide success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        if result.imported > 0 {
            notificationFeedback.notificationOccurred(.success)
        } else {
            notificationFeedback.notificationOccurred(.warning)
        }
        
        print("📸 Pull-to-refresh import completed: \(result.imported) imported, \(result.skipped) skipped")
        
        isRefreshing = false
    }
}

struct ScreenshotThumbnailView: View {
    let screenshot: Screenshot
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let uiImage = UIImage(data: screenshot.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 140)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                Text("Unable to load")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
            
            Text(screenshot.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}


struct ImportProgressOverlay: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    .scaleEffect(1.5)
                
                Text(progress > 0 ? "Importing..." : "Scanning Photo Library...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if progress > 0 {
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Finding screenshots to import")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
        }
        .transition(.opacity)
    }
}

/// AI Query Processing Indicator - Shows when natural language understanding is active
struct AIQueryIndicator: View {
    let query: SearchQuery
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.blue)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI: \(query.intent.rawValue)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if query.hasVisualAttributes {
                    Text("Visual search")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if query.confidence.rawValue >= 0.8 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

/// Search Suggestions View for Phase 5.1.4 Enhanced Search Robustness
struct SearchSuggestionsView: View {
    let suggestions: [String]
    let metrics: SearchRobustnessService.PerformanceMetrics
    let onSuggestionTapped: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("Search Suggestions")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if metrics.fallbackTier > 1 {
                    Text("Tier \(metrics.fallbackTier)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                
                Spacer()
                
                if metrics.processingTime > 0 {
                    Text("\(String(format: "%.0f", metrics.processingTime * 1000))ms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(suggestions.prefix(3), id: \.self) { suggestion in
                    Button(action: {
                        onSuggestionTapped(suggestion)
                    }) {
                        HStack {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.left")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
