//
//  AppShortcuts.swift
//  ScreenshotNotes
//
//  Sprint 5.3.2: Siri App Intents Foundation
//  Created by Assistant on 7/5/25.
//

import AppIntents

/// App Shortcuts provider for Siri integration
@available(iOS 16.0, *)
struct ScreenshotNotesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchScreenshotsIntent(),
            phrases: [
                "Search \(.applicationName)",
                "Search \(.applicationName) for screenshots",
                "Find screenshots in \(.applicationName)",
                "Open \(.applicationName) search",
                "Search my screenshots in \(.applicationName)",
                "Look for screenshots in \(.applicationName)",
                "Find my screenshots in \(.applicationName)",
                "Search Screenshot Vault in \(.applicationName)",
                "Open search in \(.applicationName)",
                "Search photos in \(.applicationName)"
            ],
            shortTitle: "Search Screenshots",
            systemImageName: "magnifyingglass"
        )
    }
    
    static var shortcutTileColor: ShortcutTileColor = .blue
}
