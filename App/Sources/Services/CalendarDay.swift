import Foundation
import PitlogCore

/// Bridges `Date` and the calendar value types of PitlogCore (ADR-7).
enum CalendarDay {
    /// Austria's inspection deadlines are calendar days in Vienna, wherever the phone is.
    static let austria = TimeZone(identifier: "Europe/Vienna") ?? .gmt

    static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func today(in timeZone: TimeZone, now: Date = Date()) -> DayDate {
        dayDate(from: now, in: timeZone)
    }

    static func dayDate(from date: Date, in timeZone: TimeZone) -> DayDate {
        let parts = calendar(in: timeZone).dateComponents([.year, .month, .day], from: date)
        // Components of a Gregorian calendar are always a valid day.
        return DayDate(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
            ?? DayDate(year: 1970, month: 1, day: 1)!
    }

    /// Noon on `day` in `timeZone`. Noon keeps the day stable for display in nearby time zones.
    static func date(from day: DayDate, in timeZone: TimeZone) -> Date {
        let components = DateComponents(
            calendar: calendar(in: timeZone), timeZone: timeZone,
            year: day.year, month: day.month, day: day.day, hour: 12)
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}

extension DayDate {
    /// Formatted via `FormatStyle`, in the time zone the day was computed in.
    func formatted(
        _ style: Date.FormatStyle.DateStyle = .long,
        locale: Locale,
        timeZone: TimeZone = CalendarDay.austria
    ) -> String {
        let date = CalendarDay.date(from: self, in: timeZone)
        return date.formatted(
            Date.FormatStyle(date: style, time: .omitted, locale: locale, calendar: CalendarDay.calendar(in: timeZone), timeZone: timeZone))
    }
}

extension YearMonth {
    private static let utc = TimeZone(secondsFromGMT: 0) ?? .gmt

    /// "March 2027" / "März 2027"; the de-AT locale yields "Jänner".
    func displayString(locale: Locale) -> String {
        let date = CalendarDay.date(from: firstDay, in: Self.utc)
        let style = Date.FormatStyle(
            locale: locale, calendar: CalendarDay.calendar(in: Self.utc), timeZone: Self.utc
        )
        .month(.wide)
        .year()
        return date.formatted(style)
    }

    /// Month name only ("March"), for the plaque picker.
    static func monthName(_ month: Int, locale: Locale, style: Date.FormatStyle.Symbol.Month = .wide) -> String {
        let probe = YearMonth(year: 2000, month: month) ?? YearMonth(year: 2000, month: 1)!
        let date = CalendarDay.date(from: probe.firstDay, in: utc)
        let format = Date.FormatStyle(
            locale: locale, calendar: CalendarDay.calendar(in: utc), timeZone: utc
        )
        .month(style)
        return date.formatted(format)
    }
}
