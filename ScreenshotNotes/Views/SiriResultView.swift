//
//  SiriResultView.swift
//  ScreenshotNotes
//
//  Sub-Sprint 5.3.3: Conversational Search UI & Siri Response Interface
//  Created by Assistant on 7/5/25.
//

import SwiftUI
import AppIntents

/// Enhanced result presentation for Siri App Intents with rich visual feedback
struct SiriResultView: View {
    let searchResults: [Screenshot]
    let searchQuery: String
    let searchType: String
    
    @State private var selectedScreenshot: Screenshot?
    @State private var showingDetailView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header with search context
                searchHeaderView
                
                // Results overview
                resultsOverviewView
                
                // Results grid
                if !searchResults.isEmpty {
                    resultsGridView
                } else {
                    emptyStateView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Search Results")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(
                screenshot: screenshot,
                heroNamespace: Namespace().wrappedValue,
                allScreenshots: searchResults,
                onDelete: nil
            )
        }
    }
    
    // MARK: - Search Header
    
    private var searchHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                    .imageScale(.medium)
                
                Text("Siri Search")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Search type indicator
                Text(searchType.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Query display
            HStack {
                Image(systemName: "quote.opening")
                    .foregroundColor(.secondary)
                    .imageScale(.small)
                
                Text(searchQuery)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Image(systemName: "quote.closing")
                    .foregroundColor(.secondary)
                    .imageScale(.small)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // MARK: - Results Overview
    
    private var resultsOverviewView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Found \(searchResults.count) results")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if !searchResults.isEmpty {
                    Text("Tap any screenshot to view details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Quick actions
            if !searchResults.isEmpty {
                Menu {
                    Button("Share All", action: shareAllResults)
                    Button("Export List", action: exportResults)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Results Grid
    
    private var resultsGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150, maximum: 200))
            ], spacing: 16) {
                ForEach(searchResults.prefix(20)) { screenshot in
                    resultCard(screenshot)
                }
            }
            .padding(.top, 8)
        }
    }
    
    private func resultCard(_ screenshot: Screenshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Screenshot thumbnail
            AsyncImage(url: URL(string: "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                            .imageScale(.large)
                    )
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Screenshot info
            VStack(alignment: .leading, spacing: 4) {
                // Timestamp
                Text(screenshot.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Extracted text preview
                if let extractedText = screenshot.extractedText, !extractedText.isEmpty {
                    Text(extractedText)
                        .font(.caption2)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                } else {
                    Text("No text found")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                // Semantic tags
                if !screenshot.searchableTagNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(screenshot.searchableTagNames.prefix(3)), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onTapGesture {
            selectedScreenshot = screenshot
            showingDetailView = true
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Try adjusting your search or check your spelling")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Suggestion buttons
            VStack(spacing: 12) {
                Button("Search All Screenshots") {
                    // Handle search all action
                }
                .buttonStyle(.borderedProminent)
                
                Button("Try Voice Search") {
                    // Handle voice search action  
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
    }
    
    // MARK: - Actions
    
    private func shareAllResults() {
        // Implement sharing functionality
    }
    
    private func exportResults() {
        // Implement export functionality
    }
}

/// Enhanced App Intent result presentation for Siri
@available(iOS 16.0, *)
struct SiriIntentResultView: View {
    let searchResults: [ScreenshotEntity]
    let searchQuery: String
    let searchType: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Siri header
            siriHeaderView
            
            // Results summary
            resultsSummaryView
            
            // Preview grid
            if !searchResults.isEmpty {
                previewGridView
            }
            
            // Action button
            actionButtonView
        }
        .padding()
    }
    
    private var siriHeaderView: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(.blue)
            
            Text("Screenshot Search")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
    
    private var resultsSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Found \(searchResults.count) screenshots")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("for \"\(searchQuery)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var previewGridView: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 80))
        ], spacing: 8) {
            ForEach(Array(searchResults.prefix(6)), id: \.id) { result in
                siriResultCard(result)
            }
        }
    }
    
    private func siriResultCard(_ result: ScreenshotEntity) -> some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                )
                .cornerRadius(6)
            
            if let text = result.extractedText, !text.isEmpty {
                Text(text)
                    .font(.caption2)
                    .lineLimit(1)
            } else {
                Text("Screenshot")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var actionButtonView: some View {
        Button("Open Screenshot Vault") {
            // This will open the main app
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

// MARK: - Preview

struct SiriResultView_Previews: PreviewProvider {
    static var previews: some View {
        SiriResultView(
            searchResults: [],
            searchQuery: "blue dress receipts",
            searchType: "visual"
        )
    }
}
