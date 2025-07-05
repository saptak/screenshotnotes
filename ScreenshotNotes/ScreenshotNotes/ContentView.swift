import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    @StateObject private var photoLibraryService = PhotoLibraryService()
    @StateObject private var queryParser = QueryParserService()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingImportSheet = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var lastParsedQuery: SearchQuery?
    @State private var showingQueryAnalysis = false
    
    private var filteredScreenshots: [Screenshot] {
        if searchText.isEmpty {
            return screenshots
        } else {
            // Use natural language understanding for enhanced search
            if let parsedQuery = lastParsedQuery, parsedQuery.isActionable {
                return screenshots.filter { screenshot in
                    // Apply temporal filtering if query has temporal context
                    if parsedQuery.hasTemporalContext {
                        if !matchesTemporalContext(screenshot: screenshot, query: parsedQuery) {
                            return false
                        }
                    }
                    
                    // Apply text-based filtering
                    let enhancedTerms = parsedQuery.searchTerms.filter { term in
                        !isTemporalTerm(term) // Exclude temporal terms from text search
                    }
                    
                    print("🔍 Non-temporal terms to search: \(enhancedTerms)")
                    
                    if enhancedTerms.isEmpty {
                        print("🔍 Only temporal terms, returning true for temporal match")
                        return true // If only temporal terms, return true (temporal filter already applied)
                    }
                    
                    // For terms like "screenshots" that are generic references to the content type,
                    // don't require them to match - the temporal filter is sufficient
                    let meaningfulTerms = enhancedTerms.filter { term in
                        !["screenshots", "screenshot", "images", "image", "photos", "photo", "pictures", "picture"].contains(term.lowercased())
                    }
                    
                    print("🔍 Meaningful terms after filtering generic words: \(meaningfulTerms)")
                    
                    if meaningfulTerms.isEmpty {
                        print("🔍 Only generic content type terms, temporal filter is sufficient")
                        return true // If only generic content type terms, temporal filter is sufficient
                    }
                    
                    let textMatch = meaningfulTerms.allSatisfy { term in
                        let filenameMatch = screenshot.filename.localizedCaseInsensitiveContains(term)
                        let textMatch = screenshot.extractedText?.localizedCaseInsensitiveContains(term) ?? false
                        print("🔍 Checking meaningful term '\(term)' in filename '\(screenshot.filename)': \(filenameMatch), extractedText: \(textMatch)")
                        return filenameMatch || textMatch
                    }
                    
                    return textMatch
                }
            } else {
                // Fallback to traditional search
                return screenshots.filter { screenshot in
                    screenshot.filename.localizedCaseInsensitiveContains(searchText) ||
                    (screenshot.extractedText?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
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
                
                // AI Query Analysis Indicator
                if showingQueryAnalysis, let query = lastParsedQuery {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            AIQueryIndicator(query: query)
                                .padding(.trailing, 16)
                                .padding(.bottom, 100)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .navigationTitle("Screenshot Vault")
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
                
                // Add natural language processing for enhanced search
                if !newValue.isEmpty && newValue.count > 2 {
                    Task {
                        let parsedQuery = await queryParser.parseQuery(newValue)
                        await MainActor.run {
                            lastParsedQuery = parsedQuery
                            showingQueryAnalysis = parsedQuery.isActionable
                            
                            // Debug output
                            print("🔍 Debug Query: '\(newValue)'")
                            print("   Terms: \(parsedQuery.searchTerms)")
                            print("   Temporal: \(parsedQuery.hasTemporalContext)")
                            print("   Intent: \(parsedQuery.intent)")
                            print("   Confidence: \(parsedQuery.confidence) (\(parsedQuery.confidence.rawValue))")
                            print("   Actionable: \(parsedQuery.isActionable)")
                        }
                    }
                } else {
                    lastParsedQuery = nil
                    showingQueryAnalysis = false
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
    
    // MARK: - Temporal Query Helpers
    
    private func matchesTemporalContext(screenshot: Screenshot, query: SearchQuery) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let screenshotDate = screenshot.timestamp
        
        print("📅 Checking temporal match for screenshot from \(screenshotDate) vs now \(now)")
        
        for term in query.searchTerms {
            switch term.lowercased() {
            case "today":
                let isToday = calendar.isDate(screenshotDate, inSameDayAs: now)
                print("   Term 'today': \(isToday)")
                if isToday {
                    return true
                }
            case "yesterday":
                if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                   calendar.isDate(screenshotDate, inSameDayAs: yesterday) {
                    return true
                }
            case "week", "this week":
                if calendar.isDate(screenshotDate, equalTo: now, toGranularity: .weekOfYear) {
                    return true
                }
            case "last week":
                if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
                   calendar.isDate(screenshotDate, equalTo: lastWeek, toGranularity: .weekOfYear) {
                    return true
                }
            case "month", "this month":
                if calendar.isDate(screenshotDate, equalTo: now, toGranularity: .month) {
                    return true
                }
            case "last month":
                if let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
                   calendar.isDate(screenshotDate, equalTo: lastMonth, toGranularity: .month) {
                    return true
                }
            case "recent":
                // Define recent as within the last 7 days
                if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                   screenshotDate >= weekAgo {
                    return true
                }
            default:
                continue
            }
        }
        
        return false
    }
    
    private func isTemporalTerm(_ term: String) -> Bool {
        let temporalTerms: Set<String> = [
            "today", "yesterday", "tomorrow", "week", "this week", "last week",
            "month", "this month", "last month", "year", "this year", "last year",
            "recent", "lately"
        ]
        return temporalTerms.contains(term.lowercased())
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

/// AI Query Processing Indicator - Shows when natural language understanding is active
struct AIQueryIndicator: View {
    let query: SearchQuery
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.blue)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI: \(query.intent.rawValue)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if query.hasVisualAttributes {
                    Text("Visual search")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if query.confidence.rawValue >= 0.8 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
