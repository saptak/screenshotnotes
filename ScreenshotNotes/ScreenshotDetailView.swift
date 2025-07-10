import SwiftUI

struct ScreenshotDetailView: View {
    let screenshot: Screenshot
    let heroNamespace: Namespace.ID
    let allScreenshots: [Screenshot]
    let onDelete: ((Screenshot) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var showingControls = true
    @State private var showingAttributesPanel = false
    @State private var showingExtractedText = true
    @StateObject private var glassSystem = GlassDesignSystem.shared
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

    init(screenshot: Screenshot, heroNamespace: Namespace.ID, allScreenshots: [Screenshot], onDelete: ((Screenshot) -> Void)? = nil) {
        self.screenshot = screenshot
        self.heroNamespace = heroNamespace
        self.allScreenshots = allScreenshots
        self.onDelete = onDelete
        self._currentScreenshot = State(initialValue: screenshot)
    }

    var body: some View {
        return ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
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
                                        scale = 2.0
                                        offset = .zero
                                    }
                                }
                                addHapticFeedback(.light)
                            }
                            .onTapGesture {
                                // Single tap no longer toggles controls (they're persistent)
                                // Could add other single tap actions here if needed
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
                // --- Extracted Text Display ---
                if let extractedText = currentScreenshot.extractedText, !extractedText.isEmpty {
                    VStack(spacing: 0) {
                        // Toggle button for text panel
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingExtractedText.toggle()
                                }
                                addHapticFeedback(.light)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "text.quote")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    
                                    Text(showingExtractedText ? "Hide Text" : "Show Text")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    
                                    Image(systemName: showingExtractedText ? "chevron.down" : "chevron.up")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 1)
                                )
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, showingExtractedText ? 8 : 16)
                        }
                        
                        // Extracted text content
                        if showingExtractedText {
                            ExtractedTextView(
                                text: extractedText,
                                mode: .standard,
                                theme: .glass,
                                editable: true,
                                onTextChanged: { newText in
                                    // Update the screenshot's extracted text
                                    currentScreenshot.extractedText = newText
                                },
                                onCopy: { copiedText in
                                    addHapticFeedback(.light)
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            // Glass navigation bar overlay - always visible
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                        addHapticFeedback(.light)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                            )
                    }
                    
                    Spacer()
                    
                    Text(currentScreenshot.filename)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                        )
                    
                    Spacer()
                    
                    Button(action: {
                        showingAttributesPanel = true
                        addHapticFeedback(.light)
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                            )
                    }
                    
                    Menu {
                        Button("Share", systemImage: "square.and.arrow.up") {
                            shareImage()
                        }
                        Button("Copy Image", systemImage: "doc.on.doc") {
                            copyImage()
                        }
                        if let extractedText = currentScreenshot.extractedText, !extractedText.isEmpty {
                            Button("Copy Text", systemImage: "text.quote") {
                                copyExtractedText()
                            }
                            Button(showingExtractedText ? "Hide Text Panel" : "Show Text Panel", systemImage: showingExtractedText ? "eye.slash" : "eye") {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingExtractedText.toggle()
                                }
                                addHapticFeedback(.light)
                            }
                        }
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            showingActionSheet = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60) // Account for safe area
                Spacer()
                
                // Bottom Glass control panel - always visible
                VStack(spacing: 12) {
                    // Navigation controls
                    HStack(spacing: 20) {
                        Button(action: {
                            if canNavigatePrevious {
                                navigateToPrevious()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(canNavigatePrevious ? .white : .white.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                                )
                        }
                        .disabled(!canNavigatePrevious)
                        
                        VStack(spacing: 4) {
                            Text(currentScreenshot.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Text("\(currentIndex + 1) of \(allScreenshots.count)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                        )
                        
                        Button(action: {
                            if canNavigateNext {
                                navigateToNext()
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(canNavigateNext ? .white : .white.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                                )
                        }
                        .disabled(!canNavigateNext)
                    }
                    
                    // Zoom controls (only when zoomed)
                    if scale != 1.0 {
                        HStack(spacing: 16) {
                            Button("Reset Zoom") {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    resetZoom()
                                }
                                addHapticFeedback(.light)
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                            )
                            
                            Text("\(Int(scale * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial.opacity(0.6))
                                )
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40) // Account for safe area
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .onAppear {
            // Controls are now persistent - no timer needed
            // Smart initialization: hide text panel if it's very long
            if let extractedText = currentScreenshot.extractedText, extractedText.count > 300 {
                showingExtractedText = false
            }
        }
        .sheet(isPresented: $showingAttributesPanel) {
            ScreenshotAttributesPanel(screenshot: currentScreenshot)
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

    var allGestures: some Gesture {
        SimultaneousGesture(
            magnificationGesture,
            combinedDragGesture
        )
    }
    
    var combinedDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    // When zoomed in, use pan gesture
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
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
    
    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = max(minScale, min(maxScale, newScale))
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
    
    
    func resetZoom() {
        scale = 1.0
        offset = .zero
        lastScale = 1.0
        lastOffset = .zero
    }
    
    func constrainOffset() {
        // Simple constraint - reset to center if too far
        let maxOffset: CGFloat = 100
        if abs(offset.width) > maxOffset || abs(offset.height) > maxOffset {
            offset = .zero
            lastOffset = .zero
        }
    }
    
    func copyExtractedText() {
        guard let extractedText = currentScreenshot.extractedText else {
            addHapticFeedback(.error)
            return
        }
        UIPasteboard.general.string = extractedText
        addHapticFeedback(.success)
    }
    
    func navigateToPrevious() {
        guard canNavigatePrevious else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreenshot = allScreenshots[currentIndex - 1]
            resetZoom()
        }
        addHapticFeedback(.light)
    }
    
    func navigateToNext() {
        guard canNavigateNext else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreenshot = allScreenshots[currentIndex + 1]
            resetZoom()
        }
        addHapticFeedback(.light)
    }
    
    func shareImage() {
        guard let image = UIImage(data: currentScreenshot.imageData) else { 
            addHapticFeedback(.error)
            return 
        }
        
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        // Configure for iPad
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            popoverController.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        // Find the topmost view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = window.rootViewController {
            
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            topController.present(activityVC, animated: true) {
                self.addHapticFeedback(.medium)
            }
        } else {
            addHapticFeedback(.error)
        }
    }
    
    func copyImage() {
        guard let image = UIImage(data: currentScreenshot.imageData) else { 
            addHapticFeedback(.error)
            return 
        }
        UIPasteboard.general.image = image
        addHapticFeedback(.success)
    }
    
    func shareCurrentImage() {
        shareImage()
    }
    
    func deleteCurrentImage() {
        addHapticFeedback(.heavy)
        
        // Call the deletion callback if provided
        if let onDelete = onDelete {
            onDelete(currentScreenshot)
        }
        
        // Always dismiss after deletion
        dismiss()
    }
    
    func addHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
    }
    
    func addHapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(type)
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
