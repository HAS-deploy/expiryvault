import Foundation
import Combine
import StoreKit

/// Single source of truth for whether the user has ExpiryVault Plus.
/// Any of the three products — monthly, yearly, lifetime — grant it.
///
/// Plus access is also granted during the install-time trial window
/// (`installTrialActive`). Use `hasPlusAccess` for feature gating; reserve
/// `isPremium` for "is the user a paying subscriber" UI (Settings status
/// label, Manage Subscription affordance, etc).
@MainActor
final class EntitlementStore: ObservableObject {
    @Published private(set) var isPremium: Bool = false
    /// Which product is active right now (for Settings display).
    @Published private(set) var activeProductID: String?
    /// True while the install-time trial is still running. Reactively
    /// recomputed any time `isPremium` flips or the trial elapses.
    @Published private(set) var installTrialActive: Bool = false

    /// UserDefaults key holding the install timestamp.
    static let firstLaunchAtKey = "expiryvault.firstLaunchAt"

    private let defaults: UserDefaults
    private let clock: () -> Date

    init(defaults: UserDefaults = .standard, clock: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.clock = clock
        // Stamp first-launch on the first run that ever sees this app
        // install. After that, the gate computes trial state off the stamp.
        if defaults.object(forKey: Self.firstLaunchAtKey) == nil {
            defaults.set(clock(), forKey: Self.firstLaunchAtKey)
        }
        self.installTrialActive = computeInstallTrialActive()
    }

    /// The day the app was first launched on this device, if recorded.
    var firstLaunchAt: Date? {
        defaults.object(forKey: Self.firstLaunchAtKey) as? Date
    }

    /// Days remaining in the install-time trial. Returns 0 once elapsed
    /// and `.max` for paying subscribers (so callers can skip the math).
    var installTrialDaysRemaining: Int {
        if isPremium { return .max }
        guard let start = firstLaunchAt else { return PricingConfig.annualTrialDays }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: clock()).day ?? 0
        return max(0, PricingConfig.annualTrialDays - elapsed)
    }

    /// True if the user can use Plus features right now — either because
    /// they bought it, or because the install trial hasn't elapsed.
    var hasPlusAccess: Bool {
        isPremium || installTrialActive
    }

    var statusLabel: String {
        if isPremium {
            switch activeProductID {
            case PricingConfig.lifetimeProductID: return "Plus — Lifetime"
            case PricingConfig.yearlyProductID:   return "Plus — Yearly"
            case PricingConfig.monthlyProductID:  return "Plus — Monthly"
            default:                              return "Plus"
            }
        }
        return "Free"
    }

    /// Drop every active entitlement. Call after `AppStore.sync()` so we recompute.
    func reset() {
        isPremium = false
        activeProductID = nil
        installTrialActive = computeInstallTrialActive()
    }

    /// Consider a transaction and apply its entitlement if applicable.
    /// Returns true if this transaction granted Plus.
    @discardableResult
    func apply(_ tx: Transaction) -> Bool {
        guard PricingConfig.allProductIDs.contains(tx.productID),
              tx.revocationDate == nil else { return false }
        if let exp = tx.expirationDate, exp <= .now { return false }
        isPremium = true
        activeProductID = tx.productID
        // Subscriber supersedes the install trial.
        installTrialActive = false
        return true
    }

    /// Force a recompute of `installTrialActive` against the clock. Useful
    /// at scene activation if the user has been backgrounded across the
    /// 30-day boundary.
    func refreshInstallTrialState() {
        installTrialActive = computeInstallTrialActive()
    }

    private func computeInstallTrialActive() -> Bool {
        guard !isPremium else { return false }
        return installTrialDaysRemaining > 0
    }

    #if DEBUG
    /// Developer-only direct flip so we don't have to fabricate a `Transaction`
    /// in test/debug UI. Never compiled into Release.
    func debugSetPremium(for productID: String) {
        isPremium = true
        activeProductID = productID
        installTrialActive = false
    }
    #endif
}
