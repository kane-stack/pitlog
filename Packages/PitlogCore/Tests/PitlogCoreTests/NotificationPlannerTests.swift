import Foundation
import Testing
@testable import PitlogCore

// MARK: Helpers

func status(
    dueMonth: YearMonth, opens: DayDate, closes: DayDate,
    phase: InspectionPhase = .notYetOpen, regime: LegalRegime = .amendedLaw
) -> InspectionStatus {
    InspectionStatus(
        dueMonth: dueMonth, dueMonthSource: .plaque, window: InspectionWindow(opens: opens, closes: closes),
        phase: phase, regime: regime, notes: [], exchangePlaqueSuggestion: nil, ruleVersion: "test")
}

func custom(
    _ id: String, due: DayDate, lead: Int = 0, recurrence: ReminderRecurrence = .none, vehicle: String = "v"
) -> ReminderSchedule {
    ReminderSchedule(
        vehicleID: vehicle, reminderID: id, title: id,
        kind: .custom(CustomDue(dueDay: due, leadDays: lead, recurrence: recurrence)))
}

// MARK: Inspection reminders

struct InspectionReminderCase: Sendable {
    let rules: String
    let status: InspectionStatus
    let today: DayDate
    let expected: [Fire]
}

let inspectionReminderCases: [InspectionReminderCase] = [
    // AT-41 amended law: window 2027-09-01 to 2028-01-31 for due month 2028-01
    .init(
        rules: "AT-41",
        status: status(dueMonth: ym(2028, 1), opens: day(2027, 9, 1), closes: day(2028, 1, 31)),
        today: day(2027, 6, 1),
        expected: [
            fire(.inspectionWindowOpens, day(2027, 9, 1)),
            fire(.inspectionMonthBefore, day(2027, 12, 1)),
            fire(.inspectionDueMonth, day(2028, 1, 1)),
            fire(.inspectionClosingSoon, day(2028, 1, 24)),
        ]),
    // AT-56 transition: due 2027-08, window 2027-05-19 to 2027-11-30
    .init(
        rules: "AT-56",
        status: status(dueMonth: ym(2027, 8), opens: day(2027, 5, 19), closes: day(2027, 11, 30), regime: .transition),
        today: day(2027, 1, 15),
        expected: [
            fire(.inspectionWindowOpens, day(2027, 5, 19)),
            fire(.inspectionMonthBefore, day(2027, 7, 1)),
            fire(.inspectionDueMonth, day(2027, 8, 1)),
            fire(.inspectionClosingSoon, day(2027, 11, 23)),
        ]),
    // AT-56: the window has opened already, so it is not announced
    .init(
        rules: "AT-56",
        status: status(dueMonth: ym(2027, 8), opens: day(2027, 5, 19), closes: day(2027, 11, 30), phase: .open, regime: .transition),
        today: day(2027, 6, 10),
        expected: [
            fire(.inspectionMonthBefore, day(2027, 7, 1)),
            fire(.inspectionDueMonth, day(2027, 8, 1)),
            fire(.inspectionClosingSoon, day(2027, 11, 23)),
        ]),
    // AT-40 previous law: the window opens on the first day of the month before the due month,
    // so that day is announced once
    .init(
        rules: "AT-40",
        status: status(dueMonth: ym(2026, 12), opens: day(2026, 11, 1), closes: day(2027, 4, 30), regime: .previousLaw),
        today: day(2026, 10, 5),
        expected: [
            fire(.inspectionWindowOpens, day(2026, 11, 1)),
            fire(.inspectionDueMonth, day(2026, 12, 1)),
            fire(.inspectionClosingSoon, day(2027, 4, 23)),
        ]),
    // only the last reminder is still ahead
    .init(
        rules: "AT-41",
        status: status(dueMonth: ym(2028, 1), opens: day(2027, 9, 1), closes: day(2028, 1, 31), phase: .closesThisMonth),
        today: day(2028, 1, 10),
        expected: [fire(.inspectionClosingSoon, day(2028, 1, 24))]),
    // overdue: the window has closed, one notice for the next day
    .init(
        rules: "AT-40",
        status: status(dueMonth: ym(2026, 1), opens: day(2025, 12, 1), closes: day(2026, 5, 31), phase: .overdue, regime: .previousLaw),
        today: day(2026, 10, 5),
        expected: [fire(.inspectionOverdue, day(2026, 10, 6))]),
    // overdue in the transition window, across a year end
    .init(
        rules: "AT-56",
        status: status(dueMonth: ym(2027, 8), opens: day(2027, 5, 19), closes: day(2027, 11, 30), phase: .overdue, regime: .transition),
        today: day(2027, 12, 31),
        expected: [fire(.inspectionOverdue, day(2028, 1, 1))]),
    // the last day of the window is not overdue yet: nothing is left to plan
    .init(
        rules: "AT-56",
        status: status(dueMonth: ym(2027, 8), opens: day(2027, 5, 19), closes: day(2027, 11, 30), phase: .closesThisMonth, regime: .transition),
        today: day(2027, 11, 30),
        expected: []),
]

