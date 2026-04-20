import Foundation

/// Fixed set of "fire N days before expiration" offsets.
/// Stored as Int via `rawValue` for trivial SwiftData migration.
enum ReminderOffset: Int, CaseIterable, Identifiable, Codable {
    case sixMonths = 180
    case threeMonths = 90
    case oneMonth = 30
    case oneWeek = 7
    case oneDay = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sixMonths:   return "6 months before"
        case .threeMonths: return "3 months before"
        case .oneMonth:    return "30 days before"
        case .oneWeek:     return "7 days before"
        case .oneDay:      return "1 day before"
        }
    }

    /// Offsets free-tier users can schedule.
    static let freeTierAllowed: Set<ReminderOffset> = [.oneMonth, .oneWeek, .oneDay]

    /// Defaults applied when a new item is created by a free user.
    static let defaultsForFreeTier: [ReminderOffset] = [.oneMonth, .oneWeek, .oneDay]

    /// Defaults applied when a new item is created by a premium user.
    static let defaultsForPremium: [ReminderOffset] = [.sixMonths, .threeMonths, .oneMonth, .oneWeek, .oneDay]

    /// Is this offset allowed for a user with the given premium state?
    func isAllowed(premium: Bool) -> Bool {
        premium ? true : Self.freeTierAllowed.contains(self)
    }
}
