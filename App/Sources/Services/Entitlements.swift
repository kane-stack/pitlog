import PitlogCore
import SwiftUI

/// What the user may do (ADR-11). Backed by the StoreKit status (`StoreService`), never by CloudKit data.
/// Over the limit the app never deletes anything, it only restricts writes.
protocol Entitlements: Sendable {
    var isPro: Bool { get }
    /// Active (not archived) vehicles that may be edited. Further ones stay readable.
    var vehicleLimit: Int { get }
    var canScanReceipts: Bool { get }
    /// Reminders of the kinds tyres, service, vignette and custom. The inspection reminder is always free.
    var canUseProReminders: Bool { get }
    /// Costs of earlier years and the multi-year chart. The current year is always free.
    var canViewMultiYearCosts: Bool { get }
    var canExportServiceRecord: Bool { get }
}

/// The entitlements of a tier, from the pure policy in PitlogCore.
struct TierEntitlements: Entitlements {
    let tier: Tier

    private var policy: AccessPolicy { AccessPolicy(tier: tier) }

    var isPro: Bool { policy.isPro }
    var vehicleLimit: Int { policy.vehicleLimit }
    var canScanReceipts: Bool { policy.allows(.receiptScan) }
    var canUseProReminders: Bool { policy.allows(.proReminders) }
    var canViewMultiYearCosts: Bool { policy.allows(.multiYearCosts) }
    var canExportServiceRecord: Bool { policy.allows(.serviceRecordExport) }
}

/// Everything unlocked: the default for previews and for tests that are not about the tiers.
struct UnlimitedEntitlements: Entitlements {
    var isPro: Bool { true }
    var vehicleLimit: Int { .max }
    var canScanReceipts: Bool { true }
    var canUseProReminders: Bool { true }
    var canViewMultiYearCosts: Bool { true }
    var canExportServiceRecord: Bool { true }
}

/// For the UI test of one restricted feature (`-UITestNoReceiptScan`): everything but the receipt scan.
struct NoReceiptScanEntitlements: Entitlements {
    var isPro: Bool { false }
    var vehicleLimit: Int { .max }
    var canScanReceipts: Bool { false }
    var canUseProReminders: Bool { true }
    var canViewMultiYearCosts: Bool { true }
    var canExportServiceRecord: Bool { true }
}

/// The free tier as in ADR-11.
struct FreeEntitlements: Entitlements {
    private let base = TierEntitlements(tier: .free)

    var isPro: Bool { base.isPro }
    var vehicleLimit: Int { base.vehicleLimit }
    var canScanReceipts: Bool { base.canScanReceipts }
    var canUseProReminders: Bool { base.canUseProReminders }
    var canViewMultiYearCosts: Bool { base.canViewMultiYearCosts }
    var canExportServiceRecord: Bool { base.canExportServiceRecord }
}

extension Entitlements {
    /// `true` if one more vehicle may be added to `currentCount` existing ones.
    func canAddVehicle(currentCount: Int) -> Bool {
        currentCount < vehicleLimit
    }

    /// `true` if `vehicle` is beyond the limit: it stays visible but cannot be changed. Archived vehicles do
    /// not count against the limit. `active` are the non-archived vehicles.
    func isReadOnly(_ vehicle: Vehicle, among active: [Vehicle]) -> Bool {
        guard !vehicle.isArchived else { return false }
        let keys = active.map { VehicleKey(id: $0.id.uuidString, createdAt: $0.createdAt) }
        let editable = AccessPolicy.editableVehicleIDs(among: keys, limit: vehicleLimit)
        return !editable.contains(vehicle.id.uuidString)
    }
}

extension EnvironmentValues {
    @Entry var entitlements: any Entitlements = UnlimitedEntitlements()
}
