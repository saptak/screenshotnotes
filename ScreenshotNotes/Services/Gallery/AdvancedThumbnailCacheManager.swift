import Foundation
import UIKit

/// Advanced thumbnail cache manager with multi-tier caching system
/// Phase 2: Enhanced with intelligent LRU hierarchy and thread-safe coordination
@MainActor
class AdvancedThumbnailCacheManager {
    
    // MARK: - Singleton
    static let shared = AdvancedThumbnailCacheManager()
    
    // MARK: - Properties
    
    /// Hot cache - frequently accessed thumbnails (in-memory)
    private var hotCache: [String: CachedThumbnailEntry] = [:]
    
    /// Warm cache - recently accessed thumbnails (in-memory)
    private var warmCache: [String: CachedThumbnailEntry] = [:]
    
    /// Cold cache - file system cache (paths only)
    private var coldCache: [String: String] = [:]
    
    /// Performance configuration - Phase 2 enhanced with adaptive limits
    private var maxHotCacheSize: Int = 50
    private var maxWarmCacheSize: Int = 200
    private var maxColdCacheSize: Int = 1000
    private var maxMemoryUsageBytes: Int = 50 * 1024 * 1024 // 50MB
    
    /// Phase 2: Collection-aware cache sizing
    private var collectionSize: Int = 0
    private var adaptiveCachingEnabled = true
    
    /// Performance targets
    private let targetLoadTime: TimeInterval = 0.2 // 200ms
    private let targetCacheHitRate: Double = 0.9 // 90%
    
    /// Performance metrics - Phase 2 enhanced
    private var cacheHitCount: Int = 0
    private var cacheMissCount: Int = 0
    private var cacheHitRate: Double = 0.0
    private var hotCacheHits: Int = 0
    private var warmCacheHits: Int = 0
    private var coldCacheHits: Int = 0
    private var hotCacheHitRate: Double = 0.0
    private var warmCacheHitRate: Double = 0.0
    private var coldCacheHitRate: Double = 0.0
    
    /// Phase 2: Enhanced LRU metrics
    private var lruEvictionCount: Int = 0
    private var cachePromotionCount: Int = 0
    private var cacheDemotionCount: Int = 0
    
    /// Memory usage tracking
    private var memoryUsage: Int = 0
    private var lastLoadTime: TimeInterval = 0
    
    /// File system management
    private let fileManager = FileManager.default
    private let thumbnailsDirectory: URL
    
    /// Phase 2: Thread-safe coordination
    private let cacheQueue = DispatchQueue(label: "com.screenshotnotes.cache", qos: .userInitiated, attributes: .concurrent)
    private var isOptimizing = false
    
    // MARK: - Initialization
    
    private init() {
        // Create thumbnails directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        thumbnailsDirectory = documentsPath.appendingPathComponent("AdvancedThumbnails")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        
        // Load existing cache index
        loadColdCacheIndex()
        
        // Phase 2: Initialize adaptive caching
        optimizeCacheSizesForCollection(size: 0)
    }
    
    // MARK: - Phase 2: Collection-Aware Cache Management
    
    /// Update cache configuration based on collection size
    func updateCollectionSize(_ size: Int) {
        collectionSize = size
        if adaptiveCachingEnabled {
            optimizeCacheSizesForCollection(size: size)
        }
    }
    
    /// Get current collection size for intelligent cache management
    func getCollectionSize() -> Int {
        return collectionSize
    }
    