@Test(arguments: inspectionReminderCases)
func inspectionReminderDates(_ c: InspectionReminderCase) {
    let schedule = ReminderSchedule.inspection(vehicleID: "v", status: c.status)
    #expect(fires(NotificationPlanner.plan(schedules: [schedule], today: c.today)) == c.expected, "\(c.rules)")
}

@Test func inspectionReminderFromTheEngineInTheTransitionWindow() throws {
    // AT-56: plaque 2027-08 closes on 2027-11-30
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2015, 8), plaque: ym(2027, 8))
    let today = day(2027, 1, 15)
    let status = try austria.status(for: input, today: today)
    #expect(status.window.closes == day(2027, 11, 30))
    let planned = NotificationPlanner.plan(
        schedules: [.inspection(vehicleID: "v", status: status)], today: today)
    #expect(planned.last?.fireDay == day(2027, 11, 23))
    #expect(planned.last?.eventDay == day(2027, 11, 30))
    #expect(planned.map(\.kind).contains(.inspectionDueMonth))
}

// MARK: Planner

@Test func plannerDropsPastDaysAndKeepsToday() {
    let today = day(2026, 10, 5)
    let schedules = [
        custom("past", due: day(2026, 10, 1)),
        custom("yesterdayFire", due: day(2026, 10, 8), lead: 4),
        custom("today", due: today),
        custom("tomorrow", due: day(2026, 10, 6)),
    ]
    let planned = NotificationPlanner.plan(schedules: schedules, today: today)
    #expect(planned.map(\.reminderID) == ["today", "tomorrow"])
}

@Test func plannerSortsByFireDay() {
    let today = day(2026, 1, 1)
    let schedules = [
        custom("c", due: day(2026, 6, 1)),
        custom("a", due: day(2026, 2, 1)),
        custom("b", due: day(2026, 3, 1), lead: 30),
    ]
    let planned = NotificationPlanner.plan(schedules: schedules, today: today)
    #expect(planned.map(\.reminderID) == ["b", "a", "c"])
    #expect(planned.map(\.fireDay) == [day(2026, 1, 30), day(2026, 2, 1), day(2026, 6, 1)])
}

@Test func plannerRemovesDuplicates() {
    let today = day(2026, 1, 1)
    let one = custom("same", due: day(2026, 2, 1))
    let planned = NotificationPlanner.plan(schedules: [one, one], today: today)
    #expect(planned.count == 1)
}

@Test func plannerIDsAreStableAndDistinguishVehicleReminderKindAndDay() {
    let today = day(2026, 1, 1)
    let first = NotificationPlanner.plan(schedules: [custom("r", due: day(2026, 2, 1), vehicle: "A")], today: today)
    let again = NotificationPlanner.plan(schedules: [custom("r", due: day(2026, 2, 1), vehicle: "A")], today: today)
    #expect(first.map(\.id) == again.map(\.id))
    #expect(first.first?.id == "A/r/custom/2026-02-01")
    let other = NotificationPlanner.plan(schedules: [custom("r", due: day(2026, 2, 1), vehicle: "B")], today: today)
    #expect(first.first?.id != other.first?.id)
    let moved = NotificationPlanner.plan(schedules: [custom("r", due: day(2026, 2, 2), vehicle: "A")], today: today)
    #expect(first.first?.id != moved.first?.id)
}

