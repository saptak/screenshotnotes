import Foundation
import Photos
import UIKit
import os.log

/// Service for handling network retries with exponential backoff and error classification
class NetworkRetryService: @unchecked Sendable {
    static let shared = NetworkRetryService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "NetworkRetry")
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 30.0
    
    private init() {}
    
    /// Enhanced error classification for better retry logic
    enum NetworkError: Error, LocalizedError {
        case networkUnavailable
        case temporaryFailure(Error)
        case permanentFailure(Error)
        case timeout
        case iCloudSyncRequired
        case lowStorageSpace
        case rateLimited
        
        var errorDescription: String? {
            switch self {
            case .networkUnavailable:
                return "Network is unavailable"
            case .temporaryFailure(let error):
                return "Temporary failure: \(error.localizedDescription)"
            case .permanentFailure(let error):
                return "Permanent failure: \(error.localizedDescription)"
            case .timeout:
                return "Request timed out"
            case .iCloudSyncRequired:
                return "iCloud Photos sync required"
            case .lowStorageSpace:
                return "Insufficient storage space"
            case .rateLimited:
                return "Rate limited by system"
            }
        }
        
        var isRetryable: Bool {
            switch self {
            case .networkUnavailable, .temporaryFailure, .timeout, .iCloudSyncRequired, .rateLimited:
                return true
            case .permanentFailure, .lowStorageSpace:
                return false
            }
        }
    }
    
    /// Retry configuration for different scenarios
    struct RetryConfiguration {
        let maxRetries: Int
        let baseDelay: TimeInterval
        let maxDelay: TimeInterval
        let jitterFactor: Double
        
        static let standard = RetryConfiguration(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 30.0,
            jitterFactor: 0.1
        )
        
        static let aggressive = RetryConfiguration(
            maxRetries: 5,
            baseDelay: 0.5,
            maxDelay: 60.0,
            jitterFactor: 0.2
        )
        
        static let conservative = RetryConfiguration(
            maxRetries: 2,
            baseDelay: 2.0,
            maxDelay: 15.0,
            jitterFactor: 0.05
        )
    }
    
    /// Request image with retry logic and comprehensive error handling
    /// - Parameters:
    ///   - asset: The PHAsset to request
    ///   - targetSize: Target size for the image
    ///   - configuration: Retry configuration to use
    /// - Returns: The requested UIImage
    func requestImageWithRetry(
        asset: PHAsset,
        targetSize: CGSize = PHImageManagerMaximumSize,
        configuration: RetryConfiguration = .standard
    ) async throws -> UIImage {
        let imageManager = PHImageManager.default()
        
        // Create optimized request options
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.progressHandler = { progress, error, stop, info in
            // Log progress for debugging
            if let error = error {
                self.logger.info("Image request progress error: \(error.localizedDescription)")
            }
        }
        
        var lastError: Error?
        
        for attempt in 0...configuration.maxRetries {
            logger.info("Attempting image request for asset \(asset.localIdentifier), attempt \(attempt + 1)/\(configuration.maxRetries + 1)")
            
            do {
                let image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
                    imageManager.requestImage(
                        for: asset,
                        targetSize: targetSize,
                        contentMode: .aspectFit,
                        options: requestOptions
                    ) { image, info in
                        // Check for errors in the info dictionary
                        if let error = info?[PHImageErrorKey] as? Error {
                            let networkError = self.classifyError(error)
                            self.logger.error("Image request failed: \(error.localizedDescription)")
                            continuation.resume(throwing: networkError)
                            return
                        }
                        
                        // Check if the image is in iCloud and needs downloading
                        if let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool, isInCloud {
                            if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                                // This is a degraded image, wait for the full resolution
                                self.logger.info("Received degraded image from iCloud, waiting for full resolution")
                                return
                            }
                        }
                        
                        // Check if this is a cancelled request
                        if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                            self.logger.warning("Image request was cancelled")
                            continuation.resume(throwing: NetworkError.timeout)
                            return
                        }
                        
                        guard let image = image else {
                            self.logger.error("No image returned from request")
                            continuation.resume(throwing: NetworkError.temporaryFailure(NSError(domain: "PHImageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image returned"])))
                            return
                        }
                        
                        self.logger.info("Successfully received image for asset \(asset.localIdentifier)")
                        continuation.resume(returning: image)
                    }
                }
                
                // Success - return the image
                if attempt > 0 {
                    logger.info("Successfully recovered after \(attempt) retries for asset \(asset.localIdentifier)")
                }
                return image
                
            } catch {
                lastError = error
                logger.error("Image request attempt \(attempt + 1) failed: \(error.localizedDescription)")
                
                // Classify the error to determine if we should retry
                let networkError = classifyError(error)
                
                // Don't retry if it's a permanent failure or we've exhausted retries
                if !networkError.isRetryable || attempt >= configuration.maxRetries {
                    logger.error("Not retrying - permanent failure or max retries reached")
                    throw networkError
                }
                
                // Calculate delay with exponential backoff and jitter
                let delay = calculateDelay(
                    attempt: attempt,
                    configuration: configuration
                )
                
                logger.info("Retrying after \(delay) seconds...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // This should never be reached, but just in case
        throw lastError ?? NetworkError.temporaryFailure(NSError(domain: "NetworkRetryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]))
    }
    
    /// Classify errors to determine retry strategy
    private func classifyError(_ error: Error) -> NetworkError {
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
    
    /// Calculate retry delay with exponential backoff and jitter
    private func calculateDelay(
        attempt: Int,
        configuration: RetryConfiguration
    ) -> TimeInterval {
        let exponentialDelay = configuration.baseDelay * pow(2.0, Double(attempt))
        let cappedDelay = min(exponentialDelay, configuration.maxDelay)
        
        // Add jitter to prevent thundering herd
        let jitter = cappedDelay * configuration.jitterFactor * Double.random(in: -1...1)
        let finalDelay = max(0.1, cappedDelay + jitter)
        
        return finalDelay
    }
    
    /// Check network availability
    func checkNetworkAvailability() async -> Bool {
        // Simple network check - in a real app you might use Network framework
        let url = URL(string: "https://www.apple.com")!
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    /// Batch request with retry logic
    func requestImagesWithRetry(
        assets: [PHAsset],
        targetSize: CGSize = PHImageManagerMaximumSize,
        configuration: RetryConfiguration = .standard,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async throws -> [(PHAsset, UIImage)] {
        var results: [(PHAsset, UIImage)] = []
        var failures: [(PHAsset, Error)] = []
        
        for (index, asset) in assets.enumerated() {
            do {
                let image = try await requestImageWithRetry(
                    asset: asset,
                    targetSize: targetSize,
                    configuration: configuration
                )
                results.append((asset, image))
                progressHandler?(index + 1, assets.count)
            } catch {
                failures.append((asset, error))
                logger.error("Failed to retrieve image for asset \(asset.localIdentifier): \(error.localizedDescription)")
            }
        }
        
        if !failures.isEmpty {
            logger.warning("Batch request completed with \(failures.count) failures out of \(assets.count) assets")
        }
        
        return results
    }
}

// MARK: - Testing Support

extension NetworkRetryService {
    /// Test helper to simulate network failures
    func simulateNetworkFailure() async throws {
        throw NetworkError.networkUnavailable
    }
    
    /// Test helper to simulate timeout
    func simulateTimeout() async throws {
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        throw NetworkError.timeout
    }
    
    /// Test helper to verify retry logic
    func testRetryLogic() async -> Bool {
        do {
            _ = try await requestImageWithRetry(
                asset: PHAsset(), // This will fail
                configuration: .standard
            )
            return false
        } catch {
            // Expected to fail
            return true
        }
    }
}