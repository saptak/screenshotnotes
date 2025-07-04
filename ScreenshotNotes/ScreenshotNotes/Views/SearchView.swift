import SwiftUI
import Foundation

struct SearchFilters {
    var dateRange: DateRange = .all
    var hasText: Bool? = nil // nil = all, true = with text, false = without text
    var sortOrder: SortOrder = .relevance
    
    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        
        var predicate: (Date) -> Bool {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .all:
                return { _ in true }
            case .today:
                return { date in calendar.isDate(date, inSameDayAs: now) }
            case .week:
                let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
                return { date in date >= weekAgo }
            case .month:
                let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                return { date in date >= monthAgo }
            case .year:
                let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                return { date in date >= yearAgo }
            }
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case relevance = "Relevance"
        case newest = "Newest First"
        case oldest = "Oldest First"
    }
}

struct SearchView: View {
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    @Binding var searchFilters: SearchFilters
    let onClear: () -> Void
    
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchFieldHeight: CGFloat = 44
    @State private var showingFilters = false
    
    private var hasActiveFilters: Bool {
        searchFilters.dateRange != .all || 
        searchFilters.hasText != nil || 
        searchFilters.sortOrder != .relevance
    }
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))
                    .scaleEffect(isSearchActive ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSearchActive)
                
                TextField("Search screenshots...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        isSearchFieldFocused = false
                    }
                    .onChange(of: searchText) { _, newValue in
                        withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
                            isSearchActive = !newValue.isEmpty
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            searchText = ""
                            isSearchActive = false
                            onClear()
                        }
                        isSearchFieldFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlayMaterial(cornerRadius: 12, stroke: .subtle)
            .scaleEffect(isSearchFieldFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearchFieldFocused)
            
            if isSearchActive {
                Button(action: {
                    showingFilters = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(hasActiveFilters ? .accentColor : .secondary)
                        .scaleEffect(hasActiveFilters ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasActiveFilters)
                }
                .transition(.scale.combined(with: .opacity))
                
                Button("Cancel") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        searchText = ""
                        isSearchActive = false
                        isSearchFieldFocused = false
                        onClear()
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background {
            Rectangle()
                .materialBackground(depth: .navigation)
                .ignoresSafeArea()
        }
        .onTapGesture {
            isSearchFieldFocused = true
        }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(filters: $searchFilters, isPresented: $showingFilters)
        }
    }
}

struct SearchResultsView: View {
    let screenshots: [Screenshot]
    let searchText: String
    let onScreenshotTap: (Screenshot) -> Void
    let onDelete: ((Screenshot) -> Void)?
    
    @State private var animateResults = false
    @State private var selectedScreenshot: Screenshot?
    
    // Hero Animation Support
    @Namespace private var searchHeroNamespace
    @StateObject private var heroService = HeroAnimationService.shared
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
        ], spacing: 16) {
            ForEach(Array(screenshots.enumerated()), id: \.element.id) { index, screenshot in
                SearchResultCard(
                    screenshot: screenshot,
                    searchText: searchText,
                    heroNamespace: searchHeroNamespace,
                    onTap: {
                        // Start hero animation for search-to-detail
                        heroService.startTransition(
                            .searchToDetail,
                            from: "search_result_\(screenshot.id)",
                            to: "search_detail_\(screenshot.id)"
                        )
                        selectedScreenshot = screenshot
                        onScreenshotTap(screenshot)
                    }
                )
                .scaleEffect(animateResults ? 1.0 : 0.8)
                .opacity(animateResults ? 1.0 : 0.0)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.8)
                    .delay(Double(index) * 0.05),
                    value: animateResults
                )
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation {
                animateResults = true
            }
        }
        .onChange(of: screenshots.count) { _, _ in
            animateResults = false
            withAnimation {
                animateResults = true
            }
        }
        .fullScreenCover(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(
                screenshot: screenshot,
                heroNamespace: searchHeroNamespace,
                allScreenshots: screenshots,
                onDelete: onDelete
            )
        }
    }
}

struct SearchResultCard: View {
    let screenshot: Screenshot
    let searchText: String
    let heroNamespace: Namespace.ID
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var image: UIImage?
    @StateObject private var heroService = HeroAnimationService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary.opacity(0.3))
                    .aspectRatio(3/4, contentMode: .fit)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .heroSource(
                            id: "search_result_\(screenshot.id)",
                            in: heroNamespace,
                            transitionType: .searchToDetail
                        )
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.secondary)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
                    HighlightedText(
                        text: String(extractedText.prefix(100)),
                        searchText: searchText
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }
                
                Text(screenshot.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .surfaceMaterial(cornerRadius: 16, stroke: nil)
        .shadow(
            color: .black.opacity(isPressed ? 0.15 : 0.08),
            radius: isPressed ? 2 : 6,
            x: 0,
            y: isPressed ? 1 : 3
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0) {
            // Handle press state
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = pressing
            }
        }
        .task {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard image == nil else { return }
        
        Task {
            if let uiImage = UIImage(data: screenshot.imageData) {
                await MainActor.run {
                    self.image = uiImage
                }
            }
        }
    }
}

struct HighlightedText: View {
    let text: String
    let searchText: String
    
    private let searchService = SearchService()
    
    var body: some View {
        let highlights = searchService.highlightText(in: text, matching: searchText)
        
        Text(createAttributedString(from: highlights))
    }
    
    private func createAttributedString(from highlights: [(range: NSRange, text: String)]) -> AttributedString {
        var attributedString = AttributedString()
        
        for (_, highlightText) in highlights {
            var segment = AttributedString(highlightText)
            
            if searchText.lowercased().components(separatedBy: .whitespacesAndNewlines)
                .contains(where: { term in
                    !term.isEmpty && highlightText.lowercased().contains(term)
                }) {
                segment.backgroundColor = .yellow.opacity(0.3)
                segment.font = .caption.weight(.semibold)
            }
            
            attributedString.append(segment)
        }
        
        return attributedString
    }
}

#Preview {
    VStack {
        SearchView(
            searchText: .constant(""),
            isSearchActive: .constant(false),
            searchFilters: .constant(SearchFilters()),
            onClear: {}
        )
        
        Spacer()
    }
    .background(.regularMaterial)
}