//
//  ContentConstellation.swift
//  ScreenshotNotes
//
//  Sprint 8.2.1: Content Constellation Model for Smart Grouping
//  Created by Assistant on 7/14/25.
//

import Foundation
import SwiftUI

/// Represents a smart grouping of related content (screenshots) organized around activities, projects, or themes
/// Core data structure for the Constellation mode in Enhanced Interface
struct ContentConstellation: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let emoji: String
    let type: ConstellationType
    let screenshotIds: [UUID]
    let completionPercentage: Double
    let lastUpdated: Date
    let isActive: Bool
    
    // Optional metadata
    let description: String?
    let tags: [String]
    let priority: Priority
    let estimatedTimeToComplete: TimeInterval?
    let dueDate: Date?
    let createdDate: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        emoji: String,
        type: ConstellationType,
        screenshotIds: [UUID],
        completionPercentage: Double = 0.0,
        lastUpdated: Date = Date(),
        isActive: Bool = true,
        description: String? = nil,
        tags: [String] = [],
        priority: Priority = .medium,
        estimatedTimeToComplete: TimeInterval? = nil,
        dueDate: Date? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.type = type
        self.screenshotIds = screenshotIds
        self.completionPercentage = max(0, min(1, completionPercentage))
        self.lastUpdated = lastUpdated
        self.isActive = isActive
        self.description = description
        self.tags = tags
        self.priority = priority
        self.estimatedTimeToComplete = estimatedTimeToComplete
        self.dueDate = dueDate
        self.createdDate = createdDate
    }
}

/// Types of content constellations with associated colors and behaviors
enum ConstellationType: String, CaseIterable, Codable {
    case travel = "travel"
    case project = "project"
    case work = "work"
    case home = "home"
    case health = "health"
    case finance = "finance"
    case education = "education"
    case shopping = "shopping"
    case social = "social"
    case entertainment = "entertainment"
    case food = "food"
    case fitness = "fitness"
    case other = "other"
    
    /// Display name for the constellation type
    var displayName: String {
        switch self {
        case .travel:
            return "Travel"
        case .project:
            return "Project"
        case .work:
            return "Work"
        case .home:
            return "Home"
        case .health:
            return "Health"
        case .finance:
            return "Finance"
        case .education:
            return "Education"
        case .shopping:
            return "Shopping"
        case .social:
            return "Social"
        case .entertainment:
            return "Entertainment"
        case .food:
            return "Food"
        case .fitness:
            return "Fitness"
        case .other:
            return "Other"
        }
    }
    
    /// Associated color for UI representation
    var color: Color {
        switch self {
        case .travel:
            return .orange
        case .project:
            return .blue
        case .work:
            return .indigo
        case .home:
            return .green
        case .health:
            return .red
        case .finance:
            return .yellow
        case .education:
            return .purple
        case .shopping:
            return .pink
        case .social:
            return .teal
        case .entertainment:
            return .cyan
        case .food:
            return .brown
        case .fitness:
            return .mint
        case .other:
            return .gray
        }
    }
    
    /// SF Symbol icon for the type
    var icon: String {
        switch self {
        case .travel:
            return "airplane"
        case .project:
            return "folder.badge.gear"
        case .work:
            return "briefcase"
        case .home:
            return "house"
        case .health:
            return "heart.text.square"
        case .finance:
            return "dollarsign.circle"
        case .education:
            return "graduationcap"
        case .shopping:
            return "bag"
        case .social:
            return "person.2"
        case .entertainment:
            return "tv"
        case .food:
            return "fork.knife"
        case .fitness:
            return "figure.run"
        case .other:
            return "questionmark.folder"
        }
    }
    
    /// Typical activities for this constellation type
    var typicalActivities: [String] {
        switch self {
        case .travel:
            return ["Book flights", "Reserve hotels", "Plan itinerary", "Pack luggage", "Get travel insurance"]
        case .project:
            return ["Define scope", "Create timeline", "Assign tasks", "Track progress", "Review deliverables"]
        case .work:
            return ["Attend meetings", "Complete reports", "Review documents", "Collaborate with team"]
        case .home:
            return ["Pay bills", "Schedule maintenance", "Track warranties", "Plan improvements"]
        case .health:
            return ["Schedule appointments", "Track medications", "Monitor symptoms", "Review test results"]
        case .finance:
            return ["Track expenses", "Review statements", "Pay bills", "Plan budget", "File taxes"]
        case .education:
            return ["Attend classes", "Complete assignments", "Study materials", "Take exams"]
        case .shopping:
            return ["Research products", "Compare prices", "Track orders", "Manage returns"]
        case .social:
            return ["Plan events", "Share updates", "Coordinate activities", "Stay connected"]
        case .entertainment:
            return ["Watch shows", "Listen to music", "Play games", "Read books"]
        case .food:
            return ["Plan meals", "Shop for groceries", "Try recipes", "Track nutrition"]
        case .fitness:
            return ["Track workouts", "Monitor progress", "Set goals", "Stay motivated"]
        case .other:
            return ["Organize content", "Track information", "Manage tasks"]
        }
    }
}

