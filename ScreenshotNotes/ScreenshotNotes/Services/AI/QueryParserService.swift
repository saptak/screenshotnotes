import Foundation
import NaturalLanguage
import os.log

// Import the SearchQuery model from Models directory
// Note: In Xcode, this will be resolved through the project structure

/// Protocol defining query parsing capabilities
public protocol QueryParserServiceProtocol {
    func parseQuery(_ query: String) async -> SearchQuery
    func parseQueries(_ queries: [String]) async -> [SearchQuery]
    func validateQuery(_ query: SearchQuery) -> Bool
}

/// Advanced natural language query parser using Core ML and NaturalLanguage frameworks
@MainActor
public final class QueryParserService: ObservableObject, QueryParserServiceProtocol {
    
    // MARK: - Constants
    
    private enum Constants {
        static let maxQueryLength = 500
        static let minQueryLength = 1
        static let maxProcessingTimeMs = 200.0
        static let defaultConfidenceThreshold = 0.6
    }
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.screenshotnotes.ai", category: "QueryParser")
    private let languageRecognizer = NLLanguageRecognizer()
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass])
    
    /// Pre-compiled intent detection patterns for performance
    private lazy var intentPatterns: [SearchIntent: [NSRegularExpression]] = {
        return compileIntentPatterns()
    }()
    
    /// Cached stop words for different languages
    private var stopWordsCache: [NLLanguage: Set<String>] = [:]
    
    /// Visual attribute keywords for enhanced detection
    private let visualAttributeKeywords: Set<String> = [
        "blue", "red", "green", "yellow", "purple", "orange", "pink", "black", "white", "gray",
        "bright", "dark", "light", "small", "large", "big", "tiny", "huge",
        "round", "square", "rectangle", "circle", "triangle",
        "dress", "shirt", "phone", "car", "house", "face", "person", "text", "document"
    ]
    
    /// Temporal keywords for time-based queries
    private let temporalKeywords: Set<String> = [
        "yesterday", "today", "tomorrow", "week", "month", "year", "day", "hour",
        "last", "this", "next", "recent", "old", "new", "before", "after", "during",
        "morning", "afternoon", "evening", "night", "monday", "tuesday", "wednesday",
        "thursday", "friday", "saturday", "sunday", "january", "february", "march",
        "april", "may", "june", "july", "august", "september", "october", "november", "december"
    ]
    
    // MARK: - Initialization
    
    public init() {
        setupLanguageRecognizer()
        preloadStopWords()
        logger.info("QueryParserService initialized with Core ML and NaturalLanguage support")
    }
    
    // MARK: - Public Interface
    
    /// Parse a single natural language query into structured SearchQuery
    public func parseQuery(_ query: String) async -> SearchQuery {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Input validation
        guard isValidInput(query) else {
            logger.warning("Invalid query input: '\(query)'")
            return createErrorQuery(query, reason: "Invalid input")
        }
        
        let builder = SearchQueryBuilder().setRawQuery(query)
        
        // Step 1: Language Detection
        let detectedLanguage = await detectLanguage(query)
        builder.setLanguage(detectedLanguage)
        
        // Step 2: Text Normalization
        let normalizedQuery = normalizeQuery(query)
        builder.setNormalizedQuery(normalizedQuery)
        
        // Step 3: Tokenization
        let tokens = await tokenizeQuery(normalizedQuery, language: detectedLanguage)
        builder.setTokens(tokens)
        
        // Step 4: Stop Word Filtering
        let (searchTerms, stopWords) = filterStopWords(tokens, language: detectedLanguage)
        builder.setSearchTerms(searchTerms)
        builder.setFilteredStopWords(stopWords)
        
        // Step 5: Intent Classification
        let (intent, confidence) = classifyIntent(normalizedQuery, searchTerms: searchTerms)
        builder.setIntent(intent)
        builder.setConfidence(confidence)
        
        // Step 6: Context Analysis
        let hasTemporalContext = detectTemporalContext(searchTerms)
        let hasVisualAttributes = detectVisualAttributes(searchTerms)
        let requiresExactMatch = detectExactMatch(normalizedQuery)
        
        builder.setTemporalContext(hasTemporalContext)
        builder.setVisualAttributes(hasVisualAttributes)
        builder.setExactMatch(requiresExactMatch)
        
        // Step 7: Performance Metrics
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        builder.setProcessingTime(processingTime)
        
        let result = builder.build()
        
        logger.info("Parsed query '\(query)' → Intent: \(intent.rawValue), Confidence: \(confidence.rawValue), Time: \(String(format: "%.1f", processingTime))ms")
        
        return result
    }
    
    /// Parse multiple queries efficiently with batch processing
    public func parseQueries(_ queries: [String]) async -> [SearchQuery] {
        logger.info("Batch parsing \(queries.count) queries")
        
        return await withTaskGroup(of: (Int, SearchQuery).self) { group in
            // Add tasks for each query with index preservation
            for (index, query) in queries.enumerated() {
                group.addTask {
                    let result = await self.parseQuery(query)
                    return (index, result)
                }
            }
            
            // Collect results in original order
            var results: [(Int, SearchQuery)] = []
            for await result in group {
                results.append(result)
            }
            
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    /// Validate a parsed SearchQuery for quality and completeness
    public func validateQuery(_ query: SearchQuery) -> Bool {
        let isValid = query.confidence.rawValue >= Constants.defaultConfidenceThreshold &&
                     query.intent != .unknown &&
                     !query.searchTerms.isEmpty &&
                     query.processingTimeMs <= Constants.maxProcessingTimeMs
        
        if !isValid {
            logger.debug("Query validation failed: \(query.debugDescription)")
        }
        
        return isValid
    }
    
    // MARK: - Private Implementation
    
    private func setupLanguageRecognizer() {
        // Configure for better accuracy with shorter text
        languageRecognizer.languageConstraints = [.english, .spanish, .french, .german, .simplifiedChinese, .japanese]
    }
    
    private func preloadStopWords() {
        // Preload common stop words for performance
        let languages: [NLLanguage] = [.english, .spanish, .french, .german]
        
        for language in languages {
            stopWordsCache[language] = getStopWords(for: language)
        }
    }
    
    private func isValidInput(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= Constants.minQueryLength && 
               trimmed.count <= Constants.maxQueryLength &&
               !trimmed.isEmpty
    }
    
    private func detectLanguage(_ query: String) async -> NLLanguage {
        return await withCheckedContinuation { continuation in
            languageRecognizer.processString(query)
            let language = languageRecognizer.dominantLanguage ?? .english
            continuation.resume(returning: language)
        }
    }
    
    private func normalizeQuery(_ query: String) -> String {
        return query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"[^\w\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
    
    private func tokenizeQuery(_ query: String, language: NLLanguage) async -> [String] {
        return await withCheckedContinuation { continuation in
            tokenizer.string = query
            tokenizer.setLanguage(language)
            
            var tokens: [String] = []
            tokenizer.enumerateTokens(in: query.startIndex..<query.endIndex) { tokenRange, _ in
                let token = String(query[tokenRange])
                if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    tokens.append(token)
                }
                return true
            }
            
            continuation.resume(returning: tokens)
        }
    }
    
    private func filterStopWords(_ tokens: [String], language: NLLanguage) -> ([String], [String]) {
        let stopWords = stopWordsCache[language] ?? getStopWords(for: language)
        var searchTerms: [String] = []
        var filteredStopWords: [String] = []
        
        for token in tokens {
            if stopWords.contains(token.lowercased()) {
                filteredStopWords.append(token)
            } else {
                searchTerms.append(token)
            }
        }
        
        return (searchTerms, filteredStopWords)
    }
    
    private func getStopWords(for language: NLLanguage) -> Set<String> {
        // Common English stop words - in production, this would be loaded from resources
        let englishStopWords = Set([
            "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "has", "he",
            "in", "is", "it", "its", "of", "on", "that", "the", "to", "was", "will", "with",
            "the", "this", "these", "those", "i", "you", "we", "they", "me", "my", "mine",
            "your", "yours", "his", "her", "hers", "our", "ours", "their", "theirs"
        ])
        
        // For other languages, return basic stop words or load from resources
        switch language {
        case .english:
            return englishStopWords
        default:
            return englishStopWords // Fallback to English for now
        }
    }
    
    private func classifyIntent(_ query: String, searchTerms: [String]) -> (SearchIntent, QueryConfidence) {
        var bestIntent: SearchIntent = .unknown
        var bestScore: Double = 0.0
        
        // Check each intent pattern
        for (intent, patterns) in intentPatterns {
            let score = calculateIntentScore(query, searchTerms: searchTerms, patterns: patterns, intent: intent)
            if score > bestScore {
                bestScore = score
                bestIntent = intent
            }
        }
        
        // Determine confidence based on score
        let confidence: QueryConfidence
        switch bestScore {
        case 0.8...:
            confidence = .high
        case 0.6..<0.8:
            confidence = .medium
        case 0.4..<0.6:
            confidence = .low
        default:
            confidence = .veryLow
        }
        
        return (bestIntent, confidence)
    }
    
    private func calculateIntentScore(_ query: String, searchTerms: [String], patterns: [NSRegularExpression], intent: SearchIntent) -> Double {
        var score: Double = 0.0
        let queryRange = NSRange(query.startIndex..., in: query)
        
        // Pattern matching score
        for pattern in patterns {
            if pattern.firstMatch(in: query, range: queryRange) != nil {
                score += 0.3
            }
        }
        
        // Keyword-based scoring
        let intentKeywords = getKeywords(for: intent)
        let matchingKeywords = searchTerms.filter { term in
            intentKeywords.contains(term.lowercased())
        }
        
        if !matchingKeywords.isEmpty {
            score += 0.4 * (Double(matchingKeywords.count) / Double(searchTerms.count))
        }
        
        // Structural analysis
        if query.contains("?") {
            score += intent == .find ? 0.2 : 0.1
        }
        
        if query.hasPrefix("show") || query.hasPrefix("display") {
            score += intent == .show ? 0.3 : 0.0
        }
        
        return min(1.0, score)
    }
    
    private func getKeywords(for intent: SearchIntent) -> Set<String> {
        switch intent {
        case .search:
            return ["search", "look", "examine"]
        case .find:
            return ["find", "locate", "discover", "detect"]
        case .filter:
            return ["filter", "narrow", "refine", "limit"]
        case .show:
            return ["show", "display", "present", "reveal"]
        case .get:
            return ["get", "retrieve", "fetch", "obtain"]
        case .lookup:
            return ["lookup", "check", "reference", "consult"]
        case .unknown:
            return []
        }
    }
    
    private func compileIntentPatterns() -> [SearchIntent: [NSRegularExpression]] {
        var patterns: [SearchIntent: [NSRegularExpression]] = [:]
        
        let intentPatternStrings: [SearchIntent: [String]] = [
            .search: [#"search\s+for"#, #"looking\s+for"#, #"search"#],
            .find: [#"find\s+(.*?)\s+with"#, #"find\s+me"#, #"find"#, #"where\s+is"#],
            .filter: [#"filter\s+by"#, #"only\s+show"#, #"exclude"#, #"filter"#],
            .show: [#"show\s+me"#, #"display"#, #"list"#, #"show"#],
            .get: [#"get\s+all"#, #"retrieve"#, #"give\s+me"#],
            .lookup: [#"what\s+is"#, #"tell\s+me\s+about"#, #"lookup"#]
        ]
        
        for (intent, patternStrings) in intentPatternStrings {
            patterns[intent] = patternStrings.compactMap { patternString in
                try? NSRegularExpression(pattern: patternString, options: [.caseInsensitive])
            }
        }
        
        return patterns
    }
    
    private func detectTemporalContext(_ searchTerms: [String]) -> Bool {
        return searchTerms.contains { term in
            temporalKeywords.contains(term.lowercased())
        }
    }
    
    private func detectVisualAttributes(_ searchTerms: [String]) -> Bool {
        return searchTerms.contains { term in
            visualAttributeKeywords.contains(term.lowercased())
        }
    }
    
    private func detectExactMatch(_ query: String) -> Bool {
        return query.contains("\"") || 
               query.contains("exactly") || 
               query.contains("exact") ||
               query.contains("precisely")
    }
    
    private func createErrorQuery(_ originalQuery: String, reason: String) -> SearchQuery {
        logger.error("Creating error query for '\(originalQuery)': \(reason)")
        
        return SearchQueryBuilder()
            .setRawQuery(originalQuery)
            .setNormalizedQuery("")
            .setIntent(.unknown)
            .setConfidence(.veryLow)
            .setLanguage(.undetermined)
            .setSearchTerms([])
            .setProcessingTime(0)
            .build()
    }
}

// MARK: - Extensions

extension QueryParserService {
    
    /// Get suggested query improvements for low-confidence queries
    public func getSuggestions(for query: SearchQuery) -> [String] {
        guard query.confidence.rawValue < Constants.defaultConfidenceThreshold else {
            return []
        }
        
        var suggestions: [String] = []
        
        if query.searchTerms.isEmpty {
            suggestions.append("Try using more specific keywords")
        }
        
        if query.intent == .unknown {
            suggestions.append("Start with action words like 'find', 'show', or 'search'")
        }
        
        if query.rawQuery.count < 3 {
            suggestions.append("Use more descriptive terms for better results")
        }
        
        return suggestions
    }
    
    /// Performance metrics for monitoring
    public func getPerformanceMetrics() -> [String: Any] {
        return [
            "cache_size": stopWordsCache.count,
            "supported_languages": stopWordsCache.keys.map { $0.rawValue },
            "intent_patterns_loaded": intentPatterns.count,
            "visual_keywords_count": visualAttributeKeywords.count,
            "temporal_keywords_count": temporalKeywords.count
        ]
    }
}
