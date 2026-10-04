/// A calendar day without time zone, in the proleptic Gregorian calendar.
///
/// The app converts `Date` values to `DayDate` in the user's time zone; the domain logic never
/// touches `Calendar` or `TimeZone`.
public struct DayDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    /// 1 ... 12
    public let month: Int
    /// 1 ... number of days in the month
    public let day: Int

    /// Returns `nil` if the combination is not a real calendar day.
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month),
              day >= 1,
              day <= YearMonth.daysInMonth(year: year, month: month)
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    init(uncheckedYear year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public var yearMonth: YearMonth {
        YearMonth(uncheckedYear: year, month: month)
    }

    public static func < (lhs: DayDate, rhs: DayDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        "\(year)-\(zeroPadded(month))-\(zeroPadded(day))"
    }

    private enum CodingKeys: String, CodingKey { case year, month, day }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let year = try container.decode(Int.self, forKey: .year)
        let month = try container.decode(Int.self, forKey: .month)
        let day = try container.decode(Int.self, forKey: .day)
        guard let value = DayDate(year: year, month: month, day: day) else {
            throw DecodingError.dataCorruptedError(
                forKey: .day, in: container, debugDescription: "\(year)-\(month)-\(day) is not a valid date")
        }
        self = value
    }
}
