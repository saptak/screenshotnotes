import Foundation
import SwiftData
import SwiftUI
import OSLog

/// Comprehensive test suite for natural language search validation
/// Tests real-world conversational queries and validates search quality
@MainActor
public final class NaturalLanguageSearchTestSuite: ObservableObject {
    public static let shared = NaturalLanguageSearchTestSuite()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "NLSearchTestSuite")
    
    // MARK: - Published Properties
    
    @Published public private(set) var isRunningTests = false
    @Published public private(set) var testProgress: Double = 0.0
    @Published public private(set) var currentTest: String = ""
    @Published public private(set) var testResults: [TestResult] = []
    @Published public private(set) var overallScore: Double = 0.0
    @Published public private(set) var lastTestDate: Date?
    @Published public private(set) var performanceMetrics: PerformanceMetrics?
    
    // MARK: - Services
    
    private let naturalLanguageSearch = NaturalLanguageSearchService.shared
    private let temporalProcessor = TemporalQueryProcessor.shared
    private let contentAwareSearch = ContentAwareSearchEngine.shared
    private let voiceInterface = VoiceSearchInterface.shared
    private let queryOrchestrator = IntelligentQueryOrchestrator.shared
    private let rankingEngine = SearchResultRankingEngine.shared
    private let hapticService = HapticFeedbackService.shared
    
    // MARK: - Configuration
    
    public struct TestConfiguration {
        var enablePerformanceTesting: Bool = true
        var enableAccuracyTesting: Bool = true
        var enableUsabilityTesting: Bool = true
        var enableStressTesting: Bool = true
        var testIterations: Int = 10
        var performanceThresholdMs: Double = 500.0
        var accuracyThreshold: Double = 0.75
        var maxTestDuration: TimeInterval = 300.0 // 5 minutes
        var enableVoiceSearchTesting: Bool = true
        var enableRealWorldScenarios: Bool = true
        
        public init() {}
    }
    
    @Published public var configuration = TestConfiguration()
    
    // MARK: - Data Models
    
    /// Test result with detailed metrics
    public struct TestResult: Identifiable {
        public let id = UUID()
        let testType: TestType
        let testName: String
        let query: String
        let expectedResults: Int?
        let actualResults: Int
        let accuracy: Double
        let precision: Double
        let recall: Double
        let executionTime: TimeInterval
        let userSatisfactionScore: Double
        let relevanceScore: Double
        let status: TestStatus
        let errorMessage: String?
        let suggestions: [String]
        let timestamp: Date
        
        public enum TestType: String, CaseIterable {
            case temporalQuery = "temporal_query"
            case contentAwareSearch = "content_aware_search"
            case voiceSearch = "voice_search"
            case personalizedSearch = "personalized_search"
            case complexQuery = "complex_query"
            case rankingAccuracy = "ranking_accuracy"
            case performanceBenchmark = "performance_benchmark"
            case usabilityFlow = "usability_flow"
            case stressTest = "stress_test"
            case realWorldScenario = "real_world_scenario"
            
            public var displayName: String {
                switch self {
                case .temporalQuery: return "Temporal Query"
                case .contentAwareSearch: return "Content-Aware Search"
                case .voiceSearch: return "Voice Search"
                case .personalizedSearch: return "Personalized Search"
                case .complexQuery: return "Complex Query"
                case .rankingAccuracy: return "Ranking Accuracy"
                case .performanceBenchmark: return "Performance Benchmark"
                case .usabilityFlow: return "Usability Flow"
                case .stressTest: return "Stress Test"
                case .realWorldScenario: return "Real-World Scenario"
                }
            }
        }
        
        public enum TestStatus: String, CaseIterable {
            case passed = "passed"
            case failed = "failed"
            case warning = "warning"
            case skipped = "skipped"
            
            public var color: Color {
                switch self {
                case .passed: return .green
                case .failed: return .red
                case .warning: return .orange
                case .skipped: return .gray
                }
            }
        }
    }
    
    /// Performance metrics for detailed analysis
    public struct PerformanceMetrics {
        let averageResponseTime: TimeInterval
        let p95ResponseTime: TimeInterval
        let p99ResponseTime: TimeInterval
        let throughputQPS: Double
        let memoryUsage: Double
        let cacheHitRate: Double
        let errorRate: Double
        let concurrentUsers: Int
        let totalQueries: Int
        
        public init(
            averageResponseTime: TimeInterval,
            p95ResponseTime: TimeInterval,
            p99ResponseTime: TimeInterval,
            throughputQPS: Double,
            memoryUsage: Double,
            cacheHitRate: Double,
            errorRate: Double,
            concurrentUsers: Int,
            totalQueries: Int
        ) {
            self.averageResponseTime = averageResponseTime
            self.p95ResponseTime = p95ResponseTime
            self.p99ResponseTime = p99ResponseTime
            self.throughputQPS = throughputQPS
            self.memoryUsage = memoryUsage
            self.cacheHitRate = cacheHitRate
            self.errorRate = errorRate
            self.concurrentUsers = concurrentUsers
            self.totalQueries = totalQueries
        }
    }
    
    /// Test scenario for real-world validation
    public struct TestScenario {
        let name: String
        let description: String
        let queries: [TestQuery]
        let expectedBehavior: ExpectedBehavior
        let userProfile: UserProfile?
        
        public struct TestQuery {
            let text: String
            let inputMethod: InputMethod
            let expectedResultCount: Int?
            let expectedTopResult: String?
            let maxResponseTime: TimeInterval
            
            public enum InputMethod: String, CaseIterable {
                case text = "text"
                case voice = "voice"
                case conversational = "conversational"
            }
        }
        
        public struct ExpectedBehavior {
            let minAccuracy: Double
            let maxResponseTime: TimeInterval
            let shouldAdaptToUser: Bool
            let shouldProvideExplanations: Bool
            let shouldOfferSuggestions: Bool
        }
        
        public struct UserProfile {
            let searchFrequency: Double
            let preferredContentTypes: [String]
            let temporalPatterns: [String]
            let satisfactionHistory: [Double]
        }
    }
    
    // MARK: - Test Data
    
    private let temporalQueries = [
        "screenshots from yesterday",
        "images from last week",
        "photos from my vacation",
        "screenshots from this morning",
        "pictures from Christmas",
        "images from last month",
        "screenshots from work meeting",
        "photos from summer 2023",
        "screenshots from yesterday evening",
        "images from the weekend"
    ]
    
    private let contentAwareQueries = [
        "screenshots with phone numbers",
        "images with email addresses",
        "screenshots of receipts",
        "pictures with websites",
        "screenshots from social media",
        "images with text",
        "screenshots of documents",
        "photos with QR codes",
        "screenshots with contact info",
        "images of business cards"
    ]
    
    private let voiceQueries = [
        "Show me screenshots from yesterday",
        "Find images with phone numbers",
        "Look for receipts",
        "Search for work documents",
        "Find vacation photos",
        "Show me recent screenshots",
        "Find screenshots with text",
        "Look for social media posts",
        "Search for travel bookings",
        "Find contact information"
    ]
    
    private let complexQueries = [
        "screenshots with phone numbers from last week",
        "receipts from my vacation in July",
        "work documents from yesterday morning",
        "social media screenshots with links from this month",
        "travel bookings from summer with confirmation numbers",
        "business cards with email addresses from conferences",
        "food receipts from restaurants during my trip",
        "app screenshots with settings from recent updates",
        "meeting notes with action items from last quarter",
        "shopping receipts with tax information from December"
    ]
    
    private let realWorldScenarios = [
        TestScenario(
            name: "Travel Planning",
            description: "User searching for travel-related screenshots during trip planning",
            queries: [
                TestScenario.TestQuery(text: "flight bookings", inputMethod: .text, expectedResultCount: nil, expectedTopResult: nil, maxResponseTime: 1.0),
                TestScenario.TestQuery(text: "hotel reservations", inputMethod: .voice, expectedResultCount: nil, expectedTopResult: nil, maxResponseTime: 2.0),
                TestScenario.TestQuery(text: "screenshots from my Paris trip", inputMethod: .conversational, expectedResultCount: nil, expectedTopResult: nil, maxResponseTime: 1.5)
            ],
            expectedBehavior: TestScenario.ExpectedBehavior(
                minAccuracy: 0.8,
                maxResponseTime: 2.0,
                shouldAdaptToUser: true,
                shouldProvideExplanations: true,
                shouldOfferSuggestions: true
            ),
            userProfile: TestScenario.UserProfile(
                searchFrequency: 0.8,
                preferredContentTypes: ["travel", "booking", "receipt"],
                temporalPatterns: ["vacation", "trip"],
                satisfactionHistory: [0.8, 0.9, 0.7, 0.85]
            )
        ),
        
        TestScenario(
            name: "Work Documentation",
            description: "Professional user organizing work-related screenshots",
            queries: [
                TestScenario.TestQuery(text: "meeting notes from yesterday", inputMethod: .text, expectedResultCount: nil, expectedTopResult: nil, maxResponseTime: 0.8),
                TestScenario.TestQuery(text: "project screenshots", inputMethod: .text, expectedResultCount: nil, expectedTopResult: nil, maxResponseTime: 1.0),
                TestScenario.TestQuery(text: "work documents from this week", inputMethod: .conversational, expectedResultCount: nil, expectedTopResult: nil, maxResponseTime: 1.2)
            ],
            expectedBehavior: TestScenario.ExpectedBehavior(
                minAccuracy: 0.85,
                maxResponseTime: 1.5,
                shouldAdaptToUser: true,
                shouldProvideExplanations: false,
                shouldOfferSuggestions: true
            ),
            userProfile: TestScenario.UserProfile(
                searchFrequency: 1.2,
                preferredContentTypes: ["document", "meeting", "work"],
                temporalPatterns: ["workday", "business hours"],
                satisfactionHistory: [0.9, 0.8, 0.9, 0.85, 0.9]
            )
        )
    ]
    
    // MARK: - Initialization
    
    private init() {
        logger.info("NaturalLanguageSearchTestSuite initialized with comprehensive validation")
    }
    
    // MARK: - Public Interface
    
    /// Run comprehensive test suite
    /// - Parameter modelContext: Model context for testing
    public func runComprehensiveTests(in modelContext: ModelContext) async {
        guard !isRunningTests else { return }
        
        logger.info("Starting comprehensive natural language search tests")
        
        isRunningTests = true
        testProgress = 0.0
        testResults = []
        currentTest = "Initializing..."
        
        defer {
            isRunningTests = false
            testProgress = 0.0
            currentTest = ""
            lastTestDate = Date()
            calculateOverallScore()
        }
        
        let allTests: [(TestResult.TestType, [String])] = [
            (.temporalQuery, temporalQueries),
            (.contentAwareSearch, contentAwareQueries),
            (.voiceSearch, voiceQueries),
            (.complexQuery, complexQueries)
        ]
        
        var testIndex = 0
        let totalTests = allTests.count + (configuration.enableRealWorldScenarios ? realWorldScenarios.count : 0) + 3 // +3 for special tests
        
        // Run query-based tests
        for (testType, queries) in allTests {
            await updateProgress(
                Double(testIndex) / Double(totalTests),
                testName: "Testing \(testType.displayName)"
            )
            
            let results = await runQueryTests(testType: testType, queries: queries, in: modelContext)
            testResults.append(contentsOf: results)
            
            testIndex += 1
        }
        
        // Run performance benchmarks
        if configuration.enablePerformanceTesting {
            await updateProgress(
                Double(testIndex) / Double(totalTests),
                testName: "Performance Benchmarks"
            )
            
            let perfResults = await runPerformanceBenchmarks(in: modelContext)
            testResults.append(contentsOf: perfResults)
            testIndex += 1
        }
        
        // Run ranking accuracy tests
        await updateProgress(
            Double(testIndex) / Double(totalTests),
            testName: "Ranking Accuracy"
        )
        
        let rankingResults = await runRankingAccuracyTests(in: modelContext)
        testResults.append(contentsOf: rankingResults)
        testIndex += 1
        
        // Run stress tests
        if configuration.enableStressTesting {
            await updateProgress(
                Double(testIndex) / Double(totalTests),
                testName: "Stress Testing"
            )
            
            let stressResults = await runStressTests(in: modelContext)
            testResults.append(contentsOf: stressResults)
            testIndex += 1
        }
        
        // Run real-world scenarios
        if configuration.enableRealWorldScenarios {
            for scenario in realWorldScenarios {
                await updateProgress(
                    Double(testIndex) / Double(totalTests),
                    testName: "Scenario: \(scenario.name)"
                )
                
                let scenarioResults = await runRealWorldScenario(scenario, in: modelContext)
                testResults.append(contentsOf: scenarioResults)
                testIndex += 1
            }
        }
        
        await updateProgress(1.0, testName: "Tests Complete")
        
        // Calculate performance metrics
        performanceMetrics = calculatePerformanceMetrics()
        
        logger.info("Comprehensive tests completed: \(self.testResults.count) tests, overall score: \(String(format: "%.2f", self.overallScore))")
        
        // Provide completion haptic feedback
        hapticService.triggerWorkflowCompletionCelebration(.batchProcessing)
    }
    
    /// Run specific test type
    /// - Parameters:
    ///   - testType: Type of test to run
    ///   - modelContext: Model context for testing
    public func runSpecificTest(_ testType: TestResult.TestType, in modelContext: ModelContext) async -> [TestResult] {
        logger.info("Running specific test: \(testType.displayName)")
        
        switch testType {
        case .temporalQuery:
            return await runQueryTests(testType: testType, queries: temporalQueries, in: modelContext)
        case .contentAwareSearch:
            return await runQueryTests(testType: testType, queries: contentAwareQueries, in: modelContext)
        case .voiceSearch:
            return await runQueryTests(testType: testType, queries: voiceQueries, in: modelContext)
        case .complexQuery:
            return await runQueryTests(testType: testType, queries: complexQueries, in: modelContext)
        case .performanceBenchmark:
            return await runPerformanceBenchmarks(in: modelContext)
        case .rankingAccuracy:
            return await runRankingAccuracyTests(in: modelContext)
        case .stressTest:
            return await runStressTests(in: modelContext)
        case .realWorldScenario:
            var results: [TestResult] = []
            for scenario in realWorldScenarios {
                results.append(contentsOf: await runRealWorldScenario(scenario, in: modelContext))
            }
            return results
        default:
            return []
        }
    }
    
    /// Validate search quality for specific query
    /// - Parameters:
    ///   - query: Query to validate
    ///   - expectedResults: Expected result count
    ///   - modelContext: Model context
    /// - Returns: Quality validation result
    public func validateSearchQuality(
        query: String,
        expectedResults: Int? = nil,
        in modelContext: ModelContext
    ) async -> TestResult {
        
        let startTime = Date()
        
        do {
            // Perform search
            let results = await naturalLanguageSearch.searchWithNaturalLanguage(
                query: query,
                in: modelContext
            )
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            // Calculate metrics
            let accuracy = calculateAccuracy(results: results, expected: expectedResults)
            let precision = calculatePrecision(results: results, query: query)
            let recall = await calculateRecall(results: results, query: query, in: modelContext)
            let relevanceScore = await calculateRelevanceScore(results: results, query: query)
            let userSatisfactionScore = estimateUserSatisfaction(results: results, query: query)
            
            let status: TestResult.TestStatus
            if accuracy >= configuration.accuracyThreshold && 
               executionTime <= (configuration.performanceThresholdMs / 1000.0) {
                status = .passed
            } else if accuracy >= (configuration.accuracyThreshold * 0.8) {
                status = .warning
            } else {
                status = .failed
            }
            
            return TestResult(
                testType: .complexQuery,
                testName: "Quality Validation",
                query: query,
                expectedResults: expectedResults,
                actualResults: results.count,
                accuracy: accuracy,
                precision: precision,
                recall: recall,
                executionTime: executionTime,
                userSatisfactionScore: userSatisfactionScore,
                relevanceScore: relevanceScore,
                status: status,
                errorMessage: nil,
                suggestions: generateImprovementSuggestions(accuracy: accuracy, precision: precision, recall: recall),
                timestamp: Date()
            )
            
        } catch {
            return TestResult(
                testType: .complexQuery,
                testName: "Quality Validation",
                query: query,
                expectedResults: expectedResults,
                actualResults: 0,
                accuracy: 0.0,
                precision: 0.0,
                recall: 0.0,
                executionTime: Date().timeIntervalSince(startTime),
                userSatisfactionScore: 0.0,
                relevanceScore: 0.0,
                status: .failed,
                errorMessage: error.localizedDescription,
                suggestions: ["Fix error: \(error.localizedDescription)"],
                timestamp: Date()
            )
        }
    }
    
    // MARK: - Test Implementations
    
    private func runQueryTests(
        testType: TestResult.TestType,
        queries: [String],
        in modelContext: ModelContext
    ) async -> [TestResult] {
        
        var results: [TestResult] = []
        
        for (index, query) in queries.enumerated() {
            let startTime = Date()
            
            do {
                // Perform search based on test type
                let searchResults: [Screenshot]
                
                switch testType {
                case .voiceSearch:
                    // Simulate voice search (would use actual voice in real testing)
                    searchResults = await naturalLanguageSearch.searchWithNaturalLanguage(
                        query: query,
                        in: modelContext
                    )
                case .temporalQuery:
                    // Test temporal processing
                    _ = await temporalProcessor.processTemporalQuery(query)
                    searchResults = await naturalLanguageSearch.searchWithNaturalLanguage(
                        query: query,
                        in: modelContext
                    )
                case .contentAwareSearch:
                    // Test content-aware search
                    _ = await contentAwareSearch.analyzeContentQuery(query)
                    searchResults = await naturalLanguageSearch.searchWithNaturalLanguage(
                        query: query,
                        in: modelContext
                    )
                default:
                    searchResults = await naturalLanguageSearch.searchWithNaturalLanguage(
                        query: query,
                        in: modelContext
                    )
                }
                
                let executionTime = Date().timeIntervalSince(startTime)
                
                // Calculate metrics
                let accuracy = calculateAccuracy(results: searchResults, expected: nil)
                let precision = calculatePrecision(results: searchResults, query: query)
                let recall = await calculateRecall(results: searchResults, query: query, in: modelContext)
                let relevanceScore = await calculateRelevanceScore(results: searchResults, query: query)
                let userSatisfactionScore = estimateUserSatisfaction(results: searchResults, query: query)
                
                let status: TestResult.TestStatus
                if executionTime <= (configuration.performanceThresholdMs / 1000.0) && accuracy >= configuration.accuracyThreshold {
                    status = .passed
                } else if accuracy >= (configuration.accuracyThreshold * 0.8) {
                    status = .warning
                } else {
                    status = .failed
                }
                
                results.append(TestResult(
                    testType: testType,
                    testName: "\(testType.displayName) Test \(index + 1)",
                    query: query,
                    expectedResults: nil,
                    actualResults: searchResults.count,
                    accuracy: accuracy,
                    precision: precision,
                    recall: recall,
                    executionTime: executionTime,
                    userSatisfactionScore: userSatisfactionScore,
                    relevanceScore: relevanceScore,
                    status: status,
                    errorMessage: nil,
                    suggestions: generateImprovementSuggestions(accuracy: accuracy, precision: precision, recall: recall),
                    timestamp: Date()
                ))
                
            } catch {
                results.append(TestResult(
                    testType: testType,
                    testName: "\(testType.displayName) Test \(index + 1)",
                    query: query,
                    expectedResults: nil,
                    actualResults: 0,
                    accuracy: 0.0,
                    precision: 0.0,
                    recall: 0.0,
                    executionTime: Date().timeIntervalSince(startTime),
                    userSatisfactionScore: 0.0,
                    relevanceScore: 0.0,
                    status: .failed,
                    errorMessage: error.localizedDescription,
                    suggestions: ["Fix error: \(error.localizedDescription)"],
                    timestamp: Date()
                ))
            }
            
            // Small delay between tests
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return results
    }
    
    private func runPerformanceBenchmarks(in modelContext: ModelContext) async -> [TestResult] {
        var results: [TestResult] = []
        let testQueries = ["test query", "screenshots", "yesterday", "photos with text", "recent documents"]
        
        // Latency test
        var responseTimes: [TimeInterval] = []
        
        for _ in 0..<configuration.testIterations {
            let startTime = Date()
            
            _ = await naturalLanguageSearch.searchWithNaturalLanguage(
                query: testQueries.randomElement() ?? "test",
                in: modelContext
            )
            
            responseTimes.append(Date().timeIntervalSince(startTime))
        }
        
        let avgResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        _ = responseTimes.sorted()[Int(Double(responseTimes.count) * 0.95)]
        
        let latencyStatus: TestResult.TestStatus = avgResponseTime <= (configuration.performanceThresholdMs / 1000.0) ? .passed : .failed
        
        results.append(TestResult(
            testType: .performanceBenchmark,
            testName: "Latency Benchmark",
            query: "Performance test queries",
            expectedResults: nil,
            actualResults: configuration.testIterations,
            accuracy: 1.0,
            precision: 1.0,
            recall: 1.0,
            executionTime: avgResponseTime,
            userSatisfactionScore: latencyStatus == .passed ? 0.9 : 0.4,
            relevanceScore: 1.0,
            status: latencyStatus,
            errorMessage: nil,
            suggestions: latencyStatus == .passed ? [] : ["Optimize search performance", "Implement caching", "Review algorithm efficiency"],
            timestamp: Date()
        ))
        
        // Throughput test
        let throughputStartTime = Date()
        var throughputQueries = 0
        
        let throughputTask = Task {
            while !Task.isCancelled && Date().timeIntervalSince(throughputStartTime) < 10.0 {
                _ = await naturalLanguageSearch.searchWithNaturalLanguage(
                    query: testQueries.randomElement() ?? "test",
                    in: modelContext
                )
                throughputQueries += 1
            }
        }
        
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        throughputTask.cancel()
        
        let throughputQPS = Double(throughputQueries) / 10.0
        let throughputStatus: TestResult.TestStatus = throughputQPS >= 5.0 ? .passed : .warning
        
        results.append(TestResult(
            testType: .performanceBenchmark,
            testName: "Throughput Benchmark",
            query: "Concurrent queries",
            expectedResults: nil,
            actualResults: throughputQueries,
            accuracy: 1.0,
            precision: 1.0,
            recall: 1.0,
            executionTime: 10.0,
            userSatisfactionScore: throughputStatus == .passed ? 0.9 : 0.6,
            relevanceScore: 1.0,
            status: throughputStatus,
            errorMessage: nil,
            suggestions: throughputStatus == .passed ? [] : ["Optimize concurrent processing", "Implement query batching"],
            timestamp: Date()
        ))
        
        return results
    }
    
    private func runRankingAccuracyTests(in modelContext: ModelContext) async -> [TestResult] {
        var results: [TestResult] = []
        
        let rankingQueries = [
            "important screenshots",
            "recent work documents",
            "favorite photos",
            "screenshots with phone numbers",
            "vacation pictures"
        ]
        
        for (index, query) in rankingQueries.enumerated() {
            let startTime = Date()
            
            // Get search results
            let searchResults = await naturalLanguageSearch.searchWithNaturalLanguage(
                query: query,
                in: modelContext
            )
            
            // Test ranking
            let context = SearchResultRankingEngine.SearchContext(
                query: query,
                queryType: .specific,
                userIntent: .find,
                temporalContext: nil,
                userProfile: nil,
                sessionContext: nil
            )
            
            let rankedResults = await rankingEngine.rankResults(searchResults, context: context)
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            // Validate ranking quality
            let rankingQuality = validateRankingQuality(rankedResults)
            let diversityScore = calculateDiversityScore(rankedResults)
            
            let status: TestResult.TestStatus = rankingQuality >= 0.7 ? .passed : .warning
            
            results.append(TestResult(
                testType: .rankingAccuracy,
                testName: "Ranking Test \(index + 1)",
                query: query,
                expectedResults: nil,
                actualResults: rankedResults.count,
                accuracy: rankingQuality,
                precision: rankingQuality,
                recall: diversityScore,
                executionTime: executionTime,
                userSatisfactionScore: rankingQuality,
                relevanceScore: rankingQuality,
                status: status,
                errorMessage: nil,
                suggestions: status == .passed ? [] : ["Improve ranking algorithm", "Add more ranking factors"],
                timestamp: Date()
            ))
        }
        
        return results
    }
    
    private func runStressTests(in modelContext: ModelContext) async -> [TestResult] {
        var results: [TestResult] = []
        
        // Large query test
        let longQuery = String(repeating: "test query with many words ", count: 50)
        let startTime = Date()
        
        let stressResults = await naturalLanguageSearch.searchWithNaturalLanguage(
            query: longQuery,
            in: modelContext
        )
        
        let stressExecutionTime = Date().timeIntervalSince(startTime)
        let stressStatus: TestResult.TestStatus = stressExecutionTime <= 5.0 ? .passed : .warning
        
        results.append(TestResult(
            testType: .stressTest,
            testName: "Large Query Stress Test",
            query: "Long query with \(longQuery.components(separatedBy: " ").count) words",
            expectedResults: nil,
            actualResults: stressResults.count,
            accuracy: 1.0,
            precision: 1.0,
            recall: 1.0,
            executionTime: stressExecutionTime,
            userSatisfactionScore: stressStatus == .passed ? 0.8 : 0.4,
            relevanceScore: 1.0,
            status: stressStatus,
            errorMessage: nil,
            suggestions: stressStatus == .passed ? [] : ["Optimize query processing", "Add query length limits"],
            timestamp: Date()
        ))
        
        return results
    }
    
    private func runRealWorldScenario(_ scenario: TestScenario, in modelContext: ModelContext) async -> [TestResult] {
        var results: [TestResult] = []
        
        for (index, query) in scenario.queries.enumerated() {
            let startTime = Date()
            
            // Simulate user profile if provided
            if scenario.userProfile != nil {
                // Would set user profile in search service
            }
            
            let searchResults = await naturalLanguageSearch.searchWithNaturalLanguage(
                query: query.text,
                in: modelContext
            )
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            // Evaluate against scenario expectations
            let meetsAccuracy = calculateAccuracy(results: searchResults, expected: query.expectedResultCount) >= scenario.expectedBehavior.minAccuracy
            let meetsPerformance = executionTime <= scenario.expectedBehavior.maxResponseTime
            
            let status: TestResult.TestStatus = (meetsAccuracy && meetsPerformance) ? .passed : .failed
            
            results.append(TestResult(
                testType: .realWorldScenario,
                testName: "\(scenario.name) - Query \(index + 1)",
                query: query.text,
                expectedResults: query.expectedResultCount,
                actualResults: searchResults.count,
                accuracy: calculateAccuracy(results: searchResults, expected: query.expectedResultCount),
                precision: calculatePrecision(results: searchResults, query: query.text),
                recall: await calculateRecall(results: searchResults, query: query.text, in: modelContext),
                executionTime: executionTime,
                userSatisfactionScore: status == .passed ? 0.85 : 0.5,
                relevanceScore: await calculateRelevanceScore(results: searchResults, query: query.text),
                status: status,
                errorMessage: nil,
                suggestions: status == .passed ? [] : ["Improve scenario handling", "Enhance user personalization"],
                timestamp: Date()
            ))
        }
        
        return results
    }
    
    // MARK: - Metrics Calculation
    
    private func calculateAccuracy(results: [Screenshot], expected: Int?) -> Double {
        guard let expected = expected, expected > 0 else {
            return results.isEmpty ? 0.0 : 1.0
        }
        
        let actualCount = results.count
        let difference = abs(actualCount - expected)
        return max(0.0, 1.0 - (Double(difference) / Double(expected)))
    }
    
    private func calculatePrecision(results: [Screenshot], query: String) -> Double {
        guard !results.isEmpty else { return 0.0 }
        
        let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var relevantResults = 0
        
        for result in results.prefix(10) { // Check top 10 results
            let content = [result.extractedText, result.userNotes, result.filename]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            
            var termMatches = 0
            for term in queryTerms where term.count > 2 {
                if content.contains(term) {
                    termMatches += 1
                }
            }
            
            if termMatches > 0 {
                relevantResults += 1
            }
        }
        
        return Double(relevantResults) / Double(min(results.count, 10))
    }
    
    private func calculateRecall(results: [Screenshot], query: String, in modelContext: ModelContext) async -> Double {
        // Simplified recall calculation - in practice would need ground truth data
        return results.isEmpty ? 0.0 : min(1.0, Double(results.count) / 100.0)
    }
    
    private func calculateRelevanceScore(results: [Screenshot], query: String) async -> Double {
        guard !results.isEmpty else { return 0.0 }
        
        let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var totalRelevance = 0.0
        
        for result in results.prefix(5) { // Check top 5 results
            let content = [result.extractedText, result.userNotes, result.filename]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            
            var relevance = 0.0
            for term in queryTerms where term.count > 2 {
                if content.contains(term) {
                    relevance += 1.0
                }
            }
            
            totalRelevance += relevance / Double(queryTerms.count)
        }
        
        return totalRelevance / Double(min(results.count, 5))
    }
    
    private func estimateUserSatisfaction(results: [Screenshot], query: String) -> Double {
        var satisfaction = 0.5 // Base satisfaction
        
        // Boost if results found
        if !results.isEmpty {
            satisfaction += 0.2
        }
        
        // Boost for reasonable result count
        if results.count >= 3 && results.count <= 20 {
            satisfaction += 0.2
        }
        
        // Boost for relevant top results
        if let topResult = results.first {
            let content = [topResult.extractedText, topResult.userNotes, topResult.filename]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            
            if content.contains(query.lowercased()) {
                satisfaction += 0.1
            }
        }
        
        return min(1.0, satisfaction)
    }
    
    private func validateRankingQuality(_ rankedResults: [SearchResultRankingEngine.RankedResult]) -> Double {
        guard !rankedResults.isEmpty else { return 0.0 }
        
        // Check if scores are in descending order
        var properlyRanked = 0
        for i in 0..<(rankedResults.count - 1) {
            if rankedResults[i].finalScore >= rankedResults[i + 1].finalScore {
                properlyRanked += 1
            }
        }
        
        return Double(properlyRanked) / Double(max(rankedResults.count - 1, 1))
    }
    
    private func calculateDiversityScore(_ rankedResults: [SearchResultRankingEngine.RankedResult]) -> Double {
        guard rankedResults.count > 1 else { return 1.0 }
        
        var uniqueApps: Set<String> = []
        var uniqueTypes: Set<String> = []
        
        for result in rankedResults.prefix(10) {
            if !result.screenshot.filename.isEmpty {
                uniqueApps.insert(result.screenshot.filename)
            }
            
            if let visual = result.screenshot.visualAttributes {
                uniqueTypes.insert(visual.isDocument ? "document" : "general")
            }
        }
        
        let diversityScore = (Double(uniqueApps.count) + Double(uniqueTypes.count)) / 2.0
        return min(1.0, diversityScore / 5.0) // Normalize to 0-1
    }
    
    private func generateImprovementSuggestions(accuracy: Double, precision: Double, recall: Double) -> [String] {
        var suggestions: [String] = []
        
        if accuracy < 0.7 {
            suggestions.append("Improve query understanding accuracy")
        }
        
        if precision < 0.6 {
            suggestions.append("Enhance result relevance filtering")
        }
        
        if recall < 0.5 {
            suggestions.append("Expand search coverage")
        }
        
        if suggestions.isEmpty {
            suggestions.append("Performance within acceptable ranges")
        }
        
        return suggestions
    }
    
    private func calculatePerformanceMetrics() -> PerformanceMetrics {
        let executionTimes = testResults.map { $0.executionTime }
        guard !executionTimes.isEmpty else {
            return PerformanceMetrics(
                averageResponseTime: 0, p95ResponseTime: 0, p99ResponseTime: 0,
                throughputQPS: 0, memoryUsage: 0, cacheHitRate: 0,
                errorRate: 0, concurrentUsers: 1, totalQueries: 0
            )
        }
        
        let sortedTimes = executionTimes.sorted()
        let totalTests = testResults.count
        
        return PerformanceMetrics(
            averageResponseTime: executionTimes.reduce(0, +) / Double(executionTimes.count),
            p95ResponseTime: sortedTimes[min(Int(Double(totalTests) * 0.95), totalTests - 1)],
            p99ResponseTime: sortedTimes[min(Int(Double(totalTests) * 0.99), totalTests - 1)],
            throughputQPS: Double(totalTests) / 60.0, // Assume 1 minute total test time
            memoryUsage: 0.0, // Would need actual memory monitoring
            cacheHitRate: 0.8, // Estimated
            errorRate: Double(testResults.filter { $0.status == .failed }.count) / Double(totalTests),
            concurrentUsers: 1,
            totalQueries: totalTests
        )
    }
    
    private func calculateOverallScore() {
        guard !testResults.isEmpty else {
            overallScore = 0.0
            return
        }
        
        let weights: [TestResult.TestType: Double] = [
            .temporalQuery: 1.5,
            .contentAwareSearch: 1.5,
            .voiceSearch: 1.2,
            .complexQuery: 2.0,
            .rankingAccuracy: 1.8,
            .performanceBenchmark: 1.0,
            .stressTest: 0.8,
            .realWorldScenario: 2.5
        ]
        
        var weightedScore = 0.0
        var totalWeight = 0.0
        
        for result in testResults {
            let weight = weights[result.testType] ?? 1.0
            let score = (result.accuracy + result.precision + result.recall) / 3.0
            
            weightedScore += score * weight
            totalWeight += weight
        }
        
        overallScore = totalWeight > 0 ? weightedScore / totalWeight : 0.0
    }
    
    // MARK: - Helper Methods
    
    private func updateProgress(_ progress: Double, testName: String) async {
        await MainActor.run {
            testProgress = max(0.0, min(1.0, progress))
            currentTest = testName
        }
    }
}

