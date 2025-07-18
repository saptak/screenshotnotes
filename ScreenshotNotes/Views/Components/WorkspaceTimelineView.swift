
import SwiftUI
import SwiftData

struct WorkspaceTimelineView: View {
    let workspace: ContentWorkspace
    let analytics: WorkspaceAnalytics
    let timelineInsights: WorkspaceTimelineInsights
    @State private var selectedMilestone: TimelineMilestone?
    @State private var showingTimelineDetails = false
    @State private var timelineScrollOffset: CGFloat = 0
    @Namespace private var timelineNamespace
    
    private let milestones: [TimelineMilestone]
    private let timelineEvents: [TimelineEvent]
    
    init(workspace: ContentWorkspace, analytics: WorkspaceAnalytics, timelineInsights: WorkspaceTimelineInsights) {
        self.workspace = workspace
        self.analytics = analytics
        self.timelineInsights = timelineInsights
        
        // Generate timeline milestones and events
        self.milestones = Self.generateMilestones(from: workspace, analytics: analytics)
        self.timelineEvents = Self.generateTimelineEvents(from: workspace)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Timeline Header
            TimelineHeaderView(
                workspace: workspace,
                insights: timelineInsights,
                onDetailsToggle: { showingTimelineDetails.toggle() }
            )
            
            // Interactive Timeline Visualization
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(timelineEvents.enumerated()), id: \.element.id) { index, event in
                            TimelineEventView(
                                event: event,
                                isSelected: false,
                                position: calculatePosition(for: index),
                                onTap: {
                                    // Handle event tap
                                }
                            )
                            .id(event.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .coordinateSpace(name: "timeline")
                .gesture(
                    DragGesture(coordinateSpace: .named("timeline"))
                        .onChanged { value in
                            timelineScrollOffset = value.translation.width
                        }
                )
                .onAppear {
                    // Auto-scroll to most recent activity
                    if let latestEvent = timelineEvents.last {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            proxy.scrollTo(latestEvent.id, anchor: .trailing)
                        }
                    }
                }
            }
            
            // Timeline Controls
            TimelineControlsView(
                milestones: milestones,
                selectedMilestone: $selectedMilestone,
                insights: timelineInsights,
                onMilestoneSelected: { milestone in
                    withAnimation(.easeInOut(duration: 0.4)) {
                        selectedMilestone = milestone
                    }
                }
            )
            
            // Milestone Details (when selected)
            if let milestone = selectedMilestone {
                TimelineMilestoneDetailView(
                    milestone: milestone,
                    workspace: workspace,
                    analytics: analytics
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .matchedGeometryEffect(id: "milestone-detail", in: timelineNamespace)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.tertiary, lineWidth: 0.5)
                )
        )
        .sheet(isPresented: $showingTimelineDetails) {
            TimelineDetailSheetView(
                workspace: workspace,
                analytics: analytics,
                timelineInsights: timelineInsights,
                milestones: milestones,
                events: timelineEvents
            )
        }
    }
    
    // MARK: - Position Calculation
    
    private func calculatePosition(for index: Int) -> TimelinePosition {
        let totalEvents = timelineEvents.count
        let progress = totalEvents > 1 ? Double(index) / Double(totalEvents - 1) : 0.0
        
        if index == 0 {
            return .start
        } else if index == totalEvents - 1 {
            return .end
        } else {
            return .middle(progress: progress)
        }
    }
    
    // MARK: - Data Generation
    
    static func generateMilestones(from workspace: ContentWorkspace, analytics: WorkspaceAnalytics) -> [TimelineMilestone] {
        var milestones: [TimelineMilestone] = []
        
        // Workspace creation milestone
        milestones.append(TimelineMilestone(
            date: workspace.createdAt,
            title: "Workspace Created",
            screenshotIds: [],
            importance: .major
        ))
        
        // Progress milestones based on completion stages
        let screenshots = workspace.screenshots.sorted(by: { $0.timestamp < $1.timestamp })
        let progressStages = [0.25, 0.5, 0.75, 1.0]
        
        for stage in progressStages {
            let targetCount = Int(Double(screenshots.count) * stage)
            if targetCount > 0 && targetCount <= screenshots.count {
                let milestoneScreenshots = Array(screenshots.prefix(targetCount))
                let latestDate = milestoneScreenshots.last?.timestamp ?? workspace.createdAt
                let screenshotIds = milestoneScreenshots.map { $0.id }
                
                milestones.append(TimelineMilestone(
                    date: latestDate,
                    title: "\(Int(stage * 100))% Complete",
                    screenshotIds: screenshotIds,
                    importance: stage >= 0.5 ? .major : .minor
                ))
            }
        }
        
        // Missing component milestones
        for component in analytics.missingComponentAnalysis.criticalMissing.prefix(2) {
            milestones.append(TimelineMilestone(
                date: Date(),
                title: "Missing: \(component)",
                screenshotIds: [],
                importance: .major
            ))
        }
        
        return milestones.sorted(by: { $0.date < $1.date })
    }
    
    static func generateTimelineEvents(from workspace: ContentWorkspace) -> [TimelineEvent] {
        var events: [TimelineEvent] = []
        
        // Workspace creation event
        events.append(TimelineEvent(
            date: workspace.createdAt,
            type: .workspaceCreated,
            title: "Workspace Created",
            description: "Started tracking \(workspace.type.displayName)",
            screenshots: []
        ))
        
        // Screenshot addition events
        let screenshots = workspace.screenshots.sorted(by: { $0.timestamp < $1.timestamp })
        for (index, screenshot) in screenshots.enumerated() {
            events.append(TimelineEvent(
                date: screenshot.timestamp,
                type: .screenshotAdded,
                title: "Screenshot Added",
                description: "Added screenshot \(index + 1)",
                screenshots: [screenshot]
            ))
        }
        
        // Progress milestone events
        let milestones = generateMilestones(from: workspace, analytics: WorkspaceAnalyticsService.shared.generateAnalytics(for: workspace))
        for milestone in milestones {
            events.append(TimelineEvent(
                date: milestone.date,
                type: .milestoneReached,
                title: milestone.title,
                description: "Milestone achieved",
                screenshots: [] // Will need to fetch screenshots by IDs if needed
            ))
        }
        
        return events.sorted(by: { $0.date < $1.date })
    }
}

