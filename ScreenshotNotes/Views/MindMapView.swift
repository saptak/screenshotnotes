import SwiftUI
import SwiftData

struct MindMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    
    @StateObject private var mindMapService = MindMapService.shared
    @StateObject private var glassSystem = GlassDesignSystem.shared
    private let hapticService = HapticService.shared
    
    // Responsive layout
    @Environment(\.glassResponsiveLayout) private var layout
    
    // View state
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var draggedNodeId: UUID?
    @State private var showingNodeDetail = false
    @State private var selectedScreenshot: Screenshot?
    @State private var showingControls = true
    @State private var showingStats = false
    @State private var viewSize: CGSize = .zero
    @State private var lastDragUpdate: Date = Date()
    
    // Animation state
    @State private var animationProgress: Double = 0.0
    @State private var isInitialAnimationComplete = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let responsiveLayout = GlassDesignSystem.ResponsiveLayout(
                    horizontalSizeClass: nil,
                    verticalSizeClass: nil,
                    screenWidth: geometry.size.width,
                    screenHeight: geometry.size.height
                )
                
                ZStack {
                    // Background
                    backgroundView
                    // Main mind map canvas
                    mindMapCanvas
                    // Overlay controls
                    overlayControls
                    // Generation progress
                    if mindMapService.isGenerating {
                        generationProgressView
                    }
                    // Statistics panel
                    if showingStats {
                        statisticsPanel
                    }
                }
                .environment(\.glassResponsiveLayout, responsiveLayout)
            }
            .navigationTitle("Mind Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingStats.toggle()
                        hapticService.impact(.light)
                    }) {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.primary)
                    }
                    Button(action: {
                        showingControls.toggle()
                        hapticService.impact(.light)
                    }) {
                        Image(systemName: showingControls ? "eye.slash" : "eye")
                            .foregroundColor(.primary)
                    }
                    Button(action: regenerateMindMap) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.primary)
                    }
                    .disabled(mindMapService.isGenerating)
                }
            }
            .task {
                // First, try to load from cache for instant display
                await mindMapService.loadFromCache()
                
                if mindMapService.hasNodes {
                    // Data loaded from cache - show immediately
                    withAnimation(.easeInOut(duration: 0.5)) {
                        animationProgress = 1.0
                    }
                    print("🧠 Mind map loaded from cache instantly")
                } else {
                    // No cached data - check if background generation is in progress
                    print("🧠 No cached mind map data, checking for background generation")
                    await mindMapService.refreshMindMapIfNeeded(screenshots: screenshots)
                    
                    if mindMapService.hasNodes {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            animationProgress = 1.0
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .mindMapGenerationComplete)) { _ in
                // Handle first-time generation completion
                if mindMapService.hasNodes && animationProgress == 0.0 {
                    withAnimation(.easeInOut(duration: 2.0)) {
                        animationProgress = 1.0
                    }
                }
            }
            .sheet(isPresented: $showingNodeDetail) {
                if let selectedScreenshot = selectedScreenshot {
                    NodeDetailView(screenshot: selectedScreenshot)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea()
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            // Base background that adapts to dark mode
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // Glass material overlay with proper dark mode support
            Rectangle()
                .fill(.regularMaterial.opacity(0.3))
                .ignoresSafeArea()
            
            // Subtle grid pattern
            Canvas { context, size in
                let gridSpacing: CGFloat = 50
                context.stroke(
                    Path { path in
                        for x in stride(from: 0, through: size.width, by: gridSpacing) {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        for y in stride(from: 0, through: size.height, by: gridSpacing) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                    },
                    with: .color(.primary.opacity(0.05)),
                    lineWidth: 0.5
                )
            }
            .scaleEffect(zoomScale)
            .offset(offset)
        }
    }
    
    // MARK: - Mind Map Canvas
    
    private var mindMapCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                // Connections
                connectionsView
                // Cluster backgrounds
                clustersView
                // Nodes
                nodesView
            }
            .scaleEffect(zoomScale)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    magnificationGesture,
                    dragGesture
                )
            )
            .onAppear {
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
            }
        }
        .clipped()
    }
    
    // MARK: - Connections View
    
    private var connectionsView: some View {
        Canvas { context, size in
            // Safely access connections with error handling
            let mindMapData = mindMapService.mindMapData
            let connections = mindMapData.connections
            
            // Ensure we have valid connections array
            guard !connections.isEmpty else {
                return
            }
            
            for connection in connections {
                guard let sourceNode = mindMapData.nodes[connection.sourceNodeId],
                      let targetNode = mindMapData.nodes[connection.targetNodeId] else { 
                    continue 
                }
                
                // Use viewSize for correct positioning instead of canvas size
                let adjustedSourcePos = adjustPositionForView(sourceNode.position, in: viewSize)
                let adjustedTargetPos = adjustPositionForView(targetNode.position, in: viewSize)
                
                // Create path for connection
                var path = Path()
                path.move(to: adjustedSourcePos)
                
                // Create curved connection
                let controlPoint1 = CGPoint(
                    x: adjustedSourcePos.x + (adjustedTargetPos.x - adjustedSourcePos.x) * 0.25,
                    y: adjustedSourcePos.y
                )
                let controlPoint2 = CGPoint(
                    x: adjustedSourcePos.x + (adjustedTargetPos.x - adjustedSourcePos.x) * 0.75,
                    y: adjustedTargetPos.y
                )
                
                path.addCurve(
                    to: adjustedTargetPos,
                    control1: controlPoint1,
                    control2: controlPoint2
                )
                
                // Apply connection styling with more visible defaults
                let connectionColor = connection.color.opacity(max(0.8, connection.opacity))
                let connectionThickness = max(2.0, connection.thickness)
                
                context.stroke(
                    path,
                    with: .color(connectionColor),
                    style: StrokeStyle(
                        lineWidth: connectionThickness,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                
                // Add arrowhead for directionality
                if connection.strength > 0.7 {
                    drawArrowhead(
                        context: context,
                        from: adjustedSourcePos,
                        to: adjustedTargetPos,
                        color: connection.color,
                        size: connectionThickness
                    )
                }
            }
        }
        .opacity(max(0.7, animationProgress)) // Ensure connections are always somewhat visible
        .animation(.easeInOut(duration: 1.0), value: animationProgress)
    }
    
    // MARK: - Clusters View
    
    private var clustersView: some View {
        let clusters = mindMapService.mindMapData.clusters
        return ForEach(clusters, id: \.id) { cluster in
            let adjustedCenter = adjustPositionForView(cluster.center, in: viewSize)
            
            Circle()
                .fill(cluster.color.opacity(0.1))
                .stroke(cluster.color.opacity(0.3), lineWidth: 2)
                .frame(width: cluster.radius * 2, height: cluster.radius * 2)
                .position(adjustedCenter)
                .opacity(showingControls ? 0.5 : 0.2)
                .animation(.easeInOut(duration: 0.3), value: showingControls)
        }
    }
    
    // MARK: - Nodes View
    
    private var nodesView: some View {
        let nodeArray = mindMapService.mindMapData.nodeArray
        return ForEach(nodeArray, id: \.id) { node in
            NodeView(
                node: node,
                screenshot: getScreenshot(for: node),
                position: adjustPositionForView(node.position, in: viewSize),
                isSelected: mindMapService.selectedNodeId == node.id,
                isHovered: mindMapService.hoveredNodeId == node.id,
                animationProgress: animationProgress
            )
            .scaleEffect(node.scale)
            .opacity(node.opacity)
            .onTapGesture {
                selectNode(node)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Screenshot node: \(node.title)")
            .accessibilityHint("Double tap to view details, drag to move")
            .accessibilityValue(mindMapService.selectedNodeId == node.id ? "Selected" : "Not selected")
            .accessibilityAddTraits(mindMapService.selectedNodeId == node.id ? .isSelected : [])
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        // Safety check for valid drag state
                        guard mindMapService.mindMapData.nodes[node.id] != nil else {
                            return
                        }
                        
                        if draggedNodeId != node.id {
                            draggedNodeId = node.id
                            mindMapService.startDraggingNode(nodeId: node.id)
                        }
                        
                        // Throttle updates to prevent hanging - only update every 16ms (~60fps)
                        let now = Date()
                        if now.timeIntervalSince(lastDragUpdate) > 0.016 {
                            let newPosition = convertGlobalToNodePosition(value.location)
                            
                            // Safety check for valid position
                            guard newPosition.x.isFinite && newPosition.y.isFinite else { return }
                            
                            mindMapService.updateNodePosition(nodeId: node.id, position: newPosition)
                            lastDragUpdate = now
                        }
                    }
                    .onEnded { _ in
                        if let nodeId = draggedNodeId {
                            mindMapService.stopDraggingNode(nodeId: nodeId)
                        }
                        draggedNodeId = nil
                        hapticService.impact(.medium)
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: node.scale)
            .animation(.easeInOut(duration: 0.2), value: node.opacity)
        }
    }
    
    // MARK: - Overlay Controls
    
    private var overlayControls: some View {
        VStack {
            Spacer()
            
            HStack {
                // Zoom controls
                if showingControls {
                    zoomControls
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                Spacer()
                
                // View controls
                if showingControls {
                    viewControls
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingControls)
    }
    
    private var zoomControls: some View {
        VStack(spacing: 12) {
            Button(action: zoomIn) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .glassBackground(
                                material: layout.materials.accent,
                                cornerRadius: 22,
                                shadow: true
                            )
                    )
            }
            .accessibilityLabel("Zoom in")
            .accessibilityHint("Increases the size of the mind map")
            
            Button(action: zoomOut) {
                Image(systemName: "minus")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .glassBackground(
                                material: layout.materials.accent,
                                cornerRadius: 22,
                                shadow: true
                            )
                    )
            }
            .accessibilityLabel("Zoom out")
            .accessibilityHint("Decreases the size of the mind map")
            
            Button(action: resetView) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .glassBackground(
                                material: layout.materials.accent,
                                cornerRadius: 22,
                                shadow: true
                            )
                    )
            }
            .accessibilityLabel("Reset view")
            .accessibilityHint("Resets zoom and position to default")
        }
    }
    
    private var viewControls: some View {
        VStack(spacing: 12) {
            Button(action: centerView) {
                Image(systemName: "scope")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .glassBackground(
                                material: layout.materials.accent,
                                cornerRadius: 22,
                                shadow: true
                            )
                    )
            }
            
            Button(action: mindMapService.resetFocus) {
                Image(systemName: "circle.dashed")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .glassBackground(
                                material: layout.materials.accent,
                                cornerRadius: 22,
                                shadow: true
                            )
                    )
            }
        }
    }
    
    // MARK: - Generation Progress
    
    private var generationProgressView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: mindMapService.generationProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: mindMapService.generationProgress)
                    
                    Text("\(Int(mindMapService.generationProgress * 100))%")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Generating Mind Map")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Analyzing relationships between screenshots...")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .glassBackground(
                        material: layout.materials.primary,
                        cornerRadius: 20,
                        shadow: true
                    )
            )
            .scaleEffect(mindMapService.isGenerating ? 1.0 : 0.9)
            .opacity(mindMapService.isGenerating ? 1.0 : 0.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mindMapService.isGenerating)
        }
    }
    
    // MARK: - Statistics Panel
    
    private var statisticsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Mind Map Statistics")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button("Close") {
                    showingStats = false
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Nodes",
                    value: "\(mindMapService.performanceMetrics.nodesCount)",
                    icon: "circle"
                )
                
                StatCard(
                    title: "Connections",
                    value: "\(mindMapService.performanceMetrics.connectionsCount)",
                    icon: "link"
                )
                
                StatCard(
                    title: "Clusters",
                    value: "\(mindMapService.performanceMetrics.clustersCount)",
                    icon: "circles.hexagongrid"
                )
                
                StatCard(
                    title: "Layout Time",
                    value: String(format: "%.2fs", mindMapService.performanceMetrics.layoutTime),
                    icon: "timer"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: layout.materials.cornerRadius)
                .glassBackground(
                    material: layout.materials.primary,
                    cornerRadius: layout.materials.cornerRadius,
                    shadow: true
                )
        )
        .padding(20)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Gestures
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                zoomScale = min(max(zoomScale * delta, 0.5), 3.0)
            }
            .onEnded { _ in
                lastScale = 1.0
                hapticService.impact(.light)
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if draggedNodeId == nil { // Only pan view if not dragging a node
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                lastOffset = offset
                if draggedNodeId == nil {
                    hapticService.impact(.light)
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func regenerateMindMap() {
        hapticService.impact(.medium)
        // Reset animation state
        animationProgress = 0.0
        isInitialAnimationComplete = false
        Task {
            await mindMapService.refreshMindMapIfNeeded(screenshots: screenshots)
            withAnimation(.easeInOut(duration: 1.5)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func selectNode(_ node: MindMapNode) {
        mindMapService.selectNode(nodeId: node.id)
        selectedScreenshot = getScreenshot(for: node)
        showingNodeDetail = true
        hapticService.impact(.medium)
    }
    
    private func getScreenshot(for node: MindMapNode) -> Screenshot? {
        // Safety check to prevent Core Data crashes
        guard !screenshots.isEmpty else { return nil }
        
        // Use a safer comparison approach
        for screenshot in screenshots {
            if String(describing: screenshot.id) == String(describing: node.screenshotId) {
                return screenshot
            }
        }
        return nil
    }
    
    private func adjustPositionForView(_ position: CGPoint, in size: CGSize) -> CGPoint {
        // Adaptive coordinate transformation based on screen size
        // Scale positions relative to screen dimensions for better layout
        let baseReference: CGFloat = 600.0
        let scaleX = size.width / baseReference
        let scaleY = size.height / baseReference
        let scale = min(scaleX, scaleY) * 0.8 // Add some margin
        
        // Center the coordinate system and apply transformations
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        return CGPoint(
            x: centerX + (position.x * scale * zoomScale) + offset.width,
            y: centerY + (position.y * scale * zoomScale) + offset.height
        )
    }
    
    private func convertGlobalToNodePosition(_ globalPosition: CGPoint) -> CGPoint {
        // Convert global screen position back to node coordinate system
        // Reverse the adaptive transformations from adjustPositionForView
        let baseReference: CGFloat = 600.0
        let scaleX = viewSize.width / baseReference
        let scaleY = viewSize.height / baseReference
        let scale = min(scaleX, scaleY) * 0.8 // Match the margin from adjustPositionForView
        
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2
        
        return CGPoint(
            x: (globalPosition.x - centerX - offset.width) / (scale * zoomScale),
            y: (globalPosition.y - centerY - offset.height) / (scale * zoomScale)
        )
    }
    
    private func drawArrowhead(context: GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color, size: CGFloat) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength = size * 2
        let arrowAngle = 0.5
        
        let arrowPoint1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        
        let arrowPoint2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        var arrowPath = Path()
        arrowPath.move(to: end)
        arrowPath.addLine(to: arrowPoint1)
        arrowPath.move(to: end)
        arrowPath.addLine(to: arrowPoint2)
        
        context.stroke(arrowPath, with: .color(color), lineWidth: size / 2)
    }
    
    // View control actions
    private func zoomIn() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            zoomScale = min(zoomScale * 1.5, 3.0)
        }
        hapticService.impact(.light)
    }
    
    private func zoomOut() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            zoomScale = max(zoomScale / 1.5, 0.5)
        }
        hapticService.impact(.light)
    }
    
    private func resetView() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            zoomScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
        hapticService.impact(.medium)
    }
    
    private func centerView() {
        // Calculate center of all nodes
        let nodeArray = mindMapService.mindMapData.nodeArray
        guard !nodeArray.isEmpty else {
            print("⚠️ No nodes available for centering")
            return
        }
        
        let positions = nodeArray.map { $0.position }
        guard !positions.isEmpty else {
            print("⚠️ No positions available for centering")
            return
        }
        
        let centerX = positions.map { $0.x }.reduce(0, +) / CGFloat(positions.count)
        let centerY = positions.map { $0.y }.reduce(0, +) / CGFloat(positions.count)
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            offset = CGSize(width: -centerX, height: -centerY)
            lastOffset = offset
        }
        hapticService.impact(.medium)
    }
}

