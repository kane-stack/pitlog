import Foundation
import PitlogCore

/// "today", "tomorrow", "in 14 days".
enum RelativeDays {
    static func phrase(_ days: Int, locale: Locale) -> String {
        switch days {
        case ..<1:
            String(localized: "today", locale: locale, comment: "Relative day: today, lowercase, used inside a sentence")
        case 1:
            String(localized: "tomorrow", locale: locale, comment: "Relative day: tomorrow, lowercase, used inside a sentence")
        default:
            String(localized: "in \(days) days", locale: locale, comment: "Relative day: number of days from now, plural, used inside a sentence")
        }
    }
}

/// Localized title and body of a planned notification. Short; inspection texts end with the legal hint.
enum NotificationTexts {
    struct Message: Equatable {
        let title: String
        let body: String
    }

    static func text(for item: PlannedNotification, vehicleName: String, locale: Locale) -> Message {
        let type = typeTitle(for: item, locale: locale)
        let title = vehicleName.isEmpty ? type : "\(vehicleName) · \(type)"
        // The German strings carry soft hyphens for line breaking in views; a notification must not.
        return Message(title: title.withoutSoftHyphens, body: body(for: item, locale: locale).withoutSoftHyphens)
    }

    /// Kind of the reminder; the user's own title for service and custom reminders.
    static func typeTitle(for item: PlannedNotification, locale: Locale) -> String {
        switch item.kind {
        case .inspectionWindowOpens, .inspectionMonthBefore, .inspectionDueMonth, .inspectionClosingSoon,
            .inspectionOverdue:
            return String(localized: "Inspection", locale: locale, comment: "Notification title part: the periodic vehicle inspection (Pickerl)")
        case .tyreChangeWinter:
            return String(localized: "Winter tyres", locale: locale, comment: "Reminder type: winter tyre change")
        case .tyreChangeSummer:
            return String(localized: "Summer tyres", locale: locale, comment: "Reminder type: summer tyre change")
        case .serviceDate, .serviceKm:
            return item.title.isEmpty
                ? String(localized: "Service", locale: locale, comment: "Reminder type: vehicle service")
                : item.title
        case .vignetteNew, .vignetteExpiring:
            return String(localized: "Vignette", locale: locale, comment: "Reminder type: motorway vignette")
        case .custom:
            return item.title.isEmpty
                ? String(localized: "Reminder", locale: locale, comment: "Reminder type: custom reminder without a title")
                : item.title
        }
    }

    static func body(for item: PlannedNotification, locale: Locale) -> String {
        let date = item.eventDay.formatted(.long, locale: locale)
        let relative = RelativeDays.phrase(item.daysUntilEvent, locale: locale)
        let hint = String(localized: "Check the date on your sticker.", locale: locale, comment: "Legal hint at the end of every inspection notification: the date on the inspection sticker is authoritative")
        switch item.kind {
        case .inspectionWindowOpens:
            let text = String(localized: "The inspection window opens today.", locale: locale, comment: "Notification body: the inspection window opens")
            return "\(text) \(hint)"
        case .inspectionMonthBefore:
            let text = String(localized: "The inspection is due next month.", locale: locale, comment: "Notification body: the inspection is due in the next month")
            return "\(text) \(hint)"
        case .inspectionDueMonth:
            let text = String(localized: "The inspection is due this month.", locale: locale, comment: "Notification body: the inspection is due in the current month")
            return "\(text) \(hint)"
        case .inspectionClosingSoon:
            let text = String(localized: "The inspection window closes \(relative), on \(date).", locale: locale, comment: "Notification body: the inspection window closes soon. First argument: relative time such as 'in 7 days', second: the date")
            return "\(text) \(hint)"
        case .inspectionOverdue:
            return String(localized: "§57a inspection overdue — check the date on your sticker.", locale: locale, comment: "Notification body: the inspection window has closed. Sent once, the day after the app notices. The date on the inspection sticker is authoritative")
        case .tyreChangeWinter:
            return String(localized: "The winter tyre period starts on \(date), \(relative).", locale: locale, comment: "Notification body: winter tyres. First argument: the date, second: relative time such as 'in 14 days'")
        case .tyreChangeSummer:
            return String(localized: "The winter tyre period ends on \(date), \(relative).", locale: locale, comment: "Notification body: summer tyres. First argument: the date, second: relative time such as 'in 14 days'")
        case .serviceDate:
            return String(localized: "Service due on \(date), \(relative).", locale: locale, comment: "Notification body: service by date. First argument: the date, second: relative time such as 'in 14 days'")
        case .serviceKm:
            let km = (item.dueKm ?? 0).formatted(.number.locale(locale))
            return String(localized: "Service due at \(km) km, expected around \(date) (estimate).", locale: locale, comment: "Notification body: service by odometer. First argument: kilometres, second: the estimated date")
        case .vignetteNew:
            return String(localized: "The new vignette is available from today.", locale: locale, comment: "Notification body: the new annual vignette can be bought from today (1 December in Austria)")
        case .vignetteExpiring:
            return String(localized: "Your vignette is valid until \(date). A vignette bought online may only be valid from the 18th day after purchase.", locale: locale, comment: "Notification body: the vignette expires soon, with the hint about the 18 day delay for online purchases. Argument: the date")
        case .custom:
            return String(localized: "Due on \(date), \(relative).", locale: locale, comment: "Notification body: custom reminder. First argument: the date, second: relative time such as 'in 14 days'")
        }
    }
}
