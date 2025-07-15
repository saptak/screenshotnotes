import Foundation
import SwiftUI
import UIKit
import OSLog

// MARK: - Recovery Strategy Protocol

protocol ErrorRecoveryStrategy {
    func execute() async
    static func strategy(for errorType: ErrorType, context: ErrorContext) -> ErrorRecoveryStrategy?
}

// MARK: - Retry Strategy Protocol

protocol RetryStrategy {
    func execute() async
    static func strategy(for errorType: ErrorType) -> RetryStrategy?
}

// MARK: - Network Recovery Strategies

struct NetworkRecoveryStrategy: ErrorRecoveryStrategy {
    let networkError: NetworkError
    let context: ErrorContext
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "NetworkRecovery")
    
    func execute() async {
        logger.info("Executing network recovery strategy for: \(networkError.rawValue)")
        
        switch networkError {
        case .noConnection:
            await handleConnectionLoss()
        case .timeout:
            await handleTimeout()
        case .serverError:
            await handleServerError()
        case .invalidResponse:
            await handleInvalidResponse()
        case .rateLimited:
            await handleRateLimit()
        }
    }
    
    static func strategy(for errorType: ErrorType, context: ErrorContext) -> ErrorRecoveryStrategy? {
        guard case .network(let networkError) = errorType else { return nil }
        return NetworkRecoveryStrategy(networkError: networkError, context: context)
    }
    
    private func handleConnectionLoss() async {
        // Start network monitoring
        await NetworkMonitor.shared.startMonitoring()
        
        // Queue operations for when connection returns
        await OfflineQueue.shared.queuePendingOperations(for: context)
        
        logger.info("Network recovery: Started monitoring and queued operations")
    }
    
    private func handleTimeout() async {
        // Increase timeout for next request
        await NetworkConfiguration.shared.increaseTimeout()
        
        logger.info("Network recovery: Increased timeout for subsequent requests")
    }
    
    private func handleServerError() async {
        // Exponential backoff before retry
        let delay = await ExponentialBackoff.shared.nextDelay()
        try? await Task.sleep(for: .seconds(delay))
        
        logger.info("Network recovery: Applied exponential backoff: \(delay)s")
    }
    
    private func handleInvalidResponse() async {
        // Clear any cached responses
        await ResponseCache.shared.clearCorruptedEntries()
        
        logger.info("Network recovery: Cleared corrupted cache entries")
    }
    
    private func handleRateLimit() async {
        // Implement exponential backoff with jitter
        let baseDelay = 60.0 // 1 minute base
        let jitter = Double.random(in: 0...30) // Up to 30 seconds jitter
        let totalDelay = baseDelay + jitter
        
        try? await Task.sleep(for: .seconds(totalDelay))
        
        logger.info("Network recovery: Rate limit backoff: \(totalDelay)s")
    }
}

// MARK: - Data Recovery Strategies

struct DataRecoveryStrategy: ErrorRecoveryStrategy {
    let dataError: DataError
    let context: ErrorContext
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "DataRecovery")
    
    func execute() async {
        logger.info("Executing data recovery strategy for: \(dataError.rawValue)")
        
        switch dataError {
        case .corruptedData:
            await handleCorruptedData()
        case .invalidFormat:
            await handleInvalidFormat()
        case .missingData:
            await handleMissingData()
        case .encodingFailed:
            await handleEncodingFailure()
        case .decodingFailed:
            await handleDecodingFailure()
        }
    }
    
    static func strategy(for errorType: ErrorType, context: ErrorContext) -> ErrorRecoveryStrategy? {
        guard case .data(let dataError) = errorType else { return nil }
        return DataRecoveryStrategy(dataError: dataError, context: context)
    }
    
    private func handleCorruptedData() async {
        // Attempt to recover from backup
        let _ = await BackupManager.shared.restoreFromBackup(for: context)
        
        // Reset to default values if needed
        await DataValidationManager.shared.resetCorruptedEntries(for: context)
        
        logger.info("Data recovery: Attempted backup restoration and reset corrupted entries")
    }
    
    private func handleInvalidFormat() async {
        // Attempt format migration
        await DataMigrator.shared.migrateInvalidFormat(for: context)
        
        logger.info("Data recovery: Attempted format migration")
    }
    
    private func handleMissingData() async {
        // Provide default values
        await DefaultValueProvider.shared.populateDefaults(for: context)
        
        // Attempt to regenerate missing data
        await DataRegenerator.shared.regenerateMissingData(for: context)
        
        logger.info("Data recovery: Populated defaults and attempted regeneration")
    }
    
    private func handleEncodingFailure() async {
        // Use alternative encoding method
        await AlternativeEncoder.shared.attemptEncoding(for: context)
        
        logger.info("Data recovery: Attempted alternative encoding")
    }
    
    private func handleDecodingFailure() async {
        // Use alternative decoding method
        await AlternativeDecoder.shared.attemptDecoding(for: context)
        
        logger.info("Data recovery: Attempted alternative decoding")
    }
}

// MARK: - Permission Recovery Strategies

struct PermissionRecoveryStrategy: ErrorRecoveryStrategy {
    let permissionError: PermissionError
    let context: ErrorContext
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "PermissionRecovery")
    
    func execute() async {
        logger.info("Executing permission recovery strategy for: \(permissionError.rawValue)")
        
        switch permissionError {
        case .photoLibraryDenied:
            await handlePhotoLibraryDenied()
        case .cameraAccess:
            await handleCameraAccess()
        case .accessDenied:
            await handleAccessDenied()
        case .insufficientPermissions:
            await handleInsufficientPermissions()
        }
    }
    
    static func strategy(for errorType: ErrorType, context: ErrorContext) -> ErrorRecoveryStrategy? {
        guard case .permission(let permissionError) = errorType else { return nil }
        return PermissionRecoveryStrategy(permissionError: permissionError, context: context)
    }
    
    private func handlePhotoLibraryDenied() async {
        // Show settings deep link
        await PermissionManager.shared.showPhotoLibrarySettings()
        
        // Enable limited functionality mode
        await FeatureManager.shared.enableLimitedMode(excluding: [.photoImport])
        
        logger.info("Permission recovery: Showed settings link and enabled limited mode")
    }
    
    private func handleCameraAccess() async {
        // Show settings deep link
        await PermissionManager.shared.showCameraSettings()
        
        logger.info("Permission recovery: Showed camera settings link")
    }
    
    private func handleAccessDenied() async {
        // Show generic settings guidance
        await PermissionManager.shared.showGeneralSettings()
        
        logger.info("Permission recovery: Showed general settings guidance")
    }
    
    private func handleInsufficientPermissions() async {
        // Re-request permissions
        await PermissionManager.shared.requestAllRequiredPermissions()
        
        logger.info("Permission recovery: Re-requested all required permissions")
    }
}

// MARK: - Resource Recovery Strategies

struct ResourceRecoveryStrategy: ErrorRecoveryStrategy {
    let resourceError: ResourceError
    let context: ErrorContext
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ResourceRecovery")
    
    func execute() async {
        logger.info("Executing resource recovery strategy for: \(resourceError.rawValue)")
        
        switch resourceError {
        case .memoryPressure:
            await handleMemoryPressure()
        case .diskSpaceLow:
            await handleDiskSpaceLow()
        case .thermalThrottling:
            await handleThermalThrottling()
        case .processingOverload:
            await handleProcessingOverload()
        }
    }
    
    static func strategy(for errorType: ErrorType, context: ErrorContext) -> ErrorRecoveryStrategy? {
        guard case .resource(let resourceError) = errorType else { return nil }
        return ResourceRecoveryStrategy(resourceError: resourceError, context: context)
    }
    
    private func handleMemoryPressure() async {
        // Clear caches
        await CacheManager.shared.clearLowPriorityCaches()
        
        // Reduce quality settings
        await QualityManager.shared.reduceQuality()
        
        // Pause non-essential operations
        await ErrorRecoveryTaskManager.shared.pauseNonEssentialTasks()
        
        logger.info("Resource recovery: Cleared caches, reduced quality, paused non-essential tasks")
    }
    
