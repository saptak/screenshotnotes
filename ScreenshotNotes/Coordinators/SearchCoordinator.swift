import SwiftUI
import SwiftData

/// SearchCoordinator manages all search-related state and logic for ContentView
/// Following the Coordinator pattern for better separation of concerns and testability
@MainActor
class SearchCoordinator: ObservableObject {
    // MARK: - Search State Properties
    @Published var searchText = ""
    @Published var isSearchActive = false
    @Published var lastParsedQuery: SearchQuery?
    @Published var enhancedSearchResult: EnhancedSearchResult?
    @Published var showingSearchSuggestions = false
    @Published var showingQueryAnalysis = false
    
    // MARK: - Services
    @Published var searchRobustnessService = SearchRobustnessService()
    let queryParser: QueryParserService
    @Published var searchOrchestrator: GlassConversationalSearchOrchestrator
    
    // MARK: - Private Properties
    private var searchTask: Task<Void, Never>?
    private var delegate: SearchCoordinatorDelegate?
    
    // MARK: - Initialization
    init(delegate: SearchCoordinatorDelegate? = nil) {
        self.delegate = delegate
        self.queryParser = QueryParserService()
        self.searchOrchestrator = GlassConversationalSearchOrchestrator(settingsService: SettingsService.shared)
        
        // Set up search text observation
        setupSearchTextObservation()
    }
    
    // MARK: - Public Methods
    
    /// Filters screenshots based on current search state
    func filterScreenshots(_ screenshots: [Screenshot]) -> [Screenshot] {
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
    
    /// Performs enhanced search with robustness service
    func performSearch(_ query: String) async {
        searchOrchestrator.microphoneState = .results
        
        // Process the search query with enhanced robustness
        let enhancedResult = await searchRobustnessService.enhanceSearchQuery(query, screenshots: delegate?.getScreenshots() ?? [])
        
        await MainActor.run {
            enhancedSearchResult = enhancedResult
            showingSearchSuggestions = !enhancedResult.suggestions.isEmpty
        }
    }
    
    /// Clears search state
    func clearSearch() {
        searchText = ""
        isSearchActive = false
        lastParsedQuery = nil
        enhancedSearchResult = nil
        showingSearchSuggestions = false
        showingQueryAnalysis = false
        searchTask?.cancel()
        searchTask = nil
    }
    
    /// Resets search bar focus
    func resetSearchBarFocus() {
        searchOrchestrator.resetSearchBarFocus()
    }
    
    /// Handles search submitted from Glass search bar
    func handleSearchSubmitted(query: String) {
        searchOrchestrator.handleSearchSubmitted(query: query)
        Task {
            await performSearch(query)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSearchTextObservation() {
        // This will be handled by SwiftUI's @Published property wrapper
        // The actual observation logic will be moved from ContentView's onChange
    }
    
    /// Processes search text changes with debouncing and race condition prevention
    func processSearchTextChange(_ newValue: String, screenshots: [Screenshot]) {
        withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
            isSearchActive = !newValue.isEmpty
            searchOrchestrator.isSearchBarActive = !newValue.isEmpty
        }
        
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
    
    // MARK: - Cleanup
    deinit {
        searchTask?.cancel()
        searchTask = nil
    }
}

// MARK: - SearchCoordinatorDelegate Protocol
protocol SearchCoordinatorDelegate {
    func getScreenshots() -> [Screenshot]
}