import Foundation
import NaturalLanguage

// MARK: - Semantic Tag Model

/// Represents a semantic tag with confidence and source information
public struct SemanticTag: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let name: String
    public let confidence: Double
    public let source: TagSource
    public let category: TagCategory
    public let timestamp: Date
    
    public init(
        name: String,
        confidence: Double,
        source: TagSource,
        category: TagCategory,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.name = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidence = max(0.0, min(1.0, confidence))
        self.source = source
        self.category = category
        self.timestamp = timestamp
    }
    
    /// Get display name with proper capitalization
    public var displayName: String {
        return name.localizedCapitalized
    }
    
    /// Check if tag meets minimum confidence threshold
    public var isHighConfidence: Bool {
        return confidence >= 0.7
    }
    
    /// Check if tag is user-generated
    public var isUserGenerated: Bool {
        return source == .userInput
    }
}

// MARK: - Tag Source

/// Source of the semantic tag
public enum TagSource: String, Codable, CaseIterable, Sendable {
    case vision = "vision"
    case ocr = "ocr"
    case entityExtraction = "entity_extraction"
    case businessRecognition = "business_recognition"
    case contentClassification = "content_classification"
    case userInput = "user_input"
    case aiGenerated = "ai_generated"
    
    public var displayName: String {
        switch self {
        case .vision: return "Vision"
        case .ocr: return "Text Recognition"
        case .entityExtraction: return "Entity Detection"
        case .businessRecognition: return "Business Recognition"
        case .contentClassification: return "Content Type"
        case .userInput: return "User Added"
        case .aiGenerated: return "AI Generated"
        }
    }
    
    public var icon: String {
        switch self {
        case .vision: return "eye"
        case .ocr: return "text.viewfinder"
        case .entityExtraction: return "brain"
        case .businessRecognition: return "building.2"
        case .contentClassification: return "doc.text"
        case .userInput: return "person"
        case .aiGenerated: return "sparkles"
        }
    }
}

// MARK: - Tag Category

/// Category classification for semantic tags
public enum TagCategory: String, Codable, CaseIterable, Sendable {
    case object = "object"
    case location = "location"
    case person = "person"
    case organization = "organization"
    case brand = "brand"
    case product = "product"
    case documentType = "document_type"
    case contentType = "content_type"
    case color = "color"
    case temporal = "temporal"
    case currency = "currency"
    case contact = "contact"
    case url = "url"
    case email = "email"
    case phone = "phone"
    case emotion = "emotion"
    case action = "action"
    case concept = "concept"
    case general = "general"
    
    public var displayName: String {
        switch self {
        case .object: return "Object"
        case .location: return "Location"
        case .person: return "Person"
        case .organization: return "Organization"
        case .brand: return "Brand"
        case .product: return "Product"
        case .documentType: return "Document"
        case .contentType: return "Content"
        case .color: return "Color"
        case .temporal: return "Time"
        case .currency: return "Currency"
        case .contact: return "Contact"
        case .url: return "URL"
        case .email: return "Email"
        case .phone: return "Phone"
        case .emotion: return "Emotion"
        case .action: return "Action"
        case .concept: return "Concept"
        case .general: return "General"
        }
    }
    
    public var color: String {
        switch self {
        case .object: return "blue"
        case .location: return "green"
        case .person: return "purple"
        case .organization: return "orange"
        case .brand: return "red"
        case .product: return "yellow"
        case .documentType: return "gray"
        case .contentType: return "indigo"
        case .color: return "pink"
        case .temporal: return "cyan"
        case .currency: return "mint"
        case .contact: return "teal"
        case .url: return "blue"
        case .email: return "purple"
        case .phone: return "green"
        case .emotion: return "pink"
        case .action: return "orange"
        case .concept: return "indigo"
        case .general: return "gray"
        }
    }
}

// MARK: - Semantic Tag Collection

/// Collection of semantic tags with utilities
public struct SemanticTagCollection: Codable, Sendable {
    public let tags: [SemanticTag]
    public let extractionTimestamp: Date
    public let overallConfidence: Double
    
    public init(tags: [SemanticTag], extractionTimestamp: Date = Date()) {
        self.tags = tags
        self.extractionTimestamp = extractionTimestamp
        
        // Calculate overall confidence as weighted average
        if tags.isEmpty {
            self.overallConfidence = 0.0
        } else {
            let totalWeight = tags.reduce(0.0) { $0 + $1.confidence }
            self.overallConfidence = totalWeight / Double(tags.count)
        }
    }
    
    /// Get tags filtered by minimum confidence
    public func highConfidenceTags(threshold: Double = 0.7) -> [SemanticTag] {
        return tags.filter { $0.confidence >= threshold }
    }
    
    /// Get tags by category
    public func tags(in category: TagCategory) -> [SemanticTag] {
        return tags.filter { $0.category == category }
    }
    
    /// Get tags by source
    public func tags(from source: TagSource) -> [SemanticTag] {
        return tags.filter { $0.source == source }
    }
    
    /// Get unique tag names
    public var uniqueTagNames: [String] {
        return Array(Set(tags.map(\.name))).sorted()
    }
    
    /// Get tags grouped by category
    public var tagsByCategory: [TagCategory: [SemanticTag]] {
        return Dictionary(grouping: tags, by: \.category)
    }
    
