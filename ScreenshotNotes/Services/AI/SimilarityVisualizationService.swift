import Foundation
import SwiftUI
import Charts

/// Advanced Similarity Visualization Service for debugging and user insights
/// Sprint 7.1.1: Production-ready similarity analysis visualization and debugging tools
@MainActor
final class SimilarityVisualizationService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SimilarityVisualizationService()
    
    // MARK: - State
    @Published var isGenerating = false
    @Published var visualizationProgress: Double = 0.0
    
    // MARK: - Configuration
    private let maxDataPoints = 100
    private let colorScheme: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .cyan]
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Creates a comprehensive similarity analysis visualization
    /// - Parameter scores: Array of similarity scores to visualize
    /// - Returns: Similarity visualization data for charts and insights
    func createSimilarityVisualization(scores: [SimilarityScore]) async -> SimilarityVisualizationData {
        isGenerating = true
        visualizationProgress = 0.0
        
        defer {
            isGenerating = false
            visualizationProgress = 1.0
        }
        
        // Generate distribution analysis
        visualizationProgress = 0.2
        let distribution = generateDistributionAnalysis(scores)
        
        // Generate component breakdown
        visualizationProgress = 0.4
        let componentBreakdown = generateComponentBreakdown(scores)
        
        // Generate similarity clusters
        visualizationProgress = 0.6
        let clusters = generateSimilarityClusters(scores)
        
        // Generate performance insights
        visualizationProgress = 0.8
        let performance = generatePerformanceInsights(scores)
        
        // Generate recommendations
        let recommendations = generateInsightRecommendations(scores, clusters: clusters)
        
        return SimilarityVisualizationData(
            distribution: distribution,
            componentBreakdown: componentBreakdown,
            clusters: clusters,
            performance: performance,
            recommendations: recommendations,
            summary: generateSummaryStatistics(scores)
        )
    }
    
    /// Creates a radar chart visualization for similarity components
    /// - Parameter score: Individual similarity score to visualize
    /// - Returns: Radar chart data for component analysis
    func createRadarChartData(for score: SimilarityScore) -> RadarChartData {
        let components = [
            RadarComponent(name: "Text", value: score.textSimilarity, color: .blue),
            RadarComponent(name: "Visual", value: score.visualSimilarity, color: .green),
            RadarComponent(name: "Thematic", value: score.thematicSimilarity, color: .orange),
            RadarComponent(name: "Temporal", value: score.temporalSimilarity, color: .red),
            RadarComponent(name: "Semantic", value: score.semanticSimilarity, color: .purple)
        ]
        
        return RadarChartData(
            components: components,
            overallScore: score.overallScore,
            confidenceScore: score.confidenceScore
        )
    }
    
    /// Creates a heatmap visualization for similarity matrices
    /// - Parameter scores: Array of similarity scores
    /// - Returns: Heatmap data for similarity matrix visualization
    func createSimilarityHeatmap(scores: [SimilarityScore]) -> SimilarityHeatmapData {
        // Group scores by source-target pairs
        let scoreGroups = Dictionary(grouping: scores) { score in
            "\(score.sourceScreenshotId)_\(score.targetScreenshotId)"
        }
        
        var heatmapCells: [HeatmapCell] = []
        var uniqueScreenshots = Set<UUID>()
        
        for score in scores {
            uniqueScreenshots.insert(score.sourceScreenshotId)
            uniqueScreenshots.insert(score.targetScreenshotId)
        }
        
        let screenshotArray = Array(uniqueScreenshots).sorted { $0.uuidString < $1.uuidString }
        
        for (i, sourceId) in screenshotArray.enumerated() {
            for (j, targetId) in screenshotArray.enumerated() {
                let key = "\(sourceId)_\(targetId)"
                let reverseKey = "\(targetId)_\(sourceId)"
                
                let similarity: Double
                if sourceId == targetId {
                    similarity = 1.0 // Perfect self-similarity
                } else if let score = scoreGroups[key]?.first {
                    similarity = score.overallScore
                } else if let score = scoreGroups[reverseKey]?.first {
                    similarity = score.overallScore
                } else {
                    similarity = 0.0 // No similarity calculated
                }
                
                heatmapCells.append(HeatmapCell(
                    row: i,
                    column: j,
                    value: similarity,
                    sourceId: sourceId,
                    targetId: targetId
                ))
            }
        }
        
        return SimilarityHeatmapData(
            cells: heatmapCells,
            screenshots: screenshotArray,
            maxSimilarity: heatmapCells.map { $0.value }.max() ?? 1.0,
            minSimilarity: heatmapCells.map { $0.value }.min() ?? 0.0
        )
    }
    
    /// Creates performance benchmarking visualization
    /// - Parameter scores: Array of similarity scores with performance data
    /// - Returns: Performance benchmark data for analysis
    func createPerformanceBenchmark(scores: [SimilarityScore]) -> PerformanceBenchmarkData {
        let processingTimes = scores.map { $0.processingTime }
        let qualityScores = scores.map { $0.qualityScore }
        let confidenceScores = scores.map { $0.confidenceScore }
        
        return PerformanceBenchmarkData(
            averageProcessingTime: processingTimes.reduce(0, +) / Double(processingTimes.count),
            maxProcessingTime: processingTimes.max() ?? 0,
            minProcessingTime: processingTimes.min() ?? 0,
            averageQuality: qualityScores.reduce(0, +) / Double(qualityScores.count),
            averageConfidence: confidenceScores.reduce(0, +) / Double(confidenceScores.count),
            performanceDistribution: createPerformanceDistribution(processingTimes),
            qualityDistribution: createQualityDistribution(qualityScores)
        )
    }
}

