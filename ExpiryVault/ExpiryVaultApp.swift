import SwiftUI
import SwiftData

@main
struct ExpiryVaultApp: App {
    @StateObject private var entitlements: EntitlementStore
    @StateObject private var purchases: PurchaseManager
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    let analytics = AnalyticsService.local

    init() {
        let ent = EntitlementStore()
        _entitlements = StateObject(wrappedValue: ent)
        _purchases = StateObject(wrappedValue: PurchaseManager(entitlements: ent))
        PortfolioAnalytics.shared.start(appName: "expiryvault")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(entitlements)
                .environmentObject(purchases)
                .environmentObject(appState)
                .environment(\.analytics, analytics)
                .modelContainer(for: [TrackedItem.self])
                .task { purchases.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                analytics.track(.appOpen)
                PortfolioAnalytics.shared.track(PortfolioEvent.sessionStart)
                appState.incrementSessionCount()
            }
        }
    }
}

/// Tiny app-scope state kept in UserDefaults. Anything bigger lives in SwiftData.
@MainActor
final class AppState: ObservableObject {
    private enum Keys {
        static let onboardingCompleted = "ev.onboardingCompleted"
        static let sessionCount = "ev.sessionCount"
        static let softUpsellShown = "ev.softUpsellShown"
    }

    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted) }
    }
    @Published var sessionCount: Int {
        didSet { defaults.set(sessionCount, forKey: Keys.sessionCount) }
    }
    @Published var softUpsellShown: Bool {
        didSet { defaults.set(softUpsellShown, forKey: Keys.softUpsellShown) }
    }

    private let defaults = UserDefaults.standard

    init() {
        self.onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
        self.sessionCount = defaults.integer(forKey: Keys.sessionCount)
        self.softUpsellShown = defaults.bool(forKey: Keys.softUpsellShown)
    }

    func incrementSessionCount() { sessionCount += 1 }

    /// Fire the soft upsell once, on a session where the user isn't already
    /// premium and has enough items to make the pitch meaningful.
    func shouldShowSoftUpsell(isPremium: Bool, itemCount: Int) -> Bool {
        guard !isPremium, !softUpsellShown else { return false }
        return sessionCount >= PricingConfig.softUpsellSessionThreshold
            && itemCount >= PricingConfig.softUpsellMinItems
    }
}
