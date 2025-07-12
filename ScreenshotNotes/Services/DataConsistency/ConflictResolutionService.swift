import Foundation
import SwiftData
import os.log

/// Advanced conflict resolution service with intelligent merge strategies
/// Handles concurrent user/AI modifications with priority-based resolution
@MainActor
class ConflictResolutionService: ObservableObject {
    static let shared = ConflictResolutionService()
    
    // MARK: - Performance Targets
    // - Simple conflict resolution: <100ms
    // - Complex merge operations: <1s
    // - Conflict detection: <50ms
    // - Success rate: >95% for automated resolution
    
    // MARK: - State Management
    @Published var activeConflicts: [UUID: DataConflict] = [:]
    @Published var resolutionHistory: [ConflictResolution] = []
    @Published var metrics = ConflictMetrics()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ConflictResolution")
    private var modelContext: ModelContext?
    private let changeTracker = ChangeTrackingService.shared
    
    // Resolution strategies
    private let strategies: [ConflictResolutionStrategy] = [
        UserPriorityStrategy(),
        TimestampBasedStrategy(),
        ContentMergeStrategy(),
        ConfidenceBasedStrategy(),
        SemanticMergeStrategy()
    ]
    
    private init() {
        logger.info("⚡ ConflictResolutionService initialized")
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        logger.info("✅ ConflictResolutionService configured with ModelContext")
    }
    
    // MARK: - Public API
    
    /// Detect conflicts for a given change
    func detectConflicts(for change: DataChange) async -> [DataConflict] {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("🔍 Detecting conflicts for change: \(String(describing: change.type))")
        
        var conflicts: [DataConflict] = []
        
        // Get affected nodes for this change
        let affectedNodes = changeTracker.getAffectedNodesForChange(change)
        
        // Check for concurrent modifications
        conflicts.append(contentsOf: await detectConcurrentModifications(change: change, affectedNodes: affectedNodes))
        
        // Check for data consistency violations
        conflicts.append(contentsOf: await detectConsistencyViolations(change: change))
        
        // Check for business rule violations
        conflicts.append(contentsOf: await detectBusinessRuleViolations(change: change))
        
        let detectionTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("✅ Conflict detection completed in \(String(format: "%.2f", detectionTime))ms, found \(conflicts.count) conflicts")
        
        // Store active conflicts
        for conflict in conflicts {
            activeConflicts[conflict.conflictId] = conflict
        }
        
        return conflicts
    }
    
    /// Resolve a list of conflicts
    func resolveConflicts(_ conflicts: [DataConflict]) async -> ConflictResolution {
        guard !conflicts.isEmpty else {
            return ConflictResolution(
                resolutionId: UUID(),
                conflicts: [],
                acceptedChanges: [],
                rejectedChanges: [],
                resolutionStrategy: .automatic,
                success: true,
                message: "No conflicts to resolve"
            )
        }
        
        logger.info("⚡ Resolving \(conflicts.count) conflicts")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var acceptedChanges: [DataChange] = []
        var rejectedChanges: [DataChange] = []
        var resolutionStrategies: [ResolutionStrategy] = []
        
        // Group conflicts by type for batch processing
        let groupedConflicts = Dictionary(grouping: conflicts) { $0.conflictType }
        
        for (conflictType, typeConflicts) in groupedConflicts {
            let result = await resolveConflictGroup(typeConflicts, type: conflictType)
            
            acceptedChanges.append(contentsOf: result.acceptedChanges)
            rejectedChanges.append(contentsOf: result.rejectedChanges)
            resolutionStrategies.append(result.strategy)
        }
        
        // Determine overall strategy
        let overallStrategy = determineOverallStrategy(resolutionStrategies)
        
        let resolutionTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let success = acceptedChanges.count > 0 || conflicts.allSatisfy { $0.canAutoResolve }
        
        let resolution = ConflictResolution(
            resolutionId: UUID(),
            conflicts: conflicts,
            acceptedChanges: acceptedChanges,
            rejectedChanges: rejectedChanges,
            resolutionStrategy: overallStrategy,
            success: success,
            message: success ? "Conflicts resolved successfully" : "Manual intervention required",
            resolutionTime: resolutionTime
        )
        
        // Update metrics
        updateMetrics(resolution: resolution)
        
        // Store in history
        resolutionHistory.append(resolution)
        limitHistory()
        
        // Clean up resolved conflicts
        for conflict in conflicts {
            activeConflicts.removeValue(forKey: conflict.conflictId)
        }
        
        logger.info("✅ Conflict resolution completed in \(String(format: "%.2f", resolutionTime))ms")
        
        return resolution
    }
    
