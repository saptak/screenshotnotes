import Foundation
import Vision
import CoreML
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

/// Phase 5.2.1 & 5.2.2: Enhanced Vision Processing Service
/// Advanced object detection, scene classification, and color analysis using Apple's Vision framework
@MainActor
public final class EnhancedVisionService: ObservableObject {
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let objectDetectionThreshold: Float = 0.5
        static let sceneClassificationThreshold: Float = 0.3
        static let maxDetectedObjects: Int = 20
        static let processingTimeout: TimeInterval = 10.0
        static let cacheSize: Int = 500
    }
    
    // MARK: - Performance Metrics
    
    public struct PerformanceMetrics {
        var processingTime: TimeInterval = 0
        var objectCount: Int = 0
        var analysisConfidence: Double = 0
        var cacheHit: Bool = false
        var enhancementsApplied: [String] = []
    }
    
    @Published public var lastMetrics = PerformanceMetrics()
    
    // MARK: - Dependencies
    
    // Note: ColorAnalysisService integration temporarily simplified due to build issues
    // TODO: Re-integrate full ColorAnalysisService when project structure is resolved
    private let colorAnalysisService = ColorAnalysisService()
    
    // MARK: - Caching
    
    private var analysisCache: [String: VisualAttributes] = [:]
    
    // MARK: - Apple Vision Framework Components
    
    /// Core ML model for advanced object detection (if available)
    private var objectDetectionModel: VNCoreMLModel?
    
    /// Scene classification request
    private lazy var sceneClassificationRequest: VNClassifyImageRequest = {
        let request = VNClassifyImageRequest()
        return request
    }()
    
    /// Saliency request for visual attention analysis
    private lazy var saliencyRequest: VNGenerateAttentionBasedSaliencyImageRequest = {
        return VNGenerateAttentionBasedSaliencyImageRequest()
    }()
    
    // MARK: - Initialization
    
    public init() {
        setupVisionRequests()
        loadOptionalModels()
    }
    
    // MARK: - Main Analysis Methods
    
    /// Perform comprehensive visual analysis on screenshot image data
    public func analyzeScreenshot(_ imageData: Data) async -> VisualAttributes? {
        let startTime = CFAbsoluteTimeGetCurrent()
        var metrics = PerformanceMetrics()
        
        // Check cache first
        let cacheKey = generateCacheKey(for: imageData)
        if let cached = analysisCache[cacheKey] {
            metrics.cacheHit = true
            metrics.processingTime = CFAbsoluteTimeGetCurrent() - startTime
            await MainActor.run {
                self.lastMetrics = metrics
            }
            return cached
        }
        
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            return nil
        }
        
        // Perform multi-stage analysis
        let analysis = await performComprehensiveAnalysis(cgImage: cgImage)
        
        // Cache the result
        if analysisCache.count < Configuration.cacheSize {
            analysisCache[cacheKey] = analysis
        }
        
        // Update metrics
        metrics.processingTime = CFAbsoluteTimeGetCurrent() - startTime
        metrics.objectCount = analysis?.detectedObjects.count ?? 0
        metrics.analysisConfidence = analysis?.overallConfidence ?? 0
        metrics.enhancementsApplied = ["object_detection", "scene_classification", "composition_analysis", "color_analysis"]
        
        await MainActor.run {
            self.lastMetrics = metrics
        }
        
        return analysis
    }
    
    /// Perform comprehensive analysis combining multiple Vision requests
    private func performComprehensiveAnalysis(cgImage: CGImage) async -> VisualAttributes? {
        // Run all analysis requests concurrently for performance
        async let objectResults = performObjectDetection(cgImage: cgImage)
        async let sceneResults = performSceneClassification(cgImage: cgImage)
        async let compositionResults = performCompositionAnalysis(cgImage: cgImage)
        async let colorResults = performColorAnalysis(cgImage: cgImage)
        
        // Await all results
        let objects = await objectResults
        let scene = await sceneResults
        let composition = await compositionResults
        let colors = await colorResults
        
        // Calculate overall confidence
        let overallConfidence = calculateOverallConfidence(
            objectConfidence: objects.isEmpty ? 0 : objects.map { $0.confidence }.reduce(0, +) / Double(objects.count),
            sceneConfidence: scene.primaryConfidence,
            compositionConfidence: composition.complexity,
            colorConfidence: colors.dominantColors.isEmpty ? 0 : colors.dominantColors[0].prominence
        )
        
        return VisualAttributes(
            detectedObjects: objects,
            sceneClassification: scene,
            composition: composition,
            colorAnalysis: colors,
            overallConfidence: overallConfidence
        )
    }
}

