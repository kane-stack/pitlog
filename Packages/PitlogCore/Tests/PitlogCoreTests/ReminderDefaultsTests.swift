import Testing
@testable import PitlogCore

let atDefaults = AustriaReminderDefaults()

@Test func austriaTyreSeasonDates() {
    // AT-72: winter period 1 November to 15 April
    #expect(atDefaults.tyreChangeDay(for: .winter) == MonthDay(month: 11, day: 1))
    #expect(atDefaults.tyreChangeDay(for: .summer) == MonthDay(month: 4, day: 15))
    #expect(atDefaults.tyreLeadDays == 14)
    #expect(atDefaults.country == .austria)
}

@Test func austriaVignetteDates() throws {
    // AT-70: valid from 1 December of the previous year until 31 January
    let vignette = try #require(atDefaults.vignette)
    #expect(vignette.newVignetteAvailable == MonthDay(month: 12, day: 1))
    #expect(vignette.validUntil == MonthDay(month: 1, day: 31))
    // AT-71: first day of validity at the earliest the 18th day after a remote purchase
    #expect(vignette.remotePurchaseDelayDays == 18)
    #expect(vignette.expiryLeadDays == 25)
    // the 25 day lead leaves a week of buffer to the 18 day delay
    #expect(vignette.expiryLeadDays - vignette.remotePurchaseDelayDays == 7)
}

@Test func registryFindsAustria() {
    #expect(ReminderDefaultsRegistry.standard.defaults(for: .austria) != nil)
    #expect(ReminderDefaultsRegistry.standard.defaults(for: CountryCode(rawValue: "XX")) == nil)
}

struct TyreDefaultCase: Sendable {
    let rules: String
    let season: TyreSeason
    let today: DayDate
    let event: DayDate
    let fire: DayDate
}

let tyreDefaultCases: [TyreDefaultCase] = [
    // AT-72 winter: 14 days before 1 November is 18 October
    .init(rules: "AT-72", season: .winter, today: day(2026, 10, 5), event: day(2026, 11, 1), fire: day(2026, 10, 18)),
    // on the legal day itself the event is still ahead, the fire day is long past
    .init(rules: "AT-72", season: .winter, today: day(2026, 11, 1), event: day(2026, 11, 1), fire: day(2026, 10, 18)),
    // across the year boundary: December asks for next November
    .init(rules: "AT-72", season: .winter, today: day(2026, 12, 20), event: day(2027, 11, 1), fire: day(2027, 10, 18)),
    // AT-72 summer: 14 days before 15 April is 1 April
    .init(rules: "AT-72", season: .summer, today: day(2026, 10, 5), event: day(2027, 4, 15), fire: day(2027, 4, 1)),
    .init(rules: "AT-72", season: .summer, today: day(2027, 1, 2), event: day(2027, 4, 15), fire: day(2027, 4, 1)),
    .init(rules: "AT-72", season: .summer, today: day(2027, 4, 16), event: day(2028, 4, 15), fire: day(2028, 4, 1)),
]

@Test(arguments: tyreDefaultCases)
func tyreReminderFromDefaults(_ c: TyreDefaultCase) {
    let first = atDefaults.nextTyreChangeDay(for: c.season, from: c.today)
    #expect(first == c.event, "\(c.rules)")
    let schedule = ReminderSchedule(
        vehicleID: "v", reminderID: "r",
        kind: .tyreChange(TyreChange(season: c.season, firstEventDay: first, leadDays: atDefaults.tyreLeadDays)))
    let next = schedule.nextOccurrence(today: c.today)
    #expect(next?.eventDay == c.event, "\(c.rules)")
    #expect(next?.fireDay == c.fire, "\(c.rules)")
}

struct VignetteDefaultCase: Sendable {
    let rules: String
    let today: DayDate
    let expiry: DayDate
    /// Planned notifications in order: kind and fire day.
    let planned: [Fire]
}

struct Fire: Hashable, Sendable {
    let kind: PlannedNotification.Kind
    let day: DayDate
}

func fire(_ kind: PlannedNotification.Kind, _ day: DayDate) -> Fire {
    Fire(kind: kind, day: day)
}

func fires(_ notifications: [PlannedNotification]) -> [Fire] {
    notifications.map { Fire(kind: $0.kind, day: $0.fireDay) }
}

let vignetteDefaultCases: [VignetteDefaultCase] = [
    // AT-70: announcement on 1 December, expiry reminder 25 days before 31 January (6 January)
    .init(rules: "AT-70", today: day(2026, 10, 5), expiry: day(2027, 1, 31), planned: [
        fire(.vignetteNew, day(2026, 12, 1)), fire(.vignetteExpiring, day(2027, 1, 6)),
        fire(.vignetteNew, day(2027, 12, 1)), fire(.vignetteExpiring, day(2028, 1, 6)),
    ]),
    // between the announcement and the expiry reminder
    .init(rules: "AT-70", today: day(2026, 12, 20), expiry: day(2027, 1, 31), planned: [
        fire(.vignetteExpiring, day(2027, 1, 6)),
        fire(.vignetteNew, day(2027, 12, 1)), fire(.vignetteExpiring, day(2028, 1, 6)),
        fire(.vignetteNew, day(2028, 12, 1)),
    ]),
    // across the year boundary: after 31 January the next cycle ends 31 January 2028
    .init(rules: "AT-70", today: day(2027, 2, 1), expiry: day(2028, 1, 31), planned: [
        fire(.vignetteNew, day(2027, 12, 1)), fire(.vignetteExpiring, day(2028, 1, 6)),
        fire(.vignetteNew, day(2028, 12, 1)), fire(.vignetteExpiring, day(2029, 1, 6)),
    ]),
]

@Test(arguments: vignetteDefaultCases)
func vignetteReminderFromDefaults(_ c: VignetteDefaultCase) throws {
    let vignette = try #require(atDefaults.vignette)
    let expiry = try #require(atDefaults.nextVignetteExpiry(from: c.today))
    #expect(expiry == c.expiry, "\(c.rules)")
    let schedule = ReminderSchedule(
        vehicleID: "v", reminderID: "r",
        kind: .vignette(VignetteDue(
            firstExpiryDay: expiry, leadDays: vignette.expiryLeadDays, announce: vignette.newVignetteAvailable)))
    let planned = NotificationPlanner.plan(schedules: [schedule], today: c.today, limit: 4)
    #expect(fires(planned) == c.planned, "\(c.rules)")
}
