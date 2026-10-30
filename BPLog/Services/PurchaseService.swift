import Foundation
import StoreKit

/// Simply BP Pro is a single non-consumable unlock. StoreKit 2 keeps the
/// entitlement itself, so nothing about the purchase is persisted here —
/// asking StoreKit on every launch is both simpler and harder to spoof than
/// mirroring a flag into UserDefaults.
@Observable
final class PurchaseService {
    static let productID = "white.tea.BPLog.pro"

    private(set) var product: Product?
    private(set) var isPro = false
    /// True while a purchase or restore is in flight, so the paywall can block
    /// double taps.
    private(set) var isWorking = false

    private var updatesTask: Task<Void, Never>?

    init() {
        // A purchase can also land from outside the app — Ask to Buy approval,
        // another device, a refund — so listen for the lifetime of the service.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let transaction = try? update.payloadValue else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
        Task { await load() }
    }

    deinit { updatesTask?.cancel() }

    /// Loads the product and the current entitlement. Safe to call repeatedly.
    /// True once a product lookup has finished, whatever it returned. Lets the
    /// paywall tell "still loading" from "the store had nothing for us" — with
    /// no network, or before the product is approved, the second one would
    /// otherwise look like a spinner that never ends.
    private(set) var loaded = false

    @MainActor
    func load() async {
        // Entitlement first: it's local and instant, and it's what gates the
        // screens. The product lookup hits the store and can stall when the
        // product isn't live yet — it must never hold the unlock hostage.
        await refreshEntitlement()
        product = try? await Product.products(for: [Self.productID]).first
        loaded = true
    }

    /// Returns true when the user ends up entitled — including the case where
    /// they already owned it and StoreKit short-circuits the sheet.
    @MainActor
    @discardableResult
    func purchase() async throws -> Bool {
        guard let product, !isWorking else { return isPro }
        isWorking = true
        defer { isWorking = false }

        switch try await product.purchase() {
        case .success(let verification):
            // An unverified transaction means the signature didn't check out —
            // treat it as no purchase rather than unlocking on trust.
            guard let transaction = try? verification.payloadValue else { return false }
            await transaction.finish()
            await refreshEntitlement()
            return isPro
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    /// Apple requires an explicit restore path even though `currentEntitlement`
    /// usually resolves on its own.
    @MainActor
    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    /// Deliberately on the deprecated singular API: its replacement,
    /// `currentEntitlements(for:)`, needs iOS 18.4 and the deployment target is
    /// 18.0. Deprecated is not removed — revisit only when the floor moves.
    @MainActor
    private func refreshEntitlement() async {
        #if DEBUG
        // Demo runs (-SNAPSHOT*) show the paid screen populated, not the paywall.
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-SNAPSHOT") }) {
            isPro = true
            return
        }
        // -FREE: look at the app as a non-payer even if the sandbox owns the purchase.
        if ProcessInfo.processInfo.arguments.contains("-FREE") {
            isPro = false
            return
        }
        #endif
        guard let result = await Transaction.currentEntitlement(for: Self.productID),
              let transaction = try? result.payloadValue,
              transaction.revocationDate == nil
        else {
            isPro = false
            return
        }
        isPro = true
    }
}
