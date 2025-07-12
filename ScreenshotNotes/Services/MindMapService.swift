import Foundation
import SwiftUI
import SwiftData
import os.log

/// Service for creating and managing mind map visualizations of screenshot relationships
@MainActor
class MindMapService: ObservableObject {
    // MARK: - Performance Optimization Infrastructure
    private let layoutCacheManager = LayoutCacheManager.shared
    private let backgroundProcessor = BackgroundLayoutProcessor.shared
    private let changeTracker = ChangeTrackingService.shared
    
    // Track last data fingerprint to avoid unnecessary regeneration
    private var lastDataFingerprint: String?
    private var modelContext: ModelContext?
    
    /// Enhanced fingerprint computation using new performance infrastructure
    func computeDataFingerprint(screenshots: [Screenshot]) async -> String {
        // Use the new ChangeTrackingService for comprehensive fingerprinting
        return await changeTracker.createDataFingerprint()
    }

    /// Refresh mind map only if data has changed - Enhanced with performance optimization
    func refreshMindMapIfNeeded(screenshots: [Screenshot]) async {
        let newFingerprint = await computeDataFingerprint(screenshots: screenshots)
        
        // Check cache first for instant loading (<200ms target)
        if let cachedLayout = layoutCacheManager.getCachedLayout(for: newFingerprint) {
            await loadFromCachedLayout(cachedLayout)
            lastDataFingerprint = newFingerprint
            return
        }
        
        // If data changed or no cache, schedule background processing
        if newFingerprint != lastDataFingerprint {
            lastDataFingerprint = newFingerprint
            
            // Schedule background layout update with high priority for user-requested refresh
            backgroundProcessor.scheduleLayoutUpdate(
                for: DataChange(type: .bulkImport(screenshots.map { $0.id })),
                priority: .userInteraction
            )
            
            // For immediate response, generate simplified layout
            await generateSimplifiedLayout(from: screenshots)
        } else {
            // Just load from legacy cache for backward compatibility
            await loadFromCache()
        }
    }
    
