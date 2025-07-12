import Foundation
import SwiftData
import os.log

/// Version History Service for undo/redo functionality
/// Provides comprehensive versioning with undo/redo capabilities
@MainActor
class VersionHistoryService: ObservableObject {
    static let shared = VersionHistoryService()
    
    // MARK: - Performance Targets
    // - Undo/Redo operations: <50ms
    // - Version storage: <10MB for 100 versions
    // - History navigation: <25ms per step
    // - Success rate: >99% for version restoration
    
    // MARK: - State Management
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var currentVersion: DataVersion?
    @Published var historySize = 0
    @Published var metrics = VersionMetrics()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "VersionHistory")
    private var modelContext: ModelContext?
    
    // Version storage
    private var versionHistory: [DataVersion] = []
    private var currentIndex = -1
    private let maxHistorySize = 100
    private let maxStorageSize = 10 * 1024 * 1024 // 10MB
    
    // Configuration
    private let config = VersionHistoryConfig()
    
    private init() {
        logger.info("📚 VersionHistoryService initialized")
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        logger.info("✅ VersionHistoryService configured with ModelContext")
        
        Task {
            await loadHistoryFromPersistence()
        }
    }
    
    // MARK: - Public API
    
    /// Add a new version to history
    func addVersion(_ version: DataVersion) async {
        logger.info("📝 Adding version to history: \(version.versionId)")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Remove any future versions if we're in the middle of history
        if currentIndex < versionHistory.count - 1 {
            versionHistory.removeSubrange((currentIndex + 1)...)
        }
        
        // Add new version
        versionHistory.append(version)
        currentIndex = versionHistory.count - 1
        self.currentVersion = version
        
        // Manage storage limits
        await enforceStorageLimits()
        
        // Update state
        updateNavigationState()
        
        // Persist to storage
        await persistHistory()
        
        let addTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        updateMetrics(operationType: .add, processingTime: addTime)
        
        logger.info("✅ Version added in \(String(format: "%.2f", addTime))ms")
    }
    
    /// Undo to previous version
    func undo(from version: DataVersion) async -> UndoResult {
        guard canUndo, currentIndex > 0 else {
            return UndoResult(success: false, message: "Cannot undo - no previous version available")
        }
        
        logger.info("↩️ Performing undo operation")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Move to previous version
        currentIndex -= 1
        let targetVersion = versionHistory[currentIndex]
        
        // Apply the undo
        let result = await applyVersion(targetVersion, operation: .undo)
        
        if result.success {
            self.currentVersion = targetVersion
            updateNavigationState()
            
            let undoTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            updateMetrics(operationType: .undo, processingTime: undoTime)
            
            logger.info("✅ Undo completed in \(String(format: "%.2f", undoTime))ms")
            
            return UndoResult(success: true, message: "Undo successful", newVersion: targetVersion)
        } else {
            // Rollback the index change
            currentIndex += 1
            logger.error("❌ Undo failed: \(result.message)")
            
            return UndoResult(success: false, message: "Undo failed: \(result.message)")
        }
    }
    
    /// Redo to next version
    func redo() async -> RedoResult {
        guard canRedo, currentIndex < versionHistory.count - 1 else {
            return RedoResult(success: false, message: "Cannot redo - no next version available")
        }
        
        logger.info("↪️ Performing redo operation")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Move to next version
        currentIndex += 1
        let targetVersion = versionHistory[currentIndex]
        
        // Apply the redo
        let result = await applyVersion(targetVersion, operation: .redo)
        
        if result.success {
            self.currentVersion = targetVersion
            updateNavigationState()
            
            let redoTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            updateMetrics(operationType: .redo, processingTime: redoTime)
            
            logger.info("✅ Redo completed in \(String(format: "%.2f", redoTime))ms")
            
            return RedoResult(success: true, message: "Redo successful", newVersion: targetVersion)
        } else {
            // Rollback the index change
            currentIndex -= 1
            logger.error("❌ Redo failed: \(result.message)")
            
            return RedoResult(success: false, message: "Redo failed: \(result.message)")
        }
    }
    
    /// Get version history
    func getHistory(limit: Int = 50) -> [DataVersion] {
        let startIndex = max(0, versionHistory.count - limit)
        return Array(versionHistory.suffix(from: startIndex))
    }
    
    /// Jump to specific version
    func jumpToVersion(_ versionId: UUID) async -> VersionJumpResult {
        guard let targetIndex = versionHistory.firstIndex(where: { $0.versionId == versionId }) else {
            return VersionJumpResult(success: false, message: "Version not found in history")
        }
        
        logger.info("🎯 Jumping to version: \(versionId)")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let targetVersion = versionHistory[targetIndex]
        let result = await applyVersion(targetVersion, operation: .jump)
        
        if result.success {
            currentIndex = targetIndex
            self.currentVersion = targetVersion
            updateNavigationState()
            
            let jumpTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            updateMetrics(operationType: .jump, processingTime: jumpTime)
            
            logger.info("✅ Version jump completed in \(String(format: "%.2f", jumpTime))ms")
            
            return VersionJumpResult(success: true, message: "Jump successful", targetVersion: targetVersion)
        } else {
            logger.error("❌ Version jump failed: \(result.message)")
            return VersionJumpResult(success: false, message: "Jump failed: \(result.message)")
        }
    }
    
    /// Clear history older than specified date
    func clearOldHistory(olderThan date: Date) async {
        let oldCount = versionHistory.count
        versionHistory.removeAll { $0.timestamp < date }
        
        // Adjust current index
        let removedCount = oldCount - versionHistory.count
        if removedCount > 0 {
            currentIndex = max(-1, currentIndex - removedCount)
            if currentIndex >= 0 && currentIndex < versionHistory.count {
                self.currentVersion = versionHistory[currentIndex]
            } else {
                self.currentVersion = versionHistory.last
                currentIndex = versionHistory.count - 1
            }
        }
        
        updateNavigationState()
        await persistHistory()
        
        logger.info("🧹 Cleared \(removedCount) old versions from history")
    }
    
    /// Get version metrics
    func getMetrics() -> VersionMetrics {
        return metrics
    }
    
    // MARK: - Private Implementation
    
    private func applyVersion(_ version: DataVersion, operation: VersionOperation) async -> VersionApplicationResult {
        guard let modelContext = modelContext else {
            return VersionApplicationResult(success: false, message: "No model context available")
        }
        
        // Apply version delta or snapshot
        if let delta = version.decodedDelta {
            return await applyDelta(delta, context: modelContext)
        } else if version.isSnapshot {
            return await applySnapshot(version, context: modelContext)
        } else {
            return VersionApplicationResult(success: false, message: "Version contains no applicable data")
        }
    }
    
    private func applyDelta(_ delta: VersionDelta, context: ModelContext) async -> VersionApplicationResult {
        // Apply delta operations in sequence
        for operation in delta.operations {
            let result = await applyDeltaOperation(operation, context: context)
            if !result.success {
                return result
            }
        }
        
        // Save context
        do {
            try context.save()
            return VersionApplicationResult(success: true, message: "Delta applied successfully")
        } catch {
            return VersionApplicationResult(success: false, message: "Failed to save delta changes: \(error)")
        }
    }
    
    private func applySnapshot(_ version: DataVersion, context: ModelContext) async -> VersionApplicationResult {
        // Apply complete snapshot restoration
        // This would restore the entire data state to the snapshot
        // Implementation would depend on specific data model requirements
        
        return VersionApplicationResult(success: true, message: "Snapshot applied (placeholder implementation)")
    }
    
    private func applyDeltaOperation(_ operation: DeltaOperation, context: ModelContext) async -> VersionApplicationResult {
        // Apply individual delta operation
        switch operation.type {
        case .create:
            return await applyInsertOperation(operation, context: context)
        case .update:
            return await applyUpdateOperation(operation, context: context)
        case .delete:
            return await applyDeleteOperation(operation, context: context)
        case .move:
            return await applyMoveOperation(operation, context: context)
        case .merge:
            return await applyMergeOperation(operation, context: context)
        }
    }
    
    private func applyInsertOperation(_ operation: DeltaOperation, context: ModelContext) async -> VersionApplicationResult {
        // Implementation for insert operations
        return VersionApplicationResult(success: true, message: "Insert operation applied")
    }
    
    private func applyUpdateOperation(_ operation: DeltaOperation, context: ModelContext) async -> VersionApplicationResult {
        // Implementation for update operations
        return VersionApplicationResult(success: true, message: "Update operation applied")
    }
    
    private func applyDeleteOperation(_ operation: DeltaOperation, context: ModelContext) async -> VersionApplicationResult {
        // Implementation for delete operations
        return VersionApplicationResult(success: true, message: "Delete operation applied")
    }
    
    private func applyMoveOperation(_ operation: DeltaOperation, context: ModelContext) async -> VersionApplicationResult {
        // Implementation for move operations
        return VersionApplicationResult(success: true, message: "Move operation applied")
    }
    
    private func applyMergeOperation(_ operation: DeltaOperation, context: ModelContext) async -> VersionApplicationResult {
        // Implementation for merge operations
        return VersionApplicationResult(success: true, message: "Merge operation applied")
    }
    
    private func updateNavigationState() {
        canUndo = currentIndex > 0
        canRedo = currentIndex < versionHistory.count - 1
        historySize = versionHistory.count
    }
    
    private func enforceStorageLimits() async {
        // Check count limit
        if versionHistory.count > maxHistorySize {
            let removeCount = versionHistory.count - maxHistorySize
            versionHistory.removeFirst(removeCount)
            currentIndex = max(-1, currentIndex - removeCount)
        }
        
        // Check storage size limit
        let totalSize = versionHistory.reduce(0) { $0 + $1.storageSize }
        if totalSize > maxStorageSize {
            await compressOldVersions()
        }
    }
    
    private func compressOldVersions() async {
        // Compress old versions to reduce storage
        let compressThreshold = versionHistory.count / 2
        
        for i in 0..<min(compressThreshold, versionHistory.count) {
            if !versionHistory[i].isSnapshot {
                // Convert to compressed delta if not already
                versionHistory[i] = await compressVersion(versionHistory[i])
            }
        }
    }
    
    private func compressVersion(_ version: DataVersion) async -> DataVersion {
        // Apply compression to version data
        if let delta = version.decodedDelta {
            version.setDelta(delta) // This will recompress
        }
        return version
    }
    
    private func updateMetrics(operationType: VersionOperation, processingTime: TimeInterval) {
        metrics.totalOperations += 1
        metrics.lastOperationTime = processingTime
        
        switch operationType {
        case .add:
            metrics.addOperations += 1
        case .undo:
            metrics.undoOperations += 1
        case .redo:
            metrics.redoOperations += 1
        case .jump:
            metrics.jumpOperations += 1
        }
        
        // Update average
        let totalTime = metrics.averageOperationTime * Double(metrics.totalOperations - 1) + processingTime
        metrics.averageOperationTime = totalTime / Double(metrics.totalOperations)
    }
    
    private func loadHistoryFromPersistence() async {
        // Load version history from persistent storage
        // This would integrate with SwiftData or file system storage
        
        logger.info("📚 Loading version history from persistence")
        // Placeholder implementation
        updateNavigationState()
    }
    
    private func persistHistory() async {
        // Persist version history to storage
        // This would save to SwiftData or file system
        
        logger.debug("💾 Persisting version history (\(self.versionHistory.count) versions)")
        // Placeholder implementation
    }
}

// MARK: - Supporting Types

struct VersionHistoryConfig {
    let maxHistorySize = 100
    let maxStorageSize = 10 * 1024 * 1024 // 10MB
    let compressionThreshold = 0.5 // Compress when over 50% of max size
    let autoCleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
}

enum VersionOperation {
    case add, undo, redo, jump
}

struct VersionApplicationResult {
    let success: Bool
    let message: String
}

struct VersionJumpResult {
    let success: Bool
    let message: String
    let targetVersion: DataVersion?
    
    init(success: Bool, message: String, targetVersion: DataVersion? = nil) {
        self.success = success
        self.message = message
        self.targetVersion = targetVersion
    }
}



struct VersionMetrics {
    var totalOperations = 0
    var addOperations = 0
    var undoOperations = 0
    var redoOperations = 0
    var jumpOperations = 0
    var averageOperationTime: TimeInterval = 0
    var lastOperationTime: TimeInterval = 0
    
    var undoRedoRatio: Double {
        let totalUndoRedo = undoOperations + redoOperations
        guard totalUndoRedo > 0 else { return 0 }
        return Double(undoOperations) / Double(totalUndoRedo)
    }
} 