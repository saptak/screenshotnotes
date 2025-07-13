import Foundation
import SwiftUI

// MARK: - Smart Categorization System

/// Comprehensive category model for automatic screenshot classification
public struct Category: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let displayName: String
    public let parentId: String?
    public let level: CategoryLevel
    public let icon: String
    public let colorName: String
    public let keywords: [String]
    public let confidenceThreshold: Double
    public let isActive: Bool
    
    public init(
        id: String,
        name: String,
        displayName: String,
        parentId: String? = nil,
        level: CategoryLevel,
        icon: String,
        colorName: String,
        keywords: [String] = [],
        confidenceThreshold: Double = 0.7,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.parentId = parentId
        self.level = level
        self.icon = icon
        self.colorName = colorName
        self.keywords = keywords
        self.confidenceThreshold = confidenceThreshold
        self.isActive = isActive
    }
    
    /// Convert color name to SwiftUI Color
    public var color: Color {
        switch colorName {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "red": return .red
        case "mint": return .mint
        case "cyan": return .cyan
        case "indigo": return .indigo
        case "brown": return .brown
        case "teal": return .teal
        case "yellow": return .yellow
        case "gray": return .gray
        case "secondary": return .secondary
        default: return .secondary
        }
    }
}

/// Category hierarchy levels
public enum CategoryLevel: String, Codable, CaseIterable, Sendable {
    case root = "root"
    case primary = "primary"
    case secondary = "secondary"
    case tertiary = "tertiary"
    
    public var displayName: String {
        switch self {
        case .root: return "Root"
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        case .tertiary: return "Tertiary"
        }
    }
}

/// Category classification result with confidence scoring
public struct CategoryResult: Codable, Sendable {
    public let category: Category
    public let confidence: Double
    public let signals: [ClassificationSignal]
    public let uncertainty: UncertaintyMeasure
    public let alternativeCategories: [CategoryConfidence]
    public let timestamp: Date
    
    public init(
        category: Category,
        confidence: Double,
        signals: [ClassificationSignal],
        uncertainty: UncertaintyMeasure,
        alternativeCategories: [CategoryConfidence] = [],
        timestamp: Date = Date()
    ) {
        self.category = category
        self.confidence = confidence
        self.signals = signals
        self.uncertainty = uncertainty
        self.alternativeCategories = alternativeCategories
        self.timestamp = timestamp
    }
}

/// Individual category with confidence score
public struct CategoryConfidence: Codable, Sendable {
    public let category: Category
    public let confidence: Double
    
    public init(category: Category, confidence: Double) {
        self.category = category
        self.confidence = confidence
    }
}

/// Classification signals used for categorization
public enum ClassificationSignal: String, Codable, CaseIterable, Sendable {
    case vision = "vision"
    case text = "text"
    case metadata = "metadata"
    case userFeedback = "user_feedback"
    case temporal = "temporal"
    case contextual = "contextual"
    
    public var weight: Double {
        switch self {
        case .vision: return 0.35
        case .text: return 0.30
        case .metadata: return 0.15
        case .userFeedback: return 0.50  // Highest weight for user corrections
        case .temporal: return 0.10
        case .contextual: return 0.20
        }
    }
    
    public var displayName: String {
        switch self {
        case .vision: return "Visual Analysis"
        case .text: return "Text Content"
        case .metadata: return "File Metadata"
        case .userFeedback: return "User Feedback"
        case .temporal: return "Time Context"
        case .contextual: return "Related Content"
        }
    }
}

/// Uncertainty measurement for classification confidence
public struct UncertaintyMeasure: Codable, Sendable {
    public let entropy: Double  // Information entropy of the classification
    public let margin: Double   // Margin between top two categories
    public let variance: Double // Variance in signal confidences
    public let ambiguityScore: Double // Combined uncertainty score
    
    public init(entropy: Double, margin: Double, variance: Double) {
        self.entropy = entropy
        self.margin = margin
        self.variance = variance
        self.ambiguityScore = (entropy + (1 - margin) + variance) / 3.0
    }
    
