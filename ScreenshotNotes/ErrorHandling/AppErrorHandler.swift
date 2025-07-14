import Foundation
import SwiftUI
import OSLog

/// Unified error handling system for ScreenshotNotes
/// Provides consistent error handling, recovery strategies, and user feedback across all services
@MainActor
class AppErrorHandler: ObservableObject {
    static let shared = AppErrorHandler()
    
    // MARK: - Published Properties
    @Published var currentError: AppError?
    @Published var isShowingError = false
    @Published var errorHistory: [ErrorRecord] = []
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ErrorHandling")
    private let maxErrorHistoryCount = 100
    private var retryTimers: [String: Timer] = [:]
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Handles an error with appropriate recovery strategy and user feedback
    func handle(_ error: Error, context: ErrorContext, source: String = #function) {
        let appError = AppError.from(error, context: context, source: source)
        
        // Log the error
        logError(appError)
        
        // Add to history
        addToHistory(appError)
        
        // Execute recovery strategy
        executeRecoveryStrategy(for: appError)
        
        // Show user feedback if needed
        if appError.requiresUserFeedback {
            showErrorToUser(appError)
        }
    }
    
    /// Handles errors with automatic retry mechanism
    func handleWithRetry<T>(
        operation: @escaping () async throws -> T,
        context: ErrorContext,
        maxRetries: Int = 3,
        backoffStrategy: BackoffStrategy = .exponential,
        source: String = #function
    ) async -> Result<T, AppError> {
        var lastError: AppError?
        
        for attempt in 0...maxRetries {
            do {
                let result = try await operation()
                
                // Clear any retry timers on success
                clearRetryTimer(for: source)
                
                return .success(result)
            } catch {
                let appError = AppError.from(error, context: context, source: source, retryAttempt: attempt)
                lastError = appError
                
                // Log retry attempt
                logger.info("Retry attempt \(attempt + 1)/\(maxRetries + 1) failed: \(appError.localizedDescription)")
                
                // If this isn't the last attempt, wait before retrying
                if attempt < maxRetries {
                    let delay = backoffStrategy.delay(for: attempt)
                    try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                }
            }
        }
        
        // All retries failed
        if let finalError = lastError {
            handle(finalError, context: context, source: source)
            return .failure(finalError)
        }
        
        // Fallback error
        let fallbackError = AppError.unknown(source: source)
        handle(fallbackError, context: context, source: source)
        return .failure(fallbackError)
    }
    
    /// Dismisses the current error
    func dismissError() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentError = nil
            isShowingError = false
        }
    }
    
    /// Retries the failed operation if possible
    func retryOperation() {
        guard let error = currentError else { return }
        
        dismissError()
        
        // Execute retry strategy
        Task {
            await error.retryStrategy?.execute()
        }
    }
    
    /// Clears error history
    func clearErrorHistory() {
        errorHistory.removeAll()
        logger.info("Error history cleared")
    }
    
    // MARK: - Private Methods
    
    private func logError(_ error: AppError) {
        switch error.severity {
        case .info:
            logger.info("\(error.logDescription)")
        case .warning:
            logger.notice("\(error.logDescription)")
        case .error:
            logger.error("\(error.logDescription)")
        case .critical:
            logger.fault("\(error.logDescription)")
        }
    }
    
    private func addToHistory(_ error: AppError) {
        let record = ErrorRecord(error: error, timestamp: Date())
        errorHistory.insert(record, at: 0)
        
        // Limit history size
        if errorHistory.count > maxErrorHistoryCount {
            errorHistory.removeLast()
        }
    }
    
    private func executeRecoveryStrategy(for error: AppError) {
        Task {
            await error.recoveryStrategy?.execute()
        }
    }
    
    private func showErrorToUser(_ error: AppError) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentError = error
            isShowingError = true
        }
        
        // Auto-dismiss non-critical errors after delay
        if error.severity != .critical {
            let dismissDelay: TimeInterval = error.severity == .error ? 8.0 : 5.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                if self.currentError?.id == error.id {
                    self.dismissError()
                }
            }
        }
    }
    
    private func clearRetryTimer(for source: String) {
        retryTimers[source]?.invalidate()
        retryTimers.removeValue(forKey: source)
    }
}

// MARK: - Error Types

