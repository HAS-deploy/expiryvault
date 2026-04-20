import Foundation
import SwiftData

/// Single tracked expiring thing — passport, license, registration, etc.
/// Only fields the user directly provides; no computed state is persisted.
@Model
final class TrackedItem {
    /// Stable UUID for scheduling notification identifiers that survive renames.
    @Attribute(.unique) var id: UUID
    var name: String
    /// Raw value of `ItemCategory`. Using the string form keeps migrations cheap.
    var categoryRaw: String
    var ownerName: String
    var expirationDate: Date
    var createdAt: Date
    var updatedAt: Date
    var notes: String
    var referenceCode: String
    var remindersEnabled: Bool
    /// Raw `ReminderOffset` values to fire on. Stored as Ints so SwiftData
    /// can migrate without a custom transformer.
    var reminderOffsetDays: [Int]
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: ItemCategory,
        ownerName: String,
        expirationDate: Date,
        notes: String = "",
        referenceCode: String = "",
        remindersEnabled: Bool = true,
        reminderOffsetDays: [Int] = ReminderOffset.defaultsForFreeTier.map(\.rawValue)
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.ownerName = ownerName
        self.expirationDate = expirationDate
        self.createdAt = .now
        self.updatedAt = .now
        self.notes = notes
        self.referenceCode = referenceCode
        self.remindersEnabled = remindersEnabled
        self.reminderOffsetDays = reminderOffsetDays
        self.isArchived = false
    }

    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    var reminderOffsets: [ReminderOffset] {
        get { reminderOffsetDays.compactMap(ReminderOffset.init(rawValue:)) }
        set { reminderOffsetDays = newValue.map(\.rawValue) }
    }

    // MARK: Derived

    /// Days remaining until expiration (0 on the day of, negative when expired).
    func daysUntilExpiration(reference: Date = .now) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: reference)
        let end = cal.startOfDay(for: expirationDate)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    var isExpired: Bool { daysUntilExpiration() < 0 }

    var expiresWithin30Days: Bool {
        let d = daysUntilExpiration()
        return d >= 0 && d <= 30
    }

    var group: ExpiryGroup {
        let d = daysUntilExpiration()
        if d < 0 { return .expired }
        if d <= 30 { return .next30 }
        return .later
    }
}

enum ExpiryGroup: String, CaseIterable, Identifiable {
    case expired, next30, later
    var id: String { rawValue }

    var title: String {
        switch self {
        case .expired: return "Expired"
        case .next30:  return "Next 30 days"
        case .later:   return "Later"
        }
    }
}
