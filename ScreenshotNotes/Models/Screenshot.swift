import Foundation
import SwiftData
import SwiftUI

@Model
public final class Screenshot {
    @Attribute(.unique) public var id: UUID
    public var imageData: Data
    public var timestamp: Date
    public var filename: String
    public var extractedText: String?
    public var objectTags: [String]?
    public var userNotes: String?
    public var userTags: [String]?
    public var isFavorite: Bool = false
    public var assetIdentifier: String?
    
    // Collections relationship
    @Relationship(deleteRule: .nullify)
    public var collections: [Collection] = []
    
    // Smart grouping relationship
    @Relationship(deleteRule: .nullify)
    public var groups: [ScreenshotGroup] = []
    
    // Workspace relationship
    @Relationship(deleteRule: .nullify)
    public var workspace: ContentWorkspace?
    
    // Phase 5.2.1: Enhanced Vision Processing
    public var visualAttributesData: Data?
    public var lastVisionAnalysis: Date?
    
    // Phase 5.2.3: Semantic Tagging
    public var semanticTagsData: Data?
    public var lastSemanticAnalysis: Date?
    
    // Phase 5.1.2: Entity Extraction
    public var entitiesData: Data?
    public var lastEntityExtraction: Date?
    
    // OCR Processing State
    public var lastOCRProcessing: Date?
    
    // Sprint 7.1.2: Smart Categorization
    public var categoryResultData: Data?
    public var lastCategorization: Date?
    public var manualCategoryOverride: String?
    
    public init(imageData: Data, filename: String, timestamp: Date? = nil, assetIdentifier: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.timestamp = timestamp ?? Date()
        self.filename = filename
        self.extractedText = nil
        self.objectTags = nil
        self.userNotes = nil
        self.userTags = nil
        self.isFavorite = false
        self.assetIdentifier = assetIdentifier
        self.visualAttributesData = nil
        self.lastVisionAnalysis = nil
        self.semanticTagsData = nil
        self.lastSemanticAnalysis = nil
        self.entitiesData = nil
        self.lastEntityExtraction = nil
        self.lastOCRProcessing = nil
        self.categoryResultData = nil
        self.lastCategorization = nil
        self.manualCategoryOverride = nil
    }
}

// MARK: - OCR Processing Support

extension Screenshot {
    
    /// Check if OCR processing is needed
    public var needsOCRProcessing: Bool {
        // If we already have extracted text and it was processed recently, no need to reprocess
        if let extractedText = extractedText, !extractedText.isEmpty,
           let lastOCR = lastOCRProcessing {
            // Consider OCR fresh for 365 days (essentially permanent unless manually triggered)
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date.distantPast
            return lastOCR < oneYearAgo
        }
        
        // If no extracted text or no processing date, needs OCR
        return extractedText?.isEmpty ?? true
    }
    
    /// Mark OCR as completed
    public func markOCRCompleted(with text: String?) {
        self.extractedText = text
        self.lastOCRProcessing = Date()
    }
}

// MARK: - Semantic Tagging Support

extension Screenshot {
    
    /// Get semantic tags from stored data
    public var semanticTags: SemanticTagCollection? {
        get {
            guard let data = semanticTagsData else { return nil }
            return try? JSONDecoder().decode(SemanticTagCollection.self, from: data)
        }
        set {
            if let tags = newValue {
                semanticTagsData = try? JSONEncoder().encode(tags)
                lastSemanticAnalysis = Date()
            } else {
                semanticTagsData = nil
                lastSemanticAnalysis = nil
            }
        }
    }
    
    /// Check if semantic analysis needs to be refreshed
    public var needsSemanticAnalysis: Bool {
        guard let lastAnalysis = lastSemanticAnalysis else { return true }
        
        // Consider analysis stale after 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        return lastAnalysis < thirtyDaysAgo
    }
    
    /// Get high-confidence semantic tags for search
    public var highConfidenceSemanticTags: [SemanticTag] {
        return semanticTags?.highConfidenceTags() ?? []
    }
    
    /// Get business entities from semantic tags
    public var businessEntities: [SemanticTag] {
        return semanticTags?.tags(in: .brand) ?? []
    }
    
    /// Get content type classification
    public var contentType: SemanticTag? {
        return semanticTags?.tags(in: .contentType).first
    }
    
