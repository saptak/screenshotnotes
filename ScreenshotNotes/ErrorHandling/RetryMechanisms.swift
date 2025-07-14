import Foundation
import SwiftUI
import OSLog

/// Comprehensive retry mechanisms with exponential backoff
/// Implements Iteration 8.5.2.3: Retry Mechanisms with Exponential Backoff
@MainActor
struct RetryMechanisms {
    private static let logger = Logger(subsystem: "com.screenshotnotes.app", category: "RetryMechanisms")
    
    // MARK: - Generic Retry with Strategy
    
    /// Execute operation with retry strategy and error handling
    static func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        maxAttempts: Int = 3,
        backoffStrategy: BackoffStrategy = .exponential,
        context: ErrorContext = .general,
        source: String = #function
    ) async -> Result<T, AppError> {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                let result = try await operation()
                logger.info("Operation succeeded on attempt \(attempt + 1)")
                return .success(result)
                
            } catch {
                lastError = error
                logger.warning("Attempt \(attempt + 1) failed: \(error.localizedDescription)")
                
                // Don't wait after the last attempt
                if attempt < maxAttempts - 1 {
                    let delay = backoffStrategy.delay(for: attempt)
                    logger.info("Waiting \(delay)s before retry attempt \(attempt + 2)")
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
        }
        
        // All attempts failed
        let appError = AppError.from(lastError!, context: context, source: source)
        logger.error("All \(maxAttempts) attempts failed: \(appError.logDescription)")
        return .failure(appError)
    }
    
    // MARK: - Specialized Retry Strategies
    
    /// Network operation retry with intelligent backoff
    static func networkRetry<T>(
        operation: @escaping () async throws -> T,
        maxAttempts: Int = 3,
        context: ErrorContext = .general,
        source: String = #function
    ) async -> Result<T, AppError> {
        return await executeWithRetry(
            operation: operation,
            maxAttempts: maxAttempts,
            backoffStrategy: .exponential,
            context: context,
            source: source
        )
    }
    
    /// Data operation retry with progressive strategies
    static func dataRetry<T>(
        operation: @escaping () async throws -> T,
        maxAttempts: Int = 2,
        context: ErrorContext = .general,
        source: String = #function
    ) async -> Result<T, AppError> {
        return await executeWithRetry(
            operation: operation,
            maxAttempts: maxAttempts,
            backoffStrategy: .linear,
            context: context,
            source: source
        )
    }
    
    /// Resource operation retry with adaptive strategies
    static func resourceRetry<T>(
        operation: @escaping () async throws -> T,
        maxAttempts: Int = 2,
        context: ErrorContext = .general,
        source: String = #function
    ) async -> Result<T, AppError> {
        return await executeWithRetry(
            operation: operation,
            maxAttempts: maxAttempts,
            backoffStrategy: .fibonacci,
            context: context,
            source: source
        )
    }
    
}

// MARK: - Retry Strategy Protocol

protocol RetryStrategyProtocol {
    var maxAttempts: Int { get }
    var backoffStrategy: BackoffStrategy { get }
    
    func shouldRetry(_ errorType: ErrorType, attempt: Int) -> Bool
}

// MARK: - Concrete Retry Strategies

struct NetworkRetryStrategy: RetryStrategyProtocol {
    let maxAttempts: Int
    let backoffStrategy: BackoffStrategy
    let retryableErrors: [NetworkError]
    
    func shouldRetry(_ errorType: ErrorType, attempt: Int) -> Bool {
        guard case .network(let networkError) = errorType else { return false }
        return retryableErrors.contains(networkError) && attempt < maxAttempts - 1
    }
}

struct DataRetryStrategy: RetryStrategyProtocol {
    let maxAttempts: Int
    let backoffStrategy: BackoffStrategy
    let retryableErrors: [DataError]
    
    func shouldRetry(_ errorType: ErrorType, attempt: Int) -> Bool {
        guard case .data(let dataError) = errorType else { return false }
        return retryableErrors.contains(dataError) && attempt < maxAttempts - 1
    }
}

struct ResourceRetryStrategy: RetryStrategyProtocol {
    let maxAttempts: Int
    let backoffStrategy: BackoffStrategy
    let retryableErrors: [ResourceError]
    
    func shouldRetry(_ errorType: ErrorType, attempt: Int) -> Bool {
        guard case .resource(let resourceError) = errorType else { return false }
        return retryableErrors.contains(resourceError) && attempt < maxAttempts - 1
    }
}

