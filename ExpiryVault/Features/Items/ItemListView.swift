import SwiftUI
import SwiftData

struct ItemListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.analytics) private var analytics
    @Query(sort: \TrackedItem.expirationDate, order: .forward) private var allItems: [TrackedItem]

    let requestPaywall: (PaywallTrigger) -> Void

    @State private var searchText: String = ""
    @State private var selectedCategory: ItemCategory?
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if allItems.isEmpty {
                    ContentUnavailableView(
                        "No items yet",
                        systemImage: "tray",
                        description: Text("Add your first item from the Home tab."),
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Items")
            .searchable(text: $searchText, prompt: "Search items")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { attemptAdd() } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add item")
                }
                ToolbarItem(placement: .topBarLeading) { categoryMenu }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack { ItemEditView(item: nil) }
            }
        }
    }

    // MARK: List

    @ViewBuilder
    private var list: some View {
        let filtered = applyFilters(to: allItems)
        if filtered.isEmpty {
            ContentUnavailableView.search
        } else {
            List {
                ForEach(ExpiryGroup.allCases) { group in
                    let section = filtered.filter { $0.group == group }
                    if !section.isEmpty {
                        Section(group.title) {
                            ForEach(section) { ItemRow(item: $0) }
                                .onDelete { offsets in delete(offsets, from: section) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var categoryMenu: some View {
        Menu {
            Button {
                selectedCategory = nil
            } label: {
                Label("All categories", systemImage: selectedCategory == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(ItemCategory.allCases) { cat in
                Button {
                    selectedCategory = cat
                } label: {
                    Label(cat.title, systemImage: selectedCategory == cat ? "checkmark" : cat.symbol)
                }
            }
        } label: {
            Image(systemName: selectedCategory == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .accessibilityLabel("Filter by category")
        }
    }

    // MARK: Filters

    private func applyFilters(to items: [TrackedItem]) -> [TrackedItem] {
        var out = items
        if let cat = selectedCategory {
            out = out.filter { $0.category == cat }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            out = out.filter { $0.name.lowercased().contains(q)
                || $0.ownerName.lowercased().contains(q)
                || $0.notes.lowercased().contains(q)
            }
        }
        return out
    }

    private func attemptAdd() {
        if !entitlements.hasPlusAccess && allItems.count >= PricingConfig.freeItemLimit {
            analytics.track(.freeLimitHit, properties: ["trigger_source": .source(.list)])
            requestPaywall(.hardLimit)
            return
        }
        showingAdd = true
    }

    private func delete(_ offsets: IndexSet, from section: [TrackedItem]) {
        for index in offsets {
            let item = section[index]
            let id = item.id
            let category = item.category
            context.delete(item)
            analytics.track(.itemDeleted, properties: ["category": .category(.init(category))])
            Task { await NotificationService.shared.cancel(for: id) }
        }
        try? context.save()
    }
}
