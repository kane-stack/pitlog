import Testing
@testable import PitlogCore

private func entry(
    _ d: DayDate, _ category: MaintenanceCategory, _ minor: Int64, _ currency: String = "EUR"
) -> CostEntry {
    CostEntry(date: d, category: category, money: Money(amountMinor: minor, currencyCode: currency))
}

private func eur(_ minor: Int64) -> Money { Money(amountMinor: minor, currencyCode: "EUR") }

@Test func emptyInputGivesAnEmptySummary() {
    let summary = CostSummary(entries: [])
    #expect(summary.isEmpty)
    #expect(summary.currencies.isEmpty)
    #expect(summary.series(currency: "EUR").isEmpty)
    #expect(summary.yearRange(currency: "EUR") == nil)
    #expect(summary.categoryTotals(currency: "EUR").isEmpty)
    #expect(summary.total(currency: "EUR") == Money.zero("EUR"))
    #expect(summary.costs(year: 2026, currency: "EUR").total == Money.zero("EUR"))
}

struct YearBoundaryCase: Sendable {
    let name: String
    let date: DayDate
    let year: Int
}

@Test(arguments: [
    YearBoundaryCase(name: "first day of the year", date: day(2026, 1, 1), year: 2026),
    YearBoundaryCase(name: "last day of the year", date: day(2025, 12, 31), year: 2025),
    YearBoundaryCase(name: "leap day", date: day(2028, 2, 29), year: 2028),
])
func entriesLandInTheirCalendarYear(_ c: YearBoundaryCase) {
    let summary = CostSummary(entries: [entry(c.date, .service, 1_000)])
    #expect(summary.costs(year: c.year, currency: "EUR").total == eur(1_000), "\(c.name)")
    #expect(summary.costs(year: c.year + 1, currency: "EUR").total == eur(0), "\(c.name)")
    #expect(summary.costs(year: c.year - 1, currency: "EUR").total == eur(0), "\(c.name)")
}

@Test func newYearsEveAndNewYearsDaySplitAcrossYears() {
    let summary = CostSummary(entries: [
        entry(day(2025, 12, 31), .repair, 10_000),
        entry(day(2026, 1, 1), .repair, 2_500),
    ])
    #expect(summary.costs(year: 2025, currency: "EUR").total == eur(10_000))
    #expect(summary.costs(year: 2026, currency: "EUR").total == eur(2_500))
    #expect(summary.total(currency: "EUR") == eur(12_500))
}

@Test func categorySumsAddUpPerYearAndOverall() {
    let summary = CostSummary(entries: [
        entry(day(2026, 2, 1), .service, 20_000),
        entry(day(2026, 6, 1), .service, 5_000),
        entry(day(2026, 7, 1), .tyres, 40_000),
        entry(day(2025, 3, 1), .service, 1_000),
        entry(day(2025, 9, 1), .inspection, 5_000),
    ])
    let year = summary.costs(year: 2026, currency: "EUR")
    #expect(year.total == eur(65_000))
    // the order of MaintenanceCategory.allCases, only categories with entries
    #expect(year.categories == [
        CategoryAmount(category: .service, money: eur(25_000)),
        CategoryAmount(category: .tyres, money: eur(40_000)),
    ])
    #expect(summary.categoryTotals(currency: "EUR") == [
        CategoryAmount(category: .service, money: eur(26_000)),
        CategoryAmount(category: .tyres, money: eur(40_000)),
        CategoryAmount(category: .inspection, money: eur(5_000)),
    ])
    #expect(summary.total(currency: "EUR") == eur(71_000))
}

@Test func seriesIsAscendingAndFillsZeroYears() {
    let summary = CostSummary(entries: [
        entry(day(2028, 5, 1), .repair, 700),
        entry(day(2025, 5, 1), .service, 300),
        entry(day(2026, 5, 1), .service, 100),
    ])
    let series = summary.series(currency: "EUR")
    #expect(series.map(\.year) == [2025, 2026, 2027, 2028])
    #expect(series.map(\.total) == [eur(300), eur(100), eur(0), eur(700)])
    #expect(series[2].categories.isEmpty)
    #expect(summary.yearRange(currency: "EUR") == 2025...2028)
}

@Test func aSingleYearIsASeriesOfOne() {
    let series = CostSummary(entries: [entry(day(2026, 5, 1), .otherWorkshop, 300)]).series(currency: "EUR")
    #expect(series.map(\.year) == [2026])
}

@Test func aFreeEntryStillCountsAsAYear() {
    let summary = CostSummary(entries: [
        entry(day(2024, 5, 1), .service, 0),
        entry(day(2026, 5, 1), .service, 100),
    ])
    #expect(summary.series(currency: "EUR").map(\.year) == [2024, 2025, 2026])
}

@Test func currenciesStaySeparateAndAreNeverConverted() {
    let summary = CostSummary(entries: [
        entry(day(2026, 1, 10), .service, 10_000, "EUR"),
        entry(day(2026, 2, 10), .service, 7_000, "CHF"),
        entry(day(2024, 2, 10), .repair, 3_000, "CHF"),
        entry(day(2026, 3, 10), .tyres, 500, "eur"),
    ])
    #expect(summary.currencies == ["CHF", "EUR"])
    #expect(summary.total(currency: "EUR") == eur(10_500))
    #expect(summary.total(currency: "CHF") == Money(amountMinor: 10_000, currencyCode: "CHF"))
    // each currency has its own year range
    #expect(summary.series(currency: "EUR").map(\.year) == [2026])
    #expect(summary.series(currency: "CHF").map(\.year) == [2024, 2025, 2026])
    #expect(summary.series(currency: "GBP").isEmpty)
}

@Test func largeAmountsDoNotOverflow() {
    let half = Int64.max / 2
    let summary = CostSummary(entries: [
        entry(day(2026, 1, 1), .service, half),
        entry(day(2026, 6, 1), .repair, half),
    ])
    #expect(summary.total(currency: "EUR") == eur(half * 2))
    // beyond the limit the total saturates and never wraps around to a negative number
    let overflowing = CostSummary(entries: [
        entry(day(2026, 1, 1), .service, Int64.max),
        entry(day(2026, 2, 1), .service, 1),
        entry(day(2026, 3, 1), .repair, Int64.max),
    ])
    #expect(overflowing.costs(year: 2026, currency: "EUR").total == eur(Int64.max))
    #expect(overflowing.total(currency: "EUR") == eur(Int64.max))
}

@Test func manyLargeEntriesSumExactly() {
    let entries = (0..<10_000).map { _ in entry(day(2026, 1, 1), .service, 900_000_000_000, "EUR") }
    // 10 000 x 9 000 000 000.00 EUR
    #expect(CostSummary(entries: entries).total(currency: "EUR") == eur(9_000_000_000_000_000))
}

@Test func negativeAmountsAreCredits() {
    let summary = CostSummary(entries: [
        entry(day(2026, 1, 1), .repair, 10_000),
        entry(day(2026, 2, 1), .repair, -2_500),
    ])
    #expect(summary.total(currency: "EUR") == eur(7_500))
}
