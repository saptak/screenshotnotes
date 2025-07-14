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
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var lastParsedQuery: SearchQuery?
    @State private var showingQueryAnalysis = false
    @State private var searchRobustnessService = SearchRobustnessService()
    @State private var enhancedSearchResult: EnhancedSearchResult?
    @State private var showingSearchSuggestions = false
    @State private var searchTask: Task<Void, Never>?
    
    // Phase 2: Viewport management for predictive loading
    @State private var scrollOffset: CGFloat = 0
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
                        if !SearchHelpers.matchesTemporalContext(screenshot: screenshot, query: parsedQuery) {
                            return false
                        }
                    }
                    
                    // Apply entity-based filtering first (Sub-Sprint 5.1.2 enhancement)
                    if let entityResult = parsedQuery.entityExtractionResult, !entityResult.entities.isEmpty {
                        if SearchHelpers.matchesEntityContext(screenshot: screenshot, entityResult: entityResult) {
                            return true // Entity match found, return immediately
                        }
                    }
                    
                    // Apply text-based filtering
                    let enhancedTerms = parsedQuery.searchTerms.filter { term in
                        !SearchHelpers.isTemporalTerm(term) // Exclude temporal terms from text search
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
            if interfaceSettings.isEnhancedInterfaceEnabled {
                adaptiveContentHub
            } else {
                // Legacy Interface: Original screenshot grid
                GalleryModeRenderer(
                    screenshots: screenshots,
                    modelContext: modelContext,
                    photoLibraryService: photoLibraryService,
                    backgroundOCRProcessor: backgroundOCRProcessor,
                    backgroundSemanticProcessor: backgroundSemanticProcessor,
                    searchOrchestrator: searchOrchestrator,
                    viewportManager: viewportManager,
                    qualityManager: qualityManager
                )
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
                qualityManager: qualityManager
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
                        // This is now handled by the GalleryModeViewModel
                    }) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
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
            .onChange(of: selectedItems) { _, newItems in
                if !newItems.isEmpty {
                    Task {
                        // This is now handled by the GalleryModeViewModel
                        // await importImages(from: newItems)
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
                    onSearchSubmitted: { query in
                        searchText = query
                        isSearchActive = true
                        searchOrchestrator.showingConversationalSearch = false
                    }
                )
            }
            .fullScreenCover(isPresented: $searchOrchestrator.showingVoiceInput) {
                VoiceInputView(
                    searchText: $searchText,
                    isPresented: $searchOrchestrator.showingVoiceInput,
                    onSearchSubmitted: { query in
                        searchText = query
                        isSearchActive = true
                        searchOrchestrator.showingVoiceInput = false
                    }
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
        
        // Process the search query with enhanced robustness
        let enhancedResult = await searchRobustnessService.enhanceSearchQuery(query, screenshots: screenshots)
        
        await MainActor.run {
            enhancedSearchResult = enhancedResult
            showingSearchSuggestions = !enhancedResult.suggestions.isEmpty
        }
    }
}