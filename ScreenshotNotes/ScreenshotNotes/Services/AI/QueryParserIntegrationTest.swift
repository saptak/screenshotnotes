import Foundation

// Simple integration test for Sub-Sprint 5.1.1
// This file tests the basic functionality of QueryParserService

class QueryParserIntegrationTest {
    
    func testBasicQueryParsing() async {
        let parser = QueryParserService()
        
        // Test cases from the implementation plan
        let testQueries = [
            "find blue dress",
            "search for documents",
            "show me receipts",
            "filter by last week"
        ]
        
        for query in testQueries {
            let result = await parser.parseQuery(query)
            print("Query: '\(query)' → Intent: \(result.intent.rawValue), Confidence: \(result.confidence.rawValue)")
            
            // Validation as per integration test requirements
            assert(result.intent != .unknown || result.confidence == .veryLow, 
                   "Query should have valid intent or very low confidence")
            assert(!result.searchTerms.isEmpty || result.confidence == .veryLow, 
                   "Query should have search terms or very low confidence")
        }
    }
    
    func testFunctionalValidation() async {
        let parser = QueryParserService()
        
        // Functional test: "find blue dress" should return SearchIntent with visual attributes
        let result = await parser.parseQuery("find blue dress")
        
        // Verify 95% accuracy requirement simulation
        assert(result.intent == .find, "Should detect 'find' intent")
        assert(result.hasVisualAttributes, "Should detect visual attributes (blue, dress)")
        assert(result.searchTerms.contains("blue"), "Should extract 'blue' as search term")
        assert(result.searchTerms.contains("dress"), "Should extract 'dress' as search term")
        assert(result.confidence.rawValue >= 0.6, "Should have medium or higher confidence")
        
        print("✅ Integration test passed: \(result.debugDescription)")
    }
}

// Example usage for verification
func runIntegrationTests() async {
    let test = QueryParserIntegrationTest()
    await test.testBasicQueryParsing()
    await test.testFunctionalValidation()
    print("🎯 Sub-Sprint 5.1.1 Integration Tests Complete")
}