// MARK: - Enhanced Backoff Strategies (Extending the existing BackoffStrategy from AppErrorHandler.swift)

enum AdvancedBackoffStrategy {
    case exponentialWithJitter(baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 60.0)
    case custom((Int) -> TimeInterval)
    
    func delay(for attempt: Int) -> TimeInterval {
        switch self {
        case .exponentialWithJitter(let baseDelay, let maxDelay):
            let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
            let jitter = Double.random(in: 0...0.3) * exponentialDelay
            return min(exponentialDelay + jitter, maxDelay)
        case .custom(let delayFunction):
            return delayFunction(attempt)
        }
    }
}

// MARK: - Retry Context and Configuration

struct RetryConfiguration {
    let maxAttempts: Int
    let backoffStrategy: BackoffStrategy
    let timeoutPerAttempt: TimeInterval
    let totalTimeout: TimeInterval
    let shouldRetryPredicate: (Error, Int) -> Bool
    
    static let networkDefault = RetryConfiguration(
        maxAttempts: 3,
        backoffStrategy: .exponential,
        timeoutPerAttempt: 30.0,
        totalTimeout: 120.0,
        shouldRetryPredicate: { error, attempt in
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                    return attempt < 3
                default:
                    return false
                }
            }
            return false
        }
    )
    
    static let dataDefault = RetryConfiguration(
        maxAttempts: 2,
        backoffStrategy: .linear,
        timeoutPerAttempt: 10.0,
        totalTimeout: 30.0,
        shouldRetryPredicate: { error, attempt in
            return error is DecodingError || error is EncodingError
        }
    )
    
    static let resourceDefault = RetryConfiguration(
        maxAttempts: 2,
        backoffStrategy: .fibonacci,
        timeoutPerAttempt: 5.0,
        totalTimeout: 15.0,
        shouldRetryPredicate: { error, attempt in
            let description = error.localizedDescription.lowercased()
            return description.contains("memory") || description.contains("resource")
        }
    )
}

// MARK: - Circuit Breaker Pattern

@MainActor
class CircuitBreaker: ObservableObject {
    enum State {
        case closed
        case open
        case halfOpen
    }
    
    @Published private(set) var state: State = .closed
    private let failureThreshold: Int
    private let recoveryTimeout: TimeInterval
    private var failures: Int = 0
    private var lastFailureTime: Date?
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "CircuitBreaker")
    
    init(failureThreshold: Int = 5, recoveryTimeout: TimeInterval = 60.0) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
    }
    
    func execute<T>(operation: @escaping () async throws -> T) async throws -> T {
        switch state {
        case .open:
            // Check if we should try half-open
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > recoveryTimeout {
                state = .halfOpen
                logger.info("Circuit breaker transitioning to half-open")
            } else {
                logger.warning("Circuit breaker is open - operation blocked")
                throw CircuitBreakerError.circuitOpen
            }
            
        case .halfOpen:
            logger.info("Circuit breaker is half-open - testing operation")
            
        case .closed:
            // Normal operation
            break
        }
        
        do {
            let result = try await operation()
            
            // Operation succeeded
            if state == .halfOpen {
                state = .closed
                failures = 0
                logger.info("Circuit breaker reset to closed")
            }
            
            return result
            
        } catch {
            recordFailure()
            throw error
        }
    }
    
    private func recordFailure() {
        failures += 1
        lastFailureTime = Date()
        
        if failures >= failureThreshold && state == .closed {
            state = .open
            logger.warning("Circuit breaker opened after \(self.failures) failures")
        } else if state == .halfOpen {
            state = .open
            logger.warning("Circuit breaker returned to open from half-open")
        }
    }
}

enum CircuitBreakerError: LocalizedError {
    case circuitOpen
    
    var errorDescription: String? {
        switch self {
        case .circuitOpen:
            return "Circuit breaker is open - operation temporarily unavailable"
        }
    }
}

// MARK: - Retry Utility Extensions

extension AppErrorHandler {
    /// Execute operation with circuit breaker protection
    func executeWithCircuitBreaker<T>(
        operation: @escaping () async throws -> T,
        circuitBreaker: CircuitBreaker,
        context: ErrorContext = .general,
        source: String = #function
    ) async -> Result<T, AppError> {
        do {
            let result = try await circuitBreaker.execute(operation: operation)
            return .success(result)
        } catch {
            let appError = AppError.from(error, context: context, source: source)
            handle(appError, context: context, source: source)
            return .failure(appError)
        }
    }
}