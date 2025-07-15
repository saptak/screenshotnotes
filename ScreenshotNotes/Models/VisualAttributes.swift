import Foundation
import Vision
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Models Namespace
public enum Models {}

// MARK: - Type Aliases for easier access
public typealias DominantColor = Models.DominantColor
public typealias ColorAnalysis = Models.ColorAnalysis

/// Comprehensive visual attributes extracted from screenshot images using Apple's Vision framework
public struct VisualAttributes: Codable, Sendable {
    
    // MARK: - Object Detection
    
    /// Detected objects in the image with confidence scores
    public let detectedObjects: [DetectedObject]
    
    /// Scene classification results
    public let sceneClassification: SceneClassification
    
    /// Visual composition analysis
    public let composition: CompositionAnalysis
    
    /// Dominant colors extracted from the image
    public let colorAnalysis: Models.ColorAnalysis
    
    /// Overall confidence score for the visual analysis
    public let overallConfidence: Double
    
    /// Timestamp when the analysis was performed
    public let analysisTimestamp: Date
    
    public init(
        detectedObjects: [DetectedObject],
        sceneClassification: SceneClassification,
        composition: CompositionAnalysis,
        colorAnalysis: Models.ColorAnalysis,
        overallConfidence: Double,
        analysisTimestamp: Date = Date()
    ) {
        self.detectedObjects = detectedObjects
        self.sceneClassification = sceneClassification
        self.composition = composition
        self.colorAnalysis = colorAnalysis
        self.overallConfidence = overallConfidence
        self.analysisTimestamp = analysisTimestamp
    }
}

// MARK: - Object Detection

/// Represents a detected object in an image
public struct DetectedObject: Codable, Sendable {
    /// Object identifier/label
    public let identifier: String
    /// Human-readable object name
    public let label: String
    /// Confidence score (0.0 to 1.0)
    public let confidence: Double
    /// Bounding box coordinates (normalized 0.0 to 1.0)
    public let boundingBox: BoundingBox
    /// Object category for grouping
    public let category: ObjectCategory
    
    public init(identifier: String, label: String, confidence: Double, boundingBox: BoundingBox, category: ObjectCategory) {
        self.identifier = identifier
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.category = category
    }
}

/// Normalized bounding box coordinates
public struct BoundingBox: Codable, Sendable {
    public let x: Double      // Left edge (0.0 to 1.0)
    public let y: Double      // Top edge (0.0 to 1.0)
    public let width: Double  // Width (0.0 to 1.0)
    public let height: Double // Height (0.0 to 1.0)
    
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    /// Convert from Vision framework CGRect
    public init(from cgRect: CGRect) {
        self.x = Double(cgRect.minX)
        self.y = Double(cgRect.minY)
        self.width = Double(cgRect.width)
        self.height = Double(cgRect.height)
    }
}

/// Object categories for semantic grouping
public enum ObjectCategory: String, Codable, CaseIterable, Sendable {
    case document = "document"
    case receipt = "receipt"
    case text = "text"
    case person = "person"
    case clothing = "clothing"
    case food = "food"
    case vehicle = "vehicle"
    case building = "building"
    case technology = "technology"
    case nature = "nature"
    case furniture = "furniture"
    case unknown = "unknown"
    
