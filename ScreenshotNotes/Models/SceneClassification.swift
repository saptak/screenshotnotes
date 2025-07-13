import Foundation
import Vision
import SwiftUI

// MARK: - Advanced Scene Classification

/// Advanced scene classification results with confidence scoring and attention analysis
public struct AdvancedSceneClassification: Codable, Sendable {
    /// Primary scene classification result
    public let primaryScene: AdvancedSceneType
    /// Secondary scene types with confidence scores
    public let secondaryScenes: [SceneConfidence]
    /// Overall confidence for the primary classification
    public let confidence: Double
    /// Attention-based focus areas within the scene
    public let attentionAreas: [AttentionArea]
    /// Analysis timestamp
    public let timestamp: Date
    /// Processing metadata
    public let processingMetadata: ProcessingMetadata
    
    public init(
        primaryScene: AdvancedSceneType,
        secondaryScenes: [SceneConfidence] = [],
        confidence: Double,
        attentionAreas: [AttentionArea] = [],
        timestamp: Date = Date(),
        processingMetadata: ProcessingMetadata = ProcessingMetadata()
    ) {
        self.primaryScene = primaryScene
        self.secondaryScenes = secondaryScenes
        self.confidence = confidence
        self.attentionAreas = attentionAreas
        self.timestamp = timestamp
        self.processingMetadata = processingMetadata
    }
}

// MARK: - Scene Type Enumeration

/// Advanced scene types for comprehensive classification
public enum AdvancedSceneType: String, Codable, CaseIterable, Sendable {
    // Document & Text Content
    case document = "document"
    case receipt = "receipt"
    case invoice = "invoice"
    case businessCard = "business_card"
    case handwriting = "handwriting"
    case form = "form"
    case certificate = "certificate"
    case menu = "menu"
    case brochure = "brochure"
    case presentation = "presentation"
    
    // Digital Interfaces
    case webPage = "web_page"
    case mobileApp = "mobile_app"
    case socialMedia = "social_media"
    case email = "email"
    case message = "message"
    case calendar = "calendar"
    case map = "map"
    case shopping = "shopping"
    case video = "video"
    case game = "game"
    
    // Physical Objects & Products
    case product = "product"
    case clothing = "clothing"
    case electronics = "electronics"
    case food = "food"
    case books = "books"
    case artwork = "artwork"
    case vehicle = "vehicle"
    case architecture = "architecture"
    
    // People & Social
    case people = "people"
    case portrait = "portrait"
    case group = "group"
    case event = "event"
    case wedding = "wedding"
    case graduation = "graduation"
    case meeting = "meeting"
    
    // Nature & Environment
    case landscape = "landscape"
    case cityscape = "cityscape"
    case indoor = "indoor"
    case outdoor = "outdoor"
    case nature = "nature"
    case weather = "weather"
    
    // Specialized Content
    case medicalContent = "medical_content"
    case legalContent = "legal_content"
    case educationalContent = "educational_content"
    case financialContent = "financial_content"
    case technicalDiagram = "technical_diagram"
    case chart = "chart"
    case qrCode = "qr_code"
    case barcode = "barcode"
    
