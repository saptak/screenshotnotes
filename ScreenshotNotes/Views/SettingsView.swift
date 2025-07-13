import SwiftUI
import SwiftData
import Photos

struct SettingsView: View {
    @ObservedObject private var settingsService = SettingsService.shared
    @ObservedObject private var photoLibraryService: PhotoLibraryService
    @StateObject private var performanceMonitor = GalleryPerformanceMonitor.shared
    @StateObject private var thumbnailService = ThumbnailService.shared
    @StateObject private var interfaceSettings = InterfaceSettings()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var screenshots: [Screenshot]
    
    // Bulk deletion state
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletionProgress = false
    @State private var deletionProgress: Double = 0.0
    @State private var deletionStatus = ""
    @State private var deletionCompleted = false
    
    init(photoLibraryService: PhotoLibraryService) {
        self.photoLibraryService = photoLibraryService
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Automatic Import")
                                    .font(.headline)
                                Text("Automatically import new screenshots")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $photoLibraryService.automaticImportEnabled)
                                .onChange(of: photoLibraryService.automaticImportEnabled) { _, enabled in
                                    settingsService.automaticImportEnabled = enabled
                                }
                        }
                        
                        if photoLibraryService.authorizationStatus != .authorized {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                Text("Photo library access required")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Grant Access") {
                                    Task { @MainActor in
                                        _ = await photoLibraryService.requestPhotoLibraryPermission()
                                    }
                                }
                                .font(.caption)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Screenshot Detection")
                } footer: {
                    Text("When enabled, Screenshot Vault will automatically detect and import new screenshots from your photo library.")
                }
                
                Section {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Originals")
                                .font(.headline)
                            Text("Remove screenshots from Photos app after import")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $settingsService.deleteOriginalScreenshots)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Storage Management")
                } footer: {
                    Text("⚠️ Warning: This will permanently delete screenshots from your Photos app. They will only exist in Screenshot Vault.")
                }
                
                Section {
                    HStack {
                        Image(systemName: "gearshape.2")
                            .foregroundColor(.purple)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Background Processing")
                                .font(.headline)
                            Text("Process screenshots when app is in background")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $settingsService.backgroundProcessingEnabled)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Performance")
                } footer: {
                    Text("Allows the app to process screenshots and extract text when not actively in use.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gallery Performance")
                                    .font(.headline)
                                Text("Current performance metrics")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        if performanceMonitor.isMonitoring {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("FPS:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(performanceMonitor.currentFPS))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(performanceMonitor.currentFPS < 45 ? .red : .primary)
                                }
                                
                                HStack {
                                    Text("Memory:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(performanceMonitor.memoryUsage))MB")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(performanceMonitor.memoryUsage > 200 ? .red : .primary)
                                }
                                
                                HStack {
                                    Text("Thermal:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(thermalStateText(performanceMonitor.thermalState))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(thermalStateColor(performanceMonitor.thermalState))
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            Text("Performance monitoring inactive")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        
                        Button(action: {
                            thumbnailService.clearCache()
                            thumbnailService.cleanupDiskCache()
                        }) {
                            HStack {
                                Image(systemName: "trash.circle")
                                    .foregroundColor(.orange)
                                Text("Clear Thumbnail Cache")
                                    .foregroundColor(.orange)
                                Spacer()
                                let stats = thumbnailService.getCacheStats()
                                Text("\(stats.memoryCount) cached")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Performance Monitoring")
                } footer: {
                    Text("Monitor gallery performance and clear cache to free up memory. Multiple thumbnail sizes are cached per image for optimal performance. Performance monitoring is active when viewing the gallery.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundColor(.red)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bulk Delete from Photos")
                                    .font(.headline)
                                Text("Remove all imported screenshots from Photos app")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        let importedCount = screenshots.filter { $0.assetIdentifier != nil }.count
                        
                        if importedCount > 0 {
                            HStack {
                                Text("\(importedCount) imported screenshots found")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.white)
                                    Text("Delete All from Photos")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("No imported screenshots to delete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Bulk Operations")
                } footer: {
                    Text("⚠️ WARNING: This will permanently delete ALL imported screenshots from your Photos app. Screenshots will remain in Screenshot Vault. This action cannot be undone.")
                }
                
                // Enhanced Interface Section (Sprint 8.1.1)
                if interfaceSettings.showEnhancedInterfaceOptions {
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Enhanced Interface")
                                        .font(.headline)
                                    Text("Advanced Liquid Glass design with voice controls")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            InterfaceTypeSelectionView(settings: interfaceSettings)
                            
                            if interfaceSettings.isUsingEnhancedInterface {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Enhanced Features Available:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Single-click voice commands")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Content constellation grouping")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Liquid Glass materials")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Intelligent triage system")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Advanced")
                    } footer: {
                        if interfaceSettings.isUsingEnhancedInterface {
                            Text("You are using the Enhanced Interface with advanced features. You can switch back to the Legacy Interface at any time.")
                        } else {
                            Text("The Enhanced Interface includes advanced Liquid Glass design, voice controls, and intelligent content organization. The Legacy Interface remains fully functional.")
                        }
                    }
                }
                
                Section {
                    Button("Reset to Defaults") {
                        settingsService.resetToDefaults()
                        interfaceSettings.resetToDefaults()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Delete All Screenshots from Photos?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    Task {
                        await performBulkDeletion()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let count = screenshots.filter { $0.assetIdentifier != nil }.count
                Text("This will permanently delete \(count) screenshots from your Photos app. This action cannot be undone. Screenshots will remain in Screenshot Vault.")
            }
            .sheet(isPresented: $showingDeletionProgress) {
                DeletionProgressView(
                    progress: deletionProgress,
                    status: deletionStatus,
                    isCompleted: deletionCompleted,
                    onDismiss: {
                        showingDeletionProgress = false
                        deletionCompleted = false
                        deletionProgress = 0.0
                        deletionStatus = ""
                    }
                )
            }
        }
    }
    
    // MARK: - Bulk Deletion Functions
    
    private func performBulkDeletion() async {
        showingDeletionProgress = true
        deletionProgress = 0.0
        deletionStatus = "Preparing deletion..."
        
        // Check permissions
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized else {
            deletionStatus = "Photos access required"
            deletionCompleted = true
            return
        }
        
        // Get screenshots with asset identifiers
        let screenshotsToDelete = screenshots.filter { $0.assetIdentifier != nil }
        let totalCount = screenshotsToDelete.count
        
        guard totalCount > 0 else {
            deletionStatus = "No screenshots to delete"
            deletionCompleted = true
            return
        }
        
        deletionStatus = "Deleting \(totalCount) screenshots..."
        
        var deletedCount = 0
        var failedCount = 0
        
        // Process in batches to avoid memory issues
        let batchSize = 50
        let batches = stride(from: 0, to: totalCount, by: batchSize).map {
            Array(screenshotsToDelete[$0..<min($0 + batchSize, totalCount)])
        }
        
        for (batchIndex, batch) in batches.enumerated() {
            // Update progress
            let batchProgress = Double(batchIndex) / Double(batches.count)
            await MainActor.run {
                deletionProgress = batchProgress
                deletionStatus = "Processing batch \(batchIndex + 1) of \(batches.count)..."
            }
            
            // Get asset identifiers for this batch
            let assetIdentifiers = batch.compactMap { $0.assetIdentifier }
            
            // Fetch PHAssets
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
            let assetsToDelete = Array(0..<fetchResult.count).map { fetchResult.object(at: $0) }
            
            // Perform deletion
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
                }
                
                deletedCount += assetsToDelete.count
                
                // Clear asset identifiers from successfully deleted screenshots
                await MainActor.run {
                    for screenshot in batch {
                        if assetIdentifiers.contains(screenshot.assetIdentifier ?? "") {
                            screenshot.assetIdentifier = nil
                        }
                    }
                    
                    do {
                        try modelContext.save()
                    } catch {
                        print("❌ Failed to save model context: \(error)")
                    }
                }
                
            } catch {
                print("❌ Failed to delete batch: \(error)")
                failedCount += assetsToDelete.count
            }
        }
        
        // Final status
        await MainActor.run {
            deletionProgress = 1.0
            if failedCount == 0 {
                deletionStatus = "Successfully deleted \(deletedCount) screenshots"
            } else {
                deletionStatus = "Deleted \(deletedCount), failed \(failedCount)"
            }
            deletionCompleted = true
        }
    }
    
    // MARK: - Helper Functions
    
    private func thermalStateText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "Normal"
        case .fair:
            return "Fair"
        case .serious:
            return "High"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func thermalStateColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        @unknown default:
            return .gray
        }
    }
}

// MARK: - Deletion Progress View

struct DeletionProgressView: View {
    let progress: Double
    let status: String
    let isCompleted: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                Image(systemName: isCompleted ? (progress == 1.0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill") : "trash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(isCompleted ? (progress == 1.0 ? .green : .orange) : .red)
                
                // Progress Circle
                if !isCompleted {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: progress)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                
                // Status Text
                VStack(spacing: 8) {
                    Text(isCompleted ? "Deletion Complete" : "Deleting Screenshots")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(status)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Done Button (only when completed)
                if isCompleted {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Bulk Delete")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(!isCompleted)
            .toolbar {
                if isCompleted {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            onDismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(!isCompleted)
    }
}