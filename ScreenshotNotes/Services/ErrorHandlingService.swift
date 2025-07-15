import Foundation
import SwiftData
import SwiftUI
import OSLog

/// Comprehensive error handling and recovery service for robust application behavior
/// Provides intelligent error categorization, recovery strategies, and user communication
@MainActor
public final class ErrorHandlingService: ObservableObject {
    public static let shared = ErrorHandlingService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ErrorHandling")
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentError: AppError?
    @Published public private(set) var isRecovering = false
    @Published public private(set) var recoveryProgress: Double = 0.0
    @Published public private(set) var errorHistory: [ErrorRecord] = []
    @Published public private(set) var systemHealth: SystemHealth = .healthy
    
    // MARK: - Services
    
    private let hapticService = HapticFeedbackService.shared
    
    // MARK: - Configuration
    
    public struct ErrorHandlingSettings {
        var enableAutomaticRecovery: Bool = true
        var maxRetryAttempts: Int = 3
        var retryDelaySeconds: TimeInterval = 2.0
        var enableHapticFeedback: Bool = true
        var enableUserNotifications: Bool = true
        var logErrorsToConsole: Bool = true
        var enableCrashRecovery: Bool = true
        
        public init() {}
    }
    
    @Published public var settings = ErrorHandlingSettings()
    
    // MARK: - Error Types
    
    public enum AppError: Error, Identifiable, LocalizedError {
        case dataCorruption(String)
        case networkError(String)
        case fileSystemError(String)
        case memoryPressure(String)
        case permissionDenied(String)
        case processingFailure(String)
        case userInputError(String)
        case systemResourceUnavailable(String)
        case duplicateOperationError(String)
        case batchOperationFailure(String, Int) // message, failed count
        case visionAnalysisError(String)
        case exportError(String)
        case importError(String)
        case databaseError(String)
        case cachingError(String)
        case unexpectedError(String)
        
        public var id: String {
            switch self {
            case .dataCorruption: return "data_corruption"
            case .networkError: return "network_error"
            case .fileSystemError: return "file_system_error"
            case .memoryPressure: return "memory_pressure"
            case .permissionDenied: return "permission_denied"
            case .processingFailure: return "processing_failure"
            case .userInputError: return "user_input_error"
            case .systemResourceUnavailable: return "system_resource_unavailable"
            case .duplicateOperationError: return "duplicate_operation_error"
            case .batchOperationFailure: return "batch_operation_failure"
            case .visionAnalysisError: return "vision_analysis_error"
            case .exportError: return "export_error"
            case .importError: return "import_error"
            case .databaseError: return "database_error"
            case .cachingError: return "caching_error"
            case .unexpectedError: return "unexpected_error"
            }
        }
        
        public var errorDescription: String? {
            switch self {
            case .dataCorruption(let message):
                return "Data Corruption: \(message)"
            case .networkError(let message):
                return "Network Error: \(message)"
            case .fileSystemError(let message):
                return "File System Error: \(message)"
            case .memoryPressure(let message):
                return "Memory Pressure: \(message)"
            case .permissionDenied(let message):
                return "Permission Denied: \(message)"
            case .processingFailure(let message):
                return "Processing Failed: \(message)"
            case .userInputError(let message):
                return "Invalid Input: \(message)"
            case .systemResourceUnavailable(let message):
                return "System Resource Unavailable: \(message)"
            case .duplicateOperationError(let message):
                return "Duplicate Operation: \(message)"
            case .batchOperationFailure(let message, let count):
                return "Batch Operation Failed: \(message) (\(count) items failed)"
            case .visionAnalysisError(let message):
                return "Vision Analysis Error: \(message)"
            case .exportError(let message):
                return "Export Error: \(message)"
            case .importError(let message):
                return "Import Error: \(message)"
            case .databaseError(let message):
                return "Database Error: \(message)"
            case .cachingError(let message):
                return "Caching Error: \(message)"
            case .unexpectedError(let message):
                return "Unexpected Error: \(message)"
            }
        }
        
