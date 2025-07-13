import Foundation
import XCTest
@testable import ScreenshotNotes

/// Integration tests for Sprint 7.1.3 Entity Recognition Service
/// Tests business card screenshot entity extraction and content understanding
class EntityRecognitionIntegrationTests: XCTestCase {
    
    private var entityRecognitionService: EntityRecognitionService!
    
    override func setUpWithError() throws {
        entityRecognitionService = EntityRecognitionService()
    }
    
    override func tearDownWithError() throws {
        entityRecognitionService = nil
    }
    
    // MARK: - Business Card Entity Extraction Tests
    
    /// Integration Test: Business card screenshot → extract entities:[person, company, phone, email, address]
    func testBusinessCardEntityExtraction() async throws {
        // Simulate OCR text from a business card screenshot
        let businessCardText = """
        John Smith
        Senior Software Engineer
        Apple Inc.
        One Apple Park Way
        Cupertino, CA 95014
        Phone: (408) 996-1010
        Email: john.smith@apple.com
        www.apple.com
        """
        
        // Perform content analysis
        let result = await entityRecognitionService.analyzeContent(from: businessCardText)
        
        // Assert successful processing
        XCTAssertTrue(result.isSuccessful, "Business card analysis should be successful")
        XCTAssertGreaterThanOrEqual(result.overallAccuracy, 0.85, "Overall accuracy should be ≥85%")
        XCTAssertEqual(result.contentType, .document, "Content should be classified as document")
        XCTAssertGreaterThan(result.contentTypeConfidence, 0.7, "Content type confidence should be high")
        
        // Assert personal entities extraction
        let personalEntities = result.personalEntities
        XCTAssertGreaterThanOrEqual(personalEntities.count, 4, "Should extract at least 4 personal entities")
        
        // Verify contact entity (person)
        let contactEntities = personalEntities.filter { $0.type == .contact }
        XCTAssertGreaterThanOrEqual(contactEntities.count, 1, "Should extract at least one contact")
        
        // Verify phone number entity
        let phoneEntities = personalEntities.filter { $0.type == .phoneNumber }
        XCTAssertGreaterThanOrEqual(phoneEntities.count, 1, "Should extract phone number")
        if let phoneEntity = phoneEntities.first {
            XCTAssertTrue(phoneEntity.value.contains("408"), "Should extract correct phone number")
            XCTAssertGreaterThanOrEqual(phoneEntity.confidence, 0.85, "Phone confidence should be high")
        }
        
        // Verify email entity
        let emailEntities = personalEntities.filter { $0.type == .email }
        XCTAssertGreaterThanOrEqual(emailEntities.count, 1, "Should extract email address")
        if let emailEntity = emailEntities.first {
            XCTAssertTrue(emailEntity.value.contains("@apple.com"), "Should extract correct email")
            XCTAssertEqual(emailEntity.label, "business", "Should classify as business email")
            XCTAssertGreaterThanOrEqual(emailEntity.confidence, 0.85, "Email confidence should be high")
        }
        
        // Verify address entity
        let addressEntities = personalEntities.filter { $0.type == .address }
        XCTAssertGreaterThanOrEqual(addressEntities.count, 1, "Should extract address information")
        
        // Assert business entities extraction
        let businessEntities = result.businessEntities
        XCTAssertGreaterThanOrEqual(businessEntities.count, 2, "Should extract at least 2 business entities")
        
        // Verify organization entity
        let organizationEntities = businessEntities.filter { $0.type == .organization }
        XCTAssertGreaterThanOrEqual(organizationEntities.count, 1, "Should extract organization")
        
        // Verify brand entity
        let brandEntities = businessEntities.filter { $0.type == .brand }
        XCTAssertGreaterThanOrEqual(brandEntities.count, 1, "Should extract Apple brand")
        if let appleEntity = brandEntities.first(where: { $0.name.lowercased().contains("apple") }) {
            XCTAssertEqual(appleEntity.category, "technology", "Apple should be categorized as technology")
            XCTAssertGreaterThanOrEqual(appleEntity.confidence, 0.7, "Brand confidence should be high")
        }
        
        // Assert entity relationships
        let relationships = result.entityRelationships
        XCTAssertGreaterThanOrEqual(relationships.count, 1, "Should find entity relationships")
        
        // Verify employment relationship
        let employmentRelationships = relationships.filter { $0.relationshipType == .employment }
        XCTAssertGreaterThanOrEqual(employmentRelationships.count, 1, "Should find employment relationship")
        
        print("✅ Business card test passed - extracted \(personalEntities.count) personal and \(businessEntities.count) business entities")
    }
    
    // MARK: - Content Type Classification Tests
    
