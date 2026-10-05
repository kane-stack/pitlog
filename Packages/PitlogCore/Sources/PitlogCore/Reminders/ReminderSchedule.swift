/// How a reminder repeats.
public enum ReminderRecurrence: Hashable, Codable, Sendable {
    case none
    case yearly
    case everyMonths(Int)

    /// The `index`-th event of a series that starts on `first`. Always computed from `first`, so a
    /// 31st does not drift to the 28th for good.
    func day(_ index: Int, from first: DayDate) -> DayDate {
        switch self {
        case .none: first
        case .yearly: first.adding(years: index)
        case .everyMonths(let months): first.adding(months: max(1, months) * index)
        }
    }

    /// Up to `count` events on or after `today`.
    func events(from first: DayDate, today: DayDate, count: Int) -> [DayDate] {
        switch self {
        case .none:
            return first >= today ? [first] : []
        case .yearly, .everyMonths:
            let stepMonths = monthsStep
            let elapsed = today.yearMonth.months(from: first.yearMonth)
            var index = max(0, elapsed / stepMonths - 1)
            var result: [DayDate] = []
            while result.count < count && index < 100_000 {
                let candidate = day(index, from: first)
                if candidate >= today { result.append(candidate) }
                index += 1
            }
            return result
        }
    }

    private var monthsStep: Int {
        if case .everyMonths(let months) = self { return max(1, months) }
        return 12
    }
}

/// Seasonal tyre change, every year.
public struct TyreChange: Hashable, Sendable {
    public var season: TyreSeason
    /// The first legal date still to come. Later years repeat on the same month and day.
    public var firstEventDay: DayDate
    public var leadDays: Int

    public init(season: TyreSeason, firstEventDay: DayDate, leadDays: Int) {
        self.season = season
        self.firstEventDay = firstEventDay
        self.leadDays = leadDays
    }
}

/// Annual vignette: a reminder before the old one ends and one when the new one is available.
public struct VignetteDue: Hashable, Sendable {
    /// The first "valid until" day still to come. Later years repeat on the same month and day.
    public var firstExpiryDay: DayDate
    public var leadDays: Int
    /// Day the new vignette becomes available, usually before `firstExpiryDay`. `nil`: no such reminder.
    public var announce: MonthDay?

    public init(firstExpiryDay: DayDate, leadDays: Int, announce: MonthDay?) {
        self.firstExpiryDay = firstExpiryDay
        self.leadDays = leadDays
        self.announce = announce
    }
}

/// A reminder with its own title and date.
public struct CustomDue: Hashable, Sendable {
    public var dueDay: DayDate
    public var leadDays: Int
    public var recurrence: ReminderRecurrence

    public init(dueDay: DayDate, leadDays: Int, recurrence: ReminderRecurrence = .none) {
        self.dueDay = dueDay
        self.leadDays = leadDays
        self.recurrence = recurrence
    }
}

/// Service by date and/or odometer, optionally repeating.
public struct ServiceDue: Hashable, Sendable {
    public static let defaultLeadDays = 14
    public static let defaultLeadKm = 500

    public var dueDay: DayDate?
    public var dueKm: Int?
    public var leadDays: Int
    public var leadKm: Int
    public var repeatMonths: Int?
    public var repeatKm: Int?
    /// Estimate of when the odometer reaches `dueKm`. Without it there is no km-based notification.
    public var projection: OdometerProjection?

    public init(
        dueDay: DayDate? = nil,
        dueKm: Int? = nil,
        leadDays: Int = ServiceDue.defaultLeadDays,
        leadKm: Int = ServiceDue.defaultLeadKm,
        repeatMonths: Int? = nil,
        repeatKm: Int? = nil,
        projection: OdometerProjection? = nil
    ) {
        self.dueDay = dueDay
        self.dueKm = dueKm
        self.leadDays = leadDays
        self.leadKm = leadKm
        self.repeatMonths = repeatMonths
        self.repeatKm = repeatKm
        self.projection = projection
    }

