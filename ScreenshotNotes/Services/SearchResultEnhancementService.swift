//
//  SearchResultEnhancementService.swift
//  ScreenshotNotes
//
//  Sub-Sprint 5.3.3: Conversational Search UI & Siri Response Interface
//  Created by Assistant on 7/5/25.
//

import Foundation
import SwiftUI
import NaturalLanguage

/// Service for enhancing search results with intelligent feedback and presentation
@MainActor
class SearchResultEnhancementService: ObservableObject {
    @Published var lastSearchMetrics: SearchMetrics?
    @Published var searchInsights: [SearchInsight] = []
    
    private let conversationalService = ConversationalSearchService()
    
    // MARK: - Search Result Enhancement
    
    func enhanceSearchResults(
        query: String,
        results: [Screenshot],
        allScreenshots: [Screenshot]
    ) async -> EnhancedSearchPresentation {
        
        let metrics = calculateSearchMetrics(query: query, results: results, total: allScreenshots.count)
        await MainActor.run {
            self.lastSearchMetrics = metrics
        }
        
        let insights = await generateSearchInsights(query: query, results: results, metrics: metrics)
        await MainActor.run {
            self.searchInsights = insights
        }
        
        let groupedResults = groupSearchResults(results, query: query)
        let suggestions = await generateSmartSuggestions(query: query, results: results, allScreenshots: allScreenshots)
        
        return EnhancedSearchPresentation(
            originalQuery: query,
            results: results,
            groupedResults: groupedResults,
            metrics: metrics,
            insights: insights,
            suggestions: suggestions,
            timestamp: Date()
        )
    }
    
    // MARK: - Search Metrics
    
    private func calculateSearchMetrics(query: String, results: [Screenshot], total: Int) -> SearchMetrics {
        let resultCount = results.count
        let percentage = total > 0 ? Double(resultCount) / Double(total) * 100 : 0
        
        // Analyze temporal distribution
        let now = Date()
        let calendar = Calendar.current
        
        let recent = results.filter { calendar.isDateInToday($0.timestamp) || calendar.isDateInYesterday($0.timestamp) }
        let thisWeek = results.filter { calendar.isDate($0.timestamp, equalTo: now, toGranularity: .weekOfYear) }
        let thisMonth = results.filter { calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month) }
        
        // Analyze content types
        let withText = results.filter { !($0.extractedText?.isEmpty ?? true) }
        let withTags = results.filter { !$0.searchableTagNames.isEmpty }
        let withNotes = results.filter { !($0.userNotes?.isEmpty ?? true) }
        
        // Calculate relevance score
        let relevanceScore = calculateRelevanceScore(query: query, results: results)
        
