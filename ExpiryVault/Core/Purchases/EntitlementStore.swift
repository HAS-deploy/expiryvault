import Foundation
import Combine
import StoreKit

/// Single source of truth for whether the user has ExpiryVault Plus.
/// Any of the three products — monthly, yearly, lifetime — grant it.
@MainActor
final class EntitlementStore: ObservableObject {
    @Published private(set) var isPremium: Bool = false
    /// Which product is active right now (for Settings display).
    @Published private(set) var activeProductID: String?

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
        return true
    }

    #if DEBUG
    /// Developer-only direct flip so we don't have to fabricate a `Transaction`
    /// in test/debug UI. Never compiled into Release.
    func debugSetPremium(for productID: String) {
        isPremium = true
        activeProductID = productID
    }
    #endif
}
