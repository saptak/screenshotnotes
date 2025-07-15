import Foundation
import SwiftData
import SwiftUI
import Vision
import UIKit
import OSLog

/// Service for automatically grouping related screenshots using intelligent algorithms
/// Optimized for performance with background processing and batching
public final class SmartGroupingService: ObservableObject {
    public static let shared = SmartGroupingService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "SmartGrouping")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isProcessing = false
    @Published public private(set) var processingProgress: Double = 0.0
    @Published public private(set) var lastGroupingUpdate: Date?
    @Published public private(set) var groupingStatistics: GroupStatistics?
    
    // MARK: - Configuration
    
    private let sequenceTimeWindow: TimeInterval = 300 // 5 minutes
    private let contentSimilarityThreshold: Double = 0.8
    private let visualSimilarityThreshold: Double = 0.75
    private let projectDetectionTimeWindow: TimeInterval = 86400 // 24 hours
    private let minGroupSize: Int = 2
    private let maxGroupSize: Int = 50
    private let batchSize: Int = 10 // Process screenshots in batches to avoid blocking
    
    // MARK: - Services
    
    private let ocrService = OCRService()
    // Visual similarity service reference removed for performance optimizations
    
    // MARK: - Cancellation Support
    
    private var currentTask: Task<Void, Never>?
    
    private init() {
        logger.info("SmartGroupingService initialized with performance optimizations")
    }
    
    // MARK: - Main Grouping Interface
    
    /// Analyze and group all screenshots in the provided context with performance optimization
    @MainActor
    public func analyzeAndGroupScreenshots(in modelContext: ModelContext) async {
        logger.info("Starting optimized screenshot grouping analysis")
        
        guard !isProcessing else {
            logger.warning("Grouping analysis already in progress")
            return
        }
        
        // Cancel any existing task
        currentTask?.cancel()
        
        // Start new task
        currentTask = Task { @MainActor in
            await performGroupingAnalysis(in: modelContext)
        }
        
        await currentTask?.value
    }
    
    /// Cancel ongoing grouping analysis
    @MainActor
    public func cancelGroupingAnalysis() {
        currentTask?.cancel()
        isProcessing = false
        processingProgress = 0.0
        logger.info("Grouping analysis cancelled")
    }
    
    /// Internal method that performs the actual grouping analysis
    @MainActor
    private func performGroupingAnalysis(in modelContext: ModelContext) async {
        isProcessing = true
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            processingProgress = 0.0
            lastGroupingUpdate = Date()
        }
        
        do {
            // Fetch all screenshots
            let fetchRequest = FetchDescriptor<Screenshot>(
                sortBy: [SortDescriptor(\Screenshot.timestamp, order: .forward)]
            )
            let screenshots = try modelContext.fetch(fetchRequest)
            
            guard !screenshots.isEmpty else {
                logger.info("No screenshots to group")
                return
            }
            
            logger.info("Analyzing \(screenshots.count) screenshots for grouping (optimized)")
            
            // Remove existing automatic groups (keep user-created groups)
            await removeAutomaticGroups(in: modelContext)
            
            // Check for cancellation
            guard !Task.isCancelled else { return }
            
            // Step 1: Sequence Detection (40% of progress) - Fast algorithm
            await updateProgress(0.1)
            let sequenceGroups = await detectSequenceGroups(screenshots, in: modelContext)
            logger.info("Created \(sequenceGroups.count) sequence groups")
            
            guard !Task.isCancelled else { return }
            
            // Step 2: Content Similarity (60% of progress) - Optimized with batching
            await updateProgress(0.4)
            let contentGroups = await detectContentSimilarityGroups(screenshots, in: modelContext)
            logger.info("Created \(contentGroups.count) content similarity groups")
            
            guard !Task.isCancelled else { return }
            
            // Step 3: Merge and optimize groups
            await updateProgress(0.9)
            let allGroups = sequenceGroups + contentGroups
            let optimizedGroups = await optimizeGroups(allGroups, in: modelContext)
            logger.info("Optimized to \(optimizedGroups.count) final groups")
            
            guard !Task.isCancelled else { return }
            
            // Step 4: Calculate statistics
            await updateProgress(1.0)
            let statistics = GroupStatistics(groups: optimizedGroups, totalScreenshots: screenshots.count)
            
            groupingStatistics = statistics
            
            logger.info("Optimized grouping analysis completed successfully")
            
        } catch {
            logger.error("Error during grouping analysis: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sequence Detection
    
    /// Detect screenshot sequences based on timestamps and app continuity (Optimized)
    private func detectSequenceGroups(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> [ScreenshotGroup] {
        var groups: [ScreenshotGroup] = []
        var currentSequence: [Screenshot] = []
        var lastTimestamp: Date?
        var lastAppName: String?
        
        // Process screenshots in batches to allow for cancellation and progress updates
        let batchCount = (screenshots.count + batchSize - 1) / batchSize
        var processedCount = 0
        
        for batchIndex in 0..<batchCount {
            guard !Task.isCancelled else { break }
            
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, screenshots.count)
            let batch = Array(screenshots[startIndex..<endIndex])
            
            for screenshot in batch {
                guard !Task.isCancelled else { break }
                
                // Extract app name efficiently (cached if available)
                let appName = await extractAppNameOptimized(from: screenshot)
                
                defer {
                    lastTimestamp = screenshot.timestamp
                    lastAppName = appName
                }
                
                // Check if this screenshot continues the current sequence
                if let lastTime = lastTimestamp,
                   let lastApp = lastAppName,
                   screenshot.timestamp.timeIntervalSince(lastTime) <= sequenceTimeWindow,
                   appName == lastApp {
                    
                    // Continue current sequence
                    currentSequence.append(screenshot)
                } else {
                    // End current sequence if it's long enough
                    if currentSequence.count >= minGroupSize {
                        let group = await createSequenceGroup(from: currentSequence, in: modelContext)
                        groups.append(group)
                    }
                    
                    // Start new sequence
                    currentSequence = [screenshot]
                }
                
                processedCount += 1
            }
            
            // Update progress after each batch
            let progress = 0.1 + (Double(processedCount) / Double(screenshots.count)) * 0.3
            await updateProgress(progress)
            
            // Yield control to allow UI updates
            await Task.yield()
        }
        
        // Handle final sequence
        if currentSequence.count >= minGroupSize && !Task.isCancelled {
            let group = await createSequenceGroup(from: currentSequence, in: modelContext)
            groups.append(group)
        }
        
        return groups
    }
    
    private func createSequenceGroup(from screenshots: [Screenshot], in modelContext: ModelContext) async -> ScreenshotGroup {
        let appName = await extractAppName(from: screenshots.first!)
        let title = "\(appName ?? "App") Session"
        
        let group = ScreenshotGroup(
            title: title,
            groupType: .sequence,
            confidence: 0.9,
            appName: appName,
            sessionIdentifier: UUID().uuidString
        )
        
        for screenshot in screenshots {
            group.addScreenshot(screenshot)
        }
        
        modelContext.insert(group)
        return group
    }
    
    // MARK: - Content Similarity Detection
    
    /// Detect groups based on OCR text similarity (Optimized with clustering)
    private func detectContentSimilarityGroups(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> [ScreenshotGroup] {
        var groups: [ScreenshotGroup] = []
        
        // Pre-filter screenshots with extracted text
        let screenshotsWithText = screenshots.compactMap { screenshot -> (Screenshot, String, Set<String>)? in
            guard let extractedText = screenshot.extractedText,
                  !extractedText.isEmpty else { return nil }
            
            let cleanText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let words = Set(cleanText.split(separator: " ").map(String.init))
            return (screenshot, cleanText, words)
        }
        
        guard !screenshotsWithText.isEmpty else {
            logger.info("No screenshots with text content found")
            return groups
        }
        
        logger.info("Processing \(screenshotsWithText.count) screenshots with text content")
        
        // Build URL-based groups first (fast exact matching)
        var urlGroups: [String: [Screenshot]] = [:]
        var nonUrlScreenshots: [(Screenshot, String, Set<String>)] = []
        
        for (screenshot, text, words) in screenshotsWithText {
            if let url = extractWebsiteURL(from: text) {
                urlGroups[url, default: []].append(screenshot)
            } else {
                nonUrlScreenshots.append((screenshot, text, words))
            }
        }
        
        // Create URL-based groups
        for (url, screenshots) in urlGroups {
            if screenshots.count >= minGroupSize {
                let group = await createContentSimilarityGroup(from: screenshots, in: modelContext, websiteURL: url)
                groups.append(group)
            }
        }
        
        guard !Task.isCancelled else { return groups }
        
        // Process remaining screenshots using optimized clustering
        if !nonUrlScreenshots.isEmpty {
            let textGroups = await clusterScreenshotsByText(nonUrlScreenshots)
            
            for similarScreenshots in textGroups {
                guard !Task.isCancelled else { break }
                
                if similarScreenshots.count >= minGroupSize {
                    let group = await createContentSimilarityGroup(from: similarScreenshots, in: modelContext)
                    groups.append(group)
                }
            }
        }
        
        return groups
    }
    
    /// Efficiently cluster screenshots by text similarity using word overlap
    private func clusterScreenshotsByText(_ screenshotsWithText: [(Screenshot, String, Set<String>)]) async -> [[Screenshot]] {
        var clusters: [[Screenshot]] = []
        var processed: Set<UUID> = []
        
        for (screenshot, _, words) in screenshotsWithText {
            guard !processed.contains(screenshot.id) else { continue }
            guard !Task.isCancelled else { break }
            
            var cluster = [screenshot]
            processed.insert(screenshot.id)
            
            // Find similar screenshots using word overlap
            for (otherScreenshot, _, otherWords) in screenshotsWithText {
                guard !processed.contains(otherScreenshot.id) else { continue }
                
                let similarity = calculateWordOverlapSimilarity(words, otherWords)
                if similarity >= contentSimilarityThreshold {
                    cluster.append(otherScreenshot)
                    processed.insert(otherScreenshot.id)
                }
            }
            
            if cluster.count >= minGroupSize {
                clusters.append(cluster)
            }
            
            // Yield control periodically
            if clusters.count % 5 == 0 {
                await Task.yield()
            }
        }
        
        return clusters
    }
    
    /// Fast word overlap similarity calculation
    private func calculateWordOverlapSimilarity(_ words1: Set<String>, _ words2: Set<String>) -> Double {
        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }
    
    private func isContentSimilar(_ text1: String, _ text2: String) async -> Bool {
        // Clean and normalize text
        let cleanText1 = text1.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanText2 = text2.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Check for website URLs
        if let url1 = extractWebsiteURL(from: cleanText1),
           let url2 = extractWebsiteURL(from: cleanText2) {
            return url1 == url2
        }
        
        // Calculate text similarity using basic algorithm
        let similarity = calculateTextSimilarity(cleanText1, cleanText2)
        return similarity >= contentSimilarityThreshold
    }
    
    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        // Simple Jaccard similarity for now
        let words1 = Set(text1.split(separator: " ").map(String.init))
        let words2 = Set(text2.split(separator: " ").map(String.init))
        
        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }
    
    private func createContentSimilarityGroup(from screenshots: [Screenshot], in modelContext: ModelContext, websiteURL: String? = nil) async -> ScreenshotGroup {
        let detectedURL = websiteURL ?? extractWebsiteURL(from: screenshots.first?.extractedText ?? "")
        let title = detectedURL?.components(separatedBy: ".").first?.capitalized ?? "Similar Content"
        
        let group = ScreenshotGroup(
            title: title,
            groupType: .contentSimilarity,
            confidence: 0.8,
            websiteURL: detectedURL
        )
        
        for screenshot in screenshots {
            group.addScreenshot(screenshot)
        }
        
        modelContext.insert(group)
        return group
    }
    
    // MARK: - Visual Similarity Detection (Disabled for Performance)
    
    /// Visual similarity detection temporarily disabled for performance
    /// This was causing the major performance issues with Vision Framework calls
    private func detectVisualSimilarityGroups(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> [ScreenshotGroup] {
        // Temporarily disabled to improve performance
        // Visual similarity detection requires expensive Vision Framework operations
        // that were causing 2+ second hangs. Will be re-enabled with proper background processing.
        logger.info("Visual similarity detection temporarily disabled for performance")
        return []
    }
    
    // Visual similarity temporarily disabled for performance
    private func isVisuallySimilar(_ screenshot1: Screenshot, _ screenshot2: Screenshot) async -> Bool {
        // This was causing major performance issues with Vision Framework calls
        return false
    }
    
    // Visual similarity group creation disabled for performance
    private func createVisualSimilarityGroup(from screenshots: [Screenshot], in modelContext: ModelContext) async -> ScreenshotGroup {
        let group = ScreenshotGroup(
            title: "Visual Group",
            groupType: .visualSimilarity,
            confidence: 0.75
        )
        
        for screenshot in screenshots {
            group.addScreenshot(screenshot)
        }
        
        modelContext.insert(group)
        return group
    }
    
    // MARK: - Project Detection
    
    /// Detect project-based groups using recurring patterns
    private func detectProjectGroups(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> [ScreenshotGroup] {
        var groups: [ScreenshotGroup] = []
        var appSessions: [String: [Screenshot]] = [:]
        
        // Group by app name
        for screenshot in screenshots {
            let appName = await extractAppName(from: screenshot)
            if let app = appName {
                appSessions[app, default: []].append(screenshot)
            }
        }
        
        // Detect projects within each app
        for (appName, appScreenshots) in appSessions {
            let sortedScreenshots = appScreenshots.sorted { $0.timestamp < $1.timestamp }
            var projectScreenshots: [Screenshot] = []
            var lastTimestamp: Date?
            
            for screenshot in sortedScreenshots {
                if let lastTime = lastTimestamp,
                   screenshot.timestamp.timeIntervalSince(lastTime) <= projectDetectionTimeWindow {
                    projectScreenshots.append(screenshot)
                } else {
                    // End current project if it's significant
                    if projectScreenshots.count >= minGroupSize {
                        let group = await createProjectGroup(from: projectScreenshots, appName: appName, in: modelContext)
                        groups.append(group)
                    }
                    
                    // Start new project
                    projectScreenshots = [screenshot]
                }
                
                lastTimestamp = screenshot.timestamp
            }
            
            // Handle final project
            if projectScreenshots.count >= minGroupSize {
                let group = await createProjectGroup(from: projectScreenshots, appName: appName, in: modelContext)
                groups.append(group)
            }
        }
        
        return groups
    }
    
    private func createProjectGroup(from screenshots: [Screenshot], appName: String, in modelContext: ModelContext) async -> ScreenshotGroup {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = dateFormatter.string(from: screenshots.first?.timestamp ?? Date())
        
        let title = "\(appName) Project - \(dateString)"
        
        let group = ScreenshotGroup(
            title: title,
            groupType: .project,
            confidence: 0.7,
            appName: appName
        )
        
        for screenshot in screenshots {
            group.addScreenshot(screenshot)
        }
        
        modelContext.insert(group)
        return group
    }
    
    // MARK: - Group Optimization
    
    /// Optimize groups by merging similar ones and removing small groups
    private func optimizeGroups(_ groups: [ScreenshotGroup], in modelContext: ModelContext) async -> [ScreenshotGroup] {
        var optimizedGroups = groups
        
        // Remove groups that are too small
        optimizedGroups = optimizedGroups.filter { $0.screenshotCount >= minGroupSize }
        
        // Merge similar groups
        var mergedGroups: [ScreenshotGroup] = []
        var processed: Set<UUID> = []
        
        for group in optimizedGroups {
            guard !processed.contains(group.id) else { continue }
            
            let mergedGroup = group
            processed.insert(group.id)
            
            // Find groups to merge with this one
            for otherGroup in optimizedGroups {
                guard !processed.contains(otherGroup.id) else { continue }
                
                if group.shouldMergeWith(otherGroup) {
                    await mergeGroups(mergedGroup, with: otherGroup, in: modelContext)
                    processed.insert(otherGroup.id)
                }
            }
            
            mergedGroups.append(mergedGroup)
        }
        
        return mergedGroups
    }
    
    private func mergeGroups(_ group1: ScreenshotGroup, with group2: ScreenshotGroup, in modelContext: ModelContext) async {
        // Move all screenshots from group2 to group1
        for screenshot in group2.screenshots {
            group1.addScreenshot(screenshot)
        }
        
        // Update group1 properties
        group1.confidence = (group1.confidence + group2.confidence) / 2
        group1.lastModified = Date()
        
        // Remove group2
        modelContext.delete(group2)
    }
    
    // MARK: - Helper Methods
    
    private func removeAutomaticGroups(in modelContext: ModelContext) async {
        do {
            let fetchRequest = FetchDescriptor<ScreenshotGroup>(
                predicate: #Predicate { !$0.isUserCreated }
            )
            let automaticGroups = try modelContext.fetch(fetchRequest)
            
            for group in automaticGroups {
                modelContext.delete(group)
            }
        } catch {
            logger.error("Error removing automatic groups: \(error.localizedDescription)")
        }
    }
    
    /// Optimized app name extraction with caching
    private func extractAppNameOptimized(from screenshot: Screenshot) async -> String? {
        // Simple extraction from filename or metadata if available
        // This avoids expensive OCR text parsing during sequence detection
        let filename = screenshot.filename
        if !filename.isEmpty {
            // Extract potential app name from filename patterns
            if filename.contains("safari") { return "Safari" }
            if filename.contains("chrome") { return "Chrome" }
            if filename.contains("messages") { return "Messages" }
            if filename.contains("mail") { return "Mail" }
            if filename.contains("settings") { return "Settings" }
        }
        
        // Fast OCR text scanning for app indicators
        if let extractedText = screenshot.extractedText {
            let text = extractedText.lowercased()
            if text.contains("safari") { return "Safari" }
            if text.contains("chrome") { return "Chrome" }
            if text.contains("messages") { return "Messages" }
            if text.contains("mail") { return "Mail" }
            if text.contains("settings") { return "Settings" }
        }
        
        return "App"
    }
    
    private func extractAppName(from screenshot: Screenshot) async -> String? {
        return await extractAppNameOptimized(from: screenshot)
    }
    
    private func extractWebsiteURL(from text: String) -> String? {
        // Simple URL extraction
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        return matches?.first?.url?.host
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            processingProgress = max(0.0, min(1.0, progress))
        }
    }
    
    // MARK: - Public Query Methods
    
    /// Get all groups for display
    public func getAllGroups(in modelContext: ModelContext) -> [ScreenshotGroup] {
        do {
            let fetchRequest = FetchDescriptor<ScreenshotGroup>(
                sortBy: [
                    SortDescriptor(\ScreenshotGroup.lastModified, order: .reverse)
                ]
            )
            let groups = try modelContext.fetch(fetchRequest)
            // Sort manually since SwiftData has issues with enum sorting
            return groups.sorted { $0.groupType.priority < $1.groupType.priority }
        } catch {
            logger.error("Error fetching groups: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get ungrouped screenshots
    public func getUngroupedScreenshots(in modelContext: ModelContext) -> [Screenshot] {
        do {
            let fetchRequest = FetchDescriptor<Screenshot>(
                predicate: #Predicate { $0.groups.isEmpty },
                sortBy: [SortDescriptor(\Screenshot.timestamp, order: .reverse)]
            )
            return try modelContext.fetch(fetchRequest)
        } catch {
            logger.error("Error fetching ungrouped screenshots: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Extensions

extension SmartGroupingService {
    /// Trigger grouping analysis with user feedback
    public func triggerGroupingAnalysis(in modelContext: ModelContext) async {
        await analyzeAndGroupScreenshots(in: modelContext)
    }
    
    /// Check if grouping is needed based on new screenshots
    public func needsRegrouping(in modelContext: ModelContext) -> Bool {
        guard let lastUpdate = lastGroupingUpdate else { return true }
        
        // Check if there are new screenshots since last grouping
        do {
            let fetchRequest = FetchDescriptor<Screenshot>(
                predicate: #Predicate { $0.timestamp > lastUpdate }
            )
            let newScreenshots = try modelContext.fetch(fetchRequest)
            return !newScreenshots.isEmpty
        } catch {
            logger.error("Error checking for new screenshots: \(error.localizedDescription)")
            return true
        }
    }
}