// MARK: - Object Detection

extension EnhancedVisionService {
    
    /// Perform advanced object detection using Vision framework
    private func performObjectDetection(cgImage: CGImage) async -> [DetectedObject] {
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            let request = VNDetectHumanRectanglesRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true
                
                if let error = error {
                    print("Object detection error: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                
                guard let results = request.results as? [VNHumanObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let detectedObjects = results.map { result in
                    return DetectedObject(
                        identifier: "person",
                        label: "Person",
                        confidence: Double(result.confidence),
                        boundingBox: BoundingBox(from: result.boundingBox),
                        category: .person
                    )
                }
                continuation.resume(returning: detectedObjects)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /// Categorize detected objects into semantic groups
    private func categorizeObject(identifier: String) -> ObjectCategory {
        let lowercaseId = identifier.lowercased()
        
        switch lowercaseId {
        case let id where id.contains("document") || id.contains("paper") || id.contains("receipt"):
            return .document
        case let id where id.contains("receipt") || id.contains("bill") || id.contains("invoice"):
            return .receipt
        case let id where id.contains("text") || id.contains("writing"):
            return .text
        case let id where id.contains("person") || id.contains("human") || id.contains("face"):
            return .person
        case let id where id.contains("clothing") || id.contains("shirt") || id.contains("dress") || id.contains("pants"):
            return .clothing
        case let id where id.contains("food") || id.contains("meal") || id.contains("drink"):
            return .food
        case let id where id.contains("car") || id.contains("vehicle") || id.contains("truck") || id.contains("bike"):
            return .vehicle
        case let id where id.contains("building") || id.contains("house") || id.contains("structure"):
            return .building
        case let id where id.contains("phone") || id.contains("computer") || id.contains("screen") || id.contains("device"):
            return .technology
        case let id where id.contains("tree") || id.contains("plant") || id.contains("flower") || id.contains("nature"):
            return .nature
        case let id where id.contains("furniture") || id.contains("chair") || id.contains("table"):
            return .furniture
        default:
            return .unknown
        }
    }
    
    /// Convert object identifier to human-readable label
    private func humanReadableLabel(for identifier: String) -> String {
        // Remove technical prefixes and convert to title case
        let cleaned = identifier.replacingOccurrences(of: "/m/", with: "")
            .replacingOccurrences(of: "_", with: " ")
        
        return cleaned.capitalized
    }
}

// MARK: - Scene Classification

extension EnhancedVisionService {
    
    /// Perform intelligent scene classification
    private func performSceneClassification(cgImage: CGImage) async -> SceneClassification {
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNClassifyImageRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true
                
                if let error = error {
                    print("Scene classification error: \(error)")
                    continuation.resume(returning: self.defaultSceneClassification())
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: self.defaultSceneClassification())
                    return
                }
                
                let filteredResults = results.filter { $0.confidence >= Float(Configuration.sceneClassificationThreshold) }
                
                let primaryScene = self.interpretSceneResult(results: filteredResults)
                let secondaryScene = filteredResults.count > 1 ? self.interpretSceneResult(results: Array(filteredResults.dropFirst())) : nil
                
                let environment = self.determineEnvironment(from: filteredResults)
                let lighting = self.determineLighting(from: cgImage)
                
                let classification = SceneClassification(
                    primaryScene: primaryScene.type,
                    secondaryScene: secondaryScene?.type,
                    primaryConfidence: primaryScene.confidence,
                    secondaryConfidence: secondaryScene?.confidence,
                    environment: environment,
                    lighting: lighting
                )
                
                continuation.resume(returning: classification)
            }
            
            do {
                try handler.perform([request])
            } catch {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: self.defaultSceneClassification())
                }
            }
        }
    }
    
    /// Interpret Vision scene classification results
    private func interpretSceneResult(results: [VNClassificationObservation]) -> (type: SceneType, confidence: Double) {
        guard let topResult = results.first else {
            return (.unknown, 0.0)
        }
        
        let identifier = topResult.identifier.lowercased()
        let confidence = Double(topResult.confidence)
        
        // Map Vision results to our scene types
        let sceneType: SceneType
        switch identifier {
        case let id where id.contains("document") || id.contains("text") || id.contains("paper"):
            sceneType = .document
        case let id where id.contains("receipt") || id.contains("bill") || id.contains("invoice"):
            sceneType = .receipt
        case let id where id.contains("web") || id.contains("browser") || id.contains("website"):
            sceneType = .webpage
        case let id where id.contains("app") || id.contains("interface") || id.contains("ui"):
            sceneType = .application
        case let id where id.contains("photo") || id.contains("camera"):
            sceneType = .photo
        case let id where id.contains("screen") || id.contains("display"):
            sceneType = .screenshot
        case let id where id.contains("message") || id.contains("chat") || id.contains("text"):
            sceneType = .message
        case let id where id.contains("email") || id.contains("mail"):
            sceneType = .email
        case let id where id.contains("social") || id.contains("feed") || id.contains("post"):
            sceneType = .social
        case let id where id.contains("shop") || id.contains("store") || id.contains("cart"):
            sceneType = .shopping
        case let id where id.contains("map") || id.contains("navigation") || id.contains("location"):
            sceneType = .map
        case let id where id.contains("calendar") || id.contains("schedule") || id.contains("event"):
            sceneType = .calendar
        default:
            sceneType = .unknown
        }
        
        return (sceneType, confidence)
    }
    
    /// Determine environment type from classification results
    private func determineEnvironment(from results: [VNClassificationObservation]) -> EnvironmentType {
        for result in results {
            let identifier = result.identifier.lowercased()
            if identifier.contains("indoor") || identifier.contains("room") || identifier.contains("inside") {
                return .indoor
            } else if identifier.contains("outdoor") || identifier.contains("outside") || identifier.contains("landscape") {
                return .outdoor
            } else if identifier.contains("digital") || identifier.contains("screen") || identifier.contains("interface") {
                return .digital
            }
        }
        return .digital // Default for screenshots
    }
    
    /// Analyze lighting conditions from image
    private func determineLighting(from cgImage: CGImage) -> LightingConditions {
        // Simplified lighting analysis based on image brightness
        let brightness = calculateImageBrightness(cgImage: cgImage)
        
        switch brightness {
        case 0.0..<0.3:
            return .dim
        case 0.3..<0.7:
            return .normal
        case 0.7...1.0:
            return .bright
        default:
            return .unknown
        }
    }
    
    /// Default scene classification for error cases
    private func defaultSceneClassification() -> SceneClassification {
        return SceneClassification(
            primaryScene: .screenshot,
            primaryConfidence: 0.5,
            environment: .digital,
            lighting: .artificial
        )
    }
}

