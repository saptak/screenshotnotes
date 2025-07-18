import Foundation
import NaturalLanguage

/// Represents different types of entities that can be extracted from queries
public enum EntityType: String, CaseIterable, Codable {
    // Standard Named Entities (NLTagger)
    case person = "person"
    case place = "place"
    case organization = "organization"
    
    // Visual Attributes
    case color = "color"
    case object = "object"
    case shape = "shape"
    case size = "size"
    case texture = "texture"
    
    // Temporal Entities
    case date = "date"
    case time = "time"
    case duration = "duration"
    case frequency = "frequency"
    
    // Structured Data
    case phoneNumber = "phoneNumber"
    case email = "email"
    case url = "url"
    case currency = "currency"
    case number = "number"
    
    // Document Types
    case documentType = "documentType"
    case businessType = "businessType"
    
    // Miscellaneous
    case unknown = "unknown"
    
    /// Human-readable description of the entity type
    public var description: String {
        switch self {
        case .person:
            return "Person or name"
        case .place:
            return "Location or place"
        case .organization:
            return "Organization or company"
        case .color:
            return "Color description"
        case .object:
            return "Physical object or item"
        case .shape:
            return "Shape or form"
        case .size:
            return "Size description"
        case .texture:
            return "Texture or material"
        case .date:
            return "Date reference"
        case .time:
            return "Time reference"
        case .duration:
            return "Duration or time span"
        case .frequency:
            return "Frequency or repetition"
        case .phoneNumber:
            return "Phone number"
        case .email:
            return "Email address"
        case .url:
            return "Website URL"
        case .currency:
            return "Currency or money amount"
        case .number:
            return "Numeric value"
        case .documentType:
            return "Document category"
        case .businessType:
            return "Business category"
        case .unknown:
            return "Unknown entity type"
        }
    }
    
    /// Weight for relevance scoring (higher is more important)
    public var weight: Double {
        switch self {
        case .object, .documentType:
            return 1.0
        case .color, .person, .organization:
            return 0.9
        case .date, .time, .place:
            return 0.8
        case .phoneNumber, .email, .url:
            return 0.7
        case .businessType, .currency:
            return 0.6
        case .size, .shape, .texture:
            return 0.5
        case .duration, .frequency, .number:
            return 0.4
        case .unknown:
            return 0.1
        }
    }
    
    /// Whether this entity type suggests visual search
    public var isVisual: Bool {
        switch self {
        case .color, .object, .shape, .size, .texture:
            return true
        default:
            return false
        }
    }
    
    /// Whether this entity type suggests temporal search
    public var isTemporal: Bool {
        switch self {
        case .date, .time, .duration, .frequency:
            return true
        default:
            return false
        }
    }
}

/// Confidence level for entity extraction
public enum EntityConfidence: Double, CaseIterable, Codable {
    case veryHigh = 0.95
    case high = 0.85
    case medium = 0.70
    case low = 0.55
    case veryLow = 0.30
    
    public var description: String {
        switch self {
        case .veryHigh:
            return "Very high confidence"
        case .high:
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence"
        case .veryLow:
            return "Very low confidence"
        }
    }
    
    /// Whether this confidence level is actionable for search
    public var isActionable: Bool {
        return self.rawValue >= EntityConfidence.medium.rawValue
    }
}

/// Represents an extracted entity from a natural language query
public struct ExtractedEntity: Codable {
    
    // MARK: - Core Properties
    
    /// The entity type classification
    public let type: EntityType
    
    /// Original text that was identified as this entity
    public let text: String
    
    /// Normalized/standardized form of the entity
    public let normalizedValue: String
    
    /// Confidence level of the extraction
    public let confidence: EntityConfidence
    
    /// Language of the original text
    public let language: NLLanguage
    
    /// Range in the original query where this entity was found
    public let range: NSRange
    
    /// Processing timestamp
    public let timestamp: Date
    
    // MARK: - Context Properties
    
    /// Additional context information about the entity
    public let context: [String: Any]
    
    /// Alternative interpretations of this entity
    public let alternatives: [EntityAlternative]
    
