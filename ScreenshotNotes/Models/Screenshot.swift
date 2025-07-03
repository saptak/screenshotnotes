import Foundation
import SwiftData

@Model
final class Screenshot {
    @Attribute(.unique) var id: UUID
    var imageData: Data
    var timestamp: Date
    var filename: String
    var extractedText: String?
    var objectTags: [String]?
    var userNotes: String?
    var userTags: [String]?
    
    init(imageData: Data, filename: String) {
        self.id = UUID()
        self.imageData = imageData
        self.timestamp = Date()
        self.filename = filename
        self.extractedText = nil
        self.objectTags = nil
        self.userNotes = nil
        self.userTags = nil
    }
}
