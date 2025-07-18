
import Foundation
import SwiftData
import SwiftUI

@MainActor
class WorkspaceInsightsEngine: ObservableObject {
    private let analyticsService = WorkspaceAnalyticsService.shared
    
    // MARK: - Type Aliases for Clarity
    
    typealias TimelineAnalysis = WorkspaceAnalyticsService.TimelineAnalysis
    typealias MissingComponentAnalysis = WorkspaceAnalyticsService.MissingComponentAnalysis
    typealias CrossWorkspaceInsights = WorkspaceAnalyticsService.CrossWorkspaceInsight
    
    // MARK: - Primary Insights Generation
    
    func generateInsights(for workspace: ContentWorkspace) -> [String] {
        let analytics = analyticsService.generateAnalytics(for: workspace)
        var insights: [String] = []
        
        // Progress-based insights
        insights.append(contentsOf: generateProgressInsights(from: analytics))
        
        // Timeline-based insights
        insights.append(contentsOf: generateTimelineInsights(from: analytics))
        
        // Missing component insights
        insights.append(contentsOf: generateComponentInsights(from: analytics))
        
        // Action recommendation insights
        insights.append(contentsOf: generateActionInsights(from: analytics))
        
        return insights
    }
    
    // MARK: - Advanced Insights Generation
    
    func generateAdvancedInsights(for workspace: ContentWorkspace, allWorkspaces: [ContentWorkspace] = []) -> WorkspaceAdvancedInsights {
        let analytics = analyticsService.generateAnalytics(for: workspace)
        let crossWorkspaceInsights = analyticsService.generateCrossWorkspaceAnalytics(for: workspace, allWorkspaces: allWorkspaces)
        
        return WorkspaceAdvancedInsights(
            progressInsights: generateDetailedProgressInsights(from: analytics),
            timelineInsights: generateDetailedTimelineInsights(from: analytics),
            componentInsights: generateDetailedComponentInsights(from: analytics),
            crossWorkspaceInsights: generateCrossWorkspaceInsightTexts(from: crossWorkspaceInsights),
            actionRecommendations: analytics.actionRecommendations,
            workspaceMomentum: calculateWorkspaceMomentum(from: analytics),
            completionPrediction: predictCompletion(from: analytics),
            nextBestActions: identifyNextBestActions(from: analytics)
        )
    }
    
    // MARK: - Progress Insights
    
    private func generateProgressInsights(from analytics: WorkspaceAnalytics) -> [String] {
        var insights: [String] = []
        let completion = analytics.completionAnalysis
        
        switch completion.completionLevel {
        case .justStarted:
            insights.append("🌱 This workspace is just getting started with \(Int(completion.overallCompletion * 100))% progress.")
        case .earlyProgress:
            insights.append("🚀 Good momentum! You're \(Int(completion.overallCompletion * 100))% complete with this workspace.")
        case .midProgress:
            insights.append("📈 Great progress! You're halfway there at \(Int(completion.overallCompletion * 100))% completion.")
        case .nearCompletion:
            insights.append("🎯 Almost there! Only \(Int((1 - completion.overallCompletion) * 100))% left to complete.")
        case .complete:
            insights.append("✅ Congratulations! This workspace is complete.")
        }
        
        if completion.criticalMissingCount > 0 {
            insights.append("⚠️ \(completion.criticalMissingCount) critical components are missing for completion.")
        }
        
        return insights
    }
    
    private func generateDetailedProgressInsights(from analytics: WorkspaceAnalytics) -> WorkspaceProgressInsights {
        let completion = analytics.completionAnalytics
        let trends = analytics.progressTrends
        
        return WorkspaceProgressInsights(
            completionLevel: completion.completionLevel,
            progressPercentage: completion.overallCompletion,
            momentum: convertTrendToMomentum(trends.momentum),
            recentActivity: trends.recentActivityLevel,
            estimatedTimeToCompletion: trends.estimatedDaysToCompletion,
            criticalBlockers: completion.criticalMissingCount,
            strengths: identifyProgressStrengths(from: analytics),
            improvements: identifyProgressImprovements(from: analytics)
        )
    }
    
    // MARK: - Timeline Insights
    
    private func generateTimelineInsights(from analytics: WorkspaceAnalytics) -> [String] {
        var insights: [String] = []
        let timeline = analytics.timelineAnalysis
        
        if timeline.hasRecentActivity {
            let daysSinceUpdate = Int(timeline.daysSinceLastUpdate)
            insights.append("📅 Last updated \(daysSinceUpdate) day\(daysSinceUpdate == 1 ? "" : "s") ago.")
        } else {
            insights.append("⏰ This workspace hasn't been updated recently. Consider adding new screenshots.")
        }
        
        if timeline.hasSignificantGaps {
            insights.append("📊 There are gaps in your timeline that could benefit from additional documentation.")
        }
        
        if timeline.milestoneCount > 0 {
            insights.append("🎯 \(timeline.milestoneCount) key milestone\(timeline.milestoneCount == 1 ? "" : "s") identified in your progress.")
        }
        
        return insights
    }
    
