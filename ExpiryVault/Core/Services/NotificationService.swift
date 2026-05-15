import Foundation
import UserNotifications

/// Local-notification scheduler for tracked item expirations.
/// All reminders are computed from each item's `expirationDate` minus its
/// `reminderOffsets` (in whole days) and fire at 9:00 AM local time.
///
/// Identifier convention: `expiryvault.reminder.<itemID>.<offsetDays>`
/// so we can cancel all reminders for a specific item by prefix search.
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private static let idPrefix = "expiryvault.reminder"
    private static let hourOfDay = 9

    // MARK: Permission

    func currentAuthorization() async -> UNAuthorizationStatus {
        await withCheckedContinuation { cont in
            center.getNotificationSettings { cont.resume(returning: $0.authorizationStatus) }
        }
    }

    /// Request `alert`, `sound`, and `badge`. Safe to call repeatedly — iOS
    /// only prompts once per install.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: Scheduling

    /// Replace all reminders for the item with the set dictated by its
    /// current `remindersEnabled` / `reminderOffsets` / `expirationDate`.
    func reschedule(for item: TrackedItem) async {
        await cancel(for: item.id)
        guard item.remindersEnabled, !item.isArchived else { return }
        // S3: request authorization lazily at the moment the user actually
        // tries to schedule their first reminder. If the user previously
        // denied, the system returns false and we still proceed to *attempt*
        // the add — iOS will silently drop the request rather than show, and
        // Settings exposes the "Open Settings" deep link for re-enabling.
        let status = await currentAuthorization()
        if status == .notDetermined {
            _ = await requestAuthorization()
        }
        let now = Date()
        for offset in item.reminderOffsets {
            guard let fire = fireDate(for: item, offsetDays: offset.rawValue), fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "\(item.name) expires \(offset.wording)"
            content.body = humanBody(for: item, offset: offset)
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                repeats: false,
            )
            let id = Self.identifier(item: item.id, offsetDays: offset.rawValue)
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(req)
        }
    }

    /// Cancel all reminders for the given item ID (both pending and delivered).
    func cancel(for itemID: UUID) async {
        let prefix = "\(Self.idPrefix).\(itemID.uuidString)"
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix) }
        if !deliveredIDs.isEmpty { center.removeDeliveredNotifications(withIdentifiers: deliveredIDs) }
    }

    /// Cancel every reminder this app scheduled. Used on "Clear all" / sign-out flows.
    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
    }

    // MARK: Date math (static + testable)

    static func identifier(item: UUID, offsetDays: Int) -> String {
        "\(idPrefix).\(item.uuidString).\(offsetDays)"
    }

    /// Compute the fire date for an item + offset (9:00 local on `expiry − offset`).
    /// `nil` if the calendar math fails (extreme dates) — caller skips.
    static func fireDate(expiry: Date, offsetDays: Int, hourOfDay: Int = hourOfDay) -> Date? {
        let cal = Calendar.current
        guard let dayShifted = cal.date(byAdding: .day, value: -offsetDays, to: expiry) else { return nil }
        var comps = cal.dateComponents([.year, .month, .day], from: dayShifted)
        comps.hour = hourOfDay
        comps.minute = 0
        return cal.date(from: comps)
    }

    private func fireDate(for item: TrackedItem, offsetDays: Int) -> Date? {
        Self.fireDate(expiry: item.expirationDate, offsetDays: offsetDays)
    }

    private func humanBody(for item: TrackedItem, offset: ReminderOffset) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let target = formatter.string(from: item.expirationDate)
        if item.ownerName.isEmpty {
            return "Expires \(target). Take a minute to renew."
        }
        return "\(item.ownerName) · expires \(target). Take a minute to renew."
    }
}

extension ReminderOffset {
    /// Fragment used in the notification title: "expires in 7 days", "expires tomorrow", etc.
    var wording: String {
        switch self {
        case .oneDay:      return "tomorrow"
        case .oneWeek:     return "in 7 days"
        case .oneMonth:    return "in 30 days"
        case .threeMonths: return "in 3 months"
        case .sixMonths:   return "in 6 months"
        }
    }
}
