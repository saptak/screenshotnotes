import Foundation
import SwiftData
import SwiftUI

@MainActor
class LayoutCacheManager: ObservableObject {
    static let shared = LayoutCacheManager()
    
    // MARK: - Performance Targets
    // Based on MIND_MAP_PERFORMANCE_SPECIFICATION.md:
    // - Cache restoration: <200ms
    // - Cache hit rate: >90%
    // - Memory usage: <50MB
    
    // MARK: - Cache Layers
    private var memoryCache: [String: CachedMindMapLayoutData] = [:]
    private var cacheHitCount = 0
    private var cacheMissCount = 0
    private var modelContext: ModelContext?
    
    // MARK: - Memory Management
    private let maxMemoryCacheSize = 50 // layouts
    private let maxMemoryUsageBytes = 50 * 1024 * 1024 // 50MB
    
    // MARK: - Performance Monitoring
    @Published var cacheHitRate: Double = 0.0
    @Published var memoryUsage: Int = 0
    @Published var lastRestorationTime: TimeInterval = 0.0
    
    private init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Cache Operations
    
    /// Get cached layout for data fingerprint with <200ms target
    func getCachedLayout(for dataFingerprint: String) -> CachedMindMapLayoutData? {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            lastRestorationTime = (endTime - startTime) * 1000 // Convert to milliseconds
            print("🎯 Layout cache restoration time: \(lastRestorationTime)ms")
        }
        
        // Level 1: Memory Cache (fastest)
        if let layout = memoryCache[dataFingerprint] {
            cacheHitCount += 1
            updateCacheMetrics()
            print("✅ Memory cache hit for fingerprint: \(String(dataFingerprint.prefix(8)))...")
            return layout
        }
        
        // Level 2: Disk Cache (SwiftData persistence)
        if let persistedLayout = loadLayoutFromDisk(fingerprint: dataFingerprint) {
            // Promote to memory cache
            memoryCache[dataFingerprint] = persistedLayout
            enforceMemoryLimits()
            
            cacheHitCount += 1
            updateCacheMetrics()
            print("✅ Disk cache hit for fingerprint: \(String(dataFingerprint.prefix(8)))...")
            return persistedLayout
        }
        
