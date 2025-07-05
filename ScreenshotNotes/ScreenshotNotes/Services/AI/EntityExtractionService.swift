import Foundation
import NaturalLanguage

/// Service for extracting entities from natural language queries
/// Implements Named Entity Recognition using NLTagger and custom pattern matching
public class EntityExtractionService: ObservableObject {
    
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
        
        // Validate input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return EntityExtractionResult(
                entities: [],
                originalText: text,
                processingTimeMs: 0,
                detectedLanguage: .undetermined,
                overallConfidence: .veryLow,
                isSuccessful: false,
                errors: [.invalidInput("Empty or whitespace-only input")]
            )
        }
        
        var extractedEntities: [ExtractedEntity] = []
        var errors: [EntityExtractionError] = []
        
        // Detect language
        let detectedLanguage = detectLanguage(text)
        guard supportedLanguages.contains(detectedLanguage) else {
            return EntityExtractionResult(
                entities: [],
                originalText: text,
                processingTimeMs: 0,
                detectedLanguage: detectedLanguage,
                overallConfidence: .veryLow,
                isSuccessful: false,
                errors: [.languageNotSupported(detectedLanguage)]
            )
        }
        
        // Extract entities using different methods
        do {
            // 1. Named Entity Recognition using NLTagger
            let namedEntities = try await extractNamedEntities(from: text, language: detectedLanguage)
            extractedEntities.append(contentsOf: namedEntities)
            
            // 2. Custom pattern-based extraction
            let patternEntities = try await extractPatternBasedEntities(from: text, language: detectedLanguage)
            extractedEntities.append(contentsOf: patternEntities)
            
            // 3. Visual and object entities
            let visualEntities = try await extractVisualEntities(from: text, language: detectedLanguage)
            extractedEntities.append(contentsOf: visualEntities)
            
            // 4. Temporal entities
            let temporalEntities = try await extractTemporalEntities(from: text, language: detectedLanguage)
            extractedEntities.append(contentsOf: temporalEntities)
            
        } catch let error as EntityExtractionError {
            errors.append(error)
        } catch {
            errors.append(.nlTaggerFailed(error.localizedDescription))
        }
        
        // Remove duplicates and overlapping entities
        extractedEntities = removeDuplicatesAndOverlaps(extractedEntities)
        
        // Calculate processing time
        let processingTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        // Calculate overall confidence
        let overallConfidence = calculateOverallConfidence(entities: extractedEntities)
        
        // Create result
        let result = EntityExtractionResult(
            entities: extractedEntities,
            originalText: text,
            processingTimeMs: processingTimeMs,
            detectedLanguage: detectedLanguage,
            overallConfidence: overallConfidence,
            isSuccessful: errors.isEmpty || !extractedEntities.isEmpty,
            errors: errors
        )
        
        // Cache the result
        cacheResult(result, for: text)
        
        return result
    }
    
    /// Extract entities for multiple texts in batch
    /// - Parameter texts: Array of input texts
    /// - Returns: Array of EntityExtractionResult
    public func extractEntitiesBatch(from texts: [String]) async -> [EntityExtractionResult] {
        await withTaskGroup(of: EntityExtractionResult.self) { group in
            var results: [EntityExtractionResult] = []
            
            for text in texts {
                group.addTask {
                    await self.extractEntities(from: text)
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    /// Clear the entity extraction cache
    public func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cachedResults.removeAll()
        }
    }
    
    // MARK: - Private Methods - Language Detection
    
    private func detectLanguage(_ text: String) -> NLLanguage {
        languageRecognizer.reset()
        languageRecognizer.processString(text)
        
        guard let dominantLanguage = languageRecognizer.dominantLanguage,
              supportedLanguages.contains(dominantLanguage) else {
            return .english // Default to English if unsupported
        }
        
        return dominantLanguage
    }
    
    // MARK: - Private Methods - Named Entity Recognition
    
    private func extractNamedEntities(from text: String, language: NLLanguage) async throws -> [ExtractedEntity] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var entities: [ExtractedEntity] = []
                    
                    self.nlTagger.string = text
                    self.nlTagger.setLanguage(language, range: NSRange(location: 0, length: text.count))
                    
                    // Extract named entities
                    self.nlTagger.enumerateTags(in: NSRange(location: 0, length: text.count),
                                              unit: .word,
                                              scheme: .nameType) { tag, range in
                        
                        guard let tag = tag else { return true }
                        
                        let entityText = String(text[Range(range, in: text)!])
                        let entityType = self.mapNLTagToEntityType(tag)
                        let confidence = self.calculateNLTagConfidence(tag, text: entityText)
                        
                        let entity = ExtractedEntity(
                            type: entityType,
                            text: entityText,
                            normalizedValue: self.normalizeEntityValue(entityText, type: entityType),
                            confidence: confidence,
                            language: language,
                            range: range,
                            isMLDerived: true
                        )
                        
                        entities.append(entity)
                        return true
                    }
                    
                    continuation.resume(returning: entities)
                } catch {
                    continuation.resume(throwing: EntityExtractionError.nlTaggerFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Private Methods - Pattern-Based Extraction
    
    private func extractPatternBasedEntities(from text: String, language: NLLanguage) async throws -> [ExtractedEntity] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
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
                } catch {
                    continuation.resume(throwing: EntityExtractionError.regexPatternFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Private Methods - Visual Entity Extraction
    
    private func extractVisualEntities(from text: String, language: NLLanguage) async throws -> [ExtractedEntity] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var entities: [ExtractedEntity] = []
                let lowercasedText = text.lowercased()
                let words = lowercasedText.components(separatedBy: .whitespacesAndPunctuation)
                
                for word in words {
                    let cleanWord = word.trimmingCharacters(in: .whitespacesAndPunctuation)
                    guard !cleanWord.isEmpty else { continue }
                    
                    // Colors
                    if EntityPatterns.colors.contains(cleanWord) {
                        if let range = self.findWordRange(cleanWord, in: text) {
                            let entity = ExtractedEntity(
                                type: .color,
                                text: String(text[Range(range, in: text)!]),
                                normalizedValue: cleanWord,
                                confidence: .high,
                                language: language,
                                range: range
                            )
                            entities.append(entity)
                        }
                    }
                    
                    // Objects
                    if EntityPatterns.objects.contains(cleanWord) {
                        if let range = self.findWordRange(cleanWord, in: text) {
                            let entity = ExtractedEntity(
                                type: .object,
                                text: String(text[Range(range, in: text)!]),
                                normalizedValue: cleanWord,
                                confidence: .high,
                                language: language,
                                range: range
                            )
                            entities.append(entity)
                        }
                    }
                    
                    // Document types
                    if EntityPatterns.documentTypes.contains(cleanWord) {
                        if let range = self.findWordRange(cleanWord, in: text) {
                            let entity = ExtractedEntity(
                                type: .documentType,
                                text: String(text[Range(range, in: text)!]),
                                normalizedValue: cleanWord,
                                confidence: .high,
                                language: language,
                                range: range
                            )
                            entities.append(entity)
                        }
                    }
                    
                    // Business types
                    if EntityPatterns.businessTypes.contains(cleanWord) {
                        if let range = self.findWordRange(cleanWord, in: text) {
                            let entity = ExtractedEntity(
                                type: .businessType,
                                text: String(text[Range(range, in: text)!]),
                                normalizedValue: cleanWord,
                                confidence: .medium,
                                language: language,
                                range: range
                            )
                            entities.append(entity)
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
                let words = lowercasedText.components(separatedBy: .whitespacesAndPunctuation)
                
                for word in words {
                    let cleanWord = word.trimmingCharacters(in: .whitespacesAndPunctuation)
                    guard !cleanWord.isEmpty else { continue }
                    
                    if EntityPatterns.temporalExpressions.contains(cleanWord) {
                        if let range = self.findWordRange(cleanWord, in: text) {
                            let entityType: EntityType = self.classifyTemporalExpression(cleanWord)
                            let entity = ExtractedEntity(
                                type: entityType,
                                text: String(text[Range(range, in: text)!]),
                                normalizedValue: self.normalizeTemporalExpression(cleanWord),
                                confidence: .high,
                                language: language,
                                range: range
                            )
                            entities.append(entity)
                        }
                    }
                }
                
                continuation.resume(returning: entities)
            }
        }
    }
    
    // MARK: - Private Methods - Helper Functions
    
    private func extractWithPattern(pattern: String, type: EntityType, text: String, language: NLLanguage) -> [ExtractedEntity] {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            return matches.compactMap { match in
                guard let range = Range(match.range, in: text) else { return nil }
                
                let matchedText = String(text[range])
                let nsRange = NSRange(range, in: text)
                
                return ExtractedEntity(
                    type: type,
                    text: matchedText,
                    normalizedValue: normalizeEntityValue(matchedText, type: type),
                    confidence: calculatePatternConfidence(type, text: matchedText),
                    language: language,
                    range: nsRange
                )
            }
        } catch {
            return []
        }
    }
    
    private func findWordRange(_ word: String, in text: String) -> NSRange? {
        let lowercasedText = text.lowercased()
        let lowercasedWord = word.lowercased()
        
        guard let range = lowercasedText.range(of: lowercasedWord) else { return nil }
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
            return .unknown
        }
    }
    
    private func calculateNLTagConfidence(_ tag: NLTag, text: String) -> EntityConfidence {
        // Base confidence on tag type and text characteristics
        let baseConfidence: Double = {
            switch tag {
            case .personalName, .placeName, .organizationName:
                return 0.85
            default:
                return 0.60
            }
        }()
        
        // Adjust based on text length and capitalization
        let lengthBonus = min(0.1, Double(text.count) / 50.0)
        let capitalizationBonus = text.first?.isUppercase == true ? 0.05 : 0.0
        
        let finalConfidence = baseConfidence + lengthBonus + capitalizationBonus
        
        switch finalConfidence {
        case 0.9...:
            return .veryHigh
        case 0.8..<0.9:
            return .high
        case 0.6..<0.8:
            return .medium
        case 0.4..<0.6:
            return .low
        default:
            return .veryLow
        }
    }
    
    private func calculatePatternConfidence(_ type: EntityType, text: String) -> EntityConfidence {
        switch type {
        case .phoneNumber, .email, .url:
            return .veryHigh
        case .currency, .date:
            return .high
        case .number:
            return .medium
        default:
            return .low
        }
    }
    
    private func classifyTemporalExpression(_ word: String) -> EntityType {
        if ["today", "yesterday", "tomorrow", "now"].contains(word) {
            return .date
        } else if ["morning", "afternoon", "evening", "night"].contains(word) {
            return .time
        } else if ["daily", "weekly", "monthly", "yearly"].contains(word) {
            return .frequency
        } else if word.contains("day") || word.contains("week") || word.contains("month") {
            return .duration
        } else {
            return .date
        }
    }
    
    private func normalizeEntityValue(_ text: String, type: EntityType) -> String {
        switch type {
        case .color, .object, .documentType, .businessType:
            return text.lowercased().trimmingCharacters(in: .whitespacesAndPunctuation)
        case .person, .place, .organization:
            return text.trimmingCharacters(in: .whitespacesAndPunctuation)
        case .phoneNumber:
            return text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        case .email, .url:
            return text.lowercased().trimmingCharacters(in: .whitespacesAndPunctuation)
        default:
            return text.trimmingCharacters(in: .whitespacesAndPunctuation)
        }
    }
    
    private func normalizeTemporalExpression(_ word: String) -> String {
        // Convert relative temporal expressions to standardized forms
        switch word.lowercased() {
        case "today":
            return "today"
        case "yesterday":
            return "yesterday"
        case "tomorrow":
            return "tomorrow"
        case "last":
            return "previous"
        case "next":
            return "upcoming"
        default:
            return word.lowercased()
        }
    }
    
    private func removeDuplicatesAndOverlaps(_ entities: [ExtractedEntity]) -> [ExtractedEntity] {
        var uniqueEntities: [ExtractedEntity] = []
        
        // Sort by range location
        let sortedEntities = entities.sorted { $0.range.location < $1.range.location }
        
        for entity in sortedEntities {
            // Check for overlaps with existing entities
            let hasOverlap = uniqueEntities.contains { existing in
                NSLocationInRange(entity.range.location, existing.range) ||
                NSLocationInRange(existing.range.location, entity.range)
            }
            
            if !hasOverlap {
                uniqueEntities.append(entity)
            } else {
                // If there's an overlap, keep the entity with higher confidence
                if let overlappingIndex = uniqueEntities.firstIndex(where: { existing in
                    NSLocationInRange(entity.range.location, existing.range) ||
                    NSLocationInRange(existing.range.location, entity.range)
                }) {
                    if entity.confidence.rawValue > uniqueEntities[overlappingIndex].confidence.rawValue {
                        uniqueEntities[overlappingIndex] = entity
                    }
                }
            }
        }
        
        return uniqueEntities
    }
    
    private func calculateOverallConfidence(entities: [ExtractedEntity]) -> EntityConfidence {
        guard !entities.isEmpty else { return .veryLow }
        
        let averageConfidence = entities.reduce(0.0) { $0 + $1.confidence.rawValue } / Double(entities.count)
        
        switch averageConfidence {
        case 0.9...:
            return .veryHigh
        case 0.8..<0.9:
            return .high
        case 0.6..<0.8:
            return .medium
        case 0.4..<0.6:
            return .low
        default:
            return .veryLow
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