/// Unified error type for the application
struct AppError: LocalizedError, Identifiable {
    let id = UUID()
    let type: ErrorType
    let context: ErrorContext
    let severity: ErrorSeverity
    let source: String
    let originalError: Error?
    let retryAttempt: Int
    let timestamp: Date
    let recoveryStrategy: ErrorRecoveryStrategy?
    let retryStrategy: RetryStrategy?
    let requiresUserFeedback: Bool
    
    var errorDescription: String? {
        switch type {
        case .network(let networkError):
            return networkError.userDescription
        case .data(let dataError):
            return dataError.userDescription
        case .permission(let permissionError):
            return permissionError.userDescription
        case .resource(let resourceError):
            return resourceError.userDescription
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
    
    var logDescription: String {
        "[\(severity.rawValue.uppercased())] \(source): \(type.logDescription) | Context: \(context.rawValue) | Retry: \(retryAttempt)"
    }
    
    static func from(_ error: Error, context: ErrorContext, source: String, retryAttempt: Int = 0) -> AppError {
        let errorType = ErrorType.classify(error)
        let severity = ErrorSeverity.determine(for: errorType, context: context)
        
        // Create appropriate recovery strategy based on error type
        let recoveryStrategy: ErrorRecoveryStrategy? = {
            switch errorType {
            case .network(let networkError):
                return NetworkRecoveryStrategy(networkError: networkError, context: context)
            case .data(let dataError):
                return DataRecoveryStrategy(dataError: dataError, context: context)
            case .permission(let permissionError):
                return PermissionRecoveryStrategy(permissionError: permissionError, context: context)
            case .resource(let resourceError):
                return ResourceRecoveryStrategy(resourceError: resourceError, context: context)
            case .unknown:
                return nil
            }
        }()
        
        // Create appropriate retry strategy based on error type
        let retryStrategy: RetryStrategy? = {
            switch errorType {
            case .network:
                return ErrorRecoveryRetryStrategy(
                    operation: { /* Will be set by caller */ },
                    maxRetries: 3,
                    backoffStrategy: .exponential
                )
            default:
                return nil
            }
        }()
        
        let requiresFeedback = severity == .error || severity == .critical
        
        return AppError(
            type: errorType,
            context: context,
            severity: severity,
            source: source,
            originalError: error,
            retryAttempt: retryAttempt,
            timestamp: Date(),
            recoveryStrategy: recoveryStrategy,
            retryStrategy: retryStrategy,
            requiresUserFeedback: requiresFeedback
        )
    }
    
    static func unknown(source: String) -> AppError {
        AppError(
            type: .unknown,
            context: .general,
            severity: .error,
            source: source,
            originalError: nil,
            retryAttempt: 0,
            timestamp: Date(),
            recoveryStrategy: nil,
            retryStrategy: nil,
            requiresUserFeedback: true
        )
    }
}

// MARK: - Error Classification

enum ErrorType {
    case network(NetworkError)
    case data(DataError)
    case permission(PermissionError)
    case resource(ResourceError)
    case unknown
    
    static func classify(_ error: Error) -> ErrorType {
        switch error {
        case let urlError as URLError:
            return .network(NetworkError.from(urlError))
        case let decodingError as DecodingError:
            return .data(DataError.from(decodingError))
        case let encodingError as EncodingError:
            return .data(DataError.from(encodingError))
        default:
            if error.localizedDescription.contains("permission") || error.localizedDescription.contains("access") {
                return .permission(.accessDenied)
            } else if error.localizedDescription.contains("memory") || error.localizedDescription.contains("resource") {
                return .resource(.memoryPressure)
            } else {
                return .unknown
            }
        }
    }
    
    var logDescription: String {
        switch self {
        case .network(let networkError):
            return "Network: \(networkError.rawValue)"
        case .data(let dataError):
            return "Data: \(dataError.rawValue)"
        case .permission(let permissionError):
            return "Permission: \(permissionError.rawValue)"
        case .resource(let resourceError):
            return "Resource: \(resourceError.rawValue)"
        case .unknown:
            return "Unknown error"
        }
    }
}

enum NetworkError: String, CaseIterable {
    case noConnection = "no_connection"
    case timeout = "timeout"
    case serverError = "server_error"
    case invalidResponse = "invalid_response"
    case rateLimited = "rate_limited"
    
    static func from(_ urlError: URLError) -> NetworkError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .badServerResponse, .cannotParseResponse:
            return .invalidResponse
        default:
            return .serverError
        }
    }
    