// MARK: - Composition Analysis

extension EnhancedVisionService {
    
    /// Analyze image composition and layout
    private func performCompositionAnalysis(cgImage: CGImage) async -> CompositionAnalysis {
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNDetectTextRectanglesRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true
                
                if let error = error {
                    print("Composition analysis error: \(error)")
                    // Fallback composition analysis without text detection
                    let fallbackComposition = CompositionAnalysis(
                        layout: .unknown,
                        textDensity: 0.0,
                        complexity: 0.5,
                        symmetry: 0.5,
                        balance: 0.5,
                        textRegions: []
                    )
                    continuation.resume(returning: fallbackComposition)
                    return
                }
                
                let textRegions = self.extractTextRegions(from: request.results)
                let textDensity = self.calculateTextDensity(textRegions: textRegions, imageSize: CGSize(width: cgImage.width, height: cgImage.height))
                
                let layout = self.determineLayoutType(textRegions: textRegions, textDensity: textDensity)
                let complexity = self.calculateComplexity(cgImage: cgImage, textRegions: textRegions)
                let symmetry = self.calculateSymmetry(cgImage: cgImage)
                let balance = self.calculateBalance(cgImage: cgImage, textRegions: textRegions)
                
                let composition = CompositionAnalysis(
                    layout: layout,
                    textDensity: textDensity,
                    complexity: complexity,
                    symmetry: symmetry,
                    balance: balance,
                    textRegions: textRegions
                )
                
                continuation.resume(returning: composition)
            }
            
