import SwiftUI

/// Comprehensive debug view for monitoring memory management and leak prevention
/// Implements Iteration 8.5.3.2: Memory Management & Leak Prevention
struct MemoryManagerDebugView: View {
    @StateObject private var memoryManager = MemoryManager.shared
    @StateObject private var resourceCleanupManager = ResourceCleanupManager.shared
    @StateObject private var weakReferenceManager = WeakReferenceManager.shared
    @State private var showingDetailedReport = false
    @State private var showingLeakReport = false
    @State private var selectedCleanupType: CleanupType = .light
    
    enum CleanupType: String, CaseIterable {
        case light = "Light Cleanup"
        case deep = "Deep Cleanup"
        case emergency = "Emergency Cleanup"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Memory Usage Overview
                    memoryUsageSection
                    
                    // Object Lifecycle Tracking
                    objectLifecycleSection
                    
                    // Resource Cleanup Management
                    resourceCleanupSection
                    
                    // Weak Reference Management
                    weakReferenceSection
                    
                    // Memory Leak Detection
                    memoryLeakSection
                    
                    // Manual Actions
                    manualActionsSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Memory Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Detailed Report") {
                        showingDetailedReport.toggle()
                    }
                    
                    Button("Leak Report") {
                        showingLeakReport.toggle()
                    }
                }
            }
            .sheet(isPresented: $showingDetailedReport) {
                detailedReportSheet
            }
            .sheet(isPresented: $showingLeakReport) {
                leakReportSheet
            }
        }
    }
    
    // MARK: - Memory Usage Section
    
    private var memoryUsageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Usage")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Used Memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(memoryManager.currentMemoryUsage.formattedUsedMemory)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(memoryManager.currentMemoryUsage.formattedTotalMemory)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage %")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(memoryManager.currentMemoryUsage.usagePercentage.formatted(.number.precision(.fractionLength(1))))%")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(memoryManager.currentMemoryUsage.memoryPressure.color)
                }
            }
            
            // Memory Pressure Indicator
            HStack {
                Text("Memory Pressure:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(memoryManager.currentMemoryUsage.memoryPressure.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(memoryManager.currentMemoryUsage.memoryPressure.color.opacity(0.2))
                    .foregroundColor(memoryManager.currentMemoryUsage.memoryPressure.color)
                    .cornerRadius(4)
                
                Spacer()
                
                Text("Monitoring: \(memoryManager.isMonitoring ? "Active" : "Inactive")")
                    .font(.caption)
                    .foregroundColor(memoryManager.isMonitoring ? .green : .red)
            }
            
            // Memory Usage Chart (simplified)
            if memoryManager.memoryHistory.count > 1 {
                memoryUsageChart
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var memoryUsageChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memory Usage History")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(memoryManager.memoryHistory.suffix(20).enumerated()), id: \.offset) { index, usage in
                    Rectangle()
                        .fill(usage.memoryPressure.color)
                        .frame(width: 8, height: CGFloat(usage.usagePercentage) * 0.8)
                        .opacity(0.7)
                }
            }
            .frame(height: 60)
        }
    }
    
    // MARK: - Object Lifecycle Section
    
    private var objectLifecycleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Object Lifecycle Tracking")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Objects")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(memoryManager.trackedObjects.values.filter { $0.isActive }.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deallocated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(memoryManager.trackedObjects.values.filter { !$0.isActive }.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Potential Leaks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(memoryManager.detectedLeaks.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(memoryManager.detectedLeaks.isEmpty ? .green : .red)
                }
            }
            
            // Object breakdown by class
            if !memoryManager.trackedObjects.isEmpty {
                objectBreakdownView
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var objectBreakdownView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Objects by Class")
                .font(.caption)
                .foregroundColor(.secondary)
            
            let objectsByClass = Dictionary(grouping: memoryManager.trackedObjects.values.filter { $0.isActive }, by: { $0.className })
            
            ForEach(Array(objectsByClass.keys.sorted()), id: \.self) { className in
                HStack {
                    Text(className)
                        .font(.caption2)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(objectsByClass[className]?.count ?? 0)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Resource Cleanup Section
    
    private var resourceCleanupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resource Cleanup Management")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Registered Handlers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(resourceCleanupManager.registeredCleanupHandlers.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(resourceCleanupManager.getTotalEstimatedMemoryUsage()), countStyle: .memory))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cleanup Ops")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(resourceCleanupManager.totalCleanupOperations)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
            }
            
            // Memory usage by handler
            if !resourceCleanupManager.registeredCleanupHandlers.isEmpty {
                memoryUsageByHandlerView
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var memoryUsageByHandlerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memory Usage by Handler")
                .font(.caption)
                .foregroundColor(.secondary)
            
            let handlersByMemory = resourceCleanupManager.getHandlersByMemoryUsage()
            
            ForEach(Array(handlersByMemory.prefix(5)), id: \.0) { identifier, memoryUsage in
                HStack {
                    Text(identifier)
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Weak Reference Section
    
    private var weakReferenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weak Reference Management")
                .font(.headline)
                .foregroundColor(.primary)
            
            let stats = weakReferenceManager.getStatistics()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Collections")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.activeCollections)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Delegates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.activeDelegates)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cleanup Efficiency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.cleanupEfficiency.formatted(.number.precision(.fractionLength(1))))%")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
            }
            
            HStack {
                Text("Dead References Cleaned:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(stats.deadReferenceCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Text("Last Cleanup:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(stats.lastCleanupTime?.formatted(.relative(presentation: .named)) ?? "Never")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Memory Leak Section
    
    private var memoryLeakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Leak Detection")
                .font(.headline)
                .foregroundColor(.primary)
            
            if memoryManager.detectedLeaks.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No memory leaks detected")
                        .font(.body)
                        .foregroundColor(.green)
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("\(memoryManager.detectedLeaks.count) potential leaks detected")
                            .font(.body)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    
                    ForEach(Array(memoryManager.detectedLeaks.prefix(3)), id: \.instanceId) { leak in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(leak.className)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Alive for \(Date().timeIntervalSince(leak.createdAt).formatted(.number.precision(.fractionLength(0))))s")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("LEAK")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    if memoryManager.detectedLeaks.count > 3 {
                        Text("... and \(memoryManager.detectedLeaks.count - 3) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Manual Actions Section
    
    private var manualActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Cleanup Type Picker
            Picker("Cleanup Type", selection: $selectedCleanupType) {
                ForEach(CleanupType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                actionButton("Perform Cleanup", color: .blue) {
                    performCleanup()
                }
                
                actionButton("Force GC", color: .orange) {
                    forceGarbageCollection()
                }
                
                actionButton("Start Monitoring", color: .green) {
                    memoryManager.startMonitoring()
                }
                
                actionButton("Stop Monitoring", color: .red) {
                    memoryManager.stopMonitoring()
                }
                
                actionButton("Clear Weak Refs", color: .purple) {
                    weakReferenceManager.performCleanup()
                }
                
                actionButton("Detect Cycles", color: .yellow) {
                    detectRetainCycles()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
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
    
    // MARK: - Detail Sheets
    
    private var detailedReportSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Memory Manager Summary")
                        .font(.headline)
                    
                    Text(memoryManager.getMemorySummary())
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Text("Resource Cleanup Summary")
                        .font(.headline)
                    
                    Text(resourceCleanupManager.getDetailedReport())
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Text("Weak Reference Summary")
                        .font(.headline)
                    
                    Text(weakReferenceManager.getStatistics().summary)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Detailed Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDetailedReport = false
                    }
                }
            }
        }
    }
    
    private var leakReportSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Memory Leak Report")
                        .font(.headline)
                    
                    Text(memoryManager.getLeakReport())
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    if !memoryManager.detectedLeaks.isEmpty {
                        Text("Detailed Leak Information")
                            .font(.headline)
                        
                        ForEach(memoryManager.detectedLeaks, id: \.instanceId) { leak in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(leak.className)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text("LEAK")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.2))
                                        .foregroundColor(.red)
                                        .cornerRadius(4)
                                }
                                
                                Text("Instance ID: \(leak.instanceId)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("Created: \(leak.createdAt.formatted())")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("Alive for: \(Date().timeIntervalSince(leak.createdAt).formatted(.number.precision(.fractionLength(0))))s")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Leak Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingLeakReport = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func performCleanup() {
        Task {
            switch selectedCleanupType {
            case .light:
                await resourceCleanupManager.performLightCleanup()
            case .deep:
                await resourceCleanupManager.performDeepCleanup()
            case .emergency:
                await memoryManager.performEmergencyCleanup()
            }
        }
    }
    
    private func forceGarbageCollection() {
        // Force autoreleasepool drain
        autoreleasepool {
            // This will help release any autoreleased objects
        }
        
        // Trigger weak reference cleanup
        weakReferenceManager.performCleanup()
    }
    
    private func detectRetainCycles() {
        let cycles = RetainCycleDetector.shared.detectCycles()
        if !cycles.isEmpty {
            print("Detected \(cycles.count) potential retain cycles:")
            for (index, cycle) in cycles.enumerated() {
                print("Cycle \(index + 1): \(cycle.joined(separator: " -> "))")
            }
        } else {
            print("No retain cycles detected")
        }
    }
}

// MARK: - Preview

struct MemoryManagerDebugView_Previews: PreviewProvider {
    static var previews: some View {
        MemoryManagerDebugView()
    }
}