    /// Optimize cache sizes based on collection size and device capabilities
    private func optimizeCacheSizesForCollection(size: Int) {
        // Prevent race conditions during optimization
        guard !isOptimizing else { return }
        isOptimizing = true
        defer { isOptimizing = false }
        
        let deviceMemory = ProcessInfo.processInfo.physicalMemory
        let isLowMemoryDevice = deviceMemory < 4_000_000_000 // < 4GB
        
        switch size {
        case 0..<100:
            // Small collection - conservative settings
            maxHotCacheSize = isLowMemoryDevice ? 30 : 50
            maxWarmCacheSize = isLowMemoryDevice ? 120 : 200
            maxColdCacheSize = isLowMemoryDevice ? 600 : 1000
            maxMemoryUsageBytes = isLowMemoryDevice ? 30 * 1024 * 1024 : 50 * 1024 * 1024
            
        case 100..<500:
            // Medium collection - balanced settings
            maxHotCacheSize = isLowMemoryDevice ? 40 : 75
            maxWarmCacheSize = isLowMemoryDevice ? 150 : 300
            maxColdCacheSize = isLowMemoryDevice ? 800 : 1500
            maxMemoryUsageBytes = isLowMemoryDevice ? 40 * 1024 * 1024 : 75 * 1024 * 1024
            
        case 500..<1000:
            // Large collection - aggressive caching
            maxHotCacheSize = isLowMemoryDevice ? 50 : 100
            maxWarmCacheSize = isLowMemoryDevice ? 200 : 400
            maxColdCacheSize = isLowMemoryDevice ? 1000 : 2000
            maxMemoryUsageBytes = isLowMemoryDevice ? 50 * 1024 * 1024 : 100 * 1024 * 1024
            
        default:
            // Very large collection - maximum caching with careful management
            maxHotCacheSize = isLowMemoryDevice ? 60 : 150
            maxWarmCacheSize = isLowMemoryDevice ? 250 : 500
            maxColdCacheSize = isLowMemoryDevice ? 1200 : 3000
            maxMemoryUsageBytes = isLowMemoryDevice ? 60 * 1024 * 1024 : 150 * 1024 * 1024
        }
        
        print("📊 Adaptive cache sizing for \(size) screenshots:")
        print("   Hot: \(maxHotCacheSize), Warm: \(maxWarmCacheSize), Cold: \(maxColdCacheSize)")
        print("   Memory limit: \(maxMemoryUsageBytes / 1024 / 1024)MB")
        
        // Enforce new limits immediately
        enforceMemoryLimits()
    }
    
    // MARK: - Cache Operations
    
    /// Get thumbnail from cache or generate if needed - Phase 2 enhanced with thread safety
    func getThumbnail(for screenshotId: UUID, size: CGSize) async -> UIImage? {
        let startTime = CACurrentMediaTime()
        let cacheKey = generateCacheKey(screenshotId: screenshotId, size: size)
        
        // Check hot cache first - with thread-safe access tracking
        if let entry = hotCache[cacheKey] {
            // Thread-safe access pattern
            await updateEntryAccess(entry)
            cacheHitCount += 1
            hotCacheHits += 1
            updateCacheMetrics()
            
            lastLoadTime = CACurrentMediaTime() - startTime
            return entry.image
        }
        
        // Check warm cache - with intelligent promotion
        if let entry = warmCache[cacheKey] {
            // Thread-safe access pattern
            await updateEntryAccess(entry)
            cacheHitCount += 1
            warmCacheHits += 1
            
            // Phase 2: Enhanced promotion logic based on access patterns
            if shouldPromoteToHotCache(entry) {
                promoteToHotCache(cacheKey: cacheKey, entry: entry)
                cachePromotionCount += 1
            }
            
            updateCacheMetrics()
            lastLoadTime = CACurrentMediaTime() - startTime
            return entry.image
        }
        
        // Check cold cache (file system)
        if let filePath = coldCache[cacheKey] {
            if let image = UIImage(contentsOfFile: filePath) {
                cacheHitCount += 1
                coldCacheHits += 1
                
                // Promote to warm cache
                let entry = CachedThumbnailEntry(
                    image: image,
                    size: size,
                    lastAccessTime: Date(),
                    accessCount: 1
                )
                warmCache[cacheKey] = entry
                
                updateCacheMetrics()
                lastLoadTime = CACurrentMediaTime() - startTime
                return image
            }
        }
        
        // Cache miss - will be handled by BackgroundThumbnailProcessor
        cacheMissCount += 1
        updateCacheMetrics()
        
        return nil
    }
    
    /// Store thumbnail in cache
    func storeThumbnail(_ image: UIImage, for screenshotId: UUID, size: CGSize) {
        let cacheKey = generateCacheKey(screenshotId: screenshotId, size: size)
        
        let entry = CachedThumbnailEntry(
            image: image,
            size: size,
            lastAccessTime: Date(),
            accessCount: 1
        )
        
        // Store in hot cache initially
        hotCache[cacheKey] = entry
        
        // Enforce cache limits
        enforceMemoryLimits()
        
        // Save to disk asynchronously
        Task {
            await saveThumbnailToDisk(image, cacheKey: cacheKey)
        }
    }
    
