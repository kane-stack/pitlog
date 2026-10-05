/// One local notification the app should schedule. Pure data: texts are built by the app.
public struct PlannedNotification: Hashable, Identifiable, Sendable {
    public enum Kind: String, Hashable, Sendable, CaseIterable {
        case inspectionWindowOpens
        /// First day of the month before the due month.
        case inspectionMonthBefore
        /// First day of the due month.
        case inspectionDueMonth
        /// A week before the window closes.
        case inspectionClosingSoon
        /// The window has closed. Planned once for the day after the app first notices (see `OverdueNoticeLedger`).
        case inspectionOverdue
        case tyreChangeWinter
        case tyreChangeSummer
        case serviceDate
        case serviceKm
        case vignetteNew
        case vignetteExpiring
        case custom
    }

    /// Stable: vehicle, reminder, kind and fire day. Replanning replaces instead of duplicating.
    public let id: String
    public let vehicleID: String
    public let reminderID: String
    public let kind: Kind
    public let fireDay: DayDate
    /// The day the notification is about (due day, legal day, last day of the window).
    public let eventDay: DayDate
    /// The reminder's own title (service, custom). Empty for the built-in kinds.
    public let title: String
    /// Target odometer for `.serviceKm`.
    public let dueKm: Int?
    /// `true` if `fireDay` or `eventDay` come from an odometer projection.
    public let isEstimate: Bool

    public init(
        vehicleID: String,
        reminderID: String,
        kind: Kind,
        fireDay: DayDate,
        eventDay: DayDate,
        title: String = "",
        dueKm: Int? = nil,
        isEstimate: Bool = false
    ) {
        self.init(
            id: "\(vehicleID)/\(reminderID)/\(kind.rawValue)/\(fireDay)", vehicleID: vehicleID,
            reminderID: reminderID, kind: kind, fireDay: fireDay, eventDay: eventDay, title: title, dueKm: dueKm,
            isEstimate: isEstimate)
    }

    init(
        id: String,
        vehicleID: String,
        reminderID: String,
        kind: Kind,
        fireDay: DayDate,
        eventDay: DayDate,
        title: String,
        dueKm: Int?,
        isEstimate: Bool
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.reminderID = reminderID
        self.kind = kind
        self.fireDay = fireDay
        self.eventDay = eventDay
        self.title = title
        self.dueKm = dueKm
        self.isEstimate = isEstimate
    }

    /// The same notification on another fire day. The ID is kept.
    func firing(on day: DayDate) -> PlannedNotification {
        PlannedNotification(
            id: id, vehicleID: vehicleID, reminderID: reminderID, kind: kind, fireDay: day, eventDay: eventDay,
            title: title, dueKm: dueKm, isEstimate: isEstimate)
    }

    /// Days from the fire day to the event day.
    public var daysUntilEvent: Int { eventDay.days(from: fireDay) }
}

/// Turns reminder schedules into the notifications to schedule next.
public enum NotificationPlanner {
    /// Below iOS's limit of 64 pending notifications, leaving headroom.
    public static let defaultLimit = 60

    /// Drops fire days before `today`, removes duplicate IDs, sorts by fire day and keeps the first `limit`.
    /// Overdue notices keep the fire day the `ledger` recorded and are dropped once that day has passed.
    public static func plan(
        schedules: [ReminderSchedule],
        today: DayDate,
        limit: Int = defaultLimit,
        ledger: OverdueNoticeLedger = OverdueNoticeLedger()
    ) -> [PlannedNotification] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        var result: [PlannedNotification] = []
        for occurrence in schedules.flatMap({ $0.occurrences(today: today) }) {
            var notification = occurrence
            if notification.kind == .inspectionOverdue {
                guard let day = ledger.fireDay(for: notification, today: today) else { continue }
                notification = notification.firing(on: day)
            }
            if notification.fireDay >= today && seen.insert(notification.id).inserted {
                result.append(notification)
            }
        }
        result.sort { lhs, rhs in
            if lhs.fireDay != rhs.fireDay { return lhs.fireDay < rhs.fireDay }
            return lhs.id < rhs.id
        }
        return Array(result.prefix(limit))
    }
}

/// Remembers when each "inspection overdue" notice was first planned, so it is delivered once and then
/// never planned again. Without it the notice would move to "tomorrow" on every replanning and never fire
/// for someone who opens the app every morning. Pure data: the app stores it (and may keep it forever,
/// its IDs name vehicle and due month).
public struct OverdueNoticeLedger: Hashable, Codable, Sendable {
    /// Notice ID -> the day it fires.
    public private(set) var fireDays: [String: DayDate]

    public init(fireDays: [String: DayDate] = [:]) {
        self.fireDays = fireDays
    }

    /// The recorded fire day, or the candidate's own (the day after `today`) if the notice is new.
    /// `nil` once the recorded day lies before `today`: the notice has been delivered.
    func fireDay(for notice: PlannedNotification, today: DayDate) -> DayDate? {
        guard let recorded = fireDays[notice.id] else { return notice.fireDay }
        return recorded >= today ? recorded : nil
    }

    /// Records the overdue notices of `plan`, keeping days recorded earlier.
    public mutating func record(_ plan: [PlannedNotification]) {
        for notice in plan where notice.kind == .inspectionOverdue && fireDays[notice.id] == nil {
            fireDays[notice.id] = notice.fireDay
        }
    }
}
