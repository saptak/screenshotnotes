import Foundation
import Vision
import OSLog

/// Comprehensive error handling and retry service for Vision Framework operations
@MainActor
public final class VisionErrorHandler: ObservableObject {
    public static let shared = VisionErrorHandler()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "VisionErrorHandler")
    private let retryQueue = DispatchQueue(label: "vision.retry", qos: .utility)
    
    // Retry configuration
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 10.0
    
    // Error tracking
    private var errorMetrics = ErrorMetrics()
    
    private init() {}
    
    // MARK: - Retry Logic
    
    /// Execute a vision operation with automatic retry on failure
    public func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        operationType: VisionOperationType,
        maxAttempts: Int? = nil
    ) async throws -> T {
        let attempts = maxAttempts ?? maxRetryAttempts
        var lastError: Error?
        
        for attempt in 1...attempts {
            do {
                let result = try await operation()
                
                // Record successful operation
                if attempt > 1 {
                    errorMetrics.recordRecovery(operationType: operationType, attemptCount: attempt)
                    logger.info("Vision operation succeeded on attempt \\(attempt) for \\(operationType.rawValue)")
                }
                
                return result
                
            } catch {
                lastError = error
                errorMetrics.recordError(error: error, operationType: operationType, attempt: attempt)
                
                logger.warning("Vision operation failed on attempt \\(attempt)/\\(attempts) for \\(operationType.rawValue): \\(error.localizedDescription)")
                
                // Don't retry on non-retryable errors
                if !isRetryableError(error) {
                    logger.error("Non-retryable error encountered: \\(error.localizedDescription)")
                    throw VisionOperationError.nonRetryableError(error)
                }
                
                // Don't delay on final attempt
                if attempt < attempts {
                    let delay = calculateRetryDelay(attempt: attempt, error: error)
                    logger.info("Retrying in \\(delay)s...")
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retry attempts failed
        let finalError = lastError ?? VisionOperationError.unknownError
        errorMetrics.recordFinalFailure(operationType: operationType, finalError: finalError)
        
        logger.error("Vision operation failed after \\(attempts) attempts for \\(operationType.rawValue)")
        throw VisionOperationError.maxRetriesExceeded(attempts, finalError)
    }
    
    // MARK: - Error Classification
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Vision Framework specific errors
        let nsError = error as NSError
        if nsError.domain == "com.apple.Vision" {
            switch nsError.code {
            case 1: // requestCancelled
                return false // Don't retry cancelled requests
            case 2: // invalidFormat
                return false // Invalid input format won't fix with retry
            case 3: // operationFailed
                return true  // May succeed on retry
            case 4: // outOfBoundsError
                return false // Data issue, won't fix with retry
            case 5: // invalidOption
                return false // Configuration issue
            case 6: // ioError
                return true  // I/O issues may be transient
            case 7: // missingOption
                return false // Configuration issue
            case 8: // notImplemented
                return false // Feature not available
            case 9: // invalidArgument
                return false // Invalid parameters
            case 10: // invalidModel
                return false // Model loading issue
            case 11: // unsupportedRevision
                return false // Version compatibility issue
            case 12: // dataUnavailable
                return true  // May be transient
            case 13: // timeStampUnavailable
                return false // Metadata issue
            default:
                return true  // Err on the side of retrying unknown errors
            }
        }
        
        // System errors
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSCocoaErrorDomain:
                // Memory or resource issues might be transient
                return nsError.code == NSFileReadCorruptFileError || 
                       nsError.code == NSFileReadNoSuchFileError ||
                       nsError.code == NSFileReadNoPermissionError
            case NSPOSIXErrorDomain:
                // System resource issues
                return nsError.code == ENOMEM || nsError.code == EAGAIN
            default:
                break
            }
        }
        
        // Custom Vision errors
        if let visionError = error as? VisionError {
            switch visionError {
            case .invalidImage, .invalidResults:
                return false // Input/output format issues
            case .classificationFailed, .processingFailed:
                return true  // May succeed on retry
            case .cacheError:
                return true  // Cache issues are often transient
            }
        }
        
        // Default to retryable for unknown errors
        return true
    }
    
    private func calculateRetryDelay(attempt: Int, error: Error) -> TimeInterval {
        // Exponential backoff with jitter
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0.1...0.3) * exponentialDelay
        let totalDelay = exponentialDelay + jitter
        
        // Apply error-specific adjustments
        let adjustedDelay = adjustDelayForError(delay: totalDelay, error: error)
        
        return min(adjustedDelay, maxRetryDelay)
    }
    
    private func adjustDelayForError(delay: TimeInterval, error: Error) -> TimeInterval {
        // Adjust delay based on error type
        let nsError = error as NSError
        if nsError.domain == "com.apple.Vision" {
            switch nsError.code {
            case 6: // ioError
                return delay * 2.0 // Longer delay for I/O issues
            case 3: // operationFailed
                return delay * 1.5 // Moderate delay for operation failures
            default:
                return delay
            }
        }
        
        // Memory pressure - longer delay
        if isMemoryPressureError(error) {
            return delay * 3.0
        }
        
        return delay
    }
    
    private func isMemoryPressureError(_ error: Error) -> Bool {
        if let nsError = error as NSError? {
            return nsError.domain == NSPOSIXErrorDomain && nsError.code == ENOMEM
        }
        return false
    }
    
    // MARK: - Graceful Degradation
    
    /// Provide fallback results when vision operations fail
    public func provideFallbackResults(for operationType: VisionOperationType, error: Error) -> Any? {
        logger.info("Providing fallback results for \\(operationType.rawValue)")
        
        switch operationType {
        case .sceneClassification:
            return createFallbackSceneClassification()
        case .faceDetection:
            return nil // No fallback for face detection
        case .textRecognition:
            return createFallbackTextRecognition()
        case .attentionAnalysis:
            return [] // Empty attention areas
        case .comprehensive:
            return createFallbackComprehensiveResults()
        }
    }
    
    private func createFallbackSceneClassification() -> AdvancedSceneClassification {
        return AdvancedSceneClassification(
            primaryScene: .screenshot,
            secondaryScenes: [],
            confidence: 0.5,
            attentionAreas: [],
            processingMetadata: ProcessingMetadata(
                processingTime: 0,
                modelVersions: ["fallback"],
                qualityLevel: .fast
            )
        )
    }
    
    private func createFallbackTextRecognition() -> EnhancedTextRecognition {
        return EnhancedTextRecognition(
            textBlocks: [],
            detectedLanguages: [RecognizedLanguage(code: "en", name: "English", confidence: 0.5)],
            confidence: 0.0,
            processingInfo: TextProcessingInfo(
                processingTime: 0,
                recognitionLevel: .fast
            )
        )
    }
    
    private func createFallbackComprehensiveResults() -> ComprehensiveVisionResults {
        return ComprehensiveVisionResults(
            sceneClassification: createFallbackSceneClassification(),
            faceDetection: nil,
            textRecognition: createFallbackTextRecognition()
        )
    }
    
    // MARK: - Error Analytics
    
    public func getErrorMetrics() -> ErrorMetrics {
        return errorMetrics
    }
    
    public func resetMetrics() {
        errorMetrics = ErrorMetrics()
    }
}

