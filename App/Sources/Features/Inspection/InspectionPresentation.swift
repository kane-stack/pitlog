import PitlogCore
import SwiftUI

/// Texts, icons and accessibility labels for an `InspectionStatus`. Status is never conveyed by
/// color alone: every state has an icon and a text.
struct InspectionPresentation {
    let status: InspectionStatus
    let today: DayDate
    let locale: Locale

    var dueMonthText: String { status.dueMonth.displayString(locale: locale) }
    var windowOpensText: String { status.window.opens.formatted(.long, locale: locale) }
    var windowClosesText: String { status.window.closes.formatted(.long, locale: locale) }

    var iconName: String {
        switch status.phase {
        case .notYetOpen: "calendar"
        case .open: "checkmark.seal"
        case .closesThisMonth: "exclamationmark.triangle"
        case .overdue: "exclamationmark.octagon.fill"
        }
    }

    /// Whole days from `today` until the window closes. Negative once it has closed.
    var daysUntilClose: Int {
        let calendar = CalendarDay.calendar(in: CalendarDay.austria)
        let from = CalendarDay.date(from: today, in: CalendarDay.austria)
        let to = CalendarDay.date(from: status.window.closes, in: CalendarDay.austria)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Whole months from `today`'s month to the due month.
    var monthsUntilDue: Int {
        status.dueMonth.months(from: today.yearMonth)
    }

    var phaseText: String {
        switch status.phase {
        case .notYetOpen:
            String(localized: "Not yet open", locale: locale, comment: "Inspection phase: the window has not opened yet")
        case .open:
            String(localized: "Window open", locale: locale, comment: "Inspection phase: the inspection can be done now")
        case .closesThisMonth:
            String(localized: "Closes this month", locale: locale, comment: "Inspection phase: the window closes within the current month")
        case .overdue:
            String(localized: "Overdue", locale: locale, comment: "Inspection phase: the window has closed")
        }
    }

    /// Short badge text for list rows, e.g. "Due in 3 months", "Window open", "Overdue".
    var badgeText: String {
        switch status.phase {
        case .notYetOpen:
            let months = max(monthsUntilDue, 1)
            return String(localized: "Due in \(months) months", locale: locale, comment: "Status badge: months until the inspection is due, plural")
        default:
            return phaseText
        }
    }

    var daysText: String {
        let days = daysUntilClose
        if days < 0 {
            let ago = -days
            return String(localized: "Window closed \(ago) days ago", locale: locale, comment: "Days since the inspection window closed, plural")
        }
        if days == 0 {
            return String(localized: "Window closes today", locale: locale, comment: "The inspection window closes today")
        }
        return String(localized: "\(days) days until the window closes", locale: locale, comment: "Days until the inspection window closes, plural")
    }

    /// Fully spelled-out label for VoiceOver (due month, last day, status).
    var accessibilityLabel: String {
        let due = dueMonthText
        let last = windowClosesText
        let phase = phaseText
        if status.dueMonthSource == .estimatedFromFirstRegistration {
            return String(
                localized: "Estimated inspection due \(due). Last day \(last). \(phase).",
                locale: locale,
                comment: "VoiceOver label of the Pickerl card when the due month is only estimated")
        }
        return String(
            localized: "Inspection due \(due). Last day \(last). \(phase).",
            locale: locale,
            comment: "VoiceOver label of the Pickerl card: due month, last day of the window, phase")
    }

    /// Exchange sticker suggestion row (visible and in the VoiceOver label), or `nil`.
    var exchangeSuggestionText: String? {
        guard let suggestion = status.exchangePlaqueSuggestion else { return nil }
        let month = suggestion.displayString(locale: locale)
        return String(
            localized: "Exchange sticker suggestion: \(month). Not binding.",
            locale: locale,
            comment: "Pickerl card: optional exchange sticker with the later due month")
    }

    /// AT-58: exchange stickers exist only from the cutoff day on.
    var exchangeAvailabilityText: String? {
        guard status.exchangePlaqueSuggestion != nil, today < AustriaInspectionRules.cutoffDay else { return nil }
        let date = AustriaInspectionRules.cutoffDay.formatted(.long, locale: locale)
        return String(
            localized: "Available from \(date) at an authorised inspection station.",
            locale: locale,
            comment: "Pickerl card: exchange stickers are only issued from the cutoff date on (AT-58); the argument is the date")
    }

    var badgeAccessibilityLabel: String {
        let due = dueMonthText
        let badge = badgeText
        return String(
            localized: "Inspection due \(due). \(badge).",
            locale: locale,
            comment: "VoiceOver label of the status badge in the vehicle list")
    }
}

/// Short, localized texts for the rule notes. Unknown notes fall back to a generic text so a new
/// engine case never breaks the build or shows nothing.
enum RuleNoteText {
    static func text(for note: RuleNote, locale: Locale) -> String {
        // Kind first: AT-53 is used by more than one kind.
        switch note.kind {
        case .derivedLastInspection:
            return String(
                localized: "Last inspection estimated from the sticker and first registration. Enter it for a precise suggestion.",
                locale: locale, comment: "Rule note AT-53: the last inspection was derived, entering it gives a precise exchange sticker suggestion")
        case .possibleExtension(let until):
            let date = until.formatted(.long, locale: locale)
            return String(
                localized: "The deadline may be extended until \(date).",
                locale: locale, comment: "Rule note: possible extension of the deadline, with the date")
        default:
            break
        }
        switch note.ruleID {
        case "AT-10":
            return String(
                localized: "Estimated from the first registration. Check it against your inspection sticker.",
                locale: locale, comment: "Rule note AT-10: due month is an estimate")
        case "AT-12":
            return String(
                localized: "Inspected outside the window: enter the new punch from your inspection sticker.",
                locale: locale, comment: "Rule note AT-12: late inspection, the sticker is punched anew")
        case "AT-53":
            return String(
                localized: "An exchange sticker may be possible. This is not binding.",
                locale: locale, comment: "Rule note AT-53: exchange sticker, non-binding")
        case "AT-54a":
            return String(
                localized: "Open legal question for vehicles aged 9 to 10 years.",
                locale: locale, comment: "Rule note AT-54a: unclear rule at age 9 to 10")
        default:
            return String(
                localized: "See the legal notes for this deadline.",
                locale: locale, comment: "Generic rule note, points to the legal notes")
        }
    }
}
