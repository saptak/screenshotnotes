import Foundation
import OSLog
import SwiftData

/// Comprehensive analytics and monitoring service for vision processing accuracy and performance
@MainActor
public final class VisionAnalyticsService: ObservableObject {
    public static let shared = VisionAnalyticsService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "VisionAnalytics")
    private let analyticsQueue = DispatchQueue(label: "vision.analytics", qos: .utility)
    
    // Analytics data
    @Published private(set) var processingStats = ProcessingStatistics()
    @Published private(set) var accuracyMetrics = AccuracyMetrics()
    @Published private(set) var performanceMetrics = PerformanceMetrics()
    
    // Real-time monitoring
    @Published private(set) var isMonitoring = false
    @Published private(set) var realtimeStats = RealtimeStatistics()
    
    private var analyticsTimer: Timer?
    private var sessionStartTime = Date()
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        // Note: Cannot use async operations in deinit
        // Monitoring will be stopped automatically when the service is deallocated
    }
    
    // MARK: - Monitoring Control
    
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        sessionStartTime = Date()
        
        analyticsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRealtimeStats()
            }
        }
        
        logger.info("Vision analytics monitoring started")
    }
    
    public func stopMonitoring() {
        isMonitoring = false
        analyticsTimer?.invalidate()
        analyticsTimer = nil
        
        logger.info("Vision analytics monitoring stopped")
    }
    
    // MARK: - Data Collection
    
    public func recordProcessingStart(operationType: VisionOperationType, imageSize: CGSize, quality: ProcessingQuality) {
        analyticsQueue.async { [weak self] in
            Task { @MainActor in
                self?.processingStats.recordStart(operationType: operationType, imageSize: imageSize, quality: quality)
                self?.updateRealtimeStats()
            }
        }
    }
    
    public func recordProcessingCompletion(
        operationType: VisionOperationType,
        processingTime: TimeInterval,
        success: Bool,
        confidence: Double? = nil,
        error: Error? = nil
    ) {
        analyticsQueue.async { [weak self] in
            Task { @MainActor in
                self?.processingStats.recordCompletion(
                    operationType: operationType,
                    processingTime: processingTime,
                    success: success
                )
                
                if let confidence = confidence {
                    self?.accuracyMetrics.recordConfidence(operationType: operationType, confidence: confidence)
                }
                
                if let error = error {
                    self?.recordError(error: error, operationType: operationType)
                }
                
                self?.performanceMetrics.recordProcessingTime(operationType: operationType, time: processingTime)
                self?.updateRealtimeStats()
            }
        }
    }
    
    public func recordUserFeedback(
        operationType: VisionOperationType,
        wasAccurate: Bool,
        userRating: Int? = nil,
        comments: String? = nil
    ) {
        analyticsQueue.async { [weak self] in
            Task { @MainActor in
                self?.accuracyMetrics.recordUserFeedback(
                    operationType: operationType,
                    wasAccurate: wasAccurate,
                    userRating: userRating,
                    comments: comments
                )
                self?.updateRealtimeStats()
            }
        }
    }
    
    private func recordError(error: Error, operationType: VisionOperationType) {
        processingStats.recordError(error: error, operationType: operationType)
        logger.warning("Vision processing error recorded: \\(error.localizedDescription) for \\(operationType.rawValue)")
    }
    
    // MARK: - Analytics Queries
    
    public func getProcessingStatsFor(operationType: VisionOperationType) -> OperationStatistics? {
        return processingStats.statsFor(operationType: operationType)
    }
    
    public func getAccuracyFor(operationType: VisionOperationType) -> Double {
        return accuracyMetrics.accuracyFor(operationType: operationType)
    }
    
    public func getAverageProcessingTimeFor(operationType: VisionOperationType) -> TimeInterval {
        return performanceMetrics.averageProcessingTimeFor(operationType: operationType)
    }
    
    public func getOverallSuccessRate() -> Double {
        return processingStats.overallSuccessRate
    }
    
    public func getMostCommonErrors() -> [(String, Int)] {
        return processingStats.mostCommonErrors
    }
    
    public func getPerformanceTrends() -> PerformanceTrends {
        return performanceMetrics.trends
    }
    
    // MARK: - Real-time Updates
    
    private func updateRealtimeStats() {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        
        realtimeStats = RealtimeStatistics(
            sessionDuration: sessionDuration,
            operationsPerMinute: calculateOperationsPerMinute(),
            currentSuccessRate: processingStats.recentSuccessRate,
            averageConfidence: accuracyMetrics.recentAverageConfidence,
            averageProcessingTime: performanceMetrics.recentAverageTime,
            activeOperations: processingStats.activeOperationCount,
            memoryUsage: getCurrentMemoryUsage(),
            processingQueueDepth: getProcessingQueueDepth()
        )
    }
    
    private func calculateOperationsPerMinute() -> Double {
        let sessionMinutes = max(Date().timeIntervalSince(sessionStartTime) / 60.0, 1.0)
        return Double(processingStats.totalOperations) / sessionMinutes
    }
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size / 1024 / 1024) : 0 // MB
    }
    
    private func getProcessingQueueDepth() -> Int {
        // This would need to be implemented based on the actual processing queue
        return 0
    }
    
    // MARK: - Analytics Export
    
    public func exportAnalyticsData() -> AnalyticsExport {
        return AnalyticsExport(
            timestamp: Date(),
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            processingStats: processingStats,
            accuracyMetrics: accuracyMetrics,
            performanceMetrics: performanceMetrics,
            realtimeStats: realtimeStats
        )
    }
    
    public func exportAsJSON() throws -> Data {
        let export = exportAnalyticsData()
        return try JSONEncoder().encode(export)
    }
    
    public func exportAsCSV() -> String {
        var csv = "Operation Type,Total Count,Success Rate,Average Confidence,Average Time\\n"
        
        for operationType in VisionOperationType.allCases {
            _ = getProcessingStatsFor(operationType: operationType)
            _ = getAccuracyFor(operationType: operationType)
            _ = getAverageProcessingTimeFor(operationType: operationType)
            
            csv += "\\(operationType.rawValue),\\(stats?.totalCount ?? 0),\\(String(format: \"%.2f\", stats?.successRate ?? 0)),\\(String(format: \"%.2f\", accuracy)),\\(String(format: \"%.3f\", avgTime))\\n"
        }
        
        return csv
    }
    
    // MARK: - Data Reset
    
    public func resetAnalytics() {
        processingStats = ProcessingStatistics()
        accuracyMetrics = AccuracyMetrics()
        performanceMetrics = PerformanceMetrics()
        realtimeStats = RealtimeStatistics()
        sessionStartTime = Date()
        
        logger.info("Vision analytics data reset")
    }
    
    public func resetSessionData() {
        sessionStartTime = Date()
        updateRealtimeStats()
        
        logger.info("Vision analytics session data reset")
    }
}

