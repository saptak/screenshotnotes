import Foundation
import SwiftUI
import OSLog
import CoreML
import NaturalLanguage
import UIKit

/// Comprehensive smart categorization service using multi-signal analysis
@MainActor
public final class CategorizationService: ObservableObject {
    public static let shared = CategorizationService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "Categorization")
    private let processingQueue = DispatchQueue(label: "categorization.processing", qos: .userInitiated)
    
    // Service dependencies
    private let visionService = AdvancedVisionService.shared
    private let feedbackManager = CategoryFeedbackManager()
    private let learningEngine = CategoryLearningEngine()
    
    // Processing state
    @Published private(set) var isProcessing = false
    @Published private(set) var processingProgress: Double = 0.0
    @Published private(set) var lastCategorizationTime: TimeInterval = 0.0
    
    // Performance metrics
    private var processingMetrics = CategorizationMetrics()
    
    private init() {
        configureCategorizationEngine()
    }
    
    // MARK: - Main Categorization Interface
    
    /// Categorize a screenshot using multi-signal analysis
    public func categorizeScreenshot(_ image: UIImage, metadata: ScreenshotMetadata? = nil) async throws -> CategoryResult {
        let startTime = Date()
        
        // Update processing state
        isProcessing = true
        processingProgress = 0.0
        defer { isProcessing = false }
        
        logger.info("Starting multi-signal categorization")
        
        // Phase 1: Vision-based categorization (35% weight)
        processingProgress = 0.1
        let visionResult = try await performVisionCategorization(image)
        processingProgress = 0.4
        
        // Phase 2: Text-based categorization (30% weight)
        let textResult = try await performTextCategorization(image)
        processingProgress = 0.6
        
        // Phase 3: Metadata-based categorization (15% weight)
        let metadataResult = await performMetadataCategorization(metadata)
        processingProgress = 0.8
        
        // Phase 4: Temporal and contextual analysis (20% weight)
        let contextualResult = await performContextualCategorization(image, metadata: metadata)
        processingProgress = 0.9
        
        // Phase 5: Signal fusion and final categorization
        let finalResult = await fuseCategorizationSignals(
            vision: visionResult,
            text: textResult,
            metadata: metadataResult,
            contextual: contextualResult
        )
        
        // Update metrics
        let processingTime = Date().timeIntervalSince(startTime)
        lastCategorizationTime = processingTime
        processingMetrics.recordCategorization(duration: processingTime, result: finalResult)
        
        processingProgress = 1.0
        
        logger.info("Categorization completed in \(String(format: "%.2f", processingTime))s with confidence \(String(format: "%.2f", finalResult.confidence))")
        
        return finalResult
    }
    
    /// Batch categorize multiple screenshots
    public func categorizeScreenshots(_ images: [(UIImage, ScreenshotMetadata?)]) async throws -> [CategoryResult] {
        logger.info("Starting batch categorization for \(images.count) screenshots")
        
        var results: [CategoryResult] = []
        let totalCount = images.count
        
        for (index, (image, metadata)) in images.enumerated() {
            do {
                let result = try await categorizeScreenshot(image, metadata: metadata)
                results.append(result)
                
                // Update overall progress
                let progress = Double(index + 1) / Double(totalCount)
                await MainActor.run {
                    processingProgress = progress
                }
            } catch {
                logger.warning("Failed to categorize screenshot \(index): \(error.localizedDescription)")
                
                // Create fallback category result
                let fallbackResult = createFallbackCategoryResult()
                results.append(fallbackResult)
            }
        }
        
        logger.info("Batch categorization completed: \(results.count) results")
        return results
    }
    
    // MARK: - Vision-Based Categorization
    
    private func performVisionCategorization(_ image: UIImage) async throws -> SignalResult {
        do {
            let visionResults = try await visionService.analyzeImage(image)
            let sceneType = visionResults.sceneClassification.primaryScene
            
            // Map advanced scene type to category
            let category = mapSceneTypeToCategory(sceneType)
            let confidence = visionResults.sceneClassification.confidence
            
            return SignalResult(
                signal: .vision,
                category: category,
                confidence: confidence,
                details: ["scene_type": sceneType.rawValue, "vision_confidence": String(confidence)]
            )
        } catch {
            logger.warning("Vision categorization failed: \(error.localizedDescription)")
            
            // Return low-confidence fallback
            return SignalResult(
                signal: .vision,
                category: Category.categoryById("uncategorized")!,
                confidence: 0.1,
                details: ["error": error.localizedDescription]
            )
        }
    }
    
    private func mapSceneTypeToCategory(_ sceneType: AdvancedSceneType) -> Category {
        switch sceneType {
        case .receipt:
            return Category.categoryById("documents.receipts")!
        case .invoice:
            return Category.categoryById("documents.invoices")!
        case .businessCard:
            return Category.categoryById("work")!
        case .document, .form, .certificate:
            return Category.categoryById("documents")!
        case .webPage:
            return Category.categoryById("digital.websites")!
        case .mobileApp:
            return Category.categoryById("digital.apps")!
        case .socialMedia:
            return Category.categoryById("digital.social")!
        case .email:
            return Category.categoryById("digital.email")!
        case .message:
            return Category.categoryById("digital.messaging")!
        case .shopping:
            return Category.categoryById("shopping")!
        case .photo:
            return Category.categoryById("media.photos")!
        case .screenshot:
            return Category.categoryById("media.screenshots")!
        case .food, .menu:
            return Category.categoryById("financial.receipts.food")!
        case .people, .portrait, .group:
            return Category.categoryById("personal")!
        case .medicalContent:
            return Category.categoryById("health")!
        case .educationalContent:
            return Category.categoryById("education")!
        case .financialContent:
            return Category.categoryById("financial")!
        case .chart, .technicalDiagram:
            return Category.categoryById("technical")!
        case .qrCode, .barcode:
            return Category.categoryById("reference")!
        default:
            return Category.categoryById("uncategorized")!
        }
    }
    
    // MARK: - Text-Based Categorization
    
    private func performTextCategorization(_ image: UIImage) async throws -> SignalResult {
        // Use existing OCR service if available, otherwise fallback
        let extractedText = await extractTextFromImage(image)
        
        guard !extractedText.isEmpty else {
            return SignalResult(
                signal: .text,
                category: Category.categoryById("uncategorized")!,
                confidence: 0.0,
                details: ["text_length": "0"]
            )
        }
        
        // Analyze text content for categorization signals
        let textAnalysis = analyzeTextContent(extractedText)
        let category = determineTextBasedCategory(textAnalysis)
        
        return SignalResult(
            signal: .text,
            category: category.category,
            confidence: category.confidence,
            details: [
                "text_length": String(extractedText.count),
                "keywords_found": textAnalysis.matchedKeywords.joined(separator: ","),
                "language": textAnalysis.detectedLanguage ?? "unknown"
            ]
        )
    }
    
    private func extractTextFromImage(_ image: UIImage) async -> String {
        // This would integrate with existing OCR service
        // For now, return placeholder
        return ""
    }
    
    private func analyzeTextContent(_ text: String) -> TextAnalysis {
        let lowercaseText = text.lowercased()
        var matchedKeywords: [String] = []
        var categoryMatches: [Category: Int] = [:]
        
        // Analyze text against all category keywords
        for category in Category.predefinedCategories {
            let matches = category.keywords.filter { keyword in
                let found = lowercaseText.contains(keyword.lowercased())
                if found {
                    matchedKeywords.append(keyword)
                }
                return found
            }
            
            if !matches.isEmpty {
                categoryMatches[category] = matches.count
            }
        }
        
        // Detect language
        let languageRecognizer = NLLanguageRecognizer()
        languageRecognizer.processString(text)
        let detectedLanguage = languageRecognizer.dominantLanguage?.rawValue
        
        // Detect specific patterns
        let patterns = detectTextPatterns(text)
        
        return TextAnalysis(
            text: text,
            matchedKeywords: matchedKeywords,
            categoryMatches: categoryMatches,
            detectedLanguage: detectedLanguage,
            patterns: patterns
        )
    }
    
    private func detectTextPatterns(_ text: String) -> [TextPattern] {
        var patterns: [TextPattern] = []
        
        // Email pattern
        let emailRegex = try? NSRegularExpression(pattern: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", options: [])
        if let emailMatches = emailRegex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           !emailMatches.isEmpty {
            patterns.append(.email)
        }
        
        // Phone pattern
        let phoneRegex = try? NSRegularExpression(pattern: "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b", options: [])
        if let phoneMatches = phoneRegex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           !phoneMatches.isEmpty {
            patterns.append(.phone)
        }
        
        // URL pattern
        let urlRegex = try? NSRegularExpression(pattern: "https?://[^\\s]+", options: [])
        if let urlMatches = urlRegex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           !urlMatches.isEmpty {
            patterns.append(.url)
        }
        
        // Currency pattern
        let currencyRegex = try? NSRegularExpression(pattern: "\\$\\d+\\.\\d{2}|\\d+\\.\\d{2}\\s*(USD|EUR|GBP)", options: [])
        if let currencyMatches = currencyRegex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           !currencyMatches.isEmpty {
            patterns.append(.currency)
        }
        
        // Date pattern
        let dateRegex = try? NSRegularExpression(pattern: "\\d{1,2}/\\d{1,2}/\\d{4}|\\d{4}-\\d{2}-\\d{2}", options: [])
        if let dateMatches = dateRegex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           !dateMatches.isEmpty {
            patterns.append(.date)
        }
        
        return patterns
    }
    
    private func determineTextBasedCategory(_ analysis: TextAnalysis) -> (category: Category, confidence: Double) {
        // Pattern-based categorization with high confidence
        if analysis.patterns.contains(.currency) && analysis.patterns.contains(.date) {
            return (Category.categoryById("documents.receipts")!, 0.9)
        }
        
        if analysis.patterns.contains(.email) && analysis.patterns.contains(.phone) {
            return (Category.categoryById("work")!, 0.8)
        }
        
        if analysis.patterns.contains(.url) {
            return (Category.categoryById("digital.websites")!, 0.7)
        }
        
        // Keyword-based categorization
        if let topCategory = analysis.categoryMatches.max(by: { $0.value < $1.value }) {
            let confidence = min(0.8, Double(topCategory.value) / 5.0) // Scale confidence based on keyword matches
            return (topCategory.key, confidence)
        }
        
        return (Category.categoryById("uncategorized")!, 0.1)
    }
    
    // MARK: - Metadata-Based Categorization
    
    private func performMetadataCategorization(_ metadata: ScreenshotMetadata?) async -> SignalResult {
        guard let metadata = metadata else {
            return SignalResult(
                signal: .metadata,
                category: Category.categoryById("uncategorized")!,
                confidence: 0.0,
                details: ["metadata": "none"]
            )
        }
        
        var categoryScores: [Category: Double] = [:]
        var details: [String: String] = [:]
        
        // Analyze app source
        if let appName = metadata.sourceApp {
            details["source_app"] = appName
            
            if let appCategory = categorizeByAppSource(appName) {
                categoryScores[appCategory.category] = appCategory.confidence
            }
        }
        
        // Analyze file size (large files might be photos/media)
        if let fileSize = metadata.fileSize {
            details["file_size"] = String(fileSize)
            
            if fileSize > 1_000_000 { // > 1MB likely media
                if let mediaCategory = Category.categoryById("media") {
                    categoryScores[mediaCategory] = 0.6
                }
            }
        }
        
        // Analyze timestamp patterns
        if let timestamp = metadata.timestamp {
            details["timestamp"] = timestamp.ISO8601Format()
            
            if let timeCategory = categorizeByTimePattern(timestamp) {
                categoryScores[timeCategory.category] = timeCategory.confidence
            }
        }
        
        // Find best category
        if let topCategory = categoryScores.max(by: { $0.value < $1.value }) {
            return SignalResult(
                signal: .metadata,
                category: topCategory.key,
                confidence: topCategory.value,
                details: details
            )
        }
        
        return SignalResult(
            signal: .metadata,
            category: Category.categoryById("uncategorized")!,
            confidence: 0.1,
            details: details
        )
    }
    
    private func categorizeByAppSource(_ appName: String) -> (category: Category, confidence: Double)? {
        let lowercaseApp = appName.lowercased()
        
        // Social media apps
        if ["instagram", "facebook", "twitter", "tiktok", "snapchat", "linkedin"].contains(where: lowercaseApp.contains) {
            return (Category.categoryById("digital.social")!, 0.8)
        }
        
        // Messaging apps
        if ["messages", "whatsapp", "telegram", "slack", "discord", "teams"].contains(where: lowercaseApp.contains) {
            return (Category.categoryById("digital.messaging")!, 0.8)
        }
        
        // Email apps
        if ["mail", "gmail", "outlook", "yahoo"].contains(where: lowercaseApp.contains) {
            return (Category.categoryById("digital.email")!, 0.8)
        }
        
        // Shopping apps
        if ["amazon", "shop", "store", "retail", "buy"].contains(where: lowercaseApp.contains) {
            return (Category.categoryById("shopping")!, 0.7)
        }
        
        // Web browsers
        if ["safari", "chrome", "firefox", "edge"].contains(where: lowercaseApp.contains) {
            return (Category.categoryById("digital.websites")!, 0.6)
        }
        
        return nil
    }
    
    private func categorizeByTimePattern(_ timestamp: Date) -> (category: Category, confidence: Double)? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        
        // Work hours (9-17) might indicate work-related content
        if (9...17).contains(hour) {
            return (Category.categoryById("work")!, 0.3)
        }
        
        // Evening hours might indicate personal content
        if (19...23).contains(hour) {
            return (Category.categoryById("personal")!, 0.2)
        }
        
        return nil
    }
    
    // MARK: - Contextual Categorization
    
    private func performContextualCategorization(_ image: UIImage, metadata: ScreenshotMetadata?) async -> SignalResult {
        // This would analyze context like recent screenshots, user behavior patterns, etc.
        // For now, return minimal contextual analysis
        
        return SignalResult(
            signal: .contextual,
            category: Category.categoryById("uncategorized")!,
            confidence: 0.0,
            details: ["context": "basic"]
        )
    }
    
    // MARK: - Signal Fusion
    
    private func fuseCategorizationSignals(
        vision: SignalResult,
        text: SignalResult,
        metadata: SignalResult,
        contextual: SignalResult
    ) async -> CategoryResult {
        
        let signals = [vision, text, metadata, contextual]
        var categoryScores: [String: Double] = [:]
        var allSignals: [ClassificationSignal] = []
        
        // Weight and combine signals
        for signalResult in signals {
            let weight = signalResult.signal.weight
            let weightedConfidence = signalResult.confidence * weight
            
            categoryScores[signalResult.category.id, default: 0.0] += weightedConfidence
            allSignals.append(signalResult.signal)
        }
        
        // Apply user feedback learning
        categoryScores = await learningEngine.applyLearning(to: categoryScores)
        
        // Find top categories
        let sortedCategories = categoryScores.sorted { $0.value > $1.value }
        
        guard let topCategoryEntry = sortedCategories.first,
              let topCategory = Category.categoryById(topCategoryEntry.key) else {
            return createFallbackCategoryResult()
        }
        
        let finalConfidence = topCategoryEntry.value
        
        // Create alternative categories
        let alternatives = sortedCategories.dropFirst().prefix(3).compactMap { entry -> CategoryConfidence? in
            guard let category = Category.categoryById(entry.key) else { return nil }
            return CategoryConfidence(category: category, confidence: entry.value)
        }
        
        // Calculate uncertainty
        let uncertainty = calculateUncertainty(scores: categoryScores, topConfidence: finalConfidence)
        
        return CategoryResult(
            category: topCategory,
            confidence: finalConfidence,
            signals: allSignals,
            uncertainty: uncertainty,
            alternativeCategories: alternatives
        )
    }
    
    private func calculateUncertainty(scores: [String: Double], topConfidence: Double) -> UncertaintyMeasure {
        let values = Array(scores.values)
        
        // Calculate entropy
        let totalScore = values.reduce(0, +)
        let probabilities = values.map { $0 / max(totalScore, 0.001) }
        let entropy = -probabilities.reduce(0) { result, p in
            result + (p > 0 ? p * log2(p) : 0)
        }
        
        // Calculate margin (difference between top two)
        let sortedValues = values.sorted(by: >)
        let margin = sortedValues.count > 1 ? sortedValues[0] - sortedValues[1] : topConfidence
        
        // Calculate variance
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { result, value in
            result + pow(value - mean, 2)
        } / Double(values.count)
        
        return UncertaintyMeasure(entropy: entropy, margin: margin, variance: variance)
    }
    
    // MARK: - Feedback Integration
    
    /// Submit user feedback for category learning
    public func submitFeedback(_ feedback: CategoryFeedback) async {
        await feedbackManager.storeFeedback(feedback)
        await learningEngine.updateLearning(with: feedback)
        
        logger.info("Category feedback submitted: \(feedback.feedbackType.rawValue)")
    }
    
    /// Get categorization accuracy metrics
    public func getAccuracyMetrics() -> CategorizationMetrics {
        return processingMetrics
    }
    
    // MARK: - Utility Methods
    
    private func createFallbackCategoryResult() -> CategoryResult {
        return CategoryResult(
            category: Category.categoryById("uncategorized")!,
            confidence: 0.1,
            signals: [.vision, .text, .metadata],
            uncertainty: UncertaintyMeasure(entropy: 1.0, margin: 0.0, variance: 1.0)
        )
    }
    
    private func configureCategorizationEngine() {
        logger.info("Categorization engine configured with \(Category.predefinedCategories.count) categories")
    }
}

