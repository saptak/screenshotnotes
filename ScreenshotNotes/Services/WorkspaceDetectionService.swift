
import Foundation
import SwiftData
import NaturalLanguage

/// AI-powered workspace detection service that analyzes screenshots to identify potential workspaces
/// Supports 6 workspace types: travel, projects, events, learning, shopping, health
@MainActor
public class WorkspaceDetectionService: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var isProcessing = false
    @Published public var detectionProgress: Double = 0.0
    
    private let entityExtractor = EntityExtractionService()
    private let nlTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    private let languageRecognizer = NLLanguageRecognizer()
    
    // MARK: - Detection Configuration
    
    /// Minimum confidence threshold for workspace detection
    private let minConfidenceThreshold: Double = 0.65
    
    /// Minimum screenshots required for a workspace
    private let minScreenshotsPerWorkspace: Int = 2
    
    /// Maximum processing time for large collections
    private let maxProcessingTimeSeconds: TimeInterval = 30.0
    
    // MARK: - Public Interface
    
    /// Detect workspaces from a collection of screenshots
    /// - Parameter screenshots: Array of screenshots to analyze
    /// - Returns: Array of detected workspaces with confidence scores
    public func detectWorkspaces(from screenshots: [Screenshot]) async -> [ContentWorkspace] {
        guard !screenshots.isEmpty else { return [] }
        
        await MainActor.run {
            isProcessing = true
            detectionProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                detectionProgress = 1.0
            }
        }
        
        // Phase 1: Extract entities and content analysis (30% of progress)
        let analysisResults = await analyzeScreenshots(screenshots)
        await updateProgress(0.3)
        
        // Phase 2: Detect potential workspace groups (50% of progress)
        let potentialWorkspaces = await detectPotentialWorkspaces(analysisResults)
        await updateProgress(0.5)
        
        // Phase 3: Validate and refine workspaces (80% of progress)
        let validatedWorkspaces = await validateWorkspaces(potentialWorkspaces)
        await updateProgress(0.8)
        
        // Phase 4: Create final workspace objects (100% of progress)
        let finalWorkspaces = await createWorkspaces(validatedWorkspaces)
        await updateProgress(1.0)
        
        return finalWorkspaces
    }
    
    /// Suggest new workspaces based on recent screenshots
    /// - Parameter screenshots: Recent screenshots to analyze
    /// - Returns: Array of suggested workspaces
    public func suggestNewWorkspaces(from screenshots: [Screenshot]) async -> [ContentWorkspace] {
        let recentScreenshots = screenshots.filter { 
            Date().timeIntervalSince($0.timestamp) < 86400 * 7 // Last 7 days
        }
        
        guard recentScreenshots.count >= minScreenshotsPerWorkspace else { return [] }
        
        return await detectWorkspaces(from: recentScreenshots)
    }
    
    // MARK: - Private Implementation
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            detectionProgress = progress
        }
    }
    
    /// Analyze screenshots for content patterns and entities
    private func analyzeScreenshots(_ screenshots: [Screenshot]) async -> [ScreenshotAnalysis] {
        var analyses: [ScreenshotAnalysis] = []
        
        for (index, screenshot) in screenshots.enumerated() {
            let analysis = await analyzeScreenshot(screenshot)
            analyses.append(analysis)
            
            // Update progress periodically
            if index % 10 == 0 {
                let progress = Double(index) / Double(screenshots.count) * 0.3
                await updateProgress(progress)
            }
        }
        
        return analyses
    }
    
    /// Analyze individual screenshot for workspace detection signals
    private func analyzeScreenshot(_ screenshot: Screenshot) async -> ScreenshotAnalysis {
        let extractedText = screenshot.extractedText ?? ""
        
        // Extract entities using existing service
        let entityResult = await entityExtractor.extractEntities(from: extractedText)
        
        // Analyze content patterns
        let contentPatterns = analyzeContentPatterns(extractedText)
        
        // Analyze semantic tags
        let semanticSignals = analyzeSemanticSignals(screenshot)
        
        // Determine workspace type signals
        let workspaceSignals = detectWorkspaceSignals(
            text: extractedText,
            entities: entityResult.entities,
            patterns: contentPatterns,
            semantic: semanticSignals
        )
        
        return ScreenshotAnalysis(
            screenshot: screenshot,
            entities: entityResult.entities,
            contentPatterns: contentPatterns,
            semanticSignals: semanticSignals,
            workspaceSignals: workspaceSignals,
            confidence: calculateAnalysisConfidence(entityResult, contentPatterns, semanticSignals)
        )
    }
    
    /// Analyze content patterns in extracted text
    private func analyzeContentPatterns(_ text: String) -> ContentPatterns {
        let lowercased = text.lowercased()
        
        // Travel patterns
        let travelKeywords = ["flight", "hotel", "booking", "reservation", "airport", "airline", "departure", "arrival", "itinerary", "vacation", "trip"]
        let travelMatches = travelKeywords.filter { lowercased.contains($0) }
        
        // Project patterns
        let projectKeywords = ["project", "deadline", "task", "milestone", "meeting", "presentation", "report", "budget", "plan", "schedule"]
        let projectMatches = projectKeywords.filter { lowercased.contains($0) }
        
        // Event patterns
        let eventKeywords = ["event", "conference", "seminar", "workshop", "ticket", "venue", "registration", "attend", "rsvp"]
        let eventMatches = eventKeywords.filter { lowercased.contains($0) }
        
        // Learning patterns
        let learningKeywords = ["course", "class", "lesson", "assignment", "homework", "study", "exam", "grade", "university", "school"]
        let learningMatches = learningKeywords.filter { lowercased.contains($0) }
        
        // Shopping patterns
        let shoppingKeywords = ["purchase", "buy", "order", "cart", "checkout", "payment", "receipt", "invoice", "product", "shipping"]
        let shoppingMatches = shoppingKeywords.filter { lowercased.contains($0) }
        
        // Health patterns
        let healthKeywords = ["appointment", "doctor", "hospital", "clinic", "medication", "prescription", "treatment", "diagnosis", "health"]
        let healthMatches = healthKeywords.filter { lowercased.contains($0) }
        
        return ContentPatterns(
            travelSignals: travelMatches,
            projectSignals: projectMatches,
            eventSignals: eventMatches,
            learningSignals: learningMatches,
            shoppingSignals: shoppingMatches,
            healthSignals: healthMatches
        )
    }
    
    /// Analyze semantic signals from screenshot
    private func analyzeSemanticSignals(_ screenshot: Screenshot) -> SemanticSignals {
        let semanticTags = screenshot.semanticTags?.tags ?? []
        let visualAttributes = screenshot.visualAttributes
        
        // Analyze tag patterns
        let brandTags = semanticTags.filter { $0.category == .brand }
        let locationTags = semanticTags.filter { $0.category == .location }
        let organizationTags = semanticTags.filter { $0.category == .organization }
        let personTags = semanticTags.filter { $0.category == .person }
        
        // Analyze visual attributes
        let hasDocument = visualAttributes?.isDocument ?? false
        let hasSignificantText = screenshot.hasSignificantText
        let dominantColors = screenshot.dominantColors
        
        return SemanticSignals(
            brandTags: brandTags,
            locationTags: locationTags,
            organizationTags: organizationTags,
            personTags: personTags,
            isDocument: hasDocument,
            hasSignificantText: hasSignificantText,
            dominantColors: dominantColors
        )
    }
    
    /// Detect workspace type signals from analysis
    private func detectWorkspaceSignals(
        text: String,
        entities: [ExtractedEntity],
        patterns: ContentPatterns,
        semantic: SemanticSignals
    ) -> WorkspaceSignals {
        
        // Calculate confidence scores for each workspace type
        let travelConfidence = calculateTravelConfidence(entities, patterns, semantic)
        let projectConfidence = calculateProjectConfidence(entities, patterns, semantic)
        let eventConfidence = calculateEventConfidence(entities, patterns, semantic)
        let learningConfidence = calculateLearningConfidence(entities, patterns, semantic)
        let shoppingConfidence = calculateShoppingConfidence(entities, patterns, semantic)
        let healthConfidence = calculateHealthConfidence(entities, patterns, semantic)
        
        return WorkspaceSignals(
            travelConfidence: travelConfidence,
            projectConfidence: projectConfidence,
            eventConfidence: eventConfidence,
            learningConfidence: learningConfidence,
            shoppingConfidence: shoppingConfidence,
            healthConfidence: healthConfidence
        )
    }
    
    /// Calculate confidence for travel workspace detection
    private func calculateTravelConfidence(_ entities: [ExtractedEntity], _ patterns: ContentPatterns, _ semantic: SemanticSignals) -> Double {
        var confidence: Double = 0.0
        
        // Entity-based signals
        let dateEntities = entities.filter { $0.type == .date }
        let locationEntities = entities.filter { $0.type == .place }
        let organizationEntities = entities.filter { $0.type == .organization }
        
        if !dateEntities.isEmpty { confidence += 0.2 }
        if !locationEntities.isEmpty { confidence += 0.3 }
        if !organizationEntities.isEmpty { confidence += 0.2 }
        
        // Pattern-based signals
        let travelPatternStrength = min(Double(patterns.travelSignals.count) / 3.0, 1.0)
        confidence += travelPatternStrength * 0.3
        
        // Semantic signals
        if !semantic.locationTags.isEmpty { confidence += 0.1 }
        if semantic.brandTags.contains(where: { ["airline", "hotel", "booking", "expedia", "kayak"].contains($0.name.lowercased()) }) {
            confidence += 0.2
        }
        
        return min(confidence, 1.0)
    }
    
    /// Calculate confidence for project workspace detection
    private func calculateProjectConfidence(_ entities: [ExtractedEntity], _ patterns: ContentPatterns, _ semantic: SemanticSignals) -> Double {
        var confidence: Double = 0.0
        
        // Entity-based signals
        let dateEntities = entities.filter { $0.type == .date }
        let personEntities = entities.filter { $0.type == .person }
        let organizationEntities = entities.filter { $0.type == .organization }
        
        if !dateEntities.isEmpty { confidence += 0.1 }
        if !personEntities.isEmpty { confidence += 0.2 }
        if !organizationEntities.isEmpty { confidence += 0.2 }
        
        // Pattern-based signals
        let projectPatternStrength = min(Double(patterns.projectSignals.count) / 3.0, 1.0)
        confidence += projectPatternStrength * 0.4
        
        // Semantic signals
        if semantic.isDocument { confidence += 0.2 }
        if semantic.hasSignificantText { confidence += 0.1 }
        
        return min(confidence, 1.0)
    }
    
    /// Calculate confidence for event workspace detection
    private func calculateEventConfidence(_ entities: [ExtractedEntity], _ patterns: ContentPatterns, _ semantic: SemanticSignals) -> Double {
        var confidence: Double = 0.0
        
        // Entity-based signals
        let dateEntities = entities.filter { $0.type == .date }
        let locationEntities = entities.filter { $0.type == .place }
        
        if !dateEntities.isEmpty { confidence += 0.3 }
        if !locationEntities.isEmpty { confidence += 0.2 }
        
        // Pattern-based signals
        let eventPatternStrength = min(Double(patterns.eventSignals.count) / 2.0, 1.0)
        confidence += eventPatternStrength * 0.4
        
        // Semantic signals
        if !semantic.locationTags.isEmpty { confidence += 0.1 }
        
        return min(confidence, 1.0)
    }
    
    /// Calculate confidence for learning workspace detection
    private func calculateLearningConfidence(_ entities: [ExtractedEntity], _ patterns: ContentPatterns, _ semantic: SemanticSignals) -> Double {
        var confidence: Double = 0.0
        
        // Pattern-based signals
        let learningPatternStrength = min(Double(patterns.learningSignals.count) / 3.0, 1.0)
        confidence += learningPatternStrength * 0.6
        
        // Semantic signals
        if semantic.isDocument { confidence += 0.2 }
        if semantic.hasSignificantText { confidence += 0.1 }
        if !semantic.organizationTags.isEmpty { confidence += 0.1 }
        
        return min(confidence, 1.0)
    }
    
    /// Calculate confidence for shopping workspace detection
    private func calculateShoppingConfidence(_ entities: [ExtractedEntity], _ patterns: ContentPatterns, _ semantic: SemanticSignals) -> Double {
        var confidence: Double = 0.0
        
        // Entity-based signals
        let moneyEntities = entities.filter { $0.type == .currency }
        if !moneyEntities.isEmpty { confidence += 0.3 }
        
        // Pattern-based signals
        let shoppingPatternStrength = min(Double(patterns.shoppingSignals.count) / 3.0, 1.0)
        confidence += shoppingPatternStrength * 0.5
        
        // Semantic signals
        if semantic.brandTags.contains(where: { ["amazon", "ebay", "walmart", "target", "shop"].contains($0.name.lowercased()) }) {
            confidence += 0.2
        }
        
        return min(confidence, 1.0)
    }
    
    /// Calculate confidence for health workspace detection
    private func calculateHealthConfidence(_ entities: [ExtractedEntity], _ patterns: ContentPatterns, _ semantic: SemanticSignals) -> Double {
        var confidence: Double = 0.0
        
        // Entity-based signals
        let dateEntities = entities.filter { $0.type == .date }
        let personEntities = entities.filter { $0.type == .person }
        
        if !dateEntities.isEmpty { confidence += 0.2 }
        if !personEntities.isEmpty { confidence += 0.2 }
        
        // Pattern-based signals
        let healthPatternStrength = min(Double(patterns.healthSignals.count) / 3.0, 1.0)
        confidence += healthPatternStrength * 0.4
        
        // Semantic signals
        if semantic.isDocument { confidence += 0.1 }
        if !semantic.organizationTags.isEmpty { confidence += 0.1 }
        
        return min(confidence, 1.0)
    }
    
    /// Calculate overall analysis confidence
    private func calculateAnalysisConfidence(_ entityResult: EntityExtractionResult, _ patterns: ContentPatterns, _ semantic: SemanticSignals) -> Double {
        var confidence: Double = 0.0
        
        // Entity extraction confidence
        confidence += entityResult.overallConfidence.rawValue * 0.3
        
        // Pattern detection confidence
        let totalPatterns = patterns.travelSignals.count + patterns.projectSignals.count + patterns.eventSignals.count + patterns.learningSignals.count + patterns.shoppingSignals.count + patterns.healthSignals.count
        confidence += min(Double(totalPatterns) / 5.0, 1.0) * 0.4
        
        // Semantic analysis confidence
        let totalSemanticSignals = semantic.brandTags.count + semantic.locationTags.count + semantic.organizationTags.count + semantic.personTags.count
        confidence += min(Double(totalSemanticSignals) / 3.0, 1.0) * 0.3
        
        return min(confidence, 1.0)
    }
    
    /// Detect potential workspaces from analysis results
    private func detectPotentialWorkspaces(_ analyses: [ScreenshotAnalysis]) async -> [PotentialWorkspace] {
        var potentialWorkspaces: [PotentialWorkspace] = []
        
        // Group analyses by workspace type confidence
        let workspaceGroups = groupAnalysesByWorkspaceType(analyses)
        
        // Create potential workspaces for each group
        for (workspaceType, groupedAnalyses) in workspaceGroups {
            let workspace = createPotentialWorkspace(type: workspaceType, analyses: groupedAnalyses)
            if workspace.confidence >= minConfidenceThreshold {
                potentialWorkspaces.append(workspace)
            }
        }
        
        return potentialWorkspaces
    }
    
    /// Group analyses by dominant workspace type
    private func groupAnalysesByWorkspaceType(_ analyses: [ScreenshotAnalysis]) -> [ContentWorkspace.WorkspaceType: [ScreenshotAnalysis]] {
        var groups: [ContentWorkspace.WorkspaceType: [ScreenshotAnalysis]] = [:]
        
        for analysis in analyses {
            let signals = analysis.workspaceSignals
            let dominantType = findDominantWorkspaceType(signals)
            
            if let type = dominantType {
                groups[type, default: []].append(analysis)
            }
        }
        
        // Filter groups by minimum screenshot count
        return Dictionary(uniqueKeysWithValues: groups.filter { $0.value.count >= minScreenshotsPerWorkspace })
    }
    
    /// Find dominant workspace type from signals
    private func findDominantWorkspaceType(_ signals: WorkspaceSignals) -> ContentWorkspace.WorkspaceType? {
        let confidences = [
            (signals.travelConfidence, "travel"),
            (signals.projectConfidence, "project"),
            (signals.eventConfidence, "event"),
            (signals.learningConfidence, "learning"),
            (signals.shoppingConfidence, "shopping"),
            (signals.healthConfidence, "health")
        ]
        
        let maxConfidence = confidences.max { $0.0 < $1.0 }
        
        guard let max = maxConfidence, max.0 >= minConfidenceThreshold else { return nil }
        
        switch max.1 {
        case "travel":
            return .travel(destination: "Unknown", dates: DateInterval(start: Date(), duration: 86400))
        case "project":
            return .project(name: "Unknown Project", status: .active)
        case "event":
            return .event(title: "Unknown Event", date: Date())
        case "learning":
            return .learning(subject: "Unknown Subject", progress: 0.0)
        case "shopping":
            return .shopping(category: "Unknown Category", budget: nil)
        case "health":
            return .health(category: "Unknown Category", provider: nil)
        default:
            return nil
        }
    }
    
    /// Create potential workspace from grouped analyses
    private func createPotentialWorkspace(type: ContentWorkspace.WorkspaceType, analyses: [ScreenshotAnalysis]) -> PotentialWorkspace {
        let screenshots = analyses.map { $0.screenshot }
        let averageConfidence = analyses.reduce(0.0) { $0 + $1.confidence } / Double(analyses.count)
        
        // Refine workspace type based on analysis content
        let refinedType = refineWorkspaceType(type, analyses: analyses)
        
        return PotentialWorkspace(
            type: refinedType,
            screenshots: screenshots,
            confidence: averageConfidence,
            analyses: analyses
        )
    }
    
    /// Refine workspace type based on detailed analysis
    private func refineWorkspaceType(_ type: ContentWorkspace.WorkspaceType, analyses: [ScreenshotAnalysis]) -> ContentWorkspace.WorkspaceType {
        let allEntities = analyses.flatMap { $0.entities }
        let allPatterns = analyses.map { $0.contentPatterns }
        
        switch type {
        case .travel:
            let destinations = allEntities.filter { $0.type == .place }.map { $0.normalizedValue }
            let destination = destinations.first ?? "Unknown Destination"
            
            let dates = allEntities.filter { $0.type == .date }
            let dateInterval = createDateInterval(from: dates)
            
            return .travel(destination: destination, dates: dateInterval)
            
        case .project:
            let projectNames = allPatterns.flatMap { $0.projectSignals }
            let projectName = projectNames.first?.capitalized ?? "Unknown Project"
            
            return .project(name: projectName, status: .active)
            
        case .event:
            let eventNames = allPatterns.flatMap { $0.eventSignals }
            let eventName = eventNames.first?.capitalized ?? "Unknown Event"
            
            let dates = allEntities.filter { $0.type == .date }
            let eventDate = dates.first?.dateValue ?? Date()
            
            return .event(title: eventName, date: eventDate)
            
        case .learning:
            let subjects = allPatterns.flatMap { $0.learningSignals }
            let subject = subjects.first?.capitalized ?? "Unknown Subject"
            
            return .learning(subject: subject, progress: 0.0)
            
        case .shopping:
            let categories = allPatterns.flatMap { $0.shoppingSignals }
            let category = categories.first?.capitalized ?? "Unknown Category"
            
            let budgets = allEntities.filter { $0.type == .currency }.compactMap { Double($0.normalizedValue) }
            let budget = budgets.first
            
            return .shopping(category: category, budget: budget)
            
        case .health:
            let categories = allPatterns.flatMap { $0.healthSignals }
            let category = categories.first?.capitalized ?? "Unknown Category"
            
            let providers = allEntities.filter { $0.type == .organization }.map { $0.normalizedValue }
            let provider = providers.first
            
            return .health(category: category, provider: provider)
            
        default:
            return type
        }
    }
    
    /// Create date interval from date entities
    private func createDateInterval(from dates: [ExtractedEntity]) -> DateInterval {
        let dateValues = dates.compactMap { $0.dateValue }
        
        if dateValues.isEmpty {
            return DateInterval(start: Date(), duration: 86400)
        }
        
        let sortedDates = dateValues.sorted()
        let start = sortedDates.first ?? Date()
        let end = sortedDates.last ?? Date()
        
        return DateInterval(start: start, end: end)
    }
    
    /// Validate and refine potential workspaces
    private func validateWorkspaces(_ potentialWorkspaces: [PotentialWorkspace]) async -> [PotentialWorkspace] {
        var validatedWorkspaces: [PotentialWorkspace] = []
        
        for workspace in potentialWorkspaces {
            // Additional validation logic
            if workspace.confidence >= minConfidenceThreshold &&
               workspace.screenshots.count >= minScreenshotsPerWorkspace {
                validatedWorkspaces.append(workspace)
            }
        }
        
        // Remove overlapping workspaces
        return removeDuplicateWorkspaces(validatedWorkspaces)
    }
    
    /// Remove duplicate or overlapping workspaces
    private func removeDuplicateWorkspaces(_ workspaces: [PotentialWorkspace]) -> [PotentialWorkspace] {
        var uniqueWorkspaces: [PotentialWorkspace] = []
        
        for workspace in workspaces {
            let hasOverlap = uniqueWorkspaces.contains { existing in
                let sharedScreenshots = Set(workspace.screenshots.map { $0.id })
                    .intersection(Set(existing.screenshots.map { $0.id }))
                return sharedScreenshots.count > workspace.screenshots.count / 2
            }
            
            if !hasOverlap {
                uniqueWorkspaces.append(workspace)
            }
        }
        
        return uniqueWorkspaces
    }
    
    /// Create final workspace objects
    private func createWorkspaces(_ potentialWorkspaces: [PotentialWorkspace]) async -> [ContentWorkspace] {
        var workspaces: [ContentWorkspace] = []
        
        for potential in potentialWorkspaces {
            let workspace = ContentWorkspace(
                title: potential.type.displayName,
                type: potential.type,
                screenshots: potential.screenshots,
                detectionConfidence: potential.confidence
            )
            
            workspace.updateProgress()
            workspaces.append(workspace)
        }
        
        return workspaces
    }
}

