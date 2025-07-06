import SwiftUI
import Foundation
import os.log

@MainActor
class GlassCacheManager: ObservableObject {
    static let shared = GlassCacheManager()
    
    // MARK: - Cache Configuration
    private let maxCacheSize: Int = 50 * 1024 * 1024 // 50MB
    private let maxCacheEntries: Int = 1000
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    // MARK: - Cache Storage
    private var effectCache: [String: CachedGlassEffect] = [:]
    private var animationCache: [String: CachedAnimation] = [:]
    private var conversationStateCache: [String: CachedConversationState] = [:]
    private var resourceCache: [String: CachedResource] = [:]
    
    // MARK: - Cache Statistics
    @Published var cacheSize: Int = 0
    @Published var hitRate: Double = 0.0
    @Published var missCount: Int = 0
    @Published var hitCount: Int = 0
    @Published var evictionCount: Int = 0
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "GlassCache")
    
    // MARK: - Cache Entry Types
    
    private struct CachedGlassEffect {
        let id: String
        let effect: Data // Serialized effect data
        let size: CGSize
        let quality: GlassRenderingOptimizer.RenderingQuality
        let timestamp: Date
        let accessCount: Int
        let memorySize: Int
        
        func isExpired(expirationTime: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > expirationTime
        }
    }
    
    private struct CachedAnimation {
        let id: String
        let animationData: Data
        let duration: TimeInterval
        let effectType: String
        let timestamp: Date
        let accessCount: Int
        let memorySize: Int
        
        func isExpired(expirationTime: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > expirationTime
        }
    }
    
    private struct CachedConversationState {
        let id: String
        let state: ConversationState
        let timestamp: Date
        let accessCount: Int
        let memorySize: Int
        
        func isExpired(expirationTime: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > expirationTime
        }
    }
    
    private struct CachedResource {
        let id: String
        let resourceData: Data
        let resourceType: ResourceType
        let timestamp: Date
        let accessCount: Int
        let memorySize: Int
        
        func isExpired(expirationTime: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > expirationTime
        }
    }
    
    enum ResourceType: String, CaseIterable {
        case shader = "shader"
        case texture = "texture"
        case metal = "metal"
        case coreAnimation = "coreAnimation"
    }
    
    enum ConversationState: Codable {
        case ready
        case listening
        case processing
        case results
        case conversation
        case error
        
        var memorySize: Int {
            return MemoryLayout<ConversationState>.size
        }
    }
    
    private init() {
        setupCacheMonitoring()
        scheduleCleanup()
        logger.info("🗄️ Glass Cache Manager initialized with \(self.maxCacheSize / 1024 / 1024)MB limit")
    }
    
    // MARK: - Effect Caching
    
    func cacheGlassEffect(
        id: String,
        effect: Data,
        size: CGSize,
        quality: GlassRenderingOptimizer.RenderingQuality
    ) {
        let memorySize = effect.count
        
        // Check if we need to evict entries
        if shouldEvictForSize(memorySize) {
            evictLeastRecentlyUsed()
        }
        
        let cachedEffect = CachedGlassEffect(
            id: id,
            effect: effect,
            size: size,
            quality: quality,
            timestamp: Date(),
            accessCount: 0,
            memorySize: memorySize
        )
        
        effectCache[id] = cachedEffect
        updateCacheSize()
        
        logger.debug("💾 Cached Glass effect: \(id) (\(memorySize) bytes)")
    }
    
    func getCachedGlassEffect(
        id: String,
        size: CGSize,
        quality: GlassRenderingOptimizer.RenderingQuality
    ) -> Data? {
        guard let cached = effectCache[id] else {
            recordCacheMiss()
            return nil
        }
        
        // Check if cached effect matches requirements
        if cached.size != size || cached.quality != quality || cached.isExpired(expirationTime: cacheExpirationTime) {
            effectCache.removeValue(forKey: id)
            updateCacheSize()
            recordCacheMiss()
            return nil
        }
        
        // Update access count
        var updatedCache = cached
        updatedCache = CachedGlassEffect(
            id: cached.id,
            effect: cached.effect,
            size: cached.size,
            quality: cached.quality,
            timestamp: cached.timestamp,
            accessCount: cached.accessCount + 1,
            memorySize: cached.memorySize
        )
        effectCache[id] = updatedCache
        
        recordCacheHit()
        logger.debug("🎯 Cache hit for Glass effect: \(id)")
        return cached.effect
    }
    
    // MARK: - Animation Caching
    
    func cacheAnimation(
        id: String,
        animationData: Data,
        duration: TimeInterval,
        effectType: String
    ) {
        let memorySize = animationData.count
        
        if shouldEvictForSize(memorySize) {
            evictLeastRecentlyUsed()
        }
        
        let cachedAnimation = CachedAnimation(
            id: id,
            animationData: animationData,
            duration: duration,
            effectType: effectType,
            timestamp: Date(),
            accessCount: 0,
            memorySize: memorySize
        )
        
        animationCache[id] = cachedAnimation
        updateCacheSize()
        
        logger.debug("🎬 Cached animation: \(id) (\(memorySize) bytes)")
    }
    
    func getCachedAnimation(
        id: String,
        duration: TimeInterval,
        effectType: String
    ) -> Data? {
        guard let cached = animationCache[id] else {
            recordCacheMiss()
            return nil
        }
        
        if cached.duration != duration || cached.effectType != effectType || cached.isExpired(expirationTime: cacheExpirationTime) {
            animationCache.removeValue(forKey: id)
            updateCacheSize()
            recordCacheMiss()
            return nil
        }
        
        var updatedCache = cached
        updatedCache = CachedAnimation(
            id: cached.id,
            animationData: cached.animationData,
            duration: cached.duration,
            effectType: cached.effectType,
            timestamp: cached.timestamp,
            accessCount: cached.accessCount + 1,
            memorySize: cached.memorySize
        )
        animationCache[id] = updatedCache
        
        recordCacheHit()
        logger.debug("🎯 Cache hit for animation: \(id)")
        return cached.animationData
    }
    
    // MARK: - Conversation State Caching
    
    func cacheConversationState(id: String, state: ConversationState) {
        let memorySize = state.memorySize
        
        if shouldEvictForSize(memorySize) {
            evictLeastRecentlyUsed()
        }
        
        let cachedState = CachedConversationState(
            id: id,
            state: state,
            timestamp: Date(),
            accessCount: 0,
            memorySize: memorySize
        )
        
        conversationStateCache[id] = cachedState
        updateCacheSize()
        
        logger.debug("💬 Cached conversation state: \(id) -> \(String(describing: state))")
    }
    
    func getCachedConversationState(id: String) -> ConversationState? {
        guard let cached = conversationStateCache[id] else {
            recordCacheMiss()
            return nil
        }
        
        if cached.isExpired(expirationTime: cacheExpirationTime) {
            conversationStateCache.removeValue(forKey: id)
            updateCacheSize()
            recordCacheMiss()
            return nil
        }
        
        var updatedCache = cached
        updatedCache = CachedConversationState(
            id: cached.id,
            state: cached.state,
            timestamp: cached.timestamp,
            accessCount: cached.accessCount + 1,
            memorySize: cached.memorySize
        )
        conversationStateCache[id] = updatedCache
        
        recordCacheHit()
        logger.debug("🎯 Cache hit for conversation state: \(id)")
        return cached.state
    }
    
    // MARK: - Resource Caching
    
    func cacheResource(
        id: String,
        resourceData: Data,
        type: ResourceType
    ) {
        let memorySize = resourceData.count
        
        if shouldEvictForSize(memorySize) {
            evictLeastRecentlyUsed()
        }
        
        let cachedResource = CachedResource(
            id: id,
            resourceData: resourceData,
            resourceType: type,
            timestamp: Date(),
            accessCount: 0,
            memorySize: memorySize
        )
        
        resourceCache[id] = cachedResource
        updateCacheSize()
        
        logger.debug("🔧 Cached resource: \(id) (\(type.rawValue), \(memorySize) bytes)")
    }
    
    func getCachedResource(id: String, type: ResourceType) -> Data? {
        guard let cached = resourceCache[id] else {
            recordCacheMiss()
            return nil
        }
        
        if cached.resourceType != type || cached.isExpired(expirationTime: cacheExpirationTime) {
            resourceCache.removeValue(forKey: id)
            updateCacheSize()
            recordCacheMiss()
            return nil
        }
        
        var updatedCache = cached
        updatedCache = CachedResource(
            id: cached.id,
            resourceData: cached.resourceData,
            resourceType: cached.resourceType,
            timestamp: cached.timestamp,
            accessCount: cached.accessCount + 1,
            memorySize: cached.memorySize
        )
        resourceCache[id] = updatedCache
        
        recordCacheHit()
        logger.debug("🎯 Cache hit for resource: \(id)")
        return cached.resourceData
    }
    
    // MARK: - Cache Management
    
    private func shouldEvictForSize(_ newSize: Int) -> Bool {
        let totalSize = getCurrentCacheSize()
        let totalEntries = getTotalEntryCount()
        
        return (totalSize + newSize > maxCacheSize) || (totalEntries >= maxCacheEntries)
    }
    
    private func evictLeastRecentlyUsed() {
        var allEntries: [(String, Date, Int, Int)] = []
        
        // Collect all entries with their access patterns
        for (id, effect) in effectCache {
            allEntries.append((id, effect.timestamp, effect.accessCount, effect.memorySize))
        }
        for (id, animation) in animationCache {
            allEntries.append((id, animation.timestamp, animation.accessCount, animation.memorySize))
        }
        for (id, state) in conversationStateCache {
            allEntries.append((id, state.timestamp, state.accessCount, state.memorySize))
        }
        for (id, resource) in resourceCache {
            allEntries.append((id, resource.timestamp, resource.accessCount, resource.memorySize))
        }
        
        // Sort by access count (ascending) and timestamp (ascending)
        allEntries.sort { first, second in
            if first.2 == second.2 {
                return first.1 < second.1
            }
            return first.2 < second.2
        }
        
        // Evict entries until we have enough space
        let targetSize = maxCacheSize / 2 // Evict to 50% capacity
        var currentSize = getCurrentCacheSize()
        var evicted = 0
        
        for entry in allEntries {
            if currentSize <= targetSize { break }
            
            let entryId = entry.0
            let entrySize = entry.3
            
            // Remove from appropriate cache
            if effectCache.removeValue(forKey: entryId) != nil {
                currentSize -= entrySize
                evicted += 1
            } else if animationCache.removeValue(forKey: entryId) != nil {
                currentSize -= entrySize
                evicted += 1
            } else if conversationStateCache.removeValue(forKey: entryId) != nil {
                currentSize -= entrySize
                evicted += 1
            } else if resourceCache.removeValue(forKey: entryId) != nil {
                currentSize -= entrySize
                evicted += 1
            }
        }
        
        evictionCount += evicted
        updateCacheSize()
        
        logger.info("🗑️ Evicted \(evicted) cache entries, freed \((self.getCurrentCacheSize() - currentSize) / 1024)KB")
    }
    
    private func getCurrentCacheSize() -> Int {
        let effectSize = effectCache.values.reduce(0) { $0 + $1.memorySize }
        let animationSize = animationCache.values.reduce(0) { $0 + $1.memorySize }
        let stateSize = conversationStateCache.values.reduce(0) { $0 + $1.memorySize }
        let resourceSize = resourceCache.values.reduce(0) { $0 + $1.memorySize }
        
        return effectSize + animationSize + stateSize + resourceSize
    }
    
    private func getTotalEntryCount() -> Int {
        return effectCache.count + animationCache.count + conversationStateCache.count + resourceCache.count
    }
    
    private func updateCacheSize() {
        cacheSize = getCurrentCacheSize()
    }
    
    // MARK: - Cache Statistics
    
    private func recordCacheHit() {
        hitCount += 1
        updateHitRate()
    }
    
    private func recordCacheMiss() {
        missCount += 1
        updateHitRate()
    }
    
    private func updateHitRate() {
        let totalRequests = hitCount + missCount
        hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
    }
    
    // MARK: - Cache Cleanup
    
    private func setupCacheMonitoring() {
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        
        // Monitor thermal state
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleThermalStateChange()
            }
        }
    }
    
    private func scheduleCleanup() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.performPeriodicCleanup()
        }
    }
    
    private func performPeriodicCleanup() {
        let beforeSize = getCurrentCacheSize()
        var cleaned = 0
        
        // Remove expired entries
        effectCache = effectCache.filter { !$1.isExpired(expirationTime: cacheExpirationTime) }
        animationCache = animationCache.filter { !$1.isExpired(expirationTime: cacheExpirationTime) }
        conversationStateCache = conversationStateCache.filter { !$1.isExpired(expirationTime: cacheExpirationTime) }
        resourceCache = resourceCache.filter { !$1.isExpired(expirationTime: cacheExpirationTime) }
        
        let afterSize = getCurrentCacheSize()
        cleaned = beforeSize - afterSize
        
        updateCacheSize()
        
        if cleaned > 0 {
            logger.info("🧹 Periodic cleanup freed \(cleaned / 1024)KB")
        }
    }
    
    private func handleMemoryWarning() {
        logger.warning("⚠️ Memory warning received, performing aggressive cache cleanup")
        
        // Clear 75% of cache entries
        let targetSize = maxCacheSize / 4
        
        while getCurrentCacheSize() > targetSize && getTotalEntryCount() > 0 {
            evictLeastRecentlyUsed()
        }
        
        updateCacheSize()
    }
    
    private func handleThermalStateChange() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .serious, .critical:
            logger.warning("🔥 Thermal throttling, reducing cache size")
            
            // Reduce cache to 25% capacity during thermal stress
            let targetSize = maxCacheSize / 4
            
            while getCurrentCacheSize() > targetSize && getTotalEntryCount() > 0 {
                evictLeastRecentlyUsed()
            }
            
            updateCacheSize()
        default:
            break
        }
    }
    
    // MARK: - Public Interface
    
    func clearAllCaches() {
        effectCache.removeAll()
        animationCache.removeAll()
        conversationStateCache.removeAll()
        resourceCache.removeAll()
        
        updateCacheSize()
        logger.info("🗑️ All caches cleared")
    }
    
    func getCacheStatistics() -> CacheStatistics {
        return CacheStatistics(
            totalSize: cacheSize,
            maxSize: maxCacheSize,
            entryCount: getTotalEntryCount(),
            maxEntries: maxCacheEntries,
            hitRate: hitRate,
            hitCount: hitCount,
            missCount: missCount,
            evictionCount: evictionCount,
            effectCacheSize: effectCache.count,
            animationCacheSize: animationCache.count,
            conversationCacheSize: conversationStateCache.count,
            resourceCacheSize: resourceCache.count
        )
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let totalSize: Int
    let maxSize: Int
    let entryCount: Int
    let maxEntries: Int
    let hitRate: Double
    let hitCount: Int
    let missCount: Int
    let evictionCount: Int
    let effectCacheSize: Int
    let animationCacheSize: Int
    let conversationCacheSize: Int
    let resourceCacheSize: Int
    
    var utilizationPercentage: Double {
        return Double(totalSize) / Double(maxSize) * 100.0
    }
    
    var averageEntrySize: Double {
        return entryCount > 0 ? Double(totalSize) / Double(entryCount) : 0.0
    }
}