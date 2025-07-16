import Foundation
import SwiftData
import SwiftUI
import OSLog

/// Advanced content-aware search engine for intelligent screenshot discovery
/// Provides specialized search capabilities for text, websites, apps, and contact information
@MainActor
public final class ContentAwareSearchEngine: ObservableObject {
    public static let shared = ContentAwareSearchEngine()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ContentAwareSearch")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var lastContentAnalysis: ContentAnalysisResult?
    @Published public private(set) var contentPatterns: [ContentPattern] = []
    @Published public private(set) var contentCategories: [ContentCategory] = []
    
    // MARK: - Services
    
    // Entity extraction service would be initialized when needed
    private let hapticService = HapticFeedbackService.shared
    
    // MARK: - Configuration
    
    public struct ContentSearchSettings {
        var enableAdvancedPatternRecognition: Bool = true
        var enableContextualGrouping: Bool = true
        var enableContentPrediction: Bool = true
        var minimumPatternConfidence: Double = 0.7
        var maxContentCategories: Int = 20
        var enablePhoneNumberValidation: Bool = true
        var enableEmailValidation: Bool = true
        var enableWebsiteClassification: Bool = true
        
        public init() {}
    }
    
    @Published public var settings = ContentSearchSettings()
    
    // MARK: - Data Models
    
    /// Content analysis result with detailed categorization
    public struct ContentAnalysisResult: Identifiable {
        public let id = UUID()
        let query: String
        let detectedPatterns: [ContentPattern]
        let contentTypes: [ContentType]
        let confidenceScore: Double
        let suggestedFilters: [SearchFilter]
        let timestamp: Date
        
        public init(
            query: String,
            detectedPatterns: [ContentPattern] = [],
            contentTypes: [ContentType] = [],
            confidenceScore: Double = 0.0,
            suggestedFilters: [SearchFilter] = [],
            timestamp: Date = Date()
        ) {
            self.query = query
            self.detectedPatterns = detectedPatterns
            self.contentTypes = contentTypes
            self.confidenceScore = confidenceScore
            self.suggestedFilters = suggestedFilters
            self.timestamp = timestamp
        }
    }
    
    /// Advanced content pattern recognition
    public struct ContentPattern: Identifiable {
        public let id = UUID()
        let type: PatternType
        let pattern: String
        let confidence: Double
        let context: PatternContext
        let examples: [String]
        
        public enum PatternType: String, CaseIterable {
            case phoneNumber = "phone_number"
            case email = "email"
            case website = "website"
            case socialMedia = "social_media"
            case address = "address"
            case creditCard = "credit_card"
            case date = "date"
            case time = "time"
            case currency = "currency"
            case percentage = "percentage"
            case hashtag = "hashtag"
            case mention = "mention"
            case qrCode = "qr_code"
            case barcode = "barcode"
            case serialNumber = "serial_number"
            case trackingNumber = "tracking_number"
            case license = "license"
            case invoice = "invoice"
            case receipt = "receipt"
            case businessCard = "business_card"
        }
        
        public struct PatternContext {
            let source: String
            let likelihood: Double
            let relatedPatterns: [String]
            let metadata: [String: String]
        }
    }
    
    /// Enhanced content type classification
    public enum ContentType: String, CaseIterable {
        case text = "text"
        case document = "document"
        case receipt = "receipt"
        case businessCard = "business_card"
        case website = "website"
        case socialMedia = "social_media"
        case messaging = "messaging"
        case email = "email"
        case contact = "contact"
        case calendar = "calendar"
        case map = "map"
        case photo = "photo"
        case screenshot = "screenshot"
        case qrCode = "qr_code"
        case menu = "menu"
        case ticket = "ticket"
        case invoice = "invoice"
        case form = "form"
        case app = "app"
        case game = "game"
        case news = "news"
        case shopping = "shopping"
        case travel = "travel"
        case medical = "medical"
        case financial = "financial"
        case educational = "educational"
        case entertainment = "entertainment"
        
