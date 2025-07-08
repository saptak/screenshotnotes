import Foundation
import SwiftData

/// Comprehensive similarity score model for multi-modal content analysis
/// Sprint 7.1.1: Content Similarity Engine - Production-ready similarity detection
@Model
final class SimilarityScore: @unchecked Sendable {
    
    // MARK: - Core Properties
    
    /// Unique identifier for the similarity score
    var id: UUID = UUID()
    
    /// Source screenshot being compared
    var sourceScreenshotId: UUID
    
    /// Target screenshot being compared against
    var targetScreenshotId: UUID
    
    /// Overall combined similarity score (0.0 - 1.0)
    var overallScore: Double
    
    /// Timestamp when similarity was calculated
    var calculatedAt: Date = Date()
    
    // MARK: - Detailed Similarity Metrics
    
    /// Text-based similarity using Core ML embeddings (0.0 - 1.0)
    var textSimilarity: Double
    
    /// Visual similarity based on layout, colors, and composition (0.0 - 1.0)
    var visualSimilarity: Double
    
    /// Thematic similarity from topic modeling (0.0 - 1.0)
    var thematicSimilarity: Double
    
    /// Temporal similarity based on time proximity (0.0 - 1.0)
    var temporalSimilarity: Double
    
    /// Semantic similarity from entity extraction overlap (0.0 - 1.0)
    var semanticSimilarity: Double
    
    // MARK: - Visual Analysis Components
    
    /// Color palette similarity (0.0 - 1.0)
    var colorSimilarity: Double
    
    /// Layout structure similarity (0.0 - 1.0)
    var layoutSimilarity: Double
    
    /// Object composition similarity (0.0 - 1.0)
    var compositionSimilarity: Double
    
    /// Dominant color analysis data (JSON encoded)
    var colorAnalysisData: Data?
    
    // MARK: - Text Analysis Components
    
    /// Core ML embedding similarity (0.0 - 1.0)
    var embeddingSimilarity: Double
    
    /// Syntactic text similarity (0.0 - 1.0)
    var syntacticSimilarity: Double
    
    /// Topic modeling similarity (0.0 - 1.0)
    var topicSimilarity: Double
    
    /// Entity overlap similarity (0.0 - 1.0)
    var entitySimilarity: Double
    
    // MARK: - Confidence and Quality Metrics
    
    /// Confidence level in the similarity calculation (0.0 - 1.0)
    var confidenceScore: Double
    
    /// Processing time for similarity calculation (in milliseconds)
    var processingTime: Double
    
    /// Quality score of the comparison (0.0 - 1.0)
    var qualityScore: Double
    
    /// Number of features used in calculation
    var featureCount: Int
    
    // MARK: - Metadata
    
    /// Version of similarity algorithm used
    var algorithmVersion: String = "1.0.0"
    
    /// Additional metadata (JSON encoded)
    var metadata: Data?
    
    /// Whether this similarity score was validated by user feedback
    var isUserValidated: Bool = false
    
    /// User feedback on similarity accuracy (optional)
    var userFeedback: Double?
    
    // MARK: - Initialization
    
    init(
        sourceScreenshotId: UUID,
        targetScreenshotId: UUID,
        overallScore: Double,
        textSimilarity: Double = 0.0,
        visualSimilarity: Double = 0.0,
        thematicSimilarity: Double = 0.0,
        temporalSimilarity: Double = 0.0,
        semanticSimilarity: Double = 0.0,
        colorSimilarity: Double = 0.0,
        layoutSimilarity: Double = 0.0,
        compositionSimilarity: Double = 0.0,
        embeddingSimilarity: Double = 0.0,
        syntacticSimilarity: Double = 0.0,
        topicSimilarity: Double = 0.0,
        entitySimilarity: Double = 0.0,
        confidenceScore: Double = 1.0,
        processingTime: Double = 0.0,
        qualityScore: Double = 1.0,
        featureCount: Int = 0
    ) {
        self.sourceScreenshotId = sourceScreenshotId
        self.targetScreenshotId = targetScreenshotId
        self.overallScore = overallScore
        self.textSimilarity = textSimilarity
        self.visualSimilarity = visualSimilarity
        self.thematicSimilarity = thematicSimilarity
        self.temporalSimilarity = temporalSimilarity
        self.semanticSimilarity = semanticSimilarity
        self.colorSimilarity = colorSimilarity
        self.layoutSimilarity = layoutSimilarity
        self.compositionSimilarity = compositionSimilarity
        self.embeddingSimilarity = embeddingSimilarity
        self.syntacticSimilarity = syntacticSimilarity
        self.topicSimilarity = topicSimilarity
        self.entitySimilarity = entitySimilarity
        self.confidenceScore = confidenceScore
        self.processingTime = processingTime
        self.qualityScore = qualityScore
        self.featureCount = featureCount
    }
}

// MARK: - Computed Properties

extension SimilarityScore {
    
