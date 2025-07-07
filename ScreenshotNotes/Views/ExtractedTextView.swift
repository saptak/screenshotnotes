import SwiftUI

/// Unified, beautiful extracted text display component for consistent UX across the app
struct ExtractedTextView: View {
    // MARK: - Configuration
    enum DisplayMode {
        case compact    // For mind map nodes and small spaces
        case standard   // For detail views and main content
        case expanded   // For full-screen text editing
    }
    
    enum Theme {
        case light      // Light backgrounds
        case dark       // Dark backgrounds  
        case glass      // Glass material backgrounds
        case adaptive   // Adapts to environment
    }
    
    // MARK: - Properties
    let text: String
    let mode: DisplayMode
    let theme: Theme
    let showHeader: Bool
    let editable: Bool
    let onTextChanged: ((String) -> Void)?
    let onCopy: ((String) -> Void)?
    
    // MARK: - State
    @StateObject private var smartTextService = SmartTextDisplayService.shared
    @State private var textResult: SmartTextResult?
    @State private var isLoading = true
    @State private var showCopiedFeedback = false
    @State private var editedText: String
    @State private var isEditing = false
    @State private var selectedEntity: SmartTextEntity?
    
    // MARK: - Initialization
    init(
        text: String,
        mode: DisplayMode = .standard,
        theme: Theme = .adaptive,
        showHeader: Bool = true,
        editable: Bool = false,
        onTextChanged: ((String) -> Void)? = nil,
        onCopy: ((String) -> Void)? = nil
    ) {
        self.text = text
        self.mode = mode
        self.theme = theme
        self.showHeader = showHeader
        self.editable = editable
        self.onTextChanged = onTextChanged
        self.onCopy = onCopy
        self._editedText = State(initialValue: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            if showHeader {
                headerView
            }
            
            // Main content
            ZStack(alignment: .topTrailing) {
                contentView
                
                // Copy feedback
                if showCopiedFeedback {
                    copyFeedbackView
                }
            }
        }
        .background(backgroundMaterial)
        .overlay(borderOverlay)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
        .task {
            await loadSmartText()
        }
        .onChange(of: text) { _, newText in
            editedText = newText
            Task {
                await loadSmartText()
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(headerTitle)
                    .font(headerFont)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
            } else if let result = textResult {
                HStack(spacing: 4) {
                    if !result.displayEntities.isEmpty {
                        Text("\(result.displayEntities.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.1), in: Capsule())
                    }
                    
                    if editable {
                        Button(isEditing ? "Done" : "Edit") {
                            toggleEditMode()
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .padding(.horizontal, contentPadding)
        .padding(.top, contentPadding - 4)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else if isEditing {
            editingView
        } else if let result = textResult, result.hasEntities {
            entityView(result)
        } else {
            plainTextView
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        HStack {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
            
            Text("Analyzing text...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(contentPadding)
    }
    
    @ViewBuilder
    private var editingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $editedText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minTextHeight)
            
            HStack {
                Button("Cancel") {
                    editedText = text
                    isEditing = false
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Save") {
                    onTextChanged?(editedText)
                    isEditing = false
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
            }
        }
        .padding(contentPadding)
    }
    
    @ViewBuilder
    private func entityView(_ result: SmartTextResult) -> some View {
        ScrollView(.vertical, showsIndicators: scrollIndicators) {
            LazyVStack(alignment: .leading, spacing: entitySpacing) {
                // Full text with selection enabled
                if mode != .compact {
                    Text(result.originalText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(.bottom, 8)
                    
                    Divider()
                        .padding(.bottom, 4)
                }
                
                // Entity chips
                ForEach(result.displayEntities) { entity in
                    entityChip(entity)
                }
                
                // Copy all button
                if mode != .compact {
                    copyAllButton
                }
            }
            .padding(contentPadding)
        }
        .frame(maxHeight: maxContentHeight)
    }
    
    @ViewBuilder
    private var plainTextView: some View {
        ScrollView(.vertical, showsIndicators: scrollIndicators) {
            VStack(alignment: .leading, spacing: 12) {
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                
                if mode != .compact {
                    copyAllButton
                }
            }
            .padding(contentPadding)
        }
        .frame(maxHeight: maxContentHeight)
    }
    
    @ViewBuilder
    private func entityChip(_ entity: SmartTextEntity) -> some View {
        HStack(spacing: 8) {
            // Entity content
            HStack(spacing: 6) {
                Image(systemName: entity.type.icon)
                    .font(.caption)
                    .foregroundColor(entity.type.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entity.text)
                        .font(entityTextFont)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if mode == .standard || mode == .expanded {
                        Text(entity.type.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if entity.confidence > 0.8 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer(minLength: 0)
            
            // Action button
            Button(action: {
                handleEntityAction(entity)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: entity.actionable ? actionIcon(for: entity.type) : "doc.on.doc")
                    
                    if mode == .expanded {
                        Text(entity.type.actionLabel)
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(entity.type.color, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(entity.type.actionLabel) \(entity.type.displayName): \(entity.text)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Group {
                if theme == .glass {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.thinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(entityBackgroundColor)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(entity.type.color.opacity(0.2), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var copyAllButton: some View {
        Button(action: copyAllText) {
            HStack {
                Image(systemName: "doc.on.doc")
                Text("Copy All Text")
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var copyFeedbackView: some View {
        Label("Copied!", systemImage: "checkmark.circle.fill")
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .foregroundColor(.green)
            .transition(.move(edge: .top).combined(with: .opacity))
            .padding(.trailing, 16)
            .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func loadSmartText() async {
        isLoading = true
        
        let result = await smartTextService.processText(editedText)
        
        await MainActor.run {
            textResult = result
            isLoading = false
        }
    }
    
    private func handleEntityAction(_ entity: SmartTextEntity) {
        smartTextService.performAction(for: entity)
        showCopyFeedback()
        onCopy?(entity.text)
    }
    
    private func copyAllText() {
        UIPasteboard.general.string = editedText
        showCopyFeedback()
        onCopy?(editedText)
    }
    
    private func showCopyFeedback() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showCopiedFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showCopiedFeedback = false
            }
        }
    }
    
    private func toggleEditMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditing.toggle()
        }
    }
    
    private func actionIcon(for type: SmartTextEntity.EntityType) -> String {
        switch type {
        case .url: return "safari"
        case .phoneNumber: return "phone"
        case .email: return "envelope"
        case .address: return "map"
        default: return "doc.on.doc"
        }
    }
    
    // MARK: - Computed Properties
    
    private var headerTitle: String {
        switch mode {
        case .compact: return "Text"
        case .standard: return "Extracted Text"
        case .expanded: return "Text Analysis"
        }
    }
    
    private var headerFont: Font {
        switch mode {
        case .compact: return .caption
        case .standard: return .headline
        case .expanded: return .title3
        }
    }
    
    private var entityTextFont: Font {
        switch mode {
        case .compact: return .caption
        case .standard: return .body
        case .expanded: return .body
        }
    }
    
    private var contentPadding: CGFloat {
        switch mode {
        case .compact: return 8
        case .standard: return 16
        case .expanded: return 20
        }
    }
    
    private var entitySpacing: CGFloat {
        switch mode {
        case .compact: return 6
        case .standard: return 10
        case .expanded: return 12
        }
    }
    
    private var cornerRadius: CGFloat {
        switch mode {
        case .compact: return 8
        case .standard: return 16
        case .expanded: return 20
        }
    }
    
    private var maxContentHeight: CGFloat? {
        switch mode {
        case .compact: return 150
        case .standard: return 400
        case .expanded: return nil
        }
    }
    
    private var minTextHeight: CGFloat {
        switch mode {
        case .compact: return 60
        case .standard: return 100
        case .expanded: return 150
        }
    }
    
    private var scrollIndicators: Bool {
        mode != .compact
    }
    
    @ViewBuilder
    private var backgroundMaterial: some View {
        switch theme {
        case .light:
            Color(UIColor.secondarySystemBackground)
        case .dark:
            Color(UIColor.systemBackground)
        case .glass:
            Rectangle().fill(.ultraThinMaterial)
        case .adaptive:
            Rectangle().fill(.regularMaterial)
        }
    }
    
    @ViewBuilder
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
    }
    
    private var entityBackgroundColor: Color {
        switch theme {
        case .light:
            return .white
        case .dark:
            return Color(UIColor.tertiarySystemBackground)
        case .glass:
            return Color.clear
        case .adaptive:
            return Color(UIColor.tertiarySystemBackground)
        }
    }
    
    private var shadowColor: Color {
        Color.black.opacity(mode == .compact ? 0.05 : 0.1)
    }
    
    private var shadowRadius: CGFloat {
        switch mode {
        case .compact: return 2
        case .standard: return 8
        case .expanded: return 12
        }
    }
    
    private var shadowOffset: CGFloat {
        switch mode {
        case .compact: return 1
        case .standard: return 2
        case .expanded: return 4
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ExtractedTextView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Compact mode
                ExtractedTextView(
                    text: "Call John at (555) 123-4567 or email john@example.com. Visit https://apple.com for more info.",
                    mode: .compact,
                    theme: .adaptive
                )
                
                // Standard mode
                ExtractedTextView(
                    text: "Order #12345 shipped to 123 Main St, Anytown USA 12345. Track at https://tracking.example.com. Contact support@company.com or call (555) 987-6543.",
                    mode: .standard,
                    theme: .adaptive,
                    editable: true
                )
                
                // Expanded mode
                ExtractedTextView(
                    text: "Invoice #INV-2024-001 for $2,499.99 due March 15, 2024. Apple Inc. headquartered at One Apple Park Way, Cupertino, CA 95014. Questions? Email billing@apple.com or visit https://support.apple.com.",
                    mode: .expanded,
                    theme: .glass,
                    editable: true
                )
            }
            .padding()
        }
        .previewDisplayName("ExtractedTextView Modes")
    }
}
#endif