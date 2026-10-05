import Foundation
import PitlogCore
import SwiftData

/// A vehicle the user keeps a maintenance log for.
///
/// CloudKit rules (CLAUDE.md): every attribute is optional or defaulted, nothing is `.unique`,
/// relationships are optional and have an inverse. Dates the rule engine works with are stored as
/// calendar components, not as `Date` (ADR-7).
@Model
final class Vehicle {
    var id: UUID = UUID()
    var name: String = ""
    var licensePlate: String = ""
    var vin: String?
    var make: String?
    var model: String?
    var countryCode: String = "AT"
    var categoryRaw: String = VehicleCategory.passengerCar.rawValue

    var firstRegistrationYear: Int?
    var firstRegistrationMonth: Int?

    /// Month and year punched on the inspection sticker (ADR-5: the plaque is authoritative).
    var plaqueYear: Int?
    var plaqueMonth: Int?

    var lastInspectionYear: Int?
    var lastInspectionMonth: Int?
    var lastInspectionDay: Int?

    @Attribute(.externalStorage) var photo: Data?
    var isArchived: Bool = false
    /// Notifications for the inspection deadline. The reminders themselves are derived, not stored.
    var inspectionRemindersEnabled: Bool = true
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \OdometerReading.vehicle)
    var odometerReadings: [OdometerReading]? = []

    @Relationship(deleteRule: .cascade, inverse: \Reminder.vehicle)
    var reminders: [Reminder]? = []

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceEntry.vehicle)
    var maintenanceEntries: [MaintenanceEntry]? = []

    init(
        name: String = "",
        licensePlate: String = "",
        category: VehicleCategory = .passengerCar,
        firstRegistration: YearMonth? = nil,
        plaque: YearMonth? = nil
    ) {
        self.name = name
        self.licensePlate = licensePlate
        self.categoryRaw = category.rawValue
        self.firstRegistrationYear = firstRegistration?.year
        self.firstRegistrationMonth = firstRegistration?.month
        self.plaqueYear = plaque?.year
        self.plaqueMonth = plaque?.month
    }
}

extension Vehicle {
    var category: VehicleCategory {
        get { VehicleCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var firstRegistration: YearMonth? {
        get { Self.yearMonth(year: firstRegistrationYear, month: firstRegistrationMonth) }
        set {
            firstRegistrationYear = newValue?.year
            firstRegistrationMonth = newValue?.month
        }
    }

    var plaque: YearMonth? {
        get { Self.yearMonth(year: plaqueYear, month: plaqueMonth) }
        set {
            plaqueYear = newValue?.year
            plaqueMonth = newValue?.month
        }
    }

    var lastInspection: DayDate? {
        get {
            guard let year = lastInspectionYear, let month = lastInspectionMonth, let day = lastInspectionDay
            else { return nil }
            return DayDate(year: year, month: month, day: day)
        }
        set {
            lastInspectionYear = newValue?.year
            lastInspectionMonth = newValue?.month
            lastInspectionDay = newValue?.day
        }
    }

    /// Kilometres of the most recent odometer reading.
    var currentOdometerKm: Int? {
        odometerReadings?.max { $0.date < $1.date }?.kilometers
    }

    /// Name for lists: the given name, or the plate if the name is empty.
    var displayName: String {
        name.isEmpty ? licensePlate : name
    }

    private static func yearMonth(year: Int?, month: Int?) -> YearMonth? {
        guard let year, let month else { return nil }
        return YearMonth(year: year, month: month)
    }
}
