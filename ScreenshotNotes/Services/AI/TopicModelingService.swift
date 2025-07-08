import Foundation
import NaturalLanguage
import CoreML

/// Advanced Topic Modeling Service for thematic similarity analysis
/// Sprint 7.1.1: Production-ready topic discovery and thematic relationship detection
@MainActor
final class TopicModelingService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = TopicModelingService()
    
    // MARK: - Configuration
    private let maxTopicsPerDocument = 5
    private let minTopicConfidence = 0.3
    private let topicCacheSize = 500
    
    // MARK: - State
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    
    // MARK: - Caching
    private var topicCache: [String: [Topic]] = [:]
    private var documentTopicCache: [String: DocumentTopicProfile] = [:]
    
    private init() {
        setupTopicModeling()
    }
    
    // MARK: - Public Interface
    
    /// Extracts topics from text content using Natural Language framework
    /// - Parameter text: Input text for topic extraction
    /// - Returns: Array of topics with confidence scores
    func extractTopics(from text: String) async -> [Topic] {
        let cacheKey = createCacheKey(for: text)
        
        // Check cache first
        if let cachedTopics = topicCache[cacheKey] {
            return cachedTopics
        }
        
        isProcessing = true
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            processingProgress = 1.0
        }
        
        // Extract entities and keywords using NL framework
        processingProgress = 0.2
        let entities = await extractEntities(from: text)
        
        processingProgress = 0.4
        let keywords = await extractKeywords(from: text)
        
        processingProgress = 0.6
        let semanticClusters = await clusterSemanticConcepts(text: text, entities: entities, keywords: keywords)
        
        processingProgress = 0.8
        let topics = createTopics(from: semanticClusters, entities: entities, keywords: keywords)
        
        // Cache the results
        cacheTopics(topics, for: cacheKey)
        
        return topics
    }
    
    /// Calculates thematic similarity between two sets of topics
    /// - Parameters:
    ///   - topics1: First set of topics
    ///   - topics2: Second set of topics
    /// - Returns: Similarity score (0.0 - 1.0)
    func calculateThematicSimilarity(topics1: [Topic], topics2: [Topic]) -> Double {
        guard !topics1.isEmpty && !topics2.isEmpty else { return 0.0 }
        
        // Calculate topic overlap using semantic similarity
        var totalSimilarity = 0.0
        var comparisons = 0
        
        for topic1 in topics1 {
            for topic2 in topics2 {
                let similarity = calculateTopicSimilarity(topic1, topic2)
                totalSimilarity += similarity * topic1.confidence * topic2.confidence
                comparisons += 1
            }
        }
        
        return comparisons > 0 ? totalSimilarity / Double(comparisons) : 0.0
    }
    
    /// Creates a comprehensive topic profile for a document
    /// - Parameters:
    ///   - text: Document text
    ///   - visualContext: Optional visual context for enhanced topic detection
    /// - Returns: Document topic profile with themes and relationships
    func createDocumentTopicProfile(text: String, visualContext: [String] = []) async -> DocumentTopicProfile {
        let cacheKey = "\(createCacheKey(for: text))_\(visualContext.joined(separator: "_"))"
        
        if let cached = documentTopicCache[cacheKey] {
            return cached
        }
        
        let topics = await extractTopics(from: text)
        let themes = extractThemes(from: topics, visualContext: visualContext)
        let categories = categorizeContent(topics: topics, themes: themes)
        
        let profile = DocumentTopicProfile(
            topics: topics,
            themes: themes,
            categories: categories,
            confidence: calculateProfileConfidence(topics: topics, themes: themes),
            dominantTheme: themes.max(by: { $0.strength < $1.strength })?.name ?? "general"
        )
        
        // Cache the profile
        documentTopicCache[cacheKey] = profile
        
        // Manage cache size
        if documentTopicCache.count > topicCacheSize {
            let oldestKey = documentTopicCache.keys.randomElement()
            if let key = oldestKey {
                documentTopicCache.removeValue(forKey: key)
            }
        }
        
        return profile
    }
}

// MARK: - Private Implementation

private extension TopicModelingService {
    
    /// Extract named entities using Natural Language framework
    func extractEntities(from text: String) async -> [String] {
        return await withCheckedContinuation { continuation in
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = text
            
            var entities: [String] = []
            
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
                if tag != nil {
                    let entityText = String(text[range])
                    if entityText.count > 2 && !entityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        entities.append(entityText.lowercased())
                    }
                }
                return true
            }
            
