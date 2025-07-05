import Foundation
import SwiftUI

/// Demonstration of Sub-Sprint 5.1.2: Entity Extraction Engine
/// Shows the enhanced query parsing with entity extraction capabilities
@available(iOS 17.0, *)
public struct EntityExtractionDemo: View {
    
    @StateObject private var queryParser = QueryParserService()
    @State private var searchText: String = ""
    @State private var currentResult: SearchQuery?
    @State private var isAnalyzing: Bool = false
    
    // Demo queries to showcase different entity types
    private let demoQueries = [
        "blue dress from last Tuesday",
        "find receipt from Marriott hotel",
        "show me green car screenshots",
        "photos with phone number 555-123-4567",
        "email screenshots from contact@example.com",
        "red shirt from yesterday morning",
        "invoice from Amazon this week",
        "purple phone screenshot",
        "restaurant menu from Paris trip",
        "tickets from last month"
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Entity Extraction Engine")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sub-Sprint 5.1.2 Demo")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Enhanced natural language processing with named entity recognition")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Search Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Try Natural Language Queries")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        TextField("Enter search query...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                analyzeQuery()
                            }
                        
                        Button("Analyze", action: analyzeQuery)
                            .disabled(searchText.isEmpty || isAnalyzing)
                    }
                    .padding(.horizontal)
                }
                
                // Demo Query Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Or try these examples:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(demoQueries, id: \.self) { query in
                            Button(action: {
                                searchText = query
                                analyzeQuery()
                            }) {
                                Text(query)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Analysis Results
                if isAnalyzing {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Analyzing entities...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let result = currentResult {
                    EntityAnalysisResultView(result: result)
                } else {
                    VStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Enter a query to see entity extraction in action")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
            }
            .navigationTitle("Entity Extraction")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func analyzeQuery() {
        guard !searchText.isEmpty else { return }
        
        isAnalyzing = true
        
        Task {
            let result = await queryParser.parseQuery(searchText)
            
            await MainActor.run {
                currentResult = result
                isAnalyzing = false
            }
        }
    }
}

/// View to display entity analysis results
private struct EntityAnalysisResultView: View {
    let result: SearchQuery
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Query Overview
                GroupBox("Query Analysis") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Intent:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(result.intent.rawValue.capitalized)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Confidence:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.1f%%", result.confidence.rawValue * 100))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Language:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(result.language.rawValue.capitalized)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Processing Time:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.1fms", result.processingTimeMs))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Extracted Entities
                if !result.extractedEntities.isEmpty {
                    GroupBox("Extracted Entities (\(result.extractedEntities.count))") {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(Array(result.extractedEntities.enumerated()), id: \.offset) { index, entity in
                                EntityCardView(entity: entity)
                            }
                        }
                    }
                }
                
                // Entity Categories
                let categories = [
                    ("Visual", result.visualEntities),
                    ("Temporal", result.temporalEntities),
                    ("Colors", result.colorEntities),
                    ("Objects", result.objectEntities),
                    ("Documents", result.documentTypeEntities)
                ].filter { !$1.isEmpty }
                
                if !categories.isEmpty {
                    GroupBox("Entity Categories") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(categories, id: \.0) { category, entities in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(category) (\(entities.count))")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        ForEach(entities.prefix(3), id: \.text) { entity in
                                            Text(entity.normalizedValue)
                                                .font(.caption)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                        }
                                        
                                        if entities.count > 3 {
                                            Text("+\(entities.count - 3) more")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Query Capabilities
                GroupBox("Query Capabilities") {
                    VStack(alignment: .leading, spacing: 8) {
                        CapabilityRow(title: "Rich Entity Data", value: result.hasRichEntityData)
                        CapabilityRow(title: "Visual Search", value: result.hasVisualEntities)
                        CapabilityRow(title: "Temporal Search", value: result.hasTemporalEntities)
                        CapabilityRow(title: "Actionable", value: result.isActionable)
                        
                        HStack {
                            Text("Relevance Score:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.2f", result.relevanceScore))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Debug Information
                GroupBox("Debug Information") {
                    Text(result.debugDescription)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}

/// Individual entity card view
private struct EntityCardView: View {
    let entity: ExtractedEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entity.type.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                ConfidenceBadge(confidence: entity.confidence)
            }
            
            Text(entity.text)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if entity.text != entity.normalizedValue {
                Text("→ \(entity.normalizedValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Confidence level badge
private struct ConfidenceBadge: View {
    let confidence: EntityConfidence
    
    var body: some View {
        Text(String(format: "%.0f%%", confidence.rawValue * 100))
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(confidenceColor.opacity(0.2))
            .foregroundColor(confidenceColor)
            .cornerRadius(4)
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case .veryHigh:
            return .green
        case .high:
            return .blue
        case .medium:
            return .orange
        case .low, .veryLow:
            return .red
        }
    }
}

/// Capability row view
private struct CapabilityRow: View {
    let title: String
    let value: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(value ? .green : .red)
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct EntityExtractionDemo_Previews: PreviewProvider {
    static var previews: some View {
        EntityExtractionDemo()
    }
}
