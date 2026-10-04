import SwiftUI

/// What the user may do (ADR-11). StoreKit 2 plugs in later; until M6 everything is free.
/// Over the limit the app never deletes anything, it only restricts writes.
protocol Entitlements: Sendable {
    var vehicleLimit: Int { get }
    var canScanReceipts: Bool { get }
}

struct UnlimitedEntitlements: Entitlements {
    var vehicleLimit: Int { .max }
    var canScanReceipts: Bool { true }
}

extension Entitlements {
    /// `true` if one more vehicle may be added to `currentCount` existing ones.
    func canAddVehicle(currentCount: Int) -> Bool {
        currentCount < vehicleLimit
    }
}

extension EnvironmentValues {
    @Entry var entitlements: any Entitlements = UnlimitedEntitlements()
}
