import SwiftUI

struct VirtualizedGridView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: [GridItem]
    let itemHeight: CGFloat
    let content: (Item) -> Content
    @Binding var scrollOffset: CGFloat
    @State private var localScrollOffset: CGFloat = 0
    
    // Optional pull-to-refresh message
    var showPullMessage: Bool = false
    var isRefreshing: Bool = false
    var isBulkImportInProgress: Bool = false
    var onRefresh: (() async -> Void)? = nil
    
    @State private var visibleRange: Range<Int> = 0..<0
    @State private var containerHeight: CGFloat = 0
    
    private let overscanBuffer: Int = 5 // Render extra items above/below visible area (reduced for performance)
    
    init(
        items: [Item],
        columns: [GridItem],
        itemHeight: CGFloat,
        scrollOffset: Binding<CGFloat>,
        showPullMessage: Bool = false,
        isRefreshing: Bool = false,
        isBulkImportInProgress: Bool = false,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.columns = columns
        self.itemHeight = itemHeight
        self._scrollOffset = scrollOffset
        self.showPullMessage = showPullMessage
        self.isRefreshing = isRefreshing
        self.isBulkImportInProgress = isBulkImportInProgress
        self.onRefresh = onRefresh
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Invisible header to detect pull
                    GeometryReader { proxy in
                        Color.clear
                            .frame(height: 1)
                            .onChange(of: proxy.frame(in: .global).minY) { _, newValue in
                                localScrollOffset = max(0, newValue - geometry.frame(in: .global).minY)
                            }
                    }
                    .frame(height: 1)
                    
                    // Pull-to-import message (shows when user pulls down)
                    if showPullMessage && localScrollOffset > 10 && !isRefreshing && !isBulkImportInProgress {
                        PullToImportMessageView()
                            .opacity(0.8)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    LazyVStack(spacing: 0) {
                    
                    // Top spacer for items above visible area
                    if visibleRange.lowerBound > 0 {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: CGFloat(visibleRange.lowerBound / columns.count) * (itemHeight + 16))
                    }
                    
                    // Visible items in a single grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(visibleItems), id: \.id) { item in
                            content(item)
                                .frame(height: itemHeight)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    
                    // Bottom spacer for items below visible area
                    if visibleRange.upperBound < items.count {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: CGFloat((items.count - visibleRange.upperBound) / columns.count) * (itemHeight + 16))
                    }
                }
            }
            .refreshable {
                print("📸 VirtualizedGridView: Pull-to-refresh triggered")
                if let onRefresh = onRefresh {
                    print("📸 VirtualizedGridView: Calling onRefresh callback")
                    await onRefresh()
                } else {
                    print("📸 VirtualizedGridView: No onRefresh callback available")
                }
            }
            }
            .onAppear {
                containerHeight = geometry.size.height
                // Initialize with a reasonable range for immediate display
                if visibleRange.isEmpty && !items.isEmpty {
                    let initialCount = min(items.count, 20) // Show first 20 items initially
                    visibleRange = 0..<initialCount
                }
                updateVisibleRange(containerHeight: geometry.size.height)
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                containerHeight = newHeight
                updateVisibleRange(containerHeight: newHeight)
            }
            .onChange(of: items.count) { _, newCount in
                // When items change, ensure we have a visible range
                if visibleRange.isEmpty && newCount > 0 {
                    let initialCount = min(newCount, 20)
                    visibleRange = 0..<initialCount
                }
                updateVisibleRange(containerHeight: containerHeight)
            }
        }
    }
    
    private var visibleItems: ArraySlice<Item> {
        let start = max(0, visibleRange.lowerBound)
        let end = min(items.count, visibleRange.upperBound)
        return items[start..<end]
    }
    
    private func updateVisibleRange(containerHeight: CGFloat) {
        let itemsPerRow = max(1, columns.count) // Ensure at least 1 item per row
        let rowHeight = itemHeight + 16 // Include spacing
        
        // For small to medium collections, show all items to avoid virtualization issues
        if items.count <= 100 || containerHeight < rowHeight * 3 {
            let newRange = 0..<items.count
            if newRange != visibleRange {
                visibleRange = newRange
            }
            return
        }
        
        let visibleRows = Int(ceil(containerHeight / rowHeight))
        let firstVisibleRow = max(0, Int(abs(scrollOffset) / rowHeight))
        
        // Add buffer for smooth scrolling - increased for better experience
        let bufferRows = max(overscanBuffer, visibleRows) // Use larger buffer
        let startRow = max(0, firstVisibleRow - bufferRows)
        let endRow = min(Int(ceil(Double(items.count) / Double(itemsPerRow))), firstVisibleRow + visibleRows + bufferRows)
        
        let newStart = startRow * itemsPerRow
        let newEnd = min(items.count, endRow * itemsPerRow)
        
        let newRange = newStart..<newEnd
        
        // Only update if range actually changed to avoid unnecessary redraws
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
        itemHeight: 160,
        scrollOffset: .constant(0)
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