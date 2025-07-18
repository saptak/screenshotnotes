import Foundation
import SwiftData
import UIKit
import os.log

@MainActor
public final class BackgroundSemanticProcessor: ObservableObject, MemoryTrackable, ResourceCleanupProtocol {
    public static let shared = BackgroundSemanticProcessor()
    
    @Published var isProcessing = false
    @Published var processedCount = 0
    @Published var totalCount = 0
    @Published var currentPhase: ProcessingPhase = .idle
    @Published var lastError: Error?
    
    // 🎯 Sprint 8.5.3.2: Memory Management & Leak Prevention
    private var semanticTaggingService: SemanticTaggingService? // Cannot be weak - no singleton available
    private weak var advancedVisionService: AdvancedVisionService?
    private var ocrService: OCRServiceProtocol? // Cannot be weak as it's a protocol
    private weak var mindMapService: MindMapService?
    private var entityExtractionService: EntityExtractionService? // Cannot be weak - no singleton available
    
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
        case entityExtraction = "Entity Extraction"
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
        mindMapService: MindMapService? = nil,
        entityExtractionService: EntityExtractionService? = nil
    ) {
        self.semanticTaggingService = semanticTaggingService ?? SemanticTaggingService()
        self.advancedVisionService = advancedVisionService ?? AdvancedVisionService.shared
        self.ocrService = ocrService
        self.mindMapService = mindMapService ?? MindMapService.shared
        self.entityExtractionService = entityExtractionService ?? EntityExtractionService()
        
        // 🎯 Sprint 8.5.3.2: Initialize memory management
        startMemoryTracking()
        registerForAutomaticCleanup()
        
        logger.info("BackgroundSemanticProcessor: Initialized with memory tracking")
    }
    
    deinit {
        // 🎯 Sprint 8.5.3.2: Proper cleanup in deinit
        // Note: Cannot use async methods in deinit - cleanup will be handled by system
        // The memory manager will handle cleanup when the object is deallocated
        
        logger.info("BackgroundSemanticProcessor: Deallocated")
    }
    
    /// Process screenshots that need semantic analysis
    func processScreenshotsNeedingAnalysis(in modelContext: ModelContext) async {
        // Simplified processing without TaskManager to avoid deadlocks
        print("🔍 BackgroundSemanticProcessor: Starting simplified processing")
        
        // Prevent concurrent processing
        guard !isProcessing else {
            print("🔍 BackgroundSemanticProcessor: Already processing, skipping")
            return
        }
        
        // Set bulk import state during background processing
        await MainActor.run {
            GalleryPerformanceMonitor.shared.setBulkImportState(true)
        }
        defer {
            Task { @MainActor in
                GalleryPerformanceMonitor.shared.setBulkImportState(false)
            }
        }
            
        // First, get all screenshots to see the full picture
        let allDescriptor = FetchDescriptor<Screenshot>()
        do {
            let allScreenshots = try modelContext.fetch(allDescriptor)
            print("🔍 Total screenshots in database: \(allScreenshots.count)")
            
            // Analyze what each screenshot needs with detailed timestamps
            let needsOCR = allScreenshots.filter { $0.extractedText == nil }
            let needsSemanticAnalysis = allScreenshots.filter { $0.lastSemanticAnalysis == nil }
            let alreadyProcessed = allScreenshots.filter { $0.lastSemanticAnalysis != nil && $0.extractedText != nil }
            
            print("🔍 Screenshots needing OCR: \(needsOCR.count)")
            print("🔍 Screenshots needing semantic analysis: \(needsSemanticAnalysis.count)")
            print("🔍 Screenshots already fully processed: \(alreadyProcessed.count)")
            
            // Debug: Show the timestamps of "already processed" screenshots
            if !alreadyProcessed.isEmpty {
                print("🔍 DEBUG: Already processed screenshots:")
                for screenshot in alreadyProcessed.prefix(5) {
                    let createdTime = screenshot.timestamp
                    let semanticTime = screenshot.lastSemanticAnalysis ?? Date.distantPast
                    print("  - \(screenshot.id): created \(createdTime), processed \(semanticTime)")
                }
            }
            
            // Debug: Show the age of the newest screenshots
            let sortedByTimestamp = allScreenshots.sorted { $0.timestamp > $1.timestamp }
            print("🔍 DEBUG: Newest 5 screenshots:")
            for screenshot in sortedByTimestamp.prefix(5) {
                let hasOCR = screenshot.extractedText != nil
                let hasSemantic = screenshot.lastSemanticAnalysis != nil
                print("  - \(screenshot.id): created \(screenshot.timestamp), OCR: \(hasOCR), Semantic: \(hasSemantic)")
            }
        } catch {
            print("🔍 Error fetching all screenshots: \(error)")
        }
        
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate<Screenshot> { screenshot in
                screenshot.lastSemanticAnalysis == nil
            }
        )
        
        do {
            let screenshotsNeedingProcessing = try modelContext.fetch(descriptor)
            
            guard !screenshotsNeedingProcessing.isEmpty else {
                print("🔍 No screenshots need semantic processing")
                return
            }
            
            await MainActor.run {
                self.isProcessing = true
                self.totalCount = screenshotsNeedingProcessing.count
                self.processedCount = 0
                self.lastError = nil
                self.currentPhase = .ocr
            }
            
            print("🔍 Starting simplified semantic processing for \(screenshotsNeedingProcessing.count) screenshots")
            
            // Limit to smaller batches to prevent thermal issues and provide better feedback
            let batchSize = 5  // Process in smaller batches
            let limitedScreenshots = Array(screenshotsNeedingProcessing.prefix(20)) // Allow up to 20
            
            print("🔍 Processing \(limitedScreenshots.count) screenshots in batches of \(batchSize)")
            
            // Process in smaller batches with thermal breaks
            for batchStart in stride(from: 0, to: limitedScreenshots.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, limitedScreenshots.count)
                let batch = Array(limitedScreenshots[batchStart..<batchEnd])
                
                print("🔍 Starting batch \(batchStart/batchSize + 1): processing screenshots \(batchStart + 1) to \(batchEnd)")
                
                // Check thermal state before each batch
                if await shouldPauseProcessing() {
                    print("🌡️ Thermal throttling detected before batch, cooling down...")
                    await pauseForThermalCooldown()
                }
                
                // Process batch
                for (index, screenshot) in batch.enumerated() {
                    let globalIndex = batchStart + index
                    print("🔍 Processing screenshot \(globalIndex + 1)/\(limitedScreenshots.count): \(screenshot.id)")
                    
                    await processScreenshotSimplified(screenshot, in: modelContext)
                    
                    await MainActor.run {
                        self.processedCount += 1
                    }
                    
                    print("🔍 Completed screenshot \(globalIndex + 1)/\(limitedScreenshots.count): \(screenshot.id)")
                    
                    // Short delay between individual screenshots
                    try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000)) // 0.5 second
                }
                
                // Longer break between batches for thermal management
                if batchEnd < limitedScreenshots.count {
                    print("🔍 Batch \(batchStart/batchSize + 1) complete, cooling down before next batch...")
                    try? await Task.sleep(nanoseconds: UInt64(3.0 * 1_000_000_000)) // 3 seconds between batches
                }
            }
            
            print("🔍 Simplified semantic processing completed for \(limitedScreenshots.count) screenshots")
            
            await MainActor.run {
                self.isProcessing = false
                self.currentPhase = .idle
            }
                
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.currentPhase = .idle
                self.lastError = error
                print("🔍 Error fetching screenshots for semantic processing: \(error)")
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
            
            // Phase 2: Entity Extraction (if needed)
            if screenshot.needsEntityExtraction || screenshot.entities == nil || screenshot.entities?.isEmpty == true {
                await updatePhase(.entityExtraction)
                if let entityService = entityExtractionService, let text = screenshot.extractedText, !text.isEmpty {
                    do {
                        let entityResult = await entityService.extractEntities(from: text)
                        screenshot.entities = entityResult.entities
                        screenshot.lastEntityExtraction = Date()
                        print("Entity extraction completed for screenshot \(screenshot.id) - extracted \(entityResult.entities.count) entities")
                    } catch {
                        print("Entity extraction failed for screenshot \(screenshot.id): \(error)")
                        // Continue processing even if entity extraction fails
                    }
                }
            }
            
            // Phase 3: Vision Analysis (if needed)
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
            
            // Phase 4: Semantic Tagging
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
            
            // Phase 5: Save
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
        entityExtractionService = nil
        
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

