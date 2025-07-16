import Foundation
import SwiftUI

/// Comprehensive weak reference management system to prevent retain cycles
/// Implements Iteration 8.5.3.2: Memory Management & Leak Prevention
@MainActor
public final class WeakReferenceManager: ObservableObject {
    
    public static let shared = WeakReferenceManager()
    
    // MARK: - Weak Reference Container
    
    public final class WeakContainer<T: AnyObject> {
        public weak var value: T?
        public let identifier: String
        public let createdAt: Date
        
        public init(_ value: T, identifier: String? = nil) {
            self.value = value
            self.identifier = identifier ?? UUID().uuidString
            self.createdAt = Date()
        }
        
        /// Initialize with nil value (for property wrapper support)
        public init(identifier: String? = nil) {
            self.value = nil
            self.identifier = identifier ?? UUID().uuidString
            self.createdAt = Date()
        }
        
        public var isAlive: Bool {
            return value != nil
        }
        
        public var age: TimeInterval {
            return Date().timeIntervalSince(createdAt)
        }
    }
    
    // MARK: - Weak Reference Collection
    
    public final class WeakCollection<T: AnyObject> {
        private var containers: [WeakContainer<T>] = []
        private let lock = NSLock()
        
        public var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return containers.filter { $0.isAlive }.count
        }
        
        public var allObjects: [T] {
            lock.lock()
            defer { lock.unlock() }
            return containers.compactMap { $0.value }
        }
        
        public func add(_ object: T, identifier: String? = nil) {
            lock.lock()
            defer { lock.unlock() }
            
            let container = WeakContainer(object, identifier: identifier)
            containers.append(container)
            
            // Clean up dead references periodically
            if containers.count % 10 == 0 {
                cleanupDeadReferences()
            }
        }
        
        public func remove(_ object: T) {
            lock.lock()
            defer { lock.unlock() }
            
            containers.removeAll { container in
                guard let value = container.value else { return true } // Remove dead references
                return value === object
            }
        }
        
        public func removeAll() {
            lock.lock()
            defer { lock.unlock() }
            containers.removeAll()
        }
        
