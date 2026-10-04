import Foundation
import Testing
@testable import PitlogCore

// MARK: - YearMonthTests
struct AddMonthsCase: Sendable {
    let start: YearMonth
    let months: Int
    let expected: YearMonth
}

let addMonthsCases: [AddMonthsCase] = [
    .init(start: ym(2026, 12), months: 1, expected: ym(2027, 1)),
    .init(start: ym(2027, 1), months: -1, expected: ym(2026, 12)),
    .init(start: ym(2027, 3), months: 0, expected: ym(2027, 3)),
    .init(start: ym(2027, 3), months: 12, expected: ym(2028, 3)),
    .init(start: ym(2027, 3), months: -15, expected: ym(2025, 12)),
    .init(start: ym(2027, 11), months: 14, expected: ym(2029, 1)),
    .init(start: ym(2027, 1), months: -12, expected: ym(2026, 1)),
    .init(start: ym(2027, 12), months: 1, expected: ym(2028, 1)),
    .init(start: ym(2027, 1), months: -13, expected: ym(2025, 12)),
]

@Test(arguments: addMonthsCases)
func yearMonthAddingMonths(_ c: AddMonthsCase) {
    #expect(c.start.adding(months: c.months) == c.expected)
}

struct AddYearsCase: Sendable {
    let start: YearMonth
    let years: Int
    let expected: YearMonth
}

let addYearsCases: [AddYearsCase] = [
    .init(start: ym(2024, 2), years: 4, expected: ym(2028, 2)),
    .init(start: ym(2027, 6), years: -3, expected: ym(2024, 6)),
    .init(start: ym(2027, 6), years: 0, expected: ym(2027, 6)),
]

@Test(arguments: addYearsCases)
func yearMonthAddingYears(_ c: AddYearsCase) {
    #expect(c.start.adding(years: c.years) == c.expected)
}

struct DifferenceCase: Sendable {
    let later: YearMonth
    let earlier: YearMonth
    let expected: Int
}

let differenceCases: [DifferenceCase] = [
    .init(later: ym(2027, 3), earlier: ym(2020, 3), expected: 84),
    .init(later: ym(2020, 3), earlier: ym(2027, 3), expected: -84),
    .init(later: ym(2027, 1), earlier: ym(2026, 12), expected: 1),
    .init(later: ym(2027, 3), earlier: ym(2027, 3), expected: 0),
    .init(later: ym(2028, 2), earlier: ym(2027, 11), expected: 3),
]

@Test(arguments: differenceCases)
func yearMonthMonthsFrom(_ c: DifferenceCase) {
    #expect(c.later.months(from: c.earlier) == c.expected)
}

struct LastDayCase: Sendable {
    let month: YearMonth
    let lastDay: Int
}

let lastDayCases: [LastDayCase] = [
    .init(month: ym(2028, 2), lastDay: 29),
    .init(month: ym(2027, 2), lastDay: 28),
    .init(month: ym(2100, 2), lastDay: 28),
    .init(month: ym(2000, 2), lastDay: 29),
    .init(month: ym(2027, 4), lastDay: 30),
    .init(month: ym(2027, 12), lastDay: 31),
    .init(month: ym(2027, 1), lastDay: 31),
]

@Test(arguments: lastDayCases)
func yearMonthFirstAndLastDay(_ c: LastDayCase) {
    #expect(c.month.lastDay == day(c.month.year, c.month.month, c.lastDay))
    #expect(c.month.firstDay == day(c.month.year, c.month.month, 1))
}

@Test func yearMonthPreviousAndNext() {
    #expect(ym(2027, 1).previous == ym(2026, 12))
    #expect(ym(2026, 12).next == ym(2027, 1))
}

@Test func yearMonthOrdering() {
    #expect(ym(2026, 12) < ym(2027, 1))
    #expect(ym(2027, 2) > ym(2027, 1))
    #expect(ym(2027, 5) == ym(2027, 5))
    #expect([ym(2028, 1), ym(2026, 12), ym(2027, 6)].sorted() == [ym(2026, 12), ym(2027, 6), ym(2028, 1)])
}

@Test(arguments: [0, 13, -1, 100])
func yearMonthInvalidMonthIsRejected(_ month: Int) {
    #expect(YearMonth(year: 2027, month: month) == nil)
}

@Test(arguments: [1, 6, 12])
func yearMonthValidMonthIsAccepted(_ month: Int) {
    #expect(YearMonth(year: 2027, month: month) != nil)
}

@Test func yearMonthDescription() {
    #expect(ym(2027, 3).description == "2027-03")
    #expect(ym(2027, 11).description == "2027-11")
}

@Test func yearMonthCodableRoundTrip() throws {
    let encoded = try JSONEncoder().encode(ym(2027, 3))
    #expect(try JSONDecoder().decode(YearMonth.self, from: encoded) == ym(2027, 3))
}

@Test func yearMonthDecodingInvalidMonthFails() {
    let json = Data(#"{"year":2027,"month":13}"#.utf8)
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(YearMonth.self, from: json)
    }
}