// MARK: - Supporting Data Structures

/// Signal-specific categorization result
public struct SignalResult {
    let signal: ClassificationSignal
    let category: Category
    let confidence: Double
    let details: [String: String]
}

/// Text analysis results
public struct TextAnalysis {
    let text: String
    let matchedKeywords: [String]
    let categoryMatches: [Category: Int]
    let detectedLanguage: String?
    let patterns: [TextPattern]
}

/// Detected text patterns
public enum TextPattern: String, CaseIterable {
    case email = "email"
    case phone = "phone"
    case url = "url"
    case currency = "currency"
    case date = "date"
    case address = "address"
    case creditCard = "credit_card"
}

/// Screenshot metadata for categorization
public struct ScreenshotMetadata: Codable {
    public let timestamp: Date?
    public let sourceApp: String?
    public let fileSize: Int?
    public let dimensions: CGSize?
    public let colorSpace: String?
    public let hasGPS: Bool?
    
    public init(
        timestamp: Date? = nil,
        sourceApp: String? = nil,
        fileSize: Int? = nil,
        dimensions: CGSize? = nil,
        colorSpace: String? = nil,
        hasGPS: Bool? = nil
    ) {
        self.timestamp = timestamp
        self.sourceApp = sourceApp
        self.fileSize = fileSize
        self.dimensions = dimensions
        self.colorSpace = colorSpace
        self.hasGPS = hasGPS
    }
}

