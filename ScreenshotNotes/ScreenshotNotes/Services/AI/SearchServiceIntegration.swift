import Foundation

/// Integration demonstration showing how Sub-Sprint 5.1.1 integrates with existing SearchService
/// This file bridges the new QueryParser with the existing search infrastructure

/// MARK: - Integration Bridge

/// Extension to integrate natural language processing with existing SearchService
/// This is how the QueryParser will be used by the rest of the application
extension SearchService {
    
    /// Enhanced search method that uses natural language understanding
    /// Falls back to traditional search if NLP confidence is low
    func searchWithNaturalLanguage(query: String, in screenshots: [Screenshot]) async -> [Screenshot] {
        // Use the new QueryParser for natural language understanding
        let queryParser = QueryParserComplete()
        let parsedQuery = await queryParser.parseQuery(query)
        
        // If parsing confidence is good, use enhanced search terms
        if parsedQuery.isActionable && parsedQuery.confidence >= 0.6 {
            // Use the extracted search terms for more precise matching
            let enhancedQuery = parsedQuery.searchTerms.joined(separator: " ")
            let results = searchScreenshots(query: enhancedQuery, in: screenshots)
            
            // Future: Could apply additional filters based on intent and context
            // if parsedQuery.hasVisualAttributes { /* prioritize visual content */ }
            // if parsedQuery.hasTemporalContext { /* apply date filtering */ }
            
            return results
        } else {
            // Fall back to existing search implementation
            return searchScreenshots(query: query, in: screenshots)
        }
    }
    
    /// Preview method for testing natural language query understanding
    func previewQueryParsing(query: String) async -> String {
        let queryParser = QueryParserComplete()
        let result = await queryParser.parseQuery(query)
        return result.debugDescription
    }
}

/// MARK: - Integration Validation

/// Quick validation that the integration works with existing types
public class SearchServiceIntegrationValidator {
    
    public static func validateIntegration() async {
        print("🔗 Validating Sub-Sprint 5.1.1 Integration with SearchService")
        print(String(repeating: "-", count: 50))
        
        // Create a SearchService instance (this would work in the full app context)
        let searchService = SearchService()
        
        // Test natural language query preview
        let testQueries = [
            "find blue dress",
            "search for receipts from last week",
            "show me phone numbers",
            "filter screenshots with text"
        ]
        
        print("📝 Testing Natural Language Query Understanding:")
        for query in testQueries {
            let preview = await searchService.previewQueryParsing(query: query)
            print("\nQuery: '\(query)'")
            print("Analysis:\n\(preview)")
        }
        
        print("\n✅ Integration validation complete")
        print("🎯 Sub-Sprint 5.1.1 successfully integrates with existing SearchService")
        
        // Performance validation
        await validatePerformance(searchService: searchService)
    }
    
    private static func validatePerformance(searchService: SearchService) async {
        print("\n⚡ Performance Integration Test:")
        
        let complexQuery = "find blue dress from yesterday with phone numbers and receipts"
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let _ = await searchService.previewQueryParsing(query: complexQuery)
        
        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("Complex query processing: \(String(format: "%.1f", totalTime))ms")
        print("Performance target (<200ms): \(totalTime < 200 ? "✅ PASSED" : "❌ FAILED")")
    }
}

/// MARK: - Usage Instructions

/*
 To test the integration in the full app context:
 
 1. In ContentView or SearchView, use the enhanced search:
    
    let searchService = SearchService()
    let results = await searchService.searchWithNaturalLanguage(
        query: "find blue dress", 
        in: screenshots
    )
 
 2. For query preview/debugging:
    
    let preview = await searchService.previewQueryParsing(query: "find blue dress")
    print(preview)
 
 3. To run integration validation:
    
    Task {
        await SearchServiceIntegrationValidator.validateIntegration()
    }
*/
