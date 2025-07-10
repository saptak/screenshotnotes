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
    @State private var showingUnifiedPanel = true
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
                // --- Unified Details Panel ---
                if showingUnifiedPanel {
                    UnifiedDetailsPanel(
                        screenshot: currentScreenshot,
                        onTextChanged: { newText in
                            currentScreenshot.extractedText = newText
                        },
                        onCopy: { _ in
                            addHapticFeedback(.light)
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

// MARK: - Unified Details Panel

struct UnifiedDetailsPanel: View {
    let screenshot: Screenshot
    let onTextChanged: (String) -> Void
    let onCopy: (String) -> Void
    @StateObject private var glassSystem = GlassDesignSystem.shared
    private let hapticService = HapticService.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Extracted Text Section (if available)
                if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
                    extractedTextSection(extractedText)
                }
                
                // File Information
                fileInformationSection
                
                // Object Tags (if available)
                if let objectTags = screenshot.objectTags, !objectTags.isEmpty {
                    objectTagsSection(objectTags)
                }
                
                // Semantic Tags (if available)
                if let semanticTags = screenshot.semanticTags, !semanticTags.tags.isEmpty {
                    semanticTagsSection(semanticTags.tags)
                }
                
                // Color Analysis (if available)
                if !screenshot.dominantColors.isEmpty {
                    colorAnalysisSection
                }
                
                // Technical Details
                technicalDetailsSection
                
                // Quick Actions
                quickActionsSection
            }
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Section Views
    
    @ViewBuilder
    private func extractedTextSection(_ text: String) -> some View {
        sectionCard(title: "Extracted Text", icon: "text.quote") {
            VStack(alignment: .leading, spacing: 12) {
                ExtractedTextView(
                    text: text,
                    mode: .standard,
                    theme: .glass,
                    editable: true,
                    onTextChanged: onTextChanged,
                    onCopy: onCopy
                )
                
                HStack {
                    Button(action: {
                        UIPasteboard.general.string = text
                        hapticService.impact(.light)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Text")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private var fileInformationSection: some View {
        sectionCard(title: "File Information", icon: "doc.text") {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Filename", value: screenshot.filename, copyable: true)
                infoRow(label: "Date", value: formatTimestamp(), copyable: false)
                infoRow(label: "Size", value: formatFileSize(), copyable: false)
                if let dimensions = getImageDimensions() {
                    infoRow(label: "Dimensions", value: dimensions, copyable: false)
                }
            }
        }
    }
    
    @ViewBuilder
    private func objectTagsSection(_ tags: [String]) -> some View {
        sectionCard(title: "Detected Objects", icon: "camera.viewfinder") {
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
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                    }
                }
                
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
                    .foregroundColor(.blue)
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
    }
    
    @ViewBuilder
    private func semanticTagsSection(_ tags: [SemanticTag]) -> some View {
        sectionCard(title: "AI Semantic Tags", icon: "brain.head.profile") {
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
                
                Button(action: {
                    let tagsText = tags.map { $0.displayName }.joined(separator: ", ")
                    UIPasteboard.general.string = tagsText
                    hapticService.impact(.light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Semantic Tags")
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
    }
    
    @ViewBuilder
    private var colorAnalysisSection: some View {
        sectionCard(title: "Color Analysis", icon: "paintpalette") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(screenshot.dominantColors, id: \.colorName) { colorInfo in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: colorInfo.red, green: colorInfo.green, blue: colorInfo.blue))
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                                )
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(colorInfo.colorName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("\(Int(colorInfo.prominence * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.thinMaterial)
                        )
                    }
                }
                
                Button(action: {
                    let colorText = screenshot.dominantColors.map { "\($0.colorName) (\(Int($0.prominence * 100))%)" }.joined(separator: ", ")
                    UIPasteboard.general.string = colorText
                    hapticService.impact(.light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Colors")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
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
    }
    
    @ViewBuilder
    private var technicalDetailsSection: some View {
        sectionCard(title: "Technical Details", icon: "info.circle") {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "ID", value: screenshot.id.uuidString, copyable: true)
                infoRow(label: "Processing", value: getProcessingStatus(), copyable: false)
                infoRow(label: "Vision Analysis", value: screenshot.needsVisionAnalysis ? "Pending" : "Complete", copyable: false)
            }
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        sectionCard(title: "Quick Actions", icon: "bolt") {
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
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
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
