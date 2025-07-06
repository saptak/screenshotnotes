//
//  ConversationalSearchService.swift
//  ScreenshotNotes
//
//  Sub-Sprint 5.3.3: Conversational Search UI & Siri Response Interface
//  Created by Assistant on 7/5/25.
//

import Foundation
import NaturalLanguage
import SwiftUI

/// Service providing conversational search intelligence and query understanding
@MainActor
class ConversationalSearchService: ObservableObject {
    @Published var isReady = false
    
    private let entityExtractor = EntityExtractionService()
    private let queryParser = SimpleQueryParser()
    private var recentQueries: [String] = []
    private var queryHistory: [QueryHistoryItem] = []
    
    // MARK: - Initialization
    
    func initialize() {
        // Initialize AI services
        Task {
            await setupServices()
            isReady = true
        }
    }
    
    private func setupServices() async {
        // Load query history and user patterns
        loadQueryHistory()
        loadRecentQueries()
    }
    
    // MARK: - Query Understanding
    
    func analyzeQuery(_ query: String) async -> QueryUnderstanding {
        // Parse intent
        let intent = parseQueryIntent(query)
        
        // Extract entities
        let entities = await extractQueryEntities(query)
        
        // Calculate confidence based on clarity of intent and entities
        let confidence = calculateConfidence(intent: intent, entities: entities, query: query)
        
        return QueryUnderstanding(
            query: query,
            intent: intent,
            entities: entities,
            confidence: confidence,
            timestamp: Date()
        )
    }
    
    private func parseQueryIntent(_ query: String) -> QueryIntent {
        let lowercased = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Visual search patterns
        if lowercased.contains("blue") || lowercased.contains("red") || lowercased.contains("color") ||
           lowercased.contains("dress") || lowercased.contains("shirt") || lowercased.contains("photo") {
            return .visual
        }
        
        // Document search patterns
        if lowercased.contains("receipt") || lowercased.contains("document") || lowercased.contains("text") ||
           lowercased.contains("pdf") || lowercased.contains("invoice") || lowercased.contains("bill") {
            return .document
        }
        
        // Temporal search patterns
        if lowercased.contains("yesterday") || lowercased.contains("last week") || lowercased.contains("today") ||
           lowercased.contains("monday") || lowercased.contains("january") || lowercased.contains("2024") {
            return .temporal
        }
        
        // Business search patterns  
        if lowercased.contains("marriott") || lowercased.contains("amazon") || lowercased.contains("store") ||
           lowercased.contains("restaurant") || lowercased.contains("hotel") || lowercased.contains("company") {
            return .business
        }
        
        // Location search patterns
        if lowercased.contains("address") || lowercased.contains("location") || lowercased.contains("map") ||
           lowercased.contains("street") || lowercased.contains("city") || lowercased.contains("place") {
            return .location
        }
        
        // Contact search patterns
        if lowercased.contains("phone") || lowercased.contains("email") || lowercased.contains("contact") ||
           lowercased.contains("number") || lowercased.contains("@") || lowercased.contains("call") {
            return .contact
        }
        
        // Default to content search
        return .content
    }
    
    private func extractQueryEntities(_ query: String) async -> [QueryEntity] {
        var entities: [QueryEntity] = []
        
        // Use Natural Language framework for basic entity recognition
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = query
        
        let range = query.startIndex..<query.endIndex
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            let token = String(query[tokenRange])
            
            switch tag {
            case .personalName:
                entities.append(QueryEntity(type: .person, value: token, confidence: 0.8))
            case .placeName:
                entities.append(QueryEntity(type: .location, value: token, confidence: 0.8))
            case .organizationName:
                entities.append(QueryEntity(type: .business, value: token, confidence: 0.8))
            default:
                break
            }
            
            return true
        }
        
        // Additional pattern-based entity extraction
        entities.append(contentsOf: extractPatternEntities(query))
        