    // Generic
    case photo = "photo"
    case screenshot = "screenshot"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .document: return "Document"
        case .receipt: return "Receipt"
        case .invoice: return "Invoice"
        case .businessCard: return "Business Card"
        case .handwriting: return "Handwriting"
        case .form: return "Form"
        case .certificate: return "Certificate"
        case .menu: return "Menu"
        case .brochure: return "Brochure"
        case .presentation: return "Presentation"
        case .webPage: return "Web Page"
        case .mobileApp: return "Mobile App"
        case .socialMedia: return "Social Media"
        case .email: return "Email"
        case .message: return "Message"
        case .calendar: return "Calendar"
        case .map: return "Map"
        case .shopping: return "Shopping"
        case .video: return "Video"
        case .game: return "Game"
        case .product: return "Product"
        case .clothing: return "Clothing"
        case .electronics: return "Electronics"
        case .food: return "Food"
        case .books: return "Books"
        case .artwork: return "Artwork"
        case .vehicle: return "Vehicle"
        case .architecture: return "Architecture"
        case .people: return "People"
        case .portrait: return "Portrait"
        case .group: return "Group"
        case .event: return "Event"
        case .wedding: return "Wedding"
        case .graduation: return "Graduation"
        case .meeting: return "Meeting"
        case .landscape: return "Landscape"
        case .cityscape: return "Cityscape"
        case .indoor: return "Indoor"
        case .outdoor: return "Outdoor"
        case .nature: return "Nature"
        case .weather: return "Weather"
        case .medicalContent: return "Medical Content"
        case .legalContent: return "Legal Content"
        case .educationalContent: return "Educational Content"
        case .financialContent: return "Financial Content"
        case .technicalDiagram: return "Technical Diagram"
        case .chart: return "Chart"
        case .qrCode: return "QR Code"
        case .barcode: return "Barcode"
        case .photo: return "Photo"
        case .screenshot: return "Screenshot"
        case .unknown: return "Unknown"
        }
    }
    
    public var icon: String {
        switch self {
        case .document: return "doc.text"
        case .receipt: return "receipt"
        case .invoice: return "doc.plaintext"
        case .businessCard: return "person.crop.rectangle"
        case .handwriting: return "pencil"
        case .form: return "list.clipboard"
        case .certificate: return "seal"
        case .menu: return "list.bullet"
        case .brochure: return "newspaper"
        case .presentation: return "rectangle.3.group"
        case .webPage: return "globe"
        case .mobileApp: return "app"
        case .socialMedia: return "person.3"
        case .email: return "envelope"
        case .message: return "message"
        case .calendar: return "calendar"
        case .map: return "map"
        case .shopping: return "bag"
        case .video: return "play.rectangle"
        case .game: return "gamecontroller"
        case .product: return "cube.box"
        case .clothing: return "tshirt"
        case .electronics: return "desktopcomputer"
        case .food: return "fork.knife"
        case .books: return "book"
        case .artwork: return "paintbrush"
        case .vehicle: return "car"
        case .architecture: return "building.2"
        case .people: return "person.2"
        case .portrait: return "person"
        case .group: return "person.3"
        case .event: return "party.popper"
        case .wedding: return "heart"
        case .graduation: return "graduationcap"
        case .meeting: return "person.3.sequence"
        case .landscape: return "mountain.2"
        case .cityscape: return "building.2.crop.circle"
        case .indoor: return "house"
        case .outdoor: return "tree"
        case .nature: return "leaf"
        case .weather: return "cloud.sun"
        case .medicalContent: return "cross"
        case .legalContent: return "scale.3d"
        case .educationalContent: return "book.pages"
        case .financialContent: return "dollarsign.circle"
        case .technicalDiagram: return "gearshape.2"
        case .chart: return "chart.bar"
        case .qrCode: return "qrcode"
        case .barcode: return "barcode"
        case .photo: return "photo"
        case .screenshot: return "rectangle.dashed"
        case .unknown: return "questionmark.square"
        }
    }
    
    public var color: Color {
        switch self {
        case .document, .form, .certificate: return .blue
        case .receipt, .invoice, .financialContent: return .green
        case .businessCard, .people, .portrait, .group: return .purple
        case .webPage, .mobileApp, .socialMedia: return .orange
        case .shopping, .product, .clothing: return .pink
        case .food, .menu: return .red
        case .nature, .landscape, .outdoor: return .mint
        case .medicalContent: return .cyan
        case .educationalContent: return .indigo
        case .chart, .technicalDiagram: return .teal
        default: return .secondary
        }
    }
    
    /// Confidence threshold for this scene type
    public var confidenceThreshold: Double {
        switch self {
        case .receipt, .invoice, .qrCode, .barcode: return 0.85  // High confidence needed
        case .businessCard, .certificate, .chart: return 0.80
        case .document, .form, .webPage: return 0.75
        case .people, .portrait, .food: return 0.70
        default: return 0.65  // Standard threshold
        }
    }
}

// MARK: - Scene Confidence

/// Scene classification result with confidence score
public struct SceneConfidence: Codable, Sendable {
    public let scene: AdvancedSceneType
    public let confidence: Double
    
    public init(scene: AdvancedSceneType, confidence: Double) {
        self.scene = scene
        self.confidence = confidence
    }
}

// MARK: - Attention Area

/// Attention-based focus area within a scene
public struct AttentionArea: Codable, Sendable {
    /// Normalized bounding box (0.0 to 1.0)
    public let boundingBox: BoundingBox
    /// Attention confidence score
    public let confidence: Double
    /// Type of attention (object-based, salient, etc.)
    public let attentionType: AttentionType
    /// Optional detected object in this area
    public let detectedObject: String?
    
