import Foundation
import Vision
import NaturalLanguage
import Combine

#if canImport(UIKit)
import UIKit
#endif

// Import models
import SwiftData

/// Comprehensive semantic tagging service leveraging Apple's AI frameworks
/// Combines OCR, Vision, and NLP for intelligent content understanding
@MainActor
public class SemanticTaggingService: ObservableObject {
    
    // MARK: - Dependencies
    
    private let nlTagger: NLTagger
    private let languageRecognizer: NLLanguageRecognizer
    
    // MARK: - Processing State
    
    @Published public private(set) var isProcessing = false
    @Published public private(set) var processingProgress: Double = 0.0
    @Published public private(set) var lastError: Error?
    
    // MARK: - Cache
    
    private var tagCache: [String: SemanticTagCollection] = [:]
    private var businessEntityCache: [String: [BusinessEntity]] = [:]
    private var contentClassificationCache: [String: ContentClassification] = [:]
    private let cacheQueue = DispatchQueue(label: "semantic.tagging.cache", attributes: .concurrent)
    
    // MARK: - Configuration
    
    private let maxCacheSize = 200
    private let processingTimeout: TimeInterval = 30.0
    private let minConfidenceThreshold = 0.3
    
    // MARK: - Business Recognition Data
    
    /// Known business names and their classifications
    private let businessDatabase: [String: BusinessType] = [
        // Hotels
        "marriott": .hotel, "hilton": .hotel, "hyatt": .hotel, "sheraton": .hotel,
        "westin": .hotel, "intercontinental": .hotel, "doubletree": .hotel,
        "holiday inn": .hotel, "courtyard": .hotel, "residence inn": .hotel,
        
        // Airlines
        "american airlines": .airline, "delta": .airline, "united": .airline,
        "southwest": .airline, "jetblue": .airline, "alaska": .airline,
        "spirit": .airline, "frontier": .airline, "lufthansa": .airline,
        
        // Restaurants
        "starbucks": .restaurant, "mcdonald": .restaurant, "burger king": .restaurant,
        "subway": .restaurant, "kfc": .restaurant, "taco bell": .restaurant,
        "pizza hut": .restaurant, "dominos": .restaurant, "chipotle": .restaurant,
        
        // Retail
        "walmart": .retail, "target": .retail, "amazon": .retail, "costco": .retail,
        "home depot": .retail, "best buy": .retail, "apple store": .retail,
        "nike": .retail, "adidas": .retail, "gap": .retail,
        
        // Banks
        "chase": .bank, "wells fargo": .bank, "bank of america": .bank,
        "citibank": .bank, "goldman sachs": .bank, "morgan stanley": .bank,
        
        // Technology
        "apple": .technology, "google": .technology, "microsoft": .technology,
        "facebook": .technology, "netflix": .technology,
        "uber": .technology, "lyft": .transportation, "tesla": .transportation
    ]
    
    // MARK: - Content Type Patterns
    
    /// Regular expressions for content type detection
    private let contentPatterns: [ContentType: [String]] = [
        .receipt: [
            "receipt", "total", "tax", "subtotal", "payment", "cash", "credit",
            "\\$[0-9]+\\.[0-9]{2}", "qty", "item", "amount due"
        ],
        .invoice: [
            "invoice", "bill to", "invoice number", "due date", "amount due",
            "payment terms", "net 30", "remit to"
        ],
        .email: [
            "from:", "to:", "subject:", "sent:", "@", "reply", "forward",
            "inbox", "gmail", "outlook", "yahoo"
        ],
        .webpage: [
            "http", "www\\.", "\\.com", "\\.org", "\\.net", "browser",
            "chrome", "safari", "firefox", "search"
        ],
        .socialMedia: [
            "facebook", "twitter", "instagram", "linkedin", "snapchat",
            "tiktok", "like", "share", "comment", "follow", "post"
        ],
        .message: [
            "imessage", "whatsapp", "telegram", "signal", "messenger",
            "text message", "sms", "delivered", "read"
        ],
        .map: [
            "google maps", "apple maps", "directions", "route", "gps",
            "navigate", "location", "address", "miles", "km"
        ],
        .calendar: [
            "calendar", "event", "meeting", "appointment", "schedule",
            "reminder", "date", "time", "all day"
        ],
        .ticket: [
            "ticket", "boarding pass", "seat", "flight", "gate", "departure",
            "arrival", "confirmation", "barcode", "qr code"
        ]
    ]
    
    // MARK: - Initialization
    
