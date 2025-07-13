import Foundation
import SwiftUI
import SwiftData
import OSLog
import UIKit

/// Background service for automatic screenshot categorization
@MainActor
public final class BackgroundCategorizationService: ObservableObject {
    public static let shared = BackgroundCategorizationService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "BackgroundCategorization")
    private let processingQueue = DispatchQueue(label: "background.categorization", qos: .utility)
    
    // Service dependencies
    private let categorizationService = CategorizationService.shared
    
    // Processing state
    @Published private(set) var isProcessing = false
    @Published private(set) var processingProgress: Double = 0.0
    @Published private(set) var currentlyProcessing: String?
    @Published private(set) var queuedCount = 0
    @Published private(set) var completedCount = 0
    @Published private(set) var errorCount = 0
    
    // Configuration
    private let batchSize = 5
    private let maxRetries = 3
    private let processingDelay: TimeInterval = 0.5 // Delay between screenshots to prevent overwhelming
    
    // Processing metrics
    private var sessionMetrics = BackgroundProcessingMetrics()
    
    private init() {
        logger.info("Background categorization service initialized")
    }
    
    // MARK: - Main Processing Interface
    
    /// Process all screenshots that need categorization
    public func processUncategorizedScreenshots(modelContext: ModelContext) async {
        logger.info("Starting background categorization of uncategorized screenshots")
        
        guard !isProcessing else {
            logger.warning("Background categorization already in progress")
            return
        }
        
        let startTime = Date()
        isProcessing = true
        processingProgress = 0.0
        errorCount = 0
        completedCount = 0
        
        defer {
            isProcessing = false
            currentlyProcessing = nil
            
            let duration = Date().timeIntervalSince(startTime)
            sessionMetrics.recordSession(duration: duration, processed: self.completedCount, errors: self.errorCount)
            
            logger.info("Background categorization completed: \(self.completedCount) processed, \(self.errorCount) errors in \(String(format: "%.1f", duration))s")
        }
        
        do {
            // Fetch uncategorized screenshots
            let uncategorizedScreenshotIDs = try await fetchUncategorizedScreenshots(modelContext: modelContext)
            let uncategorizedScreenshots = uncategorizedScreenshotIDs.compactMap { modelContext.model(for: $0) as? Screenshot }
            queuedCount = uncategorizedScreenshots.count
            
            guard !uncategorizedScreenshots.isEmpty else {
                logger.info("No screenshots need categorization")
                return
            }
            
            logger.info("Found \(uncategorizedScreenshots.count) screenshots needing categorization")
            
            // Process in batches
            let batches = uncategorizedScreenshotIDs.chunked(into: batchSize)
            
            for (batchIndex, batch) in batches.enumerated() {
                await processBatch(batch, batchIndex: batchIndex, totalBatches: batches.count, modelContext: modelContext)
                
                // Small delay between batches to prevent overwhelming the system
                if batchIndex < batches.count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
                }
            }
            
        } catch {
            logger.error("Failed to fetch uncategorized screenshots: \(error.localizedDescription)")
            errorCount += 1
        }
    }
    
    /// Process a single screenshot immediately
    public func processSingleScreenshot(_ screenshot: Screenshot, modelContext: ModelContext) async {
        logger.info("Processing single screenshot: \(screenshot.filename)")
        
        currentlyProcessing = screenshot.filename
        
        do {
            let result = try await categorizeScreenshot(screenshot)
            
            // Store result
            screenshot.categoryResult = result
            
            try modelContext.save()
            
            logger.info("Successfully categorized screenshot \(screenshot.filename) as \(result.category.displayPath())")
            
        } catch {
            logger.warning("Failed to categorize screenshot \(screenshot.filename): \(error.localizedDescription)")
        }
        
        currentlyProcessing = nil
    }
    
    /// Reprocess screenshots with low confidence
    public func reprocessLowConfidenceScreenshots(modelContext: ModelContext, confidenceThreshold: Double = 0.6) async {
        logger.info("Reprocessing screenshots with confidence below \(confidenceThreshold)")
        
        guard !isProcessing else {
            logger.warning("Background categorization already in progress")
            return
        }
        
        do {
            let lowConfidenceScreenshotIDs = try await fetchLowConfidenceScreenshots(modelContext: modelContext, threshold: confidenceThreshold)
            let lowConfidenceScreenshots = lowConfidenceScreenshotIDs.compactMap { modelContext.model(for: $0) as? Screenshot }
            
            guard !lowConfidenceScreenshots.isEmpty else {
                logger.info("No low-confidence screenshots to reprocess")
                return
            }
            
            logger.info("Found \(lowConfidenceScreenshots.count) low-confidence screenshots to reprocess")
            
            isProcessing = true
            queuedCount = lowConfidenceScreenshots.count
            completedCount = 0
            errorCount = 0
            
            for (index, screenshot) in lowConfidenceScreenshots.enumerated() {
                await processSingleScreenshot(screenshot, modelContext: modelContext)
                
                completedCount += 1
                processingProgress = Double(completedCount) / Double(queuedCount)
                
                // Small delay between screenshots
                if index < lowConfidenceScreenshots.count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
                }
            }
            
            isProcessing = false
            
        } catch {
            logger.error("Failed to reprocess low-confidence screenshots: \(error.localizedDescription)")
            isProcessing = false
        }
    }
    
    // MARK: - Batch Processing
    
    private func processBatch(_ screenshotIDs: [PersistentIdentifier], batchIndex: Int, totalBatches: Int, modelContext: ModelContext) async {
        logger.debug("Processing batch \(batchIndex + 1)/\(totalBatches) with \(screenshotIDs.count) screenshots")
        
        // Process screenshots in parallel within the batch (limited concurrency)
        await withTaskGroup(of: Void.self) { group in
            for screenshotID in screenshotIDs {
                group.addTask { [weak self] in
                    if let screenshot = await modelContext.model(for: screenshotID) as? Screenshot {
                        await self?.processScreenshotWithRetry(screenshot, modelContext: modelContext)
                    }
                }
            }
        }
        
        // Update overall progress
        let batchProgress = Double(batchIndex + 1) / Double(totalBatches)
        await MainActor.run {
            processingProgress = batchProgress
        }
    }
    
    private func processScreenshotWithRetry(_ screenshot: Screenshot, modelContext: ModelContext) async {
        currentlyProcessing = screenshot.filename
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let result = try await categorizeScreenshot(screenshot)
                
                // Store result in main actor context
                await MainActor.run {
                    screenshot.categoryResult = result
                    
                    do {
                        try modelContext.save()
                        completedCount += 1
                        logger.debug("Successfully categorized \(screenshot.filename) as \(result.category.displayPath()) (attempt \(attempt))")
                    } catch {
                        logger.warning("Failed to save categorization result for \(screenshot.filename): \(error.localizedDescription)")
                        errorCount += 1
                    }
                }
                
                return // Success, exit retry loop
                
            } catch {
                lastError = error
                logger.warning("Categorization attempt \(attempt)/\(self.maxRetries) failed for \(screenshot.filename): \(error.localizedDescription)")
                
                // Exponential backoff for retries
                if attempt < self.maxRetries {
                    let delay = pow(2.0, Double(attempt - 1)) * 0.5 // 0.5s, 1s, 2s
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed
        await MainActor.run {
            errorCount += 1
        }
        
        logger.error("Failed to categorize \(screenshot.filename) after \(self.maxRetries) attempts: \(lastError?.localizedDescription ?? "Unknown error")")
    }
    
    // MARK: - Categorization Logic
    
    private func categorizeScreenshot(_ screenshot: Screenshot) async throws -> CategoryResult {
        // Create UIImage from screenshot data
        guard let image = UIImage(data: screenshot.imageData) else {
            throw CategorizationError.invalidImageData
        }
        
        // Use the screenshot's metadata
        let metadata = screenshot.categorizationMetadata
        
        // Perform categorization
        let result = try await categorizationService.categorizeScreenshot(image, metadata: metadata)
        
        return result
    }
    
    // MARK: - Database Queries
    
    private func fetchUncategorizedScreenshots(modelContext: ModelContext) async throws -> [PersistentIdentifier] {
        return try await Task.detached {
            let descriptor = FetchDescriptor<Screenshot>(
                predicate: #Predicate<Screenshot> { screenshot in
                    screenshot.categoryResultData == nil || screenshot.needsCategorization
                },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            return try modelContext.fetch(descriptor).map { $0.persistentModelID }
        }.value
    }
    
    private func fetchLowConfidenceScreenshots(modelContext: ModelContext, threshold: Double) async throws -> [PersistentIdentifier] {
        return try await Task.detached {
            let descriptor = FetchDescriptor<Screenshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            let allScreenshots = try modelContext.fetch(descriptor)
            
            // Filter screenshots with low confidence
            return allScreenshots.filter { screenshot in
                guard let result = screenshot.categoryResult else { return false }
                return result.confidence < threshold || result.uncertainty.isUncertain
            }.map { $0.persistentModelID }
        }.value
    }
    
    // MARK: - Category Learning Integration
    
    /// Submit feedback for improving categorization accuracy
    public func submitCategoryFeedback(
        screenshot: Screenshot,
        correctedCategory: Category?,
        isCorrect: Bool,
        userRating: Int? = nil,
        comments: String? = nil
    ) async {
        guard let originalResult = screenshot.categoryResult else {
            logger.warning("Cannot submit feedback for screenshot without categorization result")
            return
        }
        
        let feedback = CategoryFeedback(
            originalCategory: originalResult.category,
            correctedCategory: correctedCategory,
            isCorrect: isCorrect,
            confidence: originalResult.confidence,
            feedbackType: isCorrect ? .confirmation : .correction,
            userId: getCurrentUserId()
        )
        
        await categorizationService.submitFeedback(feedback)
        
        // If user provided a correction, update the screenshot
        if let correctedCategory = correctedCategory, !isCorrect {
            screenshot.setManualCategory(correctedCategory)
            logger.info("Applied manual category correction: \(screenshot.filename) -> \(correctedCategory.displayPath())")
        }
    }
    
    private func getCurrentUserId() -> String? {
        // Return user identifier if available
        return nil // Placeholder
    }
    
    // MARK: - Status and Metrics
    
    /// Get current processing status
    public var processingStatus: ProcessingStatus {
        return ProcessingStatus(
            isProcessing: isProcessing,
            progress: processingProgress,
            currentItem: currentlyProcessing,
            queuedCount: queuedCount,
            completedCount: completedCount,
            errorCount: errorCount
        )
    }
    
    /// Get processing metrics
    public func getProcessingMetrics() -> BackgroundProcessingMetrics {
        return sessionMetrics
    }
    
    /// Reset processing metrics
    public func resetMetrics() {
        sessionMetrics = BackgroundProcessingMetrics()
        logger.info("Background categorization metrics reset")
    }
    
    // MARK: - Configuration
    
    /// Enable/disable automatic categorization for new screenshots
    public func setAutomaticCategorizationEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "automatic_categorization_enabled")
        logger.info("Automatic categorization \(enabled ? "enabled" : "disabled")")
    }
    
    /// Check if automatic categorization is enabled
    public var isAutomaticCategorizationEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "automatic_categorization_enabled")
    }
}

