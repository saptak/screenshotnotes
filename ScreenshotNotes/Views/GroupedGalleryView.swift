import SwiftUI
import SwiftData

/// Beautiful, fluid gallery view showing screenshots organized in intelligent groups
struct GroupedGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [ScreenshotGroup]
    @Query private var ungroupedScreenshots: [Screenshot]
    
    @StateObject private var groupingService = SmartGroupingService.shared
    @StateObject private var hapticService = HapticFeedbackService.shared
    
    // View state
    @State private var selectedGroup: ScreenshotGroup?
    @State private var showingGroupDetails = false
    @State private var expandedGroups: Set<UUID> = []
    @State private var showingRegroupingAlert = false
    
    // Glass design properties
    private let cardCornerRadius: CGFloat = 16
    private let groupSpacing: CGFloat = 20
    private let thumbnailSize: CGFloat = 60
    private let maxThumbnailsInPreview = 4
    
    init() {
        // Configure queries for optimal performance
        // Note: Sorting by groupType enum causes SwiftData issues, so we'll sort in the computed property instead
        let groupsQuery = FetchDescriptor<ScreenshotGroup>(
            sortBy: [
                SortDescriptor(\ScreenshotGroup.lastModified, order: .reverse)
            ]
        )
        _groups = Query(groupsQuery)
        
        let ungroupedQuery = FetchDescriptor<Screenshot>(
            predicate: #Predicate { $0.groups.isEmpty },
            sortBy: [SortDescriptor(\Screenshot.timestamp, order: .reverse)]
        )
        _ungroupedScreenshots = Query(ungroupedQuery)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: groupSpacing) {
                // Header with grouping controls
                headerView
                
                // Groups section
                if !groups.isEmpty {
                    groupsSection
                }
                
                // Ungrouped screenshots section
                if !ungroupedScreenshots.isEmpty {
                    ungroupedSection
                }
                
                // Empty state
                if groups.isEmpty && ungroupedScreenshots.isEmpty {
                    emptyStateView
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100) // Space for tab bar
        }
        .background(Color.black.opacity(0.02))
        .refreshable {
            await triggerRegrouping()
        }
        .sheet(isPresented: $showingGroupDetails) {
            if let group = selectedGroup {
                GroupDetailView(group: group)
            }
        }
        .alert("Regroup Screenshots", isPresented: $showingRegroupingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Regroup") {
                Task { @MainActor in
                    await triggerRegrouping()
                }
            }
        } message: {
            Text("This will analyze all screenshots and create new groups. Existing groups will be updated.")
        }
        .onAppear {
            checkForInitialGrouping()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Groups")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let statistics = groupingService.groupingStatistics {
                    Text("\(statistics.totalGroups) groups • \(statistics.ungroupedScreenshots) ungrouped")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Grouping controls
            VStack(spacing: 8) {
                Button(action: {
                    showingRegroupingAlert = true
                }) {
                    Image(systemName: "rectangle.3.group")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(groupingService.isProcessing)
                
                if groupingService.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Groups Section
    
    private var groupsSection: some View {
        LazyVStack(spacing: 16) {
            ForEach(groupedByType, id: \.key) { groupType, typeGroups in
                GroupTypeSection(
                    groupType: groupType,
                    groups: typeGroups,
                    expandedGroups: $expandedGroups,
                    onGroupTap: { group in
                        selectedGroup = group
                        showingGroupDetails = true
                        hapticService.triggerHaptic(.light)
                    },
                    onGroupLongPress: { group in
                        hapticService.triggerHaptic(.medium)
                        // Handle long press actions
                    }
                )
            }
        }
    }
    
    // MARK: - Ungrouped Section
    
    private var ungroupedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.stack")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Individual Screenshots")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(ungroupedScreenshots.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(ungroupedScreenshots.prefix(12)) { screenshot in
                    ScreenshotThumbnail(screenshot: screenshot, size: thumbnailSize)
                        .onTapGesture {
                            // Handle individual screenshot tap
                            hapticService.triggerHaptic(.light)
                        }
                }
                
                if ungroupedScreenshots.count > 12 {
                    Button(action: {
                        // Show all ungrouped screenshots
                    }) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: thumbnailSize, height: thumbnailSize)
                            .overlay(
                                VStack {
                                    Text("+\(ungroupedScreenshots.count - 12)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("more")
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Screenshots Yet")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Import screenshots to see them organized in smart groups")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Computed Properties
    
    private var groupedByType: [(key: GroupType, value: [ScreenshotGroup])] {
        Dictionary(grouping: groups, by: { $0.groupType })
            .sorted { $0.key.priority < $1.key.priority }
    }
    
    // MARK: - Actions
    
    private func checkForInitialGrouping() {
        // Only run if not already processing to avoid concurrent access
        guard !groupingService.isProcessing else { return }
        
        if groupingService.needsRegrouping(in: modelContext) {
            Task { @MainActor in
                await groupingService.analyzeAndGroupScreenshots(in: modelContext)
            }
        }
    }
    
    private func triggerRegrouping() async {
        await groupingService.triggerGroupingAnalysis(in: modelContext)
        hapticService.triggerHaptic(.success)
    }
}

// MARK: - Group Type Section

struct GroupTypeSection: View {
    let groupType: GroupType
    let groups: [ScreenshotGroup]
    @Binding var expandedGroups: Set<UUID>
    let onGroupTap: (ScreenshotGroup) -> Void
    let onGroupLongPress: (ScreenshotGroup) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: groupType.icon)
                    .font(.title2)
                    .foregroundColor(groupType.color)
                
                Text(groupType.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(groups.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Groups in this type
            LazyVStack(spacing: 8) {
                ForEach(groups) { group in
                    GroupCard(
                        group: group,
                        isExpanded: expandedGroups.contains(group.id),
                        onTap: { onGroupTap(group) },
                        onLongPress: { onGroupLongPress(group) },
                        onExpandToggle: {
                            if expandedGroups.contains(group.id) {
                                expandedGroups.remove(group.id)
                            } else {
                                expandedGroups.insert(group.id)
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Group Card

struct GroupCard: View {
    let group: ScreenshotGroup
    let isExpanded: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onExpandToggle: () -> Void
    
    @State private var isPressed = false
    
    private let maxThumbnailsInPreview = 4
    private let thumbnailSize: CGFloat = 45
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Group header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("\(group.screenshotCount) screenshots")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !group.isUserCreated {
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 3, height: 3)
                            
                            Text("\(Int(group.confidence * 100))% confidence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onExpandToggle) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Thumbnail preview
            if !group.screenshots.isEmpty {
                HStack(spacing: 8) {
                    ForEach(group.screenshots.prefix(maxThumbnailsInPreview)) { screenshot in
                        ScreenshotThumbnail(screenshot: screenshot, size: thumbnailSize)
                    }
                    
                    if group.screenshots.count > maxThumbnailsInPreview {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: thumbnailSize, height: thumbnailSize)
                            .overlay(
                                Text("+\(group.screenshots.count - maxThumbnailsInPreview)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            )
                    }
                    
                    Spacer()
                }
            }
            
            // Expanded content
            if isExpanded {
                expandedContent
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPressed ? Color.gray.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(group.groupType.color.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            // Group metadata
            if let dateRange = group.dateRange {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatDateRange(dateRange))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let appName = group.appName {
                HStack {
                    Image(systemName: "app.badge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(appName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let websiteURL = group.websiteURL {
                HStack {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(websiteURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick actions
            HStack {
                Button("View All") {
                    onTap()
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Spacer()
                
                if group.isUserCreated {
                    Button("Edit") {
                        // Handle edit action
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
        }
    }
    
    private func formatDateRange(_ dateRange: (start: Date, end: Date)) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        let start = formatter.string(from: dateRange.start)
        let end = formatter.string(from: dateRange.end)
        
        return "\(start) - \(end)"
    }
}

// MARK: - Screenshot Thumbnail

struct ScreenshotThumbnail: View {
    let screenshot: Screenshot
    let size: CGFloat
    
    var body: some View {
        Group {
            if let uiImage = UIImage(data: screenshot.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
            }
        }
    }
}

// MARK: - Group Detail View

struct GroupDetailView: View {
    let group: ScreenshotGroup
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(group.screenshots) { screenshot in
                        ScreenshotThumbnail(screenshot: screenshot, size: 100)
                            .onTapGesture {
                                // Handle screenshot tap
                            }
                    }
                }
                .padding()
            }
            .navigationTitle(group.title)
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
}

// MARK: - Preview

#Preview {
    GroupedGalleryView()
        .modelContainer(for: [Screenshot.self, ScreenshotGroup.self], inMemory: true)
}