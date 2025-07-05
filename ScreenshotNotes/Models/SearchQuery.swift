import Foundation
import NaturalLanguage

/// Represents the intent of a search query
public enum SearchIntent: String, CaseIterable {
    case search = "search"
    case filter = "filter"
    case find = "find"
    case show = "show"
    case get = "get"
    case lookup = "lookup"
    case unknown = "unknown"
    
    /// Human-readable description of the intent
    public var description: String {
        switch self {
        case .search:
            return "General search across all content"
        case .filter:
            return "Filter existing results by criteria"
        case .find:
            return "Find specific items with attributes"
        case .show:
            return "Display content matching criteria"
        case .get:
            return "Retrieve specific items"
        case .lookup:
            return "Look up information in screenshots"
        case .unknown:
            return "Unclear intent"
        }
    }
    
    /// Confidence weight for intent scoring
    public var weight: Double {
        switch self {
        case .find, .search:
            return 1.0
        case .show, .get:
            return 0.9
        case .filter, .lookup:
            return 0.8
        case .unknown:
            return 0.1
        }
    }
}

/// Represents query confidence levels
public enum QueryConfidence: Double, CaseIterable {
    case high = 0.8
    case medium = 0.6
    case low = 0.4
    case veryLow = 0.2
    
    public var description: String {
        switch self {
        case .high:
            return "High confidence in query understanding"
        case .medium:
            return "Medium confidence in query understanding"
        case .low:
            return "Low confidence in query understanding"
        case .veryLow:
            return "Very low confidence in query understanding"
        }
    }
}

/// Structured representation of a natural language search query
public struct SearchQuery {
    
    // MARK: - Core Properties
    
    /// Original raw query text
    public let rawQuery: String
    
    /// Processed and normalized query text
    public let normalizedQuery: String
    
    /// Detected intent of the query
    public let intent: SearchIntent
    
    /// Confidence level in the query parsing
    public let confidence: QueryConfidence
    
    /// Detected language of the query
    public let language: NLLanguage
    
    /// Processing timestamp
    public let timestamp: Date
    
    // MARK: - Parsed Components
    
    /// Key terms extracted from the query
    public let searchTerms: [String]
    
    /// Stop words that were filtered out
    public let filteredStopWords: [String]
    
    /// Preprocessed tokens for analysis
    public let tokens: [String]
    
    // MARK: - Query Metadata
    
    /// Whether the query contains temporal references
    public let hasTemporalContext: Bool
    
    /// Whether the query contains visual attribute references
    public let hasVisualAttributes: Bool
    
    /// Whether the query suggests exact matching
    public let requiresExactMatch: Bool
    
    /// Processing performance metrics
    public let processingTimeMs: Double
    
    // MARK: - Entity Extraction
    
    /// Extracted entities from the query
    public let extractedEntities: [ExtractedEntity]
    
    /// Complete entity extraction result
    public let entityExtractionResult: EntityExtractionResult?
    
    // MARK: - Initialization
    
    public init(
        rawQuery: String,
        normalizedQuery: String,
        intent: SearchIntent,
        confidence: QueryConfidence,
        language: NLLanguage,
        searchTerms: [String],
        filteredStopWords: [String] = [],
        tokens: [String] = [],
        extractedEntities: [ExtractedEntity] = [],
        entityExtractionResult: EntityExtractionResult? = nil,
        hasTemporalContext: Bool = false,
        hasVisualAttributes: Bool = false,
        requiresExactMatch: Bool = false,
        processingTimeMs: Double = 0,
        timestamp: Date = Date()
    ) {
        self.rawQuery = rawQuery
        self.normalizedQuery = normalizedQuery
        self.intent = intent
        self.confidence = confidence
        self.language = language
        self.searchTerms = searchTerms
        self.filteredStopWords = filteredStopWords
        self.tokens = tokens
        self.extractedEntities = extractedEntities
        self.entityExtractionResult = entityExtractionResult
        self.hasTemporalContext = hasTemporalContext
        self.hasVisualAttributes = hasVisualAttributes
        self.requiresExactMatch = requiresExactMatch
        self.processingTimeMs = processingTimeMs
        self.timestamp = timestamp
    }
    
    // MARK: - Computed Properties
    
    /// Whether this is a high-quality, actionable query
    public var isActionable: Bool {
        // For temporal or visual queries, we can be more lenient with confidence
        if hasTemporalContext || hasVisualAttributes {
            return confidence.rawValue >= QueryConfidence.low.rawValue && 
                   intent != .unknown && 
                   !searchTerms.isEmpty
        }
        
        // For general queries, maintain higher standards
        return confidence.rawValue >= QueryConfidence.medium.rawValue && 
               intent != .unknown && 
               !searchTerms.isEmpty
    }
    
    /// Relevance score for ranking purposes (0.0 - 1.0)
    public var relevanceScore: Double {
        let intentWeight = intent.weight
        let confidenceWeight = confidence.rawValue
        let termWeight = searchTerms.isEmpty ? 0.1 : min(1.0, Double(searchTerms.count) / 5.0)
        
        return (intentWeight * 0.4) + (confidenceWeight * 0.4) + (termWeight * 0.2)
    }
    
    // MARK: - Entity-Based Computed Properties
    
    /// Entities filtered by color type
    public var colorEntities: [ExtractedEntity] {
        return extractedEntities.filter { $0.type == .color }
    }
    
