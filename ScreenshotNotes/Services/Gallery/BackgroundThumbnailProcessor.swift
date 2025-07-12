import Foundation
import SwiftData
import SwiftUI
import UIKit

@MainActor
class BackgroundThumbnailProcessor: ObservableObject {
    static let shared = BackgroundThumbnailProcessor()
    
    // MARK: - Processing State
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var activeTaskCount = 0
    @Published var queuedTaskCount = 0
    @Published var completedTaskCount = 0
    @Published var totalTaskCount = 0
    
    // MARK: - Priority-Based Processing Queue
    private var highPriorityQueue: [ThumbnailTask] = []
    private var normalPriorityQueue: [ThumbnailTask] = []
    private var backgroundPriorityQueue: [ThumbnailTask] = []
    
    // MARK: - Resource Management
    private let maxConcurrentTasks = 2 // Respect existing concurrency limits
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private var processingTimer: Timer?
    private var resourceMonitor: ResourceMonitor
    
    // MARK: - Dependencies
    private var cacheManager: AdvancedThumbnailCacheManager
    private var modelContext: ModelContext?
    
    // MARK: - Performance Tracking
    private var processedThumbnails = 0
    private var totalProcessingTime: TimeInterval = 0
    private var startTime: Date?
    
    private init() {
        self.cacheManager = AdvancedThumbnailCacheManager.shared
        self.resourceMonitor = ResourceMonitor()
        
        // Set up resource monitoring
        setupResourceMonitoring()
        
        // Start processing timer
        startProcessingTimer()
    }
    
