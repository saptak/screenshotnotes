//
//  ConstellationView.swift
//  ScreenshotNotes
//
//  Sprint 8.2.1: Basic Constellation Mode Shell with Smart Grouping Foundation
//  Created by Assistant on 7/14/25.
//

import SwiftUI
import SwiftData

/// Content Constellation view for smart grouping and workspace creation
/// Foundation for activity-based organization with beautiful Liquid Glass design
struct ConstellationView: View {
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    @StateObject private var liquidGlassMaterial = LiquidGlassMaterial()
    @StateObject private var modeManager = InterfaceModeManager.shared
    @Environment(\.modelContext) private var modelContext
    
    // Constellation state
    @State private var detectedConstellations: [ContentConstellation] = []
    @State private var isAnalyzing = false
    @State private var selectedConstellation: ContentConstellation?
    @State private var showingWorkspaceDetail = false
    
    // Animation state
    @State private var constellationOffset = CGPoint.zero
    @State private var animationOffset: CGFloat = 0
    @Namespace private var constellationAnimation
    
    var body: some View {
        ZStack {
            // Liquid Glass background
            liquidGlassBackground
            
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header
                    constellationHeader
                    
                    if isAnalyzing {
                        // Analysis in progress
                        analysisProgressView
                    } else if detectedConstellations.isEmpty {
                        // Empty state
                        emptyStateView
                    } else {
                        // Constellation grid
                        constellationGrid
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Space for mode selector
            }
            .refreshable {
                await analyzeConstellations()
            }
        }
        .onAppear {
            if detectedConstellations.isEmpty {
                Task {
                    await analyzeConstellations()
                }
            }
        }
        .sheet(isPresented: $showingWorkspaceDetail) {
            if let constellation = selectedConstellation {
                ConstellationWorkspaceView(constellation: constellation)
            }
        }
    }
    
    // MARK: - Background
    
    private var liquidGlassBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.05),
                    Color.blue.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Material overlay
            Rectangle()
                .fill(.ultraThinMaterial)
            
            // Subtle constellation pattern
            ConstellationPatternBackground()
                .opacity(0.1)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var constellationHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Content Constellation")
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                    
                    Text("Smart groupings and activity workspaces")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Constellation count badge
                if !detectedConstellations.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("\(detectedConstellations.count)")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.regularMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(.purple.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            
            // Quick stats
            if !detectedConstellations.isEmpty {
                constellationStats
            }
        }
        .padding(.top, 8)
    }
    
    private var constellationStats: some View {
        HStack(spacing: 24) {
            StatItem(
                title: "Active Projects",
                value: "\(detectedConstellations.filter { $0.type == .project }.count)",
                icon: "folder",
                color: .blue
            )
            
            StatItem(
                title: "Travel Plans",
                value: "\(detectedConstellations.filter { $0.type == .travel }.count)",
                icon: "airplane",
                color: .orange
            )
            
            StatItem(
                title: "Workspaces",
                value: "\(detectedConstellations.count)",
                icon: "sparkles",
                color: .purple
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.ultraThinMaterial, lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Analysis Progress
    
    private var analysisProgressView: some View {
        VStack(spacing: 20) {
            // Animated constellation icon
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.purple)
                .scaleEffect(1.0 + sin(animationOffset) * 0.1)
                .rotationEffect(.degrees(animationOffset * 2))
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        animationOffset = 360
                    }
                }
            
            Text("Discovering Content Constellations")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Analyzing patterns and relationships in your screenshots...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 8)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.purple.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.top, 40)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 64))
                .foregroundColor(.purple.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Constellations Yet")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Content constellations will appear here as you add more screenshots with related themes, projects, or activities.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Helpful tips
            VStack(alignment: .leading, spacing: 12) {
                TipItem(
                    icon: "camera",
                    title: "Take Screenshots",
                    description: "Add travel bookings, project documents, or related content"
                )
                
                TipItem(
                    icon: "brain",
                    title: "AI Analysis",
                    description: "Our AI will detect patterns and create smart groupings"
                )
                
                TipItem(
                    icon: "folder.badge.plus",
                    title: "Workspaces",
                    description: "Related content becomes organized workspaces"
                )
            }
            .padding(.top, 16)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.purple.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.top, 20)
    }
    
    // MARK: - Constellation Grid
    
    private var constellationGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 20) {
            ForEach(detectedConstellations) { constellation in
                ConstellationCard(constellation: constellation) {
                    selectedConstellation = constellation
                    showingWorkspaceDetail = true
                }
                .matchedGeometryEffect(id: constellation.id, in: constellationAnimation)
            }
        }
    }
    
    // MARK: - Analysis Logic
    
    private func analyzeConstellations() async {
        isAnalyzing = true
        
        // Simulate constellation detection for Sprint 8.2.1
        // This will be replaced with actual AI analysis in future sprints
        try? await Task.sleep(for: .seconds(2))
        
        await MainActor.run {
            detectedConstellations = generateSampleConstellations()
            isAnalyzing = false
        }
    }
    
    private func generateSampleConstellations() -> [ContentConstellation] {
        // Sample data for demonstration
        // In future sprints, this will use actual AI-powered content analysis
        var constellations: [ContentConstellation] = []
        
        // Only create sample constellations if we have enough screenshots
        guard screenshots.count >= 3 else { return [] }
        
        let sampleProjects = [
            ("Home Renovation", "🏠", screenshots.prefix(3).map(\.id)),
            ("Travel Planning", "✈️", screenshots.dropFirst(3).prefix(2).map(\.id)),
            ("Work Documents", "💼", screenshots.suffix(2).map(\.id))
        ]
        
        for (index, (title, emoji, screenshotIds)) in sampleProjects.enumerated() {
            if !screenshotIds.isEmpty {
                constellations.append(ContentConstellation(
                    id: UUID(),
                    title: title,
                    emoji: emoji,
                    type: index == 0 ? .project : (index == 1 ? .travel : .work),
                    screenshotIds: Array(screenshotIds),
                    lastUpdated: Date(),
                    isActive: true
                ))
            }
        }
        
        return constellations
    }
}

// MARK: - Supporting Views

private struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct TipItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

private struct ConstellationCard: View {
    let constellation: ContentConstellation
    let action: () -> Void
    
    @StateObject private var liquidGlassMaterial = LiquidGlassMaterial()
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(constellation.emoji)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(constellation.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("\(constellation.screenshotIds.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Progress
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(constellation.completionPercentage * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(constellation.type.color)
                    }
                    
                    ProgressView(value: constellation.completionPercentage)
                        .tint(constellation.type.color)
                }
                
                Spacer()
                
                // Status
                HStack {
                    Image(systemName: constellation.isActive ? "circle.fill" : "circle")
                        .font(.caption)
                        .foregroundColor(constellation.isActive ? .green : .secondary)
                    
                    Text(constellation.isActive ? "Active" : "Archived")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(constellation.type.color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct ConstellationPatternBackground: View {
    var body: some View {
        Canvas { context, size in
            // Draw subtle constellation pattern
            let points = generateConstellationPoints(in: size)
            
            // Draw connections
            context.stroke(
                Path { path in
                    for i in 0..<points.count {
                        for j in (i+1)..<points.count {
                            let distance = sqrt(pow(points[i].x - points[j].x, 2) + pow(points[i].y - points[j].y, 2))
                            if distance < 100 {
                                path.move(to: points[i])
                                path.addLine(to: points[j])
                            }
                        }
                    }
                },
                with: .color(.purple.opacity(0.1)),
                lineWidth: 0.5
            )
            
            // Draw points
            for point in points {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
                    with: .color(.purple.opacity(0.2))
                )
            }
        }
    }
    
    private func generateConstellationPoints(in size: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        let numberOfPoints = 15
        
        for _ in 0..<numberOfPoints {
            points.append(CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            ))
        }
        
        return points
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ConstellationView()
        .modelContainer(for: Screenshot.self, inMemory: true)
        .environmentObject(InterfaceSettings())
}
#endif