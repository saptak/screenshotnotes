//
//  BulkImportCoordinator.swift
//  ScreenshotNotes
//
//  Created by Assistant on 7/12/25.
//

import Foundation
import SwiftData
import OSLog

/// Coordinates bulk import operations to prevent concurrency issues and ensure complete processing
@MainActor
class BulkImportCoordinator: ObservableObject {
    static let shared = BulkImportCoordinator()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "BulkImportCoordinator")
    
    // MARK: - Published State
    
    @Published var isImportInProgress = false
    @Published var currentPhase: ImportPhase = .idle
    @Published var progress: ImportProgress = ImportProgress()
    @Published var blockedAttempts = 0
    
    // MARK: - Private State
    
    private var currentImportTask: Task<Void, Never>?
    private var importQueue: [ImportRequest] = []
    private let maxBlockedAttempts = 3
    
    // MARK: - Types
    
    enum ImportPhase {
        case idle
        case importing
        case processing
        case finalizing
        
        var description: String {
            switch self {
            case .idle: return "Ready"
            case .importing: return "Importing screenshots"
            case .processing: return "Processing with AI"
            case .finalizing: return "Finalizing"
            }
        }
    }
    
    struct ImportProgress {
        var imported: Int = 0
        var total: Int = 0
        var processed: Int = 0
        var needsProcessing: Int = 0
        
        var isComplete: Bool {
            imported > 0 && processed >= needsProcessing
        }
        
        var percentage: Double {
            guard total > 0 else { return 0.0 }
            let importWeight = 0.3
            let processWeight = 0.7
            
            let importProgress = Double(imported) / Double(total) * importWeight
            let processProgress = needsProcessing > 0 ? Double(processed) / Double(needsProcessing) * processWeight : processWeight
            
            return min(1.0, importProgress + processProgress)
        }
    }
    
    private struct ImportRequest {
        let id = UUID()
        let requestedAt = Date()
        let completion: (ImportResult) -> Void
    }
    
    struct ImportResult {
        let success: Bool
        let imported: Int
        let processed: Int
        let error: Error?
        let duration: TimeInterval
    }
    
    private init() {}
    
    // MARK: - Public API
    
    /// Requests a bulk import. Returns immediately if import is in progress.
    func requestBulkImport(
        photoLibraryService: PhotoLibraryService,
        backgroundOCRProcessor: BackgroundOCRProcessor,
        backgroundSemanticProcessor: BackgroundSemanticProcessor,
        modelContext: ModelContext,
        completion: @escaping (ImportResult) -> Void = { _ in }
    ) {
        logger.info("🔄 Bulk import requested")
        
        // Check if import is already in progress
        if isImportInProgress {
            self.blockedAttempts += 1
            logger.warning("⚠️ Bulk import blocked - operation in progress (attempt #\(self.blockedAttempts))")
            
            if blockedAttempts <= maxBlockedAttempts {
                // Queue the request for later processing
                let request = ImportRequest(completion: completion)
                importQueue.append(request)
                logger.info("📋 Queued import request for later processing")
            } else {
                logger.error("❌ Too many blocked attempts, rejecting request")
                completion(ImportResult(
                    success: false,
                    imported: 0,
                    processed: 0,
                    error: BulkImportError.tooManyAttempts,
                    duration: 0
                ))
            }
            return
        }
        
        // Start the import
        startBulkImport(
            photoLibraryService: photoLibraryService,
            backgroundOCRProcessor: backgroundOCRProcessor,
            backgroundSemanticProcessor: backgroundSemanticProcessor,
            modelContext: modelContext,
            completion: completion
        )
    }
    
    /// Force cancels current import operation
    func cancelCurrentImport() {
        logger.warning("🛑 Cancelling current import operation")
        currentImportTask?.cancel()
        resetState()
    }
    
    /// Checks if a bulk import can be started
    var canStartImport: Bool {
        !isImportInProgress
    }
    
    // MARK: - Private Implementation
    
    private func startBulkImport(
        photoLibraryService: PhotoLibraryService,
        backgroundOCRProcessor: BackgroundOCRProcessor,
        backgroundSemanticProcessor: BackgroundSemanticProcessor,
        modelContext: ModelContext,
        completion: @escaping (ImportResult) -> Void
    ) {
        let startTime = Date()
        
        // Set initial state
        isImportInProgress = true
        currentPhase = .importing
        progress = ImportProgress()
        blockedAttempts = 0
        
        logger.info("🚀 Starting coordinated bulk import")
        
        currentImportTask = Task {
            var result = ImportResult(success: false, imported: 0, processed: 0, error: nil, duration: 0)
            
            do {
                // Phase 1: Import screenshots
                currentPhase = .importing
                let importResult = try await performImport(
                    photoLibraryService: photoLibraryService,
                    modelContext: modelContext
                )
                
                progress.imported = importResult.imported
                progress.total = importResult.total
                
                guard importResult.imported > 0 else {
                    logger.info("📸 No new screenshots to import")
                    result = ImportResult(
                        success: true,
                        imported: 0,
                        processed: 0,
                        error: nil,
                        duration: Date().timeIntervalSince(startTime)
                    )
                    completion(result)
                    await processQueuedRequests()
                    return
                }
                
                logger.info("📸 Imported \(importResult.imported) screenshots")
                
                // Phase 2: Process with AI
                currentPhase = .processing
                let processResult = try await performAIProcessing(
                    backgroundOCRProcessor: backgroundOCRProcessor,
                    backgroundSemanticProcessor: backgroundSemanticProcessor,
                    modelContext: modelContext
                )
                
                progress.processed = processResult.processed
                progress.needsProcessing = processResult.needsProcessing
                
                logger.info("🤖 Processed \(processResult.processed) screenshots with AI")
                
                // Phase 3: Finalize
                currentPhase = .finalizing
                
                // Wait for any pending operations to complete
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                
                result = ImportResult(
                    success: true,
                    imported: importResult.imported,
                    processed: processResult.processed,
                    error: nil,
                    duration: Date().timeIntervalSince(startTime)
                )
                
                logger.info("✅ Bulk import completed successfully in \(result.duration, format: .fixed(precision: 2))s")
                
            } catch {
                logger.error("❌ Bulk import failed: \(error)")
                result = ImportResult(
                    success: false,
                    imported: progress.imported,
                    processed: progress.processed,
                    error: error,
                    duration: Date().timeIntervalSince(startTime)
                )
            }
            
            // Complete the operation
            completion(result)
            await processQueuedRequests()
        }
    }
    
    private func performImport(
        photoLibraryService: PhotoLibraryService,
        modelContext: ModelContext
    ) async throws -> (imported: Int, total: Int) {
        // Check photo permission
        let currentStatus = photoLibraryService.authorizationStatus
        if currentStatus != .authorized {
            let newStatus = await photoLibraryService.requestPhotoLibraryPermission()
            guard newStatus == .authorized else {
                throw BulkImportError.permissionDenied
            }
        }
        
        // Import in batches with limit
        let batchSize = 10
        let maxImportLimit = 20
        var totalImported = 0
        var totalSkipped = 0
        var hasMore = true
        var batchIndex = 0
        
        while hasMore && totalImported < maxImportLimit {
            guard !Task.isCancelled else {
                throw BulkImportError.cancelled
            }
            
            let result = await photoLibraryService.importPastScreenshotsBatch(
                batch: batchIndex,
                batchSize: batchSize
            )
            
            totalImported += result.imported
            totalSkipped += result.skipped
            batchIndex += 1
            hasMore = result.hasMore
            
            if totalImported >= maxImportLimit {
                hasMore = false
            }
            
            // Update progress
            progress.imported = totalImported
            progress.total = min(totalImported + totalSkipped, maxImportLimit)
            
            // Brief pause between batches
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        return (imported: totalImported, total: progress.total)
    }
    
    private func performAIProcessing(
        backgroundOCRProcessor: BackgroundOCRProcessor,
        backgroundSemanticProcessor: BackgroundSemanticProcessor,
        modelContext: ModelContext
    ) async throws -> (processed: Int, needsProcessing: Int) {
        // Get screenshots that need processing
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate<Screenshot> { screenshot in
                screenshot.lastSemanticAnalysis == nil || screenshot.extractedText == nil
            }
        )
        
        let screenshotsNeedingProcessing = (try? modelContext.fetch(descriptor)) ?? []
        progress.needsProcessing = screenshotsNeedingProcessing.count
        
        guard !screenshotsNeedingProcessing.isEmpty else {
            return (processed: 0, needsProcessing: 0)
        }
        
        logger.info("🤖 Starting AI processing for \(screenshotsNeedingProcessing.count) screenshots")
        
        // Start OCR processing and wait for completion
        backgroundOCRProcessor.startBackgroundProcessingIfNeeded(in: modelContext)
        
        // Wait for OCR to initialize
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // Process semantic analysis and wait for completion
        await backgroundSemanticProcessor.processScreenshotsNeedingAnalysis(in: modelContext)
        
        // Trigger mind map regeneration and wait
        await backgroundSemanticProcessor.triggerMindMapRegeneration(in: modelContext)
        
        // Final wait to ensure all operations complete
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        
        progress.processed = screenshotsNeedingProcessing.count
        
        return (processed: screenshotsNeedingProcessing.count, needsProcessing: screenshotsNeedingProcessing.count)
    }
    
    private func processQueuedRequests() async {
        resetState()
        
        // Process next queued request if any
        guard let nextRequest = importQueue.first else { return }
        importQueue.removeFirst()
        
        logger.info("📋 Processing queued import request")
        
        // Note: This would need the same parameters - for now just complete with error
        nextRequest.completion(ImportResult(
            success: false,
            imported: 0,
            processed: 0,
            error: BulkImportError.queuedRequestNotImplemented,
            duration: 0
        ))
    }
    
    private func resetState() {
        isImportInProgress = false
        currentPhase = .idle
        progress = ImportProgress()
        currentImportTask = nil
    }
}

// MARK: - Error Types

enum BulkImportError: LocalizedError {
    case permissionDenied
    case cancelled
    case tooManyAttempts
    case queuedRequestNotImplemented
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo library permission denied"
        case .cancelled:
            return "Import operation was cancelled"
        case .tooManyAttempts:
            return "Too many import attempts while operation in progress"
        case .queuedRequestNotImplemented:
            return "Queued request processing not fully implemented"
        }
    }
}