//
//  SmartTextActionService.swift
//  ScreenshotNotes
//
//  Iteration 8.7.1.1: One-Tap Text Actions
//  Core service for intelligent text action detection and iOS system integration
//

import Foundation
import Contacts
import ContactsUI
import EventKit
import MapKit
import MessageUI
import UIKit

@MainActor
final class SmartTextActionService: ObservableObject {
    static let shared = SmartTextActionService()
    
    // MARK: - Published Properties
    
    @Published private(set) var isProcessing = false
    @Published private(set) var lastError: TextActionError?
    
    // MARK: - Private Properties
    
    private lazy var actionableTextDetector = ActionableTextDetector()
    private lazy var contactStore = CNContactStore()
    private lazy var eventStore = EKEventStore()
    
    // Memory management
    private let maxTextLength: Int = 10_000 // Limit text processing to 10K characters
    private let maxConcurrentDetections: Int = 3
    private var activeDetectionTasks: Set<Task<[TextAction], Never>> = []
    
    private init() {}
    
    deinit {
        // Cancel all active tasks to prevent memory leaks
        for task in activeDetectionTasks {
            task.cancel()
        }
        activeDetectionTasks.removeAll()
    }
    
    /// Clean up resources and cancel active tasks
    func cleanup() {
        for task in activeDetectionTasks {
            task.cancel()
        }
        activeDetectionTasks.removeAll()
        lastError = nil
    }
    
    // MARK: - Action Types
    
    enum TextActionType: String, CaseIterable {
        case copy = "copy"
        case call = "call"
        case email = "email"
        case message = "message"
        case openURL = "openURL"
        case openMaps = "openMaps"
        case addContact = "addContact"
        case createEvent = "createEvent"
        case facetime = "facetime"
        
        var systemImage: String {
            switch self {
            case .copy: return "doc.on.doc"
            case .call: return "phone"
            case .email: return "envelope"
            case .message: return "message"
            case .openURL: return "safari"
            case .openMaps: return "map"
            case .addContact: return "person.badge.plus"
            case .createEvent: return "calendar.badge.plus"
            case .facetime: return "video"
            }
        }
        
        var actionName: String {
            switch self {
            case .copy: return "Copy"
            case .call: return "Call"
            case .email: return "Email"
            case .message: return "Message"
            case .openURL: return "Open"
            case .openMaps: return "Maps"
            case .addContact: return "Add Contact"
            case .createEvent: return "Add Event"
            case .facetime: return "FaceTime"
            }
        }
        
        var priority: Int {
            switch self {
            case .copy: return 100 // Always highest priority
            case .call: return 90
            case .email: return 85
            case .message: return 80
            case .facetime: return 75
            case .openURL: return 70
            case .openMaps: return 65
            case .addContact: return 60
            case .createEvent: return 55
            }
        }
    }
    
    // MARK: - Action Structure
    
    struct TextAction: Identifiable, Hashable {
        let id = UUID()
        let type: TextActionType
        let text: String
        let displayText: String
        let confidence: Double
        let range: NSRange
        
        var systemImage: String { type.systemImage }
        var actionName: String { type.actionName }
        var priority: Int { type.priority }
        
        static func == (lhs: TextAction, rhs: TextAction) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    // MARK: - Error Handling
    
    enum TextActionError: LocalizedError {
        case invalidText
        case contactsPermissionDenied
        case calendarPermissionDenied
        case actionFailed(String)
        case systemServiceUnavailable
        
