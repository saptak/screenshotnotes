import Foundation
import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import Photos

@MainActor
class ScreenshotListViewModel: ObservableObject {
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var importProgress: Double = 0.0
    
    private let imageStorageService: ImageStorageServiceProtocol
    private let ocrService: OCRServiceProtocol
    private let backgroundSemanticProcessor: BackgroundSemanticProcessor
    private var modelContext: ModelContext?
    
    // 🎯 Sprint 8.5.3.1: Task Synchronization Framework
    private let taskCoordinator = TaskCoordinator.shared
    private let taskManager = TaskManager.shared
    
    init(imageStorageService: ImageStorageServiceProtocol = ImageStorageService(),
         ocrService: OCRServiceProtocol = OCRService(),
         backgroundSemanticProcessor: BackgroundSemanticProcessor? = nil) {
        self.imageStorageService = imageStorageService
        self.ocrService = ocrService
        self.backgroundSemanticProcessor = backgroundSemanticProcessor ?? BackgroundSemanticProcessor()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func importImages(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        
        // 🎯 Sprint 8.5.3.1: Use coordinated image import workflow
        isImporting = true
        importProgress = 0.0
        
        let importedCount = await taskCoordinator.executeImageImportWorkflow(
            items: items,
            modelContext: modelContext!,
            backgroundProcessors: BackgroundProcessors(
                ocrProcessor: BackgroundOCRProcessor(),
                visionProcessor: BackgroundVisionProcessor(),
                semanticProcessor: backgroundSemanticProcessor
            )
        )
        
        isImporting = false
        importProgress = 0.0
        
        // Add haptic feedback for completion
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        print("ScreenshotListViewModel: Successfully imported \(importedCount) images")
    }
    
    private func importSingleImage(from item: PhotosPickerItem) async throws {
        guard let data = try await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let modelContext = modelContext else {
            throw ImportError.loadFailed
        }
        
        let filename = generateFilename(from: item.itemIdentifier)
        let imageData = try await imageStorageService.saveImage(image, filename: filename)
        
        let screenshot = Screenshot(imageData: imageData, filename: filename)
        modelContext.insert(screenshot)
        
        // Save immediately so the screenshot is available
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(screenshot)
            throw ImportError.saveFailed
        }
        
        // Process full semantic analysis in background
        Task {
            await backgroundSemanticProcessor.processScreenshot(screenshot, in: modelContext)
        }
    }
    
    private func generateFilename(from identifier: String?) -> String {
        let timestamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
        let suffix = String(identifier?.suffix(8) ?? UUID().uuidString.prefix(8))
        return "screenshot_\(timestamp)_\(suffix).jpg"
    }
    
    func deleteScreenshot(_ screenshot: Screenshot) {
        guard let modelContext = modelContext else { return }
        
        // 🎯 Sprint 8.5.3.1: Use coordinated task management for deletion
        Task {
            await taskManager.execute(
                category: .userInterface,
                priority: .critical,
                description: "Delete screenshot: \(screenshot.filename)"
            ) {
                do {
                    try await self.imageStorageService.deleteImageData(screenshot.imageData)
                    
                    await MainActor.run {
                        guard let context = self.modelContext else { return }
                        context.delete(screenshot)
                        do {
                            try context.save()
                            
                            // Add haptic feedback for deletion
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        } catch {
                            self.handleDeletionError(error)
                        }
                    }
                } catch {
                    self.handleDeletionError(error)
                }
            }
        }
    }
    
    private func handleImportError(_ error: Error) async {
        await MainActor.run {
            if let importError = error as? ImportError {
                errorMessage = importError.localizedDescription
            } else if let storageError = error as? ImageStorageError {
                errorMessage = storageError.localizedDescription
            } else {
                errorMessage = "An unexpected error occurred while importing the image."
            }
            showingError = true
            isImporting = false
            
            // Add haptic feedback for error
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }
    }
    
    private func handleDeletionError(_ error: Error) {
        errorMessage = "Unable to delete the screenshot. Please try again."
        showingError = true
        
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.error)
    }
    
    func dismissError() {
        showingError = false
        errorMessage = nil
    }
    
    func importAllExistingScreenshots() async {
        guard !isImporting else { return }
        guard let modelContext = modelContext else { return }
        
        // Request photo library permission if needed
        let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            await handleImportError(ImportError.loadFailed)
            return
        }
        
        isImporting = true
        importProgress = 0.0
        
        // Fetch all screenshots from photo library
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let screenshotAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        // Filter out already imported screenshots
        var assetsToImport: [PHAsset] = []
        screenshotAssets.enumerateObjects { asset, _, _ in
            // Check if already imported using asset identifier
            let assetId = asset.localIdentifier
            let existingScreenshots = try? modelContext.fetch(
                FetchDescriptor<Screenshot>(
                    predicate: #Predicate<Screenshot> { screenshot in
                        screenshot.assetIdentifier == assetId
                    }
                )
            )
            
            if existingScreenshots?.isEmpty != false {
                assetsToImport.append(asset)
            }
        }
        
        guard !assetsToImport.isEmpty else {
            isImporting = false
            importProgress = 0.0
            return
        }
        
        print("📸 Importing \(assetsToImport.count) existing screenshots")
        
        let totalAssets = Double(assetsToImport.count)
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact
        requestOptions.isNetworkAccessAllowed = true
        
        // Process screenshots sequentially to avoid memory issues
        for (index, asset) in assetsToImport.enumerated() {
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
                                
                                self.importProgress = Double(index + 1) / totalAssets
                            }
                            
                            // Process full semantic analysis in background
                            Task {
                                await self.backgroundSemanticProcessor.processScreenshot(screenshot, in: modelContext)
                            }
                        } catch {
                            print("❌ Failed to import screenshot: \(error)")
                        }
                        continuation.resume()
                    }
                }
            }
        }
        
        isImporting = false
        importProgress = 0.0
        
        // Add haptic feedback for completion
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        print("📸 Completed importing \(assetsToImport.count) existing screenshots")
    }
    
    /// Process existing screenshots that need semantic analysis
    func processExistingScreenshots() async {
        guard let modelContext = modelContext else { return }
        await backgroundSemanticProcessor.processScreenshotsNeedingAnalysis(in: modelContext)
    }
    
    /// Get background semantic processor for observing progress
    var semanticProcessor: BackgroundSemanticProcessor {
        return backgroundSemanticProcessor
    }
}

enum ImportError: LocalizedError {
    case loadFailed
    case saveFailed
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Unable to load the selected image. Please try again."
        case .saveFailed:
            return "Unable to save the image. Please check available storage."
        case .processingFailed:
            return "Unable to process the image. Please try a different image."
        }
    }
}
