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
        if appState.shouldShowSoftUpsell(hasPlusAccess: entitlements.hasPlusAccess, itemCount: items.count) {
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
                .trackScreen("home")
                .tabItem { Label("Home", systemImage: "house.fill") }

            ItemListView(requestPaywall: requestPaywall)
                .trackScreen("items")
                .tabItem { Label("Items", systemImage: "list.bullet.clipboard") }

            SettingsView(requestPaywall: requestPaywall)
                .trackScreen("settings")
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
