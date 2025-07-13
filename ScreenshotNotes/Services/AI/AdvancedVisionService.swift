import Foundation
@preconcurrency import Vision
import UIKit
import CoreML
import OSLog
import NaturalLanguage

/// Advanced Vision Framework service providing comprehensive image analysis
@MainActor
public final class AdvancedVisionService: ObservableObject {
    public static let shared = AdvancedVisionService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "AdvancedVision")
    private let processingQueue = DispatchQueue(label: "vision.processing", qos: .userInitiated)
    private let cacheManager = VisionCacheManager()
    private let errorHandler = VisionErrorHandler.shared
    
    // Performance monitoring
    private var processingMetrics = VisionProcessingMetrics()
    
    // Processing state
    @Published private(set) var isProcessing = false
    @Published private(set) var processingProgress: Double = 0.0
    @Published private(set) var lastProcessingTime: TimeInterval = 0.0
    private let colorAnalysisService = ColorAnalysisService()
    
    private init() {
        configureVisionSettings()
    }
    
    // MARK: - Screenshot Analysis Integration
    
    /// Analyze screenshot data and convert to legacy VisualAttributes format
    public func analyzeScreenshot(_ imageData: Data) async -> VisualAttributes? {
        do {
            guard let image = UIImage(data: imageData) else {
                logger.error("Failed to create UIImage from image data")
                return nil
            }
            
            let results = try await analyzeImage(image)
            return convertToVisualAttributes(results)
            
        } catch {
            logger.error("Screenshot analysis failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Convert ComprehensiveVisionResults to legacy VisualAttributes format
    private func convertToVisualAttributes(_ results: ComprehensiveVisionResults) -> VisualAttributes {
        // Convert scene classification
        let sceneClassification = SceneClassification(
            primaryScene: convertAdvancedSceneToLegacy(results.sceneClassification.primaryScene),
            secondaryScene: results.sceneClassification.secondaryScenes.first.map { convertAdvancedSceneToLegacy($0.scene) },
            primaryConfidence: results.sceneClassification.confidence,
            secondaryConfidence: results.sceneClassification.secondaryScenes.first?.confidence,
            environment: inferEnvironmentType(from: results.sceneClassification.primaryScene),
            lighting: .unknown // Default lighting since we don't have this in advanced results
        )
        
        // Convert detected objects from attention areas and scene classification
        let detectedObjects = extractDetectedObjects(from: results)
        
        // Create composition analysis from text recognition and scene data
        let composition = createCompositionAnalysis(from: results)
        
        // Create color analysis with basic values (would need enhancement for full color analysis)
        let colorAnalysis = results.colorAnalysis.map { convertToLegacyColorAnalysis($0) } ?? createBasicColorAnalysis()
        
        return VisualAttributes(
            detectedObjects: detectedObjects,
            sceneClassification: sceneClassification,
            composition: composition,
            colorAnalysis: colorAnalysis,
            overallConfidence: results.overallConfidence,
            analysisTimestamp: results.analysisTimestamp
        )
    }
    
    private func convertAdvancedSceneToLegacy(_ advancedScene: AdvancedSceneType) -> SceneType {
        switch advancedScene {
        case .document: return .document
        case .receipt: return .receipt
        case .webPage: return .webpage
        case .mobileApp, .socialMedia, .email, .message: return .application
        case .photo, .portrait, .people, .group, .landscape, .nature: return .photo
        case .screenshot: return .screenshot
        case .calendar: return .calendar
        case .map: return .map
        case .shopping, .product: return .shopping
        default: return .unknown
        }
    }
    
    private func inferEnvironmentType(from scene: AdvancedSceneType) -> EnvironmentType {
        switch scene {
        case .webPage, .mobileApp, .socialMedia, .email, .message, .screenshot, .document, .receipt:
            return .digital
        case .landscape, .nature, .outdoor, .weather:
            return .outdoor
        case .indoor, .meeting:
            return .indoor
        default:
            return .unknown
        }
    }
    
    private func extractDetectedObjects(from results: ComprehensiveVisionResults) -> [DetectedObject] {
        var objects: [DetectedObject] = []
        
        // Convert attention areas to detected objects
        for attentionArea in results.sceneClassification.attentionAreas {
            if let objectName = attentionArea.detectedObject {
                let category = inferObjectCategory(from: objectName)
                let detectedObject = DetectedObject(
                    identifier: objectName,
                    label: objectName.capitalized,
                    confidence: attentionArea.confidence,
                    boundingBox: attentionArea.boundingBox,
                    category: category
                )
                objects.append(detectedObject)
            }
        }
        
        // Add face detection as objects
        if let faceDetection = results.faceDetection {
            for face in faceDetection.faces {
                let detectedObject = DetectedObject(
                    identifier: "face",
                    label: "Face",
                    confidence: face.confidence,
                    boundingBox: face.boundingBox,
                    category: .person
                )
                objects.append(detectedObject)
            }
        }
        
        return objects
    }
    
    private func createCompositionAnalysis(from results: ComprehensiveVisionResults) -> CompositionAnalysis {
        let textRegions = results.textRecognition?.textBlocks.map { textBlock in
            TextRegion(
                boundingBox: textBlock.boundingBox,
                confidence: textBlock.confidence,
                textDensity: 1.0, // Assume high text density for detected text blocks
                orientation: 0.0  // Default horizontal orientation
            )
        } ?? []
        
        let textDensity = textRegions.isEmpty ? 0.0 : min(Double(textRegions.count) * 0.1, 1.0)
        
        let layout = inferLayoutType(from: results.sceneClassification.primaryScene, textRegions: textRegions)
        
        return CompositionAnalysis(
            layout: layout,
            textDensity: textDensity,
            complexity: 0.5, // Default medium complexity
            symmetry: 0.5,   // Default medium symmetry
            balance: 0.5,    // Default medium balance
            textRegions: textRegions
        )
    }
    
    private func inferLayoutType(from scene: AdvancedSceneType, textRegions: [TextRegion]) -> LayoutType {
        switch scene {
        case .document, .receipt, .invoice, .form, .certificate:
            return .structured
        case .mobileApp, .webPage:
            return textRegions.count > 5 ? .list : .grid
        case .photo, .portrait, .landscape, .artwork:
            return .freeform
        default:
            return textRegions.count > 3 ? .structured : .mixed
        }
    }
    
    private func inferObjectCategory(from objectName: String) -> ObjectCategory {
        let lowercaseName = objectName.lowercased()
        
        if lowercaseName.contains("person") || lowercaseName.contains("face") {
            return .person
        } else if lowercaseName.contains("text") || lowercaseName.contains("document") {
            return .text
        } else if lowercaseName.contains("food") || lowercaseName.contains("meal") {
            return .food
        } else if lowercaseName.contains("car") || lowercaseName.contains("vehicle") {
            return .vehicle
        } else if lowercaseName.contains("building") || lowercaseName.contains("house") {
            return .building
        } else if lowercaseName.contains("phone") || lowercaseName.contains("computer") || lowercaseName.contains("screen") {
            return .technology
        } else if lowercaseName.contains("tree") || lowercaseName.contains("plant") || lowercaseName.contains("flower") {
            return .nature
        } else if lowercaseName.contains("chair") || lowercaseName.contains("table") || lowercaseName.contains("furniture") {
            return .furniture
        } else if lowercaseName.contains("shirt") || lowercaseName.contains("dress") || lowercaseName.contains("clothing") {
            return .clothing
        } else {
            return .unknown
        }
    }

    private func convertToLegacyColorAnalysis(_ colorAnalysisResult: ColorAnalysisService.ColorAnalysisResult) -> ColorAnalysis {
        let dominantColors = colorAnalysisResult.dominantColors.map {
            DominantColor(
                red: $0.red,
                green: $0.green,
                blue: $0.blue,
                prominence: $0.prominence,
                colorName: $0.colorName,
                hexValue: $0.hexValue
            )
        }

        return ColorAnalysis(
            dominantColors: dominantColors,
            brightness: colorAnalysisResult.brightness,
            contrast: colorAnalysisResult.contrast,
            saturation: colorAnalysisResult.saturation,
            temperature: .neutral, // Placeholder
            colorScheme: .unknown, // Placeholder
            visualEmbedding: []
        )
    }

    private func createBasicColorAnalysis() -> ColorAnalysis {
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
    
    /// Perform comprehensive vision analysis on an image
    public func analyzeImage(_ image: UIImage) async throws -> ComprehensiveVisionResults {
        return try await errorHandler.executeWithRetry(
            operation: { [weak self] in
                guard let self = self else { throw VisionError.processingFailed("Service unavailable") }
                return try await self.performComprehensiveAnalysis(image)
            },
            operationType: .comprehensive
        )
    }
    
    private func performComprehensiveAnalysis(_ image: UIImage) async throws -> ComprehensiveVisionResults {
        let startTime = Date()
        
        // Update processing state
        isProcessing = true
        processingProgress = 0.0
        defer { isProcessing = false }
        
        logger.info("Starting comprehensive vision analysis")
        
        // Check cache first
        if let cached = await cacheManager.getCachedResults(for: image) {
            logger.info("Returning cached vision results")
            processingProgress = 1.0
            return cached
        }
        
        // Validate image
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage("Unable to extract CGImage from UIImage")
        }
        
        // Validate image dimensions
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        guard imageSize.width > 0 && imageSize.height > 0 else {
            throw VisionError.invalidImage("Image has invalid dimensions")
        }
        
        // Check for minimum image size
        guard max(imageSize.width, imageSize.height) >= 32 else {
            throw VisionError.invalidImage("Image is too small for analysis")
        }
        
        // Determine optimal processing quality
        let quality = determineOptimalQuality(for: image)
        logger.info("Using processing quality: \\(quality.displayName)")
        
        processingProgress = 0.1
        
        // Perform vision analysis with proper error handling
        let sceneResult = try await performSceneClassificationWithRetry(cgImage, quality: quality)
        processingProgress = 0.3
        
        let faceResult = try await performFaceDetectionWithRetry(cgImage, quality: quality)
        processingProgress = 0.5
        
        let textResult = try await performTextRecognitionWithRetry(cgImage, quality: quality)
        processingProgress = 0.7
        
        let colorResult = await colorAnalysisService.analyzeImage(image.pngData()!)
        processingProgress = 0.9
        
        // Enhanced scene classification with attention areas
        let enhancedSceneClassification = AdvancedSceneClassification(
            primaryScene: sceneResult.primaryScene,
            secondaryScenes: sceneResult.secondaryScenes,
            confidence: sceneResult.confidence,
            attentionAreas: [],
            processingMetadata: createProcessingMetadata(startTime: startTime, quality: quality)
        )
        
        let results = ComprehensiveVisionResults(
            sceneClassification: enhancedSceneClassification,
            faceDetection: faceResult,
            textRecognition: textResult,
            colorAnalysis: colorResult
        )
        
        // Cache results for future use
        await cacheManager.cacheResults(results, for: image)
        
        // Update metrics
        let processingTime = Date().timeIntervalSince(startTime)
        lastProcessingTime = processingTime
        processingMetrics.recordAnalysis(duration: processingTime, quality: quality)
        
        processingProgress = 1.0
        
        logger.info("Vision analysis completed in \\(String(format: \"%.2f\", processingTime))s")
        
        return results
    }
    
    // MARK: - Individual Analysis Methods with Retry
    
    private func performSceneClassificationWithRetry(_ cgImage: CGImage, quality: ProcessingQuality) async throws -> AdvancedSceneClassification {
        return try await errorHandler.executeWithRetry(
            operation: { [weak self] in
                guard let self = self else { throw VisionError.processingFailed("Service unavailable") }
                return try await self.performSceneClassification(cgImage, quality: quality)
            },
            operationType: .sceneClassification
        )
    }
    
    private func performFaceDetectionWithRetry(_ cgImage: CGImage, quality: ProcessingQuality) async throws -> FaceDetection? {
        do {
            return try await errorHandler.executeWithRetry(
                operation: { [weak self] in
                    guard let self = self else { throw VisionError.processingFailed("Service unavailable") }
                    return try await self.performFaceDetection(cgImage, quality: quality)
                },
                operationType: .faceDetection
            )
        } catch {
            // Face detection is optional - log warning and continue
            logger.warning("Face detection failed, continuing without face data: \\(error.localizedDescription)")
            return nil
        }
    }
    
    private func performTextRecognitionWithRetry(_ cgImage: CGImage, quality: ProcessingQuality) async throws -> EnhancedTextRecognition? {
        do {
            return try await errorHandler.executeWithRetry(
                operation: { [weak self] in
                    guard let self = self else { throw VisionError.processingFailed("Service unavailable") }
                    return try await self.performEnhancedTextRecognition(cgImage, quality: quality)
                },
                operationType: .textRecognition
            )
        } catch {
            // Text recognition is optional - log warning and continue
            logger.warning("Text recognition failed, continuing without text data: \\(error.localizedDescription)")
            return nil
        }
    }
    
    private func performAttentionAnalysisWithRetry(_ cgImage: CGImage, quality: ProcessingQuality) async throws -> [AttentionArea] {
        do {
            return try await errorHandler.executeWithRetry(
                operation: { [weak self] in
                    guard let self = self else { throw VisionError.processingFailed("Service unavailable") }
                    return try await self.performAttentionAnalysis(cgImage, quality: quality)
                },
                operationType: .attentionAnalysis
            )
        } catch {
            // Attention analysis is optional - log warning and continue
            logger.warning("Attention analysis failed, continuing without attention data: \\(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Scene Classification
    
    private func performSceneClassification(_ cgImage: CGImage, quality: ProcessingQuality) async throws -> AdvancedSceneClassification {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: VisionError.processingFailed("Service unavailable"))
                return
            }
            let request = VNClassifyImageRequest { request, _ in
                
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(throwing: VisionError.invalidResults("No classification observations found"))
                    return
                }
                
                let classification = self.processClassificationObservations(observations)
                continuation.resume(returning: classification)
            }
            
            // Configure request for optimal quality
            configureClassificationRequest(request, quality: quality)
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            processingQueue.async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    private func processClassificationObservations(_ observations: [VNClassificationObservation]) -> AdvancedSceneClassification {
        // Sort by confidence
        let sortedObservations = observations.sorted { $0.confidence > $1.confidence }
        
        // Map to our scene types with intelligent categorization
        let sceneConfidences = sortedObservations.compactMap { observation -> SceneConfidence? in
            guard let sceneType = mapToAdvancedSceneType(observation.identifier, confidence: observation.confidence) else {
                return nil
            }
            return SceneConfidence(scene: sceneType, confidence: Double(observation.confidence))
        }
        
        // Determine primary scene
        let primaryScene = sceneConfidences.first?.scene ?? .unknown
        let primaryConfidence = sceneConfidences.first?.confidence ?? 0.0
        
        // Get secondary scenes (up to 3)
        let secondaryScenes = Array(sceneConfidences.dropFirst().prefix(3))
        
        return AdvancedSceneClassification(
            primaryScene: primaryScene,
            secondaryScenes: secondaryScenes,
            confidence: primaryConfidence
        )
    }
    
    private func mapToAdvancedSceneType(_ identifier: String, confidence: Float) -> AdvancedSceneType? {
        let lowercaseId = identifier.lowercased()
        
        // Document and text content
        if lowercaseId.contains("document") || lowercaseId.contains("paper") || lowercaseId.contains("text") {
            if lowercaseId.contains("receipt") { return .receipt }
            if lowercaseId.contains("invoice") { return .invoice }
            if lowercaseId.contains("form") { return .form }
            if lowercaseId.contains("certificate") { return .certificate }
            if lowercaseId.contains("menu") { return .menu }
            return .document
        }
        
        // Digital interfaces
        if lowercaseId.contains("screen") || lowercaseId.contains("computer") || lowercaseId.contains("mobile") {
            if lowercaseId.contains("shopping") || lowercaseId.contains("store") { return .shopping }
            if lowercaseId.contains("social") { return .socialMedia }
            if lowercaseId.contains("web") || lowercaseId.contains("browser") { return .webPage }
            if lowercaseId.contains("app") { return .mobileApp }
            return .screenshot
        }
        
        // People and social
        if lowercaseId.contains("person") || lowercaseId.contains("people") || lowercaseId.contains("human") {
            if lowercaseId.contains("portrait") { return .portrait }
            if lowercaseId.contains("group") { return .group }
            if lowercaseId.contains("wedding") { return .wedding }
            if lowercaseId.contains("graduation") { return .graduation }
            return .people
        }
        
        // Products and objects
        if lowercaseId.contains("product") || lowercaseId.contains("item") {
            if lowercaseId.contains("clothing") || lowercaseId.contains("shirt") || lowercaseId.contains("dress") { return .clothing }
            if lowercaseId.contains("electronic") || lowercaseId.contains("computer") || lowercaseId.contains("phone") { return .electronics }
            if lowercaseId.contains("food") || lowercaseId.contains("meal") { return .food }
            if lowercaseId.contains("book") { return .books }
            return .product
        }
        
        // Nature and environment
        if lowercaseId.contains("landscape") || lowercaseId.contains("nature") || lowercaseId.contains("outdoor") {
            if lowercaseId.contains("city") || lowercaseId.contains("urban") { return .cityscape }
            if lowercaseId.contains("building") || lowercaseId.contains("architecture") { return .architecture }
            if lowercaseId.contains("mountain") || lowercaseId.contains("forest") || lowercaseId.contains("beach") { return .landscape }
            return .outdoor
        }
        
        // Specialized content
        if lowercaseId.contains("chart") || lowercaseId.contains("graph") { return .chart }
        if lowercaseId.contains("qr") || lowercaseId.contains("code") { return .qrCode }
        if lowercaseId.contains("barcode") { return .barcode }
        if lowercaseId.contains("medical") || lowercaseId.contains("hospital") { return .medicalContent }
        if lowercaseId.contains("legal") || lowercaseId.contains("law") { return .legalContent }
        if lowercaseId.contains("education") || lowercaseId.contains("school") { return .educationalContent }
        
        // Only return if confidence is above threshold
        return confidence > 0.1 ? .unknown : nil
    }
    
    // MARK: - Attention-Based Saliency Analysis
    
    private func performAttentionAnalysis(_ cgImage: CGImage, quality: ProcessingQuality) async throws -> [AttentionArea] {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: VisionError.processingFailed("Service unavailable"))
                return
            }
            let request = VNGenerateAttentionBasedSaliencyImageRequest { request, _ in
                
                guard let observations = request.results as? [VNSaliencyImageObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let attentionAreas = self.processAttentionObservations(observations)
                continuation.resume(returning: attentionAreas)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            processingQueue.async {
                do {
                    try handler.perform([request])
                } catch {
                    self.logger.warning("Attention analysis error: \\(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func processAttentionObservations(_ observations: [VNSaliencyImageObservation]) -> [AttentionArea] {
        var attentionAreas: [AttentionArea] = []
        
        for observation in observations {
            if let salientObjects = observation.salientObjects {
                for salientObject in salientObjects {
                    let boundingBox = BoundingBox(from: salientObject.boundingBox)
                    let attentionArea = AttentionArea(
                        boundingBox: boundingBox,
                        confidence: Double(salientObject.confidence),
                        attentionType: .saliencyBased
                    )
                    attentionAreas.append(attentionArea)
                }
            }
        }
        
        // Sort by confidence and limit to top 5 areas
        return attentionAreas
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
            .map { $0 }
    }
    
    // MARK: - Face Detection
    
    private func performFaceDetection(_ cgImage: CGImage, quality: ProcessingQuality) async throws -> FaceDetection? {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: VisionError.processingFailed("Service unavailable"))
                return
            }
            let request = VNDetectFaceRectanglesRequest { request, _ in

                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                if observations.isEmpty {
                    continuation.resume(returning: nil)
                    return
                }
                
                let faceDetection = self.processFaceObservations(observations)
                continuation.resume(returning: faceDetection)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            processingQueue.async {
                do {
                    try handler.perform([request])
                } catch {
                    self.logger.warning("Face detection error: \\(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func processFaceObservations(_ observations: [VNFaceObservation]) -> FaceDetection {
        let detectedFaces = observations.map { observation in
            let boundingBox = BoundingBox(from: observation.boundingBox)
            
            // Extract landmarks if available
            var landmarks: FaceLandmarks? = nil
            if let _ = observation.landmarks?.faceContour {
                // Create simplified landmarks representation
                landmarks = FaceLandmarks()
            }
            
            return DetectedFace(
                boundingBox: boundingBox,
                confidence: Double(observation.confidence),
                landmarks: landmarks
            )
        }
        
        // Calculate overall confidence
        let averageConfidence = detectedFaces.reduce(0.0) { $0 + $1.confidence } / Double(detectedFaces.count)
        
        return FaceDetection(faces: detectedFaces, confidence: averageConfidence)
    }
    
    // MARK: - Enhanced Text Recognition
    
    private func performEnhancedTextRecognition(_ cgImage: CGImage, quality: ProcessingQuality) async throws -> EnhancedTextRecognition? {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: VisionError.processingFailed("Service unavailable"))
                return
            }
            let request = VNRecognizeTextRequest { request, _ in

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                if observations.isEmpty {
                    continuation.resume(returning: nil)
                    return
                }
                
                let textRecognition = self.processTextObservations(observations, quality: quality)
                continuation.resume(returning: textRecognition)
            }
            
            // Configure text recognition for optimal quality
            configureTextRecognitionRequest(request, quality: quality)
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            processingQueue.async {
                do {
                    try handler.perform([request])
                } catch {
                    self.logger.warning("Text recognition error: \\(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func processTextObservations(_ observations: [VNRecognizedTextObservation], quality: ProcessingQuality) -> EnhancedTextRecognition {
        var textBlocks: [TextBlock] = []
        var detectedLanguages: Set<String> = []
        var totalConfidence: Double = 0.0
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let boundingBox = BoundingBox(from: observation.boundingBox)
            let confidence = Double(topCandidate.confidence)
            
            // Simple language detection (would need more sophisticated approach in production)
            let language = detectLanguage(topCandidate.string)
            if let lang = language {
                detectedLanguages.insert(lang)
            }
            
            let characteristics = TextCharacteristics()
            
            let textBlock = TextBlock(
                text: topCandidate.string,
                boundingBox: boundingBox,
                confidence: confidence,
                language: language,
                characteristics: characteristics
            )
            
            textBlocks.append(textBlock)
            totalConfidence += confidence
        }
        
        let averageConfidence = textBlocks.isEmpty ? 0.0 : totalConfidence / Double(textBlocks.count)
        
        let recognizedLanguages = detectedLanguages.map { code in
            RecognizedLanguage(
                code: code,
                name: Locale.current.localizedString(forLanguageCode: code) ?? code,
                confidence: 0.8 // Placeholder confidence
            )
        }
        
        let processingInfo = TextProcessingInfo(
            processingTime: 0, // Will be filled by caller
            recognitionLevel: mapQualityToRecognitionLevel(quality)
        )
        
        return EnhancedTextRecognition(
            textBlocks: textBlocks,
            detectedLanguages: recognizedLanguages,
            confidence: averageConfidence,
            processingInfo: processingInfo
        )
    }
    
    // MARK: - Configuration and Optimization
    
    private func configureVisionSettings() {
        // Configure global Vision settings for optimal performance
        logger.info("Configuring Vision Framework settings")
    }
    
    private func determineOptimalQuality(for image: UIImage) -> ProcessingQuality {
        let imageSize = image.size.width * image.size.height
        let deviceCapabilities = getDeviceCapabilities()
        
        // Determine quality based on image size and device capabilities
        if imageSize > 2_000_000 && !deviceCapabilities.highPerformanceMode {
            return .fast
        } else if imageSize > 4_000_000 {
            return .standard
        } else if deviceCapabilities.neuralEngine {
            return .accurate
        } else {
            return .standard
        }
    }
    
    private func configureClassificationRequest(_ request: VNClassifyImageRequest, quality: ProcessingQuality) {
        // Configure classification request based on quality level
        switch quality {
        case .fast:
            // Optimize for speed
            break
        case .standard:
            // Balanced approach
            break
        case .accurate, .comprehensive:
            // Optimize for accuracy
            break
        }
    }
    
    private func configureTextRecognitionRequest(_ request: VNRecognizeTextRequest, quality: ProcessingQuality) {
        // Set recognition level
        switch quality {
        case .fast:
            request.recognitionLevel = .fast
        case .standard:
            request.recognitionLevel = .accurate
        case .accurate, .comprehensive:
            request.recognitionLevel = .accurate
        }
        
        // Set language hints for better accuracy
        request.recognitionLanguages = ["en-US", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-BR", "zh-Hans", "ja-JP"]
        request.usesLanguageCorrection = true
    }
    
    private func createProcessingMetadata(startTime: Date, quality: ProcessingQuality) -> ProcessingMetadata {
        let processingTime = Date().timeIntervalSince(startTime)
        let deviceCapabilities = getDeviceCapabilities()
        
        return ProcessingMetadata(
            processingTime: processingTime,
            modelVersions: ["VNClassifyImageRequest", "VNGenerateAttentionBasedSaliencyImageRequest", "VNDetectFaceRectanglesRequest", "VNRecognizeTextRequest"],
            deviceCapabilities: deviceCapabilities,
            qualityLevel: quality
        )
    }
    
    private func getDeviceCapabilities() -> DeviceCapabilities {
        let neuralEngine = hasNeuralEngine()
        let highPerformanceMode = ProcessInfo.processInfo.thermalState == .nominal
        let memoryCapacity = Int(ProcessInfo.processInfo.physicalMemory / 1_000_000) // Convert to MB
        
        return DeviceCapabilities(
            neuralEngine: neuralEngine,
            highPerformanceMode: highPerformanceMode,
            memoryCapacity: memoryCapacity
        )
    }
    
    private func hasNeuralEngine() -> Bool {
        // Check if device has Neural Engine (simplified check)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        // Neural Engine available on A11+ chips
        if let machine = machine {
            return machine.contains("iPhone10") || // iPhone X series (A11)
                   machine.contains("iPhone11") || // iPhone XS series (A12)
                   machine.contains("iPhone12") || // iPhone 11 series (A13)
                   machine.contains("iPhone13") || // iPhone 12 series (A14)
                   machine.contains("iPhone14") || // iPhone 13 series (A15)
                   machine.contains("iPad8") ||    // iPad (8th gen) A12
                   machine.contains("iPad11") ||   // iPad Air (3rd gen) A12
                   machine.contains("iPad13")      // iPad Pro (3rd gen) A12X
        }
        
        return false
    }
    
    private func detectLanguage(_ text: String) -> String? {
        // Simple language detection - in production, use NLLanguageRecognizer
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }
    
    private func mapQualityToRecognitionLevel(_ quality: ProcessingQuality) -> TextRecognitionLevel {
        switch quality {
        case .fast: return .fast
        case .standard: return .accurate
        case .accurate, .comprehensive: return .comprehensive
        }
    }
}

// MARK: - Error Types

public enum VisionError: LocalizedError {
    case invalidImage(String)
    case classificationFailed(String)
    case processingFailed(String)
    case invalidResults(String)
    case cacheError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage(let message): return "Invalid image: \(message)"
        case .classificationFailed(let message): return "Classification failed: \(message)"
        case .processingFailed(let message): return "Processing failed: \(message)"
        case .invalidResults(let message): return "Invalid results: \(message)"
        case .cacheError(let message): return "Cache error: \(message)"
        }
    }
}

// MARK: - Cache Manager

private actor VisionCacheManager {
    private var cache: [String: ComprehensiveVisionResults] = [:]
    private let maxCacheSize = 50
    
    func getCachedResults(for image: UIImage) async -> ComprehensiveVisionResults? {
        let key = generateCacheKey(for: image)
        return cache[key]
    }
    
    func cacheResults(_ results: ComprehensiveVisionResults, for image: UIImage) async {
        let key = generateCacheKey(for: image)
        
        // Implement LRU cache eviction if needed
        if cache.count >= maxCacheSize {
            let oldestKey = cache.keys.first
            if let key = oldestKey {
                cache.removeValue(forKey: key)
            }
        }
        
        cache[key] = results
    }
    
    private func generateCacheKey(for image: UIImage) -> String {
        // Generate a simple hash based on image data
        let data = image.pngData() ?? Data()
        return String(data.hashValue)
    }
}

// MARK: - Performance Metrics

private struct VisionProcessingMetrics {
    private var analysisCount = 0
    private var totalProcessingTime: TimeInterval = 0
    private var qualityDistribution: [ProcessingQuality: Int] = [:]
    
    mutating func recordAnalysis(duration: TimeInterval, quality: ProcessingQuality) {
        analysisCount += 1
        totalProcessingTime += duration
        qualityDistribution[quality, default: 0] += 1
    }
    
    var averageProcessingTime: TimeInterval {
        return analysisCount > 0 ? totalProcessingTime / TimeInterval(analysisCount) : 0
    }
    
    var analysisPerformed: Int {
        return analysisCount
    }
}