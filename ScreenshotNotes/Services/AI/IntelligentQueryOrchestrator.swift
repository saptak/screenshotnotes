import Foundation
import SwiftData
import SwiftUI
import OSLog

/// Intelligent query orchestrator with context awareness and machine learning
/// Coordinates all search components and learns from user behavior patterns
@MainActor
public final class IntelligentQueryOrchestrator: ObservableObject {
    public static let shared = IntelligentQueryOrchestrator()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "IntelligentQueryOrchestrator")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isProcessing = false
    @Published public private(set) var currentContext: SearchContext?
    @Published public private(set) var queryInsights: [QueryInsight] = []
    @Published public private(set) var userSearchProfile: UserSearchProfile?
    @Published public private(set) var contextualSuggestions: [ContextualSuggestion] = []
    @Published public private(set) var searchSession: SearchSession?
    
    // MARK: - Services
    
    private let naturalLanguageSearch = NaturalLanguageSearchService.shared
    private let temporalProcessor = TemporalQueryProcessor.shared
    private let contentAwareSearch = ContentAwareSearchEngine.shared
    private let voiceInterface = VoiceSearchInterface.shared
    private let hapticService = HapticFeedbackService.shared
    private let errorService = ErrorHandlingService.shared
    
    // MARK: - Configuration
    
    public struct OrchestratorSettings {
        var enableContextLearning: Bool = true
        var enableBehaviorAnalysis: Bool = true
        var enablePredictiveSearch: Bool = true
        var enableAdaptiveSuggestions: Bool = true
        var contextWindowSize: Int = 10
        var learningConfidenceThreshold: Double = 0.7
        var maxSessionLength: TimeInterval = 1800 // 30 minutes
        var enableCrossSessionLearning: Bool = true
        var adaptationSpeed: Double = 0.1
        
        public init() {}
    }
    
    @Published public var settings = OrchestratorSettings()
    
    // MARK: - Data Models
    
    /// Comprehensive search context with learning capabilities
    public struct SearchContext: Identifiable {
        public let id = UUID()
        let sessionId: UUID
        let userIntent: UserIntent
        let temporalContext: TemporalContext?
        let contentContext: ContentContext
        let deviceContext: DeviceContext
        let behaviorContext: BehaviorContext
        let environmentContext: EnvironmentContext
        let timestamp: Date
        
        public enum UserIntent: String, CaseIterable {
            case findSpecific = "find_specific"
            case browseRecent = "browse_recent"
            case organizeContent = "organize_content"
            case shareContent = "share_content"
            case analyzePatterns = "analyze_patterns"
            case troubleshoot = "troubleshoot"
            case discovery = "discovery"
            case workflow = "workflow"
            
            public var displayName: String {
                switch self {
                case .findSpecific: return "Find Specific Content"
                case .browseRecent: return "Browse Recent Items"
                case .organizeContent: return "Organize Content"
                case .shareContent: return "Share Content"
                case .analyzePatterns: return "Analyze Patterns"
                case .troubleshoot: return "Troubleshoot"
                case .discovery: return "Discover Content"
                case .workflow: return "Complete Workflow"
                }
            }
        }
        
        public struct TemporalContext {
            let timeOfDay: TimeOfDay
            let dayOfWeek: DayOfWeek
            let isWeekend: Bool
            let recentActivity: [String]
            let timeBasedPatterns: [String]
            
            public enum TimeOfDay: String, CaseIterable {
                case earlyMorning = "early_morning"    // 5-8 AM
                case morning = "morning"               // 8-12 PM
                case afternoon = "afternoon"           // 12-5 PM
                case evening = "evening"               // 5-9 PM
                case night = "night"                   // 9 PM-5 AM
            }
            
            public enum DayOfWeek: String, CaseIterable {
                case monday, tuesday, wednesday, thursday, friday, saturday, sunday
            }
        }
        
        public struct ContentContext {
            let recentScreenshots: [Screenshot]
            let dominantContentTypes: [String]
            let frequentApps: [String]
            let contentPatterns: [String]
            let visualThemes: [String]
        }
        
        public struct DeviceContext {
            let deviceType: String
            let orientation: String
            let inputMethod: InputMethod
            let batteryLevel: Float?
            let networkStatus: NetworkStatus
            
            public enum InputMethod: String, CaseIterable {
                case touch = "touch"
                case voice = "voice"
                case keyboard = "keyboard"
                case external = "external"
            }
            
            public enum NetworkStatus: String, CaseIterable {
                case wifi = "wifi"
                case cellular = "cellular"
                case offline = "offline"
            }
        }
        
        public struct BehaviorContext {
            let searchFrequency: Double
            let averageSessionLength: TimeInterval
            let preferredSearchTypes: [String]
            let interactionPatterns: [String]
            let successRate: Double
        }
        
        public struct EnvironmentContext {
            let location: LocationContext?
            let calendar: CalendarContext?
            let social: SocialContext?
            
            public struct LocationContext {
                let isHome: Bool
                let isWork: Bool
                let isTravel: Bool
                let locationCategory: String
            }
            
            public struct CalendarContext {
                let hasUpcomingEvents: Bool
                let currentEventType: String?
                let timeUntilNextEvent: TimeInterval?
            }
            
            public struct SocialContext {
                let isSharing: Bool
                let collaborationMode: Bool
                let presentationMode: Bool
            }
        }
    }
    
    /// Query insight for learning and optimization
    public struct QueryInsight: Identifiable {
        public let id = UUID()
        let query: String
        let intent: SearchContext.UserIntent
        let confidence: Double
        let resultQuality: Double
        let userSatisfaction: Double
        let timeToResult: TimeInterval
        let refinements: [String]
        let timestamp: Date
        let context: SearchContext
        let learningPoints: [String]
        
        public init(
            query: String,
            intent: SearchContext.UserIntent,
            confidence: Double,
            resultQuality: Double,
            userSatisfaction: Double,
            timeToResult: TimeInterval,
            refinements: [String] = [],
            timestamp: Date = Date(),
            context: SearchContext,
            learningPoints: [String] = []
        ) {
            self.query = query
            self.intent = intent
            self.confidence = confidence
            self.resultQuality = resultQuality
            self.userSatisfaction = userSatisfaction
            self.timeToResult = timeToResult
            self.refinements = refinements
            self.timestamp = timestamp
            self.context = context
            self.learningPoints = learningPoints
        }
    }
    
    /// User search profile for personalization
    public struct UserSearchProfile: Codable {
        var searchFrequency: Double = 0.0
        var preferredInputMethods: [String: Double] = [:]
        var commonSearchTerms: [String: Int] = [:]
        var temporalPatterns: [String: Double] = [:]
        var contentPreferences: [String: Double] = [:]
        var successPatterns: [String: Double] = [:]
        var learningInsights: [String] = []
        var adaptationLevel: Double = 0.5
        var lastUpdated: Date = Date()
        var totalSearches: Int = 0
        var averageSessionLength: TimeInterval = 0
        var satisfactionScore: Double = 0.7
        
        public init() {}
        
        public mutating func updateProfile(from insight: QueryInsight) {
            totalSearches += 1
            satisfactionScore = (satisfactionScore + insight.userSatisfaction) / 2.0
            
            // Update temporal patterns
            let timeKey = timeKey(for: insight.timestamp)
            temporalPatterns[timeKey, default: 0.0] += 1.0
            
            // Update search terms
            let terms = insight.query.lowercased().components(separatedBy: .whitespacesAndNewlines)
            for term in terms where term.count > 2 {
                commonSearchTerms[term, default: 0] += 1
            }
            
            // Update success patterns
            if insight.userSatisfaction > 0.7 {
                successPatterns[insight.intent.rawValue, default: 0.0] += insight.userSatisfaction
            }
            
            lastUpdated = Date()
        }
        
        private func timeKey(for date: Date) -> String {
            let hour = Calendar.current.component(.hour, from: date)
            let dayOfWeek = Calendar.current.component(.weekday, from: date)
            return "\(dayOfWeek)_\(hour)"
        }
        
        public func getTopSearchTerms(limit: Int = 10) -> [String] {
            return commonSearchTerms
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { $0.key }
        }
        
        public func getPeakSearchTimes() -> [String] {
            return temporalPatterns
                .sorted { $0.value > $1.value }
                .prefix(5)
                .map { $0.key }
        }
    }
    
    /// Contextual suggestion with learning
    public struct ContextualSuggestion: Identifiable {
        public let id = UUID()
        let text: String
        let type: SuggestionType
        let confidence: Double
        let context: String
        let learningSource: LearningSource
        let adaptationScore: Double
        
        public enum SuggestionType: String, CaseIterable {
            case temporal = "temporal"
            case behavioral = "behavioral"
            case content = "content"
            case predictive = "predictive"
            case adaptive = "adaptive"
            case social = "social"
        }
        
        public enum LearningSource: String, CaseIterable {
            case userHistory = "user_history"
            case temporalPatterns = "temporal_patterns"
            case contentAnalysis = "content_analysis"
            case behaviorModeling = "behavior_modeling"
            case contextAwareness = "context_awareness"
            case machineLearning = "machine_learning"
        }
    }
    
    /// Search session for tracking user behavior
    public struct SearchSession: Identifiable {
        public let id = UUID()
        let startTime: Date
        var endTime: Date?
        var queries: [String] = []
        var results: [Int] = []
        var satisfactionScores: [Double] = []
        var context: SearchContext
        var intent: SearchContext.UserIntent
        var wasSuccessful: Bool = false
        
        public init(context: SearchContext, intent: SearchContext.UserIntent) {
            self.startTime = Date()
            self.context = context
            self.intent = intent
        }
        
        public var duration: TimeInterval {
            return (endTime ?? Date()).timeIntervalSince(startTime)
        }
        
        public var averageSatisfaction: Double {
            guard !satisfactionScores.isEmpty else { return 0.0 }
            return satisfactionScores.reduce(0, +) / Double(satisfactionScores.count)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        logger.info("IntelligentQueryOrchestrator initialized with context awareness and learning")
        loadUserSearchProfile()
    }
    
    // MARK: - Public Interface
    
    /// Process intelligent search with full context awareness
    /// - Parameters:
    ///   - query: Natural language search query
    ///   - inputMethod: How the query was entered
    ///   - modelContext: SwiftData model context
    /// - Returns: Contextually enhanced search results
    public func processIntelligentSearch(
        query: String,
        inputMethod: SearchContext.DeviceContext.InputMethod = .touch,
        in modelContext: ModelContext
    ) async -> [Screenshot] {
        
        logger.info("Processing intelligent search: '\(query)' via \(inputMethod.rawValue)")
        
        isProcessing = true
        let startTime = Date()
        
        defer {
            isProcessing = false
        }
        
        // Step 1: Build comprehensive search context
        let searchContext = await buildSearchContext(for: query, inputMethod: inputMethod, in: modelContext)
        currentContext = searchContext
        
        // Step 2: Start or continue search session
        await manageSearchSession(context: searchContext, query: query)
        
        // Step 3: Analyze query with full context
        let (intent, confidence) = await analyzeQueryIntent(query, context: searchContext)
        
        // Step 4: Process query through appropriate services
        let results = await coordinateSearch(
            query: query,
            intent: intent,
            context: searchContext,
            in: modelContext
        )
        
        // Step 5: Enhance results with contextual ranking
        let enhancedResults = await enhanceResultsWithContext(results, context: searchContext)
        
        // Step 6: Learn from search interaction
        let processingTime = Date().timeIntervalSince(startTime)
        await recordSearchInsight(
            query: query,
            intent: intent,
            confidence: confidence,
            results: enhancedResults,
            processingTime: processingTime,
            context: searchContext
        )
        
        // Step 7: Generate contextual suggestions for next search
        await generateAdaptiveSuggestions(based: searchContext, results: enhancedResults)
        
        logger.info("Intelligent search completed: \(enhancedResults.count) results in \(String(format: "%.2f", processingTime))s")
        
        return enhancedResults
    }
    
    /// Get adaptive suggestions based on current context
    /// - Parameter query: Partial or complete query
    /// - Returns: Context-aware suggestions with learning
    public func getAdaptiveSuggestions(for query: String = "") async -> [ContextualSuggestion] {
        var suggestions: [ContextualSuggestion] = []
        
        // Get context-based suggestions
        if let context = currentContext {
            suggestions.append(contentsOf: await generateContextBasedSuggestions(context, query: query))
        }
        
        // Get behavior-based suggestions
        if let profile = userSearchProfile {
            suggestions.append(contentsOf: await generateBehaviorBasedSuggestions(profile, query: query))
        }
        
        // Get temporal suggestions
        suggestions.append(contentsOf: await generateTemporalSuggestions(query: query))
        
        // Get predictive suggestions
        if settings.enablePredictiveSearch {
            suggestions.append(contentsOf: await generatePredictiveSuggestions(query: query))
        }
        
        // Sort by confidence and adaptation score
        let sortedSuggestions = suggestions
            .sorted { ($0.confidence + $0.adaptationScore) > ($1.confidence + $1.adaptationScore) }
            .prefix(8)
            .map { $0 }
        
        contextualSuggestions = sortedSuggestions
        return sortedSuggestions
    }
    
    /// Record user feedback for learning
    /// - Parameters:
    ///   - query: Original search query
    ///   - satisfactionScore: User satisfaction (0.0 - 1.0)
    ///   - resultCount: Number of results found
    ///   - wasHelpful: Whether results were helpful
    public func recordUserFeedback(
        for query: String,
        satisfactionScore: Double,
        resultCount: Int,
        wasHelpful: Bool
    ) async {
        
        logger.debug("Recording user feedback: query='\(query)', satisfaction=\(satisfactionScore), helpful=\(wasHelpful)")
        
        // Update current session
        if var session = searchSession {
            session.satisfactionScores.append(satisfactionScore)
            session.wasSuccessful = wasHelpful
            searchSession = session
        }
        
        // Update user profile
        if var profile = userSearchProfile {
            profile.satisfactionScore = (profile.satisfactionScore + satisfactionScore) / 2.0
            
            // Learn from successful patterns
            if wasHelpful && satisfactionScore > settings.learningConfidenceThreshold {
                let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
                for term in queryTerms where term.count > 2 {
                    profile.successPatterns[term, default: 0.0] += satisfactionScore
                }
            }
            
            userSearchProfile = profile
            saveUserSearchProfile()
        }
        
        // Adapt suggestions based on feedback
        if settings.enableAdaptiveSuggestions {
            await adaptSuggestionsBasedOnFeedback(query: query, satisfaction: satisfactionScore)
        }
        
        // Provide haptic feedback
        hapticService.triggerContextualFeedback(
            for: .smartSuggestion,
            isSuccess: wasHelpful,
            itemCount: resultCount
        )
    }
    
    /// Get search insights for analytics
    /// - Parameter timeframe: Time period for insights
    /// - Returns: Search insights and patterns
    public func getSearchInsights(timeframe: TimeInterval = 604800) -> [QueryInsight] { // Default: 1 week
        let cutoffDate = Date().addingTimeInterval(-timeframe)
        return queryInsights.filter { $0.timestamp >= cutoffDate }
    }
    
    /// Reset learning data and start fresh
    public func resetLearningData() {
        queryInsights.removeAll()
        userSearchProfile = UserSearchProfile()
        contextualSuggestions.removeAll()
        saveUserSearchProfile()
        
        logger.info("Learning data reset successfully")
    }
    
    // MARK: - Context Building
    
    private func buildSearchContext(
        for query: String,
        inputMethod: SearchContext.DeviceContext.InputMethod,
        in modelContext: ModelContext
    ) async -> SearchContext {
        
        // Temporal context
        let temporalContext = await buildTemporalContext()
        
        // Content context
        let contentContext = await buildContentContext(in: modelContext)
        
        // Device context
        let deviceContext = buildDeviceContext(inputMethod: inputMethod)
        
        // Behavior context
        let behaviorContext = buildBehaviorContext()
        
        // Environment context
        let environmentContext = await buildEnvironmentContext()
        
        return SearchContext(
            sessionId: searchSession?.id ?? UUID(),
            userIntent: .findSpecific, // Will be determined later
            temporalContext: temporalContext,
            contentContext: contentContext,
            deviceContext: deviceContext,
            behaviorContext: behaviorContext,
            environmentContext: environmentContext,
            timestamp: Date()
        )
    }
    
    private func buildTemporalContext() async -> SearchContext.TemporalContext {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        
        let timeOfDay: SearchContext.TemporalContext.TimeOfDay
        switch hour {
        case 5..<8: timeOfDay = .earlyMorning
        case 8..<12: timeOfDay = .morning
        case 12..<17: timeOfDay = .afternoon
        case 17..<21: timeOfDay = .evening
        default: timeOfDay = .night
        }
        
        let dayOfWeek = SearchContext.TemporalContext.DayOfWeek(
            rawValue: calendar.weekdaySymbols[weekday - 1].lowercased()
        ) ?? .monday
        
        let isWeekend = weekday == 1 || weekday == 7
        
        // Get recent activity patterns
        let recentActivity = getRecentActivityPatterns()
        let timeBasedPatterns = getTimeBasedPatterns(for: timeOfDay)
        
        return SearchContext.TemporalContext(
            timeOfDay: timeOfDay,
            dayOfWeek: dayOfWeek,
            isWeekend: isWeekend,
            recentActivity: recentActivity,
            timeBasedPatterns: timeBasedPatterns
        )
    }
    
    private func buildContentContext(in modelContext: ModelContext) async -> SearchContext.ContentContext {
        do {
            // Get recent screenshots for context
            let recentDescriptor = FetchDescriptor<Screenshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let recentScreenshots = try modelContext.fetch(recentDescriptor).prefix(20).map { $0 }
            
            // Analyze content patterns
            let dominantContentTypes = await analyzeDominantContentTypes(recentScreenshots)
            let frequentApps = await analyzeFrequentApps(recentScreenshots)
            let contentPatterns = await analyzeContentPatterns(recentScreenshots)
            let visualThemes = await analyzeVisualThemes(recentScreenshots)
            
            return SearchContext.ContentContext(
                recentScreenshots: recentScreenshots,
                dominantContentTypes: dominantContentTypes,
                frequentApps: frequentApps,
                contentPatterns: contentPatterns,
                visualThemes: visualThemes
            )
            
        } catch {
            logger.error("Failed to build content context: \(error.localizedDescription)")
            return SearchContext.ContentContext(
                recentScreenshots: [],
                dominantContentTypes: [],
                frequentApps: [],
                contentPatterns: [],
                visualThemes: []
            )
        }
    }
    
    private func buildDeviceContext(inputMethod: SearchContext.DeviceContext.InputMethod) -> SearchContext.DeviceContext {
        return SearchContext.DeviceContext(
            deviceType: UIDevice.current.model,
            orientation: UIDevice.current.orientation.isLandscape ? "landscape" : "portrait",
            inputMethod: inputMethod,
            batteryLevel: UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : nil,
            networkStatus: .wifi // Simplified - would use actual network detection
        )
    }
    
    private func buildBehaviorContext() -> SearchContext.BehaviorContext {
        guard let profile = userSearchProfile else {
            return SearchContext.BehaviorContext(
                searchFrequency: 0.0,
                averageSessionLength: 0.0,
                preferredSearchTypes: [],
                interactionPatterns: [],
                successRate: 0.5
            )
        }
        
        return SearchContext.BehaviorContext(
            searchFrequency: profile.searchFrequency,
            averageSessionLength: profile.averageSessionLength,
            preferredSearchTypes: profile.getTopSearchTerms(limit: 5),
            interactionPatterns: Array(profile.preferredInputMethods.keys),
            successRate: profile.satisfactionScore
        )
    }
    
    private func buildEnvironmentContext() async -> SearchContext.EnvironmentContext {
        // Simplified environment context - would integrate with system APIs
        return SearchContext.EnvironmentContext(
            location: SearchContext.EnvironmentContext.LocationContext(
                isHome: true, // Would use CoreLocation
                isWork: false,
                isTravel: false,
                locationCategory: "home"
            ),
            calendar: nil, // Would integrate with EventKit
            social: SearchContext.EnvironmentContext.SocialContext(
                isSharing: false,
                collaborationMode: false,
                presentationMode: false
            )
        )
    }
    
    // MARK: - Intent Analysis
    
    private func analyzeQueryIntent(
        _ query: String,
        context: SearchContext
    ) async -> (SearchContext.UserIntent, Double) {
        
        let lowercaseQuery = query.lowercased()
        var scores: [SearchContext.UserIntent: Double] = [:]
        
        // Analyze query patterns
        if lowercaseQuery.contains(regex: "\\b(find|locate|where|search)\\b") {
            scores[.findSpecific] = 0.8
        }
        
        if lowercaseQuery.contains(regex: "\\b(recent|latest|new|today|yesterday)\\b") {
            scores[.browseRecent] = 0.7
        }
        
        if lowercaseQuery.contains(regex: "\\b(organize|group|sort|categorize)\\b") {
            scores[.organizeContent] = 0.9
        }
        
        if lowercaseQuery.contains(regex: "\\b(share|send|export)\\b") {
            scores[.shareContent] = 0.8
        }
        
        if lowercaseQuery.contains(regex: "\\b(analyze|pattern|trend|insight)\\b") {
            scores[.analyzePatterns] = 0.9
        }
        
        if lowercaseQuery.contains(regex: "\\b(help|problem|issue|error)\\b") {
            scores[.troubleshoot] = 0.7
        }
        
        if lowercaseQuery.contains(regex: "\\b(discover|explore|browse|look)\\b") {
            scores[.discovery] = 0.6
        }
        
        // Context-based intent enhancement
        if context.temporalContext?.timeOfDay == .morning {
            scores[.browseRecent, default: 0.0] += 0.2
        }
        
        if context.deviceContext.inputMethod == .voice {
            scores[.findSpecific, default: 0.0] += 0.3
        }
        
        // Behavior-based intent prediction
        if let profile = userSearchProfile {
            for (term, _) in profile.successPatterns {
                if lowercaseQuery.contains(term) {
                    if let intent = SearchContext.UserIntent(rawValue: term) {
                        scores[intent, default: 0.0] += 0.2
                    }
                }
            }
        }
        
        // Find highest scoring intent
        let bestIntent = scores.max(by: { $0.value < $1.value })
        return (bestIntent?.key ?? .findSpecific, bestIntent?.value ?? 0.5)
    }
    
    // MARK: - Search Coordination
    
    private func coordinateSearch(
        query: String,
        intent: SearchContext.UserIntent,
        context: SearchContext,
        in modelContext: ModelContext
    ) async -> [Screenshot] {
        
        // Route to appropriate search service based on intent and context
        switch intent {
        case .findSpecific:
            return await naturalLanguageSearch.searchWithNaturalLanguage(query: query, in: modelContext)
            
        case .browseRecent:
            return await browseRecentContent(query: query, context: context, in: modelContext)
            
        case .organizeContent:
            return await organizeContentSearch(query: query, context: context, in: modelContext)
            
        case .shareContent:
            return await shareContentSearch(query: query, context: context, in: modelContext)
            
        case .analyzePatterns:
            return await analyzePatternSearch(query: query, context: context, in: modelContext)
            
        case .discovery:
            return await discoverySearch(query: query, context: context, in: modelContext)
            
        default:
            return await naturalLanguageSearch.searchWithNaturalLanguage(query: query, in: modelContext)
        }
    }
    
    private func browseRecentContent(
        query: String,
        context: SearchContext,
        in modelContext: ModelContext
    ) async -> [Screenshot] {
        
        // Focus on recent screenshots with contextual filtering
        let recentDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        do {
            let descriptor = FetchDescriptor<Screenshot>(
                predicate: #Predicate { $0.timestamp >= recentDate },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let recentScreenshots = try modelContext.fetch(descriptor)
            
            // Apply natural language filtering to recent content
            if !query.isEmpty {
                return await naturalLanguageSearch.searchWithNaturalLanguage(query: query, in: modelContext)
                    .filter { screenshot in
                        screenshot.timestamp >= recentDate
                    }
            }
            
            return Array(recentScreenshots.prefix(50))
            
        } catch {
            logger.error("Browse recent content failed: \(error.localizedDescription)")
            return []
        }
    }
    
    private func organizeContentSearch(
        query: String,
        context: SearchContext,
        in modelContext: ModelContext
    ) async -> [Screenshot] {
        
        // Use content-aware search for organization purposes
        let analysis = await contentAwareSearch.analyzeContentQuery(query)
        
        do {
            let allScreenshots = try modelContext.fetch(FetchDescriptor<Screenshot>())
            return await contentAwareSearch.searchWithContentAwareness(
                query: query,
                in: allScreenshots,
                filterBy: analysis.contentTypes,
                patterns: analysis.detectedPatterns
            )
        } catch {
            logger.error("Organize content search failed: \(error.localizedDescription)")
            return []
        }
    }
    
    private func shareContentSearch(
        query: String,
        context: SearchContext,
        in modelContext: ModelContext
    ) async -> [Screenshot] {
        
        // Focus on content suitable for sharing
        let results = await naturalLanguageSearch.searchWithNaturalLanguage(query: query, in: modelContext)
        
        // Filter for shareable content (high quality, relevant)
        return results.filter { screenshot in
            // Prefer screenshots with clear content
            if let text = screenshot.extractedText, !text.isEmpty {
                return true
            }
            
            // Prefer favorited items
            if screenshot.isFavorite {
                return true
            }
            
            // Prefer recent, high-quality screenshots
            let daysSince = Date().timeIntervalSince(screenshot.timestamp) / 86400
            return daysSince <= 30
        }
    }
    
    private func analyzePatternSearch(
        query: String,
        context: SearchContext,
        in modelContext: ModelContext
    ) async -> [Screenshot] {
        
        // Get content for pattern analysis
        let categories = await contentAwareSearch.categorizeContent(from: context.contentContext.recentScreenshots)
        
        // Find patterns based on query
        var results: [Screenshot] = []
        
        for category in categories {
            if query.lowercased().contains(category.type.rawValue) ||
               category.name.lowercased().contains(query.lowercased()) {
                
                // Find all screenshots in this category
                let categoryResults = await contentAwareSearch.searchWithContentAwareness(
                    query: "",
                    in: context.contentContext.recentScreenshots,
                    filterBy: [category.type]
                )
                results.append(contentsOf: categoryResults)
            }
        }
        
        return Array(Set(results)) // Remove duplicates
    }
    
    private func discoverySearch(
        query: String,
        context: SearchContext,
        in modelContext: ModelContext
    ) async -> [Screenshot] {
        
        // Discovery search focuses on finding interesting content
        do {
            let allScreenshots = try modelContext.fetch(FetchDescriptor<Screenshot>())
            
            // Use a combination of approaches for discovery
            var discoveryResults: [Screenshot] = []
            
            // Add content from underused periods
            let unusualTimeScreenshots = allScreenshots.filter { screenshot in
                let hour = Calendar.current.component(.hour, from: screenshot.timestamp)
                return hour < 6 || hour > 22 // Late night/early morning screenshots
            }
            discoveryResults.append(contentsOf: Array(unusualTimeScreenshots.prefix(10)))
            
            // Add screenshots with unique content patterns
            let uniqueContent = allScreenshots.filter { screenshot in
                if let text = screenshot.extractedText, text.count > 100 {
                    return true // Long text content
                }
                return false
            }
            discoveryResults.append(contentsOf: Array(uniqueContent.prefix(10)))
            
            // Add visual variety
            let visuallyInteresting = allScreenshots.filter { screenshot in
                return screenshot.visualAttributes?.prominentObjects.count ?? 0 > 3
            }
            discoveryResults.append(contentsOf: Array(visuallyInteresting.prefix(10)))
            
            return Array(Set(discoveryResults)).prefix(30).map { $0 }
            
        } catch {
            logger.error("Discovery search failed: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Result Enhancement
    
    private func enhanceResultsWithContext(_ results: [Screenshot], context: SearchContext) async -> [Screenshot] {
        // Apply contextual ranking based on user behavior and preferences
        let scoredResults = results.map { screenshot -> (Screenshot, Double) in
            var score = 1.0
            
            // Time-based scoring
            if let temporalContext = context.temporalContext {
                let screenshotHour = Calendar.current.component(.hour, from: screenshot.timestamp)
                let currentTimeScore = getTimeBasedScore(hour: screenshotHour, timeOfDay: temporalContext.timeOfDay)
                score += currentTimeScore * 0.2
            }
            
            // Behavior-based scoring
            if let profile = userSearchProfile {
                let behaviorScore = getBehaviorBasedScore(screenshot: screenshot, profile: profile)
                score += behaviorScore * 0.3
            }
            
            // Content relevance scoring
            let contentScore = getContentRelevanceScore(screenshot: screenshot, context: context)
            score += contentScore * 0.5
            
            return (screenshot, score)
        }
        
        return scoredResults
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
    
    // MARK: - Learning and Adaptation
    
    private func recordSearchInsight(
        query: String,
        intent: SearchContext.UserIntent,
        confidence: Double,
        results: [Screenshot],
        processingTime: TimeInterval,
        context: SearchContext
    ) async {
        
        let resultQuality = calculateResultQuality(results, for: query)
        let userSatisfaction = estimateUserSatisfaction(results: results, intent: intent)
        
        let insight = QueryInsight(
            query: query,
            intent: intent,
            confidence: confidence,
            resultQuality: resultQuality,
            userSatisfaction: userSatisfaction,
            timeToResult: processingTime,
            context: context,
            learningPoints: generateLearningPoints(query: query, context: context, results: results)
        )
        
        queryInsights.append(insight)
        
        // Keep insights manageable
        if queryInsights.count > 100 {
            queryInsights.removeFirst(50)
        }
        
        // Update user profile
        if var profile = userSearchProfile {
            profile.updateProfile(from: insight)
            userSearchProfile = profile
            saveUserSearchProfile()
        }
    }
    
    private func generateAdaptiveSuggestions(based context: SearchContext, results: [Screenshot]) async {
        var suggestions: [ContextualSuggestion] = []
        
        // Generate context-based suggestions
        suggestions.append(contentsOf: await generateContextBasedSuggestions(context))
        
        // Generate result-based suggestions
        suggestions.append(contentsOf: generateResultBasedSuggestions(results))
        
        contextualSuggestions = suggestions.prefix(8).map { $0 }
    }
    
    // MARK: - Helper Methods
    
    private func manageSearchSession(context: SearchContext, query: String) async {
        if var session = searchSession {
            // Continue existing session
            session.queries.append(query)
            searchSession = session
        } else {
            // Start new session
            let intent = await analyzeQueryIntent(query, context: context).0
            searchSession = SearchSession(context: context, intent: intent)
        }
        
        // End session if it's too long
        if let session = searchSession, session.duration > settings.maxSessionLength {
            await endSearchSession()
        }
    }
    
    private func endSearchSession() async {
        if var session = searchSession {
            session.endTime = Date()
            
            // Learn from session
            if settings.enableCrossSessionLearning {
                await learnFromSession(session)
            }
            
            searchSession = nil
        }
    }
    
    private func learnFromSession(_ session: SearchSession) async {
        // Analyze session patterns for learning
        if session.wasSuccessful && session.averageSatisfaction > settings.learningConfidenceThreshold {
            // Extract successful patterns
            for query in session.queries {
                let terms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
                
                if var profile = userSearchProfile {
                    for term in terms where term.count > 2 {
                        profile.successPatterns[term, default: 0.0] += session.averageSatisfaction * settings.adaptationSpeed
                    }
                    userSearchProfile = profile
                }
            }
        }
    }
    
    // MARK: - Suggestion Generation
    
    private func generateContextBasedSuggestions(_ context: SearchContext, query: String = "") async -> [ContextualSuggestion] {
        var suggestions: [ContextualSuggestion] = []
        
        // Temporal suggestions
        if let temporal = context.temporalContext {
            switch temporal.timeOfDay {
            case .morning:
                suggestions.append(ContextualSuggestion(
                    text: "screenshots from yesterday",
                    type: .temporal,
                    confidence: 0.7,
                    context: "Morning review pattern",
                    learningSource: .temporalPatterns,
                    adaptationScore: 0.8
                ))
            case .evening:
                suggestions.append(ContextualSuggestion(
                    text: "screenshots from today",
                    type: .temporal,
                    confidence: 0.8,
                    context: "Evening summary pattern",
                    learningSource: .temporalPatterns,
                    adaptationScore: 0.9
                ))
            default:
                break
            }
        }
        
        // Content suggestions based on recent activity
        for contentType in context.contentContext.dominantContentTypes.prefix(3) {
            suggestions.append(ContextualSuggestion(
                text: "screenshots with \(contentType)",
                type: .content,
                confidence: 0.6,
                context: "Recent content pattern",
                learningSource: .contentAnalysis,
                adaptationScore: 0.7
            ))
        }
        
        return suggestions
    }
    
    private func generateBehaviorBasedSuggestions(_ profile: UserSearchProfile, query: String) async -> [ContextualSuggestion] {
        var suggestions: [ContextualSuggestion] = []
        
        // Suggestions based on successful patterns
        for (pattern, score) in profile.successPatterns.prefix(3) {
            if score > settings.learningConfidenceThreshold {
                suggestions.append(ContextualSuggestion(
                    text: pattern,
                    type: .behavioral,
                    confidence: min(1.0, score),
                    context: "Successful search pattern",
                    learningSource: .behaviorModeling,
                    adaptationScore: score * profile.adaptationLevel
                ))
            }
        }
        
        return suggestions
    }
    
    private func generateTemporalSuggestions(query: String) async -> [ContextualSuggestion] {
        let temporalPeriods = await temporalProcessor.processTemporalQuery(query)
        
        return temporalPeriods.compactMap { period in
            ContextualSuggestion(
                text: "screenshots \(period.originalPhrase)",
                type: .temporal,
                confidence: period.confidence,
                context: "Temporal context suggestion",
                learningSource: .temporalPatterns,
                adaptationScore: period.confidence
            )
        }
    }
    
    private func generatePredictiveSuggestions(query: String) async -> [ContextualSuggestion] {
        // Placeholder for machine learning-based predictions
        return []
    }
    
    private func generateResultBasedSuggestions(_ results: [Screenshot]) -> [ContextualSuggestion] {
        var suggestions: [ContextualSuggestion] = []
        
        // Analyze results for patterns
        let apps = results.compactMap { _ in "Unknown App" }.prefix(3)
        for app in apps {
            suggestions.append(ContextualSuggestion(
                text: "more screenshots from \(app)",
                type: .content,
                confidence: 0.6,
                context: "Result pattern analysis",
                learningSource: .contentAnalysis,
                adaptationScore: 0.5
            ))
        }
        
        return suggestions
    }
    
    private func adaptSuggestionsBasedOnFeedback(query: String, satisfaction: Double) async {
        // Adjust suggestion weights based on user feedback
        if satisfaction > settings.learningConfidenceThreshold {
            // Boost similar suggestions
            for i in 0..<contextualSuggestions.count {
                if contextualSuggestions[i].text.lowercased().contains(query.lowercased()) {
                    contextualSuggestions[i] = ContextualSuggestion(
                        text: contextualSuggestions[i].text,
                        type: contextualSuggestions[i].type,
                        confidence: min(1.0, contextualSuggestions[i].confidence + 0.1),
                        context: contextualSuggestions[i].context,
                        learningSource: contextualSuggestions[i].learningSource,
                        adaptationScore: min(1.0, contextualSuggestions[i].adaptationScore + 0.1)
                    )
                }
            }
        }
    }
    
    // MARK: - Analytics and Scoring
    
    private func getRecentActivityPatterns() -> [String] {
        return queryInsights
            .suffix(10)
            .map { $0.intent.rawValue }
    }
    
    private func getTimeBasedPatterns(for timeOfDay: SearchContext.TemporalContext.TimeOfDay) -> [String] {
        let recentInsights = queryInsights.filter { insight in
            let hour = Calendar.current.component(.hour, from: insight.timestamp)
            let insightTimeOfDay: SearchContext.TemporalContext.TimeOfDay
            switch hour {
            case 5..<8: insightTimeOfDay = .earlyMorning
            case 8..<12: insightTimeOfDay = .morning
            case 12..<17: insightTimeOfDay = .afternoon
            case 17..<21: insightTimeOfDay = .evening
            default: insightTimeOfDay = .night
            }
            return insightTimeOfDay == timeOfDay
        }
        
        return recentInsights.map { $0.query }.suffix(5).map { $0 }
    }
    
    private func analyzeDominantContentTypes(_ screenshots: [Screenshot]) async -> [String] {
        let analysis = await contentAwareSearch.categorizeContent(from: screenshots)
        return analysis.sorted { $0.screenshotCount > $1.screenshotCount }
                       .prefix(5)
                       .map { $0.type.rawValue }
    }
    
    private func analyzeFrequentApps(_ screenshots: [Screenshot]) async -> [String] {
        var appCounts: [String: Int] = [:]
        
        for screenshot in screenshots {
            if let filename = screenshot.filename.components(separatedBy: "_").first, !filename.isEmpty {
                appCounts[filename, default: 0] += 1
            }
        }
        
        return appCounts.sorted { $0.value > $1.value }
                        .prefix(5)
                        .map { $0.key }
    }
    
    private func analyzeContentPatterns(_ screenshots: [Screenshot]) async -> [String] {
        var patterns: [String] = []
        
        for screenshot in screenshots {
            if let text = screenshot.extractedText {
                let contentAnalysis = await contentAwareSearch.analyzeContentQuery(text)
                patterns.append(contentsOf: contentAnalysis.detectedPatterns.map { $0.type.rawValue })
            }
        }
        
        return Array(Set(patterns)).prefix(10).map { $0 }
    }
    
    private func analyzeVisualThemes(_ screenshots: [Screenshot]) async -> [String] {
        var themes: [String] = []
        
        for screenshot in screenshots {
            if let visualAttributes = screenshot.visualAttributes {
                // Add prominent objects as themes
                themes.append("visual content")
                
                // Add color themes
                themes.append("colorful content")
            }
        }
        
        return Array(Set(themes)).prefix(10).map { $0 }
    }
    
    private func getTimeBasedScore(hour: Int, timeOfDay: SearchContext.TemporalContext.TimeOfDay) -> Double {
        let timeRange: ClosedRange<Int>
        switch timeOfDay {
        case .earlyMorning: timeRange = 5...8
        case .morning: timeRange = 8...12
        case .afternoon: timeRange = 12...17
        case .evening: timeRange = 17...21
        case .night: timeRange = 21...24
        }
        
        return timeRange.contains(hour) ? 1.0 : 0.0
    }
    
    private func getBehaviorBasedScore(screenshot: Screenshot, profile: UserSearchProfile) -> Double {
        var score = 0.0
        
        // Check against successful patterns
        let content = [screenshot.extractedText, screenshot.userNotes, screenshot.filename]
            .compactMap { $0 }.joined(separator: " ").lowercased()
        
        for (pattern, patternScore) in profile.successPatterns {
            if content.contains(pattern) {
                score += patternScore * 0.1
            }
        }
        
        return min(1.0, score)
    }
    
    private func getContentRelevanceScore(screenshot: Screenshot, context: SearchContext) -> Double {
        var score = 0.0
        
        // Check against dominant content types
        for contentType in context.contentContext.dominantContentTypes {
            if screenshot.extractedText?.lowercased().contains(contentType) == true {
                score += 0.2
            }
        }
        
        // Check against frequent apps
        if let filename = screenshot.filename.components(separatedBy: "_").first {
            if context.contentContext.frequentApps.contains(filename) {
                score += 0.3
            }
        }
        
        return min(1.0, score)
    }
    
    private func calculateResultQuality(_ results: [Screenshot], for query: String) -> Double {
        guard !results.isEmpty else { return 0.0 }
        
        let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var totalRelevance = 0.0
        
        for screenshot in results.prefix(10) { // Check top 10 results
            let content = [screenshot.extractedText, screenshot.userNotes, screenshot.filename]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            
            var relevance = 0.0
            for term in queryTerms where term.count > 2 {
                if content.contains(term) {
                    relevance += 1.0
                }
            }
            
            totalRelevance += relevance / Double(queryTerms.count)
        }
        
        return totalRelevance / Double(min(results.count, 10))
    }
    
    private func estimateUserSatisfaction(results: [Screenshot], intent: SearchContext.UserIntent) -> Double {
        // Estimate satisfaction based on result characteristics and intent
        var satisfaction = 0.5 // Base satisfaction
        
        if !results.isEmpty {
            satisfaction += 0.2 // Found results
            
            // Intent-specific satisfaction estimation
            switch intent {
            case .findSpecific:
                satisfaction += results.count <= 5 ? 0.2 : 0.0 // Prefer fewer, more specific results
            case .browseRecent:
                satisfaction += results.count >= 10 ? 0.2 : 0.0 // Prefer more results for browsing
            case .discovery:
                satisfaction += results.count >= 15 ? 0.2 : 0.0 // Prefer many diverse results
            default:
                satisfaction += results.count >= 5 ? 0.1 : 0.0
            }
        }
        
        return min(1.0, satisfaction)
    }
    
    private func generateLearningPoints(query: String, context: SearchContext, results: [Screenshot]) -> [String] {
        var learningPoints: [String] = []
        
        // Learn from query patterns
        if results.count > 10 {
            learningPoints.append("Query '\(query)' produced many results - consider refinement suggestions")
        } else if results.isEmpty {
            learningPoints.append("Query '\(query)' produced no results - improve fallback strategies")
        }
        
        // Learn from context patterns
        if let temporal = context.temporalContext {
            learningPoints.append("Search performed during \(temporal.timeOfDay.rawValue) - track temporal patterns")
        }
        
        // Learn from input method
        learningPoints.append("Search via \(context.deviceContext.inputMethod.rawValue) - optimize for input method")
        
        return learningPoints
    }
    
    // MARK: - Persistence
    
    private func loadUserSearchProfile() {
        guard let data = UserDefaults.standard.data(forKey: "UserSearchProfile") else {
            userSearchProfile = UserSearchProfile()
            return
        }
        
        do {
            userSearchProfile = try JSONDecoder().decode(UserSearchProfile.self, from: data)
        } catch {
            logger.error("Failed to load user search profile: \(error.localizedDescription)")
            userSearchProfile = UserSearchProfile()
        }
    }
    
    private func saveUserSearchProfile() {
        guard let profile = userSearchProfile else { return }
        
        do {
            let data = try JSONEncoder().encode(profile)
            UserDefaults.standard.set(data, forKey: "UserSearchProfile")
        } catch {
            logger.error("Failed to save user search profile: \(error.localizedDescription)")
        }
    }
}

