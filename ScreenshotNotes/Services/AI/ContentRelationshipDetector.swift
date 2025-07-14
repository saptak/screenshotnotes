import Foundation
import SwiftData
import os.log

/// Background detector for content relationships between screenshots (Enhanced Interface only)
/// Runs in the background and stores detected relationships for future use (no UI changes)
@MainActor
class ContentRelationshipDetector: ObservableObject {
    static let shared = ContentRelationshipDetector()
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "ContentRelationshipDetector")
    private let relationshipService = EntityRelationshipService.shared
    @Published private(set) var detectedRelationships: [Relationship] = []
    private var lastDetectionDate: Date?
    private var isDetecting = false
    private init() {}

    /// Public API: Trigger background detection (safe to call multiple times)
    func detectRelationships(in screenshots: [Screenshot]) async {
        guard !isDetecting else {
            logger.info("Detection already in progress, skipping duplicate trigger")
            return
        }
        isDetecting = true
        logger.info("🔎 Starting background content relationship detection ( (screenshots.count) screenshots)")
        let relationships = await relationshipService.discoverRelationships(screenshots: screenshots)
        await MainActor.run {
            self.detectedRelationships = relationships
            self.lastDetectionDate = Date()
            self.isDetecting = false
        }
        logger.info("✅ Content relationship detection complete ( (relationships.count) relationships found)")
    }

    /// Accessor for detected relationships (for future use)
    func getRelationships() -> [Relationship] {
        return detectedRelationships
    }

    /// For future: clear cache or force re-detection
    func clearRelationships() {
        detectedRelationships = []
        lastDetectionDate = nil
    }
} 