    private func handleDiskSpaceLow() async {
        // Clean up temporary files
        await ErrorRecoveryFileManager.shared.cleanupTemporaryFiles()
        
        // Compress old data
        await DataCompressor.shared.compressOldData()
        
        // Show storage management UI
        await StorageManager.shared.showStorageManagement()
        
        logger.info("Resource recovery: Cleaned temp files, compressed data, showed storage UI")
    }
    
    private func handleThermalThrottling() async {
        // Reduce CPU-intensive operations
        await ProcessingManager.shared.reduceCPUIntensiveOperations()
        
        // Pause background processing
        await BackgroundProcessor.shared.pauseProcessing()
        
        // Reduce animation complexity
        await AnimationManager.shared.reduceComplexity()
        
        logger.info("Resource recovery: Reduced CPU operations, paused background processing")
    }
    
    private func handleProcessingOverload() async {
        // Queue operations for later
        await OperationQueue.shared.queueLowPriorityOperations()
        
        // Reduce concurrent operations
        await ConcurrencyManager.shared.reduceConcurrency()
        
        logger.info("Resource recovery: Queued operations, reduced concurrency")
    }
}

// MARK: - Retry Strategies

struct ErrorRecoveryRetryStrategy: RetryStrategy {
    let operation: () async throws -> Void
    let maxRetries: Int
    let backoffStrategy: BackoffStrategy
    
    func execute() async {
        for attempt in 0..<maxRetries {
            do {
                try await operation()
                return // Success
            } catch {
                if attempt == maxRetries - 1 {
                    // Last attempt failed
                    break
                }
                
                // Wait before retry
                let delay = backoffStrategy.delay(for: attempt)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }
    
    static func strategy(for errorType: ErrorType) -> RetryStrategy? {
        guard case .network = errorType else { return nil }
        
        return ErrorRecoveryRetryStrategy(
            operation: { /* Will be set by caller */ },
            maxRetries: 3,
            backoffStrategy: .exponential
        )
    }
}

// MARK: - Supporting Classes (Placeholder implementations)

// These would be implemented as part of the broader error handling system

import Network

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .wifi
    @Published var isExpensive = false
    @Published var isConstrained = false
    
    // MARK: - Private Properties
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "NetworkMonitor")
    private var isMonitoring = false
    
    // MARK: - Network State Tracking
    private var connectionHistory: [ConnectionEvent] = []
    private var lastDisconnectionTime: Date?
    private var lastConnectionTime: Date?
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() async {
        guard !isMonitoring else { return }
        
        logger.info("Starting network monitoring")
        isMonitoring = true
        monitor.start(queue: monitorQueue)
    }
    
    func stopMonitoring() {
        logger.info("Stopping network monitoring")
        isMonitoring = false
        monitor.cancel()
    }
    
    // MARK: - Network State Information
    
    var connectionQuality: ConnectionQuality {
        if !isConnected { return .none }
        if isConstrained { return .poor }
        if isExpensive { return .limited }
        
        switch connectionType {
        case .wifi:
            return .excellent
        case .cellular:
            return .good
        case .ethernet:
            return .excellent
        case .other:
            return .fair
        }
    }
    
    var isOnlineCapable: Bool {
        return isConnected && connectionQuality != .none
    }
    
    func getDisconnectionDuration() -> TimeInterval? {
        guard let disconnectionTime = lastDisconnectionTime else { return nil }
        return Date().timeIntervalSince(disconnectionTime)
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        let newIsConnected = path.status == .satisfied
        
        // Update connection state
        isConnected = newIsConnected
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        // Update connection type
        connectionType = determineConnectionType(from: path)
        
        // Track connection events
        recordConnectionEvent(wasConnected: wasConnected, isConnected: newIsConnected)
        
        // Log connection state changes
        if wasConnected != newIsConnected {
            if newIsConnected {
                logger.info("Network connected: \(self.connectionType.rawValue), expensive: \(self.isExpensive), constrained: \(self.isConstrained)")
                lastConnectionTime = Date()
                
                // Notify about connection restoration
                NotificationCenter.default.post(name: .networkConnectionRestored, object: self)
            } else {
                logger.warning("Network disconnected")
                lastDisconnectionTime = Date()
                
                // Notify about connection loss
                NotificationCenter.default.post(name: .networkConnectionLost, object: self)
            }
        }
        
        // Notify about connection quality changes
        NotificationCenter.default.post(name: .networkQualityChanged, object: self, userInfo: [
            "quality": connectionQuality,
            "isExpensive": isExpensive,
            "isConstrained": isConstrained
        ])
    }
    
    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .other
        }
    }
    
    private func recordConnectionEvent(wasConnected: Bool, isConnected: Bool) {
        guard wasConnected != isConnected else { return }
        
        let event = ConnectionEvent(
            timestamp: Date(),
            type: isConnected ? .connected : .disconnected,
            connectionType: connectionType,
            isExpensive: isExpensive,
            isConstrained: isConstrained
        )
        
        connectionHistory.append(event)
        
        // Keep only last 100 events
        if connectionHistory.count > 100 {
            connectionHistory.removeFirst(connectionHistory.count - 100)
        }
    }
}

// MARK: - Supporting Types

enum ConnectionType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case other = "Other"
}

enum ConnectionQuality: String, CaseIterable {
    case none = "None"
    case poor = "Poor"
    case limited = "Limited"
    case fair = "Fair"
    case good = "Good"
    case excellent = "Excellent"
    
    var canPerformBackgroundTasks: Bool {
        switch self {
        case .none, .poor:
            return false
        case .limited, .fair, .good, .excellent:
            return true
        }
    }
    
    var shouldReduceQuality: Bool {
        switch self {
        case .none, .poor, .limited:
            return true
        case .fair, .good, .excellent:
            return false
        }
    }
}

struct ConnectionEvent {
    let timestamp: Date
    let type: EventType
    let connectionType: ConnectionType
    let isExpensive: Bool
    let isConstrained: Bool
    
    enum EventType {
        case connected
        case disconnected
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let networkConnectionLost = Notification.Name("networkConnectionLost")
    static let networkConnectionRestored = Notification.Name("networkConnectionRestored")
    static let networkQualityChanged = Notification.Name("networkQualityChanged")
}

@MainActor
class OfflineQueue: ObservableObject {
    static let shared = OfflineQueue()
    
    // MARK: - Published Properties
    @Published var queuedOperations: [QueuedOperation] = []
    @Published var isProcessingQueue = false
    @Published var lastSyncTime: Date?
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "OfflineQueue")
    private let maxQueueSize = 100
    private let persistenceKey = "OfflineQueue_Operations"
    private var syncTimer: Timer?
    
    private init() {
        loadPersistedOperations()
        setupNetworkObserver()
    }
    
    // MARK: - Public Methods
    
    func queuePendingOperations(for context: ErrorContext) async {
        logger.info("Queuing pending operations for context: \(context.rawValue)")
        
        // For now, create a generic retry operation
        let operation = QueuedOperation(
            id: UUID(),
            type: QueueOperationType.retry,
            context: context,
            data: [:],
            timestamp: Date(),
            retryCount: 0,
            maxRetries: 3,
            priority: OperationPriority.normal
        )
        
        await addOperation(operation)
    }
    
    func addOperation(_ operation: QueuedOperation) async {
        if queuedOperations.count >= maxQueueSize {
            logger.warning("Queue full, removing oldest operation")
            queuedOperations.removeFirst()
        }
        
        queuedOperations.append(operation)
        persistOperations()
        
        logger.info("Added operation \(operation.type.rawValue) to queue. Queue size: \(self.queuedOperations.count)")
        
        // Try to process immediately if we have connection
        if NetworkMonitor.shared.isOnlineCapable {
            await processQueue()
        }
    }
    
