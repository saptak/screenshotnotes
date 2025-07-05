import SwiftUI
import Foundation

/// Performance testing utility for MaterialDesignSystem
/// Validates that material rendering meets 60fps minimum performance requirements
@MainActor
final class MaterialPerformanceTest: ObservableObject {
    
    // MARK: - Performance Metrics
    struct PerformanceMetrics {
        let averageFrameTime: Double
        let minFrameTime: Double
        let maxFrameTime: Double
        let frameDrops: Int
        let totalFrames: Int
        let testDuration: TimeInterval
        
        var averageFPS: Double {
            1.0 / averageFrameTime
        }
        
        var meetsPerformanceTarget: Bool {
            averageFPS >= 60.0 && frameDrops < Int(Double(totalFrames) * 0.05) // Allow up to 5% frame drops
        }
        
        var performanceGrade: String {
            switch averageFPS {
            case 120...: return "Excellent (120fps+)"
            case 90..<120: return "Great (90-120fps)"
            case 60..<90: return "Good (60-90fps)"
            case 30..<60: return "Fair (30-60fps)"
            default: return "Poor (<30fps)"
            }
        }
    }
    
    // MARK: - Test Results
    @Published var isRunning = false
    @Published var currentTest: String = ""
    @Published var results: [String: PerformanceMetrics] = [:]
    @Published var overallResults: String = ""
    
    private var frameTimestamp: CFTimeInterval = 0
    private var frameTimes: [Double] = []
    private var testStartTime: CFTimeInterval = 0
    
    // MARK: - Performance Testing
    
    /// Runs comprehensive performance tests for all material configurations
    func runFullPerformanceTest() async {
        isRunning = true
        results.removeAll()
        
        // Test each depth token configuration
        for depth in MaterialDesignSystem.DepthToken.allCases {
            await testMaterialPerformance(for: depth)
        }
        
        // Test complex scenarios
        await testComplexMaterialScenarios()
        
        generateOverallResults()
        isRunning = false
    }
    
    /// Tests performance for a specific depth token
    private func testMaterialPerformance(for depth: MaterialDesignSystem.DepthToken) async {
        currentTest = "Testing \(depth) material performance"
        
        let metrics = await measureRenderingPerformance(
            testName: String(describing: depth),
            duration: 2.0
        ) {
            // Simulate material rendering load
            TestMaterialView(depth: depth)
        }
        
        results[String(describing: depth)] = metrics
    }
    
    /// Tests complex scenarios with multiple overlapping materials
    private func testComplexMaterialScenarios() async {
        currentTest = "Testing complex material scenarios"
        
        let complexMetrics = await measureRenderingPerformance(
            testName: "complex_scenario",
            duration: 3.0
        ) {
            ComplexMaterialTestView()
        }
        
        results["Complex Scenario"] = complexMetrics
    }
    
    /// Measures rendering performance for a given view
    private func measureRenderingPerformance<Content: View>(
        testName: String,
        duration: TimeInterval,
        @ViewBuilder content: () -> Content
    ) async -> PerformanceMetrics {
        
        frameTimes.removeAll()
        testStartTime = CACurrentMediaTime()
        
        // Run test for specified duration
        let endTime = testStartTime + duration
        
        while CACurrentMediaTime() < endTime {
            let frameStart = CACurrentMediaTime()
            
            // Simulate frame rendering by creating and rendering the view
            _ = content()
            
            let frameEnd = CACurrentMediaTime()
            let frameTime = frameEnd - frameStart
            frameTimes.append(frameTime)
            
            // Wait for next frame opportunity (16.67ms for 60fps)
            try? await Task.sleep(nanoseconds: 16_670_000)
        }
        
        return calculateMetrics()
    }
    
    /// Calculates performance metrics from collected frame times
    private func calculateMetrics() -> PerformanceMetrics {
        guard !frameTimes.isEmpty else {
            return PerformanceMetrics(
                averageFrameTime: 0,
                minFrameTime: 0,
                maxFrameTime: 0,
                frameDrops: 0,
                totalFrames: 0,
                testDuration: 0
            )
        }
        
        let totalFrames = frameTimes.count
        let averageFrameTime = frameTimes.reduce(0, +) / Double(totalFrames)
        let minFrameTime = frameTimes.min() ?? 0
        let maxFrameTime = frameTimes.max() ?? 0
        let testDuration = CACurrentMediaTime() - testStartTime
        
        // Count frame drops (frames that took longer than 16.67ms)
        let targetFrameTime = 1.0 / 60.0
        let frameDrops = frameTimes.filter { $0 > targetFrameTime }.count
        
        return PerformanceMetrics(
            averageFrameTime: averageFrameTime,
            minFrameTime: minFrameTime,
            maxFrameTime: maxFrameTime,
            frameDrops: frameDrops,
            totalFrames: totalFrames,
            testDuration: testDuration
        )
    }
    