@Test func plannerAppliesTheLimitKeepingTheEarliest() {
    let today = day(2026, 1, 1)
    let schedules = (1...70).map { custom("r\($0)", due: today.adding(days: $0)) }
    let planned = NotificationPlanner.plan(schedules: schedules, today: today)
    #expect(planned.count == NotificationPlanner.defaultLimit)
    #expect(NotificationPlanner.defaultLimit < 64)
    #expect(planned.first?.fireDay == today.adding(days: 1))
    #expect(planned.last?.fireDay == today.adding(days: 60))
    #expect(NotificationPlanner.plan(schedules: schedules, today: today, limit: 5).count == 5)
    #expect(NotificationPlanner.plan(schedules: schedules, today: today, limit: 0).isEmpty)
}

// MARK: Service

let serviceProjection = OdometerProjection(
    samples: [sample(day(2026, 1, 1), 10_000), sample(day(2026, 1, 31), 10_900)])

func service(_ due: ServiceDue) -> ReminderSchedule {
    ReminderSchedule(vehicleID: "v", reminderID: "s", title: "Service", kind: .service(due))
}

@Test func serviceByDate() {
    let planned = NotificationPlanner.plan(
        schedules: [service(ServiceDue(dueDay: day(2027, 3, 15), leadDays: 14))], today: day(2027, 1, 1))
    #expect(fires(planned) == [fire(.serviceDate, day(2027, 3, 1))])
    #expect(planned.first?.eventDay == day(2027, 3, 15))
    #expect(planned.first?.isEstimate == false)
}

@Test func serviceByKmUsesTheProjectionAndIsAnEstimate() {
    let due = ServiceDue(dueKm: 12_000, leadKm: 500, projection: serviceProjection)
    let planned = NotificationPlanner.plan(schedules: [service(due)], today: day(2026, 2, 1))
    // 11 500 km on 2026-02-20, 12 000 km on 2026-03-09
    #expect(fires(planned) == [fire(.serviceKm, day(2026, 2, 20))])
    #expect(planned.first?.eventDay == day(2026, 3, 9))
    #expect(planned.first?.dueKm == 12_000)
    #expect(planned.first?.isEstimate == true)
}

@Test func serviceByKmUsesTheDefaultLeadOf500Km() {
    #expect(ServiceDue.defaultLeadKm == 500)
    let due = ServiceDue(dueKm: 12_000, projection: serviceProjection)
    #expect(due.leadKm == 500)
}

@Test func serviceByDateAndKmPlansBoth() {
    let due = ServiceDue(
        dueDay: day(2026, 6, 1), dueKm: 12_000, leadDays: 10, leadKm: 500, projection: serviceProjection)
    let planned = NotificationPlanner.plan(schedules: [service(due)], today: day(2026, 2, 1))
    #expect(fires(planned) == [fire(.serviceKm, day(2026, 2, 20)), fire(.serviceDate, day(2026, 5, 22))])
}

@Test func serviceByKmWithoutProjectionPlansNothing() {
    let single = OdometerProjection(samples: [sample(day(2026, 1, 1), 10_000)])
    #expect(single == nil)
    let planned = NotificationPlanner.plan(
        schedules: [service(ServiceDue(dueKm: 12_000, projection: single))], today: day(2026, 2, 1))
    #expect(planned.isEmpty)
}

@Test func serviceByKmAlreadyReachedPlansNothing() {
    let due = ServiceDue(dueKm: 10_500, leadKm: 500, projection: serviceProjection)
    #expect(NotificationPlanner.plan(schedules: [service(due)], today: day(2026, 2, 1)).isEmpty)
}

