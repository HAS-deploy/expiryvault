import XCTest
import SwiftData
@testable import ExpiryVault

@MainActor
final class ExpiryLogicTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: TrackedItem.self, configurations: config)
    }

    // MARK: Grouping

    func testExpiredGroup() {
        let past = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let item = TrackedItem(name: "Passport", category: .travel, ownerName: "", expirationDate: past)
        XCTAssertTrue(item.isExpired)
        XCTAssertEqual(item.group, .expired)
    }

    func testNext30Group() {
        let soon = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
        let item = TrackedItem(name: "License", category: .id, ownerName: "", expirationDate: soon)
        XCTAssertFalse(item.isExpired)
        XCTAssertTrue(item.expiresWithin30Days)
        XCTAssertEqual(item.group, .next30)
    }

    func testLaterGroup() {
        let far = Calendar.current.date(byAdding: .day, value: 120, to: .now)!
        let item = TrackedItem(name: "Warranty", category: .warranty, ownerName: "", expirationDate: far)
        XCTAssertEqual(item.group, .later)
    }

    func testDayOfExpirationIsToday() {
        let today = Calendar.current.startOfDay(for: .now)
        let item = TrackedItem(name: "Visa", category: .travel, ownerName: "", expirationDate: today)
        XCTAssertEqual(item.daysUntilExpiration(), 0)
        XCTAssertFalse(item.isExpired)
        XCTAssertEqual(item.group, .next30)
    }

    // MARK: Reminder offsets free-tier gating

    func testFreeTierOffsetsAllowed() {
        XCTAssertTrue(ReminderOffset.oneDay.isAllowed(premium: false))
        XCTAssertTrue(ReminderOffset.oneWeek.isAllowed(premium: false))
        XCTAssertTrue(ReminderOffset.oneMonth.isAllowed(premium: false))
        XCTAssertFalse(ReminderOffset.threeMonths.isAllowed(premium: false))
        XCTAssertFalse(ReminderOffset.sixMonths.isAllowed(premium: false))
    }

    func testPremiumOffsetsAllowed() {
        for o in ReminderOffset.allCases {
            XCTAssertTrue(o.isAllowed(premium: true), "\(o) must be allowed for premium")
        }
    }

    // MARK: Count bucket

    func testCountBucket() {
        XCTAssertEqual(CountBucket(0), .zero)
        XCTAssertEqual(CountBucket(1), .oneToTwo)
        XCTAssertEqual(CountBucket(2), .oneToTwo)
        XCTAssertEqual(CountBucket(3), .threeToFive)
        XCTAssertEqual(CountBucket(5), .threeToFive)
        XCTAssertEqual(CountBucket(6), .sixToTen)
        XCTAssertEqual(CountBucket(10), .sixToTen)
        XCTAssertEqual(CountBucket(11), .elevenPlus)
        XCTAssertEqual(CountBucket(999), .elevenPlus)
    }

    // MARK: SwiftData CRUD

    func testCreateAndFetch() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let exp = Calendar.current.date(byAdding: .year, value: 1, to: .now)!
        ctx.insert(TrackedItem(name: "Passport", category: .travel, ownerName: "Tony", expirationDate: exp))
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<TrackedItem>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Passport")
        XCTAssertEqual(fetched.first?.category, .travel)
    }

    // MARK: Reminder scheduling math

    func testFireDateIsNineAMOnOffsetDay() {
        let cal = Calendar.current
        let expiry = cal.date(from: DateComponents(year: 2030, month: 6, day: 15))!
        let fire = NotificationService.fireDate(expiry: expiry, offsetDays: 7)
        XCTAssertNotNil(fire)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire!)
        XCTAssertEqual(comps.year, 2030)
        XCTAssertEqual(comps.month, 6)
        XCTAssertEqual(comps.day, 8)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 0)
    }

    func testFireDate180DaysBefore() {
        let cal = Calendar.current
        let expiry = cal.date(from: DateComponents(year: 2030, month: 12, day: 31))!
        let fire = NotificationService.fireDate(expiry: expiry, offsetDays: 180)
        XCTAssertNotNil(fire)
        // Compare day boundaries — the fire date is at 9:00 AM, expiry at
        // midnight, so raw deltas round down by ~15 hours. Normalize both.
        let daysDelta = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: fire!),
            to: cal.startOfDay(for: expiry),
        ).day
        XCTAssertEqual(daysDelta, 180)
    }

    // MARK: Paywall trigger copy

    func testHardLimitTriggerCopyDistinct() {
        XCTAssertNotEqual(PaywallTrigger.softUpsell, PaywallTrigger.hardLimit)
        XCTAssertEqual(PaywallTrigger.hardLimit.id, "hardLimit")
    }

    // MARK: Free-tier item cap

    func testFreeTierCapIsTen() {
        XCTAssertEqual(PricingConfig.freeItemLimit, 10)
    }
}
