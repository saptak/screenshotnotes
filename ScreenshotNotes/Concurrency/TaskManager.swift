import Foundation
import SwiftUI

/// Centralized task management system to eliminate race conditions and coordinate async operations
/// Implements Iteration 8.5.3.1: Task Synchronization Framework
@MainActor
public final class TaskManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = TaskManager()
    
    // MARK: - Task Priority System
    
    public enum TaskPriority: Int, CaseIterable, Comparable {
        case critical = 0    // User-initiated actions (import, delete)
        case high = 1        // UI updates, search
        case normal = 2      // Background processing
        case low = 3         // Cleanup, optimization
        
        public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        var taskPriority: TaskPriority {
            switch self {
            case .critical: return .critical
            case .high: return .high
            case .normal: return .normal
            case .low: return .low
            }
        }
    }
    
    // MARK: - Task Categories
    
    public enum TaskCategory: String, CaseIterable {
        case userInterface = "ui"
        case dataImport = "import"
        case backgroundProcessing = "background"
        case search = "search"
        case cleanup = "cleanup"
        case mindMap = "mindmap"
        case vision = "vision"
        case ocr = "ocr"
        case semantic = "semantic"
    }
    
    // MARK: - Task State
    
    public enum TaskState: Equatable {
        case pending
        case running
        case completed
        case cancelled
        case failed(Error)
        
        public static func == (lhs: TaskState, rhs: TaskState) -> Bool {
            switch (lhs, rhs) {
            case (.pending, .pending),
                 (.running, .running),
                 (.completed, .completed),
                 (.cancelled, .cancelled):
                return true
            case (.failed, .failed):
                return true // We consider all failed states equal regardless of the specific error
            default:
                return false
            }
        }
    }
    
    // MARK: - Managed Task
    
    public struct ManagedTask: Identifiable {
        public let id = UUID()
        public let category: TaskCategory
        public let priority: TaskPriority
        public let description: String
        public let createdAt: Date
        public var state: TaskState
        public var startedAt: Date?
        public var completedAt: Date?
        public let task: Task<Void, Never>
        
        public var duration: TimeInterval? {
            guard let startedAt = startedAt else { return nil }
            let endTime = completedAt ?? Date()
            return endTime.timeIntervalSince(startedAt)
        }
        
        public var isActive: Bool {
            switch state {
            case .pending, .running:
                return true
            case .completed, .cancelled, .failed:
                return false
            }
        }
    }
    
    // MARK: - Published State
    
    @Published public private(set) var activeTasks: [ManagedTask] = []
    @Published public private(set) var taskHistory: [ManagedTask] = []
    @Published public private(set) var isProcessingCriticalTasks = false
    @Published public private(set) var resourceUsage: ResourceUsage = ResourceUsage()
    
    // MARK: - Resource Management
    
    public struct ResourceUsage {
        public var activeCriticalTasks = 0
        public var activeHighTasks = 0
        public var activeNormalTasks = 0
        public var activeLowTasks = 0
        public var totalMemoryUsage: Int64 = 0
        
        public var totalActiveTasks: Int {
            activeCriticalTasks + activeHighTasks + activeNormalTasks + activeLowTasks
        }
        
        public var isUnderPressure: Bool {
            totalActiveTasks > 10 || activeCriticalTasks > 3
        }
    }
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let maxConcurrentCriticalTasks = 3
        static let maxConcurrentHighTasks = 5
        static let maxConcurrentNormalTasks = 8
        static let maxConcurrentLowTasks = 10
        static let taskHistoryLimit = 100
        static let deadlockDetectionInterval: TimeInterval = 30.0
        static let taskTimeoutInterval: TimeInterval = 300.0 // 5 minutes
    }
    
    // MARK: - Internal State
    
    private var taskGroups: [TaskCategory: TaskGroup<Void>] = [:]
    private var deadlockDetectionTimer: Timer?
    private let taskQueue = DispatchQueue(label: "com.screenshotnotes.taskmanager", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init() {
        setupDeadlockDetection()
        setupMemoryPressureMonitoring()
    }
    
    deinit {
        deadlockDetectionTimer?.invalidate()
        // Note: Cannot access @Published properties from deinit
        // Task cleanup will be handled by the system
    }
    
    // MARK: - Public Task Management
    
    /// Execute a task with proper coordination and resource management
    /// - Parameters:
    ///   - category: Task category for grouping and coordination
    ///   - priority: Task priority for scheduling
    ///   - description: Human-readable task description
    ///   - operation: The async operation to execute
    /// - Returns: Task identifier for tracking and cancellation
    @discardableResult
    public func execute<T>(
        category: TaskCategory,
        priority: TaskPriority = .normal,
        description: String,
        operation: @escaping () async throws -> T
    ) async -> T? {
        
        // Simplified execution for semantic processing to avoid deadlocks
        if category == .semantic || category == .mindMap {
            print("TaskManager: Direct execution for \(category.rawValue): \(description)")
            do {
                return try await operation()
            } catch {
                print("TaskManager: Direct execution failed for \(description): \(error)")
                return nil
            }
        }
        
        // Check resource limits before creating task
        guard canExecuteTask(priority: priority) else {
            print("TaskManager: Resource limit reached, deferring task: \(description)")
            return await deferTask(category: category, priority: priority, description: description, operation: operation)
        }
        
        let taskId = UUID()
        var managedTask: ManagedTask!
        
        // Create managed task
        let task = Task { @MainActor in
            await updateTaskState(taskId, state: .running)
            
            do {
                let result = try await operation()
                await updateTaskState(taskId, state: .completed)
                return result
            } catch {
                await updateTaskState(taskId, state: .failed(error))
                throw error
            }
        }
        
        managedTask = ManagedTask(
            category: category,
            priority: priority,
            description: description,
            createdAt: Date(),
            state: .pending,
            task: Task {
                _ = await task.result
            }
        )
        
        // Register task
        await registerTask(managedTask, id: taskId)
        
        // Execute with proper coordination
        do {
            let result = try await task.value
            return result
        } catch {
            print("TaskManager: Task failed [\(category.rawValue)]: \(description) - \(error)")
            return nil
        }
    }
    
    /// Execute a group of related tasks with coordination
    /// - Parameters:
    ///   - category: Task category for all tasks in the group
    ///   - priority: Priority for the entire group
    ///   - description: Description of the task group
    ///   - operations: Array of operations to execute
    /// - Returns: Array of results (nil for failed operations)
    public func executeGroup<T>(
        category: TaskCategory,
        priority: TaskPriority = .normal,
        description: String,
        operations: [() async throws -> T]
    ) async -> [T?] {
        
        return await withTaskGroup(of: T?.self) { group in
            var results: [T?] = []
            
            for (index, operation) in operations.enumerated() {
                group.addTask { [weak self] in
                    await self?.execute(
                        category: category,
                        priority: priority,
                        description: "\(description) [\(index + 1)/\(operations.count)]",
                        operation: operation
                    )
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    /// Cancel all tasks in a specific category
    /// - Parameter category: Category of tasks to cancel
    public func cancelTasks(in category: TaskCategory) {
        let tasksToCancel = activeTasks.filter { $0.category == category }
        
        for managedTask in tasksToCancel {
            managedTask.task.cancel()
        }
        
        // Update states
        Task { @MainActor in
            for managedTask in tasksToCancel {
                if let index = activeTasks.firstIndex(where: { $0.id == managedTask.id }) {
                    activeTasks[index].state = .cancelled
                    activeTasks[index].completedAt = Date()
                    moveToHistory(activeTasks[index])
                    activeTasks.remove(at: index)
                }
            }
            updateResourceUsage()
        }
    }
    
    /// Cancel all active tasks
    public func cancelAllTasks() {
        for managedTask in activeTasks {
            managedTask.task.cancel()
        }
        
        Task { @MainActor in
            for i in activeTasks.indices {
                activeTasks[i].state = .cancelled
                activeTasks[i].completedAt = Date()
            }
            
            taskHistory.append(contentsOf: activeTasks)
            activeTasks.removeAll()
            updateResourceUsage()
        }
    }
    
    /// Wait for all tasks in a category to complete
    /// - Parameter category: Category to wait for
    /// - Parameter timeout: Maximum time to wait (default: 30 seconds)
    public func waitForCompletion(category: TaskCategory, timeout: TimeInterval = 30.0) async {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let activeCategoryTasks = activeTasks.filter { $0.category == category && $0.isActive }
            
            if activeCategoryTasks.isEmpty {
                break
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    // MARK: - Resource Management
    
    private func canExecuteTask(priority: TaskPriority) -> Bool {
        switch priority {
        case .critical:
            return resourceUsage.activeCriticalTasks < Configuration.maxConcurrentCriticalTasks
        case .high:
            return resourceUsage.activeHighTasks < Configuration.maxConcurrentHighTasks
        case .normal:
            return resourceUsage.activeNormalTasks < Configuration.maxConcurrentNormalTasks
        case .low:
            return resourceUsage.activeLowTasks < Configuration.maxConcurrentLowTasks
        }
    }
    
    private func deferTask<T>(
        category: TaskCategory,
        priority: TaskPriority,
        description: String,
        operation: @escaping () async throws -> T
    ) async -> T? {
        // Wait for resources to become available
        while !canExecuteTask(priority: priority) {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Check if we should give up
            if resourceUsage.isUnderPressure && priority == .low {
                print("TaskManager: Abandoning low priority task due to resource pressure: \(description)")
                return nil
            }
        }
        
        // Retry execution
        return await execute(category: category, priority: priority, description: description, operation: operation)
    }
    
    // MARK: - Internal Task Management
    
    private func registerTask(_ managedTask: ManagedTask, id: UUID) async {
        activeTasks.append(managedTask)
        updateResourceUsage()
        
        // Set critical processing flag
        if managedTask.priority == .critical {
            isProcessingCriticalTasks = true
        }
    }
    
    private func updateTaskState(_ taskId: UUID, state: TaskState) async {
        guard let index = activeTasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        activeTasks[index].state = state
        
        switch state {
        case .running:
            activeTasks[index].startedAt = Date()
        case .completed, .cancelled, .failed:
            activeTasks[index].completedAt = Date()
            moveToHistory(activeTasks[index])
            activeTasks.remove(at: index)
        case .pending:
            break
        }
        
        updateResourceUsage()
    }
    
    private func moveToHistory(_ task: ManagedTask) {
        taskHistory.append(task)
        
        // Limit history size
        if taskHistory.count > Configuration.taskHistoryLimit {
            taskHistory.removeFirst(taskHistory.count - Configuration.taskHistoryLimit)
        }
    }
    
    private func updateResourceUsage() {
        var usage = ResourceUsage()
        
        for task in activeTasks where task.isActive {
            switch task.priority {
            case .critical: usage.activeCriticalTasks += 1
            case .high: usage.activeHighTasks += 1
            case .normal: usage.activeNormalTasks += 1
            case .low: usage.activeLowTasks += 1
            }
        }
        
        resourceUsage = usage
        isProcessingCriticalTasks = usage.activeCriticalTasks > 0
    }
    
    // MARK: - Deadlock Detection
    
    private func setupDeadlockDetection() {
        deadlockDetectionTimer = Timer.scheduledTimer(withTimeInterval: Configuration.deadlockDetectionInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.detectDeadlocks()
            }
        }
    }
    
    private func detectDeadlocks() async {
        let now = Date()
        let stuckTasks = activeTasks.filter { task in
            guard let startedAt = task.startedAt else { return false }
            return now.timeIntervalSince(startedAt) > Configuration.taskTimeoutInterval && task.state == .running
        }
        
        if !stuckTasks.isEmpty {
            print("TaskManager: Detected \(stuckTasks.count) potentially stuck tasks")
            
            for task in stuckTasks {
                print("TaskManager: Stuck task - \(task.category.rawValue): \(task.description)")
                task.task.cancel()
            }
        }
    }
    
    // MARK: - Memory Pressure Monitoring
    
    private func setupMemoryPressureMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }
    }
    
    private func handleMemoryPressure() async {
        print("TaskManager: Memory pressure detected, cancelling low priority tasks")
        
        let lowPriorityTasks = activeTasks.filter { $0.priority == .low }
        for task in lowPriorityTasks {
            task.task.cancel()
        }
        
        // Force cleanup
        await cleanupCompletedTasks()
    }
    
    private func cleanupCompletedTasks() async {
        activeTasks.removeAll { !$0.isActive }
        updateResourceUsage()
    }
    
    // MARK: - Debug and Monitoring
    
    public func getTaskSummary() -> String {
        let active = activeTasks.count
        let history = taskHistory.count
        let critical = resourceUsage.activeCriticalTasks
        let high = resourceUsage.activeHighTasks
        let normal = resourceUsage.activeNormalTasks
        let low = resourceUsage.activeLowTasks
        
        return """
        TaskManager Summary:
        - Active Tasks: \(active) (Critical: \(critical), High: \(high), Normal: \(normal), Low: \(low))
        - Task History: \(history)
        - Under Pressure: \(resourceUsage.isUnderPressure)
        - Processing Critical: \(isProcessingCriticalTasks)
        """
    }
    
    public func getActiveTasks(for category: TaskCategory) -> [ManagedTask] {
        return activeTasks.filter { $0.category == category }
    }
    
    public func getTaskHistory(for category: TaskCategory, limit: Int = 10) -> [ManagedTask] {
        return Array(taskHistory.filter { $0.category == category }.suffix(limit))
    }
}

// MARK: - Task Coordination Extensions

extension TaskManager {
    
    /// Execute a task with automatic retry on failure
    /// - Parameters:
    ///   - category: Task category
    ///   - priority: Task priority
    ///   - description: Task description
    ///   - maxRetries: Maximum number of retry attempts
    ///   - retryDelay: Delay between retry attempts
    ///   - operation: Operation to execute
    /// - Returns: Result of the operation or nil if all retries failed
    public func executeWithRetry<T>(
        category: TaskCategory,
        priority: TaskPriority = .normal,
        description: String,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async -> T? {
        
        for attempt in 0...maxRetries {
            let attemptDescription = attempt > 0 ? "\(description) (Retry \(attempt)/\(maxRetries))" : description
            
            let result = await execute(
                category: category,
                priority: priority,
                description: attemptDescription
            ) {
                try await operation()
            }
            
            if result != nil {
                return result
            }
            
            // Wait before retry (except on last attempt)
            if attempt < maxRetries {
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
        
        print("TaskManager: All retry attempts failed for: \(description)")
        return nil
    }
    
    /// Execute tasks with dependency management
    /// - Parameters:
    ///   - category: Task category
    ///   - priority: Task priority
    ///   - description: Task group description
    ///   - dependencies: Tasks that must complete before main tasks
    ///   - mainTasks: Main tasks to execute after dependencies
    /// - Returns: Results of main tasks
    public func executeWithDependencies<T>(
        category: TaskCategory,
        priority: TaskPriority = .normal,
        description: String,
        dependencies: [() async throws -> Void],
        mainTasks: [() async throws -> T]
    ) async -> [T?] {
        
        // Execute dependencies first
        _ = await executeGroup(
            category: category,
            priority: priority,
            description: "\(description) - Dependencies",
            operations: dependencies
        )
        
        // Then execute main tasks
        return await executeGroup(
            category: category,
            priority: priority,
            description: "\(description) - Main Tasks",
            operations: mainTasks
        )
    }
}