    /// Whether this entity was extracted using ML models vs pattern matching
    public let isMLDerived: Bool
    
    // MARK: - Initialization
    
    public init(
        type: EntityType,
        text: String,
        normalizedValue: String,
        confidence: EntityConfidence,
        language: NLLanguage = .undetermined,
        range: NSRange,
        context: [String: Any] = [:],
        alternatives: [EntityAlternative] = [],
        isMLDerived: Bool = false,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.text = text
        self.normalizedValue = normalizedValue
        self.confidence = confidence
        self.language = language
        self.range = range
        self.context = context
        self.alternatives = alternatives
        self.isMLDerived = isMLDerived
        self.timestamp = timestamp
    }
    
    // MARK: - Computed Properties
    
    /// Relevance score for ranking (0.0 - 1.0)
    public var relevanceScore: Double {
        let typeWeight = type.weight
        let confidenceWeight = confidence.rawValue
        let mlBonus = isMLDerived ? 0.1 : 0.0
        
        return min(1.0, (typeWeight * 0.6) + (confidenceWeight * 0.3) + mlBonus)
    }
    
    /// Whether this entity is suitable for visual search operations
    public var isVisualEntity: Bool {
        return type.isVisual && confidence.isActionable
    }
    
    /// Whether this entity is suitable for temporal search operations
    public var isTemporalEntity: Bool {
        return type.isTemporal && confidence.isActionable
    }
    
    /// Debug description for development
    public var debugDescription: String {
        return """
        ExtractedEntity:
        - Type: \(type.rawValue) (\(type.description))
        - Text: "\(text)"
        - Normalized: "\(normalizedValue)"
        - Confidence: \(confidence.rawValue) (\(confidence.description))
        - Language: \(language.rawValue)
        - Range: \(NSStringFromRange(range))
        - Relevance: \(String(format: "%.2f", relevanceScore))
        - Visual: \(isVisualEntity)
        - Temporal: \(isTemporalEntity)
        - ML Derived: \(isMLDerived)
        - Alternatives: \(alternatives.count)
        """
    }
}

// MARK: - ExtractedEntity Codable Implementation

extension ExtractedEntity {
    private enum CodingKeys: String, CodingKey {
        case type, text, normalizedValue, confidence, language, range, timestamp
        case alternatives, isMLDerived
    }
    
    private struct RangeData: Codable {
        let location: Int
        let length: Int
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(text, forKey: .text)
        try container.encode(normalizedValue, forKey: .normalizedValue)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(language.rawValue, forKey: .language)
        try container.encode(RangeData(location: range.location, length: range.length), forKey: .range)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(alternatives, forKey: .alternatives)
        try container.encode(isMLDerived, forKey: .isMLDerived)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(EntityType.self, forKey: .type)
        text = try container.decode(String.self, forKey: .text)
        normalizedValue = try container.decode(String.self, forKey: .normalizedValue)
        confidence = try container.decode(EntityConfidence.self, forKey: .confidence)
        let languageRawValue = try container.decode(String.self, forKey: .language)
        language = NLLanguage(rawValue: languageRawValue)
        let rangeData = try container.decode(RangeData.self, forKey: .range)
        range = NSRange(location: rangeData.location, length: rangeData.length)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        // Skip context as it contains Any type
        context = [:]
        alternatives = try container.decode([EntityAlternative].self, forKey: .alternatives)
        isMLDerived = try container.decode(Bool.self, forKey: .isMLDerived)
    }
}

/// Alternative interpretation of an extracted entity
public struct EntityAlternative: Codable {
    public let type: EntityType
    public let normalizedValue: String
    public let confidence: EntityConfidence
    
    public init(type: EntityType, normalizedValue: String, confidence: EntityConfidence) {
        self.type = type
        self.normalizedValue = normalizedValue
        self.confidence = confidence
    }
}

// MARK: - ExtractedEntity Extensions

extension ExtractedEntity: Equatable {
    public static func == (lhs: ExtractedEntity, rhs: ExtractedEntity) -> Bool {
        return lhs.type == rhs.type &&
               lhs.normalizedValue == rhs.normalizedValue &&
               lhs.range.location == rhs.range.location &&
               lhs.range.length == rhs.range.length
    }
}

