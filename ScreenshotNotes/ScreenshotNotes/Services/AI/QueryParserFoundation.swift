import Foundation
import NaturalLanguage
import SwiftData

// This file implements Sub-Sprint 5.1.1: Core ML Setup & Query Parser Foundation
// It provides basic NLP infrastructure for conversational AI search

/// Enhanced SearchService extension for natural language query parsing
/// Integrates QueryParser capabilities with existing search infrastructure
/// NOTE: This will integrate with the existing SearchService when compiled in Xcode
public class NaturalLanguageSearchExtension {
    
    private let queryParser = QueryParser()
    
    /// Parse natural language query and convert to enhanced search
    /// This is the main integration point for Sub-Sprint 5.1.1
    public func parseNaturalLanguageQuery(_ query: String) async -> ParsedQuery {
        return await queryParser.parseQuery(query)
    }
    
    /// Enhanced search with natural language understanding
    /// NOTE: In full integration, this would work with Screenshot model
    public func searchWithNaturalLanguage(query: String, in items: [Any]) async -> [Any] {
        let parsedQuery = await parseNaturalLanguageQuery(query)
        
        // If parsing confidence is low, fall back to traditional search
        guard parsedQuery.confidence >= 0.6 else {
            return items // Fallback logic would go here
        }
        
        // Enhanced search logic would be implemented here
        // For now, return original items as this is a foundation layer
        return items
    }
}

/// Lightweight parsed query representation for integration
public struct ParsedQuery {
    public let originalQuery: String
    public let intent: QueryIntent
    public let searchTerms: [String]
    public let confidence: Double
    public let hasVisualAttributes: Bool
    public let hasTemporalContext: Bool
    public let language: NLLanguage
    public let processingTimeMs: Double
    
    public var debugDescription: String {
        return "ParsedQuery(intent: \(intent), terms: \(searchTerms), confidence: \(confidence))"
    }
}

/// Basic intent classification for integration
public enum QueryIntent: String, CaseIterable {
    case find = "find"
    case search = "search" 
    case show = "show"
    case filter = "filter"
    case unknown = "unknown"
}

/// Core query parser for natural language understanding
/// Implements Sub-Sprint 5.1.1 requirements with NLLanguageRecognizer
public class QueryParser {
    
    private let languageRecognizer = NLLanguageRecognizer()
    private let tokenizer = NLTokenizer(unit: .word)
    
    /// Visual attribute keywords for detection
    private let visualKeywords: Set<String> = [
        "blue", "red", "green", "yellow", "purple", "orange", "pink", "black", "white", "gray",
        "bright", "dark", "light", "small", "large", "big", "tiny", "dress", "shirt", "phone"
    ]
    
    /// Temporal keywords for time-based queries  
    private let temporalKeywords: Set<String> = [
        "yesterday", "today", "tomorrow", "week", "month", "year", "last", "this", "recent"
    ]
    
    /// Intent patterns for classification
    private let intentPatterns: [QueryIntent: [String]] = [
        .find: ["find", "locate", "where", "look for"],
        .search: ["search", "look", "examine"],
        .show: ["show", "display", "list"],
        .filter: ["filter", "only", "exclude"]
    ]
    
    public func parseQuery(_ query: String) async -> ParsedQuery {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Input validation
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return createErrorQuery(query, "Empty query")
        }
        
        // Language detection
        languageRecognizer.processString(query)
        let language = languageRecognizer.dominantLanguage ?? .english
        
        // Tokenization
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = tokenizeQuery(normalizedQuery)
        let searchTerms = filterStopWords(tokens)
        
        // Intent classification
        let (intent, confidence) = classifyIntent(normalizedQuery, searchTerms: searchTerms)
        
        // Context detection
        let hasVisualAttributes = detectVisualAttributes(searchTerms)
        let hasTemporalContext = detectTemporalContext(searchTerms)
        
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        return ParsedQuery(
            originalQuery: query,
            intent: intent,
            searchTerms: searchTerms,
            confidence: confidence,
            hasVisualAttributes: hasVisualAttributes,
            hasTemporalContext: hasTemporalContext,
            language: language,
            processingTimeMs: processingTime
        )
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
    
    private func classifyIntent(_ query: String, searchTerms: [String]) -> (QueryIntent, Double) {
        var bestIntent: QueryIntent = .unknown
        var bestScore: Double = 0.0
        
        for (intent, keywords) in intentPatterns {
            let score = calculateIntentScore(query, searchTerms: searchTerms, keywords: keywords)
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
        
        return (bestIntent, bestScore)
    }
    
    private func calculateIntentScore(_ query: String, searchTerms: [String], keywords: [String]) -> Double {
        var score: Double = 0.0
        
        // Direct keyword matches
        for keyword in keywords {
            if query.contains(keyword) {
                score += 0.4
            }
        }
        
        // Search term matches
        let matchingTerms = searchTerms.filter { term in
            keywords.contains { keyword in
                keyword.contains(term) || term.contains(keyword)
            }
        }
        
        if !matchingTerms.isEmpty {
            score += 0.3 * (Double(matchingTerms.count) / Double(searchTerms.count))
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
    
    private func createErrorQuery(_ originalQuery: String, _ reason: String) -> ParsedQuery {
        return ParsedQuery(
            originalQuery: originalQuery,
            intent: .unknown,
            searchTerms: [],
            confidence: 0.0,
            hasVisualAttributes: false,
            hasTemporalContext: false,
            language: .undetermined,
            processingTimeMs: 0.0
        )
    }
}

/// Integration test function for Sub-Sprint 5.1.1
/// Tests the core requirements: basic intent classification and visual attribute detection
public func testQueryParserIntegration() async {
    let parser = QueryParser()
    
    // Test case from implementation plan: "find blue dress"
    let testQuery = "find blue dress"
    let result = await parser.parseQuery(testQuery)
    
    print("🧪 Testing Sub-Sprint 5.1.1 - Core ML Setup & Query Parser Foundation")
    print("Query: '\(testQuery)'")
    print("Result: \(result.debugDescription)")
    
    // Validate integration test requirements
    let hasCorrectIntent = result.intent == .find
    let hasVisualAttributes = result.hasVisualAttributes
    let hasSearchTerms = result.searchTerms.contains("blue") && result.searchTerms.contains("dress")
    let hasReasonableConfidence = result.confidence >= 0.4
    
    print("✅ Intent Classification: \(hasCorrectIntent ? "PASS" : "FAIL") - Detected '\(result.intent.rawValue)'")
    print("✅ Visual Attributes: \(hasVisualAttributes ? "PASS" : "FAIL") - Found visual terms")
    print("✅ Search Terms: \(hasSearchTerms ? "PASS" : "FAIL") - Extracted: \(result.searchTerms)")
    print("✅ Confidence: \(hasReasonableConfidence ? "PASS" : "FAIL") - Score: \(result.confidence)")
    print("⏱️  Processing Time: \(String(format: "%.1f", result.processingTimeMs))ms")
    
    let overallPass = hasCorrectIntent && hasVisualAttributes && hasSearchTerms && hasReasonableConfidence
    print("\n🎯 Sub-Sprint 5.1.1 Integration Test: \(overallPass ? "✅ PASSED" : "❌ FAILED")")
}
