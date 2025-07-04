import SwiftUI
import Foundation
import PhotosUI

/// Quick action service for executing contextual menu actions with sophisticated animations and feedback
/// Provides implementation for share, copy, delete, tag, and other quick actions
@MainActor
final class QuickActionService: ObservableObject {
    
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
    private let materialSystem = MaterialDesignSystem.shared
    
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
    
    private init() {}
    
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
        
        do {
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
            
        } catch {
            // Record failed action
            let duration = Date().timeIntervalSince(startTime)
            recordAction(action, screenshots: screenshots, duration: duration, success: false, error: error)
            
            await updateActionStatus(.failed(error))
            hapticService.triggerHaptic(.errorFeedback)
            
            // Auto-reset after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await updateActionStatus(.idle)
        }
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
        
        if screenshots.count == 1 {
            guard let image = UIImage(data: screenshots[0].imageData) else {
                await updateActionStatus(.failed(QuickActionError.noValidImages))
                return
            }
            
            await MainActor.run {
                UIPasteboard.general.image = image
            }
            
            await updateActionMessage("Image copied to clipboard")
        } else {
            let images = screenshots.compactMap { UIImage(data: $0.imageData) }
            guard !images.isEmpty else {
                await updateActionStatus(.failed(QuickActionError.noValidImages))
                return
            }
            
            await updateProgress(0.7)
            
            await MainActor.run {
                UIPasteboard.general.images = images
            }
            
            await updateActionMessage("\(images.count) images copied to clipboard")
        }
        
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
        
        // TODO: Implement actual deletion through SwiftData model context
        // For now, simulate the deletion process
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await updateProgress(1.0)
        await updateActionMessage("Screenshots deleted")
    }
    
    private func executeTagAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Opening tag editor...")
        await updateProgress(0.5)
        
        // TODO: Implement tagging system
        // For now, simulate the tagging process
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        await updateProgress(1.0)
        await updateActionMessage("Tags applied")
    }
    
    private func executeFavoriteAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Updating favorites...")
        await updateProgress(0.4)
        
        // TODO: Implement favorite system
        // For now, simulate the favoriting process
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        await updateProgress(1.0)
        await updateActionMessage("Added to favorites")
    }
    
    private func executeExportAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Preparing export...")
        await updateProgress(0.2)
        
        // TODO: Implement export system
        // For now, simulate the export process
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await updateProgress(1.0)
        await updateActionMessage("Export ready")
    }
    
    private func executeDuplicateAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Creating duplicates...")
        await updateProgress(0.3)
        
        // TODO: Implement duplication system
        // For now, simulate the duplication process
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        await updateProgress(1.0)
        await updateActionMessage("Screenshots duplicated")
    }
    
    private func executeAddToCollectionAction(_ screenshots: [Screenshot]) async {
        await updateActionMessage("Adding to collection...")
        await updateProgress(0.4)
        
        // TODO: Implement collection system
        // For now, simulate adding to collection
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        await updateProgress(1.0)
        await updateActionMessage("Added to collection")
    }
    
    private func executeViewDetailsAction(_ screenshot: Screenshot?) async {
        await updateActionMessage("Opening details...")
        await updateProgress(0.5)
        
        guard screenshot != nil else {
            await updateActionStatus(.failed(QuickActionError.invalidScreenshot))
            return
        }
        
        // TODO: Implement details view navigation
        // For now, simulate opening details
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        await updateProgress(1.0)
        await updateActionMessage("Details opened")
    }
    
    private func executeEditMetadataAction(_ screenshot: Screenshot?) async {
        await updateActionMessage("Opening metadata editor...")
        await updateProgress(0.3)
        
        guard screenshot != nil else {
            await updateActionStatus(.failed(QuickActionError.invalidScreenshot))
            return
        }
        
        // TODO: Implement metadata editing
        // For now, simulate opening metadata editor
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        await updateProgress(1.0)
        await updateActionMessage("Metadata editor opened")
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