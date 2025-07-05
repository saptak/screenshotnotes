import Foundation
import NaturalLanguage

/// Service for extracting entities from natural language queries
/// Implements Named Entity Recognition using NLTagger and custom pattern matching
public class EntityExtractionService: ObservableObject, @unchecked Sendable {
    
    // MARK: - Private Properties
    
    private let nlTagger: NLTagger
    private let languageRecognizer: NLLanguageRecognizer
    private var cachedResults: [String: EntityExtractionResult] = [:]
    private let cacheQueue = DispatchQueue(label: "entity.extraction.cache", attributes: .concurrent)
    
    // MARK: - Configuration
    
    /// Maximum processing time before timeout (in seconds)
    private let maxProcessingTime: TimeInterval = 5.0
    
    /// Cache size limit
    private let maxCacheSize = 100
    
    /// Supported languages for entity extraction
    private let supportedLanguages: Set<NLLanguage> = [
        .english, .spanish, .french, .german, .italian, .portuguese,
        .russian, .simplifiedChinese, .japanese, .korean, .arabic
    ]
    
    // MARK: - Initialization
    
    public init() {
        // Configure NLTagger for named entity recognition
        self.nlTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        self.languageRecognizer = NLLanguageRecognizer()
        
        // Set language constraints
        self.languageRecognizer.languageConstraints = Array(supportedLanguages)
    }
    
    // MARK: - Public Methods
    
    /// Extract entities from the given text
    /// - Parameter text: The input text to analyze
    /// - Returns: EntityExtractionResult with all extracted entities
    public func extractEntities(from text: String) async -> EntityExtractionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Check cache first
        if let cachedResult = getCachedResult(for: text) {
            return cachedResult
        }
        
