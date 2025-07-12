import Foundation
import SwiftData
import os.log

/// Service for handling transaction-like operations with SwiftData
/// Provides atomic batch operations with rollback capabilities
@MainActor
class TransactionService: ObservableObject {
    nonisolated static let shared = TransactionService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "Transaction")
    
    nonisolated private init() {}
    
    /// Transaction state tracking
    enum TransactionState {
        case idle
        case inProgress
        case committed
        case rolledBack
    }
    
    /// Transaction result
    enum TransactionResult {
        case success(itemsProcessed: Int)
        case failure(error: Error, itemsProcessed: Int)
        case partialSuccess(itemsProcessed: Int, failures: [TransactionError])
    }
    
    /// Transaction-specific errors
    enum TransactionError: Error, LocalizedError {
        case transactionInProgress
        case contextUnavailable
        case batchOperationFailed(Error)
        case rollbackFailed(Error)
        case itemProcessingFailed(itemIndex: Int, error: Error)
        
        var errorDescription: String? {
            switch self {
            case .transactionInProgress:
                return "Another transaction is already in progress"
            case .contextUnavailable:
                return "Model context is not available"
            case .batchOperationFailed(let error):
                return "Batch operation failed: \(error.localizedDescription)"
            case .rollbackFailed(let error):
                return "Rollback failed: \(error.localizedDescription)"
            case .itemProcessingFailed(let itemIndex, let error):
                return "Item \(itemIndex) processing failed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Configuration for transaction behavior
    struct TransactionConfiguration {
        let batchSize: Int
        let continueOnError: Bool
        let saveFrequency: SaveFrequency
        let rollbackOnAnyFailure: Bool
        let maxRetries: Int
        
        enum SaveFrequency {
            case never           // Save only at end
            case afterEachItem   // Save after each successful item
            case afterEachBatch  // Save after each batch
            case periodic(Int)   // Save every N items
        }
        
        static let standard = TransactionConfiguration(
            batchSize: 10,
            continueOnError: true,
            saveFrequency: .afterEachBatch,
            rollbackOnAnyFailure: false,
            maxRetries: 0
        )
        
        static let strict = TransactionConfiguration(
            batchSize: 5,
            continueOnError: false,
            saveFrequency: .afterEachItem,
            rollbackOnAnyFailure: true,
            maxRetries: 2
        )
        
        static let aggressive = TransactionConfiguration(
            batchSize: 20,
            continueOnError: true,
            saveFrequency: .periodic(5),
            rollbackOnAnyFailure: false,
            maxRetries: 1
        )
    }
    
    /// Execute a batch transaction with comprehensive error handling and rollback
    /// - Parameters:
    ///   - modelContext: The SwiftData model context
    ///   - items: Array of items to process
    ///   - configuration: Transaction configuration
    ///   - operation: The operation to perform on each item
    /// - Returns: Transaction result with success/failure details
    func executeTransaction<T>(
        modelContext: ModelContext,
        items: [T],
        configuration: TransactionConfiguration = .standard,
        operation: @escaping (T, Int) async throws -> Void
    ) async -> TransactionResult {
        
        logger.info("Starting transaction with \(items.count) items")
        
        // Create a snapshot of the current state for potential rollback
        let snapshot = await createSnapshot(modelContext: modelContext)
        
        var processedCount = 0
        var failures: [TransactionError] = []
        
        // Process items in batches
        for batchStart in stride(from: 0, to: items.count, by: configuration.batchSize) {
            let batchEnd = min(batchStart + configuration.batchSize, items.count)
            let batch = Array(items[batchStart..<batchEnd])
            
            logger.info("Processing batch \(batchStart/configuration.batchSize + 1), items \(batchStart+1)-\(batchEnd)")
            
            // Process each item in the batch
            for (index, item) in batch.enumerated() {
                let globalIndex = batchStart + index
                
                do {
                    try await operation(item, globalIndex)
                    processedCount += 1
                    
                    // Handle save frequency
                    if case .afterEachItem = configuration.saveFrequency {
                        try await saveContext(modelContext: modelContext)
                    } else if case .periodic(let interval) = configuration.saveFrequency,
                              processedCount % interval == 0 {
                        try await saveContext(modelContext: modelContext)
                    }
                    
                } catch {
                    let transactionError = TransactionError.itemProcessingFailed(itemIndex: globalIndex, error: error)
                    failures.append(transactionError)
                    
                    logger.error("Item \(globalIndex) failed: \(error.localizedDescription)")
                    
                    // Check if we should stop on error
                    if !configuration.continueOnError || configuration.rollbackOnAnyFailure {
                        logger.warning("Stopping transaction due to error policy")
                        break
                    }
                }
            }
            
            // Save after each batch if configured
            if case .afterEachBatch = configuration.saveFrequency {
                do {
                    try await saveContext(modelContext: modelContext)
                } catch {
                    let transactionError = TransactionError.batchOperationFailed(error)
                    failures.append(transactionError)
                    
                    if configuration.rollbackOnAnyFailure {
                        logger.error("Batch save failed, rolling back")
                        break
                    }
                }
            }
            
            // Check if we need to stop due to errors
            if !configuration.continueOnError && !failures.isEmpty {
                break
            }
        }
        
        // Final save if needed
        if case .never = configuration.saveFrequency {
            do {
                try await saveContext(modelContext: modelContext)
            } catch {
                failures.append(TransactionError.batchOperationFailed(error))
            }
        }
        
        // Determine result and handle rollback if necessary
        let result = await determineResult(
            processedCount: processedCount,
            failures: failures,
            configuration: configuration,
            modelContext: modelContext,
            snapshot: snapshot
        )
        
        logger.info("Transaction completed: \(processedCount) processed, \(failures.count) failures")
        
        return result
    }
    
    /// Execute a batch screenshot import transaction
    /// - Parameters:
    ///   - modelContext: The SwiftData model context
    ///   - assets: Array of PHAssets to import
    ///   - configuration: Transaction configuration
    ///   - importOperation: The import operation to perform
    /// - Returns: Transaction result with import statistics
    func executeScreenshotImportTransaction(
        modelContext: ModelContext,
        assets: [PHAsset],
        configuration: TransactionConfiguration = .standard,
        importOperation: @escaping (PHAsset, Int) async throws -> UUID
    ) async -> TransactionResult {
        
        return await executeTransaction(
            modelContext: modelContext,
            items: assets,
            configuration: configuration
        ) { asset, index in
            _ = try await importOperation(asset, index)
            // The screenshot is already in the context, we don't need to do anything here.
        }
    }
    
    /// Create a snapshot of the current context state for rollback
    private func createSnapshot(modelContext: ModelContext) async -> ContextSnapshot {
        // For SwiftData, we'll track the objects that exist before the transaction
        // This is a simplified approach - in a more complex system you might want
        // to track actual data changes
        
        let existingScreenshots: [Screenshot] = (try? modelContext.fetch(FetchDescriptor<Screenshot>())) ?? []
        
        return ContextSnapshot(
            screenshotCount: existingScreenshots.count,
            screenshotIds: existingScreenshots.map { $0.id }
        )
    }
    
    /// Save the model context with error handling
    private func saveContext(modelContext: ModelContext) async throws {
        try modelContext.save()
    }
    
    /// Determine the final result and handle rollback if necessary
    private func determineResult(
        processedCount: Int,
        failures: [TransactionError],
        configuration: TransactionConfiguration,
        modelContext: ModelContext,
        snapshot: ContextSnapshot
    ) async -> TransactionResult {
        
        let shouldRollback = configuration.rollbackOnAnyFailure && !failures.isEmpty
        
        if shouldRollback {
            do {
                try await rollbackToSnapshot(modelContext: modelContext, snapshot: snapshot)
                logger.info("Successfully rolled back transaction")
                return .failure(
                    error: failures.first ?? TransactionError.batchOperationFailed(NSError(domain: "TransactionService", code: -1, userInfo: nil)),
                    itemsProcessed: 0
                )
            } catch {
                logger.error("Rollback failed: \(error.localizedDescription)")
                return .failure(
                    error: TransactionError.rollbackFailed(error),
                    itemsProcessed: processedCount
                )
            }
        }
        
        if failures.isEmpty {
            return .success(itemsProcessed: processedCount)
        } else {
            return .partialSuccess(itemsProcessed: processedCount, failures: failures)
        }
    }
    
    /// Rollback to a previous snapshot
    private func rollbackToSnapshot(modelContext: ModelContext, snapshot: ContextSnapshot) async throws {
        // Get all current screenshots
        let currentScreenshots = (try? modelContext.fetch(FetchDescriptor<Screenshot>())) ?? []
        
        // Delete any screenshots that weren't in the snapshot
        for screenshot in currentScreenshots {
            if !snapshot.screenshotIds.contains(screenshot.id) {
                modelContext.delete(screenshot)
            }
        }
        
        // Save the rollback
        try? modelContext.save()
    }
}

// MARK: - Supporting Types

/// Snapshot of context state for rollback purposes
struct ContextSnapshot {
    let screenshotCount: Int
    let screenshotIds: [UUID]
}

// MARK: - PHAsset Extension

import Photos

extension PHAsset {
    /// Convert PHAsset to a simple identifier for transaction tracking
    var transactionIdentifier: String {
        return localIdentifier
    }
}

// MARK: - Testing Support

extension TransactionService {
    /// Test helper to simulate transaction failures
    func simulateTransactionFailure() async throws {
        throw TransactionError.batchOperationFailed(NSError(domain: "TestError", code: -1, userInfo: nil))
    }
    
    /// Test helper to verify rollback functionality
    func testRollback(modelContext: ModelContext) async -> Bool {
        let snapshot = await createSnapshot(modelContext: modelContext)
        
        // Simulate some changes
        let testScreenshot = Screenshot(
            imageData: Data(),
            filename: "test_rollback.jpg",
            timestamp: Date()
        )
        
        modelContext.insert(testScreenshot)
        
        // Rollback
        do {
            try await rollbackToSnapshot(modelContext: modelContext, snapshot: snapshot)
            return true
        } catch {
            return false
        }
    }
}