import Foundation
import NaturalLanguage

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Phase 5.1.4: Search Robustness Enhancement Service
/// Provides advanced conversational search capabilities with fuzzy matching, synonym support, and progressive fallback
@MainActor
public final class SearchRobustnessService: ObservableObject {
    
    // MARK: - Apple API Components
    
    /// iOS compatible spell checker using UITextChecker
    private let spellChecker = UITextChecker()
    
    /// Natural Language tokenizer for advanced text processing
    private let tokenizer = NLTokenizer(unit: .word)
    
    /// Language recognizer for multi-language support
    private let languageRecognizer = NLLanguageRecognizer()
    
    /// Embedding model for semantic similarity (iOS 17+)
    @available(iOS 17.0, *)
    private lazy var embeddingModel: NLEmbedding? = {
        return NLEmbedding.sentenceEmbedding(for: .english)
    }()
    
    // MARK: - Performance Metrics
    
    public struct PerformanceMetrics {
        var processingTime: TimeInterval = 0
        var fallbackTier: Int = 0
        var confidence: Double = 0
        var enhancementsApplied: [String] = []
    }
    
    @Published public var lastMetrics = PerformanceMetrics()
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let fuzzyMatchThreshold: Double = 0.75
        static let semanticSimilarityThreshold: Double = 0.6
        static let maxSuggestions: Int = 5
        static let cacheSize: Int = 1000
        static let processingTimeout: TimeInterval = 2.0
    }
    
    // MARK: - Caching
    
    private var correctionCache: [String: String] = [:]
    private var synonymCache: [String: Set<String>] = [:]
    private var embeddingCache: [String: [Double]] = [:]
    
    // MARK: - Initialization
    
    public init() {
        setupTokenizer()
        preloadCommonCorrections()
    }
    
    // MARK: - Main Enhancement Methods
    
    /// Main entry point for search query enhancement
    /// Applies multiple robustness strategies in progressive fallback order
    public func enhanceSearchQuery(_ originalQuery: String, screenshots: [Screenshot]) async -> EnhancedSearchResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var metrics = PerformanceMetrics()
        
        // Input validation
        guard !originalQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return EnhancedSearchResult(
                originalQuery: originalQuery,
                enhancedQuery: originalQuery,
                suggestions: [],
                results: screenshots,
                metrics: metrics
            )
        }
        
        // Language detection using Apple's NLLanguageRecognizer
        let detectedLanguage = await detectLanguage(originalQuery)
        metrics.enhancementsApplied.append("language_detection")
        
        // Progressive enhancement tiers
        var enhancedQuery = originalQuery
        var results: [Screenshot] = []
        var suggestions: [String] = []
        
        // Tier 1: Exact match with query normalization
        enhancedQuery = await normalizeQuery(originalQuery, language: detectedLanguage)
        results = performExactSearch(enhancedQuery, in: screenshots)
        metrics.fallbackTier = 1
        
        if !results.isEmpty {
            metrics.confidence = 1.0
            metrics.enhancementsApplied.append("normalization")
        } else {
            // Tier 2: Fuzzy matching with spell correction
            let correctedQuery = await applySpeelCorrection(enhancedQuery, language: detectedLanguage)
            if correctedQuery != enhancedQuery {
                enhancedQuery = correctedQuery
                results = performExactSearch(enhancedQuery, in: screenshots)
                metrics.fallbackTier = 2
                metrics.enhancementsApplied.append("spell_correction")
                
                if !results.isEmpty {
                    metrics.confidence = 0.8
                    suggestions.append("Did you mean: \"\(correctedQuery)\"?")
                }
            }
        }
        
        if results.isEmpty {
            // Tier 3: Synonym expansion
            let expandedQueries = await expandWithSynonyms(enhancedQuery, language: detectedLanguage)
            for expandedQuery in expandedQueries {
                results = performExactSearch(expandedQuery, in: screenshots)
                if !results.isEmpty {
                    enhancedQuery = expandedQuery
                    metrics.fallbackTier = 3
                    metrics.confidence = 0.7
                    metrics.enhancementsApplied.append("synonym_expansion")
                    break
                }
            }
        }
        
        if results.isEmpty {
            // Tier 4: Fuzzy text matching
            results = await performFuzzySearch(enhancedQuery, in: screenshots)
            if !results.isEmpty {
                metrics.fallbackTier = 4
                metrics.confidence = 0.6
                metrics.enhancementsApplied.append("fuzzy_matching")
            }
        }
        
        if results.isEmpty {
            if #available(iOS 17.0, *) {
                // Tier 5: Semantic similarity matching (iOS 17+)
                results = await performSemanticSearch(enhancedQuery, in: screenshots)
                if !results.isEmpty {
                    metrics.fallbackTier = 5
                    metrics.confidence = 0.5
                    metrics.enhancementsApplied.append("semantic_matching")
                }
            }
        }
        
        // Generate smart suggestions
        if results.isEmpty {
            suggestions = await generateSmartSuggestions(originalQuery, screenshots: screenshots)
        }
        
        // Update metrics
        metrics.processingTime = CFAbsoluteTimeGetCurrent() - startTime
        await MainActor.run {
            self.lastMetrics = metrics
        }
        
        return EnhancedSearchResult(
            originalQuery: originalQuery,
            enhancedQuery: enhancedQuery,
            suggestions: suggestions,
            results: results,
            metrics: metrics
        )
    }
}