        var errorDescription: String? {
            switch self {
            case .invalidText:
                return "Invalid text for this action"
            case .contactsPermissionDenied:
                return "Permission to access contacts is required"
            case .calendarPermissionDenied:
                return "Permission to access calendar is required"
            case .actionFailed(let message):
                return "Action failed: \(message)"
            case .systemServiceUnavailable:
                return "System service is not available"
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Detect actionable text and return available actions
    func detectActions(in text: String) async -> [TextAction] {
        // Memory safety: Limit text length and concurrent operations
        guard !isProcessing else { return [] }
        guard text.count <= maxTextLength else {
            let truncatedText = String(text.prefix(maxTextLength))
            return await detectActions(in: truncatedText)
        }
        
        // Limit concurrent detection tasks
        if activeDetectionTasks.count >= maxConcurrentDetections {
            // Cancel oldest task to make room
            if let oldestTask = activeDetectionTasks.first {
                oldestTask.cancel()
                activeDetectionTasks.remove(oldestTask)
            }
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let task = Task<[TextAction], Never> {
            let detectedItems = await actionableTextDetector.detectActionableItems(in: text)
            let actions = convertToActions(detectedItems)
            
            // Clean up completed task
            await MainActor.run {
                if let taskToRemove = activeDetectionTasks.first(where: { $0.isCancelled || !$0.isCancelled }) {
                    activeDetectionTasks.remove(taskToRemove)
                }
            }
            
            return actions
        }
        
        activeDetectionTasks.insert(task)
        let result = await task.value
        
        return result
    }
    
    /// Execute a specific text action
    func executeAction(_ action: TextAction) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            switch action.type {
            case .copy:
                return executeCopyAction(action)
            case .call:
                return await executeCallAction(action)
            case .email:
                return await executeEmailAction(action)
            case .message:
                return await executeMessageAction(action)
            case .openURL:
                return await executeURLAction(action)
            case .openMaps:
                return await executeMapsAction(action)
            case .addContact:
                return await executeAddContactAction(action)
            case .createEvent:
                return await executeCreateEventAction(action)
            case .facetime:
                return await executeFaceTimeAction(action)
            }
        } catch {
            lastError = error as? TextActionError ?? .actionFailed(error.localizedDescription)
            return false
        }
    }
    
    /// Check if action requires permissions
    func actionRequiresPermission(_ action: TextAction) -> Bool {
        switch action.type {
        case .addContact:
            return true
        case .createEvent:
            return true
        default:
            return false
        }
    }
    
    /// Request permissions for action
    func requestPermission(for action: TextAction) async -> Bool {
        switch action.type {
        case .addContact:
            return await requestContactsPermission()
        case .createEvent:
            return await requestCalendarPermission()
        default:
            return true
        }
    }
    
    // MARK: - Private Methods - Action Conversion
    
    private func convertToActions(_ detectedItems: [ActionableTextDetector.DetectedItem]) -> [TextAction] {
        var actions: [TextAction] = []
        
        for item in detectedItems {
            // Always add copy action
            let copyAction = TextAction(
                type: .copy,
                text: item.text,
                displayText: item.text,
                confidence: 1.0,
                range: item.range
            )
            actions.append(copyAction)
            
            // Add specific actions based on item type
            switch item.type {
            case .phoneNumber:
                actions.append(contentsOf: createPhoneActions(for: item))
            case .email:
                actions.append(contentsOf: createEmailActions(for: item))
            case .url:
                actions.append(contentsOf: createURLActions(for: item))
            case .address:
                actions.append(contentsOf: createAddressActions(for: item))
            case .date:
                actions.append(contentsOf: createDateActions(for: item))
            }
        }
        
        // Sort by priority and confidence
        return actions.sorted { first, second in
            if first.priority != second.priority {
                return first.priority > second.priority
            }
            return first.confidence > second.confidence
        }
    }
    
    private func createPhoneActions(for item: ActionableTextDetector.DetectedItem) -> [TextAction] {
        let phoneNumber = item.text
        return [
            TextAction(type: .call, text: phoneNumber, displayText: "Call \(phoneNumber)", confidence: item.confidence, range: item.range),
            TextAction(type: .message, text: phoneNumber, displayText: "Message \(phoneNumber)", confidence: item.confidence, range: item.range),
            TextAction(type: .facetime, text: phoneNumber, displayText: "FaceTime \(phoneNumber)", confidence: item.confidence, range: item.range),
            TextAction(type: .addContact, text: phoneNumber, displayText: "Add to Contacts", confidence: item.confidence, range: item.range)
        ]
    }
    
    private func createEmailActions(for item: ActionableTextDetector.DetectedItem) -> [TextAction] {
        let email = item.text
        return [
            TextAction(type: .email, text: email, displayText: "Email \(email)", confidence: item.confidence, range: item.range),
            TextAction(type: .addContact, text: email, displayText: "Add to Contacts", confidence: item.confidence, range: item.range)
        ]
    }
    
    private func createURLActions(for item: ActionableTextDetector.DetectedItem) -> [TextAction] {
        let url = item.text
        return [
            TextAction(type: .openURL, text: url, displayText: "Open Link", confidence: item.confidence, range: item.range)
        ]
    }
    
    private func createAddressActions(for item: ActionableTextDetector.DetectedItem) -> [TextAction] {
        let address = item.text
        return [
            TextAction(type: .openMaps, text: address, displayText: "Open in Maps", confidence: item.confidence, range: item.range)
        ]
    }
    
    private func createDateActions(for item: ActionableTextDetector.DetectedItem) -> [TextAction] {
        let dateText = item.text
        return [
            TextAction(type: .createEvent, text: dateText, displayText: "Create Event", confidence: item.confidence, range: item.range)
        ]
    }
    
    // MARK: - Private Methods - Action Execution
    
    private func executeCopyAction(_ action: TextAction) -> Bool {
        UIPasteboard.general.string = action.text
        return true
    }
    
    private func executeCallAction(_ action: TextAction) async -> Bool {
        guard let url = URL(string: "tel:\(action.text.replacingOccurrences(of: " ", with: ""))"),
              UIApplication.shared.canOpenURL(url) else {
            return false
        }
        
        await UIApplication.shared.open(url)
        return true
    }
    
    private func executeEmailAction(_ action: TextAction) async -> Bool {
        guard let url = URL(string: "mailto:\(action.text)"),
              UIApplication.shared.canOpenURL(url) else {
            return false
        }
        
        await UIApplication.shared.open(url)
        return true
    }
    
    private func executeMessageAction(_ action: TextAction) async -> Bool {
        guard let url = URL(string: "sms:\(action.text.replacingOccurrences(of: " ", with: ""))"),
              UIApplication.shared.canOpenURL(url) else {
            return false
        }
        
        await UIApplication.shared.open(url)
        return true
    }
    
    private func executeURLAction(_ action: TextAction) async -> Bool {
        var urlString = action.text
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else {
            return false
        }
        
        await UIApplication.shared.open(url)
        return true
    }
    
    private func executeMapsAction(_ action: TextAction) async -> Bool {
        let encodedAddress = action.text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "http://maps.apple.com/?q=\(encodedAddress)"),
              UIApplication.shared.canOpenURL(url) else {
            return false
        }
        
        await UIApplication.shared.open(url)
        return true
    }
    