// MARK: - BackgroundSemanticProcessor Extensions

extension BackgroundSemanticProcessor {
    
    /// Simplified processing function that bypasses TaskManager
    private func processScreenshotSimplified(_ screenshot: Screenshot, in modelContext: ModelContext) async {
        print("🔍 Starting processing for screenshot \(screenshot.id)")
        
        guard let image = UIImage(data: screenshot.imageData) else {
            print("🔍 Invalid image data for screenshot \(screenshot.id)")
            return
        }
            
            // Phase 1: OCR (if needed)
            if screenshot.extractedText == nil || screenshot.extractedText?.isEmpty == true {
                print("🔍 Starting OCR for screenshot \(screenshot.id)")
                await updatePhase(.ocr)
                guard let service = ocrService else {
                    print("🔍 OCR service not available for screenshot \(screenshot.id)")
                    return
                }
                
                do {
                    let extractedText = try await service.extractText(from: image)
                    screenshot.extractedText = extractedText
                    print("🔍 OCR completed for screenshot \(screenshot.id) - extracted \(extractedText.count) characters")
                } catch {
                    print("🔍 OCR failed for screenshot \(screenshot.id): \(error)")
                    // Continue processing even if OCR fails
                }
            } else {
                print("🔍 Skipping OCR for screenshot \(screenshot.id) - already has text")
            }
            
            // Phase 2: Entity extraction (if needed and text is available)
            if screenshot.needsEntityExtraction || screenshot.entities == nil || screenshot.entities?.isEmpty == true {
                if let text = screenshot.extractedText, !text.isEmpty {
                    print("🔍 Starting entity extraction for screenshot \(screenshot.id)")
                    await updatePhase(.entityExtraction)
                    if let entityService = entityExtractionService {
                        do {
                            let entityResult = await entityService.extractEntities(from: text)
                            screenshot.entities = entityResult.entities
                            screenshot.lastEntityExtraction = Date()
                            print("🔍 Entity extraction completed for screenshot \(screenshot.id) - extracted \(entityResult.entities.count) entities")
                        } catch {
                            print("🔍 Entity extraction failed for screenshot \(screenshot.id): \(error)")
                            // Continue processing even if entity extraction fails
                        }
                    } else {
                        print("🔍 Entity extraction service not available for screenshot \(screenshot.id)")
                    }
                } else {
                    print("🔍 Skipping entity extraction for screenshot \(screenshot.id) - no text available")
                }
            } else {
                print("🔍 Skipping entity extraction for screenshot \(screenshot.id) - already has entities")
            }
            
            // Phase 3: Basic semantic tagging (minimal processing)
            print("🔍 Starting semantic tagging for screenshot \(screenshot.id)")
            await updatePhase(.semanticTagging)
            if let taggingService = semanticTaggingService {
                do {
                    let semanticTags = await taggingService.generateSemanticTags(
                        for: screenshot,
                        extractedText: screenshot.extractedText,
                        visualAttributes: nil // Skip vision analysis for thermal performance
                    )
                    screenshot.semanticTags = semanticTags
                    print("🔍 Semantic tagging completed for screenshot \(screenshot.id) - generated \(semanticTags.tags.count) tags")
                } catch {
                    print("🔍 Semantic tagging failed for screenshot \(screenshot.id): \(error)")
                    // Continue processing even if semantic tagging fails
                }
            } else {
                print("🔍 Semantic tagging service not available for screenshot \(screenshot.id)")
            }
            
            // Phase 4: Save immediately
            print("🔍 Saving screenshot \(screenshot.id)")
            await updatePhase(.completing)
            await MainActor.run {
                do {
                    try modelContext.save()
                    print("🔍 Saved semantic analysis for screenshot \(screenshot.id)")
                } catch {
                    print("🔍 Failed to save semantic analysis for screenshot \(screenshot.id): \(error)")
                }
            }
        
        print("🔍 Finished processing for screenshot \(screenshot.id)")
    }
    
