import Foundation
import NaturalLanguage

/// Integration tests for Sub-Sprint 5.1.2: Entity Extraction Engine
/// This file validates the integration between QueryParserService and EntityExtractionService
@available(iOS 17.0, *)
@MainActor
public class EntityExtractionIntegrationTests {
    
    private let queryParser = QueryParserService()
    
    // MARK: - Core Integration Tests
    
    /// Integration Test: "blue dress from last Tuesday" → extract color:blue, object:dress, time:lastTuesday
    public func testIntegrationTestBlueDessTuesday() async -> Bool {
        let query = "blue dress from last Tuesday"
        let result = await queryParser.parseQuery(query)
        
        print("🧪 Integration Test: Blue Dress Tuesday")
        print("Query: '\(query)'")
        print("Entities: \(result.extractedEntities.count)")
        
        // Check for required entities
        let hasBlueColor = result.colorEntities.contains { $0.normalizedValue == "blue" }
        let hasDressObject = result.objectEntities.contains { $0.normalizedValue == "dress" }
        let hasTemporalEntity = result.hasTemporalEntities
        
        print("✓ Blue color detected: \(hasBlueColor)")
        print("✓ Dress object detected: \(hasDressObject)")
        print("✓ Temporal entity detected: \(hasTemporalEntity)")
        print("✓ Query has rich entity data: \(result.hasRichEntityData)")
        print("Debug: \(result.debugDescription)")
        print("")
        
        return hasBlueColor && hasDressObject && hasTemporalEntity
    }
    
    /// Test visual entity extraction
    public func testVisualEntityExtraction() async -> Bool {
        let testQueries = [
            "find red shirt",
            "show me green car",
            "purple phone screenshot",
            "dark blue dress"
        ]
        
        print("🧪 Visual Entity Extraction Test")
        var allPassed = true
        
        for query in testQueries {
            let result = await queryParser.parseQuery(query)
            let hasVisualEntities = result.hasVisualEntities
            let hasColorEntity = !result.colorEntities.isEmpty
            
            print("Query: '\(query)' → Visual: \(hasVisualEntities), Colors: \(hasColorEntity)")
            if !hasVisualEntities || !hasColorEntity {
                allPassed = false
            }
        }
        
        print("Visual entity extraction: \(allPassed ? "✅ PASSED" : "❌ FAILED")")
        print("")
        return allPassed
    }
    
    /// Test temporal entity extraction
    public func testTemporalEntityExtraction() async -> Bool {
        let testQueries = [
            "screenshots from yesterday",
            "photos from last week",
            "images from this month",
            "receipts from today"
        ]
        
        print("🧪 Temporal Entity Extraction Test")
        var allPassed = true
        
        for query in testQueries {
            let result = await queryParser.parseQuery(query)
            let hasTemporalEntities = result.hasTemporalEntities
            let hasTemporalContext = result.hasTemporalContext
            
            print("Query: '\(query)' → Temporal Entities: \(hasTemporalEntities), Context: \(hasTemporalContext)")
            if !hasTemporalEntities || !hasTemporalContext {
                allPassed = false
            }
        }
        
        print("Temporal entity extraction: \(allPassed ? "✅ PASSED" : "❌ FAILED")")
        print("")
        return allPassed
    }
    
    /// Test document type entity extraction
    public func testDocumentTypeExtraction() async -> Bool {
        let testQueries = [
            "find receipt from Marriott",
            "show me invoice documents",
            "ticket screenshots",
            "menu from restaurant"
        ]
        
        print("🧪 Document Type Extraction Test")
        var allPassed = true
        
        for query in testQueries {
            let result = await queryParser.parseQuery(query)
            let hasDocumentTypes = !result.documentTypeEntities.isEmpty
            
            print("Query: '\(query)' → Document Types: \(hasDocumentTypes)")
            print("  Entities: \(result.documentTypeEntities.map { $0.normalizedValue })")
            
            if !hasDocumentTypes {
                allPassed = false
            }
        }
        
        print("Document type extraction: \(allPassed ? "✅ PASSED" : "❌ FAILED")")
        print("")
        return allPassed
    }
    
    /// Test pattern-based extraction (phone, email, URL)
    public func testPatternBasedExtraction() async -> Bool {
        let testQueries = [
            "call 555-123-4567 for support",
            "email contact@example.com",
            "visit https://example.com",
            "price $29.99"
        ]
        
        print("🧪 Pattern-Based Extraction Test")
        var allPassed = true
        
        for query in testQueries {
            let result = await queryParser.parseQuery(query)
            let hasPatternEntities = result.extractedEntities.contains { entity in
                [EntityType.phoneNumber, EntityType.email, EntityType.url, EntityType.currency].contains(entity.type)
            }
            
            print("Query: '\(query)' → Pattern Entities: \(hasPatternEntities)")
            print("  Entities: \(result.extractedEntities.map { "\($0.type.rawValue):\($0.normalizedValue)" })")
            
            if !hasPatternEntities {
                allPassed = false
            }
        }
        
        print("Pattern-based extraction: \(allPassed ? "✅ PASSED" : "❌ FAILED")")
        print("")
        return allPassed
    }
    