    /// Remove thumbnail from cache
    func removeThumbnail(for screenshotId: UUID) {
        let keyPrefix = screenshotId.uuidString
        
        // Remove from all cache tiers
        hotCache.removeValue(forKey: keyPrefix)
        warmCache.removeValue(forKey: keyPrefix)
        coldCache.removeValue(forKey: keyPrefix)
        
        // Remove from disk
        Task {
            await removeThumbnailFilesFromDisk(screenshotId: screenshotId)
        }
    }
    
    /// Clear all cache tiers
    func clearAllCaches() {
        hotCache.removeAll()
        warmCache.removeAll()
        coldCache.removeAll()
        
        // Clear disk cache
        Task {
            do {
                let files = try fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil)
                for file in files {
                    try fileManager.removeItem(at: file)
                }
            } catch {
                print("❌ Failed to clear disk cache: \(error)")
            }
        }
        
        updateMemoryUsage()
        print("🧹 All advanced caches cleared")
    }
    
    /// Phase 2: Enhanced memory pressure optimization with intelligent graduated response
    func optimizeForMemoryPressure(level: ThumbnailMemoryPressureLevel) {
        // Prevent concurrent optimization to avoid race conditions
        guard !isOptimizing else { return }
        isOptimizing = true
        defer { isOptimizing = false }
        
        let beforeMemory = memoryUsage
        
        switch level {
        case .normal:
            // Standard cache management with collection-aware optimization
            enforceMemoryLimits()
            
        case .warning:
            // Intelligent graduated reduction based on collection size
            let warmReductionRatio: Double
            if collectionSize < 100 {
                warmReductionRatio = 0.1  // Very light reduction for small collections
            } else if collectionSize < 500 {
                warmReductionRatio = 0.15  // Light reduction for medium collections  
            } else {
                warmReductionRatio = collectionSize > 1000 ? 0.3 : 0.25  // Standard reduction for large collections
            }
            reduceWarmCacheIntelligently(by: warmReductionRatio)
            print("⚠️ Memory warning - reduced warm cache by \(Int(warmReductionRatio * 100))% for collection of \(collectionSize) screenshots")
            
        case .critical:
            // Aggressive but intelligent cache reduction
            let warmReductionRatio = collectionSize > 1000 ? 0.6 : 0.5
            let hotReductionRatio = collectionSize > 1000 ? 0.4 : 0.25
            
            reduceWarmCacheIntelligently(by: warmReductionRatio)
            reduceHotCacheIntelligently(by: hotReductionRatio)
            
            // Also clear some cold cache entries for large collections
            if collectionSize > 1000 {
                reduceColdCache(by: 0.3)
            }
            
            print("🚨 Memory critical - reduced caches significantly")
        }
        
        updateMemoryUsage()
        
        let savedMemory = beforeMemory - memoryUsage
        if savedMemory > 0 {
            print("💾 Memory optimization saved \(savedMemory / 1024 / 1024)MB")
        }
    }
    
    /// Preload thumbnails for viewport optimization
    func preloadThumbnails(for screenshotIds: [UUID], size: CGSize, priority: CachePriority = .normal) {
        Task.detached { [weak self] in
            for screenshotId in screenshotIds {
                // Check if already cached
                _ = await self?.generateCacheKey(screenshotId: screenshotId, size: size)
                
                if await self?.getThumbnail(for: screenshotId, size: size) == nil {
                    // Not cached - add to background processing queue
                    await self?.requestThumbnailGeneration(screenshotId: screenshotId, size: size, priority: priority)
                }
                
                // Respect system resources during preloading
                if priority == .background {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                }
            }
        }
    }
    
    // MARK: - Phase 2: Enhanced Access Management
    
    /// Thread-safe entry access update
    private func updateEntryAccess(_ entry: CachedThumbnailEntry) async {
        entry.lastAccessTime = Date()
        entry.accessCount += 1
    }
    
    /// Enhanced promotion logic based on access patterns and cache pressure
    private func shouldPromoteToHotCache(_ entry: CachedThumbnailEntry) -> Bool {
        let accessThreshold = adaptiveAccessThreshold()
        let timeSinceLastAccess = Date().timeIntervalSince(entry.lastAccessTime)
        
        // Promote if frequently accessed and recently used
        return entry.accessCount >= accessThreshold && timeSinceLastAccess < 300 // 5 minutes
    }
    
    /// Calculate adaptive access threshold based on cache pressure
    private func adaptiveAccessThreshold() -> Int {
        let hotCachePressure = Double(hotCache.count) / Double(maxHotCacheSize)
        
        if hotCachePressure > 0.8 {
            return 5 // Higher threshold when hot cache is under pressure
        } else if hotCachePressure > 0.6 {
            return 4
        } else {
            return 3 // Default threshold
        }
    }
    
    // MARK: - Memory Management
    
    private func enforceMemoryLimits() {
        enforceHotCacheLimit()
        enforceWarmCacheLimit()
        enforceColdCacheLimit()
        updateMemoryUsage()
    }
    
    private func enforceHotCacheLimit() {
        // Phase 2: Enhanced LRU eviction with batch processing to prevent resource starvation
        let itemsToEvict = max(0, hotCache.count - maxHotCacheSize)
        
        if itemsToEvict > 0 {
            let lruEntries = findLRUEntries(in: hotCache, count: itemsToEvict)
            
            for (key, entry) in lruEntries {
                hotCache.removeValue(forKey: key)
                
                // Demote to warm cache if there's room, otherwise skip
                if warmCache.count < maxWarmCacheSize {
                    warmCache[key] = entry
                    cacheDemotionCount += 1
                } else {
                    lruEvictionCount += 1
                }
            }
        }
    }
    
    private func enforceWarmCacheLimit() {
        // Phase 2: Enhanced LRU eviction with batch processing
        let itemsToEvict = max(0, warmCache.count - maxWarmCacheSize)
        
        if itemsToEvict > 0 {
            let lruEntries = findLRUEntries(in: warmCache, count: itemsToEvict)
            
            for (key, _) in lruEntries {
                if warmCache.removeValue(forKey: key) != nil {
                    // Demote to cold cache (file system only) if there's room
                    if coldCache.count < maxColdCacheSize {
                        let filePath = generateFilePath(for: key)
                        coldCache[key] = filePath
                        cacheDemotionCount += 1
                    } else {
                        lruEvictionCount += 1
                    }
                }
            }
        }
    }
    
    private func enforceColdCacheLimit() {
        while coldCache.count > maxColdCacheSize {
            // Remove least recently used file
            if let lruKey = coldCache.keys.first {
                if let filePath = coldCache.removeValue(forKey: lruKey) {
                    // Remove file from disk
                    try? fileManager.removeItem(atPath: filePath)
                }
            }
        }
    }
    
    /// Phase 2: Enhanced LRU finding with batch processing to prevent resource starvation
    private func findLRUEntries(in cache: [String: CachedThumbnailEntry], count: Int) -> [(String, CachedThumbnailEntry)] {
        return cache.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }
                   .prefix(count)
                   .map { ($0.key, $0.value) }
    }
    
    /// Legacy method for compatibility
    private func findLRUKey(in cache: [String: CachedThumbnailEntry]) -> String? {
        return cache.min { $0.value.lastAccessTime < $1.value.lastAccessTime }?.key
    }
    
    private func promoteToHotCache(cacheKey: String, entry: CachedThumbnailEntry) {
        warmCache.removeValue(forKey: cacheKey)
        hotCache[cacheKey] = entry
        enforceHotCacheLimit()
    }
    
    /// Phase 2: Intelligent warm cache reduction preserving frequently accessed items
    private func reduceWarmCacheIntelligently(by fraction: Double) {
        let itemsToRemove = Int(Double(warmCache.count) * fraction)
        
        // Sort by both access time and access count for intelligent eviction
        let sortedEntries = warmCache.sorted { entry1, entry2 in
            let score1 = calculateEvictionScore(entry1.value)
            let score2 = calculateEvictionScore(entry2.value)
            return score1 < score2 // Lower score = more likely to evict
        }
        
        for (key, _) in sortedEntries.prefix(itemsToRemove) {
            if warmCache.removeValue(forKey: key) != nil {
                // Try to demote to cold cache if there's room
                if coldCache.count < maxColdCacheSize {
                    let filePath = generateFilePath(for: key)
                    coldCache[key] = filePath
                    cacheDemotionCount += 1
                } else {
                    lruEvictionCount += 1
                }
            }
        }
    }
    
    /// Legacy method for compatibility
    private func reduceWarmCache(by fraction: Double) {
        reduceWarmCacheIntelligently(by: fraction)
    }
    
    /// Phase 2: Intelligent hot cache reduction preserving high-value items
    private func reduceHotCacheIntelligently(by fraction: Double) {
        let itemsToRemove = Int(Double(hotCache.count) * fraction)
        
        // Sort by eviction score to preserve high-value items
        let sortedEntries = hotCache.sorted { entry1, entry2 in
            let score1 = calculateEvictionScore(entry1.value)
            let score2 = calculateEvictionScore(entry2.value)
            return score1 < score2 // Lower score = more likely to evict
        }
        
        for (key, entry) in sortedEntries.prefix(itemsToRemove) {
            hotCache.removeValue(forKey: key)
            
            // Try to demote to warm cache if there's room
            if warmCache.count < maxWarmCacheSize {
                warmCache[key] = entry
                cacheDemotionCount += 1
            } else {
                lruEvictionCount += 1
            }
        }
    }
    
    /// Calculate eviction score for intelligent cache management
    private func calculateEvictionScore(_ entry: CachedThumbnailEntry) -> Double {
        let recency = Date().timeIntervalSince(entry.lastAccessTime)
        let frequency = Double(entry.accessCount)
        
        // Lower score = higher priority to keep
        // Higher frequency and recent access = lower eviction score
        return recency / max(frequency, 1.0)
    }
    
    /// Phase 2: Cold cache reduction for extreme memory pressure
    private func reduceColdCache(by fraction: Double) {
        let itemsToRemove = Int(Double(coldCache.count) * fraction)
        let keysToRemove = Array(coldCache.keys.prefix(itemsToRemove))
        
        for key in keysToRemove {
            if let filePath = coldCache.removeValue(forKey: key) {
                try? fileManager.removeItem(atPath: filePath)
                lruEvictionCount += 1
            }
        }
    }
    
    /// Legacy method for compatibility
    private func reduceHotCache(by fraction: Double) {
        reduceHotCacheIntelligently(by: fraction)
    }
    
    private func updateMemoryUsage() {
        let hotCacheSize = hotCache.values.reduce(0) { $0 + $1.estimatedMemorySize }
        let warmCacheSize = warmCache.values.reduce(0) { $0 + $1.estimatedMemorySize }
        memoryUsage = hotCacheSize + warmCacheSize
        
        // Check memory pressure
        if memoryUsage > maxMemoryUsageBytes {
            optimizeForMemoryPressure(level: .critical)
        }
    }
    
    private func updateCacheMetrics() {
        let totalRequests = cacheHitCount + cacheMissCount
        if totalRequests > 0 {
            cacheHitRate = Double(cacheHitCount) / Double(totalRequests)
            hotCacheHitRate = Double(hotCacheHits) / Double(totalRequests)
            warmCacheHitRate = Double(warmCacheHits) / Double(totalRequests)
            coldCacheHitRate = Double(coldCacheHits) / Double(totalRequests)
        }
        
        // Log metrics periodically
        if totalRequests % 20 == 0 && totalRequests > 0 {
            print("📊 Advanced Cache Metrics:")
            print("   Overall Hit Rate: \(String(format: "%.1f", cacheHitRate * 100))%")
            print("   Hot Cache: \(String(format: "%.1f", hotCacheHitRate * 100))%")
            print("   Warm Cache: \(String(format: "%.1f", warmCacheHitRate * 100))%")
            print("   Cold Cache: \(String(format: "%.1f", coldCacheHitRate * 100))%")
            print("   Memory Usage: \(memoryUsage / 1024 / 1024)MB")
        }
    }
    
    // MARK: - File System Operations
    
    private func saveThumbnailToDisk(_ image: UIImage, cacheKey: String) async {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let filePath = generateFilePath(for: cacheKey)
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            try data.write(to: fileURL)
            await MainActor.run {
                self.coldCache[cacheKey] = filePath
                self.enforceColdCacheLimit()
            }
        } catch {
            print("❌ Failed to save thumbnail to disk: \(error)")
        }
    }
    
    private func removeThumbnailFilesFromDisk(screenshotId: UUID) async {
        let keyPrefix = screenshotId.uuidString
        
        // Find all files for this screenshot
        let keysToRemove = await MainActor.run {
            coldCache.keys.filter { $0.hasPrefix(keyPrefix) }
        }
        
        for key in keysToRemove {
            let filePath = await MainActor.run {
                return coldCache[key]
            }
            if let filePath = filePath {
                try? fileManager.removeItem(atPath: filePath)
            }
        }
        
        await MainActor.run {
            for key in keysToRemove {
                coldCache.removeValue(forKey: key)
            }
        }
    }
    
    private func loadColdCacheIndex() {
        // Load existing thumbnails from disk
        do {
            let files = try fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil)
            for file in files {
                if file.pathExtension == "jpg" {
                    let cacheKey = file.deletingPathExtension().lastPathComponent
                    coldCache[cacheKey] = file.path
                }
            }
            print("📂 Loaded \(coldCache.count) thumbnails from disk cache")
        } catch {
            print("❌ Failed to load cold cache index: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateCacheKey(screenshotId: UUID, size: CGSize) -> String {
        return "\(screenshotId.uuidString)_\(Int(size.width))x\(Int(size.height))"
    }
    
    private func generateFilePath(for cacheKey: String) -> String {
        return thumbnailsDirectory.appendingPathComponent("\(cacheKey).jpg").path
    }
    
    private func requestThumbnailGeneration(screenshotId: UUID, size: CGSize, priority: CachePriority) async {
        // This will be handled by BackgroundThumbnailProcessor
        // For now, just log the request
        print("🔄 Requested thumbnail generation for: \(screenshotId)")
    }
    
    /// Get cache statistics for debugging - Phase 2 enhanced
    var cacheStatistics: ThumbnailCacheStatistics {
        return ThumbnailCacheStatistics(
            hotCacheSize: hotCache.count,
            warmCacheSize: warmCache.count,
            coldCacheSize: coldCache.count,
            totalMemoryUsage: memoryUsage,
            hitRate: cacheHitRate,
            hotCacheHitRate: hotCacheHitRate,
            warmCacheHitRate: warmCacheHitRate,
            coldCacheHitRate: coldCacheHitRate,
            averageLoadTime: lastLoadTime,
            // Phase 2 metrics
            lruEvictionCount: lruEvictionCount,
            cachePromotionCount: cachePromotionCount,
            cacheDemotionCount: cacheDemotionCount,
            collectionSize: collectionSize,
            adaptiveCachingEnabled: adaptiveCachingEnabled
        )
    }
}

