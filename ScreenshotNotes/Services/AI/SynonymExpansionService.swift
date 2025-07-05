import Foundation
import NaturalLanguage

/// Synonym expansion service for Phase 5.1.4 Search Robustness Enhancement
/// Provides comprehensive synonym dictionary and query expansion capabilities
public final class SynonymExpansionService {
    
    // MARK: - Comprehensive Synonym Dictionary
    
    /// Multi-language synonym dictionary organized by semantic categories
    private let synonymDictionary: [String: Set<String>] = [
        // Visual/Media Terms
        "photo": ["picture", "image", "pic", "screenshot", "snap", "shot", "capture", "photograph"],
        "picture": ["photo", "image", "pic", "screenshot", "snap", "shot", "capture", "photograph"],
        "image": ["photo", "picture", "pic", "screenshot", "snap", "shot", "capture", "photograph"],
        "screenshot": ["photo", "picture", "image", "pic", "snap", "shot", "capture", "screen grab"],
        "pic": ["photo", "picture", "image", "screenshot", "snap", "shot", "capture"],
        "snap": ["photo", "picture", "image", "screenshot", "pic", "shot", "capture"],
        
        // Document Types
        "document": ["doc", "paper", "file", "form", "report", "text", "writing"],
        "doc": ["document", "paper", "file", "form", "report", "text", "writing"],
        "receipt": ["bill", "invoice", "ticket", "voucher", "stub", "proof of purchase"],
        "bill": ["receipt", "invoice", "ticket", "voucher", "statement", "account"],
        "invoice": ["bill", "receipt", "statement", "account", "charge"],
        "ticket": ["receipt", "bill", "voucher", "stub", "pass"],
        "form": ["document", "application", "questionnaire", "survey", "sheet"],
        "report": ["document", "summary", "analysis", "paper", "study"],
        
        // Colors (with variations and cultural differences)
        "blue": ["azure", "navy", "cerulean", "cobalt", "sapphire", "teal", "cyan", "indigo"],
        "red": ["crimson", "scarlet", "burgundy", "maroon", "cherry", "rose", "coral"],
        "green": ["emerald", "forest", "lime", "olive", "mint", "sage", "jade"],
        "yellow": ["gold", "amber", "lemon", "canary", "butter", "cream"],
        "purple": ["violet", "lavender", "plum", "indigo", "magenta", "lilac"],
        "orange": ["tangerine", "peach", "coral", "amber", "rust", "copper"],
        "pink": ["rose", "coral", "salmon", "fuchsia", "magenta", "blush"],
        "brown": ["tan", "beige", "chocolate", "coffee", "caramel", "bronze"],
        "black": ["dark", "ebony", "charcoal", "coal", "jet", "midnight"],
        "white": ["ivory", "cream", "pearl", "snow", "alabaster", "pale"],
        "gray": ["grey", "silver", "ash", "slate", "pewter", "stone"],
        "grey": ["gray", "silver", "ash", "slate", "pewter", "stone"],
        
        // Clothing & Fashion
        "dress": ["gown", "frock", "outfit", "garment", "attire", "clothing"],
        "shirt": ["blouse", "top", "tee", "jersey", "garment", "clothing"],
        "pants": ["trousers", "jeans", "slacks", "bottoms", "legwear"],
        "shoes": ["footwear", "sneakers", "boots", "sandals", "loafers"],
        "jacket": ["coat", "blazer", "cardigan", "outerwear", "sweater"],
        "hat": ["cap", "beanie", "headwear", "helmet", "bonnet"],
        
        // Technology & Devices
        "phone": ["mobile", "cell", "smartphone", "device", "telephone", "cellular"],
        "mobile": ["phone", "cell", "smartphone", "device", "cellular"],
        "computer": ["laptop", "desktop", "pc", "mac", "device", "machine"],
        "laptop": ["computer", "notebook", "portable", "pc", "device"],
        "tablet": ["ipad", "device", "portable", "slate"],
        "camera": ["cam", "device", "recorder", "lens"],
        
        // Places & Locations
        "restaurant": ["cafe", "diner", "eatery", "bistro", "establishment", "place"],
        "cafe": ["restaurant", "coffee shop", "bistro", "eatery"],
        "hotel": ["motel", "inn", "lodge", "accommodation", "resort"],
        "store": ["shop", "market", "retailer", "outlet", "business"],
        "shop": ["store", "market", "retailer", "boutique", "outlet"],
        "market": ["store", "shop", "bazaar", "marketplace", "mart"],
        "office": ["workplace", "building", "headquarters", "bureau"],
        "home": ["house", "residence", "dwelling", "place", "apartment"],
        "house": ["home", "residence", "dwelling", "building"],
        
        // Business & Finance
        "money": ["cash", "currency", "funds", "payment", "finance", "dollar"],
        "cash": ["money", "currency", "funds", "payment", "bills"],
        "payment": ["transaction", "charge", "fee", "cost", "expense"],
        "price": ["cost", "fee", "charge", "amount", "value", "expense"],
        "cost": ["price", "fee", "charge", "amount", "expense"],
        "expense": ["cost", "price", "fee", "charge", "expenditure"],
        "bank": ["financial institution", "credit union", "finance"],
        "card": ["credit card", "debit card", "payment card"],
        
        // Transportation
        "car": ["vehicle", "auto", "automobile", "transport"],
        "truck": ["vehicle", "lorry", "pickup", "transport"],
        "bus": ["coach", "transport", "vehicle", "transit"],
        "train": ["rail", "railway", "locomotive", "transport"],
        "plane": ["aircraft", "airplane", "flight", "jet"],
        "bike": ["bicycle", "cycle", "transport"],
        
        // Food & Dining
        "food": ["meal", "dish", "cuisine", "nutrition", "dining"],
        "meal": ["food", "dish", "dinner", "lunch", "breakfast"],
        "drink": ["beverage", "liquid", "refreshment"],
        "coffee": ["espresso", "latte", "cappuccino", "brew", "java"],
        "tea": ["beverage", "brew", "infusion"],
        "pizza": ["pie", "slice", "italian food"],
        "burger": ["sandwich", "hamburger", "cheeseburger"],
        
        // Actions & Verbs
        "buy": ["purchase", "acquire", "get", "obtain", "shop"],
        "purchase": ["buy", "acquire", "get", "obtain", "shop"],
        "get": ["obtain", "acquire", "receive", "fetch", "retrieve"],
        "obtain": ["get", "acquire", "receive", "gain"],
        "send": ["transmit", "deliver", "dispatch", "mail"],
        "receive": ["get", "obtain", "accept", "collect"],
        "create": ["make", "build", "generate", "produce"],
        "make": ["create", "build", "generate", "produce"],
        
        // Time & Temporal
        "recent": ["latest", "new", "current", "fresh", "modern"],
        "new": ["recent", "latest", "fresh", "current", "modern"],
        "old": ["ancient", "vintage", "aged", "past", "former"],
        "current": ["present", "today", "now", "recent", "latest"],
        "past": ["previous", "former", "earlier", "old"],
        "future": ["upcoming", "coming", "next", "later"],
        
        // Size & Quantity
        "big": ["large", "huge", "enormous", "giant", "massive", "great"],
        "large": ["big", "huge", "enormous", "giant", "massive", "great"],
        "small": ["little", "tiny", "miniature", "compact", "petite"],
        "little": ["small", "tiny", "miniature", "compact", "petite"],
        "many": ["multiple", "several", "numerous", "various", "lots"],
        "few": ["some", "several", "limited", "handful"],
        
        // Quality Descriptors
        "good": ["excellent", "great", "fine", "quality", "nice"],
        "bad": ["poor", "terrible", "awful", "horrible", "negative"],
        "fast": ["quick", "rapid", "speedy", "swift"],
        "slow": ["sluggish", "gradual", "delayed", "leisurely"],
        "easy": ["simple", "effortless", "straightforward"],
        "hard": ["difficult", "challenging", "tough", "complex"],
        
        // Common Objects
        "book": ["novel", "text", "publication", "literature", "volume"],
        "paper": ["document", "sheet", "page", "form"],
        "pen": ["pencil", "marker", "writing tool", "stylus"],
        "bag": ["sack", "container", "purse", "backpack"],
        "box": ["container", "package", "carton", "case"],
        "bottle": ["container", "vessel", "flask"],
        
        // Digital/Web Terms
        "website": ["site", "web page", "url", "link", "portal"],
        "site": ["website", "web page", "url", "link", "portal"],
        "link": ["url", "connection", "hyperlink", "reference"],
        "email": ["mail", "message", "correspondence", "e-mail"],
        "app": ["application", "program", "software", "tool"],
        "application": ["app", "program", "software", "tool"],
        "video": ["clip", "movie", "recording", "footage"],
        "audio": ["sound", "music", "recording", "voice"],
        
        // Health & Body
        "medicine": ["medication", "drug", "pill", "remedy", "treatment"],
        "doctor": ["physician", "medical professional", "practitioner"],
        "hospital": ["medical center", "clinic", "healthcare facility"],
        
        // Multi-language Support (Spanish examples)
        "casa": ["home", "house", "residence"], // Spanish for house
        "comida": ["food", "meal", "dish"], // Spanish for food
        "agua": ["water", "drink", "beverage"], // Spanish for water
        "trabajo": ["work", "job", "employment"], // Spanish for work
        
        // Multi-language Support (French examples)
        "maison": ["home", "house", "residence"], // French for house
        "nourriture": ["food", "meal", "dish"], // French for food
        "eau": ["water", "drink", "beverage"], // French for water
        "travail": ["work", "job", "employment"] // French for work
    ]
    
