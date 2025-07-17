
import SwiftUI
import SwiftData

struct GalleryModeRenderer: View {
    @StateObject private var viewModel: GalleryModeViewModel
    @State private var showGroupedView = false
    
    let screenshots: [Screenshot]
    let searchOrchestrator: GlassConversationalSearchOrchestrator
    let viewportManager: PredictiveViewportManager
    let qualityManager: AdaptiveQualityManager

    init(
        screenshots: [Screenshot],
        modelContext: ModelContext,
        photoLibraryService: PhotoLibraryService,
        backgroundOCRProcessor: BackgroundOCRProcessor,
        backgroundSemanticProcessor: BackgroundSemanticProcessor,
        searchOrchestrator: GlassConversationalSearchOrchestrator,
        viewportManager: PredictiveViewportManager,
        qualityManager: AdaptiveQualityManager
    ) {
        self.screenshots = screenshots
        self.searchOrchestrator = searchOrchestrator
        self.viewportManager = viewportManager
        self.qualityManager = qualityManager
        _viewModel = StateObject(wrappedValue: GalleryModeViewModel(
            modelContext: modelContext,
            photoLibraryService: photoLibraryService,
            backgroundOCRProcessor: backgroundOCRProcessor,
            backgroundSemanticProcessor: backgroundSemanticProcessor
        ))
    }

