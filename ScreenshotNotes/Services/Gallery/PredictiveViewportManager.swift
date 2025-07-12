import Foundation
import UIKit
import SwiftUI

/// Phase 2: Predictive viewport management with scroll velocity awareness
/// Prevents resource starvation by intelligently preloading content based on user behavior
@MainActor
class PredictiveViewportManager: ObservableObject {
    static let shared = PredictiveViewportManager()
    
    // MARK: - Viewport State
    
    @Published var currentViewport: ViewportInfo = ViewportInfo()
    @Published var scrollVelocity: CGFloat = 0
    @Published var isScrolling = false
    @Published var isPredictiveLoadingEnabled = true
    
    // MARK: - Scroll Analysis
    
    private var scrollHistory: [ScrollSample] = []
    private let maxScrollHistorySize = 10
    private var lastScrollOffset: CGFloat = 0
    private var lastScrollTime = Date()
    
    // MARK: - Preloading Configuration
    
    private let basePreloadBuffer = 5 // Items to preload beyond visible area
    private let maxPreloadBuffer = 15 // Maximum preload buffer for fast scrolling
    private let velocityThreshold: CGFloat = 100 // Points per second to consider "fast scrolling"
    
    // Resource management
    private let maxConcurrentPreloads = 3
    private var activePreloads: Set<UUID> = []
    private let preloadQueue = DispatchQueue(label: "com.screenshotnotes.preload", qos: .background)
    
    // Performance tracking
    private var preloadHitCount = 0
    private var preloadMissCount = 0
    private var totalPreloadRequests = 0
    
    private init() {
        print("🔮 PredictiveViewportManager initialized")
    }
    
    // MARK: - Public Interface
    
    /// Update viewport information and trigger predictive loading
    func updateViewport(_ viewport: ViewportInfo) {
        let previousViewport = currentViewport
        currentViewport = viewport
        
        // Calculate scroll velocity is handled in updateScrollOffset
        
        // Trigger predictive loading if enabled
        if isPredictiveLoadingEnabled {
            predictivelyLoadContent(previousViewport: previousViewport)
        }
    }
    
    /// Update scroll offset for velocity calculation
    func updateScrollOffset(_ offset: CGFloat) {
        let currentTime = Date()
        let deltaTime = currentTime.timeIntervalSince(lastScrollTime)
        
        // Avoid division by zero and very small time intervals
        if deltaTime > 0.01 {
            let deltaOffset = offset - lastScrollOffset
            let velocity = CGFloat(deltaOffset / deltaTime)
            
            addScrollSample(ScrollSample(offset: offset, velocity: velocity, timestamp: currentTime))
            
            scrollVelocity = calculateAverageVelocity()
            isScrolling = abs(scrollVelocity) > 10 // Consider scrolling if velocity > 10 pts/sec
            
            lastScrollOffset = offset
            lastScrollTime = currentTime
        }
    }
    
    /// Register preload hit (item was needed and was preloaded)
    func registerPreloadHit(for itemId: UUID) {
        preloadHitCount += 1
        activePreloads.remove(itemId)
        updatePreloadMetrics()
    }
    
    /// Register preload miss (item was needed but wasn't preloaded)
    func registerPreloadMiss(for itemId: UUID) {
        preloadMissCount += 1
        updatePreloadMetrics()
    }
    
    /// Get optimal preload range based on current conditions
    func getPreloadRange() -> Range<Int> {
        let adaptiveBuffer = calculateAdaptiveBuffer()
        let start = max(0, currentViewport.firstVisibleIndex - adaptiveBuffer)
        let end = min(currentViewport.totalItems, currentViewport.lastVisibleIndex + adaptiveBuffer + 1)
        
        return start..<end
    }
    
    // MARK: - Scroll Analysis
    
    private func addScrollSample(_ sample: ScrollSample) {
        scrollHistory.append(sample)
        
        // Maintain history size
        if scrollHistory.count > maxScrollHistorySize {
            scrollHistory.removeFirst()
        }
    }
    
    private func calculateAverageVelocity() -> CGFloat {
        guard !scrollHistory.isEmpty else { return 0 }
        
        // Weight recent samples more heavily
        let weightedSum = scrollHistory.enumerated().reduce(0.0) { sum, element in
            let (index, sample) = element
            let weight = Double(index + 1) / Double(scrollHistory.count) // 0.1 to 1.0
            return sum + (Double(sample.velocity) * weight)
        }
        
        let totalWeight = scrollHistory.enumerated().reduce(0.0) { sum, element in
            let (index, _) = element
            return sum + (Double(index + 1) / Double(scrollHistory.count))
        }
        
        return CGFloat(weightedSum / totalWeight)
    }
    
    private func calculateAdaptiveBuffer() -> Int {
        let baseBuffer = basePreloadBuffer
        let velocityFactor = min(2.0, abs(scrollVelocity) / velocityThreshold)
        let adaptiveIncrease = Int(velocityFactor * Double(baseBuffer))
        
        // Reduce buffer during high memory pressure
        let memoryPressureFactor = getMemoryPressureFactor()
        let finalBuffer = min(maxPreloadBuffer, Int(Double(baseBuffer + adaptiveIncrease) * memoryPressureFactor))
        
        return max(1, finalBuffer)
    }
    
