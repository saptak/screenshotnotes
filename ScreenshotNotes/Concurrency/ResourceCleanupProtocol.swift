import Foundation
import SwiftUI

/// Protocol for implementing proper resource cleanup and memory management
/// Implements Iteration 8.5.3.2: Memory Management & Leak Prevention
public protocol ResourceCleanupProtocol: AnyObject {
    
    /// Perform lightweight cleanup operations
    /// Called during memory warnings or when resources need to be freed
    func performLightCleanup() async
    
    /// Perform comprehensive cleanup operations
    /// Called during critical memory pressure or app backgrounding
    func performDeepCleanup() async
    
    /// Get estimated memory usage for this component
    /// Returns memory usage in bytes
    func getEstimatedMemoryUsage() -> UInt64
    
    /// Get cleanup priority (higher numbers = higher priority)
    /// Used to determine cleanup order during memory pressure
    var cleanupPriority: Int { get }
    
    /// Identifier for this resource cleanup handler
    var cleanupIdentifier: String { get }
}

// MARK: - Default Implementation

public extension ResourceCleanupProtocol {
    
    var cleanupPriority: Int { 50 } // Default medium priority
    
    var cleanupIdentifier: String {
        String(describing: type(of: self))
    }
    
    func getEstimatedMemoryUsage() -> UInt64 {
        // Default implementation returns 0
        // Subclasses should override with actual memory usage
        return 0
    }
    
    /// Register this object with the MemoryManager for automatic cleanup
    func registerForAutomaticCleanup() {
        Task { @MainActor in
            MemoryManager.shared.registerCleanupHandler(identifier: cleanupIdentifier) { [weak self] in
                await self?.performLightCleanup()
            }
        }
    }
    
    /// Unregister from automatic cleanup
    func unregisterFromAutomaticCleanup() {
        Task { @MainActor in
            MemoryManager.shared.unregisterCleanupHandler(identifier: cleanupIdentifier)
        }
    }
}

// MARK: - Cache Cleanup Protocol

public protocol CacheCleanupProtocol: ResourceCleanupProtocol {
    
    /// Clear expired cache entries
    func clearExpiredCache() async
    
    /// Clear all cache entries
    func clearAllCache() async
    
    /// Get current cache size in bytes
    func getCacheSize() -> UInt64
    
    /// Get maximum cache size in bytes
    var maxCacheSize: UInt64 { get }
}

public extension CacheCleanupProtocol {
    
    func performLightCleanup() async {
        await clearExpiredCache()
    }
    
    func performDeepCleanup() async {
        await clearAllCache()
    }
    
    func getEstimatedMemoryUsage() -> UInt64 {
        return getCacheSize()
    }
    
    var cleanupPriority: Int { 30 } // Cache cleanup has lower priority
}

// MARK: - Task Cleanup Protocol

public protocol TaskCleanupProtocol: ResourceCleanupProtocol {
    
    /// Cancel all non-critical tasks
    func cancelNonCriticalTasks() async
    
    /// Cancel all tasks
    func cancelAllTasks() async
    
    /// Get count of active tasks
    func getActiveTaskCount() -> Int
}

public extension TaskCleanupProtocol {
    
    func performLightCleanup() async {
        await cancelNonCriticalTasks()
    }
    
    func performDeepCleanup() async {
        await cancelAllTasks()
    }
    
    func getEstimatedMemoryUsage() -> UInt64 {
        // Estimate based on active task count
        return UInt64(getActiveTaskCount() * 1024) // 1KB per task estimate
    }
    
    var cleanupPriority: Int { 80 } // Task cleanup has high priority
}

// MARK: - Image Cleanup Protocol

public protocol ImageCleanupProtocol: ResourceCleanupProtocol {
    
    /// Clear image caches
    func clearImageCache() async
    
    /// Clear thumbnails
    func clearThumbnails() async
    
    /// Compress images in memory
    func compressImagesInMemory() async
    
    /// Get image cache size
    func getImageCacheSize() -> UInt64
}

public extension ImageCleanupProtocol {
    
    func performLightCleanup() async {
        await compressImagesInMemory()
    }
    