// MARK: - Private Implementation

private extension SimilarityVisualizationService {
    
    /// Generate distribution analysis for similarity scores
    func generateDistributionAnalysis(_ scores: [SimilarityScore]) -> DistributionAnalysis {
        let overallScores = scores.map { $0.overallScore }
        let bins = createHistogramBins(overallScores, binCount: 10)
        
        return DistributionAnalysis(
            histogram: bins,
            mean: overallScores.reduce(0, +) / Double(overallScores.count),
            median: calculateMedian(overallScores),
            standardDeviation: calculateStandardDeviation(overallScores),
            skewness: calculateSkewness(overallScores)
        )
    }
    
    /// Generate component breakdown analysis
    func generateComponentBreakdown(_ scores: [SimilarityScore]) -> ComponentBreakdown {
        let componentData = [
            ComponentData(name: "Text", average: scores.map { $0.textSimilarity }.reduce(0, +) / Double(scores.count), color: .blue),
            ComponentData(name: "Visual", average: scores.map { $0.visualSimilarity }.reduce(0, +) / Double(scores.count), color: .green),
            ComponentData(name: "Thematic", average: scores.map { $0.thematicSimilarity }.reduce(0, +) / Double(scores.count), color: .orange),
            ComponentData(name: "Temporal", average: scores.map { $0.temporalSimilarity }.reduce(0, +) / Double(scores.count), color: .red),
            ComponentData(name: "Semantic", average: scores.map { $0.semanticSimilarity }.reduce(0, +) / Double(scores.count), color: .purple)
        ]
        
        return ComponentBreakdown(
            components: componentData,
            correlationMatrix: calculateCorrelationMatrix(scores)
        )
    }
    
    /// Generate similarity clusters using k-means approximation
    func generateSimilarityClusters(_ scores: [SimilarityScore]) -> [SimilarityCluster] {
        let clusterCount = min(5, max(2, scores.count / 10))
        var clusters: [SimilarityCluster] = []
        
        // Simple clustering based on overall similarity ranges
        let sortedScores = scores.sorted { $0.overallScore < $1.overallScore }
        let chunkSize = sortedScores.count / clusterCount
        
        for i in 0..<clusterCount {
            let start = i * chunkSize
            let end = min((i + 1) * chunkSize, sortedScores.count)
            let clusterScores = Array(sortedScores[start..<end])
            
            if !clusterScores.isEmpty {
                let averageScore = clusterScores.map { $0.overallScore }.reduce(0, +) / Double(clusterScores.count)
                
                clusters.append(SimilarityCluster(
                    id: i,
                    name: clusterNameForScore(averageScore),
                    scores: clusterScores,
                    averageSimilarity: averageScore,
                    size: clusterScores.count,
                    color: colorScheme[i % colorScheme.count]
                ))
            }
        }
        
        return clusters
    }
    
    /// Generate performance insights
    func generatePerformanceInsights(_ scores: [SimilarityScore]) -> PerformanceInsights {
    let processingTimes = scores.map { $0.processingTime }

    let slowScores = scores.filter { $0.processingTime > 500 }
    let fastScores = scores.filter { $0.processingTime <= 200 }
    let highQualityScores = scores.filter { $0.qualityScore > 0.8 }
        
        return PerformanceInsights(
            averageProcessingTime: processingTimes.reduce(0, +) / Double(processingTimes.count),
            slowCalculations: slowScores.count,
            fastCalculations: fastScores.count,
            highQualityCalculations: highQualityScores.count,
            performanceRating: calculatePerformanceRating(processingTimes),
            bottlenecks: identifyBottlenecks(scores)
        )
    }
    
