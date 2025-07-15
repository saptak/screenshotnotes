import Foundation
import SwiftData
import BackgroundTasks

/// Background processor for enhanced vision analysis using Apple's Vision framework
/// Integrates with Phase 5.2.1 Enhanced Vision Processing
@MainActor
public final class BackgroundVisionProcessor: ObservableObject {
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let backgroundTaskIdentifier = "com.screenshotnotes.vision-processing"
        static let batchSize = 5
        static let maxProcessingTime: TimeInterval = 25.0 // Background task limit
        static let analysisInterval: TimeInterval = 300.0 // 5 minutes
    }
    
    // MARK: - Services
    
    private let enhancedVisionService: EnhancedVisionService
    private var modelContext: ModelContext?
    
    // MARK: - State
    
    @Published public var isProcessing = false
    @Published public var processingProgress: Double = 0.0
    @Published public var lastProcessingDate: Date?
    @Published public var processedCount = 0
    @Published public var totalCount = 0
    
    // MARK: - Background Task Management
    
    private var backgroundTask: BGProcessingTask?
    private var processingTimer: Timer?
    
    // 🎯 Sprint 8.5.3.1: Task Synchronization Framework
    private let taskManager = TaskManager.shared
    
    // MARK: - Initialization
    
    public init() {
        self.enhancedVisionService = EnhancedVisionService()
        setupBackgroundTaskHandling()
    }
    
    /// Set the model context for database operations
    public func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Public Processing Methods
    
    /// Start processing screenshots that need vision analysis
    public func startProcessing() async {
        guard !isProcessing else { return }
        
        // 🎯 Sprint 8.5.3.1: Use Task Synchronization Framework for coordinated processing
        await taskManager.execute(
            category: .vision,
            priority: .normal,
            description: "Start vision processing for screenshots"
        ) {
            self.isProcessing = true
            self.processedCount = 0
            
            await self.processScreenshotsNeedingAnalysis()
            
            self.isProcessing = false
            self.lastProcessingDate = Date()
        }
    }
    
    /// Process a specific screenshot with enhanced vision analysis
    public func processScreenshot(_ screenshot: Screenshot) async -> Bool {
        guard let attributes = await enhancedVisionService.analyzeScreenshot(screenshot.imageData) else {
            return false
        }
        
        // Update screenshot with visual attributes
        screenshot.visualAttributes = attributes
        
        // Save to database
        return await saveContext()
    }
    
    /// Get screenshots that need vision analysis
    public func getScreenshotsNeedingAnalysis() -> [Screenshot] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate<Screenshot> { screenshot in
                screenshot.visualAttributesData == nil || screenshot.lastVisionAnalysis == nil
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let screenshots = try context.fetch(descriptor)
            return Array(screenshots.prefix(50)) // Limit to 50 for performance
        } catch {
            print("BackgroundVisionProcessor: Failed to fetch screenshots needing analysis: \(error)")
            return []
        }
    }
    
    // MARK: - Background Processing
    
    /// Process screenshots in background batches
    private func processScreenshotsNeedingAnalysis() async {
        let screenshots = getScreenshotsNeedingAnalysis()
        totalCount = screenshots.count
        
        guard !screenshots.isEmpty else {
            processingProgress = 1.0
            return
        }
        
        print("BackgroundVisionProcessor: Processing \(screenshots.count) screenshots")
        
        // Process in batches to avoid memory pressure
        for batch in screenshots.chunked(into: Configuration.batchSize) {
            await processBatch(batch)
            
            // Update progress
            processedCount += batch.count
            processingProgress = Double(processedCount) / Double(totalCount)
            
            // Small delay between batches to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        processingProgress = 1.0
        print("BackgroundVisionProcessor: Completed processing \(processedCount) screenshots")
    }
    
    /// Process a batch of screenshots
    private func processBatch(_ screenshots: [Screenshot]) async {
        await withTaskGroup(of: Void.self) { group in
            for screenshot in screenshots {
                group.addTask {
                    let success = await self.processScreenshot(screenshot)
                    if success {
                        print("BackgroundVisionProcessor: Successfully processed screenshot \(screenshot.id)")
                    } else {
                        print("BackgroundVisionProcessor: Failed to process screenshot \(screenshot.id)")
                    }
                }
            }
        }
    }
    
    // MARK: - Background Task Registration
    
    /// Setup background task handling
    private func setupBackgroundTaskHandling() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Configuration.backgroundTaskIdentifier,
            using: nil
        ) { task in
            Task {
                await self.handleBackgroundVisionProcessing(task: task as! BGProcessingTask)
            }
        }
    }
    
    /// Handle background vision processing task
    private func handleBackgroundVisionProcessing(task: BGProcessingTask) async {
        backgroundTask = task
        
        // Set expiration handler
        task.expirationHandler = {
            Task {
                await self.stopBackgroundProcessing()
            }
        }
        
        // Start processing
        await startProcessing()
        
        // Schedule next background task
        scheduleBackgroundVisionProcessing()
        
        // Mark task as completed
        task.setTaskCompleted(success: true)
        backgroundTask = nil
    }
    
    /// Schedule next background vision processing task
    public func scheduleBackgroundVisionProcessing() {
        let request = BGProcessingTaskRequest(identifier: Configuration.backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: Configuration.analysisInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundVisionProcessor: Scheduled next background processing task")
        } catch {
            print("BackgroundVisionProcessor: Failed to schedule background task: \(error)")
        }
    }
    
    /// Stop background processing
    private func stopBackgroundProcessing() async {
        isProcessing = false
        backgroundTask?.setTaskCompleted(success: false)
        backgroundTask = nil
    }
    
    // MARK: - Manual Processing Controls
    
    /// Start periodic processing timer
    public func startPeriodicProcessing() {
        stopPeriodicProcessing()
        
        processingTimer = Timer.scheduledTimer(withTimeInterval: Configuration.analysisInterval, repeats: true) { _ in
            Task {
                await self.startProcessing()
            }
        }
    }
    
    /// Stop periodic processing timer
    public func stopPeriodicProcessing() {
        processingTimer?.invalidate()
        processingTimer = nil
    }
    
    // MARK: - Statistics and Monitoring
    
    /// Get processing statistics
    public func getProcessingStats() -> ProcessingStats {
        let totalScreenshots = getTotalScreenshotsCount()
        let processedScreenshots = getProcessedScreenshotsCount()
        let pendingScreenshots = totalScreenshots - processedScreenshots
        
        return ProcessingStats(
            totalScreenshots: totalScreenshots,
            processedScreenshots: processedScreenshots,
            pendingScreenshots: pendingScreenshots,
            lastProcessingDate: lastProcessingDate,
            isCurrentlyProcessing: isProcessing,
            processingProgress: processingProgress
        )
    }
    
    /// Get total number of screenshots
    private func getTotalScreenshotsCount() -> Int {
        guard let context = modelContext else { return 0 }
        
        let descriptor = FetchDescriptor<Screenshot>()
        
        do {
            return try context.fetchCount(descriptor)
        } catch {
            print("BackgroundVisionProcessor: Failed to count total screenshots: \(error)")
            return 0
        }
    }
    
    /// Get number of processed screenshots
    private func getProcessedScreenshotsCount() -> Int {
        guard let context = modelContext else { return 0 }
        
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate<Screenshot> { screenshot in
                screenshot.visualAttributesData != nil && screenshot.lastVisionAnalysis != nil
            }
        )
        
        do {
            return try context.fetchCount(descriptor)
        } catch {
            print("BackgroundVisionProcessor: Failed to count processed screenshots: \(error)")
            return 0
        }
    }
    
    // MARK: - Search Integration
    
    /// Find screenshots by visual attributes
    public func findScreenshotsByVisualAttributes(
        sceneType: SceneType? = nil,
        objectCategory: ObjectCategory? = nil,
        dominantColor: String? = nil,
        isDocument: Bool? = nil
    ) -> [Screenshot] {
        guard let context = modelContext else { return [] }
        
        let predicate = #Predicate<Screenshot> { screenshot in
            screenshot.visualAttributesData != nil
        }
        
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let screenshots = try context.fetch(descriptor)
            
            // Additional filtering in memory for complex visual attribute queries
            return screenshots.filter { screenshot in
                guard let attributes = screenshot.visualAttributes else { return false }
                
                // Filter by scene type
                if let requiredScene = sceneType {
                    if attributes.sceneClassification.primaryScene != requiredScene &&
                       attributes.sceneClassification.secondaryScene != requiredScene {
                        return false
                    }
                }
                
                // Filter by object category
                if let requiredCategory = objectCategory {
                    let hasCategory = attributes.detectedObjects.contains { $0.category == requiredCategory }
                    if !hasCategory {
                        return false
                    }
                }
                
                // Filter by dominant color
                if let requiredColor = dominantColor {
                    let hasColor = attributes.colorAnalysis.dominantColors.contains { 
                        $0.colorName.lowercased().contains(requiredColor.lowercased()) 
                    }
                    if !hasColor {
                        return false
                    }
                }
                
                // Filter by document likelihood
                if let documentRequired = isDocument {
                    if attributes.isDocument != documentRequired {
                        return false
                    }
                }
                
                return true
            }
        } catch {
            print("BackgroundVisionProcessor: Failed to fetch screenshots by visual attributes: \(error)")
            return []
        }
    }
    
    // MARK: - Cleanup and Maintenance
    
    /// Clean up old cached vision analysis data
    public func cleanupOldAnalysis() async {
        guard let context = modelContext else { return }
        
        // Find screenshots with vision analysis older than 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate<Screenshot> { screenshot in
                screenshot.lastVisionAnalysis != nil && screenshot.lastVisionAnalysis! < thirtyDaysAgo
            }
        )
        
        do {
            let oldScreenshots = try context.fetch(descriptor)
            
            for screenshot in oldScreenshots {
                screenshot.visualAttributes = nil // This will clear the stored data
            }
            
            let success = await saveContext()
            if success {
                print("BackgroundVisionProcessor: Cleaned up \(oldScreenshots.count) old vision analyses")
            }
        } catch {
            print("BackgroundVisionProcessor: Failed to cleanup old analysis: \(error)")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Save the model context
    private func saveContext() async -> Bool {
        guard let context = modelContext else { return false }
        
        do {
            try context.save()
            return true
        } catch {
            print("BackgroundVisionProcessor: Failed to save context: \(error)")
            return false
        }
    }
}

// MARK: - Supporting Types

/// Processing statistics for monitoring
public struct ProcessingStats {
    public let totalScreenshots: Int
    public let processedScreenshots: Int
    public let pendingScreenshots: Int
    public let lastProcessingDate: Date?
    public let isCurrentlyProcessing: Bool
    public let processingProgress: Double
    
    public var completionPercentage: Double {
        guard totalScreenshots > 0 else { return 100.0 }
        return (Double(processedScreenshots) / Double(totalScreenshots)) * 100.0
    }
}

