import Foundation
import NaturalLanguage

/// Service for extracting entities from natural language queries
/// Implements Named Entity Recognition using NLTagger and custom pattern matching
@MainActor
public class EntityExtractionService: ObservableObject {
    
    // MARK: - Private Properties
    
    private let nlTagger: NLTagger
    private let languageRecognizer: NLLanguageRecognizer
    private var cachedResults: [String: EntityExtractionResult] = [:]
    
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
            return EntityExtractionResult(
                entities: [],
                originalText: text,
                processingTimeMs: 0,
                detectedLanguage: .english,
                overallConfidence: .low,
                isSuccessful: false
            )
        }
        
        // Detect language
        languageRecognizer.processString(normalizedText)
        let detectedLanguage = languageRecognizer.dominantLanguage ?? .english
        
        // Only proceed if language is supported
        guard supportedLanguages.contains(detectedLanguage) else {
            let result = EntityExtractionResult(
                entities: [],
                originalText: text,
                processingTimeMs: 0,
                detectedLanguage: detectedLanguage,
                overallConfidence: .low,
                isSuccessful: false
            )
            cacheResult(result, for: text)
            return result
        }
        
        do {
            // Extract different types of entities sequentially (since we're on MainActor)
            let namedEntities = try extractNamedEntities(from: normalizedText, language: detectedLanguage)
            let patternEntities = try extractPatternBasedEntities(from: normalizedText, language: detectedLanguage)
            let visualEntities = try extractVisualEntities(from: normalizedText, language: detectedLanguage)
            let temporalEntities = try extractTemporalEntities(from: normalizedText, language: detectedLanguage)
            
            // Combine all entities
            let allEntities = [
                namedEntities,
                patternEntities,
                visualEntities,
                temporalEntities
            ].flatMap { $0 }
            
            // Remove duplicates and calculate overall confidence
            let uniqueEntities = removeDuplicateEntities(allEntities)
            let overallConfidence = calculateOverallConfidence(uniqueEntities)
            
            let result = EntityExtractionResult(
                entities: uniqueEntities,
                originalText: text,
                processingTimeMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000,
                detectedLanguage: detectedLanguage,
                overallConfidence: overallConfidence,
                isSuccessful: true
            )
            
            cacheResult(result, for: text)
            return result
            
        } catch {
            let result = EntityExtractionResult(
                entities: [],
                originalText: text,
                processingTimeMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000,
                detectedLanguage: detectedLanguage,
                overallConfidence: .low,
                isSuccessful: false
            )
            return result
        }
    }
    
    // MARK: - Private Methods - Named Entity Extraction
    
    private func extractNamedEntities(from text: String, language: NLLanguage) throws -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        
        nlTagger.string = text
        if let stringRange = Range(NSRange(location: 0, length: text.utf16.count), in: text) {
            nlTagger.setLanguage(language, range: stringRange)
        }
        
        // Extract named entities
        let fullRange = text.startIndex..<text.endIndex
        nlTagger.enumerateTags(in: fullRange,
                              unit: .word,
                              scheme: .nameType) { tag, range in
            
            guard let tag = tag else { return true }
            
            let swiftRange = range
            let entityText = String(text[swiftRange])
            let entityType = mapNLTagToEntityType(tag)
            let confidence = calculateNLTagConfidence(tag, text: entityText)
            
            let entity = ExtractedEntity(
                type: entityType,
                text: entityText,
                normalizedValue: entityText.lowercased(),
                confidence: confidence,
                language: language,
                range: NSRange(swiftRange, in: text)
            )
            
            entities.append(entity)
            return true
        }
        
        return entities
    }
    
    // MARK: - Private Methods - Pattern-Based Extraction
    
    private func extractPatternBasedEntities(from text: String, language: NLLanguage) throws -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        
        // Phone numbers
        entities.append(contentsOf: extractWithPattern(
            pattern: EntityPatterns.phoneNumberPattern,
            type: .phoneNumber,
            text: text,
            language: language
        ))
        
        // Email addresses
        entities.append(contentsOf: extractWithPattern(
            pattern: EntityPatterns.emailPattern,
            type: .email,
            text: text,
            language: language
        ))
        
        // URLs
        entities.append(contentsOf: extractWithPattern(
            pattern: EntityPatterns.urlPattern,
            type: .url,
            text: text,
            language: language
        ))
        
        // Currency
        entities.append(contentsOf: extractWithPattern(
            pattern: EntityPatterns.currencyPattern,
            type: .currency,
            text: text,
            language: language
        ))
        
        // Numbers
        entities.append(contentsOf: extractWithPattern(
            pattern: EntityPatterns.numberPattern,
            type: .number,
            text: text,
            language: language
        ))
        
        // Dates
        entities.append(contentsOf: extractWithPattern(
            pattern: EntityPatterns.datePattern,
            type: .date,
            text: text,
            language: language
        ))
        
        return entities
    }
    
    // MARK: - Private Methods - Visual Entity Extraction
    
    private func extractVisualEntities(from text: String, language: NLLanguage) throws -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        
        let lowercasedText = text.lowercased()
        let words = lowercasedText.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
        
        for word in words {
            guard !word.isEmpty else { continue }
            
            if let colorEntity = extractColorEntity(from: word, text: text, language: language) {
                entities.append(colorEntity)
            }
        }
        
        return entities
    }
    
    // MARK: - Private Methods - Temporal Entity Extraction
    
    private func extractTemporalEntities(from text: String, language: NLLanguage) throws -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        
        let lowercasedText = text.lowercased()
        let words = lowercasedText.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
        
        for word in words {
            guard !word.isEmpty else { continue }
            
            if let temporalEntity = extractTemporalEntity(from: word, text: text, language: language) {
                entities.append(temporalEntity)
            }
        }
        
        return entities
    }
    
    // MARK: - Helper Methods
    
    private func extractWithPattern(pattern: String, type: EntityType, text: String, language: NLLanguage) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            
            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }
                
                let entityText = String(text[range])
                let confidence = calculatePatternConfidence(type)
                
                let entity = ExtractedEntity(
                    type: type,
                    text: entityText,
                    normalizedValue: entityText.lowercased(),
                    confidence: confidence,
                    language: language,
                    range: match.range
                )
                
                entities.append(entity)
            }
        } catch {
            // Handle regex error silently
        }
        
        return entities
    }
    
    private func extractColorEntity(from word: String, text: String, language: NLLanguage) -> ExtractedEntity? {
        let colorKeywords = ["red", "blue", "green", "yellow", "purple", "orange", "pink", "black", "white", "gray", "brown"]
        
        if colorKeywords.contains(word) {
            let range = findWordRange(word, in: text)
            return ExtractedEntity(
                type: .color,
                text: word,
                normalizedValue: word,
                confidence: .high,
                language: language,
                range: range
            )
        }
        
        return nil
    }
    
    private func extractTemporalEntity(from word: String, text: String, language: NLLanguage) -> ExtractedEntity? {
        let temporalKeywords = ["yesterday", "today", "tomorrow", "week", "month", "year", "day", "hour", "minute", "second"]
        
        if temporalKeywords.contains(word) {
            let range = findWordRange(word, in: text)
            let _ = classifyTemporalExpression(word)
            let normalizedValue = normalizeTemporalExpression(word)
            
            return ExtractedEntity(
                type: .date,
                text: word,
                normalizedValue: normalizedValue,
                confidence: .medium,
                language: language,
                range: range
            )
        }
        
        return nil
    }
    
    private func findWordRange(_ word: String, in text: String) -> NSRange {
        let range = text.range(of: word, options: .caseInsensitive)
        return range != nil ? NSRange(range!, in: text) : NSRange(location: 0, length: 0)
    }
    
    private func classifyTemporalExpression(_ word: String) -> String {
        switch word.lowercased() {
        case "yesterday", "today", "tomorrow":
            return "day"
        case "week":
            return "week"
        case "month":
            return "month"
        case "year":
            return "year"
        default:
            return "relative"
        }
    }
    
    private func normalizeTemporalExpression(_ word: String) -> String {
        return word.lowercased()
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
            return .unknown
        }
    }
    
    private func calculateNLTagConfidence(_ tag: NLTag, text: String) -> EntityConfidence {
        return .high
    }
    
    private func calculatePatternConfidence(_ type: EntityType) -> EntityConfidence {
        switch type {
        case .email, .phoneNumber, .url:
            return .veryHigh
        case .currency, .number:
            return .high
        default:
            return .medium
        }
    }
    
    private func removeDuplicateEntities(_ entities: [ExtractedEntity]) -> [ExtractedEntity] {
        var uniqueEntities: [ExtractedEntity] = []
        var seenTexts: Set<String> = []
        
        for entity in entities {
            if !seenTexts.contains(entity.normalizedValue) {
                uniqueEntities.append(entity)
                seenTexts.insert(entity.normalizedValue)
            }
        }
        
        return uniqueEntities
    }
    
    private func calculateOverallConfidence(_ entities: [ExtractedEntity]) -> EntityConfidence {
        guard !entities.isEmpty else { return .low }
        
        let totalScore = entities.reduce(0) { sum, entity in
            sum + entity.confidence.rawValue
        }
        
        let averageScore = Double(totalScore) / Double(entities.count)
        
        if averageScore >= 0.9 {
            return .veryHigh
        } else if averageScore >= 0.8 {
            return .high
        } else if averageScore >= 0.6 {
            return .medium
        } else {
            return .low
        }
    }
    
    // MARK: - Private Methods - Caching
    
    private func getCachedResult(for text: String) -> EntityExtractionResult? {
        return cachedResults[text]
    }
    
    private func cacheResult(_ result: EntityExtractionResult, for text: String) {
        // Remove oldest entries if cache is full
        if cachedResults.count >= maxCacheSize {
            let keysToRemove = Array(cachedResults.keys.prefix(cachedResults.count - maxCacheSize + 1))
            keysToRemove.forEach { cachedResults.removeValue(forKey: $0) }
        }
        
        cachedResults[text] = result
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
        return (count: cachedResults.count, maxSize: maxCacheSize)
    }
    
    /// Clear all cached results
    public func clearCache() {
        cachedResults.removeAll()
    }
}