// MARK: - Category Feedback Manager

@MainActor
public class CategoryFeedbackManager {
    private var feedbackHistory: [CategoryFeedback] = []
    private let maxHistorySize = 1000
    
    public func storeFeedback(_ feedback: CategoryFeedback) async {
        feedbackHistory.append(feedback)
        
        // Limit history size
        if feedbackHistory.count > maxHistorySize {
            feedbackHistory.removeFirst(feedbackHistory.count - maxHistorySize)
        }
    }
    
    public func getFeedbackHistory() -> [CategoryFeedback] {
        return feedbackHistory
    }
    
    public func getAccuracyRate() -> Double {
        guard !feedbackHistory.isEmpty else { return 0.0 }
        
        let correctCount = feedbackHistory.filter { $0.isCorrect }.count
        return Double(correctCount) / Double(feedbackHistory.count)
    }
}

// MARK: - Category Learning Engine

@MainActor
public class CategoryLearningEngine {
    private var categoryWeights: [String: Double] = [:]
    private var signalWeights: [ClassificationSignal: Double] = [:]
    
    public func updateLearning(with feedback: CategoryFeedback) async {
        // Adjust category weights based on feedback
        if feedback.isCorrect {
            categoryWeights[feedback.originalCategory.id, default: 1.0] *= 1.1
        } else {
            categoryWeights[feedback.originalCategory.id, default: 1.0] *= 0.9
            
            if let corrected = feedback.correctedCategory {
                categoryWeights[corrected.id, default: 1.0] *= 1.2
            }
        }
        
        // Normalize weights
        let totalWeight = categoryWeights.values.reduce(0, +)
        if totalWeight > 0 {
            for key in categoryWeights.keys {
                categoryWeights[key] = categoryWeights[key]! / totalWeight
            }
        }
    }
    
