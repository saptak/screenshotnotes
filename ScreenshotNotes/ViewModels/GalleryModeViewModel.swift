
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
        if isBulkImportInProgress { return }
        isBulkImportInProgress = true
        isRefreshing = true

        let currentStatus = photoLibraryService.authorizationStatus
        if currentStatus != .authorized {
            let newStatus = await photoLibraryService.requestPhotoLibraryPermission()
            if newStatus != .authorized {
                isRefreshing = false
                isBulkImportInProgress = false
                return
            }
        }

        let batchSize = 10
        let maxImportLimit = 20
        var totalImported = 0
        var totalSkipped = 0
        var hasMore = true
        var batchIndex = 0

        while hasMore && totalImported < maxImportLimit {
            let result = await photoLibraryService.importPastScreenshotsBatch(batch: batchIndex, batchSize: batchSize)
            totalImported += result.imported
            totalSkipped += result.skipped
            batchIndex += 1
            hasMore = result.hasMore
            if totalImported >= maxImportLimit {
                hasMore = false
            }
            bulkImportProgress = (current: totalImported, total: min(totalImported + totalSkipped, maxImportLimit))

            if result.imported > 0 {
                Task {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    backgroundOCRProcessor.startBackgroundProcessingIfNeeded(in: modelContext)
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await backgroundSemanticProcessor.processScreenshotsNeedingAnalysis(in: modelContext)
                    await backgroundSemanticProcessor.triggerMindMapRegeneration(in: modelContext)
                }
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        isRefreshing = false
        isBulkImportInProgress = false
        bulkImportProgress = (0, 0)
    }
}
