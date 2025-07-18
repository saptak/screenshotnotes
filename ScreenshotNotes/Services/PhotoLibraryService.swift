import Foundation
import Photos
import SwiftData
import UIKit
import OSLog

@MainActor
protocol PhotoLibraryServiceProtocol {
    func startMonitoring()
    func stopMonitoring()
    func requestPhotoLibraryPermission() async -> PHAuthorizationStatus
    func isAutomaticImportEnabled() -> Bool
    func setAutomaticImportEnabled(_ enabled: Bool)
    func importAllPastScreenshots() async -> (imported: Int, skipped: Int)
}


@MainActor
public class PhotoLibraryService: NSObject, PhotoLibraryServiceProtocol, ObservableObject, MemoryTrackable, ResourceCleanupProtocol {
    private var modelContext: ModelContext?
    
    // 🎯 Sprint 8.5.3.2: Memory Management & Leak Prevention
    private var imageStorageService: ImageStorageServiceProtocol? // Cannot be weak as it's a protocol
    private weak var hapticService: HapticFeedbackService?
    private weak var networkRetryService: NetworkRetryService?
    private weak var transactionService: TransactionService?
    
    private var isMonitoring = false
    // Keep a reference to the fetch result for change observation
    private var screenshotsFetchResult: PHFetchResult<PHAsset>?
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var automaticImportEnabled = true
    
    // Race condition protection using async-safe actor
    private let importCoordinator = ImportCoordinator()
    
