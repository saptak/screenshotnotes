import Foundation
import SwiftData
import SwiftUI
import Vision
import UIKit
import OSLog

/// Service for automatically grouping related screenshots using intelligent algorithms
@MainActor
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
    
    // MARK: - Services
    
    private let ocrService = OCRService()
    private let visualSimilarityService = VisualSimilarityService.shared
    
    private init() {
        logger.info("SmartGroupingService initialized")
    }
    
    // MARK: - Main Grouping Interface
    
    /// Analyze and group all screenshots in the provided context
    public func analyzeAndGroupScreenshots(in modelContext: ModelContext) async {
        logger.info("Starting screenshot grouping analysis")
        
        guard !isProcessing else {
            logger.warning("Grouping analysis already in progress")
            return
        }
        
        // Ensure we're on the main actor for ModelContext safety
        await MainActor.run {
            logger.debug("Grouping analysis starting on main actor")
        }
        
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
            
            logger.info("Analyzing \(screenshots.count) screenshots for grouping")
            
            // Remove existing automatic groups (keep user-created groups)
            await removeAutomaticGroups(in: modelContext)
            
            // Step 1: Sequence Detection (20% of progress)
            await updateProgress(0.1)
            let sequenceGroups = await detectSequenceGroups(screenshots, in: modelContext)
            logger.info("Created \(sequenceGroups.count) sequence groups")
            
            // Step 2: Content Similarity (30% of progress)
            await updateProgress(0.3)
            let contentGroups = await detectContentSimilarityGroups(screenshots, in: modelContext)
            logger.info("Created \(contentGroups.count) content similarity groups")
            
            // Step 3: Visual Similarity (30% of progress)
            await updateProgress(0.6)
            let visualGroups = await detectVisualSimilarityGroups(screenshots, in: modelContext)
            logger.info("Created \(visualGroups.count) visual similarity groups")
            
            // Step 4: Project Detection (20% of progress)
            await updateProgress(0.8)
            let projectGroups = await detectProjectGroups(screenshots, in: modelContext)
            logger.info("Created \(projectGroups.count) project groups")
            
            // Step 5: Merge and optimize groups
            await updateProgress(0.9)
            let allGroups = sequenceGroups + contentGroups + visualGroups + projectGroups
            let optimizedGroups = await optimizeGroups(allGroups, in: modelContext)
            logger.info("Optimized to \(optimizedGroups.count) final groups")
            
            // Step 6: Calculate statistics
            await updateProgress(1.0)
            let statistics = GroupStatistics(groups: optimizedGroups, totalScreenshots: screenshots.count)
            
            groupingStatistics = statistics
            
            logger.info("Grouping analysis completed successfully")
            
        } catch {
            logger.error("Error during grouping analysis: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sequence Detection
    
    /// Detect screenshot sequences based on timestamps and app continuity
    private func detectSequenceGroups(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> [ScreenshotGroup] {
        var groups: [ScreenshotGroup] = []
        var currentSequence: [Screenshot] = []
        var lastTimestamp: Date?
        var lastAppName: String?
        
        for screenshot in screenshots {
            let appName = await extractAppName(from: screenshot)
            
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
        }
        
        // Handle final sequence
        if currentSequence.count >= minGroupSize {
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
    
    /// Detect groups based on OCR text similarity
    private func detectContentSimilarityGroups(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> [ScreenshotGroup] {
        var groups: [ScreenshotGroup] = []
        var processedScreenshots: Set<UUID> = []
        
        for screenshot in screenshots {
            guard !processedScreenshots.contains(screenshot.id) else { continue }
            
            guard let extractedText = screenshot.extractedText,
                  !extractedText.isEmpty else { continue }
            
            var similarScreenshots: [Screenshot] = [screenshot]
            processedScreenshots.insert(screenshot.id)
            
            // Find similar screenshots
            for otherScreenshot in screenshots {
                guard !processedScreenshots.contains(otherScreenshot.id) else { continue }
                
                guard let otherText = otherScreenshot.extractedText,
                      !otherText.isEmpty else { continue }
                
                if await isContentSimilar(extractedText, otherText) {
                    similarScreenshots.append(otherScreenshot)
                    processedScreenshots.insert(otherScreenshot.id)
                }
            }
            
            // Create group if we have enough similar screenshots
            if similarScreenshots.count >= minGroupSize {
                let group = await createContentSimilarityGroup(from: similarScreenshots, in: modelContext)
                groups.append(group)
            }
        }
        
        return groups
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
    
    private func createContentSimilarityGroup(from screenshots: [Screenshot], in modelContext: ModelContext) async -> ScreenshotGroup {
        let websiteURL = extractWebsiteURL(from: screenshots.first?.extractedText ?? "")
        let title = websiteURL?.components(separatedBy: ".").first?.capitalized ?? "Similar Content"
        
        let group = ScreenshotGroup(
            title: title,
            groupType: .contentSimilarity,
            confidence: 0.8,
            websiteURL: websiteURL
        )
        
        for screenshot in screenshots {
            group.addScreenshot(screenshot)
        }
        
        modelContext.insert(group)
        return group
    }
    
    // MARK: - Visual Similarity Detection
    
    /// Detect groups based on visual similarity
    private func detectVisualSimilarityGroups(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> [ScreenshotGroup] {
        var groups: [ScreenshotGroup] = []
        var processedScreenshots: Set<UUID> = []
        
        for screenshot in screenshots {
            guard !processedScreenshots.contains(screenshot.id) else { continue }
            
            var similarScreenshots: [Screenshot] = [screenshot]
            processedScreenshots.insert(screenshot.id)
            
            // Find visually similar screenshots
            for otherScreenshot in screenshots {
                guard !processedScreenshots.contains(otherScreenshot.id) else { continue }
                
                if await isVisuallySimilar(screenshot, otherScreenshot) {
                    similarScreenshots.append(otherScreenshot)
                    processedScreenshots.insert(otherScreenshot.id)
                }
            }
            
            // Create group if we have enough similar screenshots
            if similarScreenshots.count >= minGroupSize {
                let group = await createVisualSimilarityGroup(from: similarScreenshots, in: modelContext)
                groups.append(group)
            }
        }
        
        return groups
    }
    
    private func isVisuallySimilar(_ screenshot1: Screenshot, _ screenshot2: Screenshot) async -> Bool {
        // Convert screenshot data to UIImage
        guard let image1 = UIImage(data: screenshot1.imageData),
              let image2 = UIImage(data: screenshot2.imageData) else {
            return false
        }
        
        // Use the existing visual similarity service
        let similarityComponents = await visualSimilarityService.calculateVisualSimilarity(
            sourceImage: image1,
            targetImage: image2
        )
        return similarityComponents.overall >= visualSimilarityThreshold
    }
    
    private func createVisualSimilarityGroup(from screenshots: [Screenshot], in modelContext: ModelContext) async -> ScreenshotGroup {
        let appName = await extractAppName(from: screenshots.first!)
        let title = "\(appName ?? "App") Screenshots"
        
        let group = ScreenshotGroup(
            title: title,
            groupType: .visualSimilarity,
            confidence: 0.75,
            appName: appName
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
    
    private func extractAppName(from screenshot: Screenshot) async -> String? {
        // Try to extract app name from OCR text or metadata
        guard let extractedText = screenshot.extractedText else { return nil }
        
        // Look for common app indicators
        if extractedText.contains("Safari") || extractedText.contains("http") {
            return "Safari"
        } else if extractedText.contains("Photos") {
            return "Photos"
        } else if extractedText.contains("Settings") {
            return "Settings"
        } else if extractedText.contains("Messages") {
            return "Messages"
        } else if extractedText.contains("Mail") {
            return "Mail"
        }
        
        return nil
    }
    
    private func extractWebsiteURL(from text: String) -> String? {
        // Simple URL extraction
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        return matches?.first?.url?.host
    }
    
    private func updateProgress(_ progress: Double) async {
        processingProgress = progress
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