    // MARK: - Contextual Synonyms
    
    /// Context-specific synonym groups for better semantic matching
    private let contextualSynonyms: [String: [String: Set<String>]] = [
        "shopping": [
            "buy": ["purchase", "shop for", "get", "order", "acquire"],
            "store": ["shop", "retailer", "outlet", "market", "mall"],
            "price": ["cost", "amount", "fee", "charge", "value"]
        ],
        "dining": [
            "food": ["meal", "dish", "cuisine", "dining", "nutrition"],
            "restaurant": ["cafe", "diner", "eatery", "bistro"],
            "drink": ["beverage", "refreshment", "liquid"]
        ],
        "travel": [
            "hotel": ["accommodation", "lodging", "inn", "resort"],
            "ticket": ["pass", "fare", "voucher", "boarding pass"],
            "trip": ["journey", "travel", "vacation", "visit"]
        ],
        "technology": [
            "phone": ["mobile", "device", "smartphone", "cellular"],
            "computer": ["laptop", "pc", "device", "machine"],
            "app": ["application", "program", "software"]
        ]
    ]
    
    // MARK: - Semantic Categories
    
    /// Organize terms by semantic meaning for better expansion
    private let semanticCategories: [String: Set<String>] = [
        "visual_media": ["photo", "picture", "image", "screenshot", "video", "clip"],
        "documents": ["document", "receipt", "bill", "form", "paper", "report"],
        "colors": ["red", "blue", "green", "yellow", "purple", "orange", "pink", "brown", "black", "white", "gray"],
        "clothing": ["dress", "shirt", "pants", "shoes", "jacket", "hat"],
        "technology": ["phone", "computer", "laptop", "tablet", "camera"],
        "places": ["restaurant", "hotel", "store", "office", "home"],
        "finance": ["money", "payment", "price", "cost", "bank", "card"],
        "transportation": ["car", "bus", "train", "plane", "bike"],
        "food": ["meal", "drink", "coffee", "pizza", "burger"]
    ]
    
