import Foundation
import NaturalLanguage
import Vision

/// Advanced entity recognition service for Sprint 7.1.3
/// Provides deep content analysis with business and personal entity extraction
@MainActor
public class EntityRecognitionService: ObservableObject {
    
    // MARK: - Dependencies
    
    private let entityExtractor: EntityExtractionService
    private let nlTagger: NLTagger
    private let languageRecognizer: NLLanguageRecognizer
    private var cachedResults: [String: ContentAnalysisResult] = [:]
    
    // MARK: - Configuration
    
    private let maxProcessingTime: TimeInterval = 10.0
    private let maxCacheSize = 200
    private let confidenceThreshold: Double = 0.85
    
    // MARK: - Business Entity Patterns
    
    private let brandKeywords: Set<String> = [
        // Tech brands
        "apple", "google", "microsoft", "amazon", "meta", "facebook", "instagram",
        "twitter", "linkedin", "spotify", "netflix", "uber", "lyft", "airbnb",
        "tesla", "samsung", "sony", "nintendo", "adobe", "salesforce", "oracle",
        
        // Retail brands
        "walmart", "target", "costco", "amazon", "best buy", "home depot",
        "lowes", "macys", "nordstrom", "gap", "nike", "adidas", "starbucks",
        "mcdonalds", "subway", "chipotle", "dominos", "pizza hut",
        
        // Financial brands
        "chase", "wells fargo", "bank of america", "citibank", "goldman sachs",
        "paypal", "venmo", "cash app", "zelle", "american express", "visa",
        "mastercard", "discover",
        
        // Service brands
        "fedex", "ups", "usps", "dhl", "hertz", "enterprise", "avis",
        "marriott", "hilton", "hyatt", "expedia", "booking", "trivago"
    ]
    
    private let productCategories: Set<String> = [
        // Electronics
        "laptop", "computer", "phone", "tablet", "smartphone", "iphone", "android",
        "macbook", "ipad", "watch", "smartwatch", "headphones", "earbuds", "speaker",
        "tv", "monitor", "camera", "gaming", "console", "xbox", "playstation",
        
        // Clothing & Fashion
        "shirt", "dress", "pants", "jeans", "shoes", "sneakers", "boots", "jacket",
        "coat", "sweater", "hoodie", "hat", "cap", "bag", "purse", "wallet",
        "jewelry", "watch", "sunglasses", "belt", "scarf", "gloves",
        
        // Home & Garden
        "furniture", "table", "chair", "sofa", "bed", "mattress", "lamp", "rug",
        "curtains", "appliance", "refrigerator", "microwave", "dishwasher",
        "vacuum", "tools", "drill", "hammer", "paint", "plants", "garden",
        
        // Food & Beverage
        "coffee", "tea", "wine", "beer", "water", "soda", "juice", "protein",
        "supplement", "vitamin", "organic", "gluten free", "vegan", "keto",
        
        // Health & Beauty
        "skincare", "makeup", "perfume", "shampoo", "toothpaste", "medicine",
        "prescription", "vitamins", "supplement", "fitness", "workout"
    ]
    
    private let serviceTypes: Set<String> = [
        // Professional services
        "consulting", "legal", "accounting", "financial", "insurance", "real estate",
        "marketing", "advertising", "design", "development", "engineering",
        "architecture", "construction", "plumbing", "electrical", "hvac",
        
        // Personal services
        "healthcare", "medical", "dental", "veterinary", "grooming", "cleaning",
        "landscaping", "catering", "photography", "videography", "tutoring",
        "fitness", "training", "therapy", "massage", "spa", "salon",
        
        // Transportation services
        "delivery", "shipping", "moving", "taxi", "rideshare", "rental",
        "maintenance", "repair", "towing", "parking", "storage",
        
        // Entertainment services
        "streaming", "subscription", "membership", "event", "ticket", "booking",
        "reservation", "travel", "hotel", "restaurant", "entertainment"
    ]
    
    // MARK: - Personal Entity Patterns
    
    private let contactIndicators: Set<String> = [
        "contact", "phone", "cell", "mobile", "home", "work", "office", "fax",
        "email", "address", "street", "avenue", "road", "boulevard", "drive",
        "lane", "way", "court", "place", "circle", "apt", "apartment", "suite",
        "unit", "floor", "building", "zip", "postal", "code"
    ]
    
