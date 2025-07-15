import Foundation

// MARK: - Change Types

enum ChangeType: Codable, Hashable {
    case screenshotAdded(UUID)
    case screenshotDeleted(UUID)
    case screenshotModified(UUID)
    case relationshipAdded(UUID, UUID)
    case relationshipDeleted(UUID, UUID)
    case userAnnotationChanged(UUID)
    case aiAnalysisUpdated(UUID)
    case bulkImport([UUID])
}

// MARK: - Data Change

struct DataChange {
    let type: ChangeType
    let timestamp: Date
    
    init(type: ChangeType) {
        self.type = type
        self.timestamp = Date()
    }
}

// MARK: - Conflict Types

enum ConflictType {
    case simultaneousEdit
    case userVsAI
    case dataIntegrityViolation
    case versionMismatch
}

enum ConflictSeverity: String, CaseIterable {
    case low, medium, high, critical
}

struct DataConflict {
    let conflictId: UUID
    let changes: [DataChange]
    let conflictType: ConflictType
    let timestamp: Date
    let canAutoResolve: Bool
    let affectedNodes: Set<UUID>
    let severity: ConflictSeverity
    
    init(changes: [DataChange], conflictType: ConflictType, canAutoResolve: Bool = true, affectedNodes: Set<UUID> = [], severity: ConflictSeverity = .medium) {
        self.conflictId = UUID()
        self.changes = changes
        self.conflictType = conflictType
        self.timestamp = Date()
        self.canAutoResolve = canAutoResolve
        self.affectedNodes = affectedNodes
        self.severity = severity
    }
}

// MARK: - Resolution Types

enum ResolutionStrategy {
    case automatic
    case userPriority
    case timestampBased
    case contentMerge
    case confidenceBased
    case semanticMerge
    case manualResolution
}

struct ConflictResolution {
    let resolutionId: UUID
    let conflicts: [DataConflict]
    let acceptedChanges: [DataChange]
    let rejectedChanges: [DataChange]
    let resolutionStrategy: ResolutionStrategy
    let success: Bool
    let message: String
    let resolutionTime: TimeInterval
    
    init(
        resolutionId: UUID,
        conflicts: [DataConflict],
        acceptedChanges: [DataChange],
        rejectedChanges: [DataChange],
        resolutionStrategy: ResolutionStrategy,
        success: Bool,
        message: String,
        resolutionTime: TimeInterval = 0
    ) {
        self.resolutionId = resolutionId
        self.conflicts = conflicts
        self.acceptedChanges = acceptedChanges
        self.rejectedChanges = rejectedChanges
        self.resolutionStrategy = resolutionStrategy
        self.success = success
        self.message = message
        self.resolutionTime = resolutionTime
    }
}

// MARK: - Data Health

enum DataHealthStatus {
    case healthy
    case warning
    case critical
    case unknown
}

enum IssueType {
    case orphanedData
    case missingReferences
    case dataCorruption
    case duplicateEntries
    case invalidRelationships
    case schemaViolation
    case unknown
}

struct IntegrityIssue {
    let id: UUID
    let type: IssueType
    let severity: IssueSeverity
    let description: String
    let affectedData: Set<UUID>
    let detectedAt: Date
    
    enum IssueSeverity {
        case critical, warning, info
    }
    
    init(type: IssueType = .unknown, severity: IssueSeverity, description: String, affectedData: Set<UUID>) {
        self.id = UUID()
        self.type = type
        self.severity = severity
        self.description = description
        self.affectedData = affectedData
        self.detectedAt = Date()
    }
}

struct IntegrityCheckResult {
    let success: Bool
    let message: String
    let issues: [IntegrityIssue]
    let healthStatus: DataHealthStatus
    let checkTime: TimeInterval
    
    init(
        success: Bool,
        message: String,
        issues: [IntegrityIssue] = [],
        healthStatus: DataHealthStatus = .healthy,
        checkTime: TimeInterval = 0
    ) {
        self.success = success
        self.message = message
        self.issues = issues
        self.healthStatus = healthStatus
        self.checkTime = checkTime
    }
}

