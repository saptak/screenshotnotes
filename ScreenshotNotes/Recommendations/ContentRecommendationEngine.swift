import Foundation
import SwiftData
import SwiftUI
import OSLog

/// Advanced content recommendation engine for intelligent screenshot discovery
/// Analyzes patterns, relationships, and user behavior to suggest relevant content
@MainActor
public final class ContentRecommendationEngine: ObservableObject {
    public static let shared = ContentRecommendationEngine()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ContentRecommendation")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var lastAnalysisResults: RecommendationResults?
    @Published public private(set) var contentRelationships: [ContentRelationship] = []
    @Published public private(set) var userDiscoveryProfile: UserDiscoveryProfile = UserDiscoveryProfile()
    @Published public private(set) var temporalPatterns: [TemporalPattern] = []
    
    // MARK: - Services Integration
    
    private let hapticService = HapticFeedbackService.shared
    private let errorHandler = AppErrorHandler.shared
    
    // MARK: - Configuration
    
    public struct RecommendationSettings {
        var enableContentDiscovery: Bool = true
        var enableTemporalAnalysis: Bool = true
        var enableSemanticSimilarity: Bool = true
        var enableVisualSimilarity: Bool = true
        var maxRecommendations: Int = 20
        var minimumSimilarityScore: Double = 0.6
        var temporalWindowDays: Int = 30
        var enableMachineLearning: Bool = true
        var adaptiveWeighting: Bool = true
        var privacyMode: Bool = false
        
        public init() {}
    }
    
    @Published public var settings = RecommendationSettings()
    
    // MARK: - Data Models
    
    /// Comprehensive recommendation results with multiple discovery types
    public struct RecommendationResults: Identifiable {
        public let id = UUID()
        let sourceScreenshot: Screenshot
        let relatedContent: [RelatedContent]
        let temporalMatches: [TemporalMatch]
        let semanticMatches: [SemanticMatch]
        let visualMatches: [VisualMatch]
        let workflowMatches: [WorkflowMatch]
        let confidence: Double
        let analysisTimestamp: Date
        let processingMetrics: ProcessingMetrics
        
        struct ProcessingMetrics {
            let analysisTime: TimeInterval
            let totalComparisons: Int
            let cacheHitRate: Double
            let memoryUsage: Int64
        }
        
        init(
            sourceScreenshot: Screenshot,
            relatedContent: [RelatedContent] = [],
            temporalMatches: [TemporalMatch] = [],
            semanticMatches: [SemanticMatch] = [],
            visualMatches: [VisualMatch] = [],
            workflowMatches: [WorkflowMatch] = [],
            confidence: Double,
            processingMetrics: ProcessingMetrics
        ) {
            self.sourceScreenshot = sourceScreenshot
            self.relatedContent = relatedContent
            self.temporalMatches = temporalMatches
            self.semanticMatches = semanticMatches
            self.visualMatches = visualMatches
            self.workflowMatches = workflowMatches
            self.confidence = confidence
            self.analysisTimestamp = Date()
            self.processingMetrics = processingMetrics
        }
    }
    
    /// Related content item with similarity scoring
    public struct RelatedContent: Identifiable, Hashable {
        public let id = UUID()
        let screenshot: Screenshot
        let similarityScore: Double
        let relationshipType: RelationshipType
        let matchingFeatures: [MatchingFeature]
        let temporalProximity: TimeInterval?
        let explanation: String
        
        public enum RelationshipType: String, CaseIterable {
            case temporal = "temporal"
            case semantic = "semantic"
            case visual = "visual"
            case workflow = "workflow"
            case contextual = "contextual"
            case thematic = "thematic"
            case duplicate = "duplicate"
            case variation = "variation"
            
            var displayName: String {
                switch self {
                case .temporal: return "Time-based"
                case .semantic: return "Content-based"
                case .visual: return "Visually Similar"
                case .workflow: return "Workflow"
                case .contextual: return "Context"
                case .thematic: return "Theme"
                case .duplicate: return "Duplicate"
                case .variation: return "Variation"
                }
            }
            