    /// Generate insight recommendations
    func generateInsightRecommendations(_ scores: [SimilarityScore], clusters: [SimilarityCluster]) -> [InsightRecommendation] {
        var recommendations: [InsightRecommendation] = []
        
        // Performance recommendations
        let slowScores = scores.filter { $0.processingTime > 500 }
        if slowScores.count > scores.count / 4 {
            recommendations.append(InsightRecommendation(
                type: .performance,
                title: "Performance Optimization Needed",
                description: "\\(slowScores.count) calculations exceeded 500ms target",
                impact: .high,
                action: "Consider optimizing visual analysis pipeline"
            ))
        }
        
        // Quality recommendations
        let lowQualityScores = scores.filter { $0.qualityScore < 0.5 }
        if !lowQualityScores.isEmpty {
            recommendations.append(InsightRecommendation(
                type: .quality,
                title: "Low Quality Calculations Detected",
                description: "\\(lowQualityScores.count) calculations have low quality scores",
                impact: .medium,
                action: "Review feature completeness for these comparisons"
            ))
        }
        
        // Clustering insights
        if clusters.count > 2 {
            let dominantCluster = clusters.max { $0.size < $1.size }
            if let cluster = dominantCluster, cluster.size > scores.count / 2 {
                recommendations.append(InsightRecommendation(
                    type: .insight,
                    title: "Dominant Similarity Pattern",
                    description: "\\(cluster.size) screenshots show \\(cluster.name) similarity",
                    impact: .low,
                    action: "Consider grouping these screenshots automatically"
                ))
            }
        }
        
        return recommendations
    }
    
    /// Generate summary statistics
    func generateSummaryStatistics(_ scores: [SimilarityScore]) -> SummaryStatistics {
        let overallScores = scores.map { $0.overallScore }
        let similarPairs = scores.filter { $0.areSimilar }.count
        
        return SummaryStatistics(
            totalComparisons: scores.count,
            similarPairs: similarPairs,
            similarityRate: Double(similarPairs) / Double(scores.count),
            averageSimilarity: overallScores.reduce(0, +) / Double(overallScores.count),
            highestSimilarity: overallScores.max() ?? 0,
            lowestSimilarity: overallScores.min() ?? 0
        )
    }
    
    /// Helper methods for statistical calculations
    func createHistogramBins(_ values: [Double], binCount: Int) -> [HistogramBin] {
        guard !values.isEmpty else { return [] }
        
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let binWidth = (maxValue - minValue) / Double(binCount)
        
        var bins: [HistogramBin] = []
        
        for i in 0..<binCount {
            let binStart = minValue + Double(i) * binWidth
            let binEnd = binStart + binWidth
            let count = values.filter { $0 >= binStart && $0 < binEnd }.count
            
            bins.append(HistogramBin(
                range: binStart...binEnd,
                count: count,
                frequency: Double(count) / Double(values.count)
            ))
        }
        
        return bins
    }
    
