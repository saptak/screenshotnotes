//
//  ActionableTextDetector.swift
//  ScreenshotNotes
//
//  Iteration 8.7.1.1: One-Tap Text Actions
//  Advanced text detection and classification using Vision framework and NSDataDetector
//

import Foundation
import Vision
import NaturalLanguage

final class ActionableTextDetector {
    
    // MARK: - Memory Management
    
    private let maxConcurrentAnalysis: Int = 2
    private let maxPatternMatches: Int = 100 // Limit pattern matches to prevent memory explosion
    
    // MARK: - Detected Item Types
    
    enum DetectedItemType: String, CaseIterable {
        case phoneNumber = "phoneNumber"
        case email = "email"
        case url = "url"
        case address = "address"
        case date = "date"
        
        var confidence: Double {
            switch self {
            case .phoneNumber, .email, .url: return 0.95
            case .address, .date: return 0.85
            }
        }
    }
    
    // MARK: - Detected Item Structure
    
    struct DetectedItem {
        let type: DetectedItemType
        let text: String
        let normalizedText: String
        let confidence: Double
        let range: NSRange
        let context: String?
        
        var isHighConfidence: Bool {
            return confidence >= 0.8
        }
    }
    
    // MARK: - Detection Error
    
    enum DetectionError: LocalizedError {
        case invalidText
        case detectionFailed
        case noItemsDetected
        
        var errorDescription: String? {
            switch self {
            case .invalidText:
                return "Invalid text provided for detection"
            case .detectionFailed:
                return "Text detection process failed"
            case .noItemsDetected:
                return "No actionable items detected in text"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let dataDetector: NSDataDetector
    private let nlTagger: NLTagger
    
    // MARK: - Initialization
    
    init() {
        // Initialize NSDataDetector with available types
        let detectorTypes: NSTextCheckingResult.CheckingType = [
            .phoneNumber,
            .link,
            .address,
            .date
        ]
        
        do {
            self.dataDetector = try NSDataDetector(types: detectorTypes.rawValue)
        } catch {
            // Fallback to basic phone number and link detection only
            self.dataDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue | NSTextCheckingResult.CheckingType.link.rawValue)
        }
        
        // Initialize NLTagger for additional context analysis
        self.nlTagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
    }
    
    // MARK: - Public Interface
    
    /// Detect actionable items in the provided text
    func detectActionableItems(in text: String) async -> [DetectedItem] {
        guard !text.isEmpty else {
            return []
        }
        
        // Memory safety: Process in chunks if text is too large
        let chunks = chunkText(text, maxSize: 5000)
        var allItems: [DetectedItem] = []
        
        for chunk in chunks {
            let chunkItems = await processTextChunk(chunk)
            allItems.append(contentsOf: chunkItems)
            
            // Prevent memory buildup
            if allItems.count > maxPatternMatches {
                allItems = Array(allItems.prefix(maxPatternMatches))
                break
            }
        }
        
        // Merge and deduplicate results
        return mergeAndDeduplicateItems(allItems)
    }
    
    /// Process a single chunk of text with memory-efficient task group
    private func processTextChunk(_ text: String) async -> [DetectedItem] {
        return await withTaskGroup(of: [DetectedItem].self) { group in
            var items: [DetectedItem] = []
            
            // Limit concurrent analysis to prevent memory spikes
            group.addTask {
                await self.performDataDetection(in: text)
            }
            
            group.addTask {
                await self.performPatternDetection(in: text)
            }
            
            // Skip contextual analysis for very long texts to save memory
            if text.count < 2000 {
                group.addTask {
                    await self.performContextualAnalysis(in: text)
                }
            }
            
            for await taskItems in group {
                items.append(contentsOf: taskItems)
                
                // Early termination to prevent memory issues
                if items.count > 50 {
                    break
                }
            }
            
            return items
        }
    }
    
    /// Split text into manageable chunks
    private func chunkText(_ text: String, maxSize: Int) -> [String] {
        guard text.count > maxSize else { return [text] }
        
        var chunks: [String] = []
        var startIndex = text.startIndex
        
        while startIndex < text.endIndex {
            let endIndex = text.index(startIndex, offsetBy: min(maxSize, text.distance(from: startIndex, to: text.endIndex)))
            let chunk = String(text[startIndex..<endIndex])
            chunks.append(chunk)
            startIndex = endIndex
        }
        
        return chunks
    }
    
    // MARK: - Private Methods - Data Detection
    
    private func performDataDetection(in text: String) async -> [DetectedItem] {
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = dataDetector.matches(in: text, options: [], range: range)
        
        return matches.compactMap { match in
            guard let detectedType = mapCheckingType(match.resultType),
                  let matchedText = extractMatchedText(from: text, range: match.range) else {
                return nil
            }
            
            let normalizedText = normalizeText(matchedText, for: detectedType)
            let context = extractContext(from: text, around: match.range)
            
            return DetectedItem(
                type: detectedType,
                text: matchedText,
                normalizedText: normalizedText,
                confidence: calculateConfidence(for: match, type: detectedType, context: context),
                range: match.range,
                context: context
            )
        }
    }
    
    private func performPatternDetection(in text: String) async -> [DetectedItem] {
        var items: [DetectedItem] = []
        
        // Enhanced phone number detection
        items.append(contentsOf: detectPhoneNumbers(in: text))
        
        // Enhanced email detection
        items.append(contentsOf: detectEmails(in: text))
        
        // Enhanced URL detection
        items.append(contentsOf: detectURLs(in: text))
        
        // Address detection with improved patterns
        items.append(contentsOf: detectAddresses(in: text))
        
        return items
    }
    
    private func performContextualAnalysis(in text: String) async -> [DetectedItem] {
        nlTagger.string = text
        var items: [DetectedItem] = []
        
        // Analyze for named entities that might be actionable
        let stringRange = text.startIndex..<text.endIndex
        nlTagger.enumerateTags(in: stringRange, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                switch tag {
                case .personalName:
                    // Could be useful for contact creation
                    let matchedText = String(text[tokenRange])
                    let nsRange = NSRange(tokenRange, in: text)
                    
                    items.append(DetectedItem(
                        type: .address, // Using address as generic contact info
                        text: matchedText,
                        normalizedText: matchedText,
                        confidence: 0.7,
                        range: nsRange,
                        context: extractContext(from: text, around: nsRange)
                    ))
                default:
                    break
                }
            }
            return true
        }
        
        return items
    }
    
