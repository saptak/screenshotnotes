import Foundation
import SwiftData

/// Semantic Tagging Service for intelligent content analysis
/// Provides AI-powered semantic analysis and tagging of screenshots
public class SemanticTaggingService {
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Generate semantic tags for a screenshot based on its content
    /// - Parameters:
    ///   - screenshot: The screenshot to analyze
    ///   - extractedText: OCR-extracted text from the screenshot
    ///   - visualAttributes: Visual attributes from vision analysis
    /// - Returns: Array of semantic tags
    public func generateSemanticTags(
        for screenshot: Screenshot,
        extractedText: String?,
        visualAttributes: VisualAttributes?
    ) async -> SemanticTagCollection {
        
        var tags: [SemanticTag] = []
        
        // Simulate semantic analysis processing
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Analyze extracted text for semantic meaning
        if let text = extractedText, !text.isEmpty {
            tags.append(contentsOf: analyzeTextContent(text))
        }
        
        // Analyze visual attributes for semantic context
        if let attributes = visualAttributes {
            tags.append(contentsOf: analyzeVisualContent(attributes))
        }
        
        // Add temporal and contextual tags
        tags.append(contentsOf: generateContextualTags(for: screenshot))
        
        return SemanticTagCollection(tags: tags)
    }
    
    /// Update semantic analysis for a screenshot
    /// - Parameters:
    ///   - screenshot: The screenshot to update
    ///   - modelContext: SwiftData model context
    public func updateSemanticAnalysis(for screenshot: Screenshot, in modelContext: ModelContext) async {
        let tags = await generateSemanticTags(
            for: screenshot,
            extractedText: screenshot.extractedText,
            visualAttributes: screenshot.visualAttributes
        )
        
        // Update screenshot with new semantic tags
        screenshot.semanticTags = tags
        screenshot.lastSemanticAnalysis = Date()
        
        // Save changes
        do {
            try modelContext.save()
        } catch {
            print("SemanticTaggingService: Failed to save semantic analysis: \(error)")
        }
    }
    
    // MARK: - Private Analysis Methods
    
    private func analyzeTextContent(_ text: String) -> [SemanticTag] {
        var tags: [SemanticTag] = []
        let lowercaseText = text.lowercased()
        
        // Business and work-related content
        if containsBusinessTerms(lowercaseText) {
            tags.append(SemanticTag(
                name: "work",
                confidence: 0.8,
                source: .businessRecognition,
                category: .concept
            ))
        }
        
        // Financial content
        if containsFinancialTerms(lowercaseText) {
            tags.append(SemanticTag(
                name: "financial",
                confidence: 0.85,
                source: .contentClassification,
                category: .currency
            ))
        }
        
        // Travel content
        if containsTravelTerms(lowercaseText) {
            tags.append(SemanticTag(
                name: "travel",
                confidence: 0.9,
                source: .contentClassification,
                category: .concept
            ))
        }
        
        // Technology content
        if containsTechTerms(lowercaseText) {
            tags.append(SemanticTag(
                name: "tech",
                confidence: 0.75,
                source: .contentClassification,
                category: .concept
            ))
        }
        
        // Shopping content
        if containsShoppingTerms(lowercaseText) {
            tags.append(SemanticTag(
                name: "purchase",
                confidence: 0.8,
                source: .contentClassification,
                category: .action
            ))
        }
        
        return tags
    }
    
    private func analyzeVisualContent(_ attributes: VisualAttributes) -> [SemanticTag] {
        var tags: [SemanticTag] = []
        
        // Document type analysis
        if attributes.isDocument {
            tags.append(SemanticTag(
                name: "document",
                confidence: 0.9,
                source: .vision,
                category: .documentType
            ))
        }
        
        // Interface analysis
        if attributes.composition.layout == .grid {
            tags.append(SemanticTag(
                name: "ui",
                confidence: 0.8,
                source: .vision,
                category: .contentType
            ))
        }
        
        // Color-based analysis
        if let dominantColor = attributes.colorAnalysis.dominantColors.first {
            tags.append(SemanticTag(
                name: "color_\(dominantColor.colorName.lowercased())",
                confidence: 0.6,
                source: .vision,
                category: .color
            ))
        }
        
        return tags
    }
    
    private func generateContextualTags(for screenshot: Screenshot) -> [SemanticTag] {
        var tags: [SemanticTag] = []
        
        // Time-based tags
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: screenshot.timestamp)
        
        if hour >= 9 && hour <= 17 {
            tags.append(SemanticTag(
                name: "work_hours",
                confidence: 0.7,
                source: .aiGenerated,
                category: .temporal
            ))
        } else if hour >= 18 || hour <= 8 {
            tags.append(SemanticTag(
                name: "personal_time",
                confidence: 0.7,
                source: .aiGenerated,
                category: .temporal
            ))
        }
        
        // Day of week analysis
        let weekday = calendar.component(.weekday, from: screenshot.timestamp)
        if weekday >= 2 && weekday <= 6 { // Monday to Friday
            tags.append(SemanticTag(
                name: "weekday",
                confidence: 0.8,
                source: .aiGenerated,
                category: .temporal
            ))
        } else {
            tags.append(SemanticTag(
                name: "weekend",
                confidence: 0.8,
                source: .aiGenerated,
                category: .temporal
            ))
        }
        
        return tags
    }
    
    // MARK: - Text Analysis Helpers
    
    private func containsBusinessTerms(_ text: String) -> Bool {
        let businessTerms = ["meeting", "project", "deadline", "client", "proposal", "contract", "invoice", "budget", "report", "presentation", "email", "calendar", "schedule", "task", "team", "manager", "department", "office", "work", "business", "company", "organization"]
        return businessTerms.contains { text.contains($0) }
    }
    
    private func containsFinancialTerms(_ text: String) -> Bool {
        let financialTerms = ["$", "€", "£", "¥", "price", "cost", "payment", "bank", "account", "balance", "transaction", "receipt", "invoice", "bill", "expense", "income", "salary", "tax", "investment", "stock", "crypto", "bitcoin", "paypal", "venmo", "credit", "debit"]
        return financialTerms.contains { text.contains($0) }
    }
    
    private func containsTravelTerms(_ text: String) -> Bool {
        let travelTerms = ["flight", "hotel", "booking", "reservation", "airport", "airline", "ticket", "boarding", "gate", "departure", "arrival", "destination", "vacation", "trip", "travel", "passport", "visa", "rental", "car", "uber", "lyft", "taxi", "train", "bus", "airbnb"]
        return travelTerms.contains { text.contains($0) }
    }
    
    private func containsTechTerms(_ text: String) -> Bool {
        let techTerms = ["app", "software", "code", "programming", "developer", "github", "api", "database", "server", "cloud", "aws", "google", "microsoft", "apple", "ios", "android", "web", "website", "domain", "hosting", "ssl", "https", "javascript", "python", "swift"]
        return techTerms.contains { text.contains($0) }
    }
    
    private func containsShoppingTerms(_ text: String) -> Bool {
        let shoppingTerms = ["buy", "purchase", "order", "cart", "checkout", "shipping", "delivery", "amazon", "ebay", "shop", "store", "retail", "product", "item", "quantity", "size", "color", "brand", "model", "warranty", "return", "refund", "discount", "sale", "coupon"]
        return shoppingTerms.contains { text.contains($0) }
    }
}