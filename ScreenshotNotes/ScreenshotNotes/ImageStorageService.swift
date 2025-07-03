import Foundation
import UIKit
import SwiftData

protocol ImageStorageServiceProtocol {
    func saveImage(_ image: UIImage, filename: String) async throws -> Data
    func loadImage(from data: Data) -> UIImage?
    func deleteImageData(_ data: Data) async throws
}

class ImageStorageService: ImageStorageServiceProtocol, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    
    init() {
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func saveImage(_ image: UIImage, filename: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Optimize image for storage - resize if too large
                let processedImage = self.optimizeImageForStorage(image)
                
                // Compress with quality optimization
                guard let imageData = processedImage.jpegData(compressionQuality: 0.8) else {
                    continuation.resume(throwing: ImageStorageError.compressionFailed)
                    return
                }
                
                // Validate final size (max 5MB after optimization)
                if imageData.count > 5 * 1024 * 1024 {
                    continuation.resume(throwing: ImageStorageError.imageTooLarge)
                    return
                }
                
                continuation.resume(returning: imageData)
            }
        }
    }
    
    private func optimizeImageForStorage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2048
        let size = image.size
        
        // Don't resize if already small enough
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // Resize the image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    func loadImage(from data: Data) -> UIImage? {
        return UIImage(data: data)
    }
    
    func deleteImageData(_ data: Data) async throws {
        // For now, just validate the data can be converted to image
        guard UIImage(data: data) != nil else {
            throw ImageStorageError.invalidImageData
        }
        // Data deletion is handled by SwiftData when the model is deleted
    }
}

enum ImageStorageError: LocalizedError {
    case compressionFailed
    case imageTooLarge
    case invalidImageData
    case storageNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Unable to process the image. Please try a different image."
        case .imageTooLarge:
            return "Image is too large. Please choose a smaller image."
        case .invalidImageData:
            return "The image data is corrupted or invalid."
        case .storageNotAvailable:
            return "Storage is not available. Please check your device storage."
        }
    }
}