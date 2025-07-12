//
//  BulkImportStatusView.swift
//  ScreenshotNotes
//
//  Created by Assistant on 7/12/25.
//

import SwiftUI

struct BulkImportStatusView: View {
    @ObservedObject var coordinator: BulkImportCoordinator
    
    var body: some View {
        VStack(spacing: 12) {
            if coordinator.isImportInProgress {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        .scaleEffect(0.8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(coordinator.currentPhase.description)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if coordinator.progress.total > 0 {
                            HStack {
                                Text("\(coordinator.progress.imported)/\(coordinator.progress.total) imported")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if coordinator.progress.needsProcessing > 0 {
                                    Text("• \(coordinator.progress.processed)/\(coordinator.progress.needsProcessing) processed")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(Int(coordinator.progress.percentage * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.quaternary, lineWidth: 0.5)
                        )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            if coordinator.blockedAttempts > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    
                    Text("Import in progress - \(coordinator.blockedAttempts) blocked attempts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.orange.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.isImportInProgress)
        .animation(.easeInOut(duration: 0.3), value: coordinator.blockedAttempts)
    }
}

#if DEBUG
#Preview("Bulk Import Status - Importing") {
    struct PreviewWrapper: View {
        @StateObject private var coordinator = BulkImportCoordinator.shared
        
        var body: some View {
            VStack(spacing: 20) {
                BulkImportStatusView(coordinator: coordinator)
                    .padding()
                
                Button("Simulate Import") {
                    coordinator.isImportInProgress = true
                    coordinator.currentPhase = .importing
                    coordinator.progress = BulkImportCoordinator.ImportProgress()
                    coordinator.progress.imported = 5
                    coordinator.progress.total = 20
                    coordinator.progress.needsProcessing = 15
                    coordinator.progress.processed = 2
                }
                
                Button("Simulate Processing") {
                    coordinator.currentPhase = .processing
                    coordinator.progress.processed = 12
                }
                
                Button("Block Attempt") {
                    coordinator.blockedAttempts += 1
                }
                
                Button("Reset") {
                    coordinator.isImportInProgress = false
                    coordinator.currentPhase = .idle
                    coordinator.progress = BulkImportCoordinator.ImportProgress()
                    coordinator.blockedAttempts = 0
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    return PreviewWrapper()
}
#endif