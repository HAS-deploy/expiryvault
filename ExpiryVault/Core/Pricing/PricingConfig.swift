import Foundation

/// Single source of truth for pricing + gating. Hardcoded display fallbacks
/// are only used before StoreKit hydrates — the App Store is authoritative
/// for the live price text shown to the user.
enum PricingConfig {

    // MARK: Product identifiers (must match App Store Connect)

    static let monthlyProductID  = "expiryvault_plus_monthly"
    static let yearlyProductID   = "expiryvault_plus_yearly"
    static let lifetimeProductID = "expiryvault_lifetime"

    static let allProductIDs: [String] = [monthlyProductID, yearlyProductID, lifetimeProductID]

    // MARK: Fallback display prices

    static let monthlyFallbackPrice  = "$3.99"
    static let yearlyFallbackPrice   = "$29.99"
    static let lifetimeFallbackPrice = "$39.99"

    // MARK: Copy

    static let paywallTitle = "Stay ahead of important deadlines"
    static let paywallSubtitle = "Unlimited items, full reminder control, and every future Plus feature."

    static let softUpsellTitle = "Never miss a renewal again"
    static let softUpsellSubtitle = "ExpiryVault Plus gives you unlimited items and advanced reminder options."

    static let hardLimitTitle = "You've reached the free item limit"
    static let hardLimitSubtitle = "Upgrade to keep tracking all your important expirations in one place."

    static let plusBenefits: [String] = [
        "Unlimited tracked items",
        "All reminder intervals (6 months, 3 months, 30 / 7 / 1 day)",
        "Premium filters and sorting",
        "Priority organization tools",
        "Every future Plus feature, included",
    ]

    // MARK: Free-tier caps

    static let freeItemLimit = 10
    /// Session threshold at which the soft upsell fires (once per install).
    static let softUpsellSessionThreshold = 3
    /// Minimum item count at which the soft upsell makes sense.
    static let softUpsellMinItems = 2
}
