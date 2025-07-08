import Foundation
import CoreML
import NaturalLanguage
import SwiftData
import UIKit

/// Production-ready Content Similarity Engine with Core ML embeddings and multi-modal analysis
/// Sprint 7.1.1: Advanced ML pipeline for intelligent content similarity detection
@MainActor
final class SimilarityEngine: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SimilarityEngine()
    
    // MARK: - Dependencies
    private let visualSimilarityService = VisualSimilarityService.shared
    private let embeddingProvider = NLEmbedding.sentenceEmbedding(for: .english)
    private let similarityCache = SimilarityCache()
    
    // MARK: - Configuration
    private let performanceTarget: TimeInterval = 0.5 // 500ms as per specification
    private let similarityThreshold: Double = 0.7 // As per integration test
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // MARK: - State
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var lastProcessingTime: TimeInterval = 0.0
    @Published var cacheHitRate: Double = 0.0
    
    // MARK: - Performance Metrics
    private var performanceMetrics = SimilarityPerformanceMetrics()
    
    private init() {
        initializeEmbeddings()
    }
    
    // MARK: - Public Interface
    
    /// Calculates comprehensive similarity between two screenshots
    /// - Parameters:
    ///   - source: Source screenshot
    ///   - target: Target screenshot for comparison
    /// - Returns: Complete similarity score with all metrics
    func calculateSimilarity(
        between source: Screenshot,
        and target: Screenshot
    ) async throws -> SimilarityScore {
        let startTime = CFAbsoluteTimeGetCurrent()
        isProcessing = true
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            lastProcessingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // Convert to ms
            performanceMetrics.recordCalculation(duration: lastProcessingTime)
        }
        
        // Check cache first
        let cacheKey = createCacheKey(source: source.id, target: target.id)
        // Only check cache on the actor, do not return the model across actor boundaries
        let cachedScoreId = await similarityCache.getScoreId(for: cacheKey)
        if let cachedScoreId {
            cacheHitRate = await similarityCache.hitRate
            // Fetch the model on the actor
            if let cachedScore = await similarityCache.getScoreDirect(for: cachedScoreId) {
                return cachedScore
            }
        }
        
        // Calculate all similarity components
        processingProgress = 0.1
        
        let textSimilarity = await calculateTextSimilarity(source: source, target: target)
        processingProgress = 0.3
        
        let visualSimilarity = await calculateVisualSimilarity(source: source, target: target)
        processingProgress = 0.5
        
        let thematicSimilarity = await calculateThematicSimilarity(source: source, target: target)
        processingProgress = 0.7
        
        let temporalSimilarity = calculateTemporalSimilarity(source: source, target: target)
        processingProgress = 0.8
        
        let semanticSimilarity = await calculateSemanticSimilarity(source: source, target: target)
        processingProgress = 0.9
        
        // Create comprehensive similarity score
        let similarityScore = createSimilarityScore(
            source: source,
            target: target,
            textSimilarity: textSimilarity,
            visualSimilarity: visualSimilarity,
            thematicSimilarity: thematicSimilarity,
            temporalSimilarity: temporalSimilarity,
            semanticSimilarity: semanticSimilarity,
            processingTime: lastProcessingTime
        )
        
        // Cache the result
        await similarityCache.storeScore(similarityScore, for: cacheKey)
        processingProgress = 1.0
        
        return similarityScore
    }
    
    /// Batch similarity calculation for multiple screenshots
    /// - Parameters:
    ///   - screenshots: Array of screenshots to compare
    ///   - referenceScreenshot: Reference screenshot for comparison
    /// - Returns: Array of similarity scores sorted by relevance
    func calculateBatchSimilarity(
        for screenshots: [Screenshot],
        against referenceScreenshot: Screenshot
    ) async throws -> [SimilarityScore] {
        let startTime = CFAbsoluteTimeGetCurrent()
        isProcessing = true
        
        var results: [SimilarityScore] = []
        let total = Double(screenshots.count)
        
        for (index, screenshot) in screenshots.enumerated() {
            processingProgress = Double(index) / total
            if screenshot.id != referenceScreenshot.id {
                let score = try await calculateSimilarity(between: referenceScreenshot, and: screenshot)
                results.append(score)
            }
        }
        
        isProcessing = false
        lastProcessingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        // Sort by overall similarity score (descending)
        return results.sorted { $0.overallScore > $1.overallScore }
    }
    
    /// Finds most similar screenshots for a given screenshot
    /// - Parameters:
    ///   - screenshot: Source screenshot
    ///   - candidates: Pool of candidate screenshots
    ///   - limit: Maximum number of results to return
    /// - Returns: Most similar screenshots with scores above threshold
    func findSimilarScreenshots(
        for screenshot: Screenshot,
        in candidates: [Screenshot],
        limit: Int = 10
    ) async throws -> [SimilarityScore] {
        let scores = try await calculateBatchSimilarity(for: candidates, against: screenshot)
        // Only return IDs, not models, across actor boundaries
        return Array(scores
            .filter { $0.areSimilar }
            .prefix(limit))
    }
}

