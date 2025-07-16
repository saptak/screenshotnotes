//
//  TextActionOverlay.swift
//  ScreenshotNotes
//
//  Iteration 8.7.1.1: One-Tap Text Actions
//  Glass design UI overlay for displaying text action buttons with beautiful animations
//

import SwiftUI

struct TextActionOverlay<Content: View>: View {
    
    // MARK: - Properties
    
    let actions: [SmartTextActionService.TextAction]
    let onActionTapped: (SmartTextActionService.TextAction) -> Void
    let onDismiss: () -> Void
    let content: Content
    
    @State private var isVisible = false
    @State private var selectedAction: SmartTextActionService.TextAction?
    @State private var isExecutingAction = false
    
    @Environment(\.glassResponsiveLayout) private var responsiveLayout
    @StateObject private var glassSystem = GlassDesignSystem.shared
    @StateObject private var hapticService = HapticFeedbackService.shared
    
    // Memory management
    private let maxDisplayedActions = 8 // Limit displayed actions to prevent memory issues
    
    // MARK: - Initialization
    
    init(
        actions: [SmartTextActionService.TextAction],
        onActionTapped: @escaping (SmartTextActionService.TextAction) -> Void,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.actions = actions
        self.onActionTapped = onActionTapped
        self.onDismiss = onDismiss
        self.content = content()
    }
    
    // MARK: - Animation Configuration
    
    private let animationDuration: Double = 0.4
    private let staggerDelay: Double = 0.05
    
    // MARK: - Body
    
    var body: some View {
        content
            .overlay(alignment: .bottom) {
                if isVisible && !displayedActions.isEmpty {
                    overlayContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .animation(
                            GlassDesignSystem.glassSpring(.responsive),
                            value: isVisible
                        )
                }
            }
            .onAppear {
                withAnimation(GlassDesignSystem.glassSpring(.gentle).delay(0.1)) {
                    isVisible = true
                }
            }
            .onDisappear {
                cleanup()
            }
    }
    
    // MARK: - Computed Properties
    
    /// Limit displayed actions for memory efficiency
    private var displayedActions: [SmartTextActionService.TextAction] {
        Array(actions.prefix(maxDisplayedActions))
    }
    
    // MARK: - Memory Management
    
    private func cleanup() {
        isVisible = false
        selectedAction = nil
        isExecutingAction = false
    }
    
    // MARK: - Overlay Content
    