    private func executeFaceTimeAction(_ action: TextAction) async -> Bool {
        guard let url = URL(string: "facetime:\(action.text.replacingOccurrences(of: " ", with: ""))"),
              UIApplication.shared.canOpenURL(url) else {
            return false
        }
        
        await UIApplication.shared.open(url)
        return true
    }
    
    private func executeAddContactAction(_ action: TextAction) async -> Bool {
        guard await requestContactsPermission() else {
            lastError = .contactsPermissionDenied
            return false
        }
        
        let contact = CNMutableContact()
        
        // Determine if it's a phone number or email
        if action.text.contains("@") {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: action.text as NSString)]
        } else {
            let phoneNumber = CNPhoneNumber(stringValue: action.text)
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: phoneNumber)]
        }
        
        // Present contact view controller
        let contactViewController = CNContactViewController(forNewContact: contact)
        contactViewController.allowsEditing = true
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            let navController = UINavigationController(rootViewController: contactViewController)
            rootViewController.present(navController, animated: true)
            return true
        }
        
        return false
    }
    
    private func executeCreateEventAction(_ action: TextAction) async -> Bool {
        guard await requestCalendarPermission() else {
            lastError = .calendarPermissionDenied
            return false
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "Event from Screenshot"
        event.notes = action.text
        
        // Try to parse date from text
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        if let date = dateFormatter.date(from: action.text) {
            event.startDate = date
            event.endDate = date.addingTimeInterval(3600) // 1 hour duration
        } else {
            event.startDate = Date()
            event.endDate = Date().addingTimeInterval(3600)
        }
        
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            lastError = .actionFailed("Failed to create event: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Permission Management
    
    private func requestContactsPermission() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .authorized:
            return true
        case .limited:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                contactStore.requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    private func requestCalendarPermission() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .fullAccess:
            return true
        case .writeOnly:
            return true
        case .authorized:
            return true
        case .notDetermined:
            if #available(iOS 17.0, *) {
                return await withCheckedContinuation { continuation in
                    eventStore.requestFullAccessToEvents { granted, _ in
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                return await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, _ in
                        continuation.resume(returning: granted)
                    }
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension SmartTextActionService {
    static func mockActions() -> [TextAction] {
        return [
            TextAction(type: .copy, text: "+1 (555) 123-4567", displayText: "+1 (555) 123-4567", confidence: 1.0, range: NSRange(location: 0, length: 16)),
            TextAction(type: .call, text: "+1 (555) 123-4567", displayText: "Call +1 (555) 123-4567", confidence: 0.95, range: NSRange(location: 0, length: 16)),
            TextAction(type: .message, text: "+1 (555) 123-4567", displayText: "Message +1 (555) 123-4567", confidence: 0.90, range: NSRange(location: 0, length: 16)),
            TextAction(type: .addContact, text: "+1 (555) 123-4567", displayText: "Add to Contacts", confidence: 0.85, range: NSRange(location: 0, length: 16))
        ]
    }
}
#endif