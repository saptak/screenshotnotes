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
    private let highMemoryThreshold: Double = 150 // MB - Reduced from 200 for better performance
    private let bulkImportMemoryThreshold: Double = 250 // MB - Reduced from 400 for better performance
    
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
        guard !isMonitoring else { return }
        
        isMonitoring = true
        thermalState = ProcessInfo.processInfo.thermalState
        
        // Start FPS monitoring
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
        
        // Start memory monitoring
        startMemoryMonitoring()
        
        logger.info("Gallery performance monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        displayLink?.invalidate()
        displayLink = nil
        
        logger.info("Gallery performance monitoring stopped")
    }
    
    @objc private func displayLinkFired(displayLink: CADisplayLink) {
        frameCount += 1
        
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }
        
        let elapsed = displayLink.timestamp - lastTimestamp
        if elapsed >= 1.0 { // Update every second
            let fps = Double(frameCount) / elapsed
            
            DispatchQueue.main.async {
                self.currentFPS = fps
                self.updateFPSHistory(fps: fps)
                self.checkPerformanceThresholds()
            }
            
            frameCount = 0
            lastTimestamp = displayLink.timestamp
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
        fpsHistory.append(fps)
        if fpsHistory.count > maxFPSHistory {
            fpsHistory.removeFirst()
        }
    }
    
    private func checkPerformanceThresholds() {
        // Check for low FPS
        if currentFPS < lowFPSThreshold {
            logger.warning("Low FPS detected: \(self.currentFPS, format: .fixed(precision: 1))")
            optimizeForLowFPS()
        }
        
        // Check for high memory usage with different thresholds for bulk import
        let currentThreshold = isBulkImporting ? bulkImportMemoryThreshold : highMemoryThreshold
        if memoryUsage > currentThreshold {
            logger.warning("High memory usage detected: \(self.memoryUsage, format: .fixed(precision: 1))MB (threshold: \(currentThreshold)MB, bulk importing: \(self.isBulkImporting))")
            optimizeForHighMemory()
        }
    }
    
    private func handleThermalStateChange() {
        switch thermalState {
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
            "fps": currentFPS
        ])
    }
    
    private func optimizeForHighMemory() {
        // More aggressive memory management during scrolling
        if !isBulkImporting {
            // If not bulk importing, clear cache more aggressively
            logger.info("Thumbnail cache cleared (bulk importing: \(self.isBulkImporting))")
            ThumbnailService.shared.clearCache()
        } else if memoryUsage > bulkImportMemoryThreshold + 50 {
            // During bulk import, only clear if memory usage is critically high
            logger.info("🧠 Critical memory pressure - clearing cache during bulk import")
            ThumbnailService.shared.clearCache()
        } else {
            logger.info("🧠 Optimizing for high memory usage - cache clearing suspended during bulk import")
        }
        
        // Post notification for other components to optimize
        NotificationCenter.default.post(name: .performanceOptimizationNeeded, object: nil, userInfo: [
            "type": "highMemory",
            "memoryMB": memoryUsage,
            "isBulkImporting": isBulkImporting
        ])
    }
    
    private func optimizeForThermalPressure() {
        // Aggressive optimization for thermal throttling
        ThumbnailService.shared.clearCache()
        
        NotificationCenter.default.post(name: .performanceOptimizationNeeded, object: nil, userInfo: [
            "type": "thermal",
            "thermalState": thermalState
        ])
    }
    
    // Bulk import state management
    func setBulkImportState(_ isImporting: Bool) {
        isBulkImporting = isImporting
        logger.info("Bulk import state changed: \(isImporting)")
    }
    
    // Performance metrics for debugging
    var performanceMetrics: PerformanceMetrics {
        return PerformanceMetrics(
            averageFPS: fpsHistory.isEmpty ? 0 : fpsHistory.reduce(0, +) / Double(fpsHistory.count),
            currentFPS: currentFPS,
            memoryUsageMB: memoryUsage,
            thermalState: thermalState,
            isOptimizing: thermalState == .serious || thermalState == .critical || currentFPS < lowFPSThreshold
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