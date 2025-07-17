
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
                }
                .refreshable {
                    print("📸 ConstellationModeView: Pull-to-refresh triggered")
                    await importPhotosAndDetectWorkspaces()
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
        print("📸 ConstellationModeView: detectWorkspaces called")
        isLoading = true
        
        let detectedWorkspaces = await detectionService.detectWorkspaces(from: screenshots)
        
        await MainActor.run {
            workspaces = ContentWorkspace.sortWorkspaces(detectedWorkspaces, by: sortCriteria)
            isLoading = false
            print("📸 ConstellationModeView: detectWorkspaces completed, found \(workspaces.count) workspaces")
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
        
        // Check photo library permission
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("📸 ConstellationModeView: Photo permission status: \(currentStatus)")
        
        if currentStatus != .authorized {
            print("📸 ConstellationModeView: Photo permission not granted, requesting...")
            let newStatus = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    continuation.resume(returning: status)
                }
            }
            print("📸 ConstellationModeView: New photo permission status: \(newStatus)")
            guard newStatus == .authorized else {
                print("📸 ConstellationModeView: Photo permission denied, cannot import")
                return
            }
        }
        
        isImporting = true
        print("📸 ConstellationModeView: Starting photo import")
        
        // Import photos similar to the GalleryModeRenderer approach
        let batchSize = 10
        let maxImportLimit = 20
        var totalImported = 0
        var totalSkipped = 0
        var hasMore = true
        var batchIndex = 0
        
        // Get screenshot assets from photo library
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allScreenshots = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        print("📸 ConstellationModeView: Found \(allScreenshots.count) screenshots in photo library")
        
        while hasMore && totalImported < maxImportLimit {
            let start = batchIndex * batchSize
            let end = min(start + batchSize, allScreenshots.count)
            
            if start >= end {
                hasMore = false
                break
            }
            
            print("📸 ConstellationModeView: Processing batch \(batchIndex + 1), range \(start)..<\(end)")
            
            for i in start..<end {
                let asset = allScreenshots.object(at: i)
                let assetId = asset.localIdentifier
                
                // Check if already imported
                let existingScreenshots = try? modelContext.fetch(
                    FetchDescriptor<Screenshot>(
                        predicate: #Predicate<Screenshot> { screenshot in
                            screenshot.assetIdentifier == assetId
                        }
                    )
                )
                
                if existingScreenshots?.isEmpty == false {
                    totalSkipped += 1
                    continue
                }
                
                // Import the screenshot
                do {
                    let imageManager = PHImageManager.default()
                    let requestOptions = PHImageRequestOptions()
                    requestOptions.isSynchronous = true
                    requestOptions.deliveryMode = .highQualityFormat
                    requestOptions.isNetworkAccessAllowed = true
                    
                    let image = await withCheckedContinuation { continuation in
                        imageManager.requestImage(
                            for: asset,
                            targetSize: PHImageManagerMaximumSize,
                            contentMode: .aspectFit,
                            options: requestOptions
                        ) { image, _ in
                            continuation.resume(returning: image)
                        }
                    }
                    
                    guard let image = image,
                          let imageData = image.jpegData(compressionQuality: 0.8) else {
                        totalSkipped += 1
                        continue
                    }
                    
                    let screenshot = Screenshot(
                        imageData: imageData,
                        filename: "screenshot_\(asset.creationDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)",
                        timestamp: asset.creationDate ?? Date(),
                        assetIdentifier: asset.localIdentifier
                    )
                    
                    modelContext.insert(screenshot)
                    try modelContext.save()
                    totalImported += 1
                    
                    print("📸 ConstellationModeView: Imported screenshot \(totalImported): \(asset.localIdentifier)")
                    
                } catch {
                    print("📸 ConstellationModeView: Failed to import screenshot: \(error)")
                    totalSkipped += 1
                }
            }
            
            batchIndex += 1
            importProgress = (current: totalImported, total: min(totalImported + totalSkipped, maxImportLimit))
            
            if totalImported >= maxImportLimit {
                hasMore = false
            }
        }
        
        print("📸 ConstellationModeView: Import completed - imported: \(totalImported), skipped: \(totalSkipped)")
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