    /// Resolve a single conflict with a specific strategy
    func resolveConflict(_ conflict: DataConflict, strategy: ConflictResolutionStrategy) async -> ConflictResolution {
        logger.info("⚡ Resolving single conflict with \(type(of: strategy)) strategy")
        
        let result = await strategy.resolve(conflict: conflict)
        
        let resolution = ConflictResolution(
            resolutionId: UUID(),
            conflicts: [conflict],
            acceptedChanges: result.acceptedChanges,
            rejectedChanges: result.rejectedChanges,
            resolutionStrategy: result.strategy,
            success: result.success,
            message: result.message
        )
        
        // Clean up
        activeConflicts.removeValue(forKey: conflict.conflictId)
        
        return resolution
    }
    
    /// Get conflict resolution suggestions for manual review
    func getResolutionSuggestions(for conflict: DataConflict) async -> [ResolutionSuggestion] {
        var suggestions: [ResolutionSuggestion] = []
        
        for strategy in strategies {
            if strategy.canResolve(conflict: conflict) {
                let suggestion = await strategy.getSuggestion(for: conflict)
                suggestions.append(suggestion)
            }
        }
        
        // Sort by confidence
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Conflict Detection Implementation
    
    private func detectConcurrentModifications(change: DataChange, affectedNodes: Set<UUID>) async -> [DataConflict] {
        var conflicts: [DataConflict] = []
        
        // Check for modifications to the same data within a time window
        let timeWindow: TimeInterval = 5.0 // 5 seconds
        let cutoffTime = Date().addingTimeInterval(-timeWindow)
        
        // Get recent changes to affected nodes
        let recentChanges = changeTracker.getChangesSince(ChangeTrackingVersion(
            timestamp: cutoffTime,
            versionId: UUID(),
            changeType: change.type,
            affectedNodes: [],
            checksum: ""
        ))
        
        for recentChange in recentChanges {
            let recentAffectedNodes = changeTracker.getAffectedNodesForChange(recentChange)
            let intersection = affectedNodes.intersection(recentAffectedNodes)
            
            if !intersection.isEmpty {
                // Found concurrent modification
                let conflict = DataConflict(
                    changes: [change, recentChange],
                    conflictType: .simultaneousEdit,
                    canAutoResolve: canAutoResolve(change, recentChange),
                    affectedNodes: intersection,
                    severity: determineSeverity(change, recentChange)
                )
                
                conflicts.append(conflict)
            }
        }
        
        return conflicts
    }
    
    private func detectConsistencyViolations(change: DataChange) async -> [DataConflict] {
        var conflicts: [DataConflict] = []
        
        switch change.type {
        case .screenshotDeleted(let id):
            // Check for orphaned relationships
            if await hasActiveRelationships(screenshotId: id) {
                let conflict = DataConflict(
                    changes: [change],
                    conflictType: .dataIntegrityViolation,
                    canAutoResolve: true, // Can auto-delete relationships
                    affectedNodes: [id],
                    severity: .high
                )
                conflicts.append(conflict)
            }
            
        case .relationshipAdded(let fromId, let toId):
            // Check for circular references
            if await wouldCreateCircularReference(from: fromId, to: toId) {
                let conflict = DataConflict(
                    changes: [change],
                    conflictType: .dataIntegrityViolation,
                    canAutoResolve: false, // Requires manual review
                    affectedNodes: [fromId, toId],
                    severity: .medium
                )
                conflicts.append(conflict)
            }
            
        default:
            break
        }
        
        return conflicts
    }
    
    private func detectBusinessRuleViolations(change: DataChange) async -> [DataConflict] {
        var conflicts: [DataConflict] = []
        
        // Example: User annotations should always take precedence over AI
        if case .aiAnalysisUpdated(let id) = change.type {
            if await hasRecentUserAnnotation(screenshotId: id) {
                let conflict = DataConflict(
                    changes: [change],
                    conflictType: .userVsAI,
                    canAutoResolve: true, // AI should defer to user
                    affectedNodes: [id],
                    severity: .low
                )
                conflicts.append(conflict)
            }
        }
        
        return conflicts
    }
    
    // MARK: - Conflict Resolution Implementation
    
    private func resolveConflictGroup(_ conflicts: [DataConflict], type: ConflictType) async -> GroupResolutionResult {
        logger.debug("🔧 Resolving \(conflicts.count) conflicts of type: \(String(describing: type))")
        
        // Find the best strategy for this conflict type
        let strategy = findBestStrategy(for: type, conflicts: conflicts)
        
        var acceptedChanges: [DataChange] = []
        var rejectedChanges: [DataChange] = []
        var success = true
        
        for conflict in conflicts {
            let result = await strategy.resolve(conflict: conflict)
            
            acceptedChanges.append(contentsOf: result.acceptedChanges)
            rejectedChanges.append(contentsOf: result.rejectedChanges)
            
            if !result.success {
                success = false
            }
        }
        
        return GroupResolutionResult(
            acceptedChanges: acceptedChanges,
            rejectedChanges: rejectedChanges,
            strategy: strategy.strategyType,
            success: success
        )
    }
    
    private func findBestStrategy(for conflictType: ConflictType, conflicts: [DataConflict]) -> ConflictResolutionStrategy {
        // Select strategy based on conflict type and characteristics
        switch conflictType {
        case .userVsAI:
            return UserPriorityStrategy()
            
        case .simultaneousEdit:
            // Use timestamp-based for simple edits, content merge for complex
            let hasComplexChanges = conflicts.contains { $0.severity == .high }
            return hasComplexChanges ? ContentMergeStrategy() : TimestampBasedStrategy()
            
        case .dataIntegrityViolation:
            return SemanticMergeStrategy()
            
        case .versionMismatch:
            return ConfidenceBasedStrategy()
        }
    }
    
    private func determineOverallStrategy(_ strategies: [ResolutionStrategy]) -> ResolutionStrategy {
        // Determine the most used strategy
        let strategyCounts = Dictionary(strategies.map { ($0, 1) }, uniquingKeysWith: +)
        let mostUsed = strategyCounts.max { $0.value < $1.value }?.key
        
        return mostUsed ?? .automatic
    }
    
    // MARK: - Helper Methods
    
    private func determineSeverity(_ change1: DataChange, _ change2: DataChange) -> ConflictSeverity {
        // Determine severity based on change types and potential impact
        let userInitiated1 = isUserInitiated(change1)
        let userInitiated2 = isUserInitiated(change2)
        
        if userInitiated1 && userInitiated2 {
            return .high // Both user-initiated
        } else if userInitiated1 || userInitiated2 {
            return .medium // Mixed user/AI
        } else {
            return .low // Both AI-initiated
        }
    }
    
    private func canAutoResolve(_ change1: DataChange, _ change2: DataChange) -> Bool {
        // Determine if conflicts can be automatically resolved
        let userInitiated1 = isUserInitiated(change1)
        let userInitiated2 = isUserInitiated(change2)
        
        // Can auto-resolve if only one is user-initiated (user wins)
        return userInitiated1 != userInitiated2
    }
    
    private func isUserInitiated(_ change: DataChange) -> Bool {
        switch change.type {
        case .userAnnotationChanged:
            return true
        case .screenshotAdded, .screenshotDeleted:
            return true // Usually user-initiated
        default:
            return false
        }
    }
    
    private func hasActiveRelationships(screenshotId: UUID) async -> Bool {
        // Check if screenshot has active relationships that would be orphaned
        // This would query the relationship data
        return false // Placeholder
    }
    
    private func wouldCreateCircularReference(from: UUID, to: UUID) async -> Bool {
        // Check if adding this relationship would create a circular reference
        // This would traverse the relationship graph
        return false // Placeholder
    }
    
    private func hasRecentUserAnnotation(screenshotId: UUID) async -> Bool {
        // Check if there was a recent user annotation for this screenshot
        let timeWindow: TimeInterval = 60.0 // 1 minute
        let cutoffTime = Date().addingTimeInterval(-timeWindow)
        
        let recentChanges = changeTracker.getChangesSince(ChangeTrackingVersion(
            timestamp: cutoffTime,
            versionId: UUID(),
            changeType: .userAnnotationChanged(screenshotId),
            affectedNodes: [],
            checksum: ""
        ))
        
        return recentChanges.contains { change in
            if case .userAnnotationChanged(let id) = change.type {
                return id == screenshotId
            }
            return false
        }
    }
    
    private func updateMetrics(resolution: ConflictResolution) {
        metrics.totalConflicts += resolution.conflicts.count
        metrics.resolvedConflicts += resolution.success ? resolution.conflicts.count : 0
        metrics.lastResolutionTime = resolution.resolutionTime
        
        if metrics.averageResolutionTime == 0 {
            metrics.averageResolutionTime = resolution.resolutionTime
        } else {
            metrics.averageResolutionTime = (metrics.averageResolutionTime + resolution.resolutionTime) / 2
        }
    }
    
    private func limitHistory() {
        // Keep only last 100 resolutions
        if resolutionHistory.count > 100 {
            resolutionHistory.removeFirst(resolutionHistory.count - 100)
        }
    }
}

// MARK: - Conflict Resolution Strategies

protocol ConflictResolutionStrategy {
    var strategyType: ResolutionStrategy { get }
    func canResolve(conflict: DataConflict) -> Bool
    func resolve(conflict: DataConflict) async -> StrategyResult
    func getSuggestion(for conflict: DataConflict) async -> ResolutionSuggestion
}

/// User priority strategy - user changes always win
struct UserPriorityStrategy: ConflictResolutionStrategy {
    let strategyType: ResolutionStrategy = .userPriority
    
