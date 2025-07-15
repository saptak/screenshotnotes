import SwiftUI
import Foundation

/// Comprehensive contextual menu service for sophisticated menu interactions
/// Provides contextual menus, quick actions, and batch operations with haptic feedback
@MainActor
public final class ContextualMenuService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ContextualMenuService()
    
    // MARK: - Menu Action Types
    
    public enum MenuAction: String, CaseIterable, Identifiable {
        case share = "share"
        case copy = "copy"
        case delete = "delete"
        case tag = "tag"
        case favorite = "favorite"
        case export = "export"
        case duplicate = "duplicate"
        case addToCollection = "add_to_collection"
        case viewDetails = "view_details"
        case editMetadata = "edit_metadata"
        
        public var id: String { rawValue }
        
        var title: String {
            switch self {
            case .share:
                return "Share"
            case .copy:
                return "Copy"
            case .delete:
                return "Delete"
            case .tag:
                return "Add Tag"
            case .favorite:
                return "Favorite"
            case .export:
                return "Export"
            case .duplicate:
                return "Duplicate"
            case .addToCollection:
                return "Add to Collection"
            case .viewDetails:
                return "View Details"
            case .editMetadata:
                return "Edit Metadata"
            }
        }
        
        var systemImage: String {
            switch self {
            case .share:
                return "square.and.arrow.up"
            case .copy:
                return "doc.on.doc"
            case .delete:
                return "trash"
            case .tag:
                return "tag"
            case .favorite:
                return "heart"
            case .export:
                return "square.and.arrow.down"
            case .duplicate:
                return "plus.square.on.square"
            case .addToCollection:
                return "folder.badge.plus"
            case .viewDetails:
                return "info.circle"
            case .editMetadata:
                return "pencil.circle"
            }
        }
        
        var destructive: Bool {
            switch self {
            case .delete:
                return true
            default:
                return false
            }
        }
        
        var hapticPattern: HapticFeedbackService.HapticPattern {
            switch self {
            case .share:
                return .shareAction
            case .copy:
                return .copyAction
            case .delete:
                return .deleteConfirmation
            case .tag:
                return .tagAction
            default:
                return .quickActionTrigger
            }
        }
    }
    
    // MARK: - Menu Configuration
    
    struct MenuConfiguration {
        let actions: [MenuAction]
        let enableHaptics: Bool
        let animationDuration: TimeInterval
        let menuAppearanceDelay: TimeInterval
        let dismissAfterAction: Bool
        
        static let standard = MenuConfiguration(
            actions: [.share, .copy, .favorite, .tag, .delete],
            enableHaptics: true,
            animationDuration: 0.3,
            menuAppearanceDelay: 0.1,
            dismissAfterAction: true
        )
        
        static let minimal = MenuConfiguration(
            actions: [.share, .copy, .delete],
            enableHaptics: true,
            animationDuration: 0.25,
            menuAppearanceDelay: 0.05,
            dismissAfterAction: true
        )
        
        static let extended = MenuConfiguration(
            actions: [.share, .copy, .favorite, .tag, .export, .duplicate, .addToCollection, .viewDetails, .delete],
            enableHaptics: true,
            animationDuration: 0.35,
            menuAppearanceDelay: 0.15,
            dismissAfterAction: true
        )
    }
    
    // MARK: - Batch Selection
    
    struct BatchSelection {
        var selectedItems: Set<UUID> = []
        var isActive: Bool = false
        var lastModified: Date = Date()
        
        @MainActor mutating func toggle(_ id: UUID) {
            if selectedItems.contains(id) {
                selectedItems.remove(id)
                Task { @MainActor in
                    HapticFeedbackService.shared.triggerHaptic(.batchSelectionRemove)
                }
            } else {
                selectedItems.insert(id)
                Task { @MainActor in
                    HapticFeedbackService.shared.triggerHaptic(.batchSelectionAdd)
                }
            }
            lastModified = Date()
        }
        
        @MainActor mutating func selectAll(_ ids: [UUID]) {
            selectedItems = Set(ids)
            lastModified = Date()
            Task { @MainActor in
                HapticFeedbackService.shared.triggerHaptic(.batchSelectionStart)
            }
        }
        
        mutating func clear() {
            selectedItems.removeAll()
            isActive = false
            lastModified = Date()
        }
        
        var count: Int {
            selectedItems.count
        }
        
        var isEmpty: Bool {
            selectedItems.isEmpty
        }
    }
    
    // MARK: - Published Properties
    
    @Published var batchSelection = BatchSelection()
    @Published var currentMenu: MenuConfiguration?
    @Published var isMenuVisible = false
    @Published var menuPosition: CGPoint = .zero
    @Published var currentScreenshot: Screenshot? = nil
    @Published var lastActionResult: ActionResult?
    
    struct ActionResult {
        let action: MenuAction
        let success: Bool
        let timestamp: Date
        let itemsAffected: Int
        let errorMessage: String?
    }
    
    // MARK: - Private Properties
    
    private let hapticService = HapticFeedbackService.shared
    private var menuDismissTimer: Timer?
    private var actionHistory: [ActionResult] = []
    
    private init() {}
    
    // MARK: - Menu Presentation
    
    /// Shows a contextual menu at the specified position
    /// - Parameters:
    ///   - configuration: Menu configuration to use
    ///   - position: Position to show the menu
    ///   - item: Optional specific item for context
    func showMenu(
        configuration: MenuConfiguration = .standard,
        at position: CGPoint,
        for item: Screenshot? = nil
    ) {
        print("🎯 ContextualMenuService.showMenu called at position: \(position) for item: \(item?.id.uuidString ?? "nil")")
        guard !isMenuVisible else { 
            print("🎯 Menu already visible, ignoring request")
            return 
        }
        
        currentMenu = configuration
        menuPosition = position
        currentScreenshot = item // Store the screenshot context
        
        if configuration.enableHaptics {
            hapticService.triggerHaptic(.menuAppear)
        }
        
        withAnimation(.spring(response: configuration.animationDuration, dampingFraction: 0.8)) {
            isMenuVisible = true
        }
        
        print("🎯 Menu should now be visible: \(isMenuVisible)")
        
        // Auto-dismiss timer
        scheduleMenuDismissal(after: 10.0) // 10 seconds auto-dismiss
    }
    
    /// Dismisses the current contextual menu
    /// - Parameter animated: Whether to animate the dismissal
    func dismissMenu(animated: Bool = true) {
        print("🎯 ContextualMenuService.dismissMenu called")
        guard isMenuVisible else { 
            print("🎯 Menu not visible, ignoring dismiss request")
            return 
        }
        
        menuDismissTimer?.invalidate()
        
        if currentMenu?.enableHaptics == true {
            hapticService.triggerHaptic(.menuDismiss)
        }
        
        if animated {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                isMenuVisible = false
            }
        } else {
            isMenuVisible = false
        }
        
        print("🎯 Menu visibility set to: \(isMenuVisible)")
        
        // Clear menu after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.currentMenu = nil
            self.currentScreenshot = nil // Clear screenshot context
        }
    }
    
    // MARK: - Action Execution
    
    /// Executes a menu action for a single screenshot
    /// - Parameters:
    ///   - action: The action to execute
    ///   - screenshot: The target screenshot
    ///   - sourceView: Optional source view for animations
    func executeAction(_ action: MenuAction, for screenshot: Screenshot, from sourceView: UIView? = nil) {
        print("🎯 ContextualMenuService.executeAction called: \(action.title) for screenshot: \(screenshot.id)")
        executeAction(action, for: [screenshot], from: sourceView)
    }
    
    /// Executes a menu action for multiple screenshots
    /// - Parameters:
    ///   - action: The action to execute
    ///   - screenshots: The target screenshots
    ///   - sourceView: Optional source view for animations
    func executeAction(_ action: MenuAction, for screenshots: [Screenshot], from sourceView: UIView? = nil) {
        print("🎯 ContextualMenuService.executeAction called: \(action.title) for \(screenshots.count) screenshots")
        guard !screenshots.isEmpty else { 
            print("🎯 ERROR: No screenshots provided for action")
            return 
        }
        
        // Trigger haptic feedback
        hapticService.triggerHaptic(action.hapticPattern)
        
        // Dismiss menu if configured
        if currentMenu?.dismissAfterAction == true {
            dismissMenu()
        }
        
        // Execute the action using QuickActionService
        Task {
            print("🎯 Calling QuickActionService.executeQuickAction")
            await QuickActionService.shared.executeQuickAction(action, on: screenshots, from: sourceView)
            
            await MainActor.run {
                // Clear batch selection if action was successful and affected multiple items
                if screenshots.count > 1 {
                    batchSelection.clear()
                }
            }
        }
    }
    
    // MARK: - Batch Selection Management
    
    /// Starts batch selection mode
    func startBatchSelection() {
        hapticService.triggerHaptic(.batchSelectionStart)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            batchSelection.isActive = true
        }
    }
    
    /// Ends batch selection mode
    func endBatchSelection() {
        hapticService.triggerHaptic(.menuDismiss)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            batchSelection.clear()
        }
    }
    
    /// Toggles selection for a screenshot
    /// - Parameter screenshot: The screenshot to toggle
    func toggleSelection(for screenshot: Screenshot) {
        batchSelection.toggle(screenshot.id)
    }
    
    /// Selects all screenshots
    /// - Parameter screenshots: All available screenshots
    func selectAll(_ screenshots: [Screenshot]) {
        batchSelection.selectAll(screenshots.map { $0.id })
    }
    
    // MARK: - Quick Action Shortcuts
    
    /// Shares screenshots using the system share sheet
    /// - Parameter screenshots: Screenshots to share
    func shareScreenshots(_ screenshots: [Screenshot]) {
        executeAction(.share, for: screenshots)
    }
    
    /// Copies screenshots to the clipboard
    /// - Parameter screenshots: Screenshots to copy
    func copyScreenshots(_ screenshots: [Screenshot]) {
        executeAction(.copy, for: screenshots)
    }
    
    /// Deletes screenshots with confirmation
    /// - Parameter screenshots: Screenshots to delete
    func deleteScreenshots(_ screenshots: [Screenshot]) {
        executeAction(.delete, for: screenshots)
    }
    
    // MARK: - Private Methods
    
    private func scheduleMenuDismissal(after delay: TimeInterval) {
        menuDismissTimer?.invalidate()
        menuDismissTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor in
                self.dismissMenu()
            }
        }
    }
    
}

