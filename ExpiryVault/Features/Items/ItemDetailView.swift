import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics
    let item: TrackedItem

    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section { countdownCard.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }

            Section("Item") {
                row("Name", item.name)
                row("Category", item.category.title)
                if !item.ownerName.isEmpty { row("Owner", item.ownerName) }
                row("Expires", item.expirationDate.formatted(date: .long, time: .omitted))
                if !item.referenceCode.isEmpty { row("Reference", item.referenceCode) }
            }
            if !item.notes.isEmpty {
                Section("Notes") { Text(item.notes) }
            }
            Section("Reminders") {
                if item.remindersEnabled, !item.reminderOffsets.isEmpty {
                    ForEach(item.reminderOffsets) { offset in
                        Label(offset.title, systemImage: "bell.fill").foregroundStyle(.primary)
                    }
                } else {
                    Text("Off").foregroundStyle(.secondary)
                }
            }
            Section {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete item", systemImage: "trash")
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            NavigationStack { ItemEditView(item: item) }
        }
        .confirmationDialog("Delete this item?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reminders will be removed. This can't be undone.")
        }
        .onAppear {
            analytics.track(.itemViewed, properties: ["category": .category(.init(item.category))])
        }
    }

    private var countdownCard: some View {
        let days = item.daysUntilExpiration()
        let color: Color = days < 0 ? .red : days <= 7 ? .orange : days <= 30 ? .yellow : .green
        let label: String = {
            if days < 0 { return "Expired \(abs(days)) day\(abs(days) == 1 ? "" : "s") ago" }
            if days == 0 { return "Expires today" }
            return "\(days) day\(days == 1 ? "" : "s") remaining"
        }()
        return VStack(alignment: .leading, spacing: 8) {
            Label(item.category.title, systemImage: item.category.symbol)
                .font(.caption)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(item.category.tint.opacity(0.18)))
                .foregroundStyle(item.category.tint)
            Text(label).font(.title2.weight(.bold)).foregroundStyle(color)
            Text(item.expirationDate.formatted(date: .long, time: .omitted))
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        .padding(.horizontal, 16).padding(.vertical, 4)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    private func delete() async {
        let id = item.id
        let category = item.category
        context.delete(item)
        try? context.save()
        analytics.track(.itemDeleted, properties: ["category": .category(.init(category))])
        await NotificationService.shared.cancel(for: id)
        dismiss()
    }
}
