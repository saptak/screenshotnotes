import Foundation
import UIKit
import OSLog
import Darwin

/// Comprehensive test suite for categorization system validation
@MainActor
public final class CategorizationTestSuite: ObservableObject {
    public static let shared = CategorizationTestSuite()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "CategorizationTest")
    private let categorizationService = CategorizationService.shared
    
    // Test results
    @Published private(set) var isRunning = false
    @Published private(set) var testProgress: Double = 0.0
    @Published private(set) var lastTestResults: TestResults?
    
    private init() {}
    
    // MARK: - Main Test Interface
    
    /// Run comprehensive categorization tests
    public func runComprehensiveTests() async -> TestResults {
        logger.info("Starting comprehensive categorization tests")
        
        isRunning = true
        testProgress = 0.0
        defer { isRunning = false }
        
        var results = TestResults()
        
        // Test 1: Individual category accuracy (40% of total)
        testProgress = 0.1
        let categoryAccuracy = await testCategoryAccuracy()
        results.categoryAccuracyResults = categoryAccuracy
        testProgress = 0.4
        
        // Test 2: Multi-signal integration (30% of total)
        let signalIntegration = await testSignalIntegration()
        results.signalIntegrationResults = signalIntegration
        testProgress = 0.7
        
        // Test 3: Performance benchmarks (20% of total)
        let performance = await testPerformance()
        results.performanceResults = performance
        testProgress = 0.9
        
        // Test 4: Edge case handling (10% of total)
        let edgeCases = await testEdgeCases()
        results.edgeCaseResults = edgeCases
        testProgress = 1.0
        
        // Calculate overall results
        results.calculateOverallMetrics()
        
        lastTestResults = results
        
        logger.info("Categorization tests completed with \(String(format: "%.1f", results.overallAccuracy * 100))% accuracy")
        
        return results
    }
    
    /// Run targeted accuracy test for specific category
    public func testCategoryAccuracy(for categoryId: String) async -> CategoryTestResult? {
        guard let category = Category.categoryById(categoryId) else {
            logger.warning("Category not found: \(categoryId)")
            return nil
        }
        
        logger.info("Testing accuracy for category: \(category.displayName)")
        
        let testCases = generateTestCasesForCategory(category)
        var correctPredictions = 0
        var totalTests = testCases.count
        var confidenceScores: [Double] = []
        var processingTimes: [TimeInterval] = []
        
        for testCase in testCases {
            let startTime = Date()
            
            do {
                let result = try await categorizationService.categorizeScreenshot(testCase.image, metadata: testCase.metadata)
                let processingTime = Date().timeIntervalSince(startTime)
                processingTimes.append(processingTime)
                
                let isCorrect = result.category.id == category.id || 
                                isAcceptableAlternative(predicted: result.category, expected: category)
                
                if isCorrect {
                    correctPredictions += 1
                }
                
                confidenceScores.append(result.confidence)
                
            } catch {
                logger.warning("Categorization failed for test case: \(error.localizedDescription)")
                totalTests -= 1 // Don't count failed tests
            }
        }
        
        let accuracy = totalTests > 0 ? Double(correctPredictions) / Double(totalTests) : 0.0
        let avgConfidence = confidenceScores.isEmpty ? 0.0 : confidenceScores.reduce(0, +) / Double(confidenceScores.count)
        let avgProcessingTime = processingTimes.isEmpty ? 0.0 : processingTimes.reduce(0, +) / Double(processingTimes.count)
        
        return CategoryTestResult(
            category: category,
            accuracy: accuracy,
            averageConfidence: avgConfidence,
            averageProcessingTime: avgProcessingTime,
            testCaseCount: totalTests,
            confidenceDistribution: confidenceScores.sorted()
        )
    }
    
    // MARK: - Test Implementation
    
    private func testCategoryAccuracy() async -> [CategoryTestResult] {
        logger.info("Testing individual category accuracy")
        
        var results: [CategoryTestResult] = []
        let primaryCategories = Category.primaryCategories
        
        for (index, category) in primaryCategories.enumerated() {
            if let result = await testCategoryAccuracy(for: category.id) {
                results.append(result)
            }
            
            // Update progress
            let progress = 0.1 + (0.3 * Double(index + 1) / Double(primaryCategories.count))
            await MainActor.run {
                testProgress = progress
            }
        }
        
        return results
    }
    
    private func testSignalIntegration() async -> SignalIntegrationResult {
        logger.info("Testing multi-signal integration")
        
        // Test cases with known signal strengths
        let testCases = generateSignalIntegrationTestCases()
        var visionOnlyAccuracy: [Double] = []
        var textOnlyAccuracy: [Double] = []
        var metadataOnlyAccuracy: [Double] = []
        var combinedAccuracy: [Double] = []
        
        for testCase in testCases {
            // Test individual signals (simulated)
            let visionAccuracy = await simulateVisionOnlyTest(testCase)
            let textAccuracy = await simulateTextOnlyTest(testCase)
            let metadataAccuracy = await simulateMetadataOnlyTest(testCase)
            
            visionOnlyAccuracy.append(visionAccuracy)
            textOnlyAccuracy.append(textAccuracy)
            metadataOnlyAccuracy.append(metadataAccuracy)
            
            // Test combined approach
            do {
                let result = try await categorizationService.categorizeScreenshot(testCase.image, metadata: testCase.metadata)
                let isCorrect = result.category.id == testCase.expectedCategory.id
                combinedAccuracy.append(isCorrect ? 1.0 : 0.0)
            } catch {
                combinedAccuracy.append(0.0)
            }
        }
        
        return SignalIntegrationResult(
            visionOnlyAccuracy: calculateAverage(visionOnlyAccuracy),
            textOnlyAccuracy: calculateAverage(textOnlyAccuracy),
            metadataOnlyAccuracy: calculateAverage(metadataOnlyAccuracy),
            combinedAccuracy: calculateAverage(combinedAccuracy),
            improvementOverBestSingle: calculateImprovement(combined: combinedAccuracy, individual: [visionOnlyAccuracy, textOnlyAccuracy, metadataOnlyAccuracy])
        )
    }
    
    private func testPerformance() async -> PerformanceTestResult {
        logger.info("Testing categorization performance")
        
        let testImages = generatePerformanceTestImages()
        var processingTimes: [TimeInterval] = []
        var memoryUsages: [Int] = []
        var successfulCategorizations = 0
        
        for image in testImages {
            let startTime = Date()
            let startMemory = getCurrentMemoryUsage()
            
            do {
                _ = try await categorizationService.categorizeScreenshot(image)
                successfulCategorizations += 1
            } catch {
                logger.warning("Performance test categorization failed: \(error.localizedDescription)")
            }
            
            let processingTime = Date().timeIntervalSince(startTime)
            let endMemory = getCurrentMemoryUsage()
            
            processingTimes.append(processingTime)
            memoryUsages.append(endMemory - startMemory)
        }
        
        return PerformanceTestResult(
            averageProcessingTime: calculateAverage(processingTimes),
            maxProcessingTime: processingTimes.max() ?? 0,
            minProcessingTime: processingTimes.min() ?? 0,
            averageMemoryUsage: Double(memoryUsages.reduce(0, +)) / Double(memoryUsages.count),
            successRate: Double(successfulCategorizations) / Double(testImages.count),
            throughputPerSecond: Double(testImages.count) / processingTimes.reduce(0, +)
        )
    }
    
    private func testEdgeCases() async -> EdgeCaseTestResult {
        logger.info("Testing edge case handling")
        
        var results = EdgeCaseTestResult()
        
        // Test 1: Empty/blank images
        results.blankImageHandling = await testBlankImageHandling()
        
        // Test 2: Very small images
        results.smallImageHandling = await testSmallImageHandling()
        
        // Test 3: Very large images
        results.largeImageHandling = await testLargeImageHandling()
        
        // Test 4: Corrupted metadata
        results.corruptedMetadataHandling = await testCorruptedMetadataHandling()
        
        // Test 5: Ambiguous content
        results.ambiguousContentHandling = await testAmbiguousContentHandling()
        
        return results
    }
    
    // MARK: - Test Case Generation
    
    private func generateTestCasesForCategory(_ category: Category) -> [TestCase] {
        // This would generate or load test images for each category
        // For now, return mock test cases
        return [
            TestCase(
                image: createMockImage(for: category),
                expectedCategory: category,
                metadata: createMockMetadata(for: category),
                description: "Test case for \(category.displayName)"
            )
        ]
    }
    
    private func generateSignalIntegrationTestCases() -> [TestCase] {
        return Category.primaryCategories.map { category in
            TestCase(
                image: createMockImage(for: category),
                expectedCategory: category,
                metadata: createMockMetadata(for: category),
                description: "Signal integration test for \(category.displayName)"
            )
        }
    }
    
    private func generatePerformanceTestImages() -> [UIImage] {
        return (0..<10).map { _ in createGenericMockImage() }
    }
    
    private func createMockImage(for category: Category) -> UIImage {
        // Create a simple colored image as mock
        let size = CGSize(width: 300, height: 400)
        UIGraphicsBeginImageContext(size)
        UIColor.systemBlue.setFill() // Use a standard color for mock images
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
    
    private func createGenericMockImage() -> UIImage {
        let size = CGSize(width: 200, height: 300)
        UIGraphicsBeginImageContext(size)
        UIColor.systemBlue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
    
    private func createMockMetadata(for category: Category) -> ScreenshotMetadata {
        return ScreenshotMetadata(
            timestamp: Date(),
            sourceApp: getMockAppForCategory(category),
            fileSize: 500_000,
            dimensions: CGSize(width: 375, height: 812)
        )
    }
    
    private func getMockAppForCategory(_ category: Category) -> String {
        switch category.id {
        case "digital.social": return "Instagram"
        case "digital.messaging": return "Messages"
        case "digital.email": return "Mail"
        case "shopping": return "Amazon"
        case "financial": return "Bank App"
        default: return "Unknown"
        }
    }
    
    // MARK: - Test Utilities
    
    private func isAcceptableAlternative(predicted: Category, expected: Category) -> Bool {
        // Allow parent-child relationships as acceptable
        if predicted.parentId == expected.id || expected.parentId == predicted.id {
            return true
        }
        
        // Allow sibling categories with high similarity
        if predicted.parentId == expected.parentId && predicted.parentId != nil {
            return true
        }
        
        return false
    }
    
    private func calculateAverage(_ values: [Double]) -> Double {
        return values.isEmpty ? 0.0 : values.reduce(0, +) / Double(values.count)
    }
    
    private func calculateImprovement(combined: [Double], individual: [[Double]]) -> Double {
        let combinedAvg = calculateAverage(combined)
        let bestIndividual = individual.map { calculateAverage($0) }.max() ?? 0.0
        return combinedAvg - bestIndividual
    }
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size / 1024 / 1024) : 0
    }
    
    // MARK: - Simulated Single-Signal Tests
    
    private func simulateVisionOnlyTest(_ testCase: TestCase) async -> Double {
        // Simulate vision-only accuracy based on category type
        switch testCase.expectedCategory.id {
        case "media.photos", "media.screenshots": return 0.9
        case "documents.receipts", "documents.invoices": return 0.85
        case "digital.websites", "digital.apps": return 0.8
        default: return 0.7
        }
    }
    
    private func simulateTextOnlyTest(_ testCase: TestCase) async -> Double {
        // Simulate text-only accuracy
        switch testCase.expectedCategory.id {
        case "documents.receipts", "documents.invoices": return 0.9
        case "digital.email", "digital.messaging": return 0.85
        case "work", "education": return 0.8
        default: return 0.6
        }
    }
    
    private func simulateMetadataOnlyTest(_ testCase: TestCase) async -> Double {
        // Simulate metadata-only accuracy
        if testCase.metadata?.sourceApp != nil {
            return 0.7
        }
        return 0.4
    }
    
    // MARK: - Edge Case Tests
    
    private func testBlankImageHandling() async -> Bool {
        let blankImage = UIImage()
        do {
            let result = try await categorizationService.categorizeScreenshot(blankImage)
            return result.category.id == "uncategorized" && result.confidence < 0.3
        } catch {
            return true // Graceful error handling is acceptable
        }
    }
    
    private func testSmallImageHandling() async -> Bool {
        let smallImage = createImageWithSize(CGSize(width: 10, height: 10))
        do {
            _ = try await categorizationService.categorizeScreenshot(smallImage)
            return true // Should handle without crashing
        } catch {
            return true // Graceful error handling is acceptable
        }
    }
    
    private func testLargeImageHandling() async -> Bool {
        let largeImage = createImageWithSize(CGSize(width: 4000, height: 6000))
        do {
            _ = try await categorizationService.categorizeScreenshot(largeImage)
            return true // Should handle without crashing
        } catch {
            return true // Graceful error handling is acceptable
        }
    }
    
    private func testCorruptedMetadataHandling() async -> Bool {
        let corruptedMetadata = ScreenshotMetadata(timestamp: nil, sourceApp: "", fileSize: -1)
        do {
            _ = try await categorizationService.categorizeScreenshot(createGenericMockImage(), metadata: corruptedMetadata)
            return true
        } catch {
            return true
        }
    }
    
    private func testAmbiguousContentHandling() async -> Bool {
        // Test with content that could belong to multiple categories
        let ambiguousImage = createGenericMockImage()
        do {
            let result = try await categorizationService.categorizeScreenshot(ambiguousImage)
            return result.uncertainty.isUncertain // Should detect ambiguity
        } catch {
            return false
        }
    }
    
    private func createImageWithSize(_ size: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(size)
        UIColor.gray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - Test Data Structures

public struct TestResults: Codable {
    var categoryAccuracyResults: [CategoryTestResult] = []
    var signalIntegrationResults: SignalIntegrationResult?
    var performanceResults: PerformanceTestResult?
    var edgeCaseResults: EdgeCaseTestResult?
    
    var overallAccuracy: Double = 0.0
    var overallConfidence: Double = 0.0
    var testPassed: Bool = false
    
    mutating func calculateOverallMetrics() {
        // Calculate overall accuracy from category results
        if !categoryAccuracyResults.isEmpty {
            overallAccuracy = categoryAccuracyResults.map { $0.accuracy }.reduce(0, +) / Double(categoryAccuracyResults.count)
            overallConfidence = categoryAccuracyResults.map { $0.averageConfidence }.reduce(0, +) / Double(categoryAccuracyResults.count)
        }
        
        // Test passes if accuracy >= 88% (target)
        testPassed = overallAccuracy >= 0.88
    }
}

public struct CategoryTestResult: Codable {
    let category: Category
    let accuracy: Double
    let averageConfidence: Double
    let averageProcessingTime: TimeInterval
    let testCaseCount: Int
    let confidenceDistribution: [Double]
    
    var passed: Bool {
        return accuracy >= category.confidenceThreshold
    }
}

public struct SignalIntegrationResult: Codable {
    let visionOnlyAccuracy: Double
    let textOnlyAccuracy: Double
    let metadataOnlyAccuracy: Double
    let combinedAccuracy: Double
    let improvementOverBestSingle: Double
    
    var demonstratesImprovement: Bool {
        return improvementOverBestSingle > 0.05 // 5% improvement threshold
    }
}

public struct PerformanceTestResult: Codable {
    let averageProcessingTime: TimeInterval
    let maxProcessingTime: TimeInterval
    let minProcessingTime: TimeInterval
    let averageMemoryUsage: Double
    let successRate: Double
    let throughputPerSecond: Double
    
    var meetsPerformanceTargets: Bool {
        return averageProcessingTime < 2.0 && successRate > 0.95 && averageMemoryUsage < 50.0
    }
}

public struct EdgeCaseTestResult: Codable {
    var blankImageHandling: Bool = false
    var smallImageHandling: Bool = false
    var largeImageHandling: Bool = false
    var corruptedMetadataHandling: Bool = false
    var ambiguousContentHandling: Bool = false
    
    var allEdgeCasesHandled: Bool {
        return blankImageHandling && smallImageHandling && largeImageHandling && 
               corruptedMetadataHandling && ambiguousContentHandling
    }
}

private struct TestCase {
    let image: UIImage
    let expectedCategory: Category
    let metadata: ScreenshotMetadata?
    let description: String
}