// MARK: - Contextual Menu View Components

struct ContextualMenuOverlay: View {
    @StateObject private var menuService = ContextualMenuService.shared
    @State private var animationOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            if menuService.isMenuVisible, let menu = menuService.currentMenu {
                // Background overlay
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                    .onTapGesture {
                        print("🎯 Background tapped, dismissing menu")
                        menuService.dismissMenu()
                    }
                
                // Menu content
                ContextualMenuContent(configuration: menu, screenshot: menuService.currentScreenshot)
                    .position(menuService.menuPosition)
                    .offset(animationOffset)
                    .onAppear {
                        print("🎯 Menu is visible with \(menu.actions.count) actions")
                        print("🎯 Menu content appeared")
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            animationOffset = .zero
                        }
                    }
                    .onDisappear {
                        print("🎯 Menu content disappeared")
                        animationOffset = CGSize(width: 0, height: -20)
                    }
            }
        }
        .allowsHitTesting(menuService.isMenuVisible)
    }
}

struct ContextualMenuContent: View {
    let configuration: ContextualMenuService.MenuConfiguration
    let screenshot: Screenshot?
    @StateObject private var menuService = ContextualMenuService.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(configuration.actions) { action in
                MenuActionButton(action: action) {
                    print("🎯 Menu action tapped: \(action.title) for screenshot: \(screenshot?.id.uuidString ?? "nil")")
                    if let screenshot = screenshot {
                        menuService.executeAction(action, for: screenshot)
                    } else {
                        print("🎯 ERROR: No screenshot available for action")
                    }
                    menuService.dismissMenu()
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .modalMaterial(cornerRadius: 16)
        .shadow(radius: 20, y: 10)
        .fixedSize() // Allow content to size itself naturally
        .onAppear {
            print("🎯 Rendering menu content for screenshot: \(screenshot?.id.uuidString ?? "nil")")
        }
    }
}

struct MenuActionButton: View {
    let action: ContextualMenuService.MenuAction
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("Button tapped for action: \(action.title)")
            onTap()
        }) {
            HStack(spacing: 12) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(action.destructive ? .red : .primary)
                    .frame(width: 20)
                
                Text(action.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(action.destructive ? .red : .primary)
                    .frame(minWidth: 80, alignment: .leading) // Minimum width for consistency
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0.0,
            maximumDistance: .infinity,
            perform: { },
            onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }
        )
    }
}