            do {
                try handler.perform([request])
            } catch {
                if !hasResumed {
                    hasResumed = true
                    // Fallback composition analysis without text detection
                    let fallbackComposition = CompositionAnalysis(
                        layout: .unknown,
                        textDensity: 0.0,
                        complexity: 0.5,
                        symmetry: 0.5,
                        balance: 0.5,
                        textRegions: []
                    )
                    continuation.resume(returning: fallbackComposition)
                }
            }
        }
    }
    
    /// Extract text regions from Vision text detection results
    private func extractTextRegions(from results: [Any]?) -> [TextRegion] {
        guard let textResults = results as? [VNTextObservation] else {
            return []
        }
        
        return textResults.compactMap { observation in
            let boundingBox = BoundingBox(
                x: Double(observation.boundingBox.minX),
                y: Double(observation.boundingBox.minY),
                width: Double(observation.boundingBox.width),
                height: Double(observation.boundingBox.height)
            )
            let confidence = Double(observation.confidence)
            
            // Estimate text density based on character box count
            let estimatedDensity = min(1.0, Double(observation.characterBoxes?.count ?? 0) / 100.0)
            
            return TextRegion(
                boundingBox: boundingBox,
                confidence: confidence,
                textDensity: estimatedDensity,
                orientation: 0.0 // Could be enhanced with actual orientation detection
            )
        }
    }
    
    /// Calculate text density as percentage of image area
    private func calculateTextDensity(textRegions: [TextRegion], imageSize: CGSize) -> Double {
        guard !textRegions.isEmpty else { return 0.0 }
        
        let totalTextArea = textRegions.reduce(0.0) { sum, region in
            return sum + (region.boundingBox.width * region.boundingBox.height)
        }
        
        return min(1.0, totalTextArea)
    }
    
    /// Determine layout type based on text regions and patterns
    private func determineLayoutType(textRegions: [TextRegion], textDensity: Double) -> LayoutType {
        guard !textRegions.isEmpty else { return .freeform }
        
        // Analyze text region patterns
        let verticallyAligned = analyzeVerticalAlignment(textRegions: textRegions)
        let gridLike = analyzeGridPattern(textRegions: textRegions)
        
        if textDensity > 0.6 && verticallyAligned {
            return .structured
        } else if gridLike {
            return .grid
        } else if textDensity > 0.4 {
            return .list
        } else if textDensity > 0.1 {
            return .mixed
        } else {
            return .freeform
        }
    }
    
    /// Analyze vertical alignment of text regions
    private func analyzeVerticalAlignment(textRegions: [TextRegion]) -> Bool {
        guard textRegions.count >= 2 else { return false }
        
        let xPositions = textRegions.map { $0.boundingBox.x }
        let alignment = calculateAlignment(positions: xPositions)
        
        return alignment > 0.7
    }
    
    /// Analyze grid-like patterns in text regions
    private func analyzeGridPattern(textRegions: [TextRegion]) -> Bool {
        guard textRegions.count >= 4 else { return false }
        
        // Simplified grid detection based on regular spacing
        let xPositions = textRegions.map { $0.boundingBox.x }.sorted()
        let yPositions = textRegions.map { $0.boundingBox.y }.sorted()
        
        let xSpacing = calculateRegularSpacing(positions: xPositions)
        let ySpacing = calculateRegularSpacing(positions: yPositions)
        
        return xSpacing > 0.6 && ySpacing > 0.6
    }
    
    /// Calculate complexity score based on visual elements
    private func calculateComplexity(cgImage: CGImage, textRegions: [TextRegion]) -> Double {
        // Simplified complexity based on:
        // 1. Number of text regions
        // 2. Color variance
        // 3. Edge density
        
        let textComplexity = min(1.0, Double(textRegions.count) / 20.0)
        let colorComplexity = calculateColorVariance(cgImage: cgImage)
        
        return (textComplexity + colorComplexity) / 2.0
    }
    
    /// Calculate symmetry score
    private func calculateSymmetry(cgImage: CGImage) -> Double {
        // Simplified symmetry calculation
        // In a full implementation, this would analyze pixel patterns
        return 0.5 // Placeholder
    }
    
    /// Calculate visual balance score
    private func calculateBalance(cgImage: CGImage, textRegions: [TextRegion]) -> Double {
        // Simplified balance calculation based on text region distribution
        guard !textRegions.isEmpty else { return 0.5 }
        
        let leftRegions = textRegions.filter { $0.boundingBox.x < 0.5 }
        let rightRegions = textRegions.filter { $0.boundingBox.x >= 0.5 }
        
        let balance = 1.0 - abs(Double(leftRegions.count - rightRegions.count)) / Double(textRegions.count)
        return max(0.0, min(1.0, balance))
    }
    
    /// Helper methods for alignment and spacing calculations
    private func calculateAlignment(positions: [Double]) -> Double {
        guard positions.count >= 2 else { return 0.0 }
        
        let sortedPositions = positions.sorted()
        let variance = calculateVariance(values: sortedPositions)
        
        // Lower variance means better alignment
        return max(0.0, 1.0 - variance * 10.0)
    }
    
    private func calculateRegularSpacing(positions: [Double]) -> Double {
        guard positions.count >= 3 else { return 0.0 }
        
        let sortedPositions = positions.sorted()
        var spacings: [Double] = []
        
        for i in 1..<sortedPositions.count {
            spacings.append(sortedPositions[i] - sortedPositions[i-1])
        }
        
        let spacingVariance = calculateVariance(values: spacings)
        
        // Lower variance means more regular spacing
        return max(0.0, 1.0 - spacingVariance * 5.0)
    }
    
    private func calculateVariance(values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        
        let mean = values.reduce(0.0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        
        return squaredDifferences.reduce(0.0, +) / Double(values.count)
    }
    
    /// Calculate color variance for complexity analysis
    private func calculateColorVariance(cgImage: CGImage) -> Double {
        // Simplified color variance calculation
        return 0.5 // Placeholder
    }
    
    /// Calculate image brightness
    private func calculateImageBrightness(cgImage: CGImage) -> Double {
        // Simplified brightness calculation
        // In practice, would analyze actual pixel values
        return 0.5 // Placeholder
    }
}

