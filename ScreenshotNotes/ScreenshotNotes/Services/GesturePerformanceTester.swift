import SwiftUI
import Combine

/// Gesture performance testing framework for validating gesture responsiveness and accuracy
/// Provides comprehensive metrics and benchmarking capabilities
@MainActor
final class GesturePerformanceTester: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isTestingActive: Bool = false
    @Published private(set) var testResults: TestResults = TestResults()
    @Published private(set) var currentTestPhase: TestPhase = .idle
    
    // MARK: - Test Configuration
    struct TestConfiguration {
        let testDuration: TimeInterval
        let targetFrameRate: Double
        let gestureTypes: [GestureType]
        let hapticIntensity: Double
        let performanceThresholds: PerformanceThresholds
        
        static let `default` = TestConfiguration(
            testDuration: 5.0,
            targetFrameRate: 120.0,
            gestureTypes: [.tap, .longPress, .swipe, .pinch, .rotation],
            hapticIntensity: 0.8,
            performanceThresholds: .default
        )
    }
    
    // MARK: - Test Results
    struct TestResults {
        var gestureLatencies: [GestureType: [TimeInterval]] = [:]
        var frameRates: [Double] = []
        var memoryUsage: [Double] = []
        var hapticLatencies: [TimeInterval] = []
        var gestureAccuracy: [GestureType: Double] = [:]
        var overallScore: Double = 0.0
        var testDuration: TimeInterval = 0.0
        var timestamp: Date = Date()
        
        var averageLatency: TimeInterval {
            let allLatencies = gestureLatencies.values.flatMap { $0 }
            return allLatencies.isEmpty ? 0 : allLatencies.reduce(0, +) / Double(allLatencies.count)
        }
        
        var averageFrameRate: Double {
            frameRates.isEmpty ? 0 : frameRates.reduce(0, +) / Double(frameRates.count)
        }
        
        var peakMemoryUsage: Double {
            memoryUsage.max() ?? 0
        }
        
        var averageHapticLatency: TimeInterval {
            hapticLatencies.isEmpty ? 0 : hapticLatencies.reduce(0, +) / Double(hapticLatencies.count)
        }
    }
    
    // MARK: - Performance Thresholds
    struct PerformanceThresholds {
        let maxGestureLatency: TimeInterval
        let minFrameRate: Double
        let maxMemoryUsage: Double
        let maxHapticLatency: TimeInterval
        let minGestureAccuracy: Double
        
        static let `default` = PerformanceThresholds(
            maxGestureLatency: 0.050, // 50ms
            minFrameRate: 60.0,
            maxMemoryUsage: 150.0, // MB
            maxHapticLatency: 0.100, // 100ms
            minGestureAccuracy: 0.95
        )
    }
    
    // MARK: - Test Phase
    enum TestPhase: Equatable {
        case idle
        case preparing
        case warmup
        case testing
        case analyzing
        case completed
        case failed(Error)
        
        static func == (lhs: TestPhase, rhs: TestPhase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.preparing, .preparing), (.warmup, .warmup),
                 (.testing, .testing), (.analyzing, .analyzing), (.completed, .completed):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    
    // MARK: - Gesture Type
    enum GestureType: String, CaseIterable {
        case tap = "Tap"
        case longPress = "Long Press"
        case swipe = "Swipe"
        case pinch = "Pinch"
        case rotation = "Rotation"
        case drag = "Drag"
        case multiTouch = "Multi-Touch"
    }
    
    // MARK: - Test Metrics
    private struct TestMetrics {
        var gestureStartTime: Date?
        var frameTimestamps: [Date] = []
        var memoryReadings: [Double] = []
        var hapticTriggerTimes: [Date] = []
        var gestureCompletionTimes: [Date] = []
        var testStartTime: Date?
    }
    
    // MARK: - Private Properties
    private let configuration: TestConfiguration
    private var metrics = TestMetrics()
    private var testTimer: Timer?
    private var frameTimer: Timer?
    private var memoryTimer: Timer?
    private var testStartTime: Date?
    
    // MARK: - Initialization
    init(configuration: TestConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Starts a comprehensive gesture performance test
    /// - Parameter customConfiguration: Optional custom test configuration
    func startPerformanceTest(customConfiguration: TestConfiguration? = nil) {
        guard !isTestingActive else { return }
        
        let config = customConfiguration ?? configuration
        
        isTestingActive = true
        currentTestPhase = .preparing
        testResults = TestResults()
        resetMetrics()
        
        // Start test sequence
        Task {
            await runTestSequence(config: config)
        }
    }
    
    /// Stops the current performance test
    func stopPerformanceTest() {
        isTestingActive = false
        currentTestPhase = .idle
        cleanupTimers()
    }
    
    /// Records a gesture event for performance analysis
    /// - Parameters:
    ///   - gestureType: The type of gesture
    ///   - startTime: When the gesture started
    ///   - endTime: When the gesture completed
    ///   - accuracy: Accuracy score (0.0 to 1.0)
    func recordGestureEvent(
        gestureType: GestureType,
        startTime: Date,
        endTime: Date,
        accuracy: Double = 1.0
    ) {
        guard isTestingActive else { return }
        
        let latency = endTime.timeIntervalSince(startTime)
        
        if testResults.gestureLatencies[gestureType] == nil {
            testResults.gestureLatencies[gestureType] = []
        }
        testResults.gestureLatencies[gestureType]?.append(latency)
        testResults.gestureAccuracy[gestureType] = accuracy
    }
    
    /// Records a haptic feedback event
    /// - Parameters:
    ///   - triggerTime: When haptic was triggered
    ///   - completionTime: When haptic completed
    func recordHapticEvent(triggerTime: Date, completionTime: Date) {
        guard isTestingActive else { return }
        
        let latency = completionTime.timeIntervalSince(triggerTime)
        testResults.hapticLatencies.append(latency)
    }
    
    /// Generates a detailed performance report
    /// - Returns: Formatted performance report
    func generatePerformanceReport() -> String {
        var report = "=== Gesture Performance Test Report ===\n\n"
        
        report += "Test Duration: \(String(format: "%.2f", testResults.testDuration)) seconds\n"
        report += "Test Date: \(testResults.timestamp.formatted())\n\n"
        
        // Gesture Latency Results
        report += "Gesture Latency Results:\n"
        for (gestureType, latencies) in testResults.gestureLatencies {
            let avgLatency = latencies.reduce(0, +) / Double(latencies.count)
            let maxLatency = latencies.max() ?? 0
            let minLatency = latencies.min() ?? 0
            
            report += "  \(gestureType.rawValue):\n"
            report += "    Average: \(String(format: "%.3f", avgLatency * 1000))ms\n"
            report += "    Range: \(String(format: "%.3f", minLatency * 1000))ms - \(String(format: "%.3f", maxLatency * 1000))ms\n"
            report += "    Samples: \(latencies.count)\n"
        }
        
        // Frame Rate Results
        report += "\nFrame Rate Results:\n"
        report += "  Average: \(String(format: "%.1f", testResults.averageFrameRate)) FPS\n"
        report += "  Target: \(String(format: "%.1f", configuration.targetFrameRate)) FPS\n"
        report += "  Performance: \(testResults.averageFrameRate >= configuration.targetFrameRate ? "✅ PASS" : "❌ FAIL")\n"
        
        // Memory Usage Results
        report += "\nMemory Usage Results:\n"
        report += "  Peak Usage: \(String(format: "%.1f", testResults.peakMemoryUsage)) MB\n"
        report += "  Threshold: \(String(format: "%.1f", configuration.performanceThresholds.maxMemoryUsage)) MB\n"
        report += "  Performance: \(testResults.peakMemoryUsage <= configuration.performanceThresholds.maxMemoryUsage ? "✅ PASS" : "❌ FAIL")\n"
        
        // Haptic Feedback Results
        report += "\nHaptic Feedback Results:\n"
        report += "  Average Latency: \(String(format: "%.3f", testResults.averageHapticLatency * 1000))ms\n"
        report += "  Threshold: \(String(format: "%.3f", configuration.performanceThresholds.maxHapticLatency * 1000))ms\n"
        report += "  Performance: \(testResults.averageHapticLatency <= configuration.performanceThresholds.maxHapticLatency ? "✅ PASS" : "❌ FAIL")\n"
        
        // Overall Score
        report += "\nOverall Performance Score: \(String(format: "%.1f", testResults.overallScore * 100))%\n"
        
        return report
    }
    
    /// Exports test results to a structured format
    /// - Returns: Dictionary containing all test results
    func exportTestResults() -> [String: Any] {
        return [
            "timestamp": testResults.timestamp.timeIntervalSince1970,
            "testDuration": testResults.testDuration,
            "gestureLatencies": testResults.gestureLatencies.mapValues { latencies in
                [
                    "average": latencies.reduce(0, +) / Double(latencies.count),
                    "min": latencies.min() ?? 0,
                    "max": latencies.max() ?? 0,
                    "count": latencies.count
                ]
            },
            "frameRate": [
                "average": testResults.averageFrameRate,
                "target": configuration.targetFrameRate,
                "samples": testResults.frameRates.count
            ],
            "memoryUsage": [
                "peak": testResults.peakMemoryUsage,
                "threshold": configuration.performanceThresholds.maxMemoryUsage
            ],
            "hapticLatency": [
                "average": testResults.averageHapticLatency,
                "threshold": configuration.performanceThresholds.maxHapticLatency,
                "samples": testResults.hapticLatencies.count
            ],
            "overallScore": testResults.overallScore
        ]
    }
    
    // MARK: - Private Methods
    
    private func runTestSequence(config: TestConfiguration) async {
        testStartTime = Date()
        
        // Phase 1: Warmup
        currentTestPhase = .warmup
        await warmupPhase()
        
        // Phase 2: Testing
        currentTestPhase = .testing
        startMetricsCollection()
        await testingPhase(config: config)
        
        // Phase 3: Analysis
        currentTestPhase = .analyzing
        stopMetricsCollection()
        await analysisPhase()
        
        // Phase 4: Completion
        currentTestPhase = .completed
        isTestingActive = false
    }
    
    private func warmupPhase() async {
        // Allow UI to settle and prepare for testing
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    private func testingPhase(config: TestConfiguration) async {
        // Run test for specified duration
        try? await Task.sleep(nanoseconds: UInt64(config.testDuration * 1_000_000_000))
    }
    
    private func analysisPhase() async {
        // Calculate overall performance score
        let latencyScore = calculateLatencyScore()
        let frameRateScore = calculateFrameRateScore()
        let memoryScore = calculateMemoryScore()
        let hapticScore = calculateHapticScore()
        
        testResults.overallScore = (latencyScore + frameRateScore + memoryScore + hapticScore) / 4.0
        
        if let startTime = testStartTime {
            testResults.testDuration = Date().timeIntervalSince(startTime)
        }
    }
    
    private func startMetricsCollection() {
        // Start frame rate monitoring
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / configuration.targetFrameRate, repeats: true) { _ in
            self.metrics.frameTimestamps.append(Date())
        }
        
        // Start memory monitoring
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let memoryUsage = self.getCurrentMemoryUsage()
            self.metrics.memoryReadings.append(memoryUsage)
            self.testResults.memoryUsage.append(memoryUsage)
        }
    }
    
    private func stopMetricsCollection() {
        frameTimer?.invalidate()
        memoryTimer?.invalidate()
        
        // Calculate frame rates
        if metrics.frameTimestamps.count > 1 {
            for i in 1..<metrics.frameTimestamps.count {
                let interval = metrics.frameTimestamps[i].timeIntervalSince(metrics.frameTimestamps[i-1])
                let fps = 1.0 / interval
                testResults.frameRates.append(fps)
            }
        }
    }
    
    private func calculateLatencyScore() -> Double {
        let avgLatency = testResults.averageLatency
        let threshold = configuration.performanceThresholds.maxGestureLatency
        
        if avgLatency <= threshold {
            return 1.0
        } else {
            return max(0.0, 1.0 - (avgLatency - threshold) / threshold)
        }
    }
    
    private func calculateFrameRateScore() -> Double {
        let avgFrameRate = testResults.averageFrameRate
        let threshold = configuration.performanceThresholds.minFrameRate
        
        if avgFrameRate >= threshold {
            return 1.0
        } else {
            return max(0.0, avgFrameRate / threshold)
        }
    }
    
    private func calculateMemoryScore() -> Double {
        let peakMemory = testResults.peakMemoryUsage
        let threshold = configuration.performanceThresholds.maxMemoryUsage
        
        if peakMemory <= threshold {
            return 1.0
        } else {
            return max(0.0, 1.0 - (peakMemory - threshold) / threshold)
        }
    }
    
    private func calculateHapticScore() -> Double {
        let avgLatency = testResults.averageHapticLatency
        let threshold = configuration.performanceThresholds.maxHapticLatency
        
        if avgLatency <= threshold {
            return 1.0
        } else {
            return max(0.0, 1.0 - (avgLatency - threshold) / threshold)
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024 / 1024 // Convert to MB
        }
        return 0.0
    }
    
    private func resetMetrics() {
        metrics = TestMetrics()
    }
    
    private func cleanupTimers() {
        testTimer?.invalidate()
        frameTimer?.invalidate()
        memoryTimer?.invalidate()
    }
}