    /// The next service after one done on `day` at `km`, or `nil` if the service does not repeat.
    /// The interval counts from the actual service. Without a current reading the old target is the base.
    public func next(completedOn day: DayDate, atKm km: Int?) -> ServiceDue? {
        let nextDay = repeatMonths.map { day.adding(months: $0) }
        let nextKm = repeatKm.flatMap { interval in (km ?? dueKm).map { $0 + interval } }
        guard nextDay != nil || nextKm != nil else { return nil }
        var copy = self
        copy.dueDay = nextDay
        copy.dueKm = nextKm
        return copy
    }
}

public enum ReminderCompletion: Hashable, Sendable {
    /// Done for good: the reminder is switched off.
    case finished
    /// Done, the next occurrence is described by the new schedule.
    case rescheduled(ReminderSchedule)
}

/// One reminder of one vehicle. Inspection reminders are derived from `InspectionStatus` and never stored.
public struct ReminderSchedule: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case inspection(InspectionStatus)
        case tyreChange(TyreChange)
        case service(ServiceDue)
        case vignette(VignetteDue)
        case custom(CustomDue)
    }

    public static let inspectionReminderID = "inspection"
    /// Days before the window closes for the last inspection reminder.
    public static let inspectionClosingLeadDays = 7
    /// A repeating reminder plans this many future occurrences at most.
    static let maximumOccurrences = 4

    public var vehicleID: String
    public var reminderID: String
    /// The user's title (service, custom). Empty for the built-in kinds.
    public var title: String
    public var kind: Kind

    public init(vehicleID: String, reminderID: String, title: String = "", kind: Kind) {
        self.vehicleID = vehicleID
        self.reminderID = reminderID
        self.title = title
        self.kind = kind
    }

    public static func inspection(vehicleID: String, status: InspectionStatus) -> ReminderSchedule {
        ReminderSchedule(
            vehicleID: vehicleID, reminderID: inspectionReminderID, kind: .inspection(status))
    }

    // MARK: Occurrences

    /// All notifications of this reminder whose event day is not before `today`. The fire day may still
    /// be in the past; `NotificationPlanner` drops those.
    public func occurrences(today: DayDate) -> [PlannedNotification] {
        switch kind {
        case .inspection(let status): inspectionOccurrences(status, today: today)
        case .tyreChange(let tyre): tyreOccurrences(tyre, today: today)
        case .service(let service): serviceOccurrences(service, today: today)
        case .vignette(let vignette): vignetteOccurrences(vignette, today: today)
        case .custom(let custom): customOccurrences(custom, today: today)
        }
    }

    /// The occurrence with the earliest event day, for lists.
    public func nextOccurrence(today: DayDate) -> PlannedNotification? {
        occurrences(today: today).min { lhs, rhs in
            if lhs.eventDay != rhs.eventDay { return lhs.eventDay < rhs.eventDay }
            return lhs.fireDay < rhs.fireDay
        }
    }

    private func make(
        _ kind: PlannedNotification.Kind, fire: DayDate, event: DayDate,
        dueKm: Int? = nil, isEstimate: Bool = false
    ) -> PlannedNotification {
        PlannedNotification(
            vehicleID: vehicleID, reminderID: reminderID, kind: kind, fireDay: fire, eventDay: event,
            title: title, dueKm: dueKm, isEstimate: isEstimate)
    }

    private func inspectionOccurrences(_ status: InspectionStatus, today: DayDate) -> [PlannedNotification] {
        let closes = status.window.closes
        guard closes >= today else { return [] }
        // In priority order: an earlier entry wins if two fall on the same day (the previous law opens
        // the window exactly on the first day of the month before the due month).
        let candidates: [(PlannedNotification.Kind, DayDate, DayDate)] = [
            (.inspectionWindowOpens, status.window.opens, status.window.opens),
            (.inspectionMonthBefore, status.dueMonth.previous.firstDay, closes),
            (.inspectionDueMonth, status.dueMonth.firstDay, closes),
            (.inspectionClosingSoon, closes.adding(days: -Self.inspectionClosingLeadDays), closes),
        ]
        var usedDays = Set<DayDate>()
        var result: [PlannedNotification] = []
        for (kind, fire, event) in candidates where usedDays.insert(fire).inserted {
            result.append(make(kind, fire: fire, event: event))
        }
        return result
    }

    private func tyreOccurrences(_ tyre: TyreChange, today: DayDate) -> [PlannedNotification] {
        let kind: PlannedNotification.Kind = tyre.season == .winter ? .tyreChangeWinter : .tyreChangeSummer
        return ReminderRecurrence.yearly
            .events(from: tyre.firstEventDay, today: today, count: Self.maximumOccurrences)
            .map { make(kind, fire: $0.adding(days: -tyre.leadDays), event: $0) }
    }

    private func vignetteOccurrences(_ vignette: VignetteDue, today: DayDate) -> [PlannedNotification] {
        var result: [PlannedNotification] = []
        for expiry in ReminderRecurrence.yearly
            .events(from: vignette.firstExpiryDay, today: today, count: Self.maximumOccurrences)
        {
            result.append(make(.vignetteExpiring, fire: expiry.adding(days: -vignette.leadDays), event: expiry))
        }
        if let announce = vignette.announce {
            // The announcement belongs to each expiry: the latest such day before it.
            for expiry in ReminderRecurrence.yearly.events(
                from: vignette.firstExpiryDay, today: today, count: Self.maximumOccurrences + 1)
            {
                let day = announce.lastOccurrence(onOrBefore: expiry)
                if day >= today { result.append(make(.vignetteNew, fire: day, event: day)) }
            }
        }
        return result
    }

    private func customOccurrences(_ custom: CustomDue, today: DayDate) -> [PlannedNotification] {
        custom.recurrence
            .events(from: custom.dueDay, today: today, count: Self.maximumOccurrences)
            .map { make(.custom, fire: $0.adding(days: -custom.leadDays), event: $0) }
    }

    private func serviceOccurrences(_ service: ServiceDue, today: DayDate) -> [PlannedNotification] {
        var result: [PlannedNotification] = []
        if let due = service.dueDay, due >= today {
            result.append(make(.serviceDate, fire: due.adding(days: -service.leadDays), event: due))
        }
        if let km = service.dueKm,
           let projection = service.projection,
           let fire = projection.projectedDay(forKm: km - service.leadKm),
           let event = projection.projectedDay(forKm: km),
           event >= today
        {
            result.append(make(.serviceKm, fire: fire, event: event, dueKm: km, isEstimate: projection.isEstimate))
        }
        return result
    }

    // MARK: Completion

    /// What "done" does on `today`, with the odometer at `km` if known.
    /// Repeating reminders move to the next occurrence, the others finish. If the stored date has already
    /// passed or is today, the next occurrence is the next one from today on; if it is still ahead (done
    /// early), the one after it.
    public func completed(on today: DayDate, atKm km: Int?) -> ReminderCompletion {
        var copy = self
        switch kind {
        case .inspection:
            return .finished
        case .tyreChange(var tyre):
            tyre.firstEventDay = Self.advanced(tyre.firstEventDay, .yearly, today: today)
            copy.kind = .tyreChange(tyre)
        case .vignette(var vignette):
            vignette.firstExpiryDay = Self.advanced(vignette.firstExpiryDay, .yearly, today: today)
            copy.kind = .vignette(vignette)
        case .custom(var custom):
            guard custom.recurrence != .none else { return .finished }
            custom.dueDay = Self.advanced(custom.dueDay, custom.recurrence, today: today)
            copy.kind = .custom(custom)
        case .service(let service):
            guard let next = service.next(completedOn: today, atKm: km) else { return .finished }
            copy.kind = .service(next)
        }
        return .rescheduled(copy)
    }

    private static func advanced(_ anchor: DayDate, _ recurrence: ReminderRecurrence, today: DayDate) -> DayDate {
        if anchor >= today { return recurrence.day(1, from: anchor) }
        return recurrence.events(from: anchor, today: today, count: 1).first ?? anchor
    }
}