@Test func serviceWithoutDateAndKmPlansNothing() {
    #expect(NotificationPlanner.plan(schedules: [service(ServiceDue())], today: day(2026, 2, 1)).isEmpty)
}

// MARK: Custom and repeating

struct CustomCase: Sendable {
    let name: String
    let due: DayDate
    let recurrence: ReminderRecurrence
    let today: DayDate
    let events: [DayDate]
}

let customCases: [CustomCase] = [
    .init(name: "once, ahead", due: day(2027, 5, 1), recurrence: .none, today: day(2027, 1, 1), events: [day(2027, 5, 1)]),
    .init(name: "once, past", due: day(2027, 5, 1), recurrence: .none, today: day(2027, 5, 2), events: []),
    .init(
        name: "yearly, anchor long ago", due: day(2025, 6, 10), recurrence: .yearly, today: day(2026, 7, 1),
        events: [day(2027, 6, 10), day(2028, 6, 10), day(2029, 6, 10), day(2030, 6, 10)]),
    .init(
        name: "every 3 months from a 31st", due: day(2026, 1, 31), recurrence: .everyMonths(3), today: day(2026, 3, 1),
        events: [day(2026, 4, 30), day(2026, 7, 31), day(2026, 10, 31), day(2027, 1, 31)]),
    .init(
        name: "every month from a 31st", due: day(2026, 1, 31), recurrence: .everyMonths(1), today: day(2026, 2, 15),
        events: [day(2026, 2, 28), day(2026, 3, 31), day(2026, 4, 30), day(2026, 5, 31)]),
    .init(
        name: "due today", due: day(2026, 3, 1), recurrence: .yearly, today: day(2026, 3, 1),
        events: [day(2026, 3, 1), day(2027, 3, 1), day(2028, 3, 1), day(2029, 3, 1)]),
]

@Test(arguments: customCases)
func customOccurrences(_ c: CustomCase) {
    let schedule = custom("c", due: c.due, recurrence: c.recurrence)
    #expect(schedule.occurrences(today: c.today).map(\.eventDay) == c.events, "\(c.name)")
}

@Test func customLeadDaysShiftTheFireDay() {
    let planned = NotificationPlanner.plan(
        schedules: [custom("c", due: day(2027, 5, 1), lead: 7)], today: day(2027, 1, 1))
    #expect(planned.first?.fireDay == day(2027, 4, 24))
    #expect(planned.first?.daysUntilEvent == 7)
}

@Test func nextOccurrencePicksTheEarliestEventDay() throws {
    let vignette = ReminderSchedule(
        vehicleID: "v", reminderID: "g",
        kind: .vignette(VignetteDue(
            firstExpiryDay: day(2027, 1, 31), leadDays: 25, announce: AustriaReminderDefaults.vignetteNewAvailable)))
    let next = try #require(vignette.nextOccurrence(today: day(2026, 10, 5)))
    #expect(next.kind == .vignetteNew)
    #expect(next.eventDay == day(2026, 12, 1))
}

// MARK: Completion

func rescheduled(_ completion: ReminderCompletion) -> ReminderSchedule? {
    if case .rescheduled(let schedule) = completion { return schedule }
    return nil
}

@Test func completingARepeatingServiceCountsFromTheServiceDay() throws {
    let due = ServiceDue(dueDay: day(2026, 3, 1), dueKm: 60_000, repeatMonths: 12, repeatKm: 15_000)
    let completion = service(due).completed(on: day(2026, 3, 10), atKm: 61_200)
    let next = try #require(rescheduled(completion))
    guard case .service(let updated) = next.kind else { Issue.record("not a service"); return }
    #expect(updated.dueDay == day(2027, 3, 10))
    #expect(updated.dueKm == 76_200)
    #expect(updated.leadKm == due.leadKm)
}

