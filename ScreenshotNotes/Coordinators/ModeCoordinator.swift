import SwiftUI
import SwiftData

/// ModeCoordinator manages interface mode state and navigation for ContentView
/// Following the Coordinator pattern for better separation of concerns and testability
@MainActor
class ModeCoordinator: ObservableObject {
    // MARK: - Mode State Properties
    @Published var showingMindMap = false
    @Published var showingSettings = false
    @Published var currentMode: InterfaceMode = .gallery
    
    // MARK: - Interface Management
    @Published var interfaceSettings: InterfaceSettings
    @Published var modeManager: InterfaceModeManager
    @Published var relationshipDetector: ContentRelationshipDetector
    
    // MARK: - Private Properties
    private var delegate: ModeCoordinatorDelegate?
    
    // MARK: - Initialization
    init(delegate: ModeCoordinatorDelegate? = nil) {
        self.delegate = delegate
        self.interfaceSettings = InterfaceSettings()
        self.modeManager = InterfaceModeManager.shared
        self.relationshipDetector = ContentRelationshipDetector.shared
        
        // Initialize current mode from manager
        self.currentMode = modeManager.currentMode
        
        // Set up two-way binding between currentMode and modeManager
        self.setupModeBinding()
    }
    
    // MARK: - Public Methods
    
    /// Determines if Enhanced Interface is enabled
    var isEnhancedInterfaceEnabled: Bool {
        interfaceSettings.isUsingEnhancedInterface
    }
    
    /// Sets up two-way binding between currentMode and modeManager
    private func setupModeBinding() {
        // This will be handled by the switchToMode method and TabView binding
    }
    
    /// Binding for currentMode that syncs with modeManager
    var currentModeBinding: Binding<InterfaceMode> {
        Binding(
            get: { self.currentMode },
            set: { newMode in
                self.currentMode = newMode
                self.modeManager.currentMode = newMode
            }
        )
    }
    
    /// Shows the mind map view
    func showMindMap() {
        showingMindMap = true
    }
    
    /// Shows the settings view
    func showSettings() {
        showingSettings = true
    }
    
    /// Hides the mind map view
    func hideMindMap() {
        showingMindMap = false
    }
    
    /// Hides the settings view
    func hideSettings() {
        showingSettings = false
    }
    
    /// Switches to a specific interface mode
    func switchToMode(_ mode: InterfaceMode) {
        withAnimation(.easeInOut) {
            currentMode = mode
            modeManager.currentMode = mode
        }
    }
    
    /// Processes relationship detection for Enhanced Interface
    func processRelationshipDetection(with screenshots: [Screenshot]) async {
        if isEnhancedInterfaceEnabled {
            await relationshipDetector.detectRelationships(in: screenshots)
        }
    }
    
    /// Gets the appropriate content view based on current mode
    @ViewBuilder
    func getContentView(
        screenshots: [Screenshot],
        modelContext: ModelContext,
        photoLibraryService: PhotoLibraryService,
        backgroundOCRProcessor: BackgroundOCRProcessor,
        backgroundSemanticProcessor: BackgroundSemanticProcessor,
        searchOrchestrator: GlassConversationalSearchOrchestrator,
        viewportManager: PredictiveViewportManager,
        qualityManager: AdaptiveQualityManager
    ) -> some View {
        if isEnhancedInterfaceEnabled {
            // Enhanced Interface with 4-level progressive disclosure
            VStack(spacing: 0) {
                // Mode selector
                AdaptiveContentHubModeSelector(modeCoordinator: self)
                    .padding(.top, 2)
                
                // Current mode content with fluid transitions
                TabView(selection: currentModeBinding) {
                    // Gallery mode
                    GalleryModeRenderer(
                        screenshots: screenshots,
                        modelContext: modelContext,
                        photoLibraryService: photoLibraryService,
                        backgroundOCRProcessor: backgroundOCRProcessor,
                        backgroundSemanticProcessor: backgroundSemanticProcessor,
                        searchOrchestrator: searchOrchestrator,
                        viewportManager: viewportManager,
                        qualityManager: qualityManager
                    )
                    .tag(InterfaceMode.gallery)

                    // Constellation mode
                    ConstellationModeView()
                        .tag(InterfaceMode.constellation)

                    // Exploration mode (placeholder)
                    explorationModeContent
                        .tag(InterfaceMode.exploration)

                    // Search mode (placeholder)
                    searchModeContent
                        .tag(InterfaceMode.search)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentMode)
            }
        } else {
            // Legacy Interface: Original screenshot grid
            GalleryModeRenderer(
                screenshots: screenshots,
                modelContext: modelContext,
                photoLibraryService: photoLibraryService,
                backgroundOCRProcessor: backgroundOCRProcessor,
                backgroundSemanticProcessor: backgroundSemanticProcessor,
                searchOrchestrator: searchOrchestrator,
                viewportManager: viewportManager,
                qualityManager: qualityManager
            )
        }
    }
    
    // MARK: - Private Content Views
    
    /// Exploration mode content (placeholder for future implementation)
    private var explorationModeContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 64))
                .foregroundColor(.orange.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Exploration Mode")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Discover relationships and connections between your content with interactive visualization.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Text("Coming in Sprint 8.3")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.orange.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(.orange.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
    
    /// Search mode content (enhanced conversational search)
    private var searchModeContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.green.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Search Mode")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Find specific content with powerful conversational search and AI assistance.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Text("Enhanced in Sprint 8.4")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.green.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(.green.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

// MARK: - ModeCoordinatorDelegate Protocol
protocol ModeCoordinatorDelegate {
    func getScreenshots() -> [Screenshot]
}