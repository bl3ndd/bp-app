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

    static func message(for outcome: RestoreOutcome) -> String {
        switch outcome {
        case .restored: "Simply BP Pro is unlocked again."
        case .nothingToRestore: "No earlier Pro purchase was found for this Apple Account."
        case .failed: "Couldn't reach the App Store. Check your connection and try again."
        }
    }

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
            // Trust the verified transaction itself: the entitlement list can lag
            // a couple of seconds behind (measured in StoreKit testing), and
            // checking it right away left the buyer on the paywall without Pro.
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                isPro = true
            }
            return isPro
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    /// Apple requires an explicit restore path even though `currentEntitlement`
    /// usually resolves on its own.
    enum RestoreOutcome { case restored, nothingToRestore, failed }

    /// Reports the outcome so the UI can say it — a silent button reads as broken (2.1/3.1.1).
    @MainActor
    @discardableResult
    func restore() async -> RestoreOutcome {
        guard !isWorking else { return isPro ? .restored : .nothingToRestore }
        isWorking = true
        defer { isWorking = false }
        var syncFailed = false
        do { try await AppStore.sync() } catch { syncFailed = true }
        // Entitlements can take a moment to appear after a sync; give them a few seconds.
        for attempt in 0..<4 {
            await refreshEntitlement()
            if isPro || attempt == 3 { break }
            try? await Task.sleep(for: .seconds(1))
        }
        if isPro { return .restored }
        return syncFailed ? .failed : .nothingToRestore
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
