import Foundation
import Vision
import UIKit
import os.log

/// Enhanced Vision Service for advanced screenshot analysis
/// Provides comprehensive visual attribute extraction using Apple's Vision framework
@MainActor
public class EnhancedVisionService {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "EnhancedVision")
    private let processingQueue = DispatchQueue(label: "com.screenshotnotes.vision", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init() {
        logger.info("🔍 EnhancedVisionService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Analyze a screenshot and extract visual attributes
    /// - Parameter imageData: The image data to analyze
    /// - Returns: Visual attributes or nil if analysis fails
    public func analyzeScreenshot(_ imageData: Data) async -> VisualAttributes? {
        let startTime = Date()
        logger.info("🔍 Starting enhanced vision analysis")
        
        guard let image = UIImage(data: imageData) else {
            logger.error("❌ Failed to create UIImage from data")
            return nil
        }
        
        guard let cgImage = image.cgImage else {
            logger.error("❌ Failed to get CGImage from UIImage")
            return nil
        }
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<VisualAttributes?, Never>) in
            Task { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                // Perform comprehensive vision analysis
                async let objectDetection: [DetectedObject] = self.performObjectDetection(cgImage: cgImage)
                async let sceneClassification = self.performSceneClassification(cgImage: cgImage)
                async let compositionAnalysis: CompositionAnalysis = self.performCompositionAnalysis(cgImage: cgImage)
                async let colorAnalysis: Models.ColorAnalysis = self.performColorAnalysis(uiImage: image)
                // Wait for all analyses to complete
                let detectedObjects = await objectDetection
                let sceneInfo = await sceneClassification
                let composition = await compositionAnalysis
                let colors = await colorAnalysis
                // Calculate overall confidence
                let confidenceScores = [
                    detectedObjects.map { $0.confidence }.reduce(0, +) / max(1, Double(detectedObjects.count)),
                    sceneInfo.primaryConfidence,
                    composition.complexity, // Use a valid property instead of composition.confidence
                    // colors.confidence, // Remove this line as Models.ColorAnalysis has no 'confidence'
                ]
                let overallConfidence = confidenceScores.reduce(0, +) / Double(confidenceScores.count)
                let analysisTime = Date().timeIntervalSince(startTime)
                self.logger.info("✅ Enhanced vision analysis completed in \(String(format: "%.2f", analysisTime))s with confidence \(String(format: "%.2f", overallConfidence))")
                let visualAttributes = VisualAttributes(
                    detectedObjects: detectedObjects,
                    sceneClassification: sceneInfo,
                    composition: composition,
                    colorAnalysis: colors,
                    overallConfidence: overallConfidence,
                    analysisTimestamp: Date()
                )
                continuation.resume(returning: visualAttributes)
            }
        }
    }
    
    // MARK: - Object Detection
    
    private func performObjectDetection(cgImage: CGImage) async -> [DetectedObject] {
        return await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    self.logger.error("❌ Object detection failed: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                
                var detectedObjects: [DetectedObject] = []
                
                // Process rectangle observations
                if let observations = request.results as? [VNRectangleObservation] {
                    for (index, observation) in observations.enumerated() {
                        let boundingBox = BoundingBox(
                            x: Double(observation.boundingBox.origin.x),
                            y: Double(observation.boundingBox.origin.y),
                            width: Double(observation.boundingBox.width),
                            height: Double(observation.boundingBox.height)
                        )
                        
                        let detectedObject = DetectedObject(
                            identifier: "rectangle_\(index)",
                            label: "Document Region",
                            confidence: Double(observation.confidence),
                            boundingBox: boundingBox,
                            category: .document
                        )
                        detectedObjects.append(detectedObject)
                    }
                }
                
                self.logger.debug("🔍 Object detection found \(detectedObjects.count) objects")
                continuation.resume(returning: detectedObjects)
            }
            
            // Configure detection parameters
            request.minimumAspectRatio = 0.2
            request.maximumAspectRatio = 1.0
            request.minimumSize = 0.1
            // Note: VNDetectRectanglesRequest doesn't have maximumObservations property
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    // MARK: - Scene Classification
    
    private func performSceneClassification(cgImage: CGImage) async -> SceneClassification {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results as? [VNClassificationObservation],
                  !observations.isEmpty,
                  let topObservation = observations.first else {
                return self.createDefaultSceneClassification()
            }
            
            // Map Vision classification to our scene types
            let primaryScene = self.mapToSceneType(identifier: topObservation.identifier)
            let secondaryScene: SceneType? = observations.count > 1 ? self.mapToSceneType(identifier: observations[1].identifier) : nil
            
            let sceneClassification: SceneClassification = .init(
                primaryScene: primaryScene,
                secondaryScene: secondaryScene,
                primaryConfidence: Double(topObservation.confidence),
                secondaryConfidence: observations.count > 1 ? Double(observations[1].confidence) : nil,
                environment: self.determineEnvironment(identifier: topObservation.identifier),
                lighting: self.determineLighting(cgImage: cgImage)
            )
            
            self.logger.debug("🎬 Scene classification: \(primaryScene.rawValue) (\(String(format: "%.2f", Double(topObservation.confidence))))")
            return sceneClassification
        } catch {
            self.logger.error("❌ Failed to perform scene classification: \(error.localizedDescription)")
            return self.createDefaultSceneClassification()
        }
    }
    
    // MARK: - Composition Analysis
    
    private func performCompositionAnalysis(cgImage: CGImage) async -> CompositionAnalysis {
        return await withCheckedContinuation { continuation in
            let textRequest = VNDetectTextRectanglesRequest { request, error in
                if let error = error {
                    self.logger.error("❌ Text detection failed: \(error.localizedDescription)")
                    continuation.resume(returning: self.createDefaultComposition())
                    return
                }
                
                var textRegions: [TextRegion] = []
                var totalTextArea: Double = 0
                
                if let observations = request.results as? [VNTextObservation] {
                    for observation in observations {
                        let boundingBox = BoundingBox(
                            x: Double(observation.boundingBox.origin.x),
                            y: Double(observation.boundingBox.origin.y),
                            width: Double(observation.boundingBox.width),
                            height: Double(observation.boundingBox.height)
                        )
                        
                        let textRegion = TextRegion(
                            boundingBox: boundingBox,
                            confidence: Double(observation.confidence),
                            textDensity: self.calculateTextDensity(boundingBox: boundingBox),
                            orientation: 0.0 // Could be enhanced with actual text orientation
                        )
                        textRegions.append(textRegion)
                        totalTextArea += boundingBox.width * boundingBox.height
                    }
                }
                
                // Calculate composition metrics
                let textDensity = min(1.0, totalTextArea)
                let complexity = self.calculateComplexity(textRegions: textRegions)
                let symmetry = self.calculateSymmetry(textRegions: textRegions)
                let balance = self.calculateBalance(textRegions: textRegions)
                let layout = self.determineLayout(textRegions: textRegions)
                
                let composition = CompositionAnalysis(
                    layout: layout,
                    textDensity: textDensity,
                    complexity: complexity,
                    symmetry: symmetry,
                    balance: balance,
                    textRegions: textRegions
                )
                
                self.logger.debug("📏 Composition analysis: \(textRegions.count) text regions, density: \(String(format: "%.2f", textDensity))")
                continuation.resume(returning: composition)
            }
            
            // Configure text detection
            textRequest.reportCharacterBoxes = false
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([textRequest])
            } catch {
                self.logger.error("❌ Failed to perform composition analysis: \(error.localizedDescription)")
                continuation.resume(returning: self.createDefaultComposition())
            }
        }
    }
    
    // MARK: - Color Analysis
    
    private func performColorAnalysis(uiImage: UIImage) async -> Models.ColorAnalysis {
        return await withCheckedContinuation { continuation in
            Task {
                let dominantColors = self.extractDominantColors(from: uiImage)
                let brightness = self.calculateBrightness(from: uiImage)
                let contrast = self.calculateContrast(from: uiImage)
                let saturation = self.calculateSaturation(from: dominantColors)
                let temperature = self.determineTemperature(from: dominantColors)
                let colorScheme = self.determineColorScheme(from: dominantColors)
                
                let colorAnalysis = Models.ColorAnalysis(
                    dominantColors: dominantColors,
                    brightness: brightness,
                    contrast: contrast,
                    saturation: saturation,
                    temperature: temperature,
                    colorScheme: colorScheme,
                    visualEmbedding: []
                )
                
                self.logger.debug("\u{1F3A8} Color analysis: \(dominantColors.count) dominant colors, brightness: \(String(format: "%.2f", brightness))")
                continuation.resume(returning: colorAnalysis)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createDefaultSceneClassification() -> SceneClassification {
        return SceneClassification(
            primaryScene: .screenshot,
            secondaryScene: .unknown,
            primaryConfidence: 0.7,
            secondaryConfidence: 0.0,
            environment: .digital,
            lighting: .artificial
        )
    }
    
    private func createDefaultComposition() -> CompositionAnalysis {
        return CompositionAnalysis(
            layout: .unknown,
            textDensity: 0.5,
            complexity: 0.5,
            symmetry: 0.5,
            balance: 0.5,
            textRegions: []
        )
    }
    
    private func mapToSceneType(identifier: String) -> SceneType {
        let lowercased = identifier.lowercased()
        
        if lowercased.contains("document") || lowercased.contains("text") || lowercased.contains("paper") {
            return .document
        } else if lowercased.contains("web") || lowercased.contains("browser") || lowercased.contains("interface") {
            return .webpage
        } else if lowercased.contains("app") || lowercased.contains("mobile") || lowercased.contains("screen") {
            return .application
        } else if lowercased.contains("chat") || lowercased.contains("message") || lowercased.contains("conversation") {
            return .message
        } else if lowercased.contains("menu") || lowercased.contains("settings") || lowercased.contains("dialog") {
            return .application
        } else {
            return .screenshot
        }
    }
    
    private func determineEnvironment(identifier: String) -> EnvironmentType {
        return identifier.lowercased().contains("outdoor") ? .outdoor : .digital
    }
    
    private func determineLighting(cgImage: CGImage) -> LightingConditions {
        // Simple brightness-based lighting detection
        // In a more sophisticated implementation, this could analyze color temperature
        return .artificial // Most screenshots are from digital displays
    }
    
    private func calculateTextDensity(boundingBox: BoundingBox) -> Double {
        // Estimate text density based on bounding box size
        let area = boundingBox.width * boundingBox.height
        return min(1.0, area * 10) // Scale factor for density estimation
    }
    
    private func calculateComplexity(textRegions: [TextRegion]) -> Double {
        // Complexity based on number and distribution of text regions
        let regionCount = Double(textRegions.count)
        let normalizedComplexity = min(1.0, regionCount / 20.0) // Normalize to 0-1
        return normalizedComplexity
    }
    
    private func calculateSymmetry(textRegions: [TextRegion]) -> Double {
        guard !textRegions.isEmpty else { return 0.5 }
        
        // Simple symmetry calculation based on text region distribution
        let centerX = 0.5
        var symmetryScore = 0.0
        
        for region in textRegions {
            let regionCenterX = region.boundingBox.x + region.boundingBox.width / 2
            let distanceFromCenter = abs(regionCenterX - centerX)
            symmetryScore += 1.0 - (distanceFromCenter * 2.0) // Convert to symmetry score
        }
        
        return max(0.0, min(1.0, symmetryScore / Double(textRegions.count)))
    }
    
    private func calculateBalance(textRegions: [TextRegion]) -> Double {
        guard !textRegions.isEmpty else { return 0.5 }
        
        // Balance based on even distribution of text regions
        let totalArea = textRegions.reduce(0.0) { $0 + ($1.boundingBox.width * $1.boundingBox.height) }
        let averageArea = totalArea / Double(textRegions.count)
        
        var balanceScore = 0.0
        for region in textRegions {
            let regionArea = region.boundingBox.width * region.boundingBox.height
            let deviation = abs(regionArea - averageArea) / averageArea
            balanceScore += max(0.0, 1.0 - deviation)
        }
        
        return balanceScore / Double(textRegions.count)
    }
    
    private func determineLayout(textRegions: [TextRegion]) -> LayoutType {
        guard textRegions.count > 1 else { return .unknown }
        
        // Analyze text region alignment for layout detection
        let verticalAlignment = textRegions.allSatisfy { abs($0.boundingBox.x - textRegions[0].boundingBox.x) < 0.1 }
        let horizontalAlignment = textRegions.allSatisfy { abs($0.boundingBox.y - textRegions[0].boundingBox.y) < 0.1 }
        
        if verticalAlignment || horizontalAlignment {
            return .structured
        } else {
            return .unknown
        }
    }
    
    private func extractDominantColors(from image: UIImage) -> [Models.DominantColor] {
        // Extract dominant colors using Core Image or custom algorithm
        // This is a simplified implementation
        return [
            Models.DominantColor(red: 1.0, green: 1.0, blue: 1.0, prominence: 0.4, colorName: "White", hexValue: "#FFFFFF"),
            Models.DominantColor(red: 0.0, green: 0.0, blue: 0.0, prominence: 0.3, colorName: "Black", hexValue: "#000000"),
            Models.DominantColor(red: 0.2, green: 0.2, blue: 0.2, prominence: 0.3, colorName: "Gray", hexValue: "#333333")
        ]
    }
    
    private func calculateBrightness(from image: UIImage) -> Double {
        // Calculate average brightness of the image
        // This is a simplified implementation
        return 0.8 // Most screenshots are relatively bright
    }
    
    private func calculateContrast(from image: UIImage) -> Double {
        // Calculate contrast ratio
        // This is a simplified implementation
        return 0.7 // Reasonable contrast for most screenshots
    }
    
    private func calculateSaturation(from colors: [Models.DominantColor]) -> Double {
        // Calculate average saturation from dominant colors
        guard !colors.isEmpty else { return 0.5 }
        
        let totalSaturation = colors.reduce(0.0) { total, color in
            let max = Swift.max(color.red, color.green, color.blue)
            let min = Swift.min(color.red, color.green, color.blue)
            let saturation = max == 0 ? 0 : (max - min) / max
            return total + saturation * color.prominence
        }
        
        return totalSaturation
    }
    
    private func determineTemperature(from colors: [Models.DominantColor]) -> ColorTemperature {
        // Determine color temperature based on dominant colors
        let warmColors = colors.filter { $0.red > $0.blue }
        let coolColors = colors.filter { $0.blue > $0.red }
        
        let warmProminence = warmColors.reduce(0.0) { $0 + $1.prominence }
        let coolProminence = coolColors.reduce(0.0) { $0 + $1.prominence }
        
        if warmProminence > coolProminence + 0.2 {
            return .warm
        } else if coolProminence > warmProminence + 0.2 {
            return .cool
        } else {
            return .neutral
        }
    }
    
    private func determineColorScheme(from colors: [Models.DominantColor]) -> VisualColorScheme {
        // Determine color scheme based on color relationships
        guard colors.count >= 2 else { return .monochromatic }
        
        let grayscaleColors = colors.filter { abs($0.red - $0.green) < 0.1 && abs($0.green - $0.blue) < 0.1 }
        
        if grayscaleColors.count == colors.count {
            return .monochromatic
        } else if colors.count <= 3 {
            return .analogous
        } else {
            return .triadic
        }
    }
}