    /// Human-readable category name
    public var displayName: String {
        switch self {
        case .document: return "Document"
        case .receipt: return "Receipt"
        case .text: return "Text"
        case .person: return "Person"
        case .clothing: return "Clothing"
        case .food: return "Food"
        case .vehicle: return "Vehicle"
        case .building: return "Building"
        case .technology: return "Technology"
        case .nature: return "Nature"
        case .furniture: return "Furniture"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Scene Classification

/// Scene classification results with confidence scoring
public struct SceneClassification: Codable, Sendable {
    /// Primary scene type
    public let primaryScene: SceneType
    /// Secondary scene type (if applicable)
    public let secondaryScene: SceneType?
    /// Confidence for primary scene classification
    public let primaryConfidence: Double
    /// Confidence for secondary scene classification
    public let secondaryConfidence: Double?
    /// Environment type (indoor/outdoor)
    public let environment: EnvironmentType
    /// Lighting conditions
    public let lighting: LightingConditions
    
    public init(
        primaryScene: SceneType,
        secondaryScene: SceneType? = nil,
        primaryConfidence: Double,
        secondaryConfidence: Double? = nil,
        environment: EnvironmentType,
        lighting: LightingConditions
    ) {
        self.primaryScene = primaryScene
        self.secondaryScene = secondaryScene
        self.primaryConfidence = primaryConfidence
        self.secondaryConfidence = secondaryConfidence
        self.environment = environment
        self.lighting = lighting
    }
}

/// Scene types for classification
public enum SceneType: String, Codable, CaseIterable, Sendable {
    case document = "document"
    case receipt = "receipt"
    case webpage = "webpage"
    case application = "application"
    case photo = "photo"
    case screenshot = "screenshot"
    case message = "message"
    case email = "email"
    case social = "social"
    case shopping = "shopping"
    case map = "map"
    case calendar = "calendar"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .document: return "Document"
        case .receipt: return "Receipt"
        case .webpage: return "Web Page"
        case .application: return "Application"
        case .photo: return "Photo"
        case .screenshot: return "Screenshot"
        case .message: return "Message"
        case .email: return "Email"
        case .social: return "Social Media"
        case .shopping: return "Shopping"
        case .map: return "Map"
        case .calendar: return "Calendar"
        case .unknown: return "Unknown"
        }
    }
}

/// Environment classification
public enum EnvironmentType: String, Codable, CaseIterable, Sendable {
    case indoor = "indoor"
    case outdoor = "outdoor"
    case digital = "digital"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .indoor: return "Indoor"
        case .outdoor: return "Outdoor"
        case .digital: return "Digital"
        case .unknown: return "Unknown"
        }
    }
}

/// Lighting condition analysis
public enum LightingConditions: String, Codable, CaseIterable, Sendable {
    case bright = "bright"
    case normal = "normal"
    case dim = "dim"
    case artificial = "artificial"
    case natural = "natural"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .bright: return "Bright"
        case .normal: return "Normal"
        case .dim: return "Dim"
        case .artificial: return "Artificial"
        case .natural: return "Natural"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Composition Analysis

/// Visual composition and layout analysis
public struct CompositionAnalysis: Codable, Sendable {
    /// Layout type detection
    public let layout: LayoutType
    /// Text density (percentage of image containing text)
    public let textDensity: Double
    /// Image complexity score (0.0 to 1.0)
    public let complexity: Double
    /// Symmetry score (0.0 to 1.0)
    public let symmetry: Double
    /// Visual balance score (0.0 to 1.0)
    public let balance: Double
    /// Text regions detected
    public let textRegions: [TextRegion]
    
    public init(
        layout: LayoutType,
        textDensity: Double,
        complexity: Double,
        symmetry: Double,
        balance: Double,
        textRegions: [TextRegion]
    ) {
        self.layout = layout
        self.textDensity = textDensity
        self.complexity = complexity
        self.symmetry = symmetry
        self.balance = balance
        self.textRegions = textRegions
    }
}

/// Layout type classification
public enum LayoutType: String, Codable, CaseIterable, Sendable {
    case structured = "structured"     // Documents, forms, receipts
    case freeform = "freeform"        // Photos, artwork
    case grid = "grid"                // App interfaces, photo grids
    case list = "list"                // Lists, feeds
    case mixed = "mixed"              // Complex layouts
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .structured: return "Structured"
        case .freeform: return "Freeform"
        case .grid: return "Grid"
        case .list: return "List"
        case .mixed: return "Mixed"
        case .unknown: return "Unknown"
        }
    }
}

/// Text region within the image
public struct TextRegion: Codable, Sendable {
    /// Bounding box of the text region
    public let boundingBox: BoundingBox
    /// Confidence that this region contains text
    public let confidence: Double
    /// Estimated text density in this region
    public let textDensity: Double
    /// Text orientation angle in degrees
    public let orientation: Double
    
    public init(boundingBox: BoundingBox, confidence: Double, textDensity: Double, orientation: Double) {
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.textDensity = textDensity
        self.orientation = orientation
    }
}

// MARK: - Color Analysis