    /// Get all searchable tag names
    public var searchableTagNames: [String] {
        var tagNames: [String] = []
        
        // Add semantic tag names
        if let semanticTags = semanticTags {
            tagNames.append(contentsOf: semanticTags.uniqueTagNames)
        }
        
        // Add existing object tags
        if let objectTags = objectTags {
            tagNames.append(contentsOf: objectTags)
        }
        
        // Add user tags
        if let userTags = userTags {
            tagNames.append(contentsOf: userTags)
        }
        
        return Array(Set(tagNames))
    }
}

// MARK: - Entity Extraction Support

extension Screenshot {
    
    /// Get extracted entities from stored data
    public var entities: [ExtractedEntity]? {
        get {
            guard let data = entitiesData else { return nil }
            return try? JSONDecoder().decode([ExtractedEntity].self, from: data)
        }
        set {
            if let entities = newValue {
                entitiesData = try? JSONEncoder().encode(entities)
                lastEntityExtraction = Date()
            } else {
                entitiesData = nil
                lastEntityExtraction = nil
            }
        }
    }
    
    /// Check if entity extraction needs to be refreshed
    public var needsEntityExtraction: Bool {
        guard let lastExtraction = lastEntityExtraction else { return true }
        
        // Consider extraction stale after 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        return lastExtraction < thirtyDaysAgo
    }
    
    /// Get entities by type
    public func entities(ofType type: EntityType) -> [ExtractedEntity] {
        return entities?.filter { $0.type == type } ?? []
    }
    
    /// Get all location entities
    public var locationEntities: [ExtractedEntity] {
        return entities(ofType: .place)
    }
    
    /// Get all date entities
    public var dateEntities: [ExtractedEntity] {
        return entities(ofType: .date)
    }
    
    /// Get all person entities
    public var personEntities: [ExtractedEntity] {
        return entities(ofType: .person)
    }
    
    /// Get all organization entities
    public var organizationEntities: [ExtractedEntity] {
        return entities(ofType: .organization)
    }
    
    /// Get all currency entities
    public var currencyEntities: [ExtractedEntity] {
        return entities(ofType: .currency)
    }
    
    /// Get high-confidence entities for search
    public var highConfidenceEntities: [ExtractedEntity] {
        return entities?.filter { $0.confidence.rawValue >= 0.7 } ?? []
    }
    
    /// Get searchable entity values
    public var searchableEntityValues: [String] {
        return entities?.map { $0.normalizedValue } ?? []
    }
}

// MARK: - Visual Attributes Support

extension Screenshot {
    
    /// Get visual attributes from stored data
    public var visualAttributes: VisualAttributes? {
        get {
            guard let data = visualAttributesData else { return nil }
            return try? JSONDecoder().decode(VisualAttributes.self, from: data)
        }
        set {
            if let attributes = newValue {
                visualAttributesData = try? JSONEncoder().encode(attributes)
                lastVisionAnalysis = Date()
            } else {
                visualAttributesData = nil
                lastVisionAnalysis = nil
            }
        }
    }
    
    /// Check if vision analysis needs to be refreshed
    public var needsVisionAnalysis: Bool {
        guard let lastAnalysis = lastVisionAnalysis else { return true }
        
        // Consider analysis stale after 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        return lastAnalysis < sevenDaysAgo
    }
    
    /// Get semantic tags from both OCR and vision analysis
    public var allSemanticTags: [String] {
        var tags: [String] = []
        
        // Add existing object tags
        if let objectTags = objectTags {
            tags.append(contentsOf: objectTags)
        }
        
        // Add user tags
        if let userTags = userTags {
            tags.append(contentsOf: userTags)
        }
        
        // Add vision-based semantic tags
        if let visualTags = visualAttributes?.semanticTags {
            tags.append(contentsOf: visualTags)
        }
        
        return Array(Set(tags)) // Remove duplicates
    }
    
    /// Check if screenshot is likely a document based on vision analysis
    public var isDocumentLikely: Bool {
        return visualAttributes?.isDocument ?? false
    }
    
    /// Check if screenshot contains significant text
    public var hasSignificantText: Bool {
        return visualAttributes?.hasSignificantText ?? ((extractedText?.count ?? 0) > 50)
    }
    
    /// Get prominent visual objects
    public var prominentObjects: [DetectedObject] {
        return visualAttributes?.prominentObjects ?? []
    }
    
