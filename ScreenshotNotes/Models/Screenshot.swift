import Foundation
import SwiftData

@Model
public final class Screenshot {
    @Attribute(.unique) public var id: UUID
    public var imageData: Data
    public var timestamp: Date
    public var filename: String
    public var extractedText: String?
    public var objectTags: [String]?
    public var userNotes: String?
    public var userTags: [String]?
    public var assetIdentifier: String?
    
    public init(imageData: Data, filename: String, timestamp: Date? = nil, assetIdentifier: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.timestamp = timestamp ?? Date()
        self.filename = filename
        self.extractedText = nil
        self.objectTags = nil
        self.userNotes = nil
        self.userTags = nil
        self.assetIdentifier = assetIdentifier
    }
}
