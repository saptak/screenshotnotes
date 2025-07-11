import Foundation
import SwiftData

@Model
public final class Screenshot: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var imageData: Data
    public var timestamp: Date
    public var filename: String
    public var extractedText: String?
    public var objectTags: [String]?
    public var userNotes: String?
    public var userTags: [String]?
    public var assetIdentifier: String?
    
    // Phase 5.2.1: Enhanced Vision Processing
    public var visualAttributesData: Data?
    public var lastVisionAnalysis: Date?
    
    // Phase 5.2.3: Semantic Tagging
    public var semanticTagsData: Data?
    public var lastSemanticAnalysis: Date?
    
    public init(imageData: Data, filename: String, timestamp: Date? = nil, assetIdentifier: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.timestamp = timestamp ?? Date()
        self.filename = filename
        self.extractedText = nil
        self.objectTags = nil
        self.userNotes = nil
        self.userTags = nil
        self.assetIdentifier = assetIdentifier
        self.visualAttributesData = nil
        self.lastVisionAnalysis = nil
        self.semanticTagsData = nil
        self.lastSemanticAnalysis = nil
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
