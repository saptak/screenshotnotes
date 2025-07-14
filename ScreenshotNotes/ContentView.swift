import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    @StateObject private var backgroundSemanticProcessor = BackgroundSemanticProcessor()
    @StateObject private var queryParser = QueryParserService()
    @StateObject private var backgroundVisionProcessor = BackgroundVisionProcessor()
    @StateObject private var photoLibraryService = PhotoLibraryService()
    @EnvironmentObject private var backgroundOCRProcessor: BackgroundOCRProcessor
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
    @State private var bulkImportProgress: (current: Int, total: Int) = (0, 0)
    @State private var isBulkImportInProgress = false
    
    // Phase 2: Viewport management for predictive loading
    @State private var scrollOffset: CGFloat = 0
    @State private var galleryScrollOffset: CGFloat = 0 // Separate scroll offset for gallery mode
    @StateObject private var viewportManager = PredictiveViewportManager.shared
    @StateObject private var qualityManager = AdaptiveQualityManager.shared
    
    
    // 🎯 Sprint 5.4.1: Glass Search Bar State
    @StateObject private var searchOrchestrator: GlassConversationalSearchOrchestrator
    
    // 🧠 Sprint 6.1.1: Mind Map Navigation State
    @State private var showingMindMap = false
    @State private var selectedScreenshot: Screenshot?
    
    // 🌟 Sprint 8.2.1: Adaptive Content Hub Foundation
    @StateObject private var interfaceSettings = InterfaceSettings()
    @StateObject private var modeManager = InterfaceModeManager.shared
    @StateObject private var relationshipDetector = ContentRelationshipDetector.shared

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
    
    /// Main content area with adaptive interface mode support
    private var mainContentArea: some View {
        Group {
            if screenshots.isEmpty && !isImporting {
                EmptyStateView(
                        onImportTapped: {
                            showingImportSheet = true
                        },
                        photoLibraryService: photoLibraryService,
                        isRefreshing: $isRefreshing,
                        bulkImportProgress: $bulkImportProgress,
                        isBulkImportInProgress: $isBulkImportInProgress,
                        backgroundOCRProcessor: backgroundOCRProcessor,
                        backgroundSemanticProcessor: backgroundSemanticProcessor,
                        modelContext: modelContext,
                        scrollOffset: $scrollOffset
                )
            } else if isSearchActive {
                // Search mode content (same for both Legacy and Enhanced interfaces)
                ScreenshotGridView(
                    screenshots: filteredScreenshots,
                    photoLibraryService: photoLibraryService,
                    isRefreshing: $isRefreshing,
                    bulkImportProgress: $bulkImportProgress,
                    isBulkImportInProgress: $isBulkImportInProgress,
                    backgroundOCRProcessor: backgroundOCRProcessor,
                    backgroundSemanticProcessor: backgroundSemanticProcessor,
                    modelContext: modelContext,
                    searchOrchestrator: searchOrchestrator,
                    selectedScreenshot: $selectedScreenshot,
                    scrollOffset: $scrollOffset,
                    viewportManager: viewportManager,
                    qualityManager: qualityManager
                )
            } else {
                // 🌟 Sprint 8.2.1: Adaptive Content Hub based on interface mode
                if interfaceSettings.isEnhancedInterfaceEnabled {
                    adaptiveContentHub
                } else {
                    // Legacy Interface: Original screenshot grid
                    ScreenshotGridView(
                        screenshots: screenshots,
                        photoLibraryService: photoLibraryService,
                        isRefreshing: $isRefreshing,
                        bulkImportProgress: $bulkImportProgress,
                        isBulkImportInProgress: $isBulkImportInProgress,
                        backgroundOCRProcessor: backgroundOCRProcessor,
                        backgroundSemanticProcessor: backgroundSemanticProcessor,
                        modelContext: modelContext,
                        searchOrchestrator: searchOrchestrator,
                        selectedScreenshot: $selectedScreenshot,
                        scrollOffset: $scrollOffset,
                        viewportManager: viewportManager,
                        qualityManager: qualityManager
                    )
                }
            }
        }
        .padding(.bottom, 100) // Space for Glass search bar
    }
    
    // MARK: - 🌟 Sprint 8.2.1: Adaptive Content Hub
    
    /// Enhanced Interface with 4-level progressive disclosure
    private var adaptiveContentHub: some View {
        VStack(spacing: 0) {
            // Mode selector
            AdaptiveContentHubModeSelector()
                .padding(.top, 2)
            
            // Current mode content is now managed by a TabView for fluid, state-preserving transitions.
            TabView(selection: $modeManager.currentMode) {
                galleryModeContent
                    .tag(InterfaceMode.gallery)

                ConstellationModeRenderer(screenshots: screenshots)
                    .tag(InterfaceMode.constellation)

                explorationModeContent
                    .tag(InterfaceMode.exploration)

                searchModeContent
                    .tag(InterfaceMode.search)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: modeManager.currentMode)
        }
    }
    
    /// Gallery mode content (Enhanced Interface version)
    private var galleryModeContent: some View {
        GalleryModeRenderer(
                screenshots: screenshots,
                modelContext: modelContext,
                photoLibraryService: photoLibraryService,
                backgroundOCRProcessor: backgroundOCRProcessor,
                backgroundSemanticProcessor: backgroundSemanticProcessor,
                searchOrchestrator: searchOrchestrator,
                viewportManager: viewportManager,
                qualityManager: qualityManager,
                isRefreshing: $isRefreshing,
                bulkImportProgress: $bulkImportProgress,
                isBulkImportInProgress: $isBulkImportInProgress,
                selectedScreenshot: $selectedScreenshot,
                galleryScrollOffset: $galleryScrollOffset,
                showingImportSheet: $showingImportSheet,
                isImporting: $isImporting
        )
    }
    
    /// Exploration mode content (placeholder for future implementation)
    private var explorationModeContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 64))
                .foregroundColor(.orange.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Exploration Mode")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Discover relationships and connections between your content with interactive visualization.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Text("Coming in Sprint 8.3")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.orange.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(.orange.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
    
    /// Search mode content (enhanced conversational search)
    private var searchModeContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.green.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Search Mode")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Find specific content with powerful conversational search and AI assistance.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Text("Enhanced in Sprint 8.4")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.green.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(.green.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
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
                
                // Add the contextual menu overlay
                ContextualMenuOverlay()
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
            .onChange(of: selectedScreenshot) { oldValue, newValue in
                // Reset search bar focus when returning from detail view
                if oldValue != nil && newValue == nil {
                    // Reset orchestrator state but preserve search text and results
                    searchOrchestrator.resetSearchBarFocus()
                    
                    // Force dismiss keyboard - most reliable method
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                
                // Set up enhanced thumbnail services with ModelContext
                ThumbnailService.shared.setModelContext(modelContext)
                
                // Initialize enhanced vision processing
                backgroundVisionProcessor.setModelContext(modelContext)
                
                // Start background vision processing for screenshots that need analysis
                Task {
                    await backgroundVisionProcessor.startProcessing()
                }
                
                // Schedule periodic background processing
                backgroundVisionProcessor.scheduleBackgroundVisionProcessing()
                
                // Initialize enhanced semantic processing (entity extraction + AI tagging)
                Task {
                    await backgroundSemanticProcessor.processScreenshotsNeedingAnalysis(in: modelContext)
                }
                
                print("ContentView: ModelContext set up for all services including enhanced gallery infrastructure")
            }
            .onDisappear {
                // 🔧 Sprint 5.2.4: Cleanup search task to prevent memory leaks
                searchTask?.cancel()
                searchTask = nil
            }
            .task(id: screenshots) {
                // Only run in Enhanced Interface mode
                if interfaceSettings.isEnhancedInterfaceEnabled {
                    await relationshipDetector.detectRelationships(in: Array(screenshots))
                }
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
        
        // Trigger OCR processing for newly imported screenshots
        backgroundOCRProcessor.startBackgroundProcessingIfNeeded(in: modelContext)
        
        // Trigger semantic processing for newly imported screenshots
        Task {
            await backgroundSemanticProcessor.processScreenshotsNeedingAnalysis(in: modelContext)
            
            // Trigger mind map regeneration after semantic processing completes
            await backgroundSemanticProcessor.triggerMindMapRegeneration(in: modelContext)
        }
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
        let pattern = "\"([^\"]+)\"";
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
    @Binding var bulkImportProgress: (current: Int, total: Int)
    @Binding var isBulkImportInProgress: Bool
    let backgroundOCRProcessor: BackgroundOCRProcessor
    let backgroundSemanticProcessor: BackgroundSemanticProcessor
    let modelContext: ModelContext
    @Binding var scrollOffset: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Pull-to-import message (shows when user pulls down)
                    if scrollOffset > 10 && isRefreshing == false && !isBulkImportInProgress {
                        PullToImportMessageView()
                            .opacity(0.8)
                            .padding(.top, 8) // Visible at the top
                            .padding(.bottom, 8)
                    }
                    
                    // Progressive import progress indicator
                    if isRefreshing && bulkImportProgress.total > 0 {
                        VStack(spacing: 16) {
                            Text("Importing \(bulkImportProgress.current) of \(bulkImportProgress.total) screenshots")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            ProgressView(value: Double(bulkImportProgress.current), total: Double(bulkImportProgress.total))
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(width: 280)
                                .scaleEffect(1.2)
                        }
                        .padding(.horizontal, 40)
                    } else if isRefreshing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .controlSize(.large)
                            
                            Text("Importing screenshots...")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    } else {
                        // Main empty state content - focused on pull-to-refresh
                        VStack(spacing: 24) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 72, weight: .thin))
                                .foregroundColor(.blue)
                                .symbolEffect(.bounce, options: .repeating)
                            
                            Text("Pull down to import screenshots")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                                .id("pull-to-import-text") // Add unique ID to force re-rendering
                            
                            Text("Import up to 20 latest screenshots from Apple Photos")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                            
                            // Photo access guidance
                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                    
                                    Text("Photo Access Required")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                VStack(spacing: 8) {
                                    Text("When prompted, grant access to \"All Photos\" to import your screenshots.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("You can also enable photo access in Settings > Screenshot Vault > Photos.")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 500) // Ensure enough space for pull gesture
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .global).minY)
                    }
                )
            }
            .coordinateSpace(name: "pullArea")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                // Convert the global position to a proper scroll offset
                let containerTop = geometry.frame(in: .global).minY
                scrollOffset = max(0, offset - containerTop)
            }
            .refreshable {
                await refreshScreenshots()
            }
        }
    }
    
    private func refreshScreenshots() async {
        // Prevent concurrent bulk imports
        if isBulkImportInProgress {
            print("📸 Bulk import already in progress, skipping")
            return
        }
        
        isBulkImportInProgress = true
        isRefreshing = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Check and request photo permission if needed
        let currentStatus = photoLibraryService.authorizationStatus
        if currentStatus != .authorized {
            print("📸 Photo permission not granted (\(currentStatus)), requesting permission...")
            let newStatus = await photoLibraryService.requestPhotoLibraryPermission()
            
            if newStatus != .authorized {
                print("📸 Photo permission denied, cannot import screenshots")
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
                isRefreshing = false
                isBulkImportInProgress = false
                return
            }
            
            print("📸 Photo permission granted, proceeding with import")
        }

        // Extremely lazy, incremental import in batches with 20-screenshot limit
        let batchSize = 10
        let maxImportLimit = 20
        var totalImported = 0
        var totalSkipped = 0
        var hasMore = true
        var batchIndex = 0

        while hasMore && totalImported < maxImportLimit {
            let result = await photoLibraryService.importPastScreenshotsBatch(batch: batchIndex, batchSize: batchSize)
            totalImported += result.imported
            totalSkipped += result.skipped
            batchIndex += 1
            hasMore = result.hasMore
            
            // Stop if we've reached the import limit
            if totalImported >= maxImportLimit {
                hasMore = false
            }
            
            // Update progress for UI feedback
            bulkImportProgress = (current: totalImported, total: min(totalImported + totalSkipped, maxImportLimit))

            // Allow UI to update immediately after each batch import
            if result.imported > 0 {
                // Schedule background processing (rate-limited to prevent overlapping tasks)
                Task {
                    // Small delay to allow UI update
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                    
                    backgroundOCRProcessor.startBackgroundProcessingIfNeeded(in: modelContext)
                    
                    // Wait briefly for OCR to initialize  
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    
                    await backgroundSemanticProcessor.processScreenshotsNeedingAnalysis(in: modelContext)
                    await backgroundSemanticProcessor.triggerMindMapRegeneration(in: modelContext)
                    
                    print("✅ Background processing completed for batch")
                }
            }

            // Shorter yield for more responsive UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s between batches
        }

        let notificationFeedback = UINotificationFeedbackGenerator()
        if totalImported > 0 {
            notificationFeedback.notificationOccurred(.success)
        } else {
            notificationFeedback.notificationOccurred(.warning)
        }
        print("📸 Pull-to-refresh import completed: \(totalImported) imported, \(totalSkipped) skipped (limit: \(maxImportLimit))")
        isRefreshing = false
        isBulkImportInProgress = false
        bulkImportProgress = (0, 0) // Reset progress
    }
}

