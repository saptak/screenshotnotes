import SwiftUI

struct SearchHelpers {
    static func matchesEntityContext(screenshot: Screenshot, entityResult: EntityExtractionResult) -> Bool {
        let entities = entityResult.entities
        
        // Check visual entities (colors, objects) against filename, extracted text, and object tags
        let visualEntities = entities.filter { entity in
            entity.type == .color || entity.type == .object || entity.type == .documentType
        }
        
        if !visualEntities.isEmpty {
            for entity in visualEntities {
                let normalizedValue = entity.normalizedValue.lowercased()
                
                // Check filename
                if screenshot.filename.localizedCaseInsensitiveContains(normalizedValue) {
                    return true
                }
                
                // Check extracted text (OCR)
                if let extractedText = screenshot.extractedText,
                   extractedText.localizedCaseInsensitiveContains(normalizedValue) {
                    return true
                }
                
                // Check object tags (if available)
                if let objectTags = screenshot.objectTags {
                    for tag in objectTags {
                        if tag.localizedCaseInsensitiveContains(normalizedValue) {
                            return true
                        }
                    }
                }
                
                // For clothing/object entities, also check if the filename suggests it's a shopping screenshot
                if entity.type == .object && ["dress", "shirt", "pants", "jacket", "shoes"].contains(normalizedValue) {
                    let filenameWords = screenshot.filename.lowercased().components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
                    let shoppingKeywords = ["shop", "store", "buy", "purchase", "cart", "wishlist", "fashion", "clothes", "clothing"]
                    if !Set(filenameWords).intersection(Set(shoppingKeywords)).isEmpty {
                        return true
                    }
                }
            }
        }
        
        // Check person/organization entities
        let namedEntities = entities.filter { entity in
            entity.type == .person || entity.type == .organization || entity.type == .place
        }
        
        for entity in namedEntities {
            let normalizedValue = entity.normalizedValue.lowercased()
            
            // Check filename and extracted text for named entities
            if screenshot.filename.localizedCaseInsensitiveContains(normalizedValue) ||
               (screenshot.extractedText?.localizedCaseInsensitiveContains(normalizedValue) ?? false) {
                return true
            }
        }
        
        // Check structured data entities (phone, email, URL)
        let structuredEntities = entities.filter { entity in
            entity.type == .phoneNumber || entity.type == .email || entity.type == .url
        }
        
        for entity in structuredEntities {
            if let extractedText = screenshot.extractedText,
               extractedText.contains(entity.text) {
                return true
            }
        }
        
        return false
    }
    
    static func matchesTemporalContext(screenshot: Screenshot, query: SearchQuery) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let screenshotDate = screenshot.timestamp
        
        for term in query.searchTerms {
            switch term.lowercased() {
            case "today":
                if calendar.isDate(screenshotDate, inSameDayAs: now) {
                    return true
                }
            case "yesterday":
                if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                   calendar.isDate(screenshotDate, inSameDayAs: yesterday) {
                    return true
                }
            case "week", "this week":
                if calendar.isDate(screenshotDate, equalTo: now, toGranularity: .weekOfYear) {
                    return true
                }
            case "last week":
                if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
                   calendar.isDate(screenshotDate, equalTo: lastWeek, toGranularity: .weekOfYear) {
                    return true
                }
            case "month", "this month":
                if calendar.isDate(screenshotDate, equalTo: now, toGranularity: .month) {
                    return true
                }
            case "last month":
                if let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
                   calendar.isDate(screenshotDate, equalTo: lastMonth, toGranularity: .month) {
                    return true
                }
            case "recent":
                // Define recent as within the last 7 days
                if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                   screenshotDate >= weekAgo {
                    return true
                }
            default:
                continue
            }
        }
        
        return false
    }
    
    static func isTemporalTerm(_ term: String) -> Bool {
        let temporalTerms: Set<String> = [
            "today", "yesterday", "tomorrow", "week", "this week", "last week",
            "month", "this month", "last month", "year", "this year", "last year",
            "recent", "lately"
        ]
        return temporalTerms.contains(term.lowercased())
    }
    
    static func extractSuggestionText(from suggestion: String) -> String {
        // Extract quoted text from suggestions like "Did you mean: \"receipt\"?"
        let pattern = "\"([^\"]+)\"";
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: suggestion.utf16.count)
            if let match = regex.firstMatch(in: suggestion, options: [], range: range) {
                if let swiftRange = Range(match.range(at: 1), in: suggestion) {
                    return String(suggestion[swiftRange])
                }
            }
        }
        
        // If no quoted text found, return the original suggestion
        return suggestion
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var view: UIView? = self
        while let v = view {
            if let scroll = v as? UIScrollView { return scroll }
            view = v.superview
        }
        return nil
    }
}