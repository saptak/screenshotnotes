import Foundation
import SwiftData
import SwiftUI
import Vision
import OSLog

/// Advanced duplicate detection service using visual similarity, content analysis, and metadata comparison
/// Provides intelligent duplicate identification with configurable sensitivity levels
@MainActor
public final class DuplicateDetectionService: ObservableObject {
    public static let shared = DuplicateDetectionService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "DuplicateDetection")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var analysisProgress: Double = 0.0
    @Published public private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published public private(set) var lastAnalysisDate: Date?
    
    // MARK: - Configuration
    
    public struct DetectionSettings {
        var visualSimilarityThreshold: Double = 0.85     // High threshold for visual similarity
        var contentSimilarityThreshold: Double = 0.90    // Very high threshold for content similarity
        var timestampToleranceSeconds: TimeInterval = 5  // Screenshots within 5 seconds
        var enableFilenameComparison: Bool = true
        var enableSizeComparison: Bool = true
        var sizeDifferenceThreshold: Double = 0.05       // 5% size difference tolerance
        var minimumConfidenceScore: Double = 0.75        // Minimum confidence to consider a duplicate
        
        public init() {}
    }
    
    @Published public var settings = DetectionSettings()
    
    // MARK: - Services
    
    private let visualSimilarityService = VisualSimilarityIndexService.shared
    private let hapticService = HapticFeedbackService.shared
    private let errorService = ErrorHandlingService.shared
    
    private init() {
        logger.info("DuplicateDetectionService initialized with advanced detection algorithms")
    }
    
    // MARK: - Duplicate Group Model
    
    public struct DuplicateGroup: Identifiable, Hashable {
        public let id = UUID()
        public let screenshots: [Screenshot]
        public let confidence: Double
        public let duplicateType: DuplicateType
        public let detectionReason: String
        public let suggestedAction: SuggestedAction
        
        public var primaryScreenshot: Screenshot {
            // Return the earliest screenshot as primary
            screenshots.min(by: { $0.timestamp < $1.timestamp }) ?? screenshots[0]
        }
        
        public var duplicateScreenshots: [Screenshot] {
            screenshots.filter { $0.id != primaryScreenshot.id }
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        public static func == (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    public enum DuplicateType: String, CaseIterable {
        case exact = "exact"                    // Identical images
        case visualSimilar = "visual_similar"   // Visually very similar
        case contentSimilar = "content_similar" // Same text content
        case sequential = "sequential"          // Sequential screenshots
        case nearDuplicate = "near_duplicate"   // Minor variations
        
        public var displayName: String {
            switch self {
            case .exact:
                return "Exact Duplicates"
            case .visualSimilar:
                return "Visually Similar"
            case .contentSimilar:
                return "Same Content"
            case .sequential:
                return "Sequential Screenshots"
            case .nearDuplicate:
                return "Near Duplicates"
            }
        }
        
        public var priority: Int {
            switch self {
            case .exact: return 1
            case .contentSimilar: return 2
            case .sequential: return 3
            case .visualSimilar: return 4
            case .nearDuplicate: return 5
            }
        }
    }
    
    public enum SuggestedAction: String, CaseIterable {
        case deleteAll = "delete_all"           // Delete all duplicates, keep original
        case keepLatest = "keep_latest"         // Keep most recent, delete others
        case keepLargest = "keep_largest"       // Keep highest quality, delete others
        case review = "review"                  // Manual review recommended
        case merge = "merge"                    // Combine information
        
        public var displayName: String {
            switch self {
            case .deleteAll:
                return "Delete Duplicates"
            case .keepLatest:
                return "Keep Latest"
            case .keepLargest:
                return "Keep Best Quality"
            case .review:
                return "Review Manually"
            case .merge:
                return "Merge Information"
            }
        }
        
        public var systemImage: String {
            switch self {
            case .deleteAll:
                return "trash.circle"
            case .keepLatest:
                return "clock.arrow.circlepath"
            case .keepLargest:
                return "arrow.up.circle"
            case .review:
                return "eye.circle"
            case .merge:
                return "arrow.triangle.merge"
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Analyze all screenshots for duplicates using advanced detection algorithms
    public func analyzeForDuplicates(in modelContext: ModelContext) async {
        guard !isAnalyzing else { return }
        
        logger.info("Starting comprehensive duplicate analysis")
        isAnalyzing = true
        analysisProgress = 0.0
        duplicateGroups = []
        
        defer {
            isAnalyzing = false
            analysisProgress = 0.0
            lastAnalysisDate = Date()
        }
        
        do {
            // Fetch all screenshots
            let fetchRequest = FetchDescriptor<Screenshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            let screenshots = try modelContext.fetch(fetchRequest)
            
            guard screenshots.count >= 2 else {
                logger.info("Insufficient screenshots for duplicate analysis")
                return
            }
            
            logger.info("Analyzing \\(screenshots.count) screenshots for duplicates")
            
            // Progress tracking
            let totalSteps = 5
            var currentStep = 0
            
            // Step 1: Exact duplicates (file size + hash comparison)
            currentStep += 1
            await updateProgress(Double(currentStep) / Double(totalSteps) * 0.2)
            let exactDuplicates = await detectExactDuplicates(screenshots)
            duplicateGroups.append(contentsOf: exactDuplicates)
            
            // Step 2: Sequential screenshots
            currentStep += 1
            await updateProgress(Double(currentStep) / Double(totalSteps) * 0.4)
            let sequentialDuplicates = await detectSequentialDuplicates(screenshots)
            duplicateGroups.append(contentsOf: sequentialDuplicates)
            
            // Step 3: Content-based duplicates (OCR similarity)
            currentStep += 1
            await updateProgress(Double(currentStep) / Double(totalSteps) * 0.6)
            let contentDuplicates = await detectContentDuplicates(screenshots)
            duplicateGroups.append(contentsOf: contentDuplicates)
            
            // Step 4: Visual similarity duplicates
            currentStep += 1
            await updateProgress(Double(currentStep) / Double(totalSteps) * 0.8)
            let visualDuplicates = await detectVisualDuplicates(screenshots)
            duplicateGroups.append(contentsOf: visualDuplicates)
            
            // Step 5: Remove overlaps and sort by priority
            currentStep += 1
            await updateProgress(1.0)
            duplicateGroups = await consolidateDuplicateGroups(duplicateGroups)
            
            logger.info("Duplicate analysis complete: Found \\(duplicateGroups.count) duplicate groups")
            
            // Provide haptic feedback for analysis completion
            if duplicateGroups.count > 0 {
                hapticService.triggerContextualFeedback(
                    for: .duplicateDetection,
                    isSuccess: true,
                    itemCount: duplicateGroups.count
                )
            }
            
        } catch {
            logger.error("Failed to analyze duplicates: \\(error.localizedDescription)")
            let appError = ErrorHandlingService.AppError.duplicateOperationError("Duplicate analysis failed: \\(error.localizedDescription)")
            Task {
                await errorService.handleError(appError, context: "Duplicate Analysis")
            }
        }
    }
    
    /// Get quick duplicate detection results for a specific screenshot
    public func findSimilarScreenshots(to target: Screenshot, in screenshots: [Screenshot]) async -> [Screenshot] {
        var similar: [Screenshot] = []
        
        // Quick visual similarity check
        for screenshot in screenshots {
            guard screenshot.id != target.id else { continue }
            
            if await visualSimilarityService.areVisuallySimilar(target, screenshot) {
                similar.append(screenshot)
            }
        }
        
        return similar
    }
    
    /// Execute suggested action for a duplicate group
    public func executeSuggestedAction(
        for group: DuplicateGroup,
        in modelContext: ModelContext
    ) async -> Bool {
        logger.info("Executing \\(group.suggestedAction.rawValue) for duplicate group with \\(group.screenshots.count) screenshots")
        
        switch group.suggestedAction {
        case .deleteAll:
            return await deleteScreenshots(group.duplicateScreenshots, in: modelContext)
            
        case .keepLatest:
            let latest = group.screenshots.max(by: { $0.timestamp < $1.timestamp })
            let toDelete = group.screenshots.filter { $0.id != latest?.id }
            return await deleteScreenshots(toDelete, in: modelContext)
            
        case .keepLargest:
            let largest = group.screenshots.max(by: { $0.imageData.count < $1.imageData.count })
            let toDelete = group.screenshots.filter { $0.id != largest?.id }
            return await deleteScreenshots(toDelete, in: modelContext)
            
        case .merge:
            return await mergeScreenshotInformation(group.screenshots, in: modelContext)
            
        case .review:
            // No automatic action - user needs to review manually
            return true
        }
    }
    
    // MARK: - Detection Algorithms
    
    /// Detect exact duplicates using file size and data comparison
    private func detectExactDuplicates(_ screenshots: [Screenshot]) async -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        var sizeGroups: [Int: [Screenshot]] = [:]
        
        // Group by file size first for efficiency
        for screenshot in screenshots {
            let size = screenshot.imageData.count
            sizeGroups[size, default: []].append(screenshot)
        }
        
        // Check exact matches within each size group
        for (_, sizeGroup) in sizeGroups {
            guard sizeGroup.count >= 2 else { continue }
            
            var processed: Set<UUID> = []
            
            for i in 0..<sizeGroup.count {
                guard !processed.contains(sizeGroup[i].id) else { continue }
                
                var exactMatches = [sizeGroup[i]]
                processed.insert(sizeGroup[i].id)
                
                for j in (i+1)..<sizeGroup.count {
                    guard !processed.contains(sizeGroup[j].id) else { continue }
                    
                    if sizeGroup[i].imageData == sizeGroup[j].imageData {
                        exactMatches.append(sizeGroup[j])
                        processed.insert(sizeGroup[j].id)
                    }
                }
                
                if exactMatches.count >= 2 {
                    let group = DuplicateGroup(
                        screenshots: exactMatches,
                        confidence: 1.0,
                        duplicateType: .exact,
                        detectionReason: "Identical file data detected",
                        suggestedAction: .deleteAll
                    )
                    groups.append(group)
                }
            }
        }
        
        return groups
    }
    
    /// Detect sequential screenshots (same app, consecutive timestamps)
    private func detectSequentialDuplicates(_ screenshots: [Screenshot]) async -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        let sortedScreenshots = screenshots.sorted(by: { $0.timestamp < $1.timestamp })
        
        var currentSequence: [Screenshot] = []
        var lastTimestamp: Date?
        
        for screenshot in sortedScreenshots {
            if let lastTime = lastTimestamp,
               screenshot.timestamp.timeIntervalSince(lastTime) <= settings.timestampToleranceSeconds {
                currentSequence.append(screenshot)
            } else {
                // Process completed sequence
                if currentSequence.count >= 3 { // At least 3 for sequential duplicates
                    let group = DuplicateGroup(
                        screenshots: currentSequence,
                        confidence: 0.85,
                        duplicateType: .sequential,
                        detectionReason: "Sequential screenshots within \\(Int(settings.timestampToleranceSeconds)) seconds",
                        suggestedAction: .keepLatest
                    )
                    groups.append(group)
                }
                
                // Start new sequence
                currentSequence = [screenshot]
            }
            
            lastTimestamp = screenshot.timestamp
        }
        
        // Handle final sequence
        if currentSequence.count >= 3 {
            let group = DuplicateGroup(
                screenshots: currentSequence,
                confidence: 0.85,
                duplicateType: .sequential,
                detectionReason: "Sequential screenshots within \\(Int(settings.timestampToleranceSeconds)) seconds",
                suggestedAction: .keepLatest
            )
            groups.append(group)
        }
        
        return groups
    }
    
    /// Detect content-based duplicates using OCR similarity
    private func detectContentDuplicates(_ screenshots: [Screenshot]) async -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        
        // Filter screenshots with OCR text
        let screenshotsWithText = screenshots.compactMap { screenshot -> (Screenshot, String)? in
            guard let text = screenshot.extractedText,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return (screenshot, text.lowercased())
        }
        
        guard screenshotsWithText.count >= 2 else { return groups }
        
        var processed: Set<UUID> = []
        
        for i in 0..<screenshotsWithText.count {
            guard !processed.contains(screenshotsWithText[i].0.id) else { continue }
            
            var similarScreenshots = [screenshotsWithText[i].0]
            let baseText = screenshotsWithText[i].1
            processed.insert(screenshotsWithText[i].0.id)
            
            for j in (i+1)..<screenshotsWithText.count {
                guard !processed.contains(screenshotsWithText[j].0.id) else { continue }
                
                let similarity = calculateTextSimilarity(baseText, screenshotsWithText[j].1)
                
                if similarity >= settings.contentSimilarityThreshold {
                    similarScreenshots.append(screenshotsWithText[j].0)
                    processed.insert(screenshotsWithText[j].0.id)
                }
            }
            
            if similarScreenshots.count >= 2 {
                let confidence = min(0.95, 0.7 + (Double(similarScreenshots.count) * 0.05))
                let group = DuplicateGroup(
                    screenshots: similarScreenshots,
                    confidence: confidence,
                    duplicateType: .contentSimilar,
                    detectionReason: "Identical or very similar text content detected",
                    suggestedAction: .review
                )
                groups.append(group)
            }
        }
        
        return groups
    }
    
    /// Detect visual duplicates using the visual similarity service
    private func detectVisualDuplicates(_ screenshots: [Screenshot]) async -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        
        // Use existing visual similarity service for efficient detection
        let visualGroups = await visualSimilarityService.findVisualSimilarityGroups(
            from: screenshots,
            in: screenshots.first?.modelContext ?? ModelContext(try! ModelContainer(for: Screenshot.self))
        )
        
        for visualGroup in visualGroups {
            guard visualGroup.count >= 2 else { continue }
            
            // Calculate confidence based on group size and similarity
            let confidence = min(0.90, settings.visualSimilarityThreshold + (Double(visualGroup.count - 2) * 0.02))
            
            let group = DuplicateGroup(
                screenshots: visualGroup,
                confidence: confidence,
                duplicateType: .visualSimilar,
                detectionReason: "High visual similarity detected using indexed features",
                suggestedAction: visualGroup.count >= 4 ? .keepLargest : .review
            )
            groups.append(group)
        }
        
        return groups
    }
    
    // MARK: - Helper Methods
    
    /// Calculate text similarity using Jaccard similarity
    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.split(separator: " ").map(String.init))
        let words2 = Set(text2.split(separator: " ").map(String.init))
        
        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }
    
    /// Consolidate duplicate groups to remove overlaps
    private func consolidateDuplicateGroups(_ groups: [DuplicateGroup]) async -> [DuplicateGroup] {
        var consolidatedGroups: [DuplicateGroup] = []
        var processedScreenshots: Set<UUID> = []
        
        // Sort by priority (exact duplicates first, then by confidence)
        let sortedGroups = groups.sorted { group1, group2 in
            if group1.duplicateType.priority != group2.duplicateType.priority {
                return group1.duplicateType.priority < group2.duplicateType.priority
            }
            return group1.confidence > group2.confidence
        }
        
        for group in sortedGroups {
            // Check if any screenshots in this group are already processed
            let newScreenshots = group.screenshots.filter { !processedScreenshots.contains($0.id) }
            
            if newScreenshots.count >= 2 {
                // Create new group with unprocessed screenshots
                let newGroup = DuplicateGroup(
                    screenshots: newScreenshots,
                    confidence: group.confidence,
                    duplicateType: group.duplicateType,
                    detectionReason: group.detectionReason,
                    suggestedAction: group.suggestedAction
                )
                consolidatedGroups.append(newGroup)
                
                // Mark screenshots as processed
                for screenshot in newScreenshots {
                    processedScreenshots.insert(screenshot.id)
                }
            }
        }
        
        return consolidatedGroups
    }
    
    /// Delete screenshots from model context
    private func deleteScreenshots(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> Bool {
        do {
            for screenshot in screenshots {
                modelContext.delete(screenshot)
            }
            try modelContext.save()
            logger.info("Successfully deleted \\(screenshots.count) duplicate screenshots")
            return true
        } catch {
            logger.error("Failed to delete screenshots: \\(error.localizedDescription)")
            return false
        }
    }
    
    /// Merge information from multiple screenshots
    private func mergeScreenshotInformation(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> Bool {
        guard let primary = screenshots.first else { return false }
        
        var allTags: [String] = primary.userTags ?? []
        var allNotes: [String] = []
        
        if let notes = primary.userNotes, !notes.isEmpty {
            allNotes.append(notes)
        }
        
        // Collect information from other screenshots
        for screenshot in screenshots.dropFirst() {
            if let tags = screenshot.userTags {
                for tag in tags {
                    if !allTags.contains(tag) {
                        allTags.append(tag)
                    }
                }
            }
            
            if let notes = screenshot.userNotes, !notes.isEmpty {
                allNotes.append(notes)
            }
        }
        
        // Update primary screenshot with merged information
        primary.userTags = allTags.isEmpty ? nil : allTags
        primary.userNotes = allNotes.isEmpty ? nil : allNotes.joined(separator: "\\n\\n")
        
        // Delete the other screenshots
        let toDelete = Array(screenshots.dropFirst())
        return await deleteScreenshots(toDelete, in: modelContext)
    }
    
    /// Update analysis progress
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            analysisProgress = max(0.0, min(1.0, progress))
        }
    }
}

