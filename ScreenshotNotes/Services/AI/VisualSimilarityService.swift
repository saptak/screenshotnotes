import Foundation
import Vision
import VisionKit
import CoreImage
import UIKit
import CoreML
import NaturalLanguage

/// Advanced Visual Similarity Service with VisionKit integration
/// Sprint 7.1.1: Production-ready visual similarity detection for layout, colors, and composition
@MainActor
final class VisualSimilarityService: ObservableObject {
    
    // MARK: - Singleton
    @MainActor static let shared = VisualSimilarityService()
    
    // MARK: - Configuration
    private let performanceTarget: TimeInterval = 0.2 // 200ms for visual processing
    private let featureCountThreshold = 10 // Minimum features for reliable comparison
    
    // MARK: - State
    @Published var isProcessing = false
    @Published var lastProcessingTime: TimeInterval = 0.0
    @Published var processingProgress: Double = 0.0
    
    // MARK: - Vision Requests
    private lazy var featureExtractorRequest: VNGenerateImageFeaturePrintRequest = {
        return VNGenerateImageFeaturePrintRequest()
    }()
    
    // No longer store as property, use inline @available(iOS 17, *) where needed
    
    private lazy var textDetectionRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        return request
    }()
    
    private lazy var imageClassificationRequest: VNClassifyImageRequest = {
    let request = VNClassifyImageRequest()
    // VNClassifyImageRequest does not have maximumObservations property, so remove it
    return request
    }()
    
    private init() {
        setupVisionRequests()
    }
    
    // MARK: - Public Interface
    
    /// Calculates comprehensive visual similarity between two images
    /// - Parameters:
    ///   - sourceImage: Source image for comparison
    ///   - targetImage: Target image for comparison
    /// - Returns: Visual similarity components including color, layout, and composition
    func calculateVisualSimilarity(
        sourceImage: UIImage?,
        targetImage: UIImage?
    ) async -> VisualSimilarityComponents {
        let startTime = CFAbsoluteTimeGetCurrent()
        isProcessing = true
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            lastProcessingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        }
        
        guard let sourceImage = sourceImage,
              let targetImage = targetImage,
              let sourceCGImage = sourceImage.cgImage,
              let targetCGImage = targetImage.cgImage else {
            return VisualSimilarityComponents(color: 0.0, layout: 0.0, composition: 0.0)
        }
        
        // Extract visual features from both images
        processingProgress = 0.1
        let sourceFeatures = await extractVisualFeatures(from: sourceCGImage)
        
        processingProgress = 0.5
        let targetFeatures = await extractVisualFeatures(from: targetCGImage)
        
        processingProgress = 0.8
        
        // Calculate similarity components
        let colorSimilarity = calculateColorSimilarity(
            source: sourceFeatures,
            target: targetFeatures
        )
        
        let layoutSimilarity = await calculateLayoutSimilarity(
            sourceImage: sourceCGImage,
            targetImage: targetCGImage
        )
        
        let compositionSimilarity = await calculateCompositionSimilarity(
            source: sourceFeatures,
            target: targetFeatures
        )
        
        processingProgress = 1.0
        
        return VisualSimilarityComponents(
            color: colorSimilarity,
            layout: layoutSimilarity,
            composition: compositionSimilarity
        )
    }
    
    /// Analyzes image layout structure for similarity comparison
    /// - Parameter image: Image to analyze
    /// - Returns: Layout analysis data
    func analyzeImageLayout(_ image: UIImage) async -> ImageLayoutAnalysis? {
        guard let cgImage = image.cgImage else { return nil }
        
        let textRegions = await detectTextRegions(in: cgImage)
        let objectRegions = await detectObjectRegions(in: cgImage)
        let visualFeatures = await extractVisualFeatures(from: cgImage)
        
        return ImageLayoutAnalysis(
            textRegions: textRegions,
            objectRegions: objectRegions,
            dominantColors: visualFeatures.dominantColors,
            visualComplexity: calculateVisualComplexity(
                textRegions: textRegions,
                objectRegions: objectRegions
            ),
            aspectRatio: Double(cgImage.width) / Double(cgImage.height)
        )
    }
    
    /// Extracts color palette from image for thematic analysis
    /// - Parameter image: Image to analyze
    /// - Returns: Color palette with dominant colors
    func extractColorPalette(_ image: UIImage) async -> ColorPalette? {
        guard let cgImage = image.cgImage else { return nil }
        // This function should return the ColorPalette from Models/ColorPalette.swift
        // You need to map your color analysis to ColorInfo and ColorPalette
        let colorAnalysis = await analyzeImageColors(cgImage)
        // Fallback: use first three dominant colors or averageColor if not enough
        let domColors = colorAnalysis.dominantColors
        func colorInfo(from color: UIColor) -> ColorInfo {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return ColorInfo(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
        }
        let primary = domColors.indices.contains(0) ? colorInfo(from: domColors[0]) : colorInfo(from: colorAnalysis.averageColor)
        let secondary = domColors.indices.contains(1) ? colorInfo(from: domColors[1]) : colorInfo(from: colorAnalysis.averageColor)
        let accent = domColors.indices.contains(2) ? colorInfo(from: domColors[2]) : colorInfo(from: colorAnalysis.averageColor)
        return ColorPalette(primaryColor: primary, secondaryColor: secondary, accentColor: accent)
    }
}

