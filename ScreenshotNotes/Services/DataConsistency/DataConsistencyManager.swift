import Foundation
import SwiftData
import os.log

/// Central orchestrator for all data consistency operations
/// Coordinates between change tracking, conflict resolution, versioning, and integrity monitoring
@MainActor
class DataConsistencyManager: ObservableObject {
    static let shared = DataConsistencyManager()
    
    // MARK: - Performance Targets
    // Based on enterprise reliability requirements:
    // - Data integrity: 99.9% maintained under stress testing
    // - Conflict resolution: <100ms for simple conflicts, <1s for complex
    // - Version operations: <50ms for undo/redo
    // - Health checks: Real-time monitoring with <10ms impact
    
    // MARK: - Dependencies
    private let changeTracker = ChangeTrackingService.shared
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "DataConsistency")
    
    // Service dependencies (lazy initialization)
    private lazy var conflictResolver = ConflictResolutionService.shared
    private lazy var integrityMonitor = DataIntegrityMonitor.shared
    private lazy var versionHistory = VersionHistoryService.shared
    private lazy var backupRestore = BackupRestoreService.shared
    private lazy var transactionManager = BasicTransactionManager.shared
    
    // MARK: - State Management
    @Published var currentDataVersion: DataVersion?
    @Published var isConsistencyCheckRunning = false
    @Published var lastIntegrityCheck: Date?
    @Published var consistencyMetrics = ConsistencyMetrics()
    
    private var modelContext: ModelContext?
    private var isInitialized = false
    
    // MARK: - Configuration
    private let config = DataConsistencyConfig()
    
    private init() {
        logger.info("🛡️ DataConsistencyManager initialized")
        setupPeriodicHealthChecks()
    }
    
    // MARK: - Initialization
    
    func setModelContext(_ context: ModelContext) {
        guard !isInitialized else { return }
        
        self.modelContext = context
        
        // Initialize all dependent services
        changeTracker.setModelContext(context)
        conflictResolver.setModelContext(context)
        integrityMonitor.setModelContext(context)
        versionHistory.setModelContext(context)
        backupRestore.setModelContext(context)
        transactionManager.setModelContext(context)
        
        isInitialized = true
        logger.info("✅ DataConsistencyManager fully initialized with ModelContext")
        
        // Perform initial integrity check
        Task {
            await performInitialIntegrityCheck()
        }
    }
    
    // MARK: - Public API
    
    /// Begin a new transaction for atomic operations
    func beginTransaction() -> Transaction {
        return transactionManager.beginTransaction()
    }
    
    /// Track a data change and handle consistency implications
    func trackChange(_ change: DataChange) async -> ConsistencyResult {
        logger.info("🔄 Tracking change: \(String(describing: change.type))")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. Track the change
        changeTracker.trackChange(change)
        
        // 2. Check for conflicts
        let conflicts = await detectConflicts(for: change)
        
        // 3. Resolve conflicts if any
        var resolutionResult: ConflictResolution?
        if !conflicts.isEmpty {
            resolutionResult = await resolveConflicts(conflicts)
        }
        
        // 4. Update version history
        let version = await createDataVersion(for: change)
        currentDataVersion = version
        
        // 5. Propagate changes if needed
        await propagateChanges(change)
        
        // 6. Update metrics
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        updateMetrics(processingTime: processingTime, hadConflicts: !conflicts.isEmpty)
        
        return ConsistencyResult(
            success: true,
            version: version,
            conflicts: conflicts,
            resolution: resolutionResult,
            processingTime: processingTime
        )
    }
    
    /// Perform comprehensive data integrity check
    func performIntegrityCheck() async -> IntegrityCheckResult {
        guard !isConsistencyCheckRunning else {
            logger.warning("⚠️ Integrity check already running")
            return IntegrityCheckResult(success: false, message: "Check already in progress")
        }
        
        isConsistencyCheckRunning = true
        defer { isConsistencyCheckRunning = false }
        
        logger.info("🔍 Starting comprehensive data integrity check")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = await integrityMonitor.performComprehensiveCheck()
        
        lastIntegrityCheck = Date()
        let checkTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        logger.info("✅ Integrity check completed in \(String(format: "%.2f", checkTime))ms")
        
        // Handle any issues found
        if !result.issues.isEmpty {
            await handleIntegrityIssues(result.issues)
        }
        
        return result
    }
    
    /// Undo the last operation
    func undo() async -> UndoResult {
        logger.info("↩️ Performing undo operation")
        
        guard let currentVersion = currentDataVersion else {
            return UndoResult(success: false, message: "No version to undo")
        }
        
        let result = await versionHistory.undo(from: currentVersion)
        
        if result.success {
            currentDataVersion = result.newVersion
            logger.info("✅ Undo completed successfully")
        } else {
            logger.error("❌ Undo failed: \(result.message)")
        }
        
        return result
    }
    
    /// Redo the last undone operation
    func redo() async -> RedoResult {
        logger.info("↪️ Performing redo operation")
        
        let result = await versionHistory.redo()
        
        if result.success {
            currentDataVersion = result.newVersion
            logger.info("✅ Redo completed successfully")
        } else {
            logger.error("❌ Redo failed: \(result.message)")
        }
        
        return result
    }
    
    /// Create a backup of current data state
    func createBackup() async -> BackupResult {
        logger.info("💾 Creating data backup")
        
        return await backupRestore.createBackup(version: currentDataVersion)
    }
    
    /// Restore from backup
    func restoreFromBackup(_ backup: DataBackup) async -> RestoreResult {
        logger.info("🔄 Restoring from backup: \(backup.id)")
        
        let result = await backupRestore.restore(from: backup)
        
        if result.success {
            // Refresh current state after restore
            await refreshDataState()
            logger.info("✅ Restore completed successfully")
        } else {
            logger.error("❌ Restore failed: \(result.message)")
        }
        
        return result
    }
    
    // MARK: - Private Implementation
    
    private func performInitialIntegrityCheck() async {
        logger.info("🔍 Performing initial integrity check")
        
        let result = await performIntegrityCheck()
        
        if !result.success {
            logger.error("❌ Initial integrity check failed: \(result.message)")
            // Could trigger recovery mechanisms here
        }
    }
    
    private func detectConflicts(for change: DataChange) async -> [DataConflict] {
        // Use conflict resolver to detect potential conflicts
        return await conflictResolver.detectConflicts(for: change)
    }
    
    private func resolveConflicts(_ conflicts: [DataConflict]) async -> ConflictResolution {
        logger.info("⚡ Resolving \(conflicts.count) conflicts")
        
        return await conflictResolver.resolveConflicts(conflicts)
    }
    
    private func createDataVersion(for change: DataChange) async -> DataVersion {
        let fingerprint = await changeTracker.createDataFingerprint()
        
        let version = DataVersion(
            timestamp: Date(),
            versionId: UUID(),
            changeType: change.type,
            affectedNodes: Array(changeTracker.getAffectedNodesForChange(change)),
            checksum: fingerprint,
            metadata: VersionMetadata(
                changeDescription: describeChange(change),
                userInitiated: isUserInitiated(change),
                automaticBackup: shouldCreateAutomaticBackup(change)
            )
        )
        
        await versionHistory.addVersion(version)
        
        return version
    }
    
    private func propagateChanges(_ change: DataChange) async {
        // Notify dependent services about the change
        let affectedNodes = changeTracker.getAffectedNodesForChange(change)
        
        // Trigger selective updates based on change type
        switch change.type {
        case .screenshotAdded, .screenshotDeleted, .screenshotModified:
            // Notify thumbnail service, search cache, etc.
            await notifyImageRelatedServices(affectedNodes: affectedNodes)
            
        case .relationshipAdded, .relationshipDeleted:
            // Notify mind map service, graph services
            await notifyRelationshipServices(affectedNodes: affectedNodes)
            
        case .userAnnotationChanged:
            // Notify search service, backup service
            await notifyAnnotationServices(affectedNodes: affectedNodes)
            
        case .aiAnalysisUpdated:
            // Notify semantic services, search service
            await notifyAIServices(affectedNodes: affectedNodes)
            
        case .bulkImport:
            // Comprehensive notification for bulk changes
            await notifyAllServices(affectedNodes: affectedNodes)
        }
    }
    
    private func handleIntegrityIssues(_ issues: [IntegrityIssue]) async {
        logger.warning("⚠️ Handling \(issues.count) integrity issues")
        
        for issue in issues {
            switch issue.severity {
            case .critical:
                // Automatic repair for critical issues
                await attemptAutomaticRepair(issue)
                
            case .warning:
                // Log and monitor warning issues
                logger.warning("⚠️ Data integrity warning: \(issue.description)")
                
            case .info:
                // Informational logging
                logger.info("ℹ️ Data integrity info: \(issue.description)")
            }
        }
    }
    
    private func attemptAutomaticRepair(_ issue: IntegrityIssue) async {
        logger.info("🔧 Attempting automatic repair for: \(issue.description)")
        
        // Delegate to backup/restore service for repair
        let repairResult = await backupRestore.detectAndRepairCorruption()
        
        if repairResult.repairSuccessful {
            logger.info("✅ Automatic repair successful")
        } else {
            logger.error("❌ Automatic repair failed: \(repairResult.message)")
            // Could escalate to user notification or manual intervention
        }
    }
    
    private func refreshDataState() async {
        // Refresh current data version after major operations
        let fingerprint = await changeTracker.createDataFingerprint()
        
        currentDataVersion = DataVersion(
            timestamp: Date(),
            versionId: UUID(),
            changeType: .bulkImport([]), // Placeholder for refresh
            affectedNodes: [],
            checksum: fingerprint,
            metadata: VersionMetadata(
                changeDescription: "Data state refresh",
                userInitiated: false,
                automaticBackup: false
            )
        )
    }
    
    private func updateMetrics(processingTime: TimeInterval, hadConflicts: Bool) {
        consistencyMetrics.totalOperations += 1
        consistencyMetrics.averageProcessingTime = (consistencyMetrics.averageProcessingTime + processingTime) / 2
        
        if hadConflicts {
            consistencyMetrics.conflictCount += 1
        }
        
        consistencyMetrics.lastOperation = Date()
    }
    
    private func setupPeriodicHealthChecks() {
        // Set up periodic integrity checks every 24 hours
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performIntegrityCheck()
            }
        }
    }
    
    // MARK: - Service Notification Helpers
    
    private func notifyImageRelatedServices(affectedNodes: Set<UUID>) async {
        // Notify thumbnail service, gallery cache, etc.
        // This would integrate with existing thumbnail and gallery services
        logger.debug("📸 Notifying image-related services for \(affectedNodes.count) nodes")
    }
    
    private func notifyRelationshipServices(affectedNodes: Set<UUID>) async {
        // Notify mind map service, relationship tracking
        logger.debug("🔗 Notifying relationship services for \(affectedNodes.count) nodes")
    }
    
    private func notifyAnnotationServices(affectedNodes: Set<UUID>) async {
        // Notify search service, annotation processors
        logger.debug("📝 Notifying annotation services for \(affectedNodes.count) nodes")
    }
    
    private func notifyAIServices(affectedNodes: Set<UUID>) async {
        // Notify semantic processing, entity extraction
        logger.debug("🤖 Notifying AI services for \(affectedNodes.count) nodes")
    }
    
    private func notifyAllServices(affectedNodes: Set<UUID>) async {
        // Comprehensive notification for bulk operations
        await notifyImageRelatedServices(affectedNodes: affectedNodes)
        await notifyRelationshipServices(affectedNodes: affectedNodes)
        await notifyAnnotationServices(affectedNodes: affectedNodes)
        await notifyAIServices(affectedNodes: affectedNodes)
    }
    
    // MARK: - Utility Methods
    
    private func describeChange(_ change: DataChange) -> String {
        switch change.type {
        case .screenshotAdded(let id):
            return "Screenshot added: \(id)"
        case .screenshotDeleted(let id):
            return "Screenshot deleted: \(id)"
        case .screenshotModified(let id):
            return "Screenshot modified: \(id)"
        case .relationshipAdded(let fromId, let toId):
            return "Relationship added: \(fromId) -> \(toId)"
        case .relationshipDeleted(let fromId, let toId):
            return "Relationship deleted: \(fromId) -> \(toId)"
        case .userAnnotationChanged(let id):
            return "User annotation changed: \(id)"
        case .aiAnalysisUpdated(let id):
            return "AI analysis updated: \(id)"
        case .bulkImport(let ids):
            return "Bulk import: \(ids.count) items"
        }
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
    
    private func shouldCreateAutomaticBackup(_ change: DataChange) -> Bool {
        switch change.type {
        case .bulkImport(let ids):
            return ids.count > 10 // Backup for significant imports
        case .screenshotDeleted:
            return true // Always backup before deletion
        default:
            return false
        }
    }
}

// MARK: - Supporting Types

struct DataConsistencyConfig {
    let maxVersionHistory = 100
    let automaticBackupThreshold = 50 // Operations before auto-backup
    let integrityCheckInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    let conflictResolutionTimeout: TimeInterval = 10.0 // 10 seconds
}

struct ConsistencyResult {
    let success: Bool
    let version: DataVersion
    let conflicts: [DataConflict]
    let resolution: ConflictResolution?
    let processingTime: TimeInterval
}

struct ConsistencyMetrics {
    var totalOperations = 0
    var conflictCount = 0
    var averageProcessingTime: TimeInterval = 0
    var lastOperation: Date?
    
    var conflictRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(conflictCount) / Double(totalOperations)
    }
}

struct ConsistencyMetadata {
    let changeDescription: String
    let userInitiated: Bool
    let automaticBackup: Bool
}

// MARK: - Result Types
// All result types moved to DataConsistencyTypes.swift