    private func generateDetailedTimelineInsights(from analytics: WorkspaceAnalytics) -> WorkspaceTimelineInsights {
        let timeline = analytics.timelineAnalysis
        
        return WorkspaceTimelineInsights(
            totalDuration: timeline.workspaceDuration,
            daysSinceLastUpdate: timeline.daysSinceLastUpdate,
            activityFrequency: timeline.averageActivityInterval,
            milestones: timeline.milestoneCount,
            gaps: timeline.hasSignificantGaps ? 1 : 0,
            consistencyScore: calculateTimelineConsistency(from: timeline),
            peakActivityPeriods: identifyPeakActivityPeriods(from: analytics),
            suggestedUpdateFrequency: calculateOptimalUpdateFrequency(from: timeline)
        )
    }
    
    // MARK: - Component Insights
    
    private func generateComponentInsights(from analytics: WorkspaceAnalytics) -> [String] {
        var insights: [String] = []
        let missing = analytics.missingComponentAnalysis
        
        if !missing.criticalMissing.isEmpty {
            insights.append("🔴 Critical missing: \(missing.criticalMissing.joined(separator: ", "))")
        }
        
        if !missing.recommendedAdditions.isEmpty && missing.criticalMissing.isEmpty {
            insights.append("💡 Consider adding: \(missing.recommendedAdditions.joined(separator: ", "))")
        }
        
        if missing.completionBlockers.count > 0 {
            insights.append("🚧 \(missing.completionBlockers.count) item\(missing.completionBlockers.count == 1 ? "" : "s") blocking completion.")
        }
        
        return insights
    }
    
    private func generateDetailedComponentInsights(from analytics: WorkspaceAnalytics) -> WorkspaceComponentInsights {
        let missing = analytics.missingComponentAnalysis
        
        return WorkspaceComponentInsights(
            criticalMissing: missing.criticalMissing,
            recommendedAdditions: missing.recommendedAdditions,
            completionBlockers: missing.completionBlockers,
            componentCompleteness: calculateComponentCompleteness(from: missing),
            prioritizedMissing: prioritizeMissingComponents(from: missing),
            componentSuggestions: generateComponentSuggestions(from: analytics)
        )
    }
    
    // MARK: - Action Insights
    
    private func generateActionInsights(from analytics: WorkspaceAnalytics) -> [String] {
        var insights: [String] = []
        let actions = analytics.actionRecommendations
        
        let highPriorityActions = actions.filter { $0.priority == .high }
        if !highPriorityActions.isEmpty {
            insights.append("⚡ \(highPriorityActions.count) high-priority action\(highPriorityActions.count == 1 ? "" : "s") available.")
        }
        
        let quickWins = actions.filter { $0.estimatedEffort == .quick }
        if !quickWins.isEmpty {
            insights.append("🎯 \(quickWins.count) quick win\(quickWins.count == 1 ? "" : "s") identified for immediate progress.")
        }
        
        return insights
    }
    
    // MARK: - Cross-Workspace Insights
    
    private func generateCrossWorkspaceInsightTexts(from insights: [CrossWorkspaceInsights]) -> [String] {
        var texts: [String] = []
        
        if !insights.isEmpty {
            texts.append("🔗 Related to \(insights.count) other workspace\(insights.count == 1 ? "" : "s").")
        }
        
        // Extract insights from the array
        for insight in insights {
            for insightText in insight.insights.prefix(1) {
                texts.append("💡 \(insightText)")
            }
        }
        
        // Add relationship type information
        let relationshipTypes = Set(insights.map { $0.relationshipType })
        if !relationshipTypes.isEmpty {
            let typeNames = relationshipTypes.map { $0.displayName }.joined(separator: ", ")
            texts.append("🔗 Relationships: \(typeNames)")
        }
        
        return texts
    }
    
    // MARK: - Advanced Analysis Helpers
    