        return SearchMetrics(
            resultCount: resultCount,
            totalScreenshots: total,
            percentage: percentage,
            relevanceScore: relevanceScore,
            recentCount: recent.count,
            weekCount: thisWeek.count,
            monthCount: thisMonth.count,
            withTextCount: withText.count,
            withTagsCount: withTags.count,
            withNotesCount: withNotes.count,
            searchDuration: 0 // Will be updated by calling service
        )
    }
    
    private func calculateRelevanceScore(query: String, results: [Screenshot]) -> Double {
        guard !results.isEmpty else { return 0 }
        
        let queryWords = query.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var totalScore: Double = 0
        
        for screenshot in results {
            var score: Double = 0
            
            // Check filename matches
            for word in queryWords {
                if screenshot.filename.lowercased().contains(word) {
                    score += 0.3
                }
            }
            
            // Check extracted text matches
            if let text = screenshot.extractedText {
                for word in queryWords {
                    if text.lowercased().contains(word) {
                        score += 0.4
                    }
                }
            }
            
            // Check tag matches
            for word in queryWords {
                if screenshot.searchableTagNames.contains(where: { $0.lowercased().contains(word) }) {
                    score += 0.3
                }
            }
            
            totalScore += min(1.0, score) // Cap individual scores at 1.0
        }
        
        return totalScore / Double(results.count)
    }
    
    // MARK: - Search Insights
    
    private func generateSearchInsights(query: String, results: [Screenshot], metrics: SearchMetrics) async -> [SearchInsight] {
        var insights: [SearchInsight] = []
        
        // Result quantity insights
        if metrics.resultCount == 0 {
            insights.append(SearchInsight(
                type: .noResults,
                title: "No matches found",
                description: "Try broader terms or check spelling",
                icon: "magnifyingglass",
                color: .orange,
                actionSuggestion: "Try 'recent photos' or 'documents'"
            ))
        } else if metrics.resultCount == 1 {
            insights.append(SearchInsight(
                type: .exactMatch,
                title: "Perfect match",
                description: "Found exactly what you're looking for",
                icon: "target",
                color: .green
            ))
        } else if metrics.percentage < 5 {
            insights.append(SearchInsight(
                type: .preciseSearch,
                title: "Precise search",
                description: "Found \(metrics.resultCount) relevant screenshots",
                icon: "scope",
                color: .blue
            ))
        } else if metrics.percentage > 50 {
            insights.append(SearchInsight(
                type: .broadSearch,
                title: "Broad search",
                description: "Consider adding more specific terms",
                icon: "arrow.up.and.down.and.arrow.left.and.right",
                color: .orange,
                actionSuggestion: "Add color, date, or object terms"
            ))
        }
        
        // Temporal insights
        if metrics.recentCount > 0 {
            let percentage = Double(metrics.recentCount) / Double(metrics.resultCount) * 100
            if percentage > 70 {
                insights.append(SearchInsight(
                    type: .temporalPattern,
                    title: "Recent focus",
                    description: "\(Int(percentage))% from last 2 days",
                    icon: "clock.arrow.circlepath",
                    color: .cyan
                ))
            }
        }
        
        // Content type insights
        if metrics.withTextCount > 0 {
            let percentage = Double(metrics.withTextCount) / Double(metrics.resultCount) * 100
            if percentage > 80 {
                insights.append(SearchInsight(
                    type: .contentType,
                    title: "Text-rich results",
                    description: "\(Int(percentage))% contain readable text",
                    icon: "text.alignleft",
                    color: .green
                ))
            }
        }
        
        // Relevance insights
        if metrics.relevanceScore > 0.8 {
            insights.append(SearchInsight(
                type: .highRelevance,
                title: "High relevance",
                description: "Results closely match your search",
                icon: "star.fill",
                color: .yellow
            ))
        } else if metrics.relevanceScore < 0.3 {
            insights.append(SearchInsight(
                type: .lowRelevance,
                title: "Loose matches",
                description: "Results may be tangentially related",
                icon: "questionmark.circle",
                color: .orange,
                actionSuggestion: "Try more specific terms"
            ))
        }
        
        return insights
    }
    
    // MARK: - Result Grouping
    
    private func groupSearchResults(_ results: [Screenshot], query: String) -> [SearchResultGroup] {
        var groups: [SearchResultGroup] = []
        
        // Group by temporal patterns
        let calendar = Calendar.current
        let now = Date()
        
        let today = results.filter { calendar.isDateInToday($0.timestamp) }
        let yesterday = results.filter { calendar.isDateInYesterday($0.timestamp) }
        let thisWeek = results.filter { 
            calendar.isDate($0.timestamp, equalTo: now, toGranularity: .weekOfYear) && 
            !calendar.isDateInToday($0.timestamp) && 
            !calendar.isDateInYesterday($0.timestamp)
        }
        let older = results.filter { 
            !calendar.isDate($0.timestamp, equalTo: now, toGranularity: .weekOfYear)
        }
        
        if !today.isEmpty {
            groups.append(SearchResultGroup(
                title: "Today",
                screenshots: today,
                icon: "calendar.circle.fill",
                color: .blue
            ))
        }
        
        if !yesterday.isEmpty {
            groups.append(SearchResultGroup(
                title: "Yesterday", 
                screenshots: yesterday,
                icon: "calendar.circle",
                color: .cyan
            ))
        }
        
        if !thisWeek.isEmpty {
            groups.append(SearchResultGroup(
                title: "This Week",
                screenshots: thisWeek,
                icon: "calendar.badge.clock",
                color: .green
            ))
        }
        
        if !older.isEmpty {
            groups.append(SearchResultGroup(
                title: "Older",
                screenshots: older,
                icon: "clock.arrow.circlepath",
                color: .secondary
            ))
        }
        
        return groups
    }
    
    // MARK: - Smart Suggestions
    
    private func generateSmartSuggestions(query: String, results: [Screenshot], allScreenshots: [Screenshot]) async -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        
        // Analyze query for potential refinements
        let queryLower = query.lowercased()
        
        // Temporal suggestions
        if !queryLower.contains("today") && !queryLower.contains("yesterday") && !queryLower.contains("week") {
            suggestions.append(SmartSuggestion(
                type: .temporal,
                query: "\(query) from today",
                description: "Focus on recent screenshots",
                estimatedResults: estimateResults("\(query) from today", in: allScreenshots)
            ))
        }
        
        // Color suggestions
        if !hasColorTerms(queryLower) && results.contains(where: { hasColorInTags($0) }) {
            suggestions.append(SmartSuggestion(
                type: .visual,
                query: "\(query) blue",
                description: "Add color for visual search",
                estimatedResults: estimateResults("\(query) blue", in: allScreenshots)
            ))
        }
        
        // Business suggestions
        if !hasBusinessTerms(queryLower) && results.contains(where: { hasBusinessContent($0) }) {
            suggestions.append(SmartSuggestion(
                type: .business,
                query: "\(query) receipt",
                description: "Find business documents",
                estimatedResults: estimateResults("\(query) receipt", in: allScreenshots)
            ))
        }
        
        // Related term suggestions based on successful searches
        if results.count > 3 {
            let relatedTerms = findRelatedTerms(in: results)
            for term in relatedTerms.prefix(2) {
                suggestions.append(SmartSuggestion(
                    type: .related,
                    query: "\(query) \(term)",
                    description: "Common related term",
                    estimatedResults: estimateResults("\(query) \(term)", in: allScreenshots)
                ))
            }
        }
        
        return Array(suggestions.prefix(5))
    }
    
    // MARK: - Helper Methods
    
    private func hasColorTerms(_ query: String) -> Bool {
        let colorTerms = ["red", "blue", "green", "yellow", "orange", "purple", "pink", "black", "white", "gray", "brown"]
        return colorTerms.contains { query.contains($0) }
    }
    
    private func hasBusinessTerms(_ query: String) -> Bool {
        let businessTerms = ["receipt", "invoice", "bill", "business", "restaurant", "hotel", "store"]
        return businessTerms.contains { query.contains($0) }
    }
    
    private func hasColorInTags(_ screenshot: Screenshot) -> Bool {
        let colorTerms = ["red", "blue", "green", "yellow", "orange", "purple", "pink", "black", "white", "gray", "brown"]
        return screenshot.searchableTagNames.contains { tag in
            colorTerms.contains { tag.lowercased().contains($0) }
        }
    }
    
    private func hasBusinessContent(_ screenshot: Screenshot) -> Bool {
        let businessTerms = ["receipt", "invoice", "bill", "total", "$", "tax", "restaurant", "hotel"]
        let text = (screenshot.extractedText ?? "").lowercased()
        return businessTerms.contains { text.contains($0) }
    }
    
    private func findRelatedTerms(in screenshots: [Screenshot]) -> [String] {
        var termFrequency: [String: Int] = [:]
        
        for screenshot in screenshots {
            // Extract terms from tags
            for tag in screenshot.searchableTagNames {
                let words = tag.lowercased().components(separatedBy: .whitespacesAndNewlines)
                for word in words {
                    termFrequency[word, default: 0] += 1
                }
            }
            
            // Extract terms from text
            if let text = screenshot.extractedText {
                let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
                for word in words where word.count > 3 {
                    termFrequency[word, default: 0] += 1
                }
            }
        }
        
        return termFrequency
            .filter { $0.value >= 2 } // Must appear in at least 2 screenshots
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
    
    private func estimateResults(_ query: String, in screenshots: [Screenshot]) -> Int {
        // Simple estimation - in a real implementation, this would use the actual search service
        return Int(Double(screenshots.count) * 0.1) // Rough estimate
    }
}

