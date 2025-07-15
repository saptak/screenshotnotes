import SwiftUI
import Foundation
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// Quick action service for executing contextual menu actions with sophisticated animations and feedback
/// Provides implementation for share, copy, delete, tag, and other quick actions
@MainActor
final class QuickActionService: NSObject, ObservableObject, UIDocumentPickerDelegate {
    
    // MARK: - Singleton
    static let shared = QuickActionService()
    
    // MARK: - Action Status Tracking
    
    enum ActionStatus {
        case idle
        case executing
        case success
        case failed(Error)
        case cancelled
    }
    
    @Published var currentActionStatus: ActionStatus = .idle
    @Published var lastExecutedAction: ContextualMenuService.MenuAction?
    @Published var actionProgress: Double = 0.0
    @Published var actionMessage: String = ""
    
    // MARK: - Dependencies
    
    private let hapticService = HapticFeedbackService.shared
    private let glassSystem = GlassDesignSystem.shared
    
    // MARK: - Action History
    
    struct ActionRecord {
        let action: ContextualMenuService.MenuAction
        let screenshotCount: Int
        let timestamp: Date
        let duration: TimeInterval
        let success: Bool
        let errorMessage: String?
    }
    
    @Published var actionHistory: [ActionRecord] = []
    
    override private init() {}
    
    // MARK: - Public Action Interface
    
    /// Executes a quick action with sophisticated feedback and animation
    /// - Parameters:
    ///   - action: The action to execute
    ///   - screenshots: Target screenshots
    ///   - sourceView: Optional source view for animations
    func executeQuickAction(
        _ action: ContextualMenuService.MenuAction,
        on screenshots: [Screenshot],
        from sourceView: UIView? = nil
    ) async {
        guard case .idle = currentActionStatus else { return }
        
        let startTime = Date()
        lastExecutedAction = action
        
        await updateActionStatus(.executing)
        await updateActionMessage("Preparing \(action.title.lowercased())...")
        
        // Prepare haptic feedback
        hapticService.prepareHapticGenerators()
        
        // Execute the specific action
        switch action {
        case .share:
            await executeShareAction(screenshots, from: sourceView)
            
        case .copy:
            await executeCopyAction(screenshots)
            
        case .delete:
            await executeDeleteAction(screenshots)
            
        case .tag:
            await executeTagAction(screenshots)
            
        case .favorite:
            await executeFavoriteAction(screenshots)
            
        case .export:
            await executeExportAction(screenshots)
            
        case .duplicate:
            await executeDuplicateAction(screenshots)
            
        case .addToCollection:
            await executeAddToCollectionAction(screenshots)
            
        case .viewDetails:
            await executeViewDetailsAction(screenshots.first)
            
        case .editMetadata:
            await executeEditMetadataAction(screenshots.first)
        }
        
        // Record successful action
        let duration = Date().timeIntervalSince(startTime)
        recordAction(action, screenshots: screenshots, duration: duration, success: true, error: nil)
        
        await updateActionStatus(.success)
        hapticService.triggerHaptic(.successFeedback)
        
        // Auto-reset after delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        await updateActionStatus(.idle)
    }
    
    // MARK: - Specific Action Implementations
    
    private func executeShareAction(_ screenshots: [Screenshot], from sourceView: UIView?) async {
        await updateActionMessage("Preparing images for sharing...")
        await updateProgress(0.2)
        
        let images = screenshots.compactMap { UIImage(data: $0.imageData) }
        guard !images.isEmpty else {
            await updateActionStatus(.failed(QuickActionError.noValidImages))
            return
        }
        
        await updateProgress(0.6)
        await updateActionMessage("Opening share sheet...")
        
        await MainActor.run {
            let activityVC = UIActivityViewController(activityItems: images, applicationActivities: nil)
            
            // Configure for iPad
            if let popover = activityVC.popoverPresentationController {
                if let sourceView = sourceView {
                    popover.sourceView = sourceView
                    popover.sourceRect = sourceView.bounds
                } else {
                    // Use current window scene instead of deprecated windows
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        popover.sourceView = window
                        popover.sourceRect = CGRect(x: 200, y: 200, width: 1, height: 1)
                    }
                }
            }
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
        
        await updateProgress(1.0)
        await updateActionMessage("Share sheet opened")
    }
    
    private func executeCopyAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Copying to clipboard...")
        await updateProgress(0.3)
        
