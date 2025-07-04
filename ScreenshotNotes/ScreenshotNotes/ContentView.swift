import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    @StateObject private var photoLibraryService = PhotoLibraryService()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingImportSheet = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    
    private var filteredScreenshots: [Screenshot] {
        if searchText.isEmpty {
            return screenshots
        } else {
            return screenshots.filter { screenshot in
                screenshot.filename.localizedCaseInsensitiveContains(searchText) ||
                (screenshot.extractedText?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if screenshots.isEmpty && !isImporting {
                    EmptyStateView(onImportTapped: {
                        showingImportSheet = true
                    })
                } else if isSearchActive {
                    ScreenshotGridView(screenshots: filteredScreenshots)
                } else {
                    ScreenshotGridView(screenshots: screenshots)
                }
                
                if isImporting {
                    ImportProgressOverlay(progress: importProgress)
                }
            }
            .navigationTitle("Screenshot Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingImportSheet = true
                    }) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .disabled(isImporting)
                    .opacity(isImporting ? 0.5 : 1.0)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search screenshots...")
            .onChange(of: searchText) { _, newValue in
                withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
                    isSearchActive = !newValue.isEmpty
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
                        await importImages(from: newItems)
                        selectedItems = []
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(photoLibraryService: photoLibraryService)
            }
            .onAppear {
                photoLibraryService.setModelContext(modelContext)
            }
        }
    }
    
    private func importImages(from items: [PhotosPickerItem]) async {
        isImporting = true
        importProgress = 0.0
        
        for (index, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let screenshot = Screenshot(
                    imageData: data,
                    filename: item.supportedContentTypes.first?.description ?? "Screenshot"
                )
                modelContext.insert(screenshot)
            }
            
            await MainActor.run {
                importProgress = Double(index + 1) / Double(items.count)
            }
        }
        
        try? modelContext.save()
        isImporting = false
    }
}

struct EmptyStateView: View {
    let onImportTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(.secondary)
            
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

struct ScreenshotGridView: View {
    let screenshots: [Screenshot]
    @State private var selectedScreenshot: Screenshot?
    @Namespace private var heroNamespace
    
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
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .fullScreenCover(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(
                screenshot: screenshot,
                heroNamespace: heroNamespace,
                allScreenshots: screenshots,
                onDelete: nil
            )
        }
    }
}

struct ScreenshotThumbnailView: View {
    let screenshot: Screenshot
    let onTap: () -> Void
    
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
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
            
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
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
        }
        .transition(.opacity)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
