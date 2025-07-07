import Foundation
import SwiftUI
import NaturalLanguage

/// Service for consistent text display behavior across the app
@MainActor
final class SmartTextDisplayService: ObservableObject {
    static let shared = SmartTextDisplayService()
    
    private let entityService = EntityExtractionService()
    private var entityCache: [String: [SmartTextEntity]] = [:]
    private let hapticService = HapticService.shared
    
    private init() {}
    
    // MARK: - Entity Processing
    
    /// Extract and format entities for smart text display
    func processText(_ text: String) async -> SmartTextResult {
        // Check cache first
        if let cached = entityCache[text] {
            return SmartTextResult(
                originalText: text,
                entities: cached,
                processingTime: 0,
                isFromCache: true
            )
        }
        
        let startTime = Date()
        
        // Extract entities using the existing service
        let entityResult = await entityService.extractEntities(from: text)
        
        // Convert to our unified format and deduplicate
        var seenTexts = Set<String>()
        let smartEntities = entityResult.entities.compactMap { entity -> SmartTextEntity? in
            guard entity.text.count >= 3 else { return nil } // Filter very short entities
            
            // Normalize text for deduplication (case-insensitive, trimmed)
            let normalizedText = entity.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !seenTexts.contains(normalizedText) else { return nil }
            seenTexts.insert(normalizedText)
            
            return SmartTextEntity(
                id: UUID(),
                text: entity.text,
                type: mapEntityType(entity.type),
                confidence: entity.confidence.rawValue,
                range: findRange(of: entity.text, in: text),
                actionable: isActionable(entity.type)
            )
        }
        
        // Cache results
        entityCache[text] = smartEntities
        
        // Clean cache if it gets too large
        if entityCache.count > 20 {
            let oldestKey = entityCache.keys.randomElement()
            if let key = oldestKey {
                entityCache.removeValue(forKey: key)
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return SmartTextResult(
            originalText: text,
            entities: smartEntities,
            processingTime: processingTime,
            isFromCache: false
        )
    }
    
    /// Perform action for an entity (copy, open URL, etc.)
    func performAction(for entity: SmartTextEntity) {
        switch entity.type {
        case .url:
            if let url = URL(string: entity.text) {
                UIApplication.shared.open(url)
                hapticService.impact(.medium)
            } else {
                copyToClipboard(entity.text)
            }
        case .phoneNumber:
            if let url = URL(string: "tel:\(entity.text.filter { $0.isNumber })") {
                UIApplication.shared.open(url)
                hapticService.impact(.medium)
            } else {
                copyToClipboard(entity.text)
            }
        case .email:
            if let url = URL(string: "mailto:\(entity.text)") {
                UIApplication.shared.open(url)
                hapticService.impact(.medium)
            } else {
                copyToClipboard(entity.text)
            }
        default:
            copyToClipboard(entity.text)
        }
    }
    
    // MARK: - Private Helpers
    
    private func mapEntityType(_ type: EntityType) -> SmartTextEntity.EntityType {
        switch type {
        case .url: return .url
        case .phoneNumber: return .phoneNumber
        case .email: return .email
        case .date: return .date
        case .currency: return .currency
        case .person: return .person
        case .organization: return .organization
        case .place: return .address
        case .object: return .object
        case .color: return .color
        case .documentType: return .documentType
        case .time: return .time
        case .number: return .quantity
        case .businessType: return .organization
        default: return .object
        }
    }
    
    private func isActionable(_ type: EntityType) -> Bool {
        switch type {
        case .url, .phoneNumber, .email, .place:
            return true
        default:
            return false
        }
    }
    
    private func findRange(of text: String, in fullText: String) -> NSRange {
        return (fullText as NSString).range(of: text)
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        hapticService.impact(.light)
    }
}

// MARK: - Supporting Types

struct SmartTextResult {
    let originalText: String
    let entities: [SmartTextEntity]
    let processingTime: TimeInterval
    let isFromCache: Bool
    
    var hasEntities: Bool {
        !entities.isEmpty
    }
    
    var actionableEntities: [SmartTextEntity] {
        entities.filter { $0.actionable }
    }
    
    var displayEntities: [SmartTextEntity] {
        entities.filter { $0.text.count >= 4 } // Only show meaningful entities
    }
}

struct SmartTextEntity: Identifiable, Hashable {
    let id: UUID
    let text: String
    let type: EntityType
    let confidence: Double
    let range: NSRange
    let actionable: Bool
    
    enum EntityType: String, CaseIterable {
        case url = "URL"
        case phoneNumber = "Phone"
        case email = "Email"
        case date = "Date"
        case currency = "Price"
        case person = "Person"
        case organization = "Organization"
        case address = "Address"
        case object = "Object"
        case color = "Color"
        case documentType = "Document"
        case quantity = "Quantity"
        case time = "Time"
        
        var displayName: String {
            return rawValue
        }
        
        var icon: String {
            switch self {
            case .url: return "link"
            case .phoneNumber: return "phone"
            case .email: return "envelope"
            case .date: return "calendar"
            case .currency: return "dollarsign.circle"
            case .person: return "person"
            case .organization: return "building.2"
            case .address: return "location"
            case .object: return "cube"
            case .color: return "paintpalette"
            case .documentType: return "doc"
            case .quantity: return "number"
            case .time: return "clock"
            }
        }
        
        var color: Color {
            switch self {
            case .url: return .blue
            case .phoneNumber: return .green
            case .email: return .purple
            case .date: return .orange
            case .currency: return .pink
            case .person: return .indigo
            case .organization: return .mint
            case .address: return .teal
            case .object: return .brown
            case .color: return .red
            case .documentType: return .gray
            case .quantity: return .secondary
            case .time: return .orange
            }
        }
        
        var actionLabel: String {
            switch self {
            case .url: return "Open"
            case .phoneNumber: return "Call"
            case .email: return "Email"
            case .address: return "Maps"
            default: return "Copy"
            }
        }
    }
}