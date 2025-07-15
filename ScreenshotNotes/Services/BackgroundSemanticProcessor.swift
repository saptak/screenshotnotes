import Foundation
import SwiftData
import UIKit
import os.log

@MainActor
public final class BackgroundSemanticProcessor: ObservableObject, MemoryTrackable, ResourceCleanupProtocol {
    @Published var isProcessing = false
    @Published var processedCount = 0
    @Published var totalCount = 0
    @Published var currentPhase: ProcessingPhase = .idle
    @Published var lastError: Error?
    
    // 🎯 Sprint 8.5.3.2: Memory Management & Leak Prevention
    private weak var semanticTaggingService: SemanticTaggingService?
    private weak var advancedVisionService: AdvancedVisionService?
    private var ocrService: OCRServiceProtocol? // Cannot be weak as it's a protocol
    private weak var mindMapService: MindMapService?
    
    private let batchSize = 1 // Reduced to 1 for minimal resource usage during bulk imports
    private let processingDelay: TimeInterval = 2.0 // Increased to 2.0 seconds for better user experience
    private let mindMapRegenerationDelay: TimeInterval = 5.0 // Debounce mind map regeneration
    private var lastMindMapRegenerationTime: Date = Date.distantPast
    
    // 🎯 Sprint 8.5.3.1: Task Synchronization Framework
    private let taskManager = TaskManager.shared
    
