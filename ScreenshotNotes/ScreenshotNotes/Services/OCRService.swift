import Foundation
import Vision
import UIKit

protocol OCRServiceProtocol {
    func extractText(from imageData: Data) async throws -> String
    func extractText(from image: UIImage) async throws -> String
}

final class OCRService: OCRServiceProtocol {
    
    enum OCRError: LocalizedError {
        case invalidImageData
        case recognitionFailed
        case noTextFound
        
        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "Unable to process the image data"
            case .recognitionFailed:
                return "Text recognition failed"
            case .noTextFound:
                return "No text was found in the image"
            }
        }
    }
    
    func extractText(from imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData) else {
            throw OCRError.invalidImageData
        }
        
        return try await extractText(from: image)
    }
    
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImageData
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.recognitionFailed)
                    return
                }
                
                let extractedText = observations
                    .compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    .joined(separator: "\n")
                
                if extractedText.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: extractedText)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}