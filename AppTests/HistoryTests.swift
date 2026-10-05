import Foundation
import PitlogCore
import SwiftData
import Testing

@testable import Pitlog

private func day(_ y: Int, _ m: Int, _ d: Int) -> DayDate { DayDate(year: y, month: m, day: d)! }

@MainActor
struct HistoryModelTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainerFactory.inMemory())
    }

    @Test func entryStoresDateCategoryAndMoneyAsPlainValues() throws {
        let context = try makeContext()
        let vehicle = Vehicle(name: "Golf")
        context.insert(vehicle)
        let entry = MaintenanceEntry(date: day(2026, 3, 14), category: .repair, vehicle: vehicle)
        entry.amountMinor = 24_590
        entry.currencyCode = "CHF"
        context.insert(entry)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<MaintenanceEntry>()).first)
        #expect(fetched.date == day(2026, 3, 14))
        #expect(fetched.category == .repair)
        #expect(fetched.categoryRaw == "repair")
        #expect(fetched.money == Money(amountMinor: 24_590, currencyCode: "CHF"))
        #expect(fetched.vehicle?.maintenanceEntries?.count == 1)
    }

    @Test func entryWithoutAmountHasNoMoneyAndNoCost() {
        let entry = MaintenanceEntry(date: day(2026, 3, 14))
        #expect(entry.money == nil)
        #expect(entry.costEntry == nil)
    }

    @Test func unknownCategoryFallsBackToOtherWorkshop() {
        let entry = MaintenanceEntry()
        entry.categoryRaw = "something-new"
        #expect(entry.category == .otherWorkshop)
    }

    @Test func workLinesSkipBlankLines() {
        let entry = MaintenanceEntry()
        entry.workItems = "Oil change\n\n  Air filter  \n"
        #expect(entry.workLines == ["Oil change", "Air filter"])
    }

    @Test func deletingAVehicleCascadesToEntriesAndReceipts() throws {
        let context = try makeContext()
        let vehicle = Vehicle(name: "Golf")
        context.insert(vehicle)
        let entry = MaintenanceEntry(date: day(2026, 1, 1), vehicle: vehicle)
        context.insert(entry)
        context.insert(ReceiptDocument(data: Data([1, 2, 3]), entry: entry))
        let other = Vehicle(name: "Other")
        context.insert(other)
        let otherEntry = MaintenanceEntry(date: day(2026, 1, 1), vehicle: other)
        context.insert(otherEntry)
        context.insert(ReceiptDocument(data: Data([4]), entry: otherEntry))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<MaintenanceEntry>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<ReceiptDocument>()) == 2)

        context.delete(vehicle)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<MaintenanceEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ReceiptDocument>()) == 1)
    }

    @Test func deletingAnEntryCascadesToItsReceiptsOnly() throws {
        let context = try makeContext()
        let vehicle = Vehicle(name: "Golf")
        context.insert(vehicle)
        let first = MaintenanceEntry(vehicle: vehicle)
        let second = MaintenanceEntry(vehicle: vehicle)
        context.insert(first)
        context.insert(second)
        context.insert(ReceiptDocument(data: Data([1]), entry: first))
        context.insert(ReceiptDocument(data: Data([2]), contentType: ReceiptDocument.pdfType, pageCount: 3, entry: second))
        try context.save()

        context.delete(first)
        try context.save()

        let receipts = try context.fetch(FetchDescriptor<ReceiptDocument>())
        #expect(receipts.count == 1)
        #expect(receipts.first?.isPDF == true)
        #expect(receipts.first?.pageCount == 3)
        #expect(vehicle.maintenanceEntries?.count == 1)
    }

    @Test func sampleDataHasAZeroYearAndTwoCurrencies() {
        let container = PreviewData.container(withSamples: true)
        let golf = try? container.mainContext.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { $0.name == "Golf" })).first
        let summary = CostSummary(entries: (golf?.maintenanceEntries ?? []).compactMap(\.costEntry))
        #expect(summary.currencies == ["CHF", "EUR"])
        let years = summary.series(currency: "EUR").map(\.year)
        #expect(years.count == 3)
        #expect(years[1] == years[0] + 1)
        #expect(summary.costs(year: years[1], currency: "EUR").categories.isEmpty)
    }
}

@MainActor
struct HistoryTimelineTests {
    private func entry(_ d: DayDate, _ category: MaintenanceCategory, created: TimeInterval = 0) -> MaintenanceEntry {
        let entry = MaintenanceEntry(date: d, category: category)
        entry.createdAt = Date(timeIntervalSince1970: created)
        return entry
    }

