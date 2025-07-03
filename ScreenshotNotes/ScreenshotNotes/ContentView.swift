import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    @StateObject private var viewModel = ScreenshotListViewModel()
    @EnvironmentObject private var photoLibraryService: PhotoLibraryService
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingImportSheet = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if screenshots.isEmpty && !viewModel.isImporting {
                    EmptyStateView(onImportTapped: {
                        showingImportSheet = true
                    })
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
            .navigationTitle("Screenshot Notes")
            .navigationBarTitleDisplayMode(.large)
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
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(screenshots, id: \.id) { screenshot in
                    ScreenshotThumbnailView(
                        screenshot: screenshot,
                        onTap: {
                            selectedScreenshot = screenshot
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        },
                        onDelete: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.deleteScreenshot(screenshot)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: 20)),
                        removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: -20))
                    ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .fullScreenCover(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(screenshot: screenshot)
        }
    }
}

struct ScreenshotThumbnailView: View {
    let screenshot: Screenshot
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    @State private var showingDeleteConfirmation = false
    
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
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
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
        .onLongPressGesture(minimumDuration: 0.5) {
            showingDeleteConfirmation = true
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
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
                
                Text("Importing...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(Int(progress * 100))% complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
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

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