    /// Entities filtered by object type
    public var objectEntities: [ExtractedEntity] {
        return extractedEntities.filter { $0.type == .object }
    }
    
    /// Entities filtered by document type
    public var documentTypeEntities: [ExtractedEntity] {
        return extractedEntities.filter { $0.type == .documentType }
    }
    
    /// High-confidence entities suitable for filtering
    public var actionableEntities: [ExtractedEntity] {
        return extractedEntities.filter { $0.confidence.rawValue >= EntityConfidence.medium.rawValue }
    }
    
    /// Whether the query contains temporal entities
    public var hasTemporalEntities: Bool {
        return extractedEntities.contains { entity in
            [.date, .time, .duration, .frequency].contains(entity.type)
        }
    }
    
    /// Whether the query contains visual entities (colors, objects, shapes, etc.)
    public var hasVisualEntities: Bool {
        return extractedEntities.contains { entity in
            [.color, .object, .shape, .size, .texture].contains(entity.type)
        }
    }
    
    /// Whether the query has rich entity data for enhanced search
    public var hasRichEntityData: Bool {
        return actionableEntities.count >= 2 || hasVisualEntities || hasTemporalEntities
    }
    
    /// Debug description for development
    public var debugDescription: String {
        return """
        SearchQuery Debug:
        - Raw: "\(rawQuery)"
        - Normalized: "\(normalizedQuery)"
        - Intent: \(intent.rawValue) (confidence: \(confidence.rawValue))
        - Language: \(language.rawValue)
        - Terms: \(searchTerms)
        - Temporal: \(hasTemporalContext)
        - Visual: \(hasVisualAttributes)
        - Exact: \(requiresExactMatch)
        - Actionable: \(isActionable)
        - Relevance: \(String(format: "%.2f", relevanceScore))
        - Processing: \(String(format: "%.1f", processingTimeMs))ms
        """
    }
}

// MARK: - SearchQuery Extensions

extension SearchQuery: Equatable {
    public static func == (lhs: SearchQuery, rhs: SearchQuery) -> Bool {
        return lhs.normalizedQuery == rhs.normalizedQuery &&
               lhs.intent == rhs.intent &&
               lhs.searchTerms == rhs.searchTerms
    }
}

extension SearchQuery: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(normalizedQuery)
        hasher.combine(intent)
        hasher.combine(searchTerms)
    }
}

// MARK: - Search Query Builder

/// Builder pattern for constructing SearchQuery instances
public class SearchQueryBuilder {
    private var rawQuery: String = ""
    private var normalizedQuery: String = ""
    private var intent: SearchIntent = .unknown
    private var confidence: QueryConfidence = .veryLow
    private var language: NLLanguage = .undetermined
    private var searchTerms: [String] = []
    private var filteredStopWords: [String] = []
    private var tokens: [String] = []
    private var hasTemporalContext: Bool = false
    private var hasVisualAttributes: Bool = false
    private var requiresExactMatch: Bool = false
    private var processingTimeMs: Double = 0
    
    public init() {}
    
    public func setRawQuery(_ query: String) -> SearchQueryBuilder {
        self.rawQuery = query
        return self
    }
    
    public func setNormalizedQuery(_ query: String) -> SearchQueryBuilder {
        self.normalizedQuery = query
        return self
    }
    
    public func setIntent(_ intent: SearchIntent) -> SearchQueryBuilder {
        self.intent = intent
        return self
    }
    
    public func setConfidence(_ confidence: QueryConfidence) -> SearchQueryBuilder {
        self.confidence = confidence
        return self
    }
    
    public func setLanguage(_ language: NLLanguage) -> SearchQueryBuilder {
        self.language = language
        return self
    }
    
    public func setSearchTerms(_ terms: [String]) -> SearchQueryBuilder {
        self.searchTerms = terms
        return self
    }
    
    public func setFilteredStopWords(_ words: [String]) -> SearchQueryBuilder {
        self.filteredStopWords = words
        return self
    }
    
    public func setTokens(_ tokens: [String]) -> SearchQueryBuilder {
        self.tokens = tokens
        return self
    }
    
    public func setTemporalContext(_ hasContext: Bool) -> SearchQueryBuilder {
        self.hasTemporalContext = hasContext
        return self
    }
    
    public func setVisualAttributes(_ hasAttributes: Bool) -> SearchQueryBuilder {
        self.hasVisualAttributes = hasAttributes
        return self
    }
    
    public func setExactMatch(_ requiresExact: Bool) -> SearchQueryBuilder {
        self.requiresExactMatch = requiresExact
        return self
    }
    
    public func setProcessingTime(_ timeMs: Double) -> SearchQueryBuilder {
        self.processingTimeMs = timeMs
        return self
    }
    
    public func build() -> SearchQuery {
        return SearchQuery(
            rawQuery: rawQuery,
            normalizedQuery: normalizedQuery,
            intent: intent,
            confidence: confidence,
            language: language,
            searchTerms: searchTerms,
            filteredStopWords: filteredStopWords,
            tokens: tokens,
            hasTemporalContext: hasTemporalContext,
            hasVisualAttributes: hasVisualAttributes,
            requiresExactMatch: requiresExactMatch,
            processingTimeMs: processingTimeMs
        )
    }
}
