import Foundation
import SwiftData
import CryptoKit

@MainActor
class ChangeTrackingService: ObservableObject {
    static let shared = ChangeTrackingService()
    
    // MARK: - Performance Targets
    // Based on MIND_MAP_PERFORMANCE_SPECIFICATION.md:
    // - Data fingerprinting for selective invalidation
    // - Change detection and impact assessment
    // - Version tracking with conflict resolution
    
    // MARK: - State Management
    @Published var currentDataVersion: DataVersion?
    @Published var changeHistory: [DataChange] = []
    
    private var modelContext: ModelContext?
    private let fingerprintCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 100
        return cache
    }()
    
    // MARK: - Change Tracking
    private var lastKnownFingerprint: String?
    private var affectedNodeIds: Set<UUID> = []
    
    private init() {
        print("🔍 Change tracking service initialized")
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Data Fingerprinting
    
    /// Generate comprehensive fingerprint for current data state
    func createDataFingerprint() async -> String {
        let cacheKey = "current_fingerprint"
        
        // Check cache first for performance
        if let cachedFingerprint = fingerprintCache.object(forKey: NSString(string: cacheKey)) as String? {
            if await isDataUnchangedSinceFingerprint(cachedFingerprint) {
                return cachedFingerprint
            }
        }
        
        guard modelContext != nil else {
            let fallbackFingerprint = "empty-\(Date().timeIntervalSince1970)"
            print("⚠️ No model context available, using fallback fingerprint")
            return fallbackFingerprint
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Gather all relevant data for fingerprinting
        let screenshots = await fetchScreenshotsForFingerprint()
        let relationships = await fetchRelationshipsForFingerprint()
        
        // Create comprehensive fingerprint including:
        // 1. Screenshot data (IDs, timestamps, modification dates)
        // 2. Relationship data (entities, semantic tags, connections)
        // 3. User annotations and manual edits
        // 4. AI analysis versions and timestamps
        
        var fingerprintComponents: [String] = []
        
        // Screenshot fingerprint components
        for screenshot in screenshots {
            let component = createScreenshotComponent(screenshot)
            fingerprintComponents.append(component)
        }
        
        // Relationship fingerprint components
        for relationship in relationships {
            let component = createRelationshipComponent(relationship)
            fingerprintComponents.append(component)
        }
        
        // Global metadata
        let metadataComponent = await createMetadataComponent()
        fingerprintComponents.append(metadataComponent)
        
        // Generate SHA-256 hash
        let combinedData = fingerprintComponents.joined(separator: "|")
        let fingerprint = sha256Hash(from: combinedData)
        
        // Cache the result
        fingerprintCache.setObject(NSString(string: fingerprint), forKey: NSString(string: cacheKey))
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let computeTime = (endTime - startTime) * 1000
        
        print("🔍 Generated fingerprint in \(computeTime)ms: \(String(fingerprint.prefix(12)))...")
        
        return fingerprint
    }
    
    /// Create fingerprint for specific screenshots and relationships
    func createDataFingerprint(screenshots: [Screenshot], relationships: [EntityRelationship]) -> String {
        var components: [String] = []
        
        // Screenshot components
        for screenshot in screenshots.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            components.append(createScreenshotComponent(screenshot))
        }
        
        // Relationship components
        for relationship in relationships.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            components.append(createRelationshipComponent(relationship))
        }
        
        let combinedData = components.joined(separator: "|")
        return sha256Hash(from: combinedData)
    }
    
    // MARK: - Change Detection
    
    /// Detect changes since last known fingerprint
    func detectChangesSince(_ lastFingerprint: String) async -> DataChangeSet {
        let currentFingerprint = await createDataFingerprint()
        
        if currentFingerprint == lastFingerprint {
            return DataChangeSet(changes: [], hasChanges: false)
        }
        
        // Detailed change detection
        let changes = await performDetailedChangeDetection(from: lastFingerprint, to: currentFingerprint)
        
        print("🔍 Detected \(changes.count) changes since last fingerprint")
        
        return DataChangeSet(changes: changes, hasChanges: !changes.isEmpty)
    }
    
    /// Track a specific change and update affected nodes
    func trackChange(_ change: DataChange) {
        changeHistory.append(change)
        
        // Limit history to last 1000 changes
        if changeHistory.count > 1000 {
            changeHistory.removeFirst(changeHistory.count - 1000)
        }
        
        // Update affected nodes for selective invalidation
        updateAffectedNodes(for: change)
        
        // Clear fingerprint cache since data has changed
        fingerprintCache.removeAllObjects()
        
        print("🔍 Tracked change: \(change.type)")
    }
    
    /// Get changes that occurred after a specific version
    func getChangesSince(_ version: DataVersion) -> [DataChange] {
        return changeHistory.filter { change in
            change.timestamp > version.timestamp
        }
    }
    
    // MARK: - Selective Invalidation
    
    /// Determine which nodes are affected by a change for selective cache invalidation
    func getAffectedNodesForChange(_ change: DataChange) -> Set<UUID> {
        switch change.type {
        case .screenshotAdded(let id), .screenshotDeleted(let id), .screenshotModified(let id):
            // Node itself plus connected nodes (2-degree separation)
            return getExtendedNodeSet(for: id)
            
        case .relationshipAdded(let fromId, let toId), .relationshipDeleted(let fromId, let toId):
            // Both nodes and their immediate connections
            let fromSet = getExtendedNodeSet(for: fromId)
            let toSet = getExtendedNodeSet(for: toId)
            return fromSet.union(toSet)
            
        case .userAnnotationChanged(let id), .aiAnalysisUpdated(let id):
            // Conservative: immediate node and direct connections
            return getImmediateNodeSet(for: id)
            
        case .bulkImport(let ids):
            // All nodes in bulk import plus global connections
            return Set(ids).union(getGloballyConnectedNodes())
        }
    }
    
    /// Get current set of affected nodes for cache invalidation
    func getCurrentAffectedNodes() -> Set<UUID> {
        return affectedNodeIds
    }
    
    /// Clear affected nodes after cache invalidation
    func clearAffectedNodes() {
        affectedNodeIds.removeAll()
    }
    
    // MARK: - Version Management
    
    /// Create new data version snapshot
    func createDataVersion(changeType: ChangeType) -> DataVersion {
        let version = DataVersion(
            timestamp: Date(),
            versionId: UUID(),
            changeType: changeType,
            affectedNodes: Array(affectedNodeIds),
            checksum: lastKnownFingerprint ?? ""
        )
        
        currentDataVersion = version
        return version
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolve conflicts based on priority system
    func resolveConflicts(_ conflicts: [DataConflict]) -> ConflictResolution {
        var resolvedChanges: [DataChange] = []
        var rejectedChanges: [DataChange] = []
        
        for conflict in conflicts {
            let resolution = resolveIndividualConflict(conflict)
            resolvedChanges.append(contentsOf: resolution.acceptedChanges)
            rejectedChanges.append(contentsOf: resolution.rejectedChanges)
        }
        
        return ConflictResolution(
            acceptedChanges: resolvedChanges,
            rejectedChanges: rejectedChanges,
            resolutionStrategy: .priorityBased
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func createScreenshotComponent(_ screenshot: Screenshot) -> String {
        // Include all relevant screenshot data for fingerprinting
        let extractedTextHash = sha256Hash(from: screenshot.extractedText ?? "")
        let semanticTagsData = screenshot.semanticTags?.uniqueTagNames.sorted().joined(separator: ",") ?? ""
        let semanticTagsHash = sha256Hash(from: semanticTagsData)
        
        return [
            screenshot.id.uuidString,
            "\(screenshot.timestamp.timeIntervalSince1970)",
            "\(screenshot.lastSemanticAnalysis?.timeIntervalSince1970 ?? 0)",
            "\(screenshot.lastSemanticAnalysis?.timeIntervalSince1970 ?? 0)",
            String(extractedTextHash.prefix(16)), // Truncate for performance
            String(semanticTagsHash.prefix(16))
        ].joined(separator: ":")
    }
    
    private func createRelationshipComponent(_ relationship: EntityRelationship) -> String {
        return [
            relationship.id.uuidString,
            relationship.sourceScreenshotId.uuidString,
            relationship.targetScreenshotId?.uuidString ?? "",
            relationship.relationshipType,
            "\(relationship.confidence)",
            "\(relationship.timestamp.timeIntervalSince1970)"
        ].joined(separator: ":")
    }
    
    private func createMetadataComponent() async -> String {
        let screenshotCount = await getScreenshotCount()
        let relationshipCount = await getRelationshipCount()
        let lastModified = await getLastModificationTime()
        
        return [
            "screenshots:\(screenshotCount)",
            "relationships:\(relationshipCount)",
            "modified:\(lastModified)"
        ].joined(separator: ":")
    }
    
    private func fetchScreenshotsForFingerprint() async -> [Screenshot] {
        guard let modelContext = modelContext else { return [] }
        
        do {
            return try modelContext.fetch(FetchDescriptor<Screenshot>())
        } catch {
            print("❌ Failed to fetch screenshots for fingerprint: \(error)")
            return []
        }
    }
    
    private func fetchRelationshipsForFingerprint() async -> [EntityRelationship] {
        guard let modelContext = modelContext else { return [] }
        
        do {
            return try modelContext.fetch(FetchDescriptor<EntityRelationship>())
        } catch {
            print("❌ Failed to fetch relationships for fingerprint: \(error)")
            return []
        }
    }
    
    private func isDataUnchangedSinceFingerprint(_ fingerprint: String) async -> Bool {
        // Quick check if data has changed since fingerprint was created
        // This is a simplified check - in production would be more sophisticated
        let currentTime = Date().timeIntervalSince1970
        let fingerprintAge = currentTime - (Double(fingerprint.suffix(10)) ?? 0)
        
        // If fingerprint is less than 1 minute old, assume unchanged
        return fingerprintAge < 60
    }
    
    private func performDetailedChangeDetection(from oldFingerprint: String, to newFingerprint: String) async -> [DataChange] {
        // This would perform detailed diff analysis
        // For now, return empty array - full implementation would compare data structures
        return []
    }
    
    private func updateAffectedNodes(for change: DataChange) {
        let newAffectedNodes = getAffectedNodesForChange(change)
        affectedNodeIds.formUnion(newAffectedNodes)
    }
    
    private func getExtendedNodeSet(for nodeId: UUID) -> Set<UUID> {
        // Get node plus 2-degree separation
        // Simplified implementation - in production would use graph traversal
        var nodeSet: Set<UUID> = [nodeId]
        
        // Add immediate connections
        let immediateConnections = getImmediateConnections(for: nodeId)
        nodeSet.formUnion(immediateConnections)
        
        // Add second-degree connections
        for connectionId in immediateConnections {
            let secondDegreeConnections = getImmediateConnections(for: connectionId)
            nodeSet.formUnion(secondDegreeConnections)
        }
        
        return nodeSet
    }
    
    private func getImmediateNodeSet(for nodeId: UUID) -> Set<UUID> {
        // Get node plus immediate connections
        var nodeSet: Set<UUID> = [nodeId]
        nodeSet.formUnion(getImmediateConnections(for: nodeId))
        return nodeSet
    }
    
    private func getImmediateConnections(for nodeId: UUID) -> Set<UUID> {
        // Return immediately connected nodes
        // Simplified implementation
        return []
    }
    
    private func getGloballyConnectedNodes() -> Set<UUID> {
        // Return nodes that are highly connected (hubs)
        // Simplified implementation
        return []
    }
    
    private func resolveIndividualConflict(_ conflict: DataConflict) -> ConflictResolution {
        // Implement priority-based conflict resolution
        // 1. User manual edits (highest priority)
        // 2. Manual relationship creation/deletion
        // 3. User annotations and tags
        // 4. AI-generated relationships
        // 5. Automatic semantic analysis (lowest priority)
        
        let userChanges = conflict.changes.filter { isUserInitiated($0) }
        let aiChanges = conflict.changes.filter { !isUserInitiated($0) }
        
        // User changes always win
        return ConflictResolution(
            acceptedChanges: userChanges,
            rejectedChanges: aiChanges,
            resolutionStrategy: .userPriority
        )
    }
    
    private func isUserInitiated(_ change: DataChange) -> Bool {
        switch change.type {
        case .userAnnotationChanged:
            return true
        case .relationshipAdded, .relationshipDeleted:
            // Would check if user-initiated vs AI-initiated
            return false
        default:
            return false
        }
    }
    
    private func sha256Hash(from string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Data Fetching Helpers
    
    private func getScreenshotCount() async -> Int {
        guard let modelContext = modelContext else { return 0 }
        
        do {
            let screenshots = try modelContext.fetch(FetchDescriptor<Screenshot>())
            return screenshots.count
        } catch {
            return 0
        }
    }
    
    private func getRelationshipCount() async -> Int {
        guard let modelContext = modelContext else { return 0 }
        
        do {
            let relationships = try modelContext.fetch(FetchDescriptor<EntityRelationship>())
            return relationships.count
        } catch {
            return 0
        }
    }
    
    private func getLastModificationTime() async -> TimeInterval {
        guard let modelContext = modelContext else { return 0 }
        
        do {
            let screenshots = try modelContext.fetch(FetchDescriptor<Screenshot>())
            let lastScreenshotTime = screenshots.map { $0.timestamp.timeIntervalSince1970 }.max() ?? 0
            
            let relationships = try modelContext.fetch(FetchDescriptor<EntityRelationship>())
            let lastRelationshipTime = relationships.map { $0.timestamp.timeIntervalSince1970 }.max() ?? 0
            
            return max(lastScreenshotTime, lastRelationshipTime)
        } catch {
            return 0
        }
    }
}

// MARK: - Supporting Types

struct DataVersion {
    let timestamp: Date
    let versionId: UUID
    let changeType: ChangeType
    let affectedNodes: [UUID]
    let checksum: String
}

struct DataChangeSet {
    let changes: [DataChange]
    let hasChanges: Bool
    
    var affectedNodeIds: Set<UUID> {
        let nodeIds: Set<UUID> = []
        // Note: This is a simplified synchronous version
        // In practice, the main actor method would need to be called differently
        return nodeIds
    }
}

struct DataConflict {
    let conflictId: UUID
    let changes: [DataChange]
    let conflictType: ConflictType
    let timestamp: Date
    
    init(changes: [DataChange], conflictType: ConflictType) {
        self.conflictId = UUID()
        self.changes = changes
        self.conflictType = conflictType
        self.timestamp = Date()
    }
}

enum ConflictType {
    case simultaneousEdit
    case userVsAI
    case dataIntegrityViolation
    case versionMismatch
}

struct ConflictResolution {
    let acceptedChanges: [DataChange]
    let rejectedChanges: [DataChange]
    let resolutionStrategy: ResolutionStrategy
}

enum ResolutionStrategy {
    case userPriority
    case priorityBased
    case timestampBased
    case manualResolution
}

// MARK: - EntityRelationship Model (if not already defined)

@Model
class EntityRelationship {
    @Attribute(.unique) var id: UUID
    var sourceScreenshotId: UUID
    var targetScreenshotId: UUID?
    var relationshipType: String
    var confidence: Double
    var timestamp: Date
    var metadata: String?
    
    init(sourceScreenshotId: UUID, targetScreenshotId: UUID? = nil, relationshipType: String, confidence: Double, metadata: String? = nil) {
        self.id = UUID()
        self.sourceScreenshotId = sourceScreenshotId
        self.targetScreenshotId = targetScreenshotId
        self.relationshipType = relationshipType
        self.confidence = confidence
        self.timestamp = Date()
        self.metadata = metadata
    }
}