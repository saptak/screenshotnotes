import SwiftUI
import Foundation

struct SearchFiltersView: View {
    @Binding var filters: SearchFilters
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section("Date Range") {
                    Picker("Date Range", selection: $filters.dateRange) {
                        ForEach(SearchFilters.DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Text Content") {
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: {
                            filters.hasText = nil
                        }) {
                            HStack {
                                Text("All Screenshots")
                                Spacer()
                                if filters.hasText == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        
                        Button(action: {
                            filters.hasText = true
                        }) {
                            HStack {
                                Text("With Text Only")
                                Spacer()
                                if filters.hasText == true {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        
                        Button(action: {
                            filters.hasText = false
                        }) {
                            HStack {
                                Text("Images Only")
                                Spacer()
                                if filters.hasText == false {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("Sort Order") {
                    Picker("Sort Order", selection: $filters.sortOrder) {
                        ForEach(SearchFilters.SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section {
                    Button("Reset Filters") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            filters = SearchFilters()
                        }
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// Enhanced search service protocol with filters
protocol AdvancedSearchServiceProtocol: SearchServiceProtocol {
    func searchScreenshots(query: String, in screenshots: [Screenshot], filters: SearchFilters) -> [Screenshot]
}

// Enhanced search service implementation
extension SearchService: AdvancedSearchServiceProtocol {
    func searchScreenshots(query: String, in screenshots: [Screenshot], filters: SearchFilters) -> [Screenshot] {
        // First apply the basic search
        var results = searchScreenshots(query: query, in: screenshots)
        
        // Apply date filter
        results = results.filter { screenshot in
            filters.dateRange.predicate(screenshot.timestamp)
        }
        
        // Apply text content filter
        if let hasText = filters.hasText {
            results = results.filter { screenshot in
                let hasExtractedText = screenshot.extractedText?.isEmpty == false
                return hasText ? hasExtractedText : !hasExtractedText
            }
        }
        
        // Apply sort order
        switch filters.sortOrder {
        case .relevance:
            // Already sorted by relevance in the basic search
            break
        case .newest:
            results.sort { $0.timestamp > $1.timestamp }
        case .oldest:
            results.sort { $0.timestamp < $1.timestamp }
        }
        
        return results
    }
}

#Preview {
    SearchFiltersView(
        filters: .constant(SearchFilters()),
        isPresented: .constant(true)
    )
}