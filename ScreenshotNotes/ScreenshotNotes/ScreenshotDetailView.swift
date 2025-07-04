import SwiftUI

struct ScreenshotDetailView: View {
    let screenshot: Screenshot
    let heroNamespace: Namespace.ID
    let allScreenshots: [Screenshot]
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var showingControls = true
    @State private var controlsTimer: Timer?
    @State private var currentScreenshot: Screenshot
    @State private var showingActionSheet = false
    
    // Navigation support
    
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 4.0
    
    // Swipe thresholds
    private let swipeThreshold: CGFloat = 50
    
    private var currentIndex: Int {
        allScreenshots.firstIndex(where: { $0.id == currentScreenshot.id }) ?? 0
    }
    
    private var canNavigatePrevious: Bool {
        currentIndex > 0
    }
    
    private var canNavigateNext: Bool {
        currentIndex < allScreenshots.count - 1
    }
    
    init(screenshot: Screenshot, heroNamespace: Namespace.ID, allScreenshots: [Screenshot]) {
        self.screenshot = screenshot
        self.heroNamespace = heroNamespace
        self.allScreenshots = allScreenshots
        self._currentScreenshot = State(initialValue: screenshot)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                if let image = UIImage(data: currentScreenshot.imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(allGestures)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if scale > 1.0 {
                                    resetZoom()
                                } else {
                                    scale = 2.0
                                    offset = .zero
                                }
                            }
                            addHapticFeedback(.light)
                        }
                        .onTapGesture {
                            toggleControlsVisibility()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Unable to load image")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Navigation bar overlay
            VStack {
                if showingControls {
                    HStack {
                        Button(action: {
                            dismiss()
                            addHapticFeedback(.light)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .overlayMaterial(cornerRadius: 20)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text(currentScreenshot.filename)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlayMaterial(cornerRadius: 8)
                        
                        Spacer()
                        
                        Menu {
                            Button("Share", systemImage: "square.and.arrow.up") {
                                shareImage()
                            }
                            
                            Button("Copy", systemImage: "doc.on.doc") {
                                copyImage()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .overlayMaterial(cornerRadius: 20)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Spacer()
                
                // Bottom info overlay
                if showingControls {
                    VStack(spacing: 8) {
                        HStack {
                            if canNavigatePrevious {
                                Button("◀") {
                                    navigateToPrevious()
                                }
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                            }
                            
                            VStack(spacing: 4) {
                                Text(currentScreenshot.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("\(currentIndex + 1) of \(allScreenshots.count)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            if canNavigateNext {
                                Button("▶") {
                                    navigateToNext()
                                }
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                            }
                        }
                        
                        if scale != 1.0 {
                            HStack {
                                Button("Reset Zoom") {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        resetZoom()
                                    }
                                    addHapticFeedback(.light)
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .overlayMaterial(cornerRadius: 6)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Text("\(Int(scale * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .onAppear {
            scheduleControlsTimer()
        }
        .onDisappear {
            controlsTimer?.invalidate()
        }
        .confirmationDialog("Choose Action", isPresented: $showingActionSheet, titleVisibility: .visible) {
            Button("Share") {
                shareCurrentImage()
            }
            
            Button("Delete", role: .destructive) {
                deleteCurrentImage()
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("What would you like to do with this screenshot?")
        }
    }
    
    private var allGestures: some Gesture {
        SimultaneousGesture(
            magnificationGesture,
            combinedDragGesture
        )
    }
    
    private var combinedDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    // When zoomed in, use pan gesture
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                scheduleControlsTimer()
            }
            .onEnded { value in
                if scale > 1.0 {
                    // When zoomed in, handle pan end
                    lastOffset = offset
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        constrainOffset()
                    }
                    addHapticFeedback(.light)
                } else {
                    // When not zoomed, handle swipe gestures
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    // Determine primary direction
                    if abs(horizontalAmount) > abs(verticalAmount) {
                        // Horizontal swipe
                        if abs(horizontalAmount) > swipeThreshold {
                            if horizontalAmount > 0 && canNavigatePrevious {
                                // Swipe right - go to previous
                                navigateToPrevious()
                            } else if horizontalAmount < 0 && canNavigateNext {
                                // Swipe left - go to next
                                navigateToNext()
                            }
                        }
                    } else {
                        // Vertical swipe
                        if abs(verticalAmount) > swipeThreshold {
                            if verticalAmount > 0 {
                                // Swipe down - dismiss
                                dismiss()
                                addHapticFeedback(.medium)
                            } else {
                                // Swipe up - show actions
                                showingActionSheet = true
                                addHapticFeedback(.light)
                            }
                        }
                    }
                }
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = max(minScale, min(maxScale, newScale))
                scheduleControlsTimer()
            }
            .onEnded { value in
                lastScale = scale
                
                // Snap to 1.0 if close
                if abs(scale - 1.0) < 0.1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scale = 1.0
                        offset = .zero
                    }
                    lastScale = 1.0
                    lastOffset = .zero
                }
                
                addHapticFeedback(.light)
            }
    }
    
    
    private func resetZoom() {
        scale = 1.0
        offset = .zero
        lastScale = 1.0
        lastOffset = .zero
    }
    
    private func constrainOffset() {
        // Simple constraint - reset to center if too far
        let maxOffset: CGFloat = 100
        if abs(offset.width) > maxOffset || abs(offset.height) > maxOffset {
            offset = .zero
            lastOffset = .zero
        }
    }
    
    private func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingControls.toggle()
        }
        
        if showingControls {
            scheduleControlsTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }
    
    private func scheduleControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingControls = false
            }
        }
    }
    
    private func navigateToPrevious() {
        guard canNavigatePrevious else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreenshot = allScreenshots[currentIndex - 1]
            resetZoom()
        }
        addHapticFeedback(.light)
    }
    
    private func navigateToNext() {
        guard canNavigateNext else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreenshot = allScreenshots[currentIndex + 1]
            resetZoom()
        }
        addHapticFeedback(.light)
    }
    
    private func shareImage() {
        guard let image = UIImage(data: currentScreenshot.imageData) else { return }
        
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
        
        addHapticFeedback(.medium)
    }
    
    private func copyImage() {
        guard let image = UIImage(data: currentScreenshot.imageData) else { return }
        UIPasteboard.general.image = image
        addHapticFeedback(.light)
    }
    
    private func shareCurrentImage() {
        shareImage()
    }
    
    private func deleteCurrentImage() {
        // TODO: Implement deletion through proper data model
        // For now, just dismiss with haptic feedback
        addHapticFeedback(.heavy)
        dismiss()
    }
    
    private func addHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
    }
}

#Preview {
    struct PreviewWrapper: View {
        @Namespace private var heroNamespace
        
        var body: some View {
            ScreenshotDetailView(
                screenshot: Screenshot(imageData: Data(), filename: "test_image.jpg"),
                heroNamespace: heroNamespace,
                allScreenshots: [
                    Screenshot(imageData: Data(), filename: "test_image_1.jpg"),
                    Screenshot(imageData: Data(), filename: "test_image_2.jpg"),
                    Screenshot(imageData: Data(), filename: "test_image_3.jpg")
                ]
            )
        }
    }
    
    return PreviewWrapper()
}