    // 🎯 Sprint 8.5.3.2: Memory Management
    private let memoryManager = MemoryManager.shared
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "BackgroundSemanticProcessor")
    
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
        advancedVisionService: AdvancedVisionService? = nil,
        ocrService: OCRServiceProtocol = OCRService(),
        mindMapService: MindMapService? = nil
    ) {
        self.semanticTaggingService = semanticTaggingService ?? SemanticTaggingService()
        self.advancedVisionService = advancedVisionService ?? AdvancedVisionService.shared
        self.ocrService = ocrService
        self.mindMapService = mindMapService ?? MindMapService.shared
        
        // 🎯 Sprint 8.5.3.2: Initialize memory management
        startMemoryTracking()
        registerForAutomaticCleanup()
        
        logger.info("BackgroundSemanticProcessor: Initialized with memory tracking")
    }
    
    deinit {
        // 🎯 Sprint 8.5.3.2: Proper cleanup in deinit
        Task { @MainActor in
            stopMemoryTracking()
            unregisterFromAutomaticCleanup()
        }
        
        // Cancel any ongoing processing
        Task {
            await taskManager.cancelTasks(in: .semantic)
            await taskManager.cancelTasks(in: .mindMap)
        }
        
        logger.info("BackgroundSemanticProcessor: Deallocated")
    }
    
    /// Process screenshots that need semantic analysis
    func processScreenshotsNeedingAnalysis(in modelContext: ModelContext) async {
        // 🎯 Sprint 8.5.3.1: Use Task Synchronization Framework for coordinated processing
        await taskManager.execute(
            category: .semantic,
            priority: .normal,
            description: "Process screenshots needing semantic analysis"
        ) {
            // Set bulk import state during background processing
            await MainActor.run {
                GalleryPerformanceMonitor.shared.setBulkImportState(true)
            }
            defer {
                Task { @MainActor in
                    GalleryPerformanceMonitor.shared.setBulkImportState(false)
                }
            }
            
            let descriptor = FetchDescriptor<Screenshot>(
                predicate: #Predicate<Screenshot> { screenshot in
                    // Need semantic analysis if never analyzed, analysis is stale, or no extracted text
                    screenshot.lastSemanticAnalysis == nil || 
                    screenshot.extractedText == nil
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
                
                // Process in batches with coordinated task management
                let batches = screenshotsNeedingProcessing.chunked(into: self.batchSize)
                
                await self.taskManager.executeGroup(
                    category: .semantic,
                    priority: .normal,
                    description: "Process semantic analysis batches",
                    operations: batches.enumerated().map { index, batch in
                        return {
                            await self.processBatch(batch, in: modelContext)
                            
                            // Controlled delay between batches
                            try? await Task.sleep(nanoseconds: UInt64(self.processingDelay * 1_000_000_000))
                        }
                    }
                )
                
                // Generate mind map after all screenshots have been processed
                await self.updatePhase(.mindMapGeneration)
                await self.taskManager.execute(
                    category: .mindMap,
                    priority: .low,
                    description: "Generate mind map after semantic processing"
                ) {
                    await self.generateMindMapInBackground(in: modelContext)
                }
                
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
                guard let service = ocrService else {
                    print("BackgroundSemanticProcessor: OCR service not available")
                    return
                }
                let extractedText = try await service.extractText(from: image)
                screenshot.extractedText = extractedText
            }
            
            // Phase 2: Vision Analysis (if needed)
            var visualAttributes: VisualAttributes?
            if screenshot.needsVisionAnalysis {
                await updatePhase(.vision)
                if let visionService = advancedVisionService {
                    visualAttributes = await visionService.analyzeScreenshot(screenshot.imageData)
                    screenshot.visualAttributes = visualAttributes
                }
            } else {
                visualAttributes = screenshot.visualAttributes
            }
            
            // Phase 3: Semantic Tagging
            await updatePhase(.semanticTagging)
            var semanticTags: SemanticTagCollection?
            if let taggingService = semanticTaggingService {
                semanticTags = await taggingService.generateSemanticTags(
                    for: screenshot,
                    extractedText: screenshot.extractedText,
                    visualAttributes: visualAttributes
                )
            }
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
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        
        for screenshot in screenshots {
            // Check if this screenshot actually needs processing
            let needsProcessing = screenshot.lastSemanticAnalysis == nil ||
                                  screenshot.extractedText == nil ||
                                  (screenshot.lastSemanticAnalysis.map { $0 < thirtyDaysAgo } ?? false)
            
            if needsProcessing {
                await processScreenshot(screenshot, in: modelContext)
            }
            
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
            if let mapService = mindMapService {
                await mapService.generateMindMap(from: screenshotsWithSemanticData)
            }
            
            print("🧠 Mind map generation completed in background")
            
        } catch {
            print("❌ Failed to generate mind map in background: \(error)")
        }
    }
    
    /// Trigger mind map regeneration for incremental updates
    func triggerMindMapRegeneration(in modelContext: ModelContext) async {
        // Only trigger if we're not already processing
        guard !isProcessing else { return }
        
        // Debounce mind map regeneration during bulk imports
        let now = Date()
        let timeSinceLastRegeneration = now.timeIntervalSince(lastMindMapRegenerationTime)
        
        if timeSinceLastRegeneration < mindMapRegenerationDelay {
            print("🧠 Skipping mind map regeneration (debounced) - last regeneration was \(String(format: "%.1f", timeSinceLastRegeneration))s ago")
            return
        }
        
        print("🧠 Triggering incremental mind map regeneration")
        lastMindMapRegenerationTime = now
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
    
    // MARK: - 🎯 Sprint 8.5.3.2: ResourceCleanupProtocol Implementation
    
    public func performLightCleanup() async {
        logger.info("BackgroundSemanticProcessor: Performing light cleanup")
        
        // Clear error state if not currently processing
        if !isProcessing {
            lastError = nil
        }
        
        // Reset counters if processing is complete
        if !isProcessing && currentPhase == .idle {
            processedCount = 0
            totalCount = 0
        }
    }
    
    public func performDeepCleanup() async {
        logger.warning("BackgroundSemanticProcessor: Performing deep cleanup")
        
        // Cancel all semantic processing tasks
        await taskManager.cancelTasks(in: .semantic)
        await taskManager.cancelTasks(in: .mindMap)
        
        // Reset all processing state
        await MainActor.run {
            isProcessing = false
            processedCount = 0
            totalCount = 0
            currentPhase = .idle
            lastError = nil
        }
        
        // Clear service references to free memory
        semanticTaggingService = nil
        advancedVisionService = nil
        ocrService = nil
        mindMapService = nil
        
        // Reset timing
        lastMindMapRegenerationTime = Date.distantPast
    }
    
    public nonisolated func getEstimatedMemoryUsage() -> UInt64 {
        var usage: UInt64 = 0
        
        // Base service size
        usage += 4096 // BackgroundSemanticProcessor base size
        
        // Add memory for processing state (estimated)
        usage += 2048 // Processing state overhead
        
        // Add memory for service references (estimated)
        usage += 8192 // Service references overhead
        
        return usage
    }
    
    public nonisolated var cleanupPriority: Int { 50 } // Medium priority for background processing
    
    public nonisolated var cleanupIdentifier: String { "BackgroundSemanticProcessor" }
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