    func processQueue() async {
        guard !isProcessingQueue && !queuedOperations.isEmpty else { return }
        guard NetworkMonitor.shared.isOnlineCapable else {
            logger.info("No network connection, deferring queue processing")
            return
        }
        
        isProcessingQueue = true
        logger.info("Processing offline queue with \(self.queuedOperations.count) operations")
        
        var failedOperations: [QueuedOperation] = []
        
        for operation in queuedOperations {
            do {
                let success = try await executeOperation(operation)
                if !success {
                    let updatedOperation = operation.incrementRetryCount()
                    if updatedOperation.retryCount < updatedOperation.maxRetries {
                        failedOperations.append(updatedOperation)
                    } else {
                        logger.error("Operation \(operation.id) failed after \(operation.maxRetries) retries")
                    }
                }
            } catch {
                logger.error("Failed to execute operation \(operation.id): \(error)")
                let updatedOperation = operation.incrementRetryCount()
                if updatedOperation.retryCount < updatedOperation.maxRetries {
                    failedOperations.append(updatedOperation)
                }
            }
        }
        
        // Update queue with failed operations
        queuedOperations = failedOperations.sorted { $0.priority.rawValue > $1.priority.rawValue }
        persistOperations()
        
        lastSyncTime = Date()
        isProcessingQueue = false
        
        logger.info("Queue processing complete. Remaining operations: \(self.queuedOperations.count)")
    }
    
    func clearQueue() {
        queuedOperations.removeAll()
        persistOperations()
        logger.info("Queue cleared")
    }
    
    func removeOperation(_ operation: QueuedOperation) {
        queuedOperations.removeAll { $0.id == operation.id }
        persistOperations()
    }
    
    // MARK: - Private Methods
    
    private func executeOperation(_ operation: QueuedOperation) async throws -> Bool {
        logger.info("Executing operation: \(operation.type.rawValue) for context: \(operation.context.rawValue)")
        
        switch operation.type {
        case .retry:
            return await executeRetryOperation(operation)
        case .sync:
            return await executeSyncOperation(operation)
        case .upload:
            return await executeUploadOperation(operation)
        case .download:
            return await executeDownloadOperation(operation)
        case .backup:
            return await executeBackupOperation(operation)
        }
    }
    
    private func executeRetryOperation(_ operation: QueuedOperation) async -> Bool {
        // Generic retry operation - would be customized based on operation data
        try? await Task.sleep(for: .milliseconds(500))
        return true
    }
    
    private func executeSyncOperation(_ operation: QueuedOperation) async -> Bool {
        // Sync operation implementation
        logger.info("Executing sync operation")
        return true
    }
    
    private func executeUploadOperation(_ operation: QueuedOperation) async -> Bool {
        // Upload operation implementation
        logger.info("Executing upload operation")
        return true
    }
    
    private func executeDownloadOperation(_ operation: QueuedOperation) async -> Bool {
        // Download operation implementation
        logger.info("Executing download operation")
        return true
    }
    
    private func executeBackupOperation(_ operation: QueuedOperation) async -> Bool {
        // Backup operation implementation
        logger.info("Executing backup operation")
        return true
    }
    
    private func setupNetworkObserver() {
        NotificationCenter.default.addObserver(
            forName: .networkConnectionRestored,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.processQueue()
            }
        }
    }
    
    private func persistOperations() {
        do {
            let data = try JSONEncoder().encode(queuedOperations)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            logger.error("Failed to persist operations: \(error)")
        }
    }
    
    private func loadPersistedOperations() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        
        do {
            queuedOperations = try JSONDecoder().decode([QueuedOperation].self, from: data)
            logger.info("Loaded \(self.queuedOperations.count) persisted operations")
        } catch {
            logger.error("Failed to load persisted operations: \(error)")
        }
    }
}

// MARK: - Queued Operation Types

struct QueuedOperation: Codable, Identifiable {
    let id: UUID
    let type: QueueOperationType
    let context: ErrorContext
    let data: [String: String] // Simplified data storage
    let timestamp: Date
    let retryCount: Int
    let maxRetries: Int
    let priority: OperationPriority
    
    func incrementRetryCount() -> QueuedOperation {
        return QueuedOperation(
            id: id,
            type: type,
            context: context,
            data: data,
            timestamp: timestamp,
            retryCount: retryCount + 1,
            maxRetries: maxRetries,
            priority: priority
        )
    }
}

enum QueueOperationType: String, Codable, CaseIterable {
    case retry = "retry"
    case sync = "sync"
    case upload = "upload"
    case download = "download"
    case backup = "backup"
}

enum OperationPriority: Int, Codable, CaseIterable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
}

@MainActor
class NetworkConfiguration: ObservableObject {
    static let shared = NetworkConfiguration()
    
    // MARK: - Published Properties
    @Published var currentTimeoutInterval: TimeInterval = 30.0
    @Published var maxTimeoutInterval: TimeInterval = 120.0
    @Published var connectionRetryCount: Int = 3
    @Published var useAdaptiveTimeout: Bool = true
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "NetworkConfiguration")
    private let defaultTimeout: TimeInterval = 30.0
    private let timeoutIncrementStep: TimeInterval = 15.0
    private var networkQualityHistory: [ConnectionQuality] = []
    
    private init() {
        loadConfiguration()
        setupNetworkQualityObserver()
    }
    
    // MARK: - Public Methods
    
    func increaseTimeout() async {
        let newTimeout = min(currentTimeoutInterval + timeoutIncrementStep, maxTimeoutInterval)
        
        if newTimeout != currentTimeoutInterval {
            logger.info("Increasing network timeout from \\(currentTimeoutInterval)s to \\(newTimeout)s")
            currentTimeoutInterval = newTimeout
            saveConfiguration()
        } else {
            logger.warning("Timeout already at maximum: \\(maxTimeoutInterval)s")
        }
    }
    
    func resetTimeout() async {
        if currentTimeoutInterval != defaultTimeout {
            logger.info("Resetting network timeout to default: \\(defaultTimeout)s")
            currentTimeoutInterval = defaultTimeout
            saveConfiguration()
        }
    }
    
    func adjustTimeoutBasedOnQuality(_ quality: ConnectionQuality) async {
        guard useAdaptiveTimeout else { return }
        
        let recommendedTimeout: TimeInterval = {
            switch quality {
            case .none:
                return maxTimeoutInterval
            case .poor:
                return 90.0
            case .limited:
                return 60.0
            case .fair:
                return 45.0
            case .good:
                return 30.0
            case .excellent:
                return 20.0
            }
        }()
        
        if abs(currentTimeoutInterval - recommendedTimeout) > 5.0 {
            logger.info("Adjusting timeout based on connection quality \\(quality.rawValue): \\(recommendedTimeout)s")
            currentTimeoutInterval = recommendedTimeout
            saveConfiguration()
        }
    }
    
    func getOptimalRetryCount(for quality: ConnectionQuality) -> Int {
        switch quality {
        case .none, .poor:
            return 5
        case .limited:
            return 4
        case .fair:
            return 3
        case .good, .excellent:
            return 2
        }
    }
    
    func shouldUseBackgroundQueue(for quality: ConnectionQuality) -> Bool {
        return !quality.canPerformBackgroundTasks
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkQualityObserver() {
        NotificationCenter.default.addObserver(
            forName: .networkQualityChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let quality = notification.userInfo?["quality"] as? ConnectionQuality {
                Task {
                    await self?.handleQualityChange(quality)
                }
            }
        }
    }
    
    private func handleQualityChange(_ quality: ConnectionQuality) async {
        networkQualityHistory.append(quality)
        
        // Keep only last 10 quality measurements
        if networkQualityHistory.count > 10 {
            networkQualityHistory.removeFirst()
        }
        
        await adjustTimeoutBasedOnQuality(quality)
    }
    
    private func loadConfiguration() {
        let defaults = UserDefaults.standard
        currentTimeoutInterval = defaults.object(forKey: "NetworkConfig_Timeout") as? TimeInterval ?? defaultTimeout
        maxTimeoutInterval = defaults.object(forKey: "NetworkConfig_MaxTimeout") as? TimeInterval ?? 120.0
        connectionRetryCount = defaults.object(forKey: "NetworkConfig_RetryCount") as? Int ?? 3
        useAdaptiveTimeout = defaults.object(forKey: "NetworkConfig_AdaptiveTimeout") as? Bool ?? true
    }
    
    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(currentTimeoutInterval, forKey: "NetworkConfig_Timeout")
        defaults.set(maxTimeoutInterval, forKey: "NetworkConfig_MaxTimeout")
        defaults.set(connectionRetryCount, forKey: "NetworkConfig_RetryCount")
        defaults.set(useAdaptiveTimeout, forKey: "NetworkConfig_AdaptiveTimeout")
    }
}

