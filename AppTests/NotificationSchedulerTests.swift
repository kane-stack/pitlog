import Foundation
import PitlogCore
import Testing
import UserNotifications

@testable import Pitlog

@MainActor
final class FakeNotificationCenter: UserNotificationCenter {
    var status: NotificationAuthorization = .authorized
    private(set) var pending: [UNNotificationRequest] = []
    private(set) var requestedAuthorization = false

    init(foreignIdentifiers: [String] = []) {
        pending = foreignIdentifiers.map {
            UNNotificationRequest(identifier: $0, content: UNMutableNotificationContent(), trigger: nil)
        }
    }

    func authorizationStatus() async -> NotificationAuthorization { status }

    func requestAuthorization() async throws -> Bool {
        requestedAuthorization = true
        status = .authorized
        return true
    }

    func pendingRequestIdentifiers() async -> [String] { pending.map(\.identifier) }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        pending.removeAll { identifiers.contains($0.identifier) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }
}

private func planned(
    _ vehicle: String, _ reminder: String, _ kind: PlannedNotification.Kind, fire: DayDate, event: DayDate? = nil
) -> PlannedNotification {
    PlannedNotification(
        vehicleID: vehicle, reminderID: reminder, kind: kind, fireDay: fire, eventDay: event ?? fire)
}

private func day(_ y: Int, _ m: Int, _ d: Int) -> DayDate { DayDate(year: y, month: m, day: d)! }

