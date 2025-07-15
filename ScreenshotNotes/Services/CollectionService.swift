import Foundation
import SwiftData
import SwiftUI

/// Service for managing screenshot collections
@MainActor
final class CollectionService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CollectionService()
    
    // MARK: - Published Properties
    @Published var collections: [Collection] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Dependencies
    private var modelContext: ModelContext?
    
    private init() {}
    
    // MARK: - Setup
    
    /// Set the model context
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadCollections()
        createSystemCollectionsIfNeeded()
    }
    
    // MARK: - Collection Management
    
    /// Load all collections from the database
    func loadCollections() {
        guard let context = modelContext else { return }
        
        isLoading = true
        error = nil
        
        do {
            let descriptor = FetchDescriptor<Collection>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            collections = try context.fetch(descriptor)
        } catch {
            self.error = error
            print("❌ Failed to load collections: \(error)")
        }
        
        isLoading = false
    }
    
    /// Create a new collection
    func createCollection(
        name: String,
        description: String? = nil,
        color: String = "#007AFF",
        icon: String = "folder"
    ) -> Collection? {
        guard let context = modelContext else { return nil }
        
        let collection = Collection(
            name: name,
            description: description,
            color: color,
            icon: icon
        )
        
        context.insert(collection)
        
        do {
            try context.save()
            loadCollections()
            return collection
        } catch {
            self.error = error
            print("❌ Failed to create collection: \(error)")
            return nil
        }
    }
    
    /// Update an existing collection
    func updateCollection(
        _ collection: Collection,
        name: String? = nil,
        description: String? = nil,
        color: String? = nil,
        icon: String? = nil
    ) {
        guard let context = modelContext else { return }
        
        if let name = name { collection.name = name }
        if let description = description { collection.collectionDescription = description }
        if let color = color { collection.color = color }
        if let icon = icon { collection.icon = icon }
        
        collection.updateModifiedDate()
        
        do {
            try context.save()
            loadCollections()
        } catch {
            self.error = error
            print("❌ Failed to update collection: \(error)")
        }
    }
    
    /// Delete a collection
    func deleteCollection(_ collection: Collection) {
        guard let context = modelContext else { return }
        guard !collection.isSystem else {
            print("⚠️ Cannot delete system collection")
            return
        }
        
        context.delete(collection)
        
        do {
            try context.save()
            loadCollections()
        } catch {
            self.error = error
            print("❌ Failed to delete collection: \(error)")
        }
    }
    
    /// Add screenshot to collection
    func addScreenshot(_ screenshot: Screenshot, to collection: Collection) {
        guard let context = modelContext else { return }
        
        collection.addScreenshot(screenshot)
        
        do {
            try context.save()
            loadCollections()
        } catch {
            self.error = error
            print("❌ Failed to add screenshot to collection: \(error)")
        }
    }
    
    /// Remove screenshot from collection
    func removeScreenshot(_ screenshot: Screenshot, from collection: Collection) {
        guard let context = modelContext else { return }
        
        collection.removeScreenshot(screenshot)
        
        do {
            try context.save()
            loadCollections()
        } catch {
            self.error = error
            print("❌ Failed to remove screenshot from collection: \(error)")
        }
    }
    
    /// Add screenshots to collection
    func addScreenshots(_ screenshots: [Screenshot], to collection: Collection) {
        guard let context = modelContext else { return }
        
        for screenshot in screenshots {
            collection.addScreenshot(screenshot)
        }
        
        do {
            try context.save()
            loadCollections()
        } catch {
            self.error = error
            print("❌ Failed to add screenshots to collection: \(error)")
        }
    }
    
    /// Get collections containing a specific screenshot
    func getCollections(containing screenshot: Screenshot) -> [Collection] {
        return collections.filter { $0.contains(screenshot) }
    }
    
    /// Get all user-created collections (excluding system collections)
    var userCollections: [Collection] {
        return collections.filter { !$0.isSystem }
    }
    
    /// Get all system collections
    var systemCollections: [Collection] {
        return collections.filter { $0.isSystem }
    }
    
    // MARK: - System Collections
    
    /// Create system collections if they don't exist
    private func createSystemCollectionsIfNeeded() {
        guard let context = modelContext else { return }
        
        let existingSystemCollections = systemCollections.map { $0.name }
        let requiredSystemCollections = ["Favorites", "Recent", "Documents", "Images"]
        
        for collectionName in requiredSystemCollections {
            if !existingSystemCollections.contains(collectionName) {
                let systemCollection = Collection.createSystemCollections().first { $0.name == collectionName }
                if let collection = systemCollection {
                    context.insert(collection)
                }
            }
        }
        
        do {
            try context.save()
            loadCollections()
        } catch {
            print("❌ Failed to create system collections: \(error)")
        }
    }
    
    /// Get system collection by name
    func getSystemCollection(named name: String) -> Collection? {
        return systemCollections.first { $0.name == name }
    }
    
    /// Auto-update system collections based on screenshot properties
    func updateSystemCollections(for screenshot: Screenshot) {
        guard let context = modelContext else { return }
        
        // Add to Favorites if marked as favorite
        if screenshot.isFavorite {
            if let favoritesCollection = getSystemCollection(named: "Favorites") {
                addScreenshot(screenshot, to: favoritesCollection)
            }
        }
        
        // Add to Recent if captured within last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        if screenshot.timestamp >= sevenDaysAgo {
            if let recentCollection = getSystemCollection(named: "Recent") {
                addScreenshot(screenshot, to: recentCollection)
            }
        }
        
        // Add to Documents if it contains significant text
        if screenshot.hasSignificantText {
            if let documentsCollection = getSystemCollection(named: "Documents") {
                addScreenshot(screenshot, to: documentsCollection)
            }
        }
        
        // Add to Images if it's image-heavy content
        if !screenshot.hasSignificantText && screenshot.prominentObjects.count > 0 {
            if let imagesCollection = getSystemCollection(named: "Images") {
                addScreenshot(screenshot, to: imagesCollection)
            }
        }
    }
    
    // MARK: - Collection Suggestions
    
    /// Get suggested collections for a screenshot based on its content
    func getSuggestedCollections(for screenshot: Screenshot) -> [Collection] {
        var suggestions: [Collection] = []
        
        // Suggest collections based on semantic tags
        if let semanticTags = screenshot.semanticTags {
            for tag in semanticTags.tags {
                for collection in userCollections {
                    if collection.name.localizedCaseInsensitiveContains(tag.name) ||
                       collection.collectionDescription?.localizedCaseInsensitiveContains(tag.name) == true {
                        suggestions.append(collection)
                    }
                }
            }
        }
        
        // Suggest collections based on user tags
        if let userTags = screenshot.userTags {
            for tag in userTags {
                for collection in userCollections {
                    if collection.name.localizedCaseInsensitiveContains(tag) ||
                       collection.collectionDescription?.localizedCaseInsensitiveContains(tag) == true {
                        suggestions.append(collection)
                    }
                }
            }
        }
        
        return Array(Set(suggestions))
    }
    
    // MARK: - Search
    
    /// Search collections by name or description
    func searchCollections(query: String) -> [Collection] {
        guard !query.isEmpty else { return collections }
        
        return collections.filter { collection in
            collection.name.localizedCaseInsensitiveContains(query) ||
            collection.collectionDescription?.localizedCaseInsensitiveContains(query) == true
        }
    }
    
    // MARK: - Statistics
    
    /// Get collection statistics
    func getCollectionStats() -> CollectionStats {
        return CollectionStats(
            totalCollections: collections.count,
            userCollections: userCollections.count,
            systemCollections: systemCollections.count,
            totalScreenshots: collections.reduce(0) { $0 + $1.screenshotCount },
            averageScreenshotsPerCollection: collections.isEmpty ? 0 : Double(collections.reduce(0) { $0 + $1.screenshotCount }) / Double(collections.count)
        )
    }
}

