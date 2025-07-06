
import SwiftUI
import Combine

/// Section for displaying extracted text with entity highlighting and copy actions in ScreenshotDetailView.
struct ExtractedTextSection: View {
    let text: String
    @State private var entities: [ExtractedTextView.Entity] = []
    @State private var isLoading: Bool = true
    @State private var error: String? = nil
    private let entityService = EntityExtractionService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Extracted Text")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
            }
            ExtractedTextView(
                text: text,
                entities: entities,
                onCopy: { copied in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.accentColor.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .onAppear {
            loadEntities()
        }
    }

    private func loadEntities() {
        isLoading = true
        error = nil
        Task {
            let result = await entityService.extractEntities(from: text)
            await MainActor.run {
                if result.isSuccessful {
                    self.entities = result.entities.map {
                        ExtractedTextView.Entity(
                            _id: UUID(),
                            text: $0.text,
                            type: mapType($0.type)
                        )
                    }
                    self.isLoading = false
                } else {
                    self.error = "Could not analyze text."
                    self.isLoading = false
                }
            }
        }
    }

    private func mapType(_ type: EntityType) -> ExtractedTextView.Entity.EntityType {
        switch type {
        case .url: return .url
        case .phoneNumber: return .phone
        case .email: return .email
        case .date: return .date
        case .currency: return .price
        case .person: return .person
        case .organization: return .organization
        case .place: return .address
        default: return .other
        }
    }
}