        await MainActor.run {
            // Clear the pasteboard first to ensure clean state
            UIPasteboard.general.items = []
            
            if screenshots.count == 1 {
                guard let image = UIImage(data: screenshots[0].imageData) else {
                    Task {
                        await updateActionStatus(.failed(QuickActionError.noValidImages))
                    }
                    return
                }
                
                // Set multiple representations for better compatibility
                var items: [String: Any] = [:]
                
                // Add image as UIImage (preferred by most apps)
                items[UTType.image.identifier] = image
                
                // Add as PNG data for universal compatibility
                if let pngData = image.pngData() {
                    items[UTType.png.identifier] = pngData
                }
                
                // Add as JPEG data as fallback
                if let jpegData = image.jpegData(compressionQuality: 0.9) {
                    items[UTType.jpeg.identifier] = jpegData
                }
                
                UIPasteboard.general.items = [items]
                print("✅ Single image copied to clipboard with \(items.count) representations")
                
            } else {
                let images = screenshots.compactMap { UIImage(data: $0.imageData) }
                guard !images.isEmpty else {
                    Task {
                        await updateActionStatus(.failed(QuickActionError.noValidImages))
                    }
                    return
                }
                
                // For multiple images, create separate items
                var pasteboardItems: [[String: Any]] = []
                
                for image in images {
                    var items: [String: Any] = [:]
                    
                    // Add image as UIImage
                    items[UTType.image.identifier] = image
                    
                    // Add as PNG data
                    if let pngData = image.pngData() {
                        items[UTType.png.identifier] = pngData
                    }
                    
                    pasteboardItems.append(items)
                }
                
                UIPasteboard.general.items = pasteboardItems
                print("✅ \(images.count) images copied to clipboard")
            }
        }
        
