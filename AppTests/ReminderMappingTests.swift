import Foundation
import PitlogCore
import SwiftData
import Testing

@testable import Pitlog

@MainActor
struct ReminderMappingTests {
    private let austria = AustriaReminderDefaults()
    private let today = DayDate(year: 2026, month: 10, day: 5)!

    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayDate { DayDate(year: y, month: m, day: d)! }

    private func makeSchedule(_ reminder: Reminder, projection: OdometerProjection? = nil) -> ReminderSchedule? {
        reminder.schedule(vehicleID: "v", projection: projection, defaults: austria, today: today)
    }

    // MARK: Reminder -> ReminderSchedule

    @Test func tyreReminderPrefilledFromTheCountryDefaults() throws {
        let reminder = Reminder(category: .tyreWinter)
        let schedule = try #require(makeSchedule(reminder))
        guard case .tyreChange(let tyre) = schedule.kind else { Issue.record("not a tyre change"); return }
        #expect(tyre.season == .winter)
        #expect(tyre.firstEventDay == day(2026, 11, 1))
        #expect(tyre.leadDays == 14)
        #expect(schedule.reminderID == reminder.id.uuidString)
    }

    @Test func summerTyreReminderUsesTheEndOfTheWinterPeriod() throws {
        let reminder = Reminder(category: .tyreSummer)
        reminder.dueDate = day(2027, 4, 15)
        reminder.leadDays = 10
        let schedule = try #require(makeSchedule(reminder))
        guard case .tyreChange(let tyre) = schedule.kind else { Issue.record("not a tyre change"); return }
        #expect(tyre.season == .summer)
        #expect(tyre.firstEventDay == day(2027, 4, 15))
        #expect(tyre.leadDays == 10)
    }

    @Test func vignetteReminderUsesTheAustrianDates() throws {
        let reminder = Reminder(category: .vignette)
        reminder.leadDays = 25
        let schedule = try #require(makeSchedule(reminder))
        guard case .vignette(let vignette) = schedule.kind else { Issue.record("not a vignette"); return }
        #expect(vignette.firstExpiryDay == day(2027, 1, 31))
        #expect(vignette.announce == MonthDay(month: 12, day: 1))
        #expect(vignette.leadDays == 25)
    }

    @Test func serviceReminderMapsDateKmAndRepeat() throws {
        let reminder = Reminder(category: .service)
        reminder.title = "Oil"
        reminder.dueDate = day(2027, 3, 1)
        reminder.dueKm = 75_000
        reminder.leadDays = 21
        reminder.leadKm = 800
        reminder.repeatMonths = 12
        reminder.repeatKm = 15_000
        let schedule = try #require(makeSchedule(reminder))
        #expect(schedule.title == "Oil")
        guard case .service(let service) = schedule.kind else { Issue.record("not a service"); return }
        #expect(service.dueDay == day(2027, 3, 1))
        #expect(service.dueKm == 75_000)
        #expect(service.leadDays == 21)
        #expect(service.leadKm == 800)
        #expect(service.repeatMonths == 12)
        #expect(service.repeatKm == 15_000)
    }

    @Test func serviceWithoutDateAndKmHasNoSchedule() {
        #expect(makeSchedule(Reminder(category: .service)) == nil)
    }

    @Test func customReminderMapsRepeat() throws {
        let reminder = Reminder(category: .custom)
        reminder.title = "Insurance"
        reminder.dueDate = day(2026, 12, 1)
        for (rule, months, expected) in [
            (ReminderRepeatRule.none, nil, ReminderRecurrence.none),
            (.yearly, nil, .yearly),
            (.months, 3, .everyMonths(3)),
            (.months, nil, .everyMonths(1)),
        ] as [(ReminderRepeatRule, Int?, ReminderRecurrence)] {
            reminder.repeatRule = rule
            reminder.repeatMonths = months
            let schedule = try #require(makeSchedule(reminder))
            guard case .custom(let custom) = schedule.kind else { Issue.record("not custom"); return }
            #expect(custom.recurrence == expected)
        }
    }

    @Test func customReminderWithoutDateHasNoSchedule() {
        #expect(makeSchedule(Reminder(category: .custom)) == nil)
    }

    @Test func unknownRawValuesFallBack() {
        let reminder = Reminder()
        reminder.kindRaw = "hovercraft"
        reminder.repeatRaw = "weekly"
        #expect(reminder.category == .custom)
        #expect(reminder.repeatRule == .none)
    }

    @Test func dueDateRoundTrips() {
        let reminder = Reminder()
        reminder.dueDate = day(2027, 2, 28)
        #expect(reminder.dueYear == 2027 && reminder.dueMonth == 2 && reminder.dueDay == 28)
        reminder.dueDate = nil
        #expect(reminder.dueYear == nil && reminder.dueMonth == nil && reminder.dueDay == nil)
    }

    // MARK: Done

    @Test func doneAdvancesARepeatingService() {
        let reminder = Reminder(category: .service)
        reminder.dueDate = day(2026, 3, 1)
        reminder.dueKm = 60_000
        reminder.repeatMonths = 12
        reminder.repeatKm = 15_000
        let now = Date(timeIntervalSince1970: 1_000)
        reminder.complete(
            vehicleID: "v", projection: nil, defaults: austria, today: day(2026, 3, 10), km: 61_200, now: now)
        #expect(reminder.dueDate == day(2027, 3, 10))
        #expect(reminder.dueKm == 76_200)
        #expect(reminder.isEnabled)
        #expect(reminder.lastCompletedAt == now)
    }

