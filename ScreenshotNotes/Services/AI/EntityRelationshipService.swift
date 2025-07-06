import Foundation
import SwiftData
import NaturalLanguage
import os.log

/// Service for discovering and analyzing relationships between screenshots based on shared entities
@MainActor
class EntityRelationshipService: ObservableObject {
    static let shared = EntityRelationshipService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "EntityRelationship")
    private let entityExtractionService = EntityExtractionService()
    private var relationshipCache: [String: [Relationship]] = [:]
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    // MARK: - Performance Metrics
    
    @Published var processingMetrics = ProcessingMetrics()
    
    struct ProcessingMetrics {
        var relationshipsFound: Int = 0
        var processingTime: TimeInterval = 0
        var confidence: Double = 0
        var cacheHitRate: Double = 0
        var lastUpdated: Date = Date()
    }
    
    private init() {
        logger.info("🔗 EntityRelationshipService initialized")
    }
    
    // MARK: - Main API
    
    /// Discover relationships between all screenshots
    func discoverRelationships(screenshots: [Screenshot]) async -> [Relationship] {
        let startTime = Date()
        logger.info("🔍 Starting relationship discovery for \(screenshots.count) screenshots")
        
        // Memory pressure check - if we have too many screenshots, process in smaller batches
        let effectiveScreenshots: [Screenshot]
        if screenshots.count > 20 { // Reduced from 30 to 20
            logger.warning("⚠️ Large dataset detected (\(screenshots.count) screenshots). Processing first 20 to prevent memory issues.")
            effectiveScreenshots = Array(screenshots.prefix(20))
        } else {
            effectiveScreenshots = screenshots
        }
        
        // Check cache first
        let cacheKey = generateCacheKey(screenshots: effectiveScreenshots)
        if let cachedRelationships = getCachedRelationships(key: cacheKey) {
            logger.info("📦 Using cached relationships: \(cachedRelationships.count)")
            await updateMetrics(
                relationshipsFound: cachedRelationships.count,
                processingTime: Date().timeIntervalSince(startTime),
                confidence: calculateAverageConfidence(cachedRelationships),
                cacheHit: true
            )
            return cachedRelationships
        }
        
        var allRelationships: [Relationship] = []
        
        // Discover entity-based relationships
        let entityRelationships = await discoverEntityBasedRelationships(screenshots: effectiveScreenshots)
        allRelationships.append(contentsOf: entityRelationships)
        
        // Discover temporal relationships
        let temporalRelationships = await discoverTemporalRelationships(screenshots: effectiveScreenshots)
        allRelationships.append(contentsOf: temporalRelationships)
        
        // Discover content similarity relationships (limited to prevent memory issues)
        if effectiveScreenshots.count <= 15 {
            let contentRelationships = await discoverContentSimilarityRelationships(screenshots: effectiveScreenshots)
            allRelationships.append(contentsOf: contentRelationships)
        } else {
            logger.info("⏭️ Skipping content similarity analysis for large dataset to conserve memory")
        }
        
        // Remove duplicates and weak relationships
        let filteredRelationships = filterAndRankRelationships(allRelationships)
        
        // Cache results
        cacheRelationships(key: cacheKey, relationships: filteredRelationships)
        
        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("✅ Relationship discovery completed: \(filteredRelationships.count) relationships in \(String(format: "%.2f", processingTime))s")
        
        await updateMetrics(
            relationshipsFound: filteredRelationships.count,
            processingTime: processingTime,
            confidence: calculateAverageConfidence(filteredRelationships),
            cacheHit: false
        )
        
        return filteredRelationships
    }
    
    /// Find related screenshots for a specific screenshot
    func findRelatedScreenshots(for screenshot: Screenshot, in allScreenshots: [Screenshot]) async -> [Relationship] {
        let startTime = Date()
        
        var relationships: [Relationship] = []
        
        // Entity-based relationships
        if let extractedText = screenshot.extractedText {
            let entityResult = await entityExtractionService.extractEntities(from: extractedText)
            
            for otherScreenshot in allScreenshots {
                guard otherScreenshot.id != screenshot.id else { continue }
                
                if let otherText = otherScreenshot.extractedText {
                    let otherEntityResult = await entityExtractionService.extractEntities(from: otherText)
                    let similarity = calculateEntitySimilarity(entityResult, otherEntityResult)
                    
                    if similarity.score > 0.3 {
                        let relationship = Relationship(
                            id: UUID(),
                            sourceScreenshotId: screenshot.id,
                            targetScreenshotId: otherScreenshot.id,
                            type: .entityBased,
                            strength: similarity.score,
                            confidence: similarity.confidence,
                            sharedEntities: similarity.sharedEntities,
                            timestamp: Date()
                        )
                        relationships.append(relationship)
                    }
                }
            }
        }
        
        // Temporal relationships
        let temporalRelationships = findTemporalRelationships(for: screenshot, in: allScreenshots)
        relationships.append(contentsOf: temporalRelationships)
        
        let processingTime = Date().timeIntervalSince(startTime)
        logger.debug("Found \(relationships.count) relationships for screenshot in \(processingTime)s")
        
        return relationships.sorted { $0.strength > $1.strength }
    }
    
    // MARK: - Entity-Based Relationship Discovery
    
    private func discoverEntityBasedRelationships(screenshots: [Screenshot]) async -> [Relationship] {
        logger.info("🏷️ Discovering entity-based relationships")
        var relationships: [Relationship] = []
        
        // More aggressive memory optimization: smaller batches and faster processing
        let batchSize = 5 // Reduced from 8 to 5 screenshots at a time
        let batches = screenshots.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            logger.debug("Processing batch \(batchIndex + 1)/\(batches.count) (\(batch.count) screenshots)")
            
            // Extract entities for current batch only
            var batchEntities: [UUID: EntityExtractionResult] = [:]
            
            for (index, screenshot) in batch.enumerated() {
                if let extractedText = screenshot.extractedText {
                    // Skip very long texts to prevent processing delays
                    let processText = extractedText.count > 2000 ? String(extractedText.prefix(2000)) : extractedText
                    let entityResult = await entityExtractionService.extractEntities(from: processText)
                    batchEntities[screenshot.id] = entityResult
                }
                
                // More frequent yielding for responsiveness
                if index % 2 == 0 {
                    await Task.yield() // Allow other tasks to run
                }
            }
            
            // Compare within batch (smaller O(n²) operation)
            for i in 0..<batch.count {
                for j in (i+1)..<batch.count {
                    let screenshot1 = batch[i]
                    let screenshot2 = batch[j]
                    
                    guard let entities1 = batchEntities[screenshot1.id],
                          let entities2 = batchEntities[screenshot2.id] else { continue }
                    
                    let similarity = calculateEntitySimilarity(entities1, entities2)
                    
                    if similarity.score > 0.4 { // Increased threshold to reduce low-quality relationships
                        let relationship = Relationship(
                            id: UUID(),
                            sourceScreenshotId: screenshot1.id,
                            targetScreenshotId: screenshot2.id,
                            type: .entityBased,
                            strength: similarity.score,
                            confidence: similarity.confidence,
                            sharedEntities: similarity.sharedEntities,
                            timestamp: Date()
                        )
                        relationships.append(relationship)
                    }
                }
            }
            
            // Simplified cross-batch comparison - only with immediate previous batch
            if batchIndex > 0 {
                let prevBatch = batches[batchIndex - 1]
                
                for screenshot1 in batch {
                    guard let entities1 = batchEntities[screenshot1.id] else { continue }
                    
                    // Only compare with first few screenshots from previous batch to limit processing
                    for screenshot2 in prevBatch.prefix(3) {
                        if let extractedText2 = screenshot2.extractedText {
                            // Extract entities on-demand for cross-batch comparison
                            let processText2 = extractedText2.count > 2000 ? String(extractedText2.prefix(2000)) : extractedText2
                            let entities2 = await entityExtractionService.extractEntities(from: processText2)
                            
                            let similarity = calculateEntitySimilarity(entities1, entities2)
                            
                            if similarity.score > 0.4 { // Higher threshold for cross-batch
                                let relationship = Relationship(
                                    id: UUID(),
                                    sourceScreenshotId: screenshot1.id,
                                    targetScreenshotId: screenshot2.id,
                                    type: .entityBased,
                                    strength: similarity.score,
                                    confidence: similarity.confidence,
                                    sharedEntities: similarity.sharedEntities,
                                    timestamp: Date()
                                )
                                relationships.append(relationship)
                            }
                        }
                    }
                }
            }
            
            // Clear batch entities to free memory
            batchEntities.removeAll()
            
            // More aggressive memory cleanup between every batch
            await Task.yield()
            entityExtractionService.clearCache()
            
            // Break early if we already have enough relationships to prevent excessive processing
            if relationships.count > 50 {
                logger.info("⏭️ Early termination: Found sufficient relationships (\(relationships.count))")
                break
            }
        }
        
        logger.info("Found \(relationships.count) entity-based relationships")
        return relationships
    }
    
    // MARK: - Temporal Relationship Discovery
    
    private func discoverTemporalRelationships(screenshots: [Screenshot]) async -> [Relationship] {
        logger.info("⏰ Discovering temporal relationships")
        var relationships: [Relationship] = []
        
        let sortedScreenshots = screenshots.sorted { $0.timestamp < $1.timestamp }
        
        for i in 0..<sortedScreenshots.count {
            for j in (i+1)..<sortedScreenshots.count {
                let screenshot1 = sortedScreenshots[i]
                let screenshot2 = sortedScreenshots[j]
                
                let timeDifference = screenshot2.timestamp.timeIntervalSince(screenshot1.timestamp)
                let temporalScore = calculateTemporalScore(timeDifference: timeDifference)
                
                if temporalScore > 0.3 {
                    let relationship = Relationship(
                        id: UUID(),
                        sourceScreenshotId: screenshot1.id,
                        targetScreenshotId: screenshot2.id,
                        type: .temporal,
                        strength: temporalScore,
                        confidence: 0.9, // High confidence for temporal relationships
                        sharedEntities: [],
                        timestamp: Date()
                    )
                    relationships.append(relationship)
                }
                
                // Break if time difference is too large
                if timeDifference > 86400 { // 24 hours
                    break
                }
            }
        }
        
        logger.info("Found \(relationships.count) temporal relationships")
        return relationships
    }
    
    private func findTemporalRelationships(for screenshot: Screenshot, in allScreenshots: [Screenshot]) -> [Relationship] {
        var relationships: [Relationship] = []
        
        for otherScreenshot in allScreenshots {
            guard otherScreenshot.id != screenshot.id else { continue }
            
            let timeDifference = abs(screenshot.timestamp.timeIntervalSince(otherScreenshot.timestamp))
            let temporalScore = calculateTemporalScore(timeDifference: timeDifference)
            
            if temporalScore > 0.3 {
                let relationship = Relationship(
                    id: UUID(),
                    sourceScreenshotId: screenshot.id,
                    targetScreenshotId: otherScreenshot.id,
                    type: .temporal,
                    strength: temporalScore,
                    confidence: 0.9,
                    sharedEntities: [],
                    timestamp: Date()
                )
                relationships.append(relationship)
            }
        }
        
        return relationships
    }
    
    // MARK: - Content Similarity Discovery
    
    private func discoverContentSimilarityRelationships(screenshots: [Screenshot]) async -> [Relationship] {
        logger.info("📄 Discovering content similarity relationships")
        var relationships: [Relationship] = []
        
        for i in 0..<screenshots.count {
            for j in (i+1)..<screenshots.count {
                let screenshot1 = screenshots[i]
                let screenshot2 = screenshots[j]
                
                let contentSimilarity = calculateContentSimilarity(screenshot1, screenshot2)
                
                if contentSimilarity > 0.4 {
                    let relationship = Relationship(
                        id: UUID(),
                        sourceScreenshotId: screenshot1.id,
                        targetScreenshotId: screenshot2.id,
                        type: .thematic,
                        strength: contentSimilarity,
                        confidence: 0.7,
                        sharedEntities: [],
                        timestamp: Date()
                    )
                    relationships.append(relationship)
                }
            }
        }
        
        logger.info("Found \(relationships.count) content similarity relationships")
        return relationships
    }
    
    // MARK: - Similarity Calculations
    
    private func calculateEntitySimilarity(_ entities1: EntityExtractionResult, _ entities2: EntityExtractionResult) -> EntitySimilarity {
        var sharedEntities: [String] = []
        var totalScore: Double = 0
        var matchCount = 0
        
        for entity1 in entities1.entities {
            for entity2 in entities2.entities {
                if entity1.type == entity2.type {
                    let similarity = calculateStringSimilarity(entity1.normalizedValue, entity2.normalizedValue)
                    
                    if similarity > 0.8 {
                        sharedEntities.append(entity1.normalizedValue)
                        totalScore += similarity * entity1.confidence.rawValue * entity2.confidence.rawValue
                        matchCount += 1
                    }
                }
            }
        }
        
        let averageScore = matchCount > 0 ? totalScore / Double(matchCount) : 0
        let normalizedScore = min(1.0, averageScore * Double(sharedEntities.count) / 5.0)
        
        return EntitySimilarity(
            score: normalizedScore,
            confidence: averageScore,
            sharedEntities: sharedEntities
        )
    }
    
    private func calculateTemporalScore(timeDifference: TimeInterval) -> Double {
        // Temporal scoring based on time proximity
        switch timeDifference {
        case 0..<300: // 5 minutes
            return 1.0
        case 300..<1800: // 30 minutes
            return 0.8
        case 1800..<3600: // 1 hour
            return 0.6
        case 3600..<14400: // 4 hours
            return 0.4
        case 14400..<86400: // 24 hours
            return 0.2
        default:
            return 0.0
        }
    }
    
    private func calculateContentSimilarity(_ screenshot1: Screenshot, _ screenshot2: Screenshot) -> Double {
        let text1 = screenshot1.extractedText ?? ""
        let text2 = screenshot2.extractedText ?? ""
        
        if text1.isEmpty || text2.isEmpty {
            return 0.0
        }
        
        // Use NLDistance for semantic similarity
        let distance = text1.distance(to: text2)
        let maxLength = max(text1.count, text2.count)
        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        
        return max(0.0, similarity)
    }
    
    private func calculateStringSimilarity(_ string1: String, _ string2: String) -> Double {
        let distance = string1.distance(to: string2)
        let maxLength = max(string1.count, string2.count)
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    // MARK: - Relationship Filtering and Ranking
    
    private func filterAndRankRelationships(_ relationships: [Relationship]) -> [Relationship] {
        // Remove weak relationships
        let strongRelationships = relationships.filter { $0.strength > 0.3 && $0.confidence > 0.5 }
        
        // Group by screenshot pairs to avoid duplicates
        var bestRelationships: [String: Relationship] = [:]
        
        for relationship in strongRelationships {
            let key = relationshipKey(relationship.sourceScreenshotId, relationship.targetScreenshotId)
            
            if let existing = bestRelationships[key] {
                if relationship.strength > existing.strength {
                    bestRelationships[key] = relationship
                }
            } else {
                bestRelationships[key] = relationship
            }
        }
        
        return Array(bestRelationships.values).sorted { $0.strength > $1.strength }
    }
    
    private func relationshipKey(_ id1: UUID, _ id2: UUID) -> String {
        let sortedIds = [id1.uuidString, id2.uuidString].sorted()
        return "\(sortedIds[0])-\(sortedIds[1])"
    }
    
    // MARK: - Caching
    
    private func generateCacheKey(screenshots: [Screenshot]) -> String {
        let ids = screenshots.map { $0.id.uuidString }.sorted()
        return ids.joined(separator: "-").data(using: .utf8)?.base64EncodedString() ?? "default"
    }
    
    private func getCachedRelationships(key: String) -> [Relationship]? {
        return relationshipCache[key]
    }
    
    private func cacheRelationships(key: String, relationships: [Relationship]) {
        relationshipCache[key] = relationships
        
        // Clean old cache entries
        if relationshipCache.count > 10 {
            let oldestKey = relationshipCache.keys.randomElement()
            if let key = oldestKey {
                relationshipCache.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Metrics
    
    private func updateMetrics(relationshipsFound: Int, processingTime: TimeInterval, confidence: Double, cacheHit: Bool) async {
        await MainActor.run {
            processingMetrics.relationshipsFound = relationshipsFound
            processingMetrics.processingTime = processingTime
            processingMetrics.confidence = confidence
            processingMetrics.cacheHitRate = cacheHit ? 1.0 : 0.0
            processingMetrics.lastUpdated = Date()
        }
    }
    
    private func calculateAverageConfidence(_ relationships: [Relationship]) -> Double {
        guard !relationships.isEmpty else { return 0.0 }
        let totalConfidence = relationships.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Double(relationships.count)
    }
}

// MARK: - Supporting Types

struct Relationship: Identifiable, Codable {
    let id: UUID
    let sourceScreenshotId: UUID
    let targetScreenshotId: UUID
    let type: RelationshipType
    let strength: Double
    let confidence: Double
    let sharedEntities: [String]
    let timestamp: Date
    
    var displayStrength: String {
        let percentage = Int(strength * 100)
        return "\(percentage)%"
    }
    
    var strengthCategory: String {
        switch strength {
        case 0.8...1.0: return "Very Strong"
        case 0.6..<0.8: return "Strong"
        case 0.4..<0.6: return "Moderate"
        case 0.2..<0.4: return "Weak"
        default: return "Very Weak"
        }
    }
}

private struct EntitySimilarity {
    let score: Double
    let confidence: Double
    let sharedEntities: [String]
}

// MARK: - String Distance Extension

extension String {
    func distance(to other: String) -> Int {
        let m = self.count
        let n = other.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        let selfArray = Array(self)
        let otherArray = Array(other)
        
        for i in 1...m {
            for j in 1...n {
                let cost = selfArray[i-1] == otherArray[j-1] ? 0 : 1
                matrix[i][j] = Swift.min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
}