        public var displayName: String {
            switch self {
            case .text: return "Text Content"
            case .document: return "Documents"
            case .receipt: return "Receipts"
            case .businessCard: return "Business Cards"
            case .website: return "Websites"
            case .socialMedia: return "Social Media"
            case .messaging: return "Messages"
            case .email: return "Emails"
            case .contact: return "Contacts"
            case .calendar: return "Calendar Events"
            case .map: return "Maps & Locations"
            case .photo: return "Photos"
            case .screenshot: return "Screenshots"
            case .qrCode: return "QR Codes"
            case .menu: return "Menus"
            case .ticket: return "Tickets"
            case .invoice: return "Invoices"
            case .form: return "Forms"
            case .app: return "Apps"
            case .game: return "Games"
            case .news: return "News"
            case .shopping: return "Shopping"
            case .travel: return "Travel"
            case .medical: return "Medical"
            case .financial: return "Financial"
            case .educational: return "Educational"
            case .entertainment: return "Entertainment"
            }
        }
        
        public var searchKeywords: [String] {
            switch self {
            case .receipt:
                return ["receipt", "total", "tax", "subtotal", "bill", "purchase", "transaction"]
            case .businessCard:
                return ["business card", "contact", "phone", "email", "company", "title"]
            case .website:
                return ["http", "www", "website", "url", "link", "site"]
            case .socialMedia:
                return ["facebook", "twitter", "instagram", "linkedin", "social", "post", "like", "share"]
            case .email:
                return ["@", "email", "subject", "from", "to", "message"]
            case .contact:
                return ["phone", "mobile", "contact", "name", "address"]
            case .qrCode:
                return ["qr", "code", "scan", "barcode"]
            case .invoice:
                return ["invoice", "bill", "amount", "due", "payment", "number"]
            default:
                return [rawValue]
            }
        }
    }
    
    /// Content category for organization
    public struct ContentCategory: Identifiable {
        public let id = UUID()
        let name: String
        let type: ContentType
        let patterns: [ContentPattern]
        let screenshotCount: Int
        let confidence: Double
        let lastUpdated: Date
        let suggestedActions: [String]
    }
    
    /// Advanced search filter
    public struct SearchFilter: Identifiable {
        public let id = UUID()
        let type: FilterType
        let value: String
        let confidence: Double
        let description: String
        
        public enum FilterType: String, CaseIterable {
            case contentType = "content_type"
            case hasText = "has_text"
            case hasPattern = "has_pattern"
            case fromApp = "from_app"
            case containsWebsite = "contains_website"
            case hasContactInfo = "has_contact_info"
            case hasFinancialInfo = "has_financial_info"
            case documentType = "document_type"
        }
    }
    
    // MARK: - Pattern Recognition Data
    
    private let phonePatterns = [
        "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b",                    // US format
        "\\b\\(\\d{3}\\)\\s?\\d{3}[-.]?\\d{4}\\b",              // (555) 123-4567
        "\\b\\+1\\s?\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b",           // +1 555-123-4567
        "\\b1[-.]\\d{3}[-.]\\d{3}[-.]\\d{4}\\b",                // 1-555-123-4567
        "\\b\\+\\d{1,3}\\s?\\d{3,4}[-.]?\\d{3,4}[-.]?\\d{3,4}\\b" // International
    ]
    
    private let emailPatterns = [
        "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b",
        "\\b[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\\b"
    ]
    
    private let websitePatterns = [
        "\\bhttps?://[^\\s]+\\b",
        "\\bwww\\.[^\\s]+\\.[a-z]{2,}\\b",
        "\\b[a-zA-Z0-9.-]+\\.(com|org|net|edu|gov|mil|int|co|uk|de|fr|jp|au|ca)\\b"
    ]
    
    private let socialMediaPatterns = [
        "@\\w+",                           // Twitter handles
        "#\\w+",                           // Hashtags
        "facebook\\.com/\\w+",             // Facebook profiles
        "instagram\\.com/\\w+",            // Instagram profiles
        "linkedin\\.com/in/\\w+",          // LinkedIn profiles
        "twitter\\.com/\\w+",              // Twitter profiles
        "youtube\\.com/(?:c/|channel/|user/)\\w+" // YouTube channels
    ]
    
    private let financialPatterns = [
        "\\$\\d+(?:\\.\\d{2})?",           // Currency amounts
        "\\b\\d{4}\\s?\\d{4}\\s?\\d{4}\\s?\\d{4}\\b", // Credit card
        "\\b\\d{3}-\\d{2}-\\d{4}\\b",      // SSN
        "invoice\\s?#?\\s?\\d+",           // Invoice numbers
        "order\\s?#?\\s?\\d+",             // Order numbers
        "account\\s?#?\\s?\\d+"            // Account numbers
    ]
    