    // 🎯 Sprint 8.5.2: Error handling integration
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "PhotoLibraryService")
    
    // 🎯 Sprint 8.5.3.2: Memory Management
    private let memoryManager = MemoryManager.shared

    init(imageStorageService: ImageStorageServiceProtocol = ImageStorageService(),
         hapticService: HapticFeedbackService? = nil,
         networkRetryService: NetworkRetryService = NetworkRetryService.shared,
         transactionService: TransactionService = TransactionService.shared) {
        self.imageStorageService = imageStorageService
        self.hapticService = hapticService ?? HapticFeedbackService.shared
        self.networkRetryService = networkRetryService
        self.transactionService = transactionService
        super.init()
        
        // Load user preference - defaults to true for first launch
        automaticImportEnabled = UserDefaults.standard.object(forKey: "automaticImportEnabled") as? Bool ?? true
        // Check current authorization status
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        // 🎯 Sprint 8.5.3.2: Initialize memory management
        startMemoryTracking()
        registerForAutomaticCleanup()
        
        logger.info("PhotoLibraryService: Initialized with memory tracking")
    }
    
    deinit {
        // 🎯 Sprint 8.5.3.2: Proper cleanup in deinit
        // Note: Cannot use async methods in deinit - cleanup will be handled by system
        // The memory manager will handle cleanup when the object is deallocated
        screenshotsFetchResult = nil
        
        logger.info("PhotoLibraryService: Deallocated")
    }
    // Batch import method for extremely lazy, incremental import
    /// Imports a batch of past screenshots from the user's photo library.
    /// - Parameters:
    ///   - batch: The batch index (0-based)
    ///   - batchSize: The number of screenshots to import per batch
    /// - Returns: (imported: Int, skipped: Int, hasMore: Bool)
    func importPastScreenshotsBatch(batch: Int, batchSize: Int) async -> (imported: Int, skipped: Int, hasMore: Bool) {
        print("📸 PhotoLibraryService: importPastScreenshotsBatch called (batch: \(batch), batchSize: \(batchSize))")
        
        // Attempt to start import operation with async-safe coordination
        guard let importId = await importCoordinator.startImport() else {
            print("⚠️ Import already in progress, skipping batch \(batch)")
            return (imported: 0, skipped: 0, hasMore: false)
        }
        defer { 
            Task { await importCoordinator.endImport(importId: importId) }
        }
        
        // Set bulk import state to prevent aggressive cache clearing
        GalleryPerformanceMonitor.shared.setBulkImportState(true)
        defer {
            GalleryPerformanceMonitor.shared.setBulkImportState(false)
        }
        
        guard authorizationStatus == .authorized else {
            print("❌ Photo library access not authorized (status: \(authorizationStatus))")
            return (imported: 0, skipped: 0, hasMore: false)
        }
        guard let modelContext = modelContext else {
            print("❌ Model context not available")
            return (imported: 0, skipped: 0, hasMore: false)
        }
        
        print("📸 PhotoLibraryService: Permissions and context OK, proceeding with batch import")
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allScreenshots = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let total = allScreenshots.count
        let start = batch * batchSize
        let end = min(start + batchSize, total)
        
        print("📸 PhotoLibraryService: Found \(total) total screenshots, processing range \(start)..<\(end)")
        
        if start >= end {
            print("📸 PhotoLibraryService: No more screenshots to process (start=\(start), end=\(end))")
            return (imported: 0, skipped: 0, hasMore: false)
        }
        var importedCount = 0
        var skippedCount = 0
        
        for i in start..<end {
            let asset = allScreenshots.object(at: i)
            let assetId = asset.localIdentifier
            let existingScreenshots = try? modelContext.fetch(
                FetchDescriptor<Screenshot>(
                    predicate: #Predicate<Screenshot> { screenshot in
                        screenshot.assetIdentifier == assetId
                    }
                )
            )
            if existingScreenshots?.isEmpty == false {
                skippedCount += 1
                continue
            }
            do {
                guard let retryService = networkRetryService,
                      let storageService = imageStorageService else {
                    skippedCount += 1
                    continue
                }
                
                let image = try await retryService.requestImageWithRetry(
                    asset: asset,
                    targetSize: PHImageManagerMaximumSize,
                    configuration: .standard
                )
                
                let imageData = try await storageService.saveImage(
                    image,
                    filename: "screenshot_\(asset.localIdentifier)"
                )
                
                let screenshot = Screenshot(
                    imageData: imageData,
                    filename: "screenshot_\(asset.creationDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)",
                    timestamp: asset.creationDate ?? Date(),
                    assetIdentifier: asset.localIdentifier
                )
                
                await MainActor.run {
                    modelContext.insert(screenshot)
                    // Save immediately for progressive UI updates
                    try? modelContext.save()
                    importedCount += 1
                    print("📸 Batch imported screenshot \(importedCount): \(asset.localIdentifier)")
                    
                    // Proactively generate thumbnail for better UX
                    Task.detached { [screenshot] in
                        _ = await ThumbnailService.shared.getThumbnail(
                            for: screenshot.id,
                            from: screenshot.imageData,
                            size: ThumbnailService.listThumbnailSize
                        )
                    }
                }
                
                // Add small delay between imports to prevent resource starvation
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            } catch {
                print("❌ Failed to batch import screenshot with retry: \(error)")
                // Continue with next screenshot even if this one fails
            }
        }
        // Individual saves are now handled per screenshot for progressive updates
        let hasMore = end < total
        return (imported: importedCount, skipped: skippedCount, hasMore: hasMore)
    }
    func setModelContext(_ context: ModelContext) {
        print("📸 PhotoLibraryService: setModelContext called")
        self.modelContext = context
    }
    
    func startMonitoring() {
        guard !isMonitoring else { 
            print("📸 Already monitoring, skipping")
            return 
        }
        guard automaticImportEnabled else { 
            print("📸 Automatic import disabled, not starting monitoring")
            return 
        }
        guard authorizationStatus == .authorized else { 
            print("📸 Photo library not authorized (status: \(authorizationStatus)), not starting monitoring")
            return 
        }
        
        // Create the initial fetch result for screenshots before registering for changes
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        screenshotsFetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        print("📸 Initial fetch found \(screenshotsFetchResult?.count ?? 0) screenshots")
        
        PHPhotoLibrary.shared().register(self)
        isMonitoring = true
        print("📸 Photo library monitoring started successfully")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        screenshotsFetchResult = nil
        isMonitoring = false
        print("📸 Photo library monitoring stopped")
    }
    
    func requestPhotoLibraryPermission() async -> PHAuthorizationStatus {
        logger.info("Requesting photo library permission")
        
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume(returning: status)
                        return
                    }
                    
                    self.authorizationStatus = status
                    
                    // Handle different authorization states with error handling
                    switch status {
                    case .authorized:
                        self.logger.info("Photo library access granted")
                        if self.automaticImportEnabled {
                            self.startMonitoring()
                        }
                    case .denied, .restricted:
                        self.logger.warning("Photo library access denied")
                        self.stopMonitoring()
                        
                        // Report permission error
                        let permissionError = AppError(
                            type: .permission(.photoLibraryDenied),
                            context: .photoImport,
                            severity: .error,
                            source: "PhotoLibraryService.requestPhotoLibraryPermission",
                            originalError: nil,
                            retryAttempt: 0,
                            timestamp: Date(),
                            recoveryStrategy: PermissionRecoveryStrategy(permissionError: .photoLibraryDenied, context: .photoImport),
                            retryStrategy: nil,
                            requiresUserFeedback: true
                        )
                        AppErrorHandler.shared.handle(permissionError, context: .photoImport, source: "PhotoLibraryService.requestPhotoLibraryPermission")
                        
                    case .limited:
                        self.logger.info("Photo library access limited")
                        if self.automaticImportEnabled {
                            self.startMonitoring()
                        }
                    case .notDetermined:
                        self.logger.info("Photo library access not determined")
                    @unknown default:
                        self.logger.warning("Unknown photo library authorization status")
                    }
                    
                    continuation.resume(returning: status)
                }
            }
        }
    }
    
    func isAutomaticImportEnabled() -> Bool {
        return automaticImportEnabled
    }
    
    func setAutomaticImportEnabled(_ enabled: Bool) {
        print("📸 Setting automatic import to: \(enabled)")
        automaticImportEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "automaticImportEnabled")
        
        if enabled && authorizationStatus == .authorized {
            print("📸 Starting monitoring due to enabled setting")
            startMonitoring()
        } else {
            print("📸 Stopping monitoring - enabled: \(enabled), authorized: \(authorizationStatus == .authorized)")
            stopMonitoring()
        }
    }
    
    func importAllPastScreenshotsWithTransaction() async -> (imported: Int, skipped: Int) {
        // Attempt to start import operation with async-safe coordination
        guard let importId = await importCoordinator.startImport() else {
            print("⚠️ Import already in progress, aborting new import request")
            return (imported: 0, skipped: 0)
        }
        defer { 
            Task { await importCoordinator.endImport(importId: importId) }
        }
        
        guard authorizationStatus == .authorized else {
            print("❌ Photo library access not authorized")
            return (imported: 0, skipped: 0)
        }
        
        guard let modelContext = modelContext else {
            print("❌ Model context not available")
            return (imported: 0, skipped: 0)
        }
        
        // Set bulk import state to prevent aggressive cache clearing
        GalleryPerformanceMonitor.shared.setBulkImportState(true)
        defer {
            GalleryPerformanceMonitor.shared.setBulkImportState(false)
        }
        
        print("📸 Starting transactional import of all past screenshots...")
        
        // Fetch all screenshots from Photos app
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let allScreenshots = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        print("📸 Found \(allScreenshots.count) total screenshots in Photo Library")
        
        // Convert to array for transaction processing
        var assets: [PHAsset] = []
        for i in 0..<allScreenshots.count {
            let asset = allScreenshots.object(at: i)
            
            // Check if already imported
            let assetId = asset.localIdentifier
            let existingScreenshots = try? modelContext.fetch(
                FetchDescriptor<Screenshot>(
                    predicate: #Predicate<Screenshot> { screenshot in
                        screenshot.assetIdentifier == assetId
                    }
                )
            )
            
            if existingScreenshots?.isEmpty == false {
                // Already imported, skip
                continue
            }
            
            assets.append(asset)
        }
        
        let skippedCount = allScreenshots.count - assets.count
        print("📸 Will import \(assets.count) new screenshots, skipping \(skippedCount) existing ones")
        
        // Use transaction service for reliable batch import
        guard let service = transactionService else {
            print("❌ TransactionService not available for batch import")
            return (imported: 0, skipped: assets.count)
        }
        
        let result = await service.executeScreenshotImportTransaction(
            modelContext: modelContext,
            assets: assets,
            configuration: .standard
        ) { [weak self] asset, index in
            guard let self = self else { 
                throw NSError(domain: "PhotoLibraryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])
            }
            
            // Import with network retry
            guard let retryService = self.networkRetryService else {
                throw NSError(domain: "PhotoLibraryService", code: -2, userInfo: [NSLocalizedDescriptionKey: "NetworkRetryService not available"])
            }
            let image = try await retryService.requestImageWithRetry(
                asset: asset,
                targetSize: PHImageManagerMaximumSize,
                configuration: .standard
            )
            
            guard let storageService = self.imageStorageService else {
                throw NSError(domain: "PhotoLibraryService", code: -3, userInfo: [NSLocalizedDescriptionKey: "ImageStorageService not available"])
            }
            let imageData = try await storageService.saveImage(
                image,
                filename: "screenshot_\(asset.localIdentifier)"
            )
            
            let screenshot = Screenshot(
                imageData: imageData,
                filename: "screenshot_\(asset.creationDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)",
                timestamp: asset.creationDate ?? Date(),
                assetIdentifier: asset.localIdentifier
            )
            
            // Proactively generate thumbnail for better UX
            Task.detached { [screenshot] in
                _ = await ThumbnailService.shared.getThumbnail(
                    for: screenshot.id,
                    from: screenshot.imageData,
                    size: ThumbnailService.listThumbnailSize
                )
            }
            
            return screenshot.id
        }
        
        // Handle transaction result
        switch result {
        case .success(let itemsProcessed):
            print("📸 Transactional import completed successfully: \(itemsProcessed) imported, \(skippedCount) skipped")
            return (imported: itemsProcessed, skipped: skippedCount)
        case .failure(let error, let itemsProcessed):
            print("❌ Transactional import failed: \(error.localizedDescription), \(itemsProcessed) items processed")
            return (imported: itemsProcessed, skipped: skippedCount)
        case .partialSuccess(let itemsProcessed, let failures):
            print("⚠️ Transactional import partially succeeded: \(itemsProcessed) imported, \(failures.count) failures, \(skippedCount) skipped")
            return (imported: itemsProcessed, skipped: skippedCount)
        }
    }
    
    func importAllPastScreenshots() async -> (imported: Int, skipped: Int) {
        // Attempt to start import operation with async-safe coordination
        guard let importId = await importCoordinator.startImport() else {
            print("⚠️ Import already in progress, aborting new import request")
            return (imported: 0, skipped: 0)
        }
        defer { 
            Task { await importCoordinator.endImport(importId: importId) }
        }
        
        guard authorizationStatus == .authorized else {
            print("❌ Photo library access not authorized")
            return (imported: 0, skipped: 0)
        }
        
        guard let modelContext = modelContext else {
            print("❌ Model context not available")
            return (imported: 0, skipped: 0)
        }
        
        // Set bulk import state to prevent aggressive cache clearing
        GalleryPerformanceMonitor.shared.setBulkImportState(true)
        defer {
            GalleryPerformanceMonitor.shared.setBulkImportState(false)
        }
        
        print("📸 Starting manual import of all past screenshots...")
        
        // Fetch all screenshots from Photos app
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let allScreenshots = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        print("📸 Found \(allScreenshots.count) total screenshots in Photo Library")
        
        var importedCount = 0
        var skippedCount = 0
        
        // Process screenshots in batches to avoid memory issues
        let batchSize = 10
        for i in stride(from: 0, to: allScreenshots.count, by: batchSize) {
            let endIndex = min(i + batchSize, allScreenshots.count)
            
            for j in i..<endIndex {
                let asset = allScreenshots.object(at: j)
                
                // Check if already imported
                let assetId = asset.localIdentifier
                let existingScreenshots = try? modelContext.fetch(
                    FetchDescriptor<Screenshot>(
                        predicate: #Predicate<Screenshot> { screenshot in
                            screenshot.assetIdentifier == assetId
                        }
                    )
                )
                
                if existingScreenshots?.isEmpty == false {
                    skippedCount += 1
                    continue // Already imported
                }
                
                // Import the screenshot with retry logic
                do {
                    guard let retryService = networkRetryService else {
                        print("❌ NetworkRetryService not available, skipping asset")
                        skippedCount += 1
                        continue
                    }
                    let image = try await retryService.requestImageWithRetry(
                        asset: asset,
                        targetSize: PHImageManagerMaximumSize,
                        configuration: .standard
                    )
                    
                    guard let storageService = imageStorageService else {
                        print("❌ ImageStorageService not available, skipping asset")
                        skippedCount += 1
                        continue
                    }
                    let imageData = try await storageService.saveImage(
                        image,
                        filename: "screenshot_\(asset.localIdentifier)"
                    )
                    
                    let screenshot = Screenshot(
                        imageData: imageData,
                        filename: "screenshot_\(asset.creationDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)",
                        timestamp: asset.creationDate ?? Date(),
                        assetIdentifier: asset.localIdentifier
                    )
                    
                    await MainActor.run {
                        modelContext.insert(screenshot)
                        importedCount += 1
                        print("📸 Imported screenshot \(importedCount): \(asset.localIdentifier)")
                        
                        // Proactively generate thumbnail for better UX
                        Task.detached { [screenshot] in
                            _ = await ThumbnailService.shared.getThumbnail(
                                for: screenshot.id,
                                from: screenshot.imageData,
                                size: ThumbnailService.listThumbnailSize
                            )
                        }
                    }
                } catch {
                    print("❌ Failed to import screenshot with retry: \(error)")
                    // Continue with next screenshot even if this one fails
                }
            }
            
            // Save progress after each batch
            try? modelContext.save()
            
            // Add small delay to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Final save
        try? modelContext.save()
        
        print("📸 Manual import completed: \(importedCount) imported, \(skippedCount) skipped")
        return (imported: importedCount, skipped: skippedCount)
    }
    
    private func importScreenshots(_ screenshots: [PHAsset]) async {
        guard let modelContext = modelContext else { return }
        
        // Process screenshots sequentially to avoid memory issues
        for asset in screenshots {
            // Check if already imported using creation date and identifier
            let assetId = asset.localIdentifier
            let existingScreenshots = try? modelContext.fetch(
                FetchDescriptor<Screenshot>(
                    predicate: #Predicate<Screenshot> { screenshot in
                        screenshot.assetIdentifier == assetId
                    }
                )
            )
            
            if existingScreenshots?.isEmpty == false {
                continue // Already imported
            }
            
            do {
                guard let retryService = networkRetryService else {
                    print("❌ NetworkRetryService not available")
                    continue
                }
                let image = try await retryService.requestImageWithRetry(
                    asset: asset,
                    targetSize: PHImageManagerMaximumSize,
                    configuration: .conservative  // Use conservative for auto-import to avoid battery drain
                )
                
                guard let storageService = imageStorageService else {
                    print("❌ ImageStorageService not available")
                    continue
                }
                let imageData = try await storageService.saveImage(
                    image,
                    filename: "screenshot_\(asset.localIdentifier)"
                )
                
                let screenshot = Screenshot(
                    imageData: imageData,
                    filename: "screenshot_\(Date().timeIntervalSince1970)",
                    timestamp: asset.creationDate ?? Date(),
                    assetIdentifier: asset.localIdentifier
                )
                
                await MainActor.run {
                    modelContext.insert(screenshot)
                    try? modelContext.save()
                    
                    // Provide haptic feedback for successful import
                    hapticService?.triggerHaptic(.successFeedback)
                    print("📸 Auto-imported screenshot: \(asset.localIdentifier)")
                }
                
                // Trigger background OCR and AI processing for the newly imported screenshot
                Task.detached { @MainActor in
                    // Small delay to ensure the screenshot is fully saved
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await BackgroundSemanticProcessor.shared.processScreenshotsNeedingAnalysis(in: modelContext)
                }
            } catch {
                print("❌ Failed to auto-import screenshot with retry: \(error)")
                await MainActor.run {
                    hapticService?.triggerHaptic(.errorFeedback)
                }
            }
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver
extension PhotoLibraryService: @preconcurrency PHPhotoLibraryChangeObserver {
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            print("📸 Photo library changed - checking for screenshots")
            
            guard automaticImportEnabled else { 
                print("📸 Automatic import disabled, ignoring change")
                return 
            }
            
            guard let currentFetchResult = screenshotsFetchResult else {
                print("📸 No stored fetch result available - monitoring not properly initialized")
                return
            }
            
            print("📸 Current fetch result has \(currentFetchResult.count) screenshots")
            
            // Check if there are changes to our stored screenshot fetch result
            if let changeDetails = changeInstance.changeDetails(for: currentFetchResult) {
                print("📸 Change details available - hasIncrementalChanges: \(changeDetails.hasIncrementalChanges)")
                
                // Update our stored fetch result
                screenshotsFetchResult = changeDetails.fetchResultAfterChanges
                
                if changeDetails.hasIncrementalChanges {
                    // Process only newly inserted screenshots
                    let newScreenshots = changeDetails.insertedObjects
                    let removedScreenshots = changeDetails.removedObjects
                    let changedScreenshots = changeDetails.changedObjects
                    
                    print("📸 New: \(newScreenshots.count), Removed: \(removedScreenshots.count), Changed: \(changedScreenshots.count)")
                    
                    if !newScreenshots.isEmpty {
                        print("📸 Processing \(newScreenshots.count) new screenshot(s)")
                        await importScreenshots(newScreenshots)
                    }
                } else {
                    print("📸 No incremental changes detected")
                }
            } else {
                print("📸 No change details available for stored screenshot collection")
            }
        }
    }
}

