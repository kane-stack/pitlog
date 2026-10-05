import Foundation
import PitlogCore
import Testing

@testable import Pitlog

/// A fake transaction source: tests set what StoreKit "lists" and what a purchase does.
final class FakeStoreBackend: StoreBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var storedSnapshot = EntitlementSnapshot()
    private var storedPurchase: Result<PurchaseOutcome, any Error> = .success(.success)
    private var storedGrant: [PurchaseRecord] = []
    private var storedRestoreError: (any Error)?
    private var continuation: AsyncStream<Void>.Continuation?

    struct Failure: Error {}

    var snapshot: EntitlementSnapshot {
        get { lock.withLock { storedSnapshot } }
        set { lock.withLock { storedSnapshot = newValue } }
    }

    /// What the next purchase returns, and the entitlements it adds when it succeeds.
    func setPurchase(_ result: Result<PurchaseOutcome, any Error>, grants: [PurchaseRecord] = []) {
        lock.withLock {
            storedPurchase = result
            storedGrant = grants
        }
    }

    func setRestoreError(_ error: (any Error)?) {
        lock.withLock { storedRestoreError = error }
    }

    /// Simulates a transaction that arrives outside of a purchase (renewal, refund, Ask to Buy approved).
    func emitUpdate() {
        lock.withLock { continuation }?.yield()
    }

    func currentEntitlements() async -> EntitlementSnapshot { snapshot }

    func transactionUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            lock.withLock { self.continuation = continuation }
        }
    }

    func loadProducts() async throws -> [StoreProduct] { [] }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        let (result, grants) = lock.withLock { (storedPurchase, storedGrant) }
        let outcome = try result.get()
        if outcome == .success {
            lock.withLock { storedSnapshot.records += grants }
        }
        return outcome
    }

    func restore() async throws {
        if let error = lock.withLock({ storedRestoreError }) { throw error }
    }
}

