import SwiftUI
import NaturalLanguage

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
    @State private var showingUnifiedPanel = true
    @State private var isTextPanelExpanded = false
    @StateObject private var glassSystem = GlassDesignSystem.shared
    @State private var currentScreenshot: Screenshot
    @State private var showingActionSheet = false
    
    // Iteration 8.7.1.1: One-Tap Text Actions
    @StateObject private var textActionService = SmartTextActionService.shared
    @State private var detectedTextActions: [SmartTextActionService.TextAction] = []
    @State private var showingTextActions = false

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
                // --- Unified Details Panel ---
                if showingUnifiedPanel {
                    UnifiedDetailsPanel(
                        screenshot: currentScreenshot,
                        onTextChanged: { newText in
                            currentScreenshot.extractedText = newText
                        },
                        onCopy: { _ in
                            addHapticFeedback(.light)
                        },
                        showingUnifiedPanel: $showingUnifiedPanel,
                        isTextPanelExpanded: $isTextPanelExpanded,
                        onTriggerTextActions: {
                            detectAndShowTextActions()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // Glass navigation bar overlay - always visible
            VStack {
                HStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingUnifiedPanel.toggle()
                            }
                            addHapticFeedback(.light)
                        }) {
                            Image(systemName: showingUnifiedPanel ? "info.circle.fill" : "info.circle")
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
                                Button("Text Actions", systemImage: "wand.and.rays") {
                                    detectAndShowTextActions()
                                }
                            }
                            Button(showingUnifiedPanel ? "Hide Details Panel" : "Show Details Panel", systemImage: showingUnifiedPanel ? "eye.slash" : "eye") {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingUnifiedPanel.toggle()
                                }
                                addHapticFeedback(.light)
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
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 10) // Moved as high as possible
                Spacer()
                
                // Bottom Glass control panel - always visible
                VStack(spacing: 12) {
                    
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
            // Smart initialization: hide unified panel if text is very long
            if let extractedText = currentScreenshot.extractedText, extractedText.count > 300 {
                showingUnifiedPanel = false
            }
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
        .overlay(alignment: .bottom) {
            // --- Bottom Handle for Text Panel (when collapsed) ---
            if !showingUnifiedPanel {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingUnifiedPanel = true
                    }
                    addHapticFeedback(.light)
                }) {
                    VStack(spacing: 4) {
                        // Handle indicator
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(.white.opacity(0.6))
                            .frame(width: 36, height: 5)
                        
                        // Text label
                        if let extractedText = currentScreenshot.extractedText, !extractedText.isEmpty {
                            Text("Extracted Text")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text("No Text Available")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40) // Safe area padding
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $isTextPanelExpanded) {
            FullScreenTextView(
                screenshot: currentScreenshot,
                onTextChanged: { newText in
                    currentScreenshot.extractedText = newText
                },
                onDismiss: {
                    isTextPanelExpanded = false
                }
            )
        }
        .textActionOverlay(
            actions: detectedTextActions,
            onActionTapped: { action in
                executeTextAction(action)
            },
            onDismiss: {
                showingTextActions = false
                detectedTextActions = []
                
                // Clean up text action service resources
                textActionService.cleanup()
                
                // Trigger memory cleanup
                Task {
                    await TextActionMemoryMonitor.shared.performMemoryCleanup()
                }
            }
        )
        .responsiveLayout()
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
    
    // MARK: - Iteration 8.7.1.1: One-Tap Text Actions
    
    private func detectAndShowTextActions() {
        guard let extractedText = currentScreenshot.extractedText, !extractedText.isEmpty else {
            addHapticFeedback(.error)
            return
        }
        
        addHapticFeedback(.light)
        
        Task {
            // Use memory-safe detection
            let actions = await textActionService.detectActionsSafely(in: extractedText)
            
            await MainActor.run {
                if !actions.isEmpty {
                    detectedTextActions = actions
                    withAnimation(GlassDesignSystem.glassSpring(.responsive)) {
                        showingTextActions = true
                    }
                } else {
                    addHapticFeedback(.warning)
                }
            }
        }
    }
    
    private func executeTextAction(_ action: SmartTextActionService.TextAction) {
        Task {
            let success = await textActionService.executeAction(action)
            
            await MainActor.run {
                if success {
                    addHapticFeedback(.success)
                    
                    // Auto-dismiss for most actions except copy
                    if action.type != .copy {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(GlassDesignSystem.glassSpring(.gentle)) {
                                showingTextActions = false
                                detectedTextActions = []
                            }
                        }
                    }
                } else {
                    addHapticFeedback(.error)
                }
            }
        }
    }
}