    /// Categorizes similarity level based on overall score
    var similarityLevel: SimilarityLevel {
        switch overallScore {
        case 0.85...1.0:
            return .veryHigh
        case 0.7..<0.85:
            return .high
        case 0.5..<0.7:
            return .medium
        case 0.3..<0.5:
            return .low
        default:
            return .veryLow
        }
    }
    
    /// Determines if screenshots are considered similar based on threshold
    var areSimilar: Bool {
        return overallScore >= 0.7 // As specified in integration test
    }
    
    /// Weighted average of all similarity components
    var weightedScore: Double {
        let weights: [Double] = [
            textSimilarity * 0.25,
            visualSimilarity * 0.20,
            thematicSimilarity * 0.15,
            temporalSimilarity * 0.10,
            semanticSimilarity * 0.15,
            colorSimilarity * 0.05,
            layoutSimilarity * 0.05,
            compositionSimilarity * 0.05
        ]
        return weights.reduce(0, +)
    }
    
    /// Performance rating based on processing time
    var performanceRating: PerformanceRating {
        switch processingTime {
        case 0..<100:
            return .excellent
        case 100..<300:
            return .good
        case 300..<500:
            return .acceptable
        default:
            return .poor
        }
    }
}

// MARK: - Supporting Enums

enum SimilarityLevel: String, CaseIterable {
    case veryHigh = "Very High"
    case high = "High" 
    case medium = "Medium"
    case low = "Low"
    case veryLow = "Very Low"
    
    var color: String {
        switch self {
        case .veryHigh: return "green"
        case .high: return "blue"
        case .medium: return "orange"
        case .low: return "red"
        case .veryLow: return "gray"
        }
    }
}

enum PerformanceRating: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case acceptable = "Acceptable"
    case poor = "Poor"
    
    var threshold: Double {
        switch self {
        case .excellent: return 100
        case .good: return 300
        case .acceptable: return 500
        case .poor: return Double.infinity
        }
    }
}

// MARK: - Comparison Utilities

extension SimilarityScore {
    
    /// Creates a comparison key for caching purposes
    func comparisonKey() -> String {
        let sorted = [sourceScreenshotId, targetScreenshotId].sorted { $0.uuidString < $1.uuidString }
        return "\(sorted[0])_\(sorted[1])"
    }
    
    /// Validates that all similarity scores are within valid range [0.0, 1.0]
    func isValid() -> Bool {
        let scores = [
            overallScore, textSimilarity, visualSimilarity, thematicSimilarity,
            temporalSimilarity, semanticSimilarity, colorSimilarity, layoutSimilarity,
            compositionSimilarity, embeddingSimilarity, syntacticSimilarity,
            topicSimilarity, entitySimilarity, confidenceScore, qualityScore
        ]
        return scores.allSatisfy { $0 >= 0.0 && $0 <= 1.0 }
    }
    
    /// Exports similarity data for analysis and debugging
    func exportAnalysisData() -> [String: Any] {
        return [
            "id": id.uuidString,
            "source": sourceScreenshotId.uuidString,
            "target": targetScreenshotId.uuidString,
            "overall": overallScore,
            "text": textSimilarity,
            "visual": visualSimilarity,
            "thematic": thematicSimilarity,
            "temporal": temporalSimilarity,
            "semantic": semanticSimilarity,
            "confidence": confidenceScore,
            "processing_time": processingTime,
            "quality": qualityScore,
            "level": similarityLevel.rawValue,
            "performance": performanceRating.rawValue,
            "algorithm_version": algorithmVersion,
            "calculated_at": calculatedAt.ISO8601Format()
        ]
    }
}

// MARK: - Statistical Analysis

extension SimilarityScore {
    
    /// Calculates statistical summary for a collection of similarity scores
    static func statisticalSummary(for scores: [SimilarityScore]) -> SimilarityStatistics {
        guard !scores.isEmpty else {
            return SimilarityStatistics(
                count: 0, mean: 0, median: 0, standardDeviation: 0,
                minimum: 0, maximum: 0, q1: 0, q3: 0
            )
        }
        
        let overallScores = scores.map { $0.overallScore }.sorted()
        let count = scores.count
        let mean = overallScores.reduce(0, +) / Double(count)
        let median = count % 2 == 0 ? 
            (overallScores[count/2 - 1] + overallScores[count/2]) / 2 :
            overallScores[count/2]
        
        let variance = overallScores.reduce(0) { $0 + pow($1 - mean, 2) } / Double(count)
        let standardDeviation = sqrt(variance)
        
        let q1Index = count / 4
        let q3Index = 3 * count / 4
        
        return SimilarityStatistics(
            count: count,
            mean: mean,
            median: median,
            standardDeviation: standardDeviation,
            minimum: overallScores.first ?? 0,
            maximum: overallScores.last ?? 0,
            q1: overallScores[q1Index],
            q3: overallScores[q3Index]
        )
    }
}

struct SimilarityStatistics {
    let count: Int
    let mean: Double
    let median: Double
    let standardDeviation: Double
    let minimum: Double
    let maximum: Double
    let q1: Double
    let q3: Double
}