// MARK: - Duplicate Analysis Results View

public struct DuplicateAnalysisResultsView: View {
    @StateObject private var duplicateService = DuplicateDetectionService.shared
    @Environment(\.modelContext) private var modelContext
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if duplicateService.isAnalyzing {
                    analysisProgressView
                } else if duplicateService.duplicateGroups.isEmpty {
                    emptyStateView
                } else {
                    duplicateGroupsList
                }
            }
            .navigationTitle("Duplicate Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Analyze") {
                        Task {
                            await duplicateService.analyzeForDuplicates(in: modelContext)
                        }
                    }
                    .disabled(duplicateService.isAnalyzing)
                }
            }
        }
    }
    
    private var analysisProgressView: some View {
        VStack(spacing: 20) {
            ProgressView(value: duplicateService.analysisProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(y: 2.0)
            
            Text("Analyzing screenshots for duplicates...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("No Duplicates Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your screenshot collection looks clean!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if duplicateService.lastAnalysisDate != nil {
                Text("Last analyzed: \\(duplicateService.lastAnalysisDate!, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(40)
    }
    
    private var duplicateGroupsList: some View {
        List {
            ForEach(duplicateService.duplicateGroups, id: \.id) { group in
                DuplicateGroupRowView(group: group, modelContext: modelContext)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

// MARK: - Duplicate Group Row View

private struct DuplicateGroupRowView: View {
    let group: DuplicateDetectionService.DuplicateGroup
    let modelContext: ModelContext
    @StateObject private var duplicateService = DuplicateDetectionService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.duplicateType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(group.detectionReason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\\(Int(group.confidence * 100))% confidence")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text("\\(group.screenshots.count) screenshots")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Screenshot thumbnails
            LazyHGrid(rows: [GridItem(.flexible())], spacing: 8) {
                ForEach(Array(group.screenshots.prefix(4)), id: \.id) { screenshot in
                    if let image = UIImage(data: screenshot.imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
                
                if group.screenshots.count > 4 {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text("+\\(group.screenshots.count - 4)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        )
                }
            }
            
            // Action button
            HStack {
                Button(action: {
                    Task {
                        await duplicateService.executeSuggestedAction(for: group, in: modelContext)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: group.suggestedAction.systemImage)
                            .font(.caption)
                        Text(group.suggestedAction.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}