        // Cache miss
        cacheMissCount += 1
        updateCacheMetrics()
        print("❌ Cache miss for fingerprint: \(String(dataFingerprint.prefix(8)))...")
        return nil
    }
    
    /// Save layout to cache with fingerprint
    func saveLayout(_ layout: CachedMindMapLayoutData, fingerprint: String) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Save to memory cache
        memoryCache[fingerprint] = layout
        enforceMemoryLimits()
        
        // Save to disk cache asynchronously
        Task.detached { [weak self] in
            await self?.saveLayoutToDisk(layout, fingerprint: fingerprint)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let saveTime = (endTime - startTime) * 1000
        print("💾 Layout saved to cache in \(saveTime)ms for fingerprint: \(String(fingerprint.prefix(8)))...")
    }
    
    /// Invalidate cache for specific region (2-degree separation)
    func invalidateRegion(nodeIds: [UUID]) {
        print("🔄 Invalidating cache region for \(nodeIds.count) nodes")
        
        // For now, clear memory cache entries that might be affected
        // In production, we would implement more sophisticated region detection
        let fingerprintsToRemove = memoryCache.keys.filter { fingerprint in
            // This is simplified - in production we'd track which nodes are in which fingerprints
            return true // For now, conservative invalidation
        }
        
        for fingerprint in fingerprintsToRemove {
            memoryCache.removeValue(forKey: fingerprint)
        }
        
        // Remove from disk cache asynchronously
        Task.detached { [weak self] in
            await self?.invalidateRegionOnDisk(nodeIds: nodeIds)
        }
        
        updateMemoryUsage()
    }
    
    /// Clear all cache
    func invalidateAll() {
        print("🗑️ Clearing all layout cache")
        memoryCache.removeAll()
        updateMemoryUsage()
        
        // Clear disk cache asynchronously
        Task.detached { [weak self] in
            await self?.clearDiskCache()
        }
    }
    
    // MARK: - Memory Management
    
    private func enforceMemoryLimits() {
        // Remove oldest entries if cache is too large
        while memoryCache.count > maxMemoryCacheSize {
            if let oldestKey = memoryCache.keys.first {
                memoryCache.removeValue(forKey: oldestKey)
            }
        }
        
        updateMemoryUsage()
        
        // Check memory pressure
        if memoryUsage > maxMemoryUsageBytes {
            // Remove half the cache to free memory
            let keysToRemove = Array(memoryCache.keys.prefix(memoryCache.count / 2))
            for key in keysToRemove {
                memoryCache.removeValue(forKey: key)
            }
            updateMemoryUsage()
            print("⚠️ Memory pressure: Reduced cache size to \(memoryCache.count) entries")
        }
    }
    
    private func updateMemoryUsage() {
        // Rough estimation of memory usage
        let estimatedBytesPerLayout = 1024 * 10 // ~10KB per layout (conservative estimate)
        memoryUsage = memoryCache.count * estimatedBytesPerLayout
    }
    
    private func updateCacheMetrics() {
        let totalRequests = cacheHitCount + cacheMissCount
        cacheHitRate = totalRequests > 0 ? Double(cacheHitCount) / Double(totalRequests) : 0.0
        
        if totalRequests % 10 == 0 && totalRequests > 0 {
            print("📊 Cache metrics - Hit rate: \(String(format: "%.1f", cacheHitRate * 100))%, Hits: \(cacheHitCount), Misses: \(cacheMissCount)")
        }
    }
    
    // MARK: - Disk Cache Operations
    
    private func loadLayoutFromDisk(fingerprint: String) -> CachedMindMapLayoutData? {
        guard let modelContext = modelContext else { return nil }
        
        do {
            let layouts = try modelContext.fetch(
                FetchDescriptor<CachedMindMapLayout>(
                    predicate: #Predicate<CachedMindMapLayout> { cached in
                        cached.dataFingerprint == fingerprint
                    }
                )
            )
            
            if let cachedLayout = layouts.first {
                // Check if cache is still valid (not older than 24 hours)
                let cacheAge = Date().timeIntervalSince(cachedLayout.timestamp)
                if cacheAge < 24 * 60 * 60 { // 24 hours
                    return CachedMindMapLayoutData(from: cachedLayout)
                } else {
                    // Remove expired cache
                    modelContext.delete(cachedLayout)
                    try? modelContext.save()
                }
            }
        } catch {
            print("❌ Failed to load layout from disk: \(error)")
        }
        
        return nil
    }
    
    private func saveLayoutToDisk(_ layout: CachedMindMapLayoutData, fingerprint: String) async {
        guard let modelContext = modelContext else { return }
        
        await MainActor.run {
            do {
                // Remove existing cache for this fingerprint
                let existingLayouts = try modelContext.fetch(
                    FetchDescriptor<CachedMindMapLayout>(
                        predicate: #Predicate<CachedMindMapLayout> { cached in
                            cached.dataFingerprint == fingerprint
                        }
                    )
                )
                
                for existing in existingLayouts {
                    modelContext.delete(existing)
                }
                
                // Save new layout
                let cachedLayout = CachedMindMapLayout(from: layout, fingerprint: fingerprint)
                modelContext.insert(cachedLayout)
                try modelContext.save()
                
                print("💾 Layout persisted to disk for fingerprint: \(String(fingerprint.prefix(8)))...")
            } catch {
                print("❌ Failed to save layout to disk: \(error)")
            }
        }
    }
    
    private func invalidateRegionOnDisk(nodeIds: [UUID]) async {
        guard let modelContext = modelContext else { return }
        
        await MainActor.run {
            do {
                // For now, clear all cached layouts (conservative approach)
                // In production, we'd track which layouts contain which nodes
                let allCachedLayouts = try modelContext.fetch(FetchDescriptor<CachedMindMapLayout>())
                
                for cached in allCachedLayouts {
                    modelContext.delete(cached)
                }
                
                try modelContext.save()
                print("🔄 Invalidated disk cache region for \(nodeIds.count) nodes")
            } catch {
                print("❌ Failed to invalidate disk cache region: \(error)")
            }
        }
    }
    
    private func clearDiskCache() async {
        guard let modelContext = modelContext else { return }
        
        await MainActor.run {
            do {
                let allCachedLayouts = try modelContext.fetch(FetchDescriptor<CachedMindMapLayout>())
                
                for cached in allCachedLayouts {
                    modelContext.delete(cached)
                }
                
                try modelContext.save()
                print("🗑️ Cleared all disk cache")
            } catch {
                print("❌ Failed to clear disk cache: \(error)")
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    func getPerformanceMetrics() -> LayoutCacheMetrics {
        return LayoutCacheMetrics(
            hitRate: cacheHitRate,
            hitCount: cacheHitCount,
            missCount: cacheMissCount,
            memoryUsage: memoryUsage,
            cacheSize: memoryCache.count,
            lastRestorationTime: lastRestorationTime
        )
    }
}

// MARK: - Supporting Types

struct CachedMindMapLayoutData {
    let id: UUID
    let nodes: [MindMapNode]
    let connections: [MindMapConnection]
    let centerPoint: CGPoint
    let zoomLevel: Double
    let timestamp: Date
    
    init(id: UUID = UUID(), nodes: [MindMapNode], connections: [MindMapConnection], centerPoint: CGPoint = .zero, zoomLevel: Double = 1.0) {
        self.id = id
        self.nodes = nodes
        self.connections = connections
        self.centerPoint = centerPoint
        self.zoomLevel = zoomLevel
        self.timestamp = Date()
    }
    
    init(from cached: CachedMindMapLayout) {
        self.id = cached.layoutId
        self.nodes = cached.decodedNodes
        self.connections = cached.decodedConnections
        self.centerPoint = CGPoint(x: cached.centerX, y: cached.centerY)
        self.zoomLevel = cached.zoomLevel
        self.timestamp = cached.timestamp
    }
}

// Using existing MindMapNode from Models/MindMapNode.swift

// Using existing MindMapConnection from Models/MindMapNode.swift

struct LayoutCacheMetrics {
    let hitRate: Double
    let hitCount: Int
    let missCount: Int
    let memoryUsage: Int
    let cacheSize: Int
    let lastRestorationTime: TimeInterval
    
    var meetsPerformanceTargets: Bool {
        return hitRate >= 0.9 && // >90% hit rate
               memoryUsage <= 50 * 1024 * 1024 && // <50MB memory
               lastRestorationTime <= 200 // <200ms restoration
    }
}

// MARK: - SwiftData Models

@Model
class CachedMindMapLayout {
    @Attribute(.unique) var layoutId: UUID
    var dataFingerprint: String
    var timestamp: Date
    var nodesData: Data
    var connectionsData: Data
    var centerX: Double
    var centerY: Double
    var zoomLevel: Double
    
    init(from layout: CachedMindMapLayoutData, fingerprint: String) {
        self.layoutId = layout.id
        self.dataFingerprint = fingerprint
        self.timestamp = layout.timestamp
        self.centerX = layout.centerPoint.x
        self.centerY = layout.centerPoint.y
        self.zoomLevel = layout.zoomLevel
        
        // Encode nodes and connections to Data
        do {
            self.nodesData = try JSONEncoder().encode(layout.nodes.map { EncodableNode(from: $0) })
            self.connectionsData = try JSONEncoder().encode(layout.connections.map { EncodableConnection(from: $0) })
        } catch {
            print("❌ Failed to encode layout data: \(error)")
            self.nodesData = Data()
            self.connectionsData = Data()
        }
    }
    
    var decodedNodes: [MindMapNode] {
        do {
            let encodableNodes = try JSONDecoder().decode([EncodableNode].self, from: nodesData)
            return encodableNodes.map { $0.toMindMapNode() }
        } catch {
            print("❌ Failed to decode nodes: \(error)")
            return []
        }
    }
    
    var decodedConnections: [MindMapConnection] {
        do {
            let encodableConnections = try JSONDecoder().decode([EncodableConnection].self, from: connectionsData)
            return encodableConnections.map { $0.toMindMapConnection() }
        } catch {
            print("❌ Failed to decode connections: \(error)")
            return []
        }
    }
}

// Helper types for JSON encoding/decoding
private struct EncodableNode: Codable {
    let id: UUID
    let screenshotId: UUID
    let x: Double
    let y: Double
    let radius: Double
    let title: String
    let subtitle: String
    let importance: Double
    
    init(from node: MindMapNode) {
        self.id = node.id
        self.screenshotId = node.screenshotId
        self.x = node.position.x
        self.y = node.position.y
        self.radius = node.radius
        self.title = node.title
        self.subtitle = node.subtitle
        self.importance = node.importance
    }
    
    func toMindMapNode() -> MindMapNode {
        var node = MindMapNode(screenshotId: screenshotId, position: CGPoint(x: x, y: y))
        node.radius = radius
        node.title = title
        node.subtitle = subtitle
        node.importance = importance
        return node
    }
}

private struct EncodableConnection: Codable {
    let id: UUID
    let sourceNodeId: UUID
    let targetNodeId: UUID
    let relationshipType: String
    let strength: Double
    let confidence: Double
    
    init(from connection: MindMapConnection) {
        self.id = connection.id
        self.sourceNodeId = connection.sourceNodeId
        self.targetNodeId = connection.targetNodeId
        self.relationshipType = connection.relationshipType.rawValue
        self.strength = connection.strength
        self.confidence = connection.confidence
    }
    
    func toMindMapConnection() -> MindMapConnection {
        return MindMapConnection(
            sourceNodeId: sourceNodeId,
            targetNodeId: targetNodeId,
            relationshipType: RelationshipType(rawValue: relationshipType) ?? .semantic,
            strength: strength,
            confidence: confidence
        )
    }
}