        return entities
    }
    
    private func extractPatternEntities(_ query: String) -> [QueryEntity] {
        var entities: [QueryEntity] = []
        
        // Color patterns
        let colorPattern = "\\b(red|blue|green|yellow|orange|purple|pink|black|white|gray|brown)\\b"
        if let colorRegex = try? NSRegularExpression(pattern: colorPattern, options: .caseInsensitive) {
            let matches = colorRegex.matches(in: query, options: [], range: NSRange(location: 0, length: query.count))
            for match in matches {
                if let range = Range(match.range, in: query) {
                    let color = String(query[range])
                    entities.append(QueryEntity(type: .color, value: color, confidence: 0.9))
                }
            }
        }
        
        // Date patterns
        let datePatterns = [
            "\\b(yesterday|today|tomorrow)\\b",
            "\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b",
            "\\b(january|february|march|april|may|june|july|august|september|october|november|december)\\b",
            "\\b(last|this|next)\\s+(week|month|year)\\b"
        ]
        
        for pattern in datePatterns {
            if let dateRegex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = dateRegex.matches(in: query, options: [], range: NSRange(location: 0, length: query.count))
                for match in matches {
                    if let range = Range(match.range, in: query) {
                        let date = String(query[range])
                        entities.append(QueryEntity(type: .date, value: date, confidence: 0.85))
                    }
                }
            }
        }
        
        // Object patterns
        let objectPatterns = [
            "\\b(dress|shirt|pants|shoes|bag|watch|glasses)\\b",
            "\\b(receipt|document|invoice|bill|ticket|card)\\b",
            "\\b(phone|laptop|computer|screen|monitor)\\b"
        ]
        
        for pattern in objectPatterns {
            if let objectRegex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = objectRegex.matches(in: query, options: [], range: NSRange(location: 0, length: query.count))
                for match in matches {
                    if let range = Range(match.range, in: query) {
                        let object = String(query[range])
                        entities.append(QueryEntity(type: .object, value: object, confidence: 0.8))
                    }
                }
            }
        }
        
        return entities
    }
    
    private func calculateConfidence(intent: QueryIntent, entities: [QueryEntity], query: String) -> Double {
        var confidence: Double = 0.5 // Base confidence
        
        // Boost confidence based on clear intent indicators
        if intent != .content {
            confidence += 0.2
        }
        
        // Boost confidence based on extracted entities
        let entityBoost = min(0.3, Double(entities.count) * 0.1)
        confidence += entityBoost
        
        // Boost confidence based on query specificity
        let wordCount = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        if wordCount >= 3 {
            confidence += 0.1
        }
        if wordCount >= 5 {
            confidence += 0.1
        }
        
        // Reduce confidence for very short or very long queries
        if wordCount < 2 {
            confidence -= 0.2
        }
        if wordCount > 10 {
            confidence -= 0.1
        }
        
        return min(1.0, max(0.0, confidence))
    }
    
    // MARK: - Smart Suggestions
    
    func generateSuggestions() async -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        // Add recent queries
        suggestions.append(contentsOf: generateRecentSuggestions())
        
        // Add popular patterns
        suggestions.append(contentsOf: generatePopularSuggestions())
        
        // Add contextual suggestions
        suggestions.append(contentsOf: generateContextualSuggestions())
        
        // Limit and prioritize
        return Array(suggestions.prefix(8))
    }
    
    private func generateRecentSuggestions() -> [SearchSuggestion] {
        return recentQueries.prefix(3).map { query in
            SearchSuggestion(
                query: query,
                description: "Recent search",
                category: .recent,
                icon: "clock",
                isRecent: true
            )
        }
    }
    
    private func generatePopularSuggestions() -> [SearchSuggestion] {
        return [
            SearchSuggestion(
                query: "receipts from last week",
                description: "Find recent purchase receipts",
                category: .business,
                icon: "receipt"
            ),
            SearchSuggestion(
                query: "blue dress photos",
                description: "Search for clothing items by color",
                category: .visual,
                icon: "tshirt"
            ),
            SearchSuggestion(
                query: "documents with phone numbers",
                description: "Find contact information",
                category: .contact,
                icon: "phone"
            ),
            SearchSuggestion(
                query: "screenshots from yesterday",
                description: "Find recent screenshots",
                category: .temporal,
                icon: "calendar"
            )
        ]
    }
    
    private func generateContextualSuggestions() -> [SearchSuggestion] {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour >= 9 && hour <= 17 {
            // Work hours - suggest business-related searches
            return [
                SearchSuggestion(
                    query: "meeting screenshots",
                    description: "Find work-related screenshots",
                    category: .business,
                    icon: "person.3"
                )
            ]
        } else {
            // Personal time - suggest personal searches
            return [
                SearchSuggestion(
                    query: "photos with friends",
                    description: "Find personal photos",
                    category: .visual,
                    icon: "person.2"
                )
            ]
        }
    }
    
    // MARK: - Query History Management
    
    func recordSearchQuery(_ query: String) {
        // Add to recent queries
        recentQueries.removeAll { $0 == query }
        recentQueries.insert(query, at: 0)
        recentQueries = Array(recentQueries.prefix(10))
        
        // Add to history
        let historyItem = QueryHistoryItem(
            query: query,
            timestamp: Date(),
            resultCount: 0 // Will be updated after search
        )
        queryHistory.append(historyItem)
        
        // Save to persistence
        saveQueryHistory()
    }
    
    private func loadQueryHistory() {
        // Load from UserDefaults or Core Data
        if let data = UserDefaults.standard.data(forKey: "queryHistory"),
           let history = try? JSONDecoder().decode([QueryHistoryItem].self, from: data) {
            queryHistory = history
        }
    }
    
    private func saveQueryHistory() {
        if let data = try? JSONEncoder().encode(queryHistory) {
            UserDefaults.standard.set(data, forKey: "queryHistory")
        }
    }
    
    private func loadRecentQueries() {
        if let queries = UserDefaults.standard.stringArray(forKey: "recentQueries") {
            recentQueries = queries
        }
    }
}

