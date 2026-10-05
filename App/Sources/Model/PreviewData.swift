import Foundation
import PitlogCore
import SwiftData

/// Sample vehicles for previews and UI tests (`-UITestSampleData`).
enum PreviewData {
    @MainActor
    static func container(withSamples: Bool = true) -> ModelContainer {
        let container = try! ModelContainerFactory.inMemory()
        if withSamples { insertSamples(into: container.mainContext) }
        return container
    }

    @MainActor
    static func insertSamples(into context: ModelContext) {
        let golf = Vehicle(
            name: "Golf",
            licensePlate: "W 12345 A",
            category: .passengerCar,
            firstRegistration: YearMonth(year: 2020, month: 6),
            plaque: YearMonth(year: 2027, month: 6)
        )
        golf.make = "Volkswagen"
        golf.model = "Golf"
        context.insert(golf)
        context.insert(OdometerReading(date: Date(timeIntervalSince1970: 1_750_000_000), kilometers: 60_000, vehicle: golf))
        context.insert(OdometerReading(date: Date(timeIntervalSince1970: 1_780_000_000), kilometers: 68_400, vehicle: golf))
        insertReminders(for: golf, into: context)
        insertHistory(for: golf, into: context)

        let transporter = Vehicle(
            name: "Transporter",
            licensePlate: "L 777 BX",
            category: .lightCommercial,
            firstRegistration: YearMonth(year: 2022, month: 3),
            plaque: YearMonth(year: 2027, month: 3)
        )
        context.insert(transporter)

        let estimated = Vehicle(
            name: "Fiat 500",
            licensePlate: "G 4711 K",
            category: .passengerCar,
            firstRegistration: YearMonth(year: 2018, month: 9)
        )
        context.insert(estimated)

        let manual = Vehicle(name: "Traktor", licensePlate: "", category: .other)
        context.insert(manual)
    }

    /// Reminders relative to today, so previews and UI tests always show upcoming dates.
    @MainActor
    private static func insertReminders(for vehicle: Vehicle, into context: ModelContext) {
        let today = CalendarDay.today(in: .current)
        let defaults = AustriaReminderDefaults()

        let winter = Reminder(category: .tyreWinter, vehicle: vehicle)
        winter.leadDays = defaults.tyreLeadDays
        winter.dueDate = defaults.nextTyreChangeDay(for: .winter, from: today)
        context.insert(winter)

        let vignette = Reminder(category: .vignette, vehicle: vehicle)
        vignette.leadDays = AustriaReminderDefaults.vignetteExpiryLeadDays
        vignette.dueDate = defaults.nextVignetteExpiry(from: today)
        context.insert(vignette)

        // By odometer: the two readings of the sample vehicle give an estimated date.
        let service = Reminder(category: .service, vehicle: vehicle)
        service.title = "Oil service"
        service.dueKm = 75_000
        service.repeatMonths = 12
        service.repeatKm = 15_000
        context.insert(service)

        let insurance = Reminder(category: .custom, vehicle: vehicle)
        insurance.title = "Insurance"
        insurance.dueDate = today.adding(months: 2)
        insurance.leadDays = 7
        insurance.repeatRule = .yearly
        context.insert(insurance)
    }
}

extension PreviewData {
    /// History of the sample vehicle, relative to this year: entries two years ago and this year, nothing
    /// last year (a zero year in the chart), one cost in Swiss francs and one entry without a cost.
    @MainActor
    fileprivate static func insertHistory(for vehicle: Vehicle, into context: ModelContext) {
        let year = CalendarDay.today(in: .current).year
        func add(
            _ y: Int, _ m: Int, _ d: Int, _ category: MaintenanceCategory, _ amount: Int?, workshop: String,
            work: String, km: Int? = nil, currency: String = "EUR"
        ) {
            let entry = MaintenanceEntry(
                date: DayDate(year: y, month: m, day: d) ?? DayDate(year: y, month: 1, day: 1)!,
                category: category, vehicle: vehicle)
            entry.amountMinor = amount
            entry.currencyCode = currency
            entry.workshop = workshop
            entry.workItems = work
            entry.odometerKm = km
            context.insert(entry)
        }
        add(year - 2, 3, 14, .service, 24_590, workshop: "Autohaus Müller",
            work: "Oil change\nOil filter\nAir filter\nCabin filter", km: 41_200)
        add(year - 2, 5, 22, .inspection, 4_150, workshop: "ÖAMTC Prüfzentrum", work: "§57a inspection", km: 42_900)
        add(year - 2, 10, 30, .tyres, 38_000, workshop: "Reifen Huber", work: "Four winter tyres, mounting and balancing")
        add(year, 2, 9, .repair, 42_000, workshop: "Autohaus Müller",
            work: "Replace brake pads and discs, front", km: 66_300)
        add(year, 4, 2, .tyres, 8_900, workshop: "Reifen Huber", work: "Tyre change")
        add(year, 6, 18, .repair, 18_000, workshop: "Garage Bärtschi", work: "Replace windscreen wiper motor",
            currency: "CHF")
        add(year, 7, 3, .otherWorkshop, nil, workshop: "Car wash", work: "Interior cleaning")
    }
}