    private let businessCardIndicators: Set<String> = [
        "business card", "calling card", "contact card", "visiting card",
        "ceo", "president", "director", "manager", "supervisor", "coordinator",
        "specialist", "analyst", "consultant", "executive", "officer",
        "vice president", "vp", "senior", "junior", "lead", "head", "chief"
    ]
    
    // MARK: - Content Type Classification
    
    private let contentTypeIndicators: [RecognizedContentType: Set<String>] = [
        .form: [
            "application", "form", "submit", "required", "optional", "checkbox",
            "radio", "dropdown", "select", "input", "field", "enter", "fill",
            "complete", "sign", "signature", "date", "name", "address", "phone"
        ],
        .receipt: [
            "receipt", "total", "subtotal", "tax", "tip", "payment", "cash", "card",
            "credit", "debit", "amount", "price", "cost", "charge", "bill", "invoice",
            "purchase", "transaction", "merchant", "store", "shop", "retail"
        ],
        .article: [
            "article", "news", "story", "report", "headline", "byline", "author",
            "journalist", "reporter", "editor", "paragraph", "section", "column",
            "breaking", "update", "analysis", "opinion", "editorial", "feature"
        ],
        .socialPost: [
            "like", "share", "comment", "reply", "retweet", "follow", "follower",
            "friend", "post", "status", "update", "story", "feed", "timeline",
            "mention", "hashtag", "tag", "dm", "message", "chat", "social"
        ],
        .email: [
            "email", "subject", "from", "to", "cc", "bcc", "sent", "received",
            "inbox", "outbox", "draft", "reply", "forward", "attachment",
            "signature", "regards", "sincerely", "dear", "hello", "hi"
        ],
        .document: [
            "document", "file", "pdf", "doc", "docx", "page", "pages", "chapter",
            "section", "title", "heading", "paragraph", "text", "content",
            "appendix", "bibliography", "reference", "citation", "footnote"
        ],
        .website: [
            "website", "webpage", "url", "link", "site", "domain", "www", "http",
            "https", "browser", "navigation", "menu", "button", "click", "search",
            "login", "signup", "register", "home", "about", "contact", "privacy"
        ],
        .menu: [
            "menu", "restaurant", "food", "dish", "meal", "appetizer", "entree",
            "dessert", "beverage", "drink", "wine", "beer", "special", "daily",
            "seasonal", "chef", "kitchen", "cuisine", "vegetarian", "vegan"
        ]
    ]
    
    // MARK: - Initialization
    