// MARK: - Color Analysis

extension EnhancedVisionService {
    
    /// Perform comprehensive color analysis using ColorAnalysisService
    private func performColorAnalysis(cgImage: CGImage) async -> ColorAnalysis {
        // Convert CGImage to Data for the ColorAnalysisService
        guard let data = convertCGImageToData(cgImage) else {
            return createFallbackColorAnalysis()
        }
        
        // Use the ColorAnalysisService for comprehensive analysis
        let result = await colorAnalysisService.analyzeImage(data)
        
        // Convert the result to the expected ColorAnalysis format
        return convertToColorAnalysis(result)
    }
    
    /// Convert CGImage to Data for processing
    private func convertCGImageToData(_ cgImage: CGImage) -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
    
    /// Convert ColorAnalysisService result to VisualAttributes ColorAnalysis
    private func convertToColorAnalysis(_ result: ColorAnalysisService.ColorAnalysisResult) -> ColorAnalysis {
        // Convert dominant colors
        let dominantColors = result.dominantColors.map { colorInfo in
            DominantColor(
                red: colorInfo.red,
                green: colorInfo.green,
                blue: colorInfo.blue,
                prominence: colorInfo.prominence,
                colorName: colorInfo.colorName,
                hexValue: colorInfo.hexValue
            )
        }
        
        // Map color scheme
        let colorScheme = mapColorScheme(result.colorScheme)
        
        // Map temperature
        let temperature = mapTemperature(result.temperature)
        
        return ColorAnalysis(
            dominantColors: dominantColors,
            brightness: result.brightness,
            contrast: result.contrast,
            saturation: result.saturation,
            temperature: temperature,
            colorScheme: colorScheme,
            visualEmbedding: result.visualEmbedding.map { Float($0) }
        )
    }
    