    private func calculateWorkspaceMomentum(from analytics: WorkspaceAnalytics) -> WorkspaceMomentum {
        let trends = analytics.progressTrends
        let timeline = analytics.timelineAnalysis
        
        let momentumScore: Double
        switch trends.momentum {
        case .accelerating: momentumScore = 0.8 + (trends.recentActivityLevel * 0.2)
        case .steady: momentumScore = 0.5 + (trends.recentActivityLevel * 0.3)
        case .slowing: momentumScore = 0.3 - (trends.recentActivityLevel * 0.1)
        case .stalled: momentumScore = 0.1
        }
        
        return WorkspaceMomentum(
            score: max(0.0, min(1.0, momentumScore)),
            trend: convertTrendToMomentum(trends.momentum),
            velocity: trends.recentActivityLevel,
            consistency: timeline.hasRecentActivity ? 0.8 : 0.3,
            prediction: trends.estimatedDaysToCompletion > 0 ? .improving : .stable
        )
    }
    
    private func predictCompletion(from analytics: WorkspaceAnalytics) -> WorkspaceCompletionPrediction {
        let trends = analytics.progressTrends
        let completion = analytics.completionAnalytics
        
        let confidence: Double
        if trends.momentum == .accelerating && completion.overallCompletion > 0.5 {
            confidence = 0.9
        } else if trends.momentum == .steady {
            confidence = 0.7
        } else if trends.momentum == .slowing {
            confidence = 0.5
        } else {
            confidence = 0.3
        }
        
        return WorkspaceCompletionPrediction(
            estimatedDays: max(1, trends.estimatedDaysToCompletion),
            confidence: confidence,
            likelihood: completion.overallCompletion > 0.7 ? .high : completion.overallCompletion > 0.3 ? .medium : .low,
            blockers: analytics.missingComponentAnalysis.completionBlockers,
            accelerators: identifyCompletionAccelerators(from: analytics)
        )
    }
    
    private func identifyNextBestActions(from analytics: WorkspaceAnalytics) -> [ContentWorkspace.WorkspaceAction] {
        let actions = analytics.actionRecommendations
        
        // Prioritize high-impact, quick-effort actions
        return actions
            .filter { $0.priority == .high || $0.estimatedEffort == .quick }
            .sorted { action1, action2 in
                if action1.priority == action2.priority {
                    return action1.estimatedEffort.sortOrder < action2.estimatedEffort.sortOrder
                }
                return action1.priority.sortOrder < action2.priority.sortOrder
            }
            .prefix(3)
            .map { $0.action }
    }
    
    // MARK: - Helper Methods
    
    private func identifyProgressStrengths(from analytics: WorkspaceAnalytics) -> [String] {
        var strengths: [String] = []
        
        if analytics.progressTrends.momentum == .accelerating {
            strengths.append("Strong momentum")
        }
        
        if analytics.completionAnalytics.overallCompletion > 0.7 {
            strengths.append("High completion rate")
        }
        
        if analytics.timelineAnalysis.hasRecentActivity {
            strengths.append("Recent activity")
        }
        
        return strengths
    }
    
    private func identifyProgressImprovements(from analytics: WorkspaceAnalytics) -> [String] {
        var improvements: [String] = []
        
        if analytics.missingComponentAnalysis.criticalMissing.count > 0 {
            improvements.append("Address critical missing components")
        }
        
        if analytics.progressTrends.momentum == .stalled {
            improvements.append("Restart activity to build momentum")
        }
        
        if analytics.timelineAnalysis.hasSignificantGaps {
            improvements.append("Fill timeline gaps with documentation")
        }
        
        return improvements
    }
    
    private func calculateTimelineConsistency(from timeline: TimelineAnalysis) -> Double {
        // Simple consistency calculation based on activity patterns
        if timeline.hasRecentActivity && !timeline.hasSignificantGaps {
            return 0.9
        } else if timeline.hasRecentActivity || !timeline.hasSignificantGaps {
            return 0.6
        } else {
            return 0.3
        }
    }
    
    private func identifyPeakActivityPeriods(from analytics: WorkspaceAnalytics) -> [String] {
        // Placeholder for peak activity identification
        let timeline = analytics.timelineAnalysis
        
        if timeline.hasRecentActivity {
            return ["Recent period"]
        }
        
        return ["Initial creation period"]
    }
    
    private func calculateOptimalUpdateFrequency(from timeline: TimelineAnalysis) -> String {
        if timeline.averageActivityInterval <= 1.0 {
            return "Daily"
        } else if timeline.averageActivityInterval <= 7.0 {
            return "Weekly"
        } else {
            return "Monthly"
        }
    }
    
    private func calculateComponentCompleteness(from missing: MissingComponentAnalysis) -> Double {
        let totalPossible = missing.criticalMissing.count + missing.recommendedAdditions.count + 5 // Assume 5 base components
        let completed = max(0, totalPossible - missing.criticalMissing.count - missing.recommendedAdditions.count)
        return totalPossible > 0 ? Double(completed) / Double(totalPossible) : 1.0
    }
    
