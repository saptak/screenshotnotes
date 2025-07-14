import SwiftUI
import SwiftData

/// Renders the primary gallery interface, handling both the empty state and the screenshot grid.
/// This view is responsible for orchestrating the display of screenshots and managing user interactions
/// like pull-to-refresh for importing.
struct GalleryModeRenderer: View {
    // MARK: - Data Source
    let screenshots: [Screenshot]
    let modelContext: ModelContext
    
    // MARK: - Services
    let photoLibraryService: PhotoLibraryService
    let backgroundOCRProcessor: BackgroundOCRProcessor
    let backgroundSemanticProcessor: BackgroundSemanticProcessor
    let searchOrchestrator: GlassConversationalSearchOrchestrator
    let viewportManager: PredictiveViewportManager
    let qualityManager: AdaptiveQualityManager

    // MARK: - State Bindings from ContentView
    @Binding var isRefreshing: Bool
    @Binding var bulkImportProgress: (current: Int, total: Int)
    @Binding var isBulkImportInProgress: Bool
    @Binding var selectedScreenshot: Screenshot?
    @Binding var galleryScrollOffset: CGFloat
    @Binding var showingImportSheet: Bool
    @Binding var isImporting: Bool

    // MARK: - Feature Flags
    /// Hook for future constellation hint features. (Sprint 8.2.2)
    var showConstellationHints: Bool = false

    var body: some View {
        Group {
                if screenshots.isEmpty && !isImporting {
                    EmptyStateView(
                        onImportTapped: { showingImportSheet = true },
                        photoLibraryService: photoLibraryService,
                        isRefreshing: $isRefreshing,
                        bulkImportProgress: $bulkImportProgress,
                        isBulkImportInProgress: $isBulkImportInProgress,
                        backgroundOCRProcessor: backgroundOCRProcessor,
                        backgroundSemanticProcessor: backgroundSemanticProcessor,
                        modelContext: modelContext,
                        scrollOffset: $galleryScrollOffset
                        // The .refreshable modifier in EmptyStateView will call its own refreshScreenshots method.
                        // This will be refactored in a later step to use a centralized function.
                    )
                    .id("enhanced-gallery-empty-state")
            } else {
                ScreenshotGridView(
                    screenshots: screenshots,
                    photoLibraryService: photoLibraryService,
                    isRefreshing: $isRefreshing,
                    bulkImportProgress: $bulkImportProgress,
                    isBulkImportInProgress: $isBulkImportInProgress,
                    backgroundOCRProcessor: backgroundOCRProcessor,
                    backgroundSemanticProcessor: backgroundSemanticProcessor,
                    modelContext: modelContext,
                    searchOrchestrator: searchOrchestrator,
                    selectedScreenshot: $selectedScreenshot,
                    scrollOffset: $galleryScrollOffset,
                    viewportManager: viewportManager,
                    qualityManager: qualityManager
                )
                .id("enhanced-gallery-grid")
            }
        }
    }
}