import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.analytics) private var analytics

    let trigger: PaywallTrigger
    let dismiss: () -> Void

    @State private var selectedProductID = PricingConfig.yearlyProductID
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    benefitsList
                    planSelector
                    ctaStack
                    legalFooter
                }
                .padding(20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        PortfolioAnalytics.shared.track(PortfolioEvent.paywallDismissed, [
                            "source": String(describing: trigger),
                        ])
                        dismiss()
                    }
                }
            }
            .alert("Couldn't complete purchase", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .onAppear {
                analytics.track(.paywallViewed, properties: ["trigger_source": .source(source)])
                PortfolioAnalytics.shared.track(PortfolioEvent.paywallViewed, [
                    "source": String(describing: trigger),
                ])
            }
            .onChange(of: entitlements.isPremium) { _, newValue in
                if newValue { dismiss() }
            }
        }
        .trackScreen("paywall")
    }

    // MARK: Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                Text("ExpiryVault Plus").font(.title2.weight(.bold))
            }
            Text(title).font(.largeTitle.bold())
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(PricingConfig.plusBenefits, id: \.self) { b in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                    Text(b).font(.callout)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var planSelector: some View {
        VStack(spacing: 10) {
            planRow(id: PricingConfig.yearlyProductID, title: "Yearly", subtitle: "Best value", badge: "Save 37%")
            planRow(id: PricingConfig.monthlyProductID, title: "Monthly", subtitle: "Cancel anytime", badge: nil)
            planRow(id: PricingConfig.lifetimeProductID, title: "Lifetime", subtitle: "Pay once — yours forever", badge: "No subscription")
        }
    }

    private func planRow(id: String, title: String, subtitle: String, badge: String?) -> some View {
        let selected = selectedProductID == id
        return Button {
            selectedProductID = id
            PortfolioAnalytics.shared.track("paywall.product_selected", [
                "product_id": id,
                "source": String(describing: trigger),
            ])
        } label: {
            HStack {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title).font(.body.weight(.semibold))
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(purchases.displayPrice(id: id)).font(.body.weight(.semibold)).monospacedDigit()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).stroke(
                selected ? Color.accentColor : Color(.systemGray4),
                lineWidth: selected ? 2 : 1,
            ))
        }
        .buttonStyle(.plain)
    }

    private var ctaStack: some View {
        VStack(spacing: 10) {
            Button { Task { await purchase() } } label: {
                Text(ctaLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(purchases.state == .purchasing(selectedProductID) || purchases.state == .restoring)

            Button("Restore purchases") {
                Task { await restore() }
            }
            .buttonStyle(.borderless)
            .disabled(purchases.state == .restoring)
        }
    }

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Monthly and Yearly are auto-renewable subscriptions. Your Apple ID account will be charged \(purchases.displayPrice(id: PricingConfig.monthlyProductID)) per month or \(purchases.displayPrice(id: PricingConfig.yearlyProductID)) per year at confirmation of purchase and within 24 hours prior to the end of each period, at the same price, unless auto-renew is turned off at least 24 hours before the end of the current period.")
            Text("Manage or cancel in Settings → Apple ID → Subscriptions. Lifetime is a one-time non-renewing purchase and is not a subscription.")
            HStack(spacing: 4) {
                Link("Terms of Use", destination: URL(string: "https://has-deploy.github.io/expiryvault/terms.html")!)
                Text("·")
                Link("Privacy Policy", destination: URL(string: "https://has-deploy.github.io/expiryvault/privacy.html")!)
            }
        }
        .font(.caption).foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    // MARK: Copy

    private var title: String {
        switch trigger {
        case .softUpsell: return PricingConfig.softUpsellTitle
        case .hardLimit:  return PricingConfig.hardLimitTitle
        case .settings:   return PricingConfig.paywallTitle
        }
    }
    private var subtitle: String {
        switch trigger {
        case .softUpsell: return PricingConfig.softUpsellSubtitle
        case .hardLimit:  return PricingConfig.hardLimitSubtitle
        case .settings:   return PricingConfig.paywallSubtitle
        }
    }
    private var ctaLabel: String {
        switch selectedProductID {
        case PricingConfig.lifetimeProductID: return "Unlock for \(purchases.displayPrice(id: selectedProductID))"
        case PricingConfig.yearlyProductID:   return "Start yearly — \(purchases.displayPrice(id: selectedProductID))/yr"
        default: return "Start monthly — \(purchases.displayPrice(id: selectedProductID))/mo"
        }
    }
    private var source: TriggerSource {
        switch trigger {
        case .softUpsell: return .softUpsell
        case .hardLimit:  return .featureGate
        case .settings:   return .settings
        }
    }

    // MARK: Actions

    private func purchase() async {
        analytics.track(.purchaseStarted, properties: [
            "trigger_source": .source(source),
            "category": .productTier(tier(of: selectedProductID)) as AnalyticsValue,
        ].compactMapValues { $0 })
        PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseClick, [
            "product_id": selectedProductID,
            "source": String(describing: trigger),
        ])
        let ok = await purchases.purchase(selectedProductID)
        if ok {
            analytics.track(.purchaseCompleted, properties: [
                "trigger_source": .source(source),
            ])
            let product = purchases.product(id: selectedProductID)
            let price = NSDecimalNumber(decimal: product?.price ?? 0).doubleValue
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseSuccess, [
                "product_id": selectedProductID,
                "is_sub": selectedProductID != PricingConfig.lifetimeProductID,
                "source": String(describing: trigger),
                "revenue_usd": price,
                "currency": product?.priceFormatStyle.currencyCode ?? "USD",
            ])
            if !UserDefaults.standard.bool(forKey: "posthog.identified") {
                PortfolioAnalytics.shared.identifyAfterPurchase(productId: selectedProductID, revenueUsd: price)
                UserDefaults.standard.set(true, forKey: "posthog.identified")
            }
        } else if case let .failed(message) = purchases.state {
            error = message
            analytics.track(.purchaseFailed, properties: [
                "trigger_source": .source(source),
            ])
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseFailed, [
                "product_id": selectedProductID,
                "reason": message,
                "error": message,
            ])
        }
    }

    private func restore() async {
        PortfolioAnalytics.shared.track(PortfolioEvent.paywallRestoreClick)
        await purchases.restore()
        if case let .failed(message) = purchases.state {
            error = message
        } else if purchases.state == .idle {
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallRestoreSuccess)
        }
    }

    private func tier(of id: String) -> ProductTier {
        ProductTier(productID: id) ?? .lifetime
    }
}
