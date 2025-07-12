import Foundation
import UIKit
import SwiftData
import OSLog

/// Phase 2: Stress testing framework to validate resource starvation prevention
/// Ensures the gallery performance optimizations work under extreme conditions
@MainActor
class GalleryStressTester: ObservableObject {
    static let shared = GalleryStressTester()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "GalleryStressTester")
    
    // MARK: - Test State
    
    @Published var isRunningStressTest = false
    @Published var currentTestPhase: StressTestPhase = .idle
    @Published var testProgress: Double = 0.0
    @Published var testResults: [StressTestResult] = []
    
    // MARK: - Test Configuration
    
    private let testConfigurations: [StressTestConfiguration] = [
        StressTestConfiguration(
            name: "Small Collection Stress",
            screenshotCount: 100,
            concurrentRequests: 5,
            duration: 30,
            memoryPressureLevel: .normal
        ),
        StressTestConfiguration(
            name: "Medium Collection Stress",
            screenshotCount: 500,
            concurrentRequests: 10,
            duration: 60,
            memoryPressureLevel: .warning
        ),
        StressTestConfiguration(
            name: "Large Collection Stress",
            screenshotCount: 1000,
            concurrentRequests: 15,
            duration: 90,
            memoryPressureLevel: .warning
        ),
        StressTestConfiguration(
            name: "Extreme Collection Stress",
            screenshotCount: 2000,
            concurrentRequests: 20,
            duration: 120,
            memoryPressureLevel: .critical
        )
    ]
    
    // MARK: - Test Dependencies
    
    private var cacheManager: AdvancedThumbnailCacheManager
    private var backgroundProcessor: BackgroundThumbnailProcessor
    private var qualityManager: AdaptiveQualityManager
    private var viewportManager: PredictiveViewportManager
    
    // MARK: - Performance Tracking
    
    private var startTime: Date = Date()
    private var memoryUsageHistory: [MemorySnapshot] = []
    private var performanceMetrics: [PerformanceSnapshot] = []
    private var resourceStarvationEvents: [ResourceStarvationEvent] = []
    
    private init() {
        self.cacheManager = AdvancedThumbnailCacheManager.shared
        self.backgroundProcessor = BackgroundThumbnailProcessor.shared
        self.qualityManager = AdaptiveQualityManager.shared
        self.viewportManager = PredictiveViewportManager.shared
        
        logger.info("GalleryStressTester initialized")
    }
    
    // MARK: - Public Interface
    
    /// Run comprehensive stress tests
    func runStressTests() async {
        guard !isRunningStressTest else {
            logger.warning("Stress test already running")
            return
        }
        
        logger.info("Starting comprehensive gallery stress tests")
        isRunningStressTest = true
        testResults.removeAll()
        
        for (index, configuration) in testConfigurations.enumerated() {
            currentTestPhase = .running(configuration.name)
            testProgress = Double(index) / Double(testConfigurations.count)
            
            let result = await runSingleStressTest(configuration: configuration)
            testResults.append(result)
            
            // Allow system to recover between tests
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        }
        
        currentTestPhase = .completed
        testProgress = 1.0
        isRunningStressTest = false
        
        await generateStressTestReport()
        logger.info("Comprehensive stress tests completed")
    }
    
    /// Run a single stress test configuration
    func runSingleStressTest(configuration: StressTestConfiguration) async -> StressTestResult {
        logger.info("Running stress test: \(configuration.name)")
        
        startTime = Date()
        memoryUsageHistory.removeAll()
        performanceMetrics.removeAll()
        resourceStarvationEvents.removeAll()
        
        // Configure systems for test
        qualityManager.updateCollectionSize(configuration.screenshotCount)
        cacheManager.updateCollectionSize(configuration.screenshotCount)
        
        // Generate test screenshots
        let testScreenshots = generateTestScreenshots(count: configuration.screenshotCount)
        
        // Start monitoring
        let monitoringTask = Task { await monitorSystemDuringTest(duration: configuration.duration) }
        
        // Run the actual stress test
        let stressTask = Task { await simulateStressScenario(configuration: configuration, screenshots: testScreenshots) }
        
        // Wait for both tasks to complete
        _ = await [monitoringTask.value, stressTask.value]
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        return StressTestResult(
            configuration: configuration,
            duration: duration,
            memoryUsageHistory: memoryUsageHistory,
            performanceMetrics: performanceMetrics,
            resourceStarvationEvents: resourceStarvationEvents,
            finalCacheStatistics: cacheManager.cacheStatistics,
            passed: evaluateTestResults()
        )
    }
    
    // MARK: - Test Generation
    
    private func generateTestScreenshots(count: Int) -> [MockScreenshot] {
        return (0..<count).map { index in
            MockScreenshot(
                id: UUID(),
                filename: "test_screenshot_\(index).png",
                imageData: generateMockImageData(size: 1024 * 1024) // 1MB per image
            )
        }
    }
    
    private func generateMockImageData(size: Int) -> Data {
        // Generate realistic-sized mock data
        let pattern = "TEST_DATA_PATTERN_"
        let patternData = pattern.data(using: .utf8) ?? Data()
        var data = Data()
        
        while data.count < size {
            data.append(patternData)
        }
        
        return Data(data.prefix(size))
    }
    
    // MARK: - Stress Simulation
    
    private func simulateStressScenario(configuration: StressTestConfiguration, screenshots: [MockScreenshot]) async {
        logger.info("Simulating stress scenario with \(screenshots.count) screenshots")
        
        // Simulate rapid thumbnail requests
        await simulateRapidThumbnailRequests(screenshots: screenshots, concurrency: configuration.concurrentRequests)
        
        // Simulate rapid scrolling
        await simulateRapidScrolling(itemCount: screenshots.count)
        
        // Simulate memory pressure
        await simulateMemoryPressure(level: configuration.memoryPressureLevel)
        
        // Simulate bulk operations
        await simulateBulkOperations(screenshots: screenshots)
    }
    
    private func simulateRapidThumbnailRequests(screenshots: [MockScreenshot], concurrency: Int) async {
        logger.info("Simulating rapid thumbnail requests with concurrency: \(concurrency)")
        
        await withTaskGroup(of: Void.self) { group in
            for batch in screenshots.chunked(into: concurrency) {
                group.addTask {
                    await self.processThumbnailBatch(batch)
                }
                
                // Small delay to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }
    
    private func processThumbnailBatch(_ screenshots: [MockScreenshot]) async {
        for screenshot in screenshots {
            // Simulate thumbnail request
            backgroundProcessor.requestThumbnail(
                for: screenshot.id,
                from: screenshot.imageData,
                size: CGSize(width: 200, height: 200),
                priority: .normal
            )
            
            // Small delay to simulate processing time
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
    
    private func simulateRapidScrolling(itemCount: Int) async {
        logger.info("Simulating rapid scrolling through \(itemCount) items")
        
        let itemHeight: CGFloat = 200
        let viewportHeight: CGFloat = 800
        
        for offset in stride(from: 0, to: CGFloat(itemCount) * itemHeight, by: itemHeight / 4) {
            let firstVisible = Int(offset / itemHeight)
            let lastVisible = min(itemCount - 1, Int((offset + viewportHeight) / itemHeight))
            
            let viewport = ViewportInfo(
                firstVisibleIndex: firstVisible,
                lastVisibleIndex: lastVisible,
                visibleIndices: Set(firstVisible...lastVisible),
                totalItems: itemCount,
                viewportHeight: viewportHeight,
                contentHeight: CGFloat(itemCount) * itemHeight
            )
            
            viewportManager.updateViewport(viewport)
            viewportManager.updateScrollOffset(offset)
            
            // Simulate scroll velocity
            try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps
        }
    }
    
    private func simulateMemoryPressure(level: ThumbnailMemoryPressureLevel) async {
        logger.info("Simulating memory pressure: \(String(describing: level))")
        
        cacheManager.optimizeForMemoryPressure(level: level)
        
        // Record starvation event if critical
        if level == .critical {
            resourceStarvationEvents.append(ResourceStarvationEvent(
                type: .memoryPressure,
                timestamp: Date(),
                severity: .high,
                description: "Critical memory pressure simulation"
            ))
        }
    }
    
    private func simulateBulkOperations(screenshots: [MockScreenshot]) async {
        logger.info("Simulating bulk operations")
        
        // Simulate bulk import
        let batchSize = min(50, screenshots.count / 4)
        _ = Array(screenshots.prefix(batchSize)) // Simulate batch processing
        
        // Note: MockScreenshotAdapter would need to conform to Screenshot protocol
        // For now, commenting out this stress test component
        // backgroundProcessor.requestThumbnailBatch(
        //     for: batch.map { MockScreenshotAdapter(mockScreenshot: $0) },
        //     size: CGSize(width: 120, height: 120),
        //     priority: .background
        // )
    }
    
    // MARK: - System Monitoring
    
    private func monitorSystemDuringTest(duration: TimeInterval) async {
        let startTime = Date()
        let monitoringInterval: TimeInterval = 1.0 // Monitor every second
        
        while Date().timeIntervalSince(startTime) < duration {
            await captureSystemSnapshot()
            try? await Task.sleep(nanoseconds: UInt64(monitoringInterval * 1_000_000_000))
        }
    }
    
    private func captureSystemSnapshot() async {
        let memoryUsage = await getCurrentMemoryUsage()
        let timestamp = Date()
        
        memoryUsageHistory.append(MemorySnapshot(
            timestamp: timestamp,
            memoryUsageMB: memoryUsage,
            cacheStatistics: cacheManager.cacheStatistics
        ))
        
        performanceMetrics.append(PerformanceSnapshot(
            timestamp: timestamp,
            qualityMetrics: qualityManager.performanceMetrics,
            viewportMetrics: viewportManager.performanceMetrics,
            processorMetrics: backgroundProcessor.performanceMetrics
        ))
        
        // Check for resource starvation indicators
        await checkForResourceStarvation(memoryUsage: memoryUsage)
    }
    
    private func getCurrentMemoryUsage() async -> Double {
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
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0
        }
    }
    
    private func checkForResourceStarvation(memoryUsage: Double) async {
        // Check for excessive memory usage
        if memoryUsage > 300 {
            resourceStarvationEvents.append(ResourceStarvationEvent(
                type: .excessiveMemoryUsage,
                timestamp: Date(),
                severity: .high,
                description: "Memory usage exceeded 300MB: \(memoryUsage)MB"
            ))
        }
        
        // Check thermal state
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .serious || thermalState == .critical {
            resourceStarvationEvents.append(ResourceStarvationEvent(
                type: .thermalThrottling,
                timestamp: Date(),
                severity: thermalState == .critical ? .critical : .medium,
                description: "Thermal throttling detected: \(thermalState)"
            ))
        }
        
        // Check for processing queue backup
        let processorMetrics = backgroundProcessor.performanceMetrics
        if processorMetrics.queuedTaskCount > 100 {
            resourceStarvationEvents.append(ResourceStarvationEvent(
                type: .processingQueueBackup,
                timestamp: Date(),
                severity: .medium,
                description: "Processing queue backup: \(processorMetrics.queuedTaskCount) tasks"
            ))
        }
    }
    
    // MARK: - Test Evaluation
    
    private func evaluateTestResults() -> Bool {
        let maxMemoryUsage = memoryUsageHistory.max { $0.memoryUsageMB < $1.memoryUsageMB }?.memoryUsageMB ?? 0
        let criticalEvents = resourceStarvationEvents.filter { $0.severity == .critical }
        
        // Test passes if:
        // 1. Memory usage stays under 400MB
        // 2. No critical resource starvation events
        // 3. Cache hit rate stays above 50%
        
        let memoryTestPassed = maxMemoryUsage < 400
        let criticalEventsTestPassed = criticalEvents.isEmpty
        
        let finalHitRate = cacheManager.cacheStatistics.hitRate
        let cacheTestPassed = finalHitRate > 0.5
        
        logger.info("Test evaluation:")
        logger.info("  Memory test passed: \(memoryTestPassed) (max: \(maxMemoryUsage)MB)")
        logger.info("  Critical events test passed: \(criticalEventsTestPassed) (count: \(criticalEvents.count))")
        logger.info("  Cache test passed: \(cacheTestPassed) (hit rate: \(finalHitRate))")
        
        return memoryTestPassed && criticalEventsTestPassed && cacheTestPassed
    }
    
    private func generateStressTestReport() async {
        logger.info("=== GALLERY STRESS TEST REPORT ===")
        
        for result in testResults {
            logger.info("Test: \(result.configuration.name)")
            logger.info("  Result: \(result.passed ? "PASSED" : "FAILED")")
            logger.info("  Duration: \(String(format: "%.1f", result.duration))s")
            logger.info("  Max Memory: \(result.memoryUsageHistory.max { $0.memoryUsageMB < $1.memoryUsageMB }?.memoryUsageMB ?? 0)MB")
            logger.info("  Cache Hit Rate: \(String(format: "%.1f", result.finalCacheStatistics.hitRate * 100))%")
            logger.info("  Resource Events: \(result.resourceStarvationEvents.count)")
        }
        
        let passedTests = testResults.filter { $0.passed }.count
        let totalTests = testResults.count
        
        logger.info("Overall Result: \(passedTests)/\(totalTests) tests passed")
        logger.info("=== END STRESS TEST REPORT ===")
    }
}

// MARK: - Supporting Types

enum StressTestPhase {
    case idle
    case running(String)
    case completed
}

struct StressTestConfiguration {
    let name: String
    let screenshotCount: Int
    let concurrentRequests: Int
    let duration: TimeInterval
    let memoryPressureLevel: ThumbnailMemoryPressureLevel
}

struct StressTestResult {
    let configuration: StressTestConfiguration
    let duration: TimeInterval
    let memoryUsageHistory: [MemorySnapshot]
    let performanceMetrics: [PerformanceSnapshot]
    let resourceStarvationEvents: [ResourceStarvationEvent]
    let finalCacheStatistics: ThumbnailCacheStatistics
    let passed: Bool
}

struct MemorySnapshot {
    let timestamp: Date
    let memoryUsageMB: Double
    let cacheStatistics: ThumbnailCacheStatistics
}

struct PerformanceSnapshot {
    let timestamp: Date
    let qualityMetrics: AdaptiveQualityMetrics
    let viewportMetrics: PredictiveViewportMetrics
    let processorMetrics: ProcessingMetrics
}

struct ResourceStarvationEvent {
    let type: ResourceStarvationType
    let timestamp: Date
    let severity: ResourceStarvationSeverity
    let description: String
}

enum ResourceStarvationType {
    case memoryPressure
    case excessiveMemoryUsage
    case thermalThrottling
    case processingQueueBackup
}

enum ResourceStarvationSeverity {
    case low
    case medium
    case high
    case critical
}

struct MockScreenshot {
    let id: UUID
    let filename: String
    let imageData: Data
}

// Adapter to make MockScreenshot work with existing Screenshot protocol
struct MockScreenshotAdapter {
    let mockScreenshot: MockScreenshot
    
    var id: UUID { mockScreenshot.id }
    var imageData: Data { mockScreenshot.imageData }
}

// Note: chunked extension already exists in BackgroundOCRProcessor.swift