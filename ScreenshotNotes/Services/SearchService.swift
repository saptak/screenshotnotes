import Foundation
import SwiftData

protocol SearchServiceProtocol {
    func searchScreenshots(query: String, in screenshots: [Screenshot]) -> [Screenshot]
    func highlightText(in text: String, matching query: String) -> [(range: NSRange, text: String)]
}

final class SearchService: ObservableObject, SearchServiceProtocol {
    
    private let debounceInterval: TimeInterval = 0.1
    private let searchCache = SearchCache()
    private var searchTask: Task<Void, Never>?
    
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
        
        let allText = "\(searchableText) \(userTags) \(objectTags)"
        
        return allText.contains(searchTerm)
    }
    
    private func calculateRelevanceScore(for screenshot: Screenshot, searchTerms: [String]) -> Int {
        var score = 0
        
        let extractedText = screenshot.extractedText?.lowercased() ?? ""
        let userNotes = screenshot.userNotes?.lowercased() ?? ""
        let filename = screenshot.filename.lowercased()
        let userTags = screenshot.userTags?.joined(separator: " ").lowercased() ?? ""
        let objectTags = screenshot.objectTags?.joined(separator: " ").lowercased() ?? ""
        
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
}