    private let documentPatterns = [
        "receipt",
        "invoice",
        "bill",
        "statement",
        "contract",
        "agreement",
        "document",
        "form",
        "application",
        "certificate"
    ]
    
    // MARK: - Initialization
    
    private init() {
        logger.info("ContentAwareSearchEngine initialized with advanced pattern recognition")
    }
    
    // MARK: - Public Interface
    
    /// Analyze content patterns in a query for intelligent search enhancement
    /// - Parameter query: Natural language search query
    /// - Returns: Detailed content analysis with suggested filters
    public func analyzeContentQuery(_ query: String) async -> ContentAnalysisResult {
        logger.debug("Analyzing content query: '\(query)'")
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Step 1: Detect content patterns
        let detectedPatterns = await detectContentPatterns(in: normalizedQuery)
        
        // Step 2: Classify content types
        let contentTypes = await classifyContentTypes(from: normalizedQuery, patterns: detectedPatterns)
        
        // Step 3: Calculate confidence score
        let confidenceScore = calculateContentAnalysisConfidence(patterns: detectedPatterns, types: contentTypes)
        
        // Step 4: Generate suggested filters
        let suggestedFilters = await generateSearchFilters(from: detectedPatterns, types: contentTypes)
        
        let result = ContentAnalysisResult(
            query: query,
            detectedPatterns: detectedPatterns,
            contentTypes: contentTypes,
            confidenceScore: confidenceScore,
            suggestedFilters: suggestedFilters
        )
        
        lastContentAnalysis = result
        
        logger.info("Content analysis completed: \(detectedPatterns.count) patterns, \(contentTypes.count) types, confidence: \(String(format: "%.2f", confidenceScore))")
        
        return result
    }
    
    /// Search screenshots with content-aware filtering
    /// - Parameters:
    ///   - query: Search query
    ///   - screenshots: Screenshots to search within
    ///   - contentTypes: Specific content types to filter for
    /// - Returns: Filtered and ranked screenshots
    public func searchWithContentAwareness(
        query: String,
        in screenshots: [Screenshot],
        filterBy contentTypes: [ContentType] = [],
        patterns: [ContentPattern] = []
    ) async -> [Screenshot] {
        
        logger.debug("Content-aware search: query='\(query)', \(screenshots.count) screenshots, \(contentTypes.count) content filters")
        
        var filteredScreenshots = screenshots
        
        // Apply content type filters
        if !contentTypes.isEmpty {
            filteredScreenshots = await applyContentTypeFilters(filteredScreenshots, types: contentTypes)
        }
        
        // Apply pattern filters
        if !patterns.isEmpty {
            filteredScreenshots = await applyPatternFilters(filteredScreenshots, patterns: patterns)
        }
        
        // Rank results by content relevance
        let rankedResults = await rankByContentRelevance(filteredScreenshots, query: query, types: contentTypes)
        
        return rankedResults
    }
    
    /// Get content categories for organization
    /// - Parameter screenshots: Screenshots to categorize
    /// - Returns: Array of content categories with patterns
    public func categorizeContent(from screenshots: [Screenshot]) async -> [ContentCategory] {
        logger.debug("Categorizing content from \(screenshots.count) screenshots")
        
        var categories: [ContentCategory] = []
        var contentTypeCounts: [ContentType: Int] = [:]
        var typePatterns: [ContentType: [ContentPattern]] = [:]
        
        // Analyze each screenshot for content
        for screenshot in screenshots {
            let content = [
                screenshot.extractedText,
                screenshot.userNotes,
                screenshot.filename
            ].compactMap { $0 }.joined(separator: " ")
            
            let patterns = await detectContentPatterns(in: content)
            let types = await classifyContentTypes(from: content, patterns: patterns)
            
            for type in types {
                contentTypeCounts[type, default: 0] += 1
                typePatterns[type, default: []].append(contentsOf: patterns)
            }
        }
        
        // Create categories for significant content types
        for (contentType, count) in contentTypeCounts {
            if count >= 3 { // Minimum threshold for category creation
                let patterns = typePatterns[contentType] ?? []
                let uniquePatterns = Array(Set(patterns.map { $0.pattern }))
                    .compactMap { pattern in patterns.first { $0.pattern == pattern } }
                
                let category = ContentCategory(
                    name: contentType.displayName,
                    type: contentType,
                    patterns: uniquePatterns,
                    screenshotCount: count,
                    confidence: calculateCategoryConfidence(count: count, totalScreenshots: screenshots.count),
                    lastUpdated: Date(),
                    suggestedActions: generateCategoryActions(for: contentType)
                )
                
                categories.append(category)
            }
        }
        
        // Sort by screenshot count and confidence
        let sortedCategories = categories
            .sorted { ($0.screenshotCount, $0.confidence) > ($1.screenshotCount, $1.confidence) }
            .prefix(settings.maxContentCategories)
            .map { $0 }
        
        contentCategories = sortedCategories
        
        logger.info("Created \(sortedCategories.count) content categories")
        return sortedCategories
    }
    
