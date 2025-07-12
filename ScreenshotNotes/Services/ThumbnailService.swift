import UIKit
import SwiftData
import OSLog

// MARK: - AsyncSemaphore for concurrency control

actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.count = value
    }
    
    func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        if waiters.isEmpty {
            count += 1
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}

// MARK: - Timeout helper

func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T?) async -> T? {
    return await withTaskGroup(of: T?.self, returning: T?.self) { group in
        group.addTask {
            await operation()
        }
        
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        
        defer { group.cancelAll() }
        return await group.next() ?? nil
    }
}

@MainActor
class ThumbnailService: ObservableObject {
    static let shared = ThumbnailService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ThumbnailService")
    
    // Phase 2: Enhanced with all optimization services
    private let advancedCacheManager = AdvancedThumbnailCacheManager.shared
    private let backgroundProcessor = BackgroundThumbnailProcessor.shared
    private let changeTracker = GalleryChangeTracker.shared
    private let qualityManager = AdaptiveQualityManager.shared
    private let viewportManager = PredictiveViewportManager.shared
    
    // Legacy cache for backward compatibility (will be deprecated)
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let thumbnailsDirectory: URL
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]
    
    // Use async semaphore for proper concurrency control - reduced for better user experience
    private let semaphore = AsyncSemaphore(value: 2) // Significantly reduced from 8 to prevent resource starvation
    
    // Thumbnail specifications
    nonisolated static let thumbnailSize = CGSize(width: 200, height: 200)
    nonisolated static let listThumbnailSize = CGSize(width: 120, height: 120)
    nonisolated private let thumbnailQuality: CGFloat = 0.8
    
    private init() {
        // Set up legacy cache configuration for backward compatibility
        thumbnailCache.countLimit = 500 // Keep 500 thumbnails in memory (increased for bulk imports)
        thumbnailCache.totalCostLimit = 100 * 1024 * 1024 // 100MB memory limit (increased for bulk imports)
        
        // Create thumbnails directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        thumbnailsDirectory = documentsPath.appendingPathComponent("Thumbnails")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        
        logger.info("ThumbnailService initialized with advanced cache management and performance optimization")
    }
    
    /// Set ModelContext for enhanced services - Phase 2 with collection size tracking
    func setModelContext(_ context: ModelContext) {
        // Note: AdvancedThumbnailCacheManager doesn't need ModelContext
        backgroundProcessor.setModelContext(context)
        changeTracker.setModelContext(context)
        
        // Update collection size for adaptive optimization
        Task {
            await updateCollectionSizeFromContext(context)
        }
    }
    
    /// Update collection size for adaptive optimization
    private func updateCollectionSizeFromContext(_ context: ModelContext) async {
        do {
            let screenshots = try context.fetch(FetchDescriptor<Screenshot>())
            let collectionSize = screenshots.count
            
            // Update all Phase 2 managers with collection size
            advancedCacheManager.updateCollectionSize(collectionSize)
            qualityManager.updateCollectionSize(collectionSize)
            
            print("📊 Updated collection size: \(collectionSize) screenshots")
        } catch {
            print("❌ Failed to fetch collection size: \(error)")
        }
    }
    
    /// Check if thumbnail is already cached (memory or disk) without generating
    func getCachedThumbnail(for screenshotId: UUID, size: CGSize = thumbnailSize) -> UIImage? {
        // Note: For synchronous cache checking, use legacy cache
        // Advanced cache manager will be used in async generation paths
        
        // Fallback: Check legacy cache for backward compatibility
        let cacheKey = "\(screenshotId.uuidString)_\(Int(size.width))x\(Int(size.height))"
        
        // Check legacy memory cache
        if let cachedImage = thumbnailCache.object(forKey: cacheKey as NSString) {
            logger.debug("🎯 Legacy cache HIT for: \(cacheKey)")
            // Migrate to advanced cache
            advancedCacheManager.storeThumbnail(cachedImage, for: screenshotId, size: size)
            return cachedImage
        }
        
        // Check legacy disk cache
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(cacheKey).jpg")
        if fileManager.fileExists(atPath: thumbnailURL.path),
           let diskImage = UIImage(contentsOfFile: thumbnailURL.path) {
            
            logger.debug("💾 Legacy disk cache HIT for: \(cacheKey), migrating to advanced cache")
            // Migrate to advanced cache
            advancedCacheManager.storeThumbnail(diskImage, for: screenshotId, size: size)
            return diskImage
        }
        
        logger.debug("❌ Cache MISS for: \(cacheKey)")
        return nil
    }
    
    /// Generate and cache thumbnail for a screenshot - Phase 2: Enhanced with adaptive quality
    func getThumbnail(for screenshotId: UUID, from imageData: Data, size: CGSize = thumbnailSize) async -> UIImage? {
        // Phase 2: Use adaptive quality for optimal size
        let optimalSize = qualityManager.getOptimalThumbnailSize(baseSize: size)
        
        // First check if already cached in advanced cache manager with optimal size
        if let cachedImage = await advancedCacheManager.getThumbnail(for: screenshotId, size: optimalSize) {
            return cachedImage
        }
        
        // Request through background processor with optimal size
        backgroundProcessor.requestThumbnail(
            for: screenshotId,
            from: imageData,
            size: optimalSize,
            priority: .high // High priority for immediate user requests
        )
        
        // For immediate UI needs, try legacy path as fallback with optimal size
        let cacheKey = "\(screenshotId.uuidString)_\(Int(optimalSize.width))x\(Int(optimalSize.height))"
        
        // Check legacy cache
        if let cachedImage = thumbnailCache.object(forKey: cacheKey as NSString) {
            // Migrate to advanced cache
            advancedCacheManager.storeThumbnail(cachedImage, for: screenshotId, size: size)
            return cachedImage
        }
        
        // If there's already a task generating this thumbnail, await it to prevent duplicate work
        if let existingTask = activeTasks[cacheKey] {
            logger.debug("Awaiting existing thumbnail task for: \(cacheKey)")
            return await existingTask.value
        }
        
        // Check legacy disk cache
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(cacheKey).jpg")
        if fileManager.fileExists(atPath: thumbnailURL.path),
           let diskImage = UIImage(contentsOfFile: thumbnailURL.path) {
            
            // Migrate to advanced cache with optimal size
            advancedCacheManager.storeThumbnail(diskImage, for: screenshotId, size: optimalSize)
            return diskImage
        }
        
        // Generate thumbnail using optimized path
        await semaphore.wait()
        
        let task = Task {
            defer {
                Task {
                    await self.semaphore.signal()
                }
            }
            
            let result = await generateThumbnailOptimizedPhase2(imageData: imageData, size: optimalSize, screenshotId: screenshotId)
            
            await MainActor.run {
                self.activeTasks.removeValue(forKey: cacheKey)
                if result != nil {
                    self.logger.debug("✅ Successfully completed thumbnail generation for \(cacheKey)")
                } else {
                    self.logger.error("❌ Failed to generate thumbnail for \(cacheKey)")
                }
            }
            
            return result
        }
        
        activeTasks[cacheKey] = task
        
        logger.debug("🔄 Generating thumbnail for immediate use: \(cacheKey)")
        
        let result = await withTimeout(seconds: 10) { // Reduced timeout for immediate UI
            await task.value
        }
        
        return result
    }
    
    /// Phase 2: Enhanced thumbnail generation with adaptive quality and resource management
    private func generateThumbnailOptimizedPhase2(imageData: Data, size: CGSize, screenshotId: UUID) async -> UIImage? {
        logger.debug("Starting Phase 2 optimized thumbnail generation for screenshot: \(screenshotId)")
        
        // Create UIImage from data (can be done off main thread)
        guard let originalImage = UIImage(data: imageData) else {
            logger.error("Failed to create UIImage from data for screenshot: \(screenshotId)")
            return nil
        }
        
        // Phase 2: Use adaptive quality compression
        let compressionQuality = qualityManager.getCompressionQuality()
        
        // Resize image with adaptive quality
        let thumbnail = await resizeImageWithQuality(originalImage, to: size, compressionQuality: compressionQuality)
        
        // Save to advanced cache manager
        advancedCacheManager.storeThumbnail(thumbnail, for: screenshotId, size: size)
        
        // Also save to legacy cache for backward compatibility
        let cacheKey = "\(screenshotId.uuidString)_\(Int(size.width))x\(Int(size.height))"
        let memoryCost = Int(size.width * size.height * 4)
        thumbnailCache.setObject(thumbnail, forKey: cacheKey as NSString, cost: memoryCost)
        
        logger.debug("Phase 2 optimized thumbnail generation completed for screenshot: \(screenshotId)")
        return thumbnail
    }
    
    /// Legacy method maintained for compatibility
    private func generateThumbnailOptimized(imageData: Data, size: CGSize, screenshotId: UUID) async -> UIImage? {
        return await generateThumbnailOptimizedPhase2(imageData: imageData, size: size, screenshotId: screenshotId)
    }
    
    // Legacy method maintained for compatibility
    private func generateThumbnail(imageData: Data, size: CGSize, cacheKey: String, thumbnailURL: URL) async -> UIImage? {
        logger.debug("Starting legacy thumbnail generation for \(cacheKey)")
        
        // Create UIImage from data (can be done off main thread)
        guard let originalImage = UIImage(data: imageData) else {
            logger.error("Failed to create UIImage from data for \(cacheKey)")
            return nil
        }
        
        logger.debug("Original image created for \(cacheKey), size: \(String(describing: originalImage.size))")
        
        // Resize image off main thread using nonisolated method
        let thumbnail = await resizeImage(originalImage, to: size)
        
        logger.debug("Thumbnail resized for \(cacheKey), final size: \(String(describing: thumbnail.size))")
        
        // Cache on main actor
        let memoryCost = Int(size.width * size.height * 4)
        thumbnailCache.setObject(thumbnail, forKey: cacheKey as NSString, cost: memoryCost)
        
        // Save to disk on main actor
        await saveThumbnailToDisk(thumbnail, at: thumbnailURL)
        
        logger.debug("Thumbnail generation completed for \(cacheKey)")
        return thumbnail
    }
    
    /// Phase 2: Enhanced image resizing with adaptive quality
    nonisolated private func resizeImageWithQuality(_ image: UIImage, to size: CGSize, compressionQuality: CGFloat) async -> UIImage {
        return await Task.detached {
            let renderer = UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat())
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            
            // Apply compression quality for memory optimization
            if compressionQuality < 1.0,
               let jpegData = resizedImage.jpegData(compressionQuality: compressionQuality),
               let compressedImage = UIImage(data: jpegData) {
                return compressedImage
            }
            
            return resizedImage
        }.value
    }
    
    /// Legacy resize method for compatibility
    nonisolated private func resizeImage(_ image: UIImage, to size: CGSize) async -> UIImage {
        return await resizeImageWithQuality(image, to: size, compressionQuality: 0.85)
    }
    
    nonisolated private func saveThumbnailToDisk(_ image: UIImage, at url: URL) async {
        guard let data = image.jpegData(compressionQuality: thumbnailQuality) else { return }
        
        do {
            try data.write(to: url)
        } catch {
            // Note: Can't access main actor-isolated logger from nonisolated context
            print("ThumbnailService: Failed to save thumbnail to disk: \(error.localizedDescription)")
        }
    }
    
    /// Preload thumbnails for a batch of screenshots using advanced background processing
    func preloadThumbnails(for screenshots: [Screenshot], size: CGSize = thumbnailSize) {
        // Use background processor for efficient batch processing
        backgroundProcessor.requestThumbnailBatch(
            for: screenshots,
            size: size,
            priority: .background
        )
        
        logger.info("Requested preload of \(screenshots.count) thumbnails via background processor")
    }
    
    /// Legacy preload method for immediate processing (use sparingly)
    func preloadThumbnailsImmediate(for screenshots: [Screenshot], size: CGSize = thumbnailSize) {
        Task {
            for screenshot in screenshots.prefix(5) { // Reduced for immediate processing
                _ = await getThumbnail(for: screenshot.id, from: screenshot.imageData, size: size)
                
                // Small delay to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }
    
    /// Clear thumbnail cache to free memory (graduated response instead of nuclear clearing)
    func clearCache() {
        // Use graduated memory pressure response instead of nuclear clearing
        advancedCacheManager.optimizeForMemoryPressure(level: ThumbnailMemoryPressureLevel.warning)
        
        // Also clear legacy cache for immediate memory relief
        thumbnailCache.removeAllObjects()
        
        // Cancel any active tasks
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        
        logger.info("Thumbnail cache optimized for memory pressure")
    }
    
    /// Force clear all caches (nuclear option for critical memory pressure)
    func forceClearAllCaches() {
        advancedCacheManager.optimizeForMemoryPressure(level: ThumbnailMemoryPressureLevel.critical)
        thumbnailCache.removeAllObjects()
        
        // Cancel any active tasks
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        
        logger.warning("All thumbnail caches forcibly cleared due to critical memory pressure")
    }
    
    /// Clear old disk cache files
    func cleanupDiskCache() {
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        do {
            let files = try fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = attributes.creationDate, creationDate < oneWeekAgo {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            logger.error("Failed to cleanup disk cache: \(error.localizedDescription)")
        }
    }
    
    /// Get cache statistics for monitoring
    func getCacheStats() -> (memoryCount: Int, diskCount: Int) {
        let memoryCount = thumbnailCache.countLimit
        
        let diskCount: Int
        do {
            let files = try fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil)
            diskCount = files.count
        } catch {
            diskCount = 0
        }
        
        return (memoryCount: memoryCount, diskCount: diskCount)
    }
    
    // MARK: - Advanced Cache Integration
    
    /// Get comprehensive performance metrics from all thumbnail services
    var enhancedPerformanceMetrics: EnhancedThumbnailMetrics {
        return EnhancedThumbnailMetrics(
            cacheStatistics: advancedCacheManager.cacheStatistics,
            processingMetrics: backgroundProcessor.performanceMetrics,
            changeTrackingMetrics: changeTracker.changeTrackingMetrics,
            legacyCacheSize: thumbnailCache.totalCostLimit,
            activeTaskCount: activeTasks.count
        )
    }
    
    /// Track screenshot changes for cache invalidation
    func trackScreenshotAdded(_ screenshot: Screenshot) {
        changeTracker.trackScreenshotAdded(screenshot)
    }
    
    func trackScreenshotDeleted(_ screenshotId: UUID) {
        changeTracker.trackScreenshotDeleted(screenshotId)
    }
    
    func trackScreenshotModified(_ screenshot: Screenshot) {
        changeTracker.trackScreenshotModified(screenshot)
    }
    
    func trackBulkImport(_ screenshotIds: [UUID]) {
        changeTracker.trackBulkImport(screenshotIds)
    }
    
    func trackGalleryViewChange(visibleScreenshots: [UUID], collectionSize: Int) {
        changeTracker.trackGalleryViewChange(visibleScreenshots: visibleScreenshots, collectionSize: collectionSize)
    }
}

// MARK: - Enhanced Metrics

struct EnhancedThumbnailMetrics {
    let cacheStatistics: ThumbnailCacheStatistics
    let processingMetrics: ProcessingMetrics
    let changeTrackingMetrics: ChangeTrackingMetrics
    let legacyCacheSize: Int
    let activeTaskCount: Int
}

// MARK: - Legacy Task Coordinator

actor ThumbnailTaskCoordinator {
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]
    
    /// Get or create a task for thumbnail generation
    /// - Parameters:
    ///   - cacheKey: Unique cache key for the thumbnail
    ///   - taskFactory: Closure that creates the thumbnail generation task
    /// - Returns: The thumbnail image or nil if generation failed
    func getOrCreateTask(
        for cacheKey: String,
        taskFactory: @escaping () -> Task<UIImage?, Never>
    ) async -> UIImage? {
        // If there's already a task for this cache key, await it
        if let existingTask = activeTasks[cacheKey] {
            return await existingTask.value
        }
        
        // Create a new task and store it
        let newTask = taskFactory()
        activeTasks[cacheKey] = newTask
        
        let result = await newTask.value
        
        // Clean up completed task
        activeTasks.removeValue(forKey: cacheKey)
        
        return result
    }
    
    /// Cancel all active tasks and clear the task registry
    func cancelAllTasks() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
    
    /// Get count of currently active tasks
    var activeTaskCount: Int {
        return activeTasks.count
    }
}