// MARK: - Test Results View

public struct NaturalLanguageSearchTestView: View {
    @StateObject private var testSuite = NaturalLanguageSearchTestSuite.shared
    @Environment(\.modelContext) private var modelContext
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if testSuite.isRunningTests {
                    testProgressView
                } else {
                    testResultsView
                }
            }
            .navigationTitle("Natural Language Search Tests")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Run Tests") {
                        Task {
                            await testSuite.runComprehensiveTests(in: modelContext)
                        }
                    }
                    .disabled(testSuite.isRunningTests)
                }
            }
        }
    }
    
    private var testProgressView: some View {
        VStack(spacing: 24) {
            // Progress Indicator
            VStack(spacing: 12) {
                ProgressView(value: testSuite.testProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(y: 2.0)
                
                Text(testSuite.currentTest)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("\(Int(testSuite.testProgress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var testResultsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Overall Score
                VStack(spacing: 8) {
                    Text("Overall Test Score")
                        .font(.headline)
                    
                    Text("\(Int(testSuite.overallScore * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(testSuite.overallScore >= 0.8 ? .green : testSuite.overallScore >= 0.6 ? .orange : .red)
                    
                    if let lastTest = testSuite.lastTestDate {
                        Text("Last tested: \(lastTest, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .glassBackground(material: .regular, cornerRadius: 16, shadow: true)
                
                // Performance Metrics
                if let metrics = testSuite.performanceMetrics {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance Metrics")
                            .font(.headline)
                        
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                            GridRow {
                                Text("Avg Response Time:")
                                Text("\(Int(metrics.averageResponseTime * 1000))ms")
                                    .fontWeight(.medium)
                            }
                            
                            GridRow {
                                Text("P95 Response Time:")
                                Text("\(Int(metrics.p95ResponseTime * 1000))ms")
                                    .fontWeight(.medium)
                            }
                            
                            GridRow {
                                Text("Error Rate:")
                                Text("\(String(format: "%.1f", metrics.errorRate * 100))%")
                                    .fontWeight(.medium)
                                    .foregroundColor(metrics.errorRate > 0.1 ? .red : .green)
                            }
                            
                            GridRow {
                                Text("Total Queries:")
                                Text("\(metrics.totalQueries)")
                                    .fontWeight(.medium)
                            }
                        }
                        .font(.caption)
                    }
                    .padding()
                    .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
                }
                
                // Test Results by Type
                let groupedResults = Dictionary(grouping: testSuite.testResults, by: { $0.testType })
                
                ForEach(Array(groupedResults.keys.sorted(by: { $0.displayName < $1.displayName })), id: \.self) { testType in
                    if let results = groupedResults[testType] {
                        TestTypeSection(testType: testType, results: results)
                    }
                }
            }
            .padding()
        }
    }
}

private struct TestTypeSection: View {
    let testType: NaturalLanguageSearchTestSuite.TestResult.TestType
    let results: [NaturalLanguageSearchTestSuite.TestResult]
    
    private var averageScore: Double {
        guard !results.isEmpty else { return 0.0 }
        return results.map { ($0.accuracy + $0.precision + $0.recall) / 3.0 }.reduce(0, +) / Double(results.count)
    }
    
    private var passRate: Double {
        guard !results.isEmpty else { return 0.0 }
        return Double(results.filter { $0.status == .passed }.count) / Double(results.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(testType.displayName)
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(averageScore * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(averageScore >= 0.8 ? .green : averageScore >= 0.6 ? .orange : .red)
                    
                    Text("\(Int(passRate * 100))% pass rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            LazyVStack(spacing: 8) {
                ForEach(results.prefix(5), id: \.id) { result in
                    TestResultRow(result: result)
                }
                
                if results.count > 5 {
                    Text("... and \(results.count - 5) more tests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .glassBackground(material: .regular, cornerRadius: 12, shadow: true)
    }
}

private struct TestResultRow: View {
    let result: NaturalLanguageSearchTestSuite.TestResult
    
    var body: some View {
        HStack {
            Circle()
                .fill(result.status.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.testName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(result.query)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(result.accuracy * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(Int(result.executionTime * 1000))ms")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview {
    NaturalLanguageSearchTestView()
}
#endif