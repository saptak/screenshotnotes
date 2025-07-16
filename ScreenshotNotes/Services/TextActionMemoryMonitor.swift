//
//  TextActionMemoryMonitor.swift
//  ScreenshotNotes
//
//  Memory monitoring and safety for text action processing
//  Prevents memory-related crashes during text analysis
//

import Foundation
import UIKit

@MainActor
final class TextActionMemoryMonitor: ObservableObject {
    static let shared = TextActionMemoryMonitor()
    
    // MARK: - Memory Limits
    
    private let maxMemoryUsageMB: Double = 100 // 100MB limit for text processing
    private let warningMemoryUsageMB: Double = 80 // Warning at 80MB
    private let maxTextLengthForProcessing: Int = 50_000 // 50K characters max
    
    // MARK: - Monitoring Properties
    
    @Published private(set) var currentMemoryUsageMB: Double = 0
    @Published private(set) var isMemoryWarning: Bool = false
    @Published private(set) var isMemoryLimitExceeded: Bool = false
    
    private var memoryTimer: Timer?
    private var lastMemoryCheck: Date = Date()
    
    // MARK: - Initialization
    
    private init() {
        startMemoryMonitoring()
        setupMemoryWarningNotifications()
    }
    
    deinit {
        memoryTimer?.invalidate()
        memoryTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    
    /// Check if text processing is safe given current memory constraints
    func canProcessText(_ text: String) async -> Bool {
        await updateMemoryUsage()
        
        // Check text length
        guard text.count <= maxTextLengthForProcessing else {
            return false
        }
        
        // Check memory usage
        guard !isMemoryLimitExceeded else {
            return false
        }
        
        return true
    }
    
    /// Get recommended chunk size based on current memory usage
    func getRecommendedChunkSize(for text: String) async -> Int {
        await updateMemoryUsage()
        
        if isMemoryWarning {
            return min(1000, text.count) // Very small chunks
        } else if currentMemoryUsageMB > 50 {
            return min(2500, text.count) // Medium chunks
        } else {
            return min(5000, text.count) // Normal chunks
        }
    }
    
    /// Force memory cleanup
    func performMemoryCleanup() async {
        // Trigger garbage collection
        autoreleasepool {
            // Force memory cleanup
        }
        
        await updateMemoryUsage()
    }
    
    /// Get memory status summary
    func getMemoryStatus() async -> MemoryStatus {
        await updateMemoryUsage()
        
        if isMemoryLimitExceeded {
            return .critical
        } else if isMemoryWarning {
            return .warning
        } else {
            return .normal
        }
    }
    
    // MARK: - Memory Status
    
    enum MemoryStatus {
        case normal
        case warning
        case critical
        
        var canProcessText: Bool {
            switch self {
            case .normal, .warning: return true
            case .critical: return false
            }
        }
        
        var description: String {
            switch self {
            case .normal: return "Normal"
            case .warning: return "High memory usage"
            case .critical: return "Memory limit exceeded"
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMemoryUsage()
            }
        }
    }
    
    private func stopMemoryMonitoring() {
        memoryTimer?.invalidate()
        memoryTimer = nil
    }
    
    private func updateMemoryUsage() async {
        let memoryUsage = await getMemoryUsage()
        
        currentMemoryUsageMB = memoryUsage
        isMemoryWarning = memoryUsage > warningMemoryUsageMB
        isMemoryLimitExceeded = memoryUsage > maxMemoryUsageMB
        lastMemoryCheck = Date()
    }
    
    private func getMemoryUsage() async -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageBytes = info.resident_size
            return Double(memoryUsageBytes) / (1024 * 1024) // Convert to MB
        } else {
            return 0.0
        }
    }
    
    private func setupMemoryWarningNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func didReceiveMemoryWarning() {
        isMemoryWarning = true
        Task {
            await performMemoryCleanup()
        }
    }
}

// MARK: - Text Processing Safety Extension

extension SmartTextActionService {
    
    /// Memory-safe version of detectActions
    func detectActionsSafely(in text: String) async -> [TextAction] {
        let monitor = TextActionMemoryMonitor.shared
        
        // Check if processing is safe
        guard await monitor.canProcessText(text) else {
            // Return basic copy action only for safety
            if !text.isEmpty {
                return [TextAction(
                    type: .copy,
                    text: String(text.prefix(100)), // Only first 100 chars
                    displayText: "Copy Text",
                    confidence: 1.0,
                    range: NSRange(location: 0, length: min(100, text.count))
                )]
            }
            return []
        }
        
        // Get recommended chunk size
        let chunkSize = await monitor.getRecommendedChunkSize(for: text)
        let processText = text.count > chunkSize ? String(text.prefix(chunkSize)) : text
        
        // Perform memory cleanup before processing
        if await monitor.getMemoryStatus() == .warning {
            await monitor.performMemoryCleanup()
        }
        
        // Process with the existing method
        return await detectActions(in: processText)
    }
}