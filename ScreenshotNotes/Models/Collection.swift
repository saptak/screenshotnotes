import Foundation
import SwiftData
import SwiftUI

@Model
public final class Collection {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var collectionDescription: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var color: String // Store as hex string
    public var icon: String
    public var isFavorite: Bool = false
    public var isSystem: Bool = false // System collections can't be deleted
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \Screenshot.collections)
    public var screenshots: [Screenshot] = []
    
    public init(
        name: String,
        description: String? = nil,
        color: String = "#007AFF",
        icon: String = "folder",
        isSystem: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.collectionDescription = description
        self.createdAt = Date()
        self.updatedAt = Date()
        self.color = color
        self.icon = icon
        self.isFavorite = false
        self.isSystem = isSystem
    }
    
    /// Update the collection's modified date
    public func updateModifiedDate() {
        self.updatedAt = Date()
    }
    
    /// Add screenshot to collection
    public func addScreenshot(_ screenshot: Screenshot) {
        if !screenshots.contains(screenshot) {
            screenshots.append(screenshot)
            updateModifiedDate()
        }
    }
    
    /// Remove screenshot from collection
    public func removeScreenshot(_ screenshot: Screenshot) {
        if let index = screenshots.firstIndex(of: screenshot) {
            screenshots.remove(at: index)
            updateModifiedDate()
        }
    }
    
    /// Check if collection contains screenshot
    public func contains(_ screenshot: Screenshot) -> Bool {
        return screenshots.contains(screenshot)
    }
    
    /// Get screenshot count
    public var screenshotCount: Int {
        return screenshots.count
    }
    
    /// Get color as SwiftUI Color
    public var swiftUIColor: Color {
        return Color(hex: color) ?? .blue
    }
}

// MARK: - System Collections

extension Collection {
    /// Create default system collections
    public static func createSystemCollections() -> [Collection] {
        return [
            Collection(
                name: "Favorites",
                description: "Screenshots you've marked as favorites",
                color: "#FF3B30",
                icon: "heart.fill",
                isSystem: true
            ),
            Collection(
                name: "Recent",
                description: "Recently captured screenshots",
                color: "#34C759",
                icon: "clock.fill",
                isSystem: true
            ),
            Collection(
                name: "Documents",
                description: "Screenshots containing text and documents",
                color: "#007AFF",
                icon: "doc.fill",
                isSystem: true
            ),
            Collection(
                name: "Images",
                description: "Screenshots with photos and visual content",
                color: "#FF9500",
                icon: "photo.fill",
                isSystem: true
            )
        ]
    }
    
    /// Get system collection by name
    public static func systemCollection(named name: String, in context: ModelContext) -> Collection? {
        let descriptor = FetchDescriptor<Collection>(
            predicate: #Predicate { $0.name == name && $0.isSystem == true }
        )
        return try? context.fetch(descriptor).first
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let components = UIColor(self).cgColor.components
        let r = components?[0] ?? 0
        let g = components?[1] ?? 0
        let b = components?[2] ?? 0
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}