// MARK: - Analytics Data Structures

public struct ProcessingStatistics: Codable {
    private var operationStats: [String: OperationStatistics] = [:]
    private var errorCounts: [String: Int] = [:]
    private var recentResults: [Bool] = []
    private var maxRecentResults = 100
    
    public var totalOperations: Int {
        operationStats.values.reduce(0) { $0 + $1.totalCount }
    }
    
    public var overallSuccessRate: Double {
        let totalCount = totalOperations
        let successCount = operationStats.values.reduce(0) { $0 + $1.successCount }
        return totalCount > 0 ? Double(successCount) / Double(totalCount) : 0.0
    }
    
    public var recentSuccessRate: Double {
        guard !recentResults.isEmpty else { return 0.0 }
        let successCount = recentResults.filter { $0 }.count
        return Double(successCount) / Double(recentResults.count)
    }
    
    public var activeOperationCount: Int {
        return operationStats.values.reduce(0) { $0 + $1.activeCount }
    }
    
    public var mostCommonErrors: [(String, Int)] {
        return errorCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
    
    mutating func recordStart(operationType: VisionOperationType, imageSize: CGSize, quality: ProcessingQuality) {
        let key = operationType.rawValue
        if operationStats[key] == nil {
            operationStats[key] = OperationStatistics(operationType: operationType)
        }
        operationStats[key]?.recordStart(imageSize: imageSize, quality: quality)
    }
    
    mutating func recordCompletion(operationType: VisionOperationType, processingTime: TimeInterval, success: Bool) {
        let key = operationType.rawValue
        operationStats[key]?.recordCompletion(processingTime: processingTime, success: success)
        
        // Update recent results
        recentResults.append(success)
        if recentResults.count > maxRecentResults {
            recentResults.removeFirst()
        }
    }
    
    mutating func recordError(error: Error, operationType: VisionOperationType) {
        let errorKey = "\\(operationType.rawValue)_\\(type(of: error))"
        errorCounts[errorKey, default: 0] += 1
    }
    
    func statsFor(operationType: VisionOperationType) -> OperationStatistics? {
        return operationStats[operationType.rawValue]
    }
}

public struct OperationStatistics: Codable {
    let operationType: VisionOperationType
    private(set) var totalCount = 0
    private(set) var successCount = 0
    private(set) var activeCount = 0
    private(set) var totalProcessingTime: TimeInterval = 0
    private(set) var imageSizes: [CGSize] = []
    private(set) var qualityDistribution: [String: Int] = [:]
    