        // Prepare normalized text
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            return EntityExtractionResult(entities: [], processingTime: 0, confidence: .low)
        }
        
        // Detect language
        languageRecognizer.processString(normalizedText)
        let detectedLanguage = languageRecognizer.dominantLanguage ?? .english
        
        // Only proceed if language is supported
        guard supportedLanguages.contains(detectedLanguage) else {
            let result = EntityExtractionResult(entities: [], processingTime: 0, confidence: .low)
            cacheResult(result, for: text)
            return result
        }
        
        do {
            // Extract different types of entities concurrently
            async let namedEntities = extractNamedEntities(from: normalizedText, language: detectedLanguage)
            async let patternEntities = extractPatternBasedEntities(from: normalizedText, language: detectedLanguage)
            async let visualEntities = extractVisualEntities(from: normalizedText, language: detectedLanguage)
            async let temporalEntities = extractTemporalEntities(from: normalizedText, language: detectedLanguage)
            
            // Combine all entities
            let allEntities = try await [
                namedEntities,
                patternEntities,
                visualEntities,
                temporalEntities
            ].flatMap { $0 }
            
            // Remove duplicates and calculate overall confidence
            let uniqueEntities = removeDuplicateEntities(allEntities)
            let overallConfidence = calculateOverallConfidence(uniqueEntities)
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            
            let result = EntityExtractionResult(
                entities: uniqueEntities,
                processingTime: processingTime,
                confidence: overallConfidence
            )
            
            // Cache the result
            cacheResult(result, for: text)
            return result
            
        } catch {
            // Return empty result on error
            let result = EntityExtractionResult(entities: [], processingTime: CFAbsoluteTimeGetCurrent() - startTime, confidence: .low)
            return result
        }
    }
    
    // MARK: - Private Methods - Named Entity Extraction
    
    private func extractNamedEntities(from text: String, language: NLLanguage) async throws -> [ExtractedEntity] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var entities: [ExtractedEntity] = []
                
                self.nlTagger.string = text
                self.nlTagger.setLanguage(language, range: NSRange(location: 0, length: text.utf16.count))
                
                // Extract named entities
                self.nlTagger.enumerateTags(in: NSRange(location: 0, length: text.utf16.count),
                                          unit: .word,
                                          scheme: .nameType) { tag, range in
                    
                    guard let tag = tag else { return true }
                    
                    guard let swiftRange = Range(range, in: text) else { return true }
                    let entityText = String(text[swiftRange])
                    let entityType = self.mapNLTagToEntityType(tag)
                    let confidence = self.calculateNLTagConfidence(tag, text: entityText)
                    
                    let entity = ExtractedEntity(
                        type: entityType,
                        text: entityText,
                        normalizedValue: entityText.lowercased(),
                        confidence: confidence,
                        language: language,
                        range: NSRange(range, in: text)
                    )
                    
                    entities.append(entity)
                    return true
                }
                
                continuation.resume(returning: entities)
            }
        }
    }
    
    // MARK: - Private Methods - Pattern-Based Extraction
    
    private func extractPatternBasedEntities(from text: String, language: NLLanguage) async throws -> [ExtractedEntity] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var entities: [ExtractedEntity] = []
                
                // Phone numbers
                entities.append(contentsOf: self.extractWithPattern(
                    pattern: EntityPatterns.phoneNumberPattern,
                    type: .phoneNumber,
                    text: text,
                    language: language
                ))
                
                // Email addresses
                entities.append(contentsOf: self.extractWithPattern(
                    pattern: EntityPatterns.emailPattern,
                    type: .email,
                    text: text,
                    language: language
                ))
                
                // URLs
                entities.append(contentsOf: self.extractWithPattern(
                    pattern: EntityPatterns.urlPattern,
                    type: .url,
                    text: text,
                    language: language
                ))
                
                // Currency
                entities.append(contentsOf: self.extractWithPattern(
                    pattern: EntityPatterns.currencyPattern,
                    type: .currency,
                    text: text,
                    language: language
                ))
                
                // Numbers
                entities.append(contentsOf: self.extractWithPattern(
                    pattern: EntityPatterns.numberPattern,
                    type: .number,
                    text: text,
                    language: language
                ))
                
                // Dates
                entities.append(contentsOf: self.extractWithPattern(
                    pattern: EntityPatterns.datePattern,
                    type: .date,
                    text: text,
                    language: language
                ))
                
                continuation.resume(returning: entities)
            }
        }
    }
    
    // MARK: - Private Methods - Visual Entity Extraction
    
    private func extractVisualEntities(from text: String, language: NLLanguage) async throws -> [ExtractedEntity] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var entities: [ExtractedEntity] = []
                
                let lowercasedText = text.lowercased()
                let words = lowercasedText.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
                
                for word in words {
                    let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                    guard !cleanWord.isEmpty else { continue }
                    
                    // Colors
                    if EntityPatterns.colors.contains(cleanWord) {
                        if let range = self.findWordRange(cleanWord, in: text) {
                            if let swiftRange = Range(range, in: text) {
                                let entity = ExtractedEntity(
                                    type: .color,
                                    text: String(text[swiftRange]),
                                    normalizedValue: cleanWord,
                                    confidence: .high,
                                    language: language,
                                    range: range
                                )
                                entities.append(entity)
                            }
                        }
                    }
                    
                    // Objects
                    if EntityPatterns.objects.contains(cleanWord) {
                        if let range = self.findWordRange(cleanWord, in: text) {
                            if let swiftRange = Range(range, in: text) {
                                let entity = ExtractedEntity(
                                    type: .object,
                                    text: String(text[swiftRange]),
                                    normalizedValue: cleanWord,
                                    confidence: .high,
                                    language: language,
                                    range: range
                                )
                                entities.append(entity)
                            }
                        }
                    }
                    
                    // Document types
                    if EntityPatterns.documentTypes.contains(cleanWord) {
                        if let range = self.findWordRange(cleanWord, in: text) {
                            if let swiftRange = Range(range, in: text) {
                                let entity = ExtractedEntity(
                                    type: .documentType,
                                    text: String(text[swiftRange]),
                                    normalizedValue: cleanWord,
                                    confidence: .high,
                                    language: language,
                                    range: range
                                )
                                entities.append(entity)
                            }
                        }
                    }
                    
                    // Business types
                    if EntityPatterns.businessTypes.contains(cleanWord) {
                        if let range = self.findWordRange(cleanWord, in: text) {
                            if let swiftRange = Range(range, in: text) {
                                let entity = ExtractedEntity(
                                    type: .businessType,
                                    text: String(text[swiftRange]),
                                    normalizedValue: cleanWord,
                                    confidence: .high,
                                    language: language,
                                    range: range
                                )
                                entities.append(entity)
                            }
                        }
                    }
                }
                
                continuation.resume(returning: entities)
            }
        }
    }
    
    // MARK: - Private Methods - Temporal Entity Extraction
    
    private func extractTemporalEntities(from text: String, language: NLLanguage) async throws -> [ExtractedEntity] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var entities: [ExtractedEntity] = []
                
                let lowercasedText = text.lowercased()
                let words = lowercasedText.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
                
                for word in words {
                    let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                    guard !cleanWord.isEmpty else { continue }
                    
                    if EntityPatterns.temporalExpressions.contains(cleanWord) {
                        if let range = self.findWordRange(cleanWord, in: text) {
                            if let swiftRange = Range(range, in: text) {
                                let entityType: EntityType = self.classifyTemporalExpression(cleanWord)
                                let entity = ExtractedEntity(
                                    type: entityType,
                                    text: String(text[swiftRange]),
                                    normalizedValue: self.normalizeTemporalExpression(cleanWord),
                                    confidence: .high,
                                    language: language,
                                    range: range
                                )
                                entities.append(entity)
                            }
                        }
                    }
                }
                
                continuation.resume(returning: entities)
            }
        }
    }
    
    // MARK: - Private Methods - Pattern Extraction
    
    private func extractWithPattern(pattern: String, type: EntityType, text: String, language: NLLanguage) -> [ExtractedEntity] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        
        var entities: [ExtractedEntity] = []
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        for match in matches {
            let matchRange = match.range
            if let swiftRange = Range(matchRange, in: text) {
                let matchedText = String(text[swiftRange])
                let nsRange = NSRange(swiftRange, in: text)
                
                let entity = ExtractedEntity(
                    type: type,
                    text: matchedText,
                    normalizedValue: matchedText.lowercased(),
                    confidence: .high,
                    language: language,
                    range: nsRange
                )
                entities.append(entity)
            }
        }
        
        return entities
    }
    
    // MARK: - Private Methods - Helper Functions
    
    private func findWordRange(_ word: String, in text: String) -> NSRange? {
        let lowercasedText = text.lowercased()
        guard let range = lowercasedText.range(of: word.lowercased()) else {
            return nil
        }
        return NSRange(range, in: text)
    }
    
    private func mapNLTagToEntityType(_ tag: NLTag) -> EntityType {
        switch tag {
        case .personalName:
            return .person
        case .placeName:
            return .place
        case .organizationName:
            return .organization
        default:
            return .other
        }
    }
    
    private func calculateNLTagConfidence(_ tag: NLTag, text: String) -> EntityConfidence {
        // Simple confidence calculation based on tag type and text length
        switch tag {
        case .personalName, .placeName, .organizationName:
            return text.count >= 2 ? .high : .medium
        default:
            return .medium
        }
    }
    
    private func classifyTemporalExpression(_ expression: String) -> EntityType {
        let lowercased = expression.lowercased()
        
        if ["today", "yesterday", "tomorrow", "now"].contains(lowercased) {
            return .date
        } else if ["morning", "afternoon", "evening", "night"].contains(lowercased) {
            return .time
        } else if lowercased.contains("week") || lowercased.contains("month") || lowercased.contains("year") {
            return .date
        } else {
            return .time
        }
    }
    
    private func normalizeTemporalExpression(_ expression: String) -> String {
        let lowercased = expression.lowercased()
        
        switch lowercased {
        case "today":
            return "today"
        case "yesterday":
            return "yesterday"
        case "tomorrow":
            return "tomorrow"
        case "last week", "lastweek":
            return "last_week"
        case "last month", "lastmonth":
            return "last_month"
        case "last year", "lastyear":
            return "last_year"
        default:
            return lowercased
        }
    }
    
    private func removeDuplicateEntities(_ entities: [ExtractedEntity]) -> [ExtractedEntity] {
        var uniqueEntities: [ExtractedEntity] = []
        var seenRanges: Set<NSRange> = []
        
        for entity in entities {
            if let range = entity.range, !seenRanges.contains(range) {
                seenRanges.insert(range)
                uniqueEntities.append(entity)
            } else if entity.range == nil {
                uniqueEntities.append(entity)
            }
        }
        
        return uniqueEntities
    }
    
    private func calculateOverallConfidence(_ entities: [ExtractedEntity]) -> EntityConfidence {
        guard !entities.isEmpty else { return .low }
        
        let confidenceScores = entities.map { entity in
            switch entity.confidence {
            case .low: return 1.0
            case .medium: return 2.0
            case .high: return 3.0
            }
        }
        
        let averageScore = confidenceScores.reduce(0, +) / Double(confidenceScores.count)
        
        if averageScore >= 2.5 {
            return .high
        } else if averageScore >= 1.5 {
            return .medium
        } else {
            return .low
        }
    }
    
    // MARK: - Private Methods - Caching
    
    private func getCachedResult(for text: String) -> EntityExtractionResult? {
        return cacheQueue.sync {
            return cachedResults[text]
        }
    }
    
    private func cacheResult(_ result: EntityExtractionResult, for text: String) {
        cacheQueue.async(flags: .barrier) {
            // Remove oldest entries if cache is full
            if self.cachedResults.count >= self.maxCacheSize {
                let keysToRemove = Array(self.cachedResults.keys.prefix(self.cachedResults.count - self.maxCacheSize + 1))
                keysToRemove.forEach { self.cachedResults.removeValue(forKey: $0) }
            }
            
            self.cachedResults[text] = result
        }
    }
}

