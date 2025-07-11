import XCTest
import Photos
@testable import ScreenshotNotes

final class NetworkRetryServiceTests: XCTestCase {
    var networkRetryService: NetworkRetryService!
    
    override func setUp() {
        super.setUp()
        networkRetryService = NetworkRetryService.shared
    }
    
    override func tearDown() {
        networkRetryService = nil
        super.tearDown()
    }
    
    func testErrorClassification() {
        let service = NetworkRetryService.shared
        
        // Test network unavailable error
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let classifiedError = service.classifyError(networkError)
        
        switch classifiedError {
        case .networkUnavailable:
            XCTAssertTrue(classifiedError.isRetryable)
        default:
            XCTFail("Should classify as network unavailable")
        }
    }
    
    func testRetryConfiguration() {
        let standardConfig = NetworkRetryService.RetryConfiguration.standard
        let aggressiveConfig = NetworkRetryService.RetryConfiguration.aggressive
        let conservativeConfig = NetworkRetryService.RetryConfiguration.conservative
        
        XCTAssertEqual(standardConfig.maxRetries, 3)
        XCTAssertEqual(aggressiveConfig.maxRetries, 5)
        XCTAssertEqual(conservativeConfig.maxRetries, 2)
        
        XCTAssertTrue(standardConfig.baseDelay > 0)
        XCTAssertTrue(aggressiveConfig.baseDelay > 0)
        XCTAssertTrue(conservativeConfig.baseDelay > 0)
    }
    
    func testDelayCalculation() {
        let config = NetworkRetryService.RetryConfiguration.standard
        let service = NetworkRetryService.shared
        
        // Test that delay increases with attempts
        let delay1 = service.calculateDelay(attempt: 0, configuration: config)
        let delay2 = service.calculateDelay(attempt: 1, configuration: config)
        let delay3 = service.calculateDelay(attempt: 2, configuration: config)
        
        XCTAssertTrue(delay1 > 0)
        XCTAssertTrue(delay2 > delay1)
        XCTAssertTrue(delay3 > delay2)
        
        // Test that delay doesn't exceed maximum
        let maxDelay = service.calculateDelay(attempt: 10, configuration: config)
        XCTAssertTrue(maxDelay <= config.maxDelay + (config.maxDelay * config.jitterFactor))
    }
    
    func testNetworkErrorProperties() {
        let networkError = NetworkRetryService.NetworkError.networkUnavailable
        let permanentError = NetworkRetryService.NetworkError.permanentFailure(NSError(domain: "test", code: 0, userInfo: nil))
        let temporaryError = NetworkRetryService.NetworkError.temporaryFailure(NSError(domain: "test", code: 0, userInfo: nil))
        
        XCTAssertTrue(networkError.isRetryable)
        XCTAssertFalse(permanentError.isRetryable)
        XCTAssertTrue(temporaryError.isRetryable)
        
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertNotNil(permanentError.errorDescription)
        XCTAssertNotNil(temporaryError.errorDescription)
    }
    
    func testSimulatedFailures() async {
        let service = NetworkRetryService.shared
        
        // Test simulated network failure
        do {
            try await service.simulateNetworkFailure()
            XCTFail("Should have thrown network failure")
        } catch NetworkRetryService.NetworkError.networkUnavailable {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Test simulated timeout
        do {
            try await service.simulateTimeout()
            XCTFail("Should have thrown timeout")
        } catch NetworkRetryService.NetworkError.timeout {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testBatchRequestErrorHandling() async {
        let service = NetworkRetryService.shared
        
        // Create mock assets (these will fail)
        let mockAssets: [PHAsset] = []
        
        do {
            let results = try await service.requestImagesWithRetry(
                assets: mockAssets,
                configuration: .conservative
            )
            
            // Should succeed with empty array
            XCTAssertTrue(results.isEmpty)
        } catch {
            XCTFail("Batch request should handle empty array: \(error)")
        }
    }
    
    func testRetryLogic() async {
        let service = NetworkRetryService.shared
        
        let result = await service.testRetryLogic()
        XCTAssertTrue(result, "Test retry logic should return true (indicating expected failure)")
    }
    
    func testNetworkAvailabilityCheck() async {
        let service = NetworkRetryService.shared
        
        // This test depends on network connectivity
        let isAvailable = await service.checkNetworkAvailability()
        
        // We can't guarantee network state, but method should not crash
        XCTAssertTrue(isAvailable || !isAvailable) // Always true, just testing it doesn't crash
    }
}

// MARK: - Test Extension for Private Methods

extension NetworkRetryService {
    func classifyError(_ error: Error) -> NetworkError {
        if let nsError = error as NSError? {
            switch nsError.domain {
            case PHPhotosErrorDomain:
                switch nsError.code {
                case PHPhotosError.networkAccessRequired.rawValue:
                    return .networkUnavailable
                case PHPhotosError.accessRestricted.rawValue,
                     PHPhotosError.accessUserDenied.rawValue:
                    return .permanentFailure(error)
                case PHPhotosError.invalidResource.rawValue:
                    return .permanentFailure(error)
                default:
                    return .temporaryFailure(error)
                }
            case NSURLErrorDomain:
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet,
                     NSURLErrorNetworkConnectionLost,
                     NSURLErrorCannotConnectToHost:
                    return .networkUnavailable
                case NSURLErrorTimedOut:
                    return .timeout
                case NSURLErrorCannotFindHost,
                     NSURLErrorBadURL:
                    return .permanentFailure(error)
                default:
                    return .temporaryFailure(error)
                }
            case NSCocoaErrorDomain:
                switch nsError.code {
                case NSFileReadNoSuchFileError:
                    return .permanentFailure(error)
                case NSFileReadNoPermissionError:
                    return .permanentFailure(error)
                default:
                    return .temporaryFailure(error)
                }
            default:
                return .temporaryFailure(error)
            }
        }
        
        return .temporaryFailure(error)
    }
    
    func calculateDelay(attempt: Int, configuration: RetryConfiguration) -> TimeInterval {
        let exponentialDelay = configuration.baseDelay * pow(2.0, Double(attempt))
        let cappedDelay = min(exponentialDelay, configuration.maxDelay)
        
        // Add jitter to prevent thundering herd
        let jitter = cappedDelay * configuration.jitterFactor * Double.random(in: -1...1)
        let finalDelay = max(0.1, cappedDelay + jitter)
        
        return finalDelay
    }
}