@Test func completingAKmOnlyRepeatFallsBackToTheOldTarget() throws {
    let due = ServiceDue(dueKm: 60_000, repeatKm: 15_000)
    let next = try #require(rescheduled(service(due).completed(on: day(2026, 3, 10), atKm: nil)))
    guard case .service(let updated) = next.kind else { Issue.record("not a service"); return }
    #expect(updated.dueKm == 75_000)
    #expect(updated.dueDay == nil)
}

@Test func completingANonRepeatingServiceFinishesIt() {
    let due = ServiceDue(dueDay: day(2026, 3, 1), dueKm: 60_000)
    #expect(service(due).completed(on: day(2026, 3, 10), atKm: 61_000) == .finished)
}

struct AnchorCase: Sendable {
    let name: String
    let anchor: DayDate
    let today: DayDate
    let expected: DayDate
}

let yearlyAnchorCases: [AnchorCase] = [
    .init(name: "done early", anchor: day(2026, 11, 1), today: day(2026, 10, 20), expected: day(2027, 11, 1)),
    .init(name: "done on the day", anchor: day(2026, 11, 1), today: day(2026, 11, 1), expected: day(2027, 11, 1)),
    .init(name: "done late", anchor: day(2026, 11, 1), today: day(2026, 11, 3), expected: day(2027, 11, 1)),
    .init(name: "done much later", anchor: day(2025, 11, 1), today: day(2026, 10, 20), expected: day(2026, 11, 1)),
]

@Test(arguments: yearlyAnchorCases)
func completingATyreChangeMovesToTheNextYear(_ c: AnchorCase) throws {
    let schedule = ReminderSchedule(
        vehicleID: "v", reminderID: "t",
        kind: .tyreChange(TyreChange(season: .winter, firstEventDay: c.anchor, leadDays: 14)))
    let next = try #require(rescheduled(schedule.completed(on: c.today, atKm: nil)))
    guard case .tyreChange(let tyre) = next.kind else { Issue.record("not a tyre change"); return }
    #expect(tyre.firstEventDay == c.expected, "\(c.name)")
}

@Test func completingAVignetteMovesToTheNextExpiry() throws {
    for (today, expected) in [(day(2026, 12, 5), day(2028, 1, 31)), (day(2027, 2, 3), day(2028, 1, 31))] {
        let schedule = ReminderSchedule(
            vehicleID: "v", reminderID: "g",
            kind: .vignette(VignetteDue(firstExpiryDay: day(2027, 1, 31), leadDays: 25, announce: nil)))
        let next = try #require(rescheduled(schedule.completed(on: today, atKm: nil)))
        guard case .vignette(let vignette) = next.kind else { Issue.record("not a vignette"); return }
        #expect(vignette.firstExpiryDay == expected)
    }
}

let customAnchorCases: [AnchorCase] = [
    .init(name: "monthly, overdue", anchor: day(2026, 1, 10), today: day(2026, 3, 12), expected: day(2026, 4, 10)),
    .init(name: "monthly, early", anchor: day(2026, 3, 10), today: day(2026, 3, 5), expected: day(2026, 4, 10)),
]

@Test(arguments: customAnchorCases)
func completingARepeatingCustomReminder(_ c: AnchorCase) throws {
    let schedule = custom("c", due: c.anchor, recurrence: .everyMonths(1))
    let next = try #require(rescheduled(schedule.completed(on: c.today, atKm: nil)))
    guard case .custom(let updated) = next.kind else { Issue.record("not custom"); return }
    #expect(updated.dueDay == c.expected, "\(c.name)")
}

@Test func completingAOneTimeCustomReminderFinishesIt() {
    #expect(custom("c", due: day(2026, 3, 1)).completed(on: day(2026, 3, 1), atKm: nil) == .finished)
}

@Test func completingAnInspectionReminderIsNotApplicable() {
    let schedule = ReminderSchedule.inspection(
        vehicleID: "v", status: status(dueMonth: ym(2028, 1), opens: day(2027, 9, 1), closes: day(2028, 1, 31)))
    #expect(schedule.completed(on: day(2027, 9, 1), atKm: nil) == .finished)
}

// MARK: Overdue notice