    var body: some View {
        VStack {
            // Gallery view toggle (only show when we have screenshots)
            if !screenshots.isEmpty && !viewModel.isImporting {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showGroupedView.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showGroupedView ? "rectangle.grid.1x2" : "rectangle.3.group")
                                .font(.system(size: 14, weight: .medium))
                            Text(showGroupedView ? "Grid View" : "Smart Groups")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
            
            if screenshots.isEmpty && !viewModel.isImporting {
                if let photoService = viewModel.getPhotoLibraryService,
                   let ocrProcessor = viewModel.getBackgroundOCRProcessor,
                   let semanticProcessor = viewModel.getBackgroundSemanticProcessor,
                   let context = viewModel.getModelContext {
                    EmptyStateView(
                        onImportTapped: { viewModel.showingImportSheet = true },
                        photoLibraryService: photoService,
                        isRefreshing: $viewModel.isRefreshing,
                        bulkImportProgress: $viewModel.bulkImportProgress,
                        isBulkImportInProgress: $viewModel.isBulkImportInProgress,
                        backgroundOCRProcessor: ocrProcessor,
                        backgroundSemanticProcessor: semanticProcessor,
                        modelContext: context,
                        scrollOffset: $viewModel.galleryScrollOffset
                    )
                    .onAppear {
                        print("📸 GalleryModeRenderer: EmptyStateView appeared with services available")
                        print("📸 - photoService authorization: \(photoService.authorizationStatus)")
                    }
                } else {
                    // Fallback empty state when services are not available
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Screenshots")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Services not available")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .id("enhanced-gallery-empty-state")
                    .onAppear {
                        print("📸 GalleryModeRenderer: Showing fallback empty state - services not available")
                        print("📸 - photoService: \(viewModel.getPhotoLibraryService != nil ? "✅" : "❌")")
                        print("📸 - ocrProcessor: \(viewModel.getBackgroundOCRProcessor != nil ? "✅" : "❌")")
                        print("📸 - semanticProcessor: \(viewModel.getBackgroundSemanticProcessor != nil ? "✅" : "❌")")
                        print("📸 - context: \(viewModel.getModelContext != nil ? "✅" : "❌")")
                    }
                }
            } else {
                if let photoService = viewModel.getPhotoLibraryService,
                   let context = viewModel.getModelContext,
                   let ocrProcessor = viewModel.getBackgroundOCRProcessor,
                   let semanticProcessor = viewModel.getBackgroundSemanticProcessor {
                    
                    // Show either grouped view or standard grid view
                    if showGroupedView {
                        GroupedGalleryView()
                            .environment(\.modelContext, context)
                            .id("enhanced-gallery-grouped")
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        ScreenshotGridView(
                            screenshots: screenshots,
                            photoLibraryService: photoService,
                            isRefreshing: $viewModel.isRefreshing,
                            bulkImportProgress: $viewModel.bulkImportProgress,
                            isBulkImportInProgress: $viewModel.isBulkImportInProgress,
                            backgroundOCRProcessor: ocrProcessor,
                            backgroundSemanticProcessor: semanticProcessor,
                            modelContext: context,
                            searchOrchestrator: searchOrchestrator,
                            selectedScreenshot: $viewModel.selectedScreenshot,
                            scrollOffset: $viewModel.galleryScrollOffset,
                            viewportManager: viewportManager,
                            qualityManager: qualityManager,
                            onRefresh: viewModel.refreshScreenshots
                        )
                        .id("enhanced-gallery-grid")
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                } else {
                    Text("Services not available")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let onImportTapped: () -> Void
    let photoLibraryService: PhotoLibraryService
    @Binding var isRefreshing: Bool
    @Binding var bulkImportProgress: (current: Int, total: Int)
    @Binding var isBulkImportInProgress: Bool
    let backgroundOCRProcessor: BackgroundOCRProcessor
    let backgroundSemanticProcessor: BackgroundSemanticProcessor
    let modelContext: ModelContext
    @Binding var scrollOffset: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Pull-to-import message (shows when user pulls down)
                    if scrollOffset > 10 && isRefreshing == false && !isBulkImportInProgress {
                        PullToImportMessageView()
                            .opacity(0.8)
                            .padding(.top, 8) // Visible at the top
                            .padding(.bottom, 8)
                    }
                    
                    // Progressive import progress indicator
                    if isRefreshing && bulkImportProgress.total > 0 {
                        VStack(spacing: 16) {
                            Text("Importing \(bulkImportProgress.current) of \(bulkImportProgress.total) screenshots")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            ProgressView(value: Double(bulkImportProgress.current), total: Double(bulkImportProgress.total))
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(width: 280)
                                .scaleEffect(1.2)
                        }
                        .padding(.horizontal, 40)
                    } else if isRefreshing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .controlSize(.large)
                            
                            Text("Importing screenshots...")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    } else {
                        // Main empty state content - focused on pull-to-refresh
                        VStack(spacing: 24) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 72, weight: .thin))
                                .foregroundColor(.blue)
                                .symbolEffect(.bounce, options: .repeating)
                            
                            Text("Pull down to import screenshots")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                                .id("pull-to-import-text") // Add unique ID to force re-rendering
                            
                            Text("Import up to 20 latest screenshots from Apple Photos")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                            
                            // Photo access guidance
                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                    
                                    Text("Photo Access Required")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                VStack(spacing: 8) {
                                    Text("When prompted, grant access to \"All Photos\" to import your screenshots.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("You can also enable photo access in Settings > Screenshot Vault > Photos.")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 500) // Ensure enough space for pull gesture
                .background(
                    GeometryReader {
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: $0.frame(in: .global).minY)
                    }
                )
            }
            .coordinateSpace(name: "pullArea")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                // Convert the global position to a proper scroll offset
                let containerTop = geometry.frame(in: .global).minY
                scrollOffset = max(0, offset - containerTop)
            }
            .refreshable {
                await refreshScreenshots()
            }
        }
    }
    
    private func refreshScreenshots() async {
        print("📸 Pull-to-import triggered")
        
        // Prevent concurrent bulk imports
        if isBulkImportInProgress {
            print("📸 Bulk import already in progress, skipping")
            return
        }
        
        print("📸 Starting bulk import process")
        isBulkImportInProgress = true
        isRefreshing = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Check and request photo permission if needed
        let currentStatus = photoLibraryService.authorizationStatus
        print("📸 Current photo permission status: \(currentStatus)")
        
        if currentStatus != .authorized {
            print("📸 Photo permission not granted (\(currentStatus)), requesting permission...")
            let newStatus = await photoLibraryService.requestPhotoLibraryPermission()
            print("📸 Permission request result: \(newStatus)")
            
            if newStatus != .authorized {
                print("📸 Photo permission denied, cannot import screenshots")
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
                isRefreshing = false
                isBulkImportInProgress = false
                return
            }
            
            print("📸 Photo permission granted, proceeding with import")
        } else {
            print("📸 Photo permission already granted, proceeding with import")
        }

        // Extremely lazy, incremental import in batches with 20-screenshot limit
        let batchSize = 10
        let maxImportLimit = 20
        var totalImported = 0
        var totalSkipped = 0
        var hasMore = true
        var batchIndex = 0

        while hasMore && totalImported < maxImportLimit {
            print("📸 Processing batch \(batchIndex + 1) (batchSize: \(batchSize))")
            let result = await photoLibraryService.importPastScreenshotsBatch(batch: batchIndex, batchSize: batchSize)
            print("📸 Batch \(batchIndex + 1) result: imported=\(result.imported), skipped=\(result.skipped), hasMore=\(result.hasMore)")
            
            totalImported += result.imported
            totalSkipped += result.skipped
            batchIndex += 1
            hasMore = result.hasMore
            
            // Stop if we've reached the import limit
            if totalImported >= maxImportLimit {
                hasMore = false
                print("📸 Reached import limit of \(maxImportLimit), stopping")
            }
            
            // Update progress for UI feedback
            bulkImportProgress = (current: totalImported, total: min(totalImported + totalSkipped, maxImportLimit))
            print("📸 Progress: \(bulkImportProgress.current)/\(bulkImportProgress.total)")

            // Allow UI to update immediately after each batch import
            if result.imported > 0 {
                // Schedule background processing (rate-limited to prevent overlapping tasks)
                Task {
                    // Small delay to allow UI update
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                    
                    backgroundOCRProcessor.startBackgroundProcessingIfNeeded(in: modelContext)
                    
                    // Wait briefly for OCR to initialize  
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    
                    await backgroundSemanticProcessor.processScreenshotsNeedingAnalysis(in: modelContext)
                    await backgroundSemanticProcessor.triggerMindMapRegeneration(in: modelContext)
                    
                    print("✅ Background processing completed for batch")
                }
            }

            // Shorter yield for more responsive UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s between batches
        }

        let notificationFeedback = UINotificationFeedbackGenerator()
        if totalImported > 0 {
            notificationFeedback.notificationOccurred(.success)
            print("📸 ✅ Pull-to-refresh import SUCCESS: \(totalImported) imported, \(totalSkipped) skipped (limit: \(maxImportLimit))")
        } else {
            notificationFeedback.notificationOccurred(.warning)
            print("📸 ⚠️ Pull-to-refresh import WARNING: \(totalImported) imported, \(totalSkipped) skipped (limit: \(maxImportLimit))")
        }
        
        print("📸 Resetting import state")
        isRefreshing = false
        isBulkImportInProgress = false
        bulkImportProgress = (0, 0) // Reset progress
    }
}