    /// Map AdvancedColorScheme to VisualColorScheme
    private func mapColorScheme(_ scheme: ColorAnalysisService.AdvancedColorScheme) -> VisualColorScheme {
        switch scheme {
        case .monochromatic: return .monochromatic
        case .analogous: return .analogous
        case .complementary: return .complementary
        case .triadic: return .triadic
        case .tetradic: return .tetradic
        case .vibrant: return .vibrant
        case .muted: return .muted
        case .highContrast, .lowContrast, .natural, .artificial: return .unknown
        }
    }
    
    /// Map AdvancedColorTemperature to ColorTemperature
    private func mapTemperature(_ temp: ColorAnalysisService.AdvancedColorTemperature) -> ColorTemperature {
        switch temp {
        case .veryWarm, .warm: return .warm
        case .cool, .veryCool: return .cool
        case .neutral: return .neutral
        case .mixed: return .mixed
        }
    }
    
    /// Create fallback color analysis when processing fails
    private func createFallbackColorAnalysis() -> ColorAnalysis {
        return ColorAnalysis(
            dominantColors: [],
            brightness: 0.5,
            contrast: 0.5,
            saturation: 0.5,
            temperature: .neutral,
            colorScheme: .unknown,
            visualEmbedding: []
        )
    }
    
}

// MARK: - Helper Methods

extension EnhancedVisionService {
    
    /// Setup Vision framework requests with optimal configuration
    private func setupVisionRequests() {
        // Configure requests for optimal performance
        sceneClassificationRequest.preferBackgroundProcessing = false
        saliencyRequest.preferBackgroundProcessing = false
    }
    
    /// Load optional Core ML models if available
    private func loadOptionalModels() {
        // Attempt to load any available Core ML models for enhanced detection
        // This is optional and will fall back to built-in Vision models
    }
    
    /// Generate cache key for image data
    private func generateCacheKey(for imageData: Data) -> String {
        // Use a hash of the image data for caching
        return String(imageData.hashValue)
    }
    
    /// Calculate overall confidence score from multiple analysis results
    private func calculateOverallConfidence(
        objectConfidence: Double,
        sceneConfidence: Double,
        compositionConfidence: Double,
        colorConfidence: Double
    ) -> Double {
        // Weighted average of confidence scores
        let weights = [0.3, 0.3, 0.2, 0.2] // Object, Scene, Composition, Color
        let confidences = [objectConfidence, sceneConfidence, compositionConfidence, colorConfidence]
        
        let weightedSum = zip(weights, confidences).reduce(0.0) { sum, pair in
            return sum + (pair.0 * pair.1)
        }
        
        return min(1.0, max(0.0, weightedSum))
    }
    
    /// Clear analysis cache to free memory
    public func clearCache() {
        analysisCache.removeAll()
    }
    
    /// Get cache statistics
    public func getCacheStats() -> (size: Int, maxSize: Int) {
        return (analysisCache.count, Configuration.cacheSize)
    }
}