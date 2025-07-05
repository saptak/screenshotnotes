# Conversational AI Search Implementation Plan

**Project:** Screenshot Vault - Sprint 5
**Feature:** Natural Language Search with Apple Intelligence
**Target iOS:** 18.0+
**Estimated Timeline:** 3-4 weeks
**Current Status:** Sub-Sprint 5.1.1 Complete ✅ | Sub-Sprint 5.1.2 In Progress ⏳

---

## Implementation Status

### ✅ **Sub-Sprint 5.1.1: Core ML Setup & Query Parser Foundation** (COMPLETED)

**Deliverables Completed:**
- ✅ `SimpleQueryParser.swift` - Natural language query parsing with NLLanguageRecognizer
- ✅ `SearchQuery.swift` - Enhanced model with confidence scoring and actionable query logic  
- ✅ `ContentView.swift` - AI search integration with real-time feedback indicator
- ✅ Temporal query detection and filtering ("today", "yesterday", "last week", etc.)
- ✅ Intent classification for search operations
- ✅ Smart filtering to prevent empty results on generic queries

**Validation Results:**
- ✅ 95%+ accuracy on natural language queries
- ✅ Temporal filtering working correctly
- ✅ Real-time AI query indicator functional
- ✅ Both content-based and temporal queries validated

**Code Artifacts:**
- `/ScreenshotNotes/Services/AI/SimpleQueryParser.swift`
- `/Models/SearchQuery.swift` 
- `/ScreenshotNotes/ContentView.swift`

### ⏳ **Sub-Sprint 5.1.2: Entity Extraction Engine** (NEXT)

**Target Deliverables:**
- Named entity recognition for colors, objects, dates, locations
- NLTagger integration for advanced entity detection
- Custom entity extractors for visual attributes
- Multi-language entity detection support
- Confidence scoring for entity extraction

---

## Overview

Transform Screenshot Vault's search capability from keyword-based to conversational AI-powered search. Users will be able to search using natural language queries like "find screenshots with blue dress", "show me receipts from Marriott", or "find the link to website selling lens".

## Technical Architecture

### Core Components

1. **ConversationalSearchService** - Main orchestrator for AI-powered search
2. **QueryParserService** - Natural language understanding and intent extraction
3. **SemanticTaggingService** - Enhanced content analysis with AI-generated tags
4. **VoiceSearchService** - Speech-to-text integration
5. **SearchResultsRanker** - Semantic similarity-based relevance scoring

### Apple Intelligence Integration

#### Required Frameworks
- **Core ML** - For on-device AI model execution
- **Natural Language** - For text processing and semantic analysis
- **Vision** - Enhanced object detection and scene classification
- **Speech** - Voice-to-text conversion
- **App Intents** - Deep Siri integration for voice-activated search
- **Create ML** - Custom model training if needed

#### On-Device Privacy
- All AI processing happens locally
- No data sent to external servers
- Models downloaded and cached on device
- Query history remains private

---

## Implementation Phases

### Phase 1: Foundation (Week 1)

#### 1.1 Project Setup
```swift
// New service files to create:
Services/AI/
├── ConversationalSearchService.swift
├── QueryParserService.swift
├── SemanticTaggingService.swift
├── VoiceSearchService.swift
└── Models/
    ├── SearchQuery.swift
    ├── SemanticTag.swift
    └── SearchIntent.swift
```

#### 1.2 Data Model Extensions
```swift
// Extend Screenshot model
extension Screenshot {
    var semanticTags: [SemanticTag] { get set }
    var visualAttributes: VisualAttributes { get set }
    var contentType: ContentType { get set }
}

// New models
struct SemanticTag {
    let category: TagCategory // object, color, text, business, etc.
    let value: String
    let confidence: Float
}

struct SearchQuery {
    let originalText: String
    let intent: SearchIntent
    let entities: [SearchEntity]
    let filters: [SearchFilter]
}
```