// MARK: - Collapsible Section Components

struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    let defaultExpanded: Bool
    let content: () -> Content
    
    @State private var isExpanded: Bool
    @StateObject private var glassSystem = GlassDesignSystem.shared
    private let hapticService = HapticService.shared
    
    init(
        title: String,
        icon: String,
        defaultExpanded: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.defaultExpanded = defaultExpanded
        self.content = content
        
        // Restore saved state or use default
        let savedKey = "section_\(title.lowercased().replacingOccurrences(of: " ", with: "_"))_expanded"
        let savedState = UserDefaults.standard.object(forKey: savedKey) as? Bool ?? defaultExpanded
        self._isExpanded = State(initialValue: savedState)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Button(action: toggleExpansion) {
                HStack(spacing: 12) {
                    // Section Icon
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(.blue)
                        .frame(width: 20, height: 20)
                    
                    // Section Title
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Expand/Collapse Indicator
                    Image(systemName: "chevron.down")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.regularMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            
            // Section Content
            if isExpanded {
                content()
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
    
    private func toggleExpansion() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
        hapticService.impact(.light)
        
        // Save expanded state preference
        UserDefaults.standard.set(isExpanded, forKey: "section_\(title.lowercased().replacingOccurrences(of: " ", with: "_"))_expanded")
    }
}

// MARK: - Enhanced Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    let isExpanded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Unified Details Panel

struct UnifiedDetailsPanel: View {
    let screenshot: Screenshot
    let onTextChanged: (String) -> Void
    let onCopy: (String) -> Void
    @Binding var showingUnifiedPanel: Bool
    @Binding var isTextPanelExpanded: Bool
    @StateObject private var glassSystem = GlassDesignSystem.shared
    private let hapticService = HapticService.shared
    
    // Iteration 8.7.1.1: One-Tap Text Actions callback
    let onTriggerTextActions: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pull-down indicator and panel controls
            panelHeader
            
            // Collapsible Sections
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Key Content Section (Extracted Text)
                    if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
                        CollapsibleSection(
                            title: "Key Content",
                            icon: "text.quote",
                            defaultExpanded: true
                        ) {
                            keyContentSection(extractedText)
                        }
                    }
                    
                    // AI Analysis Section (Semantic Tags)
                    if let semanticTags = screenshot.semanticTags, !semanticTags.tags.isEmpty {
                        CollapsibleSection(
                            title: "AI Analysis",
                            icon: "brain.head.profile",
                            defaultExpanded: false
                        ) {
                            aiAnalysisSection(semanticTags.tags)
                        }
                    }
                    
                    // Vision Detection Section (Object Tags)
                    if let objectTags = screenshot.objectTags, !objectTags.isEmpty {
                        CollapsibleSection(
                            title: "Vision Detection",
                            icon: "camera.viewfinder",
                            defaultExpanded: false
                        ) {
                            visionDetectionSection(objectTags)
                        }
                    }
                    
                    // Metadata Section
                    CollapsibleSection(
                        title: "Metadata",
                        icon: "info.circle",
                        defaultExpanded: false
                    ) {
                        metadataSection
                    }
                    
                    // Quick Actions Section (always visible)
                    quickActionsSection
                }
                .padding(16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Panel Header
    
    @ViewBuilder
    private var panelHeader: some View {
        VStack(spacing: 8) {
            // Pull-down indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            // Header with collapse all control
            HStack {
                Text("Screenshot Details")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = getAllDataAsText()
                    hapticService.impact(.light)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy All")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(.regularMaterial)
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Pull down to close
                    if value.translation.height > 50 && value.velocity.height > 0 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showingUnifiedPanel = false
                        }
                        hapticService.impact(.medium)
                    }
                    // Pull up to expand to full screen
                    else if value.translation.height < -50 && value.velocity.height < 0 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isTextPanelExpanded = true
                        }
                        hapticService.impact(.medium)
                    }
                }
        )
    }
    
    // MARK: - Section Views
    
    @ViewBuilder
    private func keyContentSection(_ text: String) -> some View {
        let contentItems = extractContentItems(from: text)
        let hasContent = !contentItems.isEmpty
        
        VStack(alignment: .leading, spacing: 12) {
            // Action buttons for extracted text
            HStack(spacing: 8) {
                Button(action: {
                    UIPasteboard.general.string = text
                    hapticService.impact(.light)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Text")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    onTriggerTextActions?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.rays")
                        Text("Smart Actions")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            // Content items
            if hasContent {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], alignment: .leading, spacing: 8) {
                    ForEach(contentItems, id: \.text) { item in
                        ContentItemView(
                            item: item,
                            onCopy: {
                                UIPasteboard.general.string = item.text
                                hapticService.impact(.light)
                            }
                        )
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No key content detected")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    
    @ViewBuilder
    private func visionDetectionSection(_ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.green.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                }
            }
            
            HStack {
                Spacer()
                Button(action: {
                    let tagsText = tags.joined(separator: ", ")
                    UIPasteboard.general.string = tagsText
                    hapticService.impact(.light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Tags")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    @ViewBuilder
    private func aiAnalysisSection(_ tags: [SemanticTag]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(tags, id: \.id) { tag in
                    VStack(spacing: 2) {
                        Text(tag.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                        
                        Text("\(Int(tag.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.purple.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                }
            }
            
            HStack {
                Spacer()
                Button(action: {
                    let tagsText = tags.map { $0.displayName }.joined(separator: ", ")
                    UIPasteboard.general.string = tagsText
                    hapticService.impact(.light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Tags")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    
    
    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow(label: "Date", value: formatTimestamp(), copyable: true)
            infoRow(label: "File Size", value: formatFileSize(), copyable: false)
            if let dimensions = getImageDimensions() {
                infoRow(label: "Dimensions", value: dimensions, copyable: false)
            }
            infoRow(label: "Processing", value: getProcessingStatus(), copyable: false)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt")
                    .font(.body)
                    .foregroundColor(.orange)
                
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                actionButton(title: "Copy All Data", icon: "doc.on.doc.fill", color: .blue) {
                    copyAllData()
                }
                
                actionButton(title: "Export JSON", icon: "curlybraces", color: .purple) {
                    exportAsJSON()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func infoRow(label: String, value: String, copyable: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(minWidth: 60, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if copyable {
                Button(action: {
                    UIPasteboard.general.string = value
                    hapticService.impact(.light)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private func actionButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.thinMaterial)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Methods
    
    private func formatTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: screenshot.timestamp)
    }
    
    private func formatFileSize() -> String {
        let size = screenshot.imageData.count
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    private func getImageDimensions() -> String? {
        guard let uiImage = UIImage(data: screenshot.imageData) else { return nil }
        let size = uiImage.size
        return "\(Int(size.width)) × \(Int(size.height))"
    }
    
    private func getProcessingStatus() -> String {
        var status: [String] = []
        
        if screenshot.extractedText?.isEmpty == false {
            status.append("OCR")
        }
        
        if !(screenshot.objectTags?.isEmpty ?? true) {
            status.append("Vision")
        }
        
        if let semanticTags = screenshot.semanticTags, !semanticTags.tags.isEmpty {
            status.append("AI Tags")
        }
        
        if !screenshot.dominantColors.isEmpty {
            status.append("Colors")
        }
        
        return status.isEmpty ? "Basic" : status.joined(separator: ", ")
    }
    
    private func copyAllData() {
        var data: [String] = []
        
        data.append("Filename: \(screenshot.filename)")
        data.append("Date: \(formatTimestamp())")
        
        if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
            data.append("Text: \(extractedText)")
        }
        
        if let objectTags = screenshot.objectTags, !objectTags.isEmpty {
            data.append("Objects: \(objectTags.joined(separator: ", "))")
        }
        
        if let semanticTags = screenshot.semanticTags, !semanticTags.tags.isEmpty {
            let tags = semanticTags.tags.map { $0.displayName }.joined(separator: ", ")
            data.append("Semantic Tags: \(tags)")
        }
        
        if !screenshot.dominantColors.isEmpty {
            let colors = screenshot.dominantColors.map { "\($0.colorName) (\(Int($0.prominence * 100))%)" }.joined(separator: ", ")
            data.append("Colors: \(colors)")
        }
        
        UIPasteboard.general.string = data.joined(separator: "\n")
        hapticService.impact(.medium)
    }
    
    private func getAllDataAsText() -> String {
        var data: [String] = []
        
        data.append("Filename: \(screenshot.filename)")
        data.append("Date: \(formatTimestamp())")
        
        if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
            data.append("Text: \(extractedText)")
        }
        
        if let objectTags = screenshot.objectTags, !objectTags.isEmpty {
            data.append("Objects: \(objectTags.joined(separator: ", "))")
        }
        
        if let semanticTags = screenshot.semanticTags, !semanticTags.tags.isEmpty {
            let tags = semanticTags.tags.map { $0.displayName }.joined(separator: ", ")
            data.append("Semantic Tags: \(tags)")
        }
        
        if !screenshot.dominantColors.isEmpty {
            let colors = screenshot.dominantColors.map { "\($0.colorName) (\(Int($0.prominence * 100))%)" }.joined(separator: ", ")
            data.append("Colors: \(colors)")
        }
        
        return data.joined(separator: "\n")
    }
    
    private func exportAsJSON() {
        let jsonData: [String: Any] = [
            "id": screenshot.id.uuidString,
            "filename": screenshot.filename,
            "timestamp": screenshot.timestamp.ISO8601Format(),
            "extractedText": screenshot.extractedText ?? "",
            "objectTags": screenshot.objectTags ?? [],
            "semanticTags": screenshot.semanticTags?.tags.map { ["name": $0.displayName, "confidence": $0.confidence] } ?? [],
            "dominantColors": screenshot.dominantColors.map { ["name": $0.colorName, "prominence": $0.prominence, "rgb": [$0.red, $0.green, $0.blue]] }
        ]
        
        do {
            let jsonString = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
            if let string = String(data: jsonString, encoding: .utf8) {
                UIPasteboard.general.string = string
                hapticService.impact(.medium)
            }
        } catch {
            hapticService.notification(.error)
        }
    }
    
    // MARK: - Natural Language Processing
    
    // Content item types for highlighting
    enum ContentType: String, CaseIterable {
        case url = "URL"
        case email = "Email"
        case phone = "Phone"
        case price = "Price"
        case code = "Code"
        case date = "Date"
        case address = "Address"
        case number = "Number"
        case regular = "Text"
        
        var color: Color {
            switch self {
            case .url: return .blue
            case .email: return .green
            case .phone: return .orange
            case .price: return .purple
            case .code: return .red
            case .date: return .indigo
            case .address: return .brown
            case .number: return .cyan
            case .regular: return .primary
            }
        }
        
        var icon: String {
            switch self {
            case .url: return "link"
            case .email: return "envelope"
            case .phone: return "phone"
            case .price: return "dollarsign"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .date: return "calendar"
            case .address: return "location"
            case .number: return "number"
            case .regular: return "text.quote"
            }
        }
    }
    
    struct ContentItem {
        let text: String
        let type: ContentType
        let confidence: Double
    }
    
    /// Extracts content items with type detection and highlighting
    private func extractContentItems(from text: String) -> [ContentItem] {
        guard !text.isEmpty else { return [] }
        
        var contentItems: [ContentItem] = []
        
        // First extract regular content words
        let regularTerms = extractNounsAndNames(from: text)
        
        // Then detect special content types in the original text
        let specialItems = detectSpecialContent(from: text)
        
        // Combine regular terms (excluding those already found as special)
        let specialTexts = Set(specialItems.map { $0.text.lowercased() })
        for term in regularTerms {
            if !specialTexts.contains(term.lowercased()) {
                contentItems.append(ContentItem(text: term, type: .regular, confidence: 1.0))
            }
        }
        
        // Add special items
        contentItems.append(contentsOf: specialItems)
        
        // Sort by confidence and type priority, limit to 25 items
        return contentItems
            .sorted { item1, item2 in
                if item1.type != item2.type {
                    return item1.type.rawValue < item2.type.rawValue
                }
                return item1.confidence > item2.confidence
            }
            .prefix(25)
            .map { $0 }
    }
    
    /// Detect special content types like URLs, emails, prices, etc.
    private func detectSpecialContent(from text: String) -> [ContentItem] {
        var items: [ContentItem] = []
        
        // URL detection
        let urlPattern = #"(?i)\b(?:https?://|www\.)\S+\b"#
        if let urlRegex = try? NSRegularExpression(pattern: urlPattern) {
            let matches = urlRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let url = String(text[range])
                    items.append(ContentItem(text: url, type: .url, confidence: 0.95))
                }
            }
        }
        
        // Email detection
        let emailPattern = #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#
        if let emailRegex = try? NSRegularExpression(pattern: emailPattern) {
            let matches = emailRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let email = String(text[range])
                    items.append(ContentItem(text: email, type: .email, confidence: 0.95))
                }
            }
        }
        
        // Phone number detection
        let phonePattern = #"(?:\+?1[-.\s]?)?(?:\(?[0-9]{3}\)?[-.\s]?)?[0-9]{3}[-.\s]?[0-9]{4}\b"#
        if let phoneRegex = try? NSRegularExpression(pattern: phonePattern) {
            let matches = phoneRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let phone = String(text[range])
                    if phone.count >= 10 { // Filter out short numbers
                        items.append(ContentItem(text: phone, type: .phone, confidence: 0.9))
                    }
                }
            }
        }
        
        // Price detection
        let pricePattern = #"(?:\$|USD|EUR|GBP|¥|₹|£|€)\s*[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?|\b[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?\s*(?:\$|USD|EUR|GBP|dollars?|cents?)\b"#
        if let priceRegex = try? NSRegularExpression(pattern: pricePattern, options: .caseInsensitive) {
            let matches = priceRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let price = String(text[range])
                    items.append(ContentItem(text: price, type: .price, confidence: 0.9))
                }
            }
        }
        
        // Code/technical terms detection (patterns like version numbers, file extensions, hex codes)
        let codePatterns = [
            #"\bv?[0-9]+\.[0-9]+(?:\.[0-9]+)*\b"#, // Version numbers
            #"\b[A-Fa-f0-9]{6,8}\b"#, // Hex codes
            #"\b\w+\.[a-z]{2,4}\b"#, // File extensions
            #"\b[A-Z]{2,10}_[A-Z_0-9]+\b"#, // Constants
            #"\b[a-zA-Z]+:[a-zA-Z0-9_/-]+\b"# // Protocols/schemes
        ]
        
        for pattern in codePatterns {
            if let codeRegex = try? NSRegularExpression(pattern: pattern) {
                let matches = codeRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        let code = String(text[range])
                        if code.count >= 4 && !isCommonWord(code) {
                            items.append(ContentItem(text: code, type: .code, confidence: 0.8))
                        }
                    }
                }
            }
        }
        
        // Number detection (standalone numbers that might be important)
        let numberPattern = #"\b[0-9]{4,}\b"# // 4+ digit numbers
        if let numberRegex = try? NSRegularExpression(pattern: numberPattern) {
            let matches = numberRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let number = String(text[range])
                    // Avoid duplicating dates/prices already found
                    let numberText = number.lowercased()
                    if !items.contains(where: { $0.text.lowercased().contains(numberText) }) {
                        items.append(ContentItem(text: number, type: .number, confidence: 0.7))
                    }
                }
            }
        }
        
        return items
    }
    
    private func isCommonWord(_ word: String) -> Bool {
        let commonWords = ["html", "http", "https", "www", "com", "org", "net", "file", "text", "data"]
        return commonWords.contains(word.lowercased())
    }
    
    /// Extracts content words from the given text, excluding grammatical words like verbs, adjectives, prepositions
    private func extractNounsAndNames(from text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        
        var extractedTerms: Set<String> = []
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        // Extract tokens and their parts of speech
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange])
            
            // Skip very short words, punctuation, or common stop words
            guard token.count > 2,
                  !token.allSatisfy({ $0.isWhitespace || $0.isPunctuation }),
                  !isStopWord(token) else {
                return true
            }
            
            // Use POS tagger to identify content words (exclude grammatical words)
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            tagger.string = token
            
            let tags = tagger.tags(in: token.startIndex..<token.endIndex, unit: .word, scheme: .lexicalClass)
            for (tag, _) in tags {
                if let tag = tag {
                    switch tag {
                    // Include these content word types
                    case .noun, .personalName, .placeName, .organizationName:
                        let cleanToken = token.trimmingCharacters(in: .punctuationCharacters)
                        if !cleanToken.isEmpty {
                            extractedTerms.insert(cleanToken.capitalized)
                        }
                    case .otherWord:
                        // Include unclassified words (often technical terms, abbreviations, etc.)
                        let cleanToken = token.trimmingCharacters(in: .punctuationCharacters)
                        if !cleanToken.isEmpty && !isGrammaticalWord(cleanToken) {
                            extractedTerms.insert(cleanToken.capitalized)
                        }
                    // Exclude these grammatical word types
                    case .verb, .adjective, .adverb, .pronoun, .determiner, .particle, .preposition, .conjunction, .interjection:
                        break
                    default:
                        // For any other unhandled types, include if not a grammatical word
                        let cleanToken = token.trimmingCharacters(in: .punctuationCharacters)
                        if !cleanToken.isEmpty && !isGrammaticalWord(cleanToken) {
                            extractedTerms.insert(cleanToken.capitalized)
                        }
                    }
                }
            }
            
            return true
        }
        
        // Also extract named entities using NER
        let namedEntityRecognizer = NLTagger(tagSchemes: [.nameType])
        namedEntityRecognizer.string = text
        
        let namedEntityTags = namedEntityRecognizer.tags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType)
        for (tag, tokenRange) in namedEntityTags {
            if let tag = tag {
                let token = String(text[tokenRange])
                switch tag {
                case .personalName, .placeName, .organizationName:
                    let cleanToken = token.trimmingCharacters(in: .punctuationCharacters)
                    if !cleanToken.isEmpty && cleanToken.count > 2 {
                        extractedTerms.insert(cleanToken.capitalized)
                    }
                default:
                    break
                }
            }
        }
        
        // Sort alphabetically and limit to reasonable number
        return Array(extractedTerms)
            .sorted()
            .prefix(20)
            .map { $0 }
    }
    
    /// Check if a word is a common stop word that should be filtered out
    private func isStopWord(_ word: String) -> Bool {
        let stopWords: Set<String> = [
            "the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her", "was", "one", "our", "out", "day", "get", "has", "him", "his", "how", "its", "may", "new", "now", "old", "see", "two", "who", "boy", "did", "she", "use", "her", "way", "many", "then", "them", "these", "so", "some", "time", "very", "when", "come", "here", "just", "like", "long", "make", "much", "over", "such", "take", "than", "they", "well", "this", "that", "with", "have", "from", "they", "know", "want", "been", "good", "much", "some", "time", "will", "year", "your", "what", "said", "each", "which", "their", "would", "there", "could", "other"
        ]
        return stopWords.contains(word.lowercased())
    }
    
    /// Check if a word is a grammatical word (verbs, adjectives, prepositions, etc.) that should be filtered out
    private func isGrammaticalWord(_ word: String) -> Bool {
        let grammaticalWords: Set<String> = [
            // Common verbs
            "is", "am", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "shall", "should", "may", "might", "must", "can", "could", "go", "going", "went", "gone", "come", "came", "get", "got", "gotten", "make", "made", "take", "took", "taken", "see", "saw", "seen", "know", "knew", "known", "think", "thought", "say", "said", "tell", "told", "give", "gave", "given", "find", "found", "work", "worked", "call", "called", "try", "tried", "ask", "asked", "need", "needed", "feel", "felt", "become", "became", "leave", "left", "put", "bring", "brought", "begin", "began", "begun", "keep", "kept", "hold", "held", "turn", "turned", "follow", "followed", "seem", "seemed", "help", "helped", "talk", "talked", "start", "started", "show", "showed", "shown", "hear", "heard", "play", "played", "run", "ran", "move", "moved", "live", "lived", "believe", "believed", "happen", "happened", "write", "wrote", "written", "provide", "provided", "sit", "sat", "stand", "stood", "lose", "lost", "pay", "paid", "meet", "met", "include", "included", "continue", "continued", "set", "learn", "learned", "change", "changed", "lead", "led", "understand", "understood", "watch", "watched", "let", "stop", "stopped", "create", "created", "speak", "spoke", "spoken", "read", "allow", "allowed", "add", "added", "spend", "spent", "grow", "grew", "grown", "open", "opened", "walk", "walked", "win", "won", "offer", "offered", "remember", "remembered", "love", "loved", "consider", "considered", "appear", "appeared", "buy", "bought", "wait", "waited", "serve", "served", "die", "died", "send", "sent", "expect", "expected", "build", "built", "stay", "stayed", "fall", "fell", "fallen", "cut", "reach", "reached", "kill", "killed", "remain", "remained",
            // Common adjectives
            "good", "great", "small", "large", "big", "little", "high", "low", "long", "short", "wide", "narrow", "thick", "thin", "heavy", "light", "fast", "slow", "hot", "cold", "warm", "cool", "dry", "wet", "clean", "dirty", "old", "young", "new", "fresh", "early", "late", "easy", "hard", "difficult", "simple", "complex", "important", "serious", "common", "special", "certain", "particular", "general", "basic", "main", "major", "minor", "primary", "secondary", "public", "private", "personal", "social", "national", "international", "local", "regional", "global", "human", "natural", "physical", "mental", "emotional", "spiritual", "political", "economic", "financial", "legal", "medical", "technical", "scientific", "educational", "cultural", "historical", "traditional", "modern", "contemporary", "ancient", "recent", "current", "future", "past", "present", "available", "possible", "impossible", "necessary", "optional", "required", "free", "busy", "full", "empty", "open", "closed", "active", "passive", "positive", "negative", "true", "false", "real", "fake", "right", "wrong", "correct", "incorrect", "clear", "unclear", "obvious", "hidden", "visible", "invisible", "loud", "quiet", "strong", "weak", "rich", "poor", "expensive", "cheap", "beautiful", "ugly", "attractive", "popular", "famous", "unknown", "safe", "dangerous", "healthy", "sick", "happy", "sad", "angry", "calm", "excited", "bored", "interested", "surprised", "confused", "worried", "relaxed", "tired", "energetic", "successful", "failed", "lucky", "unlucky", "similar", "different", "same", "equal", "unequal", "better", "worse", "best", "worst", "first", "last", "next", "previous", "original", "final", "complete", "incomplete", "total", "partial", "whole", "broken", "fixed", "ready", "prepared", "finished", "started", "continued", "stopped",
            // Common prepositions
            "in", "on", "at", "by", "for", "with", "without", "to", "from", "of", "about", "above", "below", "under", "over", "through", "between", "among", "during", "before", "after", "since", "until", "within", "outside", "inside", "near", "far", "beside", "behind", "ahead", "around", "across", "along", "up", "down", "into", "onto", "upon", "off", "out", "against", "toward", "towards", "past", "beyond", "beneath", "underneath", "throughout", "concerning", "regarding", "despite", "except", "excluding", "including", "according", "due", "owing", "thanks", "because", "instead", "rather", "plus", "minus", "per", "via", "versus",
            // Common adverbs
            "very", "really", "quite", "rather", "pretty", "fairly", "extremely", "incredibly", "absolutely", "completely", "totally", "entirely", "fully", "partially", "hardly", "barely", "nearly", "almost", "exactly", "precisely", "approximately", "roughly", "about", "around", "clearly", "obviously", "certainly", "definitely", "probably", "possibly", "maybe", "perhaps", "surely", "likely", "unlikely", "hopefully", "fortunately", "unfortunately", "surprisingly", "interestingly", "importantly", "significantly", "basically", "essentially", "fundamentally", "generally", "usually", "normally", "typically", "commonly", "rarely", "seldom", "never", "always", "often", "sometimes", "occasionally", "frequently", "regularly", "constantly", "continuously", "temporarily", "permanently", "immediately", "instantly", "quickly", "slowly", "gradually", "suddenly", "eventually", "finally", "initially", "originally", "recently", "lately", "currently", "presently", "previously", "formerly", "earlier", "later", "soon", "shortly", "already", "still", "yet", "again", "once", "twice", "together", "apart", "separately", "alone", "here", "there", "everywhere", "somewhere", "nowhere", "anywhere", "upstairs", "downstairs", "outside", "inside", "abroad", "overseas", "home", "away", "back", "forward", "ahead", "behind", "right", "left", "straight", "directly", "indirectly"
        ]
        return grammaticalWords.contains(word.lowercased())
    }
}

// MARK: - Content Item View

struct ContentItemView: View {
    let item: UnifiedDetailsPanel.ContentItem
    let onCopy: () -> Void
    
    @StateObject private var glassSystem = GlassDesignSystem.shared
    private let hapticService = HapticService.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Type icon
            Image(systemName: item.type.icon)
                .font(.caption)
                .foregroundColor(item.type.color)
                .frame(width: 16, height: 16)
            
            // Content text
            Text(item.text)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Copy button
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
                    .foregroundColor(item.type.color)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(item.type.color.opacity(0.3), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onCopy()
        }
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

// MARK: - Full Screen Text View

struct FullScreenTextView: View {
    let screenshot: Screenshot
    let onTextChanged: (String) -> Void
    let onDismiss: () -> Void
    
    @StateObject private var glassSystem = GlassDesignSystem.shared
    private let hapticService = HapticService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with pull-down indicator
                VStack(spacing: 12) {
                    // Pull-down indicator
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(.secondary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    // Title
                    HStack {
                        Text("Extracted Text")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("Done") {
                            onDismiss()
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                }
                .background(.regularMaterial)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            // Pull down to close
                            if value.translation.height > 100 && value.velocity.height > 0 {
                                hapticService.impact(.medium)
                                onDismiss()
                            }
                        }
                )
                
                // Content
                if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
                    ExtractedTextView(
                        text: extractedText,
                        mode: .expanded,
                        theme: .glass,
                        showHeader: false,
                        editable: true,
                        onTextChanged: onTextChanged,
                        onCopy: { text in
                            hapticService.impact(.light)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                } else {
                    // No text state
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("No Text Extracted")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("This screenshot doesn't contain any readable text.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                }
                
                Spacer()
            }
            .background(.regularMaterial)
            .edgesIgnoringSafeArea(.bottom)
        }
        .navigationBarHidden(true)
    }
}