    /// Get dominant colors for visual search
    public var dominantColors: [DominantColor] {
        return visualAttributes?.colorAnalysis.dominantColors ?? []
    }
}

// MARK: - Smart Categorization Support

extension Screenshot {
    
    /// Get category result from stored data
    public var categoryResult: CategoryResult? {
        get {
            guard let data = categoryResultData else { return nil }
            return try? JSONDecoder().decode(CategoryResult.self, from: data)
        }
        set {
            if let result = newValue {
                categoryResultData = try? JSONEncoder().encode(result)
                lastCategorization = Date()
            } else {
                categoryResultData = nil
                lastCategorization = nil
            }
        }
    }
    
    /// Get the current category (manual override takes precedence)
    public var currentCategory: Category? {
        // Manual override takes precedence
        if let overrideId = manualCategoryOverride,
           let category = Category.categoryById(overrideId) {
            return category
        }
        
        // Fall back to automatic categorization
        return categoryResult?.category
    }
    
    /// Get the category display path (e.g., "Financial > Receipts > Food")
    public var categoryDisplayPath: String? {
        return currentCategory?.displayPath()
    }
    
    /// Check if categorization needs to be refreshed
    public var needsCategorization: Bool {
        // Always categorize if never done before
        guard let lastCategorization = lastCategorization else { return true }
        
        // Re-categorize if it's been more than 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        return lastCategorization < thirtyDaysAgo
    }
    
    /// Check if categorization has low confidence and might need user review
    public var categoryNeedsReview: Bool {
        guard let result = categoryResult else { return true }
        return result.confidence < 0.7 || result.uncertainty.isUncertain
    }
    
    /// Get alternative category suggestions
    public var alternativeCategories: [CategoryConfidence] {
        return categoryResult?.alternativeCategories ?? []
    }
    
    /// Set manual category override
    public func setManualCategory(_ category: Category) {
        manualCategoryOverride = category.id
    }
    
    /// Clear manual category override (revert to automatic)
    public func clearManualCategory() {
        manualCategoryOverride = nil
    }
    
    /// Check if category was manually set
    public var hasManualCategory: Bool {
        return manualCategoryOverride != nil
    }
    
    /// Get categorization confidence score
    public var categorizationConfidence: Double {
        return categoryResult?.confidence ?? 0.0
    }
    
    /// Get categorization signals used
    public var categorizationSignals: [ClassificationSignal] {
        return categoryResult?.signals ?? []
    }
    
    /// Create screenshot metadata for categorization
    public var categorizationMetadata: ScreenshotMetadata {
        return ScreenshotMetadata(
            timestamp: timestamp,
            sourceApp: extractSourceApp(),
            fileSize: imageData.count,
            dimensions: extractImageDimensions(),
            colorSpace: "sRGB",
            hasGPS: false
        )
    }
    
    private func extractSourceApp() -> String? {
        // Extract from filename or other metadata if available
        // This is a placeholder implementation
        if filename.contains("instagram") { return "Instagram" }
        if filename.contains("whatsapp") { return "WhatsApp" }
        if filename.contains("safari") { return "Safari" }
        return nil
    }
    
    private func extractImageDimensions() -> CGSize? {
        #if canImport(UIKit)
        guard let image = UIImage(data: imageData) else { return nil }
        return image.size
        #else
        return nil
        #endif
    }
    
    /// Get category-based search terms
    public var categorySearchTerms: [String] {
        var terms: [String] = []
        
        if let category = currentCategory {
            terms.append(category.name)
            terms.append(category.displayName)
            terms.append(contentsOf: category.keywords)
            
            // Add parent category terms
            let hierarchy = category.hierarchyPath()
            terms.append(contentsOf: hierarchy.flatMap { [$0.name, $0.displayName] })
        }
        
        return Array(Set(terms)).filter { !$0.isEmpty }
    }
    
    /// Check if screenshot matches category filter
    public func matchesCategoryFilter(_ categoryId: String) -> Bool {
        // Check current category and its hierarchy
        guard let category = currentCategory else { return false }
        
        let hierarchy = category.hierarchyPath()
        return hierarchy.contains { $0.id == categoryId }
    }
    
    /// Get category icon for UI display
    public var categoryIcon: String {
        return currentCategory?.icon ?? "questionmark.square"
    }
    
    /// Get category color for UI display
    public var categoryColor: Color {
        return currentCategory?.color ?? .secondary
    }
}