// MARK: - Visual Feature Extraction

private extension VisualSimilarityService {
    
    /// Extracts comprehensive visual features from an image
    func extractVisualFeatures(from cgImage: CGImage) async -> VisualFeatures {
        let colorAnalysis = await analyzeImageColors(cgImage)
        let textureAnalysis = await analyzeImageTexture(cgImage)
        let featurePoints = await extractFeaturePoints(cgImage)
        let classification = await classifyImageContent(cgImage)
        
        return VisualFeatures(
            dominantColors: colorAnalysis.dominantColors,
            averageColor: colorAnalysis.averageColor,
            colorVariance: colorAnalysis.colorVariance,
            textureComplexity: textureAnalysis.complexity,
            edgeDensity: textureAnalysis.edgeDensity,
            featurePoints: featurePoints,
            contentClassification: classification,
            aspectRatio: Double(cgImage.width) / Double(cgImage.height)
        )
    }
    
    /// Analyzes color composition of an image
    func analyzeImageColors(_ cgImage: CGImage) async -> VisualColorAnalysis {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Use a nonisolated helper to avoid main actor isolation error
                let colorAnalysis = VisualSimilarityService.performColorAnalysisStatic(cgImage)
                continuation.resume(returning: colorAnalysis)
            }
        }
    }
    
    /// Performs detailed color analysis
    nonisolated static func performColorAnalysisStatic(_ cgImage: CGImage) -> VisualColorAnalysis {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return VisualColorAnalysis(dominantColors: [],
                                       averageColor: UIColor.clear,
                                       colorVariance: 0.0,
                                       colorDistribution: [:])
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        
        var colorCounts: [String: Int] = [:]
        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        var pixelCount = 0
        
        // Sample every 10th pixel for performance
        let sampleRate = 10
        
        for y in stride(from: 0, to: height, by: sampleRate) {
            for x in stride(from: 0, to: width, by: sampleRate) {
                let pixelOffset = y * bytesPerRow + x * bytesPerPixel
                
                guard pixelOffset + 3 < CFDataGetLength(data) else { continue }
                
                let red = CGFloat(bytes[pixelOffset + 2]) / 255.0
                let green = CGFloat(bytes[pixelOffset + 1]) / 255.0
                let blue = CGFloat(bytes[pixelOffset]) / 255.0
                
                totalRed += red
                totalGreen += green
                totalBlue += blue
                pixelCount += 1
                
                // Quantize colors for counting
                let quantizedColor = quantizeColor(red: red, green: green, blue: blue)
                colorCounts[quantizedColor, default: 0] += 1
            }
        }
        
        // Calculate average color
        let averageRed = pixelCount > 0 ? totalRed / CGFloat(pixelCount) : 0
        let averageGreen = pixelCount > 0 ? totalGreen / CGFloat(pixelCount) : 0
        let averageBlue = pixelCount > 0 ? totalBlue / CGFloat(pixelCount) : 0
        let averageColor = UIColor(red: averageRed, green: averageGreen, blue: averageBlue, alpha: 1.0)
        
        // Find dominant colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        let dominantColors = Array(sortedColors.prefix(5)).compactMap { entry in
            parseQuantizedColor(entry.key)
        }
        
        // Calculate color variance
        let colorVariance = calculateColorVariance(
            colors: colorCounts.keys.compactMap(parseQuantizedColor),
            average: averageColor
        )
        
        // Create color distribution
        let totalPixels = colorCounts.values.reduce(0, +)
        let colorDistribution = colorCounts.mapValues { Double($0) / Double(totalPixels) }
        
        return VisualColorAnalysis(
            dominantColors: dominantColors,
            averageColor: averageColor,
            colorVariance: colorVariance,
            colorDistribution: colorDistribution
        )
    }
    
    /// Analyzes texture and edge information
    func analyzeImageTexture(_ cgImage: CGImage) async -> TextureAnalysis {
        return await withCheckedContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest()
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
                
                if let observation = request.results?.first {
                    let complexity = calculateTextureComplexity(from: observation)
                    let edgeDensity = calculateEdgeDensity(cgImage)
                    
                    continuation.resume(returning: TextureAnalysis(
                        complexity: complexity,
                        edgeDensity: edgeDensity
                    ))
                } else {
                    continuation.resume(returning: TextureAnalysis(complexity: 0.0, edgeDensity: 0.0))
                }
            } catch {
                continuation.resume(returning: TextureAnalysis(complexity: 0.0, edgeDensity: 0.0))
            }
        }
    }
    
    /// Extracts feature points using Vision framework
    func extractFeaturePoints(_ cgImage: CGImage) async -> [CGPoint] {
        return await withCheckedContinuation { continuation in
            let request = VNDetectContoursRequest()
            request.maximumImageDimension = 512 // Optimize for performance
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                let points = request.results?.flatMap { observation in
                    observation.normalizedPath.points()
                } ?? []
                continuation.resume(returning: Array(points.prefix(100))) // Limit for performance
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    /// Classifies image content using Vision framework
    func classifyImageContent(_ cgImage: CGImage) async -> [String] {
        return await withCheckedContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([imageClassificationRequest])
                
                let classifications = imageClassificationRequest.results?.prefix(5).compactMap { observation in
                    observation.confidence > 0.3 ? observation.identifier : nil
                } ?? []
                
                continuation.resume(returning: Array(classifications))
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}

// MARK: - Similarity Calculations

private extension VisualSimilarityService {
    
    /// Calculates color similarity between two sets of visual features
    func calculateColorSimilarity(source: VisualFeatures, target: VisualFeatures) -> Double {
        // Compare dominant colors
        let dominantColorSimilarity = calculateDominantColorSimilarity(
            colors1: source.dominantColors,
            colors2: target.dominantColors
        )
        
        // Compare average colors
        let averageColorSimilarity = calculateAverageColorSimilarity(
            color1: source.averageColor,
            color2: target.averageColor
        )
        
        // Compare color variance
        let varianceSimilarity = calculateVarianceSimilarity(
            variance1: source.colorVariance,
            variance2: target.colorVariance
        )
        
        // Weighted combination
        return (dominantColorSimilarity * 0.5 + averageColorSimilarity * 0.3 + varianceSimilarity * 0.2)
    }
    
    /// Calculates layout similarity using text and object detection
    func calculateLayoutSimilarity(sourceImage: CGImage, targetImage: CGImage) async -> Double {
        let sourceLayout = await analyzeLayoutStructure(sourceImage)
        let targetLayout = await analyzeLayoutStructure(targetImage)
        
        // Compare text region distributions
        let textSimilarity = calculateRegionSimilarity(
            regions1: sourceLayout.textRegions,
            regions2: targetLayout.textRegions
        )
        
        // Compare object region distributions
        let objectSimilarity = calculateRegionSimilarity(
            regions1: sourceLayout.objectRegions,
            regions2: targetLayout.objectRegions
        )
        
        // Compare overall layout complexity
        let complexitySimilarity = calculateComplexitySimilarity(
            complexity1: sourceLayout.complexity,
            complexity2: targetLayout.complexity
        )
        
        return (textSimilarity * 0.4 + objectSimilarity * 0.4 + complexitySimilarity * 0.2)
    }
    
    /// Calculates composition similarity using feature points and classification
    func calculateCompositionSimilarity(source: VisualFeatures, target: VisualFeatures) async -> Double {
        // Compare content classifications
        let classificationSimilarity = calculateClassificationSimilarity(
            classifications1: source.contentClassification,
            classifications2: target.contentClassification
        )
        
        // Compare texture complexity
        let textureSimilarity = calculateTextureSimilarity(
            complexity1: source.textureComplexity,
            complexity2: target.textureComplexity,
            edgeDensity1: source.edgeDensity,
            edgeDensity2: target.edgeDensity
        )
        
        // Compare aspect ratios
        let aspectRatioSimilarity = calculateAspectRatioSimilarity(
            ratio1: source.aspectRatio,
            ratio2: target.aspectRatio
        )
        
        return (classificationSimilarity * 0.5 + textureSimilarity * 0.3 + aspectRatioSimilarity * 0.2)
    }
    
    /// Analyzes layout structure of an image
    func analyzeLayoutStructure(_ cgImage: CGImage) async -> LayoutStructure {
        let textRegions = await detectTextRegions(in: cgImage)
        let objectRegions = await detectObjectRegions(in: cgImage)
        
        let complexity = calculateLayoutComplexity(
            textRegions: textRegions,
            objectRegions: objectRegions,
            imageSize: CGSize(width: cgImage.width, height: cgImage.height)
        )
        
        return LayoutStructure(
            textRegions: textRegions,
            objectRegions: objectRegions,
            complexity: complexity
        )
    }
    
    /// Detects text regions in an image
    func detectTextRegions(in cgImage: CGImage) async -> [CGRect] {
        return await withCheckedContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([textDetectionRequest])
                
                let regions = textDetectionRequest.results?.compactMap { observation in
                    observation.boundingBox
                } ?? []
                
                continuation.resume(returning: regions.map { $0 })
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    /// Detects object regions in an image
    func detectObjectRegions(in cgImage: CGImage) async -> [CGRect] {
        return await withCheckedContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            if #available(iOS 17, *) {
                if let VNRecognizeObjectsRequestType = NSClassFromString("VNRecognizeObjectsRequest") as? NSObject.Type {
                    let request = VNRecognizeObjectsRequestType.init() as! VNRequest
                    (request as NSObject).setValue(20, forKey: "maximumObservations")
                    do {
                        try handler.perform([request])
                        let results = request.value(forKey: "results") as? [Any]
                        // Directly cast boundingBox property to CGRect (no need for conditional cast)
                        let regions = results?.compactMap { ($0 as AnyObject).boundingBox } ?? []
                        continuation.resume(returning: regions)
                    } catch {
                        continuation.resume(returning: [])
                    }
                } else {
                    continuation.resume(returning: [])
                }
            } else {
                // Fallback for iOS < 17: object detection not supported
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("ObjectDetectionUnavailable"), object: nil)
                }
                continuation.resume(returning: [])
            }
        }
    }
}