    @Test func groupsByYearNewestFirst() {
        let entries = [
            entry(day(2024, 5, 1), .service),
            entry(day(2026, 1, 2), .repair),
            entry(day(2026, 11, 30), .tyres),
            entry(day(2024, 12, 31), .inspection),
        ]
        let groups = HistoryTimeline.groups(entries, filter: nil)
        #expect(groups.map(\.year) == [2026, 2024])
        #expect(groups[0].entries.map(\.date) == [day(2026, 11, 30), day(2026, 1, 2)])
        #expect(groups[1].entries.map(\.date) == [day(2024, 12, 31), day(2024, 5, 1)])
    }

    @Test func sameDayEntriesKeepTheNewestFirst() {
        let older = entry(day(2026, 1, 2), .service, created: 1)
        let newer = entry(day(2026, 1, 2), .repair, created: 2)
        #expect(HistoryTimeline.sorted([older, newer]).map(\.category) == [.repair, .service])
    }

    @Test func filterKeepsOneCategoryAndDropsEmptyYears() {
        let entries = [
            entry(day(2024, 5, 1), .service),
            entry(day(2025, 1, 2), .repair),
            entry(day(2026, 11, 30), .service),
        ]
        let groups = HistoryTimeline.groups(entries, filter: .service)
        #expect(groups.map(\.year) == [2026, 2024])
        #expect(HistoryTimeline.groups(entries, filter: .tyres).isEmpty)
        #expect(HistoryTimeline.groups([], filter: nil).isEmpty)
    }
}

struct OdometerSyncCase: Sendable {
    let name: String
    let entryDay: DayDate
    let km: Int
    let latestDay: DayDate?
    let latestKm: Int?
    let expected: Bool
}

struct OdometerSyncTests {
    @Test(arguments: [
        OdometerSyncCase(name: "no reading yet", entryDay: day(2026, 3, 1), km: 50_000, latestDay: nil, latestKm: nil, expected: true),
        OdometerSyncCase(name: "newer and higher", entryDay: day(2026, 3, 1), km: 50_000, latestDay: day(2026, 1, 1), latestKm: 48_000, expected: true),
        OdometerSyncCase(name: "same day", entryDay: day(2026, 3, 1), km: 50_000, latestDay: day(2026, 3, 1), latestKm: 49_000, expected: false),
        OdometerSyncCase(name: "back-dated", entryDay: day(2025, 3, 1), km: 41_000, latestDay: day(2026, 1, 1), latestKm: 48_000, expected: false),
        OdometerSyncCase(name: "newer but lower", entryDay: day(2026, 3, 1), km: 40_000, latestDay: day(2026, 1, 1), latestKm: 48_000, expected: false),
        OdometerSyncCase(name: "newer, same km", entryDay: day(2026, 3, 1), km: 48_000, latestDay: day(2026, 1, 1), latestKm: 48_000, expected: true),
        OdometerSyncCase(name: "zero", entryDay: day(2026, 3, 1), km: 0, latestDay: nil, latestKm: nil, expected: false),
    ])
    func decidesWhetherAnEntryBecomesAReading(_ c: OdometerSyncCase) {
        #expect(
            OdometerSync.shouldAddReading(entryDay: c.entryDay, km: c.km, latestDay: c.latestDay, latestKm: c.latestKm)
                == c.expected, "\(c.name)")
    }

    @MainActor
    @Test func addsAReadingOnlyForANewerEntry() throws {
        let context = ModelContext(try ModelContainerFactory.inMemory())
        let vehicle = Vehicle(name: "Golf")
        context.insert(vehicle)
        let zone = TimeZone(identifier: "Europe/Vienna") ?? .gmt
        context.insert(OdometerReading(date: CalendarDay.date(from: day(2026, 1, 10), in: zone), kilometers: 48_000, vehicle: vehicle))

        #expect(OdometerSync.addReadingIfNewer(for: vehicle, day: day(2025, 6, 1), km: 41_000, in: context, timeZone: zone) == false)
        #expect(OdometerSync.addReadingIfNewer(for: vehicle, day: day(2026, 3, 1), km: nil, in: context, timeZone: zone) == false)
        #expect(OdometerSync.addReadingIfNewer(for: vehicle, day: day(2026, 3, 1), km: 49_500, in: context, timeZone: zone))
        // the same entry saved again adds nothing: its own reading is now the latest one
        #expect(OdometerSync.addReadingIfNewer(for: vehicle, day: day(2026, 3, 1), km: 49_500, in: context, timeZone: zone) == false)
        #expect(vehicle.odometerReadings?.count == 2)
        #expect(vehicle.currentOdometerKm == 49_500)
    }
}

struct MoneyFormatTests {
    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_AT")

