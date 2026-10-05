#if DEBUG
import Foundation
import PitlogCore

/// Debug only: a fixed store for the UI tests (`-UITestFree`, `-UITestPro`) and for the tests that host the app.
/// The simulator on the CI machine has no App Store, so the paywall shows these sample products there.
/// The prices are sample values for the screens, the release build only ever shows StoreKit's own.
struct StubStoreBackend: StoreBackend {
    var records: [PurchaseRecord] = []
    var freeTrial = true

    static let pro = StubStoreBackend(records: [PurchaseRecord(productID: ProProduct.lifetime)])
    static let free = StubStoreBackend()

    func currentEntitlements() async -> EntitlementSnapshot {
        EntitlementSnapshot(records: records)
    }

    func transactionUpdates() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }

    func loadProducts() async throws -> [StoreProduct] {
        [
            StoreProduct(
                id: ProProduct.yearly, kind: .subscription, displayName: "Pitlog Pro", displayPrice: "€4.99",
                isFamilyShareable: true, period: .init(value: 1, unit: .year),
                freeTrial: freeTrial ? .init(value: 2, unit: .week) : nil),
            StoreProduct(
                id: ProProduct.lifetime, kind: .lifetime, displayName: "Pitlog Pro Lifetime", displayPrice: "€14.99",
                isFamilyShareable: true, period: nil, freeTrial: nil),
        ]
    }

    func purchase(productID: String) async throws -> PurchaseOutcome { .cancelled }

    func restore() async throws {}
}
#endif
