//
//  SearchScreenshotsIntent.swift
//  ScreenshotNotes
//
//  Sprint 5.3.2: Siri App Intents Foundation
//  Created by Assistant on 7/5/25.
//

import AppIntents
import Foundation
import SwiftData
import SwiftUI

// MARK: - Search Type Entity

/// Entity representing different types of search operations for Siri
@available(iOS 16.0, *)
enum SearchTypeEntity: String, AppEnum {
    case content = "content"
    case visual = "visual"
    case temporal = "temporal"
    case business = "business"
    case all = "all"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Search Type")
    }
    
    static var caseDisplayRepresentations: [SearchTypeEntity: DisplayRepresentation] {
        [
            .content: DisplayRepresentation(
                title: "Text Content",
                subtitle: "Search within text found in screenshots"
            ),
            .visual: DisplayRepresentation(
                title: "Visual Elements", 
                subtitle: "Search for objects, colors, and visual attributes"
            ),
            .temporal: DisplayRepresentation(
                title: "Date & Time",
                subtitle: "Search by when screenshots were taken"
            ),
            .business: DisplayRepresentation(
                title: "Business & Receipts",
                subtitle: "Search for business-related screenshots"
            ),
            .all: DisplayRepresentation(
                title: "Everything",
                subtitle: "Search all aspects of screenshots"
            )
        ]
    }
}

// MARK: - Screenshot Entity

/// Entity representing a screenshot for Siri App Intents
@available(iOS 16.0, *)
struct ScreenshotEntity: AppEntity {
    typealias DefaultQuery = ScreenshotEntityQuery
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Screenshot")
    }
    
    static var defaultQuery = ScreenshotEntityQuery()
    
    // MARK: - Properties
    
    var id: String
    var displayString: String
    var timestamp: Date
    var extractedText: String?
    var semanticTags: [String]?
    var userNotes: String?
    
    // MARK: - Display Representation
    
    var displayRepresentation: DisplayRepresentation {
        let subtitle = generateSubtitle()
        let image = DisplayRepresentation.Image(systemName: "camera.fill")
        
        return DisplayRepresentation(
            title: "\(displayString)",
            subtitle: LocalizedStringResource(stringLiteral: subtitle),
            image: image
        )
    }
    
    // MARK: - Initializers
    
    init(id: String, displayString: String, timestamp: Date, extractedText: String? = nil, semanticTags: [String]? = nil, userNotes: String? = nil) {
        self.id = id
        self.displayString = displayString
        self.timestamp = timestamp
        self.extractedText = extractedText
        self.semanticTags = semanticTags
        self.userNotes = userNotes
    }
    
    // MARK: - Helper Methods
    
    private func generateSubtitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var components: [String] = []
        
        // Add timestamp
        components.append(formatter.string(from: timestamp))
        
        // Add content preview
        if let text = extractedText?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !text.isEmpty {
            let preview = String(text.prefix(50))
            if text.count > 50 {
                components.append("\(preview)...")
            } else {
                components.append(preview)
            }
        } else if let tags = semanticTags, !tags.isEmpty {
            components.append("Tags: \(tags.prefix(3).joined(separator: ", "))")
        }
        
        return components.joined(separator: " • ")
    }
}

// MARK: - Entity Query

@available(iOS 16.0, *)
struct ScreenshotEntityQuery: EntityQuery {
    typealias Entity = ScreenshotEntity
    
    func entities(for identifiers: [ScreenshotEntity.ID]) async throws -> [ScreenshotEntity] {
        // This would typically fetch from the data source
        // For now, return empty array as this is used for disambiguation
        return []
    }
    
    func suggestedEntities() async throws -> [ScreenshotEntity] {
        // Return recent screenshots for suggestions
        // This would typically fetch from the data source
        return []
    }
    
    func defaultResult() async -> ScreenshotEntity? {
        // Return nil as there's no default screenshot
        return nil
    }
}

