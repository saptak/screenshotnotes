import SwiftUI
import UIKit

struct OptimizedThumbnailView: View {
    let screenshot: Screenshot
    let size: CGSize
    let onTap: () -> Void
    
    @StateObject private var thumbnailService = ThumbnailService.shared
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    private let cornerRadius: CGFloat = 14
    
    init(screenshot: Screenshot, size: CGSize = ThumbnailService.listThumbnailSize, onTap: @escaping () -> Void) {
        self.screenshot = screenshot
        self.size = size
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnailContent
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                )
            
            // Timestamp
            Text(screenshot.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task {
            await loadThumbnail()
        }
        .onAppear {
            // Preload if not already loaded
            if thumbnailImage == nil && !isLoading {
                Task {
                    await loadThumbnail()
                }
            }
        }
    }
    
    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbnailImage = thumbnailImage {
            Image(uiImage: thumbnailImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        } else if isLoading {
            loadingPlaceholder
        } else {
            errorPlaceholder
        }
    }
    
    private var loadingPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.1)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                .scaleEffect(0.8)
        }
    }
    
    private var errorPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.15)
            
            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Unable to load")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func loadThumbnail() async {
        isLoading = true
        
        let thumbnail = await thumbnailService.getThumbnail(
            for: screenshot.id,
            from: screenshot.imageData,
            size: size
        )
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.thumbnailImage = thumbnail
                self.isLoading = false
            }
        }
    }
}

#Preview {
    OptimizedThumbnailView(
        screenshot: Screenshot(
            imageData: Data(),
            filename: "test_screenshot",
            timestamp: Date()
        ),
        onTap: {}
    )
    .padding()
}