    deinit {
        processingTimer?.invalidate()
        // Cancel all active tasks
        for (_, task) in activeTasks {
            task.cancel()
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        // AdvancedThumbnailCacheManager no longer needs ModelContext
    }
    
    // MARK: - Public Interface
    
    /// Request thumbnail generation with priority
    func requestThumbnail(for screenshotId: UUID, from imageData: Data, size: CGSize, priority: CachePriority = .normal) {
        let task = ThumbnailTask(
            id: UUID(),
            screenshotId: screenshotId,
            imageData: imageData,
            size: size,
            priority: priority,
            requestedAt: Date()
        )
        
        // Add to appropriate queue
        switch priority {
        case .high:
            highPriorityQueue.append(task)
        case .normal:
            normalPriorityQueue.append(task)
        case .background:
            backgroundPriorityQueue.append(task)
        }
        
        updateQueueMetrics()
        
        // Start processing if not already active
        if !isProcessing {
            startProcessing()
        }
    }
    
    /// Batch request thumbnails for viewport optimization
    func requestThumbnailBatch(for screenshots: [Screenshot], size: CGSize, priority: CachePriority = .background) {
        let tasks = screenshots.map { screenshot in
            ThumbnailTask(
                id: UUID(),
                screenshotId: screenshot.id,
                imageData: screenshot.imageData,
                size: size,
                priority: priority,
                requestedAt: Date()
            )
        }
        
        // Add to appropriate queue
        switch priority {
        case .high:
            highPriorityQueue.append(contentsOf: tasks)
        case .normal:
            normalPriorityQueue.append(contentsOf: tasks)
        case .background:
            backgroundPriorityQueue.append(contentsOf: tasks)
        }
        
        updateQueueMetrics()
        
        // Start processing if not already active
        if !isProcessing {
            startProcessing()
        }
    }
    
    /// Cancel thumbnail generation for specific screenshot
    func cancelThumbnailGeneration(for screenshotId: UUID) {
        // Remove from queues
        highPriorityQueue.removeAll { $0.screenshotId == screenshotId }
        normalPriorityQueue.removeAll { $0.screenshotId == screenshotId }
        backgroundPriorityQueue.removeAll { $0.screenshotId == screenshotId }
        
        // Cancel active task if exists
        if let task = activeTasks[screenshotId] {
            task.cancel()
            activeTasks.removeValue(forKey: screenshotId)
        }
        
        updateQueueMetrics()
    }
    
    /// Stop all processing
    func stopProcessing() {
        isProcessing = false
        processingTimer?.invalidate()
        
        // Cancel all active tasks
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        
        updateQueueMetrics()
    }
    
    // MARK: - Processing Logic
    
    private func startProcessing() {
        guard !isProcessing else { return }
        
        isProcessing = true
        startTime = Date()
        
        print("🔄 Starting background thumbnail processing")
        
        // Process tasks from queues
        processNextTasks()
    }
    
    private func processNextTasks() {
        guard isProcessing else { return }
        
        // Check resource constraints
        guard canProcessMoreTasks() else {
            // Schedule retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.processNextTasks()
            }
            return
        }
        
        // Get next task to process based on priority
        guard let task = getNextTask() else {
            // No more tasks - stop processing
            completeProcessing()
            return
        }
        
        // Process the task
        processTask(task)
        
        // Schedule next task processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.processNextTasks()
        }
    }
    
    private func processTask(_ task: ThumbnailTask) {
        let processingTask = Task.detached { [weak self] in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Check if thumbnail is already cached
            if await self?.cacheManager.getThumbnail(for: task.screenshotId, size: task.size) != nil {
                await self?.handleTaskCompletion(task, success: true, processingTime: 0)
                return
            }
                
            // Generate thumbnail
            let thumbnail = await self?.generateThumbnail(from: task.imageData, size: task.size)
            
            if let thumbnail = thumbnail {
                // Save to cache
                if let strongSelf = self {
                    await MainActor.run {
                        strongSelf.cacheManager.storeThumbnail(thumbnail, for: task.screenshotId, size: task.size)
                    }
                }
                
                let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                await self?.handleTaskCompletion(task, success: true, processingTime: processingTime)
            } else {
                await self?.handleTaskCompletion(task, success: false, processingTime: 0)
            }
        }
        
        // Store active task
        activeTasks[task.screenshotId] = processingTask
        activeTaskCount = activeTasks.count
        
        print("🔄 Processing thumbnail for: \(task.screenshotId) (Priority: \(task.priority))")
    }
    
    private func generateThumbnail(from imageData: Data, size: CGSize) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let originalImage = UIImage(data: imageData) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let thumbnail = UIGraphicsImageRenderer(size: size).image { _ in
                    originalImage.draw(in: CGRect(origin: .zero, size: size))
                }
                
                continuation.resume(returning: thumbnail)
            }
        }
    }
    
    private func handleTaskCompletion(_ task: ThumbnailTask, success: Bool, processingTime: TimeInterval) {
        // Remove from active tasks
        activeTasks.removeValue(forKey: task.screenshotId)
        activeTaskCount = activeTasks.count
        
        // Update metrics
        if success {
            completedTaskCount += 1
            processedThumbnails += 1
            totalProcessingTime += processingTime
            
            print("✅ Thumbnail completed for: \(task.screenshotId) in \(Int(processingTime * 1000))ms")
        } else {
            print("❌ Thumbnail failed for: \(task.screenshotId)")
        }
        
        updateProgress()
    }
    
    private func getNextTask() -> ThumbnailTask? {
        // Check high priority queue first
        if !highPriorityQueue.isEmpty {
            return highPriorityQueue.removeFirst()
        }
        
        // Check normal priority queue
        if !normalPriorityQueue.isEmpty {
            return normalPriorityQueue.removeFirst()
        }
        
        // Check background priority queue
        if !backgroundPriorityQueue.isEmpty {
            return backgroundPriorityQueue.removeFirst()
        }
        
        return nil
    }
    
    private func canProcessMoreTasks() -> Bool {
        // Check concurrent task limit
        if activeTasks.count >= maxConcurrentTasks {
            return false
        }
        
        // Check resource constraints
        if resourceMonitor.isUnderResourcePressure() {
            return false
        }
        
        // Check thermal state
        if ProcessInfo.processInfo.thermalState == .critical {
            return false
        }
        
        return true
    }
    
    private func completeProcessing() {
        isProcessing = false
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime ?? endTime)
        
        print("✅ Background thumbnail processing completed")
        print("   Processed: \(processedThumbnails) thumbnails")
        print("   Total time: \(String(format: "%.2f", totalTime))s")
        print("   Average time: \(String(format: "%.2f", totalTime / Double(max(processedThumbnails, 1))))s per thumbnail")
        
        // Reset metrics
        processedThumbnails = 0
        totalProcessingTime = 0
        startTime = nil
    }
    
    // MARK: - Resource Management
    
    private func setupResourceMonitoring() {
        // Monitor memory pressure
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }
        
        // Monitor thermal state
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleThermalStateChange()
            }
        }
    }
    
    private func handleMemoryPressure() {
        print("⚠️ Memory pressure detected - optimizing thumbnail processing")
        
        // Reduce queue sizes
        backgroundPriorityQueue.removeAll()
        
        // Reduce concurrent tasks temporarily
        if activeTasks.count > 1 {
            // Cancel lowest priority active task
            if let (id, task) = activeTasks.first {
                task.cancel()
                activeTasks.removeValue(forKey: id)
            }
        }
        
        // Optimize cache
        cacheManager.optimizeForMemoryPressure(level: ThumbnailMemoryPressureLevel.warning)
        
        updateQueueMetrics()
    }
    
    private func handleThermalStateChange() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .serious:
            print("🌡️ Thermal state serious - reducing thumbnail processing")
            // Reduce queue sizes
            backgroundPriorityQueue = Array(backgroundPriorityQueue.prefix(10))
            
        case .critical:
            print("🌡️ Thermal state critical - pausing thumbnail processing")
            // Pause processing temporarily
            stopProcessing()
            
            // Resume after cooling down
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
                if ProcessInfo.processInfo.thermalState != .critical {
                    self?.startProcessing()
                }
            }
            
        default:
            // Normal thermal state - resume processing if needed
            if !isProcessing && hasTasksInQueue() {
                startProcessing()
            }
        }
    }
    
    private func startProcessingTimer() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }
    
    // MARK: - Metrics & Progress
    
    private func updateQueueMetrics() {
        queuedTaskCount = highPriorityQueue.count + normalPriorityQueue.count + backgroundPriorityQueue.count
        totalTaskCount = completedTaskCount + activeTaskCount + queuedTaskCount
    }
    
    private func updateProgress() {
        updateQueueMetrics()
        
        if totalTaskCount > 0 {
            processingProgress = Double(completedTaskCount) / Double(totalTaskCount)
        } else {
            processingProgress = 1.0
        }
    }
    
    private func hasTasksInQueue() -> Bool {
        return !highPriorityQueue.isEmpty || !normalPriorityQueue.isEmpty || !backgroundPriorityQueue.isEmpty
    }
    
    // MARK: - Performance Metrics
    
    var performanceMetrics: ProcessingMetrics {
        return ProcessingMetrics(
            averageProcessingTime: processedThumbnails > 0 ? totalProcessingTime / Double(processedThumbnails) : 0,
            totalProcessed: processedThumbnails,
            activeTaskCount: activeTaskCount,
            queuedTaskCount: queuedTaskCount,
            completedTaskCount: completedTaskCount,
            processingProgress: processingProgress,
            isProcessing: isProcessing
        )
    }
}

// MARK: - Supporting Types

struct ThumbnailTask {
    let id: UUID
    let screenshotId: UUID
    let imageData: Data
    let size: CGSize
    let priority: CachePriority
    let requestedAt: Date
}

struct ProcessingMetrics {
    let averageProcessingTime: TimeInterval
    let totalProcessed: Int
    let activeTaskCount: Int
    let queuedTaskCount: Int
    let completedTaskCount: Int
    let processingProgress: Double
    let isProcessing: Bool
}

// MARK: - Resource Monitor

class ResourceMonitor {
    private var lastMemoryCheck: Date = Date()
    private var lastMemoryUsage: UInt64 = 0
    
    func isUnderResourcePressure() -> Bool {
        // Check memory usage
        let currentMemory = getCurrentMemoryUsage()
        let memoryThreshold: UInt64 = 200 * 1024 * 1024 // 200MB
        
        if currentMemory > memoryThreshold {
            return true
        }
        
        // Check CPU usage (simplified)
        if ProcessInfo.processInfo.thermalState == .serious {
            return true
        }
        
        return false
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
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
            return info.resident_size
        } else {
            return 0
        }
    }
} 