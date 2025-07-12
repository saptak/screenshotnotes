import Foundation
import UIKit

/// Phase 2: Adaptive quality system that adjusts thumbnail resolution based on collection size
/// Prevents resource starvation by reducing quality for large collections
@MainActor
class AdaptiveQualityManager: ObservableObject {
    static let shared = AdaptiveQualityManager()
    
    // MARK: - Quality Configuration
    
    /// Quality levels for different collection sizes
    enum QualityLevel: CaseIterable {
        case maximum    // For small collections (< 100 items)
        case high       // For medium collections (100-500 items)
        case balanced   // For large collections (500-1000 items)
        case optimized  // For very large collections (1000+ items)
        
        var compressionQuality: CGFloat {
            switch self {
            case .maximum: return 0.95
            case .high: return 0.85
            case .balanced: return 0.75
            case .optimized: return 0.65
            }
        }
        
        var thumbnailSizeMultiplier: CGFloat {
            switch self {
            case .maximum: return 1.0
            case .high: return 0.9
            case .balanced: return 0.8
            case .optimized: return 0.7
            }
        }
        
        var description: String {
            switch self {
            case .maximum: return "Maximum Quality"
            case .high: return "High Quality"
            case .balanced: return "Balanced Quality"
            case .optimized: return "Optimized Quality"
            }
        }
    }
    
    // MARK: - State Management
    
    @Published var currentQualityLevel: QualityLevel = .maximum
    @Published var collectionSize: Int = 0
    @Published var isAdaptiveQualityEnabled = true
    
    // Device-specific adjustments
    private let deviceMemory = ProcessInfo.processInfo.physicalMemory
    private var isLowMemoryDevice: Bool {
        return deviceMemory < 4_000_000_000 // < 4GB
    }
    
    // Performance tracking
    private var qualityAdjustmentCount = 0
    private var lastQualityChange = Date()
    
    private init() {
        print("🎨 AdaptiveQualityManager initialized")
    }
    
    // MARK: - Public Interface
    
    /// Update collection size and adjust quality accordingly
    func updateCollectionSize(_ size: Int) {
        let previousQuality = currentQualityLevel
        collectionSize = size
        
        if isAdaptiveQualityEnabled {
            let newQuality = calculateOptimalQuality(for: size)
            
            if newQuality != currentQualityLevel {
                currentQualityLevel = newQuality
                qualityAdjustmentCount += 1
                lastQualityChange = Date()
                
                print("🎨 Quality adjusted from \(previousQuality.debugDescription) to \(newQuality.debugDescription) for \(size) screenshots")
            }
        }
    }
    
    /// Get optimal thumbnail size for current quality level
    func getOptimalThumbnailSize(baseSize: CGSize) -> CGSize {
        let multiplier = currentQualityLevel.thumbnailSizeMultiplier
        
        // Apply device-specific adjustments
        let deviceMultiplier = isLowMemoryDevice ? 0.9 : 1.0
        let finalMultiplier = multiplier * deviceMultiplier
        
        return CGSize(
            width: baseSize.width * finalMultiplier,
            height: baseSize.height * finalMultiplier
        )
    }
    
    /// Get compression quality for current level
    func getCompressionQuality() -> CGFloat {
        let baseQuality = currentQualityLevel.compressionQuality
        
        // Apply device-specific adjustments
        let deviceAdjustment = isLowMemoryDevice ? -0.05 : 0.0
        
        return max(0.5, min(1.0, baseQuality + deviceAdjustment))
    }
    
    /// Force specific quality level (for manual override)
    func setQualityLevel(_ level: QualityLevel) {
        currentQualityLevel = level
        isAdaptiveQualityEnabled = false
        print("🎨 Manual quality override: \(level.debugDescription)")
    }
    
    /// Re-enable adaptive quality
    func enableAdaptiveQuality() {
        isAdaptiveQualityEnabled = true
        updateCollectionSize(collectionSize) // Recalculate
        print("🎨 Adaptive quality re-enabled")
    }
    
    /// Get quality level for specific collection size (without changing current state)
    func getQualityLevel(for collectionSize: Int) -> QualityLevel {
        return calculateOptimalQuality(for: collectionSize)
    }
    
    // MARK: - Quality Calculation
    
    private func calculateOptimalQuality(for size: Int) -> QualityLevel {
        // Apply device-specific thresholds
        let smallThreshold = isLowMemoryDevice ? 75 : 100
        let mediumThreshold = isLowMemoryDevice ? 300 : 500
        let largeThreshold = isLowMemoryDevice ? 750 : 1000
        
        switch size {
        case 0..<smallThreshold:
            return .maximum
        case smallThreshold..<mediumThreshold:
            return .high
        case mediumThreshold..<largeThreshold:
            return .balanced
        default:
            return .optimized
        }
    }
    
    // MARK: - Resource Management
    
    /// Calculate estimated memory usage for thumbnail at current quality
    func estimateMemoryUsage(for size: CGSize) -> Int {
        let optimalSize = getOptimalThumbnailSize(baseSize: size)
        let bytesPerPixel = 4 // RGBA
        return Int(optimalSize.width * optimalSize.height) * bytesPerPixel
    }
    
    /// Get recommended batch size for current quality level
    func getRecommendedBatchSize() -> Int {
        switch currentQualityLevel {
        case .maximum:
            return isLowMemoryDevice ? 5 : 10
        case .high:
            return isLowMemoryDevice ? 8 : 15
        case .balanced:
            return isLowMemoryDevice ? 12 : 20
        case .optimized:
            return isLowMemoryDevice ? 15 : 25
        }
    }
    
    // MARK: - Performance Metrics
    
    var performanceMetrics: AdaptiveQualityMetrics {
        return AdaptiveQualityMetrics(
            currentQualityLevel: currentQualityLevel,
            collectionSize: collectionSize,
            isAdaptiveEnabled: isAdaptiveQualityEnabled,
            qualityAdjustmentCount: qualityAdjustmentCount,
            timeSinceLastAdjustment: Date().timeIntervalSince(lastQualityChange),
            isLowMemoryDevice: isLowMemoryDevice,
            currentCompressionQuality: getCompressionQuality(),
            currentSizeMultiplier: currentQualityLevel.thumbnailSizeMultiplier
        )
    }
}

// MARK: - Supporting Types

struct AdaptiveQualityMetrics {
    let currentQualityLevel: AdaptiveQualityManager.QualityLevel
    let collectionSize: Int
    let isAdaptiveEnabled: Bool
    let qualityAdjustmentCount: Int
    let timeSinceLastAdjustment: TimeInterval
    let isLowMemoryDevice: Bool
    let currentCompressionQuality: CGFloat
    let currentSizeMultiplier: CGFloat
}

// MARK: - Extensions

extension AdaptiveQualityManager.QualityLevel: CustomStringConvertible {
    var debugDescription: String {
        switch self {
        case .maximum: return "Maximum"
        case .high: return "High"
        case .balanced: return "Balanced"
        case .optimized: return "Optimized"
        }
    }
}