        await updateProgress(0.7)
        await updateActionMessage(screenshots.count == 1 ? "Image copied to clipboard" : "\(screenshots.count) images copied to clipboard")
        await updateProgress(1.0)
    }
    
    private func executeDeleteAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Confirming deletion...")
        await updateProgress(0.2)
        
        // Show confirmation dialog
        let confirmed = await showDeleteConfirmation(count: screenshots.count)
        
        guard confirmed else {
            await updateActionStatus(.cancelled)
            return
        }
        
        await updateProgress(0.6)
        await updateActionMessage("Deleting screenshots...")
        
        // Delete screenshots from SwiftData model context
        await MainActor.run {
            // Get the model context from the first screenshot (they should all share the same context)
            if let modelContext = screenshots.first?.modelContext {
                for screenshot in screenshots {
                    modelContext.delete(screenshot)
                }
                
                do {
                    try modelContext.save()
                    print("✅ Successfully deleted \(screenshots.count) screenshot(s)")
                    
                    // Trigger mind map regeneration after deletion
                    Task {
                        await BackgroundSemanticProcessor.shared.triggerMindMapRegeneration(in: modelContext)
                    }
                } catch {
                    print("❌ Failed to delete screenshots: \(error)")
                }
            } else {
                print("❌ No model context available for screenshot deletion")
            }
        }
        
        await updateProgress(1.0)
        await updateActionMessage("Screenshots deleted")
    }
    
    private func executeTagAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Opening tag editor...")
        await updateProgress(0.5)

        // Show tag editor
        if let tags = await showTagEditor(for: screenshots) {
            // Apply tags to screenshots
            await applyTags(tags, to: screenshots)
            await updateProgress(1.0)
            await updateActionMessage("Tags applied")
        } else {
            // User cancelled
            await updateActionStatus(.cancelled)
        }
    }
    
    private func executeFavoriteAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Updating favorites...")
        await updateProgress(0.4)

        await MainActor.run {
            if let modelContext = screenshots.first?.modelContext {
                for screenshot in screenshots {
                    screenshot.isFavorite.toggle()
                }

                do {
                    try modelContext.save()
                    let isFavorite = screenshots.first?.isFavorite ?? false
                    let message = isFavorite ? "Added to favorites" : "Removed from favorites"
                    Task {
                        await updateActionMessage(message)
                    }
                    print("✅ Successfully updated favorites for \(screenshots.count) screenshot(s)")
                } catch {
                    print("❌ Failed to update favorites: \(error)")
                    Task {
                        await updateActionMessage("Failed to update favorites")
                    }
                }
            }
        }

        await updateProgress(1.0)
    }
    
    private func executeExportAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Preparing export...")
        await updateProgress(0.2)

        let images = screenshots.compactMap { UIImage(data: $0.imageData) }
        guard !images.isEmpty else {
            await updateActionStatus(.failed(QuickActionError.noValidImages))
            return
        }

        await updateProgress(0.6)
        await updateActionMessage("Presenting export dialog...")

        if let url = await showExportDialog() {
            await exportImages(images, to: url)
        }

        await updateProgress(1.0)
        await updateActionMessage("Export complete")
    }
    
    private func executeDuplicateAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Creating duplicates...")
        await updateProgress(0.3)

        await MainActor.run {
            if let modelContext = screenshots.first?.modelContext {
                for screenshot in screenshots {
                    let newScreenshot = Screenshot(
                        imageData: screenshot.imageData,
                        filename: "\(screenshot.filename)_copy",
                        timestamp: Date(),
                        assetIdentifier: nil
                    )
                    modelContext.insert(newScreenshot)
                }

                do {
                    try modelContext.save()
                    print("✅ Successfully duplicated \(screenshots.count) screenshot(s)")
                } catch {
                    print("❌ Failed to duplicate screenshots: \(error)")
                }
            }
        }

        await updateActionMessage("Screenshots duplicated")

        await updateProgress(1.0)
    }
    
    private func executeAddToCollectionAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Opening collection picker...")
        await updateProgress(0.3)
        
        // Show collection picker
        if let collections = await showCollectionPicker(for: screenshots) {
            await updateProgress(0.7)
            await updateActionMessage("Adding to collections...")
            
            // Add screenshots to selected collections
            await addScreenshotsToCollections(screenshots, collections: collections)
            
            await updateProgress(1.0)
            let message = collections.count == 1 ? 
                "Added to \(collections[0].name)" : 
                "Added to \(collections.count) collections"
            await updateActionMessage(message)
        } else {
            // User cancelled
            await updateActionStatus(.cancelled)
        }
    }
    
    private func executeViewDetailsAction(_ screenshot: Screenshot?) async {
        await updateActionMessage("Opening details...")
        await updateProgress(0.5)
        
        guard let screenshot = screenshot else {
            await updateActionStatus(.failed(QuickActionError.invalidScreenshot))
            return
        }
        
        await updateProgress(0.8)
        await updateActionMessage("Navigating to detail view...")
        
        // Show detail view
        await showDetailView(for: screenshot)
        
        await updateProgress(1.0)
        await updateActionMessage("Detail view opened")
    }
    
    private func executeEditMetadataAction(_ screenshot: Screenshot?) async {
        await updateActionMessage("Opening metadata editor...")
        await updateProgress(0.3)
        
        guard let screenshot = screenshot else {
            await updateActionStatus(.failed(QuickActionError.invalidScreenshot))
            return
        }
        
        await updateProgress(0.7)
        await updateActionMessage("Loading metadata editor...")
        
        // Show metadata editor
        await showMetadataEditor(for: screenshot)
        
        await updateProgress(1.0)
        await updateActionMessage("Metadata editor opened")
    }

    private func showExportDialog() async -> URL? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
                documentPicker.delegate = self
                documentPicker.allowsMultipleSelection = false
                self.documentPickerContinuation = continuation

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(documentPicker, animated: true)
                }
            }
        }
    }

    private func exportImages(_ images: [UIImage], to directoryURL: URL) async {
        for (index, image) in images.enumerated() {
            let filename = "screenshot_\(index).png"
            let fileURL = directoryURL.appendingPathComponent(filename)

            if let data = image.pngData() {
                do {
                    try data.write(to: fileURL)
                    print("✅ Successfully exported image to \(fileURL.path)")
                } catch {
                    print("❌ Failed to export image: \(error)")
                }
            }
        }
    }

    private var documentPickerContinuation: CheckedContinuation<URL?, Never>?
    private var collectionPickerContinuation: CheckedContinuation<[Collection]?, Never>?

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        documentPickerContinuation?.resume(returning: urls.first)
        documentPickerContinuation = nil
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        documentPickerContinuation?.resume(returning: nil)
        documentPickerContinuation = nil
    }

    private func showTagEditor(for screenshots: [Screenshot]) async -> [String]? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Add Tags",
                    message: "Enter tags separated by commas.",
                    preferredStyle: .alert
                )

                alert.addTextField {
                    $0.placeholder = "e.g., work, design, inspiration"
                    // Pre-populate with existing tags
                    let existingTags = screenshots.compactMap { $0.userTags }.flatMap { $0 }.unique()
                    $0.text = existingTags.joined(separator: ", ")
                }

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    continuation.resume(returning: nil)
                })

                alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                    if let textField = alert.textFields?.first,
                       let text = textField.text {
                        let tags = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        continuation.resume(returning: tags)
                    } else {
                        continuation.resume(returning: [])
                    }
                })

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(alert, animated: true)
                }
            }
        }
    }

    private func applyTags(_ tags: [String], to screenshots: [Screenshot]) async {
        await MainActor.run {
            if let modelContext = screenshots.first?.modelContext {
                for screenshot in screenshots {
                    var existingTags = screenshot.userTags ?? []
                    for tag in tags {
                        if !existingTags.contains(tag) {
                            existingTags.append(tag)
                        }
                    }
                    screenshot.userTags = existingTags
                }

                do {
                    try modelContext.save()
                    print("✅ Successfully applied tags to \(screenshots.count) screenshot(s)")
                } catch {
                    print("❌ Failed to apply tags: \(error)")
                }
            }
        }
    }
    
    private func showCollectionPicker(for screenshots: [Screenshot]) async -> [Collection]? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let collectionPickerView = CollectionPickerView(screenshots: screenshots) { collections in
                    continuation.resume(returning: collections.isEmpty ? nil : collections)
                }
                
                let hostingController = UIHostingController(rootView: collectionPickerView)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(hostingController, animated: true)
                }
            }
        }
    }
    
    private func addScreenshotsToCollections(_ screenshots: [Screenshot], collections: [Collection]) async {
        await MainActor.run {
            let collectionService = CollectionService.shared
            
            for collection in collections {
                collectionService.addScreenshots(screenshots, to: collection)
            }
            
            print("✅ Successfully added \(screenshots.count) screenshot(s) to \(collections.count) collection(s)")
        }
    }
    
    private func showDetailView(for screenshot: Screenshot) async {
        await MainActor.run {
            // Create a namespace for hero animations
            let namespace = Namespace().wrappedValue
            
            // For detail view, we need all screenshots for navigation
            // This is a simplified approach - in a real app, you'd get this from the current context
            let allScreenshots = [screenshot] // For now, just the single screenshot
            
            let detailView = ScreenshotDetailView(
                screenshot: screenshot,
                heroNamespace: namespace,
                allScreenshots: allScreenshots,
                onDelete: { deletedScreenshot in
                    // Handle deletion if needed
                    print("Screenshot deleted from detail view: \(deletedScreenshot.filename)")
                }
            )
            
            let hostingController = UIHostingController(rootView: detailView)
            hostingController.modalPresentationStyle = .fullScreen
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(hostingController, animated: true)
            }
        }
    }
    
    private func showMetadataEditor(for screenshot: Screenshot) async {
        await MainActor.run {
            let metadataEditorView = MetadataEditorView(screenshot: screenshot)
            let hostingController = UIHostingController(rootView: metadataEditorView)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(hostingController, animated: true)
            }
        }
    }
    
    // MARK: - Confirmation Dialogs
    
    private func showDeleteConfirmation(count: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Delete Screenshots",
                    message: count == 1 ? "Delete this screenshot?" : "Delete \(count) screenshots?",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    continuation.resume(returning: false)
                })
                
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                    continuation.resume(returning: true)
                })
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(alert, animated: true)
                }
            }
        }
    }
    
    // MARK: - Progress and Status Updates
    
    private func updateActionStatus(_ status: ActionStatus) async {
        await MainActor.run {
            currentActionStatus = status
        }
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            actionProgress = max(0.0, min(1.0, progress))
        }
    }
    
    private func updateActionMessage(_ message: String) async {
        await MainActor.run {
            actionMessage = message
        }
    }
    
    // MARK: - Action History Management
    
    private func recordAction(
        _ action: ContextualMenuService.MenuAction,
        screenshots: [Screenshot],
        duration: TimeInterval,
        success: Bool,
        error: Error?
    ) {
        let record = ActionRecord(
            action: action,
            screenshotCount: screenshots.count,
            timestamp: Date(),
            duration: duration,
            success: success,
            errorMessage: error?.localizedDescription
        )
        
        actionHistory.append(record)
        
        // Keep history manageable
        if actionHistory.count > 100 {
            actionHistory.removeFirst(50)
        }
    }
    
    // MARK: - Error Types
    
    enum QuickActionError: LocalizedError {
        case noValidImages
        case invalidScreenshot
        case actionCancelled
        case networkError
        case permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .noValidImages:
                return "No valid images found"
            case .invalidScreenshot:
                return "Invalid screenshot data"
            case .actionCancelled:
                return "Action was cancelled"
            case .networkError:
                return "Network connection required"
            case .permissionDenied:
                return "Permission denied"
            }
        }
    }
}

// MARK: - Quick Action Progress View

struct QuickActionProgressView: View {
    @StateObject private var actionService = QuickActionService.shared
    
    var body: some View {
        if case .executing = actionService.currentActionStatus {
            VStack(spacing: 12) {
                ProgressView(value: actionService.actionProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    .scaleEffect(y: 2.0)
                
                VStack(spacing: 4) {
                    if let action = actionService.lastExecutedAction {
                        Text(action.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(actionService.actionMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .modalMaterial(cornerRadius: 16)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Debug View for Quick Actions

#if DEBUG
struct QuickActionTestView: View {
    var body: some View {
        Text("Quick Action Test")
    }
}

#Preview {
    Text("Quick Action Test")
}
#endif

extension Sequence where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}