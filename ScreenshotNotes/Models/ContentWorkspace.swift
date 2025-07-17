
import Foundation
import SwiftData

@Model
public final class ContentWorkspace {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var type: WorkspaceType
    public var screenshots: [Screenshot]
    public var progress: WorkspaceProgress
    public var suggestedActions: [WorkspaceAction]
    public var createdAt: Date
    public var lastUpdated: Date
    public var isArchived: Bool
    public var detectionConfidence: Double
    public var userModified: Bool
    public var iconName: String
    public var colorScheme: String

    public enum WorkspaceType: Codable, Equatable, Hashable {
        case travel(destination: String, dates: DateInterval)
        case project(name: String, status: ProjectStatus)
        case event(title: String, date: Date)
        case learning(subject: String, progress: Double)
        case shopping(category: String, budget: Double?)
        case health(category: String, provider: String?)
        case other(name: String)
        
        public var displayName: String {
            switch self {
            case .travel(let destination, _): return "Trip to \(destination)"
            case .project(let name, _): return name
            case .event(let title, _): return title
            case .learning(let subject, _): return "Learning \(subject)"
            case .shopping(let category, _): return "\(category) Shopping"
            case .health(let category, _): return "\(category) Health"
            case .other(let name): return name
            }
        }
        
        public var categoryIcon: String {
            switch self {
            case .travel: return "airplane"
            case .project: return "folder"
            case .event: return "calendar"
            case .learning: return "book"
            case .shopping: return "cart"
            case .health: return "heart"
            case .other: return "square.grid.3x3"
            }
        }
        
        public var colorScheme: String {
            switch self {
            case .travel: return "blue"
            case .project: return "purple"
            case .event: return "green"
            case .learning: return "orange"
            case .shopping: return "pink"
            case .health: return "red"
            case .other: return "gray"
            }
        }
    }

    public enum ProjectStatus: Codable, Equatable {
        case active, completed, onHold, cancelled
        
        public var displayName: String {
            switch self {
            case .active: return "Active"
            case .completed: return "Completed"
            case .onHold: return "On Hold"
            case .cancelled: return "Cancelled"
            }
        }
    }

    public struct WorkspaceProgress: Codable, Equatable {
        public var percentage: Double
        public var completedTasks: Int
        public var totalTasks: Int
        public var missingComponents: [String]
        public var lastProgressUpdate: Date
        
        public init(percentage: Double = 0.0, completedTasks: Int = 0, totalTasks: Int = 0, missingComponents: [String] = [], lastProgressUpdate: Date = Date()) {
            self.percentage = max(0.0, min(100.0, percentage))
            self.completedTasks = max(0, completedTasks)
            self.totalTasks = max(0, totalTasks)
            self.missingComponents = missingComponents
            self.lastProgressUpdate = lastProgressUpdate
        }
        
        public var isComplete: Bool {
            return percentage >= 100.0
        }
        
        public var completionRatio: Double {
            guard totalTasks > 0 else { return 0.0 }
            return Double(completedTasks) / Double(totalTasks)
        }
    }

    public enum WorkspaceAction: Codable, Equatable {
        case addScreenshot
        case completeTask(String)
        case setBudget(Double)
        case scheduleEvent
        case addMissingComponent(String)
        case archiveWorkspace
        case shareWorkspace
        case exportToCalendar
        case exportToPDF
        
        public var displayName: String {
            switch self {
            case .addScreenshot: return "Add Screenshot"
            case .completeTask(let task): return "Complete: \(task)"
            case .setBudget(let amount): return "Set Budget: $\(String(format: "%.2f", amount))"
            case .scheduleEvent: return "Schedule Event"
            case .addMissingComponent(let component): return "Add \(component)"
            case .archiveWorkspace: return "Archive Workspace"
            case .shareWorkspace: return "Share Workspace"
            case .exportToCalendar: return "Export to Calendar"
            case .exportToPDF: return "Export to PDF"
            }
        }
        
        public var iconName: String {
            switch self {
            case .addScreenshot: return "camera.fill"
            case .completeTask: return "checkmark.circle.fill"
            case .setBudget: return "dollarsign.circle.fill"
            case .scheduleEvent: return "calendar.badge.plus"
            case .addMissingComponent: return "plus.circle.fill"
            case .archiveWorkspace: return "archivebox.fill"
            case .shareWorkspace: return "square.and.arrow.up"
            case .exportToCalendar: return "calendar"
            case .exportToPDF: return "doc.fill"
            }
        }
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        type: WorkspaceType,
        screenshots: [Screenshot] = [],
        progress: WorkspaceProgress = WorkspaceProgress(),
        suggestedActions: [WorkspaceAction] = [],
        createdAt: Date = Date(),
        lastUpdated: Date = Date(),
        isArchived: Bool = false,
        detectionConfidence: Double = 0.0,
        userModified: Bool = false
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.screenshots = screenshots
        self.progress = progress
        self.suggestedActions = suggestedActions
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.isArchived = isArchived
        self.detectionConfidence = max(0.0, min(1.0, detectionConfidence))
        self.userModified = userModified
        self.iconName = type.categoryIcon
        self.colorScheme = type.colorScheme
    }
    
    // MARK: - Workspace Management
    
    public func addScreenshot(_ screenshot: Screenshot) {
        guard !screenshots.contains(where: { $0.id == screenshot.id }) else { return }
        screenshots.append(screenshot)
        lastUpdated = Date()
        userModified = true
        updateProgress()
    }
    
