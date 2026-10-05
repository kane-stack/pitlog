import Foundation

/// What the user has bought (ADR-11). Only the app's StoreKit service knows it; it is never synced.
public enum Tier: String, Hashable, Codable, Sendable, CaseIterable {
    case free
    case pro
}

/// A feature that is part of Pitlog Pro.
public enum ProFeature: String, Hashable, Codable, Sendable, CaseIterable {
    case moreVehicles
    case proReminders
    case receiptScan
    case multiYearCosts
    case serviceRecordExport
}

/// What identifies a vehicle for the limit: a stable order that is the same on every device.
/// The vehicle created first is first; the ID breaks ties between equal creation dates.
public struct VehicleKey: Hashable, Comparable, Sendable {
    public var id: String
    public var createdAt: Date

    public init(id: String, createdAt: Date) {
        self.id = id
        self.createdAt = createdAt
    }

    public static func < (lhs: VehicleKey, rhs: VehicleKey) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id < rhs.id
    }
}

/// Pure rules for what the free tier may do (ADR-11). Nothing here deletes anything: over the limit
/// the surplus vehicles stay readable, and reminders of Pro kinds are only left out of the plan.
public struct AccessPolicy: Hashable, Sendable {
    public static let freeVehicleLimit = 1

    public var tier: Tier

    public init(tier: Tier) {
        self.tier = tier
    }

    public var isPro: Bool { tier == .pro }

    /// `Int.max` for Pro.
    public var vehicleLimit: Int { isPro ? .max : Self.freeVehicleLimit }

    public func allows(_ feature: ProFeature) -> Bool { isPro }

    // MARK: Vehicles

    /// `true` if one more vehicle may be added to `currentCount` active ones.
    public func canAddVehicle(currentCount: Int) -> Bool {
        currentCount < vehicleLimit
    }

    /// The vehicles that may be edited: the first `vehicleLimit` in the stable order.
    public func editableVehicleIDs(among vehicles: [VehicleKey]) -> Set<String> {
        Self.editableVehicleIDs(among: vehicles, limit: vehicleLimit)
    }

    /// The same for any limit, for entitlement sources that bring their own.
    public static func editableVehicleIDs(among vehicles: [VehicleKey], limit: Int) -> Set<String> {
        Set(vehicles.sorted().prefix(max(0, limit)).map(\.id))
    }

    public func canEditVehicle(id: String, among vehicles: [VehicleKey]) -> Bool {
        editableVehicleIDs(among: vehicles).contains(id)
    }

    // MARK: Reminders

    /// The inspection reminder is free for every vehicle. All other kinds are Pro.
    public func canSchedule(_ kind: ReminderSchedule.Kind) -> Bool {
        switch kind {
        case .inspection: true
        case .tyreChange, .service, .vignette, .custom: isPro
        }
    }

    /// Removes the schedules of Pro kinds if the tier does not include them. The stored reminders stay.
    public func schedulable(_ schedules: [ReminderSchedule]) -> [ReminderSchedule] {
        schedules.filter { canSchedule($0.kind) }
    }

    // MARK: Costs

    /// Free: only the calendar year of `today`. Pro: every year.
    public func canViewCostYear(_ year: Int, today: DayDate) -> Bool {
        isPro || year == today.year
    }

    /// The years of `series` the tier may see.
    public func visibleCostYears(_ series: [YearCosts], today: DayDate) -> [YearCosts] {
        series.filter { canViewCostYear($0.year, today: today) }
    }
}