/// Siri App Intent for searching screenshots using natural language
@available(iOS 16.0, *)
struct SearchScreenshotsIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Screenshots"
    static var description = IntentDescription("Search your screenshots using natural language")
    
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true
    
    // MARK: - Parameters
    
    @Parameter(title: "Search Query", description: "What would you like to search for?")
    var searchQuery: String
    
    @Parameter(title: "Search Type", description: "How would you like to search?", default: .content)
    var searchType: SearchTypeEntity
    
    // MARK: - Shortcuts and Phrases
    
    static var parameterSummary: some ParameterSummary {
        Summary("Search for \(\.$searchQuery)") {
            \.$searchType
        }
    }
    
    /// Predefined shortcut phrases for better Siri recognition
    static var shortcutPhrases: [String] = [
        "Search screenshots for receipts",
        "Find screenshots with blue dress",
        "Show me screenshots from Marriott",
        "Search Screenshot Vault for phone numbers",
        "Find screenshots from last week",
        "Look for screenshots with website links",
        "Search for screenshots with text",
        "Find my receipt screenshots",
        "Show screenshots with documents",
        "Search for screenshots with addresses"
    ]
    
    // MARK: - Intent Execution
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Validate input
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SearchError.emptyQuery
        }
        
        do {
            // Perform the search
            let results = try await performSearch()
            
            // Generate response dialog
            let dialogText = generateDialogText(for: results)
            
            // Return results with dialog - opens app to show results
            return .result(dialog: IntentDialog(stringLiteral: dialogText))
            
        } catch {
            // Handle errors gracefully
            let errorDialog = generateErrorDialog(for: error)
            return .result(dialog: IntentDialog(stringLiteral: errorDialog))
        }
    }
    
    // MARK: - Search Implementation
    
    private func performSearch() async throws -> [ScreenshotEntity] {
        // Get the SwiftData container
        let container = try await getModelContainer()
        let context = ModelContext(container)
        
        // Create descriptor for all screenshots
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        // Fetch screenshots
        let screenshots = try context.fetch(descriptor)
        
        // Filter based on search type and query
        let filteredScreenshots = await filterScreenshots(screenshots, query: searchQuery, type: searchType)
        
        // Convert to entities and limit results for Siri
        let entities = filteredScreenshots.prefix(10).map { screenshot in
            ScreenshotEntity(
                id: screenshot.id.uuidString,
                displayString: generateDisplayString(for: screenshot),
                timestamp: screenshot.timestamp,
                extractedText: screenshot.extractedText,
                semanticTags: screenshot.searchableTagNames,
                userNotes: screenshot.userNotes
            )
        }
        
        return Array(entities)
    }
    
    private func filterScreenshots(_ screenshots: [Screenshot], query: String, type: SearchTypeEntity) async -> [Screenshot] {
        let lowercaseQuery = query.lowercased()
        
        switch type {
        case .content:
            return screenshots.filter { screenshot in
                (screenshot.extractedText?.lowercased().contains(lowercaseQuery) ?? false) ||
                (screenshot.userNotes?.lowercased().contains(lowercaseQuery) ?? false)
            }
            
        case .visual:
            return screenshots.filter { screenshot in
                // Check semantic tags for visual elements
                let tags = screenshot.searchableTagNames
                return tags.contains { tag in
                    tag.lowercased().contains(lowercaseQuery) ||
                    isVisualMatch(tag: tag, query: lowercaseQuery)
                }
            }
            
        case .temporal:
            return filterByTemporalQuery(screenshots, query: lowercaseQuery)
            
        case .business:
            return screenshots.filter { screenshot in
                guard let text = screenshot.extractedText?.lowercased() else { return false }
                return isBusinessMatch(text: text, query: lowercaseQuery)
            }
            
        case .all:
            // Comprehensive search across all attributes
            return screenshots.filter { screenshot in
                (screenshot.extractedText?.lowercased().contains(lowercaseQuery) ?? false) ||
                (screenshot.userNotes?.lowercased().contains(lowercaseQuery) ?? false) ||
                screenshot.searchableTagNames.contains { $0.lowercased().contains(lowercaseQuery) }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateDisplayString(for screenshot: Screenshot) -> String {
        // Try to generate a meaningful title from content
        if let text = screenshot.extractedText?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !text.isEmpty {
            // Look for titles, headers, or important text
            let lines = text.components(separatedBy: CharacterSet.newlines)
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if trimmedLine.count > 5 && trimmedLine.count < 50 {
                    return trimmedLine
                }
            }
            
            // Fall back to first 30 characters
            return String(text.prefix(30)) + (text.count > 30 ? "..." : "")
        }
        
        // Try semantic tags
        let tags = screenshot.searchableTagNames
        if !tags.isEmpty {
            return tags.prefix(2).joined(separator: ", ").capitalized
        }
        
        // Fall back to timestamp-based name
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy 'at' h:mm a"
        return "Screenshot from \(formatter.string(from: screenshot.timestamp))"
    }
    
    private func isVisualMatch(tag: String, query: String) -> Bool {
        let visualKeywords = [
            "blue", "red", "green", "yellow", "black", "white", "color",
            "dress", "shirt", "clothing", "receipt", "document", "photo",
            "indoor", "outdoor", "text", "object", "person", "place"
        ]
        
        let tagLower = tag.lowercased()
        return visualKeywords.contains { keyword in
            tagLower.contains(keyword) && query.contains(keyword)
        }
    }
    
    private func isBusinessMatch(text: String, query: String) -> Bool {
        let businessKeywords = [
            "marriott", "hotel", "restaurant", "store", "receipt",
            "payment", "transaction", "invoice", "bill", "purchase"
        ]
        
        return businessKeywords.contains { keyword in
            text.contains(keyword) && query.contains(keyword)
        }
    }
    
    private func filterByTemporalQuery(_ screenshots: [Screenshot], query: String) -> [Screenshot] {
        let calendar = Calendar.current
        let now = Date()
        
        let dateRange: DateInterval?
        
        if query.contains("today") {
            dateRange = DateInterval(start: calendar.startOfDay(for: now), end: now)
        } else if query.contains("yesterday") {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            dateRange = DateInterval(start: calendar.startOfDay(for: yesterday), 
                                   end: calendar.startOfDay(for: now))
        } else if query.contains("last week") || query.contains("this week") {
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            dateRange = DateInterval(start: weekAgo, end: now)
        } else if query.contains("last month") {
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            dateRange = DateInterval(start: monthAgo, end: now)
        } else {
            dateRange = nil
        }
        
        guard let range = dateRange else { return screenshots }
        
        return screenshots.filter { screenshot in
            range.contains(screenshot.timestamp)
        }
    }
    
    private func getModelContainer() async throws -> ModelContainer {
        // Access the shared model container
        let schema = Schema([Screenshot.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
    
    // MARK: - Response Generation
    
    private func generateDialogText(for results: [ScreenshotEntity]) -> String {
        let count = results.count
        
        switch count {
        case 0:
            return "I couldn't find any screenshots matching '\(searchQuery)'. Try a different search term or open Screenshot Vault to see all your screenshots."
            
        case 1:
            return "I found 1 screenshot matching '\(searchQuery)'. Opening Screenshot Vault to show the result."
            
        case 2...5:
            return "I found \(count) screenshots matching '\(searchQuery)'. Opening Screenshot Vault to show the results."
            
        case 6...10:
            return "I found \(count) screenshots matching '\(searchQuery)'. Opening Screenshot Vault to show the most recent ones."
            
        default:
            return "I found many screenshots matching '\(searchQuery)'. Opening Screenshot Vault to show the 10 most recent ones."
        }
    }
    
    private func generateErrorDialog(for error: Error) -> String {
        if error is SearchError {
            switch error as! SearchError {
            case .emptyQuery:
                return "Please provide a search term to look for in your screenshots."
            case .noPermission:
                return "I need permission to access your screenshots. Please open Screenshot Vault to grant access."
            case .dataUnavailable:
                return "Your screenshots aren't available right now. Please try again later."
            }
        }
        
        return "I couldn't search your screenshots right now. Please open Screenshot Vault and try again."
    }
}

// MARK: - Search Error Types

enum SearchError: LocalizedError {
    case emptyQuery
    case noPermission
    case dataUnavailable
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Search query cannot be empty"
        case .noPermission:
            return "Permission denied to access screenshots"
        case .dataUnavailable:
            return "Screenshot data is not available"
        }
    }
}