    public init() {
        self.entityExtractor = EntityExtractionService()
        self.nlTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .lemma])
        self.languageRecognizer = NLLanguageRecognizer()
    }
    
    // MARK: - Public Methods
    
    /// Perform comprehensive content analysis with entity recognition
    /// - Parameter text: The input text to analyze
    /// - Returns: ContentAnalysisResult with extracted entities and content classification
    public func analyzeContent(from text: String) async -> ContentAnalysisResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Check cache first
        if let cachedResult = getCachedResult(for: text) {
            return cachedResult
        }
        
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            return ContentAnalysisResult(
                businessEntities: [],
                personalEntities: [],
                contentType: .unknown,
                contentTypeConfidence: 0.0,
                entityRelationships: [],
                originalText: text,
                processingTimeMs: 0,
                overallAccuracy: 0.0,
                isSuccessful: false
            )
        }
        
        do {
            // Step 1: Base entity extraction
            let baseExtraction = await entityExtractor.extractEntities(from: normalizedText)
            
            // Step 2: Business entity recognition
            let businessEntities = try await extractBusinessEntities(from: normalizedText, baseEntities: baseExtraction.entities)
            
            // Step 3: Personal entity detection
            let personalEntities = try await extractPersonalEntities(from: normalizedText, baseEntities: baseExtraction.entities)
            
            // Step 4: Content type classification
            let (contentType, contentConfidence) = try classifyContentType(from: normalizedText)
            
            // Step 5: Entity relationship mapping
            let relationships = try buildEntityRelationships(
                businessEntities: businessEntities,
                personalEntities: personalEntities,
                text: normalizedText
            )
            
            // Calculate overall accuracy
            let accuracy = calculateOverallAccuracy(
                businessEntities: businessEntities,
                personalEntities: personalEntities,
                contentTypeConfidence: contentConfidence
            )
            
            let result = ContentAnalysisResult(
                businessEntities: businessEntities,
                personalEntities: personalEntities,
                contentType: contentType,
                contentTypeConfidence: contentConfidence,
                entityRelationships: relationships,
                originalText: text,
                processingTimeMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000,
                overallAccuracy: accuracy,
                isSuccessful: accuracy >= confidenceThreshold
            )
            
            cacheResult(result, for: text)
            return result
            
        } catch {
            let result = ContentAnalysisResult(
                businessEntities: [],
                personalEntities: [],
                contentType: .unknown,
                contentTypeConfidence: 0.0,
                entityRelationships: [],
                originalText: text,
                processingTimeMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000,
                overallAccuracy: 0.0,
                isSuccessful: false
            )
            return result
        }
    }
    
    // MARK: - Business Entity Recognition
    
    private func extractBusinessEntities(from text: String, baseEntities: [ExtractedEntity]) async throws -> [RecognizedBusinessEntity] {
        var businessEntities: [RecognizedBusinessEntity] = []
        let lowercasedText = text.lowercased()
        let words = Set(lowercasedText.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters)))
        
        // Extract brands
        for brand in brandKeywords {
            if words.contains(brand) || lowercasedText.contains(brand) {
                let confidence = calculateBrandConfidence(brand, in: text)
                let entity = RecognizedBusinessEntity(
                    type: .brand,
                    name: brand.capitalized,
                    category: categorizeBrand(brand),
                    confidence: confidence,
                    context: extractBrandContext(brand, from: text)
                )
                businessEntities.append(entity)
            }
        }
        
        // Extract products
        for product in productCategories {
            if words.contains(product) || lowercasedText.contains(product) {
                let confidence = calculateProductConfidence(product, in: text)
                let entity = RecognizedBusinessEntity(
                    type: .product,
                    name: product.capitalized,
                    category: categorizeProduct(product),
                    confidence: confidence,
                    context: extractProductContext(product, from: text)
                )
                businessEntities.append(entity)
            }
        }
        
        // Extract services
        for service in serviceTypes {
            if words.contains(service) || lowercasedText.contains(service) {
                let confidence = calculateServiceConfidence(service, in: text)
                let entity = RecognizedBusinessEntity(
                    type: .service,
                    name: service.capitalized,
                    category: categorizeService(service),
                    confidence: confidence,
                    context: extractServiceContext(service, from: text)
                )
                businessEntities.append(entity)
            }
        }
        
        // Extract organizations from base entities
        for baseEntity in baseEntities where baseEntity.type == .organization {
            let entity = RecognizedBusinessEntity(
                type: .organization,
                name: baseEntity.text,
                category: "organization",
                confidence: min(0.95, baseEntity.confidence.rawValue + 0.1),
                context: ["source": "nl_tagger", "normalized": baseEntity.normalizedValue]
            )
            businessEntities.append(entity)
        }
        
        return removeDuplicateBusinessEntities(businessEntities)
    }
    
    // MARK: - Personal Entity Detection
    
    private func extractPersonalEntities(from text: String, baseEntities: [ExtractedEntity]) async throws -> [RecognizedPersonalEntity] {
        var personalEntities: [RecognizedPersonalEntity] = []
        
        // Extract contacts from base entities
        for baseEntity in baseEntities where baseEntity.type == .person {
            let entity = RecognizedPersonalEntity(
                type: .contact,
                value: baseEntity.text,
                label: "person",
                confidence: baseEntity.confidence.rawValue,
                context: ["source": "nl_tagger", "range": NSStringFromRange(baseEntity.range)]
            )
            personalEntities.append(entity)
        }
        
        // Extract phone numbers
        for baseEntity in baseEntities where baseEntity.type == .phoneNumber {
            let entity = RecognizedPersonalEntity(
                type: .phoneNumber,
                value: baseEntity.text,
                label: classifyPhoneNumber(baseEntity.text),
                confidence: baseEntity.confidence.rawValue,
                context: ["normalized": baseEntity.normalizedValue, "pattern": "regex"]
            )
            personalEntities.append(entity)
        }
        
        // Extract email addresses
        for baseEntity in baseEntities where baseEntity.type == .email {
            let entity = RecognizedPersonalEntity(
                type: .email,
                value: baseEntity.text,
                label: classifyEmail(baseEntity.text),
                confidence: baseEntity.confidence.rawValue,
                context: ["domain": extractEmailDomain(baseEntity.text)]
            )
            personalEntities.append(entity)
        }
        
        // Extract addresses using pattern matching
        let addresses = try extractAddresses(from: text)
        personalEntities.append(contentsOf: addresses)
        
        return removeDuplicatePersonalEntities(personalEntities)
    }
    
    // MARK: - Content Type Classification
    
    private func classifyContentType(from text: String) throws -> (RecognizedContentType, Double) {
        let lowercasedText = text.lowercased()
        let words = Set(lowercasedText.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters)))
        
        var scores: [RecognizedContentType: Double] = [:]
        
        for (contentType, indicators) in contentTypeIndicators {
            let matchCount = indicators.intersection(words).count
            let score = Double(matchCount) / Double(indicators.count)
            scores[contentType] = score
        }
        
        // Add contextual scoring
        let contextualScores = addContextualScoring(text: lowercasedText, baseScores: scores)
        
        guard let bestMatch = contextualScores.max(by: { $0.value < $1.value }) else {
            return (.unknown, 0.0)
        }
        
        let confidence = min(0.95, bestMatch.value + calculateContextualBonus(bestMatch.key, text: lowercasedText))
        return (bestMatch.key, confidence)
    }
    
    // MARK: - Entity Relationship Mapping
    
    private func buildEntityRelationships(
        businessEntities: [RecognizedBusinessEntity],
        personalEntities: [RecognizedPersonalEntity],
        text: String
    ) throws -> [RecognizedEntityRelationship] {
        var relationships: [RecognizedEntityRelationship] = []
        
        // Map business entities to personal entities (e.g., person works at company)
        for personalEntity in personalEntities where personalEntity.type == .contact {
            for businessEntity in businessEntities where businessEntity.type == .organization {
                let proximity = calculateTextProximity(personalEntity.value, businessEntity.name, in: text)
                if proximity < 50 { // Words are close together
                    let relationship = RecognizedEntityRelationship(
                        sourceType: .personal,
                        sourceValue: personalEntity.value,
                        targetType: .business,
                        targetValue: businessEntity.name,
                        relationshipType: .employment,
                        confidence: min(0.9, 0.5 + (50.0 - proximity) / 100.0),
                        context: ["proximity": String(proximity), "type": "employment_inference"]
                    )
                    relationships.append(relationship)
                }
            }
        }
        
        // Map contact information to locations
        for personalEntity in personalEntities where personalEntity.type == .address {
            for businessEntity in businessEntities where businessEntity.type == .organization {
                let proximity = calculateTextProximity(personalEntity.value, businessEntity.name, in: text)
                if proximity < 30 {
                    let relationship = RecognizedEntityRelationship(
                        sourceType: .business,
                        sourceValue: businessEntity.name,
                        targetType: .personal,
                        targetValue: personalEntity.value,
                        relationshipType: .location,
                        confidence: min(0.8, 0.4 + (30.0 - proximity) / 60.0),
                        context: ["proximity": String(proximity), "type": "location_inference"]
                    )
                    relationships.append(relationship)
                }
            }
        }
        
        return relationships
    }
    
    // MARK: - Helper Methods
    
    private func extractAddresses(from text: String) throws -> [RecognizedPersonalEntity] {
        var addresses: [RecognizedPersonalEntity] = []
        
        // Street address pattern
        let streetPattern = #"\b\d+\s+[A-Za-z\s]+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Court|Ct|Place|Pl|Circle|Cir)\b"#
        let streetRegex = try NSRegularExpression(pattern: streetPattern, options: .caseInsensitive)
        let streetMatches = streetRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        for match in streetMatches {
            if let range = Range(match.range, in: text) {
                let address = String(text[range])
                let entity = RecognizedPersonalEntity(
                    type: .address,
                    value: address,
                    label: "street_address",
                    confidence: 0.85,
                    context: ["type": "street", "pattern": "regex"]
                )
                addresses.append(entity)
            }
        }
        
        // ZIP code pattern
        let zipPattern = #"\b\d{5}(-\d{4})?\b"#
        let zipRegex = try NSRegularExpression(pattern: zipPattern)
        let zipMatches = zipRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        for match in zipMatches {
            if let range = Range(match.range, in: text) {
                let zipCode = String(text[range])
                let entity = RecognizedPersonalEntity(
                    type: .address,
                    value: zipCode,
                    label: "zip_code",
                    confidence: 0.95,
                    context: ["type": "postal_code", "pattern": "regex"]
                )
                addresses.append(entity)
            }
        }
        
        return addresses
    }
    
    private func calculateBrandConfidence(_ brand: String, in text: String) -> Double {
        let lowercasedText = text.lowercased()
        var confidence = 0.7
        
        // Boost confidence if brand appears with typical brand context
        if lowercasedText.contains("by \(brand)") || lowercasedText.contains("\(brand) inc") ||
           lowercasedText.contains("\(brand) corp") || lowercasedText.contains("\(brand) llc") {
            confidence += 0.2
        }
        
        return min(0.95, confidence)
    }
    
    private func calculateProductConfidence(_ product: String, in text: String) -> Double {
        let lowercasedText = text.lowercased()
        var confidence = 0.6
        
        // Boost confidence if product appears with pricing or shopping context
        if lowercasedText.contains("$") || lowercasedText.contains("price") ||
           lowercasedText.contains("buy") || lowercasedText.contains("purchase") {
            confidence += 0.2
        }
        
        return min(0.9, confidence)
    }
    
    private func calculateServiceConfidence(_ service: String, in text: String) -> Double {
        let lowercasedText = text.lowercased()
        var confidence = 0.65
        
        // Boost confidence if service appears with business context
        if lowercasedText.contains("appointment") || lowercasedText.contains("booking") ||
           lowercasedText.contains("schedule") || lowercasedText.contains("consultation") {
            confidence += 0.15
        }
        
        return min(0.9, confidence)
    }
    
    private func categorizeBrand(_ brand: String) -> String {
        if ["apple", "google", "microsoft", "amazon", "meta", "facebook"].contains(brand) {
            return "technology"
        } else if ["starbucks", "mcdonalds", "subway", "chipotle"].contains(brand) {
            return "food_beverage"
        } else if ["walmart", "target", "costco", "best buy"].contains(brand) {
            return "retail"
        } else if ["chase", "wells fargo", "bank of america", "paypal"].contains(brand) {
            return "financial"
        } else {
            return "general"
        }
    }
    
    private func categorizeProduct(_ product: String) -> String {
        if ["laptop", "computer", "phone", "tablet", "smartphone"].contains(product) {
            return "electronics"
        } else if ["shirt", "dress", "pants", "shoes", "jacket"].contains(product) {
            return "clothing"
        } else if ["furniture", "table", "chair", "sofa", "bed"].contains(product) {
            return "home_garden"
        } else if ["coffee", "tea", "wine", "beer", "food"].contains(product) {
            return "food_beverage"
        } else {
            return "general"
        }
    }
    
    private func categorizeService(_ service: String) -> String {
        if ["consulting", "legal", "accounting", "financial"].contains(service) {
            return "professional"
        } else if ["healthcare", "medical", "dental", "therapy"].contains(service) {
            return "healthcare"
        } else if ["delivery", "shipping", "moving", "taxi"].contains(service) {
            return "transportation"
        } else if ["cleaning", "landscaping", "maintenance", "repair"].contains(service) {
            return "home_services"
        } else {
            return "general"
        }
    }
    
    private func classifyPhoneNumber(_ phoneNumber: String) -> String {
        if phoneNumber.contains("800") || phoneNumber.contains("888") || phoneNumber.contains("877") {
            return "toll_free"
        } else if phoneNumber.contains("+1") {
            return "us_number"
        } else {
            return "standard"
        }
    }
    
    private func classifyEmail(_ email: String) -> String {
        let domain = extractEmailDomain(email)
        if ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com"].contains(domain) {
            return "personal"
        } else if domain.contains(".edu") {
            return "educational"
        } else if domain.contains(".gov") {
            return "government"
        } else {
            return "business"
        }
    }
    
    private func extractEmailDomain(_ email: String) -> String {
        let components = email.components(separatedBy: "@")
        return components.count > 1 ? components[1] : ""
    }
    
    private func extractBrandContext(_ brand: String, from text: String) -> [String: String] {
        return ["mention_type": "brand", "category": categorizeBrand(brand)]
    }
    
    private func extractProductContext(_ product: String, from text: String) -> [String: String] {
        return ["mention_type": "product", "category": categorizeProduct(product)]
    }
    
    private func extractServiceContext(_ service: String, from text: String) -> [String: String] {
        return ["mention_type": "service", "category": categorizeService(service)]
    }
    
    private func addContextualScoring(text: String, baseScores: [RecognizedContentType: Double]) -> [RecognizedContentType: Double] {
        var enhanced = baseScores
        
        // Boost receipt confidence if currency symbols present
        if text.contains("$") || text.contains("total") || text.contains("tax") {
            enhanced[.receipt] = (enhanced[.receipt] ?? 0.0) + 0.3
        }
        
        // Boost form confidence if form-specific words present
        if text.contains("submit") || text.contains("required") || text.contains("optional") {
            enhanced[.form] = (enhanced[.form] ?? 0.0) + 0.25
        }
        
        // Boost social post confidence if social indicators present
        if text.contains("@") || text.contains("#") || text.contains("like") {
            enhanced[.socialPost] = (enhanced[.socialPost] ?? 0.0) + 0.2
        }
        
        return enhanced
    }
    
    private func calculateContextualBonus(_ contentType: RecognizedContentType, text: String) -> Double {
        switch contentType {
        case .receipt:
            return text.contains("receipt") ? 0.1 : 0.0
        case .form:
            return text.contains("form") ? 0.1 : 0.0
        case .article:
            return text.contains("article") || text.contains("news") ? 0.1 : 0.0
        case .socialPost:
            return text.contains("post") || text.contains("share") ? 0.1 : 0.0
        default:
            return 0.0
        }
    }
    
    private func calculateTextProximity(_ text1: String, _ text2: String, in fullText: String) -> Double {
        let range1 = fullText.range(of: text1, options: .caseInsensitive)
        let range2 = fullText.range(of: text2, options: .caseInsensitive)
        
        guard let r1 = range1, let r2 = range2 else { return Double.greatestFiniteMagnitude }
        
        let distance = abs(fullText.distance(from: r1.lowerBound, to: r2.lowerBound))
        return Double(distance)
    }
    
    private func calculateOverallAccuracy(
        businessEntities: [RecognizedBusinessEntity],
        personalEntities: [RecognizedPersonalEntity],
        contentTypeConfidence: Double
    ) -> Double {
        let businessAccuracy = businessEntities.isEmpty ? 0.5 : businessEntities.map { $0.confidence }.reduce(0, +) / Double(businessEntities.count)
        let personalAccuracy = personalEntities.isEmpty ? 0.5 : personalEntities.map { $0.confidence }.reduce(0, +) / Double(personalEntities.count)
        
        return (businessAccuracy * 0.4) + (personalAccuracy * 0.4) + (contentTypeConfidence * 0.2)
    }
    
    private func removeDuplicateBusinessEntities(_ entities: [RecognizedBusinessEntity]) -> [RecognizedBusinessEntity] {
        var unique: [RecognizedBusinessEntity] = []
        var seen: Set<String> = []
        
        for entity in entities {
            let key = "\(entity.type.rawValue)_\(entity.name.lowercased())"
            if !seen.contains(key) {
                unique.append(entity)
                seen.insert(key)
            }
        }
        
        return unique
    }
    
    private func removeDuplicatePersonalEntities(_ entities: [RecognizedPersonalEntity]) -> [RecognizedPersonalEntity] {
        var unique: [RecognizedPersonalEntity] = []
        var seen: Set<String> = []
        
        for entity in entities {
            let key = "\(entity.type.rawValue)_\(entity.value.lowercased())"
            if !seen.contains(key) {
                unique.append(entity)
                seen.insert(key)
            }
        }
        
        return unique
    }
    
    // MARK: - Caching
    
    private func getCachedResult(for text: String) -> ContentAnalysisResult? {
        return cachedResults[text]
    }
    
    private func cacheResult(_ result: ContentAnalysisResult, for text: String) {
        if cachedResults.count >= maxCacheSize {
            let keysToRemove = Array(cachedResults.keys.prefix(cachedResults.count - maxCacheSize + 1))
            keysToRemove.forEach { cachedResults.removeValue(forKey: $0) }
        }
        
        cachedResults[text] = result
    }
}