// MARK: - Text Similarity Calculations

private extension SimilarityEngine {
    
    /// Calculates text-based similarity using Core ML embeddings
    func calculateTextSimilarity(source: Screenshot, target: Screenshot) async -> TextSimilarityComponents {
        // Extract text content
        let sourceText = source.extractedText ?? ""
        let targetText = target.extractedText ?? ""
        
        guard !sourceText.isEmpty && !targetText.isEmpty else {
            return TextSimilarityComponents(
                embedding: 0.0,
                syntactic: 0.0,
                semantic: 0.0,
                entity: 0.0
            )
        }
        
        // Calculate Core ML embedding similarity
        let embeddingSimilarity = await calculateEmbeddingSimilarity(
            text1: sourceText,
            text2: targetText
        )
        
        // Calculate syntactic similarity
        let syntacticSimilarity = calculateSyntacticSimilarity(
            text1: sourceText,
            text2: targetText
        )
        
        // Calculate semantic similarity using entity overlap
        let semanticSimilarity = calculateSemanticTextSimilarity(
            source: source,
            target: target
        )
        
        // Calculate entity similarity
        let entitySimilarity = calculateEntitySimilarity(
            source: source,
            target: target
        )
        
        return TextSimilarityComponents(
            embedding: embeddingSimilarity,
            syntactic: syntacticSimilarity,
            semantic: semanticSimilarity,
            entity: entitySimilarity
        )
    }
    
    /// Calculates embedding similarity using Core ML on-device processing
    func calculateEmbeddingSimilarity(text1: String, text2: String) async -> Double {
        guard let embedding = embeddingProvider else { return 0.0 }
        
        // Generate embeddings
        guard let vector1 = embedding.vector(for: text1),
              let vector2 = embedding.vector(for: text2),
              vector1.count == vector2.count else { return 0.0 }
        
        // Calculate cosine similarity
        let dotProduct = zip(vector1, vector2).map { $0 * $1 }.reduce(0, +)
        let magnitude1 = sqrt(vector1.map { $0 * $0 }.reduce(0, +))
        let magnitude2 = sqrt(vector2.map { $0 * $0 }.reduce(0, +))
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0.0 }
        
