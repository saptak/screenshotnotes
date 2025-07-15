import Foundation
import SwiftData
import os.log
import CryptoKit

/// Backup and Restore Service for data corruption recovery
/// Provides automatic backup system with corruption detection and recovery workflows
@MainActor
class BackupRestoreService: ObservableObject {
    static let shared = BackupRestoreService()
    
    // MARK: - Performance Targets
    // - Backup creation: <5s for 1000+ screenshots
    // - Restore operation: <10s for full database
    // - Corruption detection: <1s
    // - Recovery success rate: >95%
    
    // MARK: - State Management
    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var lastBackupDate: Date?
    @Published var availableBackups: [DataBackup] = []
    @Published var metrics = BackupMetrics()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "BackupRestore")
    private var modelContext: ModelContext?
    
    // Configuration
    private let config = BackupConfig()
    private let backupDirectory: URL
    
    // Services
    private let integrityMonitor = DataIntegrityMonitor.shared
    
    private init() {
        // Create backup directory
        let documentsURL = Foundation.FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.backupDirectory = documentsURL.appendingPathComponent("DataBackups")
        
        logger.info("💾 BackupRestoreService initialized")
        createBackupDirectory()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        logger.info("✅ BackupRestoreService configured with ModelContext")
        
        Task {
            await loadAvailableBackups()
            await schedulePeriodicBackups()
        }
    }
    
    // MARK: - Public API
    
    /// Create a backup of current data state
    func createBackup(version: DataVersion? = nil) async -> BackupResult {
        guard !isBackingUp else {
            return BackupResult(success: false, message: "Backup already in progress")
        }
        
        isBackingUp = true
        defer { isBackingUp = false }
        
        logger.info("💾 Creating data backup")
        let startTime = CFAbsoluteTimeGetCurrent()
            // Create backup metadata
            var backup = DataBackup(
                version: version?.info,
                type: .full,
                trigger: .manual
            )
            
            // Export data
            let exportResult = await exportData(for: backup)
            if !exportResult.success {
                return BackupResult(success: false, message: "Data export failed: \(exportResult.message)")
            }
            
            // Calculate checksums
            let checksumResult = await calculateBackupChecksum(backup)
            if !checksumResult.success {
                return BackupResult(success: false, message: "Checksum calculation failed")
            }
            
            // Save backup metadata
            backup.checksum = checksumResult.checksum!
            backup.dataSize = exportResult.dataSize
            
            await saveBackupMetadata(backup)
            
            // Update state
            availableBackups.append(backup)
            lastBackupDate = backup.createdAt
            
            let backupTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            updateBackupMetrics(time: backupTime, success: true)
            
            logger.info("✅ Backup created successfully in \(String(format: "%.2f", backupTime))ms")
            
            return BackupResult(success: true, backup: backup, message: "Backup created successfully")
            
        
    }
    
    /// Restore from backup
    func restore(from backup: DataBackup) async -> RestoreResult {
        guard !isRestoring else {
            return RestoreResult(success: false, message: "Restore already in progress")
        }
        
        isRestoring = true
        defer { isRestoring = false }
        
        logger.info("🔄 Restoring from backup: \(backup.id)")
        let startTime = CFAbsoluteTimeGetCurrent()
            // Verify backup integrity
            let integrityCheck = await verifyBackupIntegrity(backup)
            if !integrityCheck.isValid {
                return RestoreResult(success: false, message: "Backup integrity check failed: \(integrityCheck.reason)")
            }
            
            // Create pre-restore backup
            let preRestoreBackup = await createBackup()
            if !preRestoreBackup.success {
                logger.warning("⚠️ Failed to create pre-restore backup, proceeding anyway")
            }
            
            // Restore data
            let restoreResult = await restoreData(from: backup)
            if !restoreResult.success {
                return RestoreResult(success: false, message: "Data restore failed: \(restoreResult.message)")
            }
            
            // Verify restored data
            let verificationResult = await verifyRestoredData()
            if !verificationResult.success {
                // Attempt rollback if verification fails
                if let preRestoreBackup = preRestoreBackup.backup {
                    logger.warning("⚠️ Restored data verification failed, attempting rollback")
                    let rollbackResult = await restoreData(from: preRestoreBackup)
                    if rollbackResult.success {
                        return RestoreResult(success: false, message: "Restore failed, rolled back to previous state")
                    } else {
                        return RestoreResult(success: false, message: "Restore failed and rollback failed - data may be corrupted")
                    }
                }
                return RestoreResult(success: false, message: "Restored data verification failed")
            }
            
            let restoreTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            updateRestoreMetrics(time: restoreTime, success: true)
            
            logger.info("✅ Restore completed successfully in \(String(format: "%.2f", restoreTime))ms")
            
            return RestoreResult(success: true, message: "Restore completed successfully", restoredVersion: backup.version)
            
        
    }
    
    /// Detect and repair data corruption
    func detectAndRepairCorruption() async -> CorruptionRepairResult {
        logger.info("🔍 Detecting and repairing data corruption")
        
        // Run comprehensive integrity check
        let integrityResult = await integrityMonitor.performComprehensiveCheck()
        
        if integrityResult.issues.isEmpty {
            return CorruptionRepairResult(
                corruptionFound: false,
                repairAttempted: false,
                repairSuccessful: false,
                message: "No corruption detected"
            )
        }
        
        let criticalIssues = integrityResult.issues.filter { $0.severity == .critical }
        
        if criticalIssues.isEmpty {
            return CorruptionRepairResult(
                corruptionFound: true,
                repairAttempted: false,
                repairSuccessful: false,
                message: "Minor issues found but no critical corruption"
            )
        }
        
        // Attempt automatic repair
        let repairResult = await attemptAutomaticRepair(issues: criticalIssues)
        
        return CorruptionRepairResult(
            corruptionFound: true,
            repairAttempted: true,
            repairSuccessful: repairResult.success,
            message: repairResult.message,
            repairedIssues: repairResult.repairedIssues
        )
    }
    
    /// Get available backups
    func getAvailableBackups() -> [DataBackup] {
        return availableBackups.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Delete old backups
    func cleanupOldBackups() async {
        let cutoffDate = Date().addingTimeInterval(-config.maxBackupAge)
        let oldBackups = availableBackups.filter { $0.createdAt < cutoffDate }
        
        for backup in oldBackups {
            await deleteBackup(backup)
        }
        
        logger.info("🧹 Cleaned up \(oldBackups.count) old backups")
    }
    
    /// Get backup metrics
    func getMetrics() -> BackupMetrics {
        return metrics
    }
    
    // MARK: - Private Implementation
    
    private func exportData(for backup: DataBackup) async -> DataExportResult {
        guard let modelContext = modelContext else {
            return DataExportResult(success: false, message: "No model context available", dataSize: 0)
        }
        
        do {
            // Export screenshots
            let screenshots = try modelContext.fetch(FetchDescriptor<Screenshot>())
            let screenshotData = try JSONEncoder().encode(screenshots.map { ScreenshotBackupData(from: $0) })
            
            // Export relationships (if any)
            // let relationships = try modelContext.fetch(FetchDescriptor<EntityRelationship>())
            // let relationshipData = try JSONEncoder().encode(relationships)
            
            // Save to backup file
            let backupFileURL = backupDirectory.appendingPathComponent("\(backup.id.uuidString).backup")
            
            let backupContent = BackupContent(
                screenshots: screenshotData,
                metadata: backup,
                exportDate: Date()
            )
            
            let backupData = try JSONEncoder().encode(backupContent)
            try backupData.write(to: backupFileURL)
            
            return DataExportResult(success: true, message: "Data exported successfully", dataSize: backupData.count)
            
        } catch {
            return DataExportResult(success: false, message: "Export failed: \(error)", dataSize: 0)
        }
    }
    
    private func restoreData(from backup: DataBackup) async -> DataRestoreResult {
        guard let modelContext = modelContext else {
            return DataRestoreResult(success: false, message: "No model context available")
        }
        
        do {
            // Load backup file
            let backupFileURL = backupDirectory.appendingPathComponent("\(backup.id.uuidString).backup")
            let backupData = try Data(contentsOf: backupFileURL)
            let backupContent = try JSONDecoder().decode(BackupContent.self, from: backupData)
            
            // Clear existing data (careful operation!)
            let existingScreenshots = try modelContext.fetch(FetchDescriptor<Screenshot>())
            for screenshot in existingScreenshots {
                modelContext.delete(screenshot)
            }
            
            // Restore screenshots
            let screenshotBackupData = try JSONDecoder().decode([ScreenshotBackupData].self, from: backupContent.screenshots)
            for screenshotData in screenshotBackupData {
                let screenshot = screenshotData.toScreenshot()
                modelContext.insert(screenshot)
            }
            
            // Save changes
            try modelContext.save()
            
            return DataRestoreResult(success: true, message: "Data restored successfully")
            
        } catch {
            return DataRestoreResult(success: false, message: "Restore failed: \(error)")
        }
    }
    
    private func calculateBackupChecksum(_ backup: DataBackup) async -> ChecksumResult {
        do {
            let backupFileURL = backupDirectory.appendingPathComponent("\(backup.id.uuidString).backup")
            let backupData = try Data(contentsOf: backupFileURL)
            let checksum = backupData.sha256Hash
            
            return ChecksumResult(success: true, checksum: checksum)
        } catch {
            return ChecksumResult(success: false, checksum: nil)
        }
    }
    
    private func verifyBackupIntegrity(_ backup: DataBackup) async -> BackupIntegrityResult {
        do {
            let backupFileURL = backupDirectory.appendingPathComponent("\(backup.id.uuidString).backup")
            let backupData = try Data(contentsOf: backupFileURL)
            let currentChecksum = backupData.sha256Hash
            
            if currentChecksum == backup.checksum {
                return BackupIntegrityResult(isValid: true, reason: "Checksum verified")
            } else {
                return BackupIntegrityResult(isValid: false, reason: "Checksum mismatch")
            }
        } catch {
            return BackupIntegrityResult(isValid: false, reason: "Unable to read backup file: \(error)")
        }
    }
    
    private func verifyRestoredData() async -> DataVerificationResult {
        // Run integrity check on restored data
        let integrityResult = await integrityMonitor.performComprehensiveCheck()
        
        let criticalIssues = integrityResult.issues.filter { $0.severity == .critical }
        
        if criticalIssues.isEmpty {
            return DataVerificationResult(success: true, message: "Restored data verified successfully")
        } else {
            return DataVerificationResult(success: false, message: "Restored data has \(criticalIssues.count) critical issues")
        }
    }
    
    private func attemptAutomaticRepair(issues: [IntegrityIssue]) async -> RepairResult {
        var repairedIssues: [IntegrityIssue] = []
        var repairMessages: [String] = []
        
        for issue in issues {
            let repairAttempt = await repairIndividualIssue(issue)
            if repairAttempt.success {
                repairedIssues.append(issue)
                repairMessages.append(repairAttempt.message)
            }
        }
        
        let success = repairedIssues.count > 0
        let message = success ? "Repaired \(repairedIssues.count) issues" : "No issues could be automatically repaired"
        
        return RepairResult(success: success, message: message)
    }
    
    private func repairIndividualIssue(_ issue: IntegrityIssue) async -> RepairAttemptResult {
        // Attempt to repair specific integrity issue
        logger.info("🔧 Attempting to repair issue: \(issue.description)")
        
        guard let modelContext = modelContext else {
            return RepairAttemptResult(success: false, message: "No model context available for repair")
        }
        
        switch issue.type {
        case .orphanedData:
            return await repairOrphanedData(issue: issue, context: modelContext)
            
        case .missingReferences:
            return await repairMissingReferences(issue: issue, context: modelContext)
            
        case .dataCorruption:
            return await repairDataCorruption(issue: issue, context: modelContext)
            
        case .duplicateEntries:
            return await repairDuplicateEntries(issue: issue, context: modelContext)
            
        case .invalidRelationships:
            return await repairInvalidRelationships(issue: issue, context: modelContext)
            
        case .schemaViolation:
            return await repairSchemaViolation(issue: issue, context: modelContext)
            
        default:
            // Fallback based on severity
            switch issue.severity {
            case .critical:
                return RepairAttemptResult(success: false, message: "Critical issue requires manual intervention: \(issue.type)")
            case .warning:
                return RepairAttemptResult(success: true, message: "Warning issue acknowledged: \(issue.type)")
            case .info:
                return RepairAttemptResult(success: true, message: "Info issue noted: \(issue.type)")
            }
        }
    }
    
    private func schedulePeriodicBackups() async {
        // Schedule automatic backups based on configuration
        logger.info("📅 Scheduling periodic backups every \(self.config.autoBackupInterval / 3600) hours")
        
        // Schedule periodic backup using Timer
        Timer.scheduledTimer(withTimeInterval: config.autoBackupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Only create backup if we have significant data changes
                let shouldBackup = await self.shouldCreatePeriodicBackup()
                if shouldBackup {
                    let result = await self.createBackup()
                    if result.success {
                        self.logger.info("✅ Periodic backup completed successfully")
                    } else {
                        self.logger.error("❌ Periodic backup failed: \(result.message)")
                    }
                }
            }
        }
    }
    
    private func createBackupDirectory() {
        do {
            try Foundation.FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("❌ Failed to create backup directory: \(error)")
        }
    }
    
    private func loadAvailableBackups() async {
        do {
            let backupFiles = try Foundation.FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in backupFiles.filter({ $0.pathExtension == "backup" }) {
                if let backup = await loadBackupMetadata(from: fileURL) {
                    availableBackups.append(backup)
                }
            }
            
            // Sort by creation date
            availableBackups.sort { $0.createdAt > $1.createdAt }
            
            logger.info("📚 Loaded \(self.availableBackups.count) available backups")
            
        } catch {
            logger.error("❌ Failed to load available backups: \(error)")
        }
    }
    
    private func loadBackupMetadata(from fileURL: URL) async -> DataBackup? {
        do {
            let backupData = try Data(contentsOf: fileURL)
            let backupContent = try JSONDecoder().decode(BackupContent.self, from: backupData)
            return backupContent.metadata
        } catch {
            logger.error("❌ Failed to load backup metadata from \(fileURL): \(error)")
            return nil
        }
    }
    
    private func saveBackupMetadata(_ backup: DataBackup) async {
        // Metadata is saved as part of the backup content
        // Additional metadata could be stored separately if needed
    }
    
    private func deleteBackup(_ backup: DataBackup) async {
        do {
            let backupFileURL = backupDirectory.appendingPathComponent("\(backup.id.uuidString).backup")
            try Foundation.FileManager.default.removeItem(at: backupFileURL)
            
            if let index = availableBackups.firstIndex(where: { $0.id == backup.id }) {
                availableBackups.remove(at: index)
            }
            
        } catch {
            logger.error("❌ Failed to delete backup \(backup.id): \(error)")
        }
    }
    
    private func updateBackupMetrics(time: TimeInterval, success: Bool) {
        metrics.totalBackups += 1
        if success {
            metrics.successfulBackups += 1
            metrics.lastBackupTime = time
            
            // Update average
            let totalTime = metrics.averageBackupTime * Double(metrics.successfulBackups - 1) + time
            metrics.averageBackupTime = totalTime / Double(metrics.successfulBackups)
        }
    }
    
    private func updateRestoreMetrics(time: TimeInterval, success: Bool) {
        metrics.totalRestores += 1
        if success {
            metrics.successfulRestores += 1
            metrics.lastRestoreTime = time
            
            // Update average
            let totalTime = metrics.averageRestoreTime * Double(metrics.successfulRestores - 1) + time
            metrics.averageRestoreTime = totalTime / Double(metrics.successfulRestores)
        }
    }
    
    // MARK: - Data Repair Methods
    
    private func repairOrphanedData(issue: IntegrityIssue, context: ModelContext) async -> RepairAttemptResult {
        do {
            // Find and remove orphaned data entries
            let screenshots = try context.fetch(FetchDescriptor<Screenshot>())
            var repairedCount = 0
            
            for screenshot in screenshots {
                // Check if screenshot has valid image data
                if screenshot.imageData.isEmpty {
                    logger.debug("🖾 Removing orphaned screenshot: \(screenshot.id)")
                    context.delete(screenshot)
                    repairedCount += 1
                }
                
                // Check for other orphaned data conditions
                if screenshot.filename.isEmpty && screenshot.extractedText?.isEmpty != false {
                    logger.debug("🖾 Removing empty screenshot: \(screenshot.id)")
                    context.delete(screenshot)
                    repairedCount += 1
                }
            }
            
            if repairedCount > 0 {
                try context.save()
                return RepairAttemptResult(success: true, message: "Removed \(repairedCount) orphaned data entries")
            } else {
                return RepairAttemptResult(success: true, message: "No orphaned data found to repair")
            }
            
        } catch {
            return RepairAttemptResult(success: false, message: "Failed to repair orphaned data: \(error.localizedDescription)")
        }
    }
    
    private func repairMissingReferences(issue: IntegrityIssue, context: ModelContext) async -> RepairAttemptResult {
        do {
            // Check for screenshots with missing file references
            let screenshots = try context.fetch(FetchDescriptor<Screenshot>())
            var repairedCount = 0
            
            for screenshot in screenshots {
                // If filename is missing but we have image data, generate filename
                if screenshot.filename.isEmpty && !screenshot.imageData.isEmpty {
                    screenshot.filename = "screenshot_\(screenshot.id.uuidString.prefix(8)).png"
                    repairedCount += 1
                    logger.debug("🔧 Generated filename for screenshot: \(screenshot.id)")
                }
                
                // If timestamp is invalid, use current date
                if screenshot.timestamp < Date(timeIntervalSince1970: 0) {
                    screenshot.timestamp = Date()
                    repairedCount += 1
                    logger.debug("🔧 Fixed invalid timestamp for screenshot: \(screenshot.id)")
                }
            }
            
            if repairedCount > 0 {
                try context.save()
                return RepairAttemptResult(success: true, message: "Repaired \(repairedCount) missing references")
            } else {
                return RepairAttemptResult(success: true, message: "No missing references found to repair")
            }
            
        } catch {
            return RepairAttemptResult(success: false, message: "Failed to repair missing references: \(error.localizedDescription)")
        }
    }
    
    private func repairDataCorruption(issue: IntegrityIssue, context: ModelContext) async -> RepairAttemptResult {
        // For critical data corruption, we need to fall back to backups
        if availableBackups.isEmpty {
            return RepairAttemptResult(success: false, message: "No backups available for corruption repair")
        }
        
        // Find the most recent valid backup
        for backup in availableBackups.sorted(by: { $0.createdAt > $1.createdAt }) {
            let integrityCheck = await verifyBackupIntegrity(backup)
            if integrityCheck.isValid {
                logger.info("🔄 Attempting to restore from backup to repair corruption: \(backup.id)")
                let restoreResult = await restoreData(from: backup)
                
                if restoreResult.success {
                    return RepairAttemptResult(success: true, message: "Data corruption repaired by restoring from backup")
                } else {
                    continue // Try next backup
                }
            }
        }
        
        return RepairAttemptResult(success: false, message: "Could not repair data corruption - no valid backups available")
    }
    
    private func repairDuplicateEntries(issue: IntegrityIssue, context: ModelContext) async -> RepairAttemptResult {
        do {
            let screenshots = try context.fetch(FetchDescriptor<Screenshot>())
            var seenIds: Set<UUID> = []
            var duplicatesRemoved = 0
            
            for screenshot in screenshots {
                if seenIds.contains(screenshot.id) {
                    // Remove duplicate
                    context.delete(screenshot)
                    duplicatesRemoved += 1
                    logger.debug("🖾 Removed duplicate screenshot: \(screenshot.id)")
                } else {
                    seenIds.insert(screenshot.id)
                }
            }
            
            if duplicatesRemoved > 0 {
                try context.save()
                return RepairAttemptResult(success: true, message: "Removed \(duplicatesRemoved) duplicate entries")
            } else {
                return RepairAttemptResult(success: true, message: "No duplicate entries found")
            }
            
        } catch {
            return RepairAttemptResult(success: false, message: "Failed to repair duplicate entries: \(error.localizedDescription)")
        }
    }
    
    private func repairInvalidRelationships(issue: IntegrityIssue, context: ModelContext) async -> RepairAttemptResult {
        // This would repair relationships between screenshots and other entities
        // For now, we'll implement a basic check
        
        do {
            let screenshots = try context.fetch(FetchDescriptor<Screenshot>())
            var repairedCount = 0
            
            for screenshot in screenshots {
                // Validate and repair screenshot relationships
                // For example, ensure tags are properly formatted
                let validTags = (screenshot.userTags ?? []).filter { !$0.isEmpty && $0.count <= 50 }
                if validTags.count != (screenshot.userTags ?? []).count {
                    screenshot.userTags = validTags
                    repairedCount += 1
                    logger.debug("🔧 Cleaned invalid tags for screenshot: \(screenshot.id)")
                }
            }
            
            if repairedCount > 0 {
                try context.save()
                return RepairAttemptResult(success: true, message: "Repaired \(repairedCount) invalid relationships")
            } else {
                return RepairAttemptResult(success: true, message: "No invalid relationships found")
            }
            
        } catch {
            return RepairAttemptResult(success: false, message: "Failed to repair invalid relationships: \(error.localizedDescription)")
        }
    }
    
    private func repairSchemaViolation(issue: IntegrityIssue, context: ModelContext) async -> RepairAttemptResult {
        // Schema violations typically require data migration or structure fixes
        do {
            let screenshots = try context.fetch(FetchDescriptor<Screenshot>())
            var repairedCount = 0
            
            for screenshot in screenshots {
                // Ensure required fields are not nil/empty
                if screenshot.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                    screenshot.id = UUID()
                    repairedCount += 1
                    logger.debug("🔧 Generated new UUID for screenshot with invalid ID")
                }
                
                // Ensure timestamp is valid
                if screenshot.timestamp.timeIntervalSince1970 < 0 {
                    screenshot.timestamp = Date()
                    repairedCount += 1
                    logger.debug("🔧 Fixed invalid timestamp for screenshot: \(screenshot.id)")
                }
            }
            
            if repairedCount > 0 {
                try context.save()
                return RepairAttemptResult(success: true, message: "Repaired \(repairedCount) schema violations")
            } else {
                return RepairAttemptResult(success: true, message: "No schema violations found")
            }
            
        } catch {
            return RepairAttemptResult(success: false, message: "Failed to repair schema violations: \(error.localizedDescription)")
        }
    }
    
    private func shouldCreatePeriodicBackup() async -> Bool {
        // Check if enough changes have occurred since last backup to warrant a new one
        guard let lastBackup = lastBackupDate else {
            return true // No previous backup exists
        }
        
        // Check if enough time has passed
        let timeSinceLastBackup = Date().timeIntervalSince(lastBackup)
        if timeSinceLastBackup < config.autoBackupInterval * 0.8 {
            return false // Too soon for another backup
        }
        
        // Check if there are significant data changes
        // This could be enhanced to track actual change volume
        return true
    }
}

