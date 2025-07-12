import Foundation
import SwiftData
import UIKit

@MainActor
class BackgroundLayoutProcessor: ObservableObject {
    static let shared = BackgroundLayoutProcessor()
    
    // MARK: - Performance Targets
    // Based on MIND_MAP_PERFORMANCE_SPECIFICATION.md:
    // - Background processing response: <2 seconds
    // - Non-blocking UI processing
    // - Priority-based queue management
    // - Resource adaptation (battery, memory, CPU)
    
    // MARK: - State Management
    @Published var isProcessing = false
    @Published var queueSize = 0
    @Published var lastProcessingTime: TimeInterval = 0.0
    @Published var processingHistory: [ProcessingMetric] = []
    
    private let layoutQueue = LayoutUpdateQueue()
    private let layoutCacheManager = LayoutCacheManager.shared
    private var modelContext: ModelContext?
    private var processingTask: Task<Void, Never>?
    
    // MARK: - Resource Management
    private var isLowPowerModeEnabled: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    private var memoryPressure: MemoryPressureLevel = .normal
    private var cpuUsageThreshold: Double = 0.1 // 10% CPU usage limit
    
    private init() {
        startMonitoringSystemResources()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Public Interface
    
    /// Schedule layout update with priority-based processing
    func scheduleLayoutUpdate(for change: DataChange, priority: ProcessingPriority = .newImport) {
        let task = LayoutTask(
            id: UUID(),
            change: change,
            priority: priority,
            timestamp: Date()
        )
        
        layoutQueue.enqueue(task, priority: priority)
        queueSize = layoutQueue.queueSize
        
        print("📋 Scheduled layout update - Priority: \(priority), Queue size: \(queueSize)")
        
        // Start processing if not already running
        if !isProcessing {
            startProcessing()
        }
    }
    
    /// Start background processing queue
    func startProcessing() {
        guard !isProcessing else { return }
        guard shouldAllowProcessing() else {
            print("⚠️ Processing paused due to resource constraints")
            return
        }
        
        isProcessing = true
        print("🚀 Starting background layout processing")
        
        processingTask = Task { [weak self] in
            await self?.processQueue()
        }
    }
    
    /// Pause processing for low battery/memory conditions
    func pauseProcessing() {
        print("⏸️ Pausing background layout processing")
        isProcessing = false
        processingTask?.cancel()
        processingTask = nil
    }
    
    /// Resume processing when resources are available
    func resumeProcessing() {
        guard shouldAllowProcessing() else { return }
        print("▶️ Resuming background layout processing")
        startProcessing()
    }
    
    /// Process the entire queue with resource monitoring
    private func processQueue() async {
        while isProcessing && layoutQueue.hasNextTask {
            // Check resource constraints before each task
            guard shouldAllowProcessing() else {
                print("⚠️ Resource constraints detected, pausing processing")
                pauseProcessing()
                break
            }
            
            // Process next task
            if let task = await layoutQueue.processNext() {
                await processLayoutTask(task)
                
                // Update queue size
                await MainActor.run {
                    queueSize = layoutQueue.queueSize
                }
                
                // Add delay between tasks to prevent CPU overload
                let delay = getAdaptiveDelay()
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        await MainActor.run {
            isProcessing = false
            print("✅ Background layout processing completed")
        }
    }
    
    // MARK: - Layout Processing
    
    private func processLayoutTask(_ task: LayoutTask) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("🔄 Processing layout task: \(task.change.type) (Priority: \(task.priority))")
        
        switch task.change.type {
        case .screenshotAdded(let screenshotId):
            await handleScreenshotAdded(screenshotId)
        case .screenshotDeleted(let screenshotId):
            await handleScreenshotDeleted(screenshotId)
        case .screenshotModified(let screenshotId):
            await handleScreenshotModified(screenshotId)
        case .relationshipAdded(let fromId, let toId):
            await handleRelationshipAdded(fromId: fromId, toId: toId)
        case .relationshipDeleted(let fromId, let toId):
            await handleRelationshipDeleted(fromId: fromId, toId: toId)
        case .userAnnotationChanged(let screenshotId):
            await handleUserAnnotationChanged(screenshotId)
        case .aiAnalysisUpdated(let screenshotId):
            await handleAIAnalysisUpdated(screenshotId)
        case .bulkImport(let screenshotIds):
            await handleBulkImport(screenshotIds)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTime = (endTime - startTime) * 1000 // milliseconds
        
        await MainActor.run {
            lastProcessingTime = processingTime
            recordProcessingMetric(task: task, processingTime: processingTime, success: true)
        }
        
        print("✅ Completed layout task in \(processingTime)ms")
    }
    
    // MARK: - Change Handlers
    
    private func handleScreenshotAdded(_ screenshotId: UUID) async {
        // Generate data fingerprint for current state
        let fingerprint = await generateDataFingerprint()
        
        // Check if layout is already cached
        if layoutCacheManager.getCachedLayout(for: fingerprint) != nil {
            print("✅ Layout already cached for new screenshot")
            return
        }
        
        // Calculate incremental layout update for single node addition
        await calculateIncrementalLayoutUpdate(
            changeType: .nodeAdded(screenshotId),
            affectedNodes: [screenshotId]
        )
    }
    
    private func handleScreenshotDeleted(_ screenshotId: UUID) async {
        // Find connected nodes for regional invalidation
        let connectedNodes = await getConnectedNodes(for: screenshotId)
        
        // Invalidate cache region (2-degree separation)
        layoutCacheManager.invalidateRegion(nodeIds: connectedNodes)
        
        // Recalculate layout for affected region
        await calculateIncrementalLayoutUpdate(
            changeType: .nodeRemoved(screenshotId),
            affectedNodes: connectedNodes
        )
    }
    
    private func handleScreenshotModified(_ screenshotId: UUID) async {
        // Check if modification affects relationships
        let connectedNodes = await getConnectedNodes(for: screenshotId)
        
        // Minimal recalculation - only if relationship structure changes
        await calculateIncrementalLayoutUpdate(
            changeType: .nodeModified(screenshotId),
            affectedNodes: [screenshotId] + connectedNodes
        )
    }
    
    private func handleRelationshipAdded(fromId: UUID, toId: UUID) async {
        // Regional update for relationship change
        let fromConnected = await getConnectedNodes(for: fromId)
        let toConnected = await getConnectedNodes(for: toId)
        let affectedNodes = [fromId, toId] + fromConnected + toConnected
        
        await calculateIncrementalLayoutUpdate(
            changeType: .relationshipAdded(fromId, toId),
            affectedNodes: Array(Set(affectedNodes)) // Remove duplicates
        )
    }
    
    private func handleRelationshipDeleted(fromId: UUID, toId: UUID) async {
        // Regional update for relationship removal
        let fromConnected = await getConnectedNodes(for: fromId)
        let toConnected = await getConnectedNodes(for: toId)
        let affectedNodes = [fromId, toId] + fromConnected + toConnected
        
        await calculateIncrementalLayoutUpdate(
            changeType: .relationshipRemoved(fromId, toId),
            affectedNodes: Array(Set(affectedNodes))
        )
    }
    
    private func handleUserAnnotationChanged(_ screenshotId: UUID) async {
        // User changes take precedence - minimal impact on layout
        _ = await generateDataFingerprint()
        
        // Only update if changes affect existing relationships
        if await doesAnnotationChangeAffectRelationships(screenshotId) {
            await calculateIncrementalLayoutUpdate(
                changeType: .nodeModified(screenshotId),
                affectedNodes: [screenshotId]
            )
        }
    }
    
    private func handleAIAnalysisUpdated(_ screenshotId: UUID) async {
        // Compare with existing relationships to determine impact
        let currentRelationships = await getCurrentRelationships(for: screenshotId)
        let newRelationships = await getNewAIRelationships(for: screenshotId)
        
        let diff = calculateRelationshipDiff(current: currentRelationships, new: newRelationships)
        
        if !diff.isEmpty {
            let affectedNodes = diff.flatMap { [$0.fromNodeId, $0.toNodeId] }
            await calculateIncrementalLayoutUpdate(
                changeType: .aiAnalysisUpdated(screenshotId),
                affectedNodes: Array(Set(affectedNodes))
            )
        }
    }
    
    private func handleBulkImport(_ screenshotIds: [UUID]) async {
        // For bulk import, generate completely new layout
        print("🔄 Handling bulk import of \(screenshotIds.count) screenshots")
        
        // Clear existing cache
        layoutCacheManager.invalidateAll()
        
        // Generate new layout for all screenshots
        await generateCompleteLayout()
    }
    
    // MARK: - Layout Calculation
    
    private func calculateIncrementalLayoutUpdate(changeType: LayoutChangeType, affectedNodes: [UUID]) async {
        guard !affectedNodes.isEmpty else { return }
        
        print("🎯 Calculating incremental layout update for \(affectedNodes.count) nodes")
        
        // Target: <100ms for single node, <500ms for regional (20 nodes)
        let targetTime = affectedNodes.count <= 1 ? 100.0 : 500.0
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Get current layout or generate new one
        let fingerprint = await generateDataFingerprint()
        var layout = layoutCacheManager.getCachedLayout(for: fingerprint)
        
        if layout == nil {
            layout = await generateLayoutForNodes(affectedNodes)
        }
        
        guard var currentLayout = layout else {
            print("❌ Failed to get or generate layout")
            return
        }
        
        // Apply incremental changes based on change type
        currentLayout = applyIncrementalChanges(to: currentLayout, changeType: changeType, affectedNodes: affectedNodes)
        
        // Save updated layout to cache
        let newFingerprint = await generateDataFingerprint()
        layoutCacheManager.saveLayout(currentLayout, fingerprint: newFingerprint)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTime = (endTime - startTime) * 1000
        
        print("✅ Incremental layout update completed in \(processingTime)ms (target: \(targetTime)ms)")
        
        // Warn if exceeding performance targets
        if processingTime > targetTime {
            print("⚠️ Layout update exceeded target time: \(processingTime)ms > \(targetTime)ms")
        }
    }
    
    private func generateCompleteLayout() async {
        print("🎯 Generating complete mind map layout")
        
        guard let modelContext = modelContext else { return }
        
        // Fetch all screenshot IDs
        let screenshotIDs = await fetchAllScreenshots()
        
        if screenshotIDs.count < 3 {
            print("ℹ️ Insufficient screenshots for mind map generation (\(screenshotIDs.count) < 3)")
            return
        }
        
        // Fetch full screenshot objects on the main actor
        let screenshots = await MainActor.run {
            screenshotIDs.compactMap { id in
                modelContext.model(for: id) as? Screenshot
            }
        }
        
        // Generate layout using force-directed algorithm
        let layout = await generateForceDirectedLayout(for: screenshotIDs)
        
        // Cache the layout
        let fingerprint = await generateDataFingerprint()
        layoutCacheManager.saveLayout(layout, fingerprint: fingerprint)
        
        print("✅ Complete layout generated for \(screenshots.count) screenshots")
    }
    
    // MARK: - Helper Methods
    
    private func applyIncrementalChanges(to layout: CachedMindMapLayoutData, changeType: LayoutChangeType, affectedNodes: [UUID]) -> CachedMindMapLayoutData {
        var updatedNodes = layout.nodes
        var updatedConnections = layout.connections
        
        switch changeType {
        case .nodeAdded(let nodeId):
            // Add new node with optimal position
            let newPosition = calculateOptimalPosition(for: nodeId, in: layout)
            let newNode = MindMapNode(screenshotId: nodeId, position: newPosition)
            updatedNodes.append(newNode)
            
        case .nodeRemoved(let nodeId):
            // Remove node and associated connections
            updatedNodes.removeAll { $0.screenshotId == nodeId }
            updatedConnections.removeAll { $0.sourceNodeId == nodeId || $0.targetNodeId == nodeId }
            
        case .nodeModified(let nodeId):
            // Update node properties if needed
            if updatedNodes.firstIndex(where: { $0.screenshotId == nodeId }) != nil {
                // Node properties might be updated based on new analysis
                // For now, keep position stable
            }
            
        case .relationshipAdded(let fromId, let toId):
            // Add new connection
            let newConnection = MindMapConnection(
                sourceNodeId: fromId,
                targetNodeId: toId,
                relationshipType: .semantic,
                strength: 0.5,
                confidence: 0.7
            )
            updatedConnections.append(newConnection)
            
        case .relationshipRemoved(let fromId, let toId):
            // Remove connection
            updatedConnections.removeAll { $0.sourceNodeId == fromId && $0.targetNodeId == toId }
            
        case .aiAnalysisUpdated(_):
            // Update relationships based on new AI analysis
            // This would involve complex diff logic - simplified for now
            break
        }
        
        return CachedMindMapLayoutData(
            id: UUID(),
            nodes: updatedNodes,
            connections: updatedConnections,
            centerPoint: layout.centerPoint,
            zoomLevel: layout.zoomLevel
        )
    }
    
    // MARK: - Data and Utility Methods
    
    private func generateDataFingerprint() async -> String {
        // Generate a fingerprint from screenshot IDs and timestamps
        
        let screenshotIDs = await fetchAllScreenshots()
        
        // Must be on main actor to access model properties
        let fingerprintData = await MainActor.run {
            screenshotIDs.compactMap { id in
                guard let screenshot = modelContext?.model(for: id) as? Screenshot else {
                    return nil
                }
                return "\(id)-\(screenshot.timestamp.timeIntervalSince1970)"
            }.joined(separator: "|")
        }
        
        return fingerprintData.md5Hash
    }
    
    private func fetchAllScreenshots() async -> [PersistentIdentifier] {
        guard let modelContext = modelContext else { return [] }
        
        return await MainActor.run {
            do {
                let screenshots = try modelContext.fetch(FetchDescriptor<Screenshot>())
                return screenshots.map { $0.persistentModelID }
            } catch {
                print("❌ Failed to fetch screenshots: \(error)")
                return []
            }
        }
    }
    
    private func getConnectedNodes(for nodeId: UUID) async -> [UUID] {
        // Return nodes within 2-degree separation
        // Simplified implementation - in production this would use graph traversal
        return []
    }
    
    private func calculateOptimalPosition(for nodeId: UUID, in layout: CachedMindMapLayoutData) -> CGPoint {
        // Calculate optimal position using force-directed layout principles
        // Simplified implementation
        let existingPositions = layout.nodes.map { $0.position }
        if existingPositions.isEmpty {
            return CGPoint(x: 0, y: 0)
        }
        
        // Find least crowded area
        let centerX = existingPositions.map { $0.x }.reduce(0, +) / Double(existingPositions.count)
        let centerY = existingPositions.map { $0.y }.reduce(0, +) / Double(existingPositions.count)
        
        // Add some randomness to avoid overlap
        let offset = Double.random(in: -100...100)
        return CGPoint(x: centerX + offset, y: centerY + offset)
    }
    
    private func generateLayoutForNodes(_ nodeIds: [UUID]) async -> CachedMindMapLayoutData? {
        // Generate basic layout for specific nodes
        let nodes = nodeIds.enumerated().map { index, id in
            MindMapNode(screenshotId: id, position: CGPoint(x: Double(index * 150), y: 0))
        }
        
        return CachedMindMapLayoutData(nodes: nodes, connections: [])
    }
    
    private func generateForceDirectedLayout(for screenshotIDs: [PersistentIdentifier]) async -> CachedMindMapLayoutData {
        // Implement force-directed layout algorithm
        // Simplified implementation for now
        
        guard let modelContext = modelContext else { return CachedMindMapLayoutData(nodes: [], connections: []) }
        
        let screenshots = await MainActor.run {
            screenshotIDs.compactMap { id in
                modelContext.model(for: id) as? Screenshot
            }
        }
        
        let nodes = screenshots.enumerated().map { index, screenshot in
            let angle = Double(index) * 2.0 * .pi / Double(screenshots.count)
            let radius = 200.0
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            
            var node = MindMapNode(screenshotId: screenshot.id, position: CGPoint(x: x, y: y))
            node.title = screenshot.filename
            return node
        }
        
        return CachedMindMapLayoutData(nodes: nodes, connections: [])
    }
    
    // MARK: - Relationship Management
    
    private func getCurrentRelationships(for screenshotId: UUID) async -> [RelationshipInfo] {
        // Fetch current relationships from data model
        return []
    }
    
    private func getNewAIRelationships(for screenshotId: UUID) async -> [RelationshipInfo] {
        // Get relationships from latest AI analysis
        return []
    }
    
    private func calculateRelationshipDiff(current: [RelationshipInfo], new: [RelationshipInfo]) -> [RelationshipChange] {
        // Calculate difference between relationship sets
        return []
    }
    
    private func doesAnnotationChangeAffectRelationships(_ screenshotId: UUID) async -> Bool {
        // Check if user annotation changes affect existing relationships
        return false
    }
    
    // MARK: - Resource Management
    
    private func shouldAllowProcessing() -> Bool {
        return !isLowPowerModeEnabled && 
               memoryPressure != .critical &&
               getCurrentCPUUsage() < cpuUsageThreshold
    }
    
    private func getAdaptiveDelay() -> TimeInterval {
        // Adapt delay based on system resources
        switch memoryPressure {
        case .normal:
            return 0.1 // 100ms
        case .warning:
            return 0.5 // 500ms
        case .critical:
            return 2.0 // 2 seconds
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage check
        // In production, this would use actual CPU monitoring
        return 0.05 // 5% (placeholder)
    }
    
    private func startMonitoringSystemResources() {
        // Monitor memory pressure
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.memoryPressure = .warning
                self?.pauseProcessing()
            }
        }
        
        // Monitor low power mode
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if ProcessInfo.processInfo.isLowPowerModeEnabled {
                    self?.pauseProcessing()
                } else {
                    self?.resumeProcessing()
                }
            }
        }
    }
    