    /// Check if this is the first time generating (no cached data)
    var isFirstTimeGeneration: Bool {
        guard let url = cacheURL else { return true }
        return !FileManager.default.fileExists(atPath: url.path)
    }
    // Cache file location
    private var cacheURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("mindmap_cache.json")
    }

    /// Load mind map data from cache (if available)
    func loadFromCache() async {
        guard let url = cacheURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let cached = try decoder.decode(MindMapData.self, from: data)
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.mindMapData = cached
                // Ensure all nodes are visible after loading from cache
                self.resetFocus()
                // Force update for SwiftUI
                self.mindMapData = self.mindMapData
                self.logger.info("✅ Mind map loaded from cache: \(cached.totalNodes) nodes, \(cached.totalConnections) connections")
            }
        } catch {
            logger.error("❌ Failed to load mind map cache: \(error.localizedDescription)")
        }
    }
    
    /// Return whether mind map has nodes to display
    var hasNodes: Bool {
        return mindMapData.totalNodes > 0
    }

    /// Save current mind map data to legacy cache
    func saveToCache() async {
        guard let url = self.cacheURL else { return }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self.mindMapData)
            try data.write(to: url, options: .atomic)
            self.logger.info("💾 Mind map saved to legacy cache: \(self.mindMapData.totalNodes) nodes, \(self.mindMapData.totalConnections) connections")
        } catch {
            self.logger.error("❌ Failed to save mind map cache: \(error.localizedDescription)")
        }
    }
    
    /// Save current mind map data to performance cache
    private func saveToPerformanceCache(screenshots: [Screenshot]) async {
        // Convert mind map data to layout format
        let layout = CachedMindMapLayoutData(
            nodes: mindMapData.nodeArray,
            connections: mindMapData.connections
        )
        
        let fingerprint = await computeDataFingerprint(screenshots: screenshots)
        
        layoutCacheManager.saveLayout(layout, fingerprint: fingerprint)
        logger.info("🚀 Mind map saved to performance cache with fingerprint: \(String(fingerprint.prefix(12)))...")
    }
    static let shared = MindMapService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "MindMap")
    private let entityRelationshipService = EntityRelationshipService.shared
    private let hapticService = HapticService.shared
    
    @Published var mindMapData = MindMapData()
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0.0
    @Published var selectedNodeId: UUID?
    @Published var hoveredNodeId: UUID?
    @Published var layoutProgress: Double = 0.0
    @Published var performanceMetrics = PerformanceMetrics()
    
    // Layout engine state
    private var layoutEngine: ForceDirectedLayoutEngine?
    private var generationTask: Task<Void, Never>?
    
    struct PerformanceMetrics {
        var nodesCount: Int = 0
        var connectionsCount: Int = 0
        var clustersCount: Int = 0
        var layoutTime: TimeInterval = 0
        var relationshipDiscoveryTime: TimeInterval = 0
        var renderingFPS: Double = 60.0
        var lastUpdated: Date = Date()
    }
    
    private init() {
        logger.info("🧠 MindMapService initialized with performance optimization")
        layoutEngine = ForceDirectedLayoutEngine()
    }
    
    /// Set model context for performance services
    func setModelContext(_ context: ModelContext) {
        modelContext = context
        layoutCacheManager.setModelContext(context)
        backgroundProcessor.setModelContext(context)
        changeTracker.setModelContext(context)
    }
    
    // MARK: - Main API
    
    /// Generate mind map from screenshots with performance optimization
    func generateMindMap(from screenshots: [Screenshot]) async {
        logger.info("🚀 Starting optimized mind map generation for \(screenshots.count) screenshots")
        
        // Check cache first
        let fingerprint = await computeDataFingerprint(screenshots: screenshots)
        if let cachedLayout = layoutCacheManager.getCachedLayout(for: fingerprint) {
            await loadFromCachedLayout(cachedLayout)
            logger.info("✅ Loaded mind map from cache in <200ms")
            return
        }
        
        // Cancel any existing generation
        generationTask?.cancel()
        
        // Schedule background processing for full layout
        backgroundProcessor.scheduleLayoutUpdate(
            for: DataChange(type: .bulkImport(screenshots.map { $0.id })),
            priority: .userInteraction
        )
        
        generationTask = Task<Void, Never> {
            await performMindMapGeneration(screenshots: screenshots)
        }
    }
    
    /// Load layout from cached data
    private func loadFromCachedLayout(_ layout: CachedMindMapLayoutData) async {
        // Convert cached layout to mind map data
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            
            // Update mind map data from cached layout
            self.mindMapData.nodes.removeAll()
            for node in layout.nodes {
                self.mindMapData.addNode(node)
            }
            
            // Update connections
            self.mindMapData.connections = layout.connections
            
            // Force update for SwiftUI
            self.mindMapData = self.mindMapData
            
            self.logger.info("📋 Loaded mind map from cached layout: \(layout.nodes.count) nodes")
        }
    }
    
    /// Generate simplified layout for immediate response
    private func generateSimplifiedLayout(from screenshots: [Screenshot]) async {
        logger.info("⚡ Generating simplified layout for immediate response")
        
        // Create basic circular layout for immediate display
        mindMapData.nodes.removeAll()
        
        let radius: CGFloat = 200
        for (index, screenshot) in screenshots.enumerated() {
            let angle = Double(index) * 2.0 * .pi / Double(screenshots.count)
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            
            let node = MindMapNode(
                screenshotId: screenshot.id,
                position: CGPoint(x: x, y: y)
            )
            
            mindMapData.addNode(node)
        }
        
        // Force update for SwiftUI
        mindMapData = mindMapData
        logger.info("⚡ Simplified layout ready with \(screenshots.count) nodes")
    }
    
    /// Handle data changes with selective updates
    func handleDataChange(_ change: DataChange) async {
        logger.info("🔄 Handling data change: \(String(describing: change.type))")
        
        // Track the change
        changeTracker.trackChange(change)
        
        // Get affected nodes for selective invalidation
        let affectedNodes = changeTracker.getAffectedNodesForChange(change)
        
        // Invalidate affected cache regions
        layoutCacheManager.invalidateRegion(nodeIds: Array(affectedNodes))
        
        // Schedule background processing based on change type
        let priority: ProcessingPriority = {
            switch change.type {
            case .userAnnotationChanged:
                return .userInteraction
            case .screenshotAdded, .screenshotDeleted:
                return .newImport
            default:
                return .optimization
            }
        }()
        
        backgroundProcessor.scheduleLayoutUpdate(for: change, priority: priority)
    }
    
    /// Update node position (for dragging) with performance optimization
    func updateNodePosition(nodeId: UUID, position: CGPoint) {
        // Safety checks to prevent crashes
        guard position.x.isFinite && position.y.isFinite else {
            logger.warning("⚠️ Invalid position provided: x=\(position.x), y=\(position.y)")
            return
        }
        
        // Ensure we're on the main actor for thread safety
        Task<Void, Never> { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Ensure mindMapData exists and is valid
            guard !self.mindMapData.nodes.isEmpty else {
                self.logger.warning("⚠️ No nodes available in mindMapData")
                return
            }
            
            // Safely access and update node
            guard var node = self.mindMapData.nodes[nodeId] else {
                self.logger.warning("⚠️ Node with ID \(nodeId) not found")
                return
            }
            
            // Update node properties safely
            node.position = position
            node.velocity = .zero // Stop physics simulation for dragged node
            
            // Safely update the dictionary
            self.mindMapData.nodes[nodeId] = node
            
            // Update layout engine without triggering full recalculation
            if let layoutEngine = self.layoutEngine {
                await layoutEngine.updateNodePosition(nodeId: nodeId, position: position)
            }
            
            // Handle cache invalidation for user manual positioning
            await self.handleDataChange(DataChange(type: .userAnnotationChanged(nodeId)))
        }
    }
    
    /// Start dragging a node (disables physics for smoother interaction)
    func startDraggingNode(nodeId: UUID) {
        Task<Void, Never> { @MainActor in
            guard !mindMapData.nodes.isEmpty else {
                logger.warning("⚠️ No nodes available for dragging")
                return
            }
            
            guard var node = mindMapData.nodes[nodeId] else {
                logger.warning("⚠️ Node with ID \(nodeId) not found for dragging")
                return
            }
            
            node.velocity = .zero
            node.isDragging = true
            mindMapData.nodes[nodeId] = node
        }
    }
    
    /// Stop dragging a node (re-enables physics)
    func stopDraggingNode(nodeId: UUID) {
        Task<Void, Never> { @MainActor in
            guard !mindMapData.nodes.isEmpty else {
                logger.warning("⚠️ No nodes available to stop dragging")
                return
            }
            
            guard var node = mindMapData.nodes[nodeId] else {
                logger.warning("⚠️ Node with ID \(nodeId) not found to stop dragging")
                return
            }
            
            node.isDragging = false
            mindMapData.nodes[nodeId] = node
        }
    }
    
    /// Select a node in the mind map
    func selectNode(nodeId: UUID?) {
        // Deselect previous node
        if let previousId = selectedNodeId {
            if var previousNode = mindMapData.nodes[previousId] {
                previousNode.isSelected = false
                mindMapData.nodes[previousId] = previousNode
            }
        }
        
        // Select new node
        selectedNodeId = nodeId
        if let nodeId = nodeId {
            if var node = mindMapData.nodes[nodeId] {
                node.isSelected = true
                mindMapData.nodes[nodeId] = node
            }
            
            // Haptic feedback
            hapticService.impact(.medium)
        }
    }
    
    /// Hover over a node (for desktop/trackpad interactions)
    func hoverNode(nodeId: UUID?) {
        hoveredNodeId = nodeId
    }
    
    /// Get screenshot for a node
    func getScreenshot(for nodeId: UUID, in screenshots: [Screenshot]) -> Screenshot? {
        guard let node = mindMapData.nodes[nodeId] else { return nil }
        return screenshots.first { $0.id == node.screenshotId }
    }
    
    /// Focus on a specific node (center view and highlight)
    func focusOnNode(nodeId: UUID) {
        selectNode(nodeId: nodeId)
        
        // Highlight connected nodes
        let connectedNodes = mindMapData.getConnectedNodes(for: nodeId)
        for connectedNode in connectedNodes {
            if var node = mindMapData.nodes[connectedNode.id] {
                node.scale = 1.2
                mindMapData.nodes[connectedNode.id] = node
            }
        }
        
        // Reset other nodes
        for (id, var node) in mindMapData.nodes {
            if id != nodeId && !connectedNodes.contains(where: { $0.id == id }) {
                node.scale = 0.8
                node.opacity = 0.6
                mindMapData.nodes[id] = node
            }
        }
    }
    
    /// Reset focus (restore all nodes to normal state)
    func resetFocus() {
        for (id, var node) in mindMapData.nodes {
            node.scale = 1.0
            node.opacity = 1.0
            mindMapData.nodes[id] = node
        }
        selectedNodeId = nil
    }
    
    // MARK: - Mind Map Generation Implementation
    
    private func performMindMapGeneration(screenshots: [Screenshot]) async {
        let startTime = Date()
        isGenerating = true
        generationProgress = 0.0
        
    do {
            // More aggressive memory management: Process screenshots in smaller batches for large datasets
            let maxScreenshots = 20 // Reduced from 50 to 20 to prevent memory issues
            let processingScreenshots = Array(screenshots.prefix(maxScreenshots))
            
            if screenshots.count > maxScreenshots {
                logger.warning("⚠️ Processing only first \(maxScreenshots) screenshots to prevent memory issues (total: \(screenshots.count))")
            }
            
            // Step 1: Discover relationships (30% of progress)
            logger.info("📊 Step 1: Discovering relationships")
            let relationshipStartTime = Date()
            let relationships = await entityRelationshipService.discoverRelationships(screenshots: processingScreenshots)
            let relationshipTime = Date().timeIntervalSince(relationshipStartTime)
            await MainActor.run { generationProgress = 0.3 }
            
            try Task.checkCancellation()
            
            // Step 2: Create nodes (20% of progress)
            logger.info("🔵 Step 2: Creating nodes")
            await createNodes(from: processingScreenshots)
            await MainActor.run { generationProgress = 0.5 }
            
            try Task.checkCancellation()
            
            // Step 3: Create connections (20% of progress)
            logger.info("🔗 Step 3: Creating connections")
            // Further limit connections to prevent visual clutter and performance issues
            let maxConnections = 50 // Reduced from 100 to 50
            let limitedRelationships = Array(relationships.prefix(maxConnections))
            await createConnections(from: limitedRelationships)
            await MainActor.run { generationProgress = 0.7 }
            
            try Task.checkCancellation()
            
            // Step 4: Perform layout (20% of progress)
            logger.info("📐 Step 4: Calculating layout")
            let layoutStartTime = Date()
            await performLayout()
            let layoutTime = Date().timeIntervalSince(layoutStartTime)
            await MainActor.run { generationProgress = 0.9 }
            
            try Task.checkCancellation()
            
            // Step 5: Create clusters (10% of progress)
            logger.info("🎯 Step 5: Creating clusters")
            await createClusters()
            await MainActor.run { generationProgress = 1.0 }
            
            let totalTime = Date().timeIntervalSince(startTime)
            
            // Update metrics
            await updatePerformanceMetrics(
                nodesCount: mindMapData.totalNodes,
                connectionsCount: mindMapData.totalConnections,
                clustersCount: mindMapData.clusters.count,
                layoutTime: layoutTime,
                relationshipDiscoveryTime: relationshipTime
            )
            
            logger.info("✅ Mind map generation completed in \(String(format: "%.2f", totalTime))s")
            logger.info("📈 Stats: \(self.mindMapData.totalNodes) nodes, \(self.mindMapData.totalConnections) connections, \(self.mindMapData.clusters.count) clusters")
            
            // Save to both legacy cache and new performance cache
            await saveToCache()
            await saveToPerformanceCache(screenshots: processingScreenshots)
            
            // Post notification that generation is complete
            NotificationCenter.default.post(name: .mindMapGenerationComplete, object: nil)
            
        } catch {
            if error is CancellationError {
                logger.info("⏹️ Mind map generation cancelled")
            } else {
                logger.error("❌ Mind map generation failed: \(error.localizedDescription)")
            }
        }
        
        isGenerating = false
    }
    
    private func createNodes(from screenshots: [Screenshot]) async {
    mindMapData.nodes.removeAll()
        
        // Use a centered coordinate system starting from (0,0)
        let canvasRadius: CGFloat = 300  // Radius for node placement
        
        // Use multiple rings to better distribute nodes and avoid overlap
        let nodesPerRing = max(6, min(12, screenshots.count / 3)) // 6-12 nodes per ring
        let ringCount = max(1, Int(ceil(Double(screenshots.count) / Double(nodesPerRing))))
        
        for (index, screenshot) in screenshots.enumerated() {
            let ringIndex = index / nodesPerRing
            let positionInRing = index % nodesPerRing
            let totalInThisRing = min(nodesPerRing, screenshots.count - ringIndex * nodesPerRing)
            
            // Calculate radius for this ring (smaller inner rings, larger outer rings)
            let baseRadius = canvasRadius / 3
            let ringRadius = baseRadius + CGFloat(ringIndex) * (baseRadius * 0.8)
            
            // Add some randomness to prevent perfect alignment
            let angleStep = 2.0 * .pi / Double(totalInThisRing)
            let baseAngle = Double(positionInRing) * angleStep
            let randomOffset = Double.random(in: -0.2...0.2) // Small random angle offset
            let angle = baseAngle + randomOffset
            
            // Add some random radius variation to make layout more organic
            let radiusVariation = CGFloat.random(in: -20...20)
            let finalRadius = ringRadius + radiusVariation
            
            // Position relative to center (0,0)
            let x = cos(angle) * finalRadius
            let y = sin(angle) * finalRadius
            
            var node = MindMapNode(
                screenshotId: screenshot.id,
                position: CGPoint(x: x, y: y)
            )
            
            // Set node properties based on screenshot content
            node.title = screenshot.filename
            node.subtitle = formatTimestamp(screenshot.timestamp)
            node.importance = calculateNodeImportance(screenshot)
            node.radius = CGFloat(25 + node.importance * 15) // 25-40 point radius for better spacing
            node.color = determineNodeColor(screenshot)
            
            // Memory optimization: Only store thumbnail data for very small images
            // Most thumbnails will be loaded on-demand to save memory
            if screenshot.imageData.count < 50 * 1024 { // Only for images < 50KB
                node.thumbnailData = screenshot.imageData
            }
            
            mindMapData.addNode(node)
            
            // Allow other tasks to run every 5 nodes
            if index % 5 == 0 {
                await Task.yield()
            }
        }
        
    logger.info("📍 Created \(screenshots.count) nodes in \(ringCount) rings")
    // Force update for SwiftUI
    mindMapData = mindMapData
    }
    
    private func createConnections(from relationships: [Relationship]) async {
    mindMapData.connections.removeAll()
        
        print("🔗 MindMapService: Creating connections from \(relationships.count) relationships")
        
        for relationship in relationships {
            // Find corresponding nodes
            let sourceNode = mindMapData.nodeArray.first { $0.screenshotId == relationship.sourceScreenshotId }
            let targetNode = mindMapData.nodeArray.first { $0.screenshotId == relationship.targetScreenshotId }
            
            guard let source = sourceNode, let target = targetNode else { 
                print("❌ MindMapService: Could not find nodes for relationship \(relationship.id) (source: \(relationship.sourceScreenshotId), target: \(relationship.targetScreenshotId))")
                continue 
            }
            
            let connection = MindMapConnection(
                sourceNodeId: source.id,
                targetNodeId: target.id,
                relationshipType: relationship.type,
                strength: relationship.strength,
                confidence: relationship.confidence
            )
            
            mindMapData.addConnection(connection)
            print("✅ MindMapService: Added connection from \(source.id) to \(target.id) with strength \(relationship.strength)")
        }
        
    print("🔗 MindMapService: Created \(mindMapData.connections.count) connections total")
    // Force update for SwiftUI
    mindMapData = mindMapData
    }
    
    private func performLayout() async {
        guard let layoutEngine = layoutEngine else { return }
        
        await MainActor.run { layoutProgress = 0.0 }
        
        // Configure layout engine
        await layoutEngine.configure(
            nodes: Array(mindMapData.nodes.values),
            connections: mindMapData.connections,
            bounds: CGRect(x: -400, y: -400, width: 800, height: 800) // Centered coordinate system
        )
        
        // Reduced iterations for memory efficiency
        let maxIterations = min(50, mindMapData.totalNodes * 2) // Adaptive iteration count
        
        for i in 0..<maxIterations {
            let updatedNodes = await layoutEngine.performIteration()
            
            // Update node positions
            for updatedNode in updatedNodes {
                mindMapData.nodes[updatedNode.id] = updatedNode
            }
            
            await MainActor.run { 
                layoutProgress = Double(i + 1) / Double(maxIterations)
            }
            
            // Allow UI updates every 5 iterations and yield to prevent blocking
            if i % 5 == 0 {
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps
            }
            
            // Early termination if layout converges
            if i > 10 && i % 10 == 0 {
                let convergenceCheck = await layoutEngine.checkConvergence()
                if convergenceCheck {
                    logger.debug("Layout converged early at iteration \(i)")
                    break
                }
            }
        }
        
    await MainActor.run { layoutProgress = 1.0 }
    // Force update for SwiftUI
    mindMapData = mindMapData
    }
    
    private func createClusters() async {
        mindMapData.clusters.removeAll()
        
        // Use simple connected component analysis for clustering
        var visitedNodes: Set<UUID> = []
        var clusterIndex = 0
        
        for (nodeId, _) in mindMapData.nodes {
            if visitedNodes.contains(nodeId) { continue }
            
            // Find all connected nodes using DFS
            let clusterNodes = findConnectedComponent(startingFrom: nodeId, visited: &visitedNodes)
            
            if clusterNodes.count >= 2 {
                let cluster = createCluster(from: clusterNodes, index: clusterIndex)
                mindMapData.clusters.append(cluster)
                clusterIndex += 1
            }
        }
        
        logger.info("Created \(self.mindMapData.clusters.count) clusters")
    }
    
    // MARK: - Helper Methods
    
    private func calculateNodeImportance(_ screenshot: Screenshot) -> Double {
        var importance = 0.5 // Base importance
        
        // Factor in text content length
        if let text = screenshot.extractedText {
            importance += min(0.3, Double(text.count) / 1000.0)
        }
        
        // Factor in object tags
        if let tags = screenshot.objectTags, !tags.isEmpty {
            importance += min(0.2, Double(tags.count) / 10.0)
        }
        
        return min(1.0, importance)
    }
    
    private func determineNodeColor(_ screenshot: Screenshot) -> Color {
        // Determine color based on content type
        if let text = screenshot.extractedText?.lowercased() {
            if text.contains("receipt") || text.contains("total") || text.contains("$") {
                return .green
            } else if text.contains("message") || text.contains("chat") {
                return .blue
            } else if text.contains("photo") || text.contains("image") {
                return .orange
            } else if text.contains("document") || text.contains("pdf") {
                return .purple
            }
        }
        
        return .blue // Default color
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func findConnectedComponent(startingFrom nodeId: UUID, visited: inout Set<UUID>) -> [UUID] {
        var component: [UUID] = []
        var stack: [UUID] = [nodeId]
        
        while !stack.isEmpty {
            let currentId = stack.removeLast()
            
            if visited.contains(currentId) { continue }
            visited.insert(currentId)
            component.append(currentId)
            
            // Find connected nodes
            let connectedNodes = mindMapData.getConnectedNodes(for: currentId)
            for connectedNode in connectedNodes {
                if !visited.contains(connectedNode.id) {
                    stack.append(connectedNode.id)
                }
            }
        }
        
        return component
    }
    
    private func createCluster(from nodeIds: [UUID], index: Int) -> MindMapCluster {
        let positions = nodeIds.compactMap { mindMapData.nodes[$0]?.position }
        
        // Calculate cluster center
        let centerX = positions.map { $0.x }.reduce(0, +) / CGFloat(positions.count)
        let centerY = positions.map { $0.y }.reduce(0, +) / CGFloat(positions.count)
        let center = CGPoint(x: centerX, y: centerY)
        
        // Calculate cluster radius
        let maxDistance = positions.map { center.distance(to: $0) }.max() ?? 50.0
        let radius = maxDistance + 30.0
        
        var cluster = MindMapCluster(title: "Cluster \(index + 1)", center: center)
        cluster.nodeIds = nodeIds
        cluster.radius = radius
        cluster.color = Color.random()
        cluster.importance = Double(nodeIds.count) / Double(mindMapData.totalNodes)
        
        return cluster
    }
    
    private func updatePerformanceMetrics(
        nodesCount: Int,
        connectionsCount: Int,
        clustersCount: Int,
        layoutTime: TimeInterval,
        relationshipDiscoveryTime: TimeInterval
    ) async {
        performanceMetrics.nodesCount = nodesCount
        performanceMetrics.connectionsCount = connectionsCount
        performanceMetrics.clustersCount = clustersCount
        performanceMetrics.layoutTime = layoutTime
        performanceMetrics.relationshipDiscoveryTime = relationshipDiscoveryTime
        performanceMetrics.lastUpdated = Date()
    }
}

