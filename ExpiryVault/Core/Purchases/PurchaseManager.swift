import Foundation
import StoreKit

/// StoreKit 2 manager for ExpiryVault Plus.
/// Covers three products in two shapes:
///   - `expiryvault_plus_monthly` / `_yearly`  — auto-renewable subscriptions
///   - `expiryvault_lifetime`                  — one-time non-consumable
/// Each grants the same in-app `premium` entitlement via `EntitlementStore`.
@MainActor
final class PurchaseManager: ObservableObject {

    @Published private(set) var products: [Product] = []
    @Published private(set) var state: State = .idle

    enum State: Equatable {
        case idle
        case purchasing(String)   // productID in flight
        case restoring
        case failed(String)
    }

    private let entitlements: EntitlementStore
    private var updatesTask: Task<Void, Never>?

    init(entitlements: EntitlementStore) {
        self.entitlements = entitlements
    }

    // MARK: Lifecycle

    /// Start the Transaction.updates listener and refresh state. Call from
    /// the app-scope `.task` modifier so cancellation happens on app exit.
    func start() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await loadProducts(); await refreshEntitlements() }
    }

    deinit { updatesTask?.cancel() }

    // MARK: Products

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: PricingConfig.allProductIDs)
            // Preserve known order: monthly, yearly, lifetime
            let order = [
                PricingConfig.monthlyProductID,
                PricingConfig.yearlyProductID,
                PricingConfig.lifetimeProductID,
            ]
            self.products = loaded.sorted { (a, b) in
                (order.firstIndex(of: a.id) ?? 99) < (order.firstIndex(of: b.id) ?? 99)
            }
        } catch {
            // Leave `products` untouched; display fallbacks will render.
        }
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    func displayPrice(id: String) -> String {
        product(id: id)?.displayPrice ?? fallbackPrice(id: id)
    }

    private func fallbackPrice(id: String) -> String {
        switch id {
        case PricingConfig.monthlyProductID:  return PricingConfig.monthlyFallbackPrice
        case PricingConfig.yearlyProductID:   return PricingConfig.yearlyFallbackPrice
        case PricingConfig.lifetimeProductID: return PricingConfig.lifetimeFallbackPrice
        default: return ""
        }
    }

    // MARK: Purchase / restore

    /// Purchase the given product. Returns true on successful entitlement.
    @discardableResult
    func purchase(_ productID: String) async -> Bool {
        guard let product = product(id: productID) else {
            state = .failed("Product not available")
            return false
        }
        state = .purchasing(productID)
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let tx):
                    await tx.finish()
                    _ = entitlements.apply(tx)
                    state = .idle
                    return entitlements.isPremium
                case .unverified(let tx, let err):
                    await tx.finish()
                    await refreshEntitlements()
                    state = .failed("Apple couldn't verify the purchase: \(err.localizedDescription)")
                    return false
                }
            case .userCancelled:
                state = .idle
                return false
            case .pending:
                // Ask-to-Buy etc. — entitlement may arrive later via updates.
                state = .idle
                return false
            @unknown default:
                state = .idle
                return false
            }
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }

    func restore() async {
        state = .restoring
        do {
            try await AppStore.sync()
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        await refreshEntitlements()
        state = .idle
    }

    // MARK: Entitlements

    func refreshEntitlements() async {
        entitlements.reset()
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result {
                _ = entitlements.apply(tx)
            }
        }
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        switch update {
        case .verified(let tx):
            await tx.finish()
            _ = entitlements.apply(tx)
        case .unverified(let tx, _):
            await tx.finish()
            await refreshEntitlements()
        }
    }

    #if DEBUG
    /// Developer-only — never shipped.
    func debugTogglePremium() {
        if entitlements.isPremium { entitlements.reset() }
        else { entitlements.objectWillChange.send(); _ = entitlements.apply(makeStubTransaction()) }
    }

    private func makeStubTransaction() -> Transaction {
        // Can't fabricate a real Transaction in tests. Caller should set
        // `entitlements.isPremium` directly via `reset()` + not call this.
        fatalError("debugTogglePremium uses entitlements.reset() path only")
    }
    #endif
}