    public var successRate: Double {
        return totalCount > 0 ? Double(successCount) / Double(totalCount) : 0.0
    }
    
    public var averageProcessingTime: TimeInterval {
        return totalCount > 0 ? totalProcessingTime / TimeInterval(totalCount) : 0.0
    }
    
    public var averageImageSize: CGSize {
        guard !imageSizes.isEmpty else { return .zero }
        let totalWidth = imageSizes.reduce(0) { $0 + $1.width }
        let totalHeight = imageSizes.reduce(0) { $0 + $1.height }
        return CGSize(
            width: totalWidth / CGFloat(imageSizes.count),
            height: totalHeight / CGFloat(imageSizes.count)
        )
    }
    
    init(operationType: VisionOperationType) {
        self.operationType = operationType
    }
    
    mutating func recordStart(imageSize: CGSize, quality: ProcessingQuality) {
        activeCount += 1
        imageSizes.append(imageSize)
        qualityDistribution[quality.rawValue, default: 0] += 1
    }
    
    mutating func recordCompletion(processingTime: TimeInterval, success: Bool) {
        totalCount += 1
        activeCount = max(0, activeCount - 1)
        totalProcessingTime += processingTime
        
        if success {
            successCount += 1
        }
    }
}

public struct AccuracyMetrics: Codable {
    private var confidenceScores: [String: [Double]] = [:]
    private var userFeedback: [String: UserFeedbackData] = [:]
    private var recentConfidenceScores: [Double] = []
    private var maxRecentScores = 50
    
    public var recentAverageConfidence: Double {
        guard !recentConfidenceScores.isEmpty else { return 0.0 }
        return recentConfidenceScores.reduce(0, +) / Double(recentConfidenceScores.count)
    }
    
    mutating func recordConfidence(operationType: VisionOperationType, confidence: Double) {
        let key = operationType.rawValue
        confidenceScores[key, default: []].append(confidence)
        
        recentConfidenceScores.append(confidence)
        if recentConfidenceScores.count > maxRecentScores {
            recentConfidenceScores.removeFirst()
        }
    }
    
    mutating func recordUserFeedback(operationType: VisionOperationType, wasAccurate: Bool, userRating: Int?, comments: String?) {
        let key = operationType.rawValue
        if userFeedback[key] == nil {
            userFeedback[key] = UserFeedbackData()
        }
        userFeedback[key]?.addFeedback(wasAccurate: wasAccurate, userRating: userRating, comments: comments)
    }
    