    /// Get intelligent content suggestions based on patterns
    /// - Parameter query: Partial or complete query
    /// - Returns: Content-aware search suggestions
    public func getContentSuggestions(for query: String) async -> [String] {
        let normalizedQuery = query.lowercased()
        var suggestions: [String] = []
        
        // Suggest content type searches
        for contentType in ContentType.allCases {
            if contentType.searchKeywords.contains(where: { normalizedQuery.contains($0) }) {
                suggestions.append("screenshots with \(contentType.displayName.lowercased())")
                suggestions.append("all my \(contentType.displayName.lowercased())")
            }
        }
        
        // Suggest pattern-based searches
        if normalizedQuery.contains("phone") || normalizedQuery.contains("number") {
            suggestions.append("screenshots with phone numbers")
            suggestions.append("contact information")
        }
        
        if normalizedQuery.contains("email") || normalizedQuery.contains("@") {
            suggestions.append("screenshots with email addresses")
            suggestions.append("email conversations")
        }
        
        if normalizedQuery.contains("website") || normalizedQuery.contains("link") {
            suggestions.append("screenshots of websites")
            suggestions.append("web pages I visited")
        }
        
        if normalizedQuery.contains("receipt") || normalizedQuery.contains("bill") {
            suggestions.append("all my receipts")
            suggestions.append("expense receipts")
            suggestions.append("shopping receipts")
        }
        
        return Array(Set(suggestions)).prefix(8).map { $0 }
    }
    
    // MARK: - Pattern Detection
    
    private func detectContentPatterns(in text: String) async -> [ContentPattern] {
        var patterns: [ContentPattern] = []
        
        // Phone number detection
        for phonePattern in phonePatterns {
            let matches = text.matches(of: phonePattern)
            for match in matches {
                patterns.append(ContentPattern(
                    type: .phoneNumber,
                    pattern: phonePattern,
                    confidence: 0.9,
                    context: ContentPattern.PatternContext(
                        source: "regex_detection",
                        likelihood: 0.9,
                        relatedPatterns: ["contact", "phone", "call"],
                        metadata: ["format": "phone_number"]
                    ),
                    examples: [String(match)]
                ))
            }
        }
        
        // Email detection
        for emailPattern in emailPatterns {
            let matches = text.matches(of: emailPattern)
            for match in matches {
                patterns.append(ContentPattern(
                    type: .email,
                    pattern: emailPattern,
                    confidence: 0.95,
                    context: ContentPattern.PatternContext(
                        source: "regex_detection",
                        likelihood: 0.95,
                        relatedPatterns: ["email", "contact", "message"],
                        metadata: ["format": "email_address"]
                    ),
                    examples: [String(match)]
                ))
            }
        }
        
        // Website detection
        for websitePattern in websitePatterns {
            let matches = text.matches(of: websitePattern)
            for match in matches {
                patterns.append(ContentPattern(
                    type: .website,
                    pattern: websitePattern,
                    confidence: 0.85,
                    context: ContentPattern.PatternContext(
                        source: "regex_detection",
                        likelihood: 0.85,
                        relatedPatterns: ["website", "url", "link"],
                        metadata: ["format": "website_url"]
                    ),
                    examples: [String(match)]
                ))
            }
        }
        
        // Social media detection
        for socialPattern in socialMediaPatterns {
            let matches = text.matches(of: socialPattern)
            for match in matches {
                patterns.append(ContentPattern(
                    type: .socialMedia,
                    pattern: socialPattern,
                    confidence: 0.8,
                    context: ContentPattern.PatternContext(
                        source: "regex_detection",
                        likelihood: 0.8,
                        relatedPatterns: ["social", "media", "post"],
                        metadata: ["format": "social_media"]
                    ),
                    examples: [String(match)]
                ))
            }
        }
        
        // Financial pattern detection
        for financialPattern in financialPatterns {
            let matches = text.matches(of: financialPattern)
            for match in matches {
                patterns.append(ContentPattern(
                    type: .currency,
                    pattern: financialPattern,
                    confidence: 0.8,
                    context: ContentPattern.PatternContext(
                        source: "regex_detection",
                        likelihood: 0.8,
                        relatedPatterns: ["money", "payment", "financial"],
                        metadata: ["format": "financial"]
                    ),
                    examples: [String(match)]
                ))
            }
        }
        
        // Document type detection
        for documentPattern in documentPatterns {
            if text.lowercased().contains(documentPattern) {
                patterns.append(ContentPattern(
                    type: .receipt,
                    pattern: documentPattern,
                    confidence: 0.7,
                    context: ContentPattern.PatternContext(
                        source: "keyword_detection",
                        likelihood: 0.7,
                        relatedPatterns: ["document", "paper", "file"],
                        metadata: ["type": documentPattern]
                    ),
                    examples: [documentPattern]
                ))
            }
        }
        
        return patterns.filter { $0.confidence >= settings.minimumPatternConfidence }
    }
    