// MARK: - Timeline Header View

struct TimelineHeaderView: View {
    let workspace: ContentWorkspace
    let insights: WorkspaceTimelineInsights
    let onDetailsToggle: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "timeline.selection")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text("Timeline")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text(formatDuration(insights.totalDuration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Consistency Score
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(consistencyColor)
                    
                    Text("\(Int(insights.consistencyScore * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(consistencyColor)
                }
                
                Text("Consistency")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onDetailsToggle) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var consistencyColor: Color {
        if insights.consistencyScore >= 0.8 {
            return .green
        } else if insights.consistencyScore >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let days = Int(duration / 86400)
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "1 day"
        } else if days < 7 {
            return "\(days) days"
        } else if days < 30 {
            let weeks = days / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s")"
        } else if days < 365 {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        } else {
            let years = days / 365
            return "\(years) year\(years == 1 ? "" : "s")"
        }
    }
}

// MARK: - Timeline Event View

struct TimelineEventView: View {
    let event: TimelineEvent
    let isSelected: Bool
    let position: TimelinePosition
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Timeline Line
            TimelineLineView(position: position, isHighlighted: isSelected)
            
            // Event Node
            Button(action: onTap) {
                Circle()
                    .fill(eventColor)
                    .frame(width: nodeSize, height: nodeSize)
                    .overlay(
                        Image(systemName: event.type.iconName)
                            .font(.system(size: iconSize, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? .blue : .clear, lineWidth: 3)
                    )
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Event Label
            VStack(spacing: 2) {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                Text(formatEventDate(event.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
            .padding(.top, 8)
        }
        .frame(width: 100)
    }
    
    private var eventColor: Color {
        return event.type.color
    }
    
    private var nodeSize: CGFloat {
        switch event.type {
        case .workspaceCreated, .milestoneReached: return 20
        case .screenshotAdded, .progressUpdate: return 16
        }
    }
    
    private var iconSize: CGFloat {
        switch event.type {
        case .workspaceCreated, .milestoneReached: return 10
        case .screenshotAdded, .progressUpdate: return 8
        }
    }
    
    private func formatEventDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Timeline Line View

struct TimelineLineView: View {
    let position: TimelinePosition
    let isHighlighted: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Left line
            if case .middle = position {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 50, height: 2)
            } else if case .end = position {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 50, height: 2)
            }
            
            Spacer().frame(width: 0)
            
            // Right line
            if case .start = position {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 50, height: 2)
            } else if case .middle = position {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 50, height: 2)
            }
        }
        .frame(width: 100, height: 2)
    }
    
    private var lineColor: Color {
        isHighlighted ? .blue : .secondary.opacity(0.4)
    }
}

// MARK: - Timeline Controls View