// MARK: - Language Detection

extension SearchRobustnessService {
    
    /// Detect query language using Apple's NLLanguageRecognizer
    private func detectLanguage(_ query: String) async -> NLLanguage {
        return await withCheckedContinuation { continuation in
            languageRecognizer.processString(query)
            let language = languageRecognizer.dominantLanguage ?? .english
            continuation.resume(returning: language)
        }
    }
}

// MARK: - Query Normalization

extension SearchRobustnessService {
    
    /// Advanced query normalization using Apple's Natural Language APIs
    private func normalizeQuery(_ query: String, language: NLLanguage) async -> String {
        let normalized = query.lowercased()
        
        // Tokenize using Apple's NLTokenizer
        tokenizer.string = normalized
        tokenizer.setLanguage(language)
        
        var normalizedTokens: [String] = []
        
        tokenizer.enumerateTokens(in: normalized.startIndex..<normalized.endIndex) { tokenRange, _ in
            let token = String(normalized[tokenRange])
            
            // Apply normalization rules
            let normalizedToken = normalizeToken(token, language: language)
            if !normalizedToken.isEmpty {
                normalizedTokens.append(normalizedToken)
            }
            
            return true
        }
        
        return normalizedTokens.joined(separator: " ")
    }
    
    /// Normalize individual tokens with language-specific rules
    private func normalizeToken(_ token: String, language: NLLanguage) -> String {
        // Remove punctuation and special characters
        let alphanumeric = CharacterSet.alphanumerics
        let filtered = token.unicodeScalars.filter { alphanumeric.contains($0) }
        var normalized = String(String.UnicodeScalarView(filtered))
        
        // Apply abbreviation expansion
        normalized = expandAbbreviations(normalized, language: language)
        
        // Handle emoji conversion
        normalized = convertEmojiToText(normalized)
        
        return normalized
    }
    
    /// Expand common abbreviations based on language
    private func expandAbbreviations(_ token: String, language: NLLanguage) -> String {
        let abbreviations: [String: String] = [
            // English
            "pic": "picture",
            "pics": "pictures",
            "img": "image",
            "imgs": "images",
            "doc": "document",
            "docs": "documents",
            "msg": "message",
            "msgs": "messages",
            "txt": "text",
            "ph": "phone",
            "tel": "telephone",
            "addr": "address",
            "info": "information",
            "app": "application",
            "screenshot": "screenshot",
            "ss": "screenshot",
            
            // Spanish (if language is Spanish)
            "foto": "photograph",
            "fotos": "photographs",
            "imagen": "image",
            "imagenes": "images"
        ]
        
        return abbreviations[token] ?? token
    }
    
    /// Convert emoji to text descriptions
    private func convertEmojiToText(_ token: String) -> String {
        let emojiMappings: [String: String] = [
            "📱": "phone",
            "📷": "camera",
            "🏠": "house",
            "🚗": "car",
            "💰": "money",
            "📧": "email",
            "📄": "document",
            "🖼️": "picture",
            "📅": "calendar",
            "⭐": "star",
            "❤️": "heart",
            "👍": "thumbs up",
            "📝": "note",
            "🛒": "shopping",
            "🍕": "food",
            "🎵": "music"
        ]
        
        return emojiMappings[token] ?? token
    }
}

