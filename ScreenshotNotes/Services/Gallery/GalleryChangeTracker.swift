import Foundation
import SwiftData
import CryptoKit
import SwiftUI

@MainActor
class GalleryChangeTracker: ObservableObject {
    static let shared = GalleryChangeTracker()
    
    // MARK: - Change Tracking State
    @Published var isTrackingChanges = false
    @Published var lastChangeDetected: Date?
    @Published var activeChanges: [GalleryChange] = []
    
    // MARK: - Dependencies
    private var cacheManager: AdvancedThumbnailCacheManager
    private var backgroundProcessor: BackgroundThumbnailProcessor
    private var modelContext: ModelContext?
    
    // MARK: - Change Detection
    private var lastDataFingerprint: String = ""
    private var lastChangeTime: Date = Date()
    private var changeBuffer: [GalleryChange] = []
    private var changeTimer: Timer?
    
    // MARK: - Performance Optimization
    private var batchChangeThreshold = 5
    private var changeBufferDelay: TimeInterval = 0.5 // 500ms batching
    
    private init() {
        self.cacheManager = AdvancedThumbnailCacheManager.shared
        self.backgroundProcessor = BackgroundThumbnailProcessor.shared
        
        // Set up change tracking
        startChangeTracking()
    }
    
    deinit {
        stopChangeTracking()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        // Note: AdvancedThumbnailCacheManager doesn't need ModelContext
        backgroundProcessor.setModelContext(context)
    }
    
    // MARK: - Change Tracking
    
