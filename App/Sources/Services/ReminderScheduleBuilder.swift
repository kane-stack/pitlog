import Foundation
import PitlogCore

/// Maps stored reminders and vehicles to the pure `ReminderSchedule` values of PitlogCore.
struct ReminderScheduleBuilder: Sendable {
    let inspectionService: InspectionService
    let defaultsRegistry: ReminderDefaultsRegistry

    init(
        inspectionService: InspectionService = InspectionService(),
        defaultsRegistry: ReminderDefaultsRegistry = .standard
    ) {
        self.inspectionService = inspectionService
        self.defaultsRegistry = defaultsRegistry
    }

    func defaults(for vehicle: Vehicle) -> any ReminderDefaults {
        defaultsRegistry.defaults(for: CountryCode(rawValue: vehicle.countryCode)) ?? AustriaReminderDefaults()
    }

    /// All schedules of a vehicle: the derived inspection reminder (if switched on) and the enabled stored ones.
    /// `today` is the device's day, `inspectionToday` the day the inspection rules are evaluated for.
    func schedules(for vehicle: Vehicle, today: DayDate, inspectionToday: DayDate) -> [ReminderSchedule] {
        var result: [ReminderSchedule] = []
        if vehicle.inspectionRemindersEnabled,
           let status = inspectionService.evaluate(vehicle, today: inspectionToday).status {
            result.append(.inspection(vehicleID: vehicle.id.uuidString, status: status))
        }
        let defaults = defaults(for: vehicle)
        let projection = vehicle.odometerProjection
        for reminder in vehicle.reminders ?? [] where reminder.isEnabled {
            if let schedule = reminder.schedule(
                vehicleID: vehicle.id.uuidString, projection: projection, defaults: defaults, today: today)
            {
                result.append(schedule)
            }
        }
        return result
    }
}

extension Vehicle {
    /// Estimate of the daily mileage from the odometer readings, in the device's calendar.
    var odometerProjection: OdometerProjection? {
        let samples = (odometerReadings ?? []).map {
            OdometerSample(day: CalendarDay.dayDate(from: $0.date, in: .current), km: $0.kilometers)
        }
        return OdometerProjection(samples: samples)
    }
}

extension Reminder {
    /// `nil` if the reminder has no date or odometer value to work with.
    func schedule(
        vehicleID: String,
        projection: OdometerProjection?,
        defaults: any ReminderDefaults,
        today: DayDate
    ) -> ReminderSchedule? {
        let kind: ReminderSchedule.Kind
        switch category {
        case .tyreWinter, .tyreSummer:
            let season: TyreSeason = category == .tyreWinter ? .winter : .summer
            let first = dueDate ?? defaults.nextTyreChangeDay(for: season, from: today)
            kind = .tyreChange(TyreChange(season: season, firstEventDay: first, leadDays: leadDays))
        case .vignette:
            guard let first = dueDate ?? defaults.nextVignetteExpiry(from: today) else { return nil }
            kind = .vignette(VignetteDue(
                firstExpiryDay: first, leadDays: leadDays, announce: defaults.vignette?.newVignetteAvailable))
        case .service:
            guard dueDate != nil || dueKm != nil else { return nil }
            kind = .service(ServiceDue(
                dueDay: dueDate, dueKm: dueKm, leadDays: leadDays, leadKm: leadKm,
                repeatMonths: repeatMonths, repeatKm: repeatKm, projection: projection))
        case .custom:
            guard let due = dueDate else { return nil }
            let recurrence: ReminderRecurrence =
                switch repeatRule {
                case .none: .none
                case .yearly: .yearly
                case .months: .everyMonths(max(1, repeatMonths ?? 1))
                }
            kind = .custom(CustomDue(dueDay: due, leadDays: leadDays, recurrence: recurrence))
        }
        return ReminderSchedule(vehicleID: vehicleID, reminderID: id.uuidString, title: title, kind: kind)
    }

    /// Writes the date and odometer target of a rescheduled `schedule` back.
    func applyDue(from schedule: ReminderSchedule) {
        switch schedule.kind {
        case .inspection:
            break
        case .tyreChange(let tyre):
            dueDate = tyre.firstEventDay
        case .vignette(let vignette):
            dueDate = vignette.firstExpiryDay
        case .custom(let custom):
            dueDate = custom.dueDay
        case .service(let service):
            dueDate = service.dueDay
            dueKm = service.dueKm
        }
    }

    /// "Done": repeating reminders move to their next occurrence, the others are switched off.
    func complete(
        vehicleID: String,
        projection: OdometerProjection?,
        defaults: any ReminderDefaults,
        today: DayDate,
        km: Int?,
        now: Date = Date()
    ) {
        defer { lastCompletedAt = now }
        guard let schedule = schedule(vehicleID: vehicleID, projection: projection, defaults: defaults, today: today)
        else {
            isEnabled = false
            return
        }
        switch schedule.completed(on: today, atKm: km) {
        case .finished:
            isEnabled = false
        case .rescheduled(let next):
            applyDue(from: next)
        }
    }
}
