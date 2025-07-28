//
//  PaginatedList.swift
//  Momentum
//
//  Efficient pagination for large lists
//

import SwiftUI
import CoreData

struct PaginatedList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let pageSize: Int
    let content: (Item) -> Content
    
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    
    init(items: [Item], pageSize: Int = 20, @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.pageSize = pageSize
        self.content = content
    }
    
    private var displayedItems: [Item] {
        let endIndex = min((currentPage + 1) * pageSize, items.count)
        return Array(items.prefix(endIndex))
    }
    
    private var hasMoreItems: Bool {
        displayedItems.count < items.count
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedItems) { item in
                    content(item)
                        .onAppear {
                            // Load more when reaching the last few items
                            if displayedItems.last?.id == item.id && hasMoreItems {
                                loadMore()
                            }
                        }
                }
                
                // Loading indicator
                if isLoadingMore {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                        Text("Loading more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                
                // End of list indicator
                if !hasMoreItems && items.count > pageSize {
                    Text("End of list")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }
    
    private func loadMore() {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        
        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                currentPage += 1
                isLoadingMore = false
            }
        }
    }
}

// Extension for FetchRequest integration
extension PaginatedList {
    init<T: NSManagedObject>(
        fetchRequest: FetchRequest<T>,
        pageSize: Int = 20,
        @ViewBuilder content: @escaping (T) -> Content
    ) where Item == T {
        self.init(
            items: fetchRequest.wrappedValue.map { $0 },
            pageSize: pageSize,
            content: content
        )
    }
}

// Paginated fetch request modifier
struct PaginatedFetchModifier: ViewModifier {
    let pageSize: Int
    @State private var fetchLimit: Int
    
    init(pageSize: Int = 20) {
        self.pageSize = pageSize
        self._fetchLimit = State(initialValue: pageSize)
    }
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Initial fetch limit
                fetchLimit = pageSize
            }
    }
}

extension View {
    func paginated(pageSize: Int = 20) -> some View {
        modifier(PaginatedFetchModifier(pageSize: pageSize))
    }
}

#Preview {
    struct PreviewItem: Identifiable {
        let id = UUID()
        let title: String
    }
    
    let items = (0..<100).map { PreviewItem(title: "Item \($0)") }
    
    return PaginatedList(items: items, pageSize: 10) { item in
        HStack {
            Text(item.title)
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}