import Foundation
import NaturalLanguage

/// Fuzzy matching service for Phase 5.1.4 Search Robustness Enhancement
/// Provides advanced text similarity and fuzzy search capabilities using optimized algorithms
public final class FuzzyMatchingService {
    
    // MARK: - Configuration
    
    public struct Configuration {
        /// Minimum similarity threshold for fuzzy matches (0.0 to 1.0)
        public let fuzzyThreshold: Double
        /// Maximum edit distance allowed for fuzzy matching
        public let maxEditDistance: Int
        /// Enable phonetic matching (sounds-like comparison)
        public let enablePhoneticMatching: Bool
        /// Enable N-gram analysis for partial matches
        public let enableNGramMatching: Bool
        /// Minimum N-gram size for analysis
        public let minNGramSize: Int
        /// Maximum N-gram size for analysis
        public let maxNGramSize: Int
        
        public static let `default` = Configuration(
            fuzzyThreshold: 0.75,
            maxEditDistance: 3,
            enablePhoneticMatching: true,
            enableNGramMatching: true,
            minNGramSize: 2,
            maxNGramSize: 4
        )
        
        public static let strict = Configuration(
            fuzzyThreshold: 0.85,
            maxEditDistance: 2,
            enablePhoneticMatching: false,
            enableNGramMatching: true,
            minNGramSize: 3,
            maxNGramSize: 3
        )
        
        public static let lenient = Configuration(
            fuzzyThreshold: 0.6,
            maxEditDistance: 4,
            enablePhoneticMatching: true,
            enableNGramMatching: true,
            minNGramSize: 2,
            maxNGramSize: 5
        )
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private let tokenizer = NLTokenizer(unit: .word)
    
    // MARK: - Caching
    
    private var distanceCache: [String: [String: Double]] = [:]
    private var phoneticCache: [String: String] = [:]
    private var ngramCache: [String: Set<String>] = [:]
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        setupTokenizer()
    }
    
    // MARK: - Public Fuzzy Matching Methods
    
    /// Perform fuzzy search on screenshots with advanced similarity matching
    public func fuzzySearch(query: String, in screenshots: [Screenshot]) -> [(screenshot: Screenshot, similarity: Double)] {
        let normalizedQuery = normalizeForFuzzy(query)
        var results: [(Screenshot, Double)] = []
        
        for screenshot in screenshots {
            let similarity = calculateScreenshotSimilarity(query: normalizedQuery, screenshot: screenshot)
            
            if similarity >= configuration.fuzzyThreshold {
                results.append((screenshot, similarity))
            }
        }
        
        // Sort by similarity (highest first)
        return results.sorted { $0.1 > $1.1 }
    }
    
    /// Calculate fuzzy similarity between two strings
    public func calculateSimilarity(_ string1: String, _ string2: String) -> Double {
        let normalized1 = normalizeForFuzzy(string1)
        let normalized2 = normalizeForFuzzy(string2)
        
        // Check cache first
        if let cached = getCachedDistance(normalized1, normalized2) {
            return cached
        }
        
        // Calculate multiple similarity metrics and combine them
        let levenshteinSim = levenshteinSimilarity(normalized1, normalized2)
        let jaccardSim = jaccardSimilarity(normalized1, normalized2)
        let ngramSim = configuration.enableNGramMatching ? ngramSimilarity(normalized1, normalized2) : 0.0
        let phoneticSim = configuration.enablePhoneticMatching ? phoneticSimilarity(normalized1, normalized2) : 0.0
        
        // Weighted combination of similarity metrics
        let combinedSimilarity: Double
        if configuration.enablePhoneticMatching && configuration.enableNGramMatching {
            combinedSimilarity = (levenshteinSim * 0.4) + (jaccardSim * 0.2) + (ngramSim * 0.2) + (phoneticSim * 0.2)
        } else if configuration.enableNGramMatching {
            combinedSimilarity = (levenshteinSim * 0.5) + (jaccardSim * 0.3) + (ngramSim * 0.2)
        } else {
            combinedSimilarity = (levenshteinSim * 0.7) + (jaccardSim * 0.3)
        }
        
        // Cache the result
        cacheDistance(normalized1, normalized2, combinedSimilarity)
        
        return combinedSimilarity
    }
    