// MARK: - Supporting Types

struct BackupConfig {
    let autoBackupInterval: TimeInterval = 6 * 60 * 60 // 6 hours
    let maxBackupAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    let maxBackupCount = 50
    let compressionEnabled = true
    let checksumValidation = true
}

// DataBackup moved to DataConsistencyTypes.swift

// BackupType and BackupTrigger moved to DataConsistencyTypes.swift

struct BackupContent: Codable {
    let screenshots: Data
    let metadata: DataBackup
    let exportDate: Date
}

struct ScreenshotBackupData: Codable {
    let id: UUID
    let timestamp: Date
    let extractedText: String?
    let imageData: Data
    let filename: String
    // Add other screenshot properties as needed
    
    init(from screenshot: Screenshot) {
        self.id = screenshot.id
        self.timestamp = screenshot.timestamp
        self.extractedText = screenshot.extractedText
        self.imageData = screenshot.imageData
        self.filename = screenshot.filename
    }
    
    func toScreenshot() -> Screenshot {
        let screenshot = Screenshot(imageData: self.imageData, filename: self.filename, timestamp: self.timestamp)
        screenshot.id = self.id
        screenshot.extractedText = self.extractedText
        return screenshot
    }
}

struct BackupMetrics {
    var totalBackups = 0
    var successfulBackups = 0
    var totalRestores = 0
    var successfulRestores = 0
    var averageBackupTime: TimeInterval = 0
    var averageRestoreTime: TimeInterval = 0
    var lastBackupTime: TimeInterval = 0
    var lastRestoreTime: TimeInterval = 0
    
