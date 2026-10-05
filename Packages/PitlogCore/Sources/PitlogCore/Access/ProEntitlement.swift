import Foundation

/// The App Store product IDs of Pitlog Pro (final, see CLAUDE.md).
public enum ProProduct {
    public static let yearly = "com.kane.pitlog.pro.yearly"
    public static let lifetime = "com.kane.pitlog.pro.lifetime"
    public static let all: Set<String> = [yearly, lifetime]
}

/// One entitlement as StoreKit reports it, reduced to what the evaluation needs.
public struct PurchaseRecord: Hashable, Sendable {
    public enum Ownership: String, Hashable, Codable, Sendable {
        case purchased
        case familyShared
    }

    public var productID: String
    public var revocationDate: Date?
    /// `nil` for the lifetime purchase.
    public var expirationDate: Date?
    public var ownership: Ownership

    public init(
        productID: String, revocationDate: Date? = nil, expirationDate: Date? = nil,
        ownership: Ownership = .purchased
    ) {
        self.productID = productID
        self.revocationDate = revocationDate
        self.expirationDate = expirationDate
        self.ownership = ownership
    }
}

/// Whether and why the user has Pro. Cached on the device only; never stored in CloudKit.
public struct ProStatus: Hashable, Codable, Sendable {
    public enum Source: String, Hashable, Codable, Sendable {
        case none
        case lifetime
        case subscription
    }

    public var source: Source
    /// The end of the current subscription period (or of its grace period start). `nil` for the lifetime purchase.
    public var expiresAt: Date?
    public var isFamilyShared: Bool
    /// The subscription period has ended but the App Store still lists it (billing retry): Pro continues for now.
    public var isInGracePeriod: Bool

    public init(
        source: Source = .none, expiresAt: Date? = nil, isFamilyShared: Bool = false, isInGracePeriod: Bool = false
    ) {
        self.source = source
        self.expiresAt = expiresAt
        self.isFamilyShared = isFamilyShared
        self.isInGracePeriod = isInGracePeriod
    }

    public static let free = ProStatus()

    public var tier: Tier { source == .none ? .free : .pro }
}

/// Turns the entitlements StoreKit lists into a `ProStatus`. Pure: `now` is passed in.
public enum ProEntitlementEvaluator {
    /// A subscription that ended up to this long ago but is still listed as an entitlement is in its grace
    /// period (billing retry). The App Store's longest configurable grace period is 16 days.
    public static let maximumGracePeriod: TimeInterval = 16 * 24 * 60 * 60

    /// Lifetime beats a subscription. Records of other products, revoked ones and expired subscriptions
    /// are ignored. Only verified entitlements belong in `records`.
    public static func status(from records: [PurchaseRecord], now: Date) -> ProStatus {
        let valid = records.filter { $0.revocationDate == nil && ProProduct.all.contains($0.productID) }
        if let lifetime = valid.first(where: { $0.productID == ProProduct.lifetime }) {
            return ProStatus(source: .lifetime, isFamilyShared: lifetime.ownership == .familyShared)
        }
        var best: ProStatus?
        for record in valid where record.productID == ProProduct.yearly {
            let candidate: ProStatus
            switch record.expirationDate {
            case nil:
                candidate = ProStatus(source: .subscription, isFamilyShared: record.ownership == .familyShared)
            case let expiry? where expiry > now:
                candidate = ProStatus(
                    source: .subscription, expiresAt: expiry, isFamilyShared: record.ownership == .familyShared)
            case let expiry? where now.timeIntervalSince(expiry) <= maximumGracePeriod:
                candidate = ProStatus(
                    source: .subscription, expiresAt: expiry, isFamilyShared: record.ownership == .familyShared,
                    isInGracePeriod: true)
            default:
                continue
            }
            if let current = best, (current.expiresAt ?? .distantFuture) >= (candidate.expiresAt ?? .distantFuture) {
                continue
            }
            best = candidate
        }
        return best ?? .free
    }

    /// Never locks the user out because verification failed: if StoreKit returned an entitlement of ours that
    /// could not be verified (no network for the certificate, for example) and the fresh result says "free",
    /// the last verified status stays.
    public static func resolve(computed: ProStatus, cached: ProStatus?, sawUnverified: Bool) -> ProStatus {
        if computed.tier == .pro { return computed }
        if sawUnverified, let cached { return cached }
        return computed
    }
}
