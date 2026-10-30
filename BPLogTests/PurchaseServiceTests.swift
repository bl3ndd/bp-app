import Testing
import Foundation
import StoreKitTest
@testable import BPLog

/// The real StoreKit 2 purchase path against the local `BPLog.storekit` store:
/// product lookup, buying Pro, the unlock, and a refund taking it away again.
@MainActor
@Suite(.serialized)
struct PurchaseServiceTests {
    private func session() throws -> SKTestSession {
        let url = try #require(Bundle.main.url(forResource: "BPLog", withExtension: "storekit"),
                               "BPLog.storekit ships in the app bundle the tests run in")
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    /// The test store's settings persist on the device: put dialogs back on, or a
    /// later manual run from Xcode buys silently without the purchase sheet.
    private func reset(_ session: SKTestSession) {
        session.clearTransactions()
        session.disableDialogs = false
    }

    @Test func productLoadsWithItsPrice() async throws {
        let session = try session()
        defer { reset(session) }
        let purchases = PurchaseService()
        await purchases.load()
        let product = try #require(purchases.product)
        #expect(product.id == PurchaseService.productID)
        #expect(product.price == Decimal(string: "14.99"))
        #expect(!purchases.isPro)
    }

    @Test func buyingUnlocksPro() async throws {
        let session = try session()
        defer { reset(session) }
        let purchases = PurchaseService()
        await purchases.load()
        #expect(!purchases.isPro)
        #expect(try await purchases.purchase())
        #expect(purchases.isPro)

        // A fresh service (next launch) sees the entitlement without buying again,
        // once StoreKit's entitlement list catches up.
        var relaunchPro = false
        for _ in 0..<6 where !relaunchPro {
            try await Task.sleep(for: .seconds(1))
            let relaunch = PurchaseService()
            await relaunch.load()
            relaunchPro = relaunch.isPro
        }
        #expect(relaunchPro)
    }

    @Test func refundRemovesPro() async throws {
        let session = try session()
        defer { reset(session) }
        let purchases = PurchaseService()
        await purchases.load()
        #expect(try await purchases.purchase())
        let transaction = try #require(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)

        // Revocations reach the entitlement list with the same short lag as purchases.
        var stillPro = true
        for _ in 0..<6 where stillPro {
            try await Task.sleep(for: .seconds(1))
            let afterRefund = PurchaseService()
            await afterRefund.load()
            stillPro = afterRefund.isPro
        }
        #expect(!stillPro)
    }
}