    /// Check if processing should pause due to thermal or memory pressure
    private func shouldPauseProcessing() async -> Bool {
        let processInfo = ProcessInfo.processInfo
        let thermalState = processInfo.thermalState
        let memoryUsage = getMemoryUsage()
        
        print("🔍 Thermal check: \(thermalState.rawValue), Memory usage: \(String(format: "%.1f", memoryUsage * 100))%")
        
        // More aggressive thermal management - pause for serious and critical
        if thermalState == .critical || thermalState == .serious {
            print("🌡️ High thermal state (\(thermalState.rawValue)) detected, pausing processing")
            return true
        }
        
        // Check memory pressure (simplified) - lower threshold for thermal protection
        if memoryUsage > 0.8 { // 80% memory usage
            print("💾 High memory usage detected (\(String(format: "%.1f", memoryUsage * 100))%), pausing processing")
            return true
        }
        
        return false
    }
    
    /// Pause processing for thermal cooldown
    private func pauseForThermalCooldown() async {
        print("🌡️ Pausing for thermal cooldown...")
        try? await Task.sleep(nanoseconds: UInt64(15.0 * 1_000_000_000)) // 15 seconds for better cooling
        print("🌡️ Thermal cooldown complete, resuming processing")
    }
    
    /// Get current memory usage ratio (0.0 to 1.0)
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            return usedMemory / totalMemory
        }
        
        return 0.0
    }
}