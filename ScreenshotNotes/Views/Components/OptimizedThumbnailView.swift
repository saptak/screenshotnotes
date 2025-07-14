import SwiftUI
import UIKit

struct OptimizedThumbnailView: View {
    let screenshot: Screenshot
    let size: CGSize
    let responsiveLayout: GlassDesignSystem.ResponsiveLayout?
    let onTap: () -> Void
    
    @StateObject private var thumbnailService = ThumbnailService.shared
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = false // Start as false, only set true when actually loading
    @State private var loadingTask: Task<Void, Never>?
    @GestureState private var longPressLocation: CGPoint = .zero
    @State private var lastGlobalFrame: CGRect = .zero
    @State private var selectedScreenshot: Screenshot? = nil // Store screenshot for menu
    
    private var cornerRadius: CGFloat {
        responsiveLayout?.materials.cornerRadius ?? 14
    }
    
    init(screenshot: Screenshot, size: CGSize = ThumbnailService.listThumbnailSize, responsiveLayout: GlassDesignSystem.ResponsiveLayout? = nil, onTap: @escaping () -> Void) {
        self.screenshot = screenshot
        self.size = size
        self.responsiveLayout = responsiveLayout
        self.onTap = onTap
    }
    
    var body: some View {
        let layout = responsiveLayout ?? GlassDesignSystem.ResponsiveLayout(
            horizontalSizeClass: nil,
            verticalSizeClass: nil,
            screenWidth: 430,
            screenHeight: 932
        )
        
        VStack(alignment: .leading, spacing: layout.spacing.xs) {
            thumbnailContent
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .responsiveGlassBackground(
                    layout: layout,
                    materialType: .primary,
                    shadow: true
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    print("Tap gesture on thumbnail: \(screenshot.id)")
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onTap()
                }
                .onLongPressGesture(minimumDuration: 0.6) {
                    print("Long press completed on screenshot: \(screenshot.id)")
                    selectedScreenshot = screenshot
                    // Use a simple position relative to the screen center
                    let menuPosition = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
                    print("Showing menu at center position: \(menuPosition)")
                    ContextualMenuService.shared.showMenu(
                        configuration: .minimal,
                        at: menuPosition,
                        for: screenshot
                    )
                } onPressingChanged: { pressing in
                    if pressing {
                        print("Long press started on screenshot: \(screenshot.id)")
                    } else {
                        print("Long press cancelled on screenshot: \(screenshot.id)")
                    }
                }
                .background(
                    Rectangle()
                        .fill(Color.clear)
                        .onAppear {
                            print("Thumbnail appeared for screenshot: \(screenshot.id)")
                        }
                )
            
            // Cleaner timestamp with better typography
            if hasExtractedText {
                Text(formatDateForDisplay())
                    .font(layout.typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                HStack(spacing: layout.spacing.xs) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                        .foregroundColor(.orange.opacity(0.7))
                    
                    Text(formatDateForDisplay())
                        .font(layout.typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: size.width)
        .onAppear {
            // Check cache first to avoid unnecessary loading states
            if thumbnailImage == nil {
                checkCacheAndLoad()
            }
        }
        .onDisappear {
            // Cancel any ongoing loading task when view disappears
            loadingTask?.cancel()
            loadingTask = nil
        }
    }
    
    @ViewBuilder
    private var thumbnailContent: some View {
        ZStack {
            if let thumbnailImage = thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                
                // Subtle overlay for better text visibility on images
                if !hasExtractedText {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(.black.opacity(0.6))
                                        .background(.ultraThinMaterial, in: Circle())
                                )
                        }
                        .padding(6)
                    }
                }
            } else if isLoading {
                loadingPlaceholder
            } else {
                errorPlaceholder
            }
        }
    }
    
    private var loadingPlaceholder: some View {
        let layout = responsiveLayout ?? GlassDesignSystem.ResponsiveLayout(
            horizontalSizeClass: nil,
            verticalSizeClass: nil,
            screenWidth: 430,
            screenHeight: 932
        )
        
        return ZStack {
            // Glass-style loading background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
            
            VStack(spacing: layout.spacing.xs) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                    .scaleEffect(0.7)
                
                Text("Loading...")
                    .font(layout.typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
    
    private var errorPlaceholder: some View {
        let layout = responsiveLayout ?? GlassDesignSystem.ResponsiveLayout(
            horizontalSizeClass: nil,
            verticalSizeClass: nil,
            screenWidth: 430,
            screenHeight: 932
        )
        
        return ZStack {
            // Glass-style error background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
            
            VStack(spacing: layout.spacing.xs) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title3)
                    .foregroundColor(.orange.opacity(0.7))
                
                Text("Unable to load")
                    .font(layout.typography.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func checkCacheAndLoad() {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Check cache first to avoid unnecessary loading states
        if let cachedThumbnail = thumbnailService.getCachedThumbnail(for: screenshot.id, size: size) {
            print("✅ Cache hit for thumbnail: \(screenshot.id)")
            thumbnailImage = cachedThumbnail
            isLoading = false
            return
        }
        
        print("🔍 Cache miss for thumbnail: \(screenshot.id), starting generation")
        // Only show loading if we need to actually load
        isLoading = true
        
        loadingTask = Task.detached(priority: .userInitiated) { [screenshotId = screenshot.id, imageData = screenshot.imageData] in
            let thumbnail = await thumbnailService.getThumbnail(
                for: screenshotId,
                from: imageData,
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
    
    // Helper to check if screenshot has extracted text
    private var hasExtractedText: Bool {
        screenshot.extractedText?.isEmpty == false
    }
    
    // Format date for cleaner display
    private func formatDateForDisplay() -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(screenshot.timestamp, inSameDayAs: now) {
            return screenshot.timestamp.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDate(screenshot.timestamp, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(screenshot.timestamp) == true {
            return screenshot.timestamp.formatted(.dateTime.weekday(.wide))
        } else {
            return screenshot.timestamp.formatted(date: .abbreviated, time: .omitted)
        }
    }
}