struct QuickCheckResult {
    let healthy: Bool
    let criticalIssues: Int
    let checkTime: TimeInterval
    
    init(healthy: Bool, criticalIssues: Int, checkTime: TimeInterval = 0) {
        self.healthy = healthy
        self.criticalIssues = criticalIssues
        self.checkTime = checkTime
    }
}

struct SpecificCheckResult {
    let dataId: UUID
    let healthy: Bool
    let issues: [IntegrityIssue]
    
    init(dataId: UUID, healthy: Bool, issues: [IntegrityIssue]) {
        self.dataId = dataId
        self.healthy = healthy
        self.issues = issues
    }
}

// MARK: - Data Types

enum DataType {
    case screenshot
    case relationship
    case annotation
    case semanticData
    case cache
}

enum BackupType: String, Codable {
    case full, incremental, snapshot
}

enum BackupTrigger: String, Codable {
    case manual, automatic, beforeRestore, corruption
}

// MARK: - Result Types

struct UndoResult {
    let success: Bool
    let message: String
    let newVersion: DataVersion?
    
    init(success: Bool, message: String, newVersion: DataVersion? = nil) {
        self.success = success
        self.message = message
        self.newVersion = newVersion
    }
}

struct RedoResult {
    let success: Bool
    let message: String
    let newVersion: DataVersion?
    
    init(success: Bool, message: String, newVersion: DataVersion? = nil) {
        self.success = success
        self.message = message
        self.newVersion = newVersion
    }
}

struct BackupResult {
    let success: Bool
    let backup: DataBackup?
    let message: String
    
    init(success: Bool, backup: DataBackup? = nil, message: String) {
        self.success = success
        self.backup = backup
        self.message = message
    }
}

struct RestoreResult {
    let success: Bool
    let message: String
    let restoredVersion: DataVersionInfo?
    
    init(success: Bool, message: String, restoredVersion: DataVersionInfo? = nil) {
        self.success = success
        self.message = message
        self.restoredVersion = restoredVersion
    }
}

struct DataBackup: Codable {
    let id: UUID
    let createdAt: Date
    var version: DataVersionInfo?
    var dataSize: Int
    var checksum: String
    let type: BackupType
    let trigger: BackupTrigger
    
    init(version: DataVersionInfo? = nil, type: BackupType = .full, trigger: BackupTrigger = .manual) {
        self.id = UUID()
        self.createdAt = Date()
        self.version = version
        self.dataSize = 0
        self.checksum = ""
        self.type = type
        self.trigger = trigger
    }
}

struct RepairResult {
    let success: Bool
    let message: String
    let repairedIssues: [IntegrityIssue] = []
}

// MARK: - Metrics

struct IntegrityMetrics {
    var lastFullCheckTime: TimeInterval = 0
    var lastQuickCheckTime: TimeInterval = 0
    var fullCheckCount: Int = 0
    var quickCheckCount: Int = 0
    var issueCount: Int = 0
    var criticalIssueCount: Int = 0
    var averageCheckTime: TimeInterval = 0
    var lastHealthStatus: DataHealthStatus = .unknown
}

struct ConflictMetrics {
    var totalConflicts: Int = 0
    var resolvedConflicts: Int = 0
    var automaticResolutions: Int = 0
    var manualResolutions: Int = 0
    var averageResolutionTime: TimeInterval = 0
    var lastConflictTime: Date?
    var lastResolutionTime: TimeInterval = 0
    
    var resolutionRate: Double {
        guard totalConflicts > 0 else { return 0 }
        return Double(resolvedConflicts) / Double(totalConflicts)
    }
    
    var automaticResolutionRate: Double {
        guard resolvedConflicts > 0 else { return 0 }
        return Double(automaticResolutions) / Double(resolvedConflicts)
    }
} 