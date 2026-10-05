import Foundation
import PitlogCore
import SwiftData

/// What a stored reminder is about. Inspection reminders are derived from the vehicle and not stored.
enum ReminderCategory: String, CaseIterable, Sendable {
    case tyreWinter
    case tyreSummer
    case service
    case vignette
    case custom
}

/// How a custom reminder repeats. Services use `repeatMonths` and `repeatKm` instead.
enum ReminderRepeatRule: String, CaseIterable, Sendable {
    case none
    case yearly
    case months
}

/// A reminder of a vehicle: tyre change, service, vignette or a custom one.
///
/// SchemaV1 may still change freely until the first TestFlight build (see `SchemaV1`).
/// CloudKit rules: everything is optional or defaulted, the relationship has an inverse on `Vehicle`.
/// Dates are calendar components (ADR-7). For yearly kinds (tyre, vignette) the date is the first legal
/// day still to come; "done" moves it a year ahead.
@Model
final class Reminder {
    var id: UUID = UUID()
    var kindRaw: String = ReminderCategory.custom.rawValue
    /// The user's title (service, custom). Empty for tyre and vignette.
    var title: String = ""

    var dueYear: Int?
    var dueMonth: Int?
    var dueDay: Int?
    var dueKm: Int?

    var leadDays: Int = 14
    var leadKm: Int = 500

    var repeatRaw: String = ReminderRepeatRule.none.rawValue
    var repeatMonths: Int?
    var repeatKm: Int?

    var isEnabled: Bool = true
    var lastCompletedAt: Date?
    var note: String = ""

    var vehicle: Vehicle?

    init(category: ReminderCategory = .custom, vehicle: Vehicle? = nil) {
        self.kindRaw = category.rawValue
        self.vehicle = vehicle
    }
}

extension Reminder {
    var category: ReminderCategory {
        get { ReminderCategory(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }

    var repeatRule: ReminderRepeatRule {
        get { ReminderRepeatRule(rawValue: repeatRaw) ?? .none }
        set { repeatRaw = newValue.rawValue }
    }

    var dueDate: DayDate? {
        get {
            guard let dueYear, let dueMonth, let dueDay else { return nil }
            return DayDate(year: dueYear, month: dueMonth, day: dueDay)
        }
        set {
            dueYear = newValue?.year
            dueMonth = newValue?.month
            dueDay = newValue?.day
        }
    }
}