    /// Find best fuzzy matches for a query term
    public func findBestMatches(for query: String, in candidates: [String], maxResults: Int = 5) -> [(string: String, similarity: Double)] {
        var matches: [(String, Double)] = []
        
        for candidate in candidates {
            let similarity = calculateSimilarity(query, candidate)
            if similarity >= configuration.fuzzyThreshold {
                matches.append((candidate, similarity))
            }
        }
        
        return matches.sorted { $0.1 > $1.1 }.prefix(maxResults).map { ($0.0, $0.1) }
    }
    
    // MARK: - Advanced Similarity Algorithms
    
    /// Optimized Levenshtein distance with early termination
    private func levenshteinSimilarity(_ string1: String, _ string2: String) -> Double {
        let len1 = string1.count
        let len2 = string2.count
        
        // Quick checks
        if len1 == 0 { return len2 == 0 ? 1.0 : 0.0 }
        if len2 == 0 { return 0.0 }
        if string1 == string2 { return 1.0 }
        
        // Early termination if length difference is too large
        let lengthDiff = abs(len1 - len2)
        if lengthDiff > configuration.maxEditDistance {
            return 0.0
        }
        
        let chars1 = Array(string1)
        let chars2 = Array(string2)
        
        // Use smaller array for efficiency
        let (shorter, longer) = len1 <= len2 ? (chars1, chars2) : (chars2, chars1)
        let (shortLen, longLen) = (shorter.count, longer.count)
        
        // Initialize distance matrix with optimized space
        var previousRow = Array(0...shortLen)
        var currentRow = Array(repeating: 0, count: shortLen + 1)
        
        for i in 1...longLen {
            currentRow[0] = i
            
            for j in 1...shortLen {
                let cost = longer[i-1] == shorter[j-1] ? 0 : 1
                currentRow[j] = min(
                    currentRow[j-1] + 1,        // insertion
                    previousRow[j] + 1,         // deletion
                    previousRow[j-1] + cost     // substitution
                )
            }
            
            // Early termination if minimum possible distance exceeds threshold
            let minInRow = currentRow.min() ?? 0
            if minInRow > configuration.maxEditDistance {
                return 0.0
            }
            
            swap(&previousRow, &currentRow)
        }
        
        let distance = previousRow[shortLen]
        let maxLength = max(len1, len2)
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Jaccard similarity using character sets
    private func jaccardSimilarity(_ string1: String, _ string2: String) -> Double {
        let set1 = Set(string1.lowercased())
        let set2 = Set(string2.lowercased())
        
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    /// N-gram similarity analysis
    private func ngramSimilarity(_ string1: String, _ string2: String) -> Double {
        var totalSimilarity = 0.0
        var comparisons = 0
        
        for n in configuration.minNGramSize...configuration.maxNGramSize {
            let ngrams1 = generateNGrams(string1, n: n)
            let ngrams2 = generateNGrams(string2, n: n)
            
            if !ngrams1.isEmpty && !ngrams2.isEmpty {
                let intersection = ngrams1.intersection(ngrams2)
                let union = ngrams1.union(ngrams2)
                let similarity = Double(intersection.count) / Double(union.count)
                
                totalSimilarity += similarity
                comparisons += 1
            }
        }
        
        return comparisons > 0 ? totalSimilarity / Double(comparisons) : 0.0
    }
    
    /// Phonetic similarity using Metaphone-like algorithm
    private func phoneticSimilarity(_ string1: String, _ string2: String) -> Double {
        let phonetic1 = generatePhoneticCode(string1)
        let phonetic2 = generatePhoneticCode(string2)
        
        return phonetic1 == phonetic2 ? 1.0 : 0.0
    }
    
    // MARK: - Helper Methods
    
    private func calculateScreenshotSimilarity(query: String, screenshot: Screenshot) -> Double {
        var maxSimilarity = 0.0
        
        // Check against filename
        let filenameSimilarity = calculateSimilarity(query, screenshot.filename)
        maxSimilarity = max(maxSimilarity, filenameSimilarity)
        
        // Check against extracted text
        if let extractedText = screenshot.extractedText {
            // Split extracted text into sentences and check each
            let sentences = extractedText.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            
            for sentence in sentences {
                let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSentence.isEmpty {
                    let sentenceSimilarity = calculateSimilarity(query, trimmedSentence)
                    maxSimilarity = max(maxSimilarity, sentenceSimilarity)
                    
                    // Also check individual words in the sentence
                    let words = trimmedSentence.components(separatedBy: .whitespacesAndNewlines)
                    for word in words {
                        let wordSimilarity = calculateSimilarity(query, word)
                        maxSimilarity = max(maxSimilarity, wordSimilarity * 0.8) // Slightly lower weight for individual words
                    }
                }
            }
        }
        
        // Check against user notes if available
        if let userNotes = screenshot.userNotes {
            let notesSimilarity = calculateSimilarity(query, userNotes)
            maxSimilarity = max(maxSimilarity, notesSimilarity)
        }
        
        // Check against object tags if available
        if let objectTags = screenshot.objectTags {
            for tag in objectTags {
                let tagSimilarity = calculateSimilarity(query, tag)
                maxSimilarity = max(maxSimilarity, tagSimilarity)
            }
        }
        
        return maxSimilarity
    }
    
    private func normalizeForFuzzy(_ string: String) -> String {
        return string.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
    }
    
    private func generateNGrams(_ string: String, n: Int) -> Set<String> {
        let cacheKey = "\(string)_\(n)"
        if let cached = ngramCache[cacheKey] {
            return cached
        }
        
        guard string.count >= n else { return [] }
        
        var ngrams: Set<String> = []
        let chars = Array(string)
        
        for i in 0...(chars.count - n) {
            let ngram = String(chars[i..<(i + n)])
            ngrams.insert(ngram)
        }
        
        // Cache the result
        if ngramCache.count < 1000 { // Limit cache size
            ngramCache[cacheKey] = ngrams
        }
        
        return ngrams
    }
    
    private func generatePhoneticCode(_ string: String) -> String {
        if let cached = phoneticCache[string] {
            return cached
        }
        
        // Simplified Metaphone-like phonetic algorithm
        var phonetic = string.lowercased()
        
        // Common phonetic transformations
        let transformations: [(String, String)] = [
            ("ph", "f"), ("gh", "f"), ("ck", "k"), ("c", "k"),
            ("x", "ks"), ("z", "s"), ("y", "i"), ("w", ""),
            ("h", ""), ("qu", "kw"), ("th", "t")
        ]
        
        for (from, to) in transformations {
            phonetic = phonetic.replacingOccurrences(of: from, with: to)
        }
        
        // Remove consecutive duplicates
        var result = ""
        var lastChar: Character?
        
        for char in phonetic {
            if char != lastChar {
                result.append(char)
                lastChar = char
            }
        }
        
        // Cache the result
        if phoneticCache.count < 1000 { // Limit cache size
            phoneticCache[string] = result
        }
        
        return result
    }
    
    // MARK: - Caching Methods
    
    private func getCachedDistance(_ string1: String, _ string2: String) -> Double? {
        return distanceCache[string1]?[string2] ?? distanceCache[string2]?[string1]
    }
    
    private func cacheDistance(_ string1: String, _ string2: String, _ distance: Double) {
        if distanceCache.count < 1000 { // Limit cache size
            if distanceCache[string1] == nil {
                distanceCache[string1] = [:]
            }
            distanceCache[string1]?[string2] = distance
        }
    }
    
    private func setupTokenizer() {
        tokenizer.setLanguage(.english)
    }
}