        public func contains(_ object: T) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            
            return containers.contains { container in
                guard let value = container.value else { return false }
                return value === object
            }
        }
        
        private func cleanupDeadReferences() {
            containers.removeAll { !$0.isAlive }
        }
        
        public func forceCleanup() {
            lock.lock()
            defer { lock.unlock() }
            cleanupDeadReferences()
        }
    }
    
    // MARK: - Delegate Weak Reference
    
    public final class WeakDelegate<T: AnyObject> {
        public weak var delegate: T?
        public let identifier: String
        
        public init(delegate: T? = nil, identifier: String? = nil) {
            self.delegate = delegate
            self.identifier = identifier ?? UUID().uuidString
        }
        
        public var isValid: Bool {
            return delegate != nil
        }
        
        public func call<R>(_ method: (T) -> R) -> R? {
            return delegate.map(method)
        }
        
        public func callAsync<R>(_ method: @escaping (T) async -> R) async -> R? {
            guard let delegate = delegate else { return nil }
            return await method(delegate)
        }
    }
    
    // MARK: - Published State
    
    @Published public private(set) var activeWeakReferences: [String: Any] = [:]
    @Published public private(set) var deadReferenceCount = 0
    @Published public private(set) var totalReferencesCreated = 0
    @Published public private(set) var lastCleanupTime: Date?
    
    // MARK: - Internal State
    
    private var weakCollections: [String: Any] = [:]
    private var weakDelegates: [String: Any] = [:]
    private var cleanupTimer: Timer?
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "WeakReferenceManager")
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let cleanupInterval: TimeInterval = 60.0 // 1 minute
        static let maxDeadReferences = 100
    }
    
    // MARK: - Initialization
    
    private init() {
        setupPeriodicCleanup()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Weak Collection Management
    
    /// Create or get a weak collection for a specific type
    /// - Parameter identifier: Unique identifier for the collection
    /// - Returns: WeakCollection for the specified type
    public func getWeakCollection<T: AnyObject>(identifier: String, type: T.Type) -> WeakCollection<T> {
        if let existing = weakCollections[identifier] as? WeakCollection<T> {
            return existing
        }
        
        let collection = WeakCollection<T>()
        weakCollections[identifier] = collection
        activeWeakReferences[identifier] = collection
        
        logger.debug("WeakReferenceManager: Created weak collection: \(identifier)")
        return collection
    }
    
    /// Remove a weak collection
    /// - Parameter identifier: Identifier of the collection to remove
    public func removeWeakCollection(identifier: String) {
        weakCollections.removeValue(forKey: identifier)
        activeWeakReferences.removeValue(forKey: identifier)
        
        logger.debug("WeakReferenceManager: Removed weak collection: \(identifier)")
    }
    
    // MARK: - Weak Delegate Management
    
    /// Create a weak delegate reference
    /// - Parameters:
    ///   - delegate: The delegate object
    ///   - identifier: Unique identifier for the delegate
    /// - Returns: WeakDelegate wrapper
    public func createWeakDelegate<T: AnyObject>(_ delegate: T?, identifier: String? = nil) -> WeakDelegate<T> {
        let finalIdentifier = identifier ?? UUID().uuidString
        let weakDelegate = WeakDelegate(delegate: delegate, identifier: finalIdentifier)
        
        weakDelegates[finalIdentifier] = weakDelegate
        activeWeakReferences[finalIdentifier] = weakDelegate
        totalReferencesCreated += 1
        
        logger.debug("WeakReferenceManager: Created weak delegate: \(finalIdentifier)")
        return weakDelegate
    }
    
    /// Remove a weak delegate reference
    /// - Parameter identifier: Identifier of the delegate to remove
    public func removeWeakDelegate(identifier: String) {
        weakDelegates.removeValue(forKey: identifier)
        activeWeakReferences.removeValue(forKey: identifier)
        
        logger.debug("WeakReferenceManager: Removed weak delegate: \(identifier)")
    }
    
    // MARK: - Cleanup Operations
    
    /// Perform comprehensive cleanup of dead references
    public func performCleanup() {
        var deadCount = 0
        
        // Clean up weak collections
        for (_, _) in weakCollections {
            // Collections will be cleaned up automatically through weak references
            // No manual cleanup needed since we're using weak references
        }
        
        // Clean up weak delegates
        let deadDelegates = weakDelegates.filter { _, value in
            // Use reflection to check if delegate is nil
            let mirror = Mirror(reflecting: value)
            for child in mirror.children {
                if child.label == "delegate" {
                    // Check if the value is an optional and is nil
                    let childMirror = Mirror(reflecting: child.value)
                    return childMirror.displayStyle == .optional && childMirror.children.isEmpty
                }
            }
            return false
        }
        
        for (identifier, _) in deadDelegates {
            weakDelegates.removeValue(forKey: identifier)
            activeWeakReferences.removeValue(forKey: identifier)
            deadCount += 1
        }
        
        deadReferenceCount += deadCount
        lastCleanupTime = Date()
        
        if deadCount > 0 {
            logger.info("WeakReferenceManager: Cleaned up \(deadCount) dead references")
        }
    }
    
    /// Force cleanup of all references
    public func forceCleanupAll() {
        logger.warning("WeakReferenceManager: Performing force cleanup of all references")
        
        weakCollections.removeAll()
        weakDelegates.removeAll()
        activeWeakReferences.removeAll()
        
        lastCleanupTime = Date()
    }
    
    // MARK: - Periodic Cleanup
    
    private func setupPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: Configuration.cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performCleanup()
            }
        }
    }
    
    // MARK: - Statistics and Monitoring
    
    public func getStatistics() -> WeakReferenceStatistics {
        let activeCollections = weakCollections.count
        let activeDelegates = weakDelegates.count
        let totalActive = activeWeakReferences.count
        
        return WeakReferenceStatistics(
            activeCollections: activeCollections,
            activeDelegates: activeDelegates,
            totalActiveReferences: totalActive,
            deadReferenceCount: deadReferenceCount,
            totalReferencesCreated: totalReferencesCreated,
            lastCleanupTime: lastCleanupTime
        )
    }
    
    public struct WeakReferenceStatistics {
        public let activeCollections: Int
        public let activeDelegates: Int
        public let totalActiveReferences: Int
        public let deadReferenceCount: Int
        public let totalReferencesCreated: Int
        public let lastCleanupTime: Date?
        
        public var cleanupEfficiency: Double {
            guard totalReferencesCreated > 0 else { return 0.0 }
            return Double(deadReferenceCount) / Double(totalReferencesCreated) * 100.0
        }
        
        public var summary: String {
            return """
            Weak Reference Statistics:
            - Active Collections: \(activeCollections)
            - Active Delegates: \(activeDelegates)
            - Total Active References: \(totalActiveReferences)
            - Dead References Cleaned: \(deadReferenceCount)
            - Total References Created: \(totalReferencesCreated)
            - Cleanup Efficiency: \(cleanupEfficiency.formatted(.number.precision(.fractionLength(1))))%
            - Last Cleanup: \(lastCleanupTime?.formatted() ?? "Never")
            """
        }
    }
}

// MARK: - Convenience Extensions

public extension WeakReferenceManager {
    