// MARK: - Supporting Data Models

/// Business entity with enhanced categorization for recognition service
public struct RecognizedBusinessEntity {
    public let type: RecognizedBusinessEntityType
    public let name: String
    public let category: String
    public let confidence: Double
    public let context: [String: String]
    
    public init(type: RecognizedBusinessEntityType, name: String, category: String, confidence: Double, context: [String: String] = [:]) {
        self.type = type
        self.name = name
        self.category = category
        self.confidence = confidence
        self.context = context
    }
}

/// Personal entity with enhanced classification for recognition service
public struct RecognizedPersonalEntity {
    public let type: RecognizedPersonalEntityType
    public let value: String
    public let label: String
    public let confidence: Double
    public let context: [String: String]
    
    public init(type: RecognizedPersonalEntityType, value: String, label: String, confidence: Double, context: [String: String] = [:]) {
        self.type = type
        self.value = value
        self.label = label
        self.confidence = confidence
        self.context = context
    }
}

/// Entity relationship mapping for recognition service
public struct RecognizedEntityRelationship {
    public let sourceType: RecognizedEntityCategory
    public let sourceValue: String
    public let targetType: RecognizedEntityCategory
    public let targetValue: String
    public let relationshipType: RecognizedRelationshipType
    public let confidence: Double
    public let context: [String: String]
    