/// Comprehensive color analysis results
extension Models {
    public struct ColorAnalysis: Codable, Sendable {
    /// Dominant colors in order of prominence
    public let dominantColors: [Models.DominantColor]
    /// Overall brightness (0.0 to 1.0)
    public let brightness: Double
    /// Contrast level (0.0 to 1.0)
    public let contrast: Double
    /// Saturation level (0.0 to 1.0)
    public let saturation: Double
    /// Color temperature (warm/cool)
    public let temperature: ColorTemperature
    /// Color scheme type
    public let colorScheme: VisualColorScheme
    /// Visual embedding for similarity search (512-dimensional vector)
    public let visualEmbedding: [Float]
    
    public init(
        dominantColors: [Models.DominantColor],
        brightness: Double,
        contrast: Double,
        saturation: Double,
        temperature: ColorTemperature,
        colorScheme: VisualColorScheme,
        visualEmbedding: [Float] = []
    ) {
        self.dominantColors = dominantColors
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
        self.colorScheme = colorScheme
        self.visualEmbedding = visualEmbedding
    }
    }
}

// MARK: - DominantColor Extension
extension Models {
    /// Dominant color with metadata
    public struct DominantColor: Codable, Sendable {
        /// RGB color values (0.0 to 1.0)
        public let red: Double
        public let green: Double
        public let blue: Double
        /// Color prominence percentage (0.0 to 1.0)
        public let prominence: Double
        /// Human-readable color name
        public let colorName: String
        /// Hex representation
        public let hexValue: String
        
        public init(red: Double, green: Double, blue: Double, prominence: Double, colorName: String, hexValue: String) {
            self.red = red
            self.green = green
            self.blue = blue
            self.prominence = prominence
            self.colorName = colorName
            self.hexValue = hexValue
        }
        
        /// Convert to SwiftUI Color
        #if canImport(UIKit)
        public var uiColor: UIColor {
            return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
        }
        #endif
        
        public var color: Color {
            return Color(red: red, green: green, blue: blue)
        }
    }
}



/// Color temperature classification
public enum ColorTemperature: String, Codable, CaseIterable, Sendable {
    case warm = "warm"
    case cool = "cool"
    case neutral = "neutral"
    case mixed = "mixed"
    
    public var displayName: String {
        switch self {
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .neutral: return "Neutral"
        case .mixed: return "Mixed"
        }
    }
}

/// Visual color scheme classification
public enum VisualColorScheme: String, Codable, CaseIterable, Sendable {
    case monochromatic = "monochromatic"
    case analogous = "analogous"
    case complementary = "complementary"
    case triadic = "triadic"
    case tetradic = "tetradic"
    case vibrant = "vibrant"
    case muted = "muted"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .monochromatic: return "Monochromatic"
        case .analogous: return "Analogous"
        case .complementary: return "Complementary"
        case .triadic: return "Triadic"
        case .tetradic: return "Tetradic"
        case .vibrant: return "Vibrant"
        case .muted: return "Muted"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Helper Extensions

extension VisualAttributes {
    /// Check if the image is likely a document or receipt
    public var isDocument: Bool {
        return sceneClassification.primaryScene == .document || 
               sceneClassification.primaryScene == .receipt ||
               composition.layout == .structured
    }
    
    /// Check if the image contains significant text content
    public var hasSignificantText: Bool {
        return composition.textDensity > 0.3 || !composition.textRegions.isEmpty
    }
    
    /// Get the most prominent objects (confidence > 0.7)
    public var prominentObjects: [DetectedObject] {
        return detectedObjects.filter { $0.confidence > 0.7 }
    }
    
    /// Get semantic tags based on visual analysis
    public var semanticTags: [String] {
        var tags: [String] = []
        
        // Add scene-based tags
        tags.append(sceneClassification.primaryScene.rawValue)
        if let secondary = sceneClassification.secondaryScene {
            tags.append(secondary.rawValue)
        }
        
        // Add object-based tags
        tags.append(contentsOf: prominentObjects.map { $0.label.lowercased() })
        
        // Add color-based tags
        tags.append(contentsOf: colorAnalysis.dominantColors.prefix(3).map { $0.colorName.lowercased() })
        
        // Add composition-based tags
        tags.append(composition.layout.rawValue)
        
        return Array(Set(tags)) // Remove duplicates
    }
}