    public func applyLearning(to scores: [String: Double]) async -> [String: Double] {
        var adjustedScores = scores
        
        for (categoryId, weight) in categoryWeights {
            if let currentScore = adjustedScores[categoryId] {
                adjustedScores[categoryId] = currentScore * weight
            }
        }
        
        return adjustedScores
    }
}

// MARK: - Performance Metrics

public struct CategorizationMetrics {
    private var totalCategorizations = 0
    private var totalProcessingTime: TimeInterval = 0
    private var accuracyHistory: [Double] = []
    
    mutating func recordCategorization(duration: TimeInterval, result: CategoryResult) {
        totalCategorizations += 1
        totalProcessingTime += duration
        
        // Record confidence as proxy for accuracy
        accuracyHistory.append(result.confidence)
        
        // Limit history
        if accuracyHistory.count > 100 {
            accuracyHistory.removeFirst()
        }
    }
    
    public var averageProcessingTime: TimeInterval {
        return totalCategorizations > 0 ? totalProcessingTime / TimeInterval(totalCategorizations) : 0
    }
    
    public var averageConfidence: Double {
        return accuracyHistory.isEmpty ? 0 : accuracyHistory.reduce(0, +) / Double(accuracyHistory.count)
    }
    
    public var categorizationCount: Int {
        return totalCategorizations
    }
}