// MARK: - Import Coordination Actor

/// Actor to provide async-safe coordination for import operations
actor ImportCoordinator {
    private var isImporting = false
    private var currentImportId: UUID?
    
    /// Attempt to start an import operation
    /// - Returns: Import session ID if successful, nil if import already in progress
    func startImport() -> UUID? {
        guard !isImporting else {
            print("⚠️ Import already in progress with ID: \(currentImportId?.uuidString ?? "unknown")")
            return nil
        }
        
        let importId = UUID()
        isImporting = true
        currentImportId = importId
        print("🚀 Starting import with ID: \(importId.uuidString)")
        return importId
    }
    
    /// End an import operation
    /// - Parameter importId: The import session ID returned by startImport()
    func endImport(importId: UUID) {
        guard currentImportId == importId else {
            print("⚠️ Attempting to end import with mismatched ID: \(importId.uuidString)")
            return
        }
        
        isImporting = false
        currentImportId = nil
        print("✅ Ended import with ID: \(importId.uuidString)")
    }
    
    /// Check if an import is currently in progress
    var importInProgress: Bool {
        return isImporting
    }
}

// MARK: - 🎯 Sprint 8.5.3.2: ResourceCleanupProtocol Implementation

extension PhotoLibraryService {
    
    public func performLightCleanup() async {
        logger.info("PhotoLibraryService: Performing light cleanup")
        
        // Clear fetch result cache if not monitoring
        if !isMonitoring {
            screenshotsFetchResult = nil
        }
        
        // Reset authorization status if needed
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus != authorizationStatus {
            authorizationStatus = currentStatus
        }
    }
    
    public func performDeepCleanup() async {
        logger.warning("PhotoLibraryService: Performing deep cleanup")
        
        // Stop monitoring to free resources
        stopMonitoring()
        
        // Clear all cached data
        screenshotsFetchResult = nil
        
        // Clear service references to free memory
        imageStorageService = nil
        hapticService = nil
        networkRetryService = nil
        transactionService = nil
        
        // Clear model context reference if safe
        let isImporting = await importCoordinator.importInProgress
        if !isImporting {
            modelContext = nil
        }
    }
    
    public nonisolated func getEstimatedMemoryUsage() -> UInt64 {
        var usage: UInt64 = 0
        
        // Base service size
        usage += 8192 // PhotoLibraryService base size (larger due to PHPhotoLibrary integration)
        
        // Add estimated memory for service references
        usage += 16384 // Service references overhead estimate
        
        return usage
    }
    
    public nonisolated var cleanupPriority: Int { 60 } // Medium-high priority for photo library service
    
    public nonisolated var cleanupIdentifier: String { "PhotoLibraryService" }
}