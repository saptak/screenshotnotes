import Foundation
import SwiftData
import SwiftUI
import OSLog
import NaturalLanguage

/// Advanced natural language search service that enables conversational search queries
/// Transforms natural language into structured search parameters with temporal awareness
@MainActor
public final class NaturalLanguageSearchService: ObservableObject {
    public static let shared = NaturalLanguageSearchService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "NaturalLanguageSearch")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastQuery: String = ""
    @Published public private(set) var lastResults: [Screenshot] = []
    @Published public private(set) var searchSuggestions: [SearchSuggestion] = []
    @Published public private(set) var queryHistory: [ProcessedQuery] = []
    
    // MARK: - Services
    
    // Services would be initialized when needed
    // private let searchService = SearchService.shared
    // private let queryParser = QueryParserService.shared  
    // private let entityExtractor = EntityExtractionService.shared
    // private let searchRobustness = SearchRobustnessService.shared
    private let hapticService = HapticFeedbackService.shared
    private let errorService = ErrorHandlingService.shared
    
    // MARK: - Configuration
    
    public struct NaturalLanguageSettings {
        var enableConversationalSearch: Bool = true
        var enableTemporalParsing: Bool = true
        var enableContextAwareness: Bool = true
        var enableLearningFromQueries: Bool = true
        var maxSuggestions: Int = 8
        var maxHistoryEntries: Int = 50
        var temporalContextWindowDays: Int = 365
        var minimumConfidenceThreshold: Double = 0.6
        
        public init() {}
    }
    
    @Published public var settings = NaturalLanguageSettings()
    
    // MARK: - Data Models
    
    /// Enhanced search query with natural language understanding
    public struct NaturalLanguageQuery {
        var originalText: String
        var processedText: String
        var intent: SearchIntent
        var temporalContext: TemporalContext?
        var contentFilters: [ContentFilter]
        var entityFilters: [EntityFilter]
        var semanticTags: [String]
        var confidence: Double
        var language: String
        var queryVector: [Float]? // For semantic similarity
        
        public init(
            originalText: String,
            processedText: String = "",
            intent: SearchIntent = .find,
            temporalContext: TemporalContext? = nil,
            contentFilters: [ContentFilter] = [],
            entityFilters: [EntityFilter] = [],
            semanticTags: [String] = [],
            confidence: Double = 0.0,
            language: String = "en",
            queryVector: [Float]? = nil
        ) {
            self.originalText = originalText
            self.processedText = processedText.isEmpty ? originalText : processedText
            self.intent = intent
            self.temporalContext = temporalContext
            self.contentFilters = contentFilters
            self.entityFilters = entityFilters
            self.semanticTags = semanticTags
            self.confidence = confidence
            self.language = language
            self.queryVector = queryVector
        }
    }
    
    /// Advanced temporal context with vacation/event detection
    public struct TemporalContext {
        var type: TemporalType
        var startDate: Date?
        var endDate: Date?
        var relativePhrase: String
        var confidence: Double
        var namedPeriod: String? // "vacation", "work trip", "meeting"
        
        public enum TemporalType: String, CaseIterable {
            case absolute = "absolute"           // "March 15th"
            case relative = "relative"           // "yesterday", "last week"  
            case range = "range"                 // "last month"
            case namedPeriod = "named_period"    // "vacation", "work trip"
            case event = "event"                 // "meeting", "conference"
            case season = "season"               // "summer", "winter"
            case timeOfDay = "time_of_day"       // "morning", "evening"
        }
    }
    
    /// Content-aware filtering for specific media types
    public struct ContentFilter {
        var type: ContentType
        var pattern: String?
        var confidence: Double
        
        public enum ContentType: String, CaseIterable {
            case text = "text"
            case website = "website"
            case phoneNumber = "phone_number"
            case email = "email"
            case receipt = "receipt"
            case document = "document"
            case contact = "contact"
            case app = "app"
            case social = "social"
            case screenshot = "screenshot"
            case photo = "photo"
            case qrCode = "qr_code"
            case barcode = "barcode"
        }
    }
    
    /// Entity-based filtering with enhanced recognition
    public struct EntityFilter {
        var entityType: String
        var entityValue: String
        var confidence: Double
        var category: EntityCategory
        
        public enum EntityCategory: String, CaseIterable {
            case person = "person"
            case place = "place"
            case organization = "organization"
            case product = "product"
            case event = "event"
            case technology = "technology"
            case financial = "financial"
            case contact = "contact"
        }
    }
    
    /// Search intent classification with expanded types
    public enum SearchIntent: String, CaseIterable {
        case find = "find"
        case show = "show"
        case search = "search"
        case filter = "filter"
        case get = "get"
        case lookup = "lookup"
        case discover = "discover"
        case organize = "organize"
        case compare = "compare"
        case recent = "recent"
        case similar = "similar"
        case duplicate = "duplicate"
        
        public var displayName: String {
            switch self {
            case .find: return "Find"
            case .show: return "Show"
            case .search: return "Search"
            case .filter: return "Filter"
            case .get: return "Get"
            case .lookup: return "Lookup"
            case .discover: return "Discover"
            case .organize: return "Organize"
            case .compare: return "Compare"
            case .recent: return "Recent"
            case .similar: return "Similar"
            case .duplicate: return "Duplicate"
            }
        }
        
        public var priority: Int {
            switch self {
            case .find, .search, .get: return 100
            case .show, .filter: return 90
            case .lookup, .recent: return 80
            case .discover, .similar: return 70
            case .organize, .compare: return 60
            case .duplicate: return 50
            }
        }
    }
    
    /// Processed query for history and learning
    public struct ProcessedQuery: Identifiable, Codable {
        public let id = UUID()
        let originalQuery: String
        let processedQuery: String
        let resultCount: Int
        let timestamp: Date
        let executionTime: TimeInterval
        let userSatisfaction: Double // 0.0 - 1.0
        let refinements: [String] // Follow-up queries
        
        public init(
            originalQuery: String,
            processedQuery: String,
            resultCount: Int,
            timestamp: Date = Date(),
            executionTime: TimeInterval = 0,
            userSatisfaction: Double = 0.5,
            refinements: [String] = []
        ) {
            self.originalQuery = originalQuery
            self.processedQuery = processedQuery
            self.resultCount = resultCount
            self.timestamp = timestamp
            self.executionTime = executionTime
            self.userSatisfaction = userSatisfaction
            self.refinements = refinements
        }
    }
    
    /// Search suggestions with context
    public struct SearchSuggestion: Identifiable {
        public let id = UUID()
        let text: String
        let type: SuggestionType
        let confidence: Double
        let contextHint: String
        
        public enum SuggestionType: String, CaseIterable {
            case recent = "recent"
            case popular = "popular"
            case contextual = "contextual"
            case temporal = "temporal"
            case semantic = "semantic"
            case completion = "completion"
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        logger.info("NaturalLanguageSearchService initialized with conversational search capabilities")
        loadQueryHistory()
    }
    
    // MARK: - Public Interface
    
    /// Process natural language search query
    /// - Parameters:
    ///   - query: Raw natural language query
    ///   - modelContext: SwiftData model context
    ///   - options: Search options for customization
    /// - Returns: Search results with enhanced relevance
    public func searchWithNaturalLanguage(
        query: String,
        in modelContext: ModelContext,
        options: SearchOptions? = nil
    ) async -> [Screenshot] {
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        logger.info("Processing natural language query: '\(query)'")
        
        isProcessing = true
        lastQuery = query
        let startTime = Date()
        
        defer {
            isProcessing = false
        }
        
        do {
            // Step 1: Parse natural language into structured query
            let nlQuery = await parseNaturalLanguageQuery(query)
            
            // Step 2: Apply temporal filtering if context detected
            var screenshots = try await getScreenshotsInTemporalContext(nlQuery.temporalContext, in: modelContext)
            
            // Step 3: Apply content and entity filters
            screenshots = await applyContentFilters(screenshots, filters: nlQuery.contentFilters)
            screenshots = await applyEntityFilters(screenshots, filters: nlQuery.entityFilters)
            
            // Step 4: Perform semantic search on filtered set
            let searchResults = await performSemanticSearch(
                query: nlQuery.processedText,
                in: screenshots,
                modelContext: modelContext,
                options: options
            )
            
            // Step 5: Enhance results with context-aware ranking
            let enhancedResults = await enhanceResultsWithContext(searchResults, originalQuery: nlQuery)
            
            // Step 6: Record query for learning
            let executionTime = Date().timeIntervalSince(startTime)
            await recordQueryForLearning(nlQuery, resultCount: enhancedResults.count, executionTime: executionTime)
            
            // Step 7: Generate search suggestions for next query
            await generateContextualSuggestions(based: nlQuery, results: enhancedResults)
            
            lastResults = enhancedResults
            
            // Provide haptic feedback based on results
            if enhancedResults.isEmpty {
                hapticService.triggerHaptic(.errorFeedback)
            } else if enhancedResults.count == 1 {
                hapticService.triggerHaptic(.successFeedback)
            } else {
                hapticService.triggerHaptic(.successFeedback)
            }
            
            logger.info("Natural language search completed: \(enhancedResults.count) results in \(String(format: "%.2f", executionTime))s")
            return enhancedResults
            
        } catch {
            logger.error("Natural language search failed: \(error.localizedDescription)")
            _ = await errorService.handleSwiftError(error, context: "Natural Language Search")
            return []
        }
    }
    
    /// Get intelligent search suggestions
    /// - Parameter partialQuery: Partial or complete query text
    /// - Returns: Contextual search suggestions
    public func getSearchSuggestions(for partialQuery: String) async -> [SearchSuggestion] {
        guard !partialQuery.isEmpty else {
            return getRecentAndPopularSuggestions()
        }
        
        var suggestions: [SearchSuggestion] = []
        
        // Completion suggestions
        suggestions.append(contentsOf: await getCompletionSuggestions(for: partialQuery))
        
        // Temporal suggestions
        suggestions.append(contentsOf: getTemporalSuggestions(for: partialQuery))
        
        // Content type suggestions
        suggestions.append(contentsOf: getContentTypeSuggestions(for: partialQuery))
        
        // Recent query suggestions
        suggestions.append(contentsOf: getRecentQuerySuggestions(matching: partialQuery))
        
        // Sort by confidence and limit
        return suggestions
            .sorted { $0.confidence > $1.confidence }
            .prefix(settings.maxSuggestions)
            .map { $0 }
    }
    
    /// Parse and preview query without executing search
    /// - Parameter query: Natural language query to parse
    /// - Returns: Parsed query structure for preview
    public func previewQuery(_ query: String) async -> NaturalLanguageQuery {
        return await parseNaturalLanguageQuery(query)
    }
    
    // MARK: - Natural Language Processing
    
    private func parseNaturalLanguageQuery(_ query: String) async -> NaturalLanguageQuery {
        logger.debug("Parsing natural language query: '\(query)'")
        
        // Step 1: Basic language detection and normalization
        let language = detectLanguage(query)
        let normalizedQuery = normalizeQuery(query)
        
        // Step 2: Intent classification
        let intent = await classifySearchIntent(normalizedQuery)
        
        // Step 3: Temporal context extraction
        let temporalContext = await extractTemporalContext(normalizedQuery)
        
        // Step 4: Content filter detection
        let contentFilters = await detectContentFilters(normalizedQuery)
        
        // Step 5: Entity extraction and filtering
        let entityFilters = await extractEntityFilters(normalizedQuery)
        
        // Step 6: Semantic tag extraction
        let semanticTags = await extractSemanticTags(normalizedQuery)
        
        // Step 7: Query vectorization for similarity
        let queryVector = await vectorizeQuery(normalizedQuery)
        
        // Step 8: Remove temporal and filter words for core search
        let processedText = await cleanQueryForSearch(normalizedQuery, temporalContext: temporalContext, contentFilters: contentFilters)
        
        // Step 9: Calculate overall confidence
        let confidence = calculateQueryConfidence(
            intent: intent,
            temporalContext: temporalContext,
            contentFilters: contentFilters,
            entityFilters: entityFilters
        )
        
        return NaturalLanguageQuery(
            originalText: query,
            processedText: processedText,
            intent: intent,
            temporalContext: temporalContext,
            contentFilters: contentFilters,
            entityFilters: entityFilters,
            semanticTags: semanticTags,
            confidence: confidence,
            language: language,
            queryVector: queryVector
        )
    }
    
    private func detectLanguage(_ query: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(query)
        return recognizer.dominantLanguage?.rawValue ?? "en"
    }
    
    private func normalizeQuery(_ query: String) -> String {
        return query
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    private func classifySearchIntent(_ query: String) async -> SearchIntent {
        // Enhanced intent classification using pattern matching
        let intentPatterns: [SearchIntent: [String]] = [
            .find: ["find", "locate", "where", "look for"],
            .show: ["show", "display", "see", "view"],
            .search: ["search", "query", "hunt"],
            .filter: ["filter", "narrow", "refine"],
            .get: ["get", "retrieve", "fetch"],
            .lookup: ["lookup", "check", "verify"],
            .discover: ["discover", "explore", "uncover"],
            .organize: ["organize", "group", "sort"],
            .compare: ["compare", "contrast", "difference"],
            .recent: ["recent", "latest", "new", "today"],
            .similar: ["similar", "like", "matching"],
            .duplicate: ["duplicate", "same", "identical", "copy"]
        ]
        
        for (intent, patterns) in intentPatterns {
            for pattern in patterns {
                if query.contains(pattern) {
                    return intent
                }
            }
        }
        
        return .find // Default intent
    }
    
    private func extractTemporalContext(_ query: String) async -> TemporalContext? {
        // Advanced temporal parsing with vacation/event detection
        let temporalPatterns: [String: (TemporalContext.TemporalType, TimeInterval?)] = [
            // Relative temporal expressions
            "yesterday": (.relative, -86400),
            "today": (.relative, 0),
            "tomorrow": (.relative, 86400),
            "last week": (.range, -604800),
            "this week": (.range, 0),
            "next week": (.range, 604800),
            "last month": (.range, -2592000),
            "this month": (.range, 0),
            "last year": (.range, -31536000),
            
            // Named periods
            "vacation": (.namedPeriod, nil),
            "holiday": (.namedPeriod, nil),
            "trip": (.namedPeriod, nil),
            "work": (.event, nil),
            "meeting": (.event, nil),
            "conference": (.event, nil),
            "wedding": (.event, nil),
            
            // Seasons
            "summer": (.season, nil),
            "winter": (.season, nil),
            "spring": (.season, nil),
            "fall": (.season, nil),
            "autumn": (.season, nil),
            
            // Time of day
            "morning": (.timeOfDay, nil),
            "afternoon": (.timeOfDay, nil),
            "evening": (.timeOfDay, nil),
            "night": (.timeOfDay, nil)
        ]
        
        for (pattern, (type, offset)) in temporalPatterns {
            if query.contains(pattern) {
                let startDate: Date?
                let endDate: Date?
                
                if let offset = offset {
                    if type == .range {
                        // Calculate range based on pattern
                        startDate = Date().addingTimeInterval(offset)
                        endDate = offset < 0 ? Date() : Date().addingTimeInterval(offset * 2)
                    } else {
                        startDate = Date().addingTimeInterval(offset)
                        endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate!) ?? startDate
                    }
                } else {
                    // For named periods, use broader date ranges or special handling
                    startDate = nil
                    endDate = nil
                }
                
                return TemporalContext(
                    type: type,
                    startDate: startDate,
                    endDate: endDate,
                    relativePhrase: pattern,
                    confidence: 0.9,
                    namedPeriod: type == .namedPeriod || type == .event ? pattern : nil
                )
            }
        }
        
        // Try to extract specific dates using natural language processing
        return await extractSpecificDates(query)
    }
    
    private func extractSpecificDates(_ query: String) async -> TemporalContext? {
        // Use NSDataDetector for date extraction
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        
        let matches = detector.matches(in: query, options: [], range: NSRange(location: 0, length: query.utf16.count))
        
        if let match = matches.first, let date = match.date {
            return TemporalContext(
                type: .absolute,
                startDate: date,
                endDate: Calendar.current.date(byAdding: .day, value: 1, to: date),
                relativePhrase: String(query[Range(match.range, in: query)!]),
                confidence: 0.8,
                namedPeriod: nil
            )
        }
        
        return nil
    }
    
    private func detectContentFilters(_ query: String) async -> [ContentFilter] {
        var filters: [ContentFilter] = []
        
        let contentPatterns: [ContentFilter.ContentType: [String]] = [
            .text: ["text", "words", "message", "note"],
            .website: ["website", "web", "url", "link", "site"],
            .phoneNumber: ["phone", "number", "contact", "mobile"],
            .email: ["email", "mail", "@", "address"],
            .receipt: ["receipt", "bill", "invoice", "purchase"],
            .document: ["document", "pdf", "file", "paper"],
            .contact: ["contact", "person", "name"],
            .app: ["app", "application", "software"],
            .social: ["social", "facebook", "twitter", "instagram"],
            .qrCode: ["qr", "code", "barcode"],
            .photo: ["photo", "picture", "image"]
        ]
        
        for (contentType, patterns) in contentPatterns {
            for pattern in patterns {
                if query.contains(pattern) {
                    filters.append(ContentFilter(
                        type: contentType,
                        pattern: pattern,
                        confidence: 0.8
                    ))
                }
            }
        }
        
        return filters
    }
    
    private func extractEntityFilters(_ query: String) async -> [EntityFilter] {
        // Use existing EntityExtractionService for advanced entity detection
        // TODO: Integrate entity extraction when service is available
        let entities: [String] = []
        
        // Return empty filters for now
        return []
    }
    
    private func mapEntityTypeToCategory(_ entityType: String) -> EntityFilter.EntityCategory {
        switch entityType.lowercased() {
        case "person", "personalname":
            return .person
        case "place", "placename", "location":
            return .place
        case "organization", "organizationname":
            return .organization
        case "phonenumber":
            return .contact
        case "email":
            return .contact
        case "product", "brand":
            return .product
        case "event":
            return .event
        case "app", "software":
            return .technology
        case "currency", "money":
            return .financial
        default:
            return .person // Default fallback
        }
    }
    
    private func extractSemanticTags(_ query: String) async -> [String] {
        // Extract semantic meaning using existing query parser
        // TODO: Integrate query parser when service is available
        // For now, return simple keyword extraction
        return query.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.count > 2 }
    }
    
    private func vectorizeQuery(_ query: String) async -> [Float]? {
        // Placeholder for query vectorization
        // In production, would use NLEmbedding or similar
        return nil
    }
    
    private func cleanQueryForSearch(_ query: String, temporalContext: TemporalContext?, contentFilters: [ContentFilter]) async -> String {
        var cleanedQuery = query
        
        // Remove temporal phrases
        if let temporal = temporalContext {
            cleanedQuery = cleanedQuery.replacingOccurrences(of: temporal.relativePhrase, with: "")
        }
        
        // Remove content filter words
        for filter in contentFilters {
            if let pattern = filter.pattern {
                cleanedQuery = cleanedQuery.replacingOccurrences(of: pattern, with: "")
            }
        }
        
        // Remove common search words
        let stopWords = ["find", "show", "search", "get", "screenshots", "images", "photos", "with", "from", "of", "the", "a", "an"]
        for stopWord in stopWords {
            cleanedQuery = cleanedQuery.replacingOccurrences(of: "\\b\(stopWord)\\b", with: "", options: .regularExpression)
        }
        
        return cleanedQuery
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func calculateQueryConfidence(
        intent: SearchIntent,
        temporalContext: TemporalContext?,
        contentFilters: [ContentFilter],
        entityFilters: [EntityFilter]
    ) -> Double {
        var confidence = 0.5 // Base confidence
        
        // Intent adds confidence
        confidence += 0.1
        
        // Temporal context adds significant confidence
        if let temporal = temporalContext {
            confidence += temporal.confidence * 0.3
        }
        
        // Content filters add confidence
        confidence += Double(contentFilters.count) * 0.1
        
        // Entity filters add highest confidence
        let entityConfidence = entityFilters.reduce(0.0) { $0 + $1.confidence } / Double(max(entityFilters.count, 1))
        confidence += entityConfidence * 0.2
        
        return min(1.0, confidence)
    }
    
    // MARK: - Search Execution
    
    private func getScreenshotsInTemporalContext(_ context: TemporalContext?, in modelContext: ModelContext) async throws -> [Screenshot] {
        guard let context = context else {
            // Return all screenshots if no temporal context
            return try modelContext.fetch(FetchDescriptor<Screenshot>())
        }
        
        var predicate: Predicate<Screenshot>
        
        if let startDate = context.startDate, let endDate = context.endDate {
            predicate = #Predicate<Screenshot> { screenshot in
                screenshot.timestamp >= startDate && screenshot.timestamp <= endDate
            }
        } else if context.type == .namedPeriod || context.type == .event {
            // For named periods, search in user tags and extracted text
            let searchTerm = context.namedPeriod ?? context.relativePhrase
            predicate = #Predicate<Screenshot> { screenshot in
                (screenshot.userTags?.contains { tag in tag.contains(searchTerm) } ?? false) ||
                (screenshot.extractedText?.contains(searchTerm) ?? false)
            }
        } else {
            // Fallback to recent screenshots
            let recentDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            predicate = #Predicate<Screenshot> { screenshot in
                screenshot.timestamp >= recentDate
            }
        }
        
        let descriptor = FetchDescriptor<Screenshot>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
    
    private func applyContentFilters(_ screenshots: [Screenshot], filters: [ContentFilter]) async -> [Screenshot] {
        guard !filters.isEmpty else { return screenshots }
        
        return screenshots.filter { screenshot in
            for filter in filters {
                switch filter.type {
                case .text:
                    if screenshot.extractedText?.isEmpty == false { return true }
                case .website:
                    if screenshot.extractedText?.contains("http") == true || 
                       screenshot.extractedText?.contains("www") == true { return true }
                case .phoneNumber:
                    if screenshot.extractedText?.contains(regex: "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b") == true { return true }
                case .email:
                    if screenshot.extractedText?.contains("@") == true { return true }
                case .receipt:
                    if screenshot.extractedText?.contains(regex: "(?i)\\b(receipt|total|tax|bill)\\b") == true { return true }
                case .document:
                    if screenshot.visualAttributes?.isDocument == true { return true }
                case .contact:
                    if screenshot.extractedText?.contains(regex: "\\b[A-Z][a-z]+ [A-Z][a-z]+\\b") == true { return true }
                case .app:
                    if !screenshot.filename.isEmpty { return true }
                case .social:
                    if screenshot.extractedText?.contains(regex: "(?i)\\b(facebook|twitter|instagram|social)\\b") == true { return true }
                case .qrCode:
                    if screenshot.visualAttributes?.prominentObjects.contains(where: { $0.label == "QR Code" }) == true { return true }
                case .photo:
                    if screenshot.visualAttributes != nil { return true }
                default:
                    continue
                }
            }
            return false
        }
    }
    
    private func applyEntityFilters(_ screenshots: [Screenshot], filters: [EntityFilter]) async -> [Screenshot] {
        guard !filters.isEmpty else { return screenshots }
        
        return screenshots.filter { screenshot in
            for filter in filters {
                let searchText = [
                    screenshot.extractedText,
                    screenshot.userNotes,
                    screenshot.userTags?.joined(separator: " "),
                    screenshot.filename
                ].compactMap { $0 }.joined(separator: " ")
                
                if searchText.localizedCaseInsensitiveContains(filter.entityValue) {
                    return true
                }
            }
            return false
        }
    }
    
    private func performSemanticSearch(
        query: String,
        in screenshots: [Screenshot],
        modelContext: ModelContext,
        options: SearchOptions?
    ) async -> [Screenshot] {
        
        guard !query.isEmpty else { return screenshots }
        
        // Use existing SearchService for semantic search on filtered screenshots
        // For now, return the filtered screenshots since SearchService integration needs proper setup
        // TODO: Integrate with existing SearchService when available
        return screenshots
    }
    
    private func enhanceResultsWithContext(_ results: [Screenshot], originalQuery: NaturalLanguageQuery) async -> [Screenshot] {
        // Apply additional ranking based on query context
        let scoredResults = results.map { screenshot -> (Screenshot, Double) in
            var score = 1.0
            
            // Boost score for intent matching
            switch originalQuery.intent {
            case .recent:
                let hoursSince = Date().timeIntervalSince(screenshot.timestamp) / 3600
                score += max(0, (48 - hoursSince) / 48) // Boost recent screenshots
            case .similar:
                // Would boost visually similar screenshots
                score += 0.1
            case .duplicate:
                // Would boost potential duplicates
                score += 0.1
            default:
                break
            }
            
            // Boost for entity matches
            for entityFilter in originalQuery.entityFilters {
                let searchText = [screenshot.extractedText, screenshot.userNotes].compactMap { $0 }.joined(separator: " ")
                if searchText.localizedCaseInsensitiveContains(entityFilter.entityValue) {
                    score += entityFilter.confidence
                }
            }
            
            // Boost for content filter matches
            for contentFilter in originalQuery.contentFilters {
                score += contentFilter.confidence * 0.5
            }
            
            return (screenshot, score)
        }
        
        return scoredResults
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
    
    // MARK: - Learning and Suggestions
    
    private func recordQueryForLearning(_ query: NaturalLanguageQuery, resultCount: Int, executionTime: TimeInterval) async {
        let processedQuery = ProcessedQuery(
            originalQuery: query.originalText,
            processedQuery: query.processedText,
            resultCount: resultCount,
            executionTime: executionTime
        )
        
        queryHistory.append(processedQuery)
        
        // Keep history manageable
        if queryHistory.count > settings.maxHistoryEntries {
            queryHistory.removeFirst(queryHistory.count - settings.maxHistoryEntries)
        }
        
        saveQueryHistory()
    }
    
    private func generateContextualSuggestions(based query: NaturalLanguageQuery, results: [Screenshot]) async {
        var suggestions: [SearchSuggestion] = []
        
        // Temporal suggestions based on current query
        if query.temporalContext != nil {
            suggestions.append(contentsOf: [
                SearchSuggestion(text: "screenshots from this week", type: .temporal, confidence: 0.8, contextHint: "Expand time range"),
                SearchSuggestion(text: "recent screenshots", type: .temporal, confidence: 0.7, contextHint: "Show latest")
            ])
        }
        
        // Content type suggestions
        for contentFilter in query.contentFilters {
            switch contentFilter.type {
            case .website:
                suggestions.append(SearchSuggestion(text: "screenshots with links", type: .contextual, confidence: 0.8, contextHint: "Find more websites"))
            case .receipt:
                suggestions.append(SearchSuggestion(text: "all my receipts", type: .contextual, confidence: 0.9, contextHint: "Organize expenses"))
            case .contact:
                suggestions.append(SearchSuggestion(text: "screenshots with phone numbers", type: .contextual, confidence: 0.8, contextHint: "Find contact info"))
            default:
                break
            }
        }
        
        searchSuggestions = suggestions.prefix(settings.maxSuggestions).map { $0 }
    }
    
    private func getCompletionSuggestions(for partialQuery: String) async -> [SearchSuggestion] {
        let completions = [
            "screenshots from yesterday",
            "screenshots with phone numbers",
            "screenshots of receipts",
            "screenshots from my vacation",
            "screenshots with email addresses",
            "screenshots from last week",
            "screenshots of websites",
            "screenshots from meetings"
        ]
        
        return completions
            .filter { $0.localizedCaseInsensitiveHasPrefix(partialQuery) }
            .map { SearchSuggestion(text: $0, type: .completion, confidence: 0.9, contextHint: "Complete search") }
    }
    
    private func getTemporalSuggestions(for query: String) -> [SearchSuggestion] {
        let temporalSuggestions = [
            "yesterday",
            "last week",
            "last month",
            "from my vacation",
            "recent",
            "today"
        ]
        
        return temporalSuggestions
            .filter { query.localizedCaseInsensitiveContains($0) }
            .map { SearchSuggestion(text: "screenshots \($0)", type: .temporal, confidence: 0.8, contextHint: "Time-based search") }
    }
    
    private func getContentTypeSuggestions(for query: String) -> [SearchSuggestion] {
        let contentTypes = [
            "with text",
            "of receipts", 
            "with phone numbers",
            "with email addresses",
            "of websites",
            "of documents"
        ]
        
        return contentTypes
            .filter { suggestion in
                query.localizedCaseInsensitiveContains(suggestion)
            }
            .map { SearchSuggestion(text: "screenshots \($0)", type: .contextual, confidence: 0.7, contextHint: "Content filter") }
    }
    
    private func getRecentQuerySuggestions(matching partialQuery: String) -> [SearchSuggestion] {
        return queryHistory
            .filter { $0.originalQuery.localizedCaseInsensitiveContains(partialQuery) }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(3)
            .map { SearchSuggestion(text: $0.originalQuery, type: .recent, confidence: 0.6, contextHint: "Recent search") }
    }
    
    private func getRecentAndPopularSuggestions() -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        // Recent queries
        suggestions.append(contentsOf: queryHistory
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(3)
            .map { SearchSuggestion(text: $0.originalQuery, type: .recent, confidence: 0.7, contextHint: "Recent") }
        )
        
        // Popular patterns
        suggestions.append(contentsOf: [
            SearchSuggestion(text: "screenshots from yesterday", type: .popular, confidence: 0.8, contextHint: "Popular search"),
            SearchSuggestion(text: "screenshots with text", type: .popular, confidence: 0.8, contextHint: "Find text content"),
            SearchSuggestion(text: "recent screenshots", type: .popular, confidence: 0.7, contextHint: "Latest items")
        ])
        
        return suggestions
    }
    
    // MARK: - Persistence
    
    private func loadQueryHistory() {
        guard let data = UserDefaults.standard.data(forKey: "NaturalLanguageSearchHistory") else {
            queryHistory = []
            return
        }
        
        do {
            queryHistory = try JSONDecoder().decode([ProcessedQuery].self, from: data)
        } catch {
            logger.error("Failed to load query history: \(error.localizedDescription)")
            queryHistory = []
        }
    }
    
    private func saveQueryHistory() {
        do {
            let data = try JSONEncoder().encode(queryHistory)
            UserDefaults.standard.set(data, forKey: "NaturalLanguageSearchHistory")
        } catch {
            logger.error("Failed to save query history: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Extensions

// MARK: - Search Options Compatibility

public struct SearchOptions {
    let filters: [SearchFilter]
    let sortBy: SearchSortOrder
    
    public enum SearchSortOrder {
        case relevance
        case date
        case name
    }
    
    public enum SearchFilter {
        case hasText
        case dateRange(Date, Date)
        case favorite
        case tagged
    }
}