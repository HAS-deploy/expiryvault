import SwiftUI

/// Shared list row for items, used on Dashboard and Item List.
struct ItemRow: View {
    let item: TrackedItem

    var body: some View {
        NavigationLink(destination: ItemDetailView(item: item)) {
            HStack(spacing: 12) {
                categoryBadge
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.body.weight(.medium)).lineLimit(1)
                    HStack(spacing: 6) {
                        if !item.ownerName.isEmpty {
                            Text(item.ownerName).font(.caption).foregroundStyle(.secondary)
                            Text("·").foregroundStyle(.secondary)
                        }
                        Text(item.category.title).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                countdown
            }
        }
    }

    private var categoryBadge: some View {
        ZStack {
            Circle().fill(item.category.tint.opacity(0.18)).frame(width: 38, height: 38)
            Image(systemName: item.category.symbol).foregroundStyle(item.category.tint)
        }
    }

    @ViewBuilder
    private var countdown: some View {
        let days = item.daysUntilExpiration()
        VStack(alignment: .trailing, spacing: 0) {
            Text(days < 0 ? "Expired" : days == 0 ? "Today" : "\(days)d")
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(color(for: days))
            Text(item.expirationDate, format: .dateTime.month(.abbreviated).day().year())
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func color(for days: Int) -> Color {
        if days < 0 { return .red }
        if days <= 7 { return .orange }
        if days <= 30 { return Color(red: 0.85, green: 0.62, blue: 0.19) }
        return .primary
    }
}
