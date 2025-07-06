import SwiftUI
import QuartzCore
import os.log

@MainActor
class GlassPerformanceMonitor: ObservableObject {
    static let shared = GlassPerformanceMonitor()
    
    // MARK: - Performance Metrics
    @Published var currentFPS: Double = 0.0
    @Published var averageFPS: Double = 0.0
    @Published var frameDrops: Int = 0
    @Published var memoryUsage: Double = 0.0
    @Published var gpuUsage: Double = 0.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var isProMotionEnabled: Bool = false
    
    // MARK: - Performance Targets
    let targetFPS: Double = 120.0 // ProMotion target
    let minimumFPS: Double = 60.0 // Fallback target
    let maxResponseTime: TimeInterval = 0.008 // 8ms target
    let maxMemoryIncrease: Double = 10.0 // 10MB limit
    
    // MARK: - Internal State
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var frameTimes: [CFTimeInterval] = []
    private var memoryBaseline: Double = 0
    private var isMonitoring = false
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "GlassPerformance")
    
    // MARK: - Performance History
    private struct PerformanceSnapshot {
        let timestamp: Date
        let fps: Double
        let memoryUsage: Double
        let gpuUsage: Double
        let responseTime: TimeInterval
        let glassEffectsActive: Int
    }
    
    private var performanceHistory: [PerformanceSnapshot] = []
    private let maxHistoryCount = 1000
    
    private init() {
        setupThermalStateMonitoring()
        detectProMotionCapability()
        measureMemoryBaseline()
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        logger.info("🚀 Starting Glass Performance Monitoring - Target: \(self.targetFPS)fps")
        
        isMonitoring = true
        setupDisplayLink()
        startMemoryMonitoring()
        
        // Reset metrics
        currentFPS = 0.0
        frameDrops = 0
        frameTimes.removeAll()
        performanceHistory.removeAll()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        logger.info("⏹️ Stopping Glass Performance Monitoring")
        
        isMonitoring = false
        displayLink?.invalidate()
        displayLink = nil
        
        logPerformanceSummary()
    }
    
    // MARK: - Display Link Setup
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        
        if #available(iOS 15.0, *) {
            // Prefer ProMotion if available
            displayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: Float(minimumFPS),
                maximum: Float(targetFPS),
                preferred: Float(targetFPS)
            )
        } else {
            displayLink?.preferredFramesPerSecond = Int(targetFPS)
        }
        
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func displayLinkCallback(displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        
        if lastFrameTimestamp > 0 {
            let deltaTime = currentTime - lastFrameTimestamp
            let instantFPS = 1.0 / deltaTime
            
            // Update current FPS
            currentFPS = instantFPS
            
            // Track frame times for averaging
            frameTimes.append(deltaTime)
            if frameTimes.count > 60 { // Keep last 60 frames (1 second at 60fps)
                frameTimes.removeFirst()
            }
            
            // Calculate average FPS
            if !frameTimes.isEmpty {
                let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
                averageFPS = 1.0 / avgFrameTime
            }
            
            // Track frame drops (frames slower than target)
            let targetFrameTime = 1.0 / targetFPS
            if deltaTime > targetFrameTime * 1.5 { // 50% tolerance
                frameDrops += 1
                logger.warning("⚠️ Frame drop detected: \(deltaTime * 1000)ms (target: \(targetFrameTime * 1000)ms)")
            }
            
            // Update performance snapshot
            updatePerformanceSnapshot()
        }
        
        lastFrameTimestamp = currentTime
    }
    
    // MARK: - Memory Monitoring
    
    private func measureMemoryBaseline() {
        memoryBaseline = getCurrentMemoryUsage()
        logger.info("📊 Memory baseline established: \(self.memoryBaseline)MB")
    }
    
    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard self.isMonitoring else { return }
                self.updateMemoryUsage()
            }
        }
    }
    
    private func updateMemoryUsage() {
        let currentMemory = getCurrentMemoryUsage()
        memoryUsage = currentMemory - memoryBaseline
        
        // Warn if memory usage exceeds target
        if memoryUsage > maxMemoryIncrease {
            logger.warning("⚠️ Glass memory usage exceeded target: \(self.memoryUsage)MB (limit: \(self.maxMemoryIncrease)MB)")
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
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
            return 0.0
        }
    }
    
    // MARK: - Thermal State Monitoring
    
    private func setupThermalStateMonitoring() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateThermalState()
            }
        }
        updateThermalState()
    }
    
    private func updateThermalState() {
        thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .serious, .critical:
            logger.warning("🔥 Thermal throttling detected: \(String(describing: self.thermalState))")
            // Reduce Glass effect complexity during thermal throttling
            NotificationCenter.default.post(name: .glassPerformanceThrottleRequired, object: nil)
        default:
            break
        }
    }
    
    // MARK: - ProMotion Detection
    
    private func detectProMotionCapability() {
        if #available(iOS 15.0, *) {
            // Check if device supports ProMotion (120Hz)
            let screen = UIScreen.main
            isProMotionEnabled = screen.maximumFramesPerSecond >= 120
            logger.info("📱 ProMotion capability: \(self.isProMotionEnabled ? "Enabled" : "Not Available") (max: \(screen.maximumFramesPerSecond)fps)")
        } else {
            isProMotionEnabled = false
        }
    }
    
    // MARK: - Performance Analysis
    
    private func updatePerformanceSnapshot() {
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            fps: currentFPS,
            memoryUsage: memoryUsage,
            gpuUsage: gpuUsage,
            responseTime: 1.0 / currentFPS, // Approximate response time
            glassEffectsActive: getActiveGlassEffectsCount()
        )
        
        performanceHistory.append(snapshot)
        if performanceHistory.count > maxHistoryCount {
            performanceHistory.removeFirst()
        }
    }
    
    private func getActiveGlassEffectsCount() -> Int {
        // This would track active Glass effects in a real implementation
        // For now, return a placeholder value
        return 0
    }
    
    // MARK: - Performance Reporting
    
    func getPerformanceReport() -> PerformanceReport {
        let recentHistory = Array(performanceHistory.suffix(60)) // Last 60 samples
        
        let avgFPS = recentHistory.isEmpty ? 0 : recentHistory.map(\.fps).reduce(0, +) / Double(recentHistory.count)
        let minFPS = recentHistory.map(\.fps).min() ?? 0
        let maxFPS = recentHistory.map(\.fps).max() ?? 0
        
        let avgMemory = recentHistory.isEmpty ? 0 : recentHistory.map(\.memoryUsage).reduce(0, +) / Double(recentHistory.count)
        let maxMemory = recentHistory.map(\.memoryUsage).max() ?? 0
        
        let avgResponseTime = recentHistory.isEmpty ? 0 : recentHistory.map(\.responseTime).reduce(0, +) / Double(recentHistory.count)
        let maxResponseTime = recentHistory.map(\.responseTime).max() ?? 0
        
        return PerformanceReport(
            averageFPS: avgFPS,
            minimumFPS: minFPS,
            maximumFPS: maxFPS,
            frameDropCount: frameDrops,
            averageMemoryUsage: avgMemory,
            peakMemoryUsage: maxMemory,
            averageResponseTime: avgResponseTime,
            maximumResponseTime: maxResponseTime,
            thermalState: thermalState,
            isProMotionActive: isProMotionEnabled && avgFPS > 90,
            performanceGrade: calculatePerformanceGrade(avgFPS: avgFPS, avgMemory: avgMemory, avgResponseTime: avgResponseTime)
        )
    }
    
    private func calculatePerformanceGrade(avgFPS: Double, avgMemory: Double, avgResponseTime: TimeInterval) -> PerformanceGrade {
        var score = 100.0
        
        // FPS scoring (40% weight)
        let fpsRatio = avgFPS / targetFPS
        if fpsRatio < 0.5 {
            score -= 40
        } else if fpsRatio < 0.75 {
            score -= 25
        } else if fpsRatio < 0.95 {
            score -= 10
        }
        
        // Memory scoring (30% weight)
        let memoryRatio = avgMemory / maxMemoryIncrease
        if memoryRatio > 2.0 {
            score -= 30
        } else if memoryRatio > 1.5 {
            score -= 20
        } else if memoryRatio > 1.0 {
            score -= 10
        }
        
        // Response time scoring (30% weight)
        let responseRatio = avgResponseTime / maxResponseTime
        if responseRatio > 2.0 {
            score -= 30
        } else if responseRatio > 1.5 {
            score -= 20
        } else if responseRatio > 1.0 {
            score -= 10
        }
        
        switch score {
        case 90...100: return .excellent
        case 75..<90: return .good
        case 60..<75: return .fair
        case 40..<60: return .poor
        default: return .critical
        }
    }
    
    private func logPerformanceSummary() {
        let report = getPerformanceReport()
        
        logger.info("""
        📊 Glass Performance Summary:
        • Average FPS: \(report.averageFPS) (target: \(self.targetFPS))
        • Frame Drops: \(report.frameDropCount)
        • Memory Usage: \(report.averageMemoryUsage)MB (limit: \(self.maxMemoryIncrease)MB)
        • Response Time: \(report.averageResponseTime * 1000)ms (target: \(self.maxResponseTime * 1000)ms)
        • Performance Grade: \(report.performanceGrade.rawValue)
        • ProMotion Active: \(report.isProMotionActive)
        """)
    }
}

// MARK: - Performance Report Types

struct PerformanceReport {
    let averageFPS: Double
    let minimumFPS: Double
    let maximumFPS: Double
    let frameDropCount: Int
    let averageMemoryUsage: Double
    let peakMemoryUsage: Double
    let averageResponseTime: TimeInterval
    let maximumResponseTime: TimeInterval
    let thermalState: ProcessInfo.ThermalState
    let isProMotionActive: Bool
    let performanceGrade: PerformanceGrade
}

enum PerformanceGrade: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let glassPerformanceThrottleRequired = Notification.Name("glassPerformanceThrottleRequired")
    static let glassPerformanceOptimal = Notification.Name("glassPerformanceOptimal")
}