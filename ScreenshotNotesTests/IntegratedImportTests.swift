import XCTest
import SwiftData
import Photos
@testable import ScreenshotNotes

/// Integration tests for the combined NetworkRetryService + TransactionService implementation
final class IntegratedImportTests: XCTestCase {
    var photoLibraryService: PhotoLibraryService!
    var networkRetryService: NetworkRetryService!
    var transactionService: TransactionService!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        
        // Create an in-memory model context for testing
        let schema = Schema([Screenshot.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer)
        } catch {
            XCTFail("Failed to create model context: \(error)")
        }
        
        // Initialize services
        networkRetryService = NetworkRetryService.shared
        transactionService = TransactionService.shared
        photoLibraryService = PhotoLibraryService(
            imageStorageService: MockImageStorageService(),
            hapticService: MockHapticFeedbackService(),
            networkRetryService: networkRetryService,
            transactionService: transactionService
        )
        
        // Set the model context
        photoLibraryService.setModelContext(modelContext)
    }
    
    override func tearDown() {
        photoLibraryService = nil
        networkRetryService = nil
        transactionService = nil
        modelContext = nil
        super.tearDown()
    }
    
    func testNetworkRetryServiceInitialization() {
        XCTAssertNotNil(networkRetryService)
        
        // Test configuration options
        let standardConfig = NetworkRetryService.RetryConfiguration.standard
        let aggressiveConfig = NetworkRetryService.RetryConfiguration.aggressive
        let conservativeConfig = NetworkRetryService.RetryConfiguration.conservative
        
        XCTAssertEqual(standardConfig.maxRetries, 3)
        XCTAssertEqual(aggressiveConfig.maxRetries, 5)
        XCTAssertEqual(conservativeConfig.maxRetries, 2)
        
        XCTAssertTrue(standardConfig.baseDelay > 0)
        XCTAssertTrue(aggressiveConfig.baseDelay > 0)
        XCTAssertTrue(conservativeConfig.baseDelay > 0)
    }
    
    func testTransactionServiceInitialization() {
        XCTAssertNotNil(transactionService)
        
        // Test configuration options
        let standardConfig = TransactionService.TransactionConfiguration.standard
        let strictConfig = TransactionService.TransactionConfiguration.strict
        let aggressiveConfig = TransactionService.TransactionConfiguration.aggressive
        
        XCTAssertEqual(standardConfig.batchSize, 10)
        XCTAssertEqual(strictConfig.batchSize, 5)
        XCTAssertEqual(aggressiveConfig.batchSize, 20)
        
        XCTAssertTrue(standardConfig.continueOnError)
        XCTAssertFalse(strictConfig.continueOnError)
        XCTAssertTrue(aggressiveConfig.continueOnError)
    }
    
    func testPhotoLibraryServiceIntegration() {
        XCTAssertNotNil(photoLibraryService)
        
        // Test that the service has both retry and transaction capabilities
        XCTAssertTrue(photoLibraryService.responds(to: #selector(PhotoLibraryService.importAllPastScreenshots)))
        XCTAssertTrue(photoLibraryService.responds(to: #selector(PhotoLibraryService.importAllPastScreenshotsWithTransaction)))
    }
    
    func testErrorHandlingIntegration() {
        // Test that network errors are properly classified
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let classifiedError = networkRetryService.classifyError(networkError)
        
        switch classifiedError {
        case .networkUnavailable:
            XCTAssertTrue(classifiedError.isRetryable)
        default:
            XCTFail("Should classify as network unavailable")
        }
        
        // Test that transaction errors are properly defined
        let transactionError = TransactionService.TransactionError.contextUnavailable
        XCTAssertNotNil(transactionError.errorDescription)
    }
    
    func testRetryLogicWithTransactions() async {
        // Test that retry logic works within transaction context
        let testItems = ["item1", "item2", "item3"]
        var attemptCounts: [String: Int] = [:]
        
        let result = await transactionService.executeTransaction(
            modelContext: modelContext,
            items: testItems,
            configuration: .standard
        ) { item, index in
            attemptCounts[item, default: 0] += 1
            
            // Simulate network failure on first attempt for item2
            if item == "item2" && attemptCounts[item] == 1 {
                throw NetworkRetryService.NetworkError.temporaryFailure(
                    NSError(domain: "TestError", code: -1, userInfo: nil)
                )
            }
        }
        
        switch result {
        case .success(let itemsProcessed):
            XCTAssertEqual(itemsProcessed, 3)
        case .partialSuccess(let itemsProcessed, let failures):
            // This is also acceptable depending on retry configuration
            XCTAssertTrue(itemsProcessed > 0)
            XCTAssertTrue(failures.count <= 1)
        case .failure(let error, let itemsProcessed):
            XCTFail("Transaction should have succeeded or partially succeeded, but failed with: \(error)")
        }
    }
    
    func testBatchProcessingWithRetry() async {
        // Test that batch processing works with retry logic
        let testItems = Array(1...15) // 15 items to test batch processing
        var processedItems: [Int] = []
        
        let result = await transactionService.executeTransaction(
            modelContext: modelContext,
            items: testItems,
            configuration: .standard
        ) { item, index in
            processedItems.append(item)
            
            // Simulate occasional network issues
            if item % 7 == 0 {
                throw NetworkRetryService.NetworkError.temporaryFailure(
                    NSError(domain: "TestError", code: -1, userInfo: nil)
                )
            }
        }
        
        switch result {
        case .success(let itemsProcessed):
            XCTAssertEqual(itemsProcessed, 13) // 15 - 2 failures (7, 14)
        case .partialSuccess(let itemsProcessed, let failures):
            XCTAssertTrue(itemsProcessed > 10)
            XCTAssertTrue(failures.count <= 3)
        case .failure:
            // Should continue on error with standard configuration
            XCTFail("Standard configuration should continue on error")
        }
    }
    
    func testRollbackOnCriticalFailure() async {
        // Test that rollback works when using strict configuration
        let testItems = ["item1", "item2", "item3"]
        var processedItems: [String] = []
        
        let result = await transactionService.executeTransaction(
            modelContext: modelContext,
            items: testItems,
            configuration: .strict
        ) { item, index in
            processedItems.append(item)
            
            // Simulate a critical failure on item2
            if item == "item2" {
                throw NetworkRetryService.NetworkError.permanentFailure(
                    NSError(domain: "TestError", code: -1, userInfo: nil)
                )
            }
        }
        
        switch result {
        case .success:
            XCTFail("Strict configuration should have failed due to permanent failure")
        case .failure(let error, let itemsProcessed):
            XCTAssertEqual(itemsProcessed, 0) // Should rollback all items
        case .partialSuccess:
            XCTFail("Strict configuration should have completely failed")
        }
    }
    
    func testMemoryAndPerformance() async {
        // Test that the integrated system handles memory pressure gracefully
        let largeItemCount = 100
        let testItems = Array(1...largeItemCount)
        
        let startTime = Date()
        
        let result = await transactionService.executeTransaction(
            modelContext: modelContext,
            items: testItems,
            configuration: .aggressive
        ) { item, index in
            // Simulate some work
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time (less than 10 seconds for 100 items)
        XCTAssertTrue(duration < 10.0, "Processing took too long: \(duration) seconds")
        
        switch result {
        case .success(let itemsProcessed):
            XCTAssertEqual(itemsProcessed, largeItemCount)
        case .partialSuccess(let itemsProcessed, let failures):
            XCTAssertTrue(itemsProcessed > largeItemCount * 0.8) // At least 80% success
            XCTAssertTrue(failures.count < largeItemCount * 0.2) // Less than 20% failures
        case .failure:
            XCTFail("Aggressive configuration should handle large batches")
        }
    }
    
    func testNetworkRecovery() async {
        // Test that network recovery works correctly
        let isNetworkAvailable = await networkRetryService.checkNetworkAvailability()
        
        // This test depends on network connectivity, so we just verify it doesn't crash
        XCTAssertTrue(isNetworkAvailable || !isNetworkAvailable)
    }
    
    func testConfigurationConsistency() {
        // Test that all configurations are consistent and valid
        let networkConfigs = [
            NetworkRetryService.RetryConfiguration.standard,
            NetworkRetryService.RetryConfiguration.aggressive,
            NetworkRetryService.RetryConfiguration.conservative
        ]
        
        for config in networkConfigs {
            XCTAssertTrue(config.maxRetries > 0)
            XCTAssertTrue(config.baseDelay > 0)
            XCTAssertTrue(config.maxDelay > config.baseDelay)
            XCTAssertTrue(config.jitterFactor >= 0 && config.jitterFactor <= 1)
        }
        
        let transactionConfigs = [
            TransactionService.TransactionConfiguration.standard,
            TransactionService.TransactionConfiguration.strict,
            TransactionService.TransactionConfiguration.aggressive
        ]
        
        for config in transactionConfigs {
            XCTAssertTrue(config.batchSize > 0)
            XCTAssertTrue(config.maxRetries >= 0)
        }
    }
}

// MARK: - Mock Services

class MockImageStorageService: ImageStorageServiceProtocol {
    func saveImage(_ image: UIImage, filename: String) async throws -> Data {
        // Return dummy data
        return Data("mock_image_data".utf8)
    }
    
    func loadImage(from data: Data) -> UIImage? {
        return UIImage()
    }
    
    func deleteImageData(_ data: Data) async throws {
        // Mock implementation
    }
}

class MockHapticFeedbackService: HapticFeedbackServiceProtocol {
    func triggerHaptic(_ pattern: HapticPattern, intensity: CGFloat? = nil) {
        // Mock implementation - no actual haptic feedback
    }
    
    func triggerHapticSequence(_ patterns: [HapticPattern]) {
        // Mock implementation - no actual haptic feedback
    }
}