@MainActor
struct StoreServiceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let dayLength: TimeInterval = 86_400

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "store-tests-\(UUID().uuidString)") ?? .standard
    }

    private func makeStore(
        _ backend: FakeStoreBackend, defaults: UserDefaults? = nil
    ) -> StoreService {
        let fixed = now
        return StoreService(backend: backend, defaults: defaults ?? makeDefaults(), now: { fixed })
    }

    private func lifetime(family: Bool = false, revoked: Bool = false) -> PurchaseRecord {
        PurchaseRecord(
            productID: ProProduct.lifetime, revocationDate: revoked ? now.addingTimeInterval(-60) : nil,
            ownership: family ? .familyShared : .purchased)
    }

    private func yearly(expiresIn seconds: TimeInterval, family: Bool = false) -> PurchaseRecord {
        PurchaseRecord(
            productID: ProProduct.yearly, expirationDate: now.addingTimeInterval(seconds),
            ownership: family ? .familyShared : .purchased)
    }

    private let product = StoreProduct(
        id: ProProduct.lifetime, kind: .lifetime, displayName: "Pro", displayPrice: "€14.99",
        isFamilyShareable: true, period: nil, freeTrial: nil)

    // MARK: Status

    @Test func isFreeBeforeAnythingIsKnown() {
        let store = makeStore(FakeStoreBackend())
        #expect(store.tier == .free)
        #expect(store.status == .free)
    }

    @Test func lifetimePurchaseMakesProAndFamilySharedIsReported() async {
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [lifetime(family: true)])
        let store = makeStore(backend)
        await store.refresh()
        #expect(store.tier == .pro)
        #expect(store.status.source == .lifetime)
        #expect(store.status.isFamilyShared)
    }

    @Test func activeSubscriptionIsProUntilItEnds() async {
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [yearly(expiresIn: 30 * dayLength)])
        let store = makeStore(backend)
        await store.refresh()
        #expect(store.tier == .pro)
        #expect(store.status.expiresAt == now.addingTimeInterval(30 * dayLength))
    }

    @Test func expiredSubscriptionIsFreeAgain() async {
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [yearly(expiresIn: 30 * dayLength)])
        let store = makeStore(backend)
        await store.refresh()
        #expect(store.tier == .pro)
        // The period ended long ago and StoreKit no longer lists it.
        backend.snapshot = EntitlementSnapshot(records: [yearly(expiresIn: -40 * dayLength)])
        await store.refresh()
        #expect(store.tier == .free)
    }

    @Test func subscriptionInItsGracePeriodStaysPro() async {
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [yearly(expiresIn: -3 * dayLength)])
        let store = makeStore(backend)
        await store.refresh()
        #expect(store.tier == .pro)
        #expect(store.status.isInGracePeriod)
    }

    @Test func revokedPurchaseIsNotPro() async {
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [lifetime()])
        let store = makeStore(backend)
        await store.refresh()
        #expect(store.tier == .pro)
        backend.snapshot = EntitlementSnapshot(records: [lifetime(revoked: true)])
        await store.refresh()
        #expect(store.tier == .free)
    }

    @Test func familySharedSubscriptionCounts() async {
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [yearly(expiresIn: 10 * dayLength, family: true)])
        let store = makeStore(backend)
        await store.refresh()
        #expect(store.tier == .pro)
        #expect(store.status.isFamilyShared)
    }

    // MARK: Offline cache

    @Test func cachedStatusIsKnownAtLaunchBeforeStoreKitAnswers() async {
        let defaults = makeDefaults()
        let first = FakeStoreBackend()
        first.snapshot = EntitlementSnapshot(records: [lifetime()])
        let store = makeStore(first, defaults: defaults)
        await store.refresh()
        #expect(store.tier == .pro)

        // A new launch: nothing has refreshed yet, but the last verified status is there.
        let relaunched = makeStore(FakeStoreBackend(), defaults: defaults)
        #expect(relaunched.tier == .pro)
    }

    @Test func anUnverifiedEntitlementNeverLocksTheUserOut() async {
        let defaults = makeDefaults()
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [yearly(expiresIn: 30 * dayLength)])
        let store = makeStore(backend, defaults: defaults)
        await store.refresh()
        #expect(store.tier == .pro)

        // Offline: StoreKit lists the entitlement but cannot verify it. No verified record, still Pro.
        backend.snapshot = EntitlementSnapshot(records: [], sawUnverified: true)
        await store.refresh()
        #expect(store.tier == .pro)

        // The same after a relaunch.
        let relaunched = makeStore(backend, defaults: defaults)
        await relaunched.refresh()
        #expect(relaunched.tier == .pro)
    }

    @Test func aVerifiedAnswerWithoutEntitlementsReplacesTheCache() async {
        let defaults = makeDefaults()
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [lifetime()])
        let store = makeStore(backend, defaults: defaults)
        await store.refresh()
        backend.snapshot = EntitlementSnapshot()
        await store.refresh()
        #expect(store.tier == .free)
        #expect(makeStore(FakeStoreBackend(), defaults: defaults).tier == .free)
    }

    @Test func theStatusIsOnlyKeptInTheDeviceDefaults() async throws {
        let defaults = makeDefaults()
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [lifetime()])
        let store = makeStore(backend, defaults: defaults)
        await store.refresh()
        let data = try #require(defaults.data(forKey: StoreService.cacheKey))
        #expect(try JSONDecoder().decode(ProStatus.self, from: data).source == .lifetime)
    }

    // MARK: Purchase and restore

    @Test func successfulPurchaseMakesPro() async {
        let backend = FakeStoreBackend()
        backend.setPurchase(.success(.success), grants: [lifetime()])
        let store = makeStore(backend)
        await store.purchase(product)
        #expect(store.tier == .pro)
        #expect(store.message == nil)
        #expect(store.activity == .idle)
    }

    @Test func pendingPurchaseKeepsFreeAndSaysSo() async {
        let backend = FakeStoreBackend()
        backend.setPurchase(.success(.pending))
        let store = makeStore(backend)
        await store.purchase(product)
        #expect(store.tier == .free)
        #expect(store.message == .purchasePending)
    }

    @Test func cancelledPurchaseIsSilent() async {
        let backend = FakeStoreBackend()
        backend.setPurchase(.success(.cancelled))
        let store = makeStore(backend)
        await store.purchase(product)
        #expect(store.tier == .free)
        #expect(store.message == nil)
    }

    @Test func failedPurchaseSaysSo() async {
        let backend = FakeStoreBackend()
        backend.setPurchase(.failure(FakeStoreBackend.Failure()))
        let store = makeStore(backend)
        await store.purchase(product)
        #expect(store.tier == .free)
        #expect(store.message == .purchaseFailed)
        #expect(store.activity == .idle)
    }

    @Test func restoreFindsAnEarlierPurchase() async {
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [lifetime()])
        let store = makeStore(backend)
        await store.restore()
        #expect(store.tier == .pro)
        #expect(store.message == nil)
    }

    @Test func restoreWithNothingToRestoreSaysSo() async {
        let store = makeStore(FakeStoreBackend())
        await store.restore()
        #expect(store.tier == .free)
        #expect(store.message == .nothingToRestore)
    }

    @Test func failedRestoreSaysSoAndKeepsTheStatus() async {
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [lifetime()])
        let store = makeStore(backend)
        await store.refresh()
        backend.setRestoreError(FakeStoreBackend.Failure())
        await store.restore()
        #expect(store.message == .restoreFailed)
        #expect(store.tier == .pro)
    }

    // MARK: Updates

    @Test func aTransactionUpdateRefreshesTheStatus() async throws {
        let backend = FakeStoreBackend()
        let store = makeStore(backend)
        store.start()
        backend.snapshot = EntitlementSnapshot(records: [lifetime()])
        backend.emitUpdate()
        for _ in 0..<200 where store.tier != .pro {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(store.tier == .pro)
    }

    // MARK: Debug override

    @Test func debugOverrideWinsOverTheStatus() async {
        let backend = FakeStoreBackend()
        backend.snapshot = EntitlementSnapshot(records: [lifetime()])
        let store = makeStore(backend)
        await store.refresh()
        store.debugTier = .free
        #expect(store.tier == .free)
        store.debugTier = nil
        #expect(store.tier == .pro)
    }
}
