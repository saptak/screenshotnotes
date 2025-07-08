import UIKit
import SwiftData
import OSLog

@MainActor
class ThumbnailService: ObservableObject {
    static let shared = ThumbnailService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ThumbnailService")
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let thumbnailsDirectory: URL
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]
    
    // Thumbnail specifications
    nonisolated static let thumbnailSize = CGSize(width: 200, height: 200)
    nonisolated static let listThumbnailSize = CGSize(width: 120, height: 120)
    nonisolated private let thumbnailQuality: CGFloat = 0.8
    
    private init() {
        // Set up cache configuration
        thumbnailCache.countLimit = 200 // Keep 200 thumbnails in memory
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
        
        // Create thumbnails directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        thumbnailsDirectory = documentsPath.appendingPathComponent("Thumbnails")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        
        logger.info("ThumbnailService initialized with cache limit: \(self.thumbnailCache.countLimit) items")
    }
    
    /// Check if thumbnail is already cached (memory or disk) without generating
    func getCachedThumbnail(for screenshotId: UUID, size: CGSize = thumbnailSize) -> UIImage? {
        let cacheKey = "\(screenshotId.uuidString)_\(Int(size.width))x\(Int(size.height))"
        
        // Check memory cache first
        if let cachedImage = thumbnailCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        // Check disk cache
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(cacheKey).jpg")
        if fileManager.fileExists(atPath: thumbnailURL.path),
           let diskImage = UIImage(contentsOfFile: thumbnailURL.path) {
            
            // Cache in memory for faster subsequent access
            thumbnailCache.setObject(diskImage, forKey: cacheKey as NSString, cost: Int(size.width * size.height * 4))
            return diskImage
        }
        
        return nil
    }
    
    /// Generate and cache thumbnail for a screenshot
    func getThumbnail(for screenshotId: UUID, from imageData: Data, size: CGSize = thumbnailSize) async -> UIImage? {
        let cacheKey = "\(screenshotId.uuidString)_\(Int(size.width))x\(Int(size.height))"
        
        // Check memory cache first
        if let cachedImage = thumbnailCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        // If there's already a task generating this thumbnail, await it to prevent duplicate work
        if let existingTask = activeTasks[cacheKey] {
            logger.debug("Awaiting existing thumbnail task for: \(cacheKey)")
            return await existingTask.value
        }
        
        // Check disk cache
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(cacheKey).jpg")
        if fileManager.fileExists(atPath: thumbnailURL.path),
           let diskImage = UIImage(contentsOfFile: thumbnailURL.path) {
            
            // Cache in memory for faster subsequent access
            thumbnailCache.setObject(diskImage, forKey: cacheKey as NSString, cost: Int(size.width * size.height * 4))
            return diskImage
        }
        
        // Create a new task for generating the thumbnail
        let task = Task {
            await generateThumbnail(imageData: imageData, size: size, cacheKey: cacheKey, thumbnailURL: thumbnailURL)
        }
        
        // Store the task to avoid duplicate work
        activeTasks[cacheKey] = task
        
        let result = await task.value
        
        // Clean up the task reference
        activeTasks.removeValue(forKey: cacheKey)
        
        return result
    }
    
    private func generateThumbnail(imageData: Data, size: CGSize, cacheKey: String, thumbnailURL: URL) async -> UIImage? {
        // Create UIImage from data (can be done off main thread)
        guard let originalImage = UIImage(data: imageData) else {
            logger.error("Failed to create UIImage from data")
            return nil
        }
        
        // Resize image off main thread using nonisolated method
        let thumbnail = await resizeImage(originalImage, to: size)
        
        // Cache on main actor
        let memoryCost = Int(size.width * size.height * 4)
        thumbnailCache.setObject(thumbnail, forKey: cacheKey as NSString, cost: memoryCost)
        
        // Save to disk on main actor
        await saveThumbnailToDisk(thumbnail, at: thumbnailURL)
        
        return thumbnail
    }
    
    nonisolated private func resizeImage(_ image: UIImage, to size: CGSize) async -> UIImage {
        return await Task.detached {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }.value
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
    
    /// Preload thumbnails for a batch of screenshots
    func preloadThumbnails(for screenshots: [Screenshot], size: CGSize = thumbnailSize) {
        Task {
            for screenshot in screenshots.prefix(20) { // Preload first 20
                _ = await getThumbnail(for: screenshot.id, from: screenshot.imageData, size: size)
                
                // Small delay to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }
    
    /// Clear thumbnail cache to free memory
    func clearCache() {
        thumbnailCache.removeAllObjects()
        
        // Cancel any active tasks
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        
        logger.info("Thumbnail cache cleared")
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
}

// MARK: - Thumbnail Task Coordination Actor

/// Actor to provide async-safe coordination for thumbnail generation tasks
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