extension ExtractedEntity: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(normalizedValue)
        hasher.combine(range.location)
        hasher.combine(range.length)
    }
}

// MARK: - Entity Extraction Result

/// Container for entity extraction results
public struct EntityExtractionResult {
    
    /// All extracted entities
    public let entities: [ExtractedEntity]
    
    /// Original query text
    public let originalText: String
    
    /// Processing time in milliseconds
    public let processingTimeMs: Double
    
    /// Language detection result
    public let detectedLanguage: NLLanguage
    
    /// Overall extraction confidence
    public let overallConfidence: EntityConfidence
    
    /// Whether the extraction was successful
    public let isSuccessful: Bool
    
    /// Any errors encountered during extraction
    public let errors: [EntityExtractionError]
    
    public init(
        entities: [ExtractedEntity],
        originalText: String,
        processingTimeMs: Double,
        detectedLanguage: NLLanguage,
        overallConfidence: EntityConfidence,
        isSuccessful: Bool,
        errors: [EntityExtractionError] = []
    ) {
        self.entities = entities
        self.originalText = originalText
        self.processingTimeMs = processingTimeMs
        self.detectedLanguage = detectedLanguage
        self.overallConfidence = overallConfidence
        self.isSuccessful = isSuccessful
        self.errors = errors
    }
    
    // MARK: - Computed Properties
    
    /// Entities filtered by actionable confidence level
    public var actionableEntities: [ExtractedEntity] {
        return entities.filter { $0.confidence.isActionable }
    }
    
    /// Visual entities suitable for visual search
    public var visualEntities: [ExtractedEntity] {
        return entities.filter { $0.isVisualEntity }
    }
    
    /// Temporal entities suitable for temporal search
    public var temporalEntities: [ExtractedEntity] {
        return entities.filter { $0.isTemporalEntity }
    }
    
    /// Entities grouped by type
    public var entitiesByType: [EntityType: [ExtractedEntity]] {
        return Dictionary(grouping: entities) { $0.type }
    }
    
    /// High-confidence entities (confidence >= 0.7)
    public var highConfidenceEntities: [ExtractedEntity] {
        return entities.filter { $0.confidence.rawValue >= 0.7 }
    }
    
    /// Debug description for development
    public var debugDescription: String {
        let entitiesDesc = entities.map { "  - \($0.type.rawValue): \"\($0.text)\" (\($0.confidence.rawValue))" }
            .joined(separator: "\n")
        
        return """
        EntityExtractionResult:
        - Original: "\(originalText)"
        - Language: \(detectedLanguage.rawValue)
        - Entities: \(entities.count) total, \(actionableEntities.count) actionable
        - Processing: \(String(format: "%.1f", processingTimeMs))ms
        - Overall Confidence: \(overallConfidence.rawValue)
        - Successful: \(isSuccessful)
        - Errors: \(errors.count)
        
        Entities:
        \(entitiesDesc.isEmpty ? "(none)" : entitiesDesc)
        """
    }
}

// MARK: - Entity Extraction Error

/// Errors that can occur during entity extraction
public enum EntityExtractionError: Error, LocalizedError {
    case invalidInput(String)
    case languageNotSupported(NLLanguage)
    case nlTaggerFailed(String)
    case regexPatternFailed(String)
    case processingTimeout
    case insufficientMemory
    case modelNotAvailable(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let details):
            return "Invalid input: \(details)"
        case .languageNotSupported(let language):
            return "Language not supported: \(language.rawValue)"
        case .nlTaggerFailed(let details):
            return "NLTagger processing failed: \(details)"
        case .regexPatternFailed(let details):
            return "Regex pattern matching failed: \(details)"
        case .processingTimeout:
            return "Entity extraction processing timeout"
        case .insufficientMemory:
            return "Insufficient memory for entity extraction"
        case .modelNotAvailable(let modelName):
            return "Required model not available: \(modelName)"
        }
    }
}

// MARK: - Entity Pattern Definitions

/// Predefined patterns for entity extraction
public struct EntityPatterns {
    
    // MARK: - Color Patterns
    
