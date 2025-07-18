
import Foundation
import SwiftData
import OSLog
import SwiftUI

@MainActor
public class WorkspaceAnalyticsService: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = WorkspaceAnalyticsService()
    
    // MARK: - Public Properties
    
    @Published public var analyticsResults: [UUID: WorkspaceAnalytics] = [:]
    @Published public var crossWorkspaceInsights: [CrossWorkspaceInsight] = []
    @Published public var isAnalyzing = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "WorkspaceAnalytics")
    private var analysisTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    private init() {
        logger.info("WorkspaceAnalyticsService: Initialized")
    }
    
    deinit {
        analysisTask?.cancel()
        logger.info("WorkspaceAnalyticsService: Deallocated")
    }
    
    // MARK: - Analytics Models
    
    public struct WorkspaceAnalytics: Identifiable, Equatable {
        public let id: UUID
        public let workspaceId: UUID
        public let completionAnalysis: CompletionAnalysis
        public let progressTrends: ProgressTrends
        public let missingComponentAnalysis: MissingComponentAnalysis
        public let timelineAnalysis: TimelineAnalysis
        public let actionRecommendations: [ActionRecommendation]
        public let lastAnalyzed: Date
        
        // Convenience alias for compatibility
        public var completionAnalytics: CompletionAnalysis {
            return completionAnalysis
        }
        
        public init(
            workspaceId: UUID,
            completionAnalysis: CompletionAnalysis,
            progressTrends: ProgressTrends,
            missingComponentAnalysis: MissingComponentAnalysis,
            timelineAnalysis: TimelineAnalysis,
            actionRecommendations: [ActionRecommendation] = []
        ) {
            self.id = UUID()
            self.workspaceId = workspaceId
            self.completionAnalysis = completionAnalysis
            self.progressTrends = progressTrends
            self.missingComponentAnalysis = missingComponentAnalysis
            self.timelineAnalysis = timelineAnalysis
            self.actionRecommendations = actionRecommendations
            self.lastAnalyzed = Date()
        }
    }
    
    public struct CompletionAnalysis: Equatable {
        public let overallCompletion: Double
        public let componentCompletion: [String: Double]
        public let estimatedTimeToComplete: TimeInterval?
        public let confidence: Double
        public let blockers: [String]
        public let completionLevel: CompletionLevel
        public let criticalMissingCount: Int
        
        public enum CompletionLevel: String, CaseIterable, Equatable {
            case justStarted = "Just Started"
            case earlyProgress = "Early Progress"
            case midProgress = "Mid Progress"
            case nearCompletion = "Near Completion"
            case complete = "Complete"
            
            public var displayName: String {
                return self.rawValue
            }
        }
        
        public init(
            overallCompletion: Double,
            componentCompletion: [String: Double] = [:],
            estimatedTimeToComplete: TimeInterval? = nil,
            confidence: Double = 0.0,
            blockers: [String] = [],
            criticalMissingCount: Int = 0
        ) {
            self.overallCompletion = max(0.0, min(1.0, overallCompletion))
            self.componentCompletion = componentCompletion
            self.estimatedTimeToComplete = estimatedTimeToComplete
            self.confidence = max(0.0, min(1.0, confidence))
            self.blockers = blockers
            self.criticalMissingCount = criticalMissingCount
            
            // Calculate completion level based on overall completion
            if overallCompletion >= 1.0 {
                self.completionLevel = .complete
            } else if overallCompletion >= 0.8 {
                self.completionLevel = .nearCompletion
            } else if overallCompletion >= 0.5 {
                self.completionLevel = .midProgress
            } else if overallCompletion >= 0.25 {
                self.completionLevel = .earlyProgress
            } else {
                self.completionLevel = .justStarted
            }
        }
    }
    
    public struct ProgressTrends: Equatable {
        public let velocity: Double // Screenshots per day
        public let momentum: TrendDirection
        public let progressHistory: [ProgressDataPoint]
        public let predictedCompletion: Date?
        public let estimatedDaysToCompletion: Int
        public let recentActivityLevel: Double
        
        public enum TrendDirection: String, CaseIterable {
            case accelerating = "Accelerating"
            case steady = "Steady"
            case slowing = "Slowing"
            case stalled = "Stalled"
            
            public var color: Color {
                switch self {
                case .accelerating: return .green
                case .steady: return .blue
                case .slowing: return .orange
                case .stalled: return .red
                }
            }
            
            public var displayName: String {
                return self.rawValue
            }
            
            public var iconName: String {
                switch self {
                case .accelerating: return "arrow.up.right"
                case .steady: return "arrow.right"
                case .slowing: return "arrow.down.right"
                case .stalled: return "pause.circle"
                }
            }
        }
        
        public init(
            velocity: Double = 0.0,
            momentum: TrendDirection = .stalled,
            progressHistory: [ProgressDataPoint] = [],
            predictedCompletion: Date? = nil,
            estimatedDaysToCompletion: Int = 0,
            recentActivityLevel: Double = 0.0
        ) {
            self.velocity = velocity
            self.momentum = momentum
            self.progressHistory = progressHistory
            self.predictedCompletion = predictedCompletion
            self.estimatedDaysToCompletion = estimatedDaysToCompletion
            self.recentActivityLevel = max(0.0, min(1.0, recentActivityLevel))
        }
    }
    
    public struct ProgressDataPoint: Identifiable, Equatable {
        public let id = UUID()
        public let date: Date
        public let screenshotCount: Int
        public let completionPercentage: Double
        
        public init(date: Date, screenshotCount: Int, completionPercentage: Double) {
            self.date = date
            self.screenshotCount = screenshotCount
            self.completionPercentage = max(0.0, min(100.0, completionPercentage))
        }
    }
    
    public struct MissingComponentAnalysis: Equatable {
        public let criticalComponents: [MissingComponent]
        public let optionalComponents: [MissingComponent]
        public let suggestedSources: [String: [String]] // Component -> Suggested apps/sources
        public let priority: ComponentPriority
        public let criticalMissing: [String]
        public let recommendedAdditions: [String]
        public let completionBlockers: [String]
        
        public enum ComponentPriority: String, CaseIterable {
            case high = "High"
            case medium = "Medium"
            case low = "Low"
            
            public var color: Color {
                switch self {
                case .high: return .red
                case .medium: return .orange
                case .low: return .yellow
                }
            }
        }
        
        public init(
            criticalComponents: [MissingComponent] = [],
            optionalComponents: [MissingComponent] = [],
            suggestedSources: [String: [String]] = [:],
            priority: ComponentPriority = .low,
            criticalMissing: [String] = [],
            recommendedAdditions: [String] = [],
            completionBlockers: [String] = []
        ) {
            self.criticalComponents = criticalComponents
            self.optionalComponents = optionalComponents
            self.suggestedSources = suggestedSources
            self.priority = priority
            self.criticalMissing = criticalMissing
            self.recommendedAdditions = recommendedAdditions
            self.completionBlockers = completionBlockers
        }
    }
    
    public struct MissingComponent: Identifiable, Equatable {
        public let id = UUID()
        public let name: String
        public let description: String
        public let importance: ImportanceLevel
        public let suggestedActions: [String]
        
        public enum ImportanceLevel: String, CaseIterable {
            case critical = "Critical"
            case important = "Important"
            case nice = "Nice to Have"
            
            public var color: Color {
                switch self {
                case .critical: return .red
                case .important: return .orange
                case .nice: return .blue
                }
            }
        }
        
        public init(
            name: String,
            description: String,
            importance: ImportanceLevel = .nice,
            suggestedActions: [String] = []
        ) {
            self.name = name
            self.description = description
            self.importance = importance
            self.suggestedActions = suggestedActions
        }
    }
    
    public struct TimelineAnalysis: Equatable {
        public let milestones: [TimelineMilestone]
        public let gaps: [TimelineGap]
        public let recommendedSchedule: [ScheduledAction]
        public let timelineEfficiency: Double
        public let workspaceDuration: TimeInterval
        public let daysSinceLastUpdate: Double
        public let averageActivityInterval: Double
        public let hasRecentActivity: Bool
        public let hasSignificantGaps: Bool
        public let milestoneCount: Int
        
        public init(
            milestones: [TimelineMilestone] = [],
            gaps: [TimelineGap] = [],
            recommendedSchedule: [ScheduledAction] = [],
            timelineEfficiency: Double = 0.0,
            workspaceDuration: TimeInterval = 0.0,
            daysSinceLastUpdate: Double = 0.0,
            averageActivityInterval: Double = 0.0,
            hasRecentActivity: Bool = false,
            hasSignificantGaps: Bool = false,
            milestoneCount: Int = 0
        ) {
            self.milestones = milestones
            self.gaps = gaps
            self.recommendedSchedule = recommendedSchedule
            self.timelineEfficiency = max(0.0, min(1.0, timelineEfficiency))
            self.workspaceDuration = workspaceDuration
            self.daysSinceLastUpdate = daysSinceLastUpdate
            self.averageActivityInterval = averageActivityInterval
            self.hasRecentActivity = hasRecentActivity
            self.hasSignificantGaps = hasSignificantGaps
            self.milestoneCount = milestoneCount
        }
    }
    
    public struct TimelineMilestone: Identifiable, Equatable {
        public let id = UUID()
        public let date: Date
        public let title: String
        public let screenshotIds: [UUID]
        public let importance: ImportanceLevel
        
        public enum ImportanceLevel: String, CaseIterable {
            case major = "Major"
            case minor = "Minor"
            
            public var color: Color {
                switch self {
                case .major: return .blue
                case .minor: return .gray
                }
            }
            
            public var size: CGFloat {
                switch self {
                case .major: return 12.0
                case .minor: return 8.0
                }
            }
        }
        
        public init(
            date: Date,
            title: String,
            screenshotIds: [UUID] = [],
            importance: ImportanceLevel = .minor
        ) {
            self.date = date
            self.title = title
            self.screenshotIds = screenshotIds
            self.importance = importance
        }
    }
    
    public struct TimelineEvent: Identifiable, Equatable {
        public let id = UUID()
        public let date: Date
        public let type: EventType
        public let title: String
        public let description: String
        public let screenshots: [Screenshot]
        public let milestone: TimelineMilestone?
        
        public enum EventType {
            case workspaceCreated
            case screenshotAdded
            case milestoneReached
            case progressUpdate
            
            public var iconName: String {
                switch self {
                case .workspaceCreated: return "plus.circle.fill"
                case .screenshotAdded: return "camera.fill"
                case .milestoneReached: return "flag.checkered.circle.fill"
                case .progressUpdate: return "arrow.up.circle.fill"
                }
            }
            
            public var color: Color {
                switch self {
                case .workspaceCreated: return .green
                case .screenshotAdded: return .blue
                case .milestoneReached: return .purple
                case .progressUpdate: return .orange
                }
            }
        }
        
        public init(
            date: Date,
            type: EventType,
            title: String,
            description: String,
            screenshots: [Screenshot] = [],
            milestone: TimelineMilestone? = nil
        ) {
            self.date = date
            self.type = type
            self.title = title
            self.description = description
            self.screenshots = screenshots
            self.milestone = milestone
        }
    }
    
    public struct TimelineGap: Identifiable, Equatable {
        public let id = UUID()
        public let startDate: Date
        public let endDate: Date
        public let suggestedContent: String
        public let severity: GapSeverity
        
        public enum GapSeverity: String, CaseIterable {
            case critical = "Critical"
            case moderate = "Moderate"
            case minor = "Minor"
            
            public var color: Color {
                switch self {
                case .critical: return .red
                case .moderate: return .orange
                case .minor: return .yellow
                }
            }
        }
        
        public init(
            startDate: Date,
            endDate: Date,
            suggestedContent: String,
            severity: GapSeverity = .minor
        ) {
            self.startDate = startDate
            self.endDate = endDate
            self.suggestedContent = suggestedContent
            self.severity = severity
        }
    }
    
    public struct ScheduledAction: Identifiable, Equatable {
        public let id = UUID()
        public let title: String
        public let recommendedDate: Date
        public let priority: ActionPriority
        public let estimatedDuration: TimeInterval
        
        public enum ActionPriority: String, CaseIterable {
            case urgent = "Urgent"
            case high = "High"
            case medium = "Medium"
            case low = "Low"
            
            public var color: Color {
                switch self {
                case .urgent: return .red
                case .high: return .orange
                case .medium: return .blue
                case .low: return .gray
                }
            }
        }
        
        public init(
            title: String,
            recommendedDate: Date,
            priority: ActionPriority = .medium,
            estimatedDuration: TimeInterval = 0
        ) {
            self.title = title
            self.recommendedDate = recommendedDate
            self.priority = priority
            self.estimatedDuration = estimatedDuration
        }
    }
    
    public struct ActionRecommendation: Identifiable, Equatable {
        public let id = UUID()
        public let title: String
        public let description: String
        public let actionType: ActionType
        public let priority: Priority
        public let estimatedImpact: ImpactLevel
        public let suggestedApps: [String]
        public let action: ContentWorkspace.WorkspaceAction
        public let reason: String
        public let estimatedEffort: EstimatedEffort
        
        public enum EstimatedEffort: String, CaseIterable {
            case quick = "Quick"
            case moderate = "Moderate"
            case significant = "Significant"
            
            public var displayName: String {
                return self.rawValue
            }
        }
        
        public enum ActionType: String, CaseIterable {
            case capture = "Capture"
            case organize = "Organize"
            case schedule = "Schedule"
            case share = "Share"
            case complete = "Complete"
            case review = "Review"
            
            public var iconName: String {
                switch self {
                case .capture: return "camera.fill"
                case .organize: return "folder.fill"
                case .schedule: return "calendar.badge.plus"
                case .share: return "square.and.arrow.up"
                case .complete: return "checkmark.circle.fill"
                case .review: return "eye.fill"
                }
            }
            
            public var color: Color {
                switch self {
                case .capture: return .blue
                case .organize: return .purple
                case .schedule: return .green
                case .share: return .orange
                case .complete: return .mint
                case .review: return .indigo
                }
            }
        }
        
        public enum Priority: String, CaseIterable {
            case critical = "Critical"
            case high = "High"
            case medium = "Medium"
            case low = "Low"
            
            public var displayName: String {
                return self.rawValue
            }
            
            public var color: Color {
                switch self {
                case .critical: return .red
                case .high: return .orange
                case .medium: return .blue
                case .low: return .gray
                }
            }
        }
        
        public enum ImpactLevel: String, CaseIterable {
            case high = "High"
            case medium = "Medium"
            case low = "Low"
            
            public var color: Color {
                switch self {
                case .high: return .green
                case .medium: return .yellow
                case .low: return .gray
                }
            }
        }
        
        public init(
            title: String,
            description: String,
            actionType: ActionType,
            priority: Priority = .medium,
            estimatedImpact: ImpactLevel = .medium,
            suggestedApps: [String] = [],
            action: ContentWorkspace.WorkspaceAction,
            reason: String,
            estimatedEffort: EstimatedEffort = .moderate
        ) {
            self.title = title
            self.description = description
            self.actionType = actionType
            self.priority = priority
            self.estimatedImpact = estimatedImpact
            self.suggestedApps = suggestedApps
            self.action = action
            self.reason = reason
            self.estimatedEffort = estimatedEffort
        }
    }
    

    
    // MARK: - Public Methods
    
    public func analyzeWorkspace(_ workspace: ContentWorkspace) async {
        guard !isAnalyzing else { return }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        logger.info("WorkspaceAnalyticsService: Analyzing workspace '\(workspace.title)'")
        
        let analytics = await performWorkspaceAnalysis(workspace)
        analyticsResults[workspace.id] = analytics
        
        logger.info("WorkspaceAnalyticsService: Analysis complete for workspace '\(workspace.title)'")
    }
    
    public func analyzeAllWorkspaces(_ workspaces: [ContentWorkspace]) async {
        guard !isAnalyzing else { return }
        
        analysisTask?.cancel()
        analysisTask = Task {
            await performBatchAnalysis(workspaces)
        }
        
        await analysisTask?.value
    }
    
    public func getAnalytics(for workspaceId: UUID) -> WorkspaceAnalytics? {
        return analyticsResults[workspaceId]
    }
    
    public func generateAnalytics(for workspace: ContentWorkspace) -> WorkspaceAnalytics {
        // Check if we already have analytics for this workspace
        if let existingAnalytics = analyticsResults[workspace.id] {
            return existingAnalytics
        }
        
        // Generate new analytics
        let completionAnalysis = analyzeCompletion(workspace)
        let progressTrends = analyzeProgressTrends(workspace)
        let missingComponentAnalysis = analyzeMissingComponents(workspace)
        let timelineAnalysis = analyzeTimeline(workspace)
        let actionRecommendations = generateActionRecommendations(workspace, completionAnalysis: completionAnalysis)
        
        let analytics = WorkspaceAnalytics(
            workspaceId: workspace.id,
            completionAnalysis: completionAnalysis,
            progressTrends: progressTrends,
            missingComponentAnalysis: missingComponentAnalysis,
            timelineAnalysis: timelineAnalysis,
            actionRecommendations: actionRecommendations
        )
        
        // Cache the results
        analyticsResults[workspace.id] = analytics
        
        return analytics
    }
    
    public func getTopInsights(limit: Int = 5) -> [CrossWorkspaceInsight] {
        return Array(crossWorkspaceInsights
            .sorted(by: { $0.connectionStrength > $1.connectionStrength })
            .prefix(limit))
    }
    
    public func getActionableInsights() -> [CrossWorkspaceInsight] {
        return crossWorkspaceInsights.filter { $0.connectionStrength > 0.5 }
    }
    
    // MARK: - Legacy Methods for Backward Compatibility
    
    public func calculateProgress(for workspace: inout ContentWorkspace) {
        // Enhanced version of the original method
        workspace.updateProgress()
        
        // Trigger analytics calculation in background
        let workspaceCopy = workspace
        Task {
            await analyzeWorkspace(workspaceCopy)
        }
    }
    
    public func findCrossWorkspaceRelationships(for workspace: ContentWorkspace, in allWorkspaces: [ContentWorkspace]) -> [ContentWorkspace] {
        // Enhanced version - now returns workspaces that have relationships
        let relatedWorkspaceIds = crossWorkspaceInsights
            .filter { $0.targetWorkspaceId == workspace.id }
            .map { $0.targetWorkspaceId }
            .filter { $0 != workspace.id }
        
        return allWorkspaces.filter { relatedWorkspaceIds.contains($0.id) }
    }
    
    // MARK: - Private Analysis Methods
    
    private func performBatchAnalysis(_ workspaces: [ContentWorkspace]) async {
        guard !Task.isCancelled else { return }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        logger.info("WorkspaceAnalyticsService: Starting batch analysis of \(workspaces.count) workspaces")
        
        // Analyze each workspace individually
        for workspace in workspaces {
            guard !Task.isCancelled else { break }
            
            let analytics = await performWorkspaceAnalysis(workspace)
            analyticsResults[workspace.id] = analytics
        }
        
        // Perform cross-workspace analysis
        if !Task.isCancelled {
            await performCrossWorkspaceAnalysis(workspaces)
        }
        
        logger.info("WorkspaceAnalyticsService: Batch analysis complete")
    }
    
    private func performWorkspaceAnalysis(_ workspace: ContentWorkspace) async -> WorkspaceAnalytics {
        let completionAnalysis = analyzeCompletion(workspace)
        let progressTrends = analyzeProgressTrends(workspace)
        let missingComponentAnalysis = analyzeMissingComponents(workspace)
        let timelineAnalysis = analyzeTimeline(workspace)
        let actionRecommendations = generateActionRecommendations(workspace, completionAnalysis: completionAnalysis)
        
        return WorkspaceAnalytics(
            workspaceId: workspace.id,
            completionAnalysis: completionAnalysis,
            progressTrends: progressTrends,
            missingComponentAnalysis: missingComponentAnalysis,
            timelineAnalysis: timelineAnalysis,
            actionRecommendations: actionRecommendations
        )
    }
    
    private func analyzeCompletion(_ workspace: ContentWorkspace) -> CompletionAnalysis {
        _ = workspace.progress
        let screenshots = workspace.screenshots
        
        // Calculate component completion based on workspace type
        var componentCompletion: [String: Double] = [:]
        var blockers: [String] = []
        
        switch workspace.type {
        case .travel(_, let dates):
            let hasFlightInfo = screenshots.contains { $0.extractedText?.lowercased().contains("flight") == true }
            let hasHotelInfo = screenshots.contains { $0.extractedText?.lowercased().contains("hotel") == true }
            let hasCarRental = screenshots.contains { $0.extractedText?.lowercased().contains("rental") == true }
            let hasItinerary = screenshots.contains { $0.extractedText?.lowercased().contains("itinerary") == true }
            
            componentCompletion["Transportation"] = hasFlightInfo ? 100.0 : 0.0
            componentCompletion["Accommodation"] = hasHotelInfo ? 100.0 : 0.0
            componentCompletion["Ground Transport"] = hasCarRental ? 100.0 : 0.0
            componentCompletion["Planning"] = hasItinerary ? 100.0 : 0.0
            
            if !hasFlightInfo && dates.end.timeIntervalSinceNow < 86400 * 7 { // Within a week
                blockers.append("Flight booking needed soon")
            }
            
        case .project(_, let status):
            if status == .active {
                let hasProjectPlan = screenshots.contains { $0.extractedText?.lowercased().contains("plan") == true }
                let hasBudget = screenshots.contains { $0.extractedText?.lowercased().contains("budget") == true }
                let hasTimeline = screenshots.contains { $0.extractedText?.lowercased().contains("timeline") == true }
                
                componentCompletion["Planning"] = hasProjectPlan ? 100.0 : 0.0
                componentCompletion["Budget"] = hasBudget ? 100.0 : 0.0
                componentCompletion["Timeline"] = hasTimeline ? 100.0 : 0.0
                
                if !hasProjectPlan {
                    blockers.append("Project planning incomplete")
                }
            }
            
        case .event(_, let date):
            let hasVenue = screenshots.contains { $0.extractedText?.lowercased().contains("venue") == true }
            let hasTickets = screenshots.contains { $0.extractedText?.lowercased().contains("ticket") == true }
            let hasSchedule = screenshots.contains { $0.extractedText?.lowercased().contains("schedule") == true }
            
            componentCompletion["Venue"] = hasVenue ? 100.0 : 0.0
            componentCompletion["Tickets"] = hasTickets ? 100.0 : 0.0
            componentCompletion["Schedule"] = hasSchedule ? 100.0 : 0.0
            
            if !hasTickets && date.timeIntervalSinceNow < 86400 * 3 { // Within 3 days
                blockers.append("Tickets needed urgently")
            }
            
        case .learning(_, _):
            let hasNotes = screenshots.contains { $0.extractedText?.lowercased().contains("note") == true }
            let hasAssignments = screenshots.contains { $0.extractedText?.lowercased().contains("assignment") == true }
            let hasResources = screenshots.contains { $0.extractedText?.lowercased().contains("resource") == true }
            
            componentCompletion["Study Materials"] = hasNotes ? 100.0 : 0.0
            componentCompletion["Assignments"] = hasAssignments ? 100.0 : 0.0
            componentCompletion["Resources"] = hasResources ? 100.0 : 0.0
            
        case .shopping(_, let budget):
            let hasReceipts = screenshots.contains { $0.extractedText?.lowercased().contains("receipt") == true }
            let hasWishlist = screenshots.contains { $0.extractedText?.lowercased().contains("wishlist") == true }
            let hasBudgetInfo = budget != nil
            
            componentCompletion["Purchase History"] = hasReceipts ? 100.0 : 0.0
            componentCompletion["Shopping List"] = hasWishlist ? 100.0 : 0.0
            componentCompletion["Budget Planning"] = hasBudgetInfo ? 100.0 : 0.0
            
        case .health(_, _):
            let hasAppointments = screenshots.contains { $0.extractedText?.lowercased().contains("appointment") == true }
            let hasResults = screenshots.contains { $0.extractedText?.lowercased().contains("result") == true }
            let hasRecords = screenshots.contains { $0.extractedText?.lowercased().contains("record") == true }
            
            componentCompletion["Appointments"] = hasAppointments ? 100.0 : 0.0
            componentCompletion["Test Results"] = hasResults ? 100.0 : 0.0
            componentCompletion["Medical Records"] = hasRecords ? 100.0 : 0.0
            
        case .other:
            componentCompletion["General Content"] = screenshots.isEmpty ? 0.0 : 50.0
        }
        
        // Calculate estimated time to completion
        let averageComponentCompletion = componentCompletion.values.reduce(0, +) / Double(max(componentCompletion.count, 1))
        let remainingCompletion = 100.0 - averageComponentCompletion
        let estimatedTime = remainingCompletion > 0 ? TimeInterval(remainingCompletion * 3600) : nil // 1 hour per percent remaining
        
        // Calculate confidence based on screenshot count and content quality
        let confidence = min(1.0, Double(screenshots.count) / 5.0) * (workspace.detectionConfidence)
        
        return CompletionAnalysis(
            overallCompletion: averageComponentCompletion / 100.0, // Convert to 0-1 scale
            componentCompletion: componentCompletion,
            estimatedTimeToComplete: estimatedTime,
            confidence: confidence,
            blockers: blockers,
            criticalMissingCount: blockers.count
        )
    }
    
    private func analyzeProgressTrends(_ workspace: ContentWorkspace) -> ProgressTrends {
        let screenshots = workspace.screenshots.sorted { $0.timestamp < $1.timestamp }
        
        // Generate progress history
        var progressHistory: [ProgressDataPoint] = []
        let calendar = Calendar.current
        
        if let firstDate = screenshots.first?.timestamp {
            let daysSinceStart = firstDate.timeIntervalSinceNow * -1
            let totalDays = max(1, Int(daysSinceStart / 86400))
            
            for day in 0...totalDays {
                let date = calendar.date(byAdding: .day, value: day, to: firstDate) ?? firstDate
                let screenshotsUpToDate = screenshots.filter { $0.timestamp <= date }
                let completionPercentage = Double(screenshotsUpToDate.count) / Double(max(screenshots.count, 1)) * 100.0
                
                progressHistory.append(ProgressDataPoint(
                    date: date,
                    screenshotCount: screenshotsUpToDate.count,
                    completionPercentage: completionPercentage
                ))
            }
        }
        
        // Calculate velocity (screenshots per day)
        let velocity: Double = {
            guard progressHistory.count >= 2 else { return 0.0 }
            let recentHistory = Array(progressHistory.suffix(7)) // Last 7 days
            return Double((recentHistory.last?.screenshotCount ?? 0) - (recentHistory.first?.screenshotCount ?? 0)) / Double(max(recentHistory.count - 1, 1))
        }()
        
        // Determine momentum
        let momentum: ProgressTrends.TrendDirection = {
            guard progressHistory.count >= 3 else { return .stalled }
            
            let recent = Array(progressHistory.suffix(3))
            let recentVelocity = Double((recent.last?.screenshotCount ?? 0) - (recent.first?.screenshotCount ?? 0)) / Double(recent.count - 1)
            
            if recentVelocity > velocity * 1.2 {
                return .accelerating
            } else if recentVelocity > velocity * 0.8 {
                return .steady
            } else if recentVelocity > 0 {
                return .slowing
            } else {
                return .stalled
            }
        }()
        
        // Predict completion date
        let predictedCompletion: Date? = {
            guard velocity > 0, let lastDataPoint = progressHistory.last else { return nil }
            let remainingScreenshots = 100.0 - lastDataPoint.completionPercentage
            let daysToComplete = remainingScreenshots / (velocity * 10) // Rough estimate
            return Calendar.current.date(byAdding: .day, value: Int(daysToComplete), to: Date())
        }()
        
        return ProgressTrends(
            velocity: velocity,
            momentum: momentum,
            progressHistory: progressHistory,
            predictedCompletion: predictedCompletion,
            estimatedDaysToCompletion: Int(velocity > 0 ? 100.0 / (velocity * 10) : 30),
            recentActivityLevel: min(1.0, velocity)
        )
    }
    
    private func analyzeMissingComponents(_ workspace: ContentWorkspace) -> MissingComponentAnalysis {
        var criticalComponents: [MissingComponent] = []
        var optionalComponents: [MissingComponent] = []
        var suggestedSources: [String: [String]] = [:]
        
        let missingFromProgress = workspace.progress.missingComponents
        
        switch workspace.type {
        case .travel(_, let dates):
            let isUpcoming = dates.start.timeIntervalSinceNow > 0
            let isImminentTravel = dates.start.timeIntervalSinceNow < 86400 * 7 // Within a week
            
            for missing in missingFromProgress {
                let importance: MissingComponent.ImportanceLevel = isImminentTravel ? .critical : (isUpcoming ? .important : .nice)
                let suggestedActions = getSuggestedActionsForTravelComponent(missing)
                
                let component = MissingComponent(
                    name: missing,
                    description: "Required for travel to \(workspace.title)",
                    importance: importance,
                    suggestedActions: suggestedActions
                )
                
                if importance == .critical {
                    criticalComponents.append(component)
                } else {
                    optionalComponents.append(component)
                }
                
                suggestedSources[missing] = getSuggestedSourcesForTravel(missing)
            }
            
        case .project(_, let status):
            let isActive = status == .active
            
            for missing in missingFromProgress {
                let importance: MissingComponent.ImportanceLevel = isActive ? .important : .nice
                let suggestedActions = getSuggestedActionsForProjectComponent(missing)
                
                let component = MissingComponent(
                    name: missing,
                    description: "Needed for project completion",
                    importance: importance,
                    suggestedActions: suggestedActions
                )
                
                if importance == .critical || importance == .important {
                    criticalComponents.append(component)
                } else {
                    optionalComponents.append(component)
                }
                
                suggestedSources[missing] = getSuggestedSourcesForProject(missing)
            }
            
        case .event(_, let date):
            let isUpcoming = date.timeIntervalSinceNow > 0
            let isImminentEvent = date.timeIntervalSinceNow < 86400 * 3 // Within 3 days
            
            for missing in missingFromProgress {
                let importance: MissingComponent.ImportanceLevel = isImminentEvent ? .critical : (isUpcoming ? .important : .nice)
                let suggestedActions = getSuggestedActionsForEventComponent(missing)
                
                let component = MissingComponent(
                    name: missing,
                    description: "Required for event attendance",
                    importance: importance,
                    suggestedActions: suggestedActions
                )
                
                if importance == .critical {
                    criticalComponents.append(component)
                } else {
                    optionalComponents.append(component)
                }
                
                suggestedSources[missing] = getSuggestedSourcesForEvent(missing)
            }
            
        default:
            for missing in missingFromProgress {
                let component = MissingComponent(
                    name: missing,
                    description: "Missing component for \(workspace.type.displayName)",
                    importance: .nice,
                    suggestedActions: ["Capture relevant screenshot", "Add manual note"]
                )
                optionalComponents.append(component)
            }
        }
        
        let priority: MissingComponentAnalysis.ComponentPriority = {
            if !criticalComponents.isEmpty {
                return .high
            } else if !optionalComponents.isEmpty {
                return .medium
            } else {
                return .low
            }
        }()
        
        return MissingComponentAnalysis(
            criticalComponents: criticalComponents,
            optionalComponents: optionalComponents,
            suggestedSources: suggestedSources,
            priority: priority,
            criticalMissing: criticalComponents.map { $0.name },
            recommendedAdditions: optionalComponents.map { $0.name },
            completionBlockers: criticalComponents.filter { $0.importance == .critical }.map { $0.name }
        )
    }
    
    private func analyzeTimeline(_ workspace: ContentWorkspace) -> TimelineAnalysis {
        let screenshots = workspace.screenshots.sorted { $0.timestamp < $1.timestamp }
        
        var milestones: [TimelineMilestone] = []
        var gaps: [TimelineGap] = []
        var recommendedSchedule: [ScheduledAction] = []
        
        // Generate milestones from screenshots
        let calendar = Calendar.current
        var currentDate: Date?
        var currentGroup: [Screenshot] = []
        
        for screenshot in screenshots {
            let screenshotDate = calendar.startOfDay(for: screenshot.timestamp)
            
            if let current = currentDate, calendar.isDate(screenshotDate, inSameDayAs: current) {
                currentGroup.append(screenshot)
            } else {
                // Process previous group if exists
                if let prevDate = currentDate, !currentGroup.isEmpty {
                    let milestone = TimelineMilestone(
                        date: prevDate,
                        title: generateMilestoneTitle(for: currentGroup, in: workspace),
                        screenshotIds: currentGroup.map { $0.id },
                        importance: currentGroup.count >= 3 ? .major : .minor
                    )
                    milestones.append(milestone)
                }
                
                // Start new group
                currentDate = screenshotDate
                currentGroup = [screenshot]
            }
        }
        
        // Process final group
        if let finalDate = currentDate, !currentGroup.isEmpty {
            let milestone = TimelineMilestone(
                date: finalDate,
                title: generateMilestoneTitle(for: currentGroup, in: workspace),
                screenshotIds: currentGroup.map { $0.id },
                importance: currentGroup.count >= 3 ? .major : .minor
            )
            milestones.append(milestone)
        }
        
        // Identify gaps
        for i in 0..<(milestones.count - 1) {
            let currentMilestone = milestones[i]
            let nextMilestone = milestones[i + 1]
            
            let daysBetween = calendar.dateComponents([.day], from: currentMilestone.date, to: nextMilestone.date).day ?? 0
            
            if daysBetween > 7 { // More than a week gap
                let severity: TimelineGap.GapSeverity = daysBetween > 30 ? .critical : (daysBetween > 14 ? .moderate : .minor)
                let suggestedContent = generateGapSuggestion(for: workspace, between: currentMilestone, and: nextMilestone)
                
                let gap = TimelineGap(
                    startDate: currentMilestone.date,
                    endDate: nextMilestone.date,
                    suggestedContent: suggestedContent,
                    severity: severity
                )
                gaps.append(gap)
            }
        }
        
        // Generate recommended schedule
        recommendedSchedule = generateRecommendedSchedule(for: workspace, basedOn: milestones)
        
        // Calculate timeline efficiency
        let totalDays = screenshots.count > 1 ? calendar.dateComponents([.day], from: screenshots.first!.timestamp, to: screenshots.last!.timestamp).day ?? 1 : 1
        let activeDays = Set(screenshots.map { calendar.startOfDay(for: $0.timestamp) }).count
        let timelineEfficiency = Double(activeDays) / Double(max(totalDays, 1))
        
        return TimelineAnalysis(
            milestones: milestones,
            gaps: gaps,
            recommendedSchedule: recommendedSchedule,
            timelineEfficiency: timelineEfficiency,
            workspaceDuration: Date().timeIntervalSince(workspace.createdAt),
            daysSinceLastUpdate: Date().timeIntervalSince(workspace.lastUpdated) / 86400,
            averageActivityInterval: totalDays > 0 ? Double(totalDays) / Double(max(activeDays, 1)) : 1.0,
            hasRecentActivity: Date().timeIntervalSince(workspace.lastUpdated) <= 86400 * 7,
            hasSignificantGaps: !gaps.isEmpty,
            milestoneCount: milestones.count
        )
    }
    
    private func generateActionRecommendations(_ workspace: ContentWorkspace, completionAnalysis: CompletionAnalysis) -> [ActionRecommendation] {
        var recommendations: [ActionRecommendation] = []
        
        // Add recommendations based on missing components
        for missing in workspace.progress.missingComponents {
            let recommendation = ActionRecommendation(
                title: "Capture \(missing)",
                description: "Add \(missing.lowercased()) to complete your \(workspace.type.displayName.lowercased())",
                actionType: .capture,
                priority: .high,
                estimatedImpact: .high,
                suggestedApps: getSuggestedAppsForComponent(missing, in: workspace),
                action: .addMissingComponent(missing),
                reason: "Required for workspace completion",
                estimatedEffort: .moderate
            )
            recommendations.append(recommendation)
        }
        
        // Add completion-based recommendations
        if completionAnalysis.overallCompletion < 0.5 {
            recommendations.append(ActionRecommendation(
                title: "Organize Content",
                description: "Your \(workspace.type.displayName.lowercased()) is less than 50% complete. Consider organizing existing content and identifying missing pieces.",
                actionType: .organize,
                priority: .medium,
                estimatedImpact: .medium,
                suggestedApps: ["Notes", "Reminders", "Files"],
                action: .addScreenshot,
                reason: "Low completion percentage requires organization",
                estimatedEffort: .moderate
            ))
        }
        
        if completionAnalysis.overallCompletion > 0.8 && !completionAnalysis.blockers.isEmpty {
            recommendations.append(ActionRecommendation(
                title: "Review Final Details",
                description: "You're almost done! Review final details and resolve any remaining items.",
                actionType: .review,
                priority: .high,
                estimatedImpact: .high,
                suggestedApps: ["Notes", "Checklist"],
                action: .completeTask("Review final details"),
                reason: "Near completion with remaining blockers",
                estimatedEffort: .quick
            ))
        }
        
        // Add workspace-specific recommendations
        switch workspace.type {
        case .travel(_, let dates):
            if dates.start.timeIntervalSinceNow < 86400 * 7 && dates.start.timeIntervalSinceNow > 0 {
                recommendations.append(ActionRecommendation(
                    title: "Travel Checklist",
                    description: "Your trip is coming up soon. Create a final travel checklist to ensure nothing is forgotten.",
                    actionType: .schedule,
                    priority: .critical,
                    estimatedImpact: .high,
                    suggestedApps: ["Reminders", "Notes", "Packing Pro"],
                    action: .scheduleEvent,
                    reason: "Imminent travel date approaching",
                    estimatedEffort: .quick
                ))
            }
            
        case .project(_, let status):
            if status == .active && workspace.screenshots.count > 10 {
                recommendations.append(ActionRecommendation(
                    title: "Share Progress",
                    description: "Consider sharing your project progress with stakeholders or team members.",
                    actionType: .share,
                    priority: .medium,
                    estimatedImpact: .medium,
                    suggestedApps: ["Slack", "Mail", "Messages", "Teams"],
                    action: .shareWorkspace,
                    reason: "Active project with significant content",
                    estimatedEffort: .quick
                ))
            }
            
        case .event(_, let date):
            if date.timeIntervalSinceNow < 86400 * 3 && date.timeIntervalSinceNow > 0 {
                recommendations.append(ActionRecommendation(
                    title: "Event Preparation",
                    description: "Your event is in 3 days. Make sure all preparations are complete.",
                    actionType: .complete,
                    priority: .critical,
                    estimatedImpact: .high,
                    suggestedApps: ["Calendar", "Reminders", "Maps"],
                    action: .scheduleEvent,
                    reason: "Event approaching in 3 days",
                    estimatedEffort: .moderate
                ))
            }
            
        default:
            break
        }
        
        return recommendations.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
    
    private func performCrossWorkspaceAnalysis(_ workspaces: [ContentWorkspace]) async {
        var insights: [CrossWorkspaceInsight] = []
        
        // Analyze workspace pairs for relationships
        for i in 0..<workspaces.count {
            for j in (i+1)..<workspaces.count {
                let workspace1 = workspaces[i]
                let workspace2 = workspaces[j]
                
                let pairInsights = analyzePairRelationship(workspace1, workspace2)
                insights.append(contentsOf: pairInsights)
            }
        }
        
        crossWorkspaceInsights = insights.sorted(by: { $0.connectionStrength > $1.connectionStrength })
    }
    
    private func analyzePairRelationship(_ workspace1: ContentWorkspace, _ workspace2: ContentWorkspace) -> [CrossWorkspaceInsight] {
        var insights: [CrossWorkspaceInsight] = []
        
        // Check for content overlap
        let commonText = findCommonTextPatterns(workspace1.screenshots, workspace2.screenshots)
        if !commonText.isEmpty {
            insights.append(CrossWorkspaceInsight(
                targetWorkspaceId: workspace2.id,
                relationshipType: .similar,
                connectionStrength: 0.7,
                suggestedActions: ["Review shared content", "Consider merging workspaces"],
                insights: ["Found common elements: \(commonText.joined(separator: ", "))"]
            ))
        }
        
        // Check for timeline conflicts (travel/events)
        if case .travel(_, let dates1) = workspace1.type,
           case .travel(_, let dates2) = workspace2.type {
            if dates1.intersects(dates2) {
                insights.append(CrossWorkspaceInsight(
                    targetWorkspaceId: workspace2.id,
                    relationshipType: .complementary,
                    connectionStrength: 0.9,
                    suggestedActions: ["Review travel dates", "Check for conflicts"],
                    insights: ["Travel dates overlap - potential conflict"]
                ))
            }
        }
        
        // Check for budget relationships
        if case .shopping(_, let budget1) = workspace1.type,
           case .shopping(_, let budget2) = workspace2.type,
           let b1 = budget1, let b2 = budget2 {
            let totalBudget = b1 + b2
            if totalBudget > 1000 { // Arbitrary threshold for large combined budget
                insights.append(CrossWorkspaceInsight(
                    targetWorkspaceId: workspace2.id,
                    relationshipType: .related,
                    connectionStrength: 0.6,
                    suggestedActions: ["Review combined budget", "Consider consolidation"],
                    insights: ["Combined budget is $\(String(format: "%.2f", totalBudget))"]
                ))
            }
        }
        
        return insights
    }
    
    // MARK: - Helper Methods
    
    private func findCommonTextPatterns(_ screenshots1: [Screenshot], _ screenshots2: [Screenshot]) -> [String] {
        let text1 = screenshots1.compactMap { $0.extractedText?.lowercased() }
        let text2 = screenshots2.compactMap { $0.extractedText?.lowercased() }
        
        var commonPatterns: [String] = []
        
        for t1 in text1 {
            for t2 in text2 {
                let words1 = Set(t1.components(separatedBy: .whitespacesAndNewlines))
                let words2 = Set(t2.components(separatedBy: .whitespacesAndNewlines))
                let intersection = words1.intersection(words2)
                
                let significantWords = intersection.filter { $0.count > 3 } // Words longer than 3 characters
                commonPatterns.append(contentsOf: significantWords)
            }
        }
        
        return Array(Set(commonPatterns)).prefix(3).map { String($0) }
    }
    
    private func generateMilestoneTitle(for screenshots: [Screenshot], in workspace: ContentWorkspace) -> String {
        if screenshots.count == 1 {
            return "Single Update"
        } else {
            return "\(screenshots.count) Updates"
        }
    }
    
    private func generateGapSuggestion(for workspace: ContentWorkspace, between milestone1: TimelineMilestone, and milestone2: TimelineMilestone) -> String {
        switch workspace.type {
        case .travel:
            return "Travel planning updates"
        case .project:
            return "Project progress documentation"
        case .event:
            return "Event preparation materials"
        case .learning:
            return "Study materials or assignments"
        case .shopping:
            return "Shopping research or receipts"
        case .health:
            return "Health records or appointments"
        case .other:
            return "Additional content"
        }
    }
    
    private func generateRecommendedSchedule(for workspace: ContentWorkspace, basedOn milestones: [TimelineMilestone]) -> [ScheduledAction] {
        var actions: [ScheduledAction] = []
        
        switch workspace.type {
        case .travel(_, let dates):
            if dates.start.timeIntervalSinceNow > 0 {
                actions.append(ScheduledAction(
                    title: "Finalize travel documents",
                    recommendedDate: Calendar.current.date(byAdding: .day, value: -7, to: dates.start) ?? dates.start,
                    priority: .high,
                    estimatedDuration: 3600 // 1 hour
                ))
            }
            
        case .project(_, let status):
            if status == .active {
                actions.append(ScheduledAction(
                    title: "Project status review",
                    recommendedDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                    priority: .medium,
                    estimatedDuration: 1800 // 30 minutes
                ))
            }
            
        case .event(_, let date):
            if date.timeIntervalSinceNow > 0 {
                actions.append(ScheduledAction(
                    title: "Event preparation checklist",
                    recommendedDate: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date,
                    priority: .high,
                    estimatedDuration: 1800 // 30 minutes
                ))
            }
            
        default:
            break
        }
        
        return actions
    }
    
    private func getSuggestedActionsForTravelComponent(_ component: String) -> [String] {
        switch component.lowercased() {
        case let c where c.contains("flight"):
            return ["Check airline websites", "Compare flight prices", "Book preferred flight"]
        case let c where c.contains("hotel"):
            return ["Search booking websites", "Read hotel reviews", "Make reservation"]
        case let c where c.contains("rental"):
            return ["Compare rental car options", "Check pickup locations", "Make reservation"]
        default:
            return ["Research options", "Make booking", "Save confirmation"]
        }
    }
    
    private func getSuggestedActionsForProjectComponent(_ component: String) -> [String] {
        switch component.lowercased() {
        case let c where c.contains("plan"):
            return ["Create project outline", "Define milestones", "Set timeline"]
        case let c where c.contains("budget"):
            return ["Estimate costs", "Get quotes", "Approve budget"]
        default:
            return ["Research requirements", "Create document", "Get approval"]
        }
    }
    
    private func getSuggestedActionsForEventComponent(_ component: String) -> [String] {
        switch component.lowercased() {
        case let c where c.contains("venue"):
            return ["Research venues", "Check availability", "Book venue"]
        case let c where c.contains("ticket"):
            return ["Find ticket sales", "Purchase tickets", "Save confirmations"]
        default:
            return ["Research options", "Make arrangements", "Confirm details"]
        }
    }
    
    private func getSuggestedSourcesForTravel(_ component: String) -> [String] {
        switch component.lowercased() {
        case let c where c.contains("flight"):
            return ["Airline websites", "Expedia", "Kayak", "Google Flights"]
        case let c where c.contains("hotel"):
            return ["Booking.com", "Hotels.com", "Airbnb", "Hotel websites"]
        case let c where c.contains("rental"):
            return ["Enterprise", "Hertz", "Budget", "Turo"]
        default:
            return ["Travel websites", "Apps", "Direct booking"]
        }
    }
    
    private func getSuggestedSourcesForProject(_ component: String) -> [String] {
        switch component.lowercased() {
        case let c where c.contains("plan"):
            return ["Project management tools", "Templates", "Team collaboration"]
        case let c where c.contains("budget"):
            return ["Spreadsheet apps", "Financial tools", "Accounting software"]
        default:
            return ["Productivity apps", "Documents", "Templates"]
        }
    }
    
    private func getSuggestedSourcesForEvent(_ component: String) -> [String] {
        switch component.lowercased() {
        case let c where c.contains("venue"):
            return ["Venue websites", "Event spaces", "Local directories"]
        case let c where c.contains("ticket"):
            return ["Ticketmaster", "Eventbrite", "Official websites"]
        default:
            return ["Event websites", "Local resources", "Online platforms"]
        }
    }
    
    private func getSuggestedAppsForComponent(_ component: String, in workspace: ContentWorkspace) -> [String] {
        switch workspace.type {
        case .travel:
            return ["TripIt", "Google Travel", "Expedia", "Booking.com"]
        case .project:
            return ["Notion", "Asana", "Trello", "Monday.com"]
        case .event:
            return ["Eventbrite", "Facebook Events", "Calendar", "Reminders"]
        case .learning:
            return ["Notion", "GoodNotes", "Anki", "Quizlet"]
        case .shopping:
            return ["Amazon", "Notes", "Honey", "Rakuten"]
        case .health:
            return ["Health", "MyChart", "Apple Health", "Medisafe"]
        case .other:
            return ["Notes", "Files", "Photos", "Reminders"]
        }
    }
    
    // MARK: - Cross-Workspace Analytics
    
    public func generateCrossWorkspaceAnalytics(for workspace: ContentWorkspace, allWorkspaces: [ContentWorkspace]) -> [CrossWorkspaceInsight] {
        var insights: [CrossWorkspaceInsight] = []
        
        // Find related workspaces based on content similarity
        let relatedWorkspaces = findRelatedWorkspaces(for: workspace, in: allWorkspaces)
        
        for relatedWorkspace in relatedWorkspaces {
            let insight = CrossWorkspaceInsight(
                targetWorkspaceId: relatedWorkspace.id,
                relationshipType: determineRelationshipType(between: workspace, and: relatedWorkspace),
                connectionStrength: calculateConnectionStrength(between: workspace, and: relatedWorkspace),
                suggestedActions: generateCrossWorkspaceActions(from: workspace, to: relatedWorkspace),
                insights: generateRelationshipInsights(between: workspace, and: relatedWorkspace)
            )
            insights.append(insight)
        }
        
        return insights
    }
    
    private func findRelatedWorkspaces(for workspace: ContentWorkspace, in allWorkspaces: [ContentWorkspace]) -> [ContentWorkspace] {
        return allWorkspaces.filter { otherWorkspace in
            otherWorkspace.id != workspace.id && 
            calculateConnectionStrength(between: workspace, and: otherWorkspace) > 0.3
        }
    }
    
    private func determineRelationshipType(between workspace1: ContentWorkspace, and workspace2: ContentWorkspace) -> CrossWorkspaceInsight.RelationshipType {
        // Simple heuristic based on workspace types
        switch (workspace1.type, workspace2.type) {
        case (.travel, .travel), (.project, .project):
            return .similar
        case (.travel, .shopping), (.shopping, .travel):
            return .complementary
        default:
            return .related
        }
    }
    
    private func calculateConnectionStrength(between workspace1: ContentWorkspace, and workspace2: ContentWorkspace) -> Double {
        var strength = 0.0
        
        // Time-based connection (if workspaces overlap in time)
        let timeOverlap = calculateTimeOverlap(workspace1, workspace2)
        strength += timeOverlap * 0.3
        
        // Content similarity (simplified)
        let contentSimilarity = calculateContentSimilarity(workspace1, workspace2)
        strength += contentSimilarity * 0.4
        
        // Type similarity
        let typeSimilarity = workspace1.type == workspace2.type ? 0.3 : 0.0
        strength += typeSimilarity
        
        return min(1.0, strength)
    }
    
    private func calculateTimeOverlap(_ workspace1: ContentWorkspace, _ workspace2: ContentWorkspace) -> Double {
        // Simplified time overlap calculation
        let timeDiff = abs(workspace1.createdAt.timeIntervalSince(workspace2.createdAt))
        return max(0.0, 1.0 - (timeDiff / (7 * 24 * 3600))) // Within a week = strong connection
    }
    
    private func calculateContentSimilarity(_ workspace1: ContentWorkspace, _ workspace2: ContentWorkspace) -> Double {
        // Simplified content similarity based on screenshot count and titles
        let screenshotCountSimilarity = 1.0 - abs(Double(workspace1.screenshots.count - workspace2.screenshots.count)) / 10.0
        let titleSimilarity = workspace1.title.lowercased().contains(workspace2.title.lowercased().prefix(3)) ? 0.5 : 0.0
        return max(0.0, (screenshotCountSimilarity + titleSimilarity) / 2.0)
    }
    
    private func generateCrossWorkspaceActions(from sourceWorkspace: ContentWorkspace, to targetWorkspace: ContentWorkspace) -> [String] {
        return [
            "Compare progress with \(targetWorkspace.title)",
            "Apply lessons learned from \(targetWorkspace.title)",
            "Merge related content from \(targetWorkspace.title)"
        ]
    }
    
    private func generateRelationshipInsights(between workspace1: ContentWorkspace, and workspace2: ContentWorkspace) -> [String] {
        return [
            "Both workspaces share similar patterns",
            "Consider consolidating related screenshots",
            "Apply successful strategies from one to the other"
        ]
    }
    
    // MARK: - Cross-Workspace Data Structures
    
    public struct CrossWorkspaceInsight: Identifiable, Equatable {
        public let id = UUID()
        public let targetWorkspaceId: UUID
        public let relationshipType: RelationshipType
        public let connectionStrength: Double
        public let suggestedActions: [String]
        public let insights: [String]
        
        public enum RelationshipType: String, CaseIterable {
            case similar = "Similar"
            case complementary = "Complementary"
            case related = "Related"
            
            public var displayName: String {
                return self.rawValue
            }
            
            public var color: Color {
                switch self {
                case .similar: return .blue
                case .complementary: return .green
                case .related: return .purple
                }
            }
        }
        
        public init(
            targetWorkspaceId: UUID,
            relationshipType: RelationshipType,
            connectionStrength: Double,
            suggestedActions: [String],
            insights: [String]
        ) {
            self.targetWorkspaceId = targetWorkspaceId
            self.relationshipType = relationshipType
            self.connectionStrength = max(0.0, min(1.0, connectionStrength))
            self.suggestedActions = suggestedActions
            self.insights = insights
        }
    }
}