    var userDescription: String {
        switch self {
        case .noConnection:
            return "No internet connection. Please check your network and try again."
        case .timeout:
            return "The request timed out. Please try again."
        case .serverError:
            return "Server error occurred. Please try again later."
        case .invalidResponse:
            return "Invalid response received. Please try again."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        }
    }
}

enum DataError: String, CaseIterable {
    case corruptedData = "corrupted_data"
    case invalidFormat = "invalid_format"
    case missingData = "missing_data"
    case encodingFailed = "encoding_failed"
    case decodingFailed = "decoding_failed"
    
    static func from(_ decodingError: DecodingError) -> DataError {
        switch decodingError {
        case .dataCorrupted:
            return .corruptedData
        case .keyNotFound, .valueNotFound:
            return .missingData
        case .typeMismatch:
            return .invalidFormat
        @unknown default:
            return .decodingFailed
        }
    }
    
    static func from(_ encodingError: EncodingError) -> DataError {
        switch encodingError {
        case .invalidValue:
            return .invalidFormat
        @unknown default:
            return .encodingFailed
        }
    }
    
    var userDescription: String {
        switch self {
        case .corruptedData:
            return "Data corruption detected. Attempting to recover..."
        case .invalidFormat:
            return "Invalid data format. Please check your input."
        case .missingData:
            return "Required data is missing. Please try again."
        case .encodingFailed:
            return "Failed to save data. Please try again."
        case .decodingFailed:
            return "Failed to load data. Please check the data format."
        }
    }
}

enum PermissionError: String, CaseIterable {
    case photoLibraryDenied = "photo_library_denied"
    case cameraAccess = "camera_access"
    case accessDenied = "access_denied"
    case insufficientPermissions = "insufficient_permissions"
    
    var userDescription: String {
        switch self {
        case .photoLibraryDenied:
            return "Photo library access is required. Please enable it in Settings."
        case .cameraAccess:
            return "Camera access is required. Please enable it in Settings."
        case .accessDenied:
            return "Access denied. Please check your permissions in Settings."
        case .insufficientPermissions:
            return "Insufficient permissions. Please grant the required permissions."
        }
    }
}

enum ResourceError: String, CaseIterable {
    case memoryPressure = "memory_pressure"
    case diskSpaceLow = "disk_space_low"
    case thermalThrottling = "thermal_throttling"
    case processingOverload = "processing_overload"
    
    var userDescription: String {
        switch self {
        case .memoryPressure:
            return "Low memory detected. Optimizing performance..."
        case .diskSpaceLow:
            return "Low storage space. Please free up some space."
        case .thermalThrottling:
            return "Device is hot. Reducing performance to cool down..."
        case .processingOverload:
            return "Too many operations running. Please wait..."
        }
    }
}

// MARK: - Error Context and Severity

enum ErrorContext: String, CaseIterable {
    case general = "general"
    case photoImport = "photo_import"
    case ocr = "ocr"
    case search = "search"
    case mindMap = "mind_map"
    case sync = "sync"
    case ui = "ui"
    case background = "background"
}

enum ErrorSeverity: String, CaseIterable {
    case info
    case warning
    case error
    case critical
    
    static func determine(for errorType: ErrorType, context: ErrorContext) -> ErrorSeverity {
        switch errorType {
        case .network(.noConnection):
            return context == .background ? .warning : .error
        case .network(.timeout):
            return .warning
        case .network:
            return .error
        case .data(.corruptedData), .data(.missingData):
            return .critical
        case .data:
            return .error
        case .permission:
            return .error
        case .resource(.memoryPressure), .resource(.thermalThrottling):
            return .warning
        case .resource:
            return .error
        case .unknown:
            return .error
        }
    }
}

// MARK: - Backoff Strategy

enum BackoffStrategy {
    case linear
    case exponential
    case fibonacci
    
    func delay(for attempt: Int) -> TimeInterval {
        switch self {
        case .linear:
            return TimeInterval(attempt + 1)
        case .exponential:
            return TimeInterval(pow(2.0, Double(attempt)))
        case .fibonacci:
            return TimeInterval(fibonacci(attempt + 1))
        }
    }
    
    private func fibonacci(_ n: Int) -> Int {
        if n <= 1 { return n }
        var a = 0, b = 1
        for _ in 2...n {
            let temp = a + b
            a = b
            b = temp
        }
        return b
    }
}

// MARK: - Error Record

struct ErrorRecord: Identifiable {
    let id = UUID()
    let error: AppError
    let timestamp: Date
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}