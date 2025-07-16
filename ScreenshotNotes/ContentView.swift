import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    @StateObject private var backgroundSemanticProcessor = BackgroundSemanticProcessor.shared
    @StateObject private var backgroundVisionProcessor = BackgroundVisionProcessor.shared
    @EnvironmentObject private var backgroundOCRProcessor: BackgroundOCRProcessor
    @EnvironmentObject private var photoLibraryService: PhotoLibraryService
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
    
    // 🎯 Sprint 8.5.3.1: Task Synchronization Framework
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var taskCoordinator = TaskCoordinator.shared
    
    // 🎯 Sprint 8.5.3.2: Memory Management & Leak Prevention
    @StateObject private var memoryManager = MemoryManager.shared
    @StateObject private var resourceCleanupManager = ResourceCleanupManager.shared

    init() {
        // Initialize coordinators with proper delegate pattern
        _searchCoordinator = StateObject(wrappedValue: SearchCoordinator())
        _modeCoordinator = StateObject(wrappedValue: ModeCoordinator())
    }
    
    private var filteredScreenshots: [Screenshot] {
        searchCoordinator.filterScreenshots(screenshots)
    }
    
    // MARK: - Smart Suggestions Methods
    
    /// Trigger smart suggestions generation and overlay display
    private func showSmartSuggestions() async {
        let context = SmartSuggestionsService.SuggestionContext(
            currentScreenshots: Array(screenshots.prefix(100)), // Limit for performance
            recentActivity: [],
            timeOfDay: getCurrentTimeOfDay(),
            userBehaviorProfile: nil
        )
        
        let suggestions = await SmartSuggestionsService.shared.generateSuggestionCards(
            for: context,
            in: modelContext
        )
        
        if !suggestions.isEmpty {
            SmartSuggestionsService.shared.showSuggestionOverlay(with: suggestions)
        }
    }
    
    private func getCurrentTimeOfDay() -> SmartSuggestionsService.SuggestionContext.TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
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
                
                // 🎯 Iteration 8.6.2.2: Smart Suggestions overlay
                SmartSuggestionOverlay()
                
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
                    
                    // 🎯 Iteration 8.6.2.2: Smart Suggestions
                    Button(action: {
                        Task {
                            await showSmartSuggestions()
                        }
                    }) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                    }
                    
                    // 🎯 Sprint 8.5.3.1: Task Manager Debug View
                    NavigationLink(destination: TaskManagerDebugView()) {
                        Image(systemName: "cpu")
                            .foregroundColor(.purple)
                    }
                    
                    // 🎯 Sprint 8.5.3.2: Memory Manager Debug View
                    NavigationLink(destination: MemoryManagerDebugView()) {
                        Image(systemName: "memorychip")
                            .foregroundColor(.orange)
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
                // 🎯 Sprint 8.5.3.2: Initialize Memory Management System
                memoryManager.startMonitoring()
                
                // Register all services for automatic cleanup
                backgroundSemanticProcessor.registerForAutomaticCleanup()
                backgroundVisionProcessor.registerForAutomaticCleanup()
                photoLibraryService.registerForAutomaticCleanup()
                ThumbnailService.shared.registerForAutomaticCleanup()
                
                // 🎯 Sprint 8.5.3.1: Coordinated app startup with Task Synchronization Framework
                Task {
                    await taskCoordinator.executeAppStartupWorkflow(
                        modelContext: modelContext,
                        services: AppServices(
                            photoLibraryService: photoLibraryService,
                            thumbnailService: ThumbnailService.shared,
                            backgroundVisionProcessor: backgroundVisionProcessor
                        )
                    )
                }
            }
            .onDisappear {
                // 🎯 Sprint 8.5.3.2: Cleanup when view disappears
                Task {
                    await resourceCleanupManager.performLightCleanup()
                }
            }
            .task(id: screenshots) {
                // 🎯 Sprint 8.5.3.1: Coordinated relationship detection
                await taskManager.execute(
                    category: .backgroundProcessing,
                    priority: .normal,
                    description: "Process relationship detection for \(screenshots.count) screenshots"
                ) {
                    await modeCoordinator.processRelationshipDetection(with: Array(screenshots))
                }
            }
        }
    }
    

}

// MARK: - Delegate Protocol Conformance
extension ContentView: SearchCoordinatorDelegate, ModeCoordinatorDelegate {
    func getScreenshots() -> [Screenshot] {
        return screenshots
    }
}