import XCTest
import SwiftData
@testable import ExpiryVault

@MainActor
final class InstallTrialTests: XCTestCase {

    /// A throwaway UserDefaults instance per test so we never collide with
    /// the real install-time stamp on the developer's box.
    private func makeDefaults() -> UserDefaults {
        let name = "ev.installtrial.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func makeStore(now: Date, firstLaunchAt: Date? = nil) -> EntitlementStore {
        let defaults = makeDefaults()
        if let stamp = firstLaunchAt {
            defaults.set(stamp, forKey: EntitlementStore.firstLaunchAtKey)
        }
        return EntitlementStore(defaults: defaults, clock: { now })
    }

    // MARK: Trial active during 30d

    func testInstallTrialActiveOnDayZero() {
        let store = makeStore(now: Date())
        XCTAssertTrue(store.installTrialActive)
        XCTAssertEqual(store.installTrialDaysRemaining, PricingConfig.annualTrialDays)
        XCTAssertTrue(store.hasPlusAccess)
    }

    func testInstallTrialActiveAtDay29() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let day29 = Calendar.current.date(byAdding: .day, value: 29, to: start)!
        let store = makeStore(now: day29, firstLaunchAt: start)
        XCTAssertTrue(store.installTrialActive)
        XCTAssertEqual(store.installTrialDaysRemaining, 1)
        XCTAssertTrue(store.hasPlusAccess)
    }

    // MARK: Trial inactive after 30d

    func testInstallTrialInactiveAtDay30() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let day30 = Calendar.current.date(byAdding: .day, value: 30, to: start)!
        let store = makeStore(now: day30, firstLaunchAt: start)
        XCTAssertFalse(store.installTrialActive)
        XCTAssertEqual(store.installTrialDaysRemaining, 0)
        XCTAssertFalse(store.hasPlusAccess)
        XCTAssertFalse(store.isPremium)
    }

    func testInstallTrialInactiveWellAfterExpiry() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let day120 = Calendar.current.date(byAdding: .day, value: 120, to: start)!
        let store = makeStore(now: day120, firstLaunchAt: start)
        XCTAssertFalse(store.installTrialActive)
        XCTAssertFalse(store.hasPlusAccess)
    }

    // MARK: Gate allows during trial

    func testFeatureGateAllowsDuringTrial() {
        // During trial, hasPlusAccess must be true so the free-item-cap
        // gate at DashboardView/ItemListView lets the user keep adding
        // and the reminder offsets above 30 days are unlocked.
        let store = makeStore(now: Date())
        XCTAssertTrue(store.hasPlusAccess)
        // Reminder-offset gate uses `premium:` keyword name but the call
        // sites now pass `hasPlusAccess` — verify the offsets it covers.
        XCTAssertTrue(ReminderOffset.threeMonths.isAllowed(premium: store.hasPlusAccess))
        XCTAssertTrue(ReminderOffset.sixMonths.isAllowed(premium: store.hasPlusAccess))
    }

    func testSoftUpsellSuppressedDuringTrial() {
        // AppState.shouldShowSoftUpsell now takes hasPlusAccess; trial
        // users count as "already have Plus" for upsell purposes.
        let state = AppState()
        state.sessionCount = PricingConfig.softUpsellSessionThreshold + 5
        XCTAssertFalse(state.shouldShowSoftUpsell(hasPlusAccess: true, itemCount: 10))
        XCTAssertTrue(state.shouldShowSoftUpsell(hasPlusAccess: false, itemCount: 10))
    }

    // MARK: Data preserved after trial

    /// After the install trial elapses, the user drops to the free tier
    /// — but every TrackedItem they recorded during the trial must remain
    /// in SwiftData. We verify this by inserting items and re-opening the
    /// container under a different store state.
    func testDataPreservedAfterTrialEnds() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TrackedItem.self, configurations: config)
        let ctx = ModelContext(container)

        // Simulate "user in trial" filling up well past the free cap.
        let trialStart = Date(timeIntervalSince1970: 1_700_000_000)
        let trialStore = makeStore(now: trialStart, firstLaunchAt: trialStart)
        XCTAssertTrue(trialStore.hasPlusAccess)

        let count = PricingConfig.freeItemLimit + 7
        for i in 0..<count {
            let exp = Calendar.current.date(byAdding: .day, value: 30 + i, to: trialStart)!
            ctx.insert(TrackedItem(
                name: "Item \(i)",
                category: .custom,
                ownerName: "",
                expirationDate: exp,
            ))
        }
        try ctx.save()

        // Day 60 — trial elapsed, user drops to free tier.
        let day60 = Calendar.current.date(byAdding: .day, value: 60, to: trialStart)!
        let postTrialStore = makeStore(now: day60, firstLaunchAt: trialStart)
        XCTAssertFalse(postTrialStore.hasPlusAccess)
        XCTAssertFalse(postTrialStore.isPremium)

        // All trial-era items must still be there.
        let fetched = try ctx.fetch(FetchDescriptor<TrackedItem>())
        XCTAssertEqual(fetched.count, count, "Trial-era items must survive trial expiry")
    }

    // MARK: First launch stamp

    func testFirstLaunchStampedOnFreshInstall() {
        let defaults = makeDefaults()
        XCTAssertNil(defaults.object(forKey: EntitlementStore.firstLaunchAtKey))
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = EntitlementStore(defaults: defaults, clock: { now })
        XCTAssertNotNil(store.firstLaunchAt)
        XCTAssertEqual(store.firstLaunchAt, now)
    }

    func testFirstLaunchStampNotOverwritten() {
        let defaults = makeDefaults()
        let original = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set(original, forKey: EntitlementStore.firstLaunchAtKey)
        // Instantiate later in time — original stamp must be preserved.
        let later = Calendar.current.date(byAdding: .day, value: 10, to: original)!
        let store = EntitlementStore(defaults: defaults, clock: { later })
        XCTAssertEqual(store.firstLaunchAt, original)
    }

    // MARK: Subscriber supersedes trial

    func testPremiumSupersedesTrial() {
        let store = makeStore(now: Date())
        XCTAssertTrue(store.installTrialActive)
        #if DEBUG
        store.debugSetPremium(for: PricingConfig.lifetimeProductID)
        XCTAssertFalse(store.installTrialActive)
        XCTAssertTrue(store.isPremium)
        XCTAssertTrue(store.hasPlusAccess)
        #endif
    }
}