    func startChangeTracking() {
        guard !isTrackingChanges else { return }
        
        isTrackingChanges = true
        print("🔄 Starting gallery change tracking")
        
        // Generate initial fingerprint
        Task {
            await generateInitialFingerprint()
        }
        
        // Set up change detection timer
        changeTimer = Timer.scheduledTimer(withTimeInterval: changeBufferDelay, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processChangeBuffer()
            }
        }
    }
    
    nonisolated func stopChangeTracking() {
        Task { @MainActor in
            isTrackingChanges = false
            changeTimer?.invalidate()
            changeTimer = nil
        }
        
        print("⏹️ Stopped gallery change tracking")
    }
    
    // MARK: - Change Detection
    
    /// Track screenshot addition
    func trackScreenshotAdded(_ screenshot: Screenshot) {
        let change = GalleryChange(
            type: .screenshotAdded(screenshot.id),
            timestamp: Date(),
            metadata: [
                "filename": screenshot.filename,
                "size": "\(screenshot.imageData.count)"
            ]
        )
        
        addChangeToBuffer(change)
        print("📸 Tracked screenshot added: \(screenshot.filename)")
    }
    
    /// Track screenshot deletion
    func trackScreenshotDeleted(_ screenshotId: UUID) {
        let change = GalleryChange(
            type: .screenshotDeleted(screenshotId),
            timestamp: Date(),
            metadata: [:]
        )
        
        addChangeToBuffer(change)
        print("🗑️ Tracked screenshot deleted: \(screenshotId)")
    }
    
    /// Track screenshot modification
    func trackScreenshotModified(_ screenshot: Screenshot) {
        let change = GalleryChange(
            type: .screenshotModified(screenshot.id),
            timestamp: Date(),
            metadata: [
                "filename": screenshot.filename,
                "lastModified": ISO8601DateFormatter().string(from: Date())
            ]
        )
        
        addChangeToBuffer(change)
        print("✏️ Tracked screenshot modified: \(screenshot.filename)")
    }
    
    /// Track bulk import operation
    func trackBulkImport(_ screenshotIds: [UUID]) {
        let change = GalleryChange(
            type: .bulkImport(screenshotIds),
            timestamp: Date(),
            metadata: [
                "count": "\(screenshotIds.count)",
                "type": "bulk_import"
            ]
        )
        
        addChangeToBuffer(change)
        print("📦 Tracked bulk import: \(screenshotIds.count) screenshots")
    }
    
    /// Track gallery view change (for viewport optimization)
    func trackGalleryViewChange(visibleScreenshots: [UUID], collectionSize: Int) {
        let change = GalleryChange(
            type: .galleryViewChanged(visibleScreenshots),
            timestamp: Date(),
            metadata: [
                "visibleCount": "\(visibleScreenshots.count)",
                "collectionSize": "\(collectionSize)"
            ]
        )
        
        addChangeToBuffer(change)
        // Don't log view changes to avoid spam
    }
    
    // MARK: - Change Processing
    
    private func addChangeToBuffer(_ change: GalleryChange) {
        changeBuffer.append(change)
        lastChangeDetected = Date()
        
        // Process immediately if buffer is full
        if changeBuffer.count >= batchChangeThreshold {
            Task {
                await processChangeBuffer()
            }
        }
    }
    
    private func processChangeBuffer() async {
        guard !changeBuffer.isEmpty else { return }
        
        let changesToProcess = changeBuffer
        changeBuffer.removeAll()
        
        // Group changes by type for efficient processing
        let groupedChanges = Dictionary(grouping: changesToProcess) { change in
            switch change.type {
            case .screenshotAdded(_): return "added"
            case .screenshotDeleted(_): return "deleted"
            case .screenshotModified(_): return "modified"
            case .bulkImport(_): return "bulk_import"
            case .galleryViewChanged(_): return "view_changed"
            }
        }
        
        // Process each change type
        for (changeType, changes) in groupedChanges {
            await processChanges(changes, of: changeType)
        }
        
        // Update active changes
        activeChanges = changesToProcess
    }
    
    private func processChanges(_ changes: [GalleryChange], of type: String) async {
        switch type {
        case "added":
            await handleScreenshotAdditions(changes)
        case "deleted":
            await handleScreenshotDeletions(changes)
        case "modified":
            await handleScreenshotModifications(changes)
        case "bulk_import":
            await handleBulkImports(changes)
        case "view_changed":
            await handleGalleryViewChanges(changes)
        default:
            break
        }
    }
    
    // MARK: - Change Handlers
    
    private func handleScreenshotAdditions(_ changes: [GalleryChange]) async {
        let screenshotIds = changes.compactMap { change in
            if case .screenshotAdded(let id) = change.type {
                return id
            }
            return nil
        }
        
        print("📸 Processing \(screenshotIds.count) screenshot additions")
        
        // Request background thumbnail generation for new screenshots
        guard let modelContext = modelContext else { return }
        
        do {
            let screenshots = try modelContext.fetch(
                FetchDescriptor<Screenshot>(
                    predicate: #Predicate<Screenshot> { screenshot in
                        screenshotIds.contains(screenshot.id)
                    }
                )
            )
            
            // Request thumbnails with normal priority
            backgroundProcessor.requestThumbnailBatch(
                for: screenshots,
                size: CGSize(width: 200, height: 200),
                priority: .normal
            )
            
            // Also request list thumbnails
            backgroundProcessor.requestThumbnailBatch(
                for: screenshots,
                size: CGSize(width: 120, height: 120),
                priority: .background
            )
            
        } catch {
            print("❌ Failed to fetch screenshots for additions: \(error)")
        }
    }
    
    private func handleScreenshotDeletions(_ changes: [GalleryChange]) async {
        let screenshotIds = changes.compactMap { change in
            if case .screenshotDeleted(let id) = change.type {
                return id
            }
            return nil
        }
        
        print("🗑️ Processing \(screenshotIds.count) screenshot deletions")
        
        // Invalidate thumbnails for deleted screenshots
        for screenshotId in screenshotIds {
            cacheManager.removeThumbnail(for: screenshotId)
            backgroundProcessor.cancelThumbnailGeneration(for: screenshotId)
        }
    }
    
    private func handleScreenshotModifications(_ changes: [GalleryChange]) async {
        let screenshotIds = changes.compactMap { change in
            if case .screenshotModified(let id) = change.type {
                return id
            }
            return nil
        }
        
        print("✏️ Processing \(screenshotIds.count) screenshot modifications")
        
        // Invalidate and regenerate thumbnails for modified screenshots
        for screenshotId in screenshotIds {
            cacheManager.removeThumbnail(for: screenshotId)
        }
        
        // Request regeneration
        guard let modelContext = modelContext else { return }
        
        do {
            let screenshots = try modelContext.fetch(
                FetchDescriptor<Screenshot>(
                    predicate: #Predicate<Screenshot> { screenshot in
                        screenshotIds.contains(screenshot.id)
                    }
                )
            )
            
            // Request thumbnails with high priority since they were modified
            backgroundProcessor.requestThumbnailBatch(
                for: screenshots,
                size: CGSize(width: 200, height: 200),
                priority: .high
            )
            
        } catch {
            print("❌ Failed to fetch screenshots for modifications: \(error)")
        }
    }
    
    private func handleBulkImports(_ changes: [GalleryChange]) async {
        let allScreenshotIds = changes.flatMap { change in
            if case .bulkImport(let ids) = change.type {
                return ids
            }
            return []
        }
        
        print("📦 Processing bulk import: \(allScreenshotIds.count) screenshots")
        
        // Handle bulk import with background priority to avoid overwhelming the system
        guard let modelContext = modelContext else { return }
        
        do {
            let screenshots = try modelContext.fetch(
                FetchDescriptor<Screenshot>(
                    predicate: #Predicate<Screenshot> { screenshot in
                        allScreenshotIds.contains(screenshot.id)
                    }
                )
            )
            
            // Request thumbnails with background priority for bulk operations
            backgroundProcessor.requestThumbnailBatch(
                for: screenshots,
                size: CGSize(width: 120, height: 120),
                priority: .background
            )
            
        } catch {
            print("❌ Failed to fetch screenshots for bulk import: \(error)")
        }
    }
    
    private func handleGalleryViewChanges(_ changes: [GalleryChange]) async {
        // Get the most recent view change
        guard let latestChange = changes.last,
              case .galleryViewChanged(let visibleScreenshots) = latestChange.type else {
            return
        }
        
        // Preload thumbnails for visible screenshots with high priority
        for screenshotId in visibleScreenshots {
            if await cacheManager.getThumbnail(for: screenshotId, size: CGSize(width: 200, height: 200)) == nil {
                // Request thumbnail generation for visible items
                guard let modelContext = modelContext else { continue }
                
                do {
                    let screenshots = try modelContext.fetch(
                        FetchDescriptor<Screenshot>(
                            predicate: #Predicate<Screenshot> { screenshot in
                                screenshot.id == screenshotId
                            }
                        )
                    )
                    
                    if let screenshot = screenshots.first {
                        backgroundProcessor.requestThumbnail(
                            for: screenshot.id,
                            from: screenshot.imageData,
                            size: CGSize(width: 200, height: 200),
                            priority: .high
                        )
                    }
                } catch {
                    print("❌ Failed to fetch screenshot for view change: \(error)")
                }
            }
        }
    }
    
    // MARK: - Data Fingerprinting
    
    private func generateInitialFingerprint() async {
        guard let modelContext = modelContext else { return }
        
        do {
            let screenshots = try modelContext.fetch(FetchDescriptor<Screenshot>())
            let fingerprint = generateGalleryFingerprint(screenshots: screenshots)
            lastDataFingerprint = fingerprint
            print("🔍 Generated initial gallery fingerprint: \(String(fingerprint.prefix(8)))...")
        } catch {
            print("❌ Failed to generate initial fingerprint: \(error)")
        }
    }
    
    private func generateGalleryFingerprint(screenshots: [Screenshot]) -> String {
        // Create a comprehensive fingerprint of the gallery state
        let components = screenshots.map { screenshot in
            "\(screenshot.id.uuidString):\(screenshot.timestamp.timeIntervalSince1970):\(screenshot.imageData.count)"
        }.sorted() // Sort for consistent ordering
        
        let combinedString = components.joined(separator: "|")
        let hash = SHA256.hash(data: Data(combinedString.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Performance Metrics
    
    var changeTrackingMetrics: ChangeTrackingMetrics {
        return ChangeTrackingMetrics(
            isTracking: isTrackingChanges,
            lastChangeDetected: lastChangeDetected,
            activeChangesCount: activeChanges.count,
            bufferSize: changeBuffer.count,
            lastFingerprint: String(lastDataFingerprint.prefix(8))
        )
    }
    
    // MARK: - Manual Cache Invalidation
    
    /// Manually invalidate cache for specific screenshots
    func invalidateCache(for screenshotIds: [UUID]) {
        for screenshotId in screenshotIds {
            cacheManager.removeThumbnail(for: screenshotId)
        }
        print("🗑️ Manually invalidated cache for \(screenshotIds.count) screenshots")
    }
    
    /// Force cache refresh for entire gallery
    func refreshGalleryCache() {
        Task {
            await generateInitialFingerprint()
            print("🔄 Refreshed gallery cache")
        }
    }
}

// MARK: - Supporting Types

struct GalleryChange {
    let type: GalleryChangeType
    let timestamp: Date
    let metadata: [String: String]
}

enum GalleryChangeType {
    case screenshotAdded(UUID)
    case screenshotDeleted(UUID)
    case screenshotModified(UUID)
    case bulkImport([UUID])
    case galleryViewChanged([UUID])
}

struct ChangeTrackingMetrics {
    let isTracking: Bool
    let lastChangeDetected: Date?
    let activeChangesCount: Int
    let bufferSize: Int
    let lastFingerprint: String
} 