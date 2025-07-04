import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    @StateObject private var viewModel = ScreenshotListViewModel()
    @StateObject private var searchService = SearchService()
    @EnvironmentObject private var photoLibraryService: PhotoLibraryService
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingImportSheet = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var searchFilters = SearchFilters()
    
    private var filteredScreenshots: [Screenshot] {
        (searchService as AdvancedSearchServiceProtocol).searchScreenshots(
            query: searchText,
            in: screenshots,
            filters: searchFilters
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !screenshots.isEmpty {
                    SearchView(
                        searchText: $searchText,
                        isSearchActive: $isSearchActive,
                        searchFilters: $searchFilters,
                        onClear: {
                            searchText = ""
                            isSearchActive = false
                            searchFilters = SearchFilters()
                        }
                    )
                }
                
                ZStack {
                    if screenshots.isEmpty && !viewModel.isImporting {
                        EmptyStateView(onImportTapped: {
                            showingImportSheet = true
                        })
                    } else if isSearchActive {
                        SearchResultsView(
                            screenshots: filteredScreenshots,
                            searchText: searchText,
                            onScreenshotTap: { screenshot in
                                // Present screenshot detail view
                                // This will be handled by the SearchResultCard navigation
                            }
                        )
                    } else {
                        ScreenshotListView(
                            screenshots: screenshots,
                            viewModel: viewModel
                        )
                    }
                    
                    if viewModel.isImporting {
                        ImportProgressOverlay(progress: viewModel.importProgress)
                    }
                }
            }
            .navigationTitle(isSearchActive ? "Search Results" : "Screenshot Notes")
            .navigationBarTitleDisplayMode(isSearchActive ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettings = true
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }) {
                        Image(systemName: "gearshape")
                            .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingImportSheet = true
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .disabled(viewModel.isImporting)
                    .opacity(isSearchActive ? 0.5 : 1.0)
                }
            }
            .photosPicker(
                isPresented: $showingImportSheet,
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images
            )
            .onChange(of: selectedItems) { _, newItems in
                if !newItems.isEmpty {
                    Task {
                        await viewModel.importImages(from: newItems)
                        selectedItems = []
                    }
                }
            }
            .alert("Import Error", isPresented: $viewModel.showingError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
            .onAppear {
                viewModel.setModelContext(modelContext)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(photoLibraryService: photoLibraryService)
            }
        }
    }
}

struct EmptyStateView: View {
    let onImportTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(.secondary)
                .symbolEffect(.pulse.wholeSymbol, options: .repeating)
            
            VStack(spacing: 8) {
                Text("No Screenshots Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Import your first screenshot to get started organizing your visual notes")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                onImportTapped()
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                    Text("Import Photos")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.tint)
                )
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

struct ScreenshotListView: View {
    let screenshots: [Screenshot]
    let viewModel: ScreenshotListViewModel
    @State private var selectedScreenshot: Screenshot?
    @State private var isRefreshing = false
    
    // Navigation support
    @Namespace private var heroNamespace
    