    private func recordProcessingMetric(task: LayoutTask, processingTime: TimeInterval, success: Bool) {
        let metric = ProcessingMetric(
            taskId: task.id,
            changeType: task.change.type,
            priority: task.priority,
            processingTime: processingTime,
            success: success,
            timestamp: Date()
        )
        
        processingHistory.append(metric)
        
        // Keep only last 100 metrics
        if processingHistory.count > 100 {
            processingHistory.removeFirst(processingHistory.count - 100)
        }
    }
}

// MARK: - Supporting Types

enum ProcessingPriority: String, CaseIterable, Comparable {
    case userInteraction = "user"
    case newImport = "import"
    case optimization = "optimization"
    
    static func < (lhs: ProcessingPriority, rhs: ProcessingPriority) -> Bool {
        let order: [ProcessingPriority] = [.userInteraction, .newImport, .optimization]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

struct LayoutTask {
    let id: UUID
    let change: DataChange
    let priority: ProcessingPriority
    let timestamp: Date
}

// DataChange and ChangeType moved to DataConsistencyTypes.swift

enum LayoutChangeType {
    case nodeAdded(UUID)
    case nodeRemoved(UUID)
    case nodeModified(UUID)
    case relationshipAdded(UUID, UUID)
    case relationshipRemoved(UUID, UUID)
    case aiAnalysisUpdated(UUID)
}

enum MemoryPressureLevel {
    case normal
    case warning
    case critical
}

struct ProcessingMetric {
    let taskId: UUID
    let changeType: ChangeType
    let priority: ProcessingPriority
    let processingTime: TimeInterval
    let success: Bool
    let timestamp: Date
}

struct RelationshipInfo {
    let fromNodeId: UUID
    let toNodeId: UUID
    let relationshipType: String
    let strength: Double
}

struct RelationshipChange {
    let fromNodeId: UUID
    let toNodeId: UUID
    let changeType: ChangeType
}

// MARK: - Layout Update Queue

class LayoutUpdateQueue: @unchecked Sendable {
    private var tasks: [ProcessingPriority: [LayoutTask]] = [:]
    private let queue = DispatchQueue(label: "layout.update.queue", attributes: .concurrent)
    
    var queueSize: Int {
        return queue.sync {
            tasks.values.reduce(0) { $0 + $1.count }
        }
    }
    
    var hasNextTask: Bool {
        return queueSize > 0
    }
    
    func enqueue(_ task: LayoutTask, priority: ProcessingPriority) {
        queue.async(flags: .barrier) {
            if self.tasks[priority] == nil {
                self.tasks[priority] = []
            }
            self.tasks[priority]?.append(task)
        }
    }
    
    func processNext() async -> LayoutTask? {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                // Process highest priority tasks first
                for priority in ProcessingPriority.allCases.sorted() {
                    if var tasks = self.tasks[priority], !tasks.isEmpty {
                        let task = tasks.removeFirst()
                        if tasks.isEmpty {
                            self.tasks.removeValue(forKey: priority)
                        } else {
                            self.tasks[priority] = tasks
                        }
                        continuation.resume(returning: task)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }
        }
    }
    
    func clear(priority: ProcessingPriority) {
        queue.async(flags: .barrier) {
            self.tasks.removeValue(forKey: priority)
        }
    }
}

// MARK: - String Extension for MD5

extension String {
    var md5Hash: String {
        // Simplified hash - in production use CryptoKit
        return String(abs(self.hashValue))
    }
}