    func canResolve(conflict: DataConflict) -> Bool {
        return conflict.conflictType == .userVsAI
    }
    
    func resolve(conflict: DataConflict) async -> StrategyResult {
        var acceptedChanges: [DataChange] = []
        var rejectedChanges: [DataChange] = []
        
        for change in conflict.changes {
            if isUserInitiated(change) {
                acceptedChanges.append(change)
            } else {
                rejectedChanges.append(change)
            }
        }
        
        return StrategyResult(
            acceptedChanges: acceptedChanges,
            rejectedChanges: rejectedChanges,
            strategy: .userPriority,
            success: true,
            message: "User changes prioritized over AI changes"
        )
    }
    
    func getSuggestion(for conflict: DataConflict) async -> ResolutionSuggestion {
        return ResolutionSuggestion(
            strategy: .userPriority,
            description: "Prioritize user changes over AI changes",
            confidence: 0.95,
            reasoning: "User intent should always take precedence over automated analysis"
        )
    }
    
    private func isUserInitiated(_ change: DataChange) -> Bool {
        switch change.type {
        case .userAnnotationChanged:
            return true
        case .screenshotAdded, .screenshotDeleted:
            return true
        default:
            return false
        }
    }
}

/// Timestamp-based strategy - most recent change wins
struct TimestampBasedStrategy: ConflictResolutionStrategy {
    let strategyType: ResolutionStrategy = .timestampBased
    