    /// Whether the classification is considered uncertain
    public var isUncertain: Bool {
        return ambiguityScore > 0.6 || margin < 0.2
    }
}

/// User feedback for category learning
public struct CategoryFeedback: Codable, Sendable {
    public let originalCategory: Category
    public let correctedCategory: Category?
    public let isCorrect: Bool
    public let confidence: Double
    public let feedbackType: FeedbackType
    public let timestamp: Date
    public let userId: String?
    
    public init(
        originalCategory: Category,
        correctedCategory: Category? = nil,
        isCorrect: Bool,
        confidence: Double,
        feedbackType: FeedbackType,
        timestamp: Date = Date(),
        userId: String? = nil
    ) {
        self.originalCategory = originalCategory
        self.correctedCategory = correctedCategory
        self.isCorrect = isCorrect
        self.confidence = confidence
        self.feedbackType = feedbackType
        self.timestamp = timestamp
        self.userId = userId
    }
}

/// Types of category feedback
public enum FeedbackType: String, Codable, CaseIterable, Sendable {
    case correction = "correction"
    case confirmation = "confirmation"
    case rejection = "rejection"
    case suggestion = "suggestion"
    
    public var displayName: String {
        switch self {
        case .correction: return "Corrected Category"
        case .confirmation: return "Confirmed Category"
        case .rejection: return "Rejected Category"
        case .suggestion: return "Suggested Category"
        }
    }
}

// MARK: - Predefined Category Hierarchy

extension Category {
    