    private func getMemoryPressureFactor() -> Double {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageMB = Double(memoryInfo.resident_size) / 1024.0 / 1024.0
            
            // Reduce preloading if memory usage is high
            if memoryUsageMB > 200 {
                return 0.5 // Reduce by 50%
            } else if memoryUsageMB > 150 {
                return 0.75 // Reduce by 25%
            } else {
                return 1.0 // No reduction
            }
        }
        
        return 1.0
    }
    
    // MARK: - Predictive Loading
    
    private func predictivelyLoadContent(previousViewport: ViewportInfo) {
        // Avoid excessive preloading during rapid changes
        guard !isOptimizingForResourcePressure() else { return }
        
        let preloadRange = getPreloadRange()
        let itemsToPreload = Array(preloadRange).filter { index in
            !currentViewport.visibleIndices.contains(index) &&
            !previousViewport.visibleIndices.contains(index)
        }
        
        // Limit concurrent preloads to prevent resource starvation
        let availableSlots = maxConcurrentPreloads - activePreloads.count
        let itemsToProcess = Array(itemsToPreload.prefix(availableSlots))
        
        for index in itemsToProcess {
            if let itemId = getItemId(for: index) {
                requestPreload(for: itemId, index: index)
            }
        }
    }
    
    private func requestPreload(for itemId: UUID, index: Int) {
        guard !activePreloads.contains(itemId) else { return }
        
        activePreloads.insert(itemId)
        totalPreloadRequests += 1
        
        Task.detached(priority: .background) { [weak self] in
            // Simulate preload request to cache manager
            await self?.performPreload(itemId: itemId, index: index)
        }
    }
    
    private func performPreload(itemId: UUID, index: Int) async {
        // This would integrate with the actual thumbnail cache manager
        // For now, simulate the preload process
        
        // Check if item is still needed (user might have scrolled away)
        if !getPreloadRange().contains(index) {
            await MainActor.run {
                _ = activePreloads.remove(itemId)
            }
            return
        }
        
        // Simulate preload time with resource-aware delay
        let delay = isScrolling ? 0.1 : 0.05 // Faster preload when not scrolling
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        await MainActor.run {
            _ = activePreloads.remove(itemId)
        }
        
        print("🔮 Preloaded item at index \(index)")
    }
    
    // MARK: - Resource Management
    
    private func isOptimizingForResourcePressure() -> Bool {
        // Check thermal state
        if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical {
            return true
        }
        
        // Check if too many preloads are active
        if activePreloads.count >= maxConcurrentPreloads {
            return true
        }
        
        // Check scroll velocity (too fast to keep up)
        if abs(scrollVelocity) > velocityThreshold * 3 {
            return true
        }
        
        return false
    }
    
    private func updatePreloadMetrics() {
        if (preloadHitCount + preloadMissCount) % 20 == 0 && preloadHitCount + preloadMissCount > 0 {
            let hitRate = Double(preloadHitCount) / Double(preloadHitCount + preloadMissCount)
            print("🔮 Preload hit rate: \(String(format: "%.1f", hitRate * 100))%")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getItemId(for index: Int) -> UUID? {
        // This would be provided by the actual data source
        // For now, generate a deterministic UUID based on index
        return UUID()
    }
    
    // MARK: - Performance Metrics
    
    var performanceMetrics: PredictiveViewportMetrics {
        let hitRate = preloadHitCount + preloadMissCount > 0 ?
            Double(preloadHitCount) / Double(preloadHitCount + preloadMissCount) : 0.0
        
        return PredictiveViewportMetrics(
            currentViewportSize: currentViewport.visibleIndices.count,
            scrollVelocity: scrollVelocity,
            isScrolling: isScrolling,
            activePreloads: activePreloads.count,
            preloadHitRate: hitRate,
            totalPreloadRequests: totalPreloadRequests,
            adaptiveBuffer: calculateAdaptiveBuffer(),
            isPredictiveLoadingEnabled: isPredictiveLoadingEnabled
        )
    }
}

// MARK: - Supporting Types

struct ViewportInfo {
    var firstVisibleIndex: Int = 0
    var lastVisibleIndex: Int = 0
    var visibleIndices: Set<Int> = []
    var totalItems: Int = 0
    var viewportHeight: CGFloat = 0
    var contentHeight: CGFloat = 0
}

struct ScrollSample {
    let offset: CGFloat
    let velocity: CGFloat
    let timestamp: Date
}

struct PredictiveViewportMetrics {
    let currentViewportSize: Int
    let scrollVelocity: CGFloat
    let isScrolling: Bool
    let activePreloads: Int
    let preloadHitRate: Double
    let totalPreloadRequests: Int
    let adaptiveBuffer: Int
    let isPredictiveLoadingEnabled: Bool
}