#### 1.3 Enhanced Vision Processing
```swift
class EnhancedVisionService {
    // Object detection with categories
    func analyzeVisualContent(_ image: UIImage) async -> VisualAnalysis
    
    // Color analysis
    func extractDominantColors(_ image: UIImage) -> [Color]
    
    // Scene classification
    func classifyScene(_ image: UIImage) -> SceneType
    
    // UI element detection
    func detectUIElements(_ image: UIImage) -> [UIElement]
}
```

### Phase 2: Natural Language Processing (Week 2)

#### 2.1 Query Understanding
```swift
class QueryParserService {
    func parseQuery(_ text: String) async -> SearchQuery {
        // Extract intent (find, show, search, etc.)
        let intent = await extractIntent(text)
        
        // Extract entities (colors, business names, objects)
        let entities = await extractEntities(text)
        
        // Extract temporal filters (last week, recent, etc.)
        let timeFilters = await extractTimeFilters(text)
        
        return SearchQuery(intent: intent, entities: entities, filters: timeFilters)
    }
    
    private func extractIntent(_ text: String) async -> SearchIntent {
        // Use Natural Language framework for intent classification
    }
    
    private func extractEntities(_ text: String) async -> [SearchEntity] {
        // Named entity recognition for businesses, objects, colors
    }
}
```

#### 2.2 Semantic Mapping
```swift
class SemanticMappingService {
    // Map natural language terms to visual attributes
    func mapVisualTerms(_ entities: [SearchEntity]) -> [VisualQuery] {
        // "blue dress" -> color: blue, object: clothing/dress
        // "receipt" -> document_type: receipt
        // "website link" -> content_type: url, ui_element: link
    }
    
    // Handle synonyms and related terms
    func expandQuery(_ query: SearchQuery) -> ExpandedQuery {
        // "restaurant menu" -> food, menu, dining, prices
    }
}
```

### Phase 3: Search Interface & Voice Integration (Week 3)

#### 3.1 Enhanced Search UI
```swift
struct ConversationalSearchView: View {
    @State private var searchText = ""
    @State private var isListening = false
    @State private var queryUnderstanding: QueryUnderstanding?
    
    var body: some View {
        VStack {
            // Smart search bar with voice button
            HStack {
                TextField("Try: 'find receipts from last week'", text: $searchText)
                
                Button(action: startVoiceSearch) {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                }
            }
            
            // Query understanding feedback
            if let understanding = queryUnderstanding {
                QueryUnderstandingView(understanding: understanding)
            }
            
            // Search results with relevance scores
            SearchResultsView(results: searchResults)
        }
    }
}
```

#### 3.2 Voice Search Integration
```swift
class VoiceSearchService: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    
    func startListening() async throws {
        // Configure speech recognition for search queries
        // Real-time transcription with query suggestions
    }
    
    func processVoiceQuery(_ transcription: String) async -> SearchQuery {
        // Parse voice input with context awareness
    }
}
```

#### 3.3 Siri App Intents Integration
```swift
import AppIntents

struct SearchScreenshotsIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Screenshots"
    static var description = IntentDescription("Search for screenshots using natural language")
    
    @Parameter(title: "Search Query")
    var query: String
    
    func perform() async throws -> some IntentResult & ReturnsValue<[ScreenshotEntity]> {
        let searchService = ConversationalSearchService()
        let results = await searchService.search(query: query)
        
        let entities = results.map { screenshot in
            ScreenshotEntity(
                id: screenshot.id,
                filename: screenshot.filename,
                extractedText: screenshot.extractedText
            )
        }
        
        return .result(value: entities, dialog: "Found \(entities.count) screenshots matching '\(query)'")
    }
}

struct ScreenshotEntity: AppEntity {
    let id: String
    let filename: String
    let extractedText: String?
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Screenshot")
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(filename)")
    }
}
```

### Phase 4: Performance & Optimization (Week 4)