    /// Complete hierarchical category system
    public static let predefinedCategories: [Category] = [
        
        // MARK: - Root Categories
        
        // Documents & Text
        Category(
            id: "documents",
            name: "documents",
            displayName: "Documents",
            level: .primary,
            icon: "doc.text",
            colorName: "blue",
            keywords: ["document", "text", "paper", "file", "pdf"]
        ),
        
        // Financial & Business
        Category(
            id: "financial",
            name: "financial",
            displayName: "Financial",
            level: .primary,
            icon: "dollarsign.circle",
            colorName: "green",
            keywords: ["money", "payment", "receipt", "invoice", "bill", "financial", "bank"]
        ),
        
        // Digital Interfaces
        Category(
            id: "digital",
            name: "digital",
            displayName: "Digital",
            level: .primary,
            icon: "desktopcomputer",
            colorName: "orange",
            keywords: ["screen", "app", "website", "digital", "interface", "software"]
        ),
        
        // Communication
        Category(
            id: "communication",
            name: "communication",
            displayName: "Communication",
            level: .primary,
            icon: "message",
            colorName: "purple",
            keywords: ["message", "email", "chat", "conversation", "communication", "social"]
        ),
        
        // Media & Entertainment
        Category(
            id: "media",
            name: "media",
            displayName: "Media",
            level: .primary,
            icon: "photo",
            colorName: "pink",
            keywords: ["photo", "image", "video", "media", "entertainment", "art"]
        ),
        
        // Travel & Location
        Category(
            id: "travel",
            name: "travel",
            displayName: "Travel",
            level: .primary,
            icon: "airplane",
            colorName: "cyan",
            keywords: ["travel", "trip", "vacation", "hotel", "flight", "location", "map"]
        ),
        
        // Shopping & Commerce
        Category(
            id: "shopping",
            name: "shopping",
            displayName: "Shopping",
            level: .primary,
            icon: "bag",
            colorName: "indigo",
            keywords: ["shopping", "store", "product", "buy", "purchase", "commerce", "retail"]
        ),
        
        // Work & Professional
        Category(
            id: "work",
            name: "work",
            displayName: "Work",
            level: .primary,
            icon: "briefcase",
            colorName: "brown",
            keywords: ["work", "job", "professional", "business", "office", "meeting", "project"]
        ),
        
        // Education & Learning
        Category(
            id: "education",
            name: "education",
            displayName: "Education",
            level: .primary,
            icon: "book",
            colorName: "mint",
            keywords: ["education", "learning", "school", "study", "course", "tutorial", "academic"]
        ),
        
        // Health & Medical
        Category(
            id: "health",
            name: "health",
            displayName: "Health",
            level: .primary,
            icon: "heart",
            colorName: "red",
            keywords: ["health", "medical", "doctor", "hospital", "medicine", "wellness", "fitness"]
        ),
        
        // Reference & Information
        Category(
            id: "reference",
            name: "reference",
            displayName: "Reference",
            level: .primary,
            icon: "magnifyingglass",
            colorName: "teal",
            keywords: ["reference", "information", "research", "guide", "manual", "wiki", "help"]
        ),
        
        // Personal & Lifestyle
        Category(
            id: "personal",
            name: "personal",
            displayName: "Personal",
            level: .primary,
            icon: "person",
            colorName: "yellow",
            keywords: ["personal", "family", "home", "lifestyle", "hobby", "interest", "private"]
        ),
        
        // Technical & Code
        Category(
            id: "technical",
            name: "technical",
            displayName: "Technical",
            level: .primary,
            icon: "chevron.left.forwardslash.chevron.right",
            colorName: "gray",
            keywords: ["code", "programming", "technical", "development", "software", "engineering"]
        ),
        
        // Uncategorized
        Category(
            id: "uncategorized",
            name: "uncategorized",
            displayName: "Uncategorized",
            level: .primary,
            icon: "questionmark.square",
            colorName: "secondary",
            keywords: ["unknown", "other", "misc", "uncategorized"],
            confidenceThreshold: 0.3
        ),
        
        // MARK: - Secondary Categories (Documents)
        
        Category(
            id: "documents.receipts",
            name: "receipts",
            displayName: "Receipts",
            parentId: "financial",
            level: .secondary,
            icon: "receipt",
            colorName: "green",
            keywords: ["receipt", "purchase", "transaction", "payment", "proof"],
            confidenceThreshold: 0.85
        ),
        
        Category(
            id: "documents.invoices",
            name: "invoices",
            displayName: "Invoices",
            parentId: "financial",
            level: .secondary,
            icon: "doc.plaintext",
            colorName: "green",
            keywords: ["invoice", "bill", "billing", "charge", "amount due"],
            confidenceThreshold: 0.80
        ),
        
        Category(
            id: "documents.contracts",
            name: "contracts",
            displayName: "Contracts",
            parentId: "documents",
            level: .secondary,
            icon: "doc.text",
            colorName: "blue",
            keywords: ["contract", "agreement", "legal", "terms", "conditions"],
            confidenceThreshold: 0.75
        ),
        
        Category(
            id: "documents.forms",
            name: "forms",
            displayName: "Forms",
            parentId: "documents",
            level: .secondary,
            icon: "list.clipboard",
            colorName: "blue",
            keywords: ["form", "application", "questionnaire", "survey", "registration"]
        ),
        
        Category(
            id: "documents.certificates",
            name: "certificates",
            displayName: "Certificates",
            parentId: "documents",
            level: .secondary,
            icon: "seal",
            colorName: "blue",
            keywords: ["certificate", "diploma", "award", "license", "credential"]
        ),
        
        // MARK: - Secondary Categories (Digital)
        
        Category(
            id: "digital.websites",
            name: "websites",
            displayName: "Websites",
            parentId: "digital",
            level: .secondary,
            icon: "globe",
            colorName: "orange",
            keywords: ["website", "webpage", "browser", "internet", "web", "url"]
        ),
        
        Category(
            id: "digital.apps",
            name: "apps",
            displayName: "Mobile Apps",
            parentId: "digital",
            level: .secondary,
            icon: "app",
            colorName: "orange",
            keywords: ["app", "application", "mobile", "iphone", "android", "ios"]
        ),
        
        Category(
            id: "digital.social",
            name: "social",
            displayName: "Social Media",
            parentId: "communication",
            level: .secondary,
            icon: "person.3",
            colorName: "purple",
            keywords: ["social", "facebook", "twitter", "instagram", "linkedin", "tiktok", "reddit"]
        ),
        
        Category(
            id: "digital.messaging",
            name: "messaging",
            displayName: "Messaging",
            parentId: "communication",
            level: .secondary,
            icon: "message",
            colorName: "purple",
            keywords: ["message", "chat", "whatsapp", "telegram", "slack", "teams", "discord"]
        ),
        
        Category(
            id: "digital.email",
            name: "email",
            displayName: "Email",
            parentId: "communication",
            level: .secondary,
            icon: "envelope",
            colorName: "purple",
            keywords: ["email", "mail", "gmail", "outlook", "inbox", "compose"]
        ),
        
        // MARK: - Secondary Categories (Media)
        
        Category(
            id: "media.photos",
            name: "photos",
            displayName: "Photos",
            parentId: "media",
            level: .secondary,
            icon: "photo",
            colorName: "pink",
            keywords: ["photo", "picture", "image", "selfie", "portrait", "landscape"]
        ),
        
        Category(
            id: "media.screenshots",
            name: "screenshots",
            displayName: "Screenshots",
            parentId: "media",
            level: .secondary,
            icon: "rectangle.dashed",
            colorName: "pink",
            keywords: ["screenshot", "screen capture", "screen shot", "capture"]
        ),
        
        Category(
            id: "media.memes",
            name: "memes",
            displayName: "Memes & Humor",
            parentId: "media",
            level: .secondary,
            icon: "face.smiling",
            colorName: "pink",
            keywords: ["meme", "funny", "humor", "joke", "comedy", "viral"]
        ),
        
        // MARK: - Tertiary Categories (Financial)
        
        Category(
            id: "financial.receipts.food",
            name: "food_receipts",
            displayName: "Food & Dining",
            parentId: "documents.receipts",
            level: .tertiary,
            icon: "fork.knife",
            colorName: "green",
            keywords: ["restaurant", "food", "dining", "meal", "cafe", "delivery"]
        ),
        
        Category(
            id: "financial.receipts.shopping",
            name: "shopping_receipts",
            displayName: "Shopping",
            parentId: "documents.receipts",
            level: .tertiary,
            icon: "bag",
            colorName: "green",
            keywords: ["shopping", "store", "retail", "purchase", "mall", "online"]
        ),
        
        Category(
            id: "financial.receipts.travel",
            name: "travel_receipts",
            displayName: "Travel & Hotel",
            parentId: "documents.receipts",
            level: .tertiary,
            icon: "airplane",
            colorName: "green",
            keywords: ["hotel", "flight", "travel", "booking", "vacation", "trip"]
        ),
        
        Category(
            id: "financial.receipts.gas",
            name: "gas_receipts",
            displayName: "Gas & Transportation",
            parentId: "documents.receipts",
            level: .tertiary,
            icon: "car",
            colorName: "green",
            keywords: ["gas", "fuel", "transportation", "uber", "lyft", "taxi", "parking"]
        )
    ]
    
    /// Get category by ID
    public static func categoryById(_ id: String) -> Category? {
        return predefinedCategories.first { $0.id == id }
    }
    
    /// Get primary categories
    public static var primaryCategories: [Category] {
        return predefinedCategories.filter { $0.level == .primary }
    }
    
    /// Get secondary categories for a parent
    public static func secondaryCategories(for parentId: String) -> [Category] {
        return predefinedCategories.filter { $0.parentId == parentId && $0.level == .secondary }
    }
    
    /// Get tertiary categories for a parent
    public static func tertiaryCategories(for parentId: String) -> [Category] {
        return predefinedCategories.filter { $0.parentId == parentId && $0.level == .tertiary }
    }
    
    /// Get full hierarchy path for a category
    public func hierarchyPath() -> [Category] {
        var path: [Category] = [self]
        var currentParentId = self.parentId
        
        while let parentId = currentParentId {
            if let parent = Category.categoryById(parentId) {
                path.insert(parent, at: 0)
                currentParentId = parent.parentId
            } else {
                break
            }
        }
        
        return path
    }
    
    /// Get full display path (e.g., "Financial > Receipts > Food")
    public func displayPath() -> String {
        return hierarchyPath().map { $0.displayName }.joined(separator: " > ")
    }
}