    public init(
        boundingBox: BoundingBox,
        confidence: Double,
        attentionType: AttentionType,
        detectedObject: String? = nil
    ) {
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.attentionType = attentionType
        self.detectedObject = detectedObject
    }
}

/// Type of attention detection
public enum AttentionType: String, Codable, CaseIterable, Sendable {
    case objectBased = "object_based"
    case saliencyBased = "saliency_based"
    case faceBased = "face_based"
    case textBased = "text_based"
    
    public var displayName: String {
        switch self {
        case .objectBased: return "Object Focus"
        case .saliencyBased: return "Visual Saliency"
        case .faceBased: return "Face Detection"
        case .textBased: return "Text Region"
        }
    }
}

// MARK: - Processing Metadata

/// Metadata about the vision processing operation
public struct ProcessingMetadata: Codable, Sendable {
    /// Processing duration in seconds
    public let processingTime: TimeInterval
    /// Vision model versions used
    public let modelVersions: [String]
    /// Device capabilities used
    public let deviceCapabilities: DeviceCapabilities
    /// Processing quality level
    public let qualityLevel: ProcessingQuality
    
    public init(
        processingTime: TimeInterval = 0,
        modelVersions: [String] = [],
        deviceCapabilities: DeviceCapabilities = DeviceCapabilities(),
        qualityLevel: ProcessingQuality = .standard
    ) {
        self.processingTime = processingTime
        self.modelVersions = modelVersions
        self.deviceCapabilities = deviceCapabilities
        self.qualityLevel = qualityLevel
    }
}

/// Device capabilities for vision processing
public struct DeviceCapabilities: Codable, Sendable {
    public let neuralEngine: Bool
    public let highPerformanceMode: Bool
    public let memoryCapacity: Int // MB
    
    public init(
        neuralEngine: Bool = false,
        highPerformanceMode: Bool = false,
        memoryCapacity: Int = 0
    ) {
        self.neuralEngine = neuralEngine
        self.highPerformanceMode = highPerformanceMode
        self.memoryCapacity = memoryCapacity
    }
}

/// Processing quality levels
public enum ProcessingQuality: String, Codable, CaseIterable, Sendable {
    case fast = "fast"
    case standard = "standard"
    case accurate = "accurate"
    case comprehensive = "comprehensive"
    
    public var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .standard: return "Standard"
        case .accurate: return "Accurate"
        case .comprehensive: return "Comprehensive"
        }
    }
    
    /// Processing priority for this quality level
    public var priority: Float {
        switch self {
        case .fast: return 0.3
        case .standard: return 0.5
        case .accurate: return 0.7
        case .comprehensive: return 1.0
        }
    }
}

// MARK: - Face Detection Results

/// Face detection information
public struct FaceDetection: Codable, Sendable {
    /// Detected face bounding boxes
    public let faces: [DetectedFace]
    /// Overall confidence in face detection
    public let confidence: Double
    /// Number of faces detected
    public var faceCount: Int { faces.count }
    
    public init(faces: [DetectedFace], confidence: Double) {
        self.faces = faces
        self.confidence = confidence
    }
}

/// Individual detected face
public struct DetectedFace: Codable, Sendable {
    /// Face bounding box
    public let boundingBox: BoundingBox
    /// Detection confidence
    public let confidence: Double
    /// Face landmarks (if available)
    public let landmarks: FaceLandmarks?
    
    public init(
        boundingBox: BoundingBox,
        confidence: Double,
        landmarks: FaceLandmarks? = nil
    ) {
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.landmarks = landmarks
    }
}

/// Face landmarks information
public struct FaceLandmarks: Codable, Sendable {
    public let leftEye: CGPoint?
    public let rightEye: CGPoint?
    public let nose: CGPoint?
    public let mouth: CGPoint?
    
    public init(
        leftEye: CGPoint? = nil,
        rightEye: CGPoint? = nil,
        nose: CGPoint? = nil,
        mouth: CGPoint? = nil
    ) {
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.nose = nose
        self.mouth = mouth
    }
}

// MARK: - Enhanced Text Recognition

/// Enhanced text recognition results with language optimization
public struct EnhancedTextRecognition: Codable, Sendable {
    /// Recognized text blocks
    public let textBlocks: [TextBlock]
    /// Detected languages
    public let detectedLanguages: [RecognizedLanguage]
    /// Overall recognition confidence
    public let confidence: Double
    /// Processing metadata
    public let processingInfo: TextProcessingInfo
    
