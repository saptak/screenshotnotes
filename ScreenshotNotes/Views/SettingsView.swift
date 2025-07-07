import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsService = SettingsService.shared
    @ObservedObject private var photoLibraryService: PhotoLibraryService
    @StateObject private var performanceMonitor = GalleryPerformanceMonitor.shared
    @StateObject private var thumbnailService = ThumbnailService.shared
    @Environment(\.dismiss) private var dismiss
    
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
                                Text("\(stats.diskCount) cached")
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
                    Text("Monitor gallery performance and clear cache to free up memory. Performance monitoring is active when viewing the gallery.")
                }
                
                Section {
                    Button("Reset to Defaults") {
                        settingsService.resetToDefaults()
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