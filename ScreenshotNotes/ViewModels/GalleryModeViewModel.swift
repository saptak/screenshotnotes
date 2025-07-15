
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
        // 🎯 Sprint 8.5.3.1: Prevent race conditions with coordinated task management
        if isBulkImportInProgress { return }
        
        // Cancel any existing background processing workflows to prevent conflicts
        taskManager.cancelTasks(in: .backgroundProcessing)
        
        isBulkImportInProgress = true
        isRefreshing = true

        // Step 1: Check permissions with coordinated task management
        let permissionGranted = await taskManager.execute(
            category: .userInterface,
            priority: .critical,
            description: "Check photo library permissions"
        ) {
            guard let photoService = self.photoLibraryService else { return false }
            let currentStatus = photoService.authorizationStatus
            if currentStatus != .authorized {
                let newStatus = await photoService.requestPhotoLibraryPermission()
                return newStatus == .authorized
            }
            return true
        }
        
        guard permissionGranted == true else {
            isRefreshing = false
            isBulkImportInProgress = false
            return
        }

        // Step 2: Execute coordinated import workflow
        let batchSize = 10
        let maxImportLimit = 20
        var totalImported = 0
        var totalSkipped = 0
        var hasMore = true
        var batchIndex = 0

        while hasMore && totalImported < maxImportLimit {
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
            
            totalImported += importResult.imported
            totalSkipped += importResult.skipped
            batchIndex += 1
            hasMore = importResult.hasMore
            
            if totalImported >= maxImportLimit {
                hasMore = false
            }
            
            bulkImportProgress = (current: totalImported, total: min(totalImported + totalSkipped, maxImportLimit))

            // Step 3: Coordinate background processing for imported images
            if importResult.imported > 0 {
                _ = await taskManager.execute(
                    category: .backgroundProcessing,
                    priority: .normal,
                    description: "Process imported screenshots"
                ) {
                    // Process screenshots in background
                    return ()
                }
            }
            
            // Controlled delay to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
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