    /// Check if collection contains tag with name
    public func contains(tagNamed name: String) -> Bool {
        return tags.contains { $0.name.lowercased() == name.lowercased() }
    }
    
    /// Get best tag for a given name (highest confidence)
    public func bestTag(named name: String) -> SemanticTag? {
        return tags
            .filter { $0.name.lowercased() == name.lowercased() }
            .max(by: { $0.confidence < $1.confidence })
    }
}

// MARK: - Business Entity

/// Represents a recognized business entity
public struct BusinessEntity: Codable, Sendable, Hashable {
    public let name: String
    public let type: BusinessType
    public let confidence: Double
    public let extractedFrom: String
    
    public init(name: String, type: BusinessType, confidence: Double, extractedFrom: String) {
        self.name = name
        self.type = type
        self.confidence = confidence
        self.extractedFrom = extractedFrom
    }
}

/// Types of business entities
public enum BusinessType: String, Codable, CaseIterable, Sendable {
    case hotel = "hotel"
    case restaurant = "restaurant"
    case retail = "retail"
    case airline = "airline"
    case bank = "bank"
    case insurance = "insurance"
    case healthcare = "healthcare"
    case technology = "technology"
    case transportation = "transportation"
    case entertainment = "entertainment"
    case education = "education"
    case government = "government"
    case unknown = "unknown"
    
    public var displayName: String {
        return rawValue.localizedCapitalized
    }
    
    public var icon: String {
        switch self {
        case .hotel: return "bed.double"
        case .restaurant: return "fork.knife"
        case .retail: return "bag"
        case .airline: return "airplane"
        case .bank: return "banknote"
        case .insurance: return "shield"
        case .healthcare: return "cross"
        case .technology: return "laptopcomputer"
        case .transportation: return "car"
        case .entertainment: return "tv"
        case .education: return "graduationcap"
        case .government: return "building.columns"
        case .unknown: return "building.2"
        }
    }
}

// MARK: - Content Classification

/// Content type classification result
public struct ContentClassification: Codable, Sendable {
    public let primaryType: ContentType
    public let confidence: Double
    public let secondaryTypes: [ContentType]
    
    public init(primaryType: ContentType, confidence: Double, secondaryTypes: [ContentType] = []) {
        self.primaryType = primaryType
        self.confidence = confidence
        self.secondaryTypes = secondaryTypes
    }
}

/// Types of screenshot content
public enum ContentType: String, Codable, CaseIterable, Sendable {
    case receipt = "receipt"
    case invoice = "invoice"
    case document = "document"
    case webpage = "webpage"
    case socialMedia = "social_media"
    case email = "email"
    case message = "message"
    case photo = "photo"
    case map = "map"
    case qrCode = "qr_code"
    case barcode = "barcode"
    case chart = "chart"
    case presentation = "presentation"
    case ticket = "ticket"
    case coupon = "coupon"
    case menu = "menu"
    case calendar = "calendar"
    case contact = "contact"
    case settings = "settings"
    case app = "app"
    case game = "game"
    case video = "video"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .receipt: return "Receipt"
        case .invoice: return "Invoice"
        case .document: return "Document"
        case .webpage: return "Web Page"
        case .socialMedia: return "Social Media"
        case .email: return "Email"
        case .message: return "Message"
        case .photo: return "Photo"
        case .map: return "Map"
        case .qrCode: return "QR Code"
        case .barcode: return "Barcode"
        case .chart: return "Chart"
        case .presentation: return "Presentation"
        case .ticket: return "Ticket"
        case .coupon: return "Coupon"
        case .menu: return "Menu"
        case .calendar: return "Calendar"
        case .contact: return "Contact"
        case .settings: return "Settings"
        case .app: return "App"
        case .game: return "Game"
        case .video: return "Video"
        case .unknown: return "Unknown"
        }
    }
    
    public var icon: String {
        switch self {
        case .receipt: return "receipt"
        case .invoice: return "doc.text"
        case .document: return "doc"
        case .webpage: return "globe"
        case .socialMedia: return "person.3"
        case .email: return "envelope"
        case .message: return "message"
        case .photo: return "photo"
        case .map: return "map"
        case .qrCode: return "qrcode"
        case .barcode: return "barcode"
        case .chart: return "chart.bar"
        case .presentation: return "rectangle.3.group"
        case .ticket: return "ticket"
        case .coupon: return "scissors"
        case .menu: return "list.bullet"
        case .calendar: return "calendar"
        case .contact: return "person.crop.square"
        case .settings: return "gearshape"
        case .app: return "app"
        case .game: return "gamecontroller"
        case .video: return "play.rectangle"
        case .unknown: return "questionmark.square"
        }
    }
    
    /// Get semantic relevance score for search
    public var searchRelevance: Double {
        switch self {
        case .receipt, .invoice, .document: return 1.0
        case .webpage, .email, .message: return 0.9
        case .photo, .map, .chart: return 0.8
        case .socialMedia, .ticket, .coupon: return 0.7
        case .presentation, .menu, .calendar: return 0.6
        case .contact, .settings, .app: return 0.5
        case .qrCode, .barcode, .game, .video: return 0.4
        case .unknown: return 0.1
        }
    }
}
