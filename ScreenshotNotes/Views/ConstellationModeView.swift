
import SwiftUI
import SwiftData
import Photos

struct ConstellationModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var screenshots: [Screenshot]
    
    @StateObject private var detectionService = WorkspaceDetectionService()
    @State private var workspaces: [ContentWorkspace] = []
    @State private var isLoading = false
    @State private var sortCriteria: ContentWorkspace.SortCriteria = .lastUpdated
    @State private var showingCreateWorkspace = false
    
    // Photo import state
    @State private var isImporting = false
    @State private var importProgress: (current: Int, total: Int) = (0, 0)
    
    private let glassDesign = GlassDesignSystem.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Glass Material
                Color.clear
                    .ignoresSafeArea()
                    .glassBackground(material: .ultraThin, cornerRadius: 0, shadow: false)
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Header Section
                        headerSection
                        
                        // Import State
                        if isImporting {
                            importingSection
                        } else if isLoading {
                            loadingSection
                        } else if workspaces.isEmpty {
                            emptyStateSection
                        } else {
                            // Workspaces Section
                            workspacesSection
                        }
                    }
                    .padding()
                    .frame(minHeight: 500) // Ensure minimum height for pull-to-refresh
                }
            }
            .refreshable {
                print("📸 ConstellationModeView: Pull-to-refresh triggered")
                guard !isImporting && !isLoading else { 
                    print("📸 ConstellationModeView: Skipping refresh - already importing or loading")
                    return 
                }
                await importPhotosAndDetectWorkspaces()
            }
            .navigationTitle("Constellation")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingCreateWorkspace = true }) {
                            Label("Create Workspace", systemImage: "plus.circle")
                        }
                        
                        Menu("Sort by") {
                            ForEach(ContentWorkspace.SortCriteria.allCases, id: \.self) { criteria in
                                Button(criteria.rawValue) {
                                    sortCriteria = criteria
                                    sortWorkspaces()
                                }
                            }
                        }
                        
                        Button("Refresh") {
                            Task {
                                await detectWorkspaces()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingCreateWorkspace) {
                CreateWorkspaceView()
            }
        }
        .onAppear {
            if workspaces.isEmpty {
                Task {
                    await detectWorkspaces()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Content Constellation")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Intelligent workspace organization")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Detection Progress
                if detectionService.isProcessing {
                    VStack {
                        ProgressView(value: detectionService.detectionProgress)
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(width: 24, height: 24)
                        
                        Text("Analyzing...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Stats
            if !workspaces.isEmpty {
                HStack(spacing: 20) {
                    StatView(title: "Workspaces", value: "\(workspaces.count)")
                    StatView(title: "Screenshots", value: "\(workspaces.reduce(0) { $0 + $1.screenshots.count })")
                    StatView(title: "Avg Progress", value: "\(Int(workspaces.reduce(0) { $0 + $1.progress.percentage } / Double(workspaces.count)))%")
                }
            }
        }
        .padding()
        .glassBackground(material: .thin, cornerRadius: 16, shadow: true)
    }
    
    private var importingSection: some View {
        VStack(spacing: 16) {
            if importProgress.total > 0 {
                ProgressView(value: Double(importProgress.current), total: Double(importProgress.total))
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 8)
                
                Text("Importing \(importProgress.current) of \(importProgress.total) screenshots...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                
                Text("Importing screenshots from Photos...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .glassBackground(material: .regular, cornerRadius: 12, shadow: false)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView(value: detectionService.detectionProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 8)
            
            Text("Analyzing \(screenshots.count) screenshots...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .glassBackground(material: .regular, cornerRadius: 12, shadow: false)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Workspaces Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if screenshots.isEmpty {
                    Text("Pull down to import screenshots from your photo library")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                } else {
                    Text("You have \(screenshots.count) screenshot(s). Pull down to import more or create a manual workspace.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button("Create Manual Workspace") {
                showingCreateWorkspace = true
            }
            .buttonStyle(PrimaryGlassButtonStyle())
        }
        .padding(40)
        .glassBackground(material: .regular, cornerRadius: 16, shadow: false)
    }
    
    private var workspacesSection: some View {
        LazyVStack(spacing: 16) {
            ForEach(workspaces) { workspace in
                WorkspaceCardView(workspace: workspace)
                    .onTapGesture {
                        // Navigate to workspace detail
                    }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func detectWorkspaces() async {
        print("📸 ConstellationModeView: detectWorkspaces called with \(screenshots.count) screenshots")
        isLoading = true
        
        // Debug: Check if screenshots have the necessary data for workspace detection
        let screenshotsWithText = screenshots.filter { !($0.extractedText?.isEmpty ?? true) }
        let screenshotsWithSemanticTags = screenshots.filter { !($0.semanticTags?.tags.isEmpty ?? true) }
        print("📸 ConstellationModeView: \(screenshotsWithText.count) screenshots have extracted text")
        print("📸 ConstellationModeView: \(screenshotsWithSemanticTags.count) screenshots have semantic tags")
        
        let detectedWorkspaces = await detectionService.detectWorkspaces(from: screenshots)
        
        await MainActor.run {
            workspaces = ContentWorkspace.sortWorkspaces(detectedWorkspaces, by: sortCriteria)
            isLoading = false
            print("📸 ConstellationModeView: detectWorkspaces completed, found \(workspaces.count) workspaces")
            
            // Debug: Log workspace details
            for (index, workspace) in workspaces.enumerated() {
                print("📸 ConstellationModeView: Workspace \(index): \(workspace.type.displayName) with \(workspace.screenshots.count) screenshots (confidence: \(workspace.detectionConfidence))")
            }
        }
    }
    
    private func sortWorkspaces() {
        workspaces = ContentWorkspace.sortWorkspaces(workspaces, by: sortCriteria)
    }
    
    private func importPhotosAndDetectWorkspaces() async {
        print("📸 ConstellationModeView: importPhotosAndDetectWorkspaces called")
        
        // First, try to import new photos
        await importNewPhotos()
        
        // Then detect workspaces with updated screenshot list
        await detectWorkspaces()
    }
    
    private func importNewPhotos() async {
        print("📸 ConstellationModeView: importNewPhotos called")
        
        // Use the existing PhotoLibraryService for consistency
        let photoLibraryService = PhotoLibraryService()
        photoLibraryService.setModelContext(modelContext)
        
        // Check and request photo permission if needed
        let currentStatus = photoLibraryService.authorizationStatus
        print("📸 ConstellationModeView: Photo permission status: \(currentStatus)")
        
        if currentStatus != PHAuthorizationStatus.authorized {
            print("📸 ConstellationModeView: Photo permission not granted, requesting...")
            let newStatus = await photoLibraryService.requestPhotoLibraryPermission()
            print("📸 ConstellationModeView: New photo permission status: \(newStatus)")
            
            if newStatus != PHAuthorizationStatus.authorized {
                print("📸 ConstellationModeView: Photo permission denied, cannot import")
                return
            }
        }
        
        isImporting = true
        print("📸 ConstellationModeView: Starting photo import using PhotoLibraryService")
        
        // Import photos using the same method as GalleryModeRenderer
        let batchSize = 10
        let maxImportLimit = 20
        var totalImported = 0
        var totalSkipped = 0
        var hasMore = true
        var batchIndex = 0
        
        while hasMore && totalImported < maxImportLimit {
            print("📸 ConstellationModeView: Processing batch \(batchIndex + 1) (batchSize: \(batchSize))")
            let result = await photoLibraryService.importPastScreenshotsBatch(batch: batchIndex, batchSize: batchSize)
            print("📸 ConstellationModeView: Batch \(batchIndex + 1) result: imported=\(result.imported), skipped=\(result.skipped), hasMore=\(result.hasMore)")
            
            totalImported += result.imported
            totalSkipped += result.skipped
            batchIndex += 1
            hasMore = result.hasMore
            
            // Stop if we've reached the import limit
            if totalImported >= maxImportLimit {
                hasMore = false
                print("📸 ConstellationModeView: Reached import limit of \(maxImportLimit), stopping")
            }
            
            // Update progress for UI feedback
            importProgress = (current: totalImported, total: min(totalImported + totalSkipped, maxImportLimit))
            print("📸 ConstellationModeView: Progress: \(importProgress.current)/\(importProgress.total)")
            
            // Shorter yield for more responsive UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s between batches
        }
        
        // Trigger background processing ONCE after all imports are complete
        if totalImported > 0 {
            print("📸 ConstellationModeView: All imports complete (\(totalImported) screenshots), starting background processing")
            
            // Start OCR processing
            let backgroundOCRProcessor = BackgroundOCRProcessor()
            backgroundOCRProcessor.startBackgroundProcessingIfNeeded(in: modelContext)
            
            // Start semantic processing using shared instance
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            await BackgroundSemanticProcessor.shared.processScreenshotsNeedingAnalysis(in: modelContext)
            
            print("📸 ConstellationModeView: Background processing completed for all imported screenshots")
        }
        
        print("📸 ConstellationModeView: Import complete: \(totalImported) imported, \(totalSkipped) skipped")
        
        isImporting = false
        importProgress = (0, 0)
    }
}

// MARK: - Supporting Views

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct WorkspaceCardView: View {
    let workspace: ContentWorkspace
    @State private var showingDetails = false
    @State private var showingTimeline = false
    @StateObject private var insightsEngine = WorkspaceInsightsEngine()
    
    private let glassDesign = GlassDesignSystem.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Section
            headerSection
            
            // Analytics & Insights Section
            analyticsSection
            
            // Timeline Preview Section
            if showingTimeline {
                timelineSection
            }
            
            // Action Buttons Section
            actionButtonsSection
        }
        .padding()
        .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
        .sheet(isPresented: $showingDetails) {
            WorkspaceDetailSheetView(workspace: workspace)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack {
            Image(systemName: workspace.iconName)
                .font(.title2)
                .foregroundColor(colorForWorkspace(workspace))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(workspace.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Activity Level Badge
            ActivityBadge(level: workspace.activityLevel)
        }
    }
    
    private var analyticsSection: some View {
        let analytics = WorkspaceAnalyticsService.shared.generateAnalytics(for: workspace)
        let insights = insightsEngine.generateInsights(for: workspace)
        
        return VStack(alignment: .leading, spacing: 12) {
            // Progress with enhanced analytics
            HStack {
                Text("Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(analytics.completionAnalytics.overallCompletion * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(colorForWorkspace(workspace))
                    
                    Text(analytics.completionAnalytics.completionLevel.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: analytics.completionAnalytics.overallCompletion)
                .progressViewStyle(LinearProgressViewStyle(tint: colorForWorkspace(workspace)))
                .scaleEffect(y: 1.2)
            
            // Enhanced metrics grid
            HStack(spacing: 20) {
                MetricView(
                    title: "Screenshots",
                    value: "\(workspace.screenshots.count)",
                    icon: "camera.fill",
                    color: .blue
                )
                
                MetricView(
                    title: "Completion",
                    value: "\(analytics.progressTrends.estimatedDaysToCompletion)d",
                    icon: "clock.fill",
                    color: analytics.progressTrends.momentum.color
                )
                
                if analytics.missingComponentAnalysis.criticalMissing.count > 0 {
                    MetricView(
                        title: "Critical",
                        value: "\(analytics.missingComponentAnalysis.criticalMissing.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
            }
            
            // AI-Generated Insights
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Insights")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(insights.prefix(2), id: \.self) { insight in
                        Text(insight)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary.opacity(0.5))
                )
            }
        }
    }
    
    @ViewBuilder
    private var timelineSection: some View {
        let analytics = WorkspaceAnalyticsService.shared.generateAnalytics(for: workspace)
        let advancedInsights = insightsEngine.generateAdvancedInsights(for: workspace)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            WorkspaceTimelineView(
                workspace: workspace,
                analytics: analytics,
                timelineInsights: advancedInsights.timelineInsights
            )
            .frame(maxHeight: 200)
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Timeline Toggle Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingTimeline.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: showingTimeline ? "timeline.selection" : "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .medium))
                    Text(showingTimeline ? "Hide Timeline" : "Show Timeline")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.blue.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Details Button
            Button(action: {
                showingDetails = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("Details")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(colorForWorkspace(workspace))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Confidence indicator (if needs review)
            if workspace.needsUserReview {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Text("\(Int(workspace.detectionConfidence * 100))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.orange.opacity(0.1))
                )
            }
        }
    }
    
    private func colorForWorkspace(_ workspace: ContentWorkspace) -> Color {
        switch workspace.colorScheme {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Supporting Views

struct MetricView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct WorkspaceDetailSheetView: View {
    let workspace: ContentWorkspace
    @Environment(\.dismiss) private var dismiss
    @StateObject private var insightsEngine = WorkspaceInsightsEngine()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Workspace Header
                    workspaceHeaderSection
                    
                    // Comprehensive Analytics
                    analyticsOverviewSection
                    
                    // Advanced Insights
                    insightsSection
                    
                    // Full Timeline
                    timelineSection
                    
                    // Action Recommendations
                    actionsSection
                }
                .padding()
            }
            .navigationTitle(workspace.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var workspaceHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: workspace.iconName)
                    .font(.largeTitle)
                    .foregroundColor(colorForWorkspace)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(workspace.type.displayName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Created \(workspace.createdAt, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private var analyticsOverviewSection: some View {
        let analytics = WorkspaceAnalyticsService.shared.generateAnalytics(for: workspace)
        
        VStack(alignment: .leading, spacing: 16) {
            Text("Analytics Overview")
                .font(.title3)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                AnalyticsCard(
                    title: "Completion",
                    value: "\(Int(analytics.completionAnalytics.overallCompletion * 100))%",
                    subtitle: analytics.completionAnalytics.completionLevel.displayName,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                AnalyticsCard(
                    title: "Momentum",
                    value: analytics.progressTrends.momentum.displayName,
                    subtitle: "Trend analysis",
                    icon: "arrow.up.right.circle.fill",
                    color: analytics.progressTrends.momentum.color
                )
                
                AnalyticsCard(
                    title: "Timeline",
                    value: "\(Int(analytics.timelineAnalysis.workspaceDuration / 86400))d",
                    subtitle: "Duration",
                    icon: "clock.fill",
                    color: .blue
                )
                
                AnalyticsCard(
                    title: "Missing",
                    value: "\(analytics.missingComponentAnalysis.criticalMissing.count)",
                    subtitle: "Critical items",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
        }
    }
    
    @ViewBuilder
    private var insightsSection: some View {
        let insights = insightsEngine.generateInsights(for: workspace)
        
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("AI Insights")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                            .frame(width: 20, height: 20)
                        
                        Text(insight)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.quaternary.opacity(0.5))
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var timelineSection: some View {
        let analytics = WorkspaceAnalyticsService.shared.generateAnalytics(for: workspace)
        let advancedInsights = insightsEngine.generateAdvancedInsights(for: workspace)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.title3)
                .fontWeight(.semibold)
            
            WorkspaceTimelineView(
                workspace: workspace,
                analytics: analytics,
                timelineInsights: advancedInsights.timelineInsights
            )
        }
    }
    
    @ViewBuilder
    private var actionsSection: some View {
        let analytics = WorkspaceAnalyticsService.shared.generateAnalytics(for: workspace)
        
        if !analytics.actionRecommendations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommended Actions")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                ForEach(analytics.actionRecommendations.prefix(5), id: \.id) { recommendation in
                    ActionRecommendationView(recommendation: recommendation)
                }
            }
        }
    }
    
    private var colorForWorkspace: Color {
        switch workspace.colorScheme {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "red": return .red
        default: return .gray
        }
    }
}

struct AnalyticsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ActionRecommendationView: View {
    let recommendation: WorkspaceAnalyticsService.ActionRecommendation
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recommendation.action.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(priorityColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.action.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(recommendation.priority.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(priorityColor)
                
                Text(recommendation.estimatedEffort.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(priorityColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var priorityColor: Color {
        switch recommendation.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .green
        }
    }
}

struct ActivityBadge: View {
    let level: ContentWorkspace.WorkspaceActivityLevel
    
    var body: some View {
        Text(level.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorForLevel(level).opacity(0.2))
            )
            .foregroundColor(colorForLevel(level))
    }
    
    private func colorForLevel(_ level: ContentWorkspace.WorkspaceActivityLevel) -> Color {
        switch level {
        case .veryActive: return .green
        case .active: return .blue
        case .moderate: return .yellow
        case .stale: return .gray
        }
    }
}

struct PrimaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct CreateWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Create Manual Workspace")
                    .font(.title)
                    .padding()
                
                Text("Manual workspace creation will be implemented in the next iteration.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("New Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
