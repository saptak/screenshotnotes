import SwiftUI
import Combine

/// Enhanced pull-to-refresh service with sophisticated haptic feedback and animation patterns
/// Provides fluid, intuitive refresh experiences with accessibility support
@MainActor
final class EnhancedPullToRefreshService: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var refreshState: RefreshState = .idle
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var isRefreshing: Bool = false
    
    // MARK: - Private Properties
    private let hapticService: HapticFeedbackService
    private let threshold: Double = 80.0
    private let maxProgress: Double = 1.2
    private var lastHapticProgress: Double = 0.0
    private var refreshTask: Task<Void, Never>?
    
    // MARK: - Refresh State
    enum RefreshState {
        case idle
        case pulling
        case triggered
        case refreshing
        case completing
    }
    
    // MARK: - Haptic Patterns
    private enum RefreshHapticPattern {
        case pullStart
        case pullProgress(Double)
        case pullTriggered
        case refreshStart
        case refreshComplete
        case refreshError
    }
    
    // MARK: - Initialization
    init(hapticService: HapticFeedbackService) {
        self.hapticService = hapticService
    }
    
    // MARK: - Public Methods
    
    /// Updates the pull progress and triggers appropriate haptic feedback
    /// - Parameter offset: The pull offset from the top
    func updateProgress(offset: Double) {
        let newProgress = min(abs(offset) / threshold, maxProgress)
        
        // Only update if progress has changed significantly
        guard abs(newProgress - progress) > 0.01 else { return }
        
        progress = newProgress
        
        // Update refresh state based on progress
        updateRefreshState(for: newProgress)
        
        // Trigger haptic feedback based on progress milestones
        triggerProgressHaptics(progress: newProgress)
    }
    
    /// Triggers refresh if the pull threshold is met
    /// - Parameter action: The refresh action to execute
    func triggerRefresh(_ action: @escaping () async -> Void) {
        guard refreshState == .triggered else { return }
        
        startRefresh(action)
    }
    
    /// Resets the refresh state when pull is cancelled
    func resetProgress() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            progress = 0.0
            refreshState = .idle
        }
        lastHapticProgress = 0.0
    }
    
    /// Completes the refresh operation with success feedback
    func completeRefresh() {
        guard refreshState == .refreshing else { return }
        
        refreshState = .completing
        triggerHaptic(.refreshComplete)
        
        // Delay to show completion state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.isRefreshing = false
                self.progress = 0.0
                self.refreshState = .idle
            }
        }
    }
    
    /// Handles refresh error with appropriate feedback
    func handleRefreshError() {
        guard refreshState == .refreshing else { return }
        
        triggerHaptic(.refreshError)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isRefreshing = false
            progress = 0.0
            refreshState = .idle
        }
    }
    
    // MARK: - Private Methods
    
    private func updateRefreshState(for progress: Double) {
        let newState: RefreshState
        
        switch progress {
        case 0.0:
            newState = .idle
        case 0.01..<1.0:
            newState = .pulling
        case 1.0...:
            newState = isRefreshing ? .refreshing : .triggered
        default:
            newState = .idle
        }
        
        if newState != refreshState {
            refreshState = newState
        }
    }
    
    private func triggerProgressHaptics(progress: Double) {
        // Trigger haptic feedback at specific progress milestones
        let milestones: [Double] = [0.2, 0.5, 0.8, 1.0]
        
        for milestone in milestones {
            if progress >= milestone && lastHapticProgress < milestone {
                let pattern: RefreshHapticPattern = milestone >= 1.0 ? .pullTriggered : .pullProgress(milestone)
                triggerHaptic(pattern)
                lastHapticProgress = milestone
                break
            }
        }
        
        // Reset haptic progress when pulling back
        if progress < lastHapticProgress - 0.1 {
            lastHapticProgress = max(0.0, progress)
        }
    }
    
    private func startRefresh(_ action: @escaping () async -> Void) {
        guard refreshState == .triggered else { return }
        
        isRefreshing = true
        refreshState = .refreshing
        triggerHaptic(.refreshStart)
        
        refreshTask?.cancel()
        refreshTask = Task {
            await action()
            
            // Ensure UI updates happen on main thread
            await MainActor.run {
                completeRefresh()
            }
        }
    }
    
    private func triggerHaptic(_ pattern: RefreshHapticPattern) {
        switch pattern {
        case .pullStart:
            hapticService.triggerHaptic(.light, intensity: 0.3)
        case .pullProgress(let progress):
            let intensity = 0.2 + (progress * 0.3)
            hapticService.triggerHaptic(.light, intensity: intensity)
        case .pullTriggered:
            hapticService.triggerHaptic(.medium, intensity: 0.8)
        case .refreshStart:
            hapticService.triggerHaptic(.success, intensity: 0.9)
        case .refreshComplete:
            hapticService.triggerHaptic(.success, intensity: 1.0)
        case .refreshError:
            hapticService.triggerHaptic(.error, intensity: 0.7)
        }
    }
}

// MARK: - SwiftUI Integration

/// Custom pull-to-refresh modifier with enhanced feedback
struct EnhancedPullToRefresh: ViewModifier {
    let action: () async -> Void
    @StateObject private var refreshService: EnhancedPullToRefreshService
    @State private var dragOffset: CGSize = .zero
    
    init(action: @escaping () async -> Void, hapticService: HapticFeedbackService) {
        self.action = action
        self._refreshService = StateObject(wrappedValue: EnhancedPullToRefreshService(hapticService: hapticService))
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                if offset > 0 {
                    refreshService.updateProgress(offset: offset)
                } else {
                    refreshService.resetProgress()
                }
            }
            .onChange(of: refreshService.refreshState) { _, state in
                if state == .triggered && !refreshService.isRefreshing {
                    refreshService.triggerRefresh(action)
                }
            }
            .overlay(alignment: .top) {
                if refreshService.progress > 0 {
                    PullToRefreshIndicator(
                        progress: refreshService.progress,
                        state: refreshService.refreshState,
                        isRefreshing: refreshService.isRefreshing
                    )
                    .offset(y: -60)
                }
            }
    }
}

// ScrollOffsetPreferenceKey is defined in VirtualizedGridView.swift

// MARK: - Pull To Refresh Indicator
private struct PullToRefreshIndicator: View {
    let progress: Double
    let state: EnhancedPullToRefreshService.RefreshState
    let isRefreshing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Progress indicator
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                if isRefreshing {
                    // Spinning refresh indicator
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(progress * 360))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: progress)
                } else {
                    // Progress arc
                    Circle()
                        .trim(from: 0, to: min(progress, 1.0))
                        .stroke(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: progress)
                }
            }
            
            // Status text
            Text(statusText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .scaleEffect(min(progress, 1.0))
        .opacity(min(progress * 2, 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: progress)
    }
    
    private var statusText: String {
        switch state {
        case .idle:
            return "Pull to refresh"
        case .pulling:
            return progress >= 1.0 ? "Release to refresh" : "Pull to refresh"
        case .triggered:
            return "Release to refresh"
        case .refreshing:
            return "Refreshing..."
        case .completing:
            return "Done"
        }
    }
}

// MARK: - View Extension
extension View {
    /// Adds enhanced pull-to-refresh functionality with sophisticated haptic feedback
    /// - Parameters:
    ///   - action: The refresh action to execute
    ///   - hapticService: The haptic feedback service to use
    /// - Returns: The view with enhanced pull-to-refresh functionality
    func enhancedPullToRefresh(action: @escaping () async -> Void, hapticService: HapticFeedbackService) -> some View {
        self.modifier(EnhancedPullToRefresh(action: action, hapticService: hapticService))
    }
}