    func performDeepCleanup() async {
        await clearImageCache()
        await clearThumbnails()
    }
    
    func getEstimatedMemoryUsage() -> UInt64 {
        return getImageCacheSize()
    }
    
    var cleanupPriority: Int { 40 } // Image cleanup has medium-low priority
}

// MARK: - Resource Cleanup Manager

@MainActor
public final class ResourceCleanupManager: ObservableObject {
    
    public static let shared = ResourceCleanupManager()
    
    // MARK: - State
    
    @Published public private(set) var registeredCleanupHandlers: [String: any ResourceCleanupProtocol] = [:]
    @Published public private(set) var lastCleanupTime: Date?
    @Published public private(set) var totalCleanupOperations = 0
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let automaticCleanupInterval: TimeInterval = 300.0 // 5 minutes
        static let memoryPressureThreshold: Double = 75.0
    }
    
    // MARK: - Internal State
    
    private var cleanupTimer: Timer?
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ResourceCleanupManager")
    
    // MARK: - Initialization
    
    private init() {
        setupAutomaticCleanup()
        setupMemoryPressureObserver()
    }
    
    deinit {
        cleanupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Registration
    
    /// Register a resource cleanup handler
    /// - Parameter handler: Object implementing ResourceCleanupProtocol
    public func register(_ handler: any ResourceCleanupProtocol) {
        registeredCleanupHandlers[handler.cleanupIdentifier] = handler
        logger.info("ResourceCleanupManager: Registered cleanup handler: \(handler.cleanupIdentifier)")
    }
    
    /// Unregister a resource cleanup handler
    /// - Parameter identifier: Cleanup identifier to remove
    public func unregister(identifier: String) {
        registeredCleanupHandlers.removeValue(forKey: identifier)
        logger.info("ResourceCleanupManager: Unregistered cleanup handler: \(identifier)")
    }
    
    /// Unregister a resource cleanup handler by object
    /// - Parameter handler: Object to unregister
    public func unregister(_ handler: any ResourceCleanupProtocol) {
        unregister(identifier: handler.cleanupIdentifier)
    }
    
    // MARK: - Cleanup Operations
    
    /// Perform light cleanup on all registered handlers
    public func performLightCleanup() async {
        logger.info("ResourceCleanupManager: Starting light cleanup")
        
        let sortedHandlers = registeredCleanupHandlers.values.sorted { $0.cleanupPriority > $1.cleanupPriority }
        
        for handler in sortedHandlers {
            do {
                await handler.performLightCleanup()
                logger.debug("ResourceCleanupManager: Light cleanup completed for \(handler.cleanupIdentifier)")
            } catch {
                logger.error("ResourceCleanupManager: Light cleanup failed for \(handler.cleanupIdentifier): \(error)")
            }
        }
        
        lastCleanupTime = Date()
        totalCleanupOperations += 1
        
        logger.info("ResourceCleanupManager: Light cleanup completed")
    }
    
    /// Perform deep cleanup on all registered handlers
    public func performDeepCleanup() async {
        logger.warning("ResourceCleanupManager: Starting deep cleanup")
        
        let sortedHandlers = registeredCleanupHandlers.values.sorted { $0.cleanupPriority > $1.cleanupPriority }
        
        for handler in sortedHandlers {
            do {
                await handler.performDeepCleanup()
                logger.debug("ResourceCleanupManager: Deep cleanup completed for \(handler.cleanupIdentifier)")
            } catch {
                logger.error("ResourceCleanupManager: Deep cleanup failed for \(handler.cleanupIdentifier): \(error)")
            }
        }
        
        lastCleanupTime = Date()
        totalCleanupOperations += 1
        
        logger.warning("ResourceCleanupManager: Deep cleanup completed")
    }
    
    /// Perform cleanup on specific handler types
    /// - Parameter handlerType: Type of handlers to clean up
    public func performCleanup<T>(for handlerType: T.Type) async where T: ResourceCleanupProtocol {
        logger.info("ResourceCleanupManager: Starting cleanup for \(String(describing: handlerType))")
        
        let matchingHandlers = registeredCleanupHandlers.values.compactMap { $0 as? T }
        let sortedHandlers = matchingHandlers.sorted { $0.cleanupPriority > $1.cleanupPriority }
        
        for handler in sortedHandlers {
            do {
                await handler.performLightCleanup()
                logger.debug("ResourceCleanupManager: Cleanup completed for \(handler.cleanupIdentifier)")
            } catch {
                logger.error("ResourceCleanupManager: Cleanup failed for \(handler.cleanupIdentifier): \(error)")
            }
        }
        
        totalCleanupOperations += 1
    }
    
    // MARK: - Memory Usage Analysis
    
    /// Get total estimated memory usage from all handlers
    /// - Returns: Total memory usage in bytes
    public func getTotalEstimatedMemoryUsage() -> UInt64 {
        return registeredCleanupHandlers.values.reduce(0) { total, handler in
            total + handler.getEstimatedMemoryUsage()
        }
    }
    
    /// Get memory usage breakdown by handler
    /// - Returns: Dictionary of handler identifier to memory usage
    public func getMemoryUsageBreakdown() -> [String: UInt64] {
        var breakdown: [String: UInt64] = [:]
        
        for handler in registeredCleanupHandlers.values {
            breakdown[handler.cleanupIdentifier] = handler.getEstimatedMemoryUsage()
        }
        
        return breakdown
    }
    
    /// Get handlers sorted by memory usage (highest first)
    /// - Returns: Array of handlers sorted by memory usage
    public func getHandlersByMemoryUsage() -> [(String, UInt64)] {
        let breakdown = getMemoryUsageBreakdown()
        return breakdown.sorted { $0.value > $1.value }
    }
    
    // MARK: - Automatic Cleanup
    
    private func setupAutomaticCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: Configuration.automaticCleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performAutomaticCleanupIfNeeded()
            }
        }
    }
    
    private func performAutomaticCleanupIfNeeded() async {
        let memoryUsage = MemoryManager.shared.currentMemoryUsage
        
        if memoryUsage.usagePercentage > Configuration.memoryPressureThreshold {
            logger.info("ResourceCleanupManager: Automatic cleanup triggered due to memory pressure")
            await performLightCleanup()
        }
    }
    
    private func setupMemoryPressureObserver() {
        NotificationCenter.default.addObserver(
            forName: .memoryPressureDetected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let memoryUsage = notification.object as? MemoryManager.MemoryUsage {
                    switch memoryUsage.memoryPressure {
                    case .warning:
                        await self?.performLightCleanup()
                    case .critical, .emergency:
                        await self?.performDeepCleanup()
                    case .normal:
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Debug Information
    
    public func getCleanupSummary() -> String {
        let totalMemory = getTotalEstimatedMemoryUsage()
        let handlerCount = registeredCleanupHandlers.count
        let lastCleanup = lastCleanupTime?.formatted() ?? "Never"
        
        return """
        Resource Cleanup Manager Summary:
        - Registered Handlers: \(handlerCount)
        - Total Estimated Memory: \(ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory))
        - Total Cleanup Operations: \(totalCleanupOperations)
        - Last Cleanup: \(lastCleanup)
        """
    }
    
    public func getDetailedReport() -> String {
        var report = getCleanupSummary() + "\n\nMemory Usage by Handler:\n"
        
        let handlersByMemory = getHandlersByMemoryUsage()
        for (identifier, memoryUsage) in handlersByMemory {
            let formattedMemory = ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
            report += "- \(identifier): \(formattedMemory)\n"
        }
        
        return report
    }
}

// MARK: - Convenience Extensions

public extension ResourceCleanupProtocol {
    
    /// Automatically register with ResourceCleanupManager
    func autoRegisterForCleanup() {
        Task { @MainActor in
            ResourceCleanupManager.shared.register(self)
        }
    }
    
    /// Automatically unregister from ResourceCleanupManager
    func autoUnregisterFromCleanup() {
        Task { @MainActor in
            ResourceCleanupManager.shared.unregister(self)
        }
    }
}

import os.log

extension Logger {
    static let resourceCleanup = Logger(subsystem: "com.screenshotnotes.app", category: "ResourceCleanup")
}