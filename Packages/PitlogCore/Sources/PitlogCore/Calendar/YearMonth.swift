/// A calendar month in the proleptic Gregorian calendar.
///
/// All inspection arithmetic works on months instead of `Date` so that results do not
/// depend on time zones or month lengths (ADR-7).
public struct YearMonth: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    /// 1 ... 12
    public let month: Int

    /// Returns `nil` if `month` is not in 1...12.
    public init?(year: Int, month: Int) {
        guard (1...12).contains(month) else { return nil }
        self.year = year
        self.month = month
    }

    init(uncheckedYear year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    /// Months since year 0, January. Monotonic and the basis of all arithmetic.
    var monthIndex: Int { year * 12 + (month - 1) }

    init(monthIndex: Int) {
        self.year = floorDivide(monthIndex, 12)
        self.month = floorModulo(monthIndex, 12) + 1
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: return isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    public func adding(months: Int) -> YearMonth {
        YearMonth(monthIndex: monthIndex + months)
    }

    public func adding(years: Int) -> YearMonth {
        adding(months: years * 12)
    }

    /// Signed number of months from `other` to `self` (positive if `self` is later).
    public func months(from other: YearMonth) -> Int {
        monthIndex - other.monthIndex
    }

    public var previous: YearMonth { adding(months: -1) }
    public var next: YearMonth { adding(months: 1) }

    public var firstDay: DayDate {
        DayDate(uncheckedYear: year, month: month, day: 1)
    }

    public var lastDay: DayDate {
        DayDate(uncheckedYear: year, month: month, day: Self.daysInMonth(year: year, month: month))
    }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.monthIndex < rhs.monthIndex
    }

    public var description: String {
        "\(year)-\(zeroPadded(month))"
    }

    private enum CodingKeys: String, CodingKey { case year, month }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let year = try container.decode(Int.self, forKey: .year)
        let month = try container.decode(Int.self, forKey: .month)
        guard let value = YearMonth(year: year, month: month) else {
            throw DecodingError.dataCorruptedError(
                forKey: .month, in: container, debugDescription: "Month \(month) is not in 1...12")
        }
        self = value
    }
}

func floorDivide(_ a: Int, _ b: Int) -> Int {
    let q = a / b
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
}

func floorModulo(_ a: Int, _ b: Int) -> Int {
    a - floorDivide(a, b) * b
}

func zeroPadded(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
}