// MARK: - Supporting Types

/// Represents understanding of a user's search query
struct QueryUnderstanding {
    let query: String
    let intent: QueryIntent
    let entities: [QueryEntity]
    let confidence: Double
    let timestamp: Date
}

/// Different types of search intents
enum QueryIntent {
    case content, visual, document, temporal, business, location, contact
    
    var displayText: String {
        switch self {
        case .content: return "Text content"
        case .visual: return "Visual elements"
        case .document: return "Documents"
        case .temporal: return "Time-based"
        case .business: return "Business info"
        case .location: return "Locations"
        case .contact: return "Contact details"
        }
    }
    
    var icon: String {
        switch self {
        case .content: return "text.alignleft"
        case .visual: return "eye"
        case .document: return "doc.text"
        case .temporal: return "clock"
        case .business: return "building.2"
        case .location: return "location"
        case .contact: return "person.crop.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .content: return .primary
        case .visual: return .blue
        case .document: return .green
        case .temporal: return .orange
        case .business: return .purple
        case .location: return .red
        case .contact: return .cyan
        }
    }
}

/// Extracted entity from a query
struct QueryEntity {
    let type: EntityType
    let value: String
    let confidence: Double
    
    enum EntityType {
        case person, location, business, color, date, object
        
        var displayName: String {
            switch self {
            case .person: return "Person"
            case .location: return "Place"
            case .business: return "Business"
            case .color: return "Color"
            case .date: return "Date"
            case .object: return "Object"
            }
        }
        
        var color: Color {
            switch self {
            case .person: return .blue
            case .location: return .red
            case .business: return .purple
            case .color: return .orange
            case .date: return .green
            case .object: return .cyan
            }
        }
    }
}

/// Smart search suggestion
struct SearchSuggestion: Identifiable {
    let id = UUID()
    let query: String
    let description: String
    let category: Category
    let icon: String
    let isRecent: Bool
    
    init(query: String, description: String, category: Category, icon: String, isRecent: Bool = false) {
        self.query = query
        self.description = description
        self.category = category
        self.icon = icon
        self.isRecent = isRecent
    }
    
    enum Category {
        case recent, visual, business, contact, temporal, document
        
        var color: Color {
            switch self {
            case .recent: return .secondary
            case .visual: return .blue
            case .business: return .purple
            case .contact: return .cyan
            case .temporal: return .orange
            case .document: return .green
            }
        }
    }
}

/// Query history item for learning user patterns
struct QueryHistoryItem: Codable {
    let query: String
    let timestamp: Date
    let resultCount: Int
}
