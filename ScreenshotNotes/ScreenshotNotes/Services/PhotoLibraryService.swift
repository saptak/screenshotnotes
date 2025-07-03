import Foundation
import Photos
import SwiftData
import UIKit

protocol PhotoLibraryServiceProtocol {
    func startMonitoring()
    func stopMonitoring()
    func requestPhotoLibraryPermission() async -> PHAuthorizationStatus
    func isAutomaticImportEnabled() -> Bool
    func setAutomaticImportEnabled(_ enabled: Bool)
}

@MainActor
class PhotoLibraryService: NSObject, PhotoLibraryServiceProtocol, ObservableObject {
    private var modelContext: ModelContext?
    private let imageStorageService: ImageStorageServiceProtocol
    private let hapticService: HapticServiceProtocol
    private var isMonitoring = false
    
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var automaticImportEnabled = true
    
    init(imageStorageService: ImageStorageServiceProtocol = ImageStorageService(),
         hapticService: HapticServiceProtocol = HapticService.shared) {
        self.imageStorageService = imageStorageService
        self.hapticService = hapticService
        super.init()
        
        // Load user preference
        automaticImportEnabled = UserDefaults.standard.bool(forKey: "automaticImportEnabled")
        
        // Check current authorization status
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        guard automaticImportEnabled else { return }
        guard authorizationStatus == .authorized else { return }
        
        PHPhotoLibrary.shared().register(self)
        isMonitoring = true
        print("📸 Photo library monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
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
        automaticImportEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "automaticImportEnabled")
        
        if enabled && authorizationStatus == .authorized {
            startMonitoring()
        } else {
            stopMonitoring()
        }
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
                                self.hapticService.notification(.success)
                                print("📸 Auto-imported screenshot: \(asset.localIdentifier)")
                            }
                        } catch {
                            print("❌ Failed to auto-import screenshot: \(error)")
                            await MainActor.run {
                                self.hapticService.notification(.error)
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
            guard automaticImportEnabled else { return }
            
            // Create a fetch request for screenshots
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 50 // Limit to recent screenshots
            
            let screenshotAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            // Check if there are changes to screenshot assets
            if let changeDetails = changeInstance.changeDetails(for: screenshotAssets) {
                if changeDetails.hasIncrementalChanges {
                    // Process only newly inserted screenshots
                    let newScreenshots = changeDetails.insertedObjects
                    
                    if !newScreenshots.isEmpty {
                        print("📸 Detected \(newScreenshots.count) new screenshot(s)")
                        await importScreenshots(newScreenshots)
                    }
                }
            }
        }
    }
}