// MARK: - Force-Directed Layout Engine

class ForceDirectedLayoutEngine {
    private var nodes: [UUID: MindMapNode] = [:]
    private var connections: [MindMapConnection] = []
    private var bounds: CGRect = CGRect(x: -400, y: -400, width: 800, height: 800)
    
    func configure(nodes: [MindMapNode], connections: [MindMapConnection], bounds: CGRect) async {
        self.nodes = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        self.connections = connections
        self.bounds = bounds
    }
    
    func performIteration() async -> [MindMapNode] {
        // Safety check to prevent crashes
        guard !nodes.isEmpty else { return [] }
        
        var updatedNodes = nodes
        
        // Apply forces to each node
        for (nodeId, node) in nodes {
            // Skip physics calculations for nodes being dragged
            if node.isDragging {
                continue
            }
            
            // Safety check for valid node position
            guard node.position.x.isFinite && node.position.y.isFinite else {
                continue
            }
            
            var totalForce = CGVector.zero
            
            // Repulsion forces from other nodes
            for (otherId, otherNode) in nodes {
                if nodeId != otherId {
                    // Safety check for other node position
                    guard otherNode.position.x.isFinite && otherNode.position.y.isFinite else {
                        continue
                    }
                    
                    let repulsion = calculateRepulsionForce(from: node, to: otherNode)
                    totalForce = totalForce.adding(repulsion)
                }
            }
            
            // Attraction forces from connected nodes
            let nodeConnections = connections.filter { $0.sourceNodeId == nodeId || $0.targetNodeId == nodeId }
            for connection in nodeConnections {
                let connectedNodeId = connection.sourceNodeId == nodeId ? connection.targetNodeId : connection.sourceNodeId
                if let connectedNode = nodes[connectedNodeId] {
                    // Safety check for connected node position
                    guard connectedNode.position.x.isFinite && connectedNode.position.y.isFinite else {
                        continue
                    }
                    
                    let attraction = calculateAttractionForce(from: node, to: connectedNode, strength: connection.strength)
                    totalForce = totalForce.adding(attraction)
                }
            }
            
            // Safety check for total force
            guard totalForce.dx.isFinite && totalForce.dy.isFinite else {
                continue
            }
            
            // Update velocity with damping
            var newVelocity = CGVector(
                dx: node.velocity.dx + totalForce.dx * PhysicsConstants.timeStep,
                dy: node.velocity.dy + totalForce.dy * PhysicsConstants.timeStep
            )
            newVelocity = CGVector(
                dx: newVelocity.dx * PhysicsConstants.dampingFactor,
                dy: newVelocity.dy * PhysicsConstants.dampingFactor
            )
            
            // Safety check for velocity
            guard newVelocity.dx.isFinite && newVelocity.dy.isFinite else {
                continue
            }
            
            // Update position
            var newPosition = CGPoint(
                x: node.position.x + newVelocity.dx * PhysicsConstants.timeStep,
                y: node.position.y + newVelocity.dy * PhysicsConstants.timeStep
            )
            
            // Safety check for new position
            guard newPosition.x.isFinite && newPosition.y.isFinite else {
                continue
            }
            
            // Keep within bounds
            newPosition = keepWithinBounds(newPosition)
            
            // Update node
            var updatedNode = node
            updatedNode.position = newPosition
            updatedNode.velocity = newVelocity
            updatedNodes[nodeId] = updatedNode
        }
        
        nodes = updatedNodes
        return Array(updatedNodes.values)
    }
    
