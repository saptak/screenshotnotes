import Foundation
import SwiftData

/// Comprehensive data version model for tracking changes and enabling undo/redo functionality
@Model
class DataVersion: @unchecked Sendable {
    @Attribute(.unique) var versionId: UUID
    var timestamp: Date
    var changeType: ChangeType
    var affectedNodes: [UUID]
    var checksum: String
    var metadata: Data? // Encoded VersionMetadata
    
    // Delta compression fields
    var deltaData: Data? // Compressed change data
    var parentVersionId: UUID? // For version chain
    var isSnapshot: Bool // Full snapshot vs delta
    
    // Version chain management
    var nextVersionId: UUID? // For bidirectional navigation
    var branchName: String // For branching support
    var mergeParents: [UUID] // For merge operation tracking
    
    // Performance metrics
    var creationTime: TimeInterval // Time to create this version
    var storageSize: Int // Bytes used for this version
    var compressionRatio: Double // Delta compression efficiency
    
    init(
        timestamp: Date,
        versionId: UUID,
        changeType: ChangeType,
        affectedNodes: [UUID],
        checksum: String,
        metadata: VersionMetadata? = nil,
        parentVersionId: UUID? = nil,
        isSnapshot: Bool = false,
        branchName: String = "main"
    ) {
        self.versionId = versionId
        self.timestamp = timestamp
        self.changeType = changeType
        self.affectedNodes = affectedNodes
        self.checksum = checksum
        self.parentVersionId = parentVersionId
        self.isSnapshot = isSnapshot
        self.branchName = branchName
        self.mergeParents = []
        self.creationTime = 0
        self.storageSize = 0
        self.compressionRatio = 1.0
        
        // Encode metadata if provided
        if let metadata = metadata {
            self.metadata = try? JSONEncoder().encode(metadata)
        }
    }
}

// MARK: - DataVersion Extensions

extension DataVersion {
    var info: DataVersionInfo {
        return DataVersionInfo(versionId: self.versionId, timestamp: self.timestamp)
    }

    
    /// Get decoded metadata
    var decodedMetadata: VersionMetadata? {
        guard let data = metadata else { return nil }
        return try? JSONDecoder().decode(VersionMetadata.self, from: data)
    }
    
    /// Set metadata with automatic encoding
    func setMetadata(_ metadata: VersionMetadata) {
        self.metadata = try? JSONEncoder().encode(metadata)
    }
    
    /// Get decoded delta data
    var decodedDelta: VersionDelta? {
        guard let data = deltaData else { return nil }
        return try? JSONDecoder().decode(VersionDelta.self, from: data)
    }
    
    /// Set delta data with automatic encoding and compression
    func setDelta(_ delta: VersionDelta) {
        do {
            let encoded = try JSONEncoder().encode(delta)
            let compressed = try encoded.compressed()
            
            self.deltaData = compressed
            self.storageSize = compressed.count
            self.compressionRatio = Double(compressed.count) / Double(encoded.count)
        } catch {
            print("❌ Failed to encode/compress delta: \(error)")
            self.deltaData = nil
            self.storageSize = 0
            self.compressionRatio = 1.0
        }
    }
    
    /// Check if this version can be safely undone
    var canUndo: Bool {
        guard let metadata = decodedMetadata else { return false }
        return !metadata.isSystemGenerated && parentVersionId != nil
    }
    
    /// Check if this version has a redo target
    var canRedo: Bool {
        return nextVersionId != nil
    }
    
    /// Get a human-readable description of this version
    var description: String {
        let metadata = decodedMetadata
        let changeDesc = metadata?.changeDescription ?? "Unknown change"
        let userFlag = metadata?.userInitiated == true ? "👤" : "🤖"
        
        return "\(userFlag) \(changeDesc) (\(affectedNodes.count) nodes)"
    }
    
    /// Calculate the age of this version
    var age: TimeInterval {
        return Date().timeIntervalSince(timestamp)
    }
    
    /// Check if this version is considered stale
    var isStale: Bool {
        let maxAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
        return age > maxAge
    }
}

// MARK: - Supporting Types

/// Metadata associated with a data version
struct DataVersionInfo: Codable {
    let versionId: UUID
    let timestamp: Date
}

struct VersionMetadata: Codable {
    let changeDescription: String
    let userInitiated: Bool
    let automaticBackup: Bool
    let isSystemGenerated: Bool
    let tags: [String]
    let confidence: Double // Confidence in the change accuracy
    let impact: ChangeImpact // Estimated impact of the change
    
    init(
        changeDescription: String,
        userInitiated: Bool,
        automaticBackup: Bool,
        isSystemGenerated: Bool = false,
        tags: [String] = [],
        confidence: Double = 1.0,
        impact: ChangeImpact = .medium
    ) {
        self.changeDescription = changeDescription
        self.userInitiated = userInitiated
        self.automaticBackup = automaticBackup
        self.isSystemGenerated = isSystemGenerated
        self.tags = tags
        self.confidence = confidence
        self.impact = impact
    }
}

/// Impact level of a change
enum ChangeImpact: String, Codable, CaseIterable {
    case low, medium, high, critical
    
