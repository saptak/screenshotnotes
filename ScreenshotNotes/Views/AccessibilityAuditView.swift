//
//  AccessibilityAuditView.swift
//  ScreenshotNotes
//
//  Sprint 8.1.4: Accessibility Audit and Compliance Reporting
//  Created by Assistant on 7/13/25.
//

import SwiftUI

/// Comprehensive accessibility audit view for Liquid Glass system
/// Provides detailed accessibility reporting and compliance information
struct AccessibilityAuditView: View {
    @StateObject private var accessibilityService = LiquidGlassAccessibilityService.shared
    @State private var validationResult: AccessibilityValidationResult?
    @State private var isLoading = false
    @State private var showingDetailReport = false
    @State private var reportText = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Accessibility Level Section
                Section {
                    accessibilityLevelCard
                } header: {
                    Text("Current Accessibility Level")
                } footer: {
                    Text("Accessibility level is automatically determined based on your system settings and enabled features.")
                }
                
                // Compliance Testing Section
                Section {
                    complianceTestingCard
                } header: {
                    Text("Accessibility Compliance Testing")
                } footer: {
                    Text("Comprehensive testing ensures Liquid Glass meets WCAG AA standards.")
                }
                
                // Test Results Section
                if let validation = validationResult {
                    Section {
                        testResultsList(validation: validation)
                    } header: {
                        Text("Test Results")
                    } footer: {
                        Text("Individual test results show compliance with different accessibility standards.")
                    }
                }
                
                // System Settings Section
                Section {
                    systemSettingsCard
                } header: {
                    Text("System Accessibility Settings")
                } footer: {
                    Text("These settings are automatically detected from your system preferences.")
                }
                
                // Recommendations Section
                if let validation = validationResult, !validation.recommendations.isEmpty {
                    Section {
                        recommendationsList(recommendations: validation.recommendations)
                    } header: {
                        Text("Recommendations")
                    } footer: {
                        Text("Suggestions for improving accessibility compliance.")
                    }
                }
                
                // Export Section
                Section {
                    exportControls
                } header: {
                    Text("Export Report")
                } footer: {
                    Text("Generate detailed accessibility report for documentation or compliance purposes.")
                }
            }
            .navigationTitle("Accessibility Audit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Refresh") {
                        runAccessibilityAudit()
                    }
                    .disabled(isLoading)
                }
            }
            .refreshable {
                runAccessibilityAudit()
            }
            .sheet(isPresented: $showingDetailReport) {
                DetailReportView(reportText: reportText)
            }
        }
        .onAppear {
            runAccessibilityAudit()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Accessibility Audit")
        .accessibilityHint("Review accessibility compliance and system settings")
    }
    
    // MARK: - Accessibility Level Card
    
    @ViewBuilder
    private var accessibilityLevelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "accessibility")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility Level")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(accessibilityService.accessibilityLevel.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                levelBadge
            }
            
            Text(GlassDescriptions.accessibilityLevelDescription(
                level: accessibilityService.accessibilityLevel
            ))
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(GlassDescriptions.accessibilityLevelDescription(
            level: accessibilityService.accessibilityLevel
        ))
    }
    
    @ViewBuilder
    private var levelBadge: some View {
        let level = accessibilityService.accessibilityLevel
        let color = switch level {
        case .standard: Color.gray
        case .enhanced: Color.blue
        case .maximum: Color.green
        }
        
        Text(level.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Compliance Testing Card
    
    @ViewBuilder
    private var complianceTestingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compliance Testing")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let validation = validationResult {
                        Text("Score: \(validation.overallScore)/100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not tested")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Run Tests") {
                        runAccessibilityAudit()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            if let validation = validationResult {
                ComplianceBadge(level: validation.complianceLevel)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(validationResult?.complianceLevel.description ?? "Compliance not tested")
    }
    
    // MARK: - Test Results List
    
    @ViewBuilder
    private func testResultsList(validation: AccessibilityValidationResult) -> some View {
        ForEach(validation.testResults, id: \.testName) { result in
            HStack {
                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.passed ? .green : .red)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.testName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(result.score)/100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(result.passed ? "Pass" : "Fail")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((result.passed ? Color.green : Color.red).opacity(0.1))
                    .foregroundColor(result.passed ? .green : .red)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(GlassDescriptions.performanceMetricDescription(
                title: result.testName,
                value: "\(result.score)/100",
                isOptimal: result.passed
            ))
        }
    }
    
    // MARK: - System Settings Card
    
    @ViewBuilder
    private var systemSettingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SystemSettingRow(
                title: "Reduce Transparency",
                isEnabled: accessibilityService.isReduceTransparencyEnabled,
                icon: "eye.slash"
            )
            
            SystemSettingRow(
                title: "Increase Contrast",
                isEnabled: accessibilityService.isDarkerSystemColorsEnabled,
                icon: "circle.lefthalf.fill"
            )
            
            SystemSettingRow(
                title: "Reduce Motion",
                isEnabled: accessibilityService.isReduceMotionEnabled,
                icon: "arrow.clockwise"
            )
            
            SystemSettingRow(
                title: "VoiceOver",
                isEnabled: accessibilityService.isVoiceOverRunning,
                icon: "speaker.wave.2"
            )
            
            SystemSettingRow(
                title: "Switch Control",
                isEnabled: accessibilityService.isSwitchControlRunning,
                icon: "switch.2"
            )
            
            SystemSettingRow(
                title: "Bold Text",
                isEnabled: accessibilityService.isBoldTextEnabled,
                icon: "bold"
            )
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Recommendations List
    
    @ViewBuilder
    private func recommendationsList(recommendations: [String]) -> some View {
        ForEach(recommendations, id: \.self) { recommendation in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text(recommendation)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Recommendation: \(recommendation)")
        }
    }
    
    // MARK: - Export Controls
    
    @ViewBuilder
    private var exportControls: some View {
        VStack(spacing: 12) {
            Button(action: generateDetailReport) {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generate Full Report")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Detailed accessibility compliance report")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Generate detailed accessibility report")
            .accessibilityHint("Double tap to create comprehensive accessibility report")
            
            Button(action: shareReport) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share Report")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Export report for documentation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Share accessibility report")
            .accessibilityHint("Double tap to share report via system share sheet")
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    
    private func runAccessibilityAudit() {
        isLoading = true
        
        // Run accessibility validation
        Task { @MainActor in
            // Simulate processing time for realistic UX
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let validation = accessibilityService.validateAccessibilityCompliance()
            self.validationResult = validation
            self.isLoading = false
            
            // Announce completion for VoiceOver users
            UIAccessibility.post(
                notification: .announcement,
                argument: "Accessibility audit completed. Score: \(validation.overallScore) out of 100."
            )
        }
    }
    
    private func generateDetailReport() {
        reportText = accessibilityService.generateAccessibilityReport()
        showingDetailReport = true
    }
    
    private func shareReport() {
        let reportText = accessibilityService.generateAccessibilityReport()
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [reportText],
            applicationActivities: nil
        )
        
        window.rootViewController?.present(activityVC, animated: true)
    }
}

// MARK: - Helper Views

struct ComplianceBadge: View {
    let level: AccessibilityComplianceLevel
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundColor(level.color)
            
            Text(level.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(level.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(level.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var iconName: String {
        switch level {
        case .excellent: return "star.fill"
        case .good: return "checkmark.circle.fill"
        case .acceptable: return "exclamationmark.triangle.fill"
        case .needsImprovement: return "xmark.circle.fill"
        }
    }
}

struct SystemSettingRow: View {
    let title: String
    let isEnabled: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isEnabled ? .green : .gray)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(isEnabled ? "On" : "Off")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isEnabled ? .green : .gray)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(isEnabled ? "On" : "Off")")
    }
}

struct DetailReportView: View {
    let reportText: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(reportText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Accessibility Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Share") {
                        shareReport()
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Detailed accessibility report")
    }
    
    private func shareReport() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [reportText],
            applicationActivities: nil
        )
        
        window.rootViewController?.present(activityVC, animated: true)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Accessibility Audit") {
    AccessibilityAuditView()
}
#endif 