    private func classifyContentTypes(from text: String, patterns: [ContentPattern]) async -> [ContentType] {
        var contentTypes: Set<ContentType> = []
        
        // Classify based on detected patterns
        for pattern in patterns {
            switch pattern.type {
            case .phoneNumber, .email:
                contentTypes.insert(.contact)
            case .website:
                contentTypes.insert(.website)
            case .socialMedia:
                contentTypes.insert(.socialMedia)
            case .currency:
                contentTypes.insert(.financial)
            case .receipt:
                contentTypes.insert(.receipt)
            default:
                break
            }
        }
        
        // Classify based on keyword analysis
        let lowercasedText = text.lowercased()
        
        // Receipt detection
        if lowercasedText.contains(regex: "\\b(receipt|total|tax|subtotal|bill|purchase)\\b") {
            contentTypes.insert(.receipt)
        }
        
        // Business card detection
        if lowercasedText.contains(regex: "\\b(business card|company|title|position)\\b") {
            contentTypes.insert(.businessCard)
        }
        
        // App detection
        if lowercasedText.contains(regex: "\\b(app|application|software|game)\\b") {
            contentTypes.insert(.app)
        }
        
        // QR code detection
        if lowercasedText.contains(regex: "\\b(qr|code|scan|barcode)\\b") {
            contentTypes.insert(.qrCode)
        }
        
        // Invoice detection
        if lowercasedText.contains(regex: "\\b(invoice|bill|amount due|payment)\\b") {
            contentTypes.insert(.invoice)
        }
        
        // Menu detection
        if lowercasedText.contains(regex: "\\b(menu|restaurant|food|order|dish)\\b") {
            contentTypes.insert(.menu)
        }
        
        // Travel detection
        if lowercasedText.contains(regex: "\\b(flight|hotel|travel|ticket|boarding|reservation)\\b") {
            contentTypes.insert(.travel)
        }
        
        // Medical detection
        if lowercasedText.contains(regex: "\\b(medical|doctor|hospital|prescription|appointment)\\b") {
            contentTypes.insert(.medical)
        }
        
        // Shopping detection
        if lowercasedText.contains(regex: "\\b(cart|buy|purchase|shop|order|price)\\b") {
            contentTypes.insert(.shopping)
        }
        
        // Default to text if content is present but no specific type detected
        if contentTypes.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contentTypes.insert(.text)
        }
        