    func testReceiptContentClassification() async throws {
        let receiptText = """
        Target Store #1234
        123 Main Street
        Anytown, CA 90210
        
        Date: 12/15/2023
        Time: 2:30 PM
        
        Items:
        Milk - $3.99
        Bread - $2.49
        Eggs - $4.29
        
        Subtotal: $10.77
        Tax: $0.86
        Total: $11.63
        
        Payment: Credit Card
        Thank you for shopping!
        """
        
        let result = await entityRecognitionService.analyzeContent(from: receiptText)
        
        XCTAssertTrue(result.isSuccessful, "Receipt analysis should be successful")
        XCTAssertEqual(result.contentType, .receipt, "Should classify as receipt")
        XCTAssertGreaterThan(result.contentTypeConfidence, 0.8, "Receipt confidence should be high")
        
        // Verify business entities
        let businessEntities = result.businessEntities
        let brandEntities = businessEntities.filter { $0.type == .brand }
        XCTAssertTrue(brandEntities.contains { $0.name.lowercased().contains("target") }, "Should identify Target brand")
        
        print("✅ Receipt classification test passed")
    }
    
    func testFormContentClassification() async throws {
        let formText = """
        Application Form
        
        Personal Information (Required*)
        
        First Name*: ________________
        Last Name*: _________________
        Email Address*: _____________
        Phone Number: _______________
        
        Address Information
        Street Address: _____________
        City: ______________________
        State: _____________________
        ZIP Code: __________________
        
        Please check all that apply:
        ☐ I agree to terms and conditions
        ☐ I want to receive email updates
        ☐ I am over 18 years old
        
        Submit Application
        """
        
        let result = await entityRecognitionService.analyzeContent(from: formText)
        
        XCTAssertTrue(result.isSuccessful, "Form analysis should be successful")
        XCTAssertEqual(result.contentType, .form, "Should classify as form")
        XCTAssertGreaterThan(result.contentTypeConfidence, 0.7, "Form confidence should be high")
        
        print("✅ Form classification test passed")
    }
    
    func testSocialPostContentClassification() async throws {
        let socialPostText = """
        @johndoe posted 2 hours ago
        
        Just had an amazing coffee at @starbucks! ☕️ The new winter blend is incredible. 
        Who else has tried it? #coffee #starbucks #winterblend
        
        👍 24 likes    💬 5 comments    🔄 2 shares
        
        @janedoe: I love that blend too!
        @coffeelover: Need to try this ASAP
        """
        
        let result = await entityRecognitionService.analyzeContent(from: socialPostText)
        
        XCTAssertTrue(result.isSuccessful, "Social post analysis should be successful")
        XCTAssertEqual(result.contentType, .socialPost, "Should classify as social post")
        XCTAssertGreaterThan(result.contentTypeConfidence, 0.7, "Social post confidence should be high")
        
        // Verify brand recognition
        let businessEntities = result.businessEntities
        let brandEntities = businessEntities.filter { $0.type == .brand }
        XCTAssertTrue(brandEntities.contains { $0.name.lowercased().contains("starbucks") }, "Should identify Starbucks brand")
        
        print("✅ Social post classification test passed")
    }
    
    // MARK: - Business Entity Recognition Tests
    
    func testBrandRecognition() async throws {
        let brandText = """
        Shopping List:
        - iPhone 15 Pro from Apple
        - Galaxy S24 from Samsung
        - MacBook Pro
        - Google Pixel 8
        - Microsoft Surface
        """
        
        let result = await entityRecognitionService.analyzeContent(from: brandText)
        
        XCTAssertTrue(result.isSuccessful, "Brand recognition should be successful")
        
        let brandEntities = result.businessEntities.filter { $0.type == .brand }
        XCTAssertGreaterThanOrEqual(brandEntities.count, 4, "Should recognize multiple brands")
        
        let brandNames = Set(brandEntities.map { $0.name.lowercased() })
        XCTAssertTrue(brandNames.contains("apple"), "Should recognize Apple")
        XCTAssertTrue(brandNames.contains("samsung"), "Should recognize Samsung")
        XCTAssertTrue(brandNames.contains("google"), "Should recognize Google")
        XCTAssertTrue(brandNames.contains("microsoft"), "Should recognize Microsoft")
        
        print("✅ Brand recognition test passed - found \(brandEntities.count) brands")
    }
    
