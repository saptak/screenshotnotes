import Foundation
import SwiftUI
import SwiftData

/// High-level task coordination for complex workflows
/// Implements coordinated execution of related operations with proper sequencing
@MainActor
public final class TaskCoordinator: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = TaskCoordinator()
    
    // MARK: - Workflow Types
    
    public enum WorkflowType: String, CaseIterable {
        case imageImport = "image_import"
        case backgroundProcessing = "background_processing"
        case searchOperation = "search_operation"
        case mindMapGeneration = "mindmap_generation"
        case dataCleanup = "data_cleanup"
        case appStartup = "app_startup"
        case userInteraction = "user_interaction"
    }
    
    // MARK: - Workflow State
    
    public enum WorkflowState {
        case idle
        case preparing
        case executing
        case completing
        case completed
        case failed(Error)
        case cancelled
    }
    
    // MARK: - Workflow Definition
    
    public struct Workflow: Identifiable {
        public let id = UUID()
        public let type: WorkflowType
        public let description: String
        public let priority: TaskManager.TaskPriority
        public let createdAt: Date
        public var state: WorkflowState
        public var progress: Double
        public var currentStep: String?
        public var startedAt: Date?
        public var completedAt: Date?
        
        public var duration: TimeInterval? {
            guard let startedAt = startedAt else { return nil }
            let endTime = completedAt ?? Date()
            return endTime.timeIntervalSince(startedAt)
        }
        
        public var isActive: Bool {
            switch state {
            case .idle, .preparing, .executing, .completing:
                return true
            case .completed, .failed, .cancelled:
                return false
            }
        }
    }
    
    // MARK: - Published State
    
    @Published public private(set) var activeWorkflows: [Workflow] = []
    @Published public private(set) var workflowHistory: [Workflow] = []
    @Published public private(set) var isCoordinating = false
    
    // MARK: - Dependencies
    
    private let taskManager = TaskManager.shared
    private var workflowTasks: [UUID: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    
    private init() {}
    
    deinit {
        Task { @MainActor in
            cancelAllWorkflows()
        }
    }
    
    // MARK: - Public Workflow Management
    
    /// Execute a complete image import workflow with proper sequencing
    /// - Parameters:
    ///   - items: Photo picker items to import
    ///   - modelContext: SwiftData model context
    ///   - backgroundProcessors: Background processing services
    /// - Returns: Number of successfully imported images
    @discardableResult
    public func executeImageImportWorkflow(
        items: [Any], // PhotosPickerItem
        modelContext: ModelContext,
        backgroundProcessors: BackgroundProcessors
    ) async -> Int {
        
        let workflow = createWorkflow(
            type: .imageImport,
            description: "Import \(items.count) images with full processing",
            priority: .critical
        )
        
        return await executeWorkflow(workflow) { [weak self] workflow in
            guard let self = self else { return 0 }
            
            // Step 1: Prepare for import
            await self.updateWorkflowProgress(workflow, step: "Preparing import", progress: 0.1)
            
            let importResults = await taskManager.executeGroup(
                category: .dataImport,
                priority: .critical,
                description: "Import image batch",
                operations: items.enumerated().map { index, item in
                    return {
                        // Simulate image import operation
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        return index // Return index as success indicator
                    }
                }
            )
            
            let successfulImports = importResults.compactMap { $0 }.count
            
            await self.updateWorkflowProgress(workflow, step: "Images imported", progress: 0.4)
            
            // Step 2: Background processing coordination
            if successfulImports > 0 {
                await self.updateWorkflowProgress(workflow, step: "Starting background processing", progress: 0.5)
                
                // Coordinate background processing with proper sequencing
                await self.coordinateBackgroundProcessing(
                    workflow: workflow,
                    modelContext: modelContext,
                    backgroundProcessors: backgroundProcessors,
                    imageCount: successfulImports
                )
            }
            
            await self.updateWorkflowProgress(workflow, step: "Import completed", progress: 1.0)
            return successfulImports
        } ?? 0
    }
    
    /// Execute background processing workflow with proper coordination
    /// - Parameters:
    ///   - modelContext: SwiftData model context
    ///   - backgroundProcessors: Background processing services
    ///   - forceFullProcessing: Whether to force processing of all screenshots
    public func executeBackgroundProcessingWorkflow(
        modelContext: ModelContext,
        backgroundProcessors: BackgroundProcessors,
        forceFullProcessing: Bool = false
    ) async {
        
        let workflow = createWorkflow(
            type: .backgroundProcessing,
            description: "Background processing workflow",
            priority: .normal
        )
        
        await executeWorkflow(workflow) { [weak self] workflow in
            guard let self = self else { return }
            
            await self.coordinateBackgroundProcessing(
                workflow: workflow,
                modelContext: modelContext,
                backgroundProcessors: backgroundProcessors,
                imageCount: nil,
                forceFullProcessing: forceFullProcessing
            )
        }
    }
    
    /// Execute search operation workflow
    /// - Parameters:
    ///   - query: Search query
    ///   - screenshots: Screenshots to search
    ///   - searchService: Search service
    /// - Returns: Search results
    public func executeSearchWorkflow<T>(
        query: String,
        screenshots: [Screenshot],
        searchService: T
    ) async -> [Screenshot] {
        
        let workflow = createWorkflow(
            type: .searchOperation,
            description: "Search: '\(query)'",
            priority: .high
        )
        
        return await executeWorkflow(workflow) { [weak self] workflow in
            guard let self = self else { return [] }
            
            await self.updateWorkflowProgress(workflow, step: "Analyzing query", progress: 0.2)
            
            // Coordinate search operations
            let results = await taskManager.executeWithRetry(
                category: .search,
                priority: .high,
                description: "Execute search query",
                maxRetries: 2
            ) {
                // Simulate search operation
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                return screenshots.filter { screenshot in
                    // Simple text matching simulation
                    screenshot.extractedText?.localizedCaseInsensitiveContains(query) == true
                }
            }
            
            await self.updateWorkflowProgress(workflow, step: "Search completed", progress: 1.0)
            return results ?? []
        } ?? []
    }
    
    /// Execute mind map generation workflow
    /// - Parameters:
    ///   - screenshots: Screenshots to analyze
    ///   - modelContext: SwiftData model context
    ///   - mindMapService: Mind map service
    public func executeMindMapGenerationWorkflow(
        screenshots: [Screenshot],
        modelContext: ModelContext,
        mindMapService: Any // MindMapService
    ) async {
        
        let workflow = createWorkflow(
            type: .mindMapGeneration,
            description: "Generate mind map for \(screenshots.count) screenshots",
            priority: .normal
        )
        
        await executeWorkflow(workflow) { [weak self] workflow in
            guard let self = self else { return }
            
            await self.updateWorkflowProgress(workflow, step: "Analyzing relationships", progress: 0.3)
            
            // Coordinate mind map generation with proper resource management
            await taskManager.execute(
                category: .mindMap,
                priority: .normal,
                description: "Generate mind map relationships"
            ) {
                // Simulate mind map generation
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            await self.updateWorkflowProgress(workflow, step: "Building visualization", progress: 0.7)
            
            await taskManager.execute(
                category: .mindMap,
                priority: .normal,
                description: "Build mind map visualization"
            ) {
                // Simulate visualization building
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            }
            
            await self.updateWorkflowProgress(workflow, step: "Mind map generated", progress: 1.0)
        }
    }
    
    /// Execute app startup workflow
    /// - Parameters:
    ///   - modelContext: SwiftData model context
    ///   - services: App services to initialize
    public func executeAppStartupWorkflow(
        modelContext: ModelContext,
        services: AppServices
    ) async {
        
        let workflow = createWorkflow(
            type: .appStartup,
            description: "App startup initialization",
            priority: .critical
        )
        
        await executeWorkflow(workflow) { [weak self] workflow in
            guard let self = self else { return }
            
            // Step 1: Initialize core services
            await self.updateWorkflowProgress(workflow, step: "Initializing core services", progress: 0.2)
            
            await taskManager.executeWithDependencies(
                category: .userInterface,
                priority: .critical,
                description: "Initialize app services",
                dependencies: [
                    {
                        // Initialize photo library service
                        services.photoLibraryService.setModelContext(modelContext)
                    },
                    {
                        // Initialize thumbnail service
                        services.thumbnailService.setModelContext(modelContext)
                    }
                ],
                mainTasks: [
                    {
                        // Initialize background processors
                        services.backgroundVisionProcessor.setModelContext(modelContext)
                        return ()
                    }
                ]
            )
            
            await self.updateWorkflowProgress(workflow, step: "Services initialized", progress: 0.6)
            
            // Step 2: Start background processing
            await self.updateWorkflowProgress(workflow, step: "Starting background processing", progress: 0.8)
            
            await taskManager.execute(
                category: .backgroundProcessing,
                priority: .normal,
                description: "Start initial background processing"
            ) {
                // Start background processing
                await services.backgroundVisionProcessor.startProcessing()
            }
            
            await self.updateWorkflowProgress(workflow, step: "App startup completed", progress: 1.0)
        }
    }
    
    // MARK: - Workflow Cancellation
    
    /// Cancel a specific workflow
    /// - Parameter workflowId: ID of the workflow to cancel
    public func cancelWorkflow(_ workflowId: UUID) {
        guard let workflow = activeWorkflows.first(where: { $0.id == workflowId }) else { return }
        
        // Cancel associated task
        workflowTasks[workflowId]?.cancel()
        workflowTasks.removeValue(forKey: workflowId)
        
        // Update workflow state
        if let index = activeWorkflows.firstIndex(where: { $0.id == workflowId }) {
            activeWorkflows[index].state = .cancelled
            activeWorkflows[index].completedAt = Date()
            moveToHistory(activeWorkflows[index])
            activeWorkflows.remove(at: index)
        }
        
        updateCoordinationState()
    }
    
    /// Cancel all active workflows
    public func cancelAllWorkflows() {
        for workflow in activeWorkflows {
            workflowTasks[workflow.id]?.cancel()
        }
        
        workflowTasks.removeAll()
        
        for i in activeWorkflows.indices {
            activeWorkflows[i].state = .cancelled
            activeWorkflows[i].completedAt = Date()
        }
        
        workflowHistory.append(contentsOf: activeWorkflows)
        activeWorkflows.removeAll()
        updateCoordinationState()
    }
    
    /// Cancel workflows of a specific type
    /// - Parameter type: Type of workflows to cancel
    public func cancelWorkflows(ofType type: WorkflowType) {
        let workflowsToCancel = activeWorkflows.filter { $0.type == type }
        
        for workflow in workflowsToCancel {
            cancelWorkflow(workflow.id)
        }
    }
    
    // MARK: - Private Implementation
    
    private func createWorkflow(
        type: WorkflowType,
        description: String,
        priority: TaskManager.TaskPriority
    ) -> Workflow {
        return Workflow(
            type: type,
            description: description,
            priority: priority,
            createdAt: Date(),
            state: .idle,
            progress: 0.0
        )
    }
    
    @discardableResult
    private func executeWorkflow<T>(
        _ workflow: Workflow,
        operation: @escaping (Workflow) async throws -> T
    ) async -> T? {
        
        // Register workflow
        var mutableWorkflow = workflow
        mutableWorkflow.state = .preparing
        mutableWorkflow.startedAt = Date()
        activeWorkflows.append(mutableWorkflow)
        updateCoordinationState()
        
        // Create and store task
        let task = Task { @MainActor in
            do {
                // Update to executing state
                await updateWorkflowState(workflow.id, state: .executing)
                
                // Execute operation
                let result = try await operation(workflow)
                
                // Complete workflow
                await updateWorkflowState(workflow.id, state: .completed)
                return result
            } catch {
                await updateWorkflowState(workflow.id, state: .failed(error))
                throw error
            }
        }
        
        workflowTasks[workflow.id] = Task {
            _ = await task.result
        }
        
        // Execute and return result
        do {
            return try await task.value
        } catch {
            print("TaskCoordinator: Workflow failed [\(workflow.type.rawValue)]: \(workflow.description) - \(error)")
            return nil
        }
    }
    
    private func updateWorkflowState(_ workflowId: UUID, state: WorkflowState) async {
        guard let index = activeWorkflows.firstIndex(where: { $0.id == workflowId }) else { return }
        
        activeWorkflows[index].state = state
        
        switch state {
        case .completed, .failed, .cancelled:
            activeWorkflows[index].completedAt = Date()
            moveToHistory(activeWorkflows[index])
            activeWorkflows.remove(at: index)
            workflowTasks.removeValue(forKey: workflowId)
        default:
            break
        }
        
        updateCoordinationState()
    }
    
    private func updateWorkflowProgress(_ workflow: Workflow, step: String, progress: Double) async {
        guard let index = activeWorkflows.firstIndex(where: { $0.id == workflow.id }) else { return }
        
        activeWorkflows[index].currentStep = step
        activeWorkflows[index].progress = progress
    }
    
    private func moveToHistory(_ workflow: Workflow) {
        workflowHistory.append(workflow)
        
        // Limit history size
        if workflowHistory.count > 50 {
            workflowHistory.removeFirst(workflowHistory.count - 50)
        }
    }
    
    private func updateCoordinationState() {
        isCoordinating = !activeWorkflows.isEmpty
    }
    
    // MARK: - Background Processing Coordination
    
    private func coordinateBackgroundProcessing(
        workflow: Workflow,
        modelContext: ModelContext,
        backgroundProcessors: BackgroundProcessors,
        imageCount: Int?,
        forceFullProcessing: Bool = false
    ) async {
        
        // Step 1: OCR Processing
        await updateWorkflowProgress(workflow, step: "Text extraction", progress: 0.6)
        
        await taskManager.execute(
            category: .ocr,
            priority: .normal,
            description: "OCR processing batch"
        ) {
            backgroundProcessors.ocrProcessor.startBackgroundProcessingIfNeeded(in: modelContext)
        }
        
        // Step 2: Vision Processing
        await updateWorkflowProgress(workflow, step: "Vision analysis", progress: 0.7)
        
        await taskManager.execute(
            category: .vision,
            priority: .normal,
            description: "Vision processing batch"
        ) {
            await backgroundProcessors.visionProcessor.startProcessing()
        }
        
        // Step 3: Semantic Processing
        await updateWorkflowProgress(workflow, step: "Semantic analysis", progress: 0.8)
        
        await taskManager.execute(
            category: .semantic,
            priority: .normal,
            description: "Semantic processing batch"
        ) {
            await backgroundProcessors.semanticProcessor.processScreenshotsNeedingAnalysis(in: modelContext)
        }
        
        // Step 4: Mind Map Generation (if needed)
        if imageCount == nil || (imageCount ?? 0) > 5 {
            await updateWorkflowProgress(workflow, step: "Updating mind map", progress: 0.9)
            
            await taskManager.execute(
                category: .mindMap,
                priority: .low,
                description: "Mind map regeneration"
            ) {
                await backgroundProcessors.semanticProcessor.triggerMindMapRegeneration(in: modelContext)
            }
        }
    }
}

// MARK: - Supporting Types

public struct BackgroundProcessors {
    public let ocrProcessor: BackgroundOCRProcessor
    public let visionProcessor: BackgroundVisionProcessor
    public let semanticProcessor: BackgroundSemanticProcessor
    
    public init(
        ocrProcessor: BackgroundOCRProcessor,
        visionProcessor: BackgroundVisionProcessor,
        semanticProcessor: BackgroundSemanticProcessor
    ) {
        self.ocrProcessor = ocrProcessor
        self.visionProcessor = visionProcessor
        self.semanticProcessor = semanticProcessor
    }
}

public struct AppServices {
    public let photoLibraryService: PhotoLibraryService
    public let thumbnailService: ThumbnailService
    public let backgroundVisionProcessor: BackgroundVisionProcessor
    
    public init(
        photoLibraryService: PhotoLibraryService,
        thumbnailService: ThumbnailService,
        backgroundVisionProcessor: BackgroundVisionProcessor
    ) {
        self.photoLibraryService = photoLibraryService
        self.thumbnailService = thumbnailService
        self.backgroundVisionProcessor = backgroundVisionProcessor
    }
}

// MARK: - Extensions for Convenience

extension TaskCoordinator {
    
    /// Get active workflows of a specific type
    /// - Parameter type: Workflow type to filter by
    /// - Returns: Array of active workflows of the specified type
    public func getActiveWorkflows(ofType type: WorkflowType) -> [Workflow] {
        return activeWorkflows.filter { $0.type == type }
    }
    
    /// Check if any workflows of a specific type are active
    /// - Parameter type: Workflow type to check
    /// - Returns: True if any workflows of the type are active
    public func hasActiveWorkflows(ofType type: WorkflowType) -> Bool {
        return activeWorkflows.contains { $0.type == type }
    }
    
    /// Wait for all workflows of a specific type to complete
    /// - Parameters:
    ///   - type: Workflow type to wait for
    ///   - timeout: Maximum time to wait
    public func waitForCompletion(ofType type: WorkflowType, timeout: TimeInterval = 30.0) async {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if !hasActiveWorkflows(ofType: type) {
                break
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    /// Get workflow summary for debugging
    /// - Returns: String summary of current workflow state
    public func getWorkflowSummary() -> String {
        let active = activeWorkflows.count
        let history = workflowHistory.count
        let byType = Dictionary(grouping: activeWorkflows, by: { $0.type })
            .mapValues { $0.count }
        
        var summary = """
        TaskCoordinator Summary:
        - Active Workflows: \(active)
        - Workflow History: \(history)
        - Is Coordinating: \(isCoordinating)
        """
        
        if !byType.isEmpty {
            summary += "\n- By Type:"
            for (type, count) in byType.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                summary += "\n  - \(type.rawValue): \(count)"
            }
        }
        
        return summary
    }
}