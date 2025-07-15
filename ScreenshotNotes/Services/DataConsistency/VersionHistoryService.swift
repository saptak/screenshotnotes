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
        guard let snapshotData = version.snapshotData else {
            logger.error("❌ No snapshot data available for version \(version.versionId)")
            return VersionApplicationResult(success: false, message: "No snapshot data available")
        }
        
        logger.info("📸 Applying snapshot version \(version.versionId)")
        
        do {
            // Decode the snapshot data
            let decoder = JSONDecoder()
            let snapshots = try decoder.decode([ScreenshotSnapshot].self, from: snapshotData)
            
            // Begin transaction for atomic operation
            try context.transaction {
                // Get all current screenshots to compare with snapshot
                let currentScreenshots = try context.fetch(FetchDescriptor<Screenshot>())
                let currentIds = Set(currentScreenshots.map { $0.id })
                let snapshotIds = Set(snapshots.map { $0.id })
                
                // Delete screenshots that shouldn't exist in the snapshot
                let toDelete = currentIds.subtracting(snapshotIds)
                for id in toDelete {
                    if let screenshot = currentScreenshots.first(where: { $0.id == id }) {
                        context.delete(screenshot)
                        logger.debug("🗑️ Deleted screenshot \(id) not in snapshot")
                    }
                }
                
                // Update or create screenshots from snapshot
                for snapshotItem in snapshots {
                    if let existingScreenshot = currentScreenshots.first(where: { $0.id == snapshotItem.id }) {
                        // Update existing screenshot
                        existingScreenshot.timestamp = snapshotItem.timestamp
                        existingScreenshot.extractedText = snapshotItem.extractedText
                        // needsOCR is a computed property in Screenshot model
                        // needsVisionAnalysis is a computed property in Screenshot model
                        // needsSemanticAnalysis is a computed property in Screenshot model
                        existingScreenshot.userTags = snapshotItem.tags
                        existingScreenshot.isFavorite = snapshotItem.isFavorite
                        existingScreenshot.userNotes = snapshotItem.userNotes
                        logger.debug("✏️ Updated screenshot \(snapshotItem.id) from snapshot")
                    } else {
                        // Create new screenshot if it doesn't exist
                        let newScreenshot = Screenshot(
                            imageData: Data(), // Image data would need to be restored separately
                            filename: "snapshot_\(snapshotItem.id.uuidString.prefix(8)).png",
                            timestamp: snapshotItem.timestamp
                        )
                        newScreenshot.id = snapshotItem.id
                        newScreenshot.extractedText = snapshotItem.extractedText
                        // needsOCR is a computed property in Screenshot model
                        // needsVisionAnalysis is a computed property in Screenshot model
                        // needsSemanticAnalysis is a computed property in Screenshot model
                        newScreenshot.userTags = snapshotItem.tags
                        newScreenshot.isFavorite = snapshotItem.isFavorite
                        newScreenshot.userNotes = snapshotItem.userNotes
                        context.insert(newScreenshot)
                        logger.debug("➕ Created screenshot \(snapshotItem.id) from snapshot")
                    }
                }
                
                // Save the context
                try context.save()
            }
            
            logger.info("✅ Snapshot applied successfully with \(snapshots.count) screenshots")
            
            return VersionApplicationResult(
                success: true, 
                message: "Snapshot applied: \(snapshots.count) screenshots restored"
            )
        } catch {
            logger.error("❌ Failed to apply snapshot: \(error.localizedDescription)")
            return VersionApplicationResult(
                success: false, 
                message: "Failed to apply snapshot: \(error.localizedDescription)"
            )
        }
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
        guard let insertData = operation.data else {
            return VersionApplicationResult(success: false, message: "No insert data provided")
        }
        
        do {
            // Decode the screenshot data to insert
            let decoder = JSONDecoder()
            let screenshotSnapshot = try decoder.decode(ScreenshotSnapshot.self, from: insertData)
            
            // Create new screenshot from snapshot
            let newScreenshot = Screenshot(
                imageData: Data(), // Image data would need to be handled separately
                filename: "restored_\(screenshotSnapshot.id.uuidString.prefix(8)).png",
                timestamp: screenshotSnapshot.timestamp
            )
            newScreenshot.id = screenshotSnapshot.id
            
            // Apply snapshot properties
            newScreenshot.extractedText = screenshotSnapshot.extractedText
            // needsOCR is a computed property in Screenshot model
            // needsVisionAnalysis is a computed property in Screenshot model
            // needsSemanticAnalysis is a computed property in Screenshot model
            newScreenshot.userTags = screenshotSnapshot.tags
            newScreenshot.isFavorite = screenshotSnapshot.isFavorite
            newScreenshot.userNotes = screenshotSnapshot.userNotes
            
            // Insert into context
            context.insert(newScreenshot)
            
            logger.debug("➕ Inserted screenshot \(screenshotSnapshot.id) via delta operation")
            return VersionApplicationResult(success: true, message: "Screenshot inserted successfully")
            
        } catch {
            logger.error("❌ Failed to apply insert operation: \(error.localizedDescription)")
            return VersionApplicationResult(success: false, message: "Insert operation failed: \(error.localizedDescription)")
        }
    }
    
    private func applyUpdateOperation(_ operation: DeltaOperation, context: ModelContext) async -> VersionApplicationResult {
        // Implementation for update operations
        let targetId = operation.targetId
        guard let updateData = operation.newValue?.data(using: .utf8) else {
            return VersionApplicationResult(success: false, message: "Incomplete update operation data")
        }
        
        do {
            // Find the screenshot to update
            let fetchDescriptor = FetchDescriptor<Screenshot>(predicate: #Predicate { $0.id == targetId })
            let screenshots = try context.fetch(fetchDescriptor)
            
            guard let screenshot = screenshots.first else {
                return VersionApplicationResult(success: false, message: "Screenshot not found for update: \(targetId)")
            }
            
            // Decode the update data
            let decoder = JSONDecoder()
            let screenshotSnapshot = try decoder.decode(ScreenshotSnapshot.self, from: updateData)
            
            // Apply updates
            screenshot.timestamp = screenshotSnapshot.timestamp
            screenshot.extractedText = screenshotSnapshot.extractedText
            // needsOCR is a computed property in Screenshot model
            // needsVisionAnalysis is a computed property in Screenshot model
            // needsSemanticAnalysis is a computed property in Screenshot model
            screenshot.userTags = screenshotSnapshot.tags
            screenshot.isFavorite = screenshotSnapshot.isFavorite
            screenshot.userNotes = screenshotSnapshot.userNotes
            
            logger.debug("✏️ Updated screenshot \(targetId) via delta operation")
            return VersionApplicationResult(success: true, message: "Screenshot updated successfully")
            
        } catch {
            logger.error("❌ Failed to apply update operation: \(error.localizedDescription)")
            return VersionApplicationResult(success: false, message: "Update operation failed: \(error.localizedDescription)")
        }
    }
    
    private func applyDeleteOperation(_ operation: DeltaOperation, context: ModelContext) async -> VersionApplicationResult {
        // Implementation for delete operations
        let targetId = operation.targetId
        guard targetId != UUID(uuidString: "00000000-0000-0000-0000-000000000000") else {
            return VersionApplicationResult(success: false, message: "No target ID provided for delete operation")
        }
        
        do {
            // Find the screenshot to delete
            let fetchDescriptor = FetchDescriptor<Screenshot>(predicate: #Predicate { $0.id == targetId })
            let screenshots = try context.fetch(fetchDescriptor)
            
            guard let screenshot = screenshots.first else {
                logger.warning("⚠️ Screenshot \(targetId) not found for deletion (may already be deleted)")
                return VersionApplicationResult(success: true, message: "Screenshot already deleted")
            }
            
            // Delete the screenshot
            context.delete(screenshot)
            
            logger.debug("🗑️ Deleted screenshot \(targetId) via delta operation")
            return VersionApplicationResult(success: true, message: "Screenshot deleted successfully")
            
        } catch {
            logger.error("❌ Failed to apply delete operation: \(error.localizedDescription)")
            return VersionApplicationResult(success: false, message: "Delete operation failed: \(error.localizedDescription)")
        }
    }
    
    private func applyMoveOperation(_ operation: DeltaOperation, context: ModelContext) async -> VersionApplicationResult {
        // Implementation for move operations (reordering, folder changes, etc.)
        let targetId = operation.targetId
        guard let moveData = operation.newValue?.data(using: .utf8) else {
            return VersionApplicationResult(success: false, message: "Incomplete move operation data")
        }
        
        do {
            // Find the screenshot to move
            let fetchDescriptor = FetchDescriptor<Screenshot>(predicate: #Predicate { $0.id == targetId })
            let screenshots = try context.fetch(fetchDescriptor)
            
            guard let screenshot = screenshots.first else {
                return VersionApplicationResult(success: false, message: "Screenshot not found for move: \(targetId)")
            }
            
            // Decode move parameters (position, tags, etc.)
            if let moveParams = try? JSONSerialization.jsonObject(with: moveData) as? [String: Any] {
                
                // Apply move operations based on parameters
                if let newTags = moveParams["tags"] as? [String] {
                    screenshot.userTags = newTags
                }
                
                if let newTimestamp = moveParams["timestamp"] as? TimeInterval {
                    screenshot.timestamp = Date(timeIntervalSince1970: newTimestamp)
                }
                
                logger.debug("🔄 Moved screenshot \(targetId) via delta operation")
                return VersionApplicationResult(success: true, message: "Screenshot moved successfully")
            }
            
            return VersionApplicationResult(success: false, message: "Invalid move operation parameters")
            
        } catch {
            logger.error("❌ Failed to apply move operation: \(error.localizedDescription)")
            return VersionApplicationResult(success: false, message: "Move operation failed: \(error.localizedDescription)")
        }
    }
    
    private func applyMergeOperation(_ operation: DeltaOperation, context: ModelContext) async -> VersionApplicationResult {
        // Implementation for merge operations (combining screenshots, merging tags, etc.)
        let targetId = operation.targetId
        guard let mergeData = operation.newValue?.data(using: .utf8) else {
            return VersionApplicationResult(success: false, message: "Incomplete merge operation data")
        }
        
        do {
            // Find the target screenshot
            let fetchDescriptor = FetchDescriptor<Screenshot>(predicate: #Predicate { $0.id == targetId })
            let screenshots = try context.fetch(fetchDescriptor)
            
            guard let targetScreenshot = screenshots.first else {
                return VersionApplicationResult(success: false, message: "Target screenshot not found for merge: \(targetId)")
            }
            
            // Decode merge parameters
            if let mergeParams = try? JSONSerialization.jsonObject(with: mergeData) as? [String: Any] {
                
                // Merge tags
                if let additionalTags = mergeParams["additionalTags"] as? [String] {
                    let currentTags = Set(targetScreenshot.userTags ?? [])
                    let newTags = Set(additionalTags)
                    targetScreenshot.userTags = Array(currentTags.union(newTags)).sorted()
                }
                
                // Merge extracted text
                if let additionalText = mergeParams["additionalText"] as? String {
                    let currentText = targetScreenshot.extractedText ?? ""
                    targetScreenshot.extractedText = currentText.isEmpty ? additionalText : "\(currentText)\n\(additionalText)"
                }
                
                // Merge user notes
                if let additionalNotes = mergeParams["additionalNotes"] as? String {
                    let currentNotes = targetScreenshot.userNotes ?? ""
                    targetScreenshot.userNotes = currentNotes.isEmpty ? additionalNotes : "\(currentNotes)\n\(additionalNotes)"
                }
                
                logger.debug("🔗 Merged data into screenshot \(targetId) via delta operation")
                return VersionApplicationResult(success: true, message: "Screenshots merged successfully")
            }
            
            return VersionApplicationResult(success: false, message: "Invalid merge operation parameters")
            
        } catch {
            logger.error("❌ Failed to apply merge operation: \(error.localizedDescription)")
            return VersionApplicationResult(success: false, message: "Merge operation failed: \(error.localizedDescription)")
        }
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
        logger.info("📚 Loading version history from persistence")
        
        do {
            // Get the Documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let historyURL = documentsDirectory.appendingPathComponent("version_history.json")
            
            // Check if history file exists
            guard FileManager.default.fileExists(atPath: historyURL.path) else {
                logger.info("📂 No existing version history file found, starting fresh")
                updateNavigationState()
                return
            }
            
            // Load and decode history
            let historyData = try Data(contentsOf: historyURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let persistedHistory = try decoder.decode(PersistedVersionHistory.self, from: historyData)
            
            // Note: For now, we'll start with an empty history since we can't fully restore DataVersion objects
            // This is a simplified implementation - a full implementation would require 
            // storing more detailed version information
            await MainActor.run {
                self.versionHistory = [] // Start fresh for now
                self.currentIndex = -1
                self.currentVersion = nil
                updateNavigationState()
                
                logger.info("📚 Loaded version history metadata: \(persistedHistory.versions.count) versions recorded")
            }
            
            logger.info("✅ Loaded \(self.versionHistory.count) versions from persistence, current index: \(self.currentIndex)")
            
            // Clean up old history to maintain storage limits
            await enforceStorageLimits()
            
        } catch {
            logger.error("❌ Failed to load version history: \(error.localizedDescription)")
            
            // Reset to clean state on error
            await MainActor.run {
                self.versionHistory = []
                self.currentIndex = -1
                self.currentVersion = nil
                updateNavigationState()
            }
        }
    }
    
    private func persistHistory() async {
        // Persist version history to storage
        logger.debug("💾 Persisting version history (\(self.versionHistory.count) versions)")
        
        do {
            // Prepare data to persist
            let simpleVersions = versionHistory.map { version in
                SimpleVersionInfo(
                    versionId: version.versionId,
                    timestamp: version.timestamp,
                    changeDescription: version.decodedMetadata?.changeDescription ?? "Unknown change",
                    isSnapshot: version.isSnapshot
                )
            }
            
            let persistedHistory = PersistedVersionHistory(
                versions: simpleVersions,
                currentIndex: currentIndex,
                lastUpdated: Date()
            )
            
            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let historyData = try encoder.encode(persistedHistory)
            
            // Get the Documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let historyURL = documentsDirectory.appendingPathComponent("version_history.json")
            
            // Write atomically to prevent corruption
            let tempURL = historyURL.appendingPathExtension("tmp")
            try historyData.write(to: tempURL)
            
            // Atomic move
            _ = try FileManager.default.replaceItem(at: historyURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
            
            logger.debug("✅ Version history persisted successfully (\(historyData.count) bytes)")
            
        } catch {
            logger.error("❌ Failed to persist version history: \(error.localizedDescription)")
        }
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

// MARK: - Snapshot Support Types

/// Represents a screenshot's state at a point in time for snapshot restoration
struct ScreenshotSnapshot: Codable {
    let id: UUID
    let timestamp: Date
    let extractedText: String?
    let needsOCR: Bool
    let needsVisionAnalysis: Bool
    let needsSemanticAnalysis: Bool
    let tags: [String]
    let isFavorite: Bool
    let userNotes: String?
    
    init(from screenshot: Screenshot) {
        self.id = screenshot.id
        self.timestamp = screenshot.timestamp
        self.extractedText = screenshot.extractedText
        self.needsOCR = screenshot.needsVisionAnalysis // Using available computed property
        self.needsVisionAnalysis = screenshot.needsVisionAnalysis
        self.needsSemanticAnalysis = screenshot.needsSemanticAnalysis
        self.tags = screenshot.userTags ?? []
        self.isFavorite = screenshot.isFavorite
        self.userNotes = screenshot.userNotes
    }
}

/// Simplified version info for persistence
struct SimpleVersionInfo: Codable {
    let versionId: UUID
    let timestamp: Date
    let changeDescription: String
    let isSnapshot: Bool
}

/// Persisted version history structure for file storage
struct PersistedVersionHistory: Codable {
    let versions: [SimpleVersionInfo]
    let currentIndex: Int
    let lastUpdated: Date
}

