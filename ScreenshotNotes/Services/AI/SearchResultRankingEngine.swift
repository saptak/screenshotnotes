import Foundation
import SwiftData
import SwiftUI
import OSLog

/// Advanced search result ranking engine with machine learning-based relevance scoring
/// Provides multi-dimensional ranking with personalization and context awareness
@MainActor
public final class SearchResultRankingEngine: ObservableObject {
    public static let shared = SearchResultRankingEngine()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "SearchResultRanking")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isRanking = false
    @Published public private(set) var lastRankingMetrics: RankingMetrics?
    @Published public private(set) var rankingFactors: [RankingFactor] = []
    @Published public private(set) var personalizedWeights: [String: Double] = [:]
    @Published public private(set) var adaptiveScoring: AdaptiveScoring?
    
    // MARK: - Services
    
    // Entity extraction service would be initialized when needed
    private let hapticService = HapticFeedbackService.shared
    
    // MARK: - Configuration
    
    public struct RankingSettings {
        var enablePersonalization: Bool = true
        var enableContextualRanking: Bool = true
        var enableMachineLearning: Bool = true
        var enableAdaptiveWeighting: Bool = true
        var maxResultsToRank: Int = 100
        var personalizedLearningRate: Double = 0.1
        var contextualBoostFactor: Double = 1.5
        var temporalDecayFactor: Double = 0.95
        var qualityThreshold: Double = 0.3
        var diversityWeight: Double = 0.2
        
        public init() {}
    }
    
    @Published public var settings = RankingSettings()
    
    // MARK: - Data Models
    
    /// Comprehensive ranking result with scoring details
    public struct RankedResult: Identifiable {
        public let id: UUID
        let screenshot: Screenshot
        let finalScore: Double
        let componentScores: [String: Double]
        let rankingFactors: [RankingFactor]
        let confidenceScore: Double
        let explanations: [String]
        let personalizedAdjustment: Double
        let contextualBoost: Double
        
        public init(
            screenshot: Screenshot,
            finalScore: Double,
            componentScores: [String: Double] = [:],
            rankingFactors: [RankingFactor] = [],
            confidenceScore: Double = 0.0,
            explanations: [String] = [],
            personalizedAdjustment: Double = 0.0,
            contextualBoost: Double = 0.0
        ) {
            self.id = screenshot.id
            self.screenshot = screenshot
            self.finalScore = finalScore
            self.componentScores = componentScores
            self.rankingFactors = rankingFactors
            self.confidenceScore = confidenceScore
            self.explanations = explanations
            self.personalizedAdjustment = personalizedAdjustment
            self.contextualBoost = contextualBoost
        }
    }
    
    /// Ranking factor with weight and explanation
    public struct RankingFactor: Identifiable {
        public let id = UUID()
        let name: String
        let weight: Double
        let score: Double
        let description: String
        let category: FactorCategory
        let impact: Impact
        let adaptable: Bool
        
        public enum FactorCategory: String, CaseIterable {
            case textRelevance = "text_relevance"
            case temporal = "temporal"
            case visual = "visual"
            case behavioral = "behavioral"
            case contextual = "contextual"
            case quality = "quality"
            case personalization = "personalization"
            case semantic = "semantic"
            case engagement = "engagement"
            case diversity = "diversity"
        }
        
        public enum Impact: String, CaseIterable {
            case high = "high"
            case medium = "medium"
            case low = "low"
            case negligible = "negligible"
            
            public var multiplier: Double {
                switch self {
                case .high: return 2.0
                case .medium: return 1.5
                case .low: return 1.0
                case .negligible: return 0.5
                }
            }
        }
    }
    
    /// Ranking metrics for analysis
    public struct RankingMetrics: Identifiable {
        public let id = UUID()
        let query: String
        let totalResults: Int
        let rankedResults: Int
        let averageScore: Double
        let scoreDistribution: [Double]
        let factorContributions: [String: Double]
        let personalizationImpact: Double
        let contextualImpact: Double
        let processingTime: TimeInterval
        let timestamp: Date
        
        public init(
            query: String,
            totalResults: Int,
            rankedResults: Int,
            averageScore: Double,
            scoreDistribution: [Double],
            factorContributions: [String: Double],
            personalizationImpact: Double,
            contextualImpact: Double,
            processingTime: TimeInterval,
            timestamp: Date = Date()
        ) {
            self.query = query
            self.totalResults = totalResults
            self.rankedResults = rankedResults
            self.averageScore = averageScore
            self.scoreDistribution = scoreDistribution
            self.factorContributions = factorContributions
            self.personalizationImpact = personalizationImpact
            self.contextualImpact = contextualImpact
            self.processingTime = processingTime
            self.timestamp = timestamp
        }
    }
    
    /// Adaptive scoring system that learns from user behavior
    public struct AdaptiveScoring: Codable {
        var factorWeights: [String: Double] = [:]
        var personalizedBias: [String: Double] = [:]
        var contextualModifiers: [String: Double] = [:]
        var temporalAdjustments: [String: Double] = [:]
        var learningHistory: [LearningEvent] = []
        var lastUpdated: Date = Date()
        var adaptationCount: Int = 0
        var convergenceScore: Double = 0.0
        
        public struct LearningEvent: Codable {
            let query: String
            let userFeedback: Double
            let factorAdjustments: [String: Double]
            let timestamp: Date
            
            public init(query: String, userFeedback: Double, factorAdjustments: [String: Double], timestamp: Date = Date()) {
                self.query = query
                self.userFeedback = userFeedback
                self.factorAdjustments = factorAdjustments
                self.timestamp = timestamp
            }
        }
        
        public init() {}
        
        public mutating func adapt(from feedback: Double, factors: [RankingFactor], learningRate: Double) {
            adaptationCount += 1
            
            // Adjust factor weights based on feedback
            for factor in factors {
                let currentWeight = factorWeights[factor.name, default: 1.0]
                let adjustment = (feedback - 0.5) * learningRate * factor.impact.multiplier
                factorWeights[factor.name] = max(0.1, min(3.0, currentWeight + adjustment))
            }
            
            // Record learning event
            let adjustments = Dictionary(uniqueKeysWithValues: factors.map { ($0.name, factorWeights[$0.name] ?? 1.0) })
            let event = LearningEvent(query: "", userFeedback: feedback, factorAdjustments: adjustments)
            learningHistory.append(event)
            
            // Keep history manageable
            if learningHistory.count > 100 {
                learningHistory.removeFirst(50)
            }
            
            lastUpdated = Date()
            
            // Calculate convergence score
            if learningHistory.count >= 10 {
                let recentFeedback = learningHistory.suffix(10).map { $0.userFeedback }
                let variance = calculateVariance(recentFeedback)
                convergenceScore = max(0, 1.0 - variance)
            }
        }
        
        private func calculateVariance(_ values: [Double]) -> Double {
            guard values.count > 1 else { return 0 }
            let mean = values.reduce(0, +) / Double(values.count)
            let squaredDiffs = values.map { pow($0 - mean, 2) }
            return squaredDiffs.reduce(0, +) / Double(values.count - 1)
        }
    }
    
    /// Search context for ranking
    public struct SearchContext {
        let query: String
        let queryType: QueryType
        let userIntent: UserIntent
        let temporalContext: TemporalContext?
        let userProfile: UserProfile?
        let sessionContext: SessionContext?
        
        public enum QueryType: String, CaseIterable {
            case specific = "specific"
            case exploratory = "exploratory"
            case temporal = "temporal"
            case visual = "visual"
            case semantic = "semantic"
        }
        
        public enum UserIntent: String, CaseIterable {
            case find = "find"
            case browse = "browse"
            case organize = "organize"
            case share = "share"
            case analyze = "analyze"
        }
        
        public struct TemporalContext {
            let isRecent: Bool
            let timeRange: DateInterval?
            let timeOfDay: String
            let dayType: String
        }
        
        public struct UserProfile {
            let searchFrequency: Double
            let preferredContentTypes: [String]
            let behaviorPatterns: [String: Double]
            let satisfactionHistory: [Double]
        }
        
        public struct SessionContext {
            let previousQueries: [String]
            let viewedResults: [UUID]
            let sessionDuration: TimeInterval
            let interactionCount: Int
        }
    }
    
    // MARK: - Default Ranking Weights
    
    private let defaultWeights: [String: Double] = [
        "text_relevance": 1.0,
        "exact_match": 1.5,
        "partial_match": 0.8,
        "semantic_similarity": 0.9,
        "temporal_relevance": 0.7,
        "visual_quality": 0.6,
        "user_engagement": 0.8,
        "content_type_match": 0.7,
        "app_preference": 0.5,
        "tag_relevance": 0.9,
        "favorite_boost": 1.2,
        "recent_activity": 0.6,
        "frequency_bias": 0.4,
        "quality_score": 0.8,
        "diversity_factor": 0.3,
        "personalization": 0.7
    ]
    
    // MARK: - Initialization
    
    private init() {
        logger.info("SearchResultRankingEngine initialized with machine learning-based scoring")
        loadAdaptiveScoring()
        initializeRankingFactors()
    }
    
    // MARK: - Public Interface
    
    /// Rank search results with comprehensive multi-factor scoring
    /// - Parameters:
    ///   - results: Screenshots to rank
    ///   - context: Search context with query and user information
    /// - Returns: Ranked results with detailed scoring
    public func rankResults(
        _ results: [Screenshot],
        context: SearchContext
    ) async -> [RankedResult] {
        
        guard !results.isEmpty else { return [] }
        
        logger.info("Ranking \(results.count) results for query: '\(context.query)'")
        
        isRanking = true
        let startTime = Date()
        
        defer {
            isRanking = false
        }
        
        // Limit results for performance
        let limitedResults = Array(results.prefix(settings.maxResultsToRank))
        
        // Step 1: Calculate component scores for each result
        var rankedResults: [RankedResult] = []
        var allScores: [Double] = []
        var factorContributions: [String: Double] = [:]
        
        for screenshot in limitedResults {
            let (result, factors) = await rankSingleResult(screenshot, context: context)
            rankedResults.append(result)
            allScores.append(result.finalScore)
            
            // Accumulate factor contributions
            for factor in factors {
                factorContributions[factor.name, default: 0.0] += factor.weight * factor.score
            }
        }
        
        // Step 2: Apply diversity filtering if enabled
        if settings.diversityWeight > 0 {
            rankedResults = await applyDiversityFiltering(rankedResults, context: context)
        }
        
        // Step 3: Final ranking sort
        rankedResults.sort { $0.finalScore > $1.finalScore }
        
        // Step 4: Record ranking metrics
        let processingTime = Date().timeIntervalSince(startTime)
        let metrics = RankingMetrics(
            query: context.query,
            totalResults: results.count,
            rankedResults: rankedResults.count,
            averageScore: allScores.isEmpty ? 0.0 : allScores.reduce(0, +) / Double(allScores.count),
            scoreDistribution: calculateScoreDistribution(allScores),
            factorContributions: factorContributions,
            personalizationImpact: calculatePersonalizationImpact(rankedResults),
            contextualImpact: calculateContextualImpact(rankedResults),
            processingTime: processingTime
        )
        
        lastRankingMetrics = metrics
        
        logger.info("Ranking completed: avg score \(String(format: "%.3f", metrics.averageScore)) in \(String(format: "%.2f", processingTime))s")
        
        return rankedResults
    }
    
    /// Learn from user feedback to improve ranking
    /// - Parameters:
    ///   - query: Original search query
    ///   - selectedResults: Results user interacted with
    ///   - satisfactionScore: User satisfaction (0.0 - 1.0)
    public func learnFromUserFeedback(
        query: String,
        selectedResults: [UUID],
        satisfactionScore: Double
    ) async {
        
        guard settings.enableMachineLearning else { return }
        
        logger.debug("Learning from user feedback: query='\(query)', satisfaction=\(satisfactionScore)")
        
        // Update adaptive scoring
        if var adaptive = adaptiveScoring {
            adaptive.adapt(
                from: satisfactionScore,
                factors: rankingFactors,
                learningRate: settings.personalizedLearningRate
            )
            adaptiveScoring = adaptive
            saveAdaptiveScoring()
        }
        
        // Update personalized weights
        if satisfactionScore > 0.7 {
            // Boost factors that led to successful results
            for factor in rankingFactors where factor.impact == .high {
                personalizedWeights[factor.name, default: 1.0] *= (1.0 + settings.personalizedLearningRate)
            }
        } else if satisfactionScore < 0.3 {
            // Reduce factors that led to poor results
            for factor in rankingFactors where factor.impact == .high {
                personalizedWeights[factor.name, default: 1.0] *= (1.0 - settings.personalizedLearningRate)
            }
        }
        
        // Clamp weights to reasonable bounds
        for key in personalizedWeights.keys {
            personalizedWeights[key] = max(0.1, min(3.0, personalizedWeights[key]!))
        }
        
        logger.info("Ranking weights updated based on user feedback")
    }
    
    /// Get ranking explanation for a specific result
    /// - Parameters:
    ///   - screenshot: Screenshot to explain
    ///   - context: Search context
    /// - Returns: Detailed ranking explanation
    public func explainRanking(
        for screenshot: Screenshot,
        context: SearchContext
    ) async -> [String] {
        
        let (_, factors) = await rankSingleResult(screenshot, context: context)
        
        var explanations: [String] = []
        
        // Sort factors by contribution
        let sortedFactors = factors.sorted { $0.weight * $0.score > $1.weight * $1.score }
        
        for factor in sortedFactors.prefix(5) {
            let contribution = factor.weight * factor.score
            if contribution > 0.1 {
                explanations.append("\(factor.description) (score: \(String(format: "%.2f", contribution)))")
            }
        }
        
        return explanations
    }
    
    /// Get current ranking factor weights
    /// - Returns: Dictionary of factor names and their current weights
    public func getCurrentWeights() -> [String: Double] {
        var weights = defaultWeights
        
        // Apply personalized adjustments
        for (key, value) in personalizedWeights {
            weights[key] = (weights[key] ?? 1.0) * value
        }
        
        // Apply adaptive scoring weights
        if let adaptive = adaptiveScoring {
            for (key, value) in adaptive.factorWeights {
                weights[key] = (weights[key] ?? 1.0) * value
            }
        }
        
        return weights
    }
    
    /// Reset personalization and learning
    public func resetPersonalization() {
        personalizedWeights.removeAll()
        adaptiveScoring = AdaptiveScoring()
        saveAdaptiveScoring()
        
        logger.info("Ranking personalization reset")
    }
    
    // MARK: - Individual Result Ranking
    
    private func rankSingleResult(
        _ screenshot: Screenshot,
        context: SearchContext
    ) async -> (RankedResult, [RankingFactor]) {
        
        var componentScores: [String: Double] = [:]
        var factors: [RankingFactor] = []
        var explanations: [String] = []
        
        // Text relevance scoring
        let (textScore, textFactors) = await calculateTextRelevanceScore(screenshot, query: context.query)
        componentScores["text_relevance"] = textScore
        factors.append(contentsOf: textFactors)
        
        // Temporal relevance scoring
        let (temporalScore, temporalFactors) = await calculateTemporalScore(screenshot, context: context)
        componentScores["temporal_relevance"] = temporalScore
        factors.append(contentsOf: temporalFactors)
        
        // Visual quality scoring
        let (visualScore, visualFactors) = await calculateVisualQualityScore(screenshot)
        componentScores["visual_quality"] = visualScore
        factors.append(contentsOf: visualFactors)
        
        // User engagement scoring
        let (engagementScore, engagementFactors) = await calculateUserEngagementScore(screenshot, context: context)
        componentScores["user_engagement"] = engagementScore
        factors.append(contentsOf: engagementFactors)
        
        // Semantic relevance scoring
        let (semanticScore, semanticFactors) = await calculateSemanticScore(screenshot, context: context)
        componentScores["semantic_relevance"] = semanticScore
        factors.append(contentsOf: semanticFactors)
        
        // Quality and completeness scoring
        let (qualityScore, qualityFactors) = await calculateQualityScore(screenshot)
        componentScores["quality"] = qualityScore
        factors.append(contentsOf: qualityFactors)
        
        // Apply personalization
        let personalizedAdjustment = await calculatePersonalizedAdjustment(factors, context: context)
        
        // Apply contextual boost
        let contextualBoost = await calculateContextualBoost(screenshot, context: context)
        
        // Calculate final weighted score
        let finalScore = await calculateFinalScore(
            componentScores: componentScores,
            factors: factors,
            personalizedAdjustment: personalizedAdjustment,
            contextualBoost: contextualBoost
        )
        
        // Generate explanations
        explanations = generateScoreExplanations(componentScores: componentScores, factors: factors)
        
        let result = RankedResult(
            screenshot: screenshot,
            finalScore: finalScore,
            componentScores: componentScores,
            rankingFactors: factors,
            confidenceScore: calculateConfidenceScore(factors),
            explanations: explanations,
            personalizedAdjustment: personalizedAdjustment,
            contextualBoost: contextualBoost
        )
        
        return (result, factors)
    }
    
    // MARK: - Scoring Components
    
    private func calculateTextRelevanceScore(
        _ screenshot: Screenshot,
        query: String
    ) async -> (Double, [RankingFactor]) {
        
        var score = 0.0
        var factors: [RankingFactor] = []
        
        let searchableText = [
            screenshot.extractedText,
            screenshot.userNotes,
            screenshot.filename,
            screenshot.userTags?.joined(separator: " ")
        ].compactMap { $0 }.joined(separator: " ").lowercased()
        
        let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 1 }
        
        guard !queryTerms.isEmpty else {
            return (0.0, factors)
        }
        
        // Exact match scoring
        var exactMatches = 0
        for term in queryTerms {
            if searchableText.contains(term) {
                exactMatches += 1
            }
        }
        
        let exactMatchScore = Double(exactMatches) / Double(queryTerms.count)
        score += exactMatchScore * 0.4
        
        factors.append(RankingFactor(
            name: "exact_match",
            weight: getCurrentWeight("exact_match"),
            score: exactMatchScore,
            description: "Exact term matches (\(exactMatches)/\(queryTerms.count))",
            category: .textRelevance,
            impact: exactMatchScore > 0.5 ? .high : .medium,
            adaptable: true
        ))
        
        // Partial match scoring
        var partialMatches = 0
        for term in queryTerms {
            for word in searchableText.components(separatedBy: .whitespacesAndNewlines) {
                if word.contains(term) || term.contains(word) {
                    partialMatches += 1
                    break
                }
            }
        }
        
        let partialMatchScore = Double(partialMatches) / Double(queryTerms.count)
        score += partialMatchScore * 0.2
        
        factors.append(RankingFactor(
            name: "partial_match",
            weight: getCurrentWeight("partial_match"),
            score: partialMatchScore,
            description: "Partial term matches (\(partialMatches)/\(queryTerms.count))",
            category: .textRelevance,
            impact: partialMatchScore > 0.3 ? .medium : .low,
            adaptable: true
        ))
        
        // Tag relevance scoring
        if let tags = screenshot.userTags {
            var tagMatches = 0
            for tag in tags {
                for term in queryTerms {
                    if tag.lowercased().contains(term) {
                        tagMatches += 1
                    }
                }
            }
            
            let tagScore = Double(tagMatches) / Double(max(tags.count, 1))
            score += tagScore * 0.3
            
            factors.append(RankingFactor(
                name: "tag_relevance",
                weight: getCurrentWeight("tag_relevance"),
                score: tagScore,
                description: "Tag matches (\(tagMatches) relevant tags)",
                category: .textRelevance,
                impact: tagScore > 0.5 ? .high : .medium,
                adaptable: true
            ))
        }
        
        // Filename relevance
        let filenameScore = queryTerms.filter { screenshot.filename.lowercased().contains($0) }.count > 0 ? 1.0 : 0.0
        score += filenameScore * 0.1
        
        factors.append(RankingFactor(
            name: "filename_match",
            weight: getCurrentWeight("filename_match"),
            score: filenameScore,
            description: filenameScore > 0 ? "Filename matches query" : "No filename match",
            category: .textRelevance,
            impact: filenameScore > 0 ? .medium : .negligible,
            adaptable: true
        ))
        
        return (min(1.0, score), factors)
    }
    
    private func calculateTemporalScore(
        _ screenshot: Screenshot,
        context: SearchContext
    ) async -> (Double, [RankingFactor]) {
        
        var score = 0.0
        var factors: [RankingFactor] = []
        
        let now = Date()
        let timeSince = now.timeIntervalSince(screenshot.timestamp)
        let daysSince = timeSince / 86400
        
        // Recent activity boost
        let recentScore: Double
        if daysSince <= 1 {
            recentScore = 1.0
        } else if daysSince <= 7 {
            recentScore = 0.8
        } else if daysSince <= 30 {
            recentScore = 0.6
        } else if daysSince <= 90 {
            recentScore = 0.4
        } else {
            recentScore = 0.2
        }
        
        score += recentScore * 0.6
        
        factors.append(RankingFactor(
            name: "recent_activity",
            weight: getCurrentWeight("recent_activity"),
            score: recentScore,
            description: "Screenshot from \(Int(daysSince)) days ago",
            category: .temporal,
            impact: recentScore > 0.7 ? .medium : .low,
            adaptable: true
        ))
        
        // Temporal decay
        let decayScore = pow(settings.temporalDecayFactor, daysSince)
        score += decayScore * 0.4
        
        factors.append(RankingFactor(
            name: "temporal_decay",
            weight: getCurrentWeight("temporal_decay"),
            score: decayScore,
            description: "Temporal relevance decay",
            category: .temporal,
            impact: .low,
            adaptable: false
        ))
        
        // Contextual temporal relevance
        if let temporalContext = context.temporalContext {
            var contextScore = 0.0
            
            if temporalContext.isRecent && daysSince <= 7 {
                contextScore = 1.0
            } else if let timeRange = temporalContext.timeRange {
                if timeRange.contains(screenshot.timestamp) {
                    contextScore = 1.0
                }
            }
            
            score += contextScore * 0.3
            
            factors.append(RankingFactor(
                name: "temporal_context_match",
                weight: getCurrentWeight("temporal_context_match"),
                score: contextScore,
                description: contextScore > 0 ? "Matches temporal context" : "Outside temporal context",
                category: .temporal,
                impact: contextScore > 0 ? .high : .negligible,
                adaptable: true
            ))
        }
        
        return (min(1.0, score), factors)
    }
    
    private func calculateVisualQualityScore(_ screenshot: Screenshot) async -> (Double, [RankingFactor]) {
        var score = 0.0
        var factors: [RankingFactor] = []
        
        // Visual attributes scoring
        if let visual = screenshot.visualAttributes {
            // Object detection score
            let objectScore = min(1.0, Double(visual.prominentObjects.count) / 5.0)
            score += objectScore * 0.3
            
            factors.append(RankingFactor(
                name: "object_detection",
                weight: getCurrentWeight("object_detection"),
                score: objectScore,
                description: "\(visual.prominentObjects.count) objects detected",
                category: .visual,
                impact: objectScore > 0.6 ? .medium : .low,
                adaptable: true
            ))
            
            // Color analysis score
            let colorScore = 0.5 // Default color score when dominantColors not available
            score += colorScore * 0.2
            
            factors.append(RankingFactor(
                name: "color_analysis",
                weight: getCurrentWeight("color_analysis"),
                score: colorScore,
                description: "Color analysis applied",
                category: .visual,
                impact: .low,
                adaptable: false
            ))
            
            // Document quality
            if visual.isDocument {
                score += 0.3
                
                factors.append(RankingFactor(
                    name: "document_quality",
                    weight: getCurrentWeight("document_quality"),
                    score: 1.0,
                    description: "High-quality document detected",
                    category: .visual,
                    impact: .high,
                    adaptable: true
                ))
            }
        }
        
        // OCR text presence (indicates visual clarity)
        if let text = screenshot.extractedText, !text.isEmpty {
            let textLengthScore = min(1.0, Double(text.count) / 500.0)
            score += textLengthScore * 0.2
            
            factors.append(RankingFactor(
                name: "ocr_text_quality",
                weight: getCurrentWeight("ocr_text_quality"),
                score: textLengthScore,
                description: "OCR extracted \(text.count) characters",
                category: .visual,
                impact: textLengthScore > 0.5 ? .medium : .low,
                adaptable: true
            ))
        }
        
        return (min(1.0, score), factors)
    }
    
    private func calculateUserEngagementScore(
        _ screenshot: Screenshot,
        context: SearchContext
    ) async -> (Double, [RankingFactor]) {
        
        var score = 0.0
        var factors: [RankingFactor] = []
        
        // Favorite status
        if screenshot.isFavorite {
            score += 0.4
            
            factors.append(RankingFactor(
                name: "favorite_boost",
                weight: getCurrentWeight("favorite_boost"),
                score: 1.0,
                description: "User marked as favorite",
                category: .engagement,
                impact: .high,
                adaptable: true
            ))
        }
        
        // User notes presence
        if let notes = screenshot.userNotes, !notes.isEmpty {
            score += 0.3
            
            factors.append(RankingFactor(
                name: "user_notes",
                weight: getCurrentWeight("user_notes"),
                score: 1.0,
                description: "Contains user notes",
                category: .engagement,
                impact: .medium,
                adaptable: true
            ))
        }
        
        // User tags presence
        if let tags = screenshot.userTags, !tags.isEmpty {
            let tagScore = min(1.0, Double(tags.count) / 5.0)
            score += tagScore * 0.3
            
            factors.append(RankingFactor(
                name: "user_tags",
                weight: getCurrentWeight("user_tags"),
                score: tagScore,
                description: "\(tags.count) user tags",
                category: .engagement,
                impact: tagScore > 0.5 ? .medium : .low,
                adaptable: true
            ))
        }
        
        return (min(1.0, score), factors)
    }
    
    private func calculateSemanticScore(
        _ screenshot: Screenshot,
        context: SearchContext
    ) async -> (Double, [RankingFactor]) {
        
        var score = 0.0
        var factors: [RankingFactor] = []
        
        // Semantic tags matching
        if let semanticTags = screenshot.semanticTags {
            let queryTerms = context.query.lowercased().components(separatedBy: .whitespacesAndNewlines)
            var semanticMatches = 0
            
            for tag in semanticTags.tags {
                for term in queryTerms {
                    if tag.name.lowercased().contains(term) || term.contains(tag.name.lowercased()) {
                        semanticMatches += 1
                        break
                    }
                }
            }
            
            let semanticScore = Double(semanticMatches) / Double(max(semanticTags.tags.count, 1))
            score += semanticScore * 0.5
            
            factors.append(RankingFactor(
                name: "semantic_tags",
                weight: getCurrentWeight("semantic_tags"),
                score: semanticScore,
                description: "\(semanticMatches) semantic tag matches",
                category: .semantic,
                impact: semanticScore > 0.3 ? .high : .medium,
                adaptable: true
            ))
        }
        
        // App context matching
        if let filename = screenshot.filename.components(separatedBy: "_").first {
            let appScore = context.query.lowercased().contains(filename.lowercased()) ? 1.0 : 0.0
            score += appScore * 0.3
            
            factors.append(RankingFactor(
                name: "app_context",
                weight: getCurrentWeight("app_context"),
                score: appScore,
                description: appScore > 0 ? "App name matches query" : "No app context match",
                category: .semantic,
                impact: appScore > 0 ? .medium : .negligible,
                adaptable: true
            ))
        }
        
        // Content type relevance
        if let visual = screenshot.visualAttributes {
            let contentTypeScore = calculateContentTypeRelevance(visual, query: context.query)
            score += contentTypeScore * 0.2
            
            factors.append(RankingFactor(
                name: "content_type_relevance",
                weight: getCurrentWeight("content_type_relevance"),
                score: contentTypeScore,
                description: "Content type relevance",
                category: .semantic,
                impact: contentTypeScore > 0.5 ? .medium : .low,
                adaptable: true
            ))
        }
        
        return (min(1.0, score), factors)
    }
    
    private func calculateQualityScore(_ screenshot: Screenshot) async -> (Double, [RankingFactor]) {
        var score = 0.0
        var factors: [RankingFactor] = []
        
        // Data completeness
        var completenessItems = 0
        let totalItems = 5
        
        if screenshot.extractedText?.isEmpty == false { completenessItems += 1 }
        if screenshot.visualAttributes != nil { completenessItems += 1 }
        if screenshot.userTags?.isEmpty == false { completenessItems += 1 }
        if screenshot.semanticTags?.tags.isEmpty == false { completenessItems += 1 }
        if !screenshot.filename.isEmpty { completenessItems += 1 }
        
        let completenessScore = Double(completenessItems) / Double(totalItems)
        score += completenessScore * 0.4
        
        factors.append(RankingFactor(
            name: "data_completeness",
            weight: getCurrentWeight("data_completeness"),
            score: completenessScore,
            description: "\(completenessItems)/\(totalItems) data fields complete",
            category: .quality,
            impact: completenessScore > 0.6 ? .medium : .low,
            adaptable: false
        ))
        
        // Content richness
        var richnessScore = 0.0
        if let text = screenshot.extractedText {
            richnessScore += min(1.0, Double(text.count) / 1000.0) * 0.3
        }
        if let visual = screenshot.visualAttributes {
            richnessScore += min(1.0, Double(visual.prominentObjects.count) / 10.0) * 0.3
        }
        if let tags = screenshot.semanticTags {
            richnessScore += min(1.0, Double(tags.tags.count) / 20.0) * 0.4
        }
        
        score += richnessScore * 0.6
        
        factors.append(RankingFactor(
            name: "content_richness",
            weight: getCurrentWeight("content_richness"),
            score: richnessScore,
            description: "Content richness and detail",
            category: .quality,
            impact: richnessScore > 0.5 ? .medium : .low,
            adaptable: true
        ))
        
        return (min(1.0, score), factors)
    }
    
    // MARK: - Personalization and Context
    
    private func calculatePersonalizedAdjustment(
        _ factors: [RankingFactor],
        context: SearchContext
    ) async -> Double {
        
        guard settings.enablePersonalization else { return 0.0 }
        
        var adjustment = 0.0
        
        // Apply personalized weights
        for factor in factors {
            if let personalizedWeight = personalizedWeights[factor.name] {
                adjustment += (personalizedWeight - 1.0) * factor.score * 0.1
            }
        }
        
        // User profile adjustments
        if let profile = context.userProfile {
            // Boost based on user's preferred content types
            for contentType in profile.preferredContentTypes {
                if factors.contains(where: { $0.name.contains(contentType) }) {
                    adjustment += 0.1
                }
            }
            
            // Adjust based on satisfaction history
            let avgSatisfaction = profile.satisfactionHistory.isEmpty ? 0.5 :
                profile.satisfactionHistory.reduce(0, +) / Double(profile.satisfactionHistory.count)
            
            if avgSatisfaction > 0.7 {
                adjustment += 0.05 // Boost for satisfied users
            }
        }
        
        return max(-0.5, min(0.5, adjustment))
    }
    
    private func calculateContextualBoost(
        _ screenshot: Screenshot,
        context: SearchContext
    ) async -> Double {
        
        guard settings.enableContextualRanking else { return 0.0 }
        
        var boost = 0.0
        
        // Session context boost
        if let session = context.sessionContext {
            // Boost if related to previous queries
            for query in session.previousQueries {
                if let text = screenshot.extractedText,
                   text.lowercased().contains(query.lowercased()) {
                    boost += 0.1
                }
            }
            
            // Boost if previously viewed but not selected (might be relevant)
            if session.viewedResults.contains(screenshot.id) {
                boost += 0.05
            }
        }
        
        // Query type boost
        switch context.queryType {
        case .temporal:
            let daysSince = Date().timeIntervalSince(screenshot.timestamp) / 86400
            if daysSince <= 7 {
                boost += 0.2
            }
        case .visual:
            if screenshot.visualAttributes?.prominentObjects.isEmpty == false {
                boost += 0.2
            }
        case .semantic:
            if screenshot.semanticTags?.tags.isEmpty == false {
                boost += 0.2
            }
        default:
            break
        }
        
        return max(0.0, min(0.3, boost * settings.contextualBoostFactor))
    }
    
    private func calculateFinalScore(
        componentScores: [String: Double],
        factors: [RankingFactor],
        personalizedAdjustment: Double,
        contextualBoost: Double
    ) async -> Double {
        
        var finalScore = 0.0
        
        // Apply weighted component scores
        for (component, score) in componentScores {
            let weight = getCurrentWeight(component)
            finalScore += score * weight
        }
        
        // Apply personalization and context
        finalScore += personalizedAdjustment
        finalScore += contextualBoost
        
        // Normalize to 0-1 range
        return max(0.0, min(1.0, finalScore))
    }
    
    // MARK: - Diversity and Quality Filtering
    
    private func applyDiversityFiltering(
        _ results: [RankedResult],
        context: SearchContext
    ) async -> [RankedResult] {
        
        guard results.count > 10 else { return results }
        
        var diverseResults: [RankedResult] = []
        var seenApps: Set<String> = []
        var seenContentTypes: Set<String> = []
        
        // Sort by score first
        let sortedResults = results.sorted { $0.finalScore > $1.finalScore }
        
        for result in sortedResults {
            var shouldInclude = true
            
            // Diversity based on app
            if let filename = result.screenshot.filename.components(separatedBy: "_").first {
                if seenApps.contains(filename) && seenApps.count > 3 {
                    shouldInclude = false
                }
                seenApps.insert(filename)
            }
            
            // Diversity based on content type
            if let visual = result.screenshot.visualAttributes {
                let contentType = visual.isDocument ? "document" : "general"
                if seenContentTypes.contains(contentType) && seenContentTypes.count > 2 {
                    shouldInclude = false
                }
                seenContentTypes.insert(contentType)
            }
            
            // Apply diversity penalty
            if !shouldInclude {
                let diversityPenalty = settings.diversityWeight
                let adjustedScore = result.finalScore * (1.0 - diversityPenalty)
                
                let adjustedResult = RankedResult(
                    screenshot: result.screenshot,
                    finalScore: adjustedScore,
                    componentScores: result.componentScores,
                    rankingFactors: result.rankingFactors,
                    confidenceScore: result.confidenceScore,
                    explanations: result.explanations + ["Diversity penalty applied"],
                    personalizedAdjustment: result.personalizedAdjustment,
                    contextualBoost: result.contextualBoost
                )
                
                diverseResults.append(adjustedResult)
            } else {
                diverseResults.append(result)
            }
        }
        
        return diverseResults
    }
    
    // MARK: - Helper Methods
    
    private func initializeRankingFactors() {
        rankingFactors = [
            RankingFactor(name: "text_relevance", weight: 1.0, score: 0.0, description: "Text content matches", category: .textRelevance, impact: .high, adaptable: true),
            RankingFactor(name: "temporal_relevance", weight: 0.7, score: 0.0, description: "Time-based relevance", category: .temporal, impact: .medium, adaptable: true),
            RankingFactor(name: "visual_quality", weight: 0.6, score: 0.0, description: "Visual content quality", category: .visual, impact: .medium, adaptable: true),
            RankingFactor(name: "user_engagement", weight: 0.8, score: 0.0, description: "User interaction signals", category: .engagement, impact: .high, adaptable: true),
            RankingFactor(name: "semantic_relevance", weight: 0.9, score: 0.0, description: "Semantic meaning match", category: .semantic, impact: .high, adaptable: true)
        ]
    }
    
    private func getCurrentWeight(_ factorName: String) -> Double {
        var weight = defaultWeights[factorName] ?? 1.0
        
        // Apply personalized adjustment
        if let personalizedWeight = personalizedWeights[factorName] {
            weight *= personalizedWeight
        }
        
        // Apply adaptive adjustment
        if let adaptive = adaptiveScoring,
           let adaptiveWeight = adaptive.factorWeights[factorName] {
            weight *= adaptiveWeight
        }
        
        return weight
    }
    
    private func calculateContentTypeRelevance(_ visual: VisualAttributes, query: String) -> Double {
        let queryLower = query.lowercased()
        
        if visual.isDocument && (queryLower.contains("document") || queryLower.contains("text") || queryLower.contains("pdf")) {
            return 1.0
        }
        
        for object in visual.prominentObjects {
            if queryLower.contains(object.label.lowercased()) {
                return 0.8
            }
        }
        
        return 0.0
    }
    
    private func calculateConfidenceScore(_ factors: [RankingFactor]) -> Double {
        let highImpactFactors = factors.filter { $0.impact == .high }
        let totalImpact = factors.reduce(0.0) { $0 + $1.impact.multiplier }
        let highImpactTotal = highImpactFactors.reduce(0.0) { $0 + $1.impact.multiplier }
        
        return totalImpact > 0 ? highImpactTotal / totalImpact : 0.5
    }
    
    private func generateScoreExplanations(
        componentScores: [String: Double],
        factors: [RankingFactor]
    ) -> [String] {
        
        var explanations: [String] = []
        
        // Top contributing components
        let sortedComponents = componentScores.sorted { $0.value > $1.value }
        for (component, score) in sortedComponents.prefix(3) {
            if score > 0.1 {
                explanations.append("\(component.replacingOccurrences(of: "_", with: " ").capitalized): \(String(format: "%.1f%%", score * 100))")
            }
        }
        
        // Top contributing factors
        let sortedFactors = factors.sorted { $0.weight * $0.score > $1.weight * $1.score }
        for factor in sortedFactors.prefix(2) {
            let contribution = factor.weight * factor.score
            if contribution > 0.1 {
                explanations.append(factor.description)
            }
        }
        
        return explanations
    }
    
    private func calculateScoreDistribution(_ scores: [Double]) -> [Double] {
        guard !scores.isEmpty else { return [] }
        
        let sortedScores = scores.sorted()
        let count = scores.count
        
        return [
            sortedScores[0], // Min
            sortedScores[count / 4], // Q1
            sortedScores[count / 2], // Median
            sortedScores[3 * count / 4], // Q3
            sortedScores[count - 1] // Max
        ]
    }
    
    private func calculatePersonalizationImpact(_ results: [RankedResult]) -> Double {
        let personalizedAdjustments = results.map { $0.personalizedAdjustment }
        guard !personalizedAdjustments.isEmpty else { return 0.0 }
        
        return personalizedAdjustments.reduce(0, +) / Double(personalizedAdjustments.count)
    }
    
    private func calculateContextualImpact(_ results: [RankedResult]) -> Double {
        let contextualBoosts = results.map { $0.contextualBoost }
        guard !contextualBoosts.isEmpty else { return 0.0 }
        
        return contextualBoosts.reduce(0, +) / Double(contextualBoosts.count)
    }
    
    // MARK: - Persistence
    
    private func loadAdaptiveScoring() {
        guard let data = UserDefaults.standard.data(forKey: "AdaptiveScoring") else {
            adaptiveScoring = AdaptiveScoring()
            return
        }
        
        do {
            adaptiveScoring = try JSONDecoder().decode(AdaptiveScoring.self, from: data)
        } catch {
            logger.error("Failed to load adaptive scoring: \(error.localizedDescription)")
            adaptiveScoring = AdaptiveScoring()
        }
    }
    
    private func saveAdaptiveScoring() {
        guard let adaptive = adaptiveScoring else { return }
        
        do {
            let data = try JSONEncoder().encode(adaptive)
            UserDefaults.standard.set(data, forKey: "AdaptiveScoring")
        } catch {
            logger.error("Failed to save adaptive scoring: \(error.localizedDescription)")
        }
    }
}