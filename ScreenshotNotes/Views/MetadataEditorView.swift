import SwiftUI

struct MetadataEditorView: View {
    let screenshot: Screenshot
    @Environment(\.dismiss) private var dismiss
    @State private var filename: String
    @State private var userNotes: String
    @State private var userTags: String
    @State private var isFavorite: Bool
    @State private var isSaving = false
    @State private var hasChanges = false
    
    private let hapticService = HapticService.shared
    
    init(screenshot: Screenshot) {
        self.screenshot = screenshot
        self._filename = State(initialValue: screenshot.filename)
        self._userNotes = State(initialValue: screenshot.userNotes ?? "")
        self._userTags = State(initialValue: (screenshot.userTags ?? []).joined(separator: ", "))
        self._isFavorite = State(initialValue: screenshot.isFavorite)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filename")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter filename", text: $filename)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: filename) { _, _ in
                                hasChanges = true
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Created")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(screenshot.timestamp))
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    
                    Toggle("Favorite", isOn: $isFavorite)
                        .onChange(of: isFavorite) { _, _ in
                            hasChanges = true
                        }
                }
                
                Section("Notes") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Personal Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $userNotes)
                            .frame(minHeight: 100)
                            .onChange(of: userNotes) { _, _ in
                                hasChanges = true
                            }
                    }
                }
                
                Section("Tags") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Tags")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter tags separated by commas", text: $userTags)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: userTags) { _, _ in
                                hasChanges = true
                            }
                        
                        Text("Separate multiple tags with commas")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show existing tags
                    if let existingTags = screenshot.userTags, !existingTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Tags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 80))
                            ], spacing: 8) {
                                ForEach(existingTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                
                Section("Technical Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        infoRow("File Size", formatFileSize(screenshot.imageData.count))
                        
                        if let dimensions = getImageDimensions() {
                            infoRow("Dimensions", dimensions)
                        }
                        
                        infoRow("Processing Status", getProcessingStatus())
                        
                        if let lastAnalysis = screenshot.lastSemanticAnalysis {
                            infoRow("Last Analysis", formatDate(lastAnalysis))
                        }
                    }
                }
                
                if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
                    Section("Extracted Text") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OCR Results")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(extractedText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                    }
                }
                
                if let semanticTags = screenshot.semanticTags, !semanticTags.tags.isEmpty {
                    Section("AI Analysis") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Semantic Tags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 100))
                            ], spacing: 8) {
                                ForEach(semanticTags.tags, id: \.id) { tag in
                                    VStack(spacing: 2) {
                                        Text(tag.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        Text("\(Int(tag.confidence * 100))%")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundColor(.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving || !hasChanges)
                    .fontWeight(.semibold)
                }
            }
        }
        .disabled(isSaving)
        .overlay {
            if isSaving {
                ProgressView("Saving...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    private func getImageDimensions() -> String? {
        guard let uiImage = UIImage(data: screenshot.imageData) else { return nil }
        let size = uiImage.size
        return "\(Int(size.width)) × \(Int(size.height))"
    }
    
    private func getProcessingStatus() -> String {
        var status: [String] = []
        
        if screenshot.extractedText?.isEmpty == false {
            status.append("OCR")
        }
        
        if !(screenshot.objectTags?.isEmpty ?? true) {
            status.append("Vision")
        }
        
        if let semanticTags = screenshot.semanticTags, !semanticTags.tags.isEmpty {
            status.append("AI Tags")
        }
        
        if !screenshot.dominantColors.isEmpty {
            status.append("Colors")
        }
        
        return status.isEmpty ? "Basic" : status.joined(separator: ", ")
    }
    
    private func saveChanges() {
        guard hasChanges else { return }
        
        isSaving = true
        hapticService.impact(.light)
        
        Task {
            await MainActor.run {
                // Update screenshot properties
                screenshot.filename = filename.trimmingCharacters(in: .whitespacesAndNewlines)
                screenshot.userNotes = userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                screenshot.isFavorite = isFavorite
                
                // Parse and update tags
                let tagsArray = userTags
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                screenshot.userTags = tagsArray.isEmpty ? nil : tagsArray
                
                // Save to model context
                if let modelContext = screenshot.modelContext {
                    do {
                        try modelContext.save()
                        print("✅ Successfully saved metadata changes")
                        
                        // Trigger mind map regeneration if needed
                        Task {
                            await BackgroundSemanticProcessor().triggerMindMapRegeneration(in: modelContext)
                        }
                        
                        hapticService.notification(.success)
                        dismiss()
                    } catch {
                        print("❌ Failed to save metadata changes: \(error)")
                        hapticService.notification(.error)
                    }
                } else {
                    print("❌ No model context available")
                    hapticService.notification(.error)
                }
                
                isSaving = false
            }
        }
    }
}

#Preview {
    MetadataEditorView(screenshot: Screenshot(imageData: Data(), filename: "test_image.jpg"))
}