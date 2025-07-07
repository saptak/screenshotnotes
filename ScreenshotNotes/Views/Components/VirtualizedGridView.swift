import SwiftUI

struct VirtualizedGridView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: [GridItem]
    let itemHeight: CGFloat
    let content: (Item) -> Content
    
    @State private var visibleRange: Range<Int> = 0..<0
    @State private var containerHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    
    private let overscanBuffer: Int = 10 // Render extra items above/below visible area
    
    init(
        items: [Item],
        columns: [GridItem],
        itemHeight: CGFloat,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.columns = columns
        self.itemHeight = itemHeight
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Top spacer for items above visible area
                    if visibleRange.lowerBound > 0 {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: CGFloat(visibleRange.lowerBound / columns.count) * (itemHeight + 16))
                    }
                    
                    // Visible items
                    ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                        LazyVGrid(columns: columns, spacing: 16) {
                            content(item)
                                .frame(height: itemHeight)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    
                    // Bottom spacer for items below visible area
                    if visibleRange.upperBound < items.count {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: CGFloat((items.count - visibleRange.upperBound) / columns.count) * (itemHeight + 16))
                    }
                }
                .background(
                    GeometryReader { scrollGeometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: scrollGeometry.frame(in: .named("scrollView")).origin.y)
                    }
                )
            }
            .coordinateSpace(name: "scrollView")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                scrollOffset = -offset
                updateVisibleRange(containerHeight: geometry.size.height)
            }
            .onAppear {
                containerHeight = geometry.size.height
                updateVisibleRange(containerHeight: geometry.size.height)
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                containerHeight = newHeight
                updateVisibleRange(containerHeight: newHeight)
            }
        }
    }
    
    private var visibleItems: ArraySlice<Item> {
        let start = max(0, visibleRange.lowerBound)
        let end = min(items.count, visibleRange.upperBound)
        return items[start..<end]
    }
    
    private func updateVisibleRange(containerHeight: CGFloat) {
        let itemsPerRow = columns.count
        let rowHeight = itemHeight + 16 // Include spacing
        
        let visibleRows = Int(ceil(containerHeight / rowHeight))
        let firstVisibleRow = max(0, Int(scrollOffset / rowHeight))
        
        // Add buffer for smooth scrolling
        let startRow = max(0, firstVisibleRow - overscanBuffer)
        let endRow = min(Int(ceil(Double(items.count) / Double(itemsPerRow))), firstVisibleRow + visibleRows + overscanBuffer)
        
        let newStart = startRow * itemsPerRow
        let newEnd = min(items.count, endRow * itemsPerRow)
        
        let newRange = newStart..<newEnd
        
        if newRange != visibleRange {
            visibleRange = newRange
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    let sampleItems = (0..<1000).map { index in
        PreviewItem(id: index, name: "Item \(index)")
    }
    
    VirtualizedGridView(
        items: sampleItems,
        columns: [
            GridItem(.adaptive(minimum: 160), spacing: 16)
        ],
        itemHeight: 160
    ) { item in
        VStack {
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: 120)
            Text(item.name)
                .font(.caption)
        }
        .background(Color.white)
        .cornerRadius(8)
    }
}

private struct PreviewItem: Identifiable {
    let id: Int
    let name: String
}