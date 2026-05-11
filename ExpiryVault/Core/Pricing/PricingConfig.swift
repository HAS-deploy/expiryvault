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
    static let yearlyFallbackPrice   = "$34.99"
    static let lifetimeFallbackPrice = "$49.99"

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

    // MARK: Trial-determination model (annual intro offer)

    /// Trial-determination model: ExpiryVault uses a 1-month free trial on the
    /// annual product because tracked items take time to approach their
    /// expirations — the user needs enough runway to see at least one reminder
    /// cycle fire before deciding to keep paying.
    ///
    /// These constants must agree exactly with:
    ///   - `Resources/Configuration.storekit` yearly `introductoryOffer` block
    ///   - The ASC `subscriptionIntroductoryOffers` record on the yearly product
    static let annualTrialDays: Int = 30
    static let annualTrialDescription: String = "1-month free trial, then $34.99/year"

    // MARK: 3.1.2(a) disclosures (rendered verbatim by the paywall)

    static let disclosurePaymentCharged =
        "Payment will be charged to your Apple ID account at confirmation of purchase."
    static let disclosureAutoRenew =
        "Subscription automatically renews unless canceled at least 24 hours before the end of the current period."
    static let disclosureRenewalCharge =
        "Your account will be charged for renewal within 24 hours prior to the end of the current period."
    static let disclosureManage =
        "Subscriptions may be managed and auto-renewal may be turned off by going to the user's Account Settings after purchase."
    static let disclosureFreeTrial =
        "If you start a free trial, any unused portion is forfeited if you purchase a subscription before the trial ends."

    // MARK: Legal URLs

    static let privacyPolicyURL = "https://has-deploy.github.io/expiryvault/privacy.html"
    static let termsOfUseURL    = "https://has-deploy.github.io/expiryvault/terms.html"
    static let appleStdEULAURL  = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
}