    // MARK: - Public Methods
    
    /// Expand a query with synonyms and related terms
    public func expandQuery(_ query: String, maxExpansions: Int = 5) -> [String] {
        let words = tokenizeQuery(query)
        var expansions: Set<String> = []
        
        // Generate synonym combinations
        let synonymCombinations = generateSynonymCombinations(words: words, maxCombinations: maxExpansions)
        
        for combination in synonymCombinations {
            let expandedQuery = combination.joined(separator: " ")
            if expandedQuery != query.lowercased() {
                expansions.insert(expandedQuery)
            }
        }
        
        // Add contextual expansions
        let contextualExpansions = generateContextualExpansions(query: query)
        expansions.formUnion(contextualExpansions)
        
        // Sort by relevance and return top results
        return Array(expansions.prefix(maxExpansions))
    }
    
    /// Get synonyms for a specific term
    public func getSynonyms(for term: String) -> Set<String> {
        let lowercaseTerm = term.lowercased()
        return synonymDictionary[lowercaseTerm] ?? []
    }
    
    /// Check if two terms are synonymous
    public func areSynonyms(_ term1: String, _ term2: String) -> Bool {
        let synonyms1 = getSynonyms(for: term1)
        let synonyms2 = getSynonyms(for: term2)
        
        return synonyms1.contains(term2.lowercased()) || 
               synonyms2.contains(term1.lowercased()) ||
               !synonyms1.intersection(synonyms2).isEmpty
    }
    