        return Double(dotProduct / (magnitude1 * magnitude2))
    }
    
    /// Calculates syntactic similarity using Natural Language framework
    func calculateSyntacticSimilarity(text1: String, text2: String) -> Double {
        let tokenizer = NLTokenizer(unit: .word)
        
        // Tokenize both texts
        tokenizer.string = text1
        let tokens1 = Set(tokenizer.tokens(for: text1.startIndex..<text1.endIndex).map {
            String(text1[$0]).lowercased()
        })
        
        tokenizer.string = text2
        let tokens2 = Set(tokenizer.tokens(for: text2.startIndex..<text2.endIndex).map {
            String(text2[$0]).lowercased()
        })
        
        // Calculate Jaccard similarity
        let intersection = tokens1.intersection(tokens2)
        let union = tokens1.union(tokens2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    /// Calculates semantic text similarity
    func calculateSemanticTextSimilarity(source: Screenshot, target: Screenshot) -> Double {
        // Use existing semantic tags if available
        let sourceTagNames = source.searchableTagNames
        let targetTagNames = target.searchableTagNames
        
        guard !sourceTagNames.isEmpty && !targetTagNames.isEmpty else { return 0.0 }
        
        let sourceSet = Set(sourceTagNames.map { $0.lowercased() })
        let targetSet = Set(targetTagNames.map { $0.lowercased() })
        
        let intersection = sourceSet.intersection(targetSet)
        let union = sourceSet.union(targetSet)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    /// Calculates entity similarity
    func calculateEntitySimilarity(source: Screenshot, target: Screenshot) -> Double {
        // This would integrate with existing EntityExtractionService
        // For now, we'll use extracted text entity comparison
        let sourceEntities = extractSimpleEntities(from: source.extractedText ?? "")
        let targetEntities = extractSimpleEntities(from: target.extractedText ?? "")
        
        let intersection = sourceEntities.intersection(targetEntities)
        let union = sourceEntities.union(targetEntities)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    /// Simple entity extraction for similarity calculation
    func extractSimpleEntities(from text: String) -> Set<String> {
        let types: NSTextCheckingResult.CheckingType = [.phoneNumber, .link, .date, .address]
        let detector = try? NSDataDetector(types: types.rawValue)
        var entities: Set<String> = []
        
        detector?.enumerateMatches(in: text, range: NSRange(text.startIndex..., in: text)) { match, _, _ in
            if let match = match, let range = Range(match.range, in: text) {
                entities.insert(String(text[range]).lowercased())
            }
        }
        
        return entities
    }
}

// MARK: - Visual Similarity Calculations

private extension SimilarityEngine {
    
    /// Calculates visual similarity using VisionKit integration
    func calculateVisualSimilarity(source: Screenshot, target: Screenshot) async -> VisualSimilarityComponents {
        return await visualSimilarityService.calculateVisualSimilarity(
            sourceImage: UIImage(data: source.imageData),
            targetImage: UIImage(data: target.imageData)
        )
    }
}

// MARK: - Thematic and Temporal Similarity

private extension SimilarityEngine {
    
    /// Calculates thematic similarity using topic modeling
    func calculateThematicSimilarity(source: Screenshot, target: Screenshot) async -> Double {
        // Use existing visual attributes for thematic analysis
        let sourceColors = source.dominantColors.map { $0.colorName }
        let targetColors = target.dominantColors.map { $0.colorName }
        
        // Color theme similarity
        let colorSimilarity = calculateColorThemeSimilarity(
            colors1: sourceColors,
            colors2: targetColors
        )
        
        // Scene context similarity (if available from visual attributes)
        let contextSimilarity = calculateContextSimilarity(source: source, target: target)
        
        // Combine thematic factors
        return (colorSimilarity * 0.6 + contextSimilarity * 0.4)
    }
    
    /// Calculates temporal similarity based on time proximity
    func calculateTemporalSimilarity(source: Screenshot, target: Screenshot) -> Double {
        let timeDifference = abs(source.timestamp.timeIntervalSince(target.timestamp))
        
        // Exponential decay function for temporal similarity
        // Screenshots taken within 1 hour = high similarity
        // Screenshots taken within 1 day = medium similarity
        // Screenshots taken > 1 week = low similarity
        let hourInSeconds: TimeInterval = 3600
        let dayInSeconds: TimeInterval = 86400
        let weekInSeconds: TimeInterval = 604800
        
        switch timeDifference {
        case 0..<hourInSeconds:
            return 1.0 - (timeDifference / hourInSeconds) * 0.2 // 0.8-1.0
        case hourInSeconds..<dayInSeconds:
            return 0.8 - ((timeDifference - hourInSeconds) / (dayInSeconds - hourInSeconds)) * 0.4 // 0.4-0.8
        case dayInSeconds..<weekInSeconds:
            return 0.4 - ((timeDifference - dayInSeconds) / (weekInSeconds - dayInSeconds)) * 0.3 // 0.1-0.4
        default:
            return 0.1 // Very old screenshots have minimal temporal similarity
        }
    }
    
    /// Calculates semantic similarity based on extracted entities and tags
    func calculateSemanticSimilarity(source: Screenshot, target: Screenshot) async -> Double {
        // Combine multiple semantic factors
        let tagSimilarity = calculateTagSimilarity(source: source, target: target)
        let entitySimilarity = calculateEntitySimilarity(source: source, target: target)
        let contextSimilarity = calculateContextSimilarity(source: source, target: target)
        
        // Weighted combination
        return (tagSimilarity * 0.4 + entitySimilarity * 0.4 + contextSimilarity * 0.2)
    }
    
    /// Helper method for color theme similarity
    func calculateColorThemeSimilarity(colors1: [String], colors2: [String]) -> Double {
        guard !colors1.isEmpty && !colors2.isEmpty else { return 0.0 }
        
        let set1 = Set(colors1.map { $0.lowercased() })
        let set2 = Set(colors2.map { $0.lowercased() })
        
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    /// Helper method for context similarity
    func calculateContextSimilarity(source: Screenshot, target: Screenshot) -> Double {
        // This could analyze app context, UI patterns, etc.
        // For now, we'll use a simple heuristic based on available data
        let sourceText = source.extractedText ?? ""
        let targetText = target.extractedText ?? ""
        
        // Look for common patterns (URLs, app names, UI elements)
        let commonPatterns = findCommonPatterns(text1: sourceText, text2: targetText)
        
        return min(Double(commonPatterns.count) / 5.0, 1.0) // Normalize to max 5 patterns
    }
    
    /// Helper method for tag similarity
    func calculateTagSimilarity(source: Screenshot, target: Screenshot) -> Double {
        let sourceTagNames = source.searchableTagNames
        let targetTagNames = target.searchableTagNames
        
        let sourceTags = Set(sourceTagNames.map { $0.lowercased() })
        let targetTags = Set(targetTagNames.map { $0.lowercased() })
        
        let intersection = sourceTags.intersection(targetTags)
        let union = sourceTags.union(targetTags)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    /// Finds common patterns between two texts
    func findCommonPatterns(text1: String, text2: String) -> Set<String> {
        var patterns: Set<String> = []
        
        // URL patterns
        let urlRegex = try? NSRegularExpression(pattern: #"https?://[^\s]+"#)
        let urls1 = extractMatches(from: text1, using: urlRegex)
        let urls2 = extractMatches(from: text2, using: urlRegex)
        patterns.formUnion(urls1.intersection(urls2))
        
        // Email patterns
        let emailRegex = try? NSRegularExpression(pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)
        let emails1 = extractMatches(from: text1, using: emailRegex)
        let emails2 = extractMatches(from: text2, using: emailRegex)
        patterns.formUnion(emails1.intersection(emails2))
        
        return patterns
    }
    
    /// Helper method to extract regex matches
    func extractMatches(from text: String, using regex: NSRegularExpression?) -> Set<String> {
        guard let regex = regex else { return [] }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return Set(matches.compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        })
    }
}

// MARK: - Score Creation and Caching

private extension SimilarityEngine {
    
    /// Creates a comprehensive similarity score from all components
    func createSimilarityScore(
        source: Screenshot,
        target: Screenshot,
        textSimilarity: TextSimilarityComponents,
        visualSimilarity: VisualSimilarityComponents,
        thematicSimilarity: Double,
        temporalSimilarity: Double,
        semanticSimilarity: Double,
        processingTime: TimeInterval
    ) -> SimilarityScore {
        
        // Calculate weighted overall score
        let weights: [Double] = [0.25, 0.20, 0.15, 0.10, 0.15, 0.15]
        let overallScore = [
            textSimilarity.overall * weights[0],
            visualSimilarity.overall * weights[1],
            thematicSimilarity * weights[2],
            temporalSimilarity * weights[3],
            semanticSimilarity * weights[4],
            0.0 * weights[5] // Reserved for future expansion
        ].reduce(0, +)
        
        // Calculate confidence based on data availability
        let confidenceScore = calculateConfidenceScore(
            source: source,
            target: target,
            processingTime: processingTime
        )
        
        // Calculate quality score based on feature completeness
        let qualityScore = calculateQualityScore(
            textSimilarity: textSimilarity,
            visualSimilarity: visualSimilarity
        )
        
        return SimilarityScore(
            sourceScreenshotId: source.id,
            targetScreenshotId: target.id,
            overallScore: overallScore,
            textSimilarity: textSimilarity.overall,
            visualSimilarity: visualSimilarity.overall,
            thematicSimilarity: thematicSimilarity,
            temporalSimilarity: temporalSimilarity,
            semanticSimilarity: semanticSimilarity,
            colorSimilarity: visualSimilarity.color,
            layoutSimilarity: visualSimilarity.layout,
            compositionSimilarity: visualSimilarity.composition,
            embeddingSimilarity: textSimilarity.embedding,
            syntacticSimilarity: textSimilarity.syntactic,
            topicSimilarity: thematicSimilarity,
            entitySimilarity: textSimilarity.entity,
            confidenceScore: confidenceScore,
            processingTime: processingTime,
            qualityScore: qualityScore,
            featureCount: calculateFeatureCount(source: source, target: target)
        )
    }
    
    /// Creates cache key for similarity score storage
    func createCacheKey(source: UUID, target: UUID) -> String {
        let sorted = [source, target].sorted { $0.uuidString < $1.uuidString }
        return "\(sorted[0])_\(sorted[1])"
    }
    
    /// Calculates confidence score based on data quality and processing time
    func calculateConfidenceScore(source: Screenshot, target: Screenshot, processingTime: TimeInterval) -> Double {
        var confidence: Double = 1.0
        
        // Reduce confidence if processing took too long
        if processingTime > performanceTarget * 1000 {
            confidence *= 0.8
        }
        
        // Reduce confidence if screenshots lack text content
        if (source.extractedText?.isEmpty ?? true) || (target.extractedText?.isEmpty ?? true) {
            confidence *= 0.7
        }
        
        // Reduce confidence if visual analysis is limited
        if source.visualAttributes == nil || target.visualAttributes == nil {
            confidence *= 0.8
        }
        
        return max(confidence, 0.1) // Minimum confidence of 0.1
    }
    
    /// Calculates quality score based on feature completeness
    func calculateQualityScore(
        textSimilarity: TextSimilarityComponents,
        visualSimilarity: VisualSimilarityComponents
    ) -> Double {
        let completedFeatures = [
            textSimilarity.embedding > 0,
            textSimilarity.syntactic > 0,
            visualSimilarity.color > 0,
            visualSimilarity.layout > 0,
            visualSimilarity.composition > 0
        ].filter { $0 }.count
        
        return Double(completedFeatures) / 5.0
    }
    
    /// Calculates the number of features used in similarity calculation
    func calculateFeatureCount(source: Screenshot, target: Screenshot) -> Int {
        var count = 0
        
        if !(source.extractedText?.isEmpty ?? true) && !(target.extractedText?.isEmpty ?? true) {
            count += 3 // Text-based features
        }
        
        if source.visualAttributes != nil && target.visualAttributes != nil {
            count += 3 // Visual features
        }
        
        if !source.searchableTagNames.isEmpty && !target.searchableTagNames.isEmpty {
            count += 2 // Semantic features
        }
        
        count += 1 // Temporal feature (always available)
        
        return count
    }
    
    /// Initialize embedding provider
    func initializeEmbeddings() {
        // Embedding provider is initialized in property declaration
        // Additional setup could be done here if needed
    }
}

// MARK: - Supporting Types

struct TextSimilarityComponents {
    let embedding: Double
    let syntactic: Double
    let semantic: Double
    let entity: Double
    
    var overall: Double {
        return (embedding * 0.4 + syntactic * 0.2 + semantic * 0.2 + entity * 0.2)
    }
}

struct VisualSimilarityComponents {
    let color: Double
    let layout: Double
    let composition: Double
    
    var overall: Double {
        return (color * 0.3 + layout * 0.4 + composition * 0.3)
    }
}

// MARK: - Performance Metrics

class SimilarityPerformanceMetrics: ObservableObject {
    @Published var averageProcessingTime: TimeInterval = 0
    @Published var totalCalculations: Int = 0
    @Published var successfulCalculations: Int = 0
    @Published var performanceRating: String = "Excellent"
    
    private var processingTimes: [TimeInterval] = []
    
    func recordCalculation(duration: TimeInterval) {
        processingTimes.append(duration)
        totalCalculations += 1
        
        if duration <= 500 { // Target performance
            successfulCalculations += 1
        }
        
        // Keep only last 100 measurements for rolling average
        if processingTimes.count > 100 {
            processingTimes.removeFirst()
        }
        
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        updatePerformanceRating()
    }
    
    private func updatePerformanceRating() {
        switch averageProcessingTime {
        case 0..<100:
            performanceRating = "Excellent"
        case 100..<300:
            performanceRating = "Good"
        case 300..<500:
            performanceRating = "Acceptable"
        default:
            performanceRating = "Poor"
        }
    }
}

// MARK: - Similarity Cache

actor SimilarityCache {
    private var cache: [String: CachedSimilarityScore] = [:]
    private var hits: Int = 0
    private var requests: Int = 0
    private let maxCacheSize = 1000
    private let expirationInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    
    var hitRate: Double {
        return requests > 0 ? Double(hits) / Double(requests) : 0.0
    }
    
    func getScore(for key: String) async -> SimilarityScore? {
        requests += 1
        
        guard let cached = cache[key],
              Date().timeIntervalSince(cached.timestamp) < expirationInterval else {
            return nil
        }
        
        hits += 1
        return cached.score
    }
    
    func storeScore(_ score: SimilarityScore, for key: String) async {
        // Remove old entries if cache is full
        if cache.count >= maxCacheSize {
            let oldestKey = cache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let keyToRemove = oldestKey {
                cache.removeValue(forKey: keyToRemove)
            }
        }
        
        cache[key] = CachedSimilarityScore(score: score, timestamp: Date())
    }
    
    func clearExpiredEntries() async {
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) < expirationInterval }
    }
    
    // Return only the ID of the cached score, not the model itself
    func getScoreId(for key: String) async -> UUID? {
        guard let cached = cache[key],
              Date().timeIntervalSince(cached.timestamp) < expirationInterval else {
            return nil
        }
        return cached.score.id
    }

    // Fetch the model directly on the actor
    func getScoreDirect(for id: UUID) async -> SimilarityScore? {
        return cache.values.first(where: { $0.score.id == id })?.score
    }
}

struct CachedSimilarityScore {
    let score: SimilarityScore
    let timestamp: Date
}