// MARK: - Supporting Types

struct EnhancedSearchPresentation {
    let originalQuery: String
    let results: [Screenshot]
    let groupedResults: [SearchResultGroup]
    let metrics: SearchMetrics
    let insights: [SearchInsight]
    let suggestions: [SmartSuggestion]
    let timestamp: Date
}

struct SearchMetrics {
    let resultCount: Int
    let totalScreenshots: Int
    let percentage: Double
    let relevanceScore: Double
    let recentCount: Int
    let weekCount: Int
    let monthCount: Int
    let withTextCount: Int
    let withTagsCount: Int
    let withNotesCount: Int
    let searchDuration: TimeInterval
}

struct SearchInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let icon: String
    let color: Color
    let actionSuggestion: String?
    
    init(type: InsightType, title: String, description: String, icon: String, color: Color, actionSuggestion: String? = nil) {
        self.type = type
        self.title = title
        self.description = description
        self.icon = icon
        self.color = color
        self.actionSuggestion = actionSuggestion
    }
    
    enum InsightType {
        case noResults, exactMatch, preciseSearch, broadSearch
        case temporalPattern, contentType, highRelevance, lowRelevance
    }
}

struct SearchResultGroup: Identifiable {
    let id = UUID()
    let title: String
    let screenshots: [Screenshot]
    let icon: String
    let color: Color
}

struct SmartSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let query: String
    let description: String
    let estimatedResults: Int
    
    enum SuggestionType {
        case temporal, visual, business, related
        
        var icon: String {
            switch self {
            case .temporal: return "clock"
            case .visual: return "eye"
            case .business: return "building.2"
            case .related: return "link"
            }
        }
        
        var color: Color {
            switch self {
            case .temporal: return .orange
            case .visual: return .blue
            case .business: return .purple
            case .related: return .green
            }
        }
    }
}
