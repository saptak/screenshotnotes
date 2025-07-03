import SwiftUI
import SwiftData

@main
struct ScreenshotNotesApp: App {
    @StateObject private var photoLibraryService = PhotoLibraryService()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Screenshot.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Register background tasks
        BackgroundTaskService.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoLibraryService)
                .onAppear {
                    photoLibraryService.setModelContext(sharedModelContainer.mainContext)
                    
                    // Start monitoring if permissions are already granted
                    if photoLibraryService.authorizationStatus == .authorized {
                        photoLibraryService.startMonitoring()
                    }
                    
                    // Schedule background refresh
                    BackgroundTaskService.shared.scheduleAppRefresh()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
