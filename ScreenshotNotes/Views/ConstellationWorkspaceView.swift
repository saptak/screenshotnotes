//
//  ConstellationWorkspaceView.swift
//  ScreenshotNotes
//
//  Sprint 8.2.1: Constellation Workspace Detail View with Liquid Glass Design
//  Created by Assistant on 7/14/25.
//

import SwiftUI
import SwiftData

/// Detailed view for a content constellation workspace
/// Beautiful Liquid Glass design with activity tracking and smart suggestions
struct ConstellationWorkspaceView: View {
    let constellation: ContentConstellation
    @Environment(\.dismiss) private var dismiss
    @Query private var screenshots: [Screenshot]
    @StateObject private var liquidGlassMaterial = LiquidGlassMaterial()
    
    // State
    @State private var showingAddContent = false
    @State private var workspaceScreenshots: [Screenshot] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Liquid Glass background
                workspaceBackground
                
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Workspace header
                        workspaceHeader
                        
                        // Progress section
                        progressSection
                        
                        // Content grid
                        contentSection
                        
                        // Suggestions section
                        suggestionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(constellation.type.color)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddContent = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(constellation.type.color)
                    }
                }
            }
        }
        .onAppear {
            loadWorkspaceContent()
        }
        .sheet(isPresented: $showingAddContent) {
            // Add content sheet would go here
            Text("Add Content Feature Coming Soon")
                .padding()
        }
    }
    
    // MARK: - Background
    
    private var workspaceBackground: some View {
        ZStack {
            // Themed gradient
            LinearGradient(
                colors: [
                    constellation.type.color.opacity(0.08),
                    constellation.type.color.opacity(0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Material overlay
            Rectangle()
                .fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var workspaceHeader: some View {
        VStack(spacing: 16) {
            // Constellation info
            HStack {
                // Icon and emoji
                HStack(spacing: 12) {
                    Text(constellation.emoji)
                        .font(.system(size: 32))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(constellation.title)
                            .font(.title.bold())
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: constellation.type.icon)
                                .font(.caption)
                            
                            Text(constellation.type.displayName)
                                .font(.subheadline)
                        }
                        .foregroundColor(constellation.type.color)
                    }
                }
                
                Spacer()
                
                // Status badge
                VStack(spacing: 4) {
                    Image(systemName: constellation.isActive ? "circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(constellation.isActive ? .green : .secondary)
                    
                    Text(constellation.isActive ? "Active" : "Archived")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Description if available
            if let description = constellation.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Tags if available
            if !constellation.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(constellation.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .foregroundColor(constellation.type.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(constellation.type.color.opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .stroke(constellation.type.color.opacity(0.3), lineWidth: 0.5)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            // Progress header
            HStack {
                Text("Progress")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(constellation.completionText)
                    .font(.subheadline.bold())
                    .foregroundColor(constellation.type.color)
            }
            // Progress bar
            ProgressView(value: constellation.completionPercentage)
                .tint(constellation.type.color)
                .scaleEffect(y: 2.0)
                .animation(.easeInOut, value: constellation.completionPercentage)
            // Milestone tracking: typical activities
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    let total = max(1, constellation.type.typicalActivities.count)
                    let completed = min(constellation.screenshotIds.count, total)
                    ForEach(0..<total, id: \.self) { idx in
                        let isComplete = idx < completed
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .stroke(isComplete ? constellation.type.color : Color.gray.opacity(0.2), lineWidth: 3)
                                    .frame(width: 32, height: 32)
                                if isComplete {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(constellation.type.color)
                                        .font(.system(size: 22, weight: .bold))
                                } else {
                                    Text("\(idx+1)")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(constellation.type.typicalActivities[idx])
                                .font(.caption2)
                                .foregroundColor(isComplete ? .primary : .secondary)
                                .lineLimit(1)
                                .frame(width: 70)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(constellation.type.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("Content")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    showingAddContent = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Add")
                    }
                    .font(.subheadline)
                    .foregroundColor(constellation.type.color)
                }
            }
            
            if workspaceScreenshots.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(constellation.type.color.opacity(0.6))
                    
                    Text("No content yet")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Add screenshots related to this \(constellation.type.displayName.lowercased()) to get started.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(constellation.type.color.opacity(0.1), lineWidth: 1)
                        )
                )
            } else {
                // Content grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(workspaceScreenshots) { screenshot in
                        WorkspaceContentItem(screenshot: screenshot, constellation: constellation)
                    }
                }
            }
        }
    }
    
    // MARK: - Suggestions Section
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggestions")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(constellation.type.typicalActivities.prefix(3), id: \.self) { activity in
                    SuggestionCard(
                        title: activity,
                        icon: "lightbulb",
                        color: constellation.type.color
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadWorkspaceContent() {
        workspaceScreenshots = screenshots.filter { screenshot in
            constellation.screenshotIds.contains(screenshot.id)
        }
    }
}

// MARK: - Supporting Views

private struct ProgressDetail: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isAction: Bool
    
    init(title: String, value: String, icon: String, color: Color, isAction: Bool = false) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.isAction = isAction
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            if isAction {
                Text(value)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WorkspaceContentItem: View {
    let screenshot: Screenshot
    let constellation: ContentConstellation
    
    @StateObject private var liquidGlassMaterial = LiquidGlassMaterial()
    
    var body: some View {
        VStack(spacing: 8) {
            // Screenshot thumbnail
            AsyncImage(url: URL(fileURLWithPath: screenshot.filename)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Screenshot info
            VStack(spacing: 2) {
                if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
                    Text(String(extractedText.prefix(20)))
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else {
                    Text("Screenshot")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(screenshot.timestamp.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(constellation.type.color.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

private struct SuggestionCard: View {
    let title: String
    let icon: String
    let color: Color
    
    @StateObject private var liquidGlassMaterial = LiquidGlassMaterial()
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(color.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ConstellationWorkspaceView(
        constellation: ContentConstellation(
            title: "Paris Trip 2025",
            emoji: "🇫🇷",
            type: .travel,
            screenshotIds: [UUID(), UUID(), UUID()],
            description: "Planning an amazing trip to Paris with family",
            tags: ["vacation", "europe", "family"]
        )
    )
    .modelContainer(for: Screenshot.self, inMemory: true)
}
#endif