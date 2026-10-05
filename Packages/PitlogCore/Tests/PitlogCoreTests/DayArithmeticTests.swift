import Testing
@testable import PitlogCore

struct DayShiftCase: Sendable {
    let from: DayDate
    let days: Int
    let expected: DayDate
}

let dayShiftCases: [DayShiftCase] = [
    .init(from: day(2026, 12, 31), days: 1, expected: day(2027, 1, 1)),
    .init(from: day(2028, 2, 28), days: 1, expected: day(2028, 2, 29)),
    .init(from: day(2027, 2, 28), days: 1, expected: day(2027, 3, 1)),
    .init(from: day(2027, 1, 1), days: -1, expected: day(2026, 12, 31)),
    .init(from: day(2026, 10, 18), days: 14, expected: day(2026, 11, 1)),
    .init(from: day(2026, 1, 31), days: 37, expected: day(2026, 3, 9)),
    .init(from: day(2027, 5, 19), days: 0, expected: day(2027, 5, 19)),
]

@Test(arguments: dayShiftCases)
func addingDays(_ c: DayShiftCase) {
    #expect(c.from.adding(days: c.days) == c.expected)
    #expect(c.expected.days(from: c.from) == c.days)
}

@Test func epochAnchors() {
    #expect(day(1970, 1, 1).daysSinceEpoch == 0)
    #expect(day(2000, 3, 1).daysSinceEpoch == 11_017)
    #expect(day(1969, 12, 31).daysSinceEpoch == -1)
}

@Test func epochRoundTripOverSeveralYears() {
    var current = day(1999, 12, 1)
    for _ in 0..<(366 * 40) {
        #expect(DayDate(daysSinceEpoch: current.daysSinceEpoch) == current)
        current = current.adding(days: 1)
    }
}

struct MonthShiftCase: Sendable {
    let from: DayDate
    let months: Int
    let expected: DayDate
}

let monthShiftCases: [MonthShiftCase] = [
    .init(from: day(2027, 1, 31), months: 1, expected: day(2027, 2, 28)),
    .init(from: day(2028, 1, 31), months: 1, expected: day(2028, 2, 29)),
    .init(from: day(2026, 11, 30), months: 3, expected: day(2027, 2, 28)),
    .init(from: day(2027, 3, 31), months: -1, expected: day(2027, 2, 28)),
    .init(from: day(2026, 6, 15), months: 12, expected: day(2027, 6, 15)),
    .init(from: day(2028, 2, 29), months: 12, expected: day(2029, 2, 28)),
]

@Test(arguments: monthShiftCases)
func addingMonths(_ c: MonthShiftCase) {
    #expect(c.from.adding(months: c.months) == c.expected)
}

@Test func monthDayResolvesAcrossYears() throws {
    let november1 = try #require(MonthDay(month: 11, day: 1))
    #expect(november1.firstOccurrence(onOrAfter: day(2026, 11, 1)) == day(2026, 11, 1))
    #expect(november1.firstOccurrence(onOrAfter: day(2026, 11, 2)) == day(2027, 11, 1))
    #expect(november1.lastOccurrence(onOrBefore: day(2026, 10, 31)) == day(2025, 11, 1))
    let leapDay = try #require(MonthDay(month: 2, day: 29))
    #expect(leapDay.resolved(inYear: 2028) == day(2028, 2, 29))
    #expect(leapDay.resolved(inYear: 2027) == day(2027, 2, 28))
    #expect(MonthDay(month: 4, day: 31) == nil)
    #expect(MonthDay(month: 13, day: 1) == nil)
}
