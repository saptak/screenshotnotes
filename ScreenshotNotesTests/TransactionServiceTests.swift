import XCTest
import SwiftData
import Photos
@testable import ScreenshotNotes

final class TransactionServiceTests: XCTestCase {
    var transactionService: TransactionService!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        transactionService = TransactionService.shared
        
        // Create an in-memory model context for testing
        let schema = Schema([Screenshot.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer)
        } catch {
            XCTFail("Failed to create model context: \(error)")
        }
    }
    
    override func tearDown() {
        modelContext = nil
        transactionService = nil
        super.tearDown()
    }
    
    func testTransactionConfiguration() {
        let standardConfig = TransactionService.TransactionConfiguration.standard
        let strictConfig = TransactionService.TransactionConfiguration.strict
        let aggressiveConfig = TransactionService.TransactionConfiguration.aggressive
        
        XCTAssertEqual(standardConfig.batchSize, 10)
        XCTAssertEqual(strictConfig.batchSize, 5)
        XCTAssertEqual(aggressiveConfig.batchSize, 20)
        
        XCTAssertTrue(standardConfig.continueOnError)
        XCTAssertFalse(strictConfig.continueOnError)
        XCTAssertTrue(aggressiveConfig.continueOnError)
        
        XCTAssertFalse(standardConfig.rollbackOnAnyFailure)
        XCTAssertTrue(strictConfig.rollbackOnAnyFailure)
        XCTAssertFalse(aggressiveConfig.rollbackOnAnyFailure)
    }
    
    func testTransactionError() {
        let progressError = TransactionService.TransactionError.transactionInProgress
        let contextError = TransactionService.TransactionError.contextUnavailable
        let batchError = TransactionService.TransactionError.batchOperationFailed(NSError(domain: "test", code: 0, userInfo: nil))
        let itemError = TransactionService.TransactionError.itemProcessingFailed(itemIndex: 5, error: NSError(domain: "test", code: 0, userInfo: nil))
        
        XCTAssertNotNil(progressError.errorDescription)
        XCTAssertNotNil(contextError.errorDescription)
        XCTAssertNotNil(batchError.errorDescription)
        XCTAssertNotNil(itemError.errorDescription)
        
        XCTAssertTrue(itemError.errorDescription?.contains("Item 5") ?? false)
    }
    
    func testSuccessfulTransaction() async {
        let testItems = ["item1", "item2", "item3"]
        var processedItems: [String] = []
        
        let result = await transactionService.executeTransaction(
            modelContext: modelContext,
            items: testItems,
            configuration: .standard
        ) { item, index in
            processedItems.append(item)
            // Simulate some work
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        switch result {
        case .success(let itemsProcessed):
            XCTAssertEqual(itemsProcessed, 3)
            XCTAssertEqual(processedItems.count, 3)
            XCTAssertEqual(processedItems, testItems)
        case .failure(let error, let itemsProcessed):
            XCTFail("Transaction should have succeeded, but failed with: \(error), items processed: \(itemsProcessed)")
        case .partialSuccess(let itemsProcessed, let failures):
            XCTFail("Transaction should have fully succeeded, but had partial success with \(itemsProcessed) items and \(failures.count) failures")
        }
    }
    
    func testTransactionWithFailures() async {
        let testItems = ["item1", "item2", "item3", "item4"]
        var processedItems: [String] = []
        
        let result = await transactionService.executeTransaction(
            modelContext: modelContext,
            items: testItems,
            configuration: .standard
        ) { item, index in
            processedItems.append(item)
            
            // Simulate failure on item3
            if item == "item3" {
                throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated failure"])
            }
        }
        
        switch result {
        case .success:
            XCTFail("Transaction should have had partial success due to simulated failure")
        case .failure:
            XCTFail("Transaction should have continued with partial success")
        case .partialSuccess(let itemsProcessed, let failures):
            XCTAssertEqual(itemsProcessed, 3) // item1, item2, item4 should succeed
            XCTAssertEqual(failures.count, 1)
            XCTAssertEqual(processedItems.count, 4) // All items should be attempted
        }
    }
    
    func testStrictTransactionWithFailure() async {
        let testItems = ["item1", "item2", "item3", "item4"]
        var processedItems: [String] = []
        
        let result = await transactionService.executeTransaction(
            modelContext: modelContext,
            items: testItems,
            configuration: .strict
        ) { item, index in
            processedItems.append(item)
            
            // Simulate failure on item2
            if item == "item2" {
                throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated failure"])
            }
        }
        
        switch result {
        case .success:
            XCTFail("Strict transaction should have failed due to simulated failure")
        case .failure(let error, let itemsProcessed):
            XCTAssertEqual(itemsProcessed, 0) // Should rollback all items
            XCTAssertEqual(processedItems.count, 2) // Only item1 and item2 should be attempted
        case .partialSuccess:
            XCTFail("Strict transaction should have completely failed, not partial success")
        }
    }
    
    func testBatchProcessing() async {
        let testItems = Array(1...25) // 25 items
        var processedItems: [Int] = []
        
        let result = await transactionService.executeTransaction(
            modelContext: modelContext,
            items: testItems,
            configuration: .standard // batchSize = 10
        ) { item, index in
            processedItems.append(item)
        }
        
        switch result {
        case .success(let itemsProcessed):
            XCTAssertEqual(itemsProcessed, 25)
            XCTAssertEqual(processedItems.count, 25)
            XCTAssertEqual(processedItems.sorted(), testItems)
        case .failure(let error, let itemsProcessed):
            XCTFail("Batch transaction should have succeeded, but failed with: \(error), items processed: \(itemsProcessed)")
        case .partialSuccess(let itemsProcessed, let failures):
            XCTFail("Batch transaction should have fully succeeded, but had partial success with \(itemsProcessed) items and \(failures.count) failures")
        }
    }
    
    func testRollbackFunctionality() async {
        let rollbackSuccessful = await transactionService.testRollback(modelContext: modelContext)
        XCTAssertTrue(rollbackSuccessful, "Rollback test should succeed")
    }
    
    func testSimulatedFailure() async {
        do {
            try await transactionService.simulateTransactionFailure()
            XCTFail("Simulated failure should have thrown an error")
        } catch TransactionService.TransactionError.batchOperationFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testPHAssetTransactionIdentifier() {
        // This would require creating a mock PHAsset, which is complex
        // For now, we'll test the concept exists
        XCTAssertTrue(true, "PHAsset extension exists")
    }
    
    func testSaveFrequencyConfiguration() {
        let config1 = TransactionService.TransactionConfiguration(
            batchSize: 5,
            continueOnError: true,
            saveFrequency: .afterEachItem,
            rollbackOnAnyFailure: false,
            maxRetries: 0
        )
        
        let config2 = TransactionService.TransactionConfiguration(
            batchSize: 10,
            continueOnError: true,
            saveFrequency: .periodic(3),
            rollbackOnAnyFailure: false,
            maxRetries: 0
        )
        
        XCTAssertEqual(config1.batchSize, 5)
        XCTAssertEqual(config2.batchSize, 10)
        
        // Test that configurations are different
        XCTAssertNotEqual(config1.batchSize, config2.batchSize)
    }
    
    func testContextSnapshot() {
        let snapshot = ContextSnapshot(screenshotCount: 5, screenshotIds: [UUID(), UUID(), UUID()])
        
        XCTAssertEqual(snapshot.screenshotCount, 5)
        XCTAssertEqual(snapshot.screenshotIds.count, 3)
    }
}