    @Test func formatsOnlyThroughTheCurrencyFormatStyle() {
        let money = Money(amountMinor: 123_456, currencyCode: "EUR")
        #expect(MoneyFormat.string(money, locale: english) == "€1,234.56")
        let text = MoneyFormat.string(money, locale: german)
        #expect(text.contains("1.234,56") || text.contains("1 234,56"))
        #expect(text.contains("€"))
    }

    @Test func defaultCurrencyFollowsTheLocale() {
        #expect(MoneyFormat.defaultCurrency(locale: Locale(identifier: "de_AT")) == "EUR")
        #expect(MoneyFormat.defaultCurrency(locale: Locale(identifier: "de_CH")) == "CHF")
        #expect(MoneyFormat.defaultCurrency(locale: Locale(identifier: "en_GB")) == "GBP")
    }

    struct ParseCase: Sendable {
        let text: String
        let locale: String
        let expected: MoneyFormat.Parsed
    }

    @Test(arguments: [
        ParseCase(text: "120.50", locale: "en_US", expected: .value(Money(amountMinor: 12_050, currencyCode: "EUR"))),
        ParseCase(text: "120,50", locale: "de_AT", expected: .value(Money(amountMinor: 12_050, currencyCode: "EUR"))),
        ParseCase(text: "0", locale: "de_AT", expected: .value(Money(amountMinor: 0, currencyCode: "EUR"))),
        ParseCase(text: "  ", locale: "de_AT", expected: .empty),
        ParseCase(text: "", locale: "en_US", expected: .empty),
        ParseCase(text: "abc", locale: "en_US", expected: .invalid),
        ParseCase(text: "-5", locale: "en_US", expected: .invalid),
    ])
    func parsesWhatTheUserTypes(_ c: ParseCase) {
        #expect(MoneyFormat.parse(c.text, currency: "EUR", locale: Locale(identifier: c.locale)) == c.expected)
    }

    @Test func editTextRoundTripsThroughParse() {
        for code in ["EUR", "JPY", "KWD"] {
            let money = Money(amountMinor: 1_234_567, currencyCode: code)
            for locale in [english, german] {
                let text = MoneyFormat.editText(money, locale: locale)
                #expect(MoneyFormat.parse(text, currency: code, locale: locale) == .value(money), "\(code) \(text)")
            }
        }
    }

    @Test func currencyChoicesStartWithTheLocaleCurrencyWithoutDuplicates() {
        let choices = MoneyFormat.choices(including: ["SEK", "EUR"], locale: Locale(identifier: "de_CH"))
        #expect(choices.first == "CHF")
        #expect(Set(choices).count == choices.count)
        #expect(choices.contains("SEK"))
        #expect(choices.contains("EUR"))
    }
}

struct OverdueNoticeStoreTests {
    private func defaults() -> UserDefaults {
        let name = "OverdueNoticeStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func emptyWhenNothingIsStored() {
        #expect(OverdueNoticeStore.load(from: defaults()) == OverdueNoticeLedger())
    }

    @Test func savesAndLoadsTheLedger() {
        let store = defaults()
        var ledger = OverdueNoticeLedger()
        let status = InspectionStatus(
            dueMonth: YearMonth(year: 2026, month: 1)!, dueMonthSource: .plaque,
            window: InspectionWindow(opens: day(2025, 12, 1), closes: day(2026, 5, 31)),
            phase: .overdue, regime: .previousLaw, notes: [], exchangePlaqueSuggestion: nil, ruleVersion: "test")
        let plan = NotificationPlanner.plan(
            schedules: [.inspection(vehicleID: "v", status: status)], today: day(2026, 10, 5))
        ledger.record(plan)
        OverdueNoticeStore.save(ledger, to: store)
        #expect(OverdueNoticeStore.load(from: store) == ledger)
        #expect(OverdueNoticeStore.load(from: store).fireDays["v/inspection/inspectionOverdue/2026-01"] == day(2026, 10, 6))
    }

    @Test func ignoresCorruptData() {
        let store = defaults()
        store.set(Data([0xFF, 0x00]), forKey: OverdueNoticeStore.key)
        #expect(OverdueNoticeStore.load(from: store) == OverdueNoticeLedger())
    }
}

struct OverdueNotificationTextTests {
    @Test func bodyIsTheAgreedText() {
        let item = PlannedNotification(
            vehicleID: "v", reminderID: "inspection", kind: .inspectionOverdue,
            fireDay: day(2026, 10, 6), eventDay: day(2026, 5, 31))
        let message = NotificationTexts.text(for: item, vehicleName: "Golf", locale: Locale(identifier: "en"))
        #expect(message.body == "§57a inspection overdue — check the date on your sticker.")
        #expect(message.title.hasPrefix("Golf"))
    }
}