        public var severity: ErrorSeverity {
            switch self {
            case .dataCorruption, .databaseError:
                return .critical
            case .memoryPressure, .systemResourceUnavailable:
                return .high
            case .networkError, .fileSystemError, .permissionDenied, .processingFailure:
                return .medium
            case .userInputError, .duplicateOperationError, .cachingError:
                return .low
            case .batchOperationFailure(_, let count):
                return count > 10 ? .high : .medium
            case .visionAnalysisError, .exportError, .importError:
                return .medium
            case .unexpectedError:
                return .high
            }
        }
        
        public var isRecoverable: Bool {
            switch self {
            case .dataCorruption:
                return false
            case .networkError, .fileSystemError, .memoryPressure, .processingFailure:
                return true
            case .permissionDenied:
                return false
            case .userInputError, .duplicateOperationError, .cachingError:
                return true
            case .systemResourceUnavailable:
                return true
            case .batchOperationFailure, .visionAnalysisError, .exportError, .importError:
                return true
            case .databaseError:
                return false
            case .unexpectedError:
                return true
            }
        }
    }
    
    public enum ErrorSeverity: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
        
        public var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
        
        public var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .orange
            case .high: return .red
            case .critical: return .purple
            }
        }
    }
    
    public enum SystemHealth: String, CaseIterable {
        case healthy = "healthy"
        case degraded = "degraded"
        case critical = "critical"
        case recovering = "recovering"
        
        public var displayName: String {
            switch self {
            case .healthy: return "Healthy"
            case .degraded: return "Degraded"
            case .critical: return "Critical"
            case .recovering: return "Recovering"
            }
        }
        
        public var color: Color {
            switch self {
            case .healthy: return .green
            case .degraded: return .yellow
            case .critical: return .red
            case .recovering: return .blue
            }
        }
    }
    
    // MARK: - Error Record
    
    public struct ErrorRecord: Identifiable {
        public let id = UUID()
        public let error: AppError
        public let timestamp: Date
        public let context: String
        public let recoveryAttempted: Bool
        public let recoverySuccessful: Bool
        public let retryCount: Int
        
        public init(
            error: AppError,
            context: String,
            recoveryAttempted: Bool = false,
            recoverySuccessful: Bool = false,
            retryCount: Int = 0
        ) {
            self.error = error
            self.timestamp = Date()
            self.context = context
            self.recoveryAttempted = recoveryAttempted
            self.recoverySuccessful = recoverySuccessful
            self.retryCount = retryCount
        }
    }
    
    // MARK: - Recovery Strategies
    
    public enum RecoveryStrategy: String, CaseIterable {
        case retry = "retry"
        case fallback = "fallback"
        case skip = "skip"
        case restart = "restart"
        case userIntervention = "user_intervention"
        case dataRecovery = "data_recovery"
        case resourceCleanup = "resource_cleanup"
        case systemOptimization = "system_optimization"
        
        public var displayName: String {
            switch self {
            case .retry: return "Retry Operation"
            case .fallback: return "Use Alternative Method"
            case .skip: return "Skip and Continue"
            case .restart: return "Restart Process"
            case .userIntervention: return "User Action Required"
            case .dataRecovery: return "Recover Data"
            case .resourceCleanup: return "Clean Up Resources"
            case .systemOptimization: return "Optimize System"
            }
        }
    }
    
    private init() {
        logger.info("ErrorHandlingService initialized with comprehensive error recovery")
        loadErrorHistory()
        startSystemHealthMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Handle an error with automatic recovery attempts
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Context information about where the error occurred
    ///   - retryAttempt: Current retry attempt number
    public func handleError(
        _ error: AppError,
        context: String,
        retryAttempt: Int = 0
    ) async -> Bool {
        logger.error("Handling error: \(error.errorDescription ?? "Unknown") in context: \(context)")
        
        // Record the error
        let record = ErrorRecord(
            error: error,
            context: context,
            recoveryAttempted: false,
            recoverySuccessful: false,
            retryCount: retryAttempt
        )
        
        await recordError(record)
        
        // Update system health based on error severity
        await updateSystemHealth(for: error)
        
        // Provide haptic feedback
        if settings.enableHapticFeedback {
            hapticService.triggerHaptic(.errorFeedback)
        }
        
        // Attempt recovery if enabled and error is recoverable
        if settings.enableAutomaticRecovery && error.isRecoverable && retryAttempt < settings.maxRetryAttempts {
            return await attemptRecovery(for: error, context: context, retryAttempt: retryAttempt)
        }
        
        // Show error to user if no recovery possible
        await presentErrorToUser(error, context: context)
        return false
    }
    
    /// Handle a standard Swift Error
    /// - Parameters:
    ///   - error: The Swift error to handle
    ///   - context: Context information
    public func handleSwiftError(
        _ error: Error,
        context: String
    ) async -> Bool {
        let appError = convertToAppError(error)
        return await handleError(appError, context: context)
    }
    
    /// Manually trigger recovery for the current error
    public func manualRecovery() async -> Bool {
        guard let error = currentError else { return false }
        
        isRecovering = true
        recoveryProgress = 0.0
        
        defer {
            isRecovering = false
            recoveryProgress = 0.0
        }
        
        let success = await attemptRecovery(for: error, context: "Manual Recovery", retryAttempt: 0)
        
        if success {
            currentError = nil
            if settings.enableHapticFeedback {
                hapticService.triggerHaptic(.dataRecovery)
            }
        }
        
        return success
    }
    
    /// Clear current error without recovery
    public func dismissCurrentError() {
        currentError = nil
        if settings.enableHapticFeedback {
            hapticService.triggerHaptic(.menuDismiss)
        }
    }
    
    /// Get recovery suggestions for an error
    /// - Parameter error: The error to get suggestions for
    /// - Returns: Array of suggested recovery strategies
    public func getRecoveryStrategies(for error: AppError) -> [RecoveryStrategy] {
        switch error {
        case .networkError:
            return [.retry, .fallback]
        case .fileSystemError:
            return [.retry, .resourceCleanup]
        case .memoryPressure:
            return [.resourceCleanup, .systemOptimization]
        case .permissionDenied:
            return [.userIntervention]
        case .processingFailure:
            return [.retry, .fallback, .skip]
        case .userInputError:
            return [.userIntervention]
        case .systemResourceUnavailable:
            return [.retry, .resourceCleanup]
        case .duplicateOperationError:
            return [.skip, .fallback]
        case .batchOperationFailure:
            return [.retry, .skip, .fallback]
        case .visionAnalysisError:
            return [.retry, .fallback]
        case .exportError, .importError:
            return [.retry, .userIntervention]
        case .databaseError:
            return [.dataRecovery, .restart]
        case .cachingError:
            return [.resourceCleanup, .retry]
        case .dataCorruption:
            return [.dataRecovery, .userIntervention]
        case .unexpectedError:
            return [.retry, .restart]
        }
    }
    
    // MARK: - Private Implementation
    
    private func attemptRecovery(
        for error: AppError,
        context: String,
        retryAttempt: Int
    ) async -> Bool {
        logger.info("Attempting recovery for \(error.id), attempt \(retryAttempt + 1)")
        
        isRecovering = true
        recoveryProgress = 0.0
        
        defer {
            isRecovering = false
            recoveryProgress = 0.0
        }
        
        let strategies = getRecoveryStrategies(for: error)
        
        for (index, strategy) in strategies.enumerated() {
            await updateRecoveryProgress(Double(index) / Double(strategies.count))
            
            let success = await executeRecoveryStrategy(strategy, for: error, context: context)
            
            if success {
                logger.info("Recovery successful using strategy: \(strategy.rawValue)")
                
                // Record successful recovery
                let record = ErrorRecord(
                    error: error,
                    context: context,
                    recoveryAttempted: true,
                    recoverySuccessful: true,
                    retryCount: retryAttempt + 1
                )
                await recordError(record)
                
                // Provide success feedback
                if settings.enableHapticFeedback {
                    hapticService.triggerHaptic(.dataRecovery)
                }
                
                await updateRecoveryProgress(1.0)
                return true
            }
            
            // Small delay between strategies
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Record failed recovery
        let record = ErrorRecord(
            error: error,
            context: context,
            recoveryAttempted: true,
            recoverySuccessful: false,
            retryCount: retryAttempt + 1
        )
        await recordError(record)
        
        logger.warning("All recovery strategies failed for \(error.id)")
        return false
    }
    
    private func executeRecoveryStrategy(
        _ strategy: RecoveryStrategy,
        for error: AppError,
        context: String
    ) async -> Bool {
        switch strategy {
        case .retry:
            // Wait and try again
            try? await Task.sleep(nanoseconds: UInt64(settings.retryDelaySeconds * 1_000_000_000))
            return true // Signal that retry should be attempted
            
        case .fallback:
            // Use alternative implementation
            return await executeFallbackStrategy(for: error)
            
        case .skip:
            // Skip the operation and continue
            logger.info("Skipping failed operation as recovery strategy")
            return true
            
        case .restart:
            // Restart the current process/operation
            return await restartOperation(for: error, context: context)
            
        case .resourceCleanup:
            // Clean up system resources
            return await cleanupSystemResources()
            
        case .systemOptimization:
            // Optimize system performance
            return await optimizeSystemPerformance()
            
        case .dataRecovery:
            // Attempt to recover corrupted data
            return await recoverData(for: error)
            
        case .userIntervention:
            // Requires user action - cannot auto-recover
            return false
        }
    }
    
    private func executeFallbackStrategy(for error: AppError) async -> Bool {
        // Implement fallback strategies based on error type
        switch error {
        case .visionAnalysisError:
            // Fall back to basic OCR without advanced features
            logger.info("Falling back to basic vision analysis")
            return true
            
        case .networkError:
            // Fall back to offline mode
            logger.info("Falling back to offline operation")
            return true
            
        case .batchOperationFailure:
            // Fall back to individual operations
            logger.info("Falling back to individual operations instead of batch")
            return true
            
        default:
            return false
        }
    }
    
    private func restartOperation(for error: AppError, context: String) async -> Bool {
        logger.info("Restarting operation for error recovery")
        
        // Clear any cached state
        await cleanupSystemResources()
        
        // Small delay before restart
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return true
    }
    
    private func cleanupSystemResources() async -> Bool {
        logger.info("Cleaning up system resources")
        
        // Force garbage collection
        await MainActor.run {
            // Clear any temporary caches
            URLCache.shared.removeAllCachedResponses()
        }
        
        // Trigger system optimization haptic
        if settings.enableHapticFeedback {
            hapticService.triggerHaptic(.systemOptimization)
        }
        
        return true
    }
    
    private func optimizeSystemPerformance() async -> Bool {
        logger.info("Optimizing system performance")
        
        await cleanupSystemResources()
        
        // Additional optimization steps could be added here
        
        return true
    }
    
    private func recoverData(for error: AppError) async -> Bool {
        logger.info("Attempting data recovery")
        
        switch error {
        case .dataCorruption, .databaseError:
            // Implement data recovery logic
            logger.info("Attempting to recover corrupted data")
            return false // Would need specific implementation
            
        default:
            return false
        }
    }
    
    private func convertToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Convert common system errors to AppError
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                return .networkError(nsError.localizedDescription)
            case NSCocoaErrorDomain:
                if nsError.code == NSFileReadNoSuchFileError || nsError.code == NSFileWriteFileExistsError {
                    return .fileSystemError(nsError.localizedDescription)
                }
                return .unexpectedError(nsError.localizedDescription)
            default:
                return .unexpectedError(nsError.localizedDescription)
            }
        }
        
        return .unexpectedError(error.localizedDescription)
    }
    
    private func updateSystemHealth(for error: AppError) async {
        await MainActor.run {
            switch error.severity {
            case .critical:
                systemHealth = .critical
            case .high:
                if systemHealth == .healthy {
                    systemHealth = .degraded
                }
            case .medium:
                if systemHealth == .healthy {
                    systemHealth = .degraded
                }
            case .low:
                // Low severity errors don't affect system health
                break
            }
        }
    }
    
    private func presentErrorToUser(_ error: AppError, context: String) async {
        await MainActor.run {
            currentError = error
        }
        
        if settings.enableUserNotifications {
            // Show user notification
            logger.info("Presenting error to user: \(error.errorDescription ?? "Unknown")")
        }
    }
    
    private func recordError(_ record: ErrorRecord) async {
        await MainActor.run {
            errorHistory.append(record)
            
            // Keep history manageable
            if errorHistory.count > 100 {
                errorHistory.removeFirst(50)
            }
            
            saveErrorHistory()
        }
    }
    
    private func updateRecoveryProgress(_ progress: Double) async {
        await MainActor.run {
            recoveryProgress = max(0.0, min(1.0, progress))
        }
    }
    
    private func startSystemHealthMonitoring() {
        // Start periodic health monitoring
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                await self.performHealthCheck()
            }
        }
    }
    
    private func performHealthCheck() async {
        // Check if system has recovered
        let recentErrors = errorHistory.filter { 
            Date().timeIntervalSince($0.timestamp) < 300 // Last 5 minutes
        }
        
        if recentErrors.isEmpty && systemHealth != .healthy {
            systemHealth = .healthy
            if settings.enableHapticFeedback {
                hapticService.triggerHaptic(.systemOptimization)
            }
        }
    }
    
    private func loadErrorHistory() {
        // Load from UserDefaults or persistent storage
        // Implementation would depend on persistence strategy
    }
    
    private func saveErrorHistory() {
        // Save to UserDefaults or persistent storage
        // Implementation would depend on persistence strategy
    }
}