private func overdueSchedule(dueMonth: YearMonth = ym(2026, 1), vehicle: String = "v") -> ReminderSchedule {
    .inspection(
        vehicleID: vehicle,
        status: status(dueMonth: dueMonth, opens: day(2025, 12, 1), closes: day(2026, 5, 31), phase: .overdue, regime: .previousLaw))
}

@Test func overdueNoticeHasAStableIDPerVehicleAndDueMonth() {
    // AT-40
    let first = NotificationPlanner.plan(schedules: [overdueSchedule()], today: day(2026, 10, 5))
    let later = NotificationPlanner.plan(schedules: [overdueSchedule()], today: day(2026, 10, 9))
    #expect(first.first?.id == "v/inspection/inspectionOverdue/2026-01")
    #expect(first.map(\.id) == later.map(\.id))
    let otherMonth = NotificationPlanner.plan(schedules: [overdueSchedule(dueMonth: ym(2026, 2))], today: day(2026, 10, 5))
    let otherVehicle = NotificationPlanner.plan(schedules: [overdueSchedule(vehicle: "w")], today: day(2026, 10, 5))
    #expect(first.first?.id != otherMonth.first?.id)
    #expect(first.first?.id != otherVehicle.first?.id)
    #expect(first.first?.eventDay == day(2026, 5, 31))
}

@Test func overdueNoticeIsNotRepeatedAfterItsDay() {
    // AT-40: first noticed on 5 Oct, it fires on 6 Oct and never again
    var ledger = OverdueNoticeLedger()
    let schedules = [overdueSchedule()]
    let first = NotificationPlanner.plan(schedules: schedules, today: day(2026, 10, 5), ledger: ledger)
    ledger.record(first)
    #expect(fires(first) == [fire(.inspectionOverdue, day(2026, 10, 6))])

    // opening the app on the morning of 6 Oct must not push the notice to the 7th
    let sameDay = NotificationPlanner.plan(schedules: schedules, today: day(2026, 10, 6), ledger: ledger)
    #expect(fires(sameDay) == [fire(.inspectionOverdue, day(2026, 10, 6))])

    // once the day has passed it is gone
    for today in [day(2026, 10, 7), day(2026, 11, 1), day(2027, 6, 1)] {
        #expect(NotificationPlanner.plan(schedules: schedules, today: today, ledger: ledger).isEmpty)
    }
}

@Test func overdueNoticeIsKeptWhenReplannedOnTheSameDay() {
    var ledger = OverdueNoticeLedger()
    let schedules = [overdueSchedule()]
    ledger.record(NotificationPlanner.plan(schedules: schedules, today: day(2026, 10, 5), ledger: ledger))
    let again = NotificationPlanner.plan(schedules: schedules, today: day(2026, 10, 5), ledger: ledger)
    #expect(fires(again) == [fire(.inspectionOverdue, day(2026, 10, 6))])
    var twice = ledger
    twice.record(again)
    #expect(twice == ledger)
}

@Test func aNewDueMonthGetsANewOverdueNotice() {
    var ledger = OverdueNoticeLedger()
    ledger.record(NotificationPlanner.plan(schedules: [overdueSchedule()], today: day(2026, 10, 5), ledger: ledger))
    let next = NotificationPlanner.plan(
        schedules: [overdueSchedule(dueMonth: ym(2026, 2))], today: day(2026, 10, 20), ledger: ledger)
    #expect(fires(next) == [fire(.inspectionOverdue, day(2026, 10, 21))])
}

@Test func ledgerIgnoresOtherKindsAndSurvivesCoding() throws {
    var ledger = OverdueNoticeLedger()
    ledger.record(NotificationPlanner.plan(
        schedules: [overdueSchedule(), custom("c", due: day(2026, 11, 1))], today: day(2026, 10, 5)))
    #expect(ledger.fireDays.count == 1)
    let decoded = try JSONDecoder().decode(OverdueNoticeLedger.self, from: JSONEncoder().encode(ledger))
    #expect(decoded == ledger)
}