    private func prioritizeMissingComponents(from missing: MissingComponentAnalysis) -> [String] {
        // Prioritize critical missing components first
        var prioritized = missing.criticalMissing
        prioritized.append(contentsOf: missing.completionBlockers)
        prioritized.append(contentsOf: missing.recommendedAdditions.prefix(3))
        return Array(Set(prioritized)) // Remove duplicates
    }
    
    private func generateComponentSuggestions(from analytics: WorkspaceAnalytics) -> [String] {
        var suggestions: [String] = []
        let missing = analytics.missingComponentAnalysis
        
        for component in missing.criticalMissing.prefix(2) {
            suggestions.append("Add \(component) to unlock next milestone")
        }
        
        for component in missing.recommendedAdditions.prefix(1) {
            suggestions.append("Consider adding \(component) for completeness")
        }
        
        return suggestions
    }
    
    private func identifyCompletionAccelerators(from analytics: WorkspaceAnalytics) -> [String] {
        var accelerators: [String] = []
        
        let quickActions = analytics.actionRecommendations.filter { $0.estimatedEffort == .quick }
        for action in quickActions.prefix(2) {
            accelerators.append(action.action.displayName)
        }
        
        if analytics.progressTrends.momentum != .accelerating {
            accelerators.append("Increase update frequency")
        }
        
        return accelerators
    }
}

// MARK: - Supporting Data Structures

struct WorkspaceAdvancedInsights {
    let progressInsights: WorkspaceProgressInsights
    let timelineInsights: WorkspaceTimelineInsights
    let componentInsights: WorkspaceComponentInsights
    let crossWorkspaceInsights: [String]
    let actionRecommendations: [WorkspaceAnalyticsService.ActionRecommendation]
    let workspaceMomentum: WorkspaceMomentum
    let completionPrediction: WorkspaceCompletionPrediction
    let nextBestActions: [ContentWorkspace.WorkspaceAction]
}

struct WorkspaceProgressInsights {
    let completionLevel: WorkspaceAnalyticsService.CompletionAnalysis.CompletionLevel
    let progressPercentage: Double
    let momentum: ProgressMomentum
    let recentActivity: Double
    let estimatedTimeToCompletion: Int
    let criticalBlockers: Int
    let strengths: [String]
    let improvements: [String]
}

struct WorkspaceTimelineInsights {
    let totalDuration: TimeInterval
    let daysSinceLastUpdate: Double
    let activityFrequency: Double
    let milestones: Int
    let gaps: Int
    let consistencyScore: Double
    let peakActivityPeriods: [String]
    let suggestedUpdateFrequency: String
}

struct WorkspaceComponentInsights {
    let criticalMissing: [String]
    let recommendedAdditions: [String]
    let completionBlockers: [String]
    let componentCompleteness: Double
    let prioritizedMissing: [String]
    let componentSuggestions: [String]
}

struct WorkspaceMomentum {
    let score: Double // 0.0 to 1.0
    let trend: ProgressMomentum
    let velocity: Double
    let consistency: Double
    let prediction: MomentumPrediction
    
    enum MomentumPrediction {
        case improving, stable, declining
    }
}

struct WorkspaceCompletionPrediction {
    let estimatedDays: Int
    let confidence: Double // 0.0 to 1.0
    let likelihood: CompletionLikelihood
    let blockers: [String]
    let accelerators: [String]
    
    enum CompletionLikelihood {
        case high, medium, low
    }
}

// MARK: - Missing Type Definitions

enum ProgressMomentum {
    case accelerating
    case steady
    case slowing
    case stalled
    
    var displayName: String {
        switch self {
        case .accelerating: return "Accelerating"
        case .steady: return "Steady"
        case .slowing: return "Slowing"
        case .stalled: return "Stalled"
        }
    }
    
    var color: Color {
        switch self {
        case .accelerating: return .green
        case .steady: return .blue
        case .slowing: return .orange
        case .stalled: return .red
        }
    }
}

// MARK: - Extensions for Sorting

extension WorkspaceAnalyticsService.ActionRecommendation.Priority {
    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

extension WorkspaceAnalyticsService.ActionRecommendation.EstimatedEffort {
    var sortOrder: Int {
        switch self {
        case .quick: return 0
        case .moderate: return 1
        case .significant: return 2
        }
    }
}

// MARK: - Helper Functions

extension WorkspaceInsightsEngine {
    private func convertTrendToMomentum(_ trend: WorkspaceAnalyticsService.ProgressTrends.TrendDirection) -> ProgressMomentum {
        switch trend {
        case .accelerating: return .accelerating
        case .steady: return .steady
        case .slowing: return .slowing
        case .stalled: return .stalled
        }
    }
}