        return Array(contentTypes)
    }
    
    // MARK: - Filtering and Ranking
    
    private func applyContentTypeFilters(_ screenshots: [Screenshot], types: [ContentType]) async -> [Screenshot] {
        return screenshots.filter { screenshot in
            let content = [
                screenshot.extractedText,
                screenshot.userNotes,
                screenshot.filename
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            
            for contentType in types {
                for keyword in contentType.searchKeywords {
                    if content.contains(keyword) {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    private func applyPatternFilters(_ screenshots: [Screenshot], patterns: [ContentPattern]) async -> [Screenshot] {
        return screenshots.filter { screenshot in
            let content = [
                screenshot.extractedText,
                screenshot.userNotes,
                screenshot.filename
            ].compactMap { $0 }.joined(separator: " ")
            
            for pattern in patterns {
                if content.matches(of: pattern.pattern).count > 0 {
                    return true
                }
            }
            return false
        }
    }
    
    private func rankByContentRelevance(_ screenshots: [Screenshot], query: String, types: [ContentType]) async -> [Screenshot] {
        let scoredScreenshots = screenshots.map { screenshot -> (Screenshot, Double) in
            var score = 0.0
            
            let content = [
                screenshot.extractedText,
                screenshot.userNotes,
                screenshot.filename
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            
            // Score based on query term matches
            let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
            for term in queryTerms {
                if content.contains(term) {
                    score += 1.0
                }
            }
            
            // Boost score for content type matches
            for contentType in types {
                for keyword in contentType.searchKeywords {
                    if content.contains(keyword) {
                        score += 0.5
                    }
                }
            }
            
            // Boost recent screenshots
            let daysSince = Date().timeIntervalSince(screenshot.timestamp) / 86400
            score += max(0, (30 - daysSince) / 30) * 0.2
            
            return (screenshot, score)
        }
        
        return scoredScreenshots
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
    
    // MARK: - Helper Methods
    
    private func calculateContentAnalysisConfidence(patterns: [ContentPattern], types: [ContentType]) -> Double {
        var confidence = 0.5 // Base confidence
        
        // Add confidence for detected patterns
        let patternConfidence = patterns.reduce(0.0) { $0 + $1.confidence } / Double(max(patterns.count, 1))
        confidence += patternConfidence * 0.3
        
        // Add confidence for content types
        confidence += Double(types.count) * 0.1
        
        return min(1.0, confidence)
    }
    
    private func generateSearchFilters(from patterns: [ContentPattern], types: [ContentType]) async -> [SearchFilter] {
        var filters: [SearchFilter] = []
        
        // Generate filters from patterns
        for pattern in patterns {
            switch pattern.type {
            case .phoneNumber:
                filters.append(SearchFilter(
                    type: .hasContactInfo,
                    value: "phone_numbers",
                    confidence: pattern.confidence,
                    description: "Has phone numbers"
                ))
            case .email:
                filters.append(SearchFilter(
                    type: .hasContactInfo,
                    value: "email_addresses",
                    confidence: pattern.confidence,
                    description: "Has email addresses"
                ))
            case .website:
                filters.append(SearchFilter(
                    type: .containsWebsite,
                    value: "websites",
                    confidence: pattern.confidence,
                    description: "Contains websites"
                ))
            case .currency:
                filters.append(SearchFilter(
                    type: .hasFinancialInfo,
                    value: "financial_data",
                    confidence: pattern.confidence,
                    description: "Contains financial information"
                ))
            default:
                break
            }
        }
        
        // Generate filters from content types
        for contentType in types {
            filters.append(SearchFilter(
                type: .contentType,
                value: contentType.rawValue,
                confidence: 0.8,
                description: "Contains \(contentType.displayName.lowercased())"
            ))
        }
        
        return filters.removingDuplicates()
    }
    
    private func calculateCategoryConfidence(count: Int, totalScreenshots: Int) -> Double {
        let ratio = Double(count) / Double(totalScreenshots)
        return min(1.0, ratio * 3) // Scale confidence based on prevalence
    }
    
    private func generateCategoryActions(for contentType: ContentType) -> [String] {
        switch contentType {
        case .receipt:
            return ["Organize by date", "Calculate total expenses", "Export for taxes"]
        case .contact:
            return ["Add to contacts", "Create contact group", "Export contact list"]
        case .website:
            return ["Create bookmark collection", "Share website list", "Organize by category"]
        case .document:
            return ["Create document folder", "Convert to PDF", "Share document set"]
        case .businessCard:
            return ["Add to contacts", "Create business network", "Export contact info"]
        default:
            return ["Organize collection", "Share group", "Export items"]
        }
    }
}


extension Array where Element == ContentAwareSearchEngine.SearchFilter {
    func removingDuplicates() -> [ContentAwareSearchEngine.SearchFilter] {
        var seen: Set<String> = []
        return filter { filter in
            let key = "\(filter.type.rawValue)_\(filter.value)"
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
}