    func updateNodePosition(nodeId: UUID, position: CGPoint) async {
        // Safety checks to prevent crashes
        guard position.x.isFinite && position.y.isFinite else {
            return
        }
        
        guard !nodes.isEmpty else {
            return
        }
        
        // Safely access and update node
        guard var node = nodes[nodeId] else {
            return
        }
        
        node.position = position
        node.velocity = .zero
        nodes[nodeId] = node
    }
    
    func checkConvergence() async -> Bool {
        // Check if the system has converged (low total kinetic energy)
        let totalKineticEnergy = nodes.values.reduce(0.0) { total, node in
            let velocityMagnitude = sqrt(node.velocity.dx * node.velocity.dx + node.velocity.dy * node.velocity.dy)
            return total + velocityMagnitude
        }
        
        let averageKineticEnergy = totalKineticEnergy / Double(nodes.count)
        return averageKineticEnergy < PhysicsConstants.convergenceThreshold
    }
    
    private func calculateRepulsionForce(from node1: MindMapNode, to node2: MindMapNode) -> CGVector {
        let distance = node1.position.distance(to: node2.position)
        
        // Safety checks to prevent crashes
        guard distance.isFinite && distance > 0.001 else { return .zero }
        
        let minDistance = node1.radius + node2.radius + PhysicsConstants.minimumDistance
        
        if distance < minDistance {
            let direction = node1.position.direction(to: node2.position)
            
            // Safety check for valid direction
            guard direction.dx.isFinite && direction.dy.isFinite else { return .zero }
            
            let force = PhysicsConstants.defaultRepulsionStrength / (distance * distance + 1)
            
            // Safety check for valid force
            guard force.isFinite else { return .zero }
            
            let result = direction.scaled(by: -force) // Negative for repulsion
            
            // Final safety check
            guard result.dx.isFinite && result.dy.isFinite else { return .zero }
            
            return result
        }
        
        return .zero
    }
    
