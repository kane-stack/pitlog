import Foundation
import PitlogCore
import Testing

@testable import Pitlog

struct PlaqueAccessibilityTests {
    @Test("VoiceOver value of the inspection sticker", arguments: [
        ("en_US", 2027, 3, "March 2027"),
        ("de_DE", 2027, 3, "März 2027"),
        ("de_AT", 2027, 1, "Jänner 2027"),
    ])
    func value(localeID: String, year: Int, month: Int, expected: String) {
        let plaque = YearMonth(year: year, month: month)
        #expect(PlaqueAccessibility.value(for: plaque, locale: Locale(identifier: localeID)) == expected)
    }

    @Test func unsetValueIsNotEmpty() {
        #expect(!PlaqueAccessibility.value(for: nil, locale: Locale(identifier: "en_US")).isEmpty)
    }

    @Test("Month steps roll over the year", arguments: [
        (2027, 12, 1, 2028, 1),
        (2027, 1, -1, 2026, 12),
        (2027, 3, 1, 2027, 4),
        (2027, 3, -1, 2027, 2),
    ])
    func stepping(year: Int, month: Int, delta: Int, expectedYear: Int, expectedMonth: Int) {
        let start = YearMonth(year: year, month: month) ?? YearMonth(year: 2000, month: 1)!
        let result = start.adding(months: delta)
        #expect(result.year == expectedYear)
        #expect(result.month == expectedMonth)
    }
}
