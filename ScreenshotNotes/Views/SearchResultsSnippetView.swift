//
//  SearchResultsSnippetView.swift
//  ScreenshotNotes
//
//  Created by Assistant on 7/5/25.
//

import AppIntents
import SwiftUI

/// Snippet view for displaying search results in Siri
@available(iOS 16.0, *)
struct SearchResultsSnippetView: View {
    let query: String
    let results: [ScreenshotEntity]
    let searchType: SearchTypeEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                Text("Screenshot Search")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // Query info
            VStack(alignment: .leading, spacing: 4) {
                Text("Query: \"\(query)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Type: \(searchType.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Results summary
            HStack {
                Image(systemName: "doc.text.image")
                    .foregroundColor(.green)
                Text("\(results.count) screenshots found")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            // Results preview (first few items)
            if !results.isEmpty {
                Divider()
                
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(results.prefix(3), id: \.id) { result in
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.displayString)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text(formatDate(result.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    if results.count > 3 {
                        Text("+ \(results.count - 3) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 28)
                    }
                }
            }
            
            // Action button
            HStack {
                Spacer()
                Text("Open Screenshot Vault")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