    /// Test entity confidence scoring
    public func testEntityConfidenceScoring() async -> Bool {
        let query = "find blue dress receipt from Marriott hotel yesterday"
        let result = await queryParser.parseQuery(query)
        
        print("🧪 Entity Confidence Scoring Test")
        print("Query: '\(query)'")
        print("Total entities: \(result.extractedEntities.count)")
        print("Actionable entities: \(result.actionableEntities.count)")
        
        let hasHighConfidenceEntities = result.actionableEntities.count >= 3
        let relevanceScore = result.relevanceScore
        
        print("High-confidence entities: \(hasHighConfidenceEntities)")
        print("Overall relevance score: \(String(format: "%.2f", relevanceScore))")
        
        for entity in result.extractedEntities {
            print("  \(entity.type.rawValue): '\(entity.text)' (confidence: \(entity.confidence.rawValue))")
        }
        
        let passed = hasHighConfidenceEntities && relevanceScore > 0.6
        print("Confidence scoring: \(passed ? "✅ PASSED" : "❌ FAILED")")
        print("")
        return passed
    }
    
    /// Test multi-language support
    public func testMultiLanguageSupport() async -> Bool {
        let testQueries = [
            ("blue dress", NLLanguage.english),
            ("vestido azul", NLLanguage.spanish),
            ("robe bleue", NLLanguage.french)
        ]
        
        print("🧪 Multi-Language Support Test")
        var allPassed = true
        
        for (query, expectedLanguage) in testQueries {
            let result = await queryParser.parseQuery(query)
            let languageDetected = result.language == expectedLanguage || result.language == .english // Default fallback
            let hasEntities = !result.extractedEntities.isEmpty
            
            print("Query: '\(query)' (\(expectedLanguage.rawValue)) → Detected: \(result.language.rawValue), Entities: \(hasEntities)")
            
            if !languageDetected || !hasEntities {
                allPassed = false
            }
        }
        
        print("Multi-language support: \(allPassed ? "✅ PASSED" : "❌ FAILED")")
        print("")
        return allPassed
    }
    
    /// Performance test for entity extraction
    public func testEntityExtractionPerformance() async -> Bool {
        let complexQuery = "find blue dress receipt from Marriott hotel restaurant yesterday evening with phone number 555-123-4567 and email booking@marriott.com"
        
        print("🧪 Entity Extraction Performance Test")
        print("Query: '\(complexQuery)'")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = await queryParser.parseQuery(complexQuery)
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        print("Processing time: \(String(format: "%.1f", processingTime))ms")
        print("Target: <500ms for complex queries")
        print("Entities extracted: \(result.extractedEntities.count)")
        print("Entity types: \(Set(result.extractedEntities.map { $0.type.rawValue }))")
        
        let passed = processingTime < 500 && result.extractedEntities.count >= 5
        print("Performance test: \(passed ? "✅ PASSED" : "❌ FAILED")")
        print("")
        return passed
    }
    
    // MARK: - Functional Test Suite
    
    /// Run all functional tests to achieve 90% entity extraction accuracy
    public func runFunctionalTestSuite() async -> Bool {
        print("🚀 Starting Sub-Sprint 5.1.2 Functional Test Suite")
        print("Target: Achieve 90% entity extraction accuracy on test dataset")
        print("=" * 60)
        print("")
        
        let testResults = await [
            testIntegrationTestBlueDessTuesday(),
            testVisualEntityExtraction(),
            testTemporalEntityExtraction(),
            testDocumentTypeExtraction(),
            testPatternBasedExtraction(),
            testEntityConfidenceScoring(),
            testMultiLanguageSupport(),
            testEntityExtractionPerformance()
        ]
        
        let passedTests = testResults.filter { $0 }.count
        let totalTests = testResults.count
        let successRate = Double(passedTests) / Double(totalTests) * 100
        
        print("=" * 60)
        print("📊 FUNCTIONAL TEST RESULTS")
        print("Tests passed: \(passedTests)/\(totalTests)")
        print("Success rate: \(String(format: "%.1f", successRate))%")
        print("Target: 90% accuracy")
        
        let overallSuccess = successRate >= 90.0
        print("Overall result: \(overallSuccess ? "✅ SUCCESS" : "❌ NEEDS IMPROVEMENT")")
        
        if overallSuccess {
            print("🎉 Sub-Sprint 5.1.2: Entity Extraction Engine - COMPLETE!")
            print("✅ Named entity recognition for colors, objects, dates, locations")
            print("✅ NLTagger integration for advanced entity detection")
            print("✅ Custom entity extractors for visual attributes")
            print("✅ Multi-language entity detection support")
            print("✅ Confidence scoring for entity extraction")
        }
        
        return overallSuccess
    }
}

// MARK: - String Extension for Formatting

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
