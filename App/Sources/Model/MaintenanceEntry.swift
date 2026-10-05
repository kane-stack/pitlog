import Foundation
import PitlogCore
import SwiftData

/// One line of a vehicle's maintenance history: a workshop visit with date, odometer, work and cost.
///
/// SchemaV1 may still change freely until the first TestFlight build (see `SchemaV1`).
/// CloudKit rules: everything is optional or defaulted, relationships have an inverse.
/// The date is stored as calendar components (ADR-7), the amount as `Int` minor units plus an ISO currency
/// code (CLAUDE.md: never a `Double`).
@Model
final class MaintenanceEntry {
    var id: UUID = UUID()

    var dateYear: Int = 1970
    var dateMonth: Int = 1
    var dateDay: Int = 1
    var odometerKm: Int?

    var categoryRaw: String = MaintenanceCategory.service.rawValue
    var workshop: String = ""
    /// What was done, one item per line.
    var workItems: String = ""
    /// `nil`: no cost entered.
    var amountMinor: Int?
    var currencyCode: String = "EUR"
    var note: String = ""
    var createdAt: Date = Date()

    var vehicle: Vehicle?

    @Relationship(deleteRule: .cascade, inverse: \ReceiptDocument.entry)
    var receipts: [ReceiptDocument]? = []

    init(
        date: DayDate = DayDate(year: 1970, month: 1, day: 1)!,
        category: MaintenanceCategory = .service,
        vehicle: Vehicle? = nil
    ) {
        self.dateYear = date.year
        self.dateMonth = date.month
        self.dateDay = date.day
        self.categoryRaw = category.rawValue
        self.vehicle = vehicle
    }
}

extension MaintenanceEntry {
    var category: MaintenanceCategory {
        get { MaintenanceCategory(rawValue: categoryRaw) ?? .otherWorkshop }
        set { categoryRaw = newValue.rawValue }
    }

    var date: DayDate {
        get { DayDate(year: dateYear, month: dateMonth, day: dateDay) ?? DayDate(year: 1970, month: 1, day: 1)! }
        set {
            dateYear = newValue.year
            dateMonth = newValue.month
            dateDay = newValue.day
        }
    }

    var money: Money? {
        get { amountMinor.map { Money(amountMinor: Int64($0), currencyCode: currencyCode) } }
        set {
            amountMinor = newValue.map { Int(clamping: $0.amountMinor) }
            if let newValue { currencyCode = newValue.currencyCode }
        }
    }

    /// The first non-empty line of `workItems`, with a "+ n more" hint added by the presentation.
    var workLines: [String] {
        workItems.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// The entry as the cost summary sees it. `nil` without an amount.
    var costEntry: CostEntry? {
        money.map { CostEntry(date: date, category: category, money: $0) }
    }
}
