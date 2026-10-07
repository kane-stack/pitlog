import Foundation
import PitlogCore

/// A product of Wagemo Pro as the paywall shows it. Prices are StoreKit's `displayPrice`, never hard coded.
struct StoreProduct: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case subscription
        case lifetime
    }

    struct Period: Hashable, Sendable {
        enum Unit: Hashable, Sendable {
            case day, week, month, year
        }

        var value: Int
        var unit: Unit

        /// "14 days", "1 year": the duration in the given locale.
        func localized(locale: Locale) -> String {
            var components = DateComponents()
            switch unit {
            case .day: components.day = value
            case .week: components.day = value * 7
            case .month: components.month = value
            case .year: components.year = value
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = locale
            let formatter = DateComponentsFormatter()
            formatter.calendar = calendar
            formatter.unitsStyle = .full
            formatter.allowedUnits = [.day, .month, .year]
            formatter.maximumUnitCount = 1
            return formatter.string(from: components) ?? "\(value)"
        }
    }

    let id: String
    let kind: Kind
    let displayName: String
    let displayPrice: String
    let isFamilyShareable: Bool
    /// Renewal period of the subscription.
    let period: Period?
    /// A free trial, only if the user is eligible for it.
    let freeTrial: Period?
}

/// What StoreKit currently lists as the user's entitlements to our products.
struct EntitlementSnapshot: Sendable {
    var records: [PurchaseRecord]
    /// An entitlement of ours was listed but could not be verified.
    var sawUnverified: Bool

    init(records: [PurchaseRecord] = [], sawUnverified: Bool = false) {
        self.records = records
        self.sawUnverified = sawUnverified
    }
}

enum PurchaseOutcome: Sendable, Equatable {
    case success
    /// Ask to Buy or a payment that is not through yet. The transaction arrives later through `transactionUpdates`.
    case pending
    case cancelled
}

enum StoreError: Error {
    case productUnavailable
    case unverified
}

/// The StoreKit calls the app needs, as a protocol so that the store service can be tested with a fake
/// transaction source (ADR-12: StoreKit is the only service, and it is Apple's).
protocol StoreBackend: Sendable {
    func currentEntitlements() async -> EntitlementSnapshot
    /// Emits once for each transaction that arrives outside of a purchase (renewal, refund, Family Sharing, Ask to Buy).
    func transactionUpdates() -> AsyncStream<Void>
    func loadProducts() async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> PurchaseOutcome
    /// "Restore purchases": syncs with the App Store.
    func restore() async throws
}