    public init(sourceType: RecognizedEntityCategory, sourceValue: String, targetType: RecognizedEntityCategory, targetValue: String, relationshipType: RecognizedRelationshipType, confidence: Double, context: [String: String] = [:]) {
        self.sourceType = sourceType
        self.sourceValue = sourceValue
        self.targetType = targetType
        self.targetValue = targetValue
        self.relationshipType = relationshipType
        self.confidence = confidence
        self.context = context
    }
}

/// Content analysis result container for recognition service
public struct ContentAnalysisResult {
    public let businessEntities: [RecognizedBusinessEntity]
    public let personalEntities: [RecognizedPersonalEntity]
    public let contentType: RecognizedContentType
    public let contentTypeConfidence: Double
    public let entityRelationships: [RecognizedEntityRelationship]
    public let originalText: String
    public let processingTimeMs: Double
    public let overallAccuracy: Double
    public let isSuccessful: Bool
    
    public init(businessEntities: [RecognizedBusinessEntity], personalEntities: [RecognizedPersonalEntity], contentType: RecognizedContentType, contentTypeConfidence: Double, entityRelationships: [RecognizedEntityRelationship], originalText: String, processingTimeMs: Double, overallAccuracy: Double, isSuccessful: Bool) {
        self.businessEntities = businessEntities
        self.personalEntities = personalEntities
        self.contentType = contentType
        self.contentTypeConfidence = contentTypeConfidence
        self.entityRelationships = entityRelationships
        self.originalText = originalText
        self.processingTimeMs = processingTimeMs
        self.overallAccuracy = overallAccuracy
        self.isSuccessful = isSuccessful
    }
}

/// Business entity types for recognition service
public enum RecognizedBusinessEntityType: String, CaseIterable {
    case brand = "brand"
    case product = "product"
    case service = "service"
    case organization = "organization"
}

/// Personal entity types for recognition service
public enum RecognizedPersonalEntityType: String, CaseIterable {
    case contact = "contact"
    case phoneNumber = "phone_number"
    case email = "email"
    case address = "address"
}

/// Content type classification for recognition service
public enum RecognizedContentType: String, CaseIterable {
    case form = "form"
    case receipt = "receipt"
    case article = "article"
    case socialPost = "social_post"
    case email = "email"
    case document = "document"
    case website = "website"
    case menu = "menu"
    case unknown = "unknown"
}

/// Entity categories for relationship mapping in recognition service
public enum RecognizedEntityCategory: String, CaseIterable {
    case business = "business"
    case personal = "personal"
}

/// Relationship types between entities in recognition service
public enum RecognizedRelationshipType: String, CaseIterable {
    case employment = "employment"
    case location = "location"
    case contact = "contact"
    case transaction = "transaction"
    case association = "association"
}