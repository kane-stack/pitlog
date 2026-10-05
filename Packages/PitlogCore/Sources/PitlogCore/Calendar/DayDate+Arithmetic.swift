/// Day arithmetic on the calendar value types, without `Date` or time zones (ADR-7).
extension DayDate {
    /// Days since 1970-01-01 in the proleptic Gregorian calendar (civil-from-days algorithm).
    var daysSinceEpoch: Int {
        let y = month <= 2 ? year - 1 : year
        let era = floorDivide(y, 400)
        let yearOfEra = y - era * 400
        let shiftedMonth = month > 2 ? month - 3 : month + 9
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    init(daysSinceEpoch days: Int) {
        let z = days + 719_468
        let era = floorDivide(z, 146_097)
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        self.init(uncheckedYear: year, month: month, day: day)
    }

    public func adding(days: Int) -> DayDate {
        DayDate(daysSinceEpoch: daysSinceEpoch + days)
    }

    /// Signed number of days from `other` to `self` (positive if `self` is later).
    public func days(from other: DayDate) -> Int {
        daysSinceEpoch - other.daysSinceEpoch
    }

    /// Same day number in the target month, or its last day if the month is shorter (31 Jan + 1 month = 28/29 Feb).
    public func adding(months: Int) -> DayDate {
        let target = yearMonth.adding(months: months)
        let lastDay = YearMonth.daysInMonth(year: target.year, month: target.month)
        return DayDate(uncheckedYear: target.year, month: target.month, day: min(day, lastDay))
    }

    public func adding(years: Int) -> DayDate {
        adding(months: years * 12)
    }

    public var monthDay: MonthDay {
        MonthDay(uncheckedMonth: month, day: day)
    }
}

/// A day of the year without a year, for yearly legal dates such as 1 November.
public struct MonthDay: Hashable, Codable, Sendable, CustomStringConvertible {
    /// 1 ... 12
    public let month: Int
    public let day: Int

    /// Returns `nil` if the combination does not exist in any year. 29 February is allowed.
    public init?(month: Int, day: Int) {
        guard (1...12).contains(month), day >= 1,
              day <= YearMonth.daysInMonth(year: 2000, month: month)
        else { return nil }
        self.month = month
        self.day = day
    }

    init(uncheckedMonth month: Int, day: Int) {
        self.month = month
        self.day = day
    }

    /// The day in `year`. 29 February becomes 28 February in common years.
    public func resolved(inYear year: Int) -> DayDate {
        DayDate(
            uncheckedYear: year, month: month,
            day: min(day, YearMonth.daysInMonth(year: year, month: month)))
    }

    public func firstOccurrence(onOrAfter reference: DayDate) -> DayDate {
        let candidate = resolved(inYear: reference.year)
        return candidate >= reference ? candidate : resolved(inYear: reference.year + 1)
    }

    public func lastOccurrence(onOrBefore reference: DayDate) -> DayDate {
        let candidate = resolved(inYear: reference.year)
        return candidate <= reference ? candidate : resolved(inYear: reference.year - 1)
    }

    public var description: String {
        "\(zeroPadded(month))-\(zeroPadded(day))"
    }
}
