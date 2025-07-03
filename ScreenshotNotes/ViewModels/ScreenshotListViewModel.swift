import Foundation
import SwiftUI
import SwiftData
import PhotosUI

@MainActor
class ScreenshotListViewModel: ObservableObject {
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var importProgress: Double = 0.0
    
    private let imageStorageService: ImageStorageServiceProtocol
    private var modelContext: ModelContext?
    
    init(imageStorageService: ImageStorageServiceProtocol = ImageStorageService()) {
        self.imageStorageService = imageStorageService
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func importImages(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        
        isImporting = true
        importProgress = 0.0
        
        let totalItems = Double(items.count)
        
        for (index, item) in items.enumerated() {
            do {
                try await importSingleImage(from: item)
                importProgress = Double(index + 1) / totalItems
            } catch {
                await handleImportError(error)
                break
            }
        }
        
        isImporting = false
        importProgress = 0.0
        
        // Add haptic feedback for completion
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
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
        
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(screenshot)
            throw ImportError.saveFailed
        }
    }
    
    private func generateFilename(from identifier: String?) -> String {
        let timestamp = Date().formatted(.iso8601.year().month().day().hour().minute().second())
        let suffix = identifier?.suffix(8) ?? String(UUID().uuidString.prefix(8))
        return "screenshot_\(timestamp)_\(suffix).jpg"
    }
    
    func deleteScreenshot(_ screenshot: Screenshot) {
        guard let modelContext = modelContext else { return }
        
        Task {
            do {
                try await imageStorageService.deleteImageData(screenshot.imageData)
                
                await MainActor.run {
                    modelContext.delete(screenshot)
                    do {
                        try modelContext.save()
                        
                        // Add haptic feedback for deletion
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    } catch {
                        handleDeletionError(error)
                    }
                }
            } catch {
                await handleDeletionError(error)
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