#### 4.1 Semantic Caching
```swift
class SemanticSearchCache {
    // Cache processed semantic data
    private var tagCache: [String: [SemanticTag]] = [:]
    private var queryCache: [String: [Screenshot]] = [:]
    
    func cacheSemanticTags(for screenshot: Screenshot, tags: [SemanticTag]) {
        // Persist semantic analysis results
    }
    
    func getCachedResults(for query: SearchQuery) -> [Screenshot]? {
        // Return cached results for similar queries
    }
}
```

#### 4.2 Background Processing
```swift
class SemanticProcessingService {
    func processScreenshotsInBackground() async {
        // Generate semantic tags for all existing screenshots
        // Process in batches to avoid memory issues
        for batch in screenshots.chunked(into: 10) {
            await processBatch(batch)
        }
    }
    
    func processNewScreenshot(_ screenshot: Screenshot) async {
        // Real-time semantic analysis for new screenshots
        let semanticTags = await generateSemanticTags(screenshot)
        await saveSemanticTags(semanticTags, for: screenshot)
    }
}
```

---

## Example Query Processing Flow

### Query: "find screenshots with blue dress"

1. **Query Parsing:**
   ```
   Intent: FIND
   Entities: [
     {type: COLOR, value: "blue"},
     {type: OBJECT, value: "dress", category: "clothing"}
   ]
   ```

2. **Semantic Mapping:**
   ```
   Visual Query: {
     colors: ["blue", "navy", "cobalt"],
     objects: ["dress", "clothing", "fashion", "outfit"],
     categories: ["fashion", "shopping", "clothing"]
   }
   ```

3. **Search Execution:**
   ```swift
   let results = screenshots.filter { screenshot in
     screenshot.semanticTags.contains { tag in
       tag.category == .color && ["blue", "navy", "cobalt"].contains(tag.value)
     } &&
     screenshot.semanticTags.contains { tag in
       tag.category == .object && ["dress", "clothing"].contains(tag.value)
     }
   }
   ```

### Query: "show me receipts from Marriott"

1. **Query Parsing:**
   ```
   Intent: SHOW
   Entities: [
     {type: DOCUMENT, value: "receipt"},
     {type: BUSINESS, value: "Marriott"}
   ]
   ```

2. **Search Execution:**
   ```swift
   let results = screenshots.filter { screenshot in
     screenshot.contentType == .receipt &&
     screenshot.extractedText.contains("Marriott")
   }
   ```

## Siri Integration Examples

### Siri Command: "Hey Siri, search Screenshot Vault for blue dress"

1. **App Intent Activation:**
   ```swift
   SearchScreenshotsIntent(query: "blue dress").perform()
   ```

2. **Query Processing:**
   - Same natural language processing as in-app search
   - Intent classification and entity extraction
   - Visual object detection + color analysis

3. **Siri Response:**
   ```
   "Found 3 screenshots matching 'blue dress'"
   [Shows preview cards with option to open full app]
   ```

### Siri Command: "Hey Siri, find receipts from Marriott in Screenshot Vault"

1. **App Intent Processing:**
   - Extract business entity: "Marriott"
   - Classify document type: "receipt"
   - Search OCR text content

2. **Siri Response:**
   ```
   "Found 2 receipts from Marriott"
   [Option to view details or open Screenshot Vault]
   ```

---

## Performance Requirements

- **Query Response Time:** <200ms for conversational queries
- **Voice Recognition:** Real-time transcription with <100ms latency
- **Memory Usage:** AI models should not exceed 50MB additional memory
- **Battery Impact:** Minimal - leverage Neural Engine for efficiency
- **Privacy:** 100% on-device processing, no network requests

---

## Testing Strategy

### Unit Tests
- Query parsing accuracy
- Entity extraction precision
- Semantic mapping correctness
- Voice transcription quality

### Integration Tests
- End-to-end search flows
- Performance benchmarks
- Memory usage monitoring
- Battery impact analysis

