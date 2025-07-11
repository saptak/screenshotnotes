import SwiftUI
import SwiftData
import AppIntents

@main
struct ScreenshotNotesApp: App {
    @StateObject private var photoLibraryService = PhotoLibraryService()
    @StateObject private var backgroundOCRProcessor = BackgroundOCRProcessor()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Screenshot.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
            // Fallback to in-memory container for emergency operation
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                print("❌ Critical: Failed to create fallback ModelContainer: \(error)")
                // Last resort: create minimal container
                return try! ModelContainer(for: schema)
            }
        }
    }()

    init() {
        // Register background tasks
        BackgroundTaskService.shared.registerBackgroundTasks()
        
        // Register App Intents for Siri integration
        if #available(iOS 16.0, *) {
            ScreenshotNotesShortcuts.updateAppShortcutParameters()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoLibraryService)
                .environmentObject(backgroundOCRProcessor)
                .onAppear {
                    photoLibraryService.setModelContext(sharedModelContainer.mainContext)
                    
                    // Sync settings between services
                    let settingsService = SettingsService.shared
                    if settingsService.automaticImportEnabled != photoLibraryService.automaticImportEnabled {
                        photoLibraryService.setAutomaticImportEnabled(settingsService.automaticImportEnabled)
                    }
                    
                    // Start monitoring if permissions are already granted and automatic import is enabled
                    if photoLibraryService.authorizationStatus == .authorized && photoLibraryService.automaticImportEnabled {
                        photoLibraryService.startMonitoring()
                    }
                    
                    // Start background OCR processing for existing screenshots
                    backgroundOCRProcessor.startBackgroundProcessingIfNeeded(in: sharedModelContainer.mainContext)
                    
                    // Schedule background refresh
                    BackgroundTaskService.shared.scheduleAppRefresh()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
