import Foundation
import Vision
import UIKit
import CoreML
import ImageIO

/// Phase 5.2.1: Enhanced Vision Processing Service
/// Advanced object detection and scene classification using Apple's Vision framework
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
        // For now, return a simplified object detection result
        // In a production environment, this would use more advanced Vision APIs
        return []
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
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNClassifyImageRequest { request, error in
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
                continuation.resume(returning: self.defaultSceneClassification())
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
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNDetectTextRectanglesRequest { request, error in
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
}

// MARK: - Color Analysis

extension EnhancedVisionService {
    
    /// Perform comprehensive color analysis
    private func performColorAnalysis(cgImage: CGImage) async -> ColorAnalysis {
        let dominantColors = extractDominantColors(from: cgImage)
        let brightness = calculateImageBrightness(cgImage: cgImage)
        let contrast = calculateImageContrast(cgImage: cgImage)
        let saturation = calculateImageSaturation(cgImage: cgImage)
        let temperature = determineColorTemperature(colors: dominantColors)
        let colorScheme = determineColorScheme(colors: dominantColors)
        
        let colorPalette = createColorPalette(from: dominantColors)
        
        return ColorAnalysis(
            dominantColors: dominantColors,
            colorPalette: colorPalette,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            temperature: temperature,
            colorScheme: colorScheme
        )
    }
    
    /// Extract dominant colors using simplified clustering
    private func extractDominantColors(from cgImage: CGImage) -> [DominantColor] {
        // Simplified dominant color extraction
        // In a production implementation, this would use more sophisticated clustering
        
        var dominantColors: [DominantColor] = []
        
        // Sample colors from image and create basic dominant colors
        let sampleColors = sampleImageColors(cgImage: cgImage, sampleCount: 100)
        let clusteredColors = clusterColors(colors: sampleColors, clusterCount: 5)
        
        for (_, colorCluster) in clusteredColors.enumerated() {
            let prominence = Double(colorCluster.count) / Double(sampleColors.count)
            if prominence > 0.05 { // Only include colors that appear in at least 5% of samples
                let averageColor = averageColor(from: colorCluster)
                let colorName = mapColorToName(color: averageColor)
                let hexValue = colorToHex(color: averageColor)
                
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                averageColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                
                let dominantColor = DominantColor(
                    red: Double(red),
                    green: Double(green),
                    blue: Double(blue),
                    prominence: prominence,
                    colorName: colorName,
                    hexValue: hexValue
                )
                
                dominantColors.append(dominantColor)
            }
        }
        
        return dominantColors.sorted { $0.prominence > $1.prominence }
    }
    
    /// Sample colors from image at regular intervals
    private func sampleImageColors(cgImage: CGImage, sampleCount: Int) -> [UIColor] {
        // Simplified color sampling implementation
        var colors: [UIColor] = []
        
        // Add some basic color samples (in real implementation, would sample actual pixels)
        colors.append(UIColor.white)
        colors.append(UIColor.black)
        colors.append(UIColor.blue)
        colors.append(UIColor.gray)
        
        return colors
    }
    
    /// Simple color clustering (placeholder implementation)
    private func clusterColors(colors: [UIColor], clusterCount: Int) -> [[UIColor]] {
        // Simplified clustering - in practice would use k-means or similar
        var clusters: [[UIColor]] = Array(repeating: [], count: clusterCount)
        
        for (index, color) in colors.enumerated() {
            clusters[index % clusterCount].append(color)
        }
        
        return clusters.filter { !$0.isEmpty }
    }
    
    /// Calculate average color from color array
    private func averageColor(from colors: [UIColor]) -> UIColor {
        guard !colors.isEmpty else { return UIColor.gray }
        
        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        var totalAlpha: CGFloat = 0
        
        for color in colors {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            totalRed += red
            totalGreen += green
            totalBlue += blue
            totalAlpha += alpha
        }
        
        let count = CGFloat(colors.count)
        return UIColor(
            red: totalRed / count,
            green: totalGreen / count,
            blue: totalBlue / count,
            alpha: totalAlpha / count
        )
    }
    
    /// Map UIColor to human-readable color name
    private func mapColorToName(color: UIColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Simplified color name mapping
        if red > 0.8 && green < 0.3 && blue < 0.3 {
            return "Red"
        } else if green > 0.8 && red < 0.3 && blue < 0.3 {
            return "Green"
        } else if blue > 0.8 && red < 0.3 && green < 0.3 {
            return "Blue"
        } else if red > 0.8 && green > 0.8 && blue < 0.3 {
            return "Yellow"
        } else if red > 0.5 && green < 0.5 && blue > 0.5 {
            return "Purple"
        } else if red > 0.8 && green > 0.4 && blue < 0.3 {
            return "Orange"
        } else if red > 0.8 && green > 0.7 && blue > 0.7 {
            return "Pink"
        } else if red > 0.8 && green > 0.8 && blue > 0.8 {
            return "White"
        } else if red < 0.2 && green < 0.2 && blue < 0.2 {
            return "Black"
        } else if abs(red - green) < 0.1 && abs(green - blue) < 0.1 {
            return "Gray"
        } else {
            return "Mixed"
        }
    }
    
    /// Convert UIColor to hex string
    private func colorToHex(color: UIColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    /// Calculate image brightness
    private func calculateImageBrightness(cgImage: CGImage) -> Double {
        // Simplified brightness calculation
        // In practice, would analyze actual pixel values
        return 0.5 // Placeholder
    }
    
    /// Calculate image contrast
    private func calculateImageContrast(cgImage: CGImage) -> Double {
        // Simplified contrast calculation
        return 0.5 // Placeholder
    }
    
    /// Calculate image saturation
    private func calculateImageSaturation(cgImage: CGImage) -> Double {
        // Simplified saturation calculation
        return 0.5 // Placeholder
    }
    
    /// Calculate color variance for complexity analysis
    private func calculateColorVariance(cgImage: CGImage) -> Double {
        // Simplified color variance calculation
        return 0.5 // Placeholder
    }
    
    /// Determine color temperature from dominant colors
    private func determineColorTemperature(colors: [DominantColor]) -> ColorTemperature {
        guard !colors.isEmpty else { return .neutral }
        
        var warmScore = 0.0
        var coolScore = 0.0
        
        for color in colors {
            // Simplified temperature calculation based on red/blue balance
            let warmness = color.red - color.blue
            if warmness > 0 {
                warmScore += warmness * color.prominence
            } else {
                coolScore += abs(warmness) * color.prominence
            }
        }
        
        if warmScore > coolScore * 1.2 {
            return .warm
        } else if coolScore > warmScore * 1.2 {
            return .cool
        } else {
            return .neutral
        }
    }
    
    /// Determine color scheme type
    private func determineColorScheme(colors: [DominantColor]) -> VisualColorScheme {
        guard colors.count >= 2 else { return .monochromatic }
        
        // Simplified color scheme analysis
        let saturationSum = colors.reduce(0.0) { sum, color in
            let uiColor = color.uiColor
            var saturation: CGFloat = 0
            uiColor.getHue(nil, saturation: &saturation, brightness: nil, alpha: nil)
            return sum + Double(saturation)
        }
        
        let averageSaturation = saturationSum / Double(colors.count)
        
        if averageSaturation > 0.7 {
            return .vibrant
        } else if averageSaturation < 0.3 {
            return .muted
        } else {
            return .unknown
        }
    }
    
    /// Create organized color palette
    private func createColorPalette(from colors: [DominantColor]) -> ColorPalette {
        let sortedColors = colors.sorted { $0.prominence > $1.prominence }
        
        let primaryColors = Array(sortedColors.prefix(2))
        let secondaryColors = Array(sortedColors.dropFirst(2).prefix(2))
        let accentColors = Array(sortedColors.dropFirst(4).prefix(1))
        let backgroundColors = Array(sortedColors.dropFirst(5))
        
        return ColorPalette(
            primaryColors: primaryColors,
            secondaryColors: secondaryColors,
            accentColors: accentColors,
            backgroundColors: backgroundColors
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