    func testProductRecognition() async throws {
        let productText = """
        Need to buy:
        - New laptop for work
        - Running shoes for exercise
        - Coffee maker for kitchen
        - Smartphone upgrade
        - Fitness watch
        """
        
        let result = await entityRecognitionService.analyzeContent(from: productText)
        
        let productEntities = result.businessEntities.filter { $0.type == .product }
        XCTAssertGreaterThanOrEqual(productEntities.count, 3, "Should recognize multiple products")
        
        let productNames = Set(productEntities.map { $0.name.lowercased() })
        XCTAssertTrue(productNames.contains("laptop") || productNames.contains("computer"), "Should recognize laptop/computer")
        XCTAssertTrue(productNames.contains("shoes"), "Should recognize shoes")
        XCTAssertTrue(productNames.contains("phone") || productNames.contains("smartphone"), "Should recognize phone")
        
        print("✅ Product recognition test passed - found \(productEntities.count) products")
    }
    
    func testServiceRecognition() async throws {
        let serviceText = """
        Appointments this week:
        - Dental cleaning at 2 PM
        - Car maintenance appointment
        - Legal consultation
        - Fitness training session
        - Healthcare checkup
        """
        
        let result = await entityRecognitionService.analyzeContent(from: serviceText)
        
        let serviceEntities = result.businessEntities.filter { $0.type == .service }
        XCTAssertGreaterThanOrEqual(serviceEntities.count, 3, "Should recognize multiple services")
        
        let serviceNames = Set(serviceEntities.map { $0.name.lowercased() })
        XCTAssertTrue(serviceNames.contains("dental") || serviceNames.contains("healthcare"), "Should recognize healthcare services")
        XCTAssertTrue(serviceNames.contains("legal"), "Should recognize legal service")
        XCTAssertTrue(serviceNames.contains("fitness") || serviceNames.contains("training"), "Should recognize fitness service")
        
        print("✅ Service recognition test passed - found \(serviceEntities.count) services")
    }
    
    // MARK: - Personal Entity Detection Tests
    
    func testContactDetection() async throws {
        let contactText = """
        Contact Information:
        
        Primary Contact: Sarah Johnson
        Secondary Contact: Mike Chen
        Emergency Contact: Dr. Lisa Williams
        
        Phone Numbers:
        Sarah: (555) 123-4567
        Mike: (555) 987-6543
        
        Emails:
        sarah.johnson@company.com
        mike.chen@business.org
        """
        
        let result = await entityRecognitionService.analyzeContent(from: contactText)
        
        XCTAssertTrue(result.isSuccessful, "Contact detection should be successful")
        
        let personalEntities = result.personalEntities
        
        // Verify contact entities
        let contactEntities = personalEntities.filter { $0.type == .contact }
        XCTAssertGreaterThanOrEqual(contactEntities.count, 2, "Should detect multiple contacts")
        
        // Verify phone number entities
        let phoneEntities = personalEntities.filter { $0.type == .phoneNumber }
        XCTAssertGreaterThanOrEqual(phoneEntities.count, 2, "Should detect multiple phone numbers")
        
        // Verify email entities
        let emailEntities = personalEntities.filter { $0.type == .email }
        XCTAssertGreaterThanOrEqual(emailEntities.count, 2, "Should detect multiple emails")
        
        print("✅ Contact detection test passed - found \(contactEntities.count) contacts, \(phoneEntities.count) phones, \(emailEntities.count) emails")
    }
    
    func testAddressDetection() async throws {
        let addressText = """
        Shipping Addresses:
        
        Home: 123 Main Street, Anytown, CA 90210
        Work: 456 Business Ave, Suite 100, Corporate City, NY 10001
        
        Billing Address:
        789 Residential Blvd
        Hometown, TX 75001
        """
        
        let result = await entityRecognitionService.analyzeContent(from: addressText)
        
        let addressEntities = result.personalEntities.filter { $0.type == .address }
        XCTAssertGreaterThanOrEqual(addressEntities.count, 2, "Should detect multiple address components")
        
        // Check for street addresses and ZIP codes
        let streetAddresses = addressEntities.filter { $0.label == "street_address" }
        let zipCodes = addressEntities.filter { $0.label == "zip_code" }
        
        XCTAssertGreaterThanOrEqual(streetAddresses.count, 1, "Should detect street addresses")
        XCTAssertGreaterThanOrEqual(zipCodes.count, 2, "Should detect ZIP codes")
        
        print("✅ Address detection test passed - found \(addressEntities.count) address components")
    }
    
    // MARK: - Entity Relationship Mapping Tests
    
