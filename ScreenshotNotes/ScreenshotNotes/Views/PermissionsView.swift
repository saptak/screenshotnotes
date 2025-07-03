import SwiftUI
import Photos

struct PermissionsView: View {
    @ObservedObject private var photoLibraryService: PhotoLibraryService
    @Environment(\.dismiss) private var dismiss
    @State private var isRequestingPermission = false
    
    init(photoLibraryService: PhotoLibraryService) {
        self.photoLibraryService = photoLibraryService
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundColor(.blue)
                        .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                    
                    VStack(spacing: 8) {
                        Text("Photo Library Access")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("To automatically import screenshots, Screenshot Notes needs access to your photo library.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Permission status
                VStack(spacing: 16) {
                    statusView
                    
                    if photoLibraryService.authorizationStatus == .notDetermined {
                        Button(action: {
                            requestPermission()
                        }) {
                            HStack {
                                if isRequestingPermission {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                }
                                Text("Grant Access")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.blue)
                            )
                        }
                        .disabled(isRequestingPermission)
                        .buttonStyle(.plain)
                    } else if photoLibraryService.authorizationStatus == .denied || photoLibraryService.authorizationStatus == .restricted {
                        Button(action: {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                    .fontWeight(.semibold)
                                Text("Open Settings")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.orange)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button("Continue Without Access") {
                        dismiss()
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Permissions")
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
    
    @ViewBuilder
    private var statusView: some View {
        HStack(spacing: 12) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundColor(statusColor)
                
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
    
    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.title2)
            .foregroundColor(statusColor)
    }
    
    private var statusIconName: String {
        switch photoLibraryService.authorizationStatus {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .limited:
            return "exclamationmark.triangle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch photoLibraryService.authorizationStatus {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .limited:
            return .orange
        case .notDetermined:
            return .blue
        @unknown default:
            return .gray
        }
    }
    
    private var statusTitle: String {
        switch photoLibraryService.authorizationStatus {
        case .authorized:
            return "Access Granted"
        case .denied:
            return "Access Denied"
        case .restricted:
            return "Access Restricted"
        case .limited:
            return "Limited Access"
        case .notDetermined:
            return "Permission Required"
        @unknown default:
            return "Unknown Status"
        }
    }
    
    private var statusMessage: String {
        switch photoLibraryService.authorizationStatus {
        case .authorized:
            return "Screenshot Notes can automatically import your screenshots"
        case .denied:
            return "You've denied photo library access. You can change this in Settings."
        case .restricted:
            return "Photo library access is restricted by device policies"
        case .limited:
            return "Screenshot Notes has limited photo library access"
        case .notDetermined:
            return "Tap 'Grant Access' to enable automatic screenshot import"
        @unknown default:
            return "Unknown permission status"
        }
    }
    
    private func requestPermission() {
        isRequestingPermission = true
        Task { @MainActor in
            _ = await photoLibraryService.requestPhotoLibraryPermission()
            isRequestingPermission = false
        }
    }
}