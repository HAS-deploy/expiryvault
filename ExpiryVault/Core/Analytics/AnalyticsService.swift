import Foundation
import OSLog

/// Bounded analytics surface. Raw event names are the ship contract — don't
/// rename once released. Bounded property types keep personal content out.
enum AnalyticsEvent: String, CaseIterable, Sendable {
    case appOpen              = "app_open"
    case onboardingCompleted  = "onboarding_completed"
    case itemAdded            = "item_added"
    case itemDeleted          = "item_deleted"
    case itemViewed           = "item_viewed"
    case reminderEnabled      = "reminder_enabled"
    case paywallViewed        = "paywall_viewed"
    case purchaseStarted      = "purchase_started"
    case purchaseCompleted    = "purchase_completed"
    case purchaseFailed       = "purchase_failed"
    case freeLimitHit         = "free_limit_hit"
}

/// The only types an event property can carry. There is deliberately no
/// `.string(String)` case so names, notes, or reference codes can't be
/// logged by accident.
enum AnalyticsValue: Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case bucket(CountBucket)
    case category(ItemCategoryCode)
    case source(TriggerSource)
    case productTier(ProductTier)

    var stringValue: String {
        switch self {
        case .bool(let b):     return b ? "true" : "false"
        case .int(let i):      return String(i)
        case .bucket(let b):   return b.rawValue
        case .category(let c): return c.rawValue
        case .source(let s):   return s.rawValue
        case .productTier(t: let t): return t.rawValue
        }
    }
}

/// 0 / 1-2 / 3-5 / 6-10 / 11+ coarse item count.
enum CountBucket: String, Sendable {
    case zero      = "0"
    case oneToTwo  = "1-2"
    case threeToFive = "3-5"
    case sixToTen  = "6-10"
    case elevenPlus = "11+"

    init(_ n: Int) {
        switch n {
        case ..<1:  self = .zero
        case 1...2: self = .oneToTwo
        case 3...5: self = .threeToFive
        case 6...10: self = .sixToTen
        default:    self = .elevenPlus
        }
    }
}

/// Same-valued mirror of `ItemCategory` so we don't leak the view-model
/// enum into analytics. Keeps the analytics surface stable across refactors.
enum ItemCategoryCode: String, Sendable {
    case travel, id, insurance, vehicle, work, health, pet, home, membership, warranty, custom
    init(_ c: ItemCategory) {
        self = ItemCategoryCode(rawValue: c.rawValue) ?? .custom
    }
}

enum TriggerSource: String, Sendable {
    case onboarding
    case dashboard
    case list
    case detail
    case settings
    case softUpsell = "soft_upsell"
    case featureGate = "feature_gate"
    case emptyState = "empty_state"
}

enum ProductTier: String, Sendable {
    case monthly, yearly, lifetime
    init?(productID: String) {
        switch productID {
        case PricingConfig.monthlyProductID:  self = .monthly
        case PricingConfig.yearlyProductID:   self = .yearly
        case PricingConfig.lifetimeProductID: self = .lifetime
        default: return nil
        }
    }
}

/// Injected facade. All live events go through `track`. Swap the closure to
/// change sinks. Default Release build is a no-op; Debug logs to os.Logger.
struct AnalyticsService: Sendable {
    private let emit: @Sendable (AnalyticsEvent, [String: AnalyticsValue]) -> Void

    func track(_ event: AnalyticsEvent, properties: [String: AnalyticsValue] = [:]) {
        emit(event, properties)
    }

    static let noop = AnalyticsService(emit: { _, _ in })

    static let local: AnalyticsService = {
        let logger = Logger(subsystem: "app.expiryvault", category: "analytics")
        return AnalyticsService { event, props in
            #if DEBUG
            let joined = props.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value.stringValue)" }
                .joined(separator: " ")
            if joined.isEmpty { logger.debug("\(event.rawValue, privacy: .public)") }
            else { logger.debug("\(event.rawValue, privacy: .public) \(joined, privacy: .public)") }
            #endif
        }
    }()
}

/// Environment key so SwiftUI views can pull the shared service.
import SwiftUI
private struct AnalyticsEnvKey: EnvironmentKey {
    static let defaultValue: AnalyticsService = .noop
}
extension EnvironmentValues {
    var analytics: AnalyticsService {
        get { self[AnalyticsEnvKey.self] }
        set { self[AnalyticsEnvKey.self] = newValue }
    }
}