// MARK: - Helper Methods

private extension VisualSimilarityService {
    
    /// Sets up Vision framework requests
    func setupVisionRequests() {
        // Additional setup if needed
    }
    
    /// Quantizes a color for counting purposes
    nonisolated static func quantizeColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        let quantizedRed = Int(red * 10) * 10
        let quantizedGreen = Int(green * 10) * 10
        let quantizedBlue = Int(blue * 10) * 10
        return "\(quantizedRed),\(quantizedGreen),\(quantizedBlue)"
    }
    
    /// Parses a quantized color string back to UIColor
    nonisolated static func parseQuantizedColor(_ quantized: String) -> UIColor? {
        let components = quantized.split(separator: ",").compactMap { Int($0) }
        guard components.count == 3 else { return nil }
        return UIColor(
            red: CGFloat(components[0]) / 255.0,
            green: CGFloat(components[1]) / 255.0,
            blue: CGFloat(components[2]) / 255.0,
            alpha: 1.0
        )
    }
    
    /// Calculates color variance
    nonisolated static func calculateColorVariance(colors: [UIColor], average: UIColor) -> Double {
        guard !colors.isEmpty else { return 0.0 }
        var avgRed: CGFloat = 0, avgGreen: CGFloat = 0, avgBlue: CGFloat = 0, avgAlpha: CGFloat = 0
        average.getRed(&avgRed, green: &avgGreen, blue: &avgBlue, alpha: &avgAlpha)
        let variance = colors.reduce(0.0) { total, color in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let redDiff = red - avgRed
            let greenDiff = green - avgGreen
            let blueDiff = blue - avgBlue
            return total + Double(redDiff * redDiff + greenDiff * greenDiff + blueDiff * blueDiff)
        }
        return variance / Double(colors.count)
    }
    
    /// Calculates texture complexity from feature print
    func calculateTextureComplexity(from observation: VNFeaturePrintObservation) -> Double {
        // Use the feature print data to estimate texture complexity
        let data = observation.data
        let variance = data.withUnsafeBytes { bytes in
            let floats = bytes.bindMemory(to: Float.self)
            let sum = floats.reduce(0, +)
            let mean = sum / Float(floats.count)
            
            return floats.reduce(0) { $0 + pow($1 - mean, 2) } / Float(floats.count)
        }
        
        return min(Double(variance) / 100.0, 1.0) // Normalize to 0-1
    }
    
    /// Calculates edge density in an image using Sobel edge detection
    func calculateEdgeDensity(_ cgImage: CGImage) -> Double {
        let width = cgImage.width
        let height = cgImage.height
        
        guard width > 2 && height > 2,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return 0.0 }
        
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        var edgeCount = 0
        let threshold: Int = 50
        
        // Sample every 5th pixel for performance
        for y in stride(from: 1, to: height - 1, by: 5) {
            for x in stride(from: 1, to: width - 1, by: 5) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                
                guard offset + bytesPerPixel < CFDataGetLength(data) else { continue }
                
                // Get grayscale value (using green channel for simplicity)
                let center = Int(bytes[offset + 1])
                let left = Int(bytes[offset - bytesPerPixel + 1])
                let right = Int(bytes[offset + bytesPerPixel + 1])
                let top = Int(bytes[(y - 1) * bytesPerRow + x * bytesPerPixel + 1])
                let bottom = Int(bytes[(y + 1) * bytesPerRow + x * bytesPerPixel + 1])
                
                // Sobel X and Y gradients
                let gx = abs((right - left) + 2 * (right - left))
                let gy = abs((bottom - top) + 2 * (bottom - top))
                
                let magnitude = Int(sqrt(Double(gx * gx + gy * gy)))
                
                if magnitude > threshold {
                    edgeCount += 1
                }
            }
        }
        
        let totalSamples = ((width - 2) / 5) * ((height - 2) / 5)
        return totalSamples > 0 ? Double(edgeCount) / Double(totalSamples) : 0.0
    }
    
    /// Calculates visual complexity based on regions
    func calculateVisualComplexity(textRegions: [CGRect], objectRegions: [CGRect]) -> Double {
        let totalRegions = textRegions.count + objectRegions.count
        
        // Normalize complexity based on region count and distribution
        let complexityScore = min(Double(totalRegions) / 20.0, 1.0)
        
        // Factor in region overlap and distribution
        let overlapPenalty = calculateRegionOverlap(textRegions + objectRegions)
        
        return max(complexityScore - overlapPenalty, 0.0)
    }
    
    /// Calculates overlap between regions
    func calculateRegionOverlap(_ regions: [CGRect]) -> Double {
        guard regions.count > 1 else { return 0.0 }
        
        var overlapCount = 0
        for i in 0..<regions.count {
            for j in (i + 1)..<regions.count {
                if regions[i].intersects(regions[j]) {
                    overlapCount += 1
                }
            }
        }
        
        return Double(overlapCount) / Double(regions.count)
    }
    
    /// Additional similarity calculation methods
    func calculateDominantColorSimilarity(colors1: [UIColor], colors2: [UIColor]) -> Double {
        guard !colors1.isEmpty && !colors2.isEmpty else { return 0.0 }
        
        // Convert to LAB color space for perceptual similarity
        let lab1 = colors1.compactMap { convertToLAB($0) }
        let lab2 = colors2.compactMap { convertToLAB($0) }
        
        guard !lab1.isEmpty && !lab2.isEmpty else { return 0.0 }
        
        // Calculate average color distance
        var totalDistance = 0.0
        var comparisons = 0
        
        for color1 in lab1 {
            for color2 in lab2 {
                let distance = calculateLABDistance(color1, color2)
                totalDistance += distance
                comparisons += 1
            }
        }
        
        let averageDistance = totalDistance / Double(comparisons)
        // Convert distance to similarity (0-1 scale)
        return max(0.0, 1.0 - (averageDistance / 100.0))
    }
    
    func calculateAverageColorSimilarity(color1: UIColor, color2: UIColor) -> Double {
        let lab1 = convertToLAB(color1)
        let lab2 = convertToLAB(color2)
        
        guard let lab1 = lab1, let lab2 = lab2 else { return 0.0 }
        
        let distance = calculateLABDistance(lab1, lab2)
        return max(0.0, 1.0 - (distance / 100.0))
    }
    
    func calculateVarianceSimilarity(variance1: Double, variance2: Double) -> Double {
        // Implementation for variance similarity
        return 1.0 - abs(variance1 - variance2)
    }
    
    func calculateRegionSimilarity(regions1: [CGRect], regions2: [CGRect]) -> Double {
        guard !regions1.isEmpty && !regions2.isEmpty else { return 0.0 }
        
        // Calculate spatial distribution similarity
        
        // Calculate density similarity
        let density1 = Double(regions1.count) / calculateTotalArea(regions1)
        let density2 = Double(regions2.count) / calculateTotalArea(regions2)
        
        let densitySimilarity = 1.0 - min(abs(density1 - density2) / max(density1, density2), 1.0)
        
        // Calculate position similarity using intersection over union
        let overlapScore = calculateRegionOverlapScore(regions1, regions2)
        
        return (densitySimilarity * 0.6 + overlapScore * 0.4)
    }
    
    func calculateComplexitySimilarity(complexity1: Double, complexity2: Double) -> Double {
        return 1.0 - abs(complexity1 - complexity2)
    }
    
    func calculateClassificationSimilarity(classifications1: [String], classifications2: [String]) -> Double {
        let set1 = Set(classifications1)
        let set2 = Set(classifications2)
        
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    func calculateTextureSimilarity(
        complexity1: Double,
        complexity2: Double,
        edgeDensity1: Double,
        edgeDensity2: Double
    ) -> Double {
        let complexitySim = 1.0 - abs(complexity1 - complexity2)
        let edgeSim = 1.0 - abs(edgeDensity1 - edgeDensity2)
        return (complexitySim + edgeSim) / 2.0
    }
    
    func calculateAspectRatioSimilarity(ratio1: Double, ratio2: Double) -> Double {
        return 1.0 - min(abs(ratio1 - ratio2) / max(ratio1, ratio2), 1.0)
    }
    
    func calculateLayoutComplexity(
        textRegions: [CGRect],
        objectRegions: [CGRect],
        imageSize: CGSize
    ) -> Double {
        let totalArea = imageSize.width * imageSize.height
        let occupiedArea = (textRegions + objectRegions).reduce(0) { total, rect in
            total + rect.width * rect.height
        }
        
        return min(Double(occupiedArea / totalArea), 1.0)
    }
    
    /// Convert UIColor to LAB color space
    func convertToLAB(_ color: UIColor) -> (L: Double, A: Double, B: Double)? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        
        // Convert RGB to XYZ
        let r = linearize(Double(red))
        let g = linearize(Double(green))
        let b = linearize(Double(blue))
        
        let x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
        let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
        let z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041
        
        // Convert XYZ to LAB
        let xn = 0.95047, yn = 1.00000, zn = 1.08883 // D65 illuminant
        
        let fx = labFunc(x / xn)
        let fy = labFunc(y / yn)
        let fz = labFunc(z / zn)
        
        let L = 116 * fy - 16
        let A = 500 * (fx - fy)
        let B = 200 * (fy - fz)
        
        return (L: L, A: A, B: B)
    }
    
    /// Calculate distance between two LAB colors
    func calculateLABDistance(_ color1: (L: Double, A: Double, B: Double), _ color2: (L: Double, A: Double, B: Double)) -> Double {
        let deltaL = color1.L - color2.L
        let deltaA = color1.A - color2.A
        let deltaB = color1.B - color2.B
        
        return sqrt(deltaL * deltaL + deltaA * deltaA + deltaB * deltaB)
    }
    
    /// Linearize RGB component
    func linearize(_ component: Double) -> Double {
        return component > 0.04045 ? pow((component + 0.055) / 1.055, 2.4) : component / 12.92
    }
    
    /// LAB function for color space conversion
    func labFunc(_ t: Double) -> Double {
        return t > 0.008856 ? pow(t, 1.0/3.0) : (7.787 * t + 16.0/116.0)
    }
    
    /// Calculate spatial distribution of regions
    func calculateSpatialDistribution(_ regions: [CGRect]) -> (centerX: Double, centerY: Double, spread: Double) {
        let centerX = regions.map { $0.midX }.reduce(0, +) / Double(regions.count)
        let centerY = regions.map { $0.midY }.reduce(0, +) / Double(regions.count)
        let variance = regions.map { region in
            let dx = region.midX - centerX
            let dy = region.midY - centerY
            return dx * dx + dy * dy
        }.reduce(0, +) / Double(regions.count)
        return (centerX: centerX, centerY: centerY, spread: sqrt(variance))
    }
    
    /// Calculate total area of regions
    func calculateTotalArea(_ regions: [CGRect]) -> Double {
        return regions.reduce(0) { $0 + $1.width * $1.height }
    }
    
    /// Calculate overlap score between two region sets
    func calculateRegionOverlapScore(_ regions1: [CGRect], _ regions2: [CGRect]) -> Double {
        var totalOverlap = 0.0
        var totalUnion = 0.0
        
        for region1 in regions1 {
            for region2 in regions2 {
                let intersection = region1.intersection(region2)
                let union = region1.union(region2)
                
                if !intersection.isNull {
                    totalOverlap += intersection.width * intersection.height
                }
                totalUnion += union.width * union.height
            }
        }
        
        return totalUnion > 0 ? totalOverlap / totalUnion : 0.0
    }
}

