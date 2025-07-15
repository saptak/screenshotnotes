import Foundation
import SwiftData
import SwiftUI

/// Represents a group of related screenshots for intelligent organization
@Model
public final class ScreenshotGroup {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var groupType: GroupType
    public var createdAt: Date
    public var lastModified: Date
    public var confidence: Double
    public var isUserCreated: Bool
    public var groupDescription: String?
    public var color: String? // Hex color for visual distinction
    
    // Group metadata
    public var appName: String?
    public var websiteURL: String?
    public var timeRange: TimeInterval? // Duration of the group in seconds
    public var sessionIdentifier: String? // For app sessions
    
    // Relationship with screenshots
    @Relationship(deleteRule: .nullify)
    public var screenshots: [Screenshot] = []
    
    // Group statistics
    public var screenshotCount: Int { screenshots.count }
    public var dateRange: (start: Date, end: Date)? {
        guard !screenshots.isEmpty else { return nil }
        let timestamps = screenshots.map { $0.timestamp }
        return (start: timestamps.min()!, end: timestamps.max()!)
    }
    
    public init(
        title: String,
        groupType: GroupType,
        confidence: Double = 1.0,
        isUserCreated: Bool = false,
        groupDescription: String? = nil,
        color: String? = nil,
        appName: String? = nil,
        websiteURL: String? = nil,
        sessionIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.groupType = groupType
        self.createdAt = Date()
        self.lastModified = Date()
        self.confidence = confidence
        self.isUserCreated = isUserCreated
        self.groupDescription = groupDescription
        self.color = color
        self.appName = appName
        self.websiteURL = websiteURL
        self.sessionIdentifier = sessionIdentifier
        self.screenshots = []
    }
    
    /// Add a screenshot to this group
    public func addScreenshot(_ screenshot: Screenshot) {
        guard !screenshots.contains(where: { $0.id == screenshot.id }) else { return }
        screenshots.append(screenshot)
        lastModified = Date()
    }
    
    /// Remove a screenshot from this group
    public func removeScreenshot(_ screenshot: Screenshot) {
        screenshots.removeAll { $0.id == screenshot.id }
        lastModified = Date()
    }
    
    /// Update the group's confidence score
    public func updateConfidence(_ newConfidence: Double) {
        confidence = newConfidence
        lastModified = Date()
    }
    
    /// Get the most representative screenshot for this group
    public var representativeScreenshot: Screenshot? {
        guard !screenshots.isEmpty else { return nil }
        
        // For sequence groups, return the first screenshot
        if groupType == .sequence {
            return screenshots.sorted(by: { $0.timestamp < $1.timestamp }).first
        }
        
        // For other groups, return the most recent
        return screenshots.sorted(by: { $0.timestamp > $1.timestamp }).first
    }
    
    /// Check if this group should be merged with another
    public func shouldMergeWith(_ other: ScreenshotGroup) -> Bool {
        // Don't merge user-created groups
        if isUserCreated || other.isUserCreated {
            return false
        }
        
        // Only merge groups of the same type
        guard groupType == other.groupType else { return false }
        
        // Check specific merge criteria based on group type
        switch groupType {
        case .sequence:
            return shouldMergeSequence(with: other)
        case .contentSimilarity:
            return shouldMergeContentSimilarity(with: other)
        case .visualSimilarity:
            return shouldMergeVisualSimilarity(with: other)
        case .project:
            return shouldMergeProject(with: other)
        case .app:
            return shouldMergeApp(with: other)
        case .website:
            return shouldMergeWebsite(with: other)
        case .userCreated:
            return false
        }
    }
    
    // MARK: - Private Merge Logic
    
    private func shouldMergeSequence(with other: ScreenshotGroup) -> Bool {
        guard let thisRange = dateRange, let otherRange = other.dateRange else { return false }
        
        // Merge if sequences are within 10 minutes of each other
        let timeDifference = min(
            abs(thisRange.end.timeIntervalSince(otherRange.start)),
            abs(otherRange.end.timeIntervalSince(thisRange.start))
        )
        
        return timeDifference <= 600 // 10 minutes
    }
    
    private func shouldMergeContentSimilarity(with other: ScreenshotGroup) -> Bool {
        // Check if they share the same website or app
        if let thisURL = websiteURL, let otherURL = other.websiteURL {
            return thisURL == otherURL
        }
        
        if let thisApp = appName, let otherApp = other.appName {
            return thisApp == otherApp
        }
        
        return false
    }
    