    public init() {
        self.nlTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .language])
        self.languageRecognizer = NLLanguageRecognizer()
        
        // Configure language constraints
        self.languageRecognizer.languageConstraints = [
            .english, .spanish, .french, .german, .italian, .portuguese
        ]
    }
    
    // MARK: - Public Interface
    
    /// Generate comprehensive semantic tags for a screenshot
    /// - Parameters:
    ///   - imageData: The screenshot image data
    ///   - ocrText: Previously extracted OCR text (optional)
    ///   - visualAttributes: Previously analyzed visual attributes (optional)
    /// - Returns: Complete semantic tag collection
    public func generateSemanticTags(
        for imageData: Data,
        ocrText: String? = nil,
        visualAttributes: VisualAttributes? = nil
    ) async throws -> SemanticTagCollection {
        
        let cacheKey = generateCacheKey(for: imageData)
        
        // Check cache first
        if let cachedTags = getCachedTags(for: cacheKey) {
            return cachedTags
        }
        
        await MainActor.run {
            isProcessing = true
            processingProgress = 0.0
            lastError = nil
        }
        
        do {
            let tags = try await performSemanticTagging(
                imageData: imageData,
                ocrText: ocrText,
                visualAttributes: visualAttributes
            )
            
            // Cache the results
            cacheTags(tags, for: cacheKey)
            
            await MainActor.run {
                isProcessing = false
                processingProgress = 1.0
            }
            
            return tags
            
        } catch {
            await MainActor.run {
                isProcessing = false
                lastError = error
            }
            throw error
        }
    }
    
    /// Extract business entities from text
    /// - Parameter text: Input text to analyze
    /// - Returns: Array of recognized business entities
    public func extractBusinessEntities(from text: String) async -> [BusinessEntity] {
        let cacheKey = "business_\(text.hash)"
        
        if let cached = businessEntityCache[cacheKey] {
            return cached
        }
        
        var entities: [BusinessEntity] = []
        let lowercasedText = text.lowercased()
        
        // Check against business database
        for (businessName, businessType) in businessDatabase {
            if lowercasedText.contains(businessName) {
                let confidence = calculateBusinessConfidence(
                    businessName: businessName,
                    in: text
                )
                
                let entity = BusinessEntity(
                    name: businessName.localizedCapitalized,
                    type: businessType,
                    confidence: confidence,
                    extractedFrom: text
                )
                entities.append(entity)
            }
        }
        
        // Use NLTagger for organization name detection
        nlTagger.string = text
        let organizationTags = nlTagger.tags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation]
        )
        
        for (tag, range) in organizationTags {
            if tag == .organizationName {
                let orgName = String(text[range])
                if !entities.contains(where: { $0.name.lowercased() == orgName.lowercased() }) {
                    let entity = BusinessEntity(
                        name: orgName,
                        type: .unknown,
                        confidence: 0.7,
                        extractedFrom: text
                    )
                    entities.append(entity)
                }
            }
        }
        
        // Cache results
        businessEntityCache[cacheKey] = entities
        limitCacheSize()
        
        return entities
    }
    
    /// Classify content type of screenshot
    /// - Parameters:
    ///   - ocrText: Extracted text from screenshot
    ///   - visualObjects: Detected visual objects
    /// - Returns: Content classification result
    public func classifyContent(
        ocrText: String?,
        visualObjects: [String] = []
    ) async -> ContentClassification {
        
        let combinedText = [ocrText ?? "", visualObjects.joined(separator: " ")].joined(separator: " ")
        let cacheKey = "content_\(combinedText.hash)"
        
        if let cached = contentClassificationCache[cacheKey] {
            return cached
        }
        
        var scores: [ContentType: Double] = [:]
        
        // Pattern-based classification
        for (contentType, patterns) in contentPatterns {
            let score = calculatePatternScore(for: patterns, in: combinedText)
            scores[contentType] = score
        }
        
        // Visual object-based classification
        let visualScore = calculateVisualObjectScore(visualObjects)
        for (contentType, score) in visualScore {
            scores[contentType] = (scores[contentType] ?? 0.0) + score
        }
        
        // Find primary type with highest score
        let sortedScores = scores.sorted { $0.value > $1.value }
        let primaryType = sortedScores.first?.key ?? .unknown
        let confidence = sortedScores.first?.value ?? 0.0
        
        // Get secondary types with significant scores
        let secondaryTypes = sortedScores.dropFirst()
            .filter { $0.value > 0.3 }
            .map { $0.key }
            .prefix(3)
            .map { $0 }
        
        let classification = ContentClassification(
            primaryType: primaryType,
            confidence: min(1.0, confidence),
            secondaryTypes: Array(secondaryTypes)
        )
        
        // Cache results
        contentClassificationCache[cacheKey] = classification
        limitCacheSize()
        
        return classification
    }
    
    // MARK: - Private Implementation
    
    /// Perform comprehensive semantic tagging
    private func performSemanticTagging(
        imageData: Data,
        ocrText: String?,
        visualAttributes: VisualAttributes?
    ) async throws -> SemanticTagCollection {
        
        var allTags: [SemanticTag] = []
        
        // Step 1: OCR-based tagging (10%)
        await updateProgress(0.1)
        if let ocrText = ocrText, !ocrText.isEmpty {
            let ocrTags = await generateOCRTags(from: ocrText)
            allTags.append(contentsOf: ocrTags)
        }
        
        // Step 2: Entity extraction tagging (20%)
        await updateProgress(0.3)
        if let ocrText = ocrText, !ocrText.isEmpty {
            let entityTags = await generateEntityTags(from: ocrText)
            allTags.append(contentsOf: entityTags)
        }
        
        // Step 3: Business entity tagging (20%)
        await updateProgress(0.5)
        if let ocrText = ocrText, !ocrText.isEmpty {
            let businessTags = await generateBusinessTags(from: ocrText)
            allTags.append(contentsOf: businessTags)
        }
        
        // Step 4: Visual object tagging (20%)
        await updateProgress(0.7)
        if let visualAttributes = visualAttributes {
            let visualTags = generateVisualTags(from: visualAttributes)
            allTags.append(contentsOf: visualTags)
        }
        
        // Step 5: Content classification tagging (20%)
        await updateProgress(0.9)
        let contentTags = await generateContentTypeTags(
            ocrText: ocrText,
            visualObjects: visualAttributes?.detectedObjects.map(\.label) ?? []
        )
        allTags.append(contentsOf: contentTags)
        
        // Step 6: AI-generated contextual tags (10%)
        await updateProgress(1.0)
        let contextualTags = await generateContextualTags(
            ocrText: ocrText,
            visualAttributes: visualAttributes
        )
        allTags.append(contentsOf: contextualTags)
        
        // Remove duplicates and low-confidence tags
        let filteredTags = removeDuplicatesAndFilter(allTags)
        
        return SemanticTagCollection(tags: filteredTags)
    }
    
    /// Generate tags from OCR text
    private func generateOCRTags(from text: String) async -> [SemanticTag] {
        var tags: [SemanticTag] = []
        
        // Use NLTagger for lexical classification
        nlTagger.string = text
        let lexicalTags = nlTagger.tags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        )
        
        for (tag, range) in lexicalTags {
            let word = String(text[range]).lowercased()
            
            if let tag = tag, shouldIncludeWord(word, lexicalClass: tag) {
                let semanticTag = SemanticTag(
                    name: word,
                    confidence: calculateOCRConfidence(for: word, tag: tag),
                    source: .ocr,
                    category: mapLexicalClassToCategory(tag)
                )
                tags.append(semanticTag)
            }
        }
        
        return tags
    }
    
    /// Generate tags from entity extraction
    private func generateEntityTags(from text: String) async -> [SemanticTag] {
        var tags: [SemanticTag] = []
        
        nlTagger.string = text
        let entityTags = nlTagger.tags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation]
        )
        
        for (tag, range) in entityTags {
            if let tag = tag {
                let entityText = String(text[range])
                let semanticTag = SemanticTag(
                    name: entityText,
                    confidence: 0.8,
                    source: .entityExtraction,
                    category: mapNameTypeToCategory(tag)
                )
                tags.append(semanticTag)
            }
        }
        
        return tags
    }
    
    /// Generate tags from business entities
    private func generateBusinessTags(from text: String) async -> [SemanticTag] {
        let businessEntities = await extractBusinessEntities(from: text)
        
        return businessEntities.map { entity in
            SemanticTag(
                name: entity.name,
                confidence: entity.confidence,
                source: .businessRecognition,
                category: .brand
            )
        }
    }
    
    /// Generate tags from visual attributes
    private func generateVisualTags(from visualAttributes: VisualAttributes) -> [SemanticTag] {
        var tags: [SemanticTag] = []
        
        // Object detection tags
        for object in visualAttributes.detectedObjects {
            let tag = SemanticTag(
                name: object.label,
                confidence: object.confidence,
                source: .vision,
                category: .object
            )
            tags.append(tag)
        }
        
        // Color tags
        for color in visualAttributes.colorAnalysis.dominantColors {
            let tag = SemanticTag(
                name: color.colorName,
                confidence: color.prominence,
                source: .vision,
                category: .color
            )
            tags.append(tag)
        }
        
        // Scene classification tags
        let sceneTag = SemanticTag(
            name: visualAttributes.sceneClassification.primaryScene.rawValue,
            confidence: visualAttributes.sceneClassification.primaryConfidence,
            source: .vision,
            category: .contentType
        )
        tags.append(sceneTag)
        
        return tags
    }
    
    /// Generate content type tags
    private func generateContentTypeTags(
        ocrText: String?,
        visualObjects: [String]
    ) async -> [SemanticTag] {
        
        let classification = await classifyContent(
            ocrText: ocrText,
            visualObjects: visualObjects
        )
        
        var tags: [SemanticTag] = []
        
        // Primary content type
        let primaryTag = SemanticTag(
            name: classification.primaryType.rawValue,
            confidence: classification.confidence,
            source: .contentClassification,
            category: .contentType
        )
        tags.append(primaryTag)
        
        // Secondary content types
        for secondaryType in classification.secondaryTypes {
            let secondaryTag = SemanticTag(
                name: secondaryType.rawValue,
                confidence: classification.confidence * 0.7,
                source: .contentClassification,
                category: .contentType
            )
            tags.append(secondaryTag)
        }
        
        return tags
    }
    
    /// Generate AI-driven contextual tags
    private func generateContextualTags(
        ocrText: String?,
        visualAttributes: VisualAttributes?
    ) async -> [SemanticTag] {
        
        var tags: [SemanticTag] = []
        
        // Context-based inference
        if let text = ocrText {
            // Financial context
            if containsFinancialTerms(text) {
                let tag = SemanticTag(
                    name: "financial",
                    confidence: 0.8,
                    source: .aiGenerated,
                    category: .concept
                )
                tags.append(tag)
            }
            
            // Travel context
            if containsTravelTerms(text) {
                let tag = SemanticTag(
                    name: "travel",
                    confidence: 0.8,
                    source: .aiGenerated,
                    category: .concept
                )
                tags.append(tag)
            }
            
            // Shopping context
            if containsShoppingTerms(text) {
                let tag = SemanticTag(
                    name: "shopping",
                    confidence: 0.8,
                    source: .aiGenerated,
                    category: .concept
                )
                tags.append(tag)
            }
        }
        
        return tags
    }
    
    // MARK: - Helper Methods
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            processingProgress = progress
        }
    }
    
    private func generateCacheKey(for imageData: Data) -> String {
        let hash = imageData.hashValue
        return "semantic_\(hash)"
    }
    
    private func getCachedTags(for key: String) -> SemanticTagCollection? {
        return tagCache[key]
    }
    
    private func cacheTags(_ tags: SemanticTagCollection, for key: String) {
        Task { @MainActor in
            self.tagCache[key] = tags
            self.limitCacheSize()
        }
    }
    
    private func limitCacheSize() {
        if tagCache.count > maxCacheSize {
            let keysToRemove = Array(tagCache.keys.prefix(tagCache.count - maxCacheSize))
            for key in keysToRemove {
                tagCache.removeValue(forKey: key)
            }
        }
    }
    
    private func tokenizeText(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range]).lowercased()
            if token.count > 2 && !token.allSatisfy({ $0.isPunctuation }) {
                tokens.append(token)
            }
            return true
        }
        
        return tokens
    }
    
    private func shouldIncludeWord(_ word: String, lexicalClass: NLTag) -> Bool {
        // Filter out common words and focus on meaningful content
        let commonWords = Set(["the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her", "was", "one", "our", "out", "day", "get", "has", "him", "his", "how", "man", "new", "now", "old", "see", "two", "way", "who", "boy", "did", "its", "let", "put", "say", "she", "too", "use"])
        
        if commonWords.contains(word) || word.count < 3 {
            return false
        }
        
        // Include nouns, proper nouns, and adjectives
        return lexicalClass == .noun || 
               lexicalClass == .adjective || 
               lexicalClass == .verb ||
               lexicalClass == .otherWord
    }
    
    private func calculateOCRConfidence(for word: String, tag: NLTag) -> Double {
        var confidence = 0.6 // Base confidence for OCR-extracted words
        
        // Boost confidence for certain types
        if tag == .noun || tag == .adjective {
            confidence += 0.2
        }
        
        // Boost for longer, more specific words
        if word.count > 6 {
            confidence += 0.1
        }
        
        return min(1.0, confidence)
    }
    
    private func mapLexicalClassToCategory(_ lexicalClass: NLTag) -> TagCategory {
        switch lexicalClass {
        case .noun: return .object
        case .adjective: return .general
        case .verb: return .action
        case .otherWord: return .concept
        default: return .general
        }
    }
    
    private func mapNameTypeToCategory(_ nameType: NLTag) -> TagCategory {
        switch nameType {
        case .personalName: return .person
        case .placeName: return .location
        case .organizationName: return .organization
        default: return .general
        }
    }
    
    private func mapEntityTypeToCategory(_ entityType: String) -> TagCategory {
        switch entityType.lowercased() {
        case "person": return .person
        case "place", "location": return .location
        case "organization": return .organization
        case "color": return .color
        case "object": return .object
        case "date", "time": return .temporal
        case "phone": return .phone
        case "email": return .email
        case "url": return .url
        case "document_type", "document": return .documentType
        default: return .general
        }
    }
    
    private func calculateBusinessConfidence(businessName: String, in text: String) -> Double {
        let businessWords = businessName.components(separatedBy: " ")
        let textWords = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var matchedWords = 0
        for word in businessWords {
            if textWords.contains(word) {
                matchedWords += 1
            }
        }
        
        let confidence = Double(matchedWords) / Double(businessWords.count)
        return min(1.0, confidence * 0.9) // Cap at 0.9 for business recognition
    }
    
    private func calculatePatternScore(for patterns: [String], in text: String) -> Double {
        let lowercasedText = text.lowercased()
        var totalScore = 0.0
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let matches = regex.numberOfMatches(
                    in: text,
                    range: NSRange(location: 0, length: text.count)
                )
                
                if matches > 0 {
                    totalScore += Double(matches) * 0.2
                }
            } catch {
                // Fallback to simple string matching
                if lowercasedText.contains(pattern.lowercased()) {
                    totalScore += 0.2
                }
            }
        }
        
        return min(1.0, totalScore)
    }
    
    private func calculateVisualObjectScore(_ objects: [String]) -> [ContentType: Double] {
        var scores: [ContentType: Double] = [:]
        
        for object in objects {
            let objectLower = object.lowercased()
            
            // Map visual objects to content types
            if objectLower.contains("receipt") || objectLower.contains("paper") {
                scores[.receipt] = (scores[.receipt] ?? 0.0) + 0.3
            }
            
            if objectLower.contains("phone") || objectLower.contains("screen") {
                scores[.app] = (scores[.app] ?? 0.0) + 0.2
            }
            
            if objectLower.contains("map") {
                scores[.map] = (scores[.map] ?? 0.0) + 0.5
            }
            
            if objectLower.contains("qr") || objectLower.contains("barcode") {
                scores[.qrCode] = (scores[.qrCode] ?? 0.0) + 0.6
            }
        }
        
        return scores
    }
    
    private func removeDuplicatesAndFilter(_ tags: [SemanticTag]) -> [SemanticTag] {
        // Group by name and keep highest confidence
        let groupedTags = Dictionary(grouping: tags, by: \.name)
        
        var filteredTags: [SemanticTag] = []
        
        for (_, tagGroup) in groupedTags {
            if let bestTag = tagGroup.max(by: { $0.confidence < $1.confidence }),
               bestTag.confidence >= minConfidenceThreshold {
                filteredTags.append(bestTag)
            }
        }
        
        // Sort by confidence descending
        return filteredTags.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Context Detection Helpers
    
    private func containsFinancialTerms(_ text: String) -> Bool {
        let financialTerms = ["bank", "payment", "transaction", "credit", "debit", "invoice", "receipt", "tax", "expense", "salary", "income"]
        let lowercasedText = text.lowercased()
        return financialTerms.contains { lowercasedText.contains($0) }
    }
    
    private func containsTravelTerms(_ text: String) -> Bool {
        let travelTerms = ["flight", "hotel", "booking", "reservation", "airport", "departure", "arrival", "boarding", "ticket", "passport"]
        let lowercasedText = text.lowercased()
        return travelTerms.contains { lowercasedText.contains($0) }
    }
    
    private func containsShoppingTerms(_ text: String) -> Bool {
        let shoppingTerms = ["purchase", "buy", "order", "cart", "checkout", "shipping", "delivery", "product", "store", "retail"]
        let lowercasedText = text.lowercased()
        return shoppingTerms.contains { lowercasedText.contains($0) }
    }
}

// MARK: - Supporting Types

/// Error types for semantic tagging operations
public enum SemanticTaggingError: LocalizedError {
    case processingTimeout
    case invalidImage
    case analysisFailure(String)
    case cacheError
    
    public var errorDescription: String? {
        switch self {
        case .processingTimeout:
            return "Semantic tagging operation timed out"
        case .invalidImage:
            return "Invalid image provided for analysis"
        case .analysisFailure(let message):
            return "Analysis failed: \(message)"
        case .cacheError:
            return "Cache operation failed"
        }
    }
}