@MainActor
class ExponentialBackoff: ObservableObject {
    static let shared = ExponentialBackoff()
    
    // MARK: - Published Properties
    @Published var currentAttempt: Int = 0
    @Published var totalBackoffTime: TimeInterval = 0.0
    @Published var lastDelayUsed: TimeInterval = 0.0
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ExponentialBackoff")
    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 60.0
    private let multiplier: Double = 2.0
    private let jitterRange: Double = 0.1
    private var backoffHistory: [BackoffRecord] = []
    
    private init() {}
    
    // MARK: - Public Methods
    
    func nextDelay(for attempt: Int = -1) -> TimeInterval {
        let attemptCount = attempt >= 0 ? attempt : currentAttempt
        
        // Calculate exponential delay
        let exponentialDelay = baseDelay * pow(multiplier, Double(attemptCount))
        
        // Apply maximum delay limit
        let cappedDelay = min(exponentialDelay, maxDelay)
        
        // Add jitter to prevent thundering herd
        let jitter = cappedDelay * jitterRange * (Double.random(in: -1.0...1.0))
        let finalDelay = max(baseDelay, cappedDelay + jitter)
        
        // Record this backoff attempt
        recordBackoffAttempt(attempt: attemptCount, delay: finalDelay)
        
        // Update state
        currentAttempt = attemptCount + 1
        totalBackoffTime += finalDelay
        lastDelayUsed = finalDelay
        
        logger.info("Backoff attempt \\(attemptCount): \\(finalDelay)s (total: \\(totalBackoffTime)s)")
        
        return finalDelay
    }
    
    func reset() {
        logger.info("Resetting exponential backoff state")
        currentAttempt = 0
        totalBackoffTime = 0.0
        lastDelayUsed = 0.0
        backoffHistory.removeAll()
    }
    
    func getBackoffStatistics() -> BackoffStatistics {
        return BackoffStatistics(
            totalAttempts: currentAttempt,
            totalBackoffTime: totalBackoffTime,
            averageDelay: currentAttempt > 0 ? totalBackoffTime / Double(currentAttempt) : 0.0,
            maxDelayUsed: backoffHistory.max { $0.delay < $1.delay }?.delay ?? 0.0,
            successRate: calculateSuccessRate()
        )
    }
    
    func getRecommendedDelay(for errorType: NetworkError, quality: ConnectionQuality) -> TimeInterval {
        let baseMultiplier: Double = {
            switch errorType {
            case .noConnection:
                return 3.0
            case .timeout:
                return 2.0
            case .serverError:
                return 1.5
            case .invalidResponse:
                return 1.0
            case .rateLimited:
                return 5.0
            }
        }()
        
        let qualityMultiplier: Double = {
            switch quality {
            case .none:
                return 4.0
            case .poor:
                return 3.0
            case .limited:
                return 2.0
            case .fair:
                return 1.5
            case .good:
                return 1.0
            case .excellent:
                return 0.8
            }
        }()
        
        let recommendedDelay = baseDelay * baseMultiplier * qualityMultiplier
        return min(recommendedDelay, maxDelay)
    }
    
    func shouldContinueRetrying(maxAttempts: Int, maxTotalTime: TimeInterval) -> Bool {
        let withinAttemptLimit = currentAttempt < maxAttempts
        let withinTimeLimit = totalBackoffTime < maxTotalTime
        
        logger.debug("Retry check: attempts \\(currentAttempt)/\\(maxAttempts), time \\(totalBackoffTime)/\\(maxTotalTime)")
        
        return withinAttemptLimit && withinTimeLimit
    }
    
    // MARK: - Private Methods
    
    private func recordBackoffAttempt(attempt: Int, delay: TimeInterval) {
        let record = BackoffRecord(
            attempt: attempt,
            delay: delay,
            timestamp: Date()
        )
        
        backoffHistory.append(record)
        
        // Keep only last 50 records
        if backoffHistory.count > 50 {
            backoffHistory.removeFirst()
        }
    }
    
    private func calculateSuccessRate() -> Double {
        guard !backoffHistory.isEmpty else { return 0.0 }
        
        // For now, assume a simple success rate based on attempts
        // In a real implementation, you'd track actual success/failure
        let recentAttempts = backoffHistory.suffix(10)
        let successfulAttempts = recentAttempts.filter { $0.delay < maxDelay * 0.5 }.count
        
        return Double(successfulAttempts) / Double(recentAttempts.count)
    }
}

// MARK: - Supporting Types

struct BackoffRecord {
    let attempt: Int
    let delay: TimeInterval
    let timestamp: Date
}

struct BackoffStatistics {
    let totalAttempts: Int
    let totalBackoffTime: TimeInterval
    let averageDelay: TimeInterval
    let maxDelayUsed: TimeInterval
    let successRate: Double
    
    var formattedTotalTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalBackoffTime) ?? "0s"
    }
}

@MainActor
class ResponseCache: NSObject, ObservableObject {
    static let shared = ResponseCache()
    
    // MARK: - Published Properties
    @Published var cacheSize: Int = 0
    @Published var hitRate: Double = 0.0
    @Published var corruptedEntries: Int = 0
    @Published var lastCleanupTime: Date?
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ResponseCache")
    private let cache = NSCache<NSString, CacheEntry>()
    private let maxCacheSize: Int = 100
    private let maxEntryAge: TimeInterval = 24 * 60 * 60 // 24 hours
    private var accessCount: Int = 0
    private var hitCount: Int = 0
    private var corruptedEntryKeys: Set<String> = []
    
    override private init() {
        super.init()
        setupCache()
        scheduleCleanup()
    }
    
    // MARK: - Public Methods
    
    func clearCorruptedEntries() async {
        logger.info("Clearing \\(corruptedEntryKeys.count) corrupted cache entries")
        
        for key in corruptedEntryKeys {
            cache.removeObject(forKey: NSString(string: key))
        }
        
        corruptedEntryKeys.removeAll()
        corruptedEntries = 0
        lastCleanupTime = Date()
        
        updateCacheStats()
        logger.info("Corrupted cache entries cleared")
    }
    
    func clearExpiredEntries() async {
        logger.info("Clearing expired cache entries")
        
        // Note: NSCache doesn't provide direct enumeration, so we'll track keys separately
        // In a real implementation, you'd use a different caching mechanism
        
        // Clear all entries for simplicity (in real implementation, track keys)
        cache.removeAllObjects()
        
        updateCacheStats()
        logger.info("Expired cache entries cleared")
    }
    
    func clearAllEntries() async {
        logger.info("Clearing all cache entries")
        
        cache.removeAllObjects()
        corruptedEntryKeys.removeAll()
        corruptedEntries = 0
        lastCleanupTime = Date()
        
        updateCacheStats()
        logger.info("All cache entries cleared")
    }
    
    func getCacheEntry(for key: String) -> CacheEntry? {
        accessCount += 1
        
        let nsKey = NSString(string: key)
        
        guard let entry = cache.object(forKey: nsKey) else {
            updateHitRate()
            return nil
        }
        
        // Check if entry is expired
        if Date().timeIntervalSince(entry.timestamp) > maxEntryAge {
            cache.removeObject(forKey: nsKey)
            updateHitRate()
            return nil
        }
        
        // Check if entry is corrupted
        if corruptedEntryKeys.contains(key) {
            cache.removeObject(forKey: nsKey)
            corruptedEntryKeys.remove(key)
            updateHitRate()
            return nil
        }
        
        hitCount += 1
        updateHitRate()
        return entry
    }
    