    var weight: Double {
        switch self {
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 0.75
        case .critical: return 1.0
        }
    }
}

/// Delta data representing changes between versions
struct VersionDelta: Codable {
    let fromVersion: UUID
    let toVersion: UUID
    let operations: [DeltaOperation]
    let timestamp: Date
    let compressionMetadata: CompressionMetadata
}





/// Individual operation in a delta
struct DeltaOperation: Codable {
    let id: UUID
    let type: DeltaOperationType
    let targetId: UUID // Screenshot, relationship, etc.
    let field: String // Which field changed
    let oldValue: String? // Previous value (encoded)
    let newValue: String? // New value (encoded)
    let timestamp: Date
    
    init(type: DeltaOperationType, targetId: UUID, field: String, oldValue: String? = nil, newValue: String? = nil) {
        self.id = UUID()
        self.type = type
        self.targetId = targetId
        self.field = field
        self.oldValue = oldValue
        self.newValue = newValue
        self.timestamp = Date()
    }
}

/// Types of delta operations
enum DeltaOperationType: String, Codable, CaseIterable {
    case create, update, delete, move, merge
    
    var isReversible: Bool {
        switch self {
        case .create: return true // Can be deleted
        case .update: return true // Can be reverted
        case .delete: return true // Can be restored (if data preserved)
        case .move: return true // Can be moved back
        case .merge: return false // Complex merges may not be reversible
        }
    }
}

/// Compression metadata for delta optimization
struct CompressionMetadata: Codable {
    let algorithm: String
    let originalSize: Int
    let compressedSize: Int
    let compressionRatio: Double
    
    init() {
        self.algorithm = "gzip" // Default compression
        self.originalSize = 0
        self.compressedSize = 0
        self.compressionRatio = 1.0
    }
    
    init(algorithm: String, originalSize: Int, compressedSize: Int) {
        self.algorithm = algorithm
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.compressionRatio = originalSize > 0 ? Double(compressedSize) / Double(originalSize) : 1.0
    }
}

// MARK: - Version Chain Management

/// Represents a chain of versions for navigation and branching
class VersionChain {
    private var versions: [UUID: DataVersion] = [:]
    private var headVersionId: UUID?
    private var branches: [String: UUID] = ["main": UUID()] // Branch name -> head version
    
    /// Add a version to the chain
    func addVersion(_ version: DataVersion) {
        versions[version.versionId] = version
        
        // Update parent-child relationships
        if let parentId = version.parentVersionId,
           let parent = versions[parentId] {
            parent.nextVersionId = version.versionId
        }
        
        // Update branch head
        branches[version.branchName] = version.versionId
        
        if version.branchName == "main" {
            headVersionId = version.versionId
        }
    }
    
    /// Get the current head version
    func getHeadVersion(branch: String = "main") -> DataVersion? {
        guard let headId = branches[branch] else { return nil }
        return versions[headId]
    }
    
    /// Get parent version
    func getParent(of version: DataVersion) -> DataVersion? {
        guard let parentId = version.parentVersionId else { return nil }
        return versions[parentId]
    }
    
    /// Get child version
    func getChild(of version: DataVersion) -> DataVersion? {
        guard let childId = version.nextVersionId else { return nil }
        return versions[childId]
    }
    
    /// Get all versions in chronological order
    func getAllVersions() -> [DataVersion] {
        return versions.values.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Get version history for a specific branch
    func getHistory(for branch: String = "main", limit: Int = 50) -> [DataVersion] {
        guard let headId = branches[branch],
              let head = versions[headId] else { return [] }
        
        var history: [DataVersion] = [head]
        var current = head
        
        while let parentId = current.parentVersionId,
              let parent = versions[parentId],
              history.count < limit {
            history.append(parent)
            current = parent
        }
        
        return history
    }
    
    /// Create a new branch from a specific version
    func createBranch(name: String, fromVersion: DataVersion) {
        branches[name] = fromVersion.versionId
    }
    
    /// Merge a branch back into main
    func mergeBranch(_ branchName: String, into targetBranch: String = "main") -> DataVersion? {
        guard let branchHeadId = branches[branchName],
              let _ = versions[branchHeadId],
              let targetHeadId = branches[targetBranch],
              let _ = versions[targetHeadId] else { return nil }
        
        // Create merge version
        let mergeVersion = DataVersion(
            timestamp: Date(),
            versionId: UUID(),
            changeType: .bulkImport([]), // Placeholder for merge
            affectedNodes: [],
            checksum: "",
            metadata: VersionMetadata(
                changeDescription: "Merge branch '\(branchName)' into '\(targetBranch)'",
                userInitiated: true,
                automaticBackup: true
            ),
            parentVersionId: targetHeadId,
            branchName: targetBranch
        )
        
        mergeVersion.mergeParents = [branchHeadId, targetHeadId]
        
        addVersion(mergeVersion)
        
        return mergeVersion
    }
}

// MARK: - Data Extension for Compression

extension Data {
    func compressed() throws -> Data {
        return try (self as NSData).compressed(using: .lzfse) as Data
    }
    
    func decompressed() throws -> Data {
        return try (self as NSData).decompressed(using: .lzfse) as Data
    }
}