struct ScreenshotGridView: View {
    let screenshots: [Screenshot]
    let photoLibraryService: PhotoLibraryService
    @Binding var isRefreshing: Bool
    @Binding var bulkImportProgress: (current: Int, total: Int)
    @Binding var isBulkImportInProgress: Bool
    let backgroundOCRProcessor: BackgroundOCRProcessor
    let backgroundSemanticProcessor: BackgroundSemanticProcessor
    let modelContext: ModelContext
    let searchOrchestrator: GlassConversationalSearchOrchestrator
    @Binding var selectedScreenshot: Screenshot?
    @Binding var scrollOffset: CGFloat
    @ObservedObject var viewportManager: PredictiveViewportManager
    @ObservedObject var qualityManager: AdaptiveQualityManager
    let onRefresh: () async -> Void
    @Namespace private var heroNamespace
    @StateObject private var performanceMonitor = GalleryPerformanceMonitor.shared
    @StateObject private var thumbnailService = ThumbnailService.shared
    

    private func computeColumns(for width: CGFloat) -> [GridItem] {
        let minThumbnailWidth: CGFloat = 150
        let columnSpacing: CGFloat = 16
        let sidePadding: CGFloat = 20 * 2 // 20 on each side
        
        let effectiveWidth = width - sidePadding
        let numberOfColumns = max(1, Int(effectiveWidth / (minThumbnailWidth + columnSpacing)))
        
        return Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: numberOfColumns)
    }

    var body: some View {
        GeometryReader { geometry in
            let columns = computeColumns(for: geometry.size.width)
            
            VirtualizedGridView(
                items: screenshots,
                columns: columns,
                itemHeight: 220,
                scrollOffset: $scrollOffset,
                showPullMessage: true,
                isRefreshing: isRefreshing,
                isBulkImportInProgress: isBulkImportInProgress,
                onRefresh: onRefresh
            ) { screenshot in
                OptimizedThumbnailView(
                    screenshot: screenshot,
                    size: CGSize(width: 160, height: 200),
                    onTap: {
                        selectedScreenshot = screenshot
                    }
                )
            }
            .frame(maxWidth: .infinity)
        }
        .fullScreenCover(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(
                screenshot: screenshot,
                heroNamespace: heroNamespace,
                allScreenshots: screenshots,
                onDelete: nil
            )
        }
        .onAppear {
            performanceMonitor.startMonitoring()
            
            // Phase 2: Update collection size for adaptive optimization
            qualityManager.updateCollectionSize(screenshots.count)
            
            // Preload thumbnails for better scrolling performance
            if screenshots.count <= 100 {
                thumbnailService.preloadThumbnails(for: Array(screenshots.prefix(20)))
            }
        }
        .onDisappear {
            performanceMonitor.stopMonitoring()
        }
        .onChange(of: scrollOffset) { _, newOffset in
            // Phase 2: Update viewport manager with scroll changes
            viewportManager.updateScrollOffset(newOffset)
        }
        .onChange(of: screenshots.count) { _, newCount in
            // Phase 2: Update collection size when screenshots change
            qualityManager.updateCollectionSize(newCount)
        }
        .onReceive(NotificationCenter.default.publisher(for: .performanceOptimizationNeeded)) { notification in
            handlePerformanceOptimization(notification)
        }
    }
    
    private func handlePerformanceOptimization(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "lowFPS":
            print("🐌 Optimizing for low FPS")
            // Force quality manager to use optimized quality
            qualityManager.forceQualityLevel(.optimized)
            // Clear thumbnail cache to reduce memory pressure
            ThumbnailService.shared.clearCache()
            // Reduce viewport prediction to save resources
            viewportManager.setPerformanceMode(enabled: true)
            
        case "highMemory":
            print("🧠 Optimizing for high memory usage")
            thumbnailService.clearCache()
            
        case "thermal":
            print("🔥 Optimizing for thermal pressure")
            thumbnailService.clearCache()
            // Could pause thumbnail generation temporarily
            
        default:
            break
        }
    }
}

struct PullToImportMessageView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.accentColor)
            Text("Pull to import 20 more Screenshots. Long-press to share, copy or delete.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(.systemBackground).opacity(0.95))
                .shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
        )
        .frame(maxWidth: .infinity)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}