    func setCacheEntry(_ entry: CacheEntry, for key: String) {
        let nsKey = NSString(string: key)
        cache.setObject(entry, forKey: nsKey)
        
        // Remove from corrupted entries if it was there
        corruptedEntryKeys.remove(key)
        
        updateCacheStats()
    }
    
    func markAsCorrupted(_ key: String) {
        logger.warning("Marking cache entry as corrupted: \\(key)")
        corruptedEntryKeys.insert(key)
        corruptedEntries = corruptedEntryKeys.count
        
        let nsKey = NSString(string: key)
        cache.removeObject(forKey: nsKey)
        
        updateCacheStats()
    }
    
    func validateCacheIntegrity() async -> CacheValidationResult {
        logger.info("Validating cache integrity")
        
        let validationResult = CacheValidationResult(
            totalEntries: cacheSize,
            corruptedEntries: corruptedEntries,
            expiredEntries: 0, // Would need to implement proper tracking
            validEntries: max(0, cacheSize - corruptedEntries),
            hitRate: hitRate,
            lastValidation: Date()
        )
        
        logger.info("Cache validation complete: \\(validationResult.validEntries) valid, \\(validationResult.corruptedEntries) corrupted")
        
        return validationResult
    }
    
    func optimizeCache() async {
        logger.info("Optimizing cache")
        
        // Clear corrupted entries
        await clearCorruptedEntries()
        
        // Clear expired entries
        await clearExpiredEntries()
        
        // Reset hit rate calculation
        if accessCount > 1000 {
            accessCount = hitCount
            hitCount = Int(Double(hitCount) * 0.8) // Maintain some history
        }
        
        logger.info("Cache optimization complete")
    }
    
    // MARK: - Private Methods
    
    private func setupCache() {
        cache.countLimit = maxCacheSize
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        
        // Set up cache eviction delegate
        cache.delegate = self
    }
    
    private func scheduleCleanup() {
        Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { _ in // Every hour
            Task {
                await self.clearExpiredEntries()
            }
        }
    }
    
    private func updateCacheStats() {
        // Update cache size (approximation since NSCache doesn't provide direct count)
        cacheSize = max(0, cacheSize) // Placeholder - would need proper tracking
        
        updateHitRate()
    }
    
    private func updateHitRate() {
        hitRate = accessCount > 0 ? Double(hitCount) / Double(accessCount) : 0.0
    }
}

// MARK: - NSCacheDelegate

extension ResponseCache: NSCacheDelegate {
    nonisolated func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // Update cache size when objects are evicted
        Task { @MainActor in
            cacheSize = max(0, cacheSize - 1)
        }
    }
}

// MARK: - Supporting Types

class CacheEntry: NSObject {
    let data: Data
    let timestamp: Date
    let contentType: String
    let etag: String?
    let lastModified: Date?
    
    init(data: Data, contentType: String, etag: String? = nil, lastModified: Date? = nil) {
        self.data = data
        self.timestamp = Date()
        self.contentType = contentType
        self.etag = etag
        self.lastModified = lastModified
        super.init()
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 24 * 60 * 60 // 24 hours
    }
    
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
}

struct CacheValidationResult {
    let totalEntries: Int
    let corruptedEntries: Int
    let expiredEntries: Int
    let validEntries: Int
    let hitRate: Double
    let lastValidation: Date
    
    var healthScore: Double {
        guard totalEntries > 0 else { return 1.0 }
        return Double(validEntries) / Double(totalEntries)
    }
    
    var isHealthy: Bool {
        return healthScore >= 0.8 && hitRate >= 0.3
    }
}

@MainActor
class BackupManager: ObservableObject {
    static let shared = BackupManager()
    
