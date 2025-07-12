import Foundation
import UIKit
import OSLog

@MainActor
class GalleryPerformanceMonitor: ObservableObject {
    static let shared = GalleryPerformanceMonitor()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "GalleryPerformance")
    
    @Published var isMonitoring = false
    @Published var currentFPS: Double = 0
    @Published var memoryUsage: Double = 0 // In MB
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var isBulkImporting = false // Track bulk import state
    
    private var displayLink: CADisplayLink?
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var fpsHistory: [Double] = []
    private let maxFPSHistory = 60
    
    // Performance thresholds
    private let lowFPSThreshold: Double = 45
    private let highMemoryThreshold: Double = 300 // MB - Increased to prevent aggressive cache clearing during normal operation
    private let bulkImportMemoryThreshold: Double = 400 // MB - Restored higher threshold for bulk imports
    
    private init() {
        // Monitor thermal state changes
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.thermalState = ProcessInfo.processInfo.thermalState
                self?.handleThermalStateChange()
            }
        }
    }
    
    deinit {
        // Can't call async methods in deinit, just clean up synchronously
        displayLink?.invalidate()
        displayLink = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    func startMonitoring() {
        guard !self.isMonitoring else { return }
        
        self.isMonitoring = true
        self.thermalState = ProcessInfo.processInfo.thermalState
        
        // Start FPS monitoring
        self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        self.displayLink?.add(to: .main, forMode: .common)
        
        // Start memory monitoring
        startMemoryMonitoring()
        
        logger.info("Gallery performance monitoring started")
    }
    
    func stopMonitoring() {
        guard self.isMonitoring else { return }
        
        self.isMonitoring = false
        self.displayLink?.invalidate()
        self.displayLink = nil
        
        logger.info("Gallery performance monitoring stopped")
    }
    
    @objc private func displayLinkFired(displayLink: CADisplayLink) {
        self.frameCount += 1
        
        if self.lastTimestamp == 0 {
            self.lastTimestamp = displayLink.timestamp
            return
        }
        
        let elapsed = displayLink.timestamp - self.lastTimestamp
        if elapsed >= 1.0 { // Update every second
            let fps = Double(self.frameCount) / elapsed
            
            DispatchQueue.main.async {
                self.currentFPS = fps
                self.updateFPSHistory(fps: fps)
                self.checkPerformanceThresholds()
            }
            
            self.frameCount = 0
            self.lastTimestamp = displayLink.timestamp
        }
    }
    
    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isMonitoring else { return }
                
                let memoryMB = await self.getCurrentMemoryUsage()
                self.memoryUsage = memoryMB
            }
        }
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
    
    private func updateFPSHistory(fps: Double) {
        self.fpsHistory.append(fps)
        if self.fpsHistory.count > self.maxFPSHistory {
            self.fpsHistory.removeFirst()
        }
    }
    
    private func checkPerformanceThresholds() {
        // Check for low FPS
        if self.currentFPS < self.lowFPSThreshold {
            logger.warning("Low FPS detected: \(self.currentFPS, format: .fixed(precision: 1))")
            optimizeForLowFPS()
        }
        
        // Check for high memory usage with different thresholds for bulk import
        let currentThreshold = self.isBulkImporting ? self.bulkImportMemoryThreshold : self.highMemoryThreshold
        if self.memoryUsage > currentThreshold {
            logger.warning("High memory usage detected: \(self.memoryUsage, format: .fixed(precision: 1))MB (threshold: \(currentThreshold)MB, bulk importing: \(self.isBulkImporting))")
            optimizeForHighMemory()
        }
    }
    
    private func handleThermalStateChange() {
        switch self.thermalState {
        case .serious, .critical:
            logger.warning("Thermal throttling detected: \(String(describing: self.thermalState))")
            optimizeForThermalPressure()
        default:
            break
        }
    }
    
    private func optimizeForLowFPS() {
        // Reduce thumbnail quality
        NotificationCenter.default.post(name: .performanceOptimizationNeeded, object: nil, userInfo: [
            "type": "lowFPS",
            "fps": self.currentFPS
        ])
    }
    
    private func optimizeForHighMemory() {
        // Graduated memory pressure response instead of nuclear cache clearing
        if !self.isBulkImporting {
            // If not bulk importing, use graduated cache optimization
            logger.info("🧠 Memory pressure detected - optimizing cache (bulk importing: \(self.isBulkImporting))")
            ThumbnailService.shared.clearCache() // This now uses graduated response
        } else if self.memoryUsage > self.bulkImportMemoryThreshold + 50 {
            // During bulk import, only use aggressive clearing if memory usage is critically high
            logger.info("🧠 Critical memory pressure - forcing cache optimization during bulk import")
            ThumbnailService.shared.forceClearAllCaches() // Use nuclear option only for critical situations
        } else {
            logger.info("🧠 Optimizing for high memory usage - using graduated cache management during bulk import")
            ThumbnailService.shared.clearCache() // Graduated response even during bulk import
        }
        
        // Post notification for other components to optimize
        NotificationCenter.default.post(name: .performanceOptimizationNeeded, object: nil, userInfo: [
            "type": "highMemory",
            "memoryMB": self.memoryUsage,
            "isBulkImporting": self.isBulkImporting,
            "optimizationLevel": self.memoryUsage > self.bulkImportMemoryThreshold + 50 ? "critical" : "warning"
        ])
    }
    
    private func optimizeForThermalPressure() {
        // Graduated optimization for thermal throttling
        switch self.thermalState {
        case .serious:
            logger.warning("🌡️ Serious thermal state - using graduated cache optimization")
            ThumbnailService.shared.clearCache() // Graduated response
        case .critical:
            logger.warning("🌡️ Critical thermal state - forcing aggressive cache clearing")
            ThumbnailService.shared.forceClearAllCaches() // Nuclear option for critical thermal state
        default:
            logger.info("🌡️ Thermal optimization for state: \(String(describing: self.thermalState))")
            ThumbnailService.shared.clearCache() // Graduated response
        }
        
        NotificationCenter.default.post(name: .performanceOptimizationNeeded, object: nil, userInfo: [
            "type": "thermal",
            "thermalState": self.thermalState,
            "optimizationLevel": self.thermalState == .critical ? "critical" : "warning"
        ])
    }
    
    // Bulk import state management
    func setBulkImportState(_ isImporting: Bool) {
        self.isBulkImporting = isImporting
        logger.info("Bulk import state changed: \(isImporting)")
    }
    
    // Performance metrics for debugging
    var performanceMetrics: PerformanceMetrics {
        return PerformanceMetrics(
            averageFPS: self.fpsHistory.isEmpty ? 0 : self.fpsHistory.reduce(0, +) / Double(self.fpsHistory.count),
            currentFPS: self.currentFPS,
            memoryUsageMB: self.memoryUsage,
            thermalState: self.thermalState,
            isOptimizing: self.thermalState == .serious || self.thermalState == .critical || self.currentFPS < self.lowFPSThreshold
        )
    }
}

struct PerformanceMetrics {
    let averageFPS: Double
    let currentFPS: Double
    let memoryUsageMB: Double
    let thermalState: ProcessInfo.ThermalState
    let isOptimizing: Bool
}

extension Notification.Name {
    static let performanceOptimizationNeeded = Notification.Name("performanceOptimizationNeeded")
}