    func calculateMedian(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            return (sorted[count/2 - 1] + sorted[count/2]) / 2
        } else {
            return sorted[count/2]
        }
    }
    
    func calculateStandardDeviation(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance)
    }
    
    func calculateSkewness(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let std = calculateStandardDeviation(values)
        let skewness = values.reduce(0) { $0 + pow(($1 - mean) / std, 3) } / Double(values.count)
        return skewness
    }
    
    func calculateCorrelationMatrix(_ scores: [SimilarityScore]) -> [[Double]] {
        let components = [
            scores.map { $0.textSimilarity },
            scores.map { $0.visualSimilarity },
            scores.map { $0.thematicSimilarity },
            scores.map { $0.temporalSimilarity },
            scores.map { $0.semanticSimilarity }
        ]
        
        var matrix: [[Double]] = []
        
        for i in 0..<components.count {
            var row: [Double] = []
            for j in 0..<components.count {
                row.append(calculateCorrelation(components[i], components[j]))
            }
            matrix.append(row)
        }
        
        return matrix
    }
    
    func calculateCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count && !x.isEmpty else { return 0 }
        
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        
        let numerator = zip(x, y).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let denomX = sqrt(x.reduce(0) { $0 + pow($1 - meanX, 2) })
        let denomY = sqrt(y.reduce(0) { $0 + pow($1 - meanY, 2) })
        
        return denomX * denomY > 0 ? numerator / (denomX * denomY) : 0
    }
    
    func clusterNameForScore(_ score: Double) -> String {
        switch score {
        case 0.85...1.0: return "Very High Similarity"
        case 0.7..<0.85: return "High Similarity"
        case 0.5..<0.7: return "Medium Similarity"
        case 0.3..<0.5: return "Low Similarity"
        default: return "Very Low Similarity"
        }
    }
    
    func calculatePerformanceRating(_ times: [Double]) -> String {
        let average = times.reduce(0, +) / Double(times.count)
        switch average {
        case 0..<100: return "Excellent"
        case 100..<300: return "Good"
        case 300..<500: return "Acceptable"
        default: return "Poor"
        }
    }
    
    func identifyBottlenecks(_ scores: [SimilarityScore]) -> [String] {
        var bottlenecks: [String] = []
        
        let slowScores = scores.filter { $0.processingTime > 500 }
        let lowQualityScores = scores.filter { $0.qualityScore < 0.5 }
        let lowConfidenceScores = scores.filter { $0.confidenceScore < 0.7 }
        
        if slowScores.count > scores.count / 10 {
            bottlenecks.append("Processing time exceeds target")
        }
        
        if lowQualityScores.count > scores.count / 10 {
            bottlenecks.append("Feature extraction incomplete")
        }
        
        if lowConfidenceScores.count > scores.count / 10 {
            bottlenecks.append("Low confidence in calculations")
        }
        
        return bottlenecks
    }
    
    func createPerformanceDistribution(_ times: [Double]) -> [PerformanceBucket] {
        let buckets = [
            (0..<100, "Excellent"),
            (100..<300, "Good"),
            (300..<500, "Acceptable"),
            (500..<Double.infinity, "Poor")
        ]
        
        return buckets.map { range, label in
            let count = times.filter { range.contains($0) }.count
            return PerformanceBucket(
                label: label,
                count: count,
                percentage: Double(count) / Double(times.count)
            )
        }
    }
    
    func createQualityDistribution(_ scores: [Double]) -> [QualityBucket] {
        let buckets: [(ClosedRange<Double>, String)] = [
            (0.8...1.0, "High"),
            (0.6...0.8, "Medium"),
            (0.4...0.6, "Low"),
            (0.0...0.4, "Very Low")
        ]
        
        return buckets.map { range, label in
            let count = scores.filter { range.contains($0) }.count
            return QualityBucket(
                label: label,
                count: count,
                percentage: Double(count) / Double(scores.count)
            )
        }
    }
}

// MARK: - Supporting Types

struct SimilarityVisualizationData {
    let distribution: DistributionAnalysis
    let componentBreakdown: ComponentBreakdown
    let clusters: [SimilarityCluster]
    let performance: PerformanceInsights
    let recommendations: [InsightRecommendation]
    let summary: SummaryStatistics
}

struct RadarChartData {
    let components: [RadarComponent]
    let overallScore: Double
    let confidenceScore: Double
}

struct RadarComponent {
    let name: String
    let value: Double
    let color: Color
}

struct SimilarityHeatmapData {
    let cells: [HeatmapCell]
    let screenshots: [UUID]
    let maxSimilarity: Double
    let minSimilarity: Double
}

struct HeatmapCell {
    let row: Int
    let column: Int
    let value: Double
    let sourceId: UUID
    let targetId: UUID
}

struct PerformanceBenchmarkData {
    let averageProcessingTime: Double
    let maxProcessingTime: Double
    let minProcessingTime: Double
    let averageQuality: Double
    let averageConfidence: Double
    let performanceDistribution: [PerformanceBucket]
    let qualityDistribution: [QualityBucket]
}

struct DistributionAnalysis {
    let histogram: [HistogramBin]
    let mean: Double
    let median: Double
    let standardDeviation: Double
    let skewness: Double
}

struct ComponentBreakdown {
    let components: [ComponentData]
    let correlationMatrix: [[Double]]
}

struct ComponentData {
    let name: String
    let average: Double
    let color: Color
}

struct SimilarityCluster {
    let id: Int
    let name: String
    let scores: [SimilarityScore]
    let averageSimilarity: Double
    let size: Int
    let color: Color
}

struct PerformanceInsights {
    let averageProcessingTime: Double
    let slowCalculations: Int
    let fastCalculations: Int
    let highQualityCalculations: Int
    let performanceRating: String
    let bottlenecks: [String]
}

struct InsightRecommendation {
    let type: RecommendationType
    let title: String
    let description: String
    let impact: Impact
    let action: String
}

struct SummaryStatistics {
    let totalComparisons: Int
    let similarPairs: Int
    let similarityRate: Double
    let averageSimilarity: Double
    let highestSimilarity: Double
    let lowestSimilarity: Double
}

struct HistogramBin {
    let range: ClosedRange<Double>
    let count: Int
    let frequency: Double
}

struct PerformanceBucket {
    let label: String
    let count: Int
    let percentage: Double
}

struct QualityBucket {
    let label: String
    let count: Int
    let percentage: Double
}

enum RecommendationType {
    case performance, quality, insight
}

enum Impact {
    case low, medium, high
}