    private func calculateAttractionForce(from node1: MindMapNode, to node2: MindMapNode, strength: Double) -> CGVector {
        let distance = node1.position.distance(to: node2.position)
        
        // Safety checks to prevent crashes
        guard distance.isFinite && distance > 0.001 else { return .zero }
        guard strength.isFinite && strength > 0 else { return .zero }
        
        let optimalDistance = PhysicsConstants.maximumDistance * strength
        
        if distance > optimalDistance {
            let direction = node1.position.direction(to: node2.position)
            
            // Safety check for valid direction
            guard direction.dx.isFinite && direction.dy.isFinite else { return .zero }
            
            let force = PhysicsConstants.defaultAttractionStrength * strength * (distance - optimalDistance)
            
            // Safety check for valid force
            guard force.isFinite else { return .zero }
            
            let result = direction.scaled(by: force)
            
            // Final safety check
            guard result.dx.isFinite && result.dy.isFinite else { return .zero }
            
            return result
        }
        
        return .zero
    }
    
    private func keepWithinBounds(_ position: CGPoint) -> CGPoint {
        // Safety checks for bounds
        guard bounds.width > 0 && bounds.height > 0 else { return position }
        
        let clampedX = max(bounds.minX, min(bounds.maxX, position.x))
        let clampedY = max(bounds.minY, min(bounds.maxY, position.y))
        
        // Final safety check
        guard clampedX.isFinite && clampedY.isFinite else { return position }
        
        return CGPoint(x: clampedX, y: clampedY)
    }
}

