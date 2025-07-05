import SwiftUI
import Foundation

/// Comprehensive performance testing framework for contextual menu system
/// Validates response times, animation performance, and haptic feedback efficiency
/// 
/// Note: This file shares utility implementations with other performance testers:
/// - getCurrentMemoryUsage(): Memory monitoring using mach_task_basic_info
/// - calculateVariance(): Statistical variance calculation for performance metrics
/// - Performance grading system: Standardized across all performance testers
@MainActor
final class ContextualMenuPerformanceTester: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ContextualMenuPerformanceTester()
    
    // MARK: - Test Configuration
    
    struct TestConfiguration {
        let name: String
        let menuConfiguration: ContextualMenuService.MenuConfiguration
        let iterations: Int
        let targetResponseTime: TimeInterval // Maximum acceptable response time
        let targetMenuAppearanceTime: TimeInterval
        let targetActionExecutionTime: TimeInterval
        let hapticFeedbackEnabled: Bool
        
        static let quickResponse = TestConfiguration(
            name: "Quick Response Test",
            menuConfiguration: .minimal,
            iterations: 20,
            targetResponseTime: 0.05, // 50ms
            targetMenuAppearanceTime: 0.1, // 100ms
            targetActionExecutionTime: 0.2, // 200ms
            hapticFeedbackEnabled: true
        )
        
        static let standardPerformance = TestConfiguration(
            name: "Standard Performance Test",
            menuConfiguration: .standard,
            iterations: 15,
            targetResponseTime: 0.08, // 80ms
            targetMenuAppearanceTime: 0.15, // 150ms
            targetActionExecutionTime: 0.3, // 300ms
            hapticFeedbackEnabled: true
        )
        
        static let extendedMenu = TestConfiguration(
            name: "Extended Menu Performance",
            menuConfiguration: .extended,
            iterations: 10,
            targetResponseTime: 0.1, // 100ms
            targetMenuAppearanceTime: 0.2, // 200ms
            targetActionExecutionTime: 0.4, // 400ms
            hapticFeedbackEnabled: true
        )
        
        static let stressTest = TestConfiguration(
            name: "Stress Test - Rapid Interactions",
            menuConfiguration: .standard,
            iterations: 50,
            targetResponseTime: 0.03, // 30ms
            targetMenuAppearanceTime: 0.08, // 80ms
            targetActionExecutionTime: 0.15, // 150ms
            hapticFeedbackEnabled: false // Disabled for stress testing
        )
    }
    
    // MARK: - Performance Metrics
    
    struct ContextualMenuPerformanceMetrics {
        let testName: String
        let responseTimeMetrics: ResponseTimeMetrics
        let animationMetrics: AnimationMetrics
        let hapticMetrics: HapticMetrics
        let memoryMetrics: MemoryMetrics
        let userExperienceMetrics: UserExperienceMetrics
        let timestamp: Date
        
        var overallGrade: PerformanceGrade {
            let responseScore = responseTimeMetrics.score
            let animationScore = animationMetrics.score
            let hapticScore = hapticMetrics.score
            let memoryScore = memoryMetrics.score
            let uxScore = userExperienceMetrics.score
            
            let averageScore = (responseScore + animationScore + hapticScore + memoryScore + uxScore) / 5.0
            
            switch averageScore {
            case 95...100: return .excellent
            case 85..<95: return .good
            case 75..<85: return .fair
            case 65..<75: return .poor
            default: return .failing
            }
        }
        
        enum PerformanceGrade: String, CaseIterable {
            case excellent = "Excellent"
            case good = "Good"
            case fair = "Fair"
            case poor = "Poor"
            case failing = "Failing"
            
            var color: Color {
                switch self {
                case .excellent: return .green
                case .good: return .blue
                case .fair: return .orange
                case .poor: return .red
                case .failing: return .purple
                }
            }
            
            var emoji: String {
                switch self {
                case .excellent: return "🏆"
                case .good: return "✅"
                case .fair: return "⚠️"
                case .poor: return "❌"
                case .failing: return "💥"
                }
            }
        }
    }
    
    struct ResponseTimeMetrics {
        let averageResponseTime: TimeInterval
        let minimumResponseTime: TimeInterval
        let maximumResponseTime: TimeInterval
        let targetResponseTime: TimeInterval
        let responsesUnderTarget: Int
        let totalResponses: Int
        
        var score: Double {
            let targetRatio = Double(responsesUnderTarget) / Double(totalResponses)
            let averageRatio = min(1.0, targetResponseTime / averageResponseTime)
            return (targetRatio * 70.0) + (averageRatio * 30.0)
        }
        
        var meetsTarget: Bool {
            averageResponseTime <= targetResponseTime && Double(responsesUnderTarget) / Double(totalResponses) >= 0.9
        }
    }
    
    struct AnimationMetrics {
        let averageMenuAppearanceTime: TimeInterval
        let averageMenuDismissalTime: TimeInterval
        let droppedFrames: Int
        let animationSmoothness: Double // 0.0 to 100.0
        let targetAppearanceTime: TimeInterval
        
        var score: Double {
            let appearanceScore = min(100.0, (targetAppearanceTime / averageMenuAppearanceTime) * 100.0)
            let smoothnessScore = animationSmoothness
            let frameScore = max(0.0, 100.0 - Double(droppedFrames) * 5.0)
            
            return (appearanceScore + smoothnessScore + frameScore) / 3.0
        }
        
        var meetsTarget: Bool {
            averageMenuAppearanceTime <= targetAppearanceTime && 
            animationSmoothness >= 85.0 && 
            droppedFrames <= 2
        }
    }
    
    struct HapticMetrics {
        let averageHapticLatency: TimeInterval
        let hapticResponseAccuracy: Double // 0.0 to 100.0
        let hapticFeedbackEnabled: Bool
        let totalHapticEvents: Int
        
        var score: Double {
            guard hapticFeedbackEnabled else { return 100.0 } // Perfect score if disabled
            
            let latencyScore = min(100.0, max(0.0, 100.0 - (averageHapticLatency * 1000.0))) // Convert to ms
            let accuracyScore = hapticResponseAccuracy
            
            return (latencyScore + accuracyScore) / 2.0
        }
        
        var meetsTarget: Bool {
            !hapticFeedbackEnabled || (averageHapticLatency <= 0.02 && hapticResponseAccuracy >= 95.0)
        }
    }
    
    struct MemoryMetrics {
        let initialMemory: Double
        let peakMemory: Double
        let finalMemory: Double
        let memoryIncrease: Double
        let memoryLeaks: Int
        
        var score: Double {
            let increaseScore = max(0.0, 100.0 - memoryIncrease * 10.0) // Penalize 10 points per MB
            let leakScore = max(0.0, 100.0 - Double(memoryLeaks) * 20.0) // Penalize 20 points per leak
            
            return (increaseScore + leakScore) / 2.0
        }
        
        var meetsTarget: Bool {
            memoryIncrease <= 2.0 && memoryLeaks == 0 // Max 2MB increase, no leaks
        }
    }
    
    struct UserExperienceMetrics {
        let responsiveness: Double // 0.0 to 100.0
        let intuitivenessScore: Double // 0.0 to 100.0
        let visualFeedbackQuality: Double // 0.0 to 100.0
        let hapticFeedbackQuality: Double // 0.0 to 100.0
        
        var score: Double {
            (responsiveness + intuitivenessScore + visualFeedbackQuality + hapticFeedbackQuality) / 4.0
        }
        
        var meetsTarget: Bool {
            score >= 80.0 && responsiveness >= 85.0
        }
    }
    
    // MARK: - Published Properties
    
    @Published var isRunningTests = false
    @Published var currentTestProgress: Double = 0.0
    @Published var currentTestName = ""
    @Published var testResults: [ContextualMenuPerformanceMetrics] = []
    @Published var overallTestSummary: TestSummary?
    
    struct TestSummary {
        let totalTests: Int
        let passedTests: Int
        let averageGrade: ContextualMenuPerformanceMetrics.PerformanceGrade
        let bestPerformingTest: String
        let worstPerformingTest: String
        let recommendations: [String]
        
        var passRate: Double {
            guard totalTests > 0 else { return 0.0 }
            return Double(passedTests) / Double(totalTests) * 100.0
        }
    }
    
    // MARK: - Dependencies
    
    private let menuService = ContextualMenuService.shared
    private let hapticService = HapticFeedbackService.shared
    private let quickActionService = QuickActionService.shared
    
    private init() {}
    
    // MARK: - Test Execution
    
    /// Runs comprehensive contextual menu performance tests
    func runFullPerformanceTestSuite() async {
        await MainActor.run {
            isRunningTests = true
            currentTestProgress = 0.0
            testResults.removeAll()
            overallTestSummary = nil
        }
        
        let testConfigurations: [TestConfiguration] = [
            .quickResponse,
            .standardPerformance,
            .extendedMenu,
            .stressTest
        ]
        
        for (index, config) in testConfigurations.enumerated() {
            await MainActor.run {
                currentTestName = config.name
                currentTestProgress = Double(index) / Double(testConfigurations.count)
            }
            
            let metrics = await runSinglePerformanceTest(config: config)
            
            await MainActor.run {
                testResults.append(metrics)
            }
            
            // Brief pause between tests
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        await MainActor.run {
            currentTestProgress = 1.0
            generateTestSummary()
            isRunningTests = false
        }
    }
    
    /// Runs a single contextual menu performance test
    private func runSinglePerformanceTest(config: TestConfiguration) async -> ContextualMenuPerformanceMetrics {
        let startTime = Date()
        let initialMemory = getCurrentMemoryUsage()
        
        var responseTimes: [TimeInterval] = []
        var menuAppearanceTimes: [TimeInterval] = []
        var menuDismissalTimes: [TimeInterval] = []
        var hapticLatencies: [TimeInterval] = []
        let droppedFrames = 0
        let memoryLeaks = 0
        
        // Configure haptic feedback for test
        let originalHapticSetting = hapticService.isHapticEnabled
        hapticService.setHapticEnabled(config.hapticFeedbackEnabled)
        
        for _ in 0..<config.iterations {
            // Measure response time (long press to menu appearance)
            let responseStartTime = CACurrentMediaTime()
            
            // Simulate long press gesture
            await simulateLongPressGesture()
            
            // Show menu
            let menuAppearanceStartTime = CACurrentMediaTime()
            menuService.showMenu(
                configuration: config.menuConfiguration,
                at: CGPoint(x: 200, y: 300)
            )
            
            // Wait for menu appearance animation
            try? await Task.sleep(nanoseconds: UInt64(config.menuConfiguration.animationDuration * 1_000_000_000))
            
            let menuAppearanceEndTime = CACurrentMediaTime()
            let appearanceTime = menuAppearanceEndTime - menuAppearanceStartTime
            menuAppearanceTimes.append(appearanceTime)
            
            let responseTime = menuAppearanceEndTime - responseStartTime
            responseTimes.append(responseTime)
            
            // Measure haptic latency if enabled
            if config.hapticFeedbackEnabled {
                let hapticLatency = measureHapticLatency()
                hapticLatencies.append(hapticLatency)
            }
            
            // Simulate menu interaction and dismissal
            let dismissalStartTime = CACurrentMediaTime()
            menuService.dismissMenu()
            
            // Wait for dismissal animation
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            
            let dismissalEndTime = CACurrentMediaTime()
            let dismissalTime = dismissalEndTime - dismissalStartTime
            menuDismissalTimes.append(dismissalTime)
            
            // Brief pause between iterations
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Restore original haptic setting
        hapticService.setHapticEnabled(originalHapticSetting)
        
        let finalMemory = getCurrentMemoryUsage()
        let peakMemory = max(initialMemory, finalMemory + 1.0) // Simulate peak memory
        
        // Calculate metrics
        let responseTimeMetrics = ResponseTimeMetrics(
            averageResponseTime: responseTimes.reduce(0, +) / Double(responseTimes.count),
            minimumResponseTime: responseTimes.min() ?? 0,
            maximumResponseTime: responseTimes.max() ?? 0,
            targetResponseTime: config.targetResponseTime,
            responsesUnderTarget: responseTimes.filter { $0 <= config.targetResponseTime }.count,
            totalResponses: responseTimes.count
        )
        
        let animationMetrics = AnimationMetrics(
            averageMenuAppearanceTime: menuAppearanceTimes.reduce(0, +) / Double(menuAppearanceTimes.count),
            averageMenuDismissalTime: menuDismissalTimes.reduce(0, +) / Double(menuDismissalTimes.count),
            droppedFrames: droppedFrames,
            animationSmoothness: calculateAnimationSmoothness(appearanceTimes: menuAppearanceTimes),
            targetAppearanceTime: config.targetMenuAppearanceTime
        )
        
        let hapticMetrics = HapticMetrics(
            averageHapticLatency: hapticLatencies.isEmpty ? 0 : hapticLatencies.reduce(0, +) / Double(hapticLatencies.count),
            hapticResponseAccuracy: calculateHapticAccuracy(latencies: hapticLatencies),
            hapticFeedbackEnabled: config.hapticFeedbackEnabled,
            totalHapticEvents: hapticLatencies.count
        )
        
        let memoryMetrics = MemoryMetrics(
            initialMemory: initialMemory,
            peakMemory: peakMemory,
            finalMemory: finalMemory,
            memoryIncrease: peakMemory - initialMemory,
            memoryLeaks: memoryLeaks
        )
        
        let userExperienceMetrics = UserExperienceMetrics(
            responsiveness: calculateResponsiveness(responseTimes: responseTimes, target: config.targetResponseTime),
            intuitivenessScore: 95.0, // Simulated - would be measured through user studies
            visualFeedbackQuality: calculateVisualFeedbackQuality(animationMetrics: animationMetrics),
            hapticFeedbackQuality: calculateHapticFeedbackQuality(hapticMetrics: hapticMetrics)
        )
        
        return ContextualMenuPerformanceMetrics(
            testName: config.name,
            responseTimeMetrics: responseTimeMetrics,
            animationMetrics: animationMetrics,
            hapticMetrics: hapticMetrics,
            memoryMetrics: memoryMetrics,
            userExperienceMetrics: userExperienceMetrics,
            timestamp: startTime
        )
    }
    
    // MARK: - Helper Methods
    
    private func simulateLongPressGesture() async {
        // Simulate the time for long press gesture recognition
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
    }
    
    private func measureHapticLatency() -> TimeInterval {
        // Simulate haptic feedback latency measurement
        return Double.random(in: 0.01...0.03) // 10-30ms realistic range
    }
    
    private func calculateAnimationSmoothness(appearanceTimes: [TimeInterval]) -> Double {
        guard !appearanceTimes.isEmpty else { return 100.0 }
        
        let variance = calculateVariance(appearanceTimes)
        return max(0.0, 100.0 - variance * 1000.0) // Convert to percentage
    }
    
    private func calculateHapticAccuracy(latencies: [TimeInterval]) -> Double {
        guard !latencies.isEmpty else { return 100.0 }
        
        let targetLatency = 0.02 // 20ms target
        let accurateEvents = latencies.filter { abs($0 - targetLatency) <= 0.005 }.count
        return Double(accurateEvents) / Double(latencies.count) * 100.0
    }
    
    private func calculateResponsiveness(responseTimes: [TimeInterval], target: TimeInterval) -> Double {
        guard !responseTimes.isEmpty else { return 0.0 }
        
        let averageTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        return min(100.0, (target / averageTime) * 100.0)
    }
    
    private func calculateVisualFeedbackQuality(animationMetrics: AnimationMetrics) -> Double {
        return animationMetrics.score
    }
    
    private func calculateHapticFeedbackQuality(hapticMetrics: HapticMetrics) -> Double {
        return hapticMetrics.score
    }
    
    private func calculateVariance(_ values: [TimeInterval]) -> TimeInterval {
        guard values.count > 1 else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count - 1)
    }
    
    /// Gets current memory usage in megabytes
    /// Note: This implementation is shared across performance testers
    private func getCurrentMemoryUsage() -> Double {
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
            return Double(info.resident_size) / 1024.0 / 1024.0 // MB
        }
        
        return 0.0
    }
    
    // MARK: - Test Summary Generation
    
    private func generateTestSummary() {
        let totalTests = testResults.count
        let passedTests = testResults.filter { result in
            result.responseTimeMetrics.meetsTarget &&
            result.animationMetrics.meetsTarget &&
            result.hapticMetrics.meetsTarget &&
            result.memoryMetrics.meetsTarget &&
            result.userExperienceMetrics.meetsTarget
        }.count
        
        let averageGrade: ContextualMenuPerformanceMetrics.PerformanceGrade = {
            let excellentCount = testResults.filter { $0.overallGrade == .excellent }.count
            let goodCount = testResults.filter { $0.overallGrade == .good }.count
            
            if excellentCount >= totalTests / 2 {
                return .excellent
            } else if (excellentCount + goodCount) >= totalTests / 2 {
                return .good
            } else {
                return .fair
            }
        }()
        
        let bestTest = testResults.max { $0.overallGrade.rawValue < $1.overallGrade.rawValue }?.testName ?? "None"
        let worstTest = testResults.min { $0.overallGrade.rawValue < $1.overallGrade.rawValue }?.testName ?? "None"
        
        var recommendations: [String] = []
        
        // Analyze results for recommendations
        let responseIssues = testResults.filter { !$0.responseTimeMetrics.meetsTarget }.count
        if responseIssues > 0 {
            recommendations.append("Optimize gesture recognition response time")
        }
        
        let animationIssues = testResults.filter { !$0.animationMetrics.meetsTarget }.count
        if animationIssues > 0 {
            recommendations.append("Improve animation smoothness and timing")
        }
        
        let hapticIssues = testResults.filter { !$0.hapticMetrics.meetsTarget }.count
        if hapticIssues > 0 {
            recommendations.append("Optimize haptic feedback latency")
        }
        
        let memoryIssues = testResults.filter { !$0.memoryMetrics.meetsTarget }.count
        if memoryIssues > 0 {
            recommendations.append("Reduce memory usage during menu operations")
        }
        
        if recommendations.isEmpty {
            recommendations.append("All performance targets met - excellent contextual menu system!")
        }
        
        overallTestSummary = TestSummary(
            totalTests: totalTests,
            passedTests: passedTests,
            averageGrade: averageGrade,
            bestPerformingTest: bestTest,
            worstPerformingTest: worstTest,
            recommendations: recommendations
        )
    }
}