    @Test func doneSwitchesOffANonRepeatingService() {
        let reminder = Reminder(category: .service)
        reminder.dueDate = day(2026, 3, 1)
        reminder.complete(vehicleID: "v", projection: nil, defaults: austria, today: day(2026, 3, 10), km: nil)
        #expect(!reminder.isEnabled)
        #expect(reminder.lastCompletedAt != nil)
        #expect(reminder.dueDate == day(2026, 3, 1))
    }

    @Test func doneMovesATyreChangeToNextYear() {
        let reminder = Reminder(category: .tyreWinter)
        reminder.dueDate = day(2026, 11, 1)
        reminder.complete(vehicleID: "v", projection: nil, defaults: austria, today: day(2026, 10, 20), km: nil)
        #expect(reminder.dueDate == day(2027, 11, 1))
        #expect(reminder.isEnabled)
    }

    @Test func doneMovesARepeatingCustomReminderOn() {
        let reminder = Reminder(category: .custom)
        reminder.dueDate = day(2026, 10, 10)
        reminder.repeatRule = .months
        reminder.repeatMonths = 6
        reminder.complete(vehicleID: "v", projection: nil, defaults: austria, today: today, km: nil)
        #expect(reminder.dueDate == day(2027, 4, 10))
    }

    // MARK: Vehicle -> schedules

    @Test func buildsInspectionAndStoredSchedules() throws {
        let context = ModelContext(try ModelContainerFactory.inMemory())
        let vehicle = Vehicle(
            name: "Golf", category: .passengerCar,
            firstRegistration: YearMonth(year: 2018, month: 1), plaque: YearMonth(year: 2028, month: 1))
        context.insert(vehicle)
        let on = Reminder(category: .tyreWinter, vehicle: vehicle)
        context.insert(on)
        let off = Reminder(category: .tyreSummer, vehicle: vehicle)
        off.isEnabled = false
        context.insert(off)

        let builder = ReminderScheduleBuilder()
        var schedules = builder.schedules(for: vehicle, today: today, inspectionToday: today)
        #expect(schedules.count == 2)
        #expect(schedules.contains { $0.reminderID == ReminderSchedule.inspectionReminderID })
        #expect(schedules.contains { $0.reminderID == on.id.uuidString })

        vehicle.inspectionRemindersEnabled = false
        schedules = builder.schedules(for: vehicle, today: today, inspectionToday: today)
        #expect(schedules.map(\.reminderID) == [on.id.uuidString])
    }

    @Test func odometerProjectionFromReadings() throws {
        let context = ModelContext(try ModelContainerFactory.inMemory())
        let vehicle = Vehicle(name: "Golf")
        context.insert(vehicle)
        #expect(vehicle.odometerProjection == nil)
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        context.insert(OdometerReading(date: start, kilometers: 10_000, vehicle: vehicle))
        #expect(vehicle.odometerProjection == nil)
        context.insert(OdometerReading(date: start.addingTimeInterval(30 * 86_400), kilometers: 10_900, vehicle: vehicle))
        let projection = try #require(vehicle.odometerProjection)
        #expect(projection.isEstimate)
        #expect(projection.kmPerDay > 29 && projection.kmPerDay < 31)
    }

    // MARK: Storage

    @Test func deletingAVehicleCascadesToReminders() throws {
        let context = ModelContext(try ModelContainerFactory.inMemory())
        let vehicle = Vehicle(name: "Golf")
        context.insert(vehicle)
        context.insert(Reminder(category: .custom, vehicle: vehicle))
        context.insert(Reminder(category: .service, vehicle: vehicle))
        let other = Vehicle(name: "Other")
        context.insert(other)
        context.insert(Reminder(category: .custom, vehicle: other))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Reminder>()) == 3)
        #expect(vehicle.reminders?.count == 2)

        context.delete(vehicle)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Reminder>()) == 1)
    }

    @Test func newVehicleHasInspectionRemindersOn() {
        #expect(Vehicle().inspectionRemindersEnabled)
    }

    // MARK: Settings and router

    @Test func settingsFallBackToTheProductDefaults() throws {
        let suite = "pitlog-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = ReminderSettings.load(from: defaults)
        #expect(settings.isEnabled)
        #expect(settings.hour == 9 && settings.minute == 0)
        #expect(settings.tyreLeadDays == 14)
        #expect(settings.vignetteLeadDays == 25)
        #expect(settings.serviceLeadKm == 500)

        defaults.set(false, forKey: ReminderSettings.Keys.enabled)
        defaults.set(7, forKey: ReminderSettings.Keys.hour)
        defaults.set(0, forKey: ReminderSettings.Keys.tyreLeadDays)
        let changed = ReminderSettings.load(from: defaults)
        #expect(!changed.isEnabled)
        #expect(changed.hour == 7)
        #expect(changed.tyreLeadDays == 0)
    }

    @Test func routerKeepsTheVehicleToOpen() {
        let router = AppRouter()
        #expect(router.pendingVehicleID == nil)
        router.openVehicle(id: "abc")
        #expect(router.pendingVehicleID == "abc")
    }
}
