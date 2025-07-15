import Foundation
import SwiftData
import SwiftUI
import OSLog

/// Intelligent service that suggests contextual actions based on screenshot content, user behavior, and patterns
/// Provides adaptive recommendations that improve over time through machine learning insights
@MainActor
public final class SmartActionSuggestionsService: ObservableObject {
    public static let shared = SmartActionSuggestionsService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "SmartActionSuggestions")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var lastAnalysisDate: Date?
    @Published public private(set) var userBehaviorProfile: UserBehaviorProfile?
    
    // MARK: - Services
    
    private let quickActionService = QuickActionService.shared
    private let batchOperationsService = BatchOperationsService.shared
    private let hapticService = HapticFeedbackService.shared
    
    // MARK: - Configuration
    
    public struct SuggestionSettings {
        var enableIntelligentSuggestions: Bool = true
        var maxSuggestionsPerContext: Int = 5
        var minimumConfidenceThreshold: Double = 0.6
        var learningEnabled: Bool = true
        var adaptToUserBehavior: Bool = true
        var enableProactiveSuggestions: Bool = true
        var suggestionUpdateInterval: TimeInterval = 300 // 5 minutes
        
        public init() {}
    }
    
    @Published public var settings = SuggestionSettings()
    
    // MARK: - Data Models
    
    /// User behavior analysis for personalized suggestions
    public struct UserBehaviorProfile: Codable {
        var frequentActions: [String: Int] = [:]
        var timeBasedPatterns: [String: Int] = [:]
        var contentTypePreferences: [String: Double] = [:]
        var batchOperationPatterns: [String: Int] = [:]
        var lastUpdated: Date = Date()
        var totalActionsPerformed: Int = 0
        var averageSessionLength: TimeInterval = 0
        var preferredWorkflows: [ActionWorkflow] = []
        
        public init() {}
        
        public mutating func recordAction(_ action: String, timestamp: Date = Date()) {
            frequentActions[action, default: 0] += 1
            totalActionsPerformed += 1
            
            let hour = Calendar.current.component(.hour, from: timestamp)
            let timeSlot = "hour_\(hour)"
            timeBasedPatterns[timeSlot, default: 0] += 1
            
            lastUpdated = Date()
        }
        
        public mutating func recordWorkflow(_ workflow: ActionWorkflow) {
            // Update or add workflow
            if let index = preferredWorkflows.firstIndex(where: { $0.pattern == workflow.pattern }) {
                preferredWorkflows[index].frequency += 1
                preferredWorkflows[index].lastUsed = Date()
            } else {
                preferredWorkflows.append(workflow)
            }
            
            // Keep only top 10 workflows
            preferredWorkflows.sort { $0.frequency > $1.frequency }
            if preferredWorkflows.count > 10 {
                preferredWorkflows = Array(preferredWorkflows.prefix(10))
            }
        }
        
        public func getMostFrequentActions(limit: Int = 5) -> [String] {
            return frequentActions
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { $0.key }
        }
        
        public func getTimeBasedSuggestions(for time: Date) -> [String] {
            let hour = Calendar.current.component(.hour, from: time)
            let timeSlot = "hour_\(hour)"
            
            // Find actions commonly performed at this time
            return timeBasedPatterns
                .filter { $0.key == timeSlot }
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map { $0.key.replacingOccurrences(of: "hour_", with: "") }
        }
    }
    
    /// Represents a sequence of actions that users commonly perform together
    public struct ActionWorkflow: Codable, Identifiable {
        public var id = UUID()
        var pattern: [String]
        var frequency: Int = 1
        var lastUsed: Date = Date()
        var averageTimeBetweenSteps: TimeInterval = 0
        var description: String
        
        public init(pattern: [String], description: String) {
            self.id = UUID()
            self.pattern = pattern
            self.description = description
        }
    }
    
    /// Context-aware action suggestion
    public struct ActionSuggestion: Identifiable {
        public let id = UUID()
        let action: ContextualMenuService.MenuAction
        let confidence: Double
        let reason: SuggestionReason
        let priority: Int
        let estimatedTimeToComplete: TimeInterval
        let contextualHint: String
        
        public var displayPriority: Int {
            return Int(confidence * 100) + priority
        }
    }
    
    public enum SuggestionReason: String, CaseIterable {
        case frequentAction = "frequent_action"
        case timeBasedPattern = "time_based_pattern"
        case contentAnalysis = "content_analysis"
        case workflowCompletion = "workflow_completion"
        case similarScreenshots = "similar_screenshots"
        case duplicateDetection = "duplicate_detection"
        case collectionPattern = "collection_pattern"
        case batchEfficiency = "batch_efficiency"
        case seasonalPattern = "seasonal_pattern"
        case contextualRelevance = "contextual_relevance"
        
        public var displayName: String {
            switch self {
            case .frequentAction:
                return "Frequently Used"
            case .timeBasedPattern:
                return "Common at This Time"
            case .contentAnalysis:
                return "Based on Content"
            case .workflowCompletion:
                return "Complete Workflow"
            case .similarScreenshots:
                return "Similar Screenshots"
            case .duplicateDetection:
                return "Duplicate Found"
            case .collectionPattern:
                return "Collection Pattern"
            case .batchEfficiency:
                return "Batch Efficiency"
            case .seasonalPattern:
                return "Seasonal Trend"
            case .contextualRelevance:
                return "Contextually Relevant"
            }
        }
        
        public var priority: Int {
            switch self {
            case .duplicateDetection: return 100
            case .batchEfficiency: return 90
            case .workflowCompletion: return 80
            case .frequentAction: return 70
            case .contentAnalysis: return 60
            case .timeBasedPattern: return 50
            case .similarScreenshots: return 40
            case .collectionPattern: return 30
            case .contextualRelevance: return 20
            case .seasonalPattern: return 10
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        logger.info("SmartActionSuggestionsService initialized with intelligent recommendation engine")
        loadUserBehaviorProfile()
    }
    
    // MARK: - Public Interface
    
    /// Get intelligent action suggestions for a single screenshot
    public func getSuggestions(
        for screenshot: Screenshot,
        in context: ScreenshotContext = .gallery
    ) async -> [ActionSuggestion] {
        
        guard settings.enableIntelligentSuggestions else { return [] }
        
        var suggestions: [ActionSuggestion] = []
        
        // Analyze screenshot content
        let contentSuggestions = await analyzeContentForSuggestions(screenshot)
        suggestions.append(contentsOf: contentSuggestions)
        
        // Add user behavior-based suggestions
        let behaviorSuggestions = getUserBehaviorSuggestions(for: screenshot, context: context)
        suggestions.append(contentsOf: behaviorSuggestions)
        
        // Add time-based suggestions
        let timeSuggestions = getTimeBasedSuggestions(for: screenshot)
        suggestions.append(contentsOf: timeSuggestions)
        
        // Add contextual suggestions
        let contextualSuggestions = getContextualSuggestions(for: screenshot, context: context)
        suggestions.append(contentsOf: contextualSuggestions)
        
        return prioritizeAndFilterSuggestions(suggestions)
    }
    
    /// Get intelligent suggestions for multiple screenshots
    public func getBatchSuggestions(
        for screenshots: [Screenshot],
        in context: ScreenshotContext = .gallery
    ) async -> [ActionSuggestion] {
        
        guard settings.enableIntelligentSuggestions && screenshots.count >= 2 else { return [] }
        
        var suggestions: [ActionSuggestion] = []
        
        // Analyze collection patterns
        let collectionSuggestions = await analyzeCollectionPatterns(screenshots)
        suggestions.append(contentsOf: collectionSuggestions)
        
        // Detect duplicates and suggest cleanup
        let duplicateSuggestions = await analyzeDuplicateOpportunities(screenshots)
        suggestions.append(contentsOf: duplicateSuggestions)
        
        // Suggest batch operations
        let batchSuggestions = await getBatchOperationSuggestions(screenshots)
        suggestions.append(contentsOf: batchSuggestions)
        
        // Workflow completion suggestions
        let workflowSuggestions = getWorkflowCompletionSuggestions(screenshots)
        suggestions.append(contentsOf: workflowSuggestions)
        
        return prioritizeAndFilterSuggestions(suggestions)
    }
    
    /// Record user action for learning
    public func recordUserAction(
        _ action: ContextualMenuService.MenuAction,
        on screenshots: [Screenshot],
        context: ScreenshotContext,
        timestamp: Date = Date()
    ) {
        guard settings.learningEnabled else { return }
        
        if userBehaviorProfile == nil {
            userBehaviorProfile = UserBehaviorProfile()
        }
        
        userBehaviorProfile?.recordAction(action.rawValue, timestamp: timestamp)
        
        // Analyze for workflow patterns
        analyzeWorkflowPatterns(action: action, screenshots: screenshots, context: context)
        
        saveUserBehaviorProfile()
        
        logger.debug("Recorded user action: \\(action.rawValue) for \\(screenshots.count) screenshot(s)")
        
        // Provide contextual haptic feedback for learning
        hapticService.triggerContextualFeedback(
            for: .smartSuggestion,
            isSuccess: true,
            itemCount: screenshots.count
        )
    }
    
    /// Get proactive suggestions based on current state
    public func getProactiveSuggestions(in modelContext: ModelContext) async -> [ActionSuggestion] {
        guard settings.enableProactiveSuggestions else { return [] }
        
        var suggestions: [ActionSuggestion] = []
        
        // Analyze screenshot collection health
        suggestions.append(contentsOf: await analyzeCollectionHealth(in: modelContext))
        
        // Suggest maintenance tasks
        suggestions.append(contentsOf: await getMaintenanceSuggestions(in: modelContext))
        
        // Suggest organization improvements
        suggestions.append(contentsOf: await getOrganizationSuggestions(in: modelContext))
        
        return prioritizeAndFilterSuggestions(suggestions)
    }
    
    // MARK: - Content Analysis
    
    private func analyzeContentForSuggestions(_ screenshot: Screenshot) async -> [ActionSuggestion] {
        var suggestions: [ActionSuggestion] = []
        
        // OCR text analysis
        if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
            // Detect actionable content
            if extractedText.contains(regex: #"\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"#) {
                suggestions.append(ActionSuggestion(
                    action: .copy,
                    confidence: 0.85,
                    reason: .contentAnalysis,
                    priority: 80,
                    estimatedTimeToComplete: 2,
                    contextualHint: "Email address detected"
                ))
            }
            
            if extractedText.contains(regex: #"\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b"#) {
                suggestions.append(ActionSuggestion(
                    action: .copy,
                    confidence: 0.90,
                    reason: .contentAnalysis,
                    priority: 85,
                    estimatedTimeToComplete: 2,
                    contextualHint: "Phone number detected"
                ))
            }
            
            if extractedText.contains(regex: #"\\bhttps?://[^\\s]+\\b"#) {
                suggestions.append(ActionSuggestion(
                    action: .share,
                    confidence: 0.75,
                    reason: .contentAnalysis,
                    priority: 70,
                    estimatedTimeToComplete: 5,
                    contextualHint: "URL detected"
                ))
            }
            
            // Document detection
            if extractedText.count > 100 && extractedText.contains(regex: #"\\b(invoice|receipt|bill|document)\\b"#) {
                suggestions.append(ActionSuggestion(
                    action: .addToCollection,
                    confidence: 0.80,
                    reason: .contentAnalysis,
                    priority: 75,
                    estimatedTimeToComplete: 10,
                    contextualHint: "Document detected - consider organizing"
                ))
            }
        }
        
        // Visual analysis
        if let visualAttributes = screenshot.visualAttributes {
            // Receipt detection
            if visualAttributes.isDocument {
                suggestions.append(ActionSuggestion(
                    action: .tag,
                    confidence: 0.75,
                    reason: .contentAnalysis,
                    priority: 70,
                    estimatedTimeToComplete: 15,
                    contextualHint: "Document detected - add tags for easy finding"
                ))
            }
            
            // Multiple objects suggest sharing or organizing
            if visualAttributes.prominentObjects.count >= 3 {
                suggestions.append(ActionSuggestion(
                    action: .share,
                    confidence: 0.70,
                    reason: .contentAnalysis,
                    priority: 65,
                    estimatedTimeToComplete: 8,
                    contextualHint: "Rich content - great for sharing"
                ))
            }
        }
        
        return suggestions
    }
    
    // MARK: - User Behavior Analysis
    
    private func getUserBehaviorSuggestions(
        for screenshot: Screenshot,
        context: ScreenshotContext
    ) -> [ActionSuggestion] {
        
        guard let profile = userBehaviorProfile else { return [] }
        
        var suggestions: [ActionSuggestion] = []
        
        // Most frequent actions
        let frequentActions = profile.getMostFrequentActions(limit: 3)
        for (index, actionString) in frequentActions.enumerated() {
            if let action = ContextualMenuService.MenuAction(rawValue: actionString) {
                let frequency = profile.frequentActions[actionString] ?? 0
                let confidence = min(0.95, 0.5 + (Double(frequency) / Double(profile.totalActionsPerformed)) * 2)
                
                suggestions.append(ActionSuggestion(
                    action: action,
                    confidence: confidence,
                    reason: .frequentAction,
                    priority: 70 - (index * 10),
                    estimatedTimeToComplete: action.estimatedTimePerItem,
                    contextualHint: "You use this action frequently"
                ))
            }
        }
        
        return suggestions
    }
    
    private func getTimeBasedSuggestions(for screenshot: Screenshot) -> [ActionSuggestion] {
        guard let profile = userBehaviorProfile else { return [] }
        
        var suggestions: [ActionSuggestion] = []
        
        let hour = Calendar.current.component(.hour, from: Date())
        let timeSlot = "hour_\(hour)"
        
        if let frequency = profile.timeBasedPatterns[timeSlot], frequency >= 3 {
            // Common actions at this time of day
            let confidence = min(0.85, 0.4 + (Double(frequency) / 10.0))
            
            // Suggest common morning/evening actions
            if hour >= 9 && hour <= 11 { // Morning
                suggestions.append(ActionSuggestion(
                    action: .addToCollection,
                    confidence: confidence,
                    reason: .timeBasedPattern,
                    priority: 60,
                    estimatedTimeToComplete: 10,
                    contextualHint: "Morning organization routine"
                ))
            } else if hour >= 17 && hour <= 19 { // Evening
                suggestions.append(ActionSuggestion(
                    action: .share,
                    confidence: confidence,
                    reason: .timeBasedPattern,
                    priority: 60,
                    estimatedTimeToComplete: 8,
                    contextualHint: "Evening sharing time"
                ))
            }
        }
        
        return suggestions
    }
    
    private func getContextualSuggestions(
        for screenshot: Screenshot,
        context: ScreenshotContext
    ) -> [ActionSuggestion] {
        
        var suggestions: [ActionSuggestion] = []
        
        switch context {
        case .gallery:
            suggestions.append(ActionSuggestion(
                action: .viewDetails,
                confidence: 0.60,
                reason: .contextualRelevance,
                priority: 40,
                estimatedTimeToComplete: 5,
                contextualHint: "View full details"
            ))
            
        case .search:
            suggestions.append(ActionSuggestion(
                action: .addToCollection,
                confidence: 0.70,
                reason: .contextualRelevance,
                priority: 50,
                estimatedTimeToComplete: 10,
                contextualHint: "Organize search results"
            ))
            
        case .collection:
            suggestions.append(ActionSuggestion(
                action: .share,
                confidence: 0.75,
                reason: .contextualRelevance,
                priority: 55,
                estimatedTimeToComplete: 8,
                contextualHint: "Share from collection"
            ))
            
        case .group:
            suggestions.append(ActionSuggestion(
                action: .export,
                confidence: 0.65,
                reason: .contextualRelevance,
                priority: 45,
                estimatedTimeToComplete: 20,
                contextualHint: "Export group"
            ))
            
        case .duplicates:
            suggestions.append(ActionSuggestion(
                action: .delete,
                confidence: 0.90,
                reason: .duplicateDetection,
                priority: 95,
                estimatedTimeToComplete: 3,
                contextualHint: "Clean up duplicates"
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Batch Analysis
    
    private func analyzeCollectionPatterns(_ screenshots: [Screenshot]) async -> [ActionSuggestion] {
        var suggestions: [ActionSuggestion] = []
        
        // Analyze timestamp patterns
        let timeSpread = screenshots.max(by: { $0.timestamp < $1.timestamp })?.timestamp.timeIntervalSince(
            screenshots.min(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
        ) ?? 0
        
        if timeSpread <= 300 { // Screenshots within 5 minutes
            suggestions.append(ActionSuggestion(
                action: .addToCollection,
                confidence: 0.85,
                reason: .collectionPattern,
                priority: 80,
                estimatedTimeToComplete: 15,
                contextualHint: "Related screenshots - create collection"
            ))
        }
        
        // Analyze content similarity
        let hasCommonTags = !screenshots.compactMap { $0.userTags }.flatMap { $0 }.isEmpty
        if hasCommonTags {
            suggestions.append(ActionSuggestion(
                action: .tag,
                confidence: 0.75,
                reason: .collectionPattern,
                priority: 70,
                estimatedTimeToComplete: 20,
                contextualHint: "Add common tags"
            ))
        }
        
        return suggestions
    }
    
    private func analyzeDuplicateOpportunities(_ screenshots: [Screenshot]) async -> [ActionSuggestion] {
        var suggestions: [ActionSuggestion] = []
        
        // Quick duplicate check
        var sizeGroups: [Int: Int] = [:]
        for screenshot in screenshots {
            let size = screenshot.imageData.count
            sizeGroups[size, default: 0] += 1
        }
        
        let hasPotentialDuplicates = sizeGroups.values.contains { $0 >= 2 }
        
        if hasPotentialDuplicates {
            suggestions.append(ActionSuggestion(
                action: .delete, // Will be handled as duplicate cleanup
                confidence: 0.80,
                reason: .duplicateDetection,
                priority: 90,
                estimatedTimeToComplete: 30,
                contextualHint: "Potential duplicates detected"
            ))
        }
        
        return suggestions
    }
    
    private func getBatchOperationSuggestions(_ screenshots: [Screenshot]) async -> [ActionSuggestion] {
        let batchSuggestions = await batchOperationsService.getBatchSuggestions(for: screenshots)
        
        return batchSuggestions.prefix(3).map { batchOp in
            ActionSuggestion(
                action: mapBatchOperationToMenuAction(batchOp),
                confidence: 0.70,
                reason: .batchEfficiency,
                priority: 75,
                estimatedTimeToComplete: batchOp.estimatedTimePerItem * Double(screenshots.count),
                contextualHint: "Efficient batch operation"
            )
        }
    }
    
    private func getWorkflowCompletionSuggestions(_ screenshots: [Screenshot]) -> [ActionSuggestion] {
        guard let profile = userBehaviorProfile else { return [] }
        
        var suggestions: [ActionSuggestion] = []
        
        // Find matching workflow patterns
        for workflow in profile.preferredWorkflows.prefix(3) {
            if workflow.frequency >= 3 { // At least used 3 times
                // Suggest next step in workflow
                if let nextAction = workflow.pattern.first,
                   let menuAction = ContextualMenuService.MenuAction(rawValue: nextAction) {
                    
                    let confidence = min(0.85, 0.5 + (Double(workflow.frequency) / 20.0))
                    
                    suggestions.append(ActionSuggestion(
                        action: menuAction,
                        confidence: confidence,
                        reason: .workflowCompletion,
                        priority: 80,
                        estimatedTimeToComplete: menuAction.estimatedTimePerItem,
                        contextualHint: "Continue \\(workflow.description)"
                    ))
                }
            }
        }
        
        return suggestions
    }
    
    // MARK: - Proactive Analysis
    
    private func analyzeCollectionHealth(in modelContext: ModelContext) async -> [ActionSuggestion] {
        var suggestions: [ActionSuggestion] = []
        
        do {
            // Count unorganized screenshots
            let unorganizedDescriptor = FetchDescriptor<Screenshot>(
                predicate: #Predicate { $0.collections.isEmpty && $0.groups.isEmpty }
            )
            let unorganizedCount = try modelContext.fetchCount(unorganizedDescriptor)
            
            if unorganizedCount >= 20 {
                suggestions.append(ActionSuggestion(
                    action: .addToCollection,
                    confidence: 0.80,
                    reason: .contextualRelevance,
                    priority: 75,
                    estimatedTimeToComplete: 60,
                    contextualHint: "\\(unorganizedCount) screenshots need organization"
                ))
            }
            
            // Count screenshots without tags
            let untaggedDescriptor = FetchDescriptor<Screenshot>(
                predicate: #Predicate { $0.userTags == nil || $0.userTags!.isEmpty }
            )
            let untaggedCount = try modelContext.fetchCount(untaggedDescriptor)
            
            if untaggedCount >= 15 {
                suggestions.append(ActionSuggestion(
                    action: .tag,
                    confidence: 0.70,
                    reason: .contextualRelevance,
                    priority: 65,
                    estimatedTimeToComplete: 45,
                    contextualHint: "\\(untaggedCount) screenshots could use tags"
                ))
            }
            
        } catch {
            logger.error("Failed to analyze collection health: \\(error.localizedDescription)")
        }
        
        return suggestions
    }
    
    private func getMaintenanceSuggestions(in modelContext: ModelContext) async -> [ActionSuggestion] {
        var suggestions: [ActionSuggestion] = []
        
        // Suggest duplicate cleanup if last analysis was more than a week ago
        if let lastAnalysis = DuplicateDetectionService.shared.lastAnalysisDate {
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
            if lastAnalysis < weekAgo {
                suggestions.append(ActionSuggestion(
                    action: .delete, // Will trigger duplicate analysis
                    confidence: 0.75,
                    reason: .contextualRelevance,
                    priority: 70,
                    estimatedTimeToComplete: 120,
                    contextualHint: "Time for duplicate cleanup"
                ))
            }
        }
        
        return suggestions
    }
    
    private func getOrganizationSuggestions(in modelContext: ModelContext) async -> [ActionSuggestion] {
        var suggestions: [ActionSuggestion] = []
        
        // Suggest creating collections based on patterns
        do {
            let recentScreenshots = try modelContext.fetch(FetchDescriptor<Screenshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            ))
            
            // Group by common OCR patterns
            let screenshots = Array(recentScreenshots.prefix(50))
            let commonWords = findCommonWords(in: screenshots)
            
            if commonWords.count >= 3 {
                suggestions.append(ActionSuggestion(
                    action: .addToCollection,
                    confidence: 0.65,
                    reason: .collectionPattern,
                    priority: 60,
                    estimatedTimeToComplete: 30,
                    contextualHint: "Common themes detected - create collections"
                ))
            }
            
        } catch {
            logger.error("Failed to get organization suggestions: \\(error.localizedDescription)")
        }
        
        return suggestions
    }
    
    // MARK: - Helper Methods
    
    private func findCommonWords(in screenshots: [Screenshot]) -> [String] {
        var wordCounts: [String: Int] = [:]
        
        for screenshot in screenshots {
            if let text = screenshot.extractedText {
                let words = text.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { $0.count >= 4 } // Only meaningful words
                
                for word in words {
                    wordCounts[word, default: 0] += 1
                }
            }
        }
        
        return wordCounts
            .filter { $0.value >= 3 } // Appears in at least 3 screenshots
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    private func prioritizeAndFilterSuggestions(_ suggestions: [ActionSuggestion]) -> [ActionSuggestion] {
        return suggestions
            .filter { $0.confidence >= settings.minimumConfidenceThreshold }
            .sorted { $0.displayPriority > $1.displayPriority }
            .removingDuplicateActions()
            .prefix(settings.maxSuggestionsPerContext)
            .map { $0 }
    }
    
    private func mapBatchOperationToMenuAction(_ batchOp: BatchOperationsService.BatchOperation) -> ContextualMenuService.MenuAction {
        switch batchOp {
        case .delete:
            return .delete
        case .addToCollection:
            return .addToCollection
        case .addTags:
            return .tag
        case .setFavorite:
            return .favorite
        case .export:
            return .export
        case .copyToClipboard:
            return .copy
        case .share:
            return .share
        case .duplicate:
            return .duplicate
        default:
            return .viewDetails
        }
    }
    
    // MARK: - Workflow Analysis
    
    private func analyzeWorkflowPatterns(
        action: ContextualMenuService.MenuAction,
        screenshots: [Screenshot],
        context: ScreenshotContext
    ) {
        // Track action sequences to identify workflow patterns
        // This is a simplified implementation - in production, you'd want more sophisticated analysis
        
        if var profile = userBehaviorProfile {
            let workflowKey = "\(context.rawValue)_\(action.rawValue)"
            profile.batchOperationPatterns[workflowKey, default: 0] += 1
            userBehaviorProfile = profile
        }
    }
    
    // MARK: - Persistence
    
    private func loadUserBehaviorProfile() {
        guard let data = UserDefaults.standard.data(forKey: "UserBehaviorProfile") else {
            userBehaviorProfile = UserBehaviorProfile()
            return
        }
        
        do {
            userBehaviorProfile = try JSONDecoder().decode(UserBehaviorProfile.self, from: data)
        } catch {
            logger.error("Failed to load user behavior profile: \\(error.localizedDescription)")
            userBehaviorProfile = UserBehaviorProfile()
        }
    }
    
    private func saveUserBehaviorProfile() {
        guard let profile = userBehaviorProfile else { return }
        
        do {
            let data = try JSONEncoder().encode(profile)
            UserDefaults.standard.set(data, forKey: "UserBehaviorProfile")
        } catch {
            logger.error("Failed to save user behavior profile: \\(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

public enum ScreenshotContext: String, CaseIterable {
    case gallery = "gallery"
    case search = "search"
    case collection = "collection"
    case group = "group"
    case duplicates = "duplicates"
}

// MARK: - Extensions

extension Array where Element == SmartActionSuggestionsService.ActionSuggestion {
    func removingDuplicateActions() -> [SmartActionSuggestionsService.ActionSuggestion] {
        var seen: Set<String> = []
        return filter { suggestion in
            let key = suggestion.action.rawValue
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
}

extension ContextualMenuService.MenuAction {
    var estimatedTimePerItem: TimeInterval {
        switch self {
        case .delete, .favorite:
            return 0.5
        case .copy, .share:
            return 2.0
        case .tag, .addToCollection:
            return 5.0
        case .export:
            return 10.0
        case .viewDetails, .editMetadata:
            return 3.0
        case .duplicate:
            return 1.0
        }
    }
}

extension String {
    func contains(regex pattern: String) -> Bool {
        return range(of: pattern, options: .regularExpression) != nil
    }
}