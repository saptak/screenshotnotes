import Foundation
import SwiftData
import UIKit

@MainActor
final class BackgroundOCRProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var processedCount = 0
    @Published var totalCount = 0
    
    private let ocrService: OCRServiceProtocol
    private let batchSize = 5
    private let processingDelay: TimeInterval = 0.5
    
    init(ocrService: OCRServiceProtocol = OCRService()) {
        self.ocrService = ocrService
    }
    
    func processExistingScreenshots(in modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate<Screenshot> { screenshot in
                screenshot.extractedText == nil || screenshot.extractedText?.isEmpty == true
            }
        )
        
        do {
            let screenshotsNeedingOCR = try modelContext.fetch(descriptor)
            
            guard !screenshotsNeedingOCR.isEmpty else {
                print("No screenshots need OCR processing")
                return
            }
            
            await MainActor.run {
                self.isProcessing = true
                self.totalCount = screenshotsNeedingOCR.count
                self.processedCount = 0
            }
            
            print("Starting background OCR processing for \(screenshotsNeedingOCR.count) screenshots")
            
            // Process in batches to avoid memory issues
            for batch in screenshotsNeedingOCR.chunked(into: batchSize) {
                await processBatch(batch, in: modelContext)
                
                // Small delay between batches to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
            }
            
            await MainActor.run {
                self.isProcessing = false
                print("Background OCR processing completed. Processed \(self.processedCount) screenshots.")
            }
            
        } catch {
            await MainActor.run {
                self.isProcessing = false
                print("Error fetching screenshots for OCR processing: \(error)")
            }
        }
    }
    
    private func processBatch(_ screenshots: [Screenshot], in modelContext: ModelContext) async {
        await withTaskGroup(of: Void.self) { group in
            for screenshot in screenshots {
                group.addTask {
                    await self.processScreenshot(screenshot, in: modelContext)
                }
            }
        }
    }
    
    private func processScreenshot(_ screenshot: Screenshot, in modelContext: ModelContext) async {
        do {
            guard let image = UIImage(data: screenshot.imageData) else {
                print("Failed to create image from data for screenshot \(screenshot.id)")
                return
            }
            
            let extractedText = try await ocrService.extractText(from: image)
            
            await MainActor.run {
                screenshot.extractedText = extractedText
                self.processedCount += 1
                
                do {
                    try modelContext.save()
                    print("OCR completed for screenshot \(screenshot.id): \(extractedText.prefix(50))...")
                } catch {
                    print("Failed to save OCR result for screenshot \(screenshot.id): \(error)")
                }
            }
            
        } catch {
            await MainActor.run {
                self.processedCount += 1
                print("OCR failed for screenshot \(screenshot.id): \(error.localizedDescription)")
            }
        }
    }
    
    func startBackgroundProcessingIfNeeded(in modelContext: ModelContext) {
        guard !isProcessing else { return }
        
        Task {
            await processExistingScreenshots(in: modelContext)
        }
    }
}

// Helper extension for chunking arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}