// MARK: - Supporting Data Structures

/// Analysis result for a single screenshot
private struct ScreenshotAnalysis {
    let screenshot: Screenshot
    let entities: [ExtractedEntity]
    let contentPatterns: ContentPatterns
    let semanticSignals: SemanticSignals
    let workspaceSignals: WorkspaceSignals
    let confidence: Double
}

/// Content patterns detected in text
private struct ContentPatterns {
    let travelSignals: [String]
    let projectSignals: [String]
    let eventSignals: [String]
    let learningSignals: [String]
    let shoppingSignals: [String]
    let healthSignals: [String]
}

/// Semantic signals from tags and visual analysis
private struct SemanticSignals {
    let brandTags: [SemanticTag]
    let locationTags: [SemanticTag]
    let organizationTags: [SemanticTag]
    let personTags: [SemanticTag]
    let isDocument: Bool
    let hasSignificantText: Bool
    let dominantColors: [DominantColor]
}

/// Workspace type confidence signals
private struct WorkspaceSignals {
    let travelConfidence: Double
    let projectConfidence: Double
    let eventConfidence: Double
    let learningConfidence: Double
    let shoppingConfidence: Double
    let healthConfidence: Double
}

/// Potential workspace before final creation
private struct PotentialWorkspace {
    let type: ContentWorkspace.WorkspaceType
    let screenshots: [Screenshot]
    let confidence: Double
    let analyses: [ScreenshotAnalysis]
}

// MARK: - Extensions

extension ExtractedEntity {
    var dateValue: Date? {
        guard type == .date else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter.date(from: normalizedValue)
    }
}

extension EntityConfidence {
    public var rawValue: Double {
        switch self {
        case .veryHigh: return 0.95
        case .high: return 0.85
        case .medium: return 0.70
        case .low: return 0.55
        case .veryLow: return 0.30
        }
    }
}