@MainActor
struct NotificationSchedulerTests {
    private let vienna: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna") ?? .gmt
        return calendar
    }()
    private let english = Locale(identifier: "en")
    /// 2026-10-05 08:00 in Vienna.
    private var now: Date { vienna.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 8)) ?? Date() }

    private func run(
        _ scheduler: NotificationScheduler, _ plan: [PlannedNotification],
        settings: ReminderSettings = ReminderSettings(), names: [String: String] = ["v": "Golf"]
    ) async {
        await scheduler.schedule(
            plan: plan, vehicleNames: names, settings: settings, now: now, calendar: vienna, locale: english)
    }

    @Test func addsOneRequestPerPlannedNotificationAtTheConfiguredTime() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        var settings = ReminderSettings()
        settings.hour = 7
        settings.minute = 30
        await run(scheduler, [planned("v", "r", .custom, fire: day(2026, 11, 3))], settings: settings)

        let request = try #require(center.pending.first)
        #expect(center.pending.count == 1)
        #expect(request.identifier == NotificationScheduler.identifierPrefix + "v/r/custom/2026-11-03")
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == false)
        #expect(trigger.dateComponents.year == 2026)
        #expect(trigger.dateComponents.month == 11)
        #expect(trigger.dateComponents.day == 3)
        #expect(trigger.dateComponents.hour == 7)
        #expect(trigger.dateComponents.minute == 30)
    }

    @Test func defaultTimeIsNineInTheMorning() async throws {
        let center = FakeNotificationCenter()
        await run(NotificationScheduler(center: center), [planned("v", "r", .custom, fire: day(2026, 11, 3))])
        let trigger = try #require(center.pending.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 9)
        #expect(trigger.dateComponents.minute == 0)
    }

    @Test func notificationCarriesTheVehicleIDForTheDeepLink() async throws {
        let center = FakeNotificationCenter()
        await run(NotificationScheduler(center: center), [planned("vehicle-42", "r", .custom, fire: day(2026, 11, 3))],
                  names: ["vehicle-42": "Golf"])
        let content = try #require(center.pending.first?.content)
        #expect(content.userInfo[NotificationUserInfo.vehicleID] as? String == "vehicle-42")
        #expect(content.userInfo[NotificationUserInfo.reminderID] as? String == "r")
        #expect(content.title.hasPrefix("Golf"))
    }

    @Test func replanningReplacesInsteadOfDuplicating() async {
        let center = FakeNotificationCenter(foreignIdentifiers: ["somebody.else"])
        let scheduler = NotificationScheduler(center: center)
        let first = [
            planned("v", "a", .custom, fire: day(2026, 11, 1)),
            planned("v", "b", .custom, fire: day(2026, 11, 2)),
            planned("v", "c", .custom, fire: day(2026, 11, 3)),
        ]
        await run(scheduler, first)
        await run(scheduler, first)
        #expect(center.pending.count == 4)

        let second = [
            planned("v", "b", .custom, fire: day(2026, 11, 2)),
            planned("v", "d", .custom, fire: day(2026, 11, 9)),
        ]
        await run(scheduler, second)
        let ids = Set(center.pending.map(\.identifier))
        let prefix = NotificationScheduler.identifierPrefix
        #expect(ids == ["somebody.else", prefix + "v/b/custom/2026-11-02", prefix + "v/d/custom/2026-11-09"])
    }

    @Test func overlappingCallsEndWithTheLastPlan() async {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let old = (1...20).map { planned("v", "old\($0)", .custom, fire: day(2026, 11, 1)) }
        let new = [planned("v", "new", .custom, fire: day(2026, 11, 2))]
        async let first: Void = run(scheduler, old)
        async let second: Void = run(scheduler, new)
        _ = await (first, second)
        #expect(center.pending.map(\.identifier) == [NotificationScheduler.identifierPrefix + "v/new/custom/2026-11-02"])
    }

    @Test func neverSchedulesMoreThanTheSystemLimit() async {
        let center = FakeNotificationCenter()
        let start = day(2026, 11, 1)
        let plan = (0..<70).map { planned("v", "r\($0)", .custom, fire: start.adding(days: $0)) }
        await run(NotificationScheduler(center: center), plan)
        #expect(center.pending.count == NotificationScheduler.maximumRequests)
        #expect(NotificationScheduler.maximumRequests == 64)
    }

    @Test func plannerLimitLeavesHeadroomBelowTheSystemLimit() {
        #expect(NotificationPlanner.defaultLimit < NotificationScheduler.maximumRequests)
    }

    @Test func withoutPermissionNothingIsScheduledAndNoPromptIsShown() async {
        let center = FakeNotificationCenter()
        center.status = .notDetermined
        await run(NotificationScheduler(center: center), [planned("v", "r", .custom, fire: day(2026, 11, 3))])
        #expect(center.pending.isEmpty)
        #expect(!center.requestedAuthorization)
        center.status = .denied
        await run(NotificationScheduler(center: center), [planned("v", "r", .custom, fire: day(2026, 11, 3))])
        #expect(center.pending.isEmpty)
    }

    @Test func masterSwitchOffRemovesEverything() async {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let plan = [planned("v", "r", .custom, fire: day(2026, 11, 3))]
        await run(scheduler, plan)
        #expect(center.pending.count == 1)
        var off = ReminderSettings()
        off.isEnabled = false
        await run(scheduler, plan, settings: off)
        #expect(center.pending.isEmpty)
    }

    @Test func skipsNotificationTimesAlreadyPast() async {
        let center = FakeNotificationCenter()
        // Today at 09:00 is in the future at 08:00, but not at the default time one hour later.
        let today = [planned("v", "r", .custom, fire: day(2026, 10, 5))]
        await run(NotificationScheduler(center: center), today)
        #expect(center.pending.count == 1)
        var early = ReminderSettings()
        early.hour = 7
        await run(NotificationScheduler(center: center), today, settings: early)
        #expect(center.pending.isEmpty)
    }

    @Test func inspectionNotificationsEndWithTheLegalHint() {
        let kinds: [PlannedNotification.Kind] = [
            .inspectionWindowOpens, .inspectionMonthBefore, .inspectionDueMonth, .inspectionClosingSoon,
        ]
        for kind in kinds {
            let item = planned("v", "inspection", kind, fire: day(2027, 7, 1), event: day(2027, 11, 30))
            let text = NotificationTexts.text(for: item, vehicleName: "Golf", locale: english)
            #expect(text.body.hasSuffix("Check the date on your sticker."), "\(kind)")
            #expect(text.title == "Golf · Inspection", "\(kind)")
        }
    }

    @Test func otherNotificationsAreNotInspectionNotificationsAndStayShort() {
        let item = planned("v", "r", .tyreChangeWinter, fire: day(2026, 10, 18), event: day(2026, 11, 1))
        let text = NotificationTexts.text(for: item, vehicleName: "Golf", locale: english)
        #expect(text.title == "Golf · Winter tyres")
        #expect(!text.body.contains("sticker"))
        #expect(text.body.contains("in 14 days"))
    }

    @Test func vignetteExpiryMentionsTheEighteenDayRule() {
        let item = planned("v", "g", .vignetteExpiring, fire: day(2027, 1, 6), event: day(2027, 1, 31))
        let text = NotificationTexts.text(for: item, vehicleName: "Golf", locale: english)
        #expect(text.body.contains("18th day"))
    }

    @Test func relativeDays() {
        #expect(RelativeDays.phrase(0, locale: english) == "today")
        #expect(RelativeDays.phrase(1, locale: english) == "tomorrow")
        #expect(RelativeDays.phrase(14, locale: english) == "in 14 days")
    }
}
