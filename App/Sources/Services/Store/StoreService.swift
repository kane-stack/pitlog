import Foundation
import Observation
import PitlogCore

/// The Pitlog Pro state of this device (ADR-11): products, purchase, restore and the entitlement status.
///
/// The status comes from StoreKit only and is cached in this device's user defaults so that the app knows
/// it at launch. It is never written to SwiftData or CloudKit. Verification problems never lock the user
/// out (see `ProEntitlementEvaluator.resolve`).
@MainActor
@Observable
final class StoreService {
    enum ProductsState: Equatable {
        case idle, loading, loaded, failed
    }

    enum Activity: Equatable {
        case idle, purchasing, restoring
    }

    /// What the paywall tells the user after an action.
    enum Message: Equatable {
        case purchasePending
        case purchaseFailed
        case restoreFailed
        case nothingToRestore
    }

    static let cacheKey = "proStatusCache"

    private(set) var status: ProStatus
    private(set) var products: [StoreProduct] = []
    private(set) var productsState = ProductsState.idle
    private(set) var activity = Activity.idle
    private(set) var message: Message?
    /// Debug builds only: overrides the tier for testing the gates. Release builds ignore it.
    var debugTier: Tier?

    @ObservationIgnored private let backend: any StoreBackend
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(
        backend: any StoreBackend,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.defaults = defaults
        self.now = now
        // The last verified status is known immediately, before StoreKit has answered.
        self.status = Self.loadCache(from: defaults) ?? .free
    }

    /// The tier the gates use.
    var tier: Tier {
        #if DEBUG
        if let debugTier { return debugTier }
        #endif
        return status.tier
    }

    /// Starts listening for transactions that arrive outside of a purchase and reads the current status.
    func start() {
        guard updatesTask == nil else { return }
        let updates = backend.transactionUpdates()
        updatesTask = Task { [weak self] in
            for await _ in updates {
                await self?.refresh()
            }
        }
        Task { [weak self] in
            await self?.refresh()
        }
    }

    /// Recomputes the status from StoreKit's current entitlements.
    func refresh() async {
        let snapshot = await backend.currentEntitlements()
        let computed = ProEntitlementEvaluator.status(from: snapshot.records, now: now())
        let resolved = ProEntitlementEvaluator.resolve(
            computed: computed, cached: status, sawUnverified: snapshot.sawUnverified)
        if resolved != status { status = resolved }
        Self.saveCache(resolved, to: defaults)
    }

    func loadProducts() async {
        guard productsState != .loading else { return }
        productsState = .loading
        do {
            products = try await backend.loadProducts()
            productsState = products.isEmpty ? .failed : .loaded
        } catch {
            productsState = .failed
        }
    }

    func purchase(_ product: StoreProduct) async {
        guard activity == .idle else { return }
        activity = .purchasing
        message = nil
        defer { activity = .idle }
        do {
            switch try await backend.purchase(productID: product.id) {
            case .success: await refresh()
            case .pending: message = .purchasePending
            case .cancelled: break
            }
        } catch {
            message = .purchaseFailed
        }
    }

    /// "Restore purchases".
    func restore() async {
        guard activity == .idle else { return }
        activity = .restoring
        message = nil
        defer { activity = .idle }
        do {
            try await backend.restore()
            await refresh()
            if status.tier == .free { message = .nothingToRestore }
        } catch {
            message = .restoreFailed
        }
    }

    func clearMessage() {
        message = nil
    }

    // MARK: Cache

    private static func loadCache(from defaults: UserDefaults) -> ProStatus? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(ProStatus.self, from: data)
    }

    private static func saveCache(_ status: ProStatus, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(status) else { return }
        defaults.set(data, forKey: cacheKey)
    }
}

extension StoreService {
    static let privacyPolicyURL = URL(string: "https://example.com/pitlog/privacy")
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
}