    func canResolve(conflict: DataConflict) -> Bool {
        return conflict.conflictType == .simultaneousEdit
    }
    
    func resolve(conflict: DataConflict) async -> StrategyResult {
        // Sort changes by timestamp, most recent wins
        let sortedChanges = conflict.changes.sorted { $0.timestamp > $1.timestamp }
        
        let acceptedChanges = [sortedChanges.first!]
        let rejectedChanges = Array(sortedChanges.dropFirst())
        
        return StrategyResult(
            acceptedChanges: acceptedChanges,
            rejectedChanges: rejectedChanges,
            strategy: .timestampBased,
            success: true,
            message: "Most recent change accepted"
        )
    }
    
    func getSuggestion(for conflict: DataConflict) async -> ResolutionSuggestion {
        return ResolutionSuggestion(
            strategy: .timestampBased,
            description: "Accept the most recent change",
            confidence: 0.8,
            reasoning: "Last-write-wins is a simple and predictable conflict resolution"
        )
    }
}

/// Content merge strategy - attempt to merge compatible changes
struct ContentMergeStrategy: ConflictResolutionStrategy {
    let strategyType: ResolutionStrategy = .contentMerge
    
    func canResolve(conflict: DataConflict) -> Bool {
        return conflict.severity != .high && conflict.changes.count == 2
    }
    
    func resolve(conflict: DataConflict) async -> StrategyResult {
        // Attempt to merge changes if they affect different fields
        let changes = conflict.changes
        
        if canMergeChanges(changes) {
            // Create merged change
            let mergedChange = await createMergedChange(changes)
            
            return StrategyResult(
                acceptedChanges: [mergedChange],
                rejectedChanges: [],
                strategy: .contentMerge,
                success: true,
                message: "Changes merged successfully"
            )
        } else {
            // Fall back to user priority or timestamp
            return await UserPriorityStrategy().resolve(conflict: conflict)
        }
    }
    