// MARK: - Spell Correction

extension SearchRobustnessService {
    
    /// Apply spell correction using Apple's UITextChecker (iOS compatible)
    private func applySpeelCorrection(_ query: String, language: NLLanguage) async -> String {
        // Check cache first
        if let cached = correctionCache[query] {
            return cached
        }
        
        return await withCheckedContinuation { continuation in
            // Convert NLLanguage to language code
            let languageCode = language.rawValue
            
            var correctedQuery = query
            let words = query.components(separatedBy: .whitespacesAndNewlines)
            var correctedWords: [String] = []
            
            for word in words {
                guard !word.isEmpty else { continue }
                
                // Check if word is misspelled using UITextChecker
                let range = NSRange(location: 0, length: word.count)
                let misspelledRange = spellChecker.rangeOfMisspelledWord(
                    in: word,
                    range: range,
                    startingAt: 0,
                    wrap: false,
                    language: languageCode
                )
                
                if misspelledRange.location != NSNotFound {
                    // Get suggestions for misspelled word using UITextChecker
                    let suggestions = spellChecker.guesses(
                        forWordRange: misspelledRange,
                        in: word,
                        language: languageCode
                    )
                    
                    if let firstSuggestion = suggestions?.first {
                        correctedWords.append(firstSuggestion)
                    } else {
                        correctedWords.append(word)
                    }
                } else {
                    correctedWords.append(word)
                }
            }
            
            correctedQuery = correctedWords.joined(separator: " ")
            
            // Cache the result
            if correctionCache.count < Configuration.cacheSize {
                correctionCache[query] = correctedQuery
            }
            
            continuation.resume(returning: correctedQuery)
        }
    }
}

// MARK: - Synonym Expansion

extension SearchRobustnessService {
    
    /// Expand query with synonyms using the comprehensive dictionary
    private func expandWithSynonyms(_ query: String, language: NLLanguage) async -> [String] {
        let synonymService = SynonymExpansionService()
        
        return await withCheckedContinuation { continuation in
            let expansions = synonymService.expandQuery(query, maxExpansions: 5)
            continuation.resume(returning: expansions)
        }
    }
}

// MARK: - Fuzzy Search

extension SearchRobustnessService {
    
    /// Perform fuzzy text matching using advanced algorithms
    private func performFuzzySearch(_ query: String, in screenshots: [Screenshot]) async -> [Screenshot] {
        let fuzzyService = FuzzyMatchingService(configuration: .default)
        
        return await withCheckedContinuation { continuation in
            let fuzzyResults = fuzzyService.fuzzySearch(query: query, in: screenshots)
            let screenshots = fuzzyResults.map { $0.screenshot }
            continuation.resume(returning: screenshots)
        }
    }
}

// MARK: - Semantic Search (iOS 17+)

extension SearchRobustnessService {
    
    /// Perform semantic similarity search using Apple's NLEmbedding
    @available(iOS 17.0, *)
    private func performSemanticSearch(_ query: String, in screenshots: [Screenshot]) async -> [Screenshot] {
        guard let embedding = embeddingModel else { return [] }
        
        return await withCheckedContinuation { continuation in
            // Check embedding cache first
            if let cachedEmbedding = embeddingCache[query] {
                let results = findSimilarScreenshots(queryEmbedding: cachedEmbedding, in: screenshots, using: embedding)
                continuation.resume(returning: results)
                return
            }
            
            // Generate embedding for query
            embedding.enumerateNeighbors(for: query, maximumCount: 10) { neighbor, distance in
                // This is a simplified approach - in a real implementation,
                // you would generate embeddings for screenshot content and compare
                return true
            }
            
            // For now, return empty array as this requires pre-computed embeddings
            continuation.resume(returning: [])
        }
    }
    
    @available(iOS 17.0, *)
    private func findSimilarScreenshots(queryEmbedding: [Double], in screenshots: [Screenshot], using embedding: NLEmbedding) -> [Screenshot] {
        // This would require pre-computed embeddings for all screenshot content
        // Implementation would compare cosine similarity between query and content embeddings
        return []
    }
}

// MARK: - Search Methods

extension SearchRobustnessService {
    