    // MARK: - Private Methods - Pattern Detection
    
    private func detectPhoneNumbers(in text: String) -> [DetectedItem] {
        let patterns = [
            // US/International formats
            #"\+?1?[-.\s]?\(?(\d{3})\)?[-.\s]?(\d{3})[-.\s]?(\d{4})"#,
            // International format
            #"\+\d{1,3}[-.\s]?\d{1,14}"#,
            // Simple digit groups
            #"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b"#
        ]
        
        return detectWithPatterns(patterns, in: text, type: .phoneNumber)
    }
    
    private func detectEmails(in text: String) -> [DetectedItem] {
        let patterns = [
            // Standard email pattern
            #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#,
            // More permissive pattern
            #"\b\w+([.-]?\w+)*@\w+([.-]?\w+)*\.\w{2,}\b"#
        ]
        
        return detectWithPatterns(patterns, in: text, type: .email)
    }
    
    private func detectURLs(in text: String) -> [DetectedItem] {
        let patterns = [
            // HTTP/HTTPS URLs
            #"https?://[^\s/$.?#].[^\s]*"#,
            // Domain names that might be URLs
            #"\b(?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?\b"#,
            // FTP URLs
            #"ftp://[^\s/$.?#].[^\s]*"#
        ]
        
        return detectWithPatterns(patterns, in: text, type: .url)
    }
    
    private func detectAddresses(in text: String) -> [DetectedItem] {
        let patterns = [
            // US Address patterns
            #"\d+\s+[A-Za-z0-9\s]+(?:Street|St|Avenue|Ave|Road|Rd|Lane|Ln|Drive|Dr|Court|Ct|Boulevard|Blvd)"#,
            // ZIP code patterns
            #"\b\d{5}(?:-\d{4})?\b"#,
            // State abbreviations with ZIP
            #"\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b"#
        ]
        
        return detectWithPatterns(patterns, in: text, type: .address)
    }
    
    private func detectWithPatterns(_ patterns: [String], in text: String, type: DetectedItemType) -> [DetectedItem] {
        var items: [DetectedItem] = []
        let maxMatchesPerPattern = 20 // Limit matches per pattern
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(location: 0, length: text.utf16.count)
                let matches = regex.matches(in: text, options: [], range: range)
                
                // Limit matches to prevent memory issues
                let limitedMatches = Array(matches.prefix(maxMatchesPerPattern))
                
                for match in limitedMatches {
                    if let matchedText = extractMatchedText(from: text, range: match.range) {
                        let normalizedText = normalizeText(matchedText, for: type)
                        
                        // Skip context extraction for memory efficiency if we have many items
                        let context: String? = items.count < 10 ? extractContext(from: text, around: match.range) : nil
                        
                        items.append(DetectedItem(
                            type: type,
                            text: matchedText,
                            normalizedText: normalizedText,
                            confidence: calculatePatternConfidence(for: matchedText, type: type, context: context),
                            range: match.range,
                            context: context
                        ))
                        
                        // Early exit if we have enough items
                        if items.count >= maxMatchesPerPattern {
                            break
                        }
                    }
                }
            } catch {
                continue
            }
            