    // MARK: - Published Properties
    @Published var isBackingUp = false
    @Published var lastBackupTime: Date?
    @Published var backupProgress: Double = 0.0
    @Published var availableBackups: [BackupRecord] = []
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "BackupManager")
    private let backupQueue = DispatchQueue(label: "BackupManager", qos: .utility)
    private let maxBackupCount = 5
    private let backupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // MARK: - Backup Configuration
    private var backupDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("Backups", isDirectory: true)
    }
    
    private init() {
        createBackupDirectoryIfNeeded()
        loadAvailableBackups()
        scheduleAutomaticBackup()
    }
    
    // MARK: - Public Methods
    
    func createBackup(for context: ErrorContext = .general, forced: Bool = false) async -> Bool {
        guard !isBackingUp || forced else {
            logger.warning("Backup already in progress")
            return false
        }
        
        // Check if backup is needed (unless forced)
        if !forced && !isBackupNeeded() {
            logger.info("Backup not needed at this time")
            return true
        }
        
        logger.info("Starting backup creation for context: \(context.rawValue)")
        isBackingUp = true
        backupProgress = 0.0
        
        do {
            let backupRecord = try await performBackup(context: context)
            await updateBackupProgress(0.9)
            
            // Add to available backups and clean up old ones
            availableBackups.insert(backupRecord, at: 0)
            await cleanupOldBackups()
            
            await updateBackupProgress(1.0)
            lastBackupTime = Date()
            
            logger.info("Backup completed successfully: \(backupRecord.filename)")
            
            // Save backup metadata
            saveBackupMetadata()
            
            isBackingUp = false
            return true
            
        } catch {
            logger.error("Backup failed: \(error)")
            isBackingUp = false
            backupProgress = 0.0
            return false
        }
    }
    
    func restoreFromBackup(for context: ErrorContext) async -> Bool {
        logger.info("Attempting backup restoration for context: \(context.rawValue)")
        
        // Find the most recent backup suitable for this context
        guard let backup = findSuitableBackup(for: context) else {
            logger.warning("No suitable backup found for context: \(context.rawValue)")
            return false
        }
        
        do {
            let success = try await performRestore(from: backup, context: context)
            if success {
                logger.info("Backup restoration completed successfully")
            } else {
                logger.error("Backup restoration failed")
            }
            return success
        } catch {
            logger.error("Backup restoration error: \(error)")
            return false
        }
    }
    
    func deleteBackup(_ backup: BackupRecord) async {
        logger.info("Deleting backup: \(backup.filename)")
        
        let backupURL = backupDirectory.appendingPathComponent(backup.filename)
        
        do {
            try FileManager.default.removeItem(at: backupURL)
            availableBackups.removeAll { $0.id == backup.id }
            saveBackupMetadata()
            logger.info("Backup deleted successfully")
        } catch {
            logger.error("Failed to delete backup: \(error)")
        }
    }
    
    func validateBackup(_ backup: BackupRecord) async -> Bool {
        let backupURL = backupDirectory.appendingPathComponent(backup.filename)
        
        do {
            let data = try Data(contentsOf: backupURL)
            let decodedBackup = try JSONDecoder().decode(BackupData.self, from: data)
            
            // Perform validation checks
            let isValid = decodedBackup.version == backup.version &&
                         decodedBackup.context == backup.context &&
                         !decodedBackup.screenshots.isEmpty
            
            logger.info("Backup validation result: \(isValid ? "valid" : "invalid")")
            return isValid
        } catch {
            logger.error("Backup validation failed: \(error)")
            return false
        }
    }
    
    // MARK: - Private Implementation
    
    private func performBackup(context: ErrorContext) async throws -> BackupRecord {
        await updateBackupProgress(0.1)
        
        // Create backup data structure
        let backupData = try await createBackupData(context: context)
        await updateBackupProgress(0.4)
        
        // Serialize backup data
        let jsonData = try JSONEncoder().encode(backupData)
        await updateBackupProgress(0.6)
        
        // Create backup file
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "backup_\(context.rawValue)_\(timestamp).json"
        let backupURL = backupDirectory.appendingPathComponent(filename)
        
        try jsonData.write(to: backupURL)
        await updateBackupProgress(0.8)
        
        // Create backup record
        let backupRecord = BackupRecord(
            id: UUID(),
            filename: filename,
            context: context,
            timestamp: Date(),
            size: jsonData.count,
            version: "1.0",
            screenshotCount: backupData.screenshots.count,
            checksum: calculateChecksum(data: jsonData)
        )
        
        return backupRecord
    }
    
    private func createBackupData(context: ErrorContext) async throws -> BackupData {
        // This would typically integrate with your SwiftData model context
        // For now, creating a placeholder structure
        
        let screenshots: [BackupScreenshot] = []
        let settings: [String: String] = [:]
        let collections: [BackupCollection] = []
        
        return BackupData(
            version: "1.0",
            context: context,
            timestamp: Date(),
            screenshots: screenshots,
            settings: settings,
            collections: collections,
            metadata: [
                "device": UIDevice.current.model,
                "osVersion": UIDevice.current.systemVersion,
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            ]
        )
    }
    
    private func performRestore(from backup: BackupRecord, context: ErrorContext) async throws -> Bool {
        let backupURL = backupDirectory.appendingPathComponent(backup.filename)
        
        // Load backup data
        let data = try Data(contentsOf: backupURL)
        let backupData = try JSONDecoder().decode(BackupData.self, from: data)
        
        // Validate backup integrity
        guard await validateBackupIntegrity(backupData, expectedChecksum: backup.checksum) else {
            throw BackupError.corruptedBackup
        }
        
        // Perform context-specific restoration
        switch context {
        case .general:
            return try await restoreGeneralData(backupData)
        case .photoImport:
            return try await restorePhotoImportData(backupData)
        case .ocr:
            return try await restoreOCRData(backupData)
        case .search:
            return try await restoreSearchData(backupData)
        case .mindMap:
            return try await restoreMindMapData(backupData)
        case .sync:
            return try await restoreSyncData(backupData)
        case .ui:
            return try await restoreUIData(backupData)
        case .background:
            return try await restoreBackgroundData(backupData)
        }
    }
    
    private func restoreGeneralData(_ backupData: BackupData) async throws -> Bool {
        logger.info("Restoring general data from backup")
        // Implement general data restoration
        return true
    }
    
    private func restorePhotoImportData(_ backupData: BackupData) async throws -> Bool {
        logger.info("Restoring photo import data from backup")
        // Implement photo import specific restoration
        return true
    }
    
    private func restoreOCRData(_ backupData: BackupData) async throws -> Bool {
        logger.info("Restoring OCR data from backup")
        // Implement OCR specific restoration
        return true
    }
    
    private func restoreSearchData(_ backupData: BackupData) async throws -> Bool {
        logger.info("Restoring search data from backup")
        // Implement search specific restoration
        return true
    }
    
    private func restoreMindMapData(_ backupData: BackupData) async throws -> Bool {
        logger.info("Restoring mind map data from backup")
        // Implement mind map specific restoration
        return true
    }
    
    private func restoreSyncData(_ backupData: BackupData) async throws -> Bool {
        logger.info("Restoring sync data from backup")
        // Implement sync specific restoration
        return true
    }
    
    private func restoreUIData(_ backupData: BackupData) async throws -> Bool {
        logger.info("Restoring UI data from backup")
        // Implement UI specific restoration
        return true
    }
    
    private func restoreBackgroundData(_ backupData: BackupData) async throws -> Bool {
        logger.info("Restoring background data from backup")
        // Implement background processing specific restoration
        return true
    }
    
    private func findSuitableBackup(for context: ErrorContext) -> BackupRecord? {
        // Find the most recent backup that matches the context or is general
        return availableBackups.first { backup in
            backup.context == context || backup.context == .general
        }
    }
    
    private func isBackupNeeded() -> Bool {
        guard let lastBackup = lastBackupTime else { return true }
        return Date().timeIntervalSince(lastBackup) >= backupInterval
    }
    
    private func cleanupOldBackups() async {
        guard availableBackups.count > maxBackupCount else { return }
        
        let backupsToRemove = Array(availableBackups.dropFirst(maxBackupCount))
        
        for backup in backupsToRemove {
            await deleteBackup(backup)
        }
    }
    
    private func createBackupDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create backup directory: \(error)")
        }
    }
    
    private func loadAvailableBackups() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            var backups: [BackupRecord] = []
            
            for file in files where file.pathExtension == "json" {
                if let backup = loadBackupRecord(from: file) {
                    backups.append(backup)
                }
            }
            
            // Sort by timestamp (newest first)
            availableBackups = backups.sorted { $0.timestamp > $1.timestamp }
            
            // Load last backup time
            if let lastBackup = availableBackups.first {
                lastBackupTime = lastBackup.timestamp
            }
            
        } catch {
            logger.error("Failed to load available backups: \(error)")
        }
    }
    
    private func loadBackupRecord(from url: URL) -> BackupRecord? {
        do {
            let data = try Data(contentsOf: url)
            let backupData = try JSONDecoder().decode(BackupData.self, from: data)
            
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int ?? 0
            
            return BackupRecord(
                id: UUID(),
                filename: url.lastPathComponent,
                context: backupData.context,
                timestamp: backupData.timestamp,
                size: fileSize,
                version: backupData.version,
                screenshotCount: backupData.screenshots.count,
                checksum: calculateChecksum(data: data)
            )
        } catch {
            logger.error("Failed to load backup record from \(url.path): \(error)")
            return nil
        }
    }
    
    private func saveBackupMetadata() {
        // Save backup metadata to UserDefaults for quick access
        if let encoded = try? JSONEncoder().encode(availableBackups) {
            UserDefaults.standard.set(encoded, forKey: "BackupManager_Metadata")
        }
        
        if let lastBackup = lastBackupTime {
            UserDefaults.standard.set(lastBackup, forKey: "BackupManager_LastBackupTime")
        }
    }
    
    private func calculateChecksum(data: Data) -> String {
        return data.base64EncodedString().prefix(32).description
    }
    
    private func validateBackupIntegrity(_ backupData: BackupData, expectedChecksum: String) async -> Bool {
        do {
            let data = try JSONEncoder().encode(backupData)
            let calculatedChecksum = calculateChecksum(data: data)
            return calculatedChecksum == expectedChecksum
        } catch {
            logger.error("Failed to validate backup integrity: \(error)")
            return false
        }
    }
    
    private func updateBackupProgress(_ progress: Double) async {
        await MainActor.run {
            backupProgress = max(0.0, min(1.0, progress))
        }
    }
    
    private func scheduleAutomaticBackup() {
        // Schedule automatic backups using Timer or background tasks
        Timer.scheduledTimer(withTimeInterval: backupInterval, repeats: true) { _ in
            Task {
                await self.createBackup(for: .general)
            }
        }
    }
}

// MARK: - Backup Data Structures

struct BackupRecord: Codable, Identifiable {
    let id: UUID
    let filename: String
    let context: ErrorContext
    let timestamp: Date
    let size: Int
    let version: String
    let screenshotCount: Int
    let checksum: String
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

struct BackupData: Codable {
    let version: String
    let context: ErrorContext
    let timestamp: Date
    let screenshots: [BackupScreenshot]
    let settings: [String: String]
    let collections: [BackupCollection]
    let metadata: [String: String]
}

struct BackupScreenshot: Codable {
    let id: UUID
    let filename: String
    let timestamp: Date
    let extractedText: String?
    let userNotes: String?
    let userTags: [String]?
    let isFavorite: Bool
    let dominantColors: [String]
    let semanticTags: BackupSemanticTags?
    let imageDataBase64: String
}

struct BackupSemanticTags: Codable {
    let tags: [BackupSemanticTag]
    let lastAnalysis: Date
    let confidence: Double
}

struct BackupSemanticTag: Codable {
    let id: String
    let type: String
    let displayName: String
    let confidence: Double
    let normalizedValue: String
}

struct BackupCollection: Codable {
    let id: UUID
    let name: String
    let creationDate: Date
    let screenshotIds: [UUID]
    let description: String?
}

// MARK: - Backup Errors

enum BackupError: LocalizedError {
    case creationFailed
    case corruptedBackup
    case restorationFailed
    case invalidBackupData
    case insufficientSpace
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "Failed to create backup"
        case .corruptedBackup:
            return "Backup file is corrupted"
        case .restorationFailed:
            return "Failed to restore from backup"
        case .invalidBackupData:
            return "Invalid backup data format"
        case .insufficientSpace:
            return "Insufficient storage space for backup"
        case .permissionDenied:
            return "Permission denied for backup operation"
        }
    }
}