    private func shouldMergeVisualSimilarity(with other: ScreenshotGroup) -> Bool {
        // Merge if they have the same app or website
        return (appName == other.appName && appName != nil) ||
               (websiteURL == other.websiteURL && websiteURL != nil)
    }
    
    private func shouldMergeProject(with other: ScreenshotGroup) -> Bool {
        // Projects merge if they share common characteristics and are within a reasonable timeframe
        guard let thisRange = dateRange, let otherRange = other.dateRange else { return false }
        
        let timeDifference = min(
            abs(thisRange.end.timeIntervalSince(otherRange.start)),
            abs(otherRange.end.timeIntervalSince(thisRange.start))
        )
        
        // Merge if within 24 hours and share app or website
        return timeDifference <= 86400 && (
            (appName == other.appName && appName != nil) ||
            (websiteURL == other.websiteURL && websiteURL != nil)
        )
    }
    
    private func shouldMergeApp(with other: ScreenshotGroup) -> Bool {
        return appName == other.appName && appName != nil
    }
    
    private func shouldMergeWebsite(with other: ScreenshotGroup) -> Bool {
        return websiteURL == other.websiteURL && websiteURL != nil
    }
}

// MARK: - Group Types

public enum GroupType: String, Codable, CaseIterable, Comparable {
    case sequence = "sequence"
    case contentSimilarity = "content_similarity"
    case visualSimilarity = "visual_similarity"
    case project = "project"
    case app = "app"
    case website = "website"
    case userCreated = "user_created"
    
    public var displayName: String {
        switch self {
        case .sequence:
            return "Sequence"
        case .contentSimilarity:
            return "Similar Content"
        case .visualSimilarity:
            return "Visually Similar"
        case .project:
            return "Project"
        case .app:
            return "App Session"
        case .website:
            return "Website"
        case .userCreated:
            return "Custom Group"
        }
    }
    
    public var icon: String {
        switch self {
        case .sequence:
            return "arrow.right.circle"
        case .contentSimilarity:
            return "doc.text.magnifyingglass"
        case .visualSimilarity:
            return "eye.circle"
        case .project:
            return "folder.circle"
        case .app:
            return "app.badge"
        case .website:
            return "globe.circle"
        case .userCreated:
            return "person.circle"
        }
    }
    
    public var color: Color {
        switch self {
        case .sequence:
            return .blue
        case .contentSimilarity:
            return .green
        case .visualSimilarity:
            return .purple
        case .project:
            return .orange
        case .app:
            return .red
        case .website:
            return .cyan
        case .userCreated:
            return .indigo
        }
    }
    
    public var priority: Int {
        switch self {
        case .userCreated:
            return 0 // Highest priority
        case .project:
            return 1
        case .sequence:
            return 2
        case .contentSimilarity:
            return 3
        case .visualSimilarity:
            return 4
        case .app:
            return 5
        case .website:
            return 6
        }
    }
    
    // MARK: - Comparable Conformance
    
    public static func < (lhs: GroupType, rhs: GroupType) -> Bool {
        return lhs.priority < rhs.priority
    }
}

// MARK: - Group Statistics

public struct GroupStatistics {
    public let totalGroups: Int
    public let groupsByType: [GroupType: Int]
    public let averageGroupSize: Double
    public let largestGroupSize: Int
    public let ungroupedScreenshots: Int
    public let groupingConfidence: Double
    
    public init(groups: [ScreenshotGroup], totalScreenshots: Int) {
        self.totalGroups = groups.count
        
        var typeCount: [GroupType: Int] = [:]
        var totalScreenshotsInGroups = 0
        var totalConfidence = 0.0
        
        for group in groups {
            typeCount[group.groupType, default: 0] += 1
            totalScreenshotsInGroups += group.screenshotCount
            totalConfidence += group.confidence
        }
        
        self.groupsByType = typeCount
        self.averageGroupSize = totalGroups > 0 ? Double(totalScreenshotsInGroups) / Double(totalGroups) : 0
        self.largestGroupSize = groups.map { $0.screenshotCount }.max() ?? 0
        self.ungroupedScreenshots = totalScreenshots - totalScreenshotsInGroups
        self.groupingConfidence = totalGroups > 0 ? totalConfidence / Double(totalGroups) : 0
    }
}

// MARK: - Extensions

extension ScreenshotGroup: Identifiable {}

extension ScreenshotGroup: Equatable {
    public static func == (lhs: ScreenshotGroup, rhs: ScreenshotGroup) -> Bool {
        return lhs.id == rhs.id
    }
}

extension ScreenshotGroup: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}