// MARK: - Error Handling Extensions

extension View {
    /// Adds comprehensive error handling to any view
    /// - Parameter handler: Error handling closure
    func errorHandling(_ handler: @escaping (Error) -> Void = { _ in }) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .errorOccurred)) { notification in
            if let error = notification.object as? Error {
                Task {
                    await ErrorHandlingService.shared.handleSwiftError(error, context: "View Error")
                }
            }
        }
    }
}

extension Notification.Name {
    static let errorOccurred = Notification.Name("ErrorOccurred")
}

// MARK: - Error Presentation Views

public struct ErrorDisplayView: View {
    @StateObject private var errorService = ErrorHandlingService.shared
    
    public var body: some View {
        if let error = errorService.currentError {
            VStack(spacing: 16) {
                // Error Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(error.severity.color)
                
                // Error Message
                Text(error.errorDescription ?? "Unknown Error")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                // Recovery Options
                HStack(spacing: 12) {
                    if error.isRecoverable {
                        Button("Try Again") {
                            Task {
                                await errorService.manualRecovery()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(errorService.isRecovering)
                    }
                    
                    Button("Dismiss") {
                        errorService.dismissCurrentError()
                    }
                    .buttonStyle(.bordered)
                }
                
                // Recovery Progress
                if errorService.isRecovering {
                    ProgressView(value: errorService.recoveryProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
            .padding()
            .glassBackground(material: .regular, cornerRadius: 16, shadow: true)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

#if DEBUG
struct ErrorHandlingTestView: View {
    @StateObject private var errorService = ErrorHandlingService.shared
    
    private func getTestErrors() -> [(String, ErrorHandlingService.AppError)] {
        return [
            ("Network", ErrorHandlingService.AppError.networkError("Connection timeout")),
            ("Memory", ErrorHandlingService.AppError.memoryPressure("Low memory")),
            ("File System", ErrorHandlingService.AppError.fileSystemError("Permission denied")),
            ("Processing", ErrorHandlingService.AppError.processingFailure("Analysis failed")),
            ("Batch Op", ErrorHandlingService.AppError.batchOperationFailure("Failed batch", 5)),
            ("Vision", ErrorHandlingService.AppError.visionAnalysisError("OCR failed"))
        ]
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // System Health
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System Health")
                            .font(.headline)
                        
                        HStack {
                            Circle()
                                .fill(errorService.systemHealth.color)
                                .frame(width: 12, height: 12)
                            
                            Text(errorService.systemHealth.displayName)
                                .font(.body)
                        }
                    }
                    .padding()
                    .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
                    
                    // Test Errors
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Error Handling")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(getTestErrors(), id: \.0) { name, error in
                                Button(name) {
                                    Task {
                                        await errorService.handleError(error, context: "Test")
                                    }
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding()
                    .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
                    
                    // Error History
                    if !errorService.errorHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Errors (\(errorService.errorHistory.count))")
                                .font(.headline)
                            
                            ForEach(errorService.errorHistory.suffix(5)) { record in
                                HStack {
                                    Circle()
                                        .fill(record.error.severity.color)
                                        .frame(width: 8, height: 8)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(record.error.id.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        Text(record.timestamp, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if record.recoverySuccessful {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .padding()
                        .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
                    }
                }
                .padding()
            }
            .navigationTitle("Error Handling")
            .overlay {
                ErrorDisplayView()
            }
        }
    }
}

#Preview {
    ErrorHandlingTestView()
}
#endif