// MARK: - SwiftUI Integration

/// Performance testing view for gesture validation
struct GesturePerformanceTestView: View {
    @StateObject private var tester = GesturePerformanceTester()
    @State private var showingResults = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Test Status
            VStack(spacing: 8) {
                Text("Gesture Performance Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(tester.currentTestPhase.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if tester.isTestingActive {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Test Controls
            HStack(spacing: 16) {
                Button(action: {
                    tester.startPerformanceTest()
                }) {
                    Text("Start Test")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(tester.isTestingActive)
                
                Button(action: {
                    tester.stopPerformanceTest()
                }) {
                    Text("Stop Test")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .disabled(!tester.isTestingActive)
            }
            
            // Results Button
            if tester.currentTestPhase == .completed {
                Button(action: {
                    showingResults = true
                }) {
                    Text("View Results")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingResults) {
            GesturePerformanceResultsView(tester: tester)
        }
    }
}

// MARK: - Performance Results View
private struct GesturePerformanceResultsView: View {
    let tester: GesturePerformanceTester
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(tester.generatePerformanceReport())
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            }
            .navigationTitle("Test Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions
extension GesturePerformanceTester.TestPhase {
    var description: String {
        switch self {
        case .idle:
            return "Ready to test"
        case .preparing:
            return "Preparing test environment..."
        case .warmup:
            return "Warming up..."
        case .testing:
            return "Testing gesture performance..."
        case .analyzing:
            return "Analyzing results..."
        case .completed:
            return "Test completed"
        case .failed(let error):
            return "Test failed: \(error.localizedDescription)"
        }
    }
}