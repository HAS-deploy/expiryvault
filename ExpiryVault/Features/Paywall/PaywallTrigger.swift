import Foundation

/// Why the paywall is being shown. Drives copy + analytics dimension.
/// `Identifiable` lets us use it as the `item:` binding on a `.sheet`.
enum PaywallTrigger: String, Identifiable, Hashable {
    case softUpsell
    case hardLimit
    case settings

    var id: String { rawValue }
}
