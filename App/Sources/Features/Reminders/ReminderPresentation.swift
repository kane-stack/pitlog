import PitlogCore
import SwiftUI

extension ReminderCategory {
    var iconName: String {
        switch self {
        case .tyreWinter: "snowflake"
        case .tyreSummer: "sun.max"
        case .service: "wrench.and.screwdriver"
        case .vignette: "road.lanes"
        case .custom: "bell"
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .tyreWinter:
            String(localized: "Winter tyres", locale: locale, comment: "Reminder type: winter tyre change")
        case .tyreSummer:
            String(localized: "Summer tyres", locale: locale, comment: "Reminder type: summer tyre change")
        case .service:
            String(localized: "Service", locale: locale, comment: "Reminder type: vehicle service")
        case .vignette:
            String(localized: "Vignette", locale: locale, comment: "Reminder type: motorway vignette")
        case .custom:
            String(localized: "Reminder", locale: locale, comment: "Reminder type: custom reminder without a title")
        }
    }
}

extension ReminderCategory {
    /// Title in the "Add reminder" menu.
    func addTitle(locale: Locale) -> String {
        self == .custom
            ? String(localized: "Custom reminder", locale: locale, comment: "Menu item to add a reminder with a title and date of the user's choice")
            : title(locale: locale)
    }
}

/// Texts, icon and VoiceOver label of a stored reminder. Dates are spelled out, estimates say so,
/// and no state is conveyed by color alone.
struct ReminderPresentation {
    enum State: Equatable {
        case upcoming(PlannedNotification)
        case overdue(DayDate)
        /// Service by odometer without a usable projection.
        case needsOdometer
        case dueByOdometer
        case done
        case off
    }

    let reminder: Reminder
    let state: State
    let today: DayDate
    let locale: Locale

    init(reminder: Reminder, vehicle: Vehicle, today: DayDate, locale: Locale) {
        self.reminder = reminder
        self.today = today
        self.locale = locale
        self.state = Self.state(for: reminder, vehicle: vehicle, today: today)
    }

    private static func state(for reminder: Reminder, vehicle: Vehicle, today: DayDate) -> State {
        guard reminder.isEnabled else {
            return reminder.lastCompletedAt != nil ? .done : .off
        }
        let builder = ReminderScheduleBuilder()
        let projection = vehicle.odometerProjection
        let schedule = reminder.schedule(
            vehicleID: vehicle.id.uuidString, projection: projection,
            defaults: builder.defaults(for: vehicle), today: today)
        let repeats = reminder.repeatRule != .none
        if let due = reminder.dueDate, due < today, !repeats, reminder.category == .service || reminder.category == .custom {
            return .overdue(due)
        }
        if let next = schedule?.nextOccurrence(today: today) {
            return .upcoming(next)
        }
        if reminder.category == .service, let km = reminder.dueKm {
            if let current = vehicle.currentOdometerKm, current >= km { return .dueByOdometer }
            return .needsOdometer
        }
        return .off
    }

    var title: String {
        if (reminder.category == .service || reminder.category == .custom), !reminder.title.isEmpty {
            return reminder.title
        }
        return reminder.category.title(locale: locale)
    }

    var iconName: String { reminder.category.iconName }

    /// The date of the next event with its meaning, e.g. "Valid until 31 January 2027".
    var dueText: String {
        switch state {
        case .upcoming(let next):
            return Self.dueText(for: next, locale: locale)
        case .overdue(let day):
            let date = day.formatted(.long, locale: locale)
            return String(localized: "Overdue since \(date)", locale: locale, comment: "Reminder status: the date has passed, with the date")
        case .needsOdometer:
            return String(localized: "Add an odometer reading to plan this reminder.", locale: locale, comment: "Reminder status: a service by odometer needs odometer readings (two, two weeks apart) to estimate a date")
        case .dueByOdometer:
            let km = (reminder.dueKm ?? 0).formatted(.number.locale(locale))
            return String(localized: "Due: the odometer has reached \(km) km", locale: locale, comment: "Reminder status: the service odometer value has been reached, with kilometres")
        case .done:
            return String(localized: "Done", locale: locale, comment: "Reminder status: completed and not repeating")
        case .off:
            return String(localized: "Off", locale: locale, comment: "Reminder status: switched off")
        }
    }

    static func dueText(for next: PlannedNotification, locale: Locale) -> String {
        let date = next.eventDay.formatted(.long, locale: locale)
        switch next.kind {
        case .tyreChangeWinter:
            return String(localized: "Winter period starts \(date)", locale: locale, comment: "Reminder status: winter tyre period start, with the date")
        case .tyreChangeSummer:
            return String(localized: "Winter period ends \(date)", locale: locale, comment: "Reminder status: winter tyre period end, with the date")
        case .vignetteNew:
            return String(localized: "New vignette from \(date)", locale: locale, comment: "Reminder status: the new vignette is available from this date")
        case .vignetteExpiring:
            return String(localized: "Valid until \(date)", locale: locale, comment: "Reminder status: the vignette is valid until this date")
        case .serviceKm:
            let km = (next.dueKm ?? 0).formatted(.number.locale(locale))
            return String(localized: "At \(km) km, estimated around \(date)", locale: locale, comment: "Reminder status: service by odometer with the estimated date. First argument: kilometres, second: date")
        default:
            return String(localized: "Due \(date)", locale: locale, comment: "Reminder status: due date")
        }
    }

    /// "in 14 days", only for upcoming reminders.
    var relativeText: String? {
        guard case .upcoming(let next) = state else { return nil }
        return RelativeDays.phrase(next.eventDay.days(from: today), locale: locale)
    }

    /// Sort key for lists: the event day, or `nil` if there is none.
    var sortDay: DayDate? {
        switch state {
        case .upcoming(let next): next.eventDay
        case .overdue(let day): day
        default: nil
        }
    }

    var accessibilityLabel: String {
        var parts = [title, dueText]
        if let relativeText { parts.append(relativeText) }
        return parts.joined(separator: ". ") + "."
    }
}
