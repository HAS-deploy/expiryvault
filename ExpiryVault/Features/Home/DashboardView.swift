import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.analytics) private var analytics
    @Query(sort: \TrackedItem.expirationDate, order: .forward) private var items: [TrackedItem]

    let requestPaywall: (PaywallTrigger) -> Void

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty { emptyState } else { dashboard }
            }
            .navigationTitle("ExpiryVault")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { attemptAdd(trigger: .dashboard) } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                        .accessibilityLabel("Add item")
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack { ItemEditView(item: nil) }
            }
        }
    }

    // MARK: Sections

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Nothing tracked yet").font(.title2.weight(.semibold))
            Text("Add your passport, license, warranty — anything with an expiration date and we'll remind you before it runs out.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button {
                attemptAdd(trigger: .emptyState)
            } label: {
                Label("Add your first item", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dashboard: some View {
        List {
            summarySection
            upcomingSection
            expiredSection
        }
        .listStyle(.insetGrouped)
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 16) {
                summaryCard(title: "Tracked", value: "\(items.count)", color: .secondary)
                summaryCard(title: "Expiring", value: "\(items.filter(\.expiresWithin30Days).count)", color: .orange)
                summaryCard(title: "Expired", value: "\(items.filter(\.isExpired).count)", color: .red)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        let upcoming = items.filter { !$0.isExpired && $0.expiresWithin30Days }
        if !upcoming.isEmpty {
            Section("Expiring in 30 days") {
                ForEach(upcoming) { ItemRow(item: $0) }
            }
        }
    }

    @ViewBuilder
    private var expiredSection: some View {
        let expired = items.filter(\.isExpired)
        if !expired.isEmpty {
            Section("Expired") {
                ForEach(expired) { ItemRow(item: $0) }
            }
        }
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.largeTitle.weight(.bold)).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: Actions

    private func attemptAdd(trigger: TriggerSource) {
        if !entitlements.hasPlusAccess && items.count >= PricingConfig.freeItemLimit {
            analytics.track(.freeLimitHit, properties: ["trigger_source": .source(trigger)])
            requestPaywall(.hardLimit)
            return
        }
        showingAdd = true
    }
}
