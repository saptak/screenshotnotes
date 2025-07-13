import SwiftUI
import SwiftData
import Photos

struct SettingsView: View {
    @ObservedObject private var settingsService = SettingsService.shared
    @ObservedObject private var photoLibraryService: PhotoLibraryService
    @StateObject private var performanceMonitor = GalleryPerformanceMonitor.shared
    @StateObject private var thumbnailService = ThumbnailService.shared
    @StateObject private var interfaceSettings = InterfaceSettings()
    @StateObject private var liquidGlassMonitor = LiquidGlassPerformanceMonitor.shared
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
                
                // A/B Testing Section (Sprint 8.1.2)
                if interfaceSettings.isUsingEnhancedInterface {
                    Section {
                        abTestingControls
                    } header: {
                        Text("Material Testing")
                    } footer: {
                        Text("Help us improve the Enhanced Interface by testing different Liquid Glass materials and providing feedback.")
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
            .background {
                // Sprint 8.1.2: Liquid Glass Preview Integration with smooth transitions
                ZStack {
                    // Legacy background always present for smooth transitions
                    legacyBackground
                    
                    // Liquid Glass background with animated opacity
                    if interfaceSettings.isUsingEnhancedInterface {
                        liquidGlassBackground
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 1.05)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.6), value: interfaceSettings.isUsingEnhancedInterface)
            }
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
        .onAppear {
            // Start monitoring when Enhanced Interface is active
            if interfaceSettings.isUsingEnhancedInterface {
                liquidGlassMonitor.startMonitoring()
            }
        }
        .onDisappear {
            // Stop monitoring when leaving settings
            liquidGlassMonitor.stopMonitoring()
        }
        .onChange(of: interfaceSettings.isUsingEnhancedInterface) { _, isUsing in
            // Track interface state changes
            if isUsing {
                liquidGlassMonitor.startMonitoring()
            } else {
                liquidGlassMonitor.stopMonitoring()
            }
        }
        .onChange(of: interfaceSettings.abTestMaterialType) { _, newMaterial in
            // Track material switches for A/B testing
            liquidGlassMonitor.recordMaterialSwitch()
        }
        .onChange(of: interfaceSettings.abTestRating) { _, newRating in
            // Record user rating for current material
            if newRating > 0 {
                liquidGlassMonitor.recordMaterialRating(
                    material: interfaceSettings.abTestMaterialType.rawValue,
                    rating: newRating
                )
            }
        }
    }
    
    // MARK: - Background Views (Sprint 8.1.2)
    
