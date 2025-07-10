import SwiftUI
import SwiftData

struct ScreenshotAttributesPanel: View {
    let screenshot: Screenshot
    @Environment(\.dismiss) private var dismiss
    @Environment(\.glassResponsiveLayout) private var layout
    @StateObject private var glassSystem = GlassDesignSystem.shared
    private let hapticService = HapticService.shared
    
    // Animation state
    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.95
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.spacing.large) {
                    // Screenshot preview
                    screenshotPreviewSection
                    
                    // File information
                    fileInformationSection
                    
                    // Extracted text section
                    if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
                        extractedTextSection(extractedText)
                    }
                    
                    // Object tags section
                    if let objectTags = screenshot.objectTags, !objectTags.isEmpty {
                        objectTagsSection(objectTags)
                    }
                    
                    // Semantic tags section
                    if let semanticTags = screenshot.semanticTags, !semanticTags.tags.isEmpty {
                        semanticTagsSection(semanticTags.tags)
                    }
                    
                    // Color analysis section
                    if !screenshot.dominantColors.isEmpty {
                        colorAnalysisSection
                    }
                    
                    // Metadata section
                    metadataSection
                    
                    // Quick actions section
                    quickActionsSection
                }
                .padding(.horizontal, layout.spacing.horizontalPadding)
                .padding(.vertical, layout.spacing.large)
            }
            .navigationTitle("Screenshot Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        hapticService.impact(.light)
                        withAnimation(glassSystem.adaptedGlassSpring(.gentle)) {
                            contentOpacity = 0
                            contentScale = 0.95
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
                        }
                    }
                    .font(layout.typography.body)
                    .fontWeight(.medium)
                }
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(glassSystem.adaptedGlassSpring(.gentle)) {
                contentOpacity = 1.0
                contentScale = 1.0
            }
        }
    }
    
    // MARK: - Preview Section
    
    @ViewBuilder
    private var screenshotPreviewSection: some View {
        VStack(alignment: .leading, spacing: layout.spacing.medium) {
            Text("Preview")
                .font(layout.typography.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if let uiImage = UIImage(data: screenshot.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: previewMaxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: layout.materials.cornerRadius, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: layout.materials.cornerRadius, style: .continuous)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.materials.cornerRadius, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            }
        }
        .scaleEffect(contentScale)
        .opacity(contentOpacity)
    }
    
    // MARK: - File Information Section
    
    @ViewBuilder
    private var fileInformationSection: some View {
        attributeSectionCard(title: "File Information", icon: "doc.text") {
            VStack(alignment: .leading, spacing: layout.spacing.small) {
                attributeRow(label: "Filename", value: screenshot.filename, copyable: true)
                attributeRow(label: "Date Created", value: formatTimestamp(), copyable: false)
                attributeRow(label: "File Size", value: formatFileSize(), copyable: false)
                if let imageSize = getImageSize() {
                    attributeRow(label: "Dimensions", value: imageSize, copyable: false)
                }
            }
        }
    }
    
    // MARK: - Extracted Text Section
    
    @ViewBuilder
    private func extractedTextSection(_ text: String) -> some View {
        attributeSectionCard(title: "Extracted Text", icon: "text.quote") {
            VStack(alignment: .leading, spacing: layout.spacing.small) {
                Text(text)
                    .font(layout.typography.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(layout.spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: layout.materials.cornerRadius, style: .continuous)
                            .fill(.thinMaterial)
                    )
                
                Button(action: {
                    UIPasteboard.general.string = text
                    hapticService.impact(.light)
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Text")
                    }
                    .font(layout.typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, layout.spacing.medium)
                    .padding(.vertical, layout.spacing.small)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Object Tags Section
    
    @ViewBuilder
    private func objectTagsSection(_ tags: [String]) -> some View {
        attributeSectionCard(title: "Detected Objects", icon: "camera.viewfinder") {
            VStack(alignment: .leading, spacing: layout.spacing.small) {
                LazyVGrid(columns: gridColumns, spacing: layout.spacing.xs) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(layout.typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, layout.spacing.small)
                            .padding(.vertical, layout.spacing.xs)
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
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy All Tags")
                    }
                    .font(layout.typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, layout.spacing.medium)
                    .padding(.vertical, layout.spacing.small)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Semantic Tags Section
    
    @ViewBuilder
    private func semanticTagsSection(_ tags: [SemanticTag]) -> some View {
        attributeSectionCard(title: "AI Semantic Tags", icon: "brain.head.profile") {
            VStack(alignment: .leading, spacing: layout.spacing.small) {
                LazyVGrid(columns: gridColumns, spacing: layout.spacing.xs) {
                    ForEach(tags, id: \.id) { tag in
                        VStack(spacing: 2) {
                            Text(tag.displayName)
                                .font(layout.typography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                            
                            Text("\(Int(tag.confidence * 100))%")
                                .font(layout.typography.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, layout.spacing.small)
                        .padding(.vertical, layout.spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
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
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Semantic Tags")
                    }
                    .font(layout.typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                    .padding(.horizontal, layout.spacing.medium)
                    .padding(.vertical, layout.spacing.small)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Color Analysis Section
    
    @ViewBuilder
    private var colorAnalysisSection: some View {
        attributeSectionCard(title: "Color Analysis", icon: "paintpalette") {
            VStack(alignment: .leading, spacing: layout.spacing.small) {
                LazyVGrid(columns: gridColumns, spacing: layout.spacing.small) {
                    ForEach(screenshot.dominantColors, id: \.colorName) { colorInfo in
                        colorInfoRow(colorInfo)
                    }
                }
                
                Button(action: {
                    let colorText = screenshot.dominantColors.map { "\($0.colorName) (\(Int($0.prominence * 100))%)" }.joined(separator: ", ")
                    UIPasteboard.general.string = colorText
                    hapticService.impact(.light)
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Color Info")
                    }
                    .font(layout.typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.horizontal, layout.spacing.medium)
                    .padding(.vertical, layout.spacing.small)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Metadata Section
    
    @ViewBuilder
    private var metadataSection: some View {
        attributeSectionCard(title: "Technical Details", icon: "info.circle") {
            VStack(alignment: .leading, spacing: layout.spacing.small) {
                attributeRow(label: "ID", value: screenshot.id.uuidString, copyable: true)
                attributeRow(label: "Processing Status", value: getProcessingStatus(), copyable: false)
                attributeRow(label: "Vision Analysis", value: screenshot.needsVisionAnalysis ? "Pending" : "Complete", copyable: false)
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    @ViewBuilder
    private var quickActionsSection: some View {
        attributeSectionCard(title: "Quick Actions", icon: "bolt") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: layout.spacing.medium) {
                quickActionButton(
                    title: "Copy All Data",
                    icon: "doc.on.doc.fill",
                    color: .blue
                ) {
                    copyAllData()
                }
                
                quickActionButton(
                    title: "Share Image",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    shareImage()
                }
                
                quickActionButton(
                    title: "Export JSON",
                    icon: "curlybraces",
                    color: .purple
                ) {
                    exportAsJSON()
                }
                
                quickActionButton(
                    title: "Copy Metadata",
                    icon: "list.clipboard",
                    color: .orange
                ) {
                    copyMetadata()
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func attributeSectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: layout.spacing.medium) {
            HStack(spacing: layout.spacing.small) {
                Image(systemName: icon)
                    .font(layout.typography.body)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(layout.typography.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            content()
        }
        .padding(layout.spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: layout.materials.cornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .scaleEffect(contentScale)
        .opacity(contentOpacity)
    }
    
    @ViewBuilder
    private func attributeRow(label: String, value: String, copyable: Bool) -> some View {
        HStack(alignment: .top, spacing: layout.spacing.medium) {
            Text(label)
                .font(layout.typography.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            
            Text(value)
                .font(layout.typography.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if copyable {
                Button(action: {
                    UIPasteboard.general.string = value
                    hapticService.impact(.light)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(layout.typography.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private func quickActionButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: layout.spacing.small) {
                Image(systemName: icon)
                    .font(layout.typography.title)
                    .foregroundColor(color)
                
                Text(title)
                    .font(layout.typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(layout.spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    
    private var previewMaxHeight: CGFloat {
        switch layout.deviceType {
        case .iPhoneSE: return 200
        case .iPhoneStandard: return 250
        case .iPhoneMax: return 300
        case .iPadMini: return 350
        case .iPad: return 400
        case .iPadPro: return 450
        }
    }
    
    private var gridColumns: [GridItem] {
        let columnCount = layout.deviceType == .iPhoneSE ? 2 : 3
        return Array(repeating: GridItem(.flexible()), count: columnCount)
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func colorInfoRow(_ colorInfo: DominantColor) -> some View {
        HStack(spacing: layout.spacing.small) {
            Circle()
                .fill(Color(red: colorInfo.red, green: colorInfo.green, blue: colorInfo.blue))
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                )
            
            VStack(alignment: .leading, spacing: 1) {
                Text(colorInfo.colorName)
                    .font(layout.typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(Int(colorInfo.prominence * 100))%")
                    .font(layout.typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(layout.spacing.small)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
        )
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
    
    private func getImageSize() -> String? {
        guard let uiImage = UIImage(data: screenshot.imageData) else { return nil }
        let size = uiImage.size
        return "\(Int(size.width)) × \(Int(size.height))"
    }
    
    private func getProcessingStatus() -> String {
        var status: [String] = []
        
        if screenshot.extractedText?.isEmpty == false {
            status.append("OCR Complete")
        }
        
        if !(screenshot.objectTags?.isEmpty ?? true) {
            status.append("Vision Analysis")
        }
        
        if let semanticTags = screenshot.semanticTags, !semanticTags.tags.isEmpty {
            status.append("AI Semantic Tags")
        }
        
        if !screenshot.dominantColors.isEmpty {
            status.append("Color Analysis")
        }
        
        return status.isEmpty ? "Basic" : status.joined(separator: ", ")
    }
    
    // MARK: - Action Methods
    
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
    
    private func shareImage() {
        guard let image = UIImage(data: screenshot.imageData) else {
            hapticService.notification(.error)
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = window.rootViewController {
            
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            // Configure for iPad
            if let popoverController = activityVC.popoverPresentationController {
                popoverController.sourceView = topController.view
                popoverController.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            topController.present(activityVC, animated: true) {
                self.hapticService.impact(.medium)
            }
        }
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
    
    private func copyMetadata() {
        var metadata: [String] = []
        
        metadata.append("ID: \(screenshot.id.uuidString)")
        metadata.append("Size: \(formatFileSize())")
        if let imageSize = getImageSize() {
            metadata.append("Dimensions: \(imageSize)")
        }
        metadata.append("Processing: \(getProcessingStatus())")
        
        UIPasteboard.general.string = metadata.joined(separator: "\n")
        hapticService.impact(.light)
    }
}

#Preview {
    ScreenshotAttributesPanel(screenshot: Screenshot(imageData: Data(), filename: "test_image.jpg"))
        .modelContainer(for: Screenshot.self, inMemory: true)
}