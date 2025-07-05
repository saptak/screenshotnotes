import Foundation
import NaturalLanguage

/// Simple, working query parser for Sub-Sprint 5.1.1
/// This integrates with the SearchQuery model in the Models directory
public final class QueryParserService: ObservableObject {
    
    private let languageRecognizer = NLLanguageRecognizer()
    private let tokenizer = NLTokenizer(unit: .word)
    
    /// Visual attribute keywords for enhanced detection
    private let visualKeywords: Set<String> = [
        "blue", "red", "green", "yellow", "purple", "orange", "pink", "black", "white", "gray",
        "bright", "dark", "light", "small", "large", "big", "tiny", "dress", "shirt", "phone"
    ]
    
    /// Temporal keywords for time-based queries
    private let temporalKeywords: Set<String> = [
        "yesterday", "today", "tomorrow", "week", "month", "year", "last", "this", "recent"
    ]
    
    /// Intent patterns for classification
    private let intentPatterns: [SearchIntent: [String]] = [
        .find: ["find", "locate", "where", "look for"],
        .search: ["search", "look", "examine"],
        .show: ["show", "display", "list"],
        .filter: ["filter", "only", "exclude"]
    ]
    
    public init() {
        setupLanguageRecognizer()
    }
    
    /// Parse a natural language query into structured SearchQuery
    public func parseQuery(_ query: String) async -> SearchQuery {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Input validation
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return createErrorQuery(query)
        }
        
        // Language detection
        languageRecognizer.processString(query)
        let language = languageRecognizer.dominantLanguage ?? .english
        
        // Tokenization and normalization
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = tokenizeQuery(normalizedQuery)
        let searchTerms = filterStopWords(tokens)
        
        // Intent classification
        let (intent, confidence) = classifyIntent(normalizedQuery, searchTerms: searchTerms)
        
        // Context detection
        let hasVisualAttributes = detectVisualAttributes(searchTerms)
        let hasTemporalContext = detectTemporalContext(searchTerms)
        
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        return SearchQuery(
            rawQuery: query,
            normalizedQuery: normalizedQuery,
            intent: intent,
            confidence: confidence,
            language: language,
            searchTerms: searchTerms,
            hasTemporalContext: hasTemporalContext,
            hasVisualAttributes: hasVisualAttributes,
            processingTimeMs: processingTime
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupLanguageRecognizer() {
        languageRecognizer.languageConstraints = [.english, .spanish, .french, .german]
    }
    
    private func tokenizeQuery(_ query: String) -> [String] {
        tokenizer.string = query
        var tokens: [String] = []
        
        tokenizer.enumerateTokens(in: query.startIndex..<query.endIndex) { tokenRange, _ in
            let token = String(query[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                tokens.append(token)
            }
            return true
        }
        
        return tokens
    }
    
    private func filterStopWords(_ tokens: [String]) -> [String] {
        let stopWords = Set(["a", "an", "and", "are", "as", "at", "be", "by", "for", "from", 
                            "has", "he", "in", "is", "it", "its", "of", "on", "that", "the", 
                            "to", "was", "will", "with", "me", "my", "you", "your"])
        
        return tokens.filter { !stopWords.contains($0.lowercased()) }
    }
    
    private func classifyIntent(_ query: String, searchTerms: [String]) -> (SearchIntent, QueryConfidence) {
        var bestIntent: SearchIntent = .unknown
        var bestScore: Double = 0.0
        
        for (intent, keywords) in intentPatterns {
            let score = calculateIntentScore(query, keywords: keywords)
            if score > bestScore {
                bestScore = score
                bestIntent = intent
            }
        }
        
        // Default to search if no specific intent detected but has search terms
        if bestIntent == .unknown && !searchTerms.isEmpty {
            bestIntent = .search
            bestScore = 0.5
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
    
    private func calculateIntentScore(_ query: String, keywords: [String]) -> Double {
        var score: Double = 0.0
        
        for keyword in keywords {
            if query.contains(keyword) {
                score += 0.4
            }
        }
        
        return min(1.0, score)
    }
    
    private func detectVisualAttributes(_ searchTerms: [String]) -> Bool {
        return searchTerms.contains { term in
            visualKeywords.contains(term.lowercased())
        }
    }
    
    private func detectTemporalContext(_ searchTerms: [String]) -> Bool {
        return searchTerms.contains { term in
            temporalKeywords.contains(term.lowercased())
        }
    }
    
    private func createErrorQuery(_ originalQuery: String) -> SearchQuery {
        return SearchQuery(
            rawQuery: originalQuery,
            normalizedQuery: "",
            intent: .unknown,
            confidence: .veryLow,
            language: .undetermined,
            searchTerms: [],
            processingTimeMs: 0.0
        )
    }
}