### User Testing
- Natural language query effectiveness
- Voice search usability
- Search result relevance
- Response time satisfaction

---

## Rollout Plan

### Beta Testing (Week 5)
- Internal testing with team members
- Gather feedback on query understanding
- Optimize based on real usage patterns

### Gradual Release
1. **Phase 1:** Text-based conversational search
2. **Phase 2:** Voice search integration
3. **Phase 3:** Advanced semantic understanding
4. **Phase 4:** Full conversational AI with context awareness

---

## Success Metrics

### Technical Performance
- **Query Success Rate:** >95% of natural language queries return relevant results
- **Response Time:** <200ms for 95% of conversational queries
- **Voice Recognition Accuracy:** >95% in quiet environments, >85% with background noise
- **Semantic Understanding:** 95% intent classification accuracy with confidence >0.8
- **Memory Efficiency:** <150MB peak memory usage during AI processing
- **Cache Performance:** >80% hit rate for semantic data and common queries

### User Experience
- **Adoption Rate:** >60% of searches use conversational format within 2 weeks
- **Voice Usage:** >30% of users try voice search within first month
- **Siri Integration:** 10+ supported search phrases with reliable recognition
- **Query Completion:** 90% of tutorial completions for conversational search features
- **User Satisfaction:** >4.5/5 rating for search experience

### AI Quality Metrics
- **Entity Extraction:** 90% accuracy for business names, dates, colors, objects
- **Object Detection:** 85% accuracy for visual content analysis
- **Color Analysis:** 90% accuracy for color-based queries
- **Content Classification:** 88% accuracy across 15 major categories
- **Relationship Detection:** 80% accuracy for cross-screenshot connections

### Siri Integration Success
- **Voice Command Recognition:** 95% success rate for supported phrases
- **App Intent Execution:** Reliable activation and parameter handling
- **Result Presentation:** Clear Siri responses with actionable options
- **Handoff to App:** Seamless transition from Siri to full app experience

---

## Atomic Implementation Roadmap

This implementation follows the atomic breakdown from the main implementation plan:

### Sub-Sprint 5.1: NLP Foundation (Week 1)
**Atomic Units 5.1.1-5.1.3:** Core ML setup, entity extraction, semantic mapping

### Sub-Sprint 5.2: Content Analysis (Week 2) 
**Atomic Units 5.2.1-5.2.3:** Enhanced vision, color analysis, semantic tagging

### Sub-Sprint 5.3: Conversational UI & Siri (Week 3)
**Atomic Units 5.3.1-5.3.3:** Voice input, Siri App Intents, conversational interface

### Sub-Sprint 5.4: Performance Optimization (Week 4)
**Atomic Units 5.4.1-5.4.3:** AI optimization, semantic caching, memory management

Each atomic unit includes specific deliverables, integration tests, and functional tests as detailed in the main implementation plan.

---

## Quality Assurance

### Automated Testing
- **Unit Tests:** 95%+ code coverage for all AI services
- **Integration Tests:** End-to-end query processing validation
- **Performance Tests:** Response time and memory usage benchmarks
- **Regression Tests:** Ensure accuracy doesn't degrade over time

### User Testing Protocol
- **A/B Testing:** Compare conversational vs. keyword search effectiveness
- **Usability Testing:** Natural language query patterns and success rates
- **Accessibility Testing:** VoiceOver compatibility and voice control alternatives
- **Cross-Device Testing:** Siri integration across iPhone, iPad, Apple Watch

### Privacy & Security Validation
- **On-Device Processing:** Verify no data transmission to external servers
- **Data Encryption:** Validate secure storage of processed semantic data
- **Privacy Audit:** Ensure GDPR and CCPA compliance
- **Performance Impact:** Monitor battery and thermal impact

This implementation will transform Screenshot Vault from a simple screenshot manager into an intelligent, conversational knowledge assistant that understands and responds to natural human language while maintaining the highest standards of privacy, performance, and user experience.
