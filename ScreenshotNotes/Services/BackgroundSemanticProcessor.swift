import Foundation
import SwiftData
import UIKit

@MainActor
final class BackgroundSemanticProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var processedCount = 0
    @Published var totalCount = 0
    @Published var currentPhase: ProcessingPhase = .idle
    @Published var lastError: Error?
    
    private let semanticTaggingService: SemanticTaggingService
    private let enhancedVisionService: EnhancedVisionService
    private let ocrService: OCRServiceProtocol
    private let mindMapService: MindMapService
    private let batchSize = 3 // Smaller batch size for AI processing
    private let processingDelay: TimeInterval = 1.0 // Longer delay for AI processing
    
    enum ProcessingPhase: String, CaseIterable {
        case idle = "idle"
        case ocr = "Text Extraction"
        case vision = "Vision Analysis"
        case semanticTagging = "Semantic Analysis"
        case mindMapGeneration = "Mind Map Generation"
        case completing = "Finalizing"
        
        var description: String {
            return rawValue
        }
    }
    
    init(
        semanticTaggingService: SemanticTaggingService? = nil,
        enhancedVisionService: EnhancedVisionService? = nil,
        ocrService: OCRServiceProtocol = OCRService(),
        mindMapService: MindMapService? = nil
    ) {
        self.semanticTaggingService = semanticTaggingService ?? SemanticTaggingService()
        self.enhancedVisionService = enhancedVisionService ?? EnhancedVisionService()
        self.ocrService = ocrService
        self.mindMapService = mindMapService ?? MindMapService.shared
    }
    
    /// Process screenshots that need semantic analysis
    func processScreenshotsNeedingAnalysis(in modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate<Screenshot> { screenshot in
                screenshot.needsSemanticAnalysis || screenshot.extractedText == nil
            }
        )
        
        do {
            let screenshotsNeedingProcessing = try modelContext.fetch(descriptor)
            
            guard !screenshotsNeedingProcessing.isEmpty else {
                print("No screenshots need semantic processing")
                return
            }
            
            await MainActor.run {
                self.isProcessing = true
                self.totalCount = screenshotsNeedingProcessing.count
                self.processedCount = 0
                self.lastError = nil
                self.currentPhase = .ocr
            }
            
            print("Starting background semantic processing for \(screenshotsNeedingProcessing.count) screenshots")
            
            // Process in batches to avoid memory issues
            for batch in screenshotsNeedingProcessing.chunked(into: batchSize) {
                await processBatch(batch, in: modelContext)
                
                // Delay between batches to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
            }
            
            // Generate mind map after all screenshots have been processed
            await updatePhase(.mindMapGeneration)
            await generateMindMapInBackground(in: modelContext)
            
            await MainActor.run {
                self.isProcessing = false
                self.currentPhase = .idle
                print("Background semantic processing completed. Processed \(self.processedCount) screenshots.")
            }
            
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.currentPhase = .idle
                self.lastError = error
                print("Error fetching screenshots for semantic processing: \(error)")
            }
        }
    }
    
    /// Process a single screenshot with full analysis pipeline
    func processScreenshot(_ screenshot: Screenshot, in modelContext: ModelContext) async {
        do {
            guard let image = UIImage(data: screenshot.imageData) else {
                throw ProcessingError.invalidImageData
            }
            
            // Phase 1: OCR (if needed)
            if screenshot.extractedText == nil || screenshot.extractedText?.isEmpty == true {
                await updatePhase(.ocr)
                let extractedText = try await ocrService.extractText(from: image)
                screenshot.extractedText = extractedText
            }
            
            // Phase 2: Vision Analysis (if needed)
            var visualAttributes: VisualAttributes?
            if screenshot.needsVisionAnalysis {
                await updatePhase(.vision)
                // TODO: Implement vision analysis when VisualAttributes structure is aligned
                // visualAttributes = await enhancedVisionService.analyzeScreenshot(screenshot.imageData)
                // screenshot.visualAttributes = visualAttributes
            } else {
                visualAttributes = screenshot.visualAttributes
            }
            
            // Phase 3: Semantic Tagging
            await updatePhase(.semanticTagging)
            let semanticTags = try await semanticTaggingService.generateSemanticTags(
                for: screenshot.imageData,
                ocrText: screenshot.extractedText,
                visualAttributes: visualAttributes
            )
            screenshot.semanticTags = semanticTags
            
            // Phase 4: Save
            await updatePhase(.completing)
            await MainActor.run {
                do {
                    try modelContext.save()
                    print("Full semantic analysis completed for screenshot \(screenshot.id)")
                } catch {
                    print("Failed to save semantic analysis for screenshot \(screenshot.id): \(error)")
                }
            }
            
        } catch {
            await MainActor.run {
                self.lastError = error
                print("Semantic processing failed for screenshot \(screenshot.id): \(error.localizedDescription)")
            }
        }
    }
    
    private func processBatch(_ screenshots: [Screenshot], in modelContext: ModelContext) async {
        for screenshot in screenshots {
            await processScreenshot(screenshot, in: modelContext)
            
            await MainActor.run {
                self.processedCount += 1
            }
            
            // Small delay between individual screenshots
            try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
        }
    }
    
    private func updatePhase(_ phase: ProcessingPhase) async {
        await MainActor.run {
            self.currentPhase = phase
        }
    }
    
    /// Generate mind map in background after semantic processing
    private func generateMindMapInBackground(in modelContext: ModelContext) async {
        do {
            // Fetch all screenshots with semantic data for mind map generation
            let descriptor = FetchDescriptor<Screenshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            let allScreenshots = try modelContext.fetch(descriptor)
            
            // Only generate if we have sufficient screenshots with semantic data
            let screenshotsWithSemanticData = allScreenshots.filter { screenshot in
                screenshot.semanticTags != nil || screenshot.extractedText != nil
            }
            
            guard screenshotsWithSemanticData.count >= 3 else {
                print("🧠 Skipping mind map generation: insufficient semantic data (\(screenshotsWithSemanticData.count) screenshots)")
                return
            }
            
            print("🧠 Generating mind map for \(screenshotsWithSemanticData.count) screenshots with semantic data")
            
            // Generate mind map using the service
            await mindMapService.generateMindMap(from: screenshotsWithSemanticData)
            
            print("🧠 Mind map generation completed in background")
            
        } catch {
            print("❌ Failed to generate mind map in background: \(error)")
        }
    }
    
    /// Trigger mind map regeneration for incremental updates
    func triggerMindMapRegeneration(in modelContext: ModelContext) async {
        // Only trigger if we're not already processing
        guard !isProcessing else { return }
        
        print("🧠 Triggering incremental mind map regeneration")
        await generateMindMapInBackground(in: modelContext)
    }
    
    /// Get processing progress as percentage
    var progress: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(processedCount) / Double(totalCount)
    }
    
    /// Get estimated time remaining
    var estimatedTimeRemaining: TimeInterval? {
        guard isProcessing, processedCount > 0, totalCount > processedCount else { return nil }
        
        let avgTimePerItem = processingDelay * Double(batchSize) // Rough estimate
        let remainingItems = totalCount - processedCount
        return avgTimePerItem * Double(remainingItems) / Double(batchSize)
    }
}

// MARK: - Processing Errors

enum ProcessingError: LocalizedError {
    case invalidImageData
    case ocrFailed
    case visionAnalysisFailed
    case semanticTaggingFailed
    case mindMapGenerationFailed
    case analysisTimeout
    case insufficientMemory
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data provided"
        case .ocrFailed:
            return "OCR text extraction failed"
        case .visionAnalysisFailed:
            return "Vision analysis failed"
        case .semanticTaggingFailed:
            return "Semantic tagging failed"
        case .mindMapGenerationFailed:
            return "Mind map generation failed"
        case .analysisTimeout:
            return "Processing timed out"
        case .insufficientMemory:
            return "Insufficient memory for processing"
        }
    }
}