// MARK: - Supporting Types

public struct ProcessingStatus: Codable {
    public let isProcessing: Bool
    public let progress: Double
    public let currentItem: String?
    public let queuedCount: Int
    public let completedCount: Int
    public let errorCount: Int
    
    public var remainingCount: Int {
        return max(0, queuedCount - completedCount - errorCount)
    }
    
    public var successRate: Double {
        let totalProcessed = completedCount + errorCount
        return totalProcessed > 0 ? Double(completedCount) / Double(totalProcessed) : 0.0
    }
}

public struct BackgroundProcessingMetrics: Codable {
    private(set) var totalSessions = 0
    private(set) var totalProcessed = 0
    private(set) var totalErrors = 0
    private(set) var totalProcessingTime: TimeInterval = 0
    private(set) var lastSessionDate: Date?
    
    mutating func recordSession(duration: TimeInterval, processed: Int, errors: Int) {
        totalSessions += 1
        totalProcessed += processed
        totalErrors += errors
        totalProcessingTime += duration
        lastSessionDate = Date()
    }
    
    public var averageProcessingTime: TimeInterval {
        return totalSessions > 0 ? totalProcessingTime / TimeInterval(totalSessions) : 0
    }
    
    public var successRate: Double {
        let total = totalProcessed + totalErrors
        return total > 0 ? Double(totalProcessed) / Double(total) : 0.0
    }
    
    public var averageItemsPerSession: Double {
        return totalSessions > 0 ? Double(totalProcessed) / Double(totalSessions) : 0.0
    }
}

public enum CategorizationError: LocalizedError {
    case invalidImageData
    case processingFailed(String)
    case databaseError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Could not create image from screenshot data"
        case .processingFailed(let message):
            return "Categorization processing failed: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}


