import Foundation
import PitlogCore
import Testing

@testable import Pitlog

struct CalendarDayTests {
    private func instant(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso) ?? Date(timeIntervalSince1970: 0)
    }

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> DayDate {
        DayDate(year: year, month: month, day: dayOfMonth) ?? DayDate(year: 1970, month: 1, day: 1)!
    }

    @Test("Vienna day around midnight UTC and DST changes", arguments: [
        // Cutoff day starts at 22:00Z the evening before (CEST, UTC+2).
        ("2027-05-18T22:30:00Z", 2027, 5, 19),
        ("2027-05-18T21:59:59Z", 2027, 5, 18),
        ("2027-05-19T21:59:59Z", 2027, 5, 19),
        // Winter (CET, UTC+1).
        ("2027-01-14T23:00:00Z", 2027, 1, 15),
        ("2027-01-14T22:59:59Z", 2027, 1, 14),
        // Spring forward on 2027-03-28 (02:00 CET becomes 03:00 CEST).
        ("2027-03-27T23:30:00Z", 2027, 3, 28),
        ("2027-03-28T00:59:59Z", 2027, 3, 28),
        ("2027-03-28T01:00:00Z", 2027, 3, 28),
        ("2027-03-28T21:59:59Z", 2027, 3, 28),
        ("2027-03-28T22:00:00Z", 2027, 3, 29),
        // Fall back on 2027-10-31 (03:00 CEST becomes 02:00 CET).
        ("2027-10-30T22:30:00Z", 2027, 10, 31),
        ("2027-10-31T22:59:59Z", 2027, 10, 31),
        ("2027-10-31T23:00:00Z", 2027, 11, 1),
    ])
    func viennaToday(iso: String, year: Int, month: Int, dayOfMonth: Int) {
        let today = CalendarDay.today(in: CalendarDay.austria, now: instant(iso))
        #expect(today == day(year, month, dayOfMonth))
    }

    @Test func sameInstantDiffersByTimeZone() {
        let now = instant("2027-05-18T22:30:00Z")
        #expect(CalendarDay.today(in: TimeZone(secondsFromGMT: 0) ?? .gmt, now: now) == day(2027, 5, 18))
        #expect(CalendarDay.today(in: CalendarDay.austria, now: now) == day(2027, 5, 19))
    }

    @Test func dayDateRoundTripsThroughDateForEveryDayOf2027And2028() {
        for zone in [CalendarDay.austria, TimeZone(secondsFromGMT: 0) ?? .gmt, TimeZone(identifier: "America/Los_Angeles") ?? .gmt] {
            var current = day(2027, 1, 1)
            while current < day(2029, 1, 1) {
                let date = CalendarDay.date(from: current, in: zone)
                #expect(CalendarDay.dayDate(from: date, in: zone) == current)
                guard let next = Self.next(current) else { return }
                current = next
            }
        }
    }

    @Test func leapDayRoundTrips() {
        let leap = day(2028, 2, 29)
        let date = CalendarDay.date(from: leap, in: CalendarDay.austria)
        #expect(CalendarDay.dayDate(from: date, in: CalendarDay.austria) == leap)
    }

    private static func next(_ day: DayDate) -> DayDate? {
        if let sameMonth = DayDate(year: day.year, month: day.month, day: day.day + 1) { return sameMonth }
        let month = day.yearMonth.next
        return DayDate(year: month.year, month: month.month, day: 1)
    }
}

struct YearMonthDisplayTests {
    @Test("Month and year are formatted with the locale", arguments: [
        ("en_US", 2027, 3, "March 2027"),
        ("de_DE", 2027, 3, "März 2027"),
        ("de_AT", 2027, 1, "Jänner 2027"),
        ("de_DE", 2027, 1, "Januar 2027"),
    ])
    func displayString(localeID: String, year: Int, month: Int, expected: String) {
        let value = YearMonth(year: year, month: month) ?? YearMonth(year: 2000, month: 1)!
        #expect(value.displayString(locale: Locale(identifier: localeID)) == expected)
    }

    @Test func longDateIsFormattedWithLocale() {
        let day = DayDate(year: 2027, month: 5, day: 19) ?? DayDate(year: 2000, month: 1, day: 1)!
        #expect(day.formatted(.long, locale: Locale(identifier: "en_US")) == "May 19, 2027")
        #expect(day.formatted(.long, locale: Locale(identifier: "de_AT")) == "19. Mai 2027")
    }
}
