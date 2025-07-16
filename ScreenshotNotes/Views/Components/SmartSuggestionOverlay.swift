import SwiftUI
import SwiftData

/// Smart suggestion overlay that provides contextual recommendations with beautiful Glass design
/// Integrates seamlessly with the main app UI and provides non-intrusive proactive assistance
struct SmartSuggestionOverlay: View {
    @StateObject private var suggestionService = SmartSuggestionsService.shared
    @StateObject private var contentRecommendations = ContentRecommendationEngine.shared
    @Environment(\.glassResponsiveLayout) private var layout
    @Environment(\.modelContext) private var modelContext
    
    @State private var currentScreenshots: [Screenshot] = []
    @State private var showingSuggestionDetail: SmartSuggestionsService.SuggestionCard?
    @State private var dragOffset: CGFloat = 0
    @State private var lastRefreshTime = Date()
    
    private let hapticService = HapticFeedbackService.shared
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    var body: some View {
        ZStack {
            if suggestionService.isShowingSuggestionOverlay {
                // Backdrop
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissOverlay()
                    }
                
                // Suggestion cards container
                suggestionCardsView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: suggestionService.isShowingSuggestionOverlay)
        .task {
            await loadInitialScreenshots()
            await refreshSuggestionsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScreenshotsUpdated"))) { _ in
            Task {
                await loadInitialScreenshots()
                await refreshSuggestionsIfNeeded()
            }
        }
        .sheet(item: $showingSuggestionDetail) { suggestion in
            SuggestionDetailView(suggestion: suggestion)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Suggestion Cards View
    
    private var suggestionCardsView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: layout.spacing.medium) {
                // Handle bar
                handleBar
                
                // Header
                suggestionHeader
                
                // Cards scroll view
                suggestionScrollView
                
                // Action buttons
                suggestionActions
            }
            .padding(layout.spacing.medium)
            .background(suggestionContainerBackground)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: layout.materials.cornerRadius,
                    style: .continuous
                )
            )
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow downward drag
                        dragOffset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            // Dismiss if dragged down enough
                            dismissOverlay()
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
    
    private var handleBar: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(.secondary.opacity(0.5))
            .frame(width: 40, height: 5)
            .padding(.top, layout.spacing.small)
    }
    
    private var suggestionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Suggestions")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                if suggestionService.isGeneratingSuggestions {
                    Text("Analyzing your content...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(suggestionService.visibleSuggestionCards.count) recommendations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Close button
            Button(action: dismissOverlay) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .background(Color.clear)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var suggestionScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: layout.spacing.medium) {
                if suggestionService.isGeneratingSuggestions {
                    // Loading states
                    ForEach(0..<3, id: \.self) { _ in
                        loadingCardPlaceholder
                    }
                } else if suggestionService.visibleSuggestionCards.isEmpty {
                    // Empty state
                    emptyState
                } else {
                    // Actual suggestion cards
                    ForEach(suggestionService.visibleSuggestionCards, id: \.id) { suggestion in
                        SmartSuggestionCard(
                            suggestion: suggestion,
                            onAccept: {
                                Task {
                                    await handleSuggestionAccepted(suggestion)
                                }
                            },
                            onDismiss: {
                                Task {
                                    await handleSuggestionDismissed(suggestion)
                                }
                            },
                            onMoreInfo: {
                                showingSuggestionDetail = suggestion
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 2) // Prevent clipping of shadows
        }
        .frame(maxHeight: 400)
    }
    
    private var loadingCardPlaceholder: some View {
        RoundedRectangle(cornerRadius: layout.materials.cornerRadius)
            .fill(.secondary.opacity(0.1))
            .frame(height: 120)
            .overlay(
                HStack(spacing: layout.spacing.medium) {
                    // Icon placeholder
                    Circle()
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Title placeholder
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.2))
                            .frame(height: 16)
                        
                        // Description placeholder
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.15))
                            .frame(height: 12)
                    }
                    
                    Spacer()
                }
                .padding(layout.spacing.medium)
            )
            .shimmer()
    }
    
    private var emptyState: some View {
        VStack(spacing: layout.spacing.medium) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Suggestions Available")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Keep using the app and we'll provide intelligent recommendations based on your content and usage patterns.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button("Refresh Suggestions") {
                Task {
                    await refreshSuggestions()
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(layout.spacing.large)
    }
    
    private var suggestionActions: some View {
        HStack(spacing: layout.spacing.medium) {
            Button("Refresh") {
                Task {
                    await refreshSuggestions()
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())
            
            Spacer()
            
            Button("Settings") {
                // Open suggestion settings
                hapticService.triggerHaptic(.menuSelection)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }
    
    private var suggestionContainerBackground: some View {
        RoundedRectangle(
            cornerRadius: layout.materials.cornerRadius,
            style: .continuous
        )
        .fill(ResponsiveMaterialType.primary.material(for: layout).material)
    }
    
    // MARK: - Actions
    
    private func dismissOverlay() {
        hapticService.triggerHaptic(.menuDismiss)
        suggestionService.hideSuggestionOverlay()
    }
    
    private func handleSuggestionAccepted(_ suggestion: SmartSuggestionsService.SuggestionCard) async {
        await suggestionService.handleCardInteraction(suggestion, action: .accepted)
        
        // Execute suggestion action based on type
        switch suggestion.type {
        case .recentlyUseful:
            // Navigate to recently useful collection
            break
        case .relatedContent:
            // Show related content view
            break
        case .organizationPrompt:
            // Start organization workflow
            break
        case .cleanupRecommendation, .duplicateCleanup:
            // Start cleanup workflow
            break
        case .contentDiscovery:
            // Open content discovery view
            break
        case .workflowSuggestion:
            // Execute workflow suggestion
            break
        case .qualityImprovement:
            // Start quality improvement workflow
            break
        }
    }
    
    private func handleSuggestionDismissed(_ suggestion: SmartSuggestionsService.SuggestionCard) async {
        await suggestionService.handleCardInteraction(suggestion, action: .dismissed)
    }
    
    private func loadInitialScreenshots() async {
        do {
            let descriptor = FetchDescriptor<Screenshot>(
                sortBy: [SortDescriptor(\Screenshot.timestamp, order: .reverse)]
            )
            currentScreenshots = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load screenshots: \\(error)")
        }
    }
    
    private func refreshSuggestionsIfNeeded() async {
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
        
        if timeSinceLastRefresh > refreshInterval || suggestionService.visibleSuggestionCards.isEmpty {
            await refreshSuggestions()
        }
    }
    
    private func refreshSuggestions() async {
        guard !currentScreenshots.isEmpty else { return }
        
        hapticService.triggerHaptic(.processingStart)
        
        let context = SmartSuggestionsService.SuggestionContext(
            currentScreenshots: currentScreenshots,
            recentActivity: [],
            timeOfDay: getCurrentTimeOfDay(),
            userBehaviorProfile: nil
        )
        
        let suggestions = await suggestionService.generateSuggestionCards(
            for: context,
            in: modelContext
        )
        
        if !suggestions.isEmpty {
            suggestionService.showSuggestionOverlay(with: suggestions)
        }
        
        lastRefreshTime = Date()
        
        hapticService.triggerHaptic(.processingComplete)
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
}

// MARK: - Supporting Views

/// Detailed view for a suggestion with additional information and actions
struct SuggestionDetailView: View {
    let suggestion: SmartSuggestionsService.SuggestionCard
    @Environment(\.dismiss) private var dismiss
    @Environment(\.glassResponsiveLayout) private var layout
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.spacing.large) {
                    // Header with icon and title
                    suggestionDetailHeader
                    
                    // Description
                    suggestionDescription
                    
                    // Screenshots if available
                    if !suggestion.screenshots.isEmpty {
                        screenshotsSection
                    }
                    
                    // Metadata
                    metadataSection
                    
                    Spacer(minLength: 40)
                }
                .padding(layout.spacing.medium)
            }
            .navigationTitle("Suggestion Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var suggestionDetailHeader: some View {
        HStack(spacing: layout.spacing.medium) {
            Image(systemName: suggestion.iconName)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.blue.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                if !suggestion.subtitle.isEmpty {
                    Text(suggestion.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var suggestionDescription: some View {
        VStack(alignment: .leading, spacing: layout.spacing.small) {
            Text("Description")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(suggestion.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    
    private var screenshotsSection: some View {
        VStack(alignment: .leading, spacing: layout.spacing.small) {
            Text("Related Screenshots (\(suggestion.screenshots.count))")
                .font(.headline)
                .foregroundStyle(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: layout.spacing.small) {
                    ForEach(suggestion.screenshots, id: \.id) { screenshot in
                        screenshotThumbnail(screenshot)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    
    private func screenshotThumbnail(_ screenshot: Screenshot) -> some View {
        RoundedRectangle(cornerRadius: layout.materials.cornerRadius)
            .fill(.secondary.opacity(0.1))
            .frame(width: 80, height: 100)
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text(screenshot.filename.isEmpty ? "Screenshot" : String(screenshot.filename.prefix(10)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(8)
            )
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: layout.spacing.medium) {
            Text("Details")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: layout.spacing.small) {
                metadataRow(title: "Type", value: suggestion.type.displayName)
                metadataRow(title: "Priority", value: suggestion.priority.description)
                metadataRow(title: "Confidence", value: "\(Int(suggestion.confidence * 100))%")
                metadataRow(title: "Created", value: DateFormatter.relativeDateFormatter.string(from: suggestion.createdAt))
            }
        }
    }
    
    private func metadataRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Button Styles

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.secondary.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let relativeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}