    var backupSuccessRate: Double {
        guard totalBackups > 0 else { return 0 }
        return Double(successfulBackups) / Double(totalBackups)
    }
    
    var restoreSuccessRate: Double {
        guard totalRestores > 0 else { return 0 }
        return Double(successfulRestores) / Double(totalRestores)
    }
}

// BackupResult and RestoreResult moved to DataConsistencyTypes.swift

struct CorruptionRepairResult {
    let corruptionFound: Bool
    let repairAttempted: Bool
    let repairSuccessful: Bool
    let message: String
    let repairedIssues: [IntegrityIssue]
    
    init(corruptionFound: Bool, repairAttempted: Bool, repairSuccessful: Bool, message: String, repairedIssues: [IntegrityIssue] = []) {
        self.corruptionFound = corruptionFound
        self.repairAttempted = repairAttempted
        self.repairSuccessful = repairSuccessful
        self.message = message
        self.repairedIssues = repairedIssues
    }
}

struct DataExportResult {
    let success: Bool
    let message: String
    let dataSize: Int
}

struct DataRestoreResult {
    let success: Bool
    let message: String
}

struct ChecksumResult {
    let success: Bool
    let checksum: String?
}

struct BackupIntegrityResult {
    let isValid: Bool
    let reason: String
}

struct DataVerificationResult {
    let success: Bool
    let message: String
}

// RepairResult moved to DataConsistencyTypes.swift

struct RepairAttemptResult {
    let success: Bool
    let message: String
}

// MARK: - Data Extension for SHA256

extension Data {
    var sha256Hash: String {
        // Enhanced hash implementation using CryptoKit
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
} 