struct ScreenshotGridView: View {
    let screenshots: [Screenshot]
    let photoLibraryService: PhotoLibraryService
    @Binding var isRefreshing: Bool
    @Binding var bulkImportProgress: (current: Int, total: Int)
    @Binding var isBulkImportInProgress: Bool
    let backgroundOCRProcessor: BackgroundOCRProcessor
    let backgroundSemanticProcessor: BackgroundSemanticProcessor
    let modelContext: ModelContext
    let searchOrchestrator: GlassConversationalSearchOrchestrator
    @Binding var selectedScreenshot: Screenshot?
    @Binding var scrollOffset: CGFloat
    @ObservedObject var viewportManager: PredictiveViewportManager
    @ObservedObject var qualityManager: AdaptiveQualityManager
    @Namespace private var heroNamespace
    @StateObject private var performanceMonitor = GalleryPerformanceMonitor.shared
    @StateObject private var thumbnailService = ThumbnailService.shared
    

    private func computeColumns(for width: CGFloat) -> [GridItem] {
        let minThumbnailWidth: CGFloat = 150
        let columnSpacing: CGFloat = 16
        let sidePadding: CGFloat = 20 * 2 // 20 on each side
        
        let effectiveWidth = width - sidePadding
        let numberOfColumns = max(1, Int(effectiveWidth / (minThumbnailWidth + columnSpacing)))
        
        return Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: numberOfColumns)
    }

    var body: some View {
        GeometryReader { geometry in
            let columns = computeColumns(for: geometry.size.width)
            
            VirtualizedGridView(
                items: screenshots,
                columns: columns,
                itemHeight: 220,
                scrollOffset: $scrollOffset,
                showPullMessage: true,
                isRefreshing: isRefreshing,
                isBulkImportInProgress: isBulkImportInProgress,
                onRefresh: refreshScreenshots
            ) { screenshot in
                OptimizedThumbnailView(
                    screenshot: screenshot,
                    size: CGSize(width: 160, height: 200),
                    onTap: {
                        selectedScreenshot = screenshot
                    }
                )
            }
            .frame(maxWidth: .infinity)
        }
        .fullScreenCover(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(
                screenshot: screenshot,
                heroNamespace: heroNamespace,
                allScreenshots: screenshots,
                onDelete: nil
            )
        }
        .onAppear {
            performanceMonitor.startMonitoring()
            
            // Phase 2: Update collection size for adaptive optimization
            qualityManager.updateCollectionSize(screenshots.count)
            
            // Preload thumbnails for better scrolling performance
            if screenshots.count <= 100 {
                thumbnailService.preloadThumbnails(for: Array(screenshots.prefix(20)))
            }
        }
        .onDisappear {
            performanceMonitor.stopMonitoring()
        }
        .onChange(of: scrollOffset) { _, newOffset in
            // Phase 2: Update viewport manager with scroll changes
            viewportManager.updateScrollOffset(newOffset)
        }
        .onChange(of: screenshots.count) { _, newCount in
            // Phase 2: Update collection size when screenshots change
            qualityManager.updateCollectionSize(newCount)
        }
        .onReceive(NotificationCenter.default.publisher(for: .performanceOptimizationNeeded)) { notification in
            handlePerformanceOptimization(notification)
        }
    }
    
    private func refreshScreenshots() async {
        // Prevent concurrent bulk imports
        if isBulkImportInProgress {
            print("📸 Bulk import already in progress, skipping")
            return
        }
        
        isBulkImportInProgress = true
        isRefreshing = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Check and request photo permission if needed
        let currentStatus = photoLibraryService.authorizationStatus
        if currentStatus != .authorized {
            print("📸 Photo permission not granted (\(currentStatus)), requesting permission...")
            let newStatus = await photoLibraryService.requestPhotoLibraryPermission()
            
            if newStatus != .authorized {
                print("📸 Photo permission denied, cannot import screenshots")
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
                isRefreshing = false
                isBulkImportInProgress = false
                return
            }
            
            print("📸 Photo permission granted, proceeding with import")
        }

        // Extremely lazy, incremental import in batches with 20-screenshot limit
        let batchSize = 10
        let maxImportLimit = 20
        var totalImported = 0
        var totalSkipped = 0
        var hasMore = true
        var batchIndex = 0

        while hasMore && totalImported < maxImportLimit {
            let result = await photoLibraryService.importPastScreenshotsBatch(batch: batchIndex, batchSize: batchSize)
            totalImported += result.imported
            totalSkipped += result.skipped
            batchIndex += 1
            hasMore = result.hasMore
            
            // Stop if we've reached the import limit
            if totalImported >= maxImportLimit {
                hasMore = false
            }
            
            // Update progress for UI feedback
            bulkImportProgress = (current: totalImported, total: min(totalImported + totalSkipped, maxImportLimit))

            // Allow UI to update immediately after each batch import
            if result.imported > 0 {
                // Schedule background processing (rate-limited to prevent overlapping tasks)
                Task {
                    // Small delay to allow UI update
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                    
                    backgroundOCRProcessor.startBackgroundProcessingIfNeeded(in: modelContext)
                    
                    // Wait briefly for OCR to initialize  
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    
                    await backgroundSemanticProcessor.processScreenshotsNeedingAnalysis(in: modelContext)
                    await backgroundSemanticProcessor.triggerMindMapRegeneration(in: modelContext)
                    
                    print("✅ Background processing completed for batch")
                }
            }

            // Shorter yield for more responsive UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s between batches
        }

        let notificationFeedback = UINotificationFeedbackGenerator()
        if totalImported > 0 {
            notificationFeedback.notificationOccurred(.success)
        } else {
            notificationFeedback.notificationOccurred(.warning)
        }
        print("📸 Pull-to-refresh import completed: \(totalImported) imported, \(totalSkipped) skipped (limit: \(maxImportLimit))")
        isRefreshing = false
        isBulkImportInProgress = false
        bulkImportProgress = (0, 0) // Reset progress
    }
    
    private func handlePerformanceOptimization(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "lowFPS":
            print("🐌 Optimizing for low FPS")
            // Already using optimized thumbnails, could reduce quality further if needed
            
        case "highMemory":
            print("🧠 Optimizing for high memory usage")
            thumbnailService.clearCache()
            
        case "thermal":
            print("🔥 Optimizing for thermal pressure")
            thumbnailService.clearCache()
            // Could pause thumbnail generation temporarily
            
        default:
            break
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

struct PullToImportMessageView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.accentColor)
            Text("Pull to import 20 more Screenshots. Long-press to share, copy or delete.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(.systemBackground).opacity(0.95))
                .shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
        )
        .frame(maxWidth: .infinity)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}

/*
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
*/

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var view: UIView? = self
        while let v = view {
            if let scroll = v as? UIScrollView { return scroll }
            view = v.superview
        }
        return nil
    }
}