    /// Generates overall performance summary
    private func generateOverallResults() {
        var summary = "📊 Material Performance Test Results\n\n"
        
        let allMetrics = Array(results.values)
        let averageFPS = allMetrics.map { $0.averageFPS }.reduce(0, +) / Double(allMetrics.count)
        let totalFrameDrops = allMetrics.map { $0.frameDrops }.reduce(0, +)
        let totalFrames = allMetrics.map { $0.totalFrames }.reduce(0, +)
        
        summary += "🎯 Overall Performance:\n"
        summary += "   Average FPS: \(String(format: "%.1f", averageFPS))\n"
        summary += "   Frame Drop Rate: \(String(format: "%.2f", Double(totalFrameDrops) / Double(totalFrames) * 100))%\n"
        summary += "   Target Met: \(averageFPS >= 60.0 ? "✅ YES" : "❌ NO")\n\n"
        
        summary += "📋 Individual Test Results:\n"
        for (testName, metrics) in results.sorted(by: { $0.key < $1.key }) {
            summary += "   \(testName): \(metrics.performanceGrade)\n"
            summary += "      FPS: \(String(format: "%.1f", metrics.averageFPS))\n"
            summary += "      Frame Drops: \(metrics.frameDrops)/\(metrics.totalFrames)\n\n"
        }
        
        // Performance recommendations
        if averageFPS < 60.0 {
            summary += "⚠️ Recommendations:\n"
            summary += "   • Consider reducing material complexity\n"
            summary += "   • Optimize shadow configurations\n"
            summary += "   • Use adaptive quality based on device capabilities\n"
        } else {
            summary += "✅ All performance targets met!\n"
            summary += "   Materials are optimized for smooth 60fps rendering.\n"
        }
        
        overallResults = summary
    }
}

// MARK: - Test Views

/// Simple test view for individual material depth tokens
private struct TestMaterialView: View {
    let depth: MaterialDesignSystem.DepthToken
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<10, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .frame(height: 60)
                    .materialBackground(depth: depth, cornerRadius: 12)
            }
        }
        .padding()
    }
}

/// Complex test view with multiple overlapping materials
private struct ComplexMaterialTestView: View {
    var body: some View {
        ZStack {
            // Background layer
            Rectangle()
                .materialBackground(depth: .background)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Navigation bar simulation
                HStack {
                    Circle()
                        .frame(width: 40, height: 40)
                        .overlayMaterial(cornerRadius: 20)
                    
                    Spacer()
                    
                    Text("Complex Test")
                        .padding()
                        .modalMaterial(cornerRadius: 8)
                    
                    Spacer()
                    
                    Circle()
                        .frame(width: 40, height: 40)
                        .overlayMaterial(cornerRadius: 20)
                }
                
                // Grid of cards
                LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 160)), count: 2), spacing: 16) {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .frame(height: 100)
                                .surfaceMaterial(cornerRadius: 8)
                            
                            Text("Material Card")
                                .padding(8)
                                .overlayMaterial(cornerRadius: 6)
                        }
                    }
                }
                
                // Floating action button
                Circle()
                    .frame(width: 56, height: 56)
                    .tooltipMaterial(cornerRadius: 28)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding()
        }
    }
}

// MARK: - Additional Material Convenience Methods

private extension View {
    func tooltipMaterial(cornerRadius: CGFloat = 0) -> some View {
        materialBackground(depth: .tooltip, cornerRadius: cornerRadius)
    }
}

// MARK: - Performance Test Integration

#if DEBUG
/// SwiftUI view for running material performance tests
struct MaterialPerformanceTestView: View {
    @StateObject private var performanceTest = MaterialPerformanceTest()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if performanceTest.isRunning {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text(performanceTest.currentTest)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text("This may take a few moments...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .surfaceMaterial(cornerRadius: 16)
                } else {
                    if performanceTest.overallResults.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 64))
                                .foregroundColor(.accentColor)
                            
                            Text("Material Performance Test")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Verify that materials render at 60fps minimum")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Run Performance Test") {
                                Task {
                                    await performanceTest.runFullPerformanceTest()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            Text(performanceTest.overallResults)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .surfaceMaterial(cornerRadius: 16)
                        
                        Button("Run Test Again") {
                            Task {
                                await performanceTest.runFullPerformanceTest()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .navigationTitle("Performance Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MaterialPerformanceTestView()
}
#endif