    @ViewBuilder
    private var overlayContent: some View {
        VStack(spacing: 0) {
            // Background tap to dismiss
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissOverlay()
                }
            
            // Action buttons container
            actionButtonsContainer
                .responsivePadding(responsiveLayout, edge: .horizontal, size: .medium)
                .responsivePadding(responsiveLayout, edge: .bottom, size: .large)
                .responsivePadding(responsiveLayout, edge: .top, size: .small)
        }
    }
    
    @ViewBuilder
    private var actionButtonsContainer: some View {
        VStack(spacing: responsiveLayout.spacing.small) {
            // Handle indicator
            handleIndicator
            
            // Actions grid
            actionsGrid
        }
        .responsiveGlassBackground(
            layout: responsiveLayout,
            materialType: .primary,
            shadow: true
        )
        .clipShape(RoundedRectangle(
            cornerRadius: responsiveLayout.materials.cornerRadius,
            style: .continuous
        ))
    }
    
    @ViewBuilder
    private var handleIndicator: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(.tertiary)
            .frame(width: 40, height: 4)
            .padding(.top, responsiveLayout.spacing.small)
            .padding(.bottom, responsiveLayout.spacing.xs)
    }
    
    @ViewBuilder
    private var actionsGrid: some View {
        let columns = gridColumns
        
        LazyVGrid(columns: columns, spacing: responsiveLayout.spacing.small) {
            ForEach(Array(displayedActions.enumerated()), id: \.element.id) { index, action in
                actionButton(for: action, index: index)
            }
        }
        .padding(.horizontal, responsiveLayout.spacing.medium)
        .padding(.bottom, responsiveLayout.spacing.medium)
    }
    
    @ViewBuilder
    private func actionButton(for action: SmartTextActionService.TextAction, index: Int) -> some View {
        Button {
            executeAction(action)
        } label: {
            VStack(spacing: responsiveLayout.spacing.xs) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(.tertiary.opacity(0.3))
                        .frame(
                            width: iconContainerSize,
                            height: iconContainerSize
                        )
                    
                    Image(systemName: action.systemImage)
                        .font(.system(
                            size: iconSize,
                            weight: .medium,
                            design: .rounded
                        ))
                        .foregroundStyle(iconColor(for: action))
                }
                
                // Action label
                Text(action.actionName)
                    .font(responsiveLayout.typography.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: buttonHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassActionButtonStyle(
            isSelected: selectedAction?.id == action.id,
            isExecuting: isExecutingAction && selectedAction?.id == action.id
        ))
        .disabled(isExecutingAction)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.8)
        .animation(
            GlassDesignSystem.glassSpring(.responsive)
                .delay(Double(index) * staggerDelay),
            value: isVisible
        )
    }
    
    // MARK: - Layout Configuration
    
    private var gridColumns: [GridItem] {
        let maxColumns = responsiveLayout.deviceType == .iPhoneSE ? 3 : 4
        let actualColumns = min(displayedActions.count, maxColumns)
        
        return Array(repeating: GridItem(.flexible(), spacing: responsiveLayout.spacing.small), count: actualColumns)
    }
    
    private var iconContainerSize: CGFloat {
        switch responsiveLayout.deviceType {
        case .iPhoneSE: return 36
        case .iPhoneStandard, .iPhoneMax: return 44
        case .iPadMini, .iPad, .iPadPro: return 48
        }
    }
    
    private var iconSize: CGFloat {
        switch responsiveLayout.deviceType {
        case .iPhoneSE: return 16
        case .iPhoneStandard, .iPhoneMax: return 18
        case .iPadMini, .iPad, .iPadPro: return 20
        }
    }
    
    private var buttonHeight: CGFloat {
        switch responsiveLayout.deviceType {
        case .iPhoneSE: return 64
        case .iPhoneStandard, .iPhoneMax: return 72
        case .iPadMini, .iPad, .iPadPro: return 80
        }
    }
    
    // MARK: - Helper Methods
    
    private func iconColor(for action: SmartTextActionService.TextAction) -> Color {
        switch action.type {
        case .copy:
            return .blue
        case .call, .facetime:
            return .green
        case .email, .message:
            return .blue
        case .openURL:
            return .orange
        case .openMaps:
            return .red
        case .addContact:
            return .purple
        case .createEvent:
            return .indigo
        }
    }
    
    private func executeAction(_ action: SmartTextActionService.TextAction) {
        guard !isExecutingAction else { return }
        
        selectedAction = action
        isExecutingAction = true
        
        // Haptic feedback
        hapticService.triggerHaptic(.light)
        
        // Visual feedback animation
        withAnimation(GlassDesignSystem.glassSpring(.responsive)) {
            // Animation handled by button style
        }
        
        // Execute action
        onActionTapped(action)
        
        // Reset after execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(GlassDesignSystem.glassSpring(.gentle)) {
                selectedAction = nil
                isExecutingAction = false
            }
        }
        
        // Auto-dismiss for copy actions
        if action.type == .copy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismissOverlay()
            }
        }
    }
    
    private func dismissOverlay() {
        hapticService.triggerHaptic(.light)
        
        withAnimation(GlassDesignSystem.glassSpring(.gentle)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            onDismiss()
        }
    }
}

// MARK: - Glass Action Button Style

struct GlassActionButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isExecuting: Bool
    
    @StateObject private var glassSystem = GlassDesignSystem.shared
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundMaterial)
                    .overlay {
                        if isSelected || configuration.isPressed {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.primary.opacity(0.3), lineWidth: 1)
                        }
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(isExecuting ? 0.6 : 1)
            .overlay {
                if isExecuting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        .scaleEffect(0.8)
                }
            }
            .animation(GlassDesignSystem.glassSpring(.microphone), value: configuration.isPressed)
            .animation(GlassDesignSystem.glassSpring(.responsive), value: isSelected)
            .animation(GlassDesignSystem.glassSpring(.gentle), value: isExecuting)
    }
    
    private var backgroundMaterial: Material {
        if isSelected {
            return .thick
        } else {
            return .thin
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds text action overlay when actions are available
    func textActionOverlay(
        actions: [SmartTextActionService.TextAction],
        onActionTapped: @escaping (SmartTextActionService.TextAction) -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        TextActionOverlay(
            actions: actions,
            onActionTapped: onActionTapped,
            onDismiss: onDismiss
        ) {
            self
        }
    }
}

// MARK: - Preview Support

#if DEBUG
#Preview("Text Action Overlay") {
    ZStack {
        // Background
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        // Sample screenshot content
        VStack {
            Text("Sample Screenshot")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Call me at +1 (555) 123-4567")
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            Spacer()
        }
        .padding()
    }
    .textActionOverlay(
        actions: SmartTextActionService.mockActions(),
        onActionTapped: { action in
            print("Action tapped: \(action.actionName)")
        },
        onDismiss: {
            print("Overlay dismissed")
        }
    )
    .responsiveLayout()
}

#Preview("Text Action Overlay - Compact") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Text("Compact Layout")
                .foregroundStyle(.white)
            Spacer()
        }
    }
    .textActionOverlay(
        actions: Array(SmartTextActionService.mockActions().prefix(3)),
        onActionTapped: { _ in },
        onDismiss: { }
    )
    .responsiveLayout()
}
#endif