    /// Common color names and variations
    public static let colors: Set<String> = [
        // Basic colors
        "red", "blue", "green", "yellow", "orange", "purple", "pink", "brown",
        "black", "white", "gray", "grey", "silver", "gold",
        
        // Extended colors
        "navy", "teal", "cyan", "magenta", "violet", "indigo", "turquoise",
        "maroon", "olive", "lime", "aqua", "beige", "tan", "khaki",
        "salmon", "coral", "crimson", "scarlet", "emerald", "jade",
        
        // Shades and tints
        "light", "dark", "bright", "pale", "deep", "rich", "vivid",
        "pastel", "neon", "metallic", "matte", "glossy"
    ]
    
    // MARK: - Object Patterns
    
    /// Common objects found in screenshots
    public static let objects: Set<String> = [
        // Clothing
        "dress", "shirt", "pants", "shoes", "jacket", "coat", "hat", "bag",
        "watch", "glasses", "belt", "scarf", "gloves", "socks",
        
        // Documents
        "receipt", "invoice", "ticket", "menu", "flyer", "poster", "sign",
        "document", "paper", "form", "certificate", "license", "card",
        
        // Technology
        "phone", "laptop", "computer", "tablet", "screen", "monitor",
        "keyboard", "mouse", "headphones", "camera", "tv", "remote",
        
        // Food & Dining
        "food", "pizza", "burger", "coffee", "drink", "wine", "beer",
        "restaurant", "menu", "plate", "cup", "glass", "bottle",
        
        // Transportation
        "car", "bus", "train", "plane", "taxi", "uber", "lyft",
        "parking", "ticket", "boarding", "pass",
        
        // Home & Furniture
        "table", "chair", "bed", "sofa", "lamp", "window", "door",
        "room", "kitchen", "bathroom", "bedroom", "living"
    ]
    
    // MARK: - Document Types
    
    /// Document type classifications
    public static let documentTypes: Set<String> = [
        "receipt", "invoice", "bill", "statement", "report", "contract",
        "agreement", "ticket", "voucher", "coupon", "menu", "flyer",
        "poster", "advertisement", "brochure", "manual", "guide",
        "certificate", "diploma", "license", "permit", "form",
        "application", "reservation", "confirmation", "itinerary"
    ]
    
    // MARK: - Business Types
    
    /// Business and organization types
    public static let businessTypes: Set<String> = [
        "restaurant", "hotel", "store", "shop", "market", "pharmacy",
        "hospital", "clinic", "bank", "office", "school", "university",
        "gym", "spa", "salon", "theater", "museum", "library",
        "airport", "station", "mall", "center", "park", "beach"
    ]
    
    // MARK: - Temporal Expressions
    
    /// Temporal reference patterns
    public static let temporalExpressions: Set<String> = [
        // Relative dates
        "today", "yesterday", "tomorrow", "now", "current", "recent",
        "latest", "last", "previous", "next", "upcoming", "past",
        
        // Time periods
        "morning", "afternoon", "evening", "night", "midnight", "noon",
        "dawn", "dusk", "early", "late",
        
        // Days of week
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "weekday", "weekend", "week",
        
        // Months
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
        "month", "year",
        
        // Frequencies
        "daily", "weekly", "monthly", "yearly", "annually", "regularly",
        "often", "sometimes", "rarely", "never", "always"
    ]
    
    // MARK: - Regex Patterns
    
    /// Phone number pattern (US format)
    public static let phoneNumberPattern = #"(?:\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})"#
    
    /// Email pattern
    public static let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
    
    /// URL pattern
    public static let urlPattern = #"https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9.-]+\.(com|org|net|edu|gov)"#
    
    /// Currency pattern
    public static let currencyPattern = #"[$£€¥₹₽¢]\s*[\d,]+\.?\d*|\d+\.?\d*\s*(USD|EUR|GBP|JPY|INR|RUB|dollars?|euros?|pounds?|yen|rupees?|rubles?)"#
    
    /// Number pattern
    public static let numberPattern = #"\b\d+(?:\.\d+)?\b"#
    
    /// Date pattern (various formats)
    public static let datePattern = #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4}|\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4}\b"#
}
