import Foundation
import SwiftData
import SwiftUI
import OSLog

/// Enhanced smart suggestions service that provides proactive, card-based recommendations
/// Extends existing SmartActionSuggestionsService with beautiful UI-focused suggestion cards
@MainActor
public final class SmartSuggestionsService: ObservableObject {
    public static let shared = SmartSuggestionsService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "SmartSuggestions")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isGeneratingSuggestions = false
    @Published public private(set) var visibleSuggestionCards: [SuggestionCard] = []
    @Published public private(set) var recentlyUsefulCards: [SuggestionCard] = []
    @Published public private(set) var organizationCards: [SuggestionCard] = []
    @Published public private(set) var cleanupCards: [SuggestionCard] = []
    @Published public private(set) var isShowingSuggestionOverlay = false
    @Published public private(set) var userInteractionMetrics: SuggestionMetrics = SuggestionMetrics()
    
    // MARK: - Services Integration
    
    private let smartActions = SmartActionSuggestionsService.shared
    private let hapticService = HapticFeedbackService.shared
    private let errorHandler = AppErrorHandler.shared
    private let taskManager = TaskManager.shared
    
    // MARK: - Configuration
    
    public struct SuggestionSettings {
        var enableProactiveSuggestions: Bool = true
        var enableRecentlyUsefulSection: Bool = true
        var enableOrganizationSuggestions: Bool = true
        var enableCleanupRecommendations: Bool = true
        var maxVisibleCards: Int = 6
        var suggestionRefreshInterval: TimeInterval = 300 // 5 minutes
        var minimumInteractionConfidence: Double = 0.7
        var enableHapticFeedback: Bool = true
        var autoHideAfterInteraction: Bool = true
        var cardAnimationDuration: Double = 0.6
        
        public init() {}
    }
    
    @Published public var settings = SuggestionSettings()
    
    // MARK: - Data Models
    
    /// Enhanced suggestion card with Glass design integration
    public struct SuggestionCard: Identifiable, Hashable {
        public let id = UUID()
        let type: SuggestionType
        let title: String
        let subtitle: String
        let description: String
        let iconName: String
        let actionTitle: String
        let priority: Priority
        let confidence: Double
        let screenshots: [Screenshot]
        let metadata: [String: Any]
        let createdAt: Date
        let expiresAt: Date?
        let hapticPattern: HapticFeedbackService.HapticPattern
        
        public enum SuggestionType: String, CaseIterable {
            case recentlyUseful = "recently_useful"
            case relatedContent = "related_content"
            case organizationPrompt = "organization_prompt"
            case cleanupRecommendation = "cleanup_recommendation"
            case duplicateCleanup = "duplicate_cleanup"
            case contentDiscovery = "content_discovery"
            case workflowSuggestion = "workflow_suggestion"
            case qualityImprovement = "quality_improvement"
            
            public var displayName: String {
                switch self {
                case .recentlyUseful: return "Recently Useful"
                case .relatedContent: return "Related Content"
                case .organizationPrompt: return "Organization"
                case .cleanupRecommendation: return "Cleanup"
                case .duplicateCleanup: return "Duplicates"
                case .contentDiscovery: return "Discovery"
                case .workflowSuggestion: return "Workflow"
                case .qualityImprovement: return "Quality"
                }
            }
            
            var glassBackground: ResponsiveMaterialType {
                switch self {
                case .recentlyUseful, .relatedContent: return .primary
                case .organizationPrompt, .workflowSuggestion: return .secondary
                case .cleanupRecommendation, .duplicateCleanup: return .secondary
                case .contentDiscovery: return .accent
                case .qualityImprovement: return .accent
                }
            }
        }
        
        public enum Priority: Int, CaseIterable {
            case low = 1
            case medium = 2
            case high = 3
            case urgent = 4
            
            public var weight: Double {
                return Double(rawValue) / 4.0
            }
        }
        
        init(
            type: SuggestionType,
            title: String,
            subtitle: String = "",
            description: String,
            iconName: String,
            actionTitle: String,
            priority: Priority = .medium,
            confidence: Double,
            screenshots: [Screenshot] = [],
            metadata: [String: Any] = [:],
            expiresAt: Date? = nil,
            hapticPattern: HapticFeedbackService.HapticPattern = .smartRecommendation
        ) {
            self.type = type
            self.title = title
            self.subtitle = subtitle
            self.description = description
            self.iconName = iconName
            self.actionTitle = actionTitle
            self.priority = priority
            self.confidence = confidence
            self.screenshots = screenshots
            self.metadata = metadata
            self.createdAt = Date()
            self.expiresAt = expiresAt
            self.hapticPattern = hapticPattern
        }
        
        public static func == (lhs: SuggestionCard, rhs: SuggestionCard) -> Bool {
            return lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    /// Interaction metrics for suggestion quality improvement
    public struct SuggestionMetrics {
        var totalSuggestionsShown: Int = 0
        var totalInteractions: Int = 0
        var acceptanceRate: Double = 0.0
        var dismissalRate: Double = 0.0
        var typePerformance: [SuggestionCard.SuggestionType: Double] = [:]
        var averageEngagementTime: TimeInterval = 0.0
        var lastUpdated: Date = Date()
        
        public init() {}
        
        public var engagementRate: Double {
            guard totalSuggestionsShown > 0 else { return 0.0 }
            return Double(totalInteractions) / Double(totalSuggestionsShown)
        }
    }
    
    /// Context for generating relevant suggestions
    public struct SuggestionContext {
        let currentScreenshots: [Screenshot]
        let recentActivity: [String]
        let timeOfDay: TimeOfDay
        let userBehaviorProfile: SmartActionSuggestionsService.UserBehaviorProfile?
        let deviceContext: DeviceContext
        
        public enum TimeOfDay: String, CaseIterable {
            case morning = "morning"
            case afternoon = "afternoon"
            case evening = "evening"
            case night = "night"
        }
        
        struct DeviceContext {
            let isLowPowerMode: Bool
            let availableMemory: Int64
            let networkStatus: NetworkStatus
            
            enum NetworkStatus {
                case wifi, cellular, offline
            }
            
            init(isLowPowerMode: Bool, availableMemory: Int64, networkStatus: NetworkStatus) {
                self.isLowPowerMode = isLowPowerMode
                self.availableMemory = availableMemory
                self.networkStatus = networkStatus
            }
        }
        
        init(
            currentScreenshots: [Screenshot] = [],
            recentActivity: [String] = [],
            timeOfDay: TimeOfDay = .afternoon,
            userBehaviorProfile: SmartActionSuggestionsService.UserBehaviorProfile? = nil,
            deviceContext: DeviceContext = DeviceContext(isLowPowerMode: false, availableMemory: 1024, networkStatus: .wifi)
        ) {
            self.currentScreenshots = currentScreenshots
            self.recentActivity = recentActivity
            self.timeOfDay = timeOfDay
            self.userBehaviorProfile = userBehaviorProfile
            self.deviceContext = deviceContext
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        logger.info("SmartSuggestionsService initialized with card-based suggestion system")
        setupSuggestionRefreshTimer()
    }
    
    // MARK: - Public Interface
    
    /// Generate suggestion cards based on current context
    /// - Parameters:
    ///   - context: Current context for suggestions
    ///   - modelContext: SwiftData model context
    /// - Returns: Array of relevant suggestion cards
    func generateSuggestionCards(
        for context: SuggestionContext,
        in modelContext: ModelContext
    ) async -> [SuggestionCard] {
        
        guard settings.enableProactiveSuggestions else {
            return []
        }
        
        logger.info("Generating suggestion cards for context with \(context.currentScreenshots.count) screenshots")
        
        isGeneratingSuggestions = true
        
        defer {
            isGeneratingSuggestions = false
        }
        
        var allCards: [SuggestionCard] = []
        
        // Generate different types of suggestions in parallel
            async let recentlyUsefulTask = generateRecentlyUsefulCards(context: context, modelContext: modelContext)
            async let organizationTask = generateOrganizationCards(context: context, modelContext: modelContext)
            async let cleanupTask = generateCleanupCards(context: context, modelContext: modelContext)
            async let contentDiscoveryTask = generateContentDiscoveryCards(context: context, modelContext: modelContext)
            
            let (recentCards, orgCards, cleanupCards, discoveryCards) = await (
                recentlyUsefulTask,
                organizationTask, 
                cleanupTask,
                contentDiscoveryTask
            )
            
            allCards.append(contentsOf: recentCards)
            allCards.append(contentsOf: orgCards)
            allCards.append(contentsOf: cleanupCards)
            allCards.append(contentsOf: discoveryCards)
            
            // Filter and rank cards
            let filteredCards = await filterAndRankCards(allCards, context: context)
            let finalCards = Array(filteredCards.prefix(settings.maxVisibleCards))
            
            // Update published properties
            updateCardCollections(finalCards)
            
            // Provide haptic feedback for new suggestions
            if !finalCards.isEmpty && settings.enableHapticFeedback {
                hapticService.triggerHaptic(.suggestionPresented)
            }
            
            logger.info("Generated \(finalCards.count) suggestion cards with \(String(format: "%.1f", finalCards.map(\.confidence).reduce(0, +) / Double(max(finalCards.count, 1)))) average confidence")
            
        return finalCards
    }
    
    /// Show suggestion overlay with cards
    /// - Parameter cards: Cards to display
    public func showSuggestionOverlay(with cards: [SuggestionCard] = []) {
        let cardsToShow = cards.isEmpty ? visibleSuggestionCards : cards
        
        guard !cardsToShow.isEmpty else { return }
        
        visibleSuggestionCards = cardsToShow
        isShowingSuggestionOverlay = true
        
        if settings.enableHapticFeedback {
            hapticService.triggerHaptic(.suggestionPresented)
        }
        
        logger.info("Showing suggestion overlay with \(cardsToShow.count) cards")
    }
    
    /// Hide suggestion overlay
    public func hideSuggestionOverlay() {
        isShowingSuggestionOverlay = false
        
        if settings.enableHapticFeedback {
            hapticService.triggerHaptic(.menuDismiss)
        }
        
        logger.debug("Suggestion overlay hidden")
    }
    
    /// Handle user interaction with suggestion card
    /// - Parameters:
    ///   - card: The suggestion card
    ///   - action: User action taken
    public func handleCardInteraction(_ card: SuggestionCard, action: CardAction) async {
        logger.info("User \\(action.rawValue) suggestion card: \\(card.type.rawValue)")
        
        // Update metrics
        await updateInteractionMetrics(for: card, action: action)
        
        // Provide haptic feedback
        if settings.enableHapticFeedback {
            hapticService.triggerHaptic(action.hapticPattern)
        }
        
        // Handle the action
        switch action {
        case .accepted:
            await executeCardAction(card)
            if settings.autoHideAfterInteraction {
                hideSuggestionOverlay()
            }
        case .dismissed:
            removeSuggestionCard(card)
        case .snoozed:
            await snoozeCard(card)
        case .moreInfo:
            await showCardDetails(card)
        }
    }
    
    public enum CardAction: String, CaseIterable {
        case accepted = "accepted"
        case dismissed = "dismissed"
        case snoozed = "snoozed"
        case moreInfo = "more_info"
        
        var hapticPattern: HapticFeedbackService.HapticPattern {
            switch self {
            case .accepted: return .suggestionAccepted
            case .dismissed: return .menuDismiss
            case .snoozed: return .menuSelection
            case .moreInfo: return .menuSelection
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupSuggestionRefreshTimer() {
        // Set up periodic suggestion refresh
        Timer.scheduledTimer(withTimeInterval: settings.suggestionRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshSuggestions()
            }
        }
    }
    
    private func refreshSuggestions() async {
        // Auto-refresh suggestions based on user activity
        logger.debug("Auto-refreshing suggestions")
        
        // This would typically be called with current context
        // Implementation would integrate with view lifecycle
    }
    
    private func generateRecentlyUsefulCards(
        context: SuggestionContext,
        modelContext: ModelContext
    ) async -> [SuggestionCard] {
        
        guard settings.enableRecentlyUsefulSection else { return [] }
        
        // Generate cards based on recently accessed content
        var cards: [SuggestionCard] = []
        
        // Example: Screenshots accessed multiple times recently
        let recentScreenshots = context.currentScreenshots.filter { screenshot in
            // Logic to determine if screenshot was recently useful
            screenshot.timestamp > Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        }
        
        if recentScreenshots.count >= 3 {
            let card = SuggestionCard(
                type: .recentlyUseful,
                title: "Recently Useful",
                subtitle: "\(recentScreenshots.count) screenshots",
                description: "Screenshots you've been accessing frequently this week",
                iconName: "clock.arrow.circlepath",
                actionTitle: "View Collection",
                priority: .medium,
                confidence: 0.8,
                screenshots: Array(recentScreenshots.prefix(5)),
                hapticPattern: .smartRecommendation
            )
            cards.append(card)
        }
        
        return cards
    }
    
    private func generateOrganizationCards(
        context: SuggestionContext,
        modelContext: ModelContext
    ) async -> [SuggestionCard] {
        
        guard settings.enableOrganizationSuggestions else { return [] }
        
        var cards: [SuggestionCard] = []
        
        // Example: Screenshots that could be grouped together
        let unorganizedScreenshots = context.currentScreenshots.filter { screenshot in
            // Logic to find screenshots that could be organized
            screenshot.userTags?.isEmpty ?? true
        }
        
        if unorganizedScreenshots.count >= 5 {
            let card = SuggestionCard(
                type: .organizationPrompt,
                title: "Organization Opportunity",
                subtitle: "\(unorganizedScreenshots.count) untagged",
                description: "These screenshots could be organized into groups",
                iconName: "folder.badge.plus",
                actionTitle: "Organize",
                priority: .medium,
                confidence: 0.7,
                screenshots: Array(unorganizedScreenshots.prefix(3)),
                hapticPattern: .intelligentGrouping
            )
            cards.append(card)
        }
        
        return cards
    }
    
    private func generateCleanupCards(
        context: SuggestionContext,
        modelContext: ModelContext
    ) async -> [SuggestionCard] {
        
        guard settings.enableCleanupRecommendations else { return [] }
        
        var cards: [SuggestionCard] = []
        
        // Example: Duplicate screenshots
        let potentialDuplicates = context.currentScreenshots.filter { screenshot in
            // Logic to identify potential duplicates
            !screenshot.filename.isEmpty
        }
        
        if potentialDuplicates.count >= 2 {
            let card = SuggestionCard(
                type: .duplicateCleanup,
                title: "Potential Duplicates",
                subtitle: "\(potentialDuplicates.count) similar items",
                description: "These screenshots appear to be duplicates",
                iconName: "doc.on.doc",
                actionTitle: "Review",
                priority: .low,
                confidence: 0.6,
                screenshots: Array(potentialDuplicates.prefix(2)),
                hapticPattern: .duplicateDetected
            )
            cards.append(card)
        }
        
        return cards
    }
    
    private func generateContentDiscoveryCards(
        context: SuggestionContext,
        modelContext: ModelContext
    ) async -> [SuggestionCard] {
        
        var cards: [SuggestionCard] = []
        
        // Example: Related content discovery
        if let recentScreenshot = context.currentScreenshots.first {
            let relatedScreenshots = context.currentScreenshots.filter { screenshot in
                // Logic to find related screenshots
                screenshot.id != recentScreenshot.id
            }
            
            if !relatedScreenshots.isEmpty {
                let card = SuggestionCard(
                    type: .relatedContent,
                    title: "Related Content",
                    subtitle: "\(relatedScreenshots.count) similar",
                    description: "Screenshots related to your recent activity",
                    iconName: "link",
                    actionTitle: "Explore",
                    priority: .medium,
                    confidence: 0.75,
                    screenshots: Array(relatedScreenshots.prefix(3)),
                    hapticPattern: .visualSimilarityFound
                )
                cards.append(card)
            }
        }
        
        return cards
    }
    
    private func filterAndRankCards(_ cards: [SuggestionCard], context: SuggestionContext) async -> [SuggestionCard] {
        return cards
            .filter { $0.confidence >= settings.minimumInteractionConfidence }
            .filter { card in
                // Remove expired cards
                if let expiresAt = card.expiresAt {
                    return expiresAt > Date()
                }
                return true
            }
            .sorted { lhs, rhs in
                // Sort by priority and confidence
                if lhs.priority.weight != rhs.priority.weight {
                    return lhs.priority.weight > rhs.priority.weight
                }
                return lhs.confidence > rhs.confidence
            }
    }
    
    private func updateCardCollections(_ cards: [SuggestionCard]) {
        visibleSuggestionCards = cards
        
        recentlyUsefulCards = cards.filter { $0.type == .recentlyUseful }
        organizationCards = cards.filter { 
            $0.type == .organizationPrompt || $0.type == .workflowSuggestion 
        }
        cleanupCards = cards.filter { 
            $0.type == .cleanupRecommendation || $0.type == .duplicateCleanup 
        }
    }
    
    private func updateInteractionMetrics(for card: SuggestionCard, action: CardAction) async {
        userInteractionMetrics.totalInteractions += 1
        
        switch action {
        case .accepted:
            userInteractionMetrics.acceptanceRate = calculateNewRate(
                current: userInteractionMetrics.acceptanceRate,
                total: userInteractionMetrics.totalSuggestionsShown,
                increment: 1.0
            )
        case .dismissed:
            userInteractionMetrics.dismissalRate = calculateNewRate(
                current: userInteractionMetrics.dismissalRate,
                total: userInteractionMetrics.totalSuggestionsShown,
                increment: 1.0
            )
        default:
            break
        }
        
        userInteractionMetrics.lastUpdated = Date()
    }
    
    private func calculateNewRate(current: Double, total: Int, increment: Double) -> Double {
        guard total > 0 else { return increment }
        return ((current * Double(total)) + increment) / Double(total + 1)
    }
    
    private func executeCardAction(_ card: SuggestionCard) async {
        logger.info("Executing action for card: \\(card.type.rawValue)")
        
        // Execute the suggested action
        switch card.type {
        case .recentlyUseful:
            // Show collection of recently useful screenshots
            break
        case .organizationPrompt:
            // Start organization workflow
            break
        case .cleanupRecommendation, .duplicateCleanup:
            // Start cleanup workflow
            break
        case .relatedContent:
            // Show related content
            break
        default:
            break
        }
        
        // Track successful action execution
        await updateInteractionMetrics(for: card, action: .accepted)
    }
    
    private func removeSuggestionCard(_ card: SuggestionCard) {
        visibleSuggestionCards.removeAll { $0.id == card.id }
        updateCardCollections(visibleSuggestionCards)
    }
    
    private func snoozeCard(_ card: SuggestionCard) async {
        // Remove card temporarily (would be re-added later)
        removeSuggestionCard(card)
        logger.debug("Snoozed suggestion card: \\(card.type.rawValue)")
    }
    
    private func showCardDetails(_ card: SuggestionCard) async {
        logger.debug("Showing details for card: \\(card.type.rawValue)")
        // Implementation would show detailed view
    }
}

// MARK: - Supporting Extensions

extension SmartSuggestionsService {
    /// Get suggestion cards for specific screenshot
    func getSuggestionCards(for screenshot: Screenshot, in modelContext: ModelContext) async -> [SuggestionCard] {
        let context = SuggestionContext(
            currentScreenshots: [screenshot],
            recentActivity: [],
            timeOfDay: getCurrentTimeOfDay(),
            userBehaviorProfile: nil
        )
        
        return await generateSuggestionCards(for: context, in: modelContext)
    }
    
    private func getCurrentTimeOfDay() -> SuggestionContext.TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }
}

// MARK: - Memory Management

extension SmartSuggestionsService: MemoryTrackable {
    var memoryFootprint: Int64 {
        let cardsMemory = Int64(visibleSuggestionCards.count * 1024) // Approximate
        let metricsMemory = Int64(256) // Metrics struct size
        return cardsMemory + metricsMemory
    }
    
    func cleanupResources() {
        visibleSuggestionCards.removeAll()
        recentlyUsefulCards.removeAll()
        organizationCards.removeAll()
        cleanupCards.removeAll()
        
        logger.debug("SmartSuggestionsService resources cleaned up")
    }
}