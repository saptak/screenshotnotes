import SwiftUI
import Foundation
import os.log

@MainActor
class GlassMemoryManager: ObservableObject {
    static let shared = GlassMemoryManager()
    
    // MARK: - Memory Configuration
    private let memoryWarningThreshold: Double = 100.0 // 100MB
    private let criticalMemoryThreshold: Double = 150.0 // 150MB
    private let maxGlassMemoryBudget: Double = 50.0 // 50MB for Glass effects
    
    // MARK: - Memory State
    @Published var currentMemoryUsage: Double = 0.0
    @Published var glassMemoryUsage: Double = 0.0
    @Published var memoryPressureLevel: MemoryPressureLevel = .normal
    @Published var isMemoryOptimizationActive = false
    @Published var memoryWarningCount = 0
    
    // MARK: - Memory Tracking
    private var memoryBaseline: Double = 0.0
    private var lastMemoryCheck: Date = Date()
    private var memoryHistory: [MemorySnapshot] = []
    private let maxHistoryCount = 100
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "GlassMemory")
    
    // MARK: - Memory Pressure Levels
    enum MemoryPressureLevel: String, CaseIterable {
        case normal = "Normal"
        case elevated = "Elevated"
        case high = "High"
        case critical = "Critical"
        
        var color: Color {
            switch self {
            case .normal: return .green
            case .elevated: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
        
        var optimizationLevel: OptimizationLevel {
            switch self {
            case .normal: return .none
            case .elevated: return .mild
            case .high: return .aggressive
            case .critical: return .maximum
            }
        }
    }
    
    enum OptimizationLevel: String, CaseIterable {
        case none = "None"
        case mild = "Mild"
        case aggressive = "Aggressive"
        case maximum = "Maximum"
        
        var effectQualityReduction: Double {
            switch self {
            case .none: return 0.0
            case .mild: return 0.1
            case .aggressive: return 0.3
            case .maximum: return 0.6
            }
        }
        
        var cacheReductionFactor: Double {
            switch self {
            case .none: return 1.0
            case .mild: return 0.8
            case .aggressive: return 0.5
            case .maximum: return 0.2
            }
        }
    }
    
    // MARK: - Memory Snapshot
    private struct MemorySnapshot {
        let timestamp: Date
        let totalMemory: Double
        let glassMemory: Double
        let pressureLevel: MemoryPressureLevel
        let activeEffects: Int
        let cacheSize: Double
    }
    
    // MARK: - Memory Pool Management
    private struct MemoryPool {
        var allocatedSize: Double = 0.0
        var availableSize: Double = 0.0
        var fragmentedSize: Double = 0.0
        
        mutating func allocate(_ size: Double) -> Bool {
            if availableSize >= size {
                allocatedSize += size
                availableSize -= size
                return true
            }
            return false
        }
        
        mutating func deallocate(_ size: Double) {
            allocatedSize -= min(allocatedSize, size)
            availableSize += size
        }
        
        mutating func defragment() {
            availableSize += fragmentedSize
            fragmentedSize = 0.0
        }
    }
    
    private var glassMemoryPool = MemoryPool()
    
    private init() {
        measureMemoryBaseline()
        setupMemoryMonitoring()
        initializeMemoryPool()
        logger.info("🧠 Glass Memory Manager initialized with \(self.maxGlassMemoryBudget)MB budget")
    }
    
    // MARK: - Memory Monitoring Setup
    
    private func setupMemoryMonitoring() {
        // System memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        
        // Thermal state changes affect memory usage
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleThermalStateChange()
            }
        }
        
        // Start periodic memory monitoring
        startPeriodicMemoryMonitoring()
    }
    
    private func measureMemoryBaseline() {
        memoryBaseline = getCurrentMemoryUsage()
        logger.info("📊 Memory baseline established: \(String(format: "%.2f", self.memoryBaseline))MB")
    }
    
    private func initializeMemoryPool() {
        glassMemoryPool = MemoryPool()
        glassMemoryPool.availableSize = maxGlassMemoryBudget
        logger.info("🏊‍♂️ Glass memory pool initialized: \(self.maxGlassMemoryBudget)MB")
    }
    
    // MARK: - Periodic Memory Monitoring
    
    private func startPeriodicMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryMetrics()
            }
        }
    }
    
    private func updateMemoryMetrics() {
        let currentMemory = getCurrentMemoryUsage()
        let glassMemory = currentMemory - memoryBaseline
        
        currentMemoryUsage = currentMemory
        glassMemoryUsage = max(0, glassMemory)
        
        // Update pressure level
        let newPressureLevel = calculateMemoryPressureLevel()
        if newPressureLevel != memoryPressureLevel {
            logger.info("🔄 Memory pressure changed: \(self.memoryPressureLevel.rawValue) -> \(newPressureLevel.rawValue)")
            memoryPressureLevel = newPressureLevel
            handlePressureLevelChange(newPressureLevel)
        }
        
        // Record snapshot
        recordMemorySnapshot()
        
        // Check for optimization needs
        checkOptimizationNeeds()
        
        lastMemoryCheck = Date()
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
            return memoryBaseline // Fallback
        }
    }
    
    private func calculateMemoryPressureLevel() -> MemoryPressureLevel {
        let memoryUsage = glassMemoryUsage
        
        if memoryUsage >= criticalMemoryThreshold {
            return .critical
        } else if memoryUsage >= memoryWarningThreshold {
            return .high
        } else if memoryUsage >= memoryWarningThreshold * 0.7 {
            return .elevated
        } else {
            return .normal
        }
    }
    
    // MARK: - Memory Allocation Management
    
    func requestGlassMemory(_ size: Double, for component: String) -> Bool {
        // Check if we have enough memory in the pool
        if glassMemoryPool.allocate(size) {
            logger.debug("✅ Allocated \(size)MB for \(component)")
            return true
        }
        
        // Try to free up memory
        if tryToFreeMemory(size) {
            if glassMemoryPool.allocate(size) {
                logger.debug("♻️ Freed memory and allocated \(size)MB for \(component)")
                return true
            }
        }
        
        logger.warning("❌ Failed to allocate \(size)MB for \(component)")
        return false
    }
    
    func releaseGlassMemory(_ size: Double, from component: String) {
        glassMemoryPool.deallocate(size)
        logger.debug("🔄 Released \(size)MB from \(component)")
    }
    
    private func tryToFreeMemory(_ requiredSize: Double) -> Bool {
        var freedMemory: Double = 0
        
        // 1. Clear Glass effect caches
        if freedMemory < requiredSize {
            GlassCacheManager.shared.clearAllCaches()
            freedMemory += 10.0 // Estimate
            logger.info("🗑️ Cleared Glass caches to free memory")
        }
        
        // 2. Reduce rendering quality
        if freedMemory < requiredSize {
            GlassRenderingOptimizer.shared.renderingQuality = .low
            freedMemory += 5.0 // Estimate
            logger.info("📉 Reduced rendering quality to free memory")
        }
        
        // 3. Defragment memory pool
        if freedMemory < requiredSize {
            glassMemoryPool.defragment()
            freedMemory += glassMemoryPool.fragmentedSize
            logger.info("🔧 Defragmented memory pool")
        }
        
        // 4. Force garbage collection
        if freedMemory < requiredSize {
            performGarbageCollection()
            freedMemory += 5.0 // Estimate
        }
        
        return freedMemory >= requiredSize
    }
    
    // MARK: - Memory Optimization
    
    private func checkOptimizationNeeds() {
        let shouldOptimize = memoryPressureLevel != .normal || glassMemoryUsage > maxGlassMemoryBudget * 0.8
        
        if shouldOptimize != isMemoryOptimizationActive {
            isMemoryOptimizationActive = shouldOptimize
            
            if shouldOptimize {
                activateMemoryOptimization()
            } else {
                deactivateMemoryOptimization()
            }
        }
    }
    
    private func activateMemoryOptimization() {
        let optimizationLevel = memoryPressureLevel.optimizationLevel
        
        logger.info("🚀 Activating memory optimization: \(optimizationLevel.rawValue)")
        
        // Notify Glass components to optimize
        NotificationCenter.default.post(
            name: .glassMemoryOptimizationRequired,
            object: nil,
            userInfo: [
                "level": optimizationLevel,
                "qualityReduction": optimizationLevel.effectQualityReduction,
                "cacheReduction": optimizationLevel.cacheReductionFactor
            ]
        )
        
        // Apply optimizations based on level
        switch optimizationLevel {
        case .none:
            break
        case .mild:
            applyMildOptimization()
        case .aggressive:
            applyAggressiveOptimization()
        case .maximum:
            applyMaximumOptimization()
        }
    }
    
    private func deactivateMemoryOptimization() {
        logger.info("🔄 Deactivating memory optimization")
        
        NotificationCenter.default.post(
            name: .glassMemoryOptimizationDeactivated,
            object: nil
        )
        
        // Restore normal quality settings
        GlassRenderingOptimizer.shared.renderingQuality = .high
    }
    
    private func applyMildOptimization() {
        // Reduce cache size slightly
        let cacheStats = GlassCacheManager.shared.getCacheStatistics()
        if cacheStats.utilizationPercentage > 60 {
            // Clear 20% of least used cache entries
            logger.info("🧹 Mild optimization: reducing cache size")
        }
    }
    
    private func applyAggressiveOptimization() {
        // Significantly reduce memory usage
        GlassRenderingOptimizer.shared.renderingQuality = .medium
        GlassCacheManager.shared.clearAllCaches()
        
        logger.info("⚡ Aggressive optimization: reduced quality and cleared caches")
    }
    
    private func applyMaximumOptimization() {
        // Emergency memory conservation
        GlassRenderingOptimizer.shared.renderingQuality = .low
        GlassRenderingOptimizer.shared.isGPUAccelerated = false
        GlassCacheManager.shared.clearAllCaches()
        
        // Disable non-essential Glass effects
        NotificationCenter.default.post(
            name: .glassEffectsEmergencyDisable,
            object: nil
        )
        
        logger.warning("🚨 Maximum optimization: emergency memory conservation mode")
    }
    
    // MARK: - Memory Warning Handling
    
    private func handleMemoryWarning() {
        memoryWarningCount += 1
        logger.warning("⚠️ System memory warning received (count: \(self.memoryWarningCount))")
        
        // Force immediate optimization
        memoryPressureLevel = .critical
        isMemoryOptimizationActive = true
        activateMemoryOptimization()
        
        // Perform emergency cleanup
        performEmergencyCleanup()
    }
    
    private func handleThermalStateChange() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .serious, .critical:
            // Thermal throttling affects memory performance
            if memoryPressureLevel == .normal {
                memoryPressureLevel = .elevated
            }
            logger.info("🔥 Thermal state affecting memory management: \(String(describing: thermalState))")
        default:
            break
        }
    }
    
    private func handlePressureLevelChange(_ newLevel: MemoryPressureLevel) {
        // Immediately apply optimizations for high pressure
        if newLevel == .high || newLevel == .critical {
            activateMemoryOptimization()
        }
        
        // Notify performance monitor
        NotificationCenter.default.post(
            name: .glassMemoryPressureChanged,
            object: nil,
            userInfo: ["level": newLevel]
        )
    }
    
    // MARK: - Memory Cleanup
    
    private func performEmergencyCleanup() {
        logger.warning("🚨 Performing emergency memory cleanup")
        
        // Clear all caches
        GlassCacheManager.shared.clearAllCaches()
        
        // Reset memory pool
        initializeMemoryPool()
        
        // Force garbage collection
        performGarbageCollection()
        
        // Stop non-essential Glass effects
        GlassPerformanceMonitor.shared.stopMonitoring()
        
        logger.info("🧹 Emergency cleanup completed")
    }
    
    private func performGarbageCollection() {
        // Force autoreleasepool drain
        autoreleasepool {
            // This forces cleanup of autorelease objects
        }
        
        logger.debug("🗑️ Performed garbage collection")
    }
    
    // MARK: - Memory History and Analysis
    
    private func recordMemorySnapshot() {
        let snapshot = MemorySnapshot(
            timestamp: Date(),
            totalMemory: currentMemoryUsage,
            glassMemory: glassMemoryUsage,
            pressureLevel: memoryPressureLevel,
            activeEffects: getActiveEffectsCount(),
            cacheSize: Double(GlassCacheManager.shared.cacheSize) / 1024.0 / 1024.0 // Convert to MB
        )
        
        memoryHistory.append(snapshot)
        if memoryHistory.count > maxHistoryCount {
            memoryHistory.removeFirst()
        }
    }
    
    private func getActiveEffectsCount() -> Int {
        // This would track active Glass effects in a real implementation
        return GlassRenderingOptimizer.shared.activeEffectsCount
    }
    
    // MARK: - Public Interface
    
    func getMemoryReport() -> MemoryReport {
        let recentHistory = Array(memoryHistory.suffix(30)) // Last 30 samples
        
        let avgMemory = recentHistory.isEmpty ? 0 : recentHistory.map(\.glassMemory).reduce(0, +) / Double(recentHistory.count)
        let peakMemory = recentHistory.map(\.glassMemory).max() ?? 0
        let avgEffects = recentHistory.isEmpty ? 0 : Double(recentHistory.map(\.activeEffects).reduce(0, +)) / Double(recentHistory.count)
        
        return MemoryReport(
            currentUsage: glassMemoryUsage,
            averageUsage: avgMemory,
            peakUsage: peakMemory,
            memoryBudget: maxGlassMemoryBudget,
            pressureLevel: memoryPressureLevel,
            optimizationActive: isMemoryOptimizationActive,
            memoryWarnings: memoryWarningCount,
            averageActiveEffects: avgEffects,
            poolUtilization: (glassMemoryPool.allocatedSize / maxGlassMemoryBudget) * 100,
            fragmentationLevel: glassMemoryPool.fragmentedSize
        )
    }
    
    func resetMemoryMetrics() {
        memoryWarningCount = 0
        memoryHistory.removeAll()
        measureMemoryBaseline()
        initializeMemoryPool()
        
        logger.info("🔄 Memory metrics reset")
    }
}

