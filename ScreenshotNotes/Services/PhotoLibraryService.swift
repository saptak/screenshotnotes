import Foundation
import Photos
import SwiftData
import UIKit

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
class PhotoLibraryService: NSObject, PhotoLibraryServiceProtocol, ObservableObject {
    private var modelContext: ModelContext?
    private let imageStorageService: ImageStorageServiceProtocol
    private let hapticService: HapticFeedbackService
    private var isMonitoring = false
    // Keep a reference to the fetch result for change observation
    private var screenshotsFetchResult: PHFetchResult<PHAsset>?
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var automaticImportEnabled = true
    
    // Race condition protection using async-safe actor
    private let importCoordinator = ImportCoordinator()

    init(imageStorageService: ImageStorageServiceProtocol = ImageStorageService(),
         hapticService: HapticFeedbackService? = nil) {
        self.imageStorageService = imageStorageService
        self.hapticService = hapticService ?? HapticFeedbackService.shared
        super.init()
        // Load user preference - defaults to true for first launch
        automaticImportEnabled = UserDefaults.standard.object(forKey: "automaticImportEnabled") as? Bool ?? true
        // Check current authorization status
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    } // <-- Added missing closing brace for init
    // Batch import method for extremely lazy, incremental import
    /// Imports a batch of past screenshots from the user's photo library.
    /// - Parameters:
    ///   - batch: The batch index (0-based)
    ///   - batchSize: The number of screenshots to import per batch
    /// - Returns: (imported: Int, skipped: Int, hasMore: Bool)
    func importPastScreenshotsBatch(batch: Int, batchSize: Int) async -> (imported: Int, skipped: Int, hasMore: Bool) {
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
            print("❌ Photo library access not authorized")
            return (imported: 0, skipped: 0, hasMore: false)
        }
        guard let modelContext = modelContext else {
            print("❌ Model context not available")
            return (imported: 0, skipped: 0, hasMore: false)
        }
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allScreenshots = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let total = allScreenshots.count
        let start = batch * batchSize
        let end = min(start + batchSize, total)
        if start >= end {
            return (imported: 0, skipped: 0, hasMore: false)
        }
        var importedCount = 0
        var skippedCount = 0
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact
        requestOptions.isNetworkAccessAllowed = true
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
            await withCheckedContinuation { continuation in
                imageManager.requestImage(
                    for: asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFit,
                    options: requestOptions
                ) { [weak self] image, _ in
                    guard let image = image, let self = self else {
                        continuation.resume()
                        return
                    }
                    Task {
                        do {
                            let imageData = try await self.imageStorageService.saveImage(
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
                        } catch {
                            print("❌ Failed to batch import screenshot: \(error)")
                        }
                        continuation.resume()
                    }
                }
            }
        }
        // Individual saves are now handled per screenshot for progressive updates
        let hasMore = end < total
        return (imported: importedCount, skipped: skippedCount, hasMore: hasMore)
    }
    func setModelContext(_ context: ModelContext) {
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
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume(returning: status)
                        return
                    }
                    
                    self.authorizationStatus = status
                    
                    // Handle different authorization states
                    switch status {
                    case .authorized:
                        print("📸 Photo library access granted")
                        if self.automaticImportEnabled {
                            self.startMonitoring()
                        }
                    case .denied, .restricted:
                        print("❌ Photo library access denied")
                        self.stopMonitoring()
                    case .limited:
                        print("⚠️ Photo library access limited")
                        if self.automaticImportEnabled {
                            self.startMonitoring()
                        }
                    case .notDetermined:
                        print("🤷 Photo library access not determined")
                    @unknown default:
                        print("🤷 Unknown photo library authorization status")
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
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact
        requestOptions.isNetworkAccessAllowed = true
        
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
                
                // Import the screenshot
                await withCheckedContinuation { continuation in
                    imageManager.requestImage(
                        for: asset,
                        targetSize: PHImageManagerMaximumSize,
                        contentMode: .aspectFit,
                        options: requestOptions
                    ) { [weak self] image, _ in
                        guard let image = image, let self = self else {
                            continuation.resume()
                            return
                        }
                        
                        Task {
                            do {
                                let imageData = try await self.imageStorageService.saveImage(
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
                                print("❌ Failed to import screenshot: \(error)")
                            }
                            continuation.resume()
                        }
                    }
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
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact
        requestOptions.isNetworkAccessAllowed = true
        
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
            
            await withCheckedContinuation { continuation in
                imageManager.requestImage(
                    for: asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFit,
                    options: requestOptions
                ) { [weak self] image, _ in
                    guard let image = image, let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    Task {
                        do {
                            let imageData = try await self.imageStorageService.saveImage(
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
                                self.hapticService.triggerHaptic(.successFeedback)
                                print("📸 Auto-imported screenshot: \(asset.localIdentifier)")
                            }
                        } catch {
                            print("❌ Failed to auto-import screenshot: \(error)")
                            await MainActor.run {
                                self.hapticService.triggerHaptic(.errorFeedback)
                            }
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver
extension PhotoLibraryService: @preconcurrency PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
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