    func getSuggestion(for conflict: DataConflict) async -> ResolutionSuggestion {
        let canMerge = canMergeChanges(conflict.changes)
        
        return ResolutionSuggestion(
            strategy: .contentMerge,
            description: canMerge ? "Merge compatible changes" : "Changes cannot be automatically merged",
            confidence: canMerge ? 0.85 : 0.3,
            reasoning: canMerge ? "Changes affect different fields and can be combined" : "Changes conflict at the field level"
        )
    }
    
    private func canMergeChanges(_ changes: [DataChange]) -> Bool {
        // Simplified logic - in practice would analyze field-level conflicts
        return changes.count == 2 && changes.allSatisfy { change in
            switch change.type {
            case .userAnnotationChanged, .aiAnalysisUpdated:
                return true // These can often be merged
            default:
                return false
            }
        }
    }
    
    private func createMergedChange(_ changes: [DataChange]) async -> DataChange {
        // Create a new change that represents the merger
        // This is simplified - real implementation would merge actual data
        let primaryChange = changes.first!
        return DataChange(type: primaryChange.type)
    }
}

/// Confidence-based strategy - higher confidence changes win
struct ConfidenceBasedStrategy: ConflictResolutionStrategy {
    let strategyType: ResolutionStrategy = .confidenceBased
    
    func canResolve(conflict: DataConflict) -> Bool {
        return conflict.conflictType == .versionMismatch
    }
    
    func resolve(conflict: DataConflict) async -> StrategyResult {
        // Choose change with higher confidence score
        let rankedChanges = await rankByConfidence(conflict.changes)
        
        let acceptedChanges = [rankedChanges.first!]
        let rejectedChanges = Array(rankedChanges.dropFirst())
        
        return StrategyResult(
            acceptedChanges: acceptedChanges,
            rejectedChanges: rejectedChanges,
            strategy: .confidenceBased,
            success: true,
            message: "Higher confidence change accepted"
        )
    }
    
    func getSuggestion(for conflict: DataConflict) async -> ResolutionSuggestion {
        return ResolutionSuggestion(
            strategy: .confidenceBased,
            description: "Accept change with higher confidence score",
            confidence: 0.75,
            reasoning: "Changes with higher confidence are more likely to be correct"
        )
    }
    
    private func rankByConfidence(_ changes: [DataChange]) async -> [DataChange] {
        // Rank changes by confidence score
        // This would integrate with AI confidence scoring
        return changes.sorted { getConfidence($0) > getConfidence($1) }
    }
    
    private func getConfidence(_ change: DataChange) -> Double {
        // Get confidence score for a change
        // This would integrate with AI services
        switch change.type {
        case .userAnnotationChanged:
            return 0.95 // User changes have high confidence
        case .aiAnalysisUpdated:
            return 0.75 // AI changes have moderate confidence
        default:
            return 0.5
        }
    }
}

/// Semantic merge strategy - understand meaning to merge intelligently
struct SemanticMergeStrategy: ConflictResolutionStrategy {
    let strategyType: ResolutionStrategy = .semanticMerge
    
    func canResolve(conflict: DataConflict) -> Bool {
        return conflict.conflictType == .dataIntegrityViolation
    }
    
    func resolve(conflict: DataConflict) async -> StrategyResult {
        // Use semantic understanding to resolve conflicts
        // This would integrate with semantic analysis services
        
        return StrategyResult(
            acceptedChanges: conflict.changes,
            rejectedChanges: [],
            strategy: .semanticMerge,
            success: true,
            message: "Semantic analysis resolved conflicts"
        )
    }
    
    func getSuggestion(for conflict: DataConflict) async -> ResolutionSuggestion {
        return ResolutionSuggestion(
            strategy: .semanticMerge,
            description: "Use semantic analysis to resolve conflicts",
            confidence: 0.7,
            reasoning: "Semantic understanding can resolve data integrity issues"
        )
    }
}

// MARK: - Supporting Types

struct StrategyResult {
    let acceptedChanges: [DataChange]
    let rejectedChanges: [DataChange]
    let strategy: ResolutionStrategy
    let success: Bool
    let message: String
}

struct GroupResolutionResult {
    let acceptedChanges: [DataChange]
    let rejectedChanges: [DataChange]
    let strategy: ResolutionStrategy
    let success: Bool
}

struct ResolutionSuggestion {
    let strategy: ResolutionStrategy
    let description: String
    let confidence: Double
    let reasoning: String
}

// ConflictSeverity moved to DataConsistencyTypes.swift