// MARK: - Supporting Types

struct VisualFeatures {
    let dominantColors: [UIColor]
    let averageColor: UIColor
    let colorVariance: Double
    let textureComplexity: Double
    let edgeDensity: Double
    let featurePoints: [CGPoint]
    let contentClassification: [String]
    let aspectRatio: Double
}

struct VisualColorAnalysis {
    let dominantColors: [UIColor]
    let averageColor: UIColor
    let colorVariance: Double
    let colorDistribution: [String: Double]
}

struct TextureAnalysis {
    let complexity: Double
    let edgeDensity: Double
}

struct LayoutStructure {
    let textRegions: [CGRect]
    let objectRegions: [CGRect]
    let complexity: Double
}

struct ImageLayoutAnalysis {
    let textRegions: [CGRect]
    let objectRegions: [CGRect]
    let dominantColors: [UIColor]
    let visualComplexity: Double
    let aspectRatio: Double
}

// Removed duplicate ColorPalette struct. Use the one from Models/ColorPalette.swift

// MARK: - CGPath Extension

extension CGPath {
    func points() -> [CGPoint] {
        var points: [CGPoint] = []
        
        self.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.pointee.points[0])
            case .addQuadCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
            case .addCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
                points.append(element.pointee.points[2])
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        
        return points
    }
}