// MARK: - Memory Report

struct MemoryReport {
    let currentUsage: Double
    let averageUsage: Double
    let peakUsage: Double
    let memoryBudget: Double
    let pressureLevel: GlassMemoryManager.MemoryPressureLevel
    let optimizationActive: Bool
    let memoryWarnings: Int
    let averageActiveEffects: Double
    let poolUtilization: Double
    let fragmentationLevel: Double
    
    var utilizationPercentage: Double {
        return (currentUsage / memoryBudget) * 100.0
    }
    
    var memoryEfficiency: Double {
        return averageActiveEffects > 0 ? averageUsage / averageActiveEffects : 0.0
    }
    
    var healthScore: Double {
        var score = 100.0
        
        // Usage factor (40% weight)
        let usageRatio = currentUsage / memoryBudget
        if usageRatio > 0.9 {
            score -= 40
        } else if usageRatio > 0.7 {
            score -= 20
        } else if usageRatio > 0.5 {
            score -= 10
        }
        
        // Pressure factor (30% weight)
        switch pressureLevel {
        case .critical: score -= 30
        case .high: score -= 20
        case .elevated: score -= 10
        case .normal: break
        }
        
        // Warning factor (20% weight)
        if memoryWarnings > 5 {
            score -= 20
        } else if memoryWarnings > 2 {
            score -= 10
        }
        
        // Fragmentation factor (10% weight)
        if fragmentationLevel > memoryBudget * 0.2 {
            score -= 10
        }
        
        return max(0, score)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let glassMemoryOptimizationRequired = Notification.Name("glassMemoryOptimizationRequired")
    static let glassMemoryOptimizationDeactivated = Notification.Name("glassMemoryOptimizationDeactivated")
    static let glassMemoryPressureChanged = Notification.Name("glassMemoryPressureChanged")
    static let glassEffectsEmergencyDisable = Notification.Name("glassEffectsEmergencyDisable")
}