    /// Perform exact text search
    private func performExactSearch(_ query: String, in screenshots: [Screenshot]) -> [Screenshot] {
        return screenshots.filter { screenshot in
            // Check filename
            if screenshot.filename.localizedCaseInsensitiveContains(query) {
                return true
            }
            
            // Check extracted text
            if let extractedText = screenshot.extractedText,
               extractedText.localizedCaseInsensitiveContains(query) {
                return true
            }
            
            // Check user notes
            if let userNotes = screenshot.userNotes,
               userNotes.localizedCaseInsensitiveContains(query) {
                return true
            }
            
            // Check object tags
            if let objectTags = screenshot.objectTags {
                for tag in objectTags {
                    if tag.localizedCaseInsensitiveContains(query) {
                        return true
                    }
                }
            }
            
            return false
        }
    }
}

// MARK: - Smart Suggestions

extension SearchRobustnessService {
    
    /// Generate intelligent search suggestions based on content analysis
    private func generateSmartSuggestions(_ query: String, screenshots: [Screenshot]) async -> [String] {
        var suggestions: [String] = []
        
        // Analyze common terms in screenshot content
        let contentTerms = extractCommonTerms(from: screenshots)
        let fuzzyService = FuzzyMatchingService()
        
        // Find similar terms using fuzzy matching
        let fuzzyMatches = fuzzyService.findBestMatches(for: query, in: contentTerms, maxResults: 3)
        for match in fuzzyMatches {
            suggestions.append("Try searching for: \"\(match.string)\"")
        }
        
        // Add synonym suggestions
        let synonymService = SynonymExpansionService()
        let synonyms = synonymService.getSynonyms(for: query)
        for synonym in synonyms.prefix(2) {
            suggestions.append("Did you mean: \"\(synonym)\"?")
        }
        
        // Add spell correction suggestions if available
        if !correctionCache.isEmpty {
            let words = query.components(separatedBy: .whitespacesAndNewlines)
            for word in words {
                if let correction = correctionCache[word.lowercased()], correction != word {
                    suggestions.append("Check spelling: \"\(correction)\"")
                }
            }
        }
        
        return Array(suggestions.prefix(5))
    }
    
    private func extractCommonTerms(from screenshots: [Screenshot]) -> [String] {
        var termFrequency: [String: Int] = [:]
        
        for screenshot in screenshots {
            // Extract from filename
            let filenameWords = screenshot.filename.components(separatedBy: .whitespacesAndNewlines)
            for word in filenameWords {
                let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
                if cleanWord.count > 2 {
                    termFrequency[cleanWord, default: 0] += 1
                }
            }
            
            // Extract from OCR text
            if let extractedText = screenshot.extractedText {
                let words = extractedText.components(separatedBy: .whitespacesAndNewlines)
                for word in words {
                    let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
                    if cleanWord.count > 2 {
                        termFrequency[cleanWord, default: 0] += 1
                    }
                }
            }
        }
        
        // Return most frequent terms
        return termFrequency.sorted { $0.value > $1.value }
            .prefix(50)
            .map { $0.key }
    }
}

// MARK: - Supporting Data Structures

public struct EnhancedSearchResult {
    public let originalQuery: String
    public let enhancedQuery: String
    public let suggestions: [String]
    public let results: [Screenshot]
    public let metrics: SearchRobustnessService.PerformanceMetrics
}

// MARK: - Setup Methods

extension SearchRobustnessService {
    
    private func setupTokenizer() {
        // Configure tokenizer for optimal performance
        tokenizer.setLanguage(.english)
    }
    
    private func preloadCommonCorrections() {
        // Pre-populate cache with common typos and corrections
        let commonCorrections: [String: String] = [
            "receit": "receipt",
            "reciept": "receipt",
            "recipt": "receipt",
            "resturant": "restaurant",
            "restaraunt": "restaurant",
            "definately": "definitely",
            "seperately": "separately",
            "occured": "occurred",
            "begining": "beginning",
            "wiht": "with",
            "teh": "the",
            "adn": "and",
            "pone": "phone",
            "phoen": "phone",
            "balck": "black",
            "bleu": "blue",
            "grene": "green",
            "yello": "yellow",
            "purpel": "purple",
            "oragne": "orange",
            "whithe": "white",
            "graey": "gray"
        ]
        
        correctionCache = commonCorrections
    }
}