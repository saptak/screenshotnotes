import Foundation
import BackgroundTasks
import SwiftData

protocol BackgroundTaskServiceProtocol {
    func scheduleAppRefresh()
    func registerBackgroundTasks()
}

class BackgroundTaskService: BackgroundTaskServiceProtocol {
    static let shared = BackgroundTaskService()
    private let backgroundTaskIdentifier = "com.screenshotnotes.refresh"
    
    private init() {}
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        print("🔄 Background tasks registered")
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🔄 Background app refresh scheduled")
        } catch {
            print("❌ Failed to schedule background app refresh: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("🔄 Background app refresh started")
        
        // Schedule the next background refresh
        scheduleAppRefresh()
        
        // Create a background task to process any pending screenshots
        let backgroundTask = Task {
            do {
                await processBackgroundScreenshots()
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ Background task failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
        
        // Handle task expiration
        task.expirationHandler = {
            print("⏰ Background task expired")
            backgroundTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    private func processBackgroundScreenshots() async {
        print("📸 Processing screenshots in background")
        
        // This would typically involve:
        // 1. Checking for new screenshots
        // 2. Running OCR on unprocessed screenshots
        // 3. Updating the database
        
        // For now, we'll just simulate some work
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        print("📸 Background screenshot processing completed")
    }
}