    public func removeScreenshot(_ screenshot: Screenshot) {
        screenshots.removeAll { $0.id == screenshot.id }
        lastUpdated = Date()
        userModified = true
        updateProgress()
    }
    
    public func updateProgress() {
        let totalScreenshots = screenshots.count
        let completedScreenshots = screenshots.filter { $0.isFavorite }.count // Using favorite as proxy for completion
        
        progress.totalTasks = totalScreenshots
        progress.completedTasks = completedScreenshots
        progress.percentage = totalScreenshots > 0 ? Double(completedScreenshots) / Double(totalScreenshots) * 100.0 : 0.0
        progress.lastProgressUpdate = Date()
        
        // Update missing components based on workspace type
        updateMissingComponents()
    }
    
    private func updateMissingComponents() {
        var missing: [String] = []
        
        switch type {
        case .travel(_, _):
            let hasFlightInfo = screenshots.contains { $0.extractedText?.lowercased().contains("flight") == true }
            let hasHotelInfo = screenshots.contains { $0.extractedText?.lowercased().contains("hotel") == true }
            let hasCarRental = screenshots.contains { $0.extractedText?.lowercased().contains("rental") == true }
            
            if !hasFlightInfo { missing.append("Flight booking") }
            if !hasHotelInfo { missing.append("Hotel reservation") }
            if !hasCarRental { missing.append("Transportation") }
            
        case .project(_, let status):
            if status == .active {
                let hasProjectPlan = screenshots.contains { $0.extractedText?.lowercased().contains("plan") == true }
                let hasBudget = screenshots.contains { $0.extractedText?.lowercased().contains("budget") == true }
                
                if !hasProjectPlan { missing.append("Project plan") }
                if !hasBudget { missing.append("Budget information") }
            }
            
        case .event(_, _):
            let hasVenue = screenshots.contains { $0.extractedText?.lowercased().contains("venue") == true }
            let hasTickets = screenshots.contains { $0.extractedText?.lowercased().contains("ticket") == true }
            
            if !hasVenue { missing.append("Venue information") }
            if !hasTickets { missing.append("Tickets") }
            
        case .learning(_, _):
            let hasNotes = screenshots.contains { $0.extractedText?.lowercased().contains("note") == true }
            let hasAssignments = screenshots.contains { $0.extractedText?.lowercased().contains("assignment") == true }
            
            if !hasNotes { missing.append("Study notes") }
            if !hasAssignments { missing.append("Assignments") }
            
        case .shopping(_, let budget):
            let hasReceipts = screenshots.contains { $0.extractedText?.lowercased().contains("receipt") == true }
            let hasWishlist = screenshots.contains { $0.extractedText?.lowercased().contains("wishlist") == true }
            
            if !hasReceipts { missing.append("Purchase receipts") }
            if budget != nil && !hasWishlist { missing.append("Shopping list") }
            
        case .health(_, _):
            let hasAppointments = screenshots.contains { $0.extractedText?.lowercased().contains("appointment") == true }
            let hasResults = screenshots.contains { $0.extractedText?.lowercased().contains("result") == true }
            
            if !hasAppointments { missing.append("Appointment confirmations") }
            if !hasResults { missing.append("Test results") }
            
        case .other:
            break
        }
        
        progress.missingComponents = missing
    }
    
    // MARK: - Workspace Analysis
    
    public var isHighConfidence: Bool {
        return detectionConfidence >= 0.8
    }
    
    public var needsUserReview: Bool {
        return detectionConfidence < 0.7 && !userModified
    }
    
    public var activityLevel: WorkspaceActivityLevel {
        let daysSinceUpdate = Date().timeIntervalSince(lastUpdated) / 86400 // seconds in a day
        
        if daysSinceUpdate <= 1 {
            return .veryActive
        } else if daysSinceUpdate <= 7 {
            return .active
        } else if daysSinceUpdate <= 30 {
            return .moderate
        } else {
            return .stale
        }
    }
    
    public enum WorkspaceActivityLevel: String, CaseIterable {
        case veryActive = "Very Active"
        case active = "Active"
        case moderate = "Moderate"
        case stale = "Stale"
        
        public var color: String {
            switch self {
            case .veryActive: return "green"
            case .active: return "blue"
            case .moderate: return "yellow"
            case .stale: return "gray"
            }
        }
    }
    
    // MARK: - Workspace Sorting & Filtering
    
    public static func sortWorkspaces(_ workspaces: [ContentWorkspace], by criteria: SortCriteria) -> [ContentWorkspace] {
        switch criteria {
        case .lastUpdated:
            return workspaces.sorted { $0.lastUpdated > $1.lastUpdated }
        case .alphabetical:
            return workspaces.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress:
            return workspaces.sorted { $0.progress.percentage > $1.progress.percentage }
        case .confidence:
            return workspaces.sorted { $0.detectionConfidence > $1.detectionConfidence }
        case .screenshotCount:
            return workspaces.sorted { $0.screenshots.count > $1.screenshots.count }
        }
    }
    
    public enum SortCriteria: String, CaseIterable {
        case lastUpdated = "Last Updated"
        case alphabetical = "Alphabetical"
        case progress = "Progress"
        case confidence = "Confidence"
        case screenshotCount = "Screenshot Count"
    }
}