// MARK: - EntityExtractionService Extensions

extension EntityExtractionService {
    
    /// Get supported languages for entity extraction
    public func getSupportedLanguages() -> [NLLanguage] {
        return Array(supportedLanguages)
    }
    
    /// Check if a language is supported
    public func isLanguageSupported(_ language: NLLanguage) -> Bool {
        return supportedLanguages.contains(language)
    }
    
    /// Get cache statistics
    public func getCacheStatistics() -> (count: Int, maxSize: Int) {
        return cacheQueue.sync {
            return (count: cachedResults.count, maxSize: maxCacheSize)
        }
    }
}

// MARK: - EntityPatterns

private struct EntityPatterns {
    
    // Regex patterns for common entities
    static let phoneNumberPattern = #"(\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#
    static let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
    static let urlPattern = #"https?://[^\s]+"#
    static let currencyPattern = #"[$€£¥]\s*\d+(?:[,.]\d{1,2})?"#
    static let numberPattern = #"\b\d+(?:[,.]\d+)?\b"#
    static let datePattern = #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#
    
    // Common colors
    static let colors: Set<String> = [
        "red", "blue", "green", "yellow", "orange", "purple", "pink", "brown",
        "black", "white", "gray", "grey", "silver", "gold", "navy", "maroon",
        "cyan", "magenta", "lime", "olive", "teal", "aqua", "crimson", "indigo"
    ]
    
    // Common objects
    static let objects: Set<String> = [
        "dress", "shirt", "pants", "shoes", "bag", "phone", "laptop", "car",
        "house", "book", "pen", "paper", "table", "chair", "computer", "camera",
        "watch", "glasses", "hat", "jacket", "sweater", "jeans", "sneakers"
    ]
    
    // Document types
    static let documentTypes: Set<String> = [
        "receipt", "invoice", "ticket", "passport", "license", "certificate",
        "contract", "report", "memo", "email", "letter", "form", "application",
        "bill", "statement", "voucher", "coupon", "screenshot", "photo"
    ]
    
    // Business types
    static let businessTypes: Set<String> = [
        "restaurant", "hotel", "store", "shop", "bank", "hospital", "school",
        "office", "mall", "market", "cafe", "bar", "gym", "salon", "garage",
        "pharmacy", "library", "museum", "theater", "stadium"
    ]
    
    // Temporal expressions
    static let temporalExpressions: Set<String> = [
        "today", "yesterday", "tomorrow", "now", "later", "soon", "recently",
        "morning", "afternoon", "evening", "night", "week", "month", "year",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "may", "june", "july",
        "august", "september", "october", "november", "december"
    ]
}
