import SwiftUI
import SwiftData

/// Beautiful suggestion card with Glass design for proactive recommendations
/// Displays actionable suggestions with elegant animations and haptic feedback
struct SmartSuggestionCard: View {
    let suggestion: SmartSuggestionsService.SuggestionCard
    let onAccept: () -> Void
    let onDismiss: () -> Void
    let onMoreInfo: () -> Void
    
    @State private var isExpanded = false
    @State private var cardOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingScreenshots = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glassResponsiveLayout) private var layout
    
    private let hapticService = HapticFeedbackService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            cardContent
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: layout.materials.cornerRadius))
                .scaleEffect(isDragging ? 0.98 : 1.0)
                .offset(cardOffset)
                .rotation3DEffect(
                    .degrees(cardOffset.width * 0.05),
                    axis: (x: 0, y: 1, z: 0)
                )
                .shadow(
                    color: suggestion.type.glassBackground == .accent ? .blue.opacity(0.3) : .black.opacity(0.1),
                    radius: isDragging ? 20 : 10,
                    x: 0,
                    y: isDragging ? 10 : 5
                )
            
            // Expanded content
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
            }
        }
        .padding(.horizontal, layout.spacing.medium)
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .animation(.easeInOut(duration: 0.2), value: cardOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        hapticService.triggerHaptic(.longPressStart)
                    }
                    cardOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    
                    let threshold: CGFloat = 100
                    
                    if value.translation.width > threshold {
                        // Swipe right to accept
                        hapticService.triggerHaptic(.suggestionAccepted)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            cardOffset = CGSize(width: 300, height: 0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onAccept()
                        }
                    } else if value.translation.width < -threshold {
                        // Swipe left to dismiss
                        hapticService.triggerHaptic(.menuDismiss)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            cardOffset = CGSize(width: -300, height: 0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            cardOffset = .zero
                        }
                    }
                }
        )
        .onTapGesture {
            hapticService.triggerHaptic(.menuSelection)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        HStack(spacing: layout.spacing.medium) {
            // Icon with dynamic color
            cardIcon
            
            // Main content
            VStack(alignment: .leading, spacing: layout.spacing.small) {
                // Title and subtitle
                titleSection
                
                // Description
                descriptionSection
                
                // Priority and confidence indicators
                metadataSection
            }
            
            Spacer()
            
            // Action button
            actionButton
        }
        .padding(layout.spacing.medium)
    }
    
    private var cardIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundGradient)
                .frame(width: 44, height: 44)
            
            Image(systemName: suggestion.iconName)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(iconForegroundColor)
        }
    }
    
    private var iconBackgroundGradient: LinearGradient {
        switch suggestion.type {
        case .recentlyUseful:
            return LinearGradient(
                colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .relatedContent:
            return LinearGradient(
                colors: [.green.opacity(0.3), .green.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .organizationPrompt:
            return LinearGradient(
                colors: [.orange.opacity(0.3), .orange.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cleanupRecommendation, .duplicateCleanup:
            return LinearGradient(
                colors: [.red.opacity(0.3), .red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .contentDiscovery:
            return LinearGradient(
                colors: [.purple.opacity(0.3), .purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .workflowSuggestion:
            return LinearGradient(
                colors: [.teal.opacity(0.3), .teal.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .qualityImprovement:
            return LinearGradient(
                colors: [.indigo.opacity(0.3), .indigo.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var iconForegroundColor: Color {
        switch suggestion.type {
        case .recentlyUseful: return .blue
        case .relatedContent: return .green
        case .organizationPrompt: return .orange
        case .cleanupRecommendation, .duplicateCleanup: return .red
        case .contentDiscovery: return .purple
        case .workflowSuggestion: return .teal
        case .qualityImprovement: return .indigo
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(suggestion.title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            if !suggestion.subtitle.isEmpty {
                Text(suggestion.subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private var descriptionSection: some View {
        Text(suggestion.description)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(isExpanded ? nil : 2)
            .multilineTextAlignment(.leading)
    }
    
    private var metadataSection: some View {
        HStack(spacing: layout.spacing.small) {
            // Priority indicator
            priorityIndicator
            
            // Confidence indicator
            confidenceIndicator
            
            Spacer()
            
            // Type badge
            typeBadge
        }
    }
    
    private var priorityIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: priorityIconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(priorityColor)
            
            Text(suggestion.priority.description)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(priorityColor)
        }
    }
    
    private var priorityIconName: String {
        switch suggestion.priority {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark"
        }
    }
    
    private var priorityColor: Color {
        switch suggestion.priority {
        case .low: return .secondary
        case .medium: return .primary
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Text("\(Int(suggestion.confidence * 100))%")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
    
    private var confidenceColor: Color {
        if suggestion.confidence > 0.8 { return .green }
        if suggestion.confidence > 0.6 { return .orange }
        return .red
    }
    
    private var typeBadge: some View {
        Text(suggestion.type.displayName)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.secondary.opacity(0.1))
            )
    }
    
    private var actionButton: some View {
        Button(action: {
            hapticService.triggerHaptic(.suggestionAccepted)
            onAccept()
        }) {
            Text(suggestion.actionTitle)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(iconForegroundColor.gradient)
                        .shadow(color: iconForegroundColor.opacity(0.3), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(SmartSuggestionScaleButtonStyle())
    }
    
    // MARK: - Card Background
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: layout.materials.cornerRadius)
            .fill(suggestion.type.glassBackground.material(for: layout).material)
            .overlay(
                RoundedRectangle(cornerRadius: layout.materials.cornerRadius)
                    .strokeBorder(borderGradient, lineWidth: 1)
            )
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                iconForegroundColor.opacity(0.3),
                iconForegroundColor.opacity(0.1),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        VStack(spacing: layout.spacing.medium) {
            // Screenshots preview if available
            if !suggestion.screenshots.isEmpty {
                screenshotsPreview
            }
            
            // Additional actions
            actionButtons
        }
        .padding(layout.spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: layout.materials.cornerRadius)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var screenshotsPreview: some View {
        VStack(alignment: .leading, spacing: layout.spacing.small) {
            Text("Related Screenshots (\(suggestion.screenshots.count))")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: layout.spacing.small) {
                    ForEach(suggestion.screenshots.prefix(5), id: \.id) { screenshot in
                        screenshotThumbnail(screenshot)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    
    private func screenshotThumbnail(_ screenshot: Screenshot) -> some View {
        RoundedRectangle(cornerRadius: layout.materials.cornerRadius)
            .fill(.secondary.opacity(0.1))
            .frame(width: 60, height: 80)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text(screenshot.filename.isEmpty ? "Screenshot" : String(screenshot.filename.prefix(8)))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            )
            .onTapGesture {
                hapticService.triggerHaptic(.menuSelection)
                showingScreenshots = true
            }
    }
    
    private var actionButtons: some View {
        HStack(spacing: layout.spacing.medium) {
            Button("More Info") {
                hapticService.triggerHaptic(.menuSelection)
                onMoreInfo()
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Spacer()
            
            Button("Dismiss") {
                hapticService.triggerHaptic(.menuDismiss)
                onDismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Button(suggestion.actionTitle) {
                hapticService.triggerHaptic(.suggestionAccepted)
                onAccept()
            }
            .buttonStyle(PrimaryButtonStyle(color: iconForegroundColor))
        }
    }
}

// MARK: - Button Styles

struct SmartSuggestionScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(color.gradient)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.secondary.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension SmartSuggestionsService.SuggestionCard.Priority {
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

// MARK: - Preview

#Preview("Suggestion Cards") {
    ScrollView {
        LazyVStack(spacing: 16) {
            ForEach(PreviewData.sampleSuggestionCards, id: \.id) { suggestion in
                SmartSuggestionCard(
                    suggestion: suggestion,
                    onAccept: { print("Accepted: \(suggestion.title)") },
                    onDismiss: { print("Dismissed: \(suggestion.title)") },
                    onMoreInfo: { print("More info: \(suggestion.title)") }
                )
            }
        }
        .padding()
    }
    .background(.regularMaterial)
    .environmentObject(GlassDesignSystem.shared)
}

private struct PreviewData {
    static let sampleSuggestionCards: [SmartSuggestionsService.SuggestionCard] = [
        SmartSuggestionsService.SuggestionCard(
            type: .recentlyUseful,
            title: "Recently Useful",
            subtitle: "5 screenshots",
            description: "Screenshots you've been accessing frequently this week",
            iconName: "clock.arrow.circlepath",
            actionTitle: "View Collection",
            priority: .medium,
            confidence: 0.85
        ),
        SmartSuggestionsService.SuggestionCard(
            type: .organizationPrompt,
            title: "Organization Opportunity",
            subtitle: "12 untagged",
            description: "These screenshots could be organized into groups",
            iconName: "folder.badge.plus",
            actionTitle: "Organize",
            priority: .high,
            confidence: 0.72
        ),
        SmartSuggestionsService.SuggestionCard(
            type: .duplicateCleanup,
            title: "Potential Duplicates",
            subtitle: "3 similar items",
            description: "These screenshots appear to be duplicates",
            iconName: "doc.on.doc",
            actionTitle: "Review",
            priority: .low,
            confidence: 0.64
        )
    ]
}