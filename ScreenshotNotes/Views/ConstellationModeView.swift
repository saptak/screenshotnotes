
import SwiftUI
import SwiftData

struct ConstellationModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var screenshots: [Screenshot]
    
    @StateObject private var detectionService = WorkspaceDetectionService()
    @State private var workspaces: [ContentWorkspace] = []
    @State private var isLoading = false
    @State private var sortCriteria: ContentWorkspace.SortCriteria = .lastUpdated
    @State private var showingCreateWorkspace = false
    
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
                        
                        // Loading State
                        if isLoading {
                            loadingSection
                        } else if workspaces.isEmpty {
                            emptyStateSection
                        } else {
                            // Workspaces Section
                            workspacesSection
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await detectWorkspaces()
                }
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
                
                Text("Add more screenshots to enable intelligent workspace detection")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
        isLoading = true
        
        let detectedWorkspaces = await detectionService.detectWorkspaces(from: screenshots)
        
        await MainActor.run {
            workspaces = ContentWorkspace.sortWorkspaces(detectedWorkspaces, by: sortCriteria)
            isLoading = false
        }
    }
    
    private func sortWorkspaces() {
        workspaces = ContentWorkspace.sortWorkspaces(workspaces, by: sortCriteria)
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
    private let glassDesign = GlassDesignSystem.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
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
            
            // Progress Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(workspace.progress.percentage))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(colorForWorkspace(workspace))
                }
                
                ProgressView(value: workspace.progress.percentage / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: colorForWorkspace(workspace)))
            }
            
            // Screenshots and Missing Components
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(workspace.screenshots.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("Screenshots")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !workspace.progress.missingComponents.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(workspace.progress.missingComponents.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        
                        Text("Missing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Missing Components List
            if !workspace.progress.missingComponents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Missing Components:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(workspace.progress.missingComponents.prefix(3), id: \.self) { component in
                        Text("• \(component)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if workspace.progress.missingComponents.count > 3 {
                        Text("and \(workspace.progress.missingComponents.count - 3) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Confidence Indicator
            if workspace.needsUserReview {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text("Needs Review")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text("\(Int(workspace.detectionConfidence * 100))% confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
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
