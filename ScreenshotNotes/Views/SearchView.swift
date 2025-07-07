import SwiftUI
import Foundation
import NaturalLanguage

// MARK: - Sub-Sprint 5.1.1 Integration: Natural Language Query Parser

/// Simple Query Intent Detection for SearchView
/// This integrates Sub-Sprint 5.1.1 functionality into the existing search experience
enum SimpleQueryIntent {
    case find, search, show, filter, unknown
    
    var icon: String {
        switch self {
        case .find: return "location.magnifyingglass"
        case .search: return "magnifyingglass"
        case .show: return "eye"
        case .filter: return "line.3.horizontal.decrease.circle"
        case .unknown: return "magnifyingglass"
        }
    }
    
    var color: Color {
        switch self {
        case .find: return .blue
        case .search: return .primary
        case .show: return .green
        case .filter: return .orange
        case .unknown: return .secondary
        }
    }
}

/// Simple query parser for SearchView integration
class SimpleQueryParser {
    static func parseIntent(from query: String) -> SimpleQueryIntent {
        let lowercased = query.lowercased()
        
        if lowercased.hasPrefix("find") || lowercased.contains("find") {
            return .find
        } else if lowercased.hasPrefix("show") || lowercased.contains("show") {
            return .show
        } else if lowercased.hasPrefix("filter") || lowercased.contains("filter") {
            return .filter
        } else if !query.isEmpty {
            return .search
        } else {
            return .unknown
        }
    }
}

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
    @State private var detectedIntent: SimpleQueryIntent = .unknown
    
    // Glass Design System
    @Environment(\.glassResponsiveLayout) private var layout
    @StateObject private var glassSystem = GlassDesignSystem.shared
    
    private var hasActiveFilters: Bool {
        searchFilters.dateRange != .all || 
        searchFilters.hasText != nil || 
        searchFilters.sortOrder != .relevance
    }
    
    var body: some View {
        GeometryReader { geometry in
            let responsiveLayout = GlassDesignSystem.ResponsiveLayout(
                horizontalSizeClass: nil,
                verticalSizeClass: nil,
                screenWidth: geometry.size.width,
                screenHeight: geometry.size.height
            )
            
            HStack(spacing: responsiveLayout.spacing.medium) {
                HStack(spacing: responsiveLayout.spacing.small) {
                    // 🎯 Sub-Sprint 5.1.1: Dynamic intent-based search icon
                    Image(systemName: detectedIntent.icon)
                        .foregroundStyle(detectedIntent.color)
                        .font(.system(size: 16, weight: .medium))
                        .scaleEffect(isSearchActive ? 1.1 : 1.0)
                        .glassAnimation(.responsive)
                        .animation(glassSystem.adaptedGlassSpring(.responsive), value: detectedIntent)
                    
                    TextField("Search screenshots...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(responsiveLayout.typography.body)
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            isSearchFieldFocused = false
                        }
                        .onChange(of: searchText) { _, newValue in
                            withAnimation(glassSystem.adaptedGlassSpring(.gentle)) {
                                isSearchActive = !newValue.isEmpty
                                // 🎯 Sub-Sprint 5.1.1: Detect intent as user types
                                detectedIntent = SimpleQueryParser.parseIntent(from: newValue)
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            withAnimation(glassSystem.adaptedGlassSpring(.responsive)) {
                                searchText = ""
                                isSearchActive = false
                                detectedIntent = .unknown
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
                .padding(.horizontal, responsiveLayout.spacing.horizontalPadding)
                .padding(.vertical, responsiveLayout.spacing.verticalPadding)
                .glassBackground(
                    material: responsiveLayout.materials.primary,
                    cornerRadius: responsiveLayout.materials.cornerRadius,
                    shadow: true
                )
                .scaleEffect(isSearchFieldFocused ? 1.02 : 1.0)
                .animation(glassSystem.adaptedGlassSpring(.conversational), value: isSearchFieldFocused)
            
                if isSearchActive {
                    Button(action: {
                        showingFilters = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(hasActiveFilters ? .accentColor : .secondary)
                            .scaleEffect(hasActiveFilters ? 1.1 : 1.0)
                            .animation(glassSystem.adaptedGlassSpring(.responsive), value: hasActiveFilters)
                    }
                    .transition(.scale.combined(with: .opacity))
                    
                    Button("Cancel") {
                        withAnimation(glassSystem.adaptedGlassSpring(.responsive)) {
                            searchText = ""
                            isSearchActive = false
                            isSearchFieldFocused = false
                            onClear()
                        }
                    }
                    .font(responsiveLayout.typography.body)
                    .foregroundStyle(.primary)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, responsiveLayout.spacing.horizontalPadding)
            .padding(.top, responsiveLayout.spacing.small)
            .frame(minHeight: GlassDesignSystem.GlassLayout.minimumTouchTarget)
            .background {
                Rectangle()
                    .glassBackground(
                        material: .chrome,
                        cornerRadius: 0,
                        shadow: false
                    )
                    .ignoresSafeArea()
            }
        }
        .onTapGesture {
            isSearchFieldFocused = true
        }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(filters: $searchFilters, isPresented: $showingFilters)
        }
        .onChange(of: searchText) { _, newValue in
            let intent = SimpleQueryParser.parseIntent(from: newValue)
            // Handle the detected intent (e.g., update UI, modify search behavior)
            print("Detected intent: \(intent)")
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
    @Environment(\.glassResponsiveLayout) private var layout
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacing.small) {
            ZStack {
                RoundedRectangle(cornerRadius: layout.materials.cornerRadius, style: .continuous)
                    .fill(.quaternary.opacity(0.3))
                    .aspectRatio(3/4, contentMode: .fit)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: layout.materials.cornerRadius, style: .continuous))
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
                RoundedRectangle(cornerRadius: layout.materials.cornerRadius, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5)
            }
            
            VStack(alignment: .leading, spacing: layout.spacing.xs) {
                if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
                    HighlightedText(
                        text: String(extractedText.prefix(100)),
                        searchText: searchText
                    )
                    .font(layout.typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }
                
                Text(screenshot.timestamp, style: .date)
                    .font(layout.typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .responsiveGlassBackground(
            layout: layout,
            materialType: .primary,
            shadow: true
        )
        .shadow(
            color: .black.opacity(isPressed ? 0.15 : 0.08),
            radius: isPressed ? 2 : 6,
            x: 0,
            y: isPressed ? 1 : 3
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(GlassDesignSystem.glassSpring(.responsive), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0) {
            // Handle press state
        } onPressingChanged: { pressing in
            withAnimation(GlassDesignSystem.glassSpring(.microphone)) {
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
    .responsiveLayout()
    .background(Color(.systemBackground))
}