@MainActor
class DataValidationManager: ObservableObject {
    static let shared = DataValidationManager()
    
    // MARK: - Published Properties
    @Published var isValidating = false
    @Published var validationProgress: Double = 0.0
    @Published var corruptedEntries: Int = 0
    @Published var validatedEntries: Int = 0
    @Published var lastValidationTime: Date?
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "DataValidationManager")
    private let validationQueue = DispatchQueue(label: "DataValidationManager", qos: .utility)
    private var validationHistory: [ValidationRecord] = []
    
    private init() {}
    
    // MARK: - Public Methods
    
    func resetCorruptedEntries(for context: ErrorContext) async {
        logger.info("Resetting corrupted entries for context: \(context.rawValue)")
        
        isValidating = true
        validationProgress = 0.0
        
        do {
            let resetCount = try await performReset(context: context)
            
            logger.info("Reset \(resetCount) corrupted entries for context: \(context.rawValue)")
            
            // Record validation
            recordValidation(context: context, resetCount: resetCount, success: true)
            
        } catch {
            logger.error("Failed to reset corrupted entries: \(error)")
            recordValidation(context: context, resetCount: 0, success: false)
        }
        
        isValidating = false
        validationProgress = 1.0
        lastValidationTime = Date()
    }
    
    func validateDataIntegrity(for context: ErrorContext) async -> DataValidationResult {
        logger.info("Validating data integrity for context: \(context.rawValue)")
        
        isValidating = true
        validationProgress = 0.0
        
        do {
            let result = try await performValidation(context: context)
            
            corruptedEntries = result.corruptedEntries
            validatedEntries = result.validEntries
            
            logger.info("Validation complete: \(result.validEntries) valid, \(result.corruptedEntries) corrupted")
            
            recordValidation(context: context, resetCount: 0, success: true)
            
            isValidating = false
            validationProgress = 1.0
            lastValidationTime = Date()
            
            return result
            
        } catch {
            logger.error("Data validation failed: \(error)")
            
            recordValidation(context: context, resetCount: 0, success: false)
            
            isValidating = false
            validationProgress = 0.0
            
            return DataValidationResult(
                context: context,
                totalEntries: 0,
                validEntries: 0,
                corruptedEntries: 0,
                fixedEntries: 0,
                validationTime: Date(),
                success: false,
                errorMessage: error.localizedDescription
            )
        }
    }
    
    func fixCorruptedData(for context: ErrorContext) async -> DataFixResult {
        logger.info("Fixing corrupted data for context: \(context.rawValue)")
        
        isValidating = true
        validationProgress = 0.0
        
        do {
            let result = try await performDataFix(context: context)
            
            logger.info("Data fix complete: \(result.fixedEntries) fixed, \(result.remainingCorrupted) remain corrupted")
            
            isValidating = false
            validationProgress = 1.0
            
            return result
            
        } catch {
            logger.error("Data fix failed: \(error)")
            
            isValidating = false
            validationProgress = 0.0
            
            return DataFixResult(
                context: context,
                fixedEntries: 0,
                remainingCorrupted: 0,
                fixTime: Date(),
                success: false,
                errorMessage: error.localizedDescription
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func performReset(context: ErrorContext) async throws -> Int {
        await updateValidationProgress(0.1)
        
        var resetCount = 0
        
        switch context {
        case .general:
            resetCount = try await resetGeneralData()
        case .photoImport:
            resetCount = try await resetPhotoImportData()
        case .ocr:
            resetCount = try await resetOCRData()
        case .search:
            resetCount = try await resetSearchData()
        case .mindMap:
            resetCount = try await resetMindMapData()
        case .sync:
            resetCount = try await resetSyncData()
        case .ui:
            resetCount = try await resetUIData()
        case .background:
            resetCount = try await resetBackgroundData()
        }
        
        await updateValidationProgress(1.0)
        
        return resetCount
    }
    
    private func performValidation(context: ErrorContext) async throws -> DataValidationResult {
        await updateValidationProgress(0.1)
        
        var validEntries = 0
        var corruptedEntries = 0
        var totalEntries = 0
        
        switch context {
        case .general:
            (validEntries, corruptedEntries, totalEntries) = try await validateGeneralData()
        case .photoImport:
            (validEntries, corruptedEntries, totalEntries) = try await validatePhotoImportData()
        case .ocr:
            (validEntries, corruptedEntries, totalEntries) = try await validateOCRData()
        case .search:
            (validEntries, corruptedEntries, totalEntries) = try await validateSearchData()
        case .mindMap:
            (validEntries, corruptedEntries, totalEntries) = try await validateMindMapData()
        case .sync:
            (validEntries, corruptedEntries, totalEntries) = try await validateSyncData()
        case .ui:
            (validEntries, corruptedEntries, totalEntries) = try await validateUIData()
        case .background:
            (validEntries, corruptedEntries, totalEntries) = try await validateBackgroundData()
        }
        
        await updateValidationProgress(1.0)
        
        return DataValidationResult(
            context: context,
            totalEntries: totalEntries,
            validEntries: validEntries,
            corruptedEntries: corruptedEntries,
            fixedEntries: 0,
            validationTime: Date(),
            success: true,
            errorMessage: nil
        )
    }
    
    private func performDataFix(context: ErrorContext) async throws -> DataFixResult {
        await updateValidationProgress(0.1)
        
        var fixedEntries = 0
        var remainingCorrupted = 0
        
        switch context {
        case .general:
            (fixedEntries, remainingCorrupted) = try await fixGeneralData()
        case .photoImport:
            (fixedEntries, remainingCorrupted) = try await fixPhotoImportData()
        case .ocr:
            (fixedEntries, remainingCorrupted) = try await fixOCRData()
        case .search:
            (fixedEntries, remainingCorrupted) = try await fixSearchData()
        case .mindMap:
            (fixedEntries, remainingCorrupted) = try await fixMindMapData()
        case .sync:
            (fixedEntries, remainingCorrupted) = try await fixSyncData()
        case .ui:
            (fixedEntries, remainingCorrupted) = try await fixUIData()
        case .background:
            (fixedEntries, remainingCorrupted) = try await fixBackgroundData()
        }
        
        await updateValidationProgress(1.0)
        
        return DataFixResult(
            context: context,
            fixedEntries: fixedEntries,
            remainingCorrupted: remainingCorrupted,
            fixTime: Date(),
            success: true,
            errorMessage: nil
        )
    }
    
    // MARK: - Context-Specific Implementations
    
    private func resetGeneralData() async throws -> Int {
        logger.info("Resetting general data")
        return 0
    }
    
    private func resetPhotoImportData() async throws -> Int {
        logger.info("Resetting photo import data")
        return 0
    }
    
    private func resetOCRData() async throws -> Int {
        logger.info("Resetting OCR data")
        return 0
    }
    
    private func resetSearchData() async throws -> Int {
        logger.info("Resetting search data")
        return 0
    }
    
    private func resetMindMapData() async throws -> Int {
        logger.info("Resetting mind map data")
        return 0
    }
    
    private func resetSyncData() async throws -> Int {
        logger.info("Resetting sync data")
        return 0
    }
    
    private func resetUIData() async throws -> Int {
        logger.info("Resetting UI data")
        return 0
    }
    
    private func resetBackgroundData() async throws -> Int {
        logger.info("Resetting background data")
        return 0
    }
    
    private func validateGeneralData() async throws -> (Int, Int, Int) {
        logger.info("Validating general data")
        await updateValidationProgress(0.3)
        return (0, 0, 0)
    }
    
    private func validatePhotoImportData() async throws -> (Int, Int, Int) {
        logger.info("Validating photo import data")
        await updateValidationProgress(0.3)
        return (0, 0, 0)
    }
    
    private func validateOCRData() async throws -> (Int, Int, Int) {
        logger.info("Validating OCR data")
        await updateValidationProgress(0.3)
        return (0, 0, 0)
    }
    
    private func validateSearchData() async throws -> (Int, Int, Int) {
        logger.info("Validating search data")
        await updateValidationProgress(0.3)
        return (0, 0, 0)
    }
    
    private func validateMindMapData() async throws -> (Int, Int, Int) {
        logger.info("Validating mind map data")
        await updateValidationProgress(0.3)
        return (0, 0, 0)
    }
    
    private func validateSyncData() async throws -> (Int, Int, Int) {
        logger.info("Validating sync data")
        await updateValidationProgress(0.3)
        return (0, 0, 0)
    }
    
    private func validateUIData() async throws -> (Int, Int, Int) {
        logger.info("Validating UI data")
        await updateValidationProgress(0.3)
        return (0, 0, 0)
    }
    
    private func validateBackgroundData() async throws -> (Int, Int, Int) {
        logger.info("Validating background data")
        await updateValidationProgress(0.3)
        return (0, 0, 0)
    }
    
    private func fixGeneralData() async throws -> (Int, Int) {
        logger.info("Fixing general data")
        await updateValidationProgress(0.5)
        return (0, 0)
    }
    
    private func fixPhotoImportData() async throws -> (Int, Int) {
        logger.info("Fixing photo import data")
        await updateValidationProgress(0.5)
        return (0, 0)
    }
    
    private func fixOCRData() async throws -> (Int, Int) {
        logger.info("Fixing OCR data")
        await updateValidationProgress(0.5)
        return (0, 0)
    }
    
    private func fixSearchData() async throws -> (Int, Int) {
        logger.info("Fixing search data")
        await updateValidationProgress(0.5)
        return (0, 0)
    }
    
    private func fixMindMapData() async throws -> (Int, Int) {
        logger.info("Fixing mind map data")
        await updateValidationProgress(0.5)
        return (0, 0)
    }
    
    private func fixSyncData() async throws -> (Int, Int) {
        logger.info("Fixing sync data")
        await updateValidationProgress(0.5)
        return (0, 0)
    }
    
    private func fixUIData() async throws -> (Int, Int) {
        logger.info("Fixing UI data")
        await updateValidationProgress(0.5)
        return (0, 0)
    }
    
    private func fixBackgroundData() async throws -> (Int, Int) {
        logger.info("Fixing background data")
        await updateValidationProgress(0.5)
        return (0, 0)
    }
    
    // MARK: - Helper Methods
    
    private func updateValidationProgress(_ progress: Double) async {
        await MainActor.run {
            validationProgress = max(0.0, min(1.0, progress))
        }
    }
    
    private func recordValidation(context: ErrorContext, resetCount: Int, success: Bool) {
        let record = ValidationRecord(
            context: context,
            resetCount: resetCount,
            timestamp: Date(),
            success: success
        )
        
        validationHistory.append(record)
        
        // Keep only last 100 records
        if validationHistory.count > 100 {
            validationHistory.removeFirst()
        }
    }
}

// MARK: - Supporting Types

struct ValidationRecord {
    let context: ErrorContext
    let resetCount: Int
    let timestamp: Date
    let success: Bool
}

struct DataValidationResult {
    let context: ErrorContext
    let totalEntries: Int
    let validEntries: Int
    let corruptedEntries: Int
    let fixedEntries: Int
    let validationTime: Date
    let success: Bool
    let errorMessage: String?
    
    var corruptionRate: Double {
        guard totalEntries > 0 else { return 0.0 }
        return Double(corruptedEntries) / Double(totalEntries)
    }
    
    var isHealthy: Bool {
        return success && corruptionRate <= 0.1
    }
}

struct DataFixResult {
    let context: ErrorContext
    let fixedEntries: Int
    let remainingCorrupted: Int
    let fixTime: Date
    let success: Bool
    let errorMessage: String?
    
    var fixSuccessRate: Double {
        let totalAttempted = fixedEntries + remainingCorrupted
        guard totalAttempted > 0 else { return 0.0 }
        return Double(fixedEntries) / Double(totalAttempted)
    }
}

@MainActor
class DataMigrator: ObservableObject {
    static let shared = DataMigrator()
    private init() {}
    
    func migrateInvalidFormat(for context: ErrorContext) async {
        // Implementation for data migration
    }
}

@MainActor
class DefaultValueProvider: ObservableObject {
    static let shared = DefaultValueProvider()
    private init() {}
    
    func populateDefaults(for context: ErrorContext) async {
        // Implementation for default value population
    }
}

@MainActor
class DataRegenerator: ObservableObject {
    static let shared = DataRegenerator()
    private init() {}
    
    func regenerateMissingData(for context: ErrorContext) async {
        // Implementation for data regeneration
    }
}

@MainActor
class AlternativeEncoder: ObservableObject {
    static let shared = AlternativeEncoder()
    private init() {}
    
    func attemptEncoding(for context: ErrorContext) async {
        // Implementation for alternative encoding
    }
}

@MainActor
class AlternativeDecoder: ObservableObject {
    static let shared = AlternativeDecoder()
    private init() {}
    
    func attemptDecoding(for context: ErrorContext) async {
        // Implementation for alternative decoding
    }
}

@MainActor
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    private init() {}
    
    func showPhotoLibrarySettings() async {
        await MainActor.run {
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
    
    func showCameraSettings() async {
        await showPhotoLibrarySettings() // Same settings page
    }
    
    func showGeneralSettings() async {
        await showPhotoLibrarySettings() // Same settings page
    }
    
    func requestAllRequiredPermissions() async {
        // Implementation for permission requests
    }
}

@MainActor
class FeatureManager: ObservableObject {
    static let shared = FeatureManager()
    private init() {}
    
    func enableLimitedMode(excluding features: [FeatureType]) async {
        // Implementation for limited mode
    }
}

enum FeatureType {
    case photoImport
    case backgroundProcessing
    case networkOperations
}

@MainActor
class CacheManager: ObservableObject {
    static let shared = CacheManager()
    private init() {}
    
    func clearLowPriorityCaches() async {
        // Implementation for cache management
    }
}

@MainActor
class QualityManager: ObservableObject {
    static let shared = QualityManager()
    private init() {}
    
    func reduceQuality() async {
        // Implementation for quality reduction
    }
}

@MainActor
class ErrorRecoveryTaskManager: ObservableObject {
    static let shared = ErrorRecoveryTaskManager()
    private init() {}
    
    func pauseNonEssentialTasks() async {
        // Implementation for task management
    }
}

@MainActor
class ErrorRecoveryFileManager: ObservableObject {
    static let shared = ErrorRecoveryFileManager()
    private init() {}
    
    func cleanupTemporaryFiles() async {
        // Implementation for file cleanup
    }
}

@MainActor
class DataCompressor: ObservableObject {
    static let shared = DataCompressor()
    private init() {}
    
    func compressOldData() async {
        // Implementation for data compression
    }
}

@MainActor
class StorageManager: ObservableObject {
    static let shared = StorageManager()
    private init() {}
    
    func showStorageManagement() async {
        // Implementation for storage management UI
    }
}

@MainActor
class ProcessingManager: ObservableObject {
    static let shared = ProcessingManager()
    private init() {}
    
    func reduceCPUIntensiveOperations() async {
        // Implementation for CPU management
    }
}

@MainActor
class BackgroundProcessor: ObservableObject {
    static let shared = BackgroundProcessor()
    private init() {}
    
    func pauseProcessing() async {
        // Implementation for background processing control
    }
}

@MainActor
class AnimationManager: ObservableObject {
    static let shared = AnimationManager()
    private init() {}
    
    func reduceComplexity() async {
        // Implementation for animation complexity reduction
    }
}

@MainActor
class OperationQueue: ObservableObject {
    static let shared = OperationQueue()
    private init() {}
    
    func queueLowPriorityOperations() async {
        // Implementation for operation queuing
    }
}

@MainActor
class ConcurrencyManager: ObservableObject {
    static let shared = ConcurrencyManager()
    private init() {}
    
    func reduceConcurrency() async {
        // Implementation for concurrency management
    }
}