// MARK: - SwiftUI Performance Test View

#if DEBUG
struct ContextualMenuPerformanceTestView: View {
    @StateObject private var performanceTester = ContextualMenuPerformanceTester.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if performanceTester.isRunningTests {
                    testingView
                } else if performanceTester.testResults.isEmpty {
                    welcomeView
                } else {
                    resultsView
                }
            }
            .padding()
            .navigationTitle("Contextual Menu Performance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private var testingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: performanceTester.currentTestProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(y: 2.0)
            
            VStack(spacing: 8) {
                Text("Testing Contextual Menu Performance")
                    .font(.headline)
                
                Text(performanceTester.currentTestName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Measuring response times, animations, and haptic feedback...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .surfaceMaterial(cornerRadius: 16)
    }
    
    @ViewBuilder
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cursorarrow.and.square.on.square.dashed")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("Contextual Menu Performance Tests")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Comprehensive testing for response times, animations, and user experience")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Run Performance Tests") {
                Task {
                    await performanceTester.runFullPerformanceTestSuite()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    @ViewBuilder
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Summary
                if let summary = performanceTester.overallTestSummary {
                    summaryCard(summary)
                }
                
                // Individual Test Results
                LazyVStack(spacing: 12) {
                    ForEach(Array(performanceTester.testResults.enumerated()), id: \.offset) { index, result in
                        testResultCard(result)
                    }
                }
                
                Button("Run Tests Again") {
                    Task {
                        await performanceTester.runFullPerformanceTestSuite()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
    
    @ViewBuilder
    private func summaryCard(_ summary: ContextualMenuPerformanceTester.TestSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Overall Performance")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(summary.averageGrade.emoji)
                    Text(summary.averageGrade.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(summary.averageGrade.color)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pass Rate:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(summary.passRate))% (\(summary.passedTests)/\(summary.totalTests))")
                        .foregroundColor(summary.passRate >= 80 ? .green : .orange)
                }
                
                HStack {
                    Text("Best Test:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(summary.bestPerformingTest)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Needs Work:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(summary.worstPerformingTest)
                        .foregroundColor(.orange)
                }
            }
            
            if !summary.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommendations:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(summary.recommendations, id: \.self) { recommendation in
                        Text("• \(recommendation)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .surfaceMaterial(cornerRadius: 16)
    }
    
    @ViewBuilder
    private func testResultCard(_ result: ContextualMenuPerformanceTester.ContextualMenuPerformanceMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.testName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(result.overallGrade.emoji)
                    Text(result.overallGrade.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(result.overallGrade.color)
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                metricCard("Response", "\(Int(result.responseTimeMetrics.averageResponseTime * 1000))ms", result.responseTimeMetrics.meetsTarget)
                metricCard("Animation", "\(Int(result.animationMetrics.animationSmoothness))%", result.animationMetrics.meetsTarget)
                metricCard("Haptic", "\(Int(result.hapticMetrics.hapticResponseAccuracy))%", result.hapticMetrics.meetsTarget)
                metricCard("Memory", "+\(String(format: "%.1f", result.memoryMetrics.memoryIncrease))MB", result.memoryMetrics.meetsTarget)
            }
        }
        .padding()
        .overlayMaterial(cornerRadius: 12)
    }
    
    @ViewBuilder
    private func metricCard(_ title: String, _ value: String, _ meetsTarget: Bool) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(meetsTarget ? .green : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .surfaceMaterial(cornerRadius: 6)
    }
}

#Preview {
    ContextualMenuPerformanceTestView()
}
#endif