// MARK: - Collection Stats

struct CollectionStats {
    let totalCollections: Int
    let userCollections: Int
    let systemCollections: Int
    let totalScreenshots: Int
    let averageScreenshotsPerCollection: Double
}

// MARK: - Collection Picker View

struct CollectionPickerView: View {
    @StateObject private var collectionService = CollectionService.shared
    @State private var selectedCollections: Set<Collection> = []
    @State private var showingNewCollectionSheet = false
    @State private var newCollectionName = ""
    @State private var newCollectionDescription = ""
    @State private var newCollectionColor = "#007AFF"
    @State private var newCollectionIcon = "folder"
    
    let screenshots: [Screenshot]
    let onComplete: ([Collection]) -> Void
    
    var body: some View {
        NavigationView {
            List {
                if !collectionService.userCollections.isEmpty {
                    Section("Your Collections") {
                        ForEach(collectionService.userCollections, id: \.id) { collection in
                            CollectionRow(
                                collection: collection,
                                isSelected: selectedCollections.contains(collection)
                            ) {
                                if selectedCollections.contains(collection) {
                                    selectedCollections.remove(collection)
                                } else {
                                    selectedCollections.insert(collection)
                                }
                            }
                        }
                    }
                }
                
                Section("System Collections") {
                    ForEach(collectionService.systemCollections, id: \.id) { collection in
                        CollectionRow(
                            collection: collection,
                            isSelected: selectedCollections.contains(collection)
                        ) {
                            if selectedCollections.contains(collection) {
                                selectedCollections.remove(collection)
                            } else {
                                selectedCollections.insert(collection)
                            }
                        }
                    }
                }
                
                Button(action: {
                    showingNewCollectionSheet = true
                }) {
                    Label("Create New Collection", systemImage: "plus")
                }
                .foregroundColor(.blue)
            }
            .navigationTitle("Add to Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onComplete([])
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onComplete(Array(selectedCollections))
                    }
                    .disabled(selectedCollections.isEmpty)
                }
            }
            .sheet(isPresented: $showingNewCollectionSheet) {
                NewCollectionSheet(
                    name: $newCollectionName,
                    description: $newCollectionDescription,
                    color: $newCollectionColor,
                    icon: $newCollectionIcon
                ) {
                    if let collection = collectionService.createCollection(
                        name: newCollectionName,
                        description: newCollectionDescription,
                        color: newCollectionColor,
                        icon: newCollectionIcon
                    ) {
                        selectedCollections.insert(collection)
                    }
                    newCollectionName = ""
                    newCollectionDescription = ""
                    newCollectionColor = "#007AFF"
                    newCollectionIcon = "folder"
                }
            }
        }
    }
}

struct CollectionRow: View {
    let collection: Collection
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: collection.icon)
                .foregroundColor(collection.swiftUIColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.headline)
                
                if let description = collection.collectionDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(collection.screenshotCount) screenshots")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct NewCollectionSheet: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var color: String
    @Binding var icon: String
    @Environment(\.dismiss) private var dismiss
    
    let onCreate: () -> Void
    
    private let availableIcons = ["folder", "star", "heart", "bookmark", "tag", "flag", "pin"]
    private let availableColors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#FF2D92", "#5AC8FA"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Collection Details") {
                    TextField("Collection Name", text: $name)
                    TextField("Description (Optional)", text: $description)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                        ForEach(availableIcons, id: \.self) { iconName in
                            Button(action: {
                                icon = iconName
                            }) {
                                Image(systemName: iconName)
                                    .font(.title2)
                                    .foregroundColor(icon == iconName ? .white : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(icon == iconName ? Color.blue : Color.gray.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                        ForEach(availableColors, id: \.self) { colorHex in
                            Button(action: {
                                color = colorHex
                            }) {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .blue)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: color == colorHex ? 3 : 0)
                                    )
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        onCreate()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}