            continuation.resume(returning: Array(Set(entities))) // Remove duplicates
        }
    }
    
    /// Extract keywords using NL tokenization and part-of-speech tagging
    func extractKeywords(from text: String) async -> [String] {
        return await withCheckedContinuation { continuation in
            let tokenizer = NLTokenizer(unit: .word)
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            
            tokenizer.string = text
            tagger.string = text
            
            var keywords: [String] = []
            
            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
                let token = String(text[tokenRange])
                
                // Filter by part of speech (nouns, adjectives, verbs)
                let tags = tagger.tags(in: tokenRange, unit: .word, scheme: .lexicalClass)
                
                for (tag, _) in tags {
                    if let tag = tag,
                       (tag == .noun || tag == .adjective || tag == .verb),
                       token.count > 3,
                       !stopWords.contains(token.lowercased()) {
                        keywords.append(token.lowercased())
                    }
                }
                
                return true
            }
            
            continuation.resume(returning: Array(Set(keywords)))
        }
    }
    
    /// Cluster semantic concepts using simple co-occurrence analysis
    func clusterSemanticConcepts(text: String, entities: [String], keywords: [String]) async -> [SemanticCluster] {
        let allTerms = entities + keywords
        var clusters: [SemanticCluster] = []
        
        // Create domain-specific clusters
        let domainClusters = [
            ("technology", ["app", "software", "computer", "digital", "tech", "system", "code", "programming"]),
            ("business", ["company", "business", "meeting", "finance", "money", "work", "office", "professional"]),
            ("communication", ["message", "email", "text", "chat", "phone", "call", "contact", "social"]),
            ("media", ["photo", "image", "video", "media", "content", "picture", "visual", "design"]),
            ("education", ["learn", "study", "school", "education", "course", "knowledge", "training", "academic"]),
            ("health", ["health", "medical", "doctor", "medicine", "fitness", "wellness", "care", "treatment"]),
            ("travel", ["travel", "trip", "location", "place", "destination", "journey", "vacation", "transport"]),
            ("shopping", ["shop", "buy", "purchase", "store", "product", "price", "cart", "order"]),
            ("entertainment", ["game", "music", "movie", "entertainment", "fun", "play", "sport", "leisure"])
        ]
        
        for (domain, domainTerms) in domainClusters {
            let matchingTerms = allTerms.filter { term in
                domainTerms.contains { domain in term.contains(domain) || domain.contains(term) }
            }
            
            if !matchingTerms.isEmpty {
                let confidence = min(Double(matchingTerms.count) / Double(allTerms.count) * 2.0, 1.0)
                clusters.append(SemanticCluster(
                    domain: domain,
                    terms: matchingTerms,
                    confidence: confidence
                ))
            }
        }
        
        return clusters
    }
    
    /// Create topics from semantic clusters
    func createTopics(from clusters: [SemanticCluster], entities: [String], keywords: [String]) -> [Topic] {
        var topics: [Topic] = []
        
        for cluster in clusters {
            let topic = Topic(
                name: cluster.domain,
                keywords: cluster.terms,
                confidence: cluster.confidence,
                category: categorizeByDomain(cluster.domain),
                entities: entities.filter { entity in
                    cluster.terms.contains { $0.contains(entity) || entity.contains($0) }
                }
            )
            topics.append(topic)
        }
        
        // Add general topics for uncategorized content
        if topics.isEmpty {
            let generalTopic = Topic(
                name: "general",
                keywords: Array(keywords.prefix(5)),
                confidence: 0.5,
                category: .general,
                entities: Array(entities.prefix(3))
            )
            topics.append(generalTopic)
        }
        
        return topics.sorted { $0.confidence > $1.confidence }
    }
    
    /// Extract themes from topics with visual context
    func extractThemes(from topics: [Topic], visualContext: [String]) -> [Theme] {
        var themes: [Theme] = []
        
        // Group topics by category
        let groupedTopics = Dictionary(grouping: topics) { $0.category }
        
        for (category, categoryTopics) in groupedTopics {
            let strength = categoryTopics.reduce(0) { $0 + $1.confidence } / Double(categoryTopics.count)
            let keywords = categoryTopics.flatMap { $0.keywords }
            
            themes.append(Theme(
                name: category.rawValue,
                strength: strength,
                keywords: Array(Set(keywords)),
                visualContext: visualContext.filter { context in
                    keywords.contains { keyword in
                        context.lowercased().contains(keyword) || keyword.contains(context.lowercased())
                    }
                }
            ))
        }
        
        return themes.sorted { $0.strength > $1.strength }
    }
    
    /// Categorize content based on topics and themes
    func categorizeContent(topics: [Topic], themes: [Theme]) -> ContentCategory {
        guard let dominantTheme = themes.first else { return .general }
        
        // Use dominant theme to determine category
        switch dominantTheme.name {
        case "technology":
            return .technology
        case "business":
            return .business
        case "communication":
            return .communication
        case "media":
            return .media
        case "education":
            return .education
        case "health":
            return .health
        case "travel":
            return .travel
        case "shopping":
            return .shopping
        case "entertainment":
            return .entertainment
        default:
            return .general
        }
    }
    
    /// Calculate topic similarity using keyword overlap and semantic distance
    func calculateTopicSimilarity(_ topic1: Topic, _ topic2: Topic) -> Double {
        let keywords1 = Set(topic1.keywords.map { $0.lowercased() })
        let keywords2 = Set(topic2.keywords.map { $0.lowercased() })
        
        let intersection = keywords1.intersection(keywords2)
        let union = keywords1.union(keywords2)
        
        let jaccardSimilarity = union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
        
        // Category bonus
        let categoryBonus = topic1.category == topic2.category ? 0.2 : 0.0
        
        return min(jaccardSimilarity + categoryBonus, 1.0)
    }
    
    /// Setup topic modeling configuration
    func setupTopicModeling() {
        // Initialize any required resources
    }
    
    /// Create cache key for text content
    func createCacheKey(for text: String) -> String {
        return String(text.prefix(100).hash)
    }
    
    /// Cache topics for performance
    func cacheTopics(_ topics: [Topic], for key: String) {
        topicCache[key] = topics
        
        // Manage cache size
        if topicCache.count > topicCacheSize {
            let oldestKey = topicCache.keys.randomElement()
            if let key = oldestKey {
                topicCache.removeValue(forKey: key)
            }
        }
    }
    
    /// Categorize by domain string
    func categorizeByDomain(_ domain: String) -> TopicCategory {
        switch domain {
        case "technology": return .technology
        case "business": return .business
        case "communication": return .communication
        case "media": return .media
        case "education": return .education
        case "health": return .health
        case "travel": return .travel
        case "shopping": return .shopping
        case "entertainment": return .entertainment
        default: return .general
        }
    }
    
    /// Calculate overall profile confidence
    func calculateProfileConfidence(topics: [Topic], themes: [Theme]) -> Double {
        let topicConfidence = topics.isEmpty ? 0.0 : topics.reduce(0) { $0 + $1.confidence } / Double(topics.count)
        let themeConfidence = themes.isEmpty ? 0.0 : themes.reduce(0) { $0 + $1.strength } / Double(themes.count)
        
        return (topicConfidence + themeConfidence) / 2.0
    }
    
    /// Common stop words to filter out
    var stopWords: Set<String> {
        return Set([
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
            "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did",
            "will", "would", "could", "should", "may", "might", "can", "this", "that", "these", "those"
        ])
    }
}

// MARK: - Supporting Types

struct Topic {
    let name: String
    let keywords: [String]
    let confidence: Double
    let category: TopicCategory
    let entities: [String]
}

struct Theme {
    let name: String
    let strength: Double
    let keywords: [String]
    let visualContext: [String]
}

struct SemanticCluster {
    let domain: String
    let terms: [String]
    let confidence: Double
}

struct DocumentTopicProfile {
    let topics: [Topic]
    let themes: [Theme]
    let categories: ContentCategory
    let confidence: Double
    let dominantTheme: String
}

enum TopicCategory: String, CaseIterable {
    case technology = "technology"
    case business = "business"
    case communication = "communication"
    case media = "media"
    case education = "education"
    case health = "health"
    case travel = "travel"
    case shopping = "shopping"
    case entertainment = "entertainment"
    case general = "general"
}

enum ContentCategory: String, CaseIterable {
    case technology = "Technology"
    case business = "Business"
    case communication = "Communication"
    case media = "Media"
    case education = "Education"
    case health = "Health"
    case travel = "Travel"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case general = "General"
}