            // Stop processing if we already have enough items
            if items.count >= maxMatchesPerPattern {
                break
            }
        }
        
        return items
    }
    
    // MARK: - Private Methods - Helper Functions
    
    private func mapCheckingType(_ checkingType: NSTextCheckingResult.CheckingType) -> DetectedItemType? {
        switch checkingType {
        case .phoneNumber:
            return .phoneNumber
        case .link:
            return .url
        case .address:
            return .address
        case .date:
            return .date
        default:
            return nil
        }
    }
    
    private func extractMatchedText(from text: String, range: NSRange) -> String? {
        guard let range = Range(range, in: text) else { return nil }
        return String(text[range])
    }
    
    private func extractContext(from text: String, around range: NSRange, contextLength: Int = 50) -> String? {
        let startIndex = max(0, range.location - contextLength)
        let endIndex = min(text.count, range.location + range.length + contextLength)
        
        let contextRange = NSRange(location: startIndex, length: endIndex - startIndex)
        
        guard let swiftRange = Range(contextRange, in: text) else { return nil }
        return String(text[swiftRange])
    }
    
    private func normalizeText(_ text: String, for type: DetectedItemType) -> String {
        switch type {
        case .phoneNumber:
            return text.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        case .email:
            return text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        case .url:
            var normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
                normalized = "https://" + normalized
            }
            return normalized
        case .address:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private func calculateConfidence(for match: NSTextCheckingResult, type: DetectedItemType, context: String?) -> Double {
        var confidence = type.confidence
        
        // Adjust confidence based on match quality
        switch type {
        case .phoneNumber:
            if let phoneNumber = match.phoneNumber {
                // US phone numbers get higher confidence
                if phoneNumber.count >= 10 {
                    confidence = min(1.0, confidence + 0.05)
                }
            }
        case .url:
            if let url = match.url {
                // URLs with common TLDs get higher confidence
                let urlString = url.absoluteString.lowercased()
                if urlString.contains(".com") || urlString.contains(".org") || urlString.contains(".net") {
                    confidence = min(1.0, confidence + 0.05)
                }
            }
        default:
            break
        }
        
        return confidence
    }
    
    private func calculatePatternConfidence(for text: String, type: DetectedItemType, context: String?) -> Double {
        var confidence = type.confidence * 0.8 // Pattern-based gets slightly lower confidence
        
        // Adjust based on text characteristics
        switch type {
        case .phoneNumber:
            if text.count >= 10 && text.count <= 15 {
                confidence += 0.1
            }
        case .email:
            if text.contains("@") && text.contains(".") {
                confidence += 0.1
            }
        case .url:
            if text.contains(".") && (text.contains("www") || text.contains("http")) {
                confidence += 0.1
            }
        default:
            break
        }
        
        return min(1.0, confidence)
    }
    
    private func mergeAndDeduplicateItems(_ items: [DetectedItem]) -> [DetectedItem] {
        var uniqueItems: [DetectedItem] = []
        var seenRanges: Set<NSRange> = []
        
        // Sort by confidence and range
        let sortedItems = items.sorted { first, second in
            if first.confidence != second.confidence {
                return first.confidence > second.confidence
            }
            return first.range.location < second.range.location
        }
        
        for item in sortedItems {
            // Check for overlap with existing items
            let hasOverlap = seenRanges.contains { existingRange in
                NSIntersectionRange(item.range, existingRange).length > 0
            }
            
            if !hasOverlap {
                uniqueItems.append(item)
                seenRanges.insert(item.range)
            }
        }
        
        return uniqueItems
    }
}

// MARK: - Preview Support

#if DEBUG
extension ActionableTextDetector {
    static func mockDetectedItems() -> [DetectedItem] {
        return [
            DetectedItem(
                type: .phoneNumber,
                text: "+1 (555) 123-4567",
                normalizedText: "+15551234567",
                confidence: 0.95,
                range: NSRange(location: 0, length: 16),
                context: "Call me at +1 (555) 123-4567 tomorrow"
            ),
            DetectedItem(
                type: .email,
                text: "john.doe@example.com",
                normalizedText: "john.doe@example.com",
                confidence: 0.92,
                range: NSRange(location: 20, length: 20),
                context: "Email john.doe@example.com for details"
            ),
            DetectedItem(
                type: .url,
                text: "www.example.com",
                normalizedText: "https://www.example.com",
                confidence: 0.88,
                range: NSRange(location: 45, length: 15),
                context: "Visit www.example.com for more info"
            )
        ]
    }
}
#endif