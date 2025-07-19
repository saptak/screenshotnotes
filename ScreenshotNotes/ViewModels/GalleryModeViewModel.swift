
import SwiftUI
import SwiftData
import os.log

@MainActor
class GalleryModeViewModel: ObservableObject, MemoryTrackable, ResourceCleanupProtocol {
    @Published var isRefreshing = false
    @Published var bulkImportProgress: (current: Int, total: Int) = (0, 0)
    @Published var isBulkImportInProgress = false
    @Published var selectedScreenshot: Screenshot?
    @Published var galleryScrollOffset: CGFloat = 0
    @Published var showingImportSheet = false
    @Published var isImporting = false

    // 🎯 Sprint 8.5.3.2: Memory Management & Leak Prevention
    private var modelContext: ModelContext? // ModelContext is a struct, cannot be weak
    private weak var photoLibraryService: PhotoLibraryService?
    private weak var backgroundOCRProcessor: BackgroundOCRProcessor?
    private weak var backgroundSemanticProcessor: BackgroundSemanticProcessor?
    
    // 🎯 Sprint 8.5.3.1: Task Synchronization Framework
    private let taskManager = TaskManager.shared
    
    // 🎯 Sprint 8.5.3.2: Memory Management
    private let memoryManager = MemoryManager.shared
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "GalleryModeViewModel")

    init(
        modelContext: ModelContext,
        photoLibraryService: PhotoLibraryService,
        backgroundOCRProcessor: BackgroundOCRProcessor,
        backgroundSemanticProcessor: BackgroundSemanticProcessor
    ) {
        self.modelContext = modelContext
        self.photoLibraryService = photoLibraryService
        self.backgroundOCRProcessor = backgroundOCRProcessor
        self.backgroundSemanticProcessor = backgroundSemanticProcessor
        
        // 🎯 Sprint 8.5.3.2: Initialize memory management
        startMemoryTracking()
        registerForAutomaticCleanup()
        
        logger.info("GalleryModeViewModel: Initialized with memory tracking")
    }
    
    deinit {
        // 🎯 Sprint 8.5.3.2: Proper cleanup in deinit
        Task { @MainActor in
            stopMemoryTracking()
            unregisterFromAutomaticCleanup()
        }
        
        // Cancel any ongoing operations
        Task {
            await taskManager.cancelTasks(in: .dataImport)
        }
        
        logger.info("GalleryModeViewModel: Deallocated")
    }
    
    // MARK: - Public Accessors for Services
    
    public var getPhotoLibraryService: PhotoLibraryService? {
        return photoLibraryService
    }
    
    public var getBackgroundOCRProcessor: BackgroundOCRProcessor? {
        return backgroundOCRProcessor
    }
    
    public var getBackgroundSemanticProcessor: BackgroundSemanticProcessor? {
        return backgroundSemanticProcessor
    }
    
    public var getModelContext: ModelContext? {
        return modelContext
    }

    func refreshScreenshots() async {
        print("📸 GalleryModeViewModel: refreshScreenshots called")
        print("📸 GalleryModeViewModel: Current state - isRefreshing: \(isRefreshing), isBulkImportInProgress: \(isBulkImportInProgress)")
        
        // 🎯 Sprint 8.5.3.1: Prevent race conditions with coordinated task management
        if isBulkImportInProgress { 
            print("📸 GalleryModeViewModel: Bulk import already in progress, returning")
            return 
        }
        
        print("📸 GalleryModeViewModel: Starting refresh process")
        
        // Set state first to prevent race conditions
        isBulkImportInProgress = true
        isRefreshing = true
        
        // Cancel any existing background processing workflows to prevent conflicts
        taskManager.cancelTasks(in: .backgroundProcessing)
        
        // Add haptic feedback for user interaction
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Step 1: Check permissions with coordinated task management
        print("📸 GalleryModeViewModel: Checking photo library permissions")
        let permissionGranted = await taskManager.execute(
            category: .userInterface,
            priority: .critical,
            description: "Check photo library permissions"
        ) {
            guard let photoService = self.photoLibraryService else { 
                print("📸 GalleryModeViewModel: PhotoLibraryService is nil")
                return false 
            }
            let currentStatus = photoService.authorizationStatus
            print("📸 GalleryModeViewModel: Current authorization status: \(currentStatus)")
            if currentStatus != .authorized {
                print("📸 GalleryModeViewModel: Requesting photo library permission")
                let newStatus = await photoService.requestPhotoLibraryPermission()
                print("📸 GalleryModeViewModel: New authorization status: \(newStatus)")
                return newStatus == .authorized
            }
            return true
        }
        
        guard permissionGranted == true else {
            print("📸 GalleryModeViewModel: Permission not granted, stopping refresh")
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
            isRefreshing = false
            isBulkImportInProgress = false
            return
        }
        
        print("📸 GalleryModeViewModel: Permission granted, starting batch import")

        // Step 2: Execute coordinated import workflow with 20-screenshot limit
        let batchSize = 10
        let maxImportLimit = 20
        var totalImported = 0
        var totalSkipped = 0
        var hasMore = true
        var batchIndex = 0

        while hasMore && totalImported < maxImportLimit {
            print("📸 GalleryModeViewModel: Processing batch \(batchIndex + 1) (batchSize: \(batchSize))")
            
            // Import batch with coordinated task management
            let result = await taskManager.execute(
                category: .dataImport,
                priority: .high,
                description: "Import screenshot batch \(batchIndex + 1)"
            ) {
                guard let photoService = self.photoLibraryService else { 
                    return (imported: 0, skipped: 0, hasMore: false)
                }
                return await photoService.importPastScreenshotsBatch(batch: batchIndex, batchSize: batchSize)
            }
            
            guard let importResult = result else { break }
            
            print("📸 GalleryModeViewModel: Batch \(batchIndex + 1) result: imported=\(importResult.imported), skipped=\(importResult.skipped), hasMore=\(importResult.hasMore)")
            
            totalImported += importResult.imported
            totalSkipped += importResult.skipped
            batchIndex += 1
            hasMore = importResult.hasMore
            
            // Stop if we've reached the import limit
            if totalImported >= maxImportLimit {
                hasMore = false
                print("📸 GalleryModeViewModel: Reached import limit of \(maxImportLimit), stopping")
            }
            
            // Update progress for UI feedback
            bulkImportProgress = (current: totalImported, total: min(totalImported + totalSkipped, maxImportLimit))
            print("📸 GalleryModeViewModel: Progress: \(bulkImportProgress.current)/\(bulkImportProgress.total)")

            // Shorter yield for more responsive UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s between batches
        }
        
        // Trigger background processing ONCE after all imports are complete
        if totalImported > 0 {
            print("📸 GalleryModeViewModel: All imports complete (\(totalImported) screenshots), starting background processing")
            
            guard let context = modelContext,
                  let semanticProcessor = backgroundSemanticProcessor else {
                print("📸 GalleryModeViewModel: Missing context or semantic processor")
                isRefreshing = false
                isBulkImportInProgress = false
                bulkImportProgress = (0, 0)
                return
            }
            
            // Wait briefly for imports to settle
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            // Use shared instance to avoid conflicts
            await BackgroundSemanticProcessor.shared.processScreenshotsNeedingAnalysis(in: context)
            await BackgroundSemanticProcessor.shared.triggerMindMapRegeneration(in: context)
            
            print("📸 GalleryModeViewModel: Background processing completed for all imported screenshots")
        }
        
        // Provide user feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        if totalImported > 0 {
            notificationFeedback.notificationOccurred(.success)
            print("📸 ✅ GalleryModeViewModel: Import SUCCESS: \(totalImported) imported, \(totalSkipped) skipped (limit: \(maxImportLimit))")
        } else {
            notificationFeedback.notificationOccurred(.warning)
            print("📸 ⚠️ GalleryModeViewModel: Import WARNING: \(totalImported) imported, \(totalSkipped) skipped (limit: \(maxImportLimit))")
        }
        
        print("📸 GalleryModeViewModel: Resetting import state")
        isRefreshing = false
        isBulkImportInProgress = false
        bulkImportProgress = (0, 0)
    }
    
    // MARK: - 🎯 Sprint 8.5.3.2: ResourceCleanupProtocol Implementation
    
    public func performLightCleanup() async {
        logger.info("GalleryModeViewModel: Performing light cleanup")
        
        // Clear progress if not actively importing
        if !isBulkImportInProgress && !isRefreshing {
            bulkImportProgress = (0, 0)
        }
        
        // Clear selected screenshot if not needed
        if !showingImportSheet {
            selectedScreenshot = nil
        }
        
        // Reset scroll offset if reasonable
        if abs(galleryScrollOffset) < 10 {
            galleryScrollOffset = 0
        }
    }
    
    public func performDeepCleanup() async {
        logger.warning("GalleryModeViewModel: Performing deep cleanup")
        
        // Cancel any ongoing operations if not critical
        if isBulkImportInProgress || isRefreshing {
            taskManager.cancelTasks(in: .dataImport)
            taskManager.cancelTasks(in: .backgroundProcessing)
            
            await MainActor.run {
                isBulkImportInProgress = false
                isRefreshing = false
                isImporting = false
                bulkImportProgress = (0, 0)
            }
        }
        
        // Clear all temporary state
        await performLightCleanup()
        
        // Clear UI state
        selectedScreenshot = nil
        showingImportSheet = false
        galleryScrollOffset = 0
    }
    
    public nonisolated func getEstimatedMemoryUsage() -> UInt64 {
        var usage: UInt64 = 0
        
        // Base ViewModel size
        usage += 2048 // Larger estimate for GalleryModeViewModel
        
        // Add estimated memory for state
        usage += 1024 // State overhead estimate
        
        return usage
    }
    
    public nonisolated var cleanupPriority: Int { 70 } // High priority for main gallery ViewModel
    
    public nonisolated var cleanupIdentifier: String { "GalleryModeViewModel" }
}