// MARK: - Supporting Types

class CachedThumbnailEntry {
    let image: UIImage
    let size: CGSize
    var lastAccessTime: Date
    var accessCount: Int
    
    init(image: UIImage, size: CGSize, lastAccessTime: Date, accessCount: Int) {
        self.image = image
        self.size = size
        self.lastAccessTime = lastAccessTime
        self.accessCount = accessCount
    }
    
    var estimatedMemorySize: Int {
        return Int(size.width * size.height * 4) // 4 bytes per pixel (RGBA)
    }
}

enum ThumbnailMemoryPressureLevel {
    case normal
    case warning
    case critical
}

enum CachePriority {
    case high
    case normal
    case background
}

struct ThumbnailCacheStatistics {
    let hotCacheSize: Int
    let warmCacheSize: Int
    let coldCacheSize: Int
    let totalMemoryUsage: Int
    let hitRate: Double
    let hotCacheHitRate: Double
    let warmCacheHitRate: Double
    let coldCacheHitRate: Double
    let averageLoadTime: TimeInterval
    
    // Phase 2: Enhanced metrics
    let lruEvictionCount: Int
    let cachePromotionCount: Int
    let cacheDemotionCount: Int
    let collectionSize: Int
    let adaptiveCachingEnabled: Bool
} 