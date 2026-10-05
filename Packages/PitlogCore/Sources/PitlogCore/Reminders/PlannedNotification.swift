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
        self.id = "\(vehicleID)/\(reminderID)/\(kind.rawValue)/\(fireDay)"
        self.vehicleID = vehicleID
        self.reminderID = reminderID
        self.kind = kind
        self.fireDay = fireDay
        self.eventDay = eventDay
        self.title = title
        self.dueKm = dueKm
        self.isEstimate = isEstimate
    }

    /// Days from the fire day to the event day.
    public var daysUntilEvent: Int { eventDay.days(from: fireDay) }
}

/// Turns reminder schedules into the notifications to schedule next.
public enum NotificationPlanner {
    /// Below iOS's limit of 64 pending notifications, leaving headroom.
    public static let defaultLimit = 60

    /// Drops fire days before `today`, removes duplicate IDs, sorts by fire day and keeps the first `limit`.
    public static func plan(
        schedules: [ReminderSchedule],
        today: DayDate,
        limit: Int = defaultLimit
    ) -> [PlannedNotification] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        var result: [PlannedNotification] = []
        for notification in schedules.flatMap({ $0.occurrences(today: today) })
        where notification.fireDay >= today && seen.insert(notification.id).inserted {
            result.append(notification)
        }
        result.sort { lhs, rhs in
            if lhs.fireDay != rhs.fireDay { return lhs.fireDay < rhs.fireDay }
            return lhs.id < rhs.id
        }
        return Array(result.prefix(limit))
    }
}
