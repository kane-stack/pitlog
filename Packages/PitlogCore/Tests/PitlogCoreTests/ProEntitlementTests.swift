import Foundation
import Testing
@testable import PitlogCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let hour: TimeInterval = 3_600
private let dayLength: TimeInterval = 86_400

private func yearly(
    expires: TimeInterval?, revoked: Bool = false, family: Bool = false
) -> PurchaseRecord {
    PurchaseRecord(
        productID: ProProduct.yearly,
        revocationDate: revoked ? now.addingTimeInterval(-hour) : nil,
        expirationDate: expires.map { now.addingTimeInterval($0) },
        ownership: family ? .familyShared : .purchased)
}

private func lifetime(revoked: Bool = false, family: Bool = false) -> PurchaseRecord {
    PurchaseRecord(
        productID: ProProduct.lifetime,
        revocationDate: revoked ? now.addingTimeInterval(-hour) : nil,
        ownership: family ? .familyShared : .purchased)
}

struct StatusCase: Sendable {
    let name: String
    let records: [PurchaseRecord]
    let source: ProStatus.Source
    let family: Bool
    let grace: Bool
}

@Test(arguments: [
    StatusCase(name: "nothing bought", records: [], source: .none, family: false, grace: false),
    StatusCase(name: "lifetime", records: [lifetime()], source: .lifetime, family: false, grace: false),
    StatusCase(name: "lifetime, family shared", records: [lifetime(family: true)], source: .lifetime, family: true, grace: false),
    StatusCase(name: "lifetime revoked", records: [lifetime(revoked: true)], source: .none, family: false, grace: false),
    StatusCase(name: "active subscription", records: [yearly(expires: 30 * dayLength)], source: .subscription, family: false, grace: false),
    StatusCase(name: "subscription, family shared", records: [yearly(expires: 30 * dayLength, family: true)], source: .subscription, family: true, grace: false),
    StatusCase(name: "subscription ends in a second", records: [yearly(expires: 1)], source: .subscription, family: false, grace: false),
    StatusCase(name: "subscription ended just now: grace period", records: [yearly(expires: 0)], source: .subscription, family: false, grace: true),
    StatusCase(name: "subscription ended 10 days ago: grace period", records: [yearly(expires: -10 * dayLength)], source: .subscription, family: false, grace: true),
    StatusCase(name: "subscription ended 16 days ago: last day of the grace period", records: [yearly(expires: -16 * dayLength)], source: .subscription, family: false, grace: true),
    StatusCase(name: "subscription ended 17 days ago", records: [yearly(expires: -17 * dayLength)], source: .none, family: false, grace: false),
    StatusCase(name: "subscription revoked", records: [yearly(expires: 30 * dayLength, revoked: true)], source: .none, family: false, grace: false),
    StatusCase(name: "unknown product", records: [PurchaseRecord(productID: "com.example.other")], source: .none, family: false, grace: false),
    StatusCase(name: "lifetime beats a subscription", records: [yearly(expires: 30 * dayLength), lifetime()], source: .lifetime, family: false, grace: false),
    StatusCase(name: "revoked lifetime, active subscription", records: [lifetime(revoked: true), yearly(expires: 30 * dayLength)], source: .subscription, family: false, grace: false),
])
func statusFromRecords(_ c: StatusCase) {
    let status = ProEntitlementEvaluator.status(from: c.records, now: now)
    #expect(status.source == c.source, "\(c.name)")
    #expect(status.isFamilyShared == c.family, "\(c.name)")
    #expect(status.isInGracePeriod == c.grace, "\(c.name)")
    #expect(status.tier == (c.source == .none ? .free : .pro), "\(c.name)")
}

@Test func theLaterSubscriptionWins() {
    let status = ProEntitlementEvaluator.status(
        from: [yearly(expires: 10 * dayLength), yearly(expires: 40 * dayLength)], now: now)
    #expect(status.expiresAt == now.addingTimeInterval(40 * dayLength))
}

@Test func expiryIsReported() {
    let status = ProEntitlementEvaluator.status(from: [yearly(expires: 30 * dayLength)], now: now)
    #expect(status.expiresAt == now.addingTimeInterval(30 * dayLength))
}

struct ResolveCase: Sendable {
    let name: String
    let computed: ProStatus
    let cached: ProStatus?
    let unverified: Bool
    let expected: ProStatus
}

private let proCached = ProStatus(source: .subscription, expiresAt: now.addingTimeInterval(dayLength))
private let longExpired = ProStatus(source: .subscription, expiresAt: now.addingTimeInterval(-17 * dayLength))
private let expiredInGrace = ProStatus(source: .subscription, expiresAt: now.addingTimeInterval(-16 * dayLength))
private let lifetimeCached = ProStatus(source: .lifetime)

@Test(arguments: [
    ResolveCase(name: "fresh Pro wins over the cache", computed: ProStatus(source: .lifetime), cached: .free, unverified: false, expected: ProStatus(source: .lifetime)),
    ResolveCase(name: "fresh free replaces a cached Pro", computed: .free, cached: proCached, unverified: false, expected: .free),
    ResolveCase(name: "unverified entitlement keeps the cached Pro", computed: .free, cached: proCached, unverified: true, expected: proCached),
    ResolveCase(name: "unverified keeps a cached lifetime", computed: .free, cached: lifetimeCached, unverified: true, expected: lifetimeCached),
    ResolveCase(name: "unverified keeps a cached subscription within the grace period", computed: .free, cached: expiredInGrace, unverified: true, expected: expiredInGrace),
    ResolveCase(name: "unverified does not keep a long expired subscription", computed: .free, cached: longExpired, unverified: true, expected: .free),
    ResolveCase(name: "unverified, nothing cached: free", computed: .free, cached: nil, unverified: true, expected: .free),
    ResolveCase(name: "unverified, cached free: free", computed: .free, cached: .free, unverified: true, expected: .free),
])
func resolveNeverLocksOutBecauseOfVerification(_ c: ResolveCase) {
    let result = ProEntitlementEvaluator.resolve(
        computed: c.computed, cached: c.cached, sawUnverified: c.unverified, now: now)
    #expect(result == c.expected, "\(c.name)")
}

@Test func statusRoundTripsThroughJSON() throws {
    let status = ProStatus(
        source: .subscription, expiresAt: now, isFamilyShared: true, isInGracePeriod: true)
    let data = try JSONEncoder().encode(status)
    #expect(try JSONDecoder().decode(ProStatus.self, from: data) == status)
}

@Test func productIDsAreTheFinalOnes() {
    #expect(ProProduct.yearly == "com.kane.pitlog.pro.yearly")
    #expect(ProProduct.lifetime == "com.kane.pitlog.pro.lifetime")
}