struct TimelineControlsView: View {
    let milestones: [TimelineMilestone]
    @Binding var selectedMilestone: TimelineMilestone?
    let insights: WorkspaceTimelineInsights
    let onMilestoneSelected: (TimelineMilestone?) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Quick milestone navigation
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(milestones.filter { $0.importance == .major }) { milestone in
                        MilestoneChipView(
                            milestone: milestone,
                            isSelected: selectedMilestone?.id == milestone.id,
                            onTap: {
                                onMilestoneSelected(milestone)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Timeline insights summary
            if insights.gaps > 0 || insights.milestones > 3 {
                TimelineInsightsSummaryView(insights: insights)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Milestone Chip View

struct MilestoneChipView: View {
    let milestone: TimelineMilestone
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: iconForImportance(milestone.importance))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : milestoneColor)
                
                Text(milestone.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? milestoneColor : .clear)
                    .overlay(
                        Capsule()
                            .stroke(milestoneColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var milestoneColor: Color {
        switch milestone.importance {
        case .major: return .blue
        case .minor: return .gray
        }
    }
    
    private func iconForImportance(_ importance: WorkspaceAnalyticsService.TimelineMilestone.ImportanceLevel) -> String {
        switch importance {
        case .major: return "star.fill"
        case .minor: return "circle.fill"
        }
    }
}

// MARK: - Timeline Insights Summary

struct TimelineInsightsSummaryView: View {
    let insights: WorkspaceTimelineInsights
    
    var body: some View {
        HStack(spacing: 16) {
            if insights.milestones > 0 {
                InsightMetricView(
                    icon: "flag.checkered",
                    value: "\(insights.milestones)",
                    label: "Milestone\(insights.milestones == 1 ? "" : "s")",
                    color: .blue
                )
            }
            
            if insights.gaps > 0 {
                InsightMetricView(
                    icon: "calendar.badge.exclamationmark",
                    value: "\(insights.gaps)",
                    label: "Gap\(insights.gaps == 1 ? "" : "s")",
                    color: .orange
                )
            }
            
            InsightMetricView(
                icon: "clock.arrow.circlepath",
                value: insights.suggestedUpdateFrequency,
                label: "Suggested",
                color: .green
            )
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Insight Metric View

struct InsightMetricView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Timeline Milestone Detail View

struct TimelineMilestoneDetailView: View {
    let milestone: TimelineMilestone
    let workspace: ContentWorkspace
    let analytics: WorkspaceAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Milestone header
            HStack {
                Image(systemName: iconForImportance(milestone.importance))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(milestoneColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Milestone for workspace")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(milestone.importance.rawValue.capitalized)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(milestoneColor)
            }
            
            // Screenshots associated with milestone
            if !milestone.screenshotIds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Screenshots (\(milestone.screenshotIds.count))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Screenshot IDs: \(milestone.screenshotIds.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Importance indicator
            HStack {
                Text("Importance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(milestone.importance.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(milestoneColor.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var milestoneColor: Color {
        switch milestone.importance {
        case .major: return .blue
        case .minor: return .gray
        }
    }
    
    private func iconForImportance(_ importance: WorkspaceAnalyticsService.TimelineMilestone.ImportanceLevel) -> String {
        switch importance {
        case .major: return "star.fill"
        case .minor: return "circle.fill"
        }
    }
}

// MARK: - Timeline Detail Sheet View

struct TimelineDetailSheetView: View {
    let workspace: ContentWorkspace
    let analytics: WorkspaceAnalytics
    let timelineInsights: WorkspaceTimelineInsights
    let milestones: [TimelineMilestone]
    let events: [TimelineEvent]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Timeline Overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timeline Overview")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        DetailMetricCard(
                            title: "Duration",
                            value: formatDuration(timelineInsights.totalDuration),
                            icon: "clock",
                            color: .blue
                        )
                        
                        DetailMetricCard(
                            title: "Last Update",
                            value: "\(Int(timelineInsights.daysSinceLastUpdate)) days ago",
                            icon: "calendar",
                            color: .green
                        )
                        
                        DetailMetricCard(
                            title: "Milestones",
                            value: "\(timelineInsights.milestones)",
                            icon: "flag.checkered",
                            color: .purple
                        )
                        
                        DetailMetricCard(
                            title: "Consistency",
                            value: "\(Int(timelineInsights.consistencyScore * 100))%",
                            icon: "chart.line.uptrend.xyaxis",
                            color: timelineInsights.consistencyScore >= 0.8 ? .green : timelineInsights.consistencyScore >= 0.5 ? .orange : .red
                        )
                    }
                }
                
                // Detailed Events List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timeline Events")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(events.reversed()) { event in
                                TimelineEventRowView(event: event)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Timeline Details")
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let days = Int(duration / 86400)
        if days < 1 {
            return "Today"
        } else if days == 1 {
            return "1 day"
        } else if days < 7 {
            return "\(days) days"
        } else if days < 30 {
            return "\(days / 7) weeks"
        } else {
            return "\(days / 30) months"
        }
    }
}

// MARK: - Detail Metric Card

struct DetailMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Timeline Event Row View

struct TimelineEventRowView: View {
    let event: TimelineEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Event icon
            Circle()
                .fill(eventColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: event.type.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                )
            
            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(event.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(event.date, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Screenshot count
            if !event.screenshots.isEmpty {
                Text("\(event.screenshots.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.blue.opacity(0.1))
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thickMaterial)
        )
    }
    
    private var eventColor: Color {
        return event.type.color
    }
}

// MARK: - Supporting Data Structures

// Using types from WorkspaceAnalyticsService
typealias WorkspaceAnalytics = WorkspaceAnalyticsService.WorkspaceAnalytics
typealias TimelineMilestone = WorkspaceAnalyticsService.TimelineMilestone
typealias TimelineEvent = WorkspaceAnalyticsService.TimelineEvent

enum TimelinePosition {
    case start
    case middle(progress: Double)
    case end
}