    /// Liquid Glass background for Enhanced Interface
    @ViewBuilder
    private var liquidGlassBackground: some View {
        // Create a beautiful gradient backdrop for the Liquid Glass effect
        LinearGradient(
            colors: [
                Color.blue.opacity(0.15),
                Color.purple.opacity(0.12),
                Color.cyan.opacity(0.08),
                Color.pink.opacity(0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea(.all)
        .overlay {
            // Add the Liquid Glass material overlay with A/B testing support
            Rectangle()
                .liquidGlassBackground(
                    material: interfaceSettings.isABTestingEnabled ? 
                        interfaceSettings.abTestMaterialType : .gossamer,
                    cornerRadius: 0,
                    specularHighlights: true
                )
                .ignoresSafeArea(.all)
        }
    }
    
    /// Legacy background for standard interface
    @ViewBuilder
    private var legacyBackground: some View {
        // Standard system background - maintains existing appearance
        Color(.systemGroupedBackground)
            .ignoresSafeArea(.all)
    }
    
    // MARK: - A/B Testing Controls (Sprint 8.1.2)
    
    @ViewBuilder
    private var abTestingControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            // A/B Testing Toggle
            HStack {
                Image(systemName: "flask")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Material Testing Mode")
                        .font(.headline)
                    Text("Test different Liquid Glass materials")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $interfaceSettings.isABTestingEnabled)
            }
            
            if interfaceSettings.isABTestingEnabled {
                Divider()
                
                // Material Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Material")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    materialSelectionGrid
                }
                
                Divider()
                
                // Feedback Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rate this material")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ratingStars
                    
                    if interfaceSettings.hasProvidedABTestFeedback {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Thank you for your feedback!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                // Performance Monitoring Display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Metrics")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    performanceMetricsView
                }
                
                Divider()
                
                // Enhanced Interface Feedback Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share Your Experience")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    feedbackSection
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var materialSelectionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(LiquidGlassMaterial.MaterialType.allCases, id: \.self) { material in
                Button(action: {
                    interfaceSettings.abTestMaterialType = material
                    interfaceSettings.abTestRating = 0 // Reset rating when material changes
                }) {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .frame(height: 40)
                            .liquidGlassBackground(material: material, cornerRadius: 8)
                            .overlay {
                                if interfaceSettings.abTestMaterialType == material {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(.blue, lineWidth: 2)
                                }
                            }
                        
                        Text(material.rawValue.capitalized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var ratingStars: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Button(action: {
                    interfaceSettings.abTestRating = star
                }) {
                    Image(systemName: star <= interfaceSettings.abTestRating ? "star.fill" : "star")
                        .foregroundColor(star <= interfaceSettings.abTestRating ? .yellow : .gray)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            if interfaceSettings.abTestRating > 0 {
                Text("(\(interfaceSettings.abTestRating)/5)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var performanceMetricsView: some View {
        VStack(spacing: 8) {
            // Performance Status
            HStack {
                Circle()
                    .fill(liquidGlassMonitor.performanceWarningLevel.color)
                    .frame(width: 8, height: 8)
                
                Text(liquidGlassMonitor.performanceWarningLevel.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if liquidGlassMonitor.isLiquidGlassActive {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("Active")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Performance Metrics Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                performanceMetricCard(
                    title: "FPS",
                    value: "\(Int(liquidGlassMonitor.liquidGlassFPS))",
                    icon: "speedometer",
                    color: liquidGlassMonitor.liquidGlassFPS >= 45 ? .green : .orange
                )
                
                performanceMetricCard(
                    title: "Memory",
                    value: "\(Int(liquidGlassMonitor.liquidGlassMemoryUsage))MB",
                    icon: "memorychip",
                    color: liquidGlassMonitor.liquidGlassMemoryUsage < 100 ? .green : .orange
                )
                
                performanceMetricCard(
                    title: "Session",
                    value: formatDuration(liquidGlassMonitor.enhancedInterfaceSessionDuration),
                    icon: "clock",
                    color: .blue
                )
                
                performanceMetricCard(
                    title: "Switches",
                    value: "\(liquidGlassMonitor.materialSwitchCount)",
                    icon: "arrow.triangle.2.circlepath",
                    color: .purple
                )
            }
        }
    }
    
    @ViewBuilder
    private func performanceMetricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "\(Int(duration))s"
        } else if duration < 3600 {
            return "\(Int(duration / 60))m"
        } else {
            return "\(Int(duration / 3600))h"
        }
    }
    
    @ViewBuilder
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quick feedback buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("How do you feel about the Enhanced Interface?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    feedbackButton(emoji: "😍", label: "Love it", action: {
                        interfaceSettings.enhancedInterfaceFeedback = "Love it - " + (interfaceSettings.enhancedInterfaceFeedback.isEmpty ? "Amazing experience!" : interfaceSettings.enhancedInterfaceFeedback)
                    })
                    
                    feedbackButton(emoji: "👍", label: "Like it", action: {
                        interfaceSettings.enhancedInterfaceFeedback = "Like it - " + (interfaceSettings.enhancedInterfaceFeedback.isEmpty ? "Good improvements!" : interfaceSettings.enhancedInterfaceFeedback)
                    })
                    
                    feedbackButton(emoji: "😐", label: "Neutral", action: {
                        interfaceSettings.enhancedInterfaceFeedback = "Neutral - " + (interfaceSettings.enhancedInterfaceFeedback.isEmpty ? "It's okay." : interfaceSettings.enhancedInterfaceFeedback)
                    })
                    
                    feedbackButton(emoji: "👎", label: "Dislike", action: {
                        interfaceSettings.enhancedInterfaceFeedback = "Dislike - " + (interfaceSettings.enhancedInterfaceFeedback.isEmpty ? "Needs improvement." : interfaceSettings.enhancedInterfaceFeedback)
                    })
                }
            }
            
            // Beta participation toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Join Beta Testing")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Get early access to new features")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $interfaceSettings.wantsBetaParticipation)
                    .scaleEffect(0.8)
            }
            
            // Feedback summary
            if !interfaceSettings.enhancedInterfaceFeedback.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Feedback:")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(interfaceSettings.enhancedInterfaceFeedback)
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                }
            }
        }
    }
    
    @ViewBuilder
    private func feedbackButton(emoji: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(emoji)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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