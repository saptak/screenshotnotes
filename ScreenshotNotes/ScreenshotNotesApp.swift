import SwiftUI
import SwiftData
import AppIntents
import UIKit
import os.log

@main
struct ScreenshotNotesApp: App {
    @StateObject private var photoLibraryService = PhotoLibraryService()
    @StateObject private var backgroundOCRProcessor = BackgroundOCRProcessor()
    @State private var modelContainerStatus: ModelContainerStatus = .unknown
    
    private static let logger = Logger(subsystem: "com.screenshotnotes.app", category: "AppInitialization")
    
    enum ModelContainerStatus {
        case unknown
        case persistent
        case inMemory
        case emergency
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Screenshot.self,
            ScreenshotGroup.self,
        ])
        
        // Try primary persistent storage first
        let persistentConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [persistentConfiguration])
            logger.info("✅ Successfully created persistent ModelContainer")
            // Note: We can't set @State from static context, will be handled in init()
            return container
        } catch {
            logger.error("❌ Failed to create persistent ModelContainer: \(error.localizedDescription)")
            
            // Log specific error details for debugging
            if let nsError = error as NSError? {
                logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")
                logger.error("Error userInfo: \(nsError.userInfo)")
            }
            
            // Fallback to in-memory container for emergency operation
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                let container = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                logger.warning("⚠️ Using in-memory ModelContainer as fallback - data will not persist")
                return container
            } catch {
                logger.critical("❌ Critical: Failed to create fallback ModelContainer: \(error.localizedDescription)")
                
                // Last resort: create minimal schema container
                let minimalSchema = Schema([Screenshot.self])
                let emergencyConfiguration = ModelConfiguration(
                    schema: minimalSchema,
                    isStoredInMemoryOnly: true
                )
                
                do {
                    let container = try ModelContainer(for: minimalSchema, configurations: [emergencyConfiguration])
                    logger.warning("⚠️ Using emergency minimal ModelContainer - limited functionality")
                    return container
                } catch {
                    // If even emergency container fails, we have a fundamental SwiftData issue
                    logger.fault("❌ FATAL: Cannot create any ModelContainer. SwiftData initialization failed: \(error.localizedDescription)")
                    
                    // Log system information for debugging
                    logger.fault("Device: \(UIDevice.current.model), iOS: \(UIDevice.current.systemVersion)")
                    
                    // Create a user-friendly error message with actionable steps
                    let errorMessage = """
                    Failed to initialize data storage.
                    
                    This may be due to:
                    • Insufficient storage space (check available storage)
                    • Corrupted data files (may require app reinstall)
                    • iOS version compatibility issues
                    • Device storage issues
                    
                    Recommended actions:
                    1. Restart the app
                    2. Restart your device
                    3. Check available storage space
                    4. If problem persists, reinstall the app
                    
                    Error details: \(error.localizedDescription)
                    """
                    
                    fatalError(errorMessage)
                }
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