// MARK: - Batch Selection UI Components

struct BatchSelectionToolbar: View {
    @StateObject private var menuService = ContextualMenuService.shared
    let screenshots: [Screenshot]
    
    private var selectedScreenshots: [Screenshot] {
        screenshots.filter { menuService.batchSelection.selectedItems.contains($0.id) }
    }
    
    var body: some View {
        if menuService.batchSelection.isActive {
            HStack {
                Button("Cancel") {
                    menuService.endBatchSelection()
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(menuService.batchSelection.count) selected")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Menu {
                    Button("Share", systemImage: "square.and.arrow.up") {
                        menuService.shareScreenshots(selectedScreenshots)
                    }
                    
                    Button("Copy", systemImage: "doc.on.doc") {
                        menuService.copyScreenshots(selectedScreenshots)
                    }
                    
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        menuService.deleteScreenshots(selectedScreenshots)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .fontWeight(.medium)
                }
                .disabled(menuService.batchSelection.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Preview and Debug Views

#if DEBUG
struct ContextualMenuTestView: View {
    @StateObject private var menuService = ContextualMenuService.shared
    @State private var testScreenshots: [Screenshot] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Menu Testing Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Contextual Menu Tests")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Button("Show Standard Menu") {
                        menuService.showMenu(
                            configuration: .standard,
                            at: CGPoint(x: 200, y: 300)
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Show Minimal Menu") {
                        menuService.showMenu(
                            configuration: .minimal,
                            at: CGPoint(x: 200, y: 350)
                        )
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Show Extended Menu") {
                        menuService.showMenu(
                            configuration: .extended,
                            at: CGPoint(x: 200, y: 400)
                        )
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
                
                // Batch Selection Testing
                VStack(alignment: .leading, spacing: 12) {
                    Text("Batch Selection Tests")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Button("Start Batch Selection") {
                            menuService.startBatchSelection()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(menuService.batchSelection.isActive)
                        
                        Button("End Batch Selection") {
                            menuService.endBatchSelection()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!menuService.batchSelection.isActive)
                    }
                    
                    Text("Selected: \(menuService.batchSelection.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Contextual Menu")
            .navigationBarTitleDisplayMode(.inline)
        }
        .overlay {
            ContextualMenuOverlay()
        }
    }
}

#Preview {
    ContextualMenuTestView()
}
#endif