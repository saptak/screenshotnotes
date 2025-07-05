import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsService = SettingsService.shared
    @ObservedObject private var photoLibraryService: PhotoLibraryService
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
}