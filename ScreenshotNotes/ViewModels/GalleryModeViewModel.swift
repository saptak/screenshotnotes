
import SwiftUI
import SwiftData

@MainActor
class GalleryModeViewModel: ObservableObject {
    @Published var isRefreshing = false
    @Published var bulkImportProgress: (current: Int, total: Int) = (0, 0)
    @Published var isBulkImportInProgress = false
    @Published var selectedScreenshot: Screenshot?
    @Published var galleryScrollOffset: CGFloat = 0
    @Published var showingImportSheet = false
    @Published var isImporting = false

    let modelContext: ModelContext
    let photoLibraryService: PhotoLibraryService
    let backgroundOCRProcessor: BackgroundOCRProcessor
    let backgroundSemanticProcessor: BackgroundSemanticProcessor
    
    // 🎯 Sprint 8.5.3.1: Task Synchronization Framework
    private let taskManager = TaskManager.shared

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
            let currentStatus = self.photoLibraryService.authorizationStatus
            if currentStatus != .authorized {
                let newStatus = await self.photoLibraryService.requestPhotoLibraryPermission()
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
                await self.photoLibraryService.importPastScreenshotsBatch(batch: batchIndex, batchSize: batchSize)
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
}