    // Contextual menu support
    @StateObject private var menuService = ContextualMenuService.shared
    @StateObject private var hapticService = HapticFeedbackService.shared
    @State private var currentContextScreenshot: Screenshot?
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(screenshots, id: \.id) { screenshot in
                        ScreenshotThumbnailView(
                            screenshot: screenshot,
                            heroNamespace: heroNamespace,
                            onTap: {
                                if menuService.batchSelection.isActive {
                                    menuService.toggleSelection(for: screenshot)
                                } else {
                                    selectedScreenshot = screenshot
                                    hapticService.triggerHaptic(.menuSelection)
                                }
                            },
                            onLongPress: { position in
                                if !menuService.batchSelection.isActive {
                                    showContextualMenu(for: screenshot, at: position)
                                }
                            },
                            onDelete: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.deleteScreenshot(screenshot)
                                }
                            }
                        )
                        .overlay(alignment: .topTrailing) {
                            if menuService.batchSelection.isActive {
                                SelectionCheckbox(
                                    isSelected: menuService.batchSelection.selectedItems.contains(screenshot.id)
                                )
                                .padding(8)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: 20)),
                            removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: -20))
                        ))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, menuService.batchSelection.isActive ? 80 : 0)
            }
            .refreshable {
                await refreshAllScreenshots()
            }
            
            // Batch selection toolbar
            BatchSelectionToolbar(screenshots: screenshots)
        }
        .fullScreenCover(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(
                screenshot: screenshot,
                heroNamespace: heroNamespace,
                allScreenshots: screenshots
            )
        }
        .overlay {
            ContextualMenuOverlay(contextScreenshot: currentContextScreenshot)
        }
        .toolbar {
            if menuService.batchSelection.isActive {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select All") {
                        menuService.selectAll(screenshots)
                    }
                    .disabled(menuService.batchSelection.count == screenshots.count)
                }
            }
        }
    }
    
    private func refreshAllScreenshots() async {
        await viewModel.importAllExistingScreenshots()
    }
    
    private func showContextualMenu(for screenshot: Screenshot, at position: CGPoint) {
        currentContextScreenshot = screenshot
        hapticService.triggerHaptic(.longPressTriggered)
        
        // Create menu actions based on screenshot context
        let menuActions: [ContextualMenuService.MenuAction] = [
            .share,
            .copy,
            .favorite,
            .tag,
            .delete
        ]
        
        let configuration = ContextualMenuService.MenuConfiguration(
            actions: menuActions,
            enableHaptics: true,
            animationDuration: 0.3,
            menuAppearanceDelay: 0.1,
            dismissAfterAction: true
        )
        
        menuService.showMenu(configuration: configuration, at: position, for: screenshot)
    }
}

struct ScreenshotThumbnailView: View {
    let screenshot: Screenshot
    let heroNamespace: Namespace.ID
    let onTap: () -> Void
    let onLongPress: (CGPoint) -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    @State private var showingDeleteConfirmation = false
    @State private var longPressLocation: CGPoint = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let uiImage = UIImage(data: screenshot.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 140)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                Text("Unable to load")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .surfaceMaterial(cornerRadius: 14, stroke: StrokeConfiguration(color: .primary.opacity(0.08), lineWidth: 0.5))
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.85 : 1.0)
            
            Text(screenshot.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress(longPressLocation)
                }
                .simultaneously(with: DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        longPressLocation = value.location
                    }
                )
        )
        .onPressGesture(
            onPressChanged: { pressed in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressed
                }
            }
        )
        .confirmationDialog(
            "Delete Screenshot",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

struct ImportProgressOverlay: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    .scaleEffect(1.5)
                
                Text(progress > 0 ? "Importing..." : "Scanning Photo Library...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if progress > 0 {
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Finding screenshots to import")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .modalMaterial(cornerRadius: 16)
        }
        .transition(.opacity)
    }
}

// Custom gesture for press feedback
struct PressGesture: ViewModifier {
    let onPressChanged: (Bool) -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onPressChanged(true)
                    }
                    .onEnded { _ in
                        onPressChanged(false)
                    }
            )
    }
}

extension View {
    func onPressGesture(onPressChanged: @escaping (Bool) -> Void) -> some View {
        modifier(PressGesture(onPressChanged: onPressChanged))
    }
}

// MARK: - Selection Checkbox Component

struct SelectionCheckbox: View {
    let isSelected: Bool
    @State private var animationScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.background)
                .frame(width: 24, height: 24)
                .shadow(radius: 2, y: 1)
            
            if isSelected {
                Circle()
                    .fill(.tint)
                    .frame(width: 20, height: 20)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(animationScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            animationScale = 1.0
                        }
                    }
                    .onDisappear {
                        animationScale = 0.8
                    }
            } else {
                Circle()
                    .stroke(.secondary, lineWidth: 2)
                    .frame(width: 20, height: 20)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
