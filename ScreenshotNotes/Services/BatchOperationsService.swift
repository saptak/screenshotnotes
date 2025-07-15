import Foundation
import SwiftData
import SwiftUI
import OSLog
import UniformTypeIdentifiers

/// Advanced batch operations service for efficient multi-screenshot workflows
/// Provides intelligent batch processing with progress tracking, cancellation, and recovery
@MainActor
public final class BatchOperationsService: ObservableObject {
    public static let shared = BatchOperationsService()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "BatchOperations")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isProcessing = false
    @Published public private(set) var currentOperation: BatchOperation?
    @Published public private(set) var operationProgress: Double = 0.0
    @Published public private(set) var processedCount: Int = 0
    @Published public private(set) var totalCount: Int = 0
    @Published public private(set) var operationMessage: String = ""
    @Published public private(set) var operationHistory: [BatchOperationRecord] = []
    
    // MARK: - Services
    
    private let hapticService = HapticFeedbackService.shared
    private let quickActionService = QuickActionService.shared
    private let duplicateService = DuplicateDetectionService.shared
    private let errorService = ErrorHandlingService.shared
    
    // MARK: - Configuration
    
    public struct BatchSettings {
        var maxBatchSize: Int = 50              // Process up to 50 screenshots at once
        var progressUpdateInterval: Double = 0.1 // Update progress every 0.1 seconds
        var enableHapticFeedback: Bool = true
        var autoRetryFailures: Bool = true
        var maxRetryAttempts: Int = 3
        var operationTimeout: TimeInterval = 300 // 5 minutes max per operation
        
        public init() {}
    }
    
    @Published public var settings = BatchSettings()
    
    // MARK: - Operation Types
    
    public enum BatchOperation: String, CaseIterable, Identifiable {
        case delete = "delete"
        case addToCollection = "add_to_collection"
        case removeFromCollection = "remove_from_collection"
        case addTags = "add_tags"
        case removeTags = "remove_tags"
        case setFavorite = "set_favorite"
        case unsetFavorite = "unset_favorite"
        case export = "export"
        case copyToClipboard = "copy_to_clipboard"
        case share = "share"
        case duplicate = "duplicate"
        case moveToGroup = "move_to_group"
        case removeFromGroup = "remove_from_group"
        case updateMetadata = "update_metadata"
        case cleanupDuplicates = "cleanup_duplicates"
        case bulkRename = "bulk_rename"
        case optimizeImages = "optimize_images"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .delete:
                return "Delete Screenshots"
            case .addToCollection:
                return "Add to Collection"
            case .removeFromCollection:
                return "Remove from Collection"
            case .addTags:
                return "Add Tags"
            case .removeTags:
                return "Remove Tags"
            case .setFavorite:
                return "Mark as Favorite"
            case .unsetFavorite:
                return "Remove from Favorites"
            case .export:
                return "Export Screenshots"
            case .copyToClipboard:
                return "Copy to Clipboard"
            case .share:
                return "Share Screenshots"
            case .duplicate:
                return "Duplicate Screenshots"
            case .moveToGroup:
                return "Move to Group"
            case .removeFromGroup:
                return "Remove from Group"
            case .updateMetadata:
                return "Update Metadata"
            case .cleanupDuplicates:
                return "Clean Up Duplicates"
            case .bulkRename:
                return "Rename Screenshots"
            case .optimizeImages:
                return "Optimize Images"
            }
        }
        
        public var systemImage: String {
            switch self {
            case .delete:
                return "trash.fill"
            case .addToCollection, .removeFromCollection:
                return "folder.badge.plus"
            case .addTags, .removeTags:
                return "tag.fill"
            case .setFavorite, .unsetFavorite:
                return "heart.fill"
            case .export:
                return "square.and.arrow.down"
            case .copyToClipboard:
                return "doc.on.doc.fill"
            case .share:
                return "square.and.arrow.up.fill"
            case .duplicate:
                return "plus.square.on.square"
            case .moveToGroup, .removeFromGroup:
                return "rectangle.3.group"
            case .updateMetadata:
                return "pencil.circle.fill"
            case .cleanupDuplicates:
                return "sparkles"
            case .bulkRename:
                return "textformat.abc"
            case .optimizeImages:
                return "wand.and.rays"
            }
        }
        
        public var requiresConfirmation: Bool {
            switch self {
            case .delete, .cleanupDuplicates, .removeFromCollection, .removeFromGroup:
                return true
            default:
                return false
            }
        }
        
        public var estimatedTimePerItem: TimeInterval {
            switch self {
            case .delete, .setFavorite, .unsetFavorite:
                return 0.01 // Very fast database operations
            case .addTags, .removeTags, .updateMetadata:
                return 0.05 // Quick metadata updates
            case .addToCollection, .removeFromCollection, .moveToGroup:
                return 0.1  // Moderate relationship updates
            case .copyToClipboard, .duplicate:
                return 0.2  // Image processing
            case .export, .share:
                return 0.5  // File operations
            case .cleanupDuplicates:
                return 1.0  // Analysis required
            case .bulkRename, .optimizeImages:
                return 0.3  // File modifications
            case .removeFromGroup:
                return 0.05 // Quick relationship removal
            }
        }
    }
    
    // MARK: - Operation Parameters
    
    public struct BatchOperationParameters {
        var targetCollection: Collection?
        var targetGroup: ScreenshotGroup?
        var tags: [String]?
        var exportDirectory: URL?
        var shareItems: [Any]?
        var metadataUpdate: ScreenshotMetadataUpdate?
        var renamePattern: String?
        var optimizationSettings: ImageOptimizationSettings?
        
        public init() {}
    }
    
    public struct ScreenshotMetadataUpdate {
        var userNotes: String?
        var filename: String?
        var isFavorite: Bool?
        var addTags: [String]?
        var removeTags: [String]?
        
        public init() {}
    }
    
    public struct ImageOptimizationSettings {
        var targetFormat: UTType = .jpeg
        var compressionQuality: Double = 0.8
        var maxDimension: Int = 2048
        var removeMetadata: Bool = true
        
        public init() {}
    }
    
    // MARK: - Operation Record
    
    public struct BatchOperationRecord: Identifiable {
        public let id = UUID()
        public let operation: BatchOperation
        public let screenshotCount: Int
        public let startTime: Date
        public let endTime: Date?
        public let duration: TimeInterval
        public let success: Bool
        public let processedCount: Int
        public let failedCount: Int
        public let errorMessage: String?
        
        public var completionRate: Double {
            guard screenshotCount > 0 else { return 0.0 }
            return Double(processedCount) / Double(screenshotCount)
        }
    }
    
    // MARK: - Cancellation Support
    
    private var currentTask: Task<Void, Never>?
    private var isCancellationRequested = false
    
    private init() {
        logger.info("BatchOperationsService initialized with intelligent batch processing")
    }
    
    // MARK: - Public Interface
    
    /// Execute a batch operation on multiple screenshots
    public func executeBatchOperation(
        _ operation: BatchOperation,
        on screenshots: [Screenshot],
        parameters: BatchOperationParameters = BatchOperationParameters(),
        in modelContext: ModelContext
    ) async -> Bool {
        guard !isProcessing else {
            logger.warning("Batch operation already in progress")
            return false
        }
        
        guard !screenshots.isEmpty else {
            logger.warning("No screenshots provided for batch operation")
            return false
        }
        
        let startTime = Date()
        logger.info("Starting batch \\(operation.rawValue) on \\(screenshots.count) screenshots")
        
        // Request confirmation if needed
        if operation.requiresConfirmation {
            let confirmed = await requestConfirmation(for: operation, count: screenshots.count)
            guard confirmed else {
                logger.info("Batch operation cancelled by user")
                return false
            }
        }
        
        // Set up progress tracking
        await updateOperationState(
            operation: operation,
            isProcessing: true,
            totalCount: screenshots.count,
            processedCount: 0,
            progress: 0.0,
            message: "Preparing \\(operation.displayName.lowercased())..."
        )
        
        // Prepare haptic feedback
        if settings.enableHapticFeedback {
            hapticService.prepareHapticGenerators()
        }
        
        // Cancel any existing task
        currentTask?.cancel()
        isCancellationRequested = false
        
        // Execute operation
        var success = false
        var processedCount = 0
        var failedCount = 0
        var errorMessage: String?
        
        currentTask = Task {
            let result = await performBatchOperation(
                operation,
                on: screenshots,
                parameters: parameters,
                in: modelContext
            )
            
            success = result.success
            processedCount = result.processedCount
            failedCount = result.failedCount
            errorMessage = result.errorMessage
        }
        
        await currentTask?.value
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Record operation
        let record = BatchOperationRecord(
            operation: operation,
            screenshotCount: screenshots.count,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            success: success,
            processedCount: processedCount,
            failedCount: failedCount,
            errorMessage: errorMessage
        )
        
        await recordOperation(record)
        
        // Provide enhanced haptic feedback
        if settings.enableHapticFeedback {
            hapticService.triggerContextualFeedback(
                for: .batchOperation,
                isSuccess: success,
                itemCount: screenshots.count
            )
        }
        
        // Reset state
        await updateOperationState(
            operation: nil,
            isProcessing: false,
            totalCount: 0,
            processedCount: 0,
            progress: 0.0,
            message: ""
        )
        
        logger.info("Batch operation completed: \(success ? "SUCCESS" : "FAILED") - \(processedCount)/\(screenshots.count) processed")
        
        return success
    }
    
    /// Cancel the current batch operation
    public func cancelCurrentOperation() {
        guard isProcessing else { return }
        
        logger.info("Cancelling current batch operation")
        isCancellationRequested = true
        currentTask?.cancel()
        
        Task { @MainActor in
            await updateOperationMessage("Cancelling operation...")
        }
    }
    
    /// Get intelligent batch suggestions based on screenshot selection
    public func getBatchSuggestions(for screenshots: [Screenshot]) async -> [BatchOperation] {
        var suggestions: [BatchOperation] = []
        
        // Analyze screenshot characteristics
        let hasFavorites = screenshots.contains { $0.isFavorite }
        let hasNonFavorites = screenshots.contains { !$0.isFavorite }
        let hasUserTags = screenshots.contains { !($0.userTags?.isEmpty ?? true) }
        let allSameCollection = screenshots.allSatisfy { screenshot in
            screenshot.collections.count == 1 && screenshot.collections.first?.id == screenshots.first?.collections.first?.id
        }
        
        // Time-based suggestions
        let timeSpread = screenshots.max(by: { $0.timestamp < $1.timestamp })?.timestamp.timeIntervalSince(
            screenshots.min(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
        ) ?? 0
        
        // Basic operations always available
        suggestions.append(.copyToClipboard)
        suggestions.append(.share)
        suggestions.append(.export)
        
        // Conditional suggestions
        if screenshots.count >= 2 {
            suggestions.append(.addToCollection)
            suggestions.append(.duplicate)
        }
        
        if hasNonFavorites {
            suggestions.append(.setFavorite)
        }
        
        if hasFavorites {
            suggestions.append(.unsetFavorite)
        }
        
        if !hasUserTags {
            suggestions.append(.addTags)
        } else {
            suggestions.append(.removeTags)
        }
        
        if allSameCollection && screenshots.count >= 2 {
            suggestions.append(.removeFromCollection)
        }
        
        if timeSpread <= 300 { // Screenshots within 5 minutes
            suggestions.append(.moveToGroup)
        }
        
        if screenshots.count >= 5 {
            suggestions.append(.cleanupDuplicates)
            suggestions.append(.bulkRename)
        }
        
        if screenshots.count >= 10 {
            suggestions.append(.optimizeImages)
        }
        
        // Always offer delete as last option
        suggestions.append(.delete)
        
        return Array(suggestions.prefix(8)) // Limit to top 8 suggestions
    }
    
    // MARK: - Operation Implementation
    
    private func performBatchOperation(
        _ operation: BatchOperation,
        on screenshots: [Screenshot],
        parameters: BatchOperationParameters,
        in modelContext: ModelContext
    ) async -> (success: Bool, processedCount: Int, failedCount: Int, errorMessage: String?) {
        
        let batches = screenshots.batchChunked(into: settings.maxBatchSize)
        var totalProcessed = 0
        var totalFailed = 0
        var lastError: String?
        
        for (batchIndex, batch) in batches.enumerated() {
            guard !isCancellationRequested && !Task.isCancelled else {
                return (false, totalProcessed, totalFailed, "Operation cancelled")
            }
            
            let batchResult = await processBatch(
                operation,
                screenshots: batch,
                parameters: parameters,
                in: modelContext
            )
            
            totalProcessed += batchResult.processedCount
            totalFailed += batchResult.failedCount
            
            if let error = batchResult.errorMessage {
                lastError = error
            }
            
            // Update progress
            let progress = Double(batchIndex + 1) / Double(batches.count)
            await updateOperationProgress(
                progress: progress,
                processedCount: totalProcessed,
                message: "Processing batch \\(batchIndex + 1) of \\(batches.count)..."
            )
            
            // Small delay between batches to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        return (
            success: totalFailed == 0,
            processedCount: totalProcessed,
            failedCount: totalFailed,
            errorMessage: lastError
        )
    }
    
    private func processBatch(
        _ operation: BatchOperation,
        screenshots: [Screenshot],
        parameters: BatchOperationParameters,
        in modelContext: ModelContext
    ) async -> (processedCount: Int, failedCount: Int, errorMessage: String?) {
        
        var processed = 0
        var failed = 0
        var lastError: String?
        
        switch operation {
        case .delete:
            let result = await deleteBatch(screenshots, in: modelContext)
            processed = result.processed
            failed = result.failed
            lastError = result.error
            
        case .addToCollection:
            if let collection = parameters.targetCollection {
                let result = await addToCollectionBatch(screenshots, collection: collection, in: modelContext)
                processed = result.processed
                failed = result.failed
                lastError = result.error
            }
            
        case .removeFromCollection:
            if let collection = parameters.targetCollection {
                let result = await removeFromCollectionBatch(screenshots, collection: collection, in: modelContext)
                processed = result.processed
                failed = result.failed
                lastError = result.error
            }
            
        case .addTags:
            if let tags = parameters.tags {
                let result = await addTagsBatch(screenshots, tags: tags, in: modelContext)
                processed = result.processed
                failed = result.failed
                lastError = result.error
            }
            
        case .removeTags:
            if let tags = parameters.tags {
                let result = await removeTagsBatch(screenshots, tags: tags, in: modelContext)
                processed = result.processed
                failed = result.failed
                lastError = result.error
            }
            
        case .setFavorite:
            let result = await setFavoriteBatch(screenshots, isFavorite: true, in: modelContext)
            processed = result.processed
            failed = result.failed
            lastError = result.error
            
        case .unsetFavorite:
            let result = await setFavoriteBatch(screenshots, isFavorite: false, in: modelContext)
            processed = result.processed
            failed = result.failed
            lastError = result.error
            
        case .export:
            if let directory = parameters.exportDirectory {
                let result = await exportBatch(screenshots, to: directory)
                processed = result.processed
                failed = result.failed
                lastError = result.error
            }
            
        case .copyToClipboard:
            let result = await copyToClipboardBatch(screenshots)
            processed = result.processed
            failed = result.failed
            lastError = result.error
            
        case .duplicate:
            let result = await duplicateBatch(screenshots, in: modelContext)
            processed = result.processed
            failed = result.failed
            lastError = result.error
            
        case .moveToGroup:
            if let group = parameters.targetGroup {
                let result = await moveToGroupBatch(screenshots, group: group, in: modelContext)
                processed = result.processed
                failed = result.failed
                lastError = result.error
            }
            
        case .removeFromGroup:
            if let group = parameters.targetGroup {
                let result = await removeFromGroupBatch(screenshots, group: group, in: modelContext)
                processed = result.processed
                failed = result.failed
                lastError = result.error
            }
            
        case .updateMetadata:
            if let metadataUpdate = parameters.metadataUpdate {
                let result = await updateMetadataBatch(screenshots, update: metadataUpdate, in: modelContext)
                processed = result.processed
                failed = result.failed
                lastError = result.error
            }
            
        case .cleanupDuplicates:
            let result = await cleanupDuplicatesBatch(screenshots, in: modelContext)
            processed = result.processed
            failed = result.failed
            lastError = result.error
            
        case .bulkRename:
            if let pattern = parameters.renamePattern {
                let result = await bulkRenameBatch(screenshots, pattern: pattern, in: modelContext)
                processed = result.processed
                failed = result.failed
                lastError = result.error
            }
            
        case .optimizeImages:
            if let settings = parameters.optimizationSettings {
                let result = await optimizeImagesBatch(screenshots, settings: settings, in: modelContext)
                processed = result.processed
                failed = result.failed
                lastError = result.error
            }
            
        case .share:
            // Share is handled differently as it requires UI interaction
            processed = screenshots.count
        }
        
        return (processedCount: processed, failedCount: failed, errorMessage: lastError)
    }
    
    // MARK: - Batch Operation Implementations
    
    private func deleteBatch(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for screenshot in screenshots {
                modelContext.delete(screenshot)
                processed += 1
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            let appError = ErrorHandlingService.AppError.batchOperationFailure("Delete operation failed", screenshots.count)
            Task {
                await errorService.handleError(appError, context: "Batch Delete Operation")
            }
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func addToCollectionBatch(_ screenshots: [Screenshot], collection: Collection, in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for screenshot in screenshots {
                if !screenshot.collections.contains(where: { $0.id == collection.id }) {
                    screenshot.collections.append(collection)
                    processed += 1
                }
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func removeFromCollectionBatch(_ screenshots: [Screenshot], collection: Collection, in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for screenshot in screenshots {
                screenshot.collections.removeAll { $0.id == collection.id }
                processed += 1
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func addTagsBatch(_ screenshots: [Screenshot], tags: [String], in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for screenshot in screenshots {
                var currentTags = screenshot.userTags ?? []
                for tag in tags {
                    if !currentTags.contains(tag) {
                        currentTags.append(tag)
                    }
                }
                screenshot.userTags = currentTags
                processed += 1
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func removeTagsBatch(_ screenshots: [Screenshot], tags: [String], in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for screenshot in screenshots {
                var currentTags = screenshot.userTags ?? []
                currentTags.removeAll { tags.contains($0) }
                screenshot.userTags = currentTags.isEmpty ? nil : currentTags
                processed += 1
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func setFavoriteBatch(_ screenshots: [Screenshot], isFavorite: Bool, in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for screenshot in screenshots {
                screenshot.isFavorite = isFavorite
                processed += 1
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func exportBatch(_ screenshots: [Screenshot], to directory: URL) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        var lastError: String?
        
        for (index, screenshot) in screenshots.enumerated() {
            let filename = "screenshot_\(index + 1)_\(screenshot.filename).png"
            let fileURL = directory.appendingPathComponent(filename)
            
            if let image = UIImage(data: screenshot.imageData),
               let pngData = image.pngData() {
                do {
                    try pngData.write(to: fileURL)
                    processed += 1
                } catch {
                    lastError = error.localizedDescription
                }
            } else {
                lastError = "Failed to convert image data"
            }
        }
        
        return (processed, screenshots.count - processed, lastError)
    }
    
    private func copyToClipboardBatch(_ screenshots: [Screenshot]) async -> (processed: Int, failed: Int, error: String?) {
        let images = screenshots.compactMap { UIImage(data: $0.imageData) }
        
        await MainActor.run {
            var pasteboardItems: [[String: Any]] = []
            
            for image in images {
                var items: [String: Any] = [:]
                items[UTType.image.identifier] = image
                
                if let pngData = image.pngData() {
                    items[UTType.png.identifier] = pngData
                }
                
                pasteboardItems.append(items)
            }
            
            UIPasteboard.general.items = pasteboardItems
        }
        
        return (images.count, screenshots.count - images.count, nil)
    }
    
    private func duplicateBatch(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for screenshot in screenshots {
                let duplicate = Screenshot(
                    imageData: screenshot.imageData,
                    filename: "\\(screenshot.filename)_copy",
                    timestamp: Date(),
                    assetIdentifier: nil
                )
                
                // Copy metadata
                duplicate.userTags = screenshot.userTags
                duplicate.userNotes = screenshot.userNotes
                duplicate.extractedText = screenshot.extractedText
                
                modelContext.insert(duplicate)
                processed += 1
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func moveToGroupBatch(_ screenshots: [Screenshot], group: ScreenshotGroup, in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for screenshot in screenshots {
                // Remove from existing groups
                screenshot.groups.removeAll()
                // Add to new group
                screenshot.groups.append(group)
                processed += 1
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func removeFromGroupBatch(_ screenshots: [Screenshot], group: ScreenshotGroup, in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for screenshot in screenshots {
                screenshot.groups.removeAll { $0.id == group.id }
                processed += 1
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func updateMetadataBatch(_ screenshots: [Screenshot], update: ScreenshotMetadataUpdate, in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for screenshot in screenshots {
                if let userNotes = update.userNotes {
                    screenshot.userNotes = userNotes
                }
                
                if let filename = update.filename {
                    screenshot.filename = filename
                }
                
                if let isFavorite = update.isFavorite {
                    screenshot.isFavorite = isFavorite
                }
                
                if let addTags = update.addTags {
                    var currentTags = screenshot.userTags ?? []
                    for tag in addTags {
                        if !currentTags.contains(tag) {
                            currentTags.append(tag)
                        }
                    }
                    screenshot.userTags = currentTags
                }
                
                if let removeTags = update.removeTags {
                    var currentTags = screenshot.userTags ?? []
                    currentTags.removeAll { removeTags.contains($0) }
                    screenshot.userTags = currentTags.isEmpty ? nil : currentTags
                }
                
                processed += 1
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func cleanupDuplicatesBatch(_ screenshots: [Screenshot], in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        // Use duplicate detection service to find and clean up duplicates
        await duplicateService.analyzeForDuplicates(in: modelContext)
        
        var processed = 0
        var failed = 0
        
        for group in duplicateService.duplicateGroups {
            // Only auto-cleanup exact duplicates and high-confidence sequential duplicates
            if group.duplicateType == .exact || 
               (group.duplicateType == .sequential && group.confidence >= 0.9) {
                let success = await duplicateService.executeSuggestedAction(for: group, in: modelContext)
                if success {
                    processed += group.duplicateScreenshots.count
                } else {
                    failed += group.duplicateScreenshots.count
                }
            }
        }
        
        return (processed, failed, nil)
    }
    
    private func bulkRenameBatch(_ screenshots: [Screenshot], pattern: String, in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        
        do {
            for (index, screenshot) in screenshots.enumerated() {
                let newFilename = pattern
                    .replacingOccurrences(of: "{index}", with: "\(index + 1)")
                    .replacingOccurrences(of: "{date}", with: DateFormatter.localizedString(from: screenshot.timestamp, dateStyle: .short, timeStyle: .none))
                    .replacingOccurrences(of: "{time}", with: DateFormatter.localizedString(from: screenshot.timestamp, dateStyle: .none, timeStyle: .short))
                
                screenshot.filename = newFilename
                processed += 1
            }
            try modelContext.save()
            return (processed, 0, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    private func optimizeImagesBatch(_ screenshots: [Screenshot], settings: ImageOptimizationSettings, in modelContext: ModelContext) async -> (processed: Int, failed: Int, error: String?) {
        var processed = 0
        var failed = 0
        
        for screenshot in screenshots {
            guard let image = UIImage(data: screenshot.imageData) else {
                failed += 1
                continue
            }
            
            // Resize if necessary
            let optimizedImage = resizeImage(image, maxDimension: settings.maxDimension)
            
            // Convert to target format
            var optimizedData: Data?
            
            switch settings.targetFormat {
            case .jpeg:
                optimizedData = optimizedImage.jpegData(compressionQuality: settings.compressionQuality)
            case .png:
                optimizedData = optimizedImage.pngData()
            default:
                optimizedData = optimizedImage.jpegData(compressionQuality: settings.compressionQuality)
            }
            
            if let data = optimizedData {
                screenshot.imageData = data
                processed += 1
            } else {
                failed += 1
            }
        }
        
        do {
            try modelContext.save()
            return (processed, failed, nil)
        } catch {
            return (0, screenshots.count, error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    private func resizeImage(_ image: UIImage, maxDimension: Int) -> UIImage {
        let size = image.size
        let maxDim = CGFloat(maxDimension)
        
        if size.width <= maxDim && size.height <= maxDim {
            return image
        }
        
        let ratio = min(maxDim / size.width, maxDim / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func requestConfirmation(for operation: BatchOperation, count: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: operation.displayName,
                    message: count == 1 ? 
                        "This action will affect 1 screenshot." :
                        "This action will affect \\(count) screenshots.",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    continuation.resume(returning: false)
                })
                
                alert.addAction(UIAlertAction(title: "Continue", style: operation.requiresConfirmation ? .destructive : .default) { _ in
                    continuation.resume(returning: true)
                })
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(alert, animated: true)
                }
            }
        }
    }
    
    // MARK: - State Management
    
    private func updateOperationState(
        operation: BatchOperation?,
        isProcessing: Bool,
        totalCount: Int,
        processedCount: Int,
        progress: Double,
        message: String
    ) async {
        await MainActor.run {
            self.currentOperation = operation
            self.isProcessing = isProcessing
            self.totalCount = totalCount
            self.processedCount = processedCount
            self.operationProgress = progress
            self.operationMessage = message
        }
    }
    
    private func updateOperationProgress(
        progress: Double,
        processedCount: Int,
        message: String
    ) async {
        await MainActor.run {
            self.operationProgress = max(0.0, min(1.0, progress))
            self.processedCount = processedCount
            self.operationMessage = message
        }
    }
    
    private func updateOperationMessage(_ message: String) async {
        await MainActor.run {
            self.operationMessage = message
        }
    }
    
    private func recordOperation(_ record: BatchOperationRecord) async {
        await MainActor.run {
            operationHistory.append(record)
            
            // Keep history manageable
            if operationHistory.count > 50 {
                operationHistory.removeFirst(25)
            }
        }
    }
}

// MARK: - Array Extension for Chunking (BatchOperations)

extension Array where Element: AnyObject {
    func batchChunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}