// MARK: - Geometry Extensions

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Safety check for valid distance
        return distance.isFinite ? distance : 0.0
    }
    
    func direction(to other: CGPoint) -> CGVector {
        let distance = distance(to: other)
        
        // Safety checks
        guard distance > 0.001 && distance.isFinite else { return .zero }
        
        let dx = (other.x - x) / distance
        let dy = (other.y - y) / distance
        
        // Safety check for valid direction components
        guard dx.isFinite && dy.isFinite else { return .zero }
        
        return CGVector(dx: dx, dy: dy)
    }
    
    func adding(_ vector: CGVector) -> CGPoint {
        let newX = x + vector.dx
        let newY = y + vector.dy
        
        // Safety check for valid coordinates
        guard newX.isFinite && newY.isFinite else { return self }
        
        return CGPoint(x: newX, y: newY)
    }
    
    func scaled(by factor: Double) -> CGPoint {
        let newX = x * factor
        let newY = y * factor
        
        // Safety check for valid coordinates
        guard newX.isFinite && newY.isFinite else { return self }
        
        return CGPoint(x: newX, y: newY)
    }
}

extension CGVector {
    func adding(_ other: CGVector) -> CGVector {
        let newDx = dx + other.dx
        let newDy = dy + other.dy
        
        // Safety check for valid components
        guard newDx.isFinite && newDy.isFinite else { return self }
        
        return CGVector(dx: newDx, dy: newDy)
    }
    
    func scaled(by factor: Double) -> CGVector {
        let newDx = dx * factor
        let newDy = dy * factor
        
        // Safety check for valid components
        guard newDx.isFinite && newDy.isFinite else { return self }
        
        return CGVector(dx: newDx, dy: newDy)
    }
    
    static var zero: CGVector {
        return CGVector(dx: 0, dy: 0)
    }
}

extension Color {
    static func random() -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo, .teal, .cyan]
        return colors.randomElement() ?? .blue
    }
}

extension Notification.Name {
    static let mindMapGenerationComplete = Notification.Name("mindMapGenerationComplete")
}