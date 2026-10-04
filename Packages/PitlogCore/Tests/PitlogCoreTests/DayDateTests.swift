import Foundation
import Testing
@testable import PitlogCore

// MARK: - DayDateTests
struct ValidityCase: Sendable {
    let year: Int
    let month: Int
    let day: Int
    let isValid: Bool
}

let validityCases: [ValidityCase] = [
    .init(year: 2027, month: 5, day: 19, isValid: true),
    .init(year: 2028, month: 2, day: 29, isValid: true),
    .init(year: 2027, month: 2, day: 29, isValid: false),
    .init(year: 2100, month: 2, day: 29, isValid: false),
    .init(year: 2000, month: 2, day: 29, isValid: true),
    .init(year: 2027, month: 4, day: 31, isValid: false),
    .init(year: 2027, month: 12, day: 31, isValid: true),
    .init(year: 2027, month: 1, day: 0, isValid: false),
    .init(year: 2027, month: 0, day: 1, isValid: false),
    .init(year: 2027, month: 13, day: 1, isValid: false),
    .init(year: 2027, month: 1, day: -3, isValid: false),
]

@Test(arguments: validityCases)
func dayDateValidatingInit(_ c: ValidityCase) {
    #expect((DayDate(year: c.year, month: c.month, day: c.day) != nil) == c.isValid)
}

@Test func dayDateYearMonthProperty() {
    #expect(day(2027, 5, 19).yearMonth == ym(2027, 5))
    #expect(day(2028, 2, 29).yearMonth == ym(2028, 2))
}

struct OrderCase: Sendable {
    let earlier: DayDate
    let later: DayDate
}

let orderCases: [OrderCase] = [
    .init(earlier: day(2027, 5, 18), later: day(2027, 5, 19)),
    .init(earlier: day(2027, 5, 31), later: day(2027, 6, 1)),
    .init(earlier: day(2026, 12, 31), later: day(2027, 1, 1)),
    .init(earlier: day(2027, 2, 28), later: day(2028, 2, 1)),
]

@Test(arguments: orderCases)
func dayDateComparison(_ c: OrderCase) {
    #expect(c.earlier < c.later)
    #expect(c.later > c.earlier)
    #expect(c.earlier != c.later)
    #expect(max(c.earlier, c.later) == c.later)
}

@Test func dayDateDescription() {
    #expect(day(2027, 5, 9).description == "2027-05-09")
    #expect(day(2027, 11, 30).description == "2027-11-30")
}

@Test func dayDateCodableRoundTrip() throws {
    let encoded = try JSONEncoder().encode(day(2028, 2, 29))
    #expect(try JSONDecoder().decode(DayDate.self, from: encoded) == day(2028, 2, 29))
}

@Test func dayDateDecodingInvalidDayFails() {
    let json = Data(#"{"year":2027,"month":2,"day":29}"#.utf8)
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(DayDate.self, from: json)
    }
}
