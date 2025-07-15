import SwiftUI
import SwiftData

/// Debug view to monitor and test the Task Synchronization Framework
/// Implements Iteration 8.5.3.1: Task Synchronization Framework
struct TaskManagerDebugView: View {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var taskCoordinator = TaskCoordinator.shared
    @State private var showingDebugInfo = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Task Manager Status
                taskManagerStatusSection
                
                // Task Coordinator Status
                taskCoordinatorStatusSection
                
                // Test Actions
                testActionsSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Task Manager Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Debug Info") {
                        showingDebugInfo.toggle()
                    }
                }
            }
            .sheet(isPresented: $showingDebugInfo) {
                debugInfoSheet
            }
        }
    }
    
    // MARK: - Task Manager Status Section
    
    private var taskManagerStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Manager Status")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(taskManager.activeTasks.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Critical Tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(taskManager.resourceUsage.activeCriticalTasks)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(taskManager.resourceUsage.activeCriticalTasks > 0 ? .red : .green)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Under Pressure")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(taskManager.resourceUsage.isUnderPressure ? "YES" : "NO")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(taskManager.resourceUsage.isUnderPressure ? .red : .green)
                }
            }
            
            // Resource Usage Breakdown
            HStack(spacing: 16) {
                resourceUsageItem("High", count: taskManager.resourceUsage.activeHighTasks, color: .orange)
                resourceUsageItem("Normal", count: taskManager.resourceUsage.activeNormalTasks, color: .blue)
                resourceUsageItem("Low", count: taskManager.resourceUsage.activeLowTasks, color: .gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func resourceUsageItem(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
    
    // MARK: - Task Coordinator Status Section
    
    private var taskCoordinatorStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Coordinator Status")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Workflows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(taskCoordinator.activeWorkflows.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Is Coordinating")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(taskCoordinator.isCoordinating ? "YES" : "NO")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(taskCoordinator.isCoordinating ? .green : .gray)
                }
            }
            
            // Active Workflows List
            if !taskCoordinator.activeWorkflows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Workflows:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(taskCoordinator.activeWorkflows) { workflow in
                        workflowRow(workflow)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func workflowRow(_ workflow: TaskCoordinator.Workflow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workflow.type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(workflow.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(workflow.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                if let step = workflow.currentStep {
                    Text(step)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }
    
    // MARK: - Test Actions Section
    
    private var testActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                testButton("Test Critical Task", color: .red) {
                    testCriticalTask()
                }
                
                testButton("Test Background Processing", color: .blue) {
                    testBackgroundProcessing()
                }
                
                testButton("Test Search Workflow", color: .green) {
                    testSearchWorkflow()
                }
                
                testButton("Cancel All Tasks", color: .orange) {
                    cancelAllTasks()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func testButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color)
                .cornerRadius(8)
        }
    }
    
    // MARK: - Debug Info Sheet
    
    private var debugInfoSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Task Manager Summary")
                        .font(.headline)
                    
                    Text(taskManager.getTaskSummary())
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Text("Task Coordinator Summary")
                        .font(.headline)
                    
                    Text(taskCoordinator.getWorkflowSummary())
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Debug Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDebugInfo = false
                    }
                }
            }
        }
    }
    
    // MARK: - Test Actions
    
    private func testCriticalTask() {
        Task {
            await taskManager.execute(
                category: .userInterface,
                priority: .critical,
                description: "Test critical task execution"
            ) {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                print("Critical task completed successfully")
            }
        }
    }
    
    private func testBackgroundProcessing() {
        Task {
            await taskCoordinator.executeBackgroundProcessingWorkflow(
                modelContext: ModelContext(ModelContainer.preview),
                backgroundProcessors: BackgroundProcessors(
                    ocrProcessor: BackgroundOCRProcessor(),
                    visionProcessor: BackgroundVisionProcessor(),
                    semanticProcessor: BackgroundSemanticProcessor()
                )
            )
        }
    }
    
    private func testSearchWorkflow() {
        Task {
            let mockScreenshots: [Screenshot] = []
            _ = await taskCoordinator.executeSearchWorkflow(
                query: "test search",
                screenshots: mockScreenshots,
                searchService: "MockSearchService"
            )
        }
    }
    
    private func cancelAllTasks() {
        taskManager.cancelAllTasks()
        taskCoordinator.cancelAllWorkflows()
    }
}

// MARK: - Preview

struct TaskManagerDebugView_Previews: PreviewProvider {
    static var previews: some View {
        TaskManagerDebugView()
    }
}

// MARK: - ModelContainer Extension for Preview

extension ModelContainer {
    static var preview: ModelContainer {
        do {
            let container = try ModelContainer(
                for: Screenshot.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}