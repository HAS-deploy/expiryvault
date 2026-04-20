import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.analytics) private var analytics
    @Query private var items: [TrackedItem]

    @State private var presentedPaywall: PaywallTrigger?

    var body: some View {
        Group {
            if appState.onboardingCompleted {
                MainTabView(requestPaywall: { presentedPaywall = $0 })
            } else {
                OnboardingView()
            }
        }
        .sheet(item: $presentedPaywall) { trigger in
            PaywallView(trigger: trigger, dismiss: { presentedPaywall = nil })
        }
        .onAppear(perform: maybeShowSoftUpsell)
        .onChange(of: appState.sessionCount) { _, _ in maybeShowSoftUpsell() }
    }

    private func maybeShowSoftUpsell() {
        guard appState.onboardingCompleted else { return }
        if appState.shouldShowSoftUpsell(isPremium: entitlements.isPremium, itemCount: items.count) {
            presentedPaywall = .softUpsell
            appState.softUpsellShown = true
        }
    }
}

struct MainTabView: View {
    let requestPaywall: (PaywallTrigger) -> Void

    var body: some View {
        TabView {
            DashboardView(requestPaywall: requestPaywall)
                .tabItem { Label("Home", systemImage: "house.fill") }

            ItemListView(requestPaywall: requestPaywall)
                .tabItem { Label("Items", systemImage: "list.bullet.clipboard") }

            SettingsView(requestPaywall: requestPaywall)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