    func testEntityRelationshipMapping() async throws {
        let relationshipText = """
        John Smith
        Senior Developer
        Tech Solutions Inc.
        123 Tech Park Drive
        Silicon Valley, CA 94301
        john.smith@techsolutions.com
        (650) 555-0123
        """
        
        let result = await entityRecognitionService.analyzeContent(from: relationshipText)
        
        XCTAssertTrue(result.isSuccessful, "Relationship mapping should be successful")
        
        let relationships = result.entityRelationships
        XCTAssertGreaterThanOrEqual(relationships.count, 1, "Should find entity relationships")
        
        // Check for employment relationships
        let employmentRelationships = relationships.filter { $0.relationshipType == .employment }
        XCTAssertGreaterThanOrEqual(employmentRelationships.count, 1, "Should find employment relationship")
        
        if let employment = employmentRelationships.first {
            XCTAssertEqual(employment.sourceType, .personal, "Employment should link personal to business")
            XCTAssertEqual(employment.targetType, .business, "Employment should link personal to business")
            XCTAssertGreaterThan(employment.confidence, 0.5, "Employment confidence should be reasonable")
        }
        
        print("✅ Entity relationship mapping test passed - found \(relationships.count) relationships")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceRequirements() async throws {
        let complexText = """
        Business Meeting Minutes
        Date: December 15, 2023
        
        Attendees:
        - John Smith, CEO, Apple Inc. (john.smith@apple.com, 408-996-1010)
        - Sarah Johnson, CTO, Google LLC (sarah@google.com, 650-253-0000)
        - Mike Chen, Director, Microsoft Corp (mike.chen@microsoft.com, 425-882-8080)
        
        Address: One Apple Park Way, Cupertino, CA 95014
        
        Discussion Topics:
        1. iPhone 15 Pro development timeline
        2. Google Pixel integration challenges
        3. Microsoft Office compatibility
        
        Action Items:
        - Contact suppliers for laptop components
        - Schedule fitness training for development team
        - Book conference room at Marriott Hotel
        - Order coffee for next meeting from Starbucks
        
        Next Meeting: January 10, 2024 at 456 Innovation Drive, Palo Alto, CA 94301
        """
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = await entityRecognitionService.analyzeContent(from: complexText)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Performance requirements
        XCTAssertLessThan(processingTime, 10.0, "Processing should complete within 10 seconds")
        XCTAssertGreaterThanOrEqual(result.overallAccuracy, 0.85, "Accuracy should be ≥85%")
        XCTAssertTrue(result.isSuccessful, "Complex text analysis should be successful")
        
        // Verify comprehensive entity extraction
        XCTAssertGreaterThanOrEqual(result.businessEntities.count, 5, "Should extract multiple business entities")
        XCTAssertGreaterThanOrEqual(result.personalEntities.count, 8, "Should extract multiple personal entities")
        XCTAssertGreaterThanOrEqual(result.entityRelationships.count, 2, "Should find multiple relationships")
        
        print("✅ Performance test passed - processed in \(String(format: "%.2f", processingTime))s with \(String(format: "%.1f", result.overallAccuracy * 100))% accuracy")
    }
    
    // MARK: - Edge Case Tests
    
    func testMultiLanguageSupport() async throws {
        let multiLanguageText = """
        Contact: José García
        Empresa: Tecnología Avanzada S.A.
        Teléfono: +34 91 123 4567
        Email: jose.garcia@empresa.es
        Dirección: Calle Mayor 123, Madrid, España
        """
        
        let result = await entityRecognitionService.analyzeContent(from: multiLanguageText)
        
        // Should handle Spanish text gracefully
        XCTAssertTrue(result.isSuccessful || result.personalEntities.count > 0, "Should handle Spanish text")
        
        print("✅ Multi-language test passed")
    }
    
    func testEmptyAndInvalidInput() async throws {
        // Test empty input
        let emptyResult = await entityRecognitionService.analyzeContent(from: "")
        XCTAssertFalse(emptyResult.isSuccessful, "Empty input should not be successful")
        XCTAssertEqual(emptyResult.businessEntities.count, 0, "Empty input should have no entities")
        XCTAssertEqual(emptyResult.personalEntities.count, 0, "Empty input should have no entities")
        
        // Test minimal input
        let minimalResult = await entityRecognitionService.analyzeContent(from: "Hi")
        XCTAssertEqual(minimalResult.contentType, .unknown, "Minimal input should be unknown type")
        
        print("✅ Edge case tests passed")
    }
}

// MARK: - Test Utilities

extension EntityRecognitionIntegrationTests {
    
    /// Helper method to print detailed test results
    private func printDetailedResults(_ result: ContentAnalysisResult, testName: String) {
        print("🔍 \(testName) Results:")
        print("   Overall Accuracy: \(String(format: "%.1f", result.overallAccuracy * 100))%")
        print("   Content Type: \(result.contentType.rawValue) (confidence: \(String(format: "%.1f", result.contentTypeConfidence * 100))%)")
        print("   Business Entities: \(result.businessEntities.count)")
        print("   Personal Entities: \(result.personalEntities.count)")
        print("   Relationships: \(result.entityRelationships.count)")
        print("   Processing Time: \(String(format: "%.1f", result.processingTimeMs))ms")
        print("")
    }
}