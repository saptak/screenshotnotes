import SwiftUI

/// Beautiful, fluid error presentation with Glass design and intuitive user feedback
struct ErrorPresentationView: View {
    @ObservedObject var errorHandler: AppErrorHandler
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if let error = errorHandler.currentError {
            ZStack {
                // Glass backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        errorHandler.dismissError()
                    }
                
                // Error card
                ErrorCard(error: error, errorHandler: errorHandler)
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                        removal: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top))
                    ))
            }
        }
    }
}

/// Individual error card with Glass design and contextual actions
private struct ErrorCard: View {
    let error: AppError
    let errorHandler: AppErrorHandler
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Error icon and severity indicator
            HStack(spacing: 12) {
                ErrorIcon(type: error.type, severity: error.severity)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorTitle(for: error))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(severityText(for: error.severity))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(severityColor(for: error.severity))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(severityColor(for: error.severity).opacity(0.15))
                        )
                }
                
                Spacer()
                
                // Dismiss button
                Button(action: {
                    errorHandler.dismissError()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Error description
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Action buttons
            if error.retryStrategy != nil || hasContextualActions(for: error) {
                HStack(spacing: 12) {
                    // Retry button
                    if error.retryStrategy != nil {
                        Button(action: {
                            errorHandler.retryOperation()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Retry")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(.blue.gradient)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Contextual action button
                    if hasContextualActions(for: error) {
                        contextualActionButton(for: error)
                    }
                    
                    Spacer()
                }
            }
            
            // Technical details (collapsible)
            if error.severity == .critical || error.retryAttempt > 0 {
                DisclosureGroup("Technical Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Source", value: error.source)
                        DetailRow(label: "Context", value: error.context.rawValue)
                        DetailRow(label: "Timestamp", value: error.timestamp.formatted())
                        
                        if error.retryAttempt > 0 {
                            DetailRow(label: "Retry Attempt", value: "\(error.retryAttempt)")
                        }
                        
                        if let originalError = error.originalError {
                            DetailRow(label: "Original Error", value: originalError.localizedDescription)
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
            isAnimating = error.severity == .critical
        }
    }
    
    private func errorTitle(for error: AppError) -> String {
        switch error.type {
        case .network(.noConnection):
            return "No Internet Connection"
        case .network(.timeout):
            return "Request Timed Out"
        case .network(.serverError):
            return "Server Error"
        case .network(.invalidResponse):
            return "Invalid Response"
        case .network(.rateLimited):
            return "Rate Limited"
        case .data(.corruptedData):
            return "Data Corruption Detected"
        case .data(.invalidFormat):
            return "Invalid Data Format"
        case .data(.missingData):
            return "Missing Data"
        case .data(.encodingFailed):
            return "Save Failed"
        case .data(.decodingFailed):
            return "Load Failed"
        case .permission(.photoLibraryDenied):
            return "Photo Access Required"
        case .permission(.cameraAccess):
            return "Camera Access Required"
        case .permission(.accessDenied):
            return "Access Denied"
        case .permission(.insufficientPermissions):
            return "Insufficient Permissions"
        case .resource(.memoryPressure):
            return "Low Memory"
        case .resource(.diskSpaceLow):
            return "Low Storage"
        case .resource(.thermalThrottling):
            return "Device Overheating"
        case .resource(.processingOverload):
            return "System Overloaded"
        case .unknown:
            return "Unexpected Error"
        }
    }
    
    private func severityText(for severity: ErrorSeverity) -> String {
        switch severity {
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .critical:
            return "Critical"
        }
    }
    
    private func severityColor(for severity: ErrorSeverity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
    
    private func hasContextualActions(for error: AppError) -> Bool {
        switch error.type {
        case .permission:
            return true
        case .resource(.diskSpaceLow):
            return true
        default:
            return false
        }
    }
    
    @ViewBuilder
    private func contextualActionButton(for error: AppError) -> some View {
        switch error.type {
        case .permission:
            Button(action: {
                Task {
                    await PermissionManager.shared.showPhotoLibrarySettings()
                }
                errorHandler.dismissError()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Settings")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.green.gradient)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
        case .resource(.diskSpaceLow):
            Button(action: {
                Task {
                    await StorageManager.shared.showStorageManagement()
                }
                errorHandler.dismissError()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Manage Storage")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.orange.gradient)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
        default:
            EmptyView()
        }
    }
}

/// Error icon with appropriate visual representation
private struct ErrorIcon: View {
    let type: ErrorType
    let severity: ErrorSeverity
    
    var body: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor.gradient)
                .frame(width: 44, height: 44)
            
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var iconName: String {
        switch type {
        case .network(.noConnection):
            return "wifi.slash"
        case .network(.timeout):
            return "clock.badge.exclamationmark"
        case .network:
            return "network.slash"
        case .data(.corruptedData):
            return "exclamationmark.triangle.fill"
        case .data:
            return "doc.badge.exclamationmark"
        case .permission:
            return "lock.shield"
        case .resource(.memoryPressure):
            return "memorychip"
        case .resource(.diskSpaceLow):
            return "externaldrive.badge.exclamationmark"
        case .resource(.thermalThrottling):
            return "thermometer.high"
        case .resource(.processingOverload):
            return "cpu"
        case .unknown:
            return "questionmark.diamond"
        }
    }
    
    private var iconBackgroundColor: Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
}

/// Technical detail row for error information
private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Error History View

struct ErrorHistoryView: View {
    @ObservedObject var errorHandler: AppErrorHandler
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if errorHandler.errorHistory.isEmpty {
                    ContentUnavailableView(
                        "No Error History",
                        systemImage: "checkmark.shield",
                        description: Text("No errors have occurred recently.")
                    )
                } else {
                    ForEach(errorHandler.errorHistory) { record in
                        ErrorHistoryRow(record: record)
                    }
                }
            }
            .navigationTitle("Error History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        errorHandler.clearErrorHistory()
                    }
                    .disabled(errorHandler.errorHistory.isEmpty)
                }
            }
        }
    }
}

private struct ErrorHistoryRow: View {
    let record: ErrorRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ErrorIcon(type: record.error.type, severity: record.error.severity)
                    .scaleEffect(0.7)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(errorTitle(for: record.error))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(record.error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(severityText(for: record.error.severity))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(severityColor(for: record.error.severity))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(severityColor(for: record.error.severity).opacity(0.15))
                        )
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func errorTitle(for error: AppError) -> String {
        // Reuse the same logic from ErrorCard
        switch error.type {
        case .network(.noConnection):
            return "No Internet Connection"
        case .network(.timeout):
            return "Request Timed Out"
        case .network(.serverError):
            return "Server Error"
        case .network(.invalidResponse):
            return "Invalid Response"
        case .network(.rateLimited):
            return "Rate Limited"
        case .data(.corruptedData):
            return "Data Corruption Detected"
        case .data(.invalidFormat):
            return "Invalid Data Format"
        case .data(.missingData):
            return "Missing Data"
        case .data(.encodingFailed):
            return "Save Failed"
        case .data(.decodingFailed):
            return "Load Failed"
        case .permission(.photoLibraryDenied):
            return "Photo Access Required"
        case .permission(.cameraAccess):
            return "Camera Access Required"
        case .permission(.accessDenied):
            return "Access Denied"
        case .permission(.insufficientPermissions):
            return "Insufficient Permissions"
        case .resource(.memoryPressure):
            return "Low Memory"
        case .resource(.diskSpaceLow):
            return "Low Storage"
        case .resource(.thermalThrottling):
            return "Device Overheating"
        case .resource(.processingOverload):
            return "System Overloaded"
        case .unknown:
            return "Unexpected Error"
        }
    }
    
    private func severityText(for severity: ErrorSeverity) -> String {
        switch severity {
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .critical:
            return "Critical"
        }
    }
    
    private func severityColor(for severity: ErrorSeverity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
}

#if DEBUG
#Preview("Error Presentation") {
    ErrorPresentationView(errorHandler: AppErrorHandler.shared)
        .onAppear {
            let sampleError = AppError(
                type: .network(.noConnection),
                context: .photoImport,
                severity: .error,
                source: "PhotoLibraryService",
                originalError: nil,
                retryAttempt: 0,
                timestamp: Date(),
                recoveryStrategy: nil,
                retryStrategy: nil,
                requiresUserFeedback: true
            )
            AppErrorHandler.shared.currentError = sampleError
            AppErrorHandler.shared.isShowingError = true
        }
}

#Preview("Error History") {
    ErrorHistoryView(errorHandler: AppErrorHandler.shared)
}
#endif