    func accuracyFor(operationType: VisionOperationType) -> Double {
        let key = operationType.rawValue
        guard let scores = confidenceScores[key], !scores.isEmpty else { return 0.0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    func userAccuracyFor(operationType: VisionOperationType) -> Double {
        let key = operationType.rawValue
        return userFeedback[key]?.accuracyRate ?? 0.0
    }
}

public struct UserFeedbackData: Codable {
    private(set) var totalFeedback = 0
    private(set) var accurateFeedback = 0
    private(set) var ratings: [Int] = []
    private(set) var comments: [String] = []
    
    public var accuracyRate: Double {
        return totalFeedback > 0 ? Double(accurateFeedback) / Double(totalFeedback) : 0.0
    }
    
    public var averageRating: Double {
        guard !ratings.isEmpty else { return 0.0 }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
    
    mutating func addFeedback(wasAccurate: Bool, userRating: Int?, comments: String?) {
        totalFeedback += 1
        if wasAccurate {
            accurateFeedback += 1
        }
        
        if let rating = userRating {
            ratings.append(rating)
        }
        
        if let comment = comments, !comment.isEmpty {
            self.comments.append(comment)
        }
    }
}

public struct PerformanceMetrics: Codable {
    private var processingTimes: [String: [TimeInterval]] = [:]
    private var recentTimes: [TimeInterval] = []
    private var maxRecentTimes = 50
    
    public var recentAverageTime: TimeInterval {
        guard !recentTimes.isEmpty else { return 0.0 }
        return recentTimes.reduce(0, +) / TimeInterval(recentTimes.count)
    }
    
    public var trends: PerformanceTrends {
        return PerformanceTrends(
            improvingOperations: getImprovingOperations(),
            degradingOperations: getDegradingOperations(),
            stableOperations: getStableOperations()
        )
    }
    
    mutating func recordProcessingTime(operationType: VisionOperationType, time: TimeInterval) {
        let key = operationType.rawValue
        processingTimes[key, default: []].append(time)
        
        recentTimes.append(time)
        if recentTimes.count > maxRecentTimes {
            recentTimes.removeFirst()
        }
    }
    
    func averageProcessingTimeFor(operationType: VisionOperationType) -> TimeInterval {
        let key = operationType.rawValue
        guard let times = processingTimes[key], !times.isEmpty else { return 0.0 }
        return times.reduce(0, +) / TimeInterval(times.count)
    }
    
    private func getImprovingOperations() -> [String] {
        // Simple trend analysis - compare recent vs historical averages
        return processingTimes.compactMap { (key, times) in
            guard times.count >= 10 else { return nil }
            let recent = times.suffix(5)
            let historical = times.prefix(times.count - 5)
            
            let recentAvg = recent.reduce(0, +) / TimeInterval(recent.count)
            let historicalAvg = historical.reduce(0, +) / TimeInterval(historical.count)
            
            return recentAvg < historicalAvg * 0.9 ? key : nil
        }
    }
    
    private func getDegradingOperations() -> [String] {
        return processingTimes.compactMap { (key, times) in
            guard times.count >= 10 else { return nil }
            let recent = times.suffix(5)
            let historical = times.prefix(times.count - 5)
            
            let recentAvg = recent.reduce(0, +) / TimeInterval(recent.count)
            let historicalAvg = historical.reduce(0, +) / TimeInterval(historical.count)
            
            return recentAvg > historicalAvg * 1.1 ? key : nil
        }
    }
    
    private func getStableOperations() -> [String] {
        return processingTimes.compactMap { (key, times) in
            guard times.count >= 10 else { return nil }
            let recent = times.suffix(5)
            let historical = times.prefix(times.count - 5)
            
            let recentAvg = recent.reduce(0, +) / TimeInterval(recent.count)
            let historicalAvg = historical.reduce(0, +) / TimeInterval(historical.count)
            
            let ratio = recentAvg / historicalAvg
            return (0.9...1.1).contains(ratio) ? key : nil
        }
    }
}

public struct PerformanceTrends: Codable {
    let improvingOperations: [String]
    let degradingOperations: [String]
    let stableOperations: [String]
}

public struct RealtimeStatistics: Codable {
    let sessionDuration: TimeInterval
    let operationsPerMinute: Double
    let currentSuccessRate: Double
    let averageConfidence: Double
    let averageProcessingTime: TimeInterval
    let activeOperations: Int
    let memoryUsage: Int // MB
    let processingQueueDepth: Int
    
    init(
        sessionDuration: TimeInterval = 0,
        operationsPerMinute: Double = 0,
        currentSuccessRate: Double = 0,
        averageConfidence: Double = 0,
        averageProcessingTime: TimeInterval = 0,
        activeOperations: Int = 0,
        memoryUsage: Int = 0,
        processingQueueDepth: Int = 0
    ) {
        self.sessionDuration = sessionDuration
        self.operationsPerMinute = operationsPerMinute
        self.currentSuccessRate = currentSuccessRate
        self.averageConfidence = averageConfidence
        self.averageProcessingTime = averageProcessingTime
        self.activeOperations = activeOperations
        self.memoryUsage = memoryUsage
        self.processingQueueDepth = processingQueueDepth
    }
}

public struct AnalyticsExport: Codable {
    let timestamp: Date
    let sessionDuration: TimeInterval
    let processingStats: ProcessingStatistics
    let accuracyMetrics: AccuracyMetrics
    let performanceMetrics: PerformanceMetrics
    let realtimeStats: RealtimeStatistics
}