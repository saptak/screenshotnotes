import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    @StateObject private var backgroundSemanticProcessor = BackgroundSemanticProcessor()
    @StateObject private var backgroundVisionProcessor = BackgroundVisionProcessor()
    @StateObject private var photoLibraryService = PhotoLibraryService()
    @EnvironmentObject private var backgroundOCRProcessor: BackgroundOCRProcessor
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedScreenshot: Screenshot?
    
    // 🎯 Sprint 8.5.2: Error handling integration
    @StateObject private var errorHandler = AppErrorHandler.shared
    
    // Phase 2: Viewport management for predictive loading
    @State private var scrollOffset: CGFloat = 0
    @StateObject private var viewportManager = PredictiveViewportManager.shared
    @StateObject private var qualityManager = AdaptiveQualityManager.shared
    
    // 🎯 Sprint 8.5.1: Coordinators for better separation of concerns
    @StateObject private var searchCoordinator: SearchCoordinator
    @StateObject private var modeCoordinator: ModeCoordinator

    init() {
        // Initialize coordinators with proper delegate pattern
        _searchCoordinator = StateObject(wrappedValue: SearchCoordinator())
        _modeCoordinator = StateObject(wrappedValue: ModeCoordinator())
    }
    
    private var filteredScreenshots: [Screenshot] {
        searchCoordinator.filterScreenshots(screenshots)
    }
    
    // MARK: - 🎯 Sprint 5.4.1: Glass Search Bar View Components
    
    /// Main content area with adaptive interface mode support
    private var mainContentArea: some View {
        modeCoordinator.getContentView(
            screenshots: filteredScreenshots,
            modelContext: modelContext,
            photoLibraryService: photoLibraryService,
            backgroundOCRProcessor: backgroundOCRProcessor,
            backgroundSemanticProcessor: backgroundSemanticProcessor,
            searchOrchestrator: searchCoordinator.searchOrchestrator,
            viewportManager: viewportManager,
            qualityManager: qualityManager
        )
        .padding(.bottom, 100) // Space for Glass search bar
    }
    
    
    /// Bottom Glass search bar with conversational microphone integration
    private var bottomGlassSearchBar: some View {
        GlassSearchBar(
            searchText: $searchCoordinator.searchText,
            isActive: $searchCoordinator.searchOrchestrator.isSearchBarActive,
            microphoneState: $searchCoordinator.searchOrchestrator.microphoneState,
            placeholder: "Search screenshots with voice or text...",
            onMicrophoneTapped: searchCoordinator.searchOrchestrator.handleMicrophoneTapped,
            onSearchSubmitted: { query in
                searchCoordinator.handleSearchSubmitted(query: query)
            },
            onClearTapped: searchCoordinator.searchOrchestrator.handleSearchCleared
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content area
                mainContentArea
                
                // 🎯 Sprint 5.4.1: Bottom Glass Search Bar
                VStack {
                    Spacer()
                    bottomGlassSearchBar
                }
                
                // Add the contextual menu overlay
                ContextualMenuOverlay()
                
                // 🎯 Sprint 8.5.2: Error presentation overlay
                ErrorPresentationView(errorHandler: errorHandler)
            }
            .navigationTitle("Screenshot Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Conversational AI Search - Remove since we have Glass search bar
                    // Button(action: {
                    //     showingConversationalSearch = true
                    // }) {
                    //     Image(systemName: "sparkles.rectangle.stack")
                    //         .foregroundColor(.blue)
                    // }
                    
                    // 🧠 Sprint 6.1.1: Mind Map Navigation
                    Button(action: {
                        modeCoordinator.showMindMap()
                    }) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        modeCoordinator.showSettings()
                    }) {
                        Image(systemName: "gearshape")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    Button(action: {
                        // This is now handled by the GalleryModeViewModel
                    }) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
            }
            // 🎯 Sprint 8.5.1: Search coordination through SearchCoordinator
            .onChange(of: searchCoordinator.searchText) { _, newValue in
                searchCoordinator.processSearchTextChange(newValue, screenshots: screenshots)
            }
            .onChange(of: selectedItems) { _, newItems in
                if !newItems.isEmpty {
                    Task {
                        // This is now handled by the GalleryModeViewModel
                        // await importImages(from: newItems)
                        selectedItems = []
                    }
                }
            }
            .onChange(of: selectedScreenshot) { oldValue, newValue in
                // Reset search bar focus when returning from detail view
                if oldValue != nil && newValue == nil {
                    // Reset orchestrator state but preserve search text and results
                    searchCoordinator.resetSearchBarFocus()
                    
                    // Force dismiss keyboard - most reliable method
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(isPresented: $modeCoordinator.showingSettings) {
                SettingsView(photoLibraryService: photoLibraryService)
            }
            .sheet(isPresented: $searchCoordinator.searchOrchestrator.showingConversationalSearch) {
                ConversationalSearchView(
                    searchText: $searchCoordinator.searchText,
                    isPresented: $searchCoordinator.searchOrchestrator.showingConversationalSearch,
                    onSearchSubmitted: { query in
                        searchCoordinator.searchText = query
                        searchCoordinator.searchOrchestrator.showingConversationalSearch = false
                    }
                )
            }
            .fullScreenCover(isPresented: $searchCoordinator.searchOrchestrator.showingVoiceInput) {
                VoiceInputView(
                    searchText: $searchCoordinator.searchText,
                    isPresented: $searchCoordinator.searchOrchestrator.showingVoiceInput,
                    onSearchSubmitted: { query in
                        searchCoordinator.searchText = query
                        searchCoordinator.searchOrchestrator.showingVoiceInput = false
                    }
                )
            }
            .fullScreenCover(isPresented: $modeCoordinator.showingMindMap) {
                MindMapView()
            }
            .onAppear {
                // 🎯 Sprint 8.5.2: Set up services with error handling
                Task {
                    let result = await errorHandler.handleWithRetry(
                        operation: {
                            photoLibraryService.setModelContext(modelContext)
                            
                            // Set up enhanced thumbnail services with ModelContext
                            ThumbnailService.shared.setModelContext(modelContext)
                            
                            // Initialize enhanced vision processing
                            backgroundVisionProcessor.setModelContext(modelContext)
                        },
                        context: .photoImport,
                        source: "ContentView.onAppear"
                    )
                    
                    switch result {
                    case .success:
                        // Start background processing only if setup succeeded
                        await startBackgroundProcessing()
                    case .failure(let error):
                        errorHandler.handle(error, context: .photoImport, source: "ContentView.onAppear")
                    }
                }
            }
            .task(id: screenshots) {
                // Process relationship detection through mode coordinator
                await modeCoordinator.processRelationshipDetection(with: Array(screenshots))
            }
        }
    }
    
    // MARK: - 🎯 Sprint 8.5.2: Background Processing with Error Handling
    
    private func startBackgroundProcessing() async {
        // Start background vision processing with error handling
        let visionResult = await errorHandler.handleWithRetry(
            operation: {
                await backgroundVisionProcessor.startProcessing()
            },
            context: .background,
            maxRetries: 2,
            source: "ContentView.startBackgroundProcessing"
        )
        
        if case .success = visionResult {
            // Schedule periodic processing only if initial processing succeeded
            backgroundVisionProcessor.scheduleBackgroundVisionProcessing()
        }
        
        // Start semantic processing with error handling
        let semanticResult = await errorHandler.handleWithRetry(
            operation: {
                await backgroundSemanticProcessor.processScreenshotsNeedingAnalysis(in: modelContext)
            },
            context: .background,
            maxRetries: 2,
            source: "ContentView.startBackgroundProcessing"
        )
        
        switch (visionResult, semanticResult) {
        case (.success, .success):
            print("ContentView: All background processing started successfully")
        case (.failure(let visionError), .success):
            print("ContentView: Vision processing failed: \(visionError.localizedDescription)")
        case (.success, .failure(let semanticError)):
            print("ContentView: Semantic processing failed: \(semanticError.localizedDescription)")
        case (.failure(let visionError), .failure(let semanticError)):
            print("ContentView: Both processing systems failed - Vision: \(visionError.localizedDescription), Semantic: \(semanticError.localizedDescription)")
        }
    }
}

// MARK: - Delegate Protocol Conformance
extension ContentView: SearchCoordinatorDelegate, ModeCoordinatorDelegate {
    func getScreenshots() -> [Screenshot] {
        return screenshots
    }
}