            var iconName: String {
                switch self {
                case .temporal: return "clock"
                case .semantic: return "text.magnifyingglass"
                case .visual: return "photo"
                case .workflow: return "arrow.triangle.2.circlepath"
                case .contextual: return "location"
                case .thematic: return "folder"
                case .duplicate: return "doc.on.doc"
                case .variation: return "arrow.up.arrow.down"
                }
            }
        }
        
        public struct MatchingFeature {
            let featureType: FeatureType
            let similarity: Double
            let description: String
            
            enum FeatureType: String, CaseIterable {
                case text, color, object, layout, entity, tag, metadata
            }
        }
        
        public static func == (lhs: RelatedContent, rhs: RelatedContent) -> Bool {
            return lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    /// Temporal pattern matching for time-based discovery
    public struct TemporalMatch: Identifiable {
        public let id = UUID()
        let pattern: TemporalPattern
        let screenshots: [Screenshot]
        let confidence: Double
        let timeSpan: TimeInterval
        let frequency: Frequency
        
        enum Frequency: String, CaseIterable {
            case daily, weekly, monthly, seasonal, irregular
            
            var displayName: String {
                switch self {
                case .daily: return "Daily"
                case .weekly: return "Weekly"
                case .monthly: return "Monthly"
                case .seasonal: return "Seasonal"
                case .irregular: return "Irregular"
                }
            }
        }
    }
    
    /// Semantic content matching based on meaning and entities
    public struct SemanticMatch: Identifiable {
        public let id = UUID()
        let screenshot: Screenshot
        let semanticSimilarity: Double
        let sharedEntities: [String]
        let sharedConcepts: [String]
        let contextSimilarity: Double
        let explanation: String
    }
    
    /// Visual similarity matching based on appearance
    public struct VisualMatch: Identifiable {
        public let id = UUID()
        let screenshot: Screenshot
        let visualSimilarity: Double
        let sharedVisualFeatures: [VisualFeature]
        let colorSimilarity: Double
        let layoutSimilarity: Double
        
        struct VisualFeature {
            let type: FeatureType
            let confidence: Double
            
            enum FeatureType: String, CaseIterable {
                case dominantColor, layout, objects, text, composition
            }
        }
    }
    
    /// Workflow pattern matching for process-based discovery
    public struct WorkflowMatch: Identifiable {
        public let id = UUID()
        let workflowType: WorkflowType
        let screenshots: [Screenshot]
        let stepPosition: Int
        let workflowConfidence: Double
        let suggestedNextSteps: [String]
        
        enum WorkflowType: String, CaseIterable {
            case documentation, comparison, iteration, research, troubleshooting
            
            var displayName: String {
                switch self {
                case .documentation: return "Documentation"
                case .comparison: return "Comparison"
                case .iteration: return "Iteration"
                case .research: return "Research"
                case .troubleshooting: return "Troubleshooting"
                }
            }
        }
    }
    
    /// Content relationship graph for advanced discovery
    public struct ContentRelationship: Identifiable {
        public let id = UUID()
        let screenshot1: Screenshot
        let screenshot2: Screenshot
        let relationshipStrength: Double
        let relationshipTypes: [RelatedContent.RelationshipType]
        let directional: Bool
        let temporalDistance: TimeInterval
        let lastUpdated: Date
    }
    
    /// Temporal pattern detection for cyclical content
    public struct TemporalPattern: Identifiable {
        public let id = UUID()
        let patternType: PatternType
        let timeInterval: TimeInterval
        let confidence: Double
        let screenshots: [Screenshot]
        let description: String
        let predictedNext: Date?
        
        enum PatternType: String, CaseIterable {
            case daily, weekly, monthly, projectCycle, meetingCycle, workflowCycle
            
            var displayName: String {
                switch self {
                case .daily: return "Daily Pattern"
                case .weekly: return "Weekly Pattern"
                case .monthly: return "Monthly Pattern"
                case .projectCycle: return "Project Cycle"
                case .meetingCycle: return "Meeting Cycle"
                case .workflowCycle: return "Workflow Cycle"
                }
            }
        }
    }
    
    /// User discovery profile for personalized recommendations
    public struct UserDiscoveryProfile {
        var preferredRelationshipTypes: [RelatedContent.RelationshipType: Double] = [:]
        var temporalPreferences: [TemporalPattern.PatternType: Double] = [:]
        var interactionHistory: [String: Int] = [:]
        var discoverySuccessRate: Double = 0.0
        var averageExplorationDepth: Int = 3
        var lastProfileUpdate: Date = Date()
        
        public init() {
            // Initialize with balanced preferences
            RelatedContent.RelationshipType.allCases.forEach { type in
                preferredRelationshipTypes[type] = 0.5
            }
            TemporalPattern.PatternType.allCases.forEach { type in
                temporalPreferences[type] = 0.5
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        logger.info("ContentRecommendationEngine initialized with advanced discovery algorithms")
        loadUserDiscoveryProfile()
    }
    
    // MARK: - Public Interface
    
    /// Generate comprehensive content recommendations for a screenshot
    /// - Parameters:
    ///   - screenshot: Source screenshot for recommendations
    ///   - modelContext: SwiftData model context
    ///   - maxResults: Maximum number of recommendations
    /// - Returns: Comprehensive recommendation results
    func generateRecommendations(
        for screenshot: Screenshot,
        in modelContext: ModelContext,
        maxResults: Int = 10
    ) async -> RecommendationResults {
        
        guard settings.enableContentDiscovery else {
            return RecommendationResults(
                sourceScreenshot: screenshot,
                confidence: 0.0,
                processingMetrics: RecommendationResults.ProcessingMetrics(
                    analysisTime: 0,
                    totalComparisons: 0,
                    cacheHitRate: 0,
                    memoryUsage: 0
                )
            )
        }
        
        logger.info("Generating comprehensive recommendations for screenshot: \\(screenshot.id)")
        
        isAnalyzing = true
        let startTime = Date()
        
        defer {
            isAnalyzing = false
        }
        
        // Get all potential candidates
        let allScreenshots = try? modelContext.fetch(FetchDescriptor<Screenshot>())
        let candidates = allScreenshots?.filter { $0.id != screenshot.id } ?? []
        
        var totalComparisons = 0
        
        // Parallel analysis of different relationship types
        async let relatedContentTask = findRelatedContent(
            for: screenshot,
            in: candidates,
            maxResults: maxResults
        )
        
        async let temporalMatchesTask = findTemporalMatches(
            for: screenshot,
            in: candidates
        )
        
        async let semanticMatchesTask = findSemanticMatches(
            for: screenshot,
            in: candidates
        )
        
        async let visualMatchesTask = findVisualMatches(
            for: screenshot,
            in: candidates
        )
        
        async let workflowMatchesTask = findWorkflowMatches(
            for: screenshot,
            in: candidates
        )
        
        let (relatedContent, temporalMatches, semanticMatches, visualMatches, workflowMatches) = await (
            relatedContentTask,
            temporalMatchesTask,
            semanticMatchesTask,
            visualMatchesTask,
            workflowMatchesTask
        )
        
        totalComparisons = candidates.count * 5 // 5 analysis types
        
        // Calculate overall confidence based on match quality
        let confidence = calculateOverallConfidence(
            relatedContent: relatedContent,
            temporal: temporalMatches,
            semantic: semanticMatches,
            visual: visualMatches,
            workflow: workflowMatches
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        let results = RecommendationResults(
            sourceScreenshot: screenshot,
            relatedContent: relatedContent,
            temporalMatches: temporalMatches,
            semanticMatches: semanticMatches,
            visualMatches: visualMatches,
            workflowMatches: workflowMatches,
            confidence: confidence,
            processingMetrics: RecommendationResults.ProcessingMetrics(
                analysisTime: processingTime,
                totalComparisons: totalComparisons,
                cacheHitRate: 0.85, // Would be calculated from actual cache
                memoryUsage: Int64(MemoryLayout<Screenshot>.size * candidates.count)
            )
        )
        
        lastAnalysisResults = results
        
        // Update user discovery profile based on results
        await updateUserDiscoveryProfile(results)
        
        logger.info("Generated \\(relatedContent.count) recommendations with \\(String(format: \"%.2f\", confidence)) confidence in \\(String(format: \"%.3f\", processingTime))s")
        
        return results
    }
    
    /// Find content clusters based on similarity patterns
    /// - Parameters:
    ///   - screenshots: Screenshots to analyze
    ///   - modelContext: SwiftData model context
    /// - Returns: Content clusters with similarity scores
    func findContentClusters(
        in screenshots: [Screenshot],
        modelContext: ModelContext
    ) async -> [ContentCluster] {
        
        logger.info("Finding content clusters in \\(screenshots.count) screenshots")
        
        var clusters: [ContentCluster] = []
        var processed: Set<UUID> = []
        
        for screenshot in screenshots {
            guard !processed.contains(screenshot.id) else { continue }
            
            let recommendations = await generateRecommendations(
                for: screenshot,
                in: modelContext,
                maxResults: 50
            )
            
            let relatedScreenshots = recommendations.relatedContent
                .filter { $0.similarityScore >= settings.minimumSimilarityScore }
                .map { $0.screenshot }
            
            if !relatedScreenshots.isEmpty {
                let cluster = ContentCluster(
                    centerScreenshot: screenshot,
                    relatedScreenshots: relatedScreenshots,
                    clusterType: determineClusterType(recommendations),
                    averageSimilarity: recommendations.relatedContent.map { $0.similarityScore }.reduce(0, +) / Double(max(recommendations.relatedContent.count, 1)),
                    temporalSpan: calculateTemporalSpan(for: [screenshot] + relatedScreenshots)
                )
                
                clusters.append(cluster)
                
                // Mark all screenshots in this cluster as processed
                processed.insert(screenshot.id)
                relatedScreenshots.forEach { processed.insert($0.id) }
            }
        }
        
        logger.info("Found \\(clusters.count) content clusters")
        return clusters
    }
    
    /// Content cluster for grouping related screenshots
    public struct ContentCluster: Identifiable {
        public let id = UUID()
        let centerScreenshot: Screenshot
        let relatedScreenshots: [Screenshot]
        let clusterType: ClusterType
        let averageSimilarity: Double
        let temporalSpan: TimeInterval
        
        enum ClusterType: String, CaseIterable {
            case temporal, semantic, visual, workflow, mixed
            
            var displayName: String {
                switch self {
                case .temporal: return "Time-based Group"
                case .semantic: return "Content Group"
                case .visual: return "Visual Group"
                case .workflow: return "Workflow Group"
                case .mixed: return "Mixed Group"
                }
            }
        }
        
        var allScreenshots: [Screenshot] {
            return [centerScreenshot] + relatedScreenshots
        }
    }
    
    // MARK: - Private Implementation
    
    private func findRelatedContent(
        for screenshot: Screenshot,
        in candidates: [Screenshot],
        maxResults: Int
    ) async -> [RelatedContent] {
        
        var relatedItems: [RelatedContent] = []
        
        for candidate in candidates.prefix(100) { // Limit for performance
            let similarity = await calculateOverallSimilarity(screenshot, candidate)
            
            if similarity >= settings.minimumSimilarityScore {
                let relationshipType = await determineRelationshipType(screenshot, candidate)
                let matchingFeatures = await findMatchingFeatures(screenshot, candidate)
                
                let relatedContent = RelatedContent(
                    screenshot: candidate,
                    similarityScore: similarity,
                    relationshipType: relationshipType,
                    matchingFeatures: matchingFeatures,
                    temporalProximity: abs(screenshot.timestamp.timeIntervalSince(candidate.timestamp)),
                    explanation: await generateSimilarityExplanation(screenshot, candidate, similarity)
                )
                
                relatedItems.append(relatedContent)
            }
        }
        
        return relatedItems
            .sorted { $0.similarityScore > $1.similarityScore }
            .prefix(maxResults)
            .map { $0 }
    }
    
    private func findTemporalMatches(
        for screenshot: Screenshot,
        in candidates: [Screenshot]
    ) async -> [TemporalMatch] {
        
        guard settings.enableTemporalAnalysis else { return [] }
        
        var matches: [TemporalMatch] = []
        
        // Find screenshots from similar times of day
        let timeOfDay = Calendar.current.component(.hour, from: screenshot.timestamp)
        let _ = Calendar.current.component(.weekday, from: screenshot.timestamp)
        
        let sameTimeOfDay = candidates.filter { candidate in
            let candidateHour = Calendar.current.component(.hour, from: candidate.timestamp)
            return abs(candidateHour - timeOfDay) <= 2 // Within 2 hours
        }
        
        if sameTimeOfDay.count >= 3 {
            let pattern = TemporalPattern(
                patternType: .daily,
                timeInterval: 86400, // 1 day
                confidence: 0.8,
                screenshots: [screenshot] + Array(sameTimeOfDay.prefix(5)),
                description: "Screenshots taken around \(timeOfDay):00",
                predictedNext: Calendar.current.date(byAdding: .day, value: 1, to: Date())
            )
            
            matches.append(TemporalMatch(
                pattern: pattern,
                screenshots: sameTimeOfDay,
                confidence: 0.8,
                timeSpan: 86400,
                frequency: .daily
            ))
        }
        
        return matches
    }
    
    private func findSemanticMatches(
        for screenshot: Screenshot,
        in candidates: [Screenshot]
    ) async -> [SemanticMatch] {
        
        guard settings.enableSemanticSimilarity else { return [] }
        
        var matches: [SemanticMatch] = []
        
        // Compare extracted text and semantic tags
        guard let sourceText = screenshot.extractedText, !sourceText.isEmpty else {
            return matches
        }
        
        for candidate in candidates.prefix(50) {
            guard let candidateText = candidate.extractedText, !candidateText.isEmpty else {
                continue
            }
            
            let textSimilarity = await calculateTextSimilarity(sourceText, candidateText)
            let sharedEntities = await findSharedEntities(screenshot, candidate)
            
            if textSimilarity >= 0.3 || !sharedEntities.isEmpty {
                let match = SemanticMatch(
                    screenshot: candidate,
                    semanticSimilarity: textSimilarity,
                    sharedEntities: sharedEntities,
                    sharedConcepts: [],
                    contextSimilarity: 0.0,
                    explanation: "Shares similar text content"
                )
                
                matches.append(match)
            }
        }
        
        return matches
            .sorted { $0.semanticSimilarity > $1.semanticSimilarity }
            .prefix(10)
            .map { $0 }
    }
    
    private func findVisualMatches(
        for screenshot: Screenshot,
        in candidates: [Screenshot]
    ) async -> [VisualMatch] {
        
        guard settings.enableVisualSimilarity else { return [] }
        
        var matches: [VisualMatch] = []
        
        // Compare visual attributes if available
        guard let sourceVisual = screenshot.visualAttributes else {
            return matches
        }
        
        for candidate in candidates.prefix(50) {
            guard let candidateVisual = candidate.visualAttributes else {
                continue
            }
            
            let colorSimilarity = await calculateColorSimilarity(sourceVisual, candidateVisual)
            let layoutSimilarity = await calculateLayoutSimilarity(sourceVisual, candidateVisual)
            
            let overallVisualSimilarity = (colorSimilarity + layoutSimilarity) / 2.0
            
            if overallVisualSimilarity >= settings.minimumSimilarityScore {
                let match = VisualMatch(
                    screenshot: candidate,
                    visualSimilarity: overallVisualSimilarity,
                    sharedVisualFeatures: [],
                    colorSimilarity: colorSimilarity,
                    layoutSimilarity: layoutSimilarity
                )
                
                matches.append(match)
            }
        }
        
        return matches
            .sorted { $0.visualSimilarity > $1.visualSimilarity }
            .prefix(10)
            .map { $0 }
    }
    
    private func findWorkflowMatches(
        for screenshot: Screenshot,
        in candidates: [Screenshot]
    ) async -> [WorkflowMatch] {
        
        // Detect workflow patterns based on temporal sequence and content similarity
        var matches: [WorkflowMatch] = []
        
        // Find screenshots that might be part of a documentation workflow
        if let extractedText = screenshot.extractedText,
           extractedText.contains("step") || extractedText.contains("tutorial") || extractedText.contains("guide") {
            
            let workflowScreenshots = candidates.filter { candidate in
                guard let candidateText = candidate.extractedText else { return false }
                return candidateText.contains("step") || candidateText.contains("tutorial") || candidateText.contains("guide")
            }
            
            if workflowScreenshots.count >= 2 {
                let match = WorkflowMatch(
                    workflowType: .documentation,
                    screenshots: Array(workflowScreenshots.prefix(5)),
                    stepPosition: 1,
                    workflowConfidence: 0.7,
                    suggestedNextSteps: ["Continue documentation sequence", "Review previous steps"]
                )
                
                matches.append(match)
            }
        }
        
        return matches
    }
    
    // MARK: - Similarity Calculation Methods
    
    private func calculateOverallSimilarity(_ screenshot1: Screenshot, _ screenshot2: Screenshot) async -> Double {
        var totalSimilarity = 0.0
        var weights = 0.0
        
        // Text similarity (high weight)
        if let text1 = screenshot1.extractedText, let text2 = screenshot2.extractedText,
           !text1.isEmpty && !text2.isEmpty {
            let textSim = await calculateTextSimilarity(text1, text2)
            totalSimilarity += textSim * 0.4
            weights += 0.4
        }
        
        // Visual similarity (medium weight)
        if let visual1 = screenshot1.visualAttributes, let visual2 = screenshot2.visualAttributes {
            let visualSim = await calculateVisualSimilarity(visual1, visual2)
            totalSimilarity += visualSim * 0.3
            weights += 0.3
        }
        
        // Temporal proximity (low weight)
        let timeDiff = abs(screenshot1.timestamp.timeIntervalSince(screenshot2.timestamp))
        let temporalSim = max(0, 1.0 - (timeDiff / (30 * 24 * 3600))) // 30-day window
        totalSimilarity += temporalSim * 0.2
        weights += 0.2
        
        // Tag similarity (medium weight)
        if let tags1 = screenshot1.userTags, let tags2 = screenshot2.userTags {
            let tagSim = calculateTagSimilarity(tags1, tags2)
            totalSimilarity += tagSim * 0.1
            weights += 0.1
        }
        
        return weights > 0 ? totalSimilarity / weights : 0.0
    }
    
    private func calculateTextSimilarity(_ text1: String, _ text2: String) async -> Double {
        // Simple word overlap similarity
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func calculateVisualSimilarity(_ visual1: VisualAttributes, _ visual2: VisualAttributes) async -> Double {
        let colorSim = await calculateColorSimilarity(visual1, visual2)
        let layoutSim = await calculateLayoutSimilarity(visual1, visual2)
        return (colorSim + layoutSim) / 2.0
    }
    
    private func calculateColorSimilarity(_ visual1: VisualAttributes, _ visual2: VisualAttributes) async -> Double {
        // Compare document type as a simple proxy for color similarity
        if visual1.isDocument == visual2.isDocument {
            return 0.8
        }
        return 0.2
    }
    
    private func calculateLayoutSimilarity(_ visual1: VisualAttributes, _ visual2: VisualAttributes) async -> Double {
        // Compare object counts as a proxy for layout similarity
        let objects1 = visual1.prominentObjects.count
        let objects2 = visual2.prominentObjects.count
        
        if objects1 == 0 && objects2 == 0 { return 1.0 }
        if objects1 == 0 || objects2 == 0 { return 0.0 }
        
        let diff = abs(objects1 - objects2)
        return max(0.0, 1.0 - Double(diff) / Double(max(objects1, objects2)))
    }
    
    private func calculateTagSimilarity(_ tags1: [String], _ tags2: [String]) -> Double {
        let set1 = Set(tags1.map { $0.lowercased() })
        let set2 = Set(tags2.map { $0.lowercased() })
        
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func determineRelationshipType(_ screenshot1: Screenshot, _ screenshot2: Screenshot) async -> RelatedContent.RelationshipType {
        // Simple heuristic-based relationship type determination
        let timeDiff = abs(screenshot1.timestamp.timeIntervalSince(screenshot2.timestamp))
        
        if timeDiff < 3600 { // Within 1 hour
            return .temporal
        }
        
        if let text1 = screenshot1.extractedText, let text2 = screenshot2.extractedText,
           !text1.isEmpty && !text2.isEmpty {
            let similarity = await calculateTextSimilarity(text1, text2)
            if similarity > 0.7 {
                return .semantic
            }
        }
        
        return .contextual
    }
    
    private func findMatchingFeatures(_ screenshot1: Screenshot, _ screenshot2: Screenshot) async -> [RelatedContent.MatchingFeature] {
        var features: [RelatedContent.MatchingFeature] = []
        
        // Text feature
        if let text1 = screenshot1.extractedText, let text2 = screenshot2.extractedText,
           !text1.isEmpty && !text2.isEmpty {
            let similarity = await calculateTextSimilarity(text1, text2)
            if similarity > 0.3 {
                features.append(RelatedContent.MatchingFeature(
                    featureType: .text,
                    similarity: similarity,
                    description: "Similar text content"
                ))
            }
        }
        
        return features
    }
    
    private func findSharedEntities(_ screenshot1: Screenshot, _ screenshot2: Screenshot) async -> [String] {
        // Extract entities from both screenshots and find overlap
        // This would integrate with existing entity extraction services
        return []
    }
    
    private func generateSimilarityExplanation(_ screenshot1: Screenshot, _ screenshot2: Screenshot, _ similarity: Double) async -> String {
        if similarity > 0.8 {
            return "Very similar content and context"
        } else if similarity > 0.6 {
            return "Similar themes and elements"
        } else {
            return "Some shared characteristics"
        }
    }
    
    private func calculateOverallConfidence(
        relatedContent: [RelatedContent],
        temporal: [TemporalMatch],
        semantic: [SemanticMatch],
        visual: [VisualMatch],
        workflow: [WorkflowMatch]
    ) -> Double {
        let contentWeight = Double(relatedContent.count) * 0.4
        let temporalWeight = Double(temporal.count) * 0.2
        let semanticWeight = Double(semantic.count) * 0.2
        let visualWeight = Double(visual.count) * 0.1
        let workflowWeight = Double(workflow.count) * 0.1
        
        let totalMatches = relatedContent.count + temporal.count + semantic.count + visual.count + workflow.count
        let weightedScore = contentWeight + temporalWeight + semanticWeight + visualWeight + workflowWeight
        
        return totalMatches > 0 ? min(1.0, weightedScore / Double(totalMatches)) : 0.0
    }
    
    private func determineClusterType(_ recommendations: RecommendationResults) -> ContentCluster.ClusterType {
        let temporalCount = recommendations.temporalMatches.count
        let semanticCount = recommendations.semanticMatches.count
        let visualCount = recommendations.visualMatches.count
        let workflowCount = recommendations.workflowMatches.count
        
        let maxCount = max(temporalCount, semanticCount, visualCount, workflowCount)
        
        if temporalCount == maxCount { return .temporal }
        if semanticCount == maxCount { return .semantic }
        if visualCount == maxCount { return .visual }
        if workflowCount == maxCount { return .workflow }
        
        return .mixed
    }
    
    private func calculateTemporalSpan(for screenshots: [Screenshot]) -> TimeInterval {
        guard !screenshots.isEmpty else { return 0 }
        
        let timestamps = screenshots.map { $0.timestamp }
        let earliest = timestamps.min() ?? Date()
        let latest = timestamps.max() ?? Date()
        
        return latest.timeIntervalSince(earliest)
    }
    
    private func updateUserDiscoveryProfile(_ results: RecommendationResults) async {
        // Update user preferences based on interaction with recommendations
        // This would be enhanced with actual user feedback
        userDiscoveryProfile.lastProfileUpdate = Date()
    }
    
    private func loadUserDiscoveryProfile() {
        // Load user discovery profile from persistence
        // For now, use default profile
        userDiscoveryProfile = UserDiscoveryProfile()
    }
}

// MARK: - Memory Management

extension ContentRecommendationEngine: MemoryTrackable {
    var memoryFootprint: Int64 {
        let relationshipsMemory = Int64(contentRelationships.count * 512) // Approximate
        let profileMemory = Int64(1024) // Profile data
        let resultsMemory = Int64(lastAnalysisResults != nil ? 2048 : 0)
        return relationshipsMemory + profileMemory + resultsMemory
    }
    
    func cleanupResources() {
        contentRelationships.removeAll()
        temporalPatterns.removeAll()
        lastAnalysisResults = nil
        
        logger.debug("ContentRecommendationEngine resources cleaned up")
    }
}