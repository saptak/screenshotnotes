import Foundation
import SwiftData

protocol SearchServiceProtocol {
    func searchScreenshots(query: String, in screenshots: [Screenshot]) -> [Screenshot]
    func highlightText(in text: String, matching query: String) -> [(range: NSRange, text: String)]
    func findSimilarScreenshots(to screenshot: Screenshot, in screenshots: [Screenshot], limit: Int) async throws -> [Screenshot]
}

final class SearchService: ObservableObject, SearchServiceProtocol {

    private let debounceInterval: TimeInterval = 0.1
    private let searchCache = SearchCache()
    private var searchTask: Task<Void, Never>?
    @MainActor private static let similarityEngine = SimilarityEngine.shared
    
    func searchScreenshots(query: String, in screenshots: [Screenshot]) -> [Screenshot] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return screenshots
        }
        
        // Check cache first
        if let cachedResults = searchCache.getCachedResults(for: query) {
            // Filter cached results to only include screenshots that still exist
            let filteredResults = cachedResults.filter { cachedScreenshot in
                screenshots.contains { $0.id == cachedScreenshot.id }
            }
            
            if filteredResults.count == cachedResults.count {
                return filteredResults
            }
        }
        
        let searchTerms = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        let results = screenshots.filter { screenshot in
            searchTerms.allSatisfy { term in
                matchesScreenshot(screenshot, searchTerm: term)
            }
        }
        .sorted { first, second in
            let firstScore = calculateRelevanceScore(for: first, searchTerms: searchTerms)
            let secondScore = calculateRelevanceScore(for: second, searchTerms: searchTerms)
            
            if firstScore != secondScore {
                return firstScore > secondScore
            }
            
            return first.timestamp > second.timestamp
        }
        
        // Cache the results
        searchCache.setCachedResults(results, for: query)
        
        return results
    }
    
    private func matchesScreenshot(_ screenshot: Screenshot, searchTerm: String) -> Bool {
        let searchableText = [
            screenshot.extractedText,
            screenshot.userNotes,
            screenshot.filename
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
        
        let userTags = screenshot.userTags?.joined(separator: " ").lowercased() ?? ""
        let objectTags = screenshot.objectTags?.joined(separator: " ").lowercased() ?? ""
        
        // Phase 5.2.1: Enhanced Vision Processing - Add visual attributes to search
        let visualTags = screenshot.allSemanticTags.joined(separator: " ").lowercased()
        let colorNames = screenshot.dominantColors.map { $0.colorName.lowercased() }.joined(separator: " ")
        let objectLabels = screenshot.prominentObjects.map { $0.label.lowercased() }.joined(separator: " ")
        
        // Phase 5.2.3: Semantic Tagging - Add semantic tags to search
        let semanticTagNames = screenshot.searchableTagNames.joined(separator: " ").lowercased()
        let businessEntityNames = screenshot.businessEntities.map { $0.name.lowercased() }.joined(separator: " ")
        let contentTypeTag = screenshot.contentType?.name.lowercased() ?? ""
        
        let allText = "\(searchableText) \(userTags) \(objectTags) \(visualTags) \(colorNames) \(objectLabels) \(semanticTagNames) \(businessEntityNames) \(contentTypeTag)"
        
        return allText.contains(searchTerm)
    }
    
    private func calculateRelevanceScore(for screenshot: Screenshot, searchTerms: [String]) -> Int {
        var score = 0
        
        let extractedText = screenshot.extractedText?.lowercased() ?? ""
        let userNotes = screenshot.userNotes?.lowercased() ?? ""
        let filename = screenshot.filename.lowercased()
        let userTags = screenshot.userTags?.joined(separator: " ").lowercased() ?? ""
        let objectTags = screenshot.objectTags?.joined(separator: " ").lowercased() ?? ""
        
        // Phase 5.2.1: Enhanced Vision Processing - Add visual scoring
        let visualTags = screenshot.allSemanticTags.joined(separator: " ").lowercased()
        let colorNames = screenshot.dominantColors.map { $0.colorName.lowercased() }.joined(separator: " ")
        let objectLabels = screenshot.prominentObjects.map { $0.label.lowercased() }.joined(separator: " ")
        
        // Phase 5.2.3: Semantic Tagging - Add semantic tag scoring
        let semanticTagNames = screenshot.searchableTagNames.joined(separator: " ").lowercased()
        let businessEntityNames = screenshot.businessEntities.map { $0.name.lowercased() }.joined(separator: " ")
        let highConfidenceTagNames = screenshot.highConfidenceSemanticTags.map { $0.name.lowercased() }.joined(separator: " ")
        let contentTypeTag = screenshot.contentType?.name.lowercased() ?? ""
        
        for term in searchTerms {
            if filename.contains(term) {
                score += 10
            }
            
            if userTags.contains(term) {
                score += 8
            }
            
            if userNotes.contains(term) {
                score += 6
            }
            
            // Phase 5.2.3: Semantic Tagging - Highest priority scoring
            if businessEntityNames.contains(term) {
                score += 12 // Highest score for business entity matches
            }
            
            if contentTypeTag.contains(term) {
                score += 10 // Very high score for content type matches
            }
            
            if highConfidenceTagNames.contains(term) {
                score += 9 // High score for confident semantic tag matches
            }
            
            // Enhanced scoring for visual attributes
            if objectLabels.contains(term) {
                score += 7 // Higher score for object detection matches
            }
            
            if colorNames.contains(term) {
                score += 6 // High score for color matches
            }
            
            if semanticTagNames.contains(term) {
                score += 5 // Good score for semantic tag matches
            }
            
            if visualTags.contains(term) {
                score += 5 // Good score for semantic tag matches
            }
            
            if objectTags.contains(term) {
                score += 4
            }
            
            if extractedText.contains(term) {
                score += 2
                
                if extractedText.hasPrefix(term) || extractedText.hasSuffix(term) {
                    score += 1
                }
            }
        }
        
        return score
    }
    
    func highlightText(in text: String, matching query: String) -> [(range: NSRange, text: String)] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [(range: NSRange(location: 0, length: text.count), text: text)]
        }
        
        let searchTerms = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var highlights: [NSRange] = []
        let lowercasedText = text.lowercased()
        
        for term in searchTerms {
            var searchRange = NSRange(location: 0, length: lowercasedText.count)
            
            while searchRange.location < lowercasedText.count {
                let foundRange = (lowercasedText as NSString).range(
                    of: term,
                    options: [.caseInsensitive],
                    range: searchRange
                )
                
                if foundRange.location == NSNotFound {
                    break
                }
                
                highlights.append(foundRange)
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = lowercasedText.count - searchRange.location
            }
        }
        
        highlights.sort { $0.location < $1.location }
        
        var results: [(range: NSRange, text: String)] = []
        var currentLocation = 0
        
        for highlight in highlights {
            if highlight.location > currentLocation {
                let beforeRange = NSRange(location: currentLocation, length: highlight.location - currentLocation)
                let beforeText = (text as NSString).substring(with: beforeRange)
                results.append((range: beforeRange, text: beforeText))
            }
            
            let highlightText = (text as NSString).substring(with: highlight)
            results.append((range: highlight, text: highlightText))
            
            currentLocation = highlight.location + highlight.length
        }
        
        if currentLocation < text.count {
            let afterRange = NSRange(location: currentLocation, length: text.count - currentLocation)
            let afterText = (text as NSString).substring(with: afterRange)
            results.append((range: afterRange, text: afterText))
        }
        
        return results.isEmpty ? [(range: NSRange(location: 0, length: text.count), text: text)] : results
    }
    
    /// Finds similar screenshots using the Content Similarity Engine
    /// - Parameters:
    ///   - screenshot: Reference screenshot to find similarities for
    ///   - screenshots: Pool of screenshots to search in
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of similar screenshots sorted by similarity score
    func findSimilarScreenshots(to screenshot: Screenshot, in screenshots: [Screenshot], limit: Int = 10) async throws -> [Screenshot] {
        // Only get IDs from the engine, then map to screenshots
        let similarScores = try await SearchService.similarityEngine.findSimilarScreenshots(
            for: screenshot,
            in: screenshots,
            limit: limit
        )
        let similarScoreIds = similarScores.map { $0.targetScreenshotId }
        return similarScoreIds.compactMap { id in
            screenshots.first { $0.id == id }
        }
    }
    
    /// Enhanced search with similarity-based results
    /// - Parameters:
    ///   - query: Search query
    ///   - screenshots: Screenshots to search in
    ///   - includeSimilar: Whether to include similar results
    /// - Returns: Enhanced search results with similarity suggestions
    func enhancedSearch(query: String, in screenshots: [Screenshot], includeSimilar: Bool = true) async throws -> EnhancedSearchResults {
        // Perform traditional text-based search
        let textResults = searchScreenshots(query: query, in: screenshots)
        
        guard includeSimilar && !textResults.isEmpty else {
            return EnhancedSearchResults(
                textResults: textResults,
                similarResults: [],
                searchQuery: query,
                totalResults: textResults.count
            )
        }
        
        // Find similar screenshots to the top results
        let topResults = Array(textResults.prefix(3))
        var similarResults: [Screenshot] = []
        
        for topResult in topResults {
            let similar = try await findSimilarScreenshots(
                to: topResult,
                in: screenshots.filter { !textResults.contains($0) }, // Exclude already found results
                limit: 5
            )
            similarResults.append(contentsOf: similar)
        }
        
        // Remove duplicates and limit results
        let uniqueSimilarResults = Array(Set(similarResults)).prefix(10)
        
        return EnhancedSearchResults(
            textResults: textResults,
            similarResults: Array(uniqueSimilarResults),
            searchQuery: query,
            totalResults: textResults.count + uniqueSimilarResults.count
        )
    }
}

/// Enhanced search results with similarity-based suggestions
struct EnhancedSearchResults {
    let textResults: [Screenshot]
    let similarResults: [Screenshot]
    let searchQuery: String
    let totalResults: Int
    
    var allResults: [Screenshot] {
        return textResults + similarResults
    }
    
    var hasResults: Bool {
        return totalResults > 0
    }
    
    var hasSimilarResults: Bool {
        return !similarResults.isEmpty
    }
}