// MARK: - Supporting Views

struct NodeView: View {
    let node: MindMapNode
    let screenshot: Screenshot?
    let position: CGPoint
    let isSelected: Bool
    let isHovered: Bool
    let animationProgress: Double
    
    @StateObject private var glassSystem = GlassDesignSystem.shared
    @Environment(\.glassResponsiveLayout) private var layout
    
    var body: some View {
        ZStack {
            // Node background with glass material
            Circle()
                .glassBackground(
                    material: layout.materials.primary,
                    cornerRadius: 25,
                    shadow: true
                )
                .frame(width: node.radius * 2, height: node.radius * 2)
                .overlay(
                    Circle()
                        .stroke(node.color, lineWidth: isSelected ? 3 : 1)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
                )
            
            // Screenshot thumbnail
            if let screenshot = screenshot,
               let uiImage = UIImage(data: screenshot.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: (node.radius - 4) * 2, height: (node.radius - 4) * 2)
                    .clipShape(Circle())
            } else {
                // Fallback icon
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(node.color)
            }
            
            // Selection highlight
            if isSelected || isHovered {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: node.radius * 2 + 8, height: node.radius * 2 + 8)
                    .opacity(isSelected ? 1.0 : 0.5)
                    .scaleEffect(isSelected ? 1.1 : 1.05)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
        }
        .position(position)
        .scaleEffect(0.3 + 0.7 * animationProgress)
        .opacity(animationProgress)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double.random(in: 0...0.5)), value: animationProgress)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    @StateObject private var glassSystem = GlassDesignSystem.shared
    @Environment(\.glassResponsiveLayout) private var layout
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: layout.materials.cornerRadius)
                .glassBackground(
                    material: layout.materials.secondary,
                    cornerRadius: layout.materials.cornerRadius,
                    shadow: false
                )
        )
    }
}

struct NodeDetailView: View {
    let screenshot: Screenshot
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Screenshot image
                    if let uiImage = UIImage(data: screenshot.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.headline)
                        
                        HStack {
                            Text("Timestamp:")
                            Spacer()
                            Text(screenshot.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                        
                        if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
                            ExtractedTextView(
                                text: extractedText,
                                mode: .standard,
                                theme: .adaptive,
                                showHeader: true,
                                editable: false,
                                onCopy: { copiedText in
                                    // Provide haptic feedback for copy actions
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }
                            )
                            .frame(maxHeight: 400) // Limit height to prevent sizing issues
                        }
                        
                        if let objectTags = screenshot.objectTags, !objectTags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Object Tags:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    ForEach(objectTags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Node Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MindMapView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}