    /// Get semantic category for a term
    public func getSemanticCategory(for term: String) -> String? {
        let lowercaseTerm = term.lowercased()
        
        for (category, terms) in semanticCategories {
            if terms.contains(lowercaseTerm) {
                return category
            }
        }
        
        return nil
    }
    
    // MARK: - Private Helper Methods
    
    private func tokenizeQuery(_ query: String) -> [String] {
        return query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    private func generateSynonymCombinations(words: [String], maxCombinations: Int) -> [[String]] {
        guard !words.isEmpty else { return [] }
        
        var combinations: Set<[String]> = []
        
        // Generate combinations by replacing each word with its synonyms
        func generateCombinations(currentIndex: Int, currentCombination: [String]) {
            guard combinations.count < maxCombinations else { return }
            
            if currentIndex >= words.count {
                combinations.insert(currentCombination)
                return
            }
            
            let word = words[currentIndex]
            let synonyms = getSynonyms(for: word)
            
            // Use original word
            generateCombinations(currentIndex: currentIndex + 1, 
                               currentCombination: currentCombination + [word])
            
            // Use synonyms
            for synonym in synonyms.prefix(3) { // Limit to 3 synonyms per word
                generateCombinations(currentIndex: currentIndex + 1,
                                   currentCombination: currentCombination + [synonym])
            }
        }
        
        generateCombinations(currentIndex: 0, currentCombination: [])
        return Array(combinations)
    }
    
    private func generateContextualExpansions(query: String) -> Set<String> {
        var expansions: Set<String> = []
        let queryWords = tokenizeQuery(query)
        
        // Detect context and apply contextual synonyms
        for (_, contextSynonyms) in contextualSynonyms {
            let contextIndicators = contextSynonyms.keys
            
            // Check if query contains context indicators
            for word in queryWords {
                if contextIndicators.contains(word) {
                    // Apply contextual synonyms
                    for (originalTerm, synonyms) in contextSynonyms {
                        if queryWords.contains(originalTerm) {
                            for synonym in synonyms {
                                let expandedQuery = query.replacingOccurrences(of: originalTerm, with: synonym)
                                expansions.insert(expandedQuery.lowercased())
                            }
                        }
                    }
                }
            }
        }
        
        return expansions
    }
}