// MARK: - Vision Operation Types

public enum VisionOperationType: String, CaseIterable, Codable, Sendable {
    case sceneClassification = "scene_classification"
    case faceDetection = "face_detection"
    case textRecognition = "text_recognition"
    case attentionAnalysis = "attention_analysis"
    case comprehensive = "comprehensive_analysis"
    
    public var displayName: String {
        switch self {
        case .sceneClassification: return "Scene Classification"
        case .faceDetection: return "Face Detection"
        case .textRecognition: return "Text Recognition"
        case .attentionAnalysis: return "Attention Analysis"
        case .comprehensive: return "Comprehensive Analysis"
        }
    }
}

// MARK: - Error Types

public enum VisionOperationError: LocalizedError {
    case maxRetriesExceeded(Int, Error)
    case nonRetryableError(Error)
    case operationCancelled
    case invalidConfiguration
    case unknownError
    
    public var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded(let attempts, let error):
            return "Vision operation failed after \(attempts) retry attempts: \(error.localizedDescription)"
        case .nonRetryableError(let error):
            return "Non-retryable vision error: \(error.localizedDescription)"
        case .operationCancelled:
            return "Vision operation was cancelled"
        case .invalidConfiguration:
            return "Invalid vision operation configuration"
        case .unknownError:
            return "Unknown vision operation error"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .maxRetriesExceeded:
            return "The operation failed persistently despite retry attempts"
        case .nonRetryableError:
            return "The error type indicates that retrying would not succeed"
        case .operationCancelled:
            return "The operation was cancelled by the user or system"
        case .invalidConfiguration:
            return "The vision operation was configured incorrectly"
        case .unknownError:
            return "An unknown error occurred during vision processing"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Try again later or check the input image quality"
        case .nonRetryableError:
            return "Check the input parameters and image format"
        case .operationCancelled:
            return "Restart the operation if needed"
        case .invalidConfiguration:
            return "Review the vision operation configuration"
        case .unknownError:
            return "Contact support if the problem persists"
        }
    }
}

// MARK: - Error Metrics

public struct ErrorMetrics: Codable {
    private var errorCounts: [String: Int] = [:]
    private var operationCounts: [String: Int] = [:]
    private var recoveryCounts: [String: Int] = [:]
    private var finalFailureCounts: [String: Int] = [:]
    private var totalOperations = 0
    
    mutating func recordError(error: Error, operationType: VisionOperationType, attempt: Int) {
        let errorKey = "\\(operationType.rawValue)_\\(type(of: error))"
        errorCounts[errorKey, default: 0] += 1
        operationCounts[operationType.rawValue, default: 0] += 1
        
        if attempt == 1 {
            totalOperations += 1
        }
    }
    
    mutating func recordRecovery(operationType: VisionOperationType, attemptCount: Int) {
        recoveryCounts[operationType.rawValue, default: 0] += 1
    }
    
    mutating func recordFinalFailure(operationType: VisionOperationType, finalError: Error) {
        finalFailureCounts[operationType.rawValue, default: 0] += 1
    }
    
    // MARK: - Analytics
    
    public var totalErrorCount: Int {
        return errorCounts.values.reduce(0, +)
    }
    
    public var recoveryRate: Double {
        let totalRecoveries = recoveryCounts.values.reduce(0, +)
        let totalFailures = finalFailureCounts.values.reduce(0, +)
        let totalAttempts = totalRecoveries + totalFailures
        
        return totalAttempts > 0 ? Double(totalRecoveries) / Double(totalAttempts) : 0.0
    }
    
    public var successRate: Double {
        let totalFailures = finalFailureCounts.values.reduce(0, +)
        return totalOperations > 0 ? Double(totalOperations - totalFailures) / Double(totalOperations) : 0.0
    }
    
    public func errorCountFor(operationType: VisionOperationType) -> Int {
        return operationCounts[operationType.rawValue, default: 0]
    }
    
    public func recoveryCountFor(operationType: VisionOperationType) -> Int {
        return recoveryCounts[operationType.rawValue, default: 0]
    }
    
    public var mostCommonErrors: [(String, Int)] {
        return errorCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
}