    public init(
        textBlocks: [TextBlock],
        detectedLanguages: [RecognizedLanguage],
        confidence: Double,
        processingInfo: TextProcessingInfo
    ) {
        self.textBlocks = textBlocks
        self.detectedLanguages = detectedLanguages
        self.confidence = confidence
        self.processingInfo = processingInfo
    }
}

/// Individual text block with enhanced metadata
public struct TextBlock: Codable, Sendable {
    /// Recognized text content
    public let text: String
    /// Bounding box for the text
    public let boundingBox: BoundingBox
    /// Recognition confidence
    public let confidence: Double
    /// Detected language for this block
    public let language: String?
    /// Text characteristics
    public let characteristics: TextCharacteristics
    
    public init(
        text: String,
        boundingBox: BoundingBox,
        confidence: Double,
        language: String? = nil,
        characteristics: TextCharacteristics = TextCharacteristics()
    ) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.language = language
        self.characteristics = characteristics
    }
}

/// Text characteristics and formatting
public struct TextCharacteristics: Codable, Sendable {
    public let fontSize: Float?
    public let isBold: Bool
    public let isItalic: Bool
    public let isUnderlined: Bool
    public let alignment: TextAlignment
    
    public init(
        fontSize: Float? = nil,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        alignment: TextAlignment = .unknown
    ) {
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.alignment = alignment
    }
}

/// Text alignment types
public enum TextAlignment: String, Codable, CaseIterable, Sendable {
    case left = "left"
    case center = "center"
    case right = "right"
    case justified = "justified"
    case unknown = "unknown"
}

/// Recognized language with confidence
public struct RecognizedLanguage: Codable, Sendable {
    public let code: String
    public let name: String
    public let confidence: Double
    
    public init(code: String, name: String, confidence: Double) {
        self.code = code
        self.name = name
        self.confidence = confidence
    }
}

/// Text processing information
public struct TextProcessingInfo: Codable, Sendable {
    public let processingTime: TimeInterval
    public let recognitionLevel: TextRecognitionLevel
    public let languageHints: [String]
    
    public init(
        processingTime: TimeInterval,
        recognitionLevel: TextRecognitionLevel,
        languageHints: [String] = []
    ) {
        self.processingTime = processingTime
        self.recognitionLevel = recognitionLevel
        self.languageHints = languageHints
    }
}

/// Text recognition processing levels
public enum TextRecognitionLevel: String, Codable, CaseIterable, Sendable {
    case fast = "fast"
    case accurate = "accurate"
    case comprehensive = "comprehensive"
    
    public var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .accurate: return "Accurate"
        case .comprehensive: return "Comprehensive"
        }
    }
}

// MARK: - Comprehensive Vision Results

/// Complete vision analysis results combining all detection types
public struct ComprehensiveVisionResults: Codable, Sendable {
    /// Scene classification results
    public let sceneClassification: AdvancedSceneClassification
    /// Face detection results
    public let faceDetection: FaceDetection?
    /// Enhanced text recognition results
    public let textRecognition: EnhancedTextRecognition?
    /// Combined confidence score
    public let overallConfidence: Double
    /// Analysis completion timestamp
    public let analysisTimestamp: Date
    
    public let colorAnalysis: ColorAnalysisService.ColorAnalysisResult?

    public init(
        sceneClassification: AdvancedSceneClassification,
        faceDetection: FaceDetection? = nil,
        textRecognition: EnhancedTextRecognition? = nil,
        colorAnalysis: ColorAnalysisService.ColorAnalysisResult? = nil,
        analysisTimestamp: Date = Date()
    ) {
        self.sceneClassification = sceneClassification
        self.faceDetection = faceDetection
        self.textRecognition = textRecognition
        self.colorAnalysis = colorAnalysis
        self.analysisTimestamp = analysisTimestamp
        
        // Calculate overall confidence as weighted average
        var totalWeight = sceneClassification.confidence
        var totalScore = sceneClassification.confidence
        
        if let faceDetection = faceDetection {
            totalWeight += 0.3
            totalScore += faceDetection.confidence * 0.3
        }
        
        if let textRecognition = textRecognition {
            totalWeight += 0.4
            totalScore += textRecognition.confidence * 0.4
        }

        if let colorAnalysis = colorAnalysis {
            totalWeight += 0.2
            totalScore += (colorAnalysis.brightness + colorAnalysis.contrast + colorAnalysis.saturation) / 3.0 * 0.2
        }
        
        self.overallConfidence = totalScore / totalWeight
    }
}