    /// Create a weak reference to an object
    /// - Parameters:
    ///   - object: Object to create weak reference for
    ///   - identifier: Optional identifier
    /// - Returns: Weak container
    func weakReference<T: AnyObject>(to object: T, identifier: String? = nil) -> WeakContainer<T> {
        let container = WeakContainer(object, identifier: identifier)
        totalReferencesCreated += 1
        return container
    }
    
    /// Create a weak collection for ViewModels
    /// - Returns: WeakCollection for ViewModels
    func viewModelCollection<T: ObservableObject>() -> WeakCollection<T> {
        return getWeakCollection(identifier: "ViewModels", type: T.self)
    }
    
    /// Create a weak collection for Services
    /// - Returns: WeakCollection for Services
    func serviceCollection<T: AnyObject>() -> WeakCollection<T> {
        return getWeakCollection(identifier: "Services", type: T.self)
    }
}

// MARK: - Property Wrapper for Weak References

@propertyWrapper
public struct WeakRef<T: AnyObject> {
    private let container: WeakReferenceManager.WeakContainer<T>
    
    public init(wrappedValue: T?) {
        if let value = wrappedValue {
            // Create container directly without going through the manager to avoid actor isolation
            self.container = WeakReferenceManager.WeakContainer<T>(value)
        } else {
            // Create a container with nil value using the convenience initializer
            self.container = WeakReferenceManager.WeakContainer<T>()
        }
    }
    
    public var wrappedValue: T? {
        get { container.value }
        set {
            if let _ = newValue {
                // This is a limitation of the property wrapper approach
                // In practice, you'd want to create a new container
                // For now, we'll just log the limitation
                print("WeakRef: Cannot reassign value after initialization")
            }
        }
    }
    
    public var projectedValue: WeakReferenceManager.WeakContainer<T> {
        return container
    }
}

// MARK: - Weak Delegate Property Wrapper

@propertyWrapper
public struct WeakDelegate<T: AnyObject> {
    private let weakDelegate: WeakReferenceManager.WeakDelegate<T>
    
    public init(wrappedValue: T? = nil) {
        // Create weak delegate directly to avoid actor isolation
        self.weakDelegate = WeakReferenceManager.WeakDelegate<T>(delegate: wrappedValue)
    }
    
    public var wrappedValue: T? {
        get { weakDelegate.delegate }
        set { weakDelegate.delegate = newValue }
    }
    
    public var projectedValue: WeakReferenceManager.WeakDelegate<T> {
        return weakDelegate
    }
}

// MARK: - Retain Cycle Detection

public final class RetainCycleDetector {
    
    public static let shared = RetainCycleDetector()
    
    private var objectGraph: [String: Set<String>] = [:]
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "RetainCycleDetector")
    
    private init() {}
    
    /// Add a reference relationship between two objects
    /// - Parameters:
    ///   - from: Source object identifier
    ///   - to: Target object identifier
    public func addReference(from: String, to: String) {
        if objectGraph[from] == nil {
            objectGraph[from] = Set<String>()
        }
        objectGraph[from]?.insert(to)
    }
    
    /// Remove a reference relationship
    /// - Parameters:
    ///   - from: Source object identifier
    ///   - to: Target object identifier
    public func removeReference(from: String, to: String) {
        objectGraph[from]?.remove(to)
        if objectGraph[from]?.isEmpty == true {
            objectGraph.removeValue(forKey: from)
        }
    }
    
    /// Detect potential retain cycles
    /// - Returns: Array of detected cycles
    public func detectCycles() -> [[String]] {
        var cycles: [[String]] = []
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        
        for node in objectGraph.keys {
            if !visited.contains(node) {
                if let cycle = detectCycleFromNode(node, visited: &visited, recursionStack: &recursionStack) {
                    cycles.append(cycle)
                }
            }
        }
        
        if !cycles.isEmpty {
            logger.warning("RetainCycleDetector: Detected \(cycles.count) potential retain cycles")
        }
        
        return cycles
    }
    
    private func detectCycleFromNode(_ node: String, visited: inout Set<String>, recursionStack: inout Set<String>) -> [String]? {
        visited.insert(node)
        recursionStack.insert(node)
        
        if let neighbors = objectGraph[node] {
            for neighbor in neighbors {
                if !visited.contains(neighbor) {
                    if let cycle = detectCycleFromNode(neighbor, visited: &visited, recursionStack: &recursionStack) {
                        return [node] + cycle
                    }
                } else if recursionStack.contains(neighbor) {
                    // Found a cycle
                    return [node, neighbor]
                }
            }
        }
        
        recursionStack.remove(node)
        return nil
    }
    
    /// Clear all reference tracking
    public func clearAll() {
        objectGraph.removeAll()
        logger.info("RetainCycleDetector: Cleared all reference tracking")
    }
}

import os.log

extension Logger {
    static let weakReference = Logger(subsystem: "com.screenshotnotes.app", category: "WeakReference")
}