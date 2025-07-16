import Foundation
import SwiftUI
import UIKit
import os.log

/// Comprehensive Memory Management System for preventing leaks and optimizing resource usage
/// Implements Iteration 8.5.3.2: Memory Management & Leak Prevention
@MainActor
public final class MemoryManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = MemoryManager()
    
    // MARK: - Memory Monitoring
    
    public struct MemoryUsage {
        public let totalMemory: UInt64
        public let usedMemory: UInt64
        public let availableMemory: UInt64
        public let memoryPressure: MemoryPressureLevel
        public let timestamp: Date
        
        public var usagePercentage: Double {
            guard totalMemory > 0 else { return 0.0 }
            return Double(usedMemory) / Double(totalMemory) * 100.0
        }
        
        public var formattedUsedMemory: String {
            ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory)
        }
        
        public var formattedTotalMemory: String {
            ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)
        }
    }
    
    public enum MemoryPressureLevel: String, CaseIterable {
        case normal = "normal"
        case warning = "warning"
        case critical = "critical"
        case emergency = "emergency"
        
        public var threshold: Double {
            switch self {
            case .normal: return 60.0
            case .warning: return 75.0
            case .critical: return 85.0
            case .emergency: return 95.0
            }
        }
        
        public var color: Color {
            switch self {
            case .normal: return .green
            case .warning: return .yellow
            case .critical: return .orange
            case .emergency: return .red
            }
        }
    }
    
    // MARK: - Object Lifecycle Tracking
    
    public struct ObjectLifecycle {
        public let className: String
        public let instanceId: String
        public let createdAt: Date
        public var deallocatedAt: Date?
        public var retainCount: Int
        public var isLeaked: Bool
        
        public var lifetime: TimeInterval? {
            guard let deallocatedAt = deallocatedAt else { return nil }
            return deallocatedAt.timeIntervalSince(createdAt)
        }
        
        public var isActive: Bool {
            return deallocatedAt == nil
        }
    }
    
    // MARK: - Published State
    
    @Published public private(set) var currentMemoryUsage: MemoryUsage
    @Published public private(set) var memoryHistory: [MemoryUsage] = []
    @Published public private(set) var trackedObjects: [String: ObjectLifecycle] = [:]
    @Published public private(set) var detectedLeaks: [ObjectLifecycle] = []
    @Published public private(set) var isMonitoring = false
    @Published public private(set) var cleanupOperationsCount = 0
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let monitoringInterval: TimeInterval = 5.0 // 5 seconds
        static let historyLimit = 100
        static let leakDetectionThreshold: TimeInterval = 300.0 // 5 minutes
        static let singletonLeakThreshold: TimeInterval = 3600.0 // 1 hour for singleton services
        static let emergencyCleanupThreshold: Double = 90.0
        static let warningThreshold: Double = 75.0
        
        // Singleton service class names that are expected to live for the app lifecycle
        static let singletonServiceClasses: Set<String> = [
            "BackgroundVisionProcessor",
            "PhotoLibraryService", 
            "BackgroundSemanticProcessor",
            "BackgroundOCRProcessor",
            "ThumbnailService",
            "SettingsService",
            "TaskManager",
            "TaskCoordinator",
            "MemoryManager",
            "WeakReferenceManager"
        ]
        
        // ViewModels and coordinators that can legitimately live for extended periods
        static let longLivedViewClasses: Set<String> = [
            "GalleryModeViewModel",
            "SearchCoordinator",
            "ModeCoordinator",
            "SmartSuggestionsService"
        ]
    }
    
    // MARK: - Internal State
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "MemoryManager")
    private var monitoringTimer: Timer?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var cleanupHandlers: [String: () async -> Void] = [:]
    private var weakReferences: NSHashTable<AnyObject> = NSHashTable.weakObjects()
    
    // MARK: - Initialization
    
    private init() {
        self.currentMemoryUsage = MemoryUsage(
            totalMemory: 0,
            usedMemory: 0,
            availableMemory: 0,
            memoryPressure: .normal,
            timestamp: Date()
        )
        
        setupMemoryPressureMonitoring()
        setupNotificationObservers()
    }
    
    deinit {
        // Clean up synchronously to avoid capture issues
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        // Note: Cannot modify @Published properties from deinit
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Memory Management
    
    /// Start comprehensive memory monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start periodic memory usage monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: Configuration.monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMemoryUsage()
                await self?.detectMemoryLeaks()
                await self?.performAutomaticCleanup()
            }
        }
        
        logger.info("MemoryManager: Started comprehensive memory monitoring")
    }
    
    /// Stop memory monitoring
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        logger.info("MemoryManager: Stopped memory monitoring")
    }
    
    /// Register an object for lifecycle tracking
    /// - Parameters:
    ///   - object: Object to track
    ///   - className: Class name for identification
    public func trackObject<T: AnyObject>(_ object: T, className: String? = nil) {
        let instanceId = String(format: "%p", unsafeBitCast(object, to: Int.self))
        let finalClassName = className ?? String(describing: type(of: object))
        
        let lifecycle = ObjectLifecycle(
            className: finalClassName,
            instanceId: instanceId,
            createdAt: Date(),
            deallocatedAt: nil,
            retainCount: CFGetRetainCount(object),
            isLeaked: false
        )
        
        // Use detached task to avoid publishing changes warning during view updates
        Task.detached { @MainActor [weak self] in
            self?.trackedObjects[instanceId] = lifecycle
            self?.weakReferences.add(object)
        }
        
        logger.debug("MemoryManager: Tracking object \(finalClassName) [\(instanceId)]")
    }
    
    /// Untrack an object (called from deinit)
    /// - Parameter instanceId: Instance identifier
    public func untrackObject(instanceId: String) {
        // Use detached task to avoid publishing changes warning during view updates
        Task.detached { @MainActor [weak self] in
            guard let self = self, var lifecycle = self.trackedObjects[instanceId] else { return }
            
            lifecycle.deallocatedAt = Date()
            self.trackedObjects[instanceId] = lifecycle
            
            self.logger.debug("MemoryManager: Object deallocated \(lifecycle.className) [\(instanceId)] after \(lifecycle.lifetime?.formatted() ?? "unknown") seconds")
        }
    }
    
    /// Register a cleanup handler for a specific component
    /// - Parameters:
    ///   - identifier: Unique identifier for the cleanup handler
    ///   - handler: Cleanup operation to perform
    public func registerCleanupHandler(identifier: String, handler: @escaping () async -> Void) {
        cleanupHandlers[identifier] = handler
        logger.debug("MemoryManager: Registered cleanup handler: \(identifier)")
    }
    
    /// Unregister a cleanup handler
    /// - Parameter identifier: Identifier of the handler to remove
    public func unregisterCleanupHandler(identifier: String) {
        cleanupHandlers.removeValue(forKey: identifier)
        logger.debug("MemoryManager: Unregistered cleanup handler: \(identifier)")
    }
    
    /// Force immediate memory cleanup
    public func performEmergencyCleanup() async {
        logger.warning("MemoryManager: Performing emergency memory cleanup")
        
        // Execute all registered cleanup handlers
        for (identifier, handler) in cleanupHandlers {
            await handler()
            logger.info("MemoryManager: Executed cleanup handler: \(identifier)")
        }
        
        // Force garbage collection
        // Clear weak references
        weakReferences.removeAllObjects()
        
        // Trigger memory cleanup
        URLCache.shared.removeAllCachedResponses()
        
        // Clear image caches if available
        ThumbnailService.shared.forceClearAllCaches()
        
        cleanupOperationsCount += 1
        
        // Update memory usage after cleanup
        await updateMemoryUsage()
        
        logger.info("MemoryManager: Emergency cleanup completed")
    }
    
    /// Get memory usage for a specific component
    /// - Parameter componentName: Name of the component
    /// - Returns: Estimated memory usage in bytes
    public func getComponentMemoryUsage(componentName: String) -> UInt64 {
        // This would require more sophisticated tracking in a real implementation
        // For now, return estimated usage based on tracked objects
        let componentObjects = trackedObjects.values.filter { $0.className.contains(componentName) && $0.isActive }
        return UInt64(componentObjects.count * 1024) // Rough estimate
    }
    
    // MARK: - Memory Pressure Handling
    
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        
        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }
        
        memoryPressureSource?.resume()
    }
    
    private func handleMemoryPressure() async {
        logger.warning("MemoryManager: System memory pressure detected")
        
        await updateMemoryUsage()
        
        if currentMemoryUsage.memoryPressure == .critical || currentMemoryUsage.memoryPressure == .emergency {
            await performEmergencyCleanup()
        }
        
        // Notify TaskManager to cancel low priority tasks
        TaskManager.shared.cancelTasks(in: .cleanup)
        
        // Post notification for other components
        NotificationCenter.default.post(name: .memoryPressureDetected, object: currentMemoryUsage)
    }
    
    // MARK: - Memory Usage Monitoring
    
    private func updateMemoryUsage() async {
        let usage = getCurrentMemoryUsage()
        
        currentMemoryUsage = usage
        memoryHistory.append(usage)
        
        // Limit history size
        if memoryHistory.count > Configuration.historyLimit {
            memoryHistory.removeFirst(memoryHistory.count - Configuration.historyLimit)
        }
        
        // Log significant changes
        if usage.memoryPressure != .normal {
            logger.warning("MemoryManager: Memory pressure \(usage.memoryPressure.rawValue) - \(usage.usagePercentage.formatted(.number.precision(.fractionLength(1))))% used")
        }
    }
    
    private func getCurrentMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        let usedMemory: UInt64
        let totalMemory: UInt64 = UInt64(ProcessInfo.processInfo.physicalMemory)
        
        if result == KERN_SUCCESS {
            usedMemory = UInt64(info.resident_size)
        } else {
            usedMemory = 0
        }
        
        let availableMemory = totalMemory > usedMemory ? totalMemory - usedMemory : 0
        let usagePercentage = totalMemory > 0 ? Double(usedMemory) / Double(totalMemory) * 100.0 : 0.0
        
        let pressureLevel: MemoryPressureLevel
        switch usagePercentage {
        case 0..<Configuration.warningThreshold:
            pressureLevel = .normal
        case Configuration.warningThreshold..<85.0:
            pressureLevel = .warning
        case 85.0..<Configuration.emergencyCleanupThreshold:
            pressureLevel = .critical
        default:
            pressureLevel = .emergency
        }
        
        return MemoryUsage(
            totalMemory: totalMemory,
            usedMemory: usedMemory,
            availableMemory: availableMemory,
            memoryPressure: pressureLevel,
            timestamp: Date()
        )
    }
    
    // MARK: - Leak Detection
    
    private func detectMemoryLeaks() async {
        let now = Date()
        var newLeaks: [ObjectLifecycle] = []
        
        for (instanceId, var lifecycle) in trackedObjects {
            // Skip already deallocated objects
            guard lifecycle.isActive else { continue }
            
            // Check if object has been alive too long
            let lifetime = now.timeIntervalSince(lifecycle.createdAt)
            
            // Use different thresholds based on object type
            let threshold: TimeInterval
            if Configuration.singletonServiceClasses.contains(lifecycle.className) {
                threshold = Configuration.singletonLeakThreshold
            } else if Configuration.longLivedViewClasses.contains(lifecycle.className) {
                threshold = Configuration.singletonLeakThreshold // Same threshold as singletons
            } else {
                threshold = Configuration.leakDetectionThreshold
            }
            
            if lifetime > threshold {
                // Check if the object is still in weak references (still alive)
                let isStillAlive = weakReferences.allObjects.contains { object in
                    String(format: "%p", unsafeBitCast(object, to: Int.self)) == instanceId
                }
                
                if isStillAlive {
                    lifecycle.isLeaked = true
                    trackedObjects[instanceId] = lifecycle
                    newLeaks.append(lifecycle)
                    
                    let objectType: String
                    if Configuration.singletonServiceClasses.contains(lifecycle.className) {
                        objectType = "singleton service"
                    } else if Configuration.longLivedViewClasses.contains(lifecycle.className) {
                        objectType = "long-lived view component"
                    } else {
                        objectType = "object"
                    }
                    
                    logger.warning("MemoryManager: Potential memory leak detected - \(lifecycle.className) [\(instanceId)] \(objectType) alive for \(lifetime.formatted()) seconds")
                }
            }
        }
        
        if !newLeaks.isEmpty {
            detectedLeaks.append(contentsOf: newLeaks)
            
            // Limit detected leaks history
            if detectedLeaks.count > 50 {
                detectedLeaks.removeFirst(detectedLeaks.count - 50)
            }
        }
    }
    
    // MARK: - Automatic Cleanup
    
    private func performAutomaticCleanup() async {
        guard currentMemoryUsage.memoryPressure != .normal else { return }
        
        // Perform graduated cleanup based on memory pressure
        switch currentMemoryUsage.memoryPressure {
        case .warning:
            await performLightCleanup()
        case .critical:
            await performMediumCleanup()
        case .emergency:
            await performEmergencyCleanup()
        case .normal:
            break
        }
    }
    
    private func performLightCleanup() async {
        logger.info("MemoryManager: Performing light cleanup")
        
        // Clear expired cache entries
        URLCache.shared.removeAllCachedResponses()
        
        cleanupOperationsCount += 1
    }
    
    private func performMediumCleanup() async {
        logger.info("MemoryManager: Performing medium cleanup")
        
        await performLightCleanup()
        
        // Execute non-critical cleanup handlers
        for (identifier, handler) in cleanupHandlers {
            if identifier.contains("cache") || identifier.contains("thumbnail") {
                await handler()
            }
        }
        
        cleanupOperationsCount += 1
    }
    
    // MARK: - Notification Setup
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performLightCleanup()
            }
        }
    }
    
    // MARK: - Debug and Monitoring
    
    public func getMemorySummary() -> String {
        let usage = currentMemoryUsage
        let activeObjects = trackedObjects.values.filter { $0.isActive }.count
        let leakedObjects = detectedLeaks.count
        
        return """
        Memory Manager Summary:
        - Memory Usage: \(usage.formattedUsedMemory) / \(usage.formattedTotalMemory) (\(usage.usagePercentage.formatted(.number.precision(.fractionLength(1))))%)
        - Memory Pressure: \(usage.memoryPressure.rawValue)
        - Active Objects: \(activeObjects)
        - Detected Leaks: \(leakedObjects)
        - Cleanup Operations: \(cleanupOperationsCount)
        - Monitoring: \(isMonitoring ? "Active" : "Inactive")
        """
    }
    
    public func getLeakReport() -> String {
        guard !detectedLeaks.isEmpty else {
            return "No memory leaks detected."
        }
        
        let leaksByClass = Dictionary(grouping: detectedLeaks, by: { $0.className })
        var report = "Memory Leak Report:\n"
        
        for (className, leaks) in leaksByClass.sorted(by: { $0.key < $1.key }) {
            report += "- \(className): \(leaks.count) instances\n"
        }
        
        return report
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let memoryPressureDetected = Notification.Name("memoryPressureDetected")
    static let memoryLeakDetected = Notification.Name("memoryLeakDetected")
}

// MARK: - Memory Tracking Protocol

public protocol MemoryTrackable: AnyObject {
    var memoryManagerInstanceId: String { get }
}

public extension MemoryTrackable {
    var memoryManagerInstanceId: String {
        String(format: "%p", unsafeBitCast(self, to: Int.self))
    }
    
    @MainActor func startMemoryTracking() {
        Task.detached { @MainActor in
            MemoryManager.shared.trackObject(self)
        }
    }
    
    @MainActor func stopMemoryTracking() {
        MemoryManager.shared.untrackObject(instanceId: memoryManagerInstanceId)
    }
}

// MARK: - Automatic Memory Tracking (Manual Implementation)
// Note: Macro removed to avoid external dependency issues
// Use MemoryTrackingProtocol directly for memory tracking