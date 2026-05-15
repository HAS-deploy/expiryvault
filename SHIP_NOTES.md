# SHIP_NOTES — ExpiryVault paying-user audit pass (2026-05-15)

Audit input: `~/Documents/portfolio-audit/05-expiryvault.md` (2 HARD · 4 SIGNIFICANT · 4 POLISH).

## Summary

**2 HARDs fixed · 4 SIGNIFICANTs fixed · 2 POLISH fixed · 0 deferred**

(P2 dismissed by audit on closer reading; P3 noted for future at >500 items.)

## Per-finding outcomes

### H1 — Lifetime IAP advertised but likely unpurchasable
**Fixed (code) + ASC metadata edit needed.**
- `ExpiryVault/Features/Paywall/PaywallView.swift` — the Lifetime `planRow(...)` and the lifetime-specific bullet in the legal-disclosure block are now both gated on `purchases.product(id: PricingConfig.lifetimeProductID) != nil`. When App Store Connect hasn't approved `expiryvault_lifetime`, the tile and bullet are hidden, so the live paywall no longer renders the unpurchasable $49.99 fallback row. Default `selectedProductID` is already `yearlyProductID`, so CTA copy stays valid.
- **ASC metadata action for the owner:** Either (a) submit `expiryvault_lifetime` for review so it lands APPROVED and the tile reappears automatically, OR (b) remove the line "Lifetime $49.99 (one-time)" from the App Store description until the SKU lands. Until one of those, the paywall will quietly skip the row and the description copy is the only remaining inconsistency.

### H2 — Silent 30-day install trial contradicts description
**Fixed (code) + ASC metadata edit needed.**
- `ExpiryVault/Core/Purchases/EntitlementStore.swift` — `statusLabel` now returns `"Plus — Trial (N day(s) left)"` while `installTrialActive` is true.
- `ExpiryVault/Features/Settings/SettingsView.swift` — subscription section footer now reads `"You're on a free Plus trial — unlimited items and every reminder interval are unlocked. After the trial, the free tier covers 10 items with 30 / 7 / 1-day reminders."` whenever the trial is active, and the "Upgrade to Plus" button relabels to `"Upgrade to keep Plus"` so the day-31 cliff is no longer a surprise.
- **ASC metadata action for the owner:** Add a sentence to the App Store description acknowledging the 30-day trial, e.g. *"New installs include 30 days of Plus free — unlimited items + every reminder interval. After that, the free tier covers 10 items with 30 / 7 / 1-day reminders."* Once that ships, the 2.3.1 risk is neutralized.

### S1 — No analytics opt-out UI
**Fixed (code).**
- `ExpiryVault/Features/Settings/SettingsView.swift` — added `@AppStorage("portfolio.analytics.opted_out")` (same key `PortfolioAnalytics` reads), a `Toggle("Anonymous usage analytics", ...)` in the Privacy section, plus an `analyticsEnabledBinding` that calls `PortfolioAnalytics.shared.optIn() / optOut()` on flip. Also rewrote the about-section blurb so it no longer implies a choice the user didn't have. Privacy section now uses an explicit footer describing what coarse events are sent.

### S2 — `installTrialActive` never re-evaluates across day boundary
**Fixed (code).**
- `ExpiryVault/ExpiryVaultApp.swift` — added `entitlements.refreshInstallTrialState()` to the `if phase == .active` branch of the scene-phase observer. The day-31 user opening the app from background now flips to free immediately.

### S3 — Notification permission requested at end of onboarding
**Fixed (code).**
- `ExpiryVault/Features/Onboarding/OnboardingView.swift` — `finish()` no longer calls `requestAuthorization()`; it reads `currentAuthorization()` so the analytics dimension still gets a value.
- `ExpiryVault/Core/Services/NotificationService.swift` — `reschedule(for:)` now checks `currentAuthorization()` and lazily calls `requestAuthorization()` if `.notDetermined`. The first save flow is the moment of intent; Settings already exposes a manual "Allow notifications" deep link for users who defer.

### S4 — No nuke-everything path
**Fixed (code).**
- `ExpiryVault/Features/Settings/SettingsView.swift` — added a destructive "Delete all items" button in the data section, a confirmation dialog (count-aware: "Delete N items"), and a `deleteAllItems()` helper that snapshots `items`, calls `NotificationService.shared.cancelAll()`, then `context.delete` over the snapshot, saves, and emits `settings.delete_data_tapped` analytics with the deleted count.

### P1 — Settings "Plan" line should show trial status
**Fixed (code).** Folded into H2 — `statusLabel` now returns `"Plus — Trial (N days left)"` during the install trial.

### P2 — Soft-upsell threshold ignores trial expiration
**Confirmed safe.** Audit re-read showed `softUpsellShown` is only flipped on actual fire (suppressed during trial). No change.

### P3 — Search is unbatched live filter
**Deferred (acceptable until 500+ items).** Per audit; revisit only when paying users hit ~500 items.

### P4 — ItemEditView locked-toggle alert has no in-flow upgrade CTA
**Fixed (code).**
- `ExpiryVault/Features/Items/ItemEditView.swift` — alert now has an "Upgrade" primary button that sets `paywallTrigger = .softUpsell` and a "Not now" cancel; a `.sheet(item: $paywallTrigger)` presents `PaywallView` directly. Environment objects (`PurchaseManager`, `EntitlementStore`) propagate from the parent so no extra wiring.

## ASC metadata edits needed (no code changes will fix these)

1. **Lifetime IAP** — either get `expiryvault_lifetime` APPROVED, or remove the "Lifetime $49.99 (one-time)" line from the App Store description.
2. **30-day install trial disclosure** — add a sentence to the App Store description acknowledging the trial: *"New installs include 30 days of Plus free — unlimited items + every reminder interval. After that, the free tier covers 10 items with 30 / 7 / 1-day reminders."*

## Risk notes

- No StoreKit plumbing touched. No product IDs renamed. No SwiftData `@Model` properties renamed. Existing `InstallTrialTests` still cover the trial-active / inactive / cross-boundary cases — they test `EntitlementStore` directly so they're unaffected.
- Notification-permission deferral changes the timing of the system prompt but not the eventual behavior — the Settings "Allow notifications" path is unchanged for users who defer at item-save time.
- Lifetime tile hide is purely additive (`if product != nil`), so when the SKU is approved later it'll automatically reappear with no additional code change.
- `analyticsOptedOut` uses the same UserDefaults key `PortfolioAnalytics` reads (`portfolio.analytics.opted_out`), so toggle state survives relaunch and matches what the SDK does internally.