/// Priority levels for constellations
enum Priority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .urgent:
            return "Urgent"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return .gray
        case .medium:
            return .blue
        case .high:
            return .orange
        case .urgent:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low:
            return "minus.circle"
        case .medium:
            return "circle"
        case .high:
            return "plus.circle"
        case .urgent:
            return "exclamationmark.circle"
        }
    }
}

/// Constellation workspace status
enum ConstellationStatus: String, CaseIterable, Codable {
    case planning = "planning"
    case active = "active"
    case onHold = "on_hold"
    case completed = "completed"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .planning:
            return "Planning"
        case .active:
            return "Active"
        case .onHold:
            return "On Hold"
        case .completed:
            return "Completed"
        case .archived:
            return "Archived"
        }
    }
    
    var color: Color {
        switch self {
        case .planning:
            return .blue
        case .active:
            return .green
        case .onHold:
            return .yellow
        case .completed:
            return .purple
        case .archived:
            return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .planning:
            return "lightbulb"
        case .active:
            return "play.circle"
        case .onHold:
            return "pause.circle"
        case .completed:
            return "checkmark.circle"
        case .archived:
            return "archivebox"
        }
    }
}

/// Constellation analytics and insights
struct ConstellationAnalytics: Codable {
    let averageCompletionTime: TimeInterval?
    let mostActiveHour: Int? // 0-23
    let mostActiveDayOfWeek: Int? // 1-7 (Sunday = 1)
    let totalTimeSpent: TimeInterval
    let screenshotAdditionRate: Double // screenshots per day
    let completionRate: Double // percentage of tasks completed on time
    let lastAnalyzed: Date
    
    init(
        averageCompletionTime: TimeInterval? = nil,
        mostActiveHour: Int? = nil,
        mostActiveDayOfWeek: Int? = nil,
        totalTimeSpent: TimeInterval = 0,
        screenshotAdditionRate: Double = 0,
        completionRate: Double = 0,
        lastAnalyzed: Date = Date()
    ) {
        self.averageCompletionTime = averageCompletionTime
        self.mostActiveHour = mostActiveHour
        self.mostActiveDayOfWeek = mostActiveDayOfWeek
        self.totalTimeSpent = totalTimeSpent
        self.screenshotAdditionRate = screenshotAdditionRate
        self.completionRate = completionRate
        self.lastAnalyzed = lastAnalyzed
    }
}

// MARK: - Extensions

extension ContentConstellation {
    /// Returns a formatted string for the completion percentage
    var completionText: String {
        return "\(Int(completionPercentage * 100))% complete"
    }
    
    /// Returns true if the constellation is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return Date() > dueDate && completionPercentage < 1.0
    }
    
    /// Returns true if the constellation is due soon (within 3 days)
    var isDueSoon: Bool {
        guard let dueDate = dueDate else { return false }
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return dueDate <= threeDaysFromNow && completionPercentage < 1.0
    }
    
    /// Returns the status color based on completion and due date
    var statusColor: Color {
        if isOverdue {
            return .red
        } else if isDueSoon {
            return .orange
        } else if completionPercentage >= 1.0 {
            return .green
        } else {
            return type.color
        }
    }
    
    /// Returns a suggested next action based on the constellation type and completion
    var suggestedNextAction: String? {
        let activities = type.typicalActivities
        let completedActivities = Int(completionPercentage * Double(activities.count))
        
        if completedActivities < activities.count {
            return activities[completedActivities]
        }
        
        return nil
    }
    
    /// Returns the estimated days until completion based on current progress rate
    var estimatedDaysToCompletion: Int? {
        guard completionPercentage > 0 && completionPercentage < 1.0 else { return nil }
        
        let daysSinceCreated = Calendar.current.dateComponents([.day], from: createdDate, to: Date()).day ?? 1
        let progressRate = completionPercentage / Double(max(1, daysSinceCreated))
        let remainingProgress = 1.0 - completionPercentage
        
        return Int(ceil(remainingProgress / progressRate))
    }
}