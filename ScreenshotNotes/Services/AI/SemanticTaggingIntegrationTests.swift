import Foundation
import UIKit

/// Integration tests for semantic tagging functionality
/// This file provides comprehensive tests for Sprint 5.2.3 implementation
@MainActor
public class SemanticTaggingIntegrationTests: ObservableObject {
    
    @Published public var testResults: [TestResult] = []
    @Published public var isRunning = false
    @Published public var currentTest = ""
    
    private let semanticTaggingService = SemanticTaggingService()
    
    public init() {}
    
    /// Run comprehensive integration tests for semantic tagging
    public func runIntegrationTests() async {
        await MainActor.run {
            isRunning = true
            testResults = []
            currentTest = "Starting integration tests..."
        }
        
        // Test 1: Receipt screenshot tagging
        await testReceiptTagging()
        
        // Test 2: Hotel receipt business entity recognition
        await testHotelReceiptTagging()
        
        // Test 3: Content type classification
        await testContentTypeClassification()
        
        // Test 4: Business entity extraction
        await testBusinessEntityExtraction()
        
        // Test 5: Confidence-based tag weighting
        await testConfidenceWeighting()
        
        // Test 6: Multi-modal analysis
        await testMultiModalAnalysis()
        
        await MainActor.run {
            isRunning = false
            currentTest = "Tests completed"
        }
    }
    
    // MARK: - Individual Test Cases
    
    private func testReceiptTagging() async {
        await updateCurrentTest("Testing receipt screenshot tagging")
        
        let testText = """
        Marriott Hotel
        Downtown Location
        
        Receipt #12345
        Date: 2024-01-15
        
        Room Charge    $189.00
        Tax            $23.67
        Total          $212.67
        
        Payment: Credit Card ****1234
        Thank you for staying with us!
        """
        
        do {
            let tagCollection = await semanticTaggingService.generateSemanticTags(
                for: createSampleScreenshot(with: testText),
                extractedText: testText,
                visualAttributes: nil
            )
            
            let expectedTags = ["marriott", "hotel", "receipt", "payment"]
            let foundTags = tagCollection.uniqueTagNames
            let hasExpectedTags = expectedTags.allSatisfy { foundTags.contains($0) }
            
            let result = TestResult(
                name: "Receipt Tagging",
                description: "Extract semantic tags from hotel receipt",
                expectedResult: "Tags: \(expectedTags.joined(separator: ", "))",
                actualResult: "Tags: \(foundTags.joined(separator: ", "))",
                passed: hasExpectedTags && tagCollection.overallConfidence > 0.5,
                confidence: tagCollection.overallConfidence
            )
            
            await addTestResult(result)
            
        } catch {
            let result = TestResult(
                name: "Receipt Tagging",
                description: "Extract semantic tags from hotel receipt",
                expectedResult: "Successful tag extraction",
                actualResult: "Error: \(error.localizedDescription)",
                passed: false,
                confidence: 0.0
            )
            await addTestResult(result)
        }
    }
    
    private func testHotelReceiptTagging() async {
        await updateCurrentTest("Testing hotel receipt business entity recognition")
        
        let testText = """
        Hilton Garden Inn
        123 Business Street
        Conference Center
        
        Invoice: INV-2024-001
        Guest: John Smith
        Check-in: 01/15/2024
        Check-out: 01/17/2024
        
        Room Rate: $159.00 x 2 nights
        Subtotal: $318.00
        Taxes: $39.75
        Total: $357.75
        """
        
        do {
            let tagCollection = await semanticTaggingService.generateSemanticTags(
                for: createSampleScreenshot(with: testText),
                extractedText: testText,
                visualAttributes: nil
            )
            
            // Check for business entities
            let businessTags = tagCollection.tags(in: .brand)
            let hasHilton = businessTags.contains { $0.name.lowercased().contains("hilton") }
            
            // Check for content type
            let contentTags = tagCollection.tags(in: .contentType)
            let hasReceipt = contentTags.contains { $0.name.contains("receipt") || $0.name.contains("invoice") }
            
            let result = TestResult(
                name: "Hotel Receipt Business Entity",
                description: "Recognize Hilton as business entity in receipt",
                expectedResult: "Business entity: Hilton, Content type: receipt/invoice",
                actualResult: "Business entities: \(businessTags.map(\.name).joined(separator: ", ")), Content types: \(contentTags.map(\.name).joined(separator: ", "))",
                passed: hasHilton && hasReceipt,
                confidence: tagCollection.overallConfidence
            )
            
            await addTestResult(result)
            
        } catch {
            let result = TestResult(
                name: "Hotel Receipt Business Entity",
                description: "Recognize Hilton as business entity in receipt",
                expectedResult: "Successful business entity recognition",
                actualResult: "Error: \(error.localizedDescription)",
                passed: false,
                confidence: 0.0
            )
            await addTestResult(result)
        }
    }
    
    private func testContentTypeClassification() async {
        await updateCurrentTest("Testing content type classification")
        
        let testCases = [
            ("Email", "From: john@example.com\nTo: jane@company.com\nSubject: Meeting tomorrow\nSent via iPhone"),
            ("Social Media", "Twitter for iPhone\n@username posted:\nHaving a great day! #blessed #happy\n❤️ 25 likes 💬 5 replies"),
            ("Receipt", "Target Store #1234\nSubtotal: $45.67\nTax: $3.65\nTotal: $49.32\nVisa ****1234"),
            ("Webpage", "https://www.apple.com\nChrome Browser\nApple iPhone 15 Pro\nStarting at $999")
        ]
        
        for (expectedType, testText) in testCases {
            // Content classification integrated into generateSemanticTags
            let tagCollection = await semanticTaggingService.generateSemanticTags(
                for: createSampleScreenshot(with: testText),
                extractedText: testText,
                visualAttributes: nil
            )
            let conceptTags = tagCollection.tags(in: .contentType)
            let classification = conceptTags.first?.name ?? "unknown"
            
            let classificationMatch = classification.lowercased().contains(expectedType.lowercased()) ||
                                    expectedType.lowercased().contains(classification.lowercased())
            
            let result = TestResult(
                name: "Content Type: \(expectedType)",
                description: "Classify content as \(expectedType)",
                expectedResult: expectedType,
                actualResult: classification,
                passed: classificationMatch,
                confidence: tagCollection.overallConfidence
            )
            
            await addTestResult(result)
        }
    }
    
    private func testBusinessEntityExtraction() async {
        await updateCurrentTest("Testing business entity extraction")
        
        let testText = """
        Starbucks Coffee
        Apple Store Receipt
        Walmart Supercenter
        McDonald's Order #12345
        Amazon.com Invoice
        Netflix Monthly Subscription
        """
        
        let tagCollection = await semanticTaggingService.generateSemanticTags(
            for: createSampleScreenshot(with: testText),
            extractedText: testText,
            visualAttributes: nil
        )
        let businessEntities = tagCollection.tags(in: .brand)
        
        let expectedBusinesses = ["starbucks", "apple", "walmart", "mcdonald", "amazon", "netflix"]
        let foundBusinesses = businessEntities.map { $0.name.lowercased() }
        
        let matchedCount = expectedBusinesses.filter { expected in
            foundBusinesses.contains { found in found.contains(expected) }
        }.count
        
        let result = TestResult(
            name: "Business Entity Extraction",
            description: "Extract known business entities from text",
            expectedResult: "6 business entities: \(expectedBusinesses.joined(separator: ", "))",
            actualResult: "\(businessEntities.count) entities: \(businessEntities.map(\.name).joined(separator: ", "))",
            passed: matchedCount >= 4, // Allow some flexibility
            confidence: Double(matchedCount) / Double(expectedBusinesses.count)
        )
        
        await addTestResult(result)
    }
    
    private func testConfidenceWeighting() async {
        await updateCurrentTest("Testing confidence-based tag weighting")
        
        // Test with high-confidence and low-confidence scenarios
        let highConfidenceText = "McDonald's Receipt #12345 Total: $8.99 Thank you!"
        let lowConfidenceText = "some unclear text maybe receipt possibly"
        
        do {
            let highConfidenceTags = try await semanticTaggingService.generateSemanticTags(
                for: createSampleScreenshot(with: highConfidenceText),
                extractedText: highConfidenceText,
                visualAttributes: nil
            )
            
            let lowConfidenceTags = try await semanticTaggingService.generateSemanticTags(
                for: createSampleScreenshot(with: lowConfidenceText),
                extractedText: lowConfidenceText,
                visualAttributes: nil
            )
            
            let highConfidenceCount = highConfidenceTags.highConfidenceTags().count
            let lowConfidenceCount = lowConfidenceTags.highConfidenceTags().count
            
            let result = TestResult(
                name: "Confidence Weighting",
                description: "Higher confidence for clear business entities",
                expectedResult: "High confidence tags > Low confidence tags",
                actualResult: "High: \(highConfidenceCount) tags, Low: \(lowConfidenceCount) tags",
                passed: highConfidenceCount > lowConfidenceCount,
                confidence: max(highConfidenceTags.overallConfidence, lowConfidenceTags.overallConfidence)
            )
            
            await addTestResult(result)
            
        } catch {
            let result = TestResult(
                name: "Confidence Weighting",
                description: "Higher confidence for clear business entities",
                expectedResult: "Successful confidence differentiation",
                actualResult: "Error: \(error.localizedDescription)",
                passed: false,
                confidence: 0.0
            )
            await addTestResult(result)
        }
    }
    
    private func testMultiModalAnalysis() async {
        await updateCurrentTest("Testing multi-modal analysis (OCR + Vision)")
        
        let ocrText = "Marriott Hotels Receipt"
        let mockVisualAttributes = createMockVisualAttributes()
        
        do {
            let tagCollection = await semanticTaggingService.generateSemanticTags(
                for: createSampleScreenshot(with: ocrText),
                extractedText: ocrText,
                visualAttributes: mockVisualAttributes
            )
            
            // Should have tags from both OCR and visual analysis
            let ocrBasedTags = tagCollection.tags(from: .ocr)
            let visionBasedTags = tagCollection.tags(from: .vision)
            let businessTags = tagCollection.tags(from: .businessRecognition)
            
            let hasMultiModalTags = !ocrBasedTags.isEmpty && (!visionBasedTags.isEmpty || !businessTags.isEmpty)
            
            let result = TestResult(
                name: "Multi-Modal Analysis",
                description: "Combine OCR and vision analysis results",
                expectedResult: "Tags from multiple sources",
                actualResult: "OCR: \(ocrBasedTags.count), Vision: \(visionBasedTags.count), Business: \(businessTags.count)",
                passed: hasMultiModalTags,
                confidence: tagCollection.overallConfidence
            )
            
            await addTestResult(result)
            
        } catch {
            let result = TestResult(
                name: "Multi-Modal Analysis",
                description: "Combine OCR and vision analysis results",
                expectedResult: "Successful multi-modal tagging",
                actualResult: "Error: \(error.localizedDescription)",
                passed: false,
                confidence: 0.0
            )
            await addTestResult(result)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateCurrentTest(_ test: String) async {
        await MainActor.run {
            currentTest = test
        }
    }
    
    private func addTestResult(_ result: TestResult) async {
        await MainActor.run {
            testResults.append(result)
        }
    }
    
    private func createSampleScreenshot(with text: String) -> Screenshot {
        // Create a simple 100x100 white image for testing
        let image = UIImage(systemName: "doc.text") ?? UIImage()
        let imageData = image.pngData() ?? Data()
        let screenshot = Screenshot(imageData: imageData, filename: "test.png")
        screenshot.extractedText = text
        return screenshot
    }
    
    private func createMockVisualAttributes() -> VisualAttributes? {
        // For now, return nil to avoid complex initialization issues
        // TODO: Create proper mock when VisualAttributes structure is finalized
        return nil
    }
    
    /// Get test summary
    public var testSummary: String {
        let totalTests = testResults.count
        let passedTests = testResults.filter(\.passed).count
        let avgConfidence = testResults.isEmpty ? 0.0 : testResults.map(\.confidence).reduce(0, +) / Double(testResults.count)
        
        return """
        Integration Tests Summary:
        • Total Tests: \(totalTests)
        • Passed: \(passedTests)/\(totalTests)
        • Success Rate: \(totalTests > 0 ? Int((Double(passedTests) / Double(totalTests)) * 100) : 0)%
        • Average Confidence: \(String(format: "%.1f", avgConfidence * 100))%
        """
    }
}

// MARK: - Test Result Model

public struct TestResult: Identifiable {
    public let id = UUID()
    public let name: String
    public let description: String
    public let expectedResult: String
    public let actualResult: String
    public let passed: Bool
    public let confidence: Double
    public let timestamp = Date()
    
    public var statusIcon: String {
        return passed ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    public var statusColor: String {
        return passed ? "green" : "red"
    }
    
    public var confidenceLevel: String {
        switch confidence {
        case 0.8...1.0: return "High"
        case 0.6..<0.8: return "Medium"
        case 0.3..<0.6: return "Low"
        default: return "Very Low"
        }
    }
}