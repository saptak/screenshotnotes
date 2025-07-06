
import SwiftUI

/// UI entity for extracted text display (not the model's ExtractedEntity)
public struct ExtractedTextView: View {
    public struct Entity: Identifiable, Hashable {
        public enum EntityType: String, CaseIterable, Hashable {
            case url, phone, email, date, price, address, person, organization, other
            var displayName: String {
                switch self {
                case .url: return "URL"
                case .phone: return "Phone"
                case .email: return "Email"
                case .date: return "Date"
                case .price: return "Price"
                case .address: return "Address"
                case .person: return "Person"
                case .organization: return "Organization"
                case .other: return "Other"
                }
            }
        }
        public let id: UUID
        public let text: String
        public let type: EntityType
        public init(_id: UUID, text: String, type: EntityType) {
            self.id = _id
            self.text = text
            self.type = type
        }
    }

    public let text: String
    public let entities: [Entity]?
    public let onCopy: ((String) -> Void)?
    @State private var showCopied: Bool = false

    public init(text: String, entities: [Entity]? = nil, onCopy: ((String) -> Void)? = nil) {
        self.text = text
        self.entities = entities
        self.onCopy = onCopy
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.vertical, showsIndicators: true) {
                selectableTextView
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
            }
            if showCopied {
                Label("Copied!", systemImage: "doc.on.doc.fill")
                    .font(.caption.bold())
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundColor(.accentColor)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.trailing, 24)
                    .padding(.top, 12)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showCopied)
    }

    @ViewBuilder
    private var selectableTextView: some View {
        if let entities, !entities.isEmpty {
            // Rich text with entity highlighting and copy buttons
            let filteredEntities = entities.filter { $0.text.count >= 4 }
            if !filteredEntities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredEntities) { entity in
                        HStack(alignment: .center, spacing: 8) {
                            highlightedText(for: entity)
                            Spacer(minLength: 0)
                            Button(action: {
                                UIPasteboard.general.string = entity.text
                                showCopied = true
                                onCopy?(entity.text)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    showCopied = false
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .padding(6)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Copy \(entity.type.displayName): \(entity.text)")
                        }
                    }
                }
            } else {
                Text("No extracted words with at least 4 characters.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            // Fallback: plain selectable text with a copy button
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                Button(action: {
                    UIPasteboard.general.string = text
                    showCopied = true
                    onCopy?(text)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showCopied = false
                    }
                }) {
                    Label("Copy All", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy all extracted text")
            }
        }
    }

    private func highlightedText(for entity: Entity) -> some View {
        HStack(spacing: 4) {
            Text(entity.text)
                .font(.body.weight(.medium))
                .foregroundColor(color(for: entity.type))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color(for: entity.type).opacity(0.12))
                )
            Text(entity.type.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color.secondary.opacity(0.08))
                )
        }
    }

    private func color(for type: Entity.EntityType) -> Color {
        switch type {
        case .url: return .blue
        case .phone: return .green
        case .email: return .purple
        case .date: return .orange
        case .price: return .pink
        case .address: return .teal
        case .person: return .indigo
        case .organization: return .mint
        case .other: return .accentColor
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ExtractedTextView_Previews: PreviewProvider {
    static var previews: some View {
        ExtractedTextView(
            text: "Call John at (555) 123-4567 or email john@example.com. Visit https://apple.com for more info.",
            entities: [
                .init(_id: UUID(), text: "(555) 123-4567", type: .phone),
                .init(_id: UUID(), text: "john@example.com", type: .email),
                .init(_id: UUID(), text: "https://apple.com", type: .url)
            ]
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
