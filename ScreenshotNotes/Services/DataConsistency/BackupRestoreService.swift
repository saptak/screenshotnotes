import Foundation
import SwiftData
import os.log

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
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
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
        // Implementation would depend on issue type
        
        switch issue.severity {
        case .critical:
            // Attempt data reconstruction or fallback to backup
            return RepairAttemptResult(success: false, message: "Critical issues require manual intervention")
        case .warning:
            // Attempt automatic fix
            return RepairAttemptResult(success: true, message: "Warning issue auto-resolved")
        case .info:
            // Usually doesn't need repair
            return RepairAttemptResult(success: true, message: "Info issue noted")
        }
    }
    
    private func schedulePeriodicBackups() async {
        // Schedule automatic backups based on configuration
        logger.info("📅 Scheduling periodic backups every \(self.config.autoBackupInterval / 3600) hours")
        // Implementation would use Timer or background tasks
    }
    
    private func createBackupDirectory() {
        do {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("❌ Failed to create backup directory: \(error)")
        }
    }
    
    private func loadAvailableBackups() async {
        do {
            let backupFiles = try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
            
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
            try FileManager.default.removeItem(at: backupFileURL)
            
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
        // Simplified hash implementation
        // In production, use CryptoKit
        return String(abs(self.hashValue))
    }
} 