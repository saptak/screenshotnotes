import SwiftUI
import SwiftData
import Combine

/// Renders the Constellation mode shell for Enhanced Interface.
/// Provides a beautiful, fluid, and reliable placeholder UI for activity-based organization.
struct ConstellationModeRenderer: View {
    // MARK: - Data Source
    let screenshots: [Screenshot]
    
    // MARK: - State
    @State private var detectedConstellations: [ContentConstellation] = []
    @State private var isAnalyzing = false
    @State private var animationOffset: CGFloat = 0
    @StateObject private var relationshipDetector = ContentRelationshipDetector.shared
    @State private var relationshipCancellable: AnyCancellable?
    
    var body: some View {
        ZStack {
            liquidGlassBackground
            ScrollView {
                LazyVStack(spacing: 24) {
                    constellationHeader
                    if isAnalyzing {
                        analysisProgressView
                    } else if detectedConstellations.isEmpty {
                        emptyStateView
                    } else {
                        constellationGrid
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .refreshable {
                await analyzeConstellations()
            }
        }
        .onAppear {
            if detectedConstellations.isEmpty {
                Task { await analyzeConstellations() }
            }
            // Subscribe to relationship updates
            relationshipCancellable = relationshipDetector.$detectedRelationships.sink { _ in
                Task { await analyzeConstellations() }
            }
        }
        .onDisappear {
            relationshipCancellable?.cancel()
        }
    }
    
    // MARK: - Background
    private var liquidGlassBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.03), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle().fill(.ultraThinMaterial)
            ConstellationPatternBackground().opacity(0.1)
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
                if !detectedConstellations.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.caption)
                        Text("\(detectedConstellations.count)").font(.caption.bold())
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(.regularMaterial)
                            .overlay(Capsule().stroke(.purple.opacity(0.3), lineWidth: 1))
                    )
                }
            }
        }
        .padding(.top, 8)
    }
    // MARK: - Analysis Progress
    private var analysisProgressView: some View {
        VStack(spacing: 20) {
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
            ProgressView().scaleEffect(1.2).padding(.top, 8)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.purple.opacity(0.2), lineWidth: 1))
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
            VStack(alignment: .leading, spacing: 12) {
                TipItem(icon: "camera", title: "Take Screenshots", description: "Add travel bookings, project documents, or related content")
                TipItem(icon: "brain", title: "AI Analysis", description: "Our AI will detect patterns and create smart groupings")
                TipItem(icon: "folder.badge.plus", title: "Workspaces", description: "Related content becomes organized workspaces")
            }
            .padding(.top, 16)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.purple.opacity(0.1), lineWidth: 1))
        )
        .padding(.top, 20)
    }
    // MARK: - Constellation Grid (Sample Only)
    private var constellationGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 20) {
            ForEach(detectedConstellations) { constellation in
                ConstellationCard(constellation: constellation, action: {})
            }
        }
    }
    // MARK: - Analysis Logic (Real Data)
    private func analyzeConstellations() async {
        isAnalyzing = true
        // Ensure relationships are up to date
        if relationshipDetector.detectedRelationships.isEmpty {
            await relationshipDetector.detectRelationships(in: screenshots)
        }
        let relationships = relationshipDetector.detectedRelationships
        let constellations = buildConstellations(from: relationships, screenshots: screenshots)
        await MainActor.run {
            detectedConstellations = constellations
            isAnalyzing = false
        }
    }
    /// Group screenshots into constellations based on strong relationships
    private func buildConstellations(from relationships: [Relationship], screenshots: [Screenshot]) -> [ContentConstellation] {
        // Build clusters using union-find (disjoint set) for robust grouping
        var parent: [UUID: UUID] = [:]
        func find(_ id: UUID) -> UUID {
            if parent[id] == nil { parent[id] = id }
            if parent[id] != id { parent[id] = find(parent[id]!) }
            return parent[id]!
        }
        func union(_ id1: UUID, _ id2: UUID) {
            let root1 = find(id1)
            let root2 = find(id2)
            if root1 != root2 { parent[root2] = root1 }
        }
        // Only use strong relationships
        let strong = relationships.filter { $0.strength > 0.5 && $0.confidence > 0.5 }
        for rel in strong {
            union(rel.sourceScreenshotId, rel.targetScreenshotId)
        }
        // Group screenshots by root
        var clusters: [UUID: [UUID]] = [:]
        for screenshot in screenshots {
            let root = find(screenshot.id)
            clusters[root, default: []].append(screenshot.id)
        }
        // Only keep clusters with >1 screenshot
        let validClusters = clusters.values.filter { $0.count > 1 }
        // Build ContentConstellation for each cluster
        var constellations: [ContentConstellation] = []
        for (i, ids) in validClusters.enumerated() {
            let screenshotsInCluster = screenshots.filter { ids.contains($0.id) }
            let title = "Constellation #\(i+1)"
            let emoji = ["✈️","🏠","💼","📊","🎓","🛒","❤️","🍽️","🎉","📅"].randomElement() ?? "✨"
            let type: ConstellationType = .other // Could infer from content in future
            constellations.append(ContentConstellation(
                title: title,
                emoji: emoji,
                type: type,
                screenshotIds: ids,
                completionPercentage: Double.random(in: 0.3...0.9),
                lastUpdated: Date(),
                isActive: true,
                description: nil,
                tags: [],
                priority: .medium,
                estimatedTimeToComplete: nil,
                dueDate: nil,
                createdDate: Date()
            ))
        }
        return constellations
    }
}

// MARK: - Supporting Views (reuse from ConstellationView)
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
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(constellation.emoji).font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(constellation.title).font(.headline).foregroundColor(.primary).lineLimit(1)
                        Text("\(constellation.screenshotIds.count) items").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(constellation.completionPercentage * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(constellation.type.color)
                    }
                    ProgressView(value: constellation.completionPercentage)
                        .tint(constellation.type.color)
                }
                Spacer()
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
            let points = generateConstellationPoints(in: size)
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