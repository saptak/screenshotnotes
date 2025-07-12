import Foundation
import UIKit

/// Advanced thumbnail cache manager with multi-tier caching system
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
    
    /// Performance configuration
    private let maxHotCacheSize: Int = 50
    private let maxWarmCacheSize: Int = 200
    private let maxColdCacheSize: Int = 1000
    private let maxMemoryUsageBytes: Int = 50 * 1024 * 1024 // 50MB
    
    /// Performance targets
    private let targetLoadTime: TimeInterval = 0.2 // 200ms
    private let targetCacheHitRate: Double = 0.9 // 90%
    
    /// Performance metrics
    private var cacheHitCount: Int = 0
    private var cacheMissCount: Int = 0
    private var cacheHitRate: Double = 0.0
    private var hotCacheHits: Int = 0
    private var warmCacheHits: Int = 0
    private var coldCacheHits: Int = 0
    private var hotCacheHitRate: Double = 0.0
    private var warmCacheHitRate: Double = 0.0
    private var coldCacheHitRate: Double = 0.0
    
    /// Memory usage tracking
    private var memoryUsage: Int = 0
    private var lastLoadTime: TimeInterval = 0
    
    /// File system management
    private let fileManager = FileManager.default
    private let thumbnailsDirectory: URL
    
    // MARK: - Initialization
    
    private init() {
        // Create thumbnails directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        thumbnailsDirectory = documentsPath.appendingPathComponent("AdvancedThumbnails")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        
        // Load existing cache index
        loadColdCacheIndex()
    }
    
    // MARK: - Cache Operations
    
    /// Get thumbnail from cache or generate if needed
    func getThumbnail(for screenshotId: UUID, size: CGSize) async -> UIImage? {
        let startTime = CACurrentMediaTime()
        let cacheKey = generateCacheKey(screenshotId: screenshotId, size: size)
        
        // Check hot cache first
        if let entry = hotCache[cacheKey] {
            entry.lastAccessTime = Date()
            entry.accessCount += 1
            cacheHitCount += 1
            hotCacheHits += 1
            updateCacheMetrics()
            
            lastLoadTime = CACurrentMediaTime() - startTime
            return entry.image
        }
        
        // Check warm cache
        if let entry = warmCache[cacheKey] {
            entry.lastAccessTime = Date()
            entry.accessCount += 1
            cacheHitCount += 1
            warmCacheHits += 1
            
            // Promote to hot cache if frequently accessed
            if entry.accessCount > 3 {
                promoteToHotCache(cacheKey: cacheKey, entry: entry)
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
    
    /// Memory pressure optimization - graduated response
    func optimizeForMemoryPressure(level: ThumbnailMemoryPressureLevel) {
        switch level {
        case .normal:
            // Standard cache management
            enforceMemoryLimits()
            
        case .warning:
            // Reduce warm cache by 25%
            reduceWarmCache(by: 0.25)
            print("⚠️ Memory warning - reduced warm cache by 25%")
            
        case .critical:
            // Aggressive cache reduction
            reduceWarmCache(by: 0.5)
            reduceHotCache(by: 0.25)
            print("🚨 Memory critical - reduced caches significantly")
        }
        
        updateMemoryUsage()
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
    
    // MARK: - Memory Management
    
    private func enforceMemoryLimits() {
        enforceHotCacheLimit()
        enforceWarmCacheLimit()
        enforceColdCacheLimit()
        updateMemoryUsage()
    }
    
    private func enforceHotCacheLimit() {
        while hotCache.count > maxHotCacheSize {
            // Remove least recently used item
            if let lruKey = findLRUKey(in: hotCache) {
                if let entry = hotCache.removeValue(forKey: lruKey) {
                    // Demote to warm cache
                    warmCache[lruKey] = entry
                }
            }
        }
    }
    
    private func enforceWarmCacheLimit() {
        while warmCache.count > maxWarmCacheSize {
            // Remove least recently used item
            if let lruKey = findLRUKey(in: warmCache) {
                if warmCache.removeValue(forKey: lruKey) != nil {
                    // Demote to cold cache (file system only)
                    let filePath = generateFilePath(for: lruKey)
                    coldCache[lruKey] = filePath
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
    
    private func findLRUKey(in cache: [String: CachedThumbnailEntry]) -> String? {
        return cache.min { $0.value.lastAccessTime < $1.value.lastAccessTime }?.key
    }
    
    private func promoteToHotCache(cacheKey: String, entry: CachedThumbnailEntry) {
        warmCache.removeValue(forKey: cacheKey)
        hotCache[cacheKey] = entry
        enforceHotCacheLimit()
    }
    
    private func reduceWarmCache(by fraction: Double) {
        let itemsToRemove = Int(Double(warmCache.count) * fraction)
        let sortedKeys = warmCache.keys.sorted { key1, key2 in
            warmCache[key1]?.lastAccessTime ?? Date.distantPast <
            warmCache[key2]?.lastAccessTime ?? Date.distantPast
        }
        
        for key in sortedKeys.prefix(itemsToRemove) {
            warmCache.removeValue(forKey: key)
        }
    }
    
    private func reduceHotCache(by fraction: Double) {
        let itemsToRemove = Int(Double(hotCache.count) * fraction)
        let sortedKeys = hotCache.keys.sorted { key1, key2 in
            hotCache[key1]?.lastAccessTime ?? Date.distantPast <
            hotCache[key2]?.lastAccessTime ?? Date.distantPast
        }
        
        for key in sortedKeys.prefix(itemsToRemove) {
            if let entry = hotCache.removeValue(forKey: key) {
                // Demote to warm cache
                warmCache[key] = entry
            }
        }
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
    
    /// Get cache statistics for debugging
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
            averageLoadTime: lastLoadTime
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
} 