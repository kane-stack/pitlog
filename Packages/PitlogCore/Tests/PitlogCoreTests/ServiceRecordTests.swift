import Testing
@testable import PitlogCore

private func entry(
    _ id: String, _ date: DayDate, km: Int? = nil, category: MaintenanceCategory = .service,
    amount: Int64? = nil, currency: String = "EUR", receipts: Int = 0
) -> ServiceRecordEntry {
    ServiceRecordEntry(
        id: id, date: date, odometerKm: km, category: category, workshop: "Shop \(id)", workItems: ["Work \(id)"],
        money: amount.map { Money(amountMinor: $0, currencyCode: currency) }, receiptCount: receipts)
}

private let golf = ServiceRecordVehicle(
    licensePlate: "W 12345 A", name: "Golf", make: "Volkswagen", model: "Golf", vin: "WVWZZZ1KZAW000001",
    category: .passengerCar, firstRegistration: ym(2020, 6), plaque: ym(2027, 6))

private func record(
    _ entries: [ServiceRecordEntry], options: ServiceRecordOptions = .init(),
    readings: [OdometerStatement] = [], vehicle: ServiceRecordVehicle = golf
) -> ServiceRecord {
    ServiceRecord(
        vehicle: vehicle, odometerReadings: readings, entries: entries, options: options, today: day(2027, 3, 1))
}

// MARK: Empty and missing data

@Test func emptyHistoryGivesAnEmptyRecordWithTheVehicle() {
    let result = record([])
    #expect(result.isEmpty)
    #expect(result.items.isEmpty)
    #expect(result.costs.isEmpty)
    #expect(result.odometer == nil)
    #expect(result.vehicle.licensePlate == "W 12345 A")
    #expect(result.createdOn == day(2027, 3, 1))
}

@Test func vehicleWithoutOptionalFieldsIsKeptAsIs() {
    let bare = ServiceRecordVehicle(licensePlate: "", category: .other)
    let result = record([entry("a", day(2026, 1, 1))], vehicle: bare)
    #expect(result.vehicle.vin == nil)
    #expect(result.vehicle.firstRegistration == nil)
    #expect(result.vehicle.plaque == nil)
    #expect(result.items.count == 1)
}

// MARK: Order and numbering

@Test func entriesAreNewestFirstAndNumberedFromOne() {
    let result = record([
        entry("old", day(2024, 5, 1)), entry("new", day(2026, 8, 1)), entry("mid", day(2025, 2, 1)),
    ])
    #expect(result.items.map(\.entry.id) == ["new", "mid", "old"])
    #expect(result.items.map(\.number) == [1, 2, 3])
}

@Test func sameDayEntriesGoByOdometerThenByInputOrder() {
    let result = record([
        entry("first", day(2026, 4, 1), km: 50_000),
        entry("high", day(2026, 4, 1), km: 50_400),
        entry("noKm", day(2026, 4, 1)),
        entry("second", day(2026, 4, 1), km: 50_000),
    ])
    #expect(result.items.map(\.entry.id) == ["high", "first", "second", "noKm"])
}

// MARK: Period

struct RecordPeriodCase: Sendable {
    let period: ServiceRecordPeriod
    let expected: [String]
}

let recordPeriodCases: [RecordPeriodCase] = [
    .init(period: .all, expected: ["c", "b", "a"]),
    // the start day itself is included
    .init(period: .since(day(2025, 6, 15)), expected: ["c", "b"]),
    // one day later it is not
    .init(period: .since(day(2025, 6, 16)), expected: ["c"]),
    // the day before the oldest entry keeps everything
    .init(period: .since(day(2024, 1, 31)), expected: ["c", "b", "a"]),
    .init(period: .since(day(2030, 1, 1)), expected: []),
]

@Test(arguments: recordPeriodCases) func periodBoundariesAreInclusiveAtTheStart(_ testCase: RecordPeriodCase) {
    let entries = [
        entry("a", day(2024, 2, 1)), entry("b", day(2025, 6, 15)), entry("c", day(2026, 1, 10)),
    ]
    let result = record(entries, options: .init(period: testCase.period))
    #expect(result.items.map(\.entry.id) == testCase.expected)
    #expect(result.isEmpty == testCase.expected.isEmpty)
}

@Test func numbersRestartInsideThePeriod() {
    let result = record(
        [entry("a", day(2024, 2, 1)), entry("c", day(2026, 1, 10))],
        options: .init(period: .since(day(2025, 1, 1))))
    #expect(result.items.map(\.number) == [1])
}

// MARK: Fields

@Test func vinIsHiddenWhenSwitchedOff() {
    #expect(record([], options: .init(includeVIN: true)).vehicle.vin == "WVWZZZ1KZAW000001")
    #expect(record([], options: .init(includeVIN: false)).vehicle.vin == nil)
}

@Test func amountsAreOffByDefaultAndRemoveMoneyAndSums() {
    let entries = [entry("a", day(2026, 1, 1), amount: 12_000), entry("b", day(2026, 2, 1), amount: 500)]
    let off = record(entries)
    #expect(off.items.allSatisfy { $0.entry.money == nil })
    #expect(off.costs.isEmpty)
    let on = record(entries, options: .init(includeAmounts: true))
    #expect(on.items.compactMap(\.entry.money).count == 2)
    #expect(on.costs.count == 1)
}

@Test func receiptAttachmentsListOnlyEntriesWithReceiptsAndOnlyWhenChosen() {
    let entries = [
        entry("a", day(2026, 1, 1), receipts: 2), entry("b", day(2026, 2, 1)), entry("c", day(2026, 3, 1), receipts: 1),
    ]
    #expect(record(entries).attachmentItems.isEmpty)
    // the receipt column still knows which entries have receipts
    #expect(record(entries).items.map(\.entry.receiptCount) == [1, 0, 2])
    let on = record(entries, options: .init(includeReceiptAttachments: true))
    #expect(on.attachmentItems.map(\.entry.id) == ["c", "a"])
    #expect(on.attachmentItems.map(\.number) == [1, 3])
}

@Test func negativeReceiptCountsAreClampedToZero() {
    let result = record([entry("a", day(2026, 1, 1), receipts: -3)])
    #expect(result.items[0].entry.receiptCount == 0)
}

// MARK: Costs

@Test func costsAreSummedPerYearAndCurrencyAndNeverMixed() throws {
    let entries = [
        entry("a", day(2024, 3, 1), amount: 10_000),
        entry("b", day(2024, 9, 1), amount: 2_550),
        entry("c", day(2026, 1, 5), amount: 4_000),
        entry("d", day(2026, 6, 5), amount: 9_000, currency: "chf"),
        entry("e", day(2025, 6, 5)),  // no amount: no year of its own
    ]
    let result = record(entries, options: .init(includeAmounts: true))
    #expect(result.costs.map(\.currencyCode) == ["CHF", "EUR"])

    let chf = try #require(result.costs.first { $0.currencyCode == "CHF" })
    #expect(chf.years.map(\.year) == [2026])
    #expect(chf.total == Money(amountMinor: 9_000, currencyCode: "CHF"))

    let eur = try #require(result.costs.first { $0.currencyCode == "EUR" })
    #expect(eur.years.map(\.year) == [2026, 2024])
    #expect(eur.years.map(\.total.amountMinor) == [4_000, 12_550])
    #expect(eur.total == Money(amountMinor: 16_550, currencyCode: "EUR"))
}

@Test func costsOnlyCountTheListedPeriod() throws {
    let entries = [entry("a", day(2023, 3, 1), amount: 99_900), entry("b", day(2026, 3, 1), amount: 1_000)]
    let result = record(entries, options: .init(period: .since(day(2025, 1, 1)), includeAmounts: true))
    let eur = try #require(result.costs.first)
    #expect(eur.total.amountMinor == 1_000)
    #expect(eur.years.map(\.year) == [2026])
}

@Test func aFreeEntryDoesNotCreateACostBlock() {
    let result = record([entry("a", day(2026, 3, 1))], options: .init(includeAmounts: true))
    #expect(result.costs.isEmpty)
}

@Test func zeroAmountCountsAsAnEntryWithACost() throws {
    let result = record([entry("a", day(2026, 3, 1), amount: 0)], options: .init(includeAmounts: true))
    let eur = try #require(result.costs.first)
    #expect(eur.total.amountMinor == 0)
    #expect(eur.years.map(\.year) == [2026])
}

// MARK: Odometer

struct RecordOdometerCase: Sendable {
    let readings: [OdometerStatement]
    let entries: [ServiceRecordEntry]
    let expected: OdometerStatement?
}

let recordOdometerCases: [RecordOdometerCase] = [
    .init(readings: [], entries: [], expected: nil),
    .init(
        readings: [OdometerStatement(kilometers: 60_000, date: day(2026, 1, 1))], entries: [],
        expected: OdometerStatement(kilometers: 60_000, date: day(2026, 1, 1))),
    // an entry newer than the readings wins
    .init(
        readings: [OdometerStatement(kilometers: 60_000, date: day(2026, 1, 1))],
        entries: [entry("a", day(2026, 5, 1), km: 63_000)],
        expected: OdometerStatement(kilometers: 63_000, date: day(2026, 5, 1))),
    // a newer reading wins over an older entry
    .init(
        readings: [OdometerStatement(kilometers: 70_000, date: day(2026, 9, 1))],
        entries: [entry("a", day(2026, 5, 1), km: 63_000)],
        expected: OdometerStatement(kilometers: 70_000, date: day(2026, 9, 1))),
    // same day: the higher value
    .init(
        readings: [OdometerStatement(kilometers: 61_000, date: day(2026, 5, 1))],
        entries: [entry("a", day(2026, 5, 1), km: 63_000)],
        expected: OdometerStatement(kilometers: 63_000, date: day(2026, 5, 1))),
    // zero is no value
    .init(
        readings: [OdometerStatement(kilometers: 0, date: day(2026, 5, 1))], entries: [entry("a", day(2026, 6, 1), km: 0)],
        expected: nil),
]

@Test(arguments: recordOdometerCases) func latestOdometerIsTheNewestStatement(_ testCase: RecordOdometerCase) {
    let result = record(testCase.entries, readings: testCase.readings)
    #expect(result.odometer == testCase.expected)
}

@Test func odometerComesFromTheWholeHistoryNotFromThePeriod() {
    let entries = [entry("a", day(2024, 1, 1), km: 41_000)]
    let result = record(entries, options: .init(period: .since(day(2026, 1, 1))))
    #expect(result.items.isEmpty)
    #expect(result.odometer == OdometerStatement(kilometers: 41_000, date: day(2024, 1, 1)))
}

// MARK: File name

struct RecordFileNameCase: Sendable {
    let title: String
    let plate: String
    let date: DayDate
    let expected: String
}

let recordFileNameCases: [RecordFileNameCase] = [
    .init(title: "Servicenachweis", plate: "W 12345 A", date: day(2027, 3, 1), expected: "Servicenachweis W-12345-A 2027-03-01.pdf"),
    .init(title: "Service record", plate: "W-12345A", date: day(2027, 3, 1), expected: "Service record W-12345A 2027-03-01.pdf"),
    // invalid characters and separators are replaced and collapsed
    .init(title: "Servicenachweis", plate: "G/4711:K", date: day(2027, 12, 31), expected: "Servicenachweis G-4711-K 2027-12-31.pdf"),
    .init(title: "Servicenachweis", plate: "  a  b  ", date: day(2027, 1, 2), expected: "Servicenachweis a-b 2027-01-02.pdf"),
    .init(title: "Servicenachweis", plate: "\"<>|*?\\", date: day(2027, 1, 2), expected: "Servicenachweis 2027-01-02.pdf"),
    // no plate
    .init(title: "Servicenachweis", plate: "", date: day(2027, 1, 2), expected: "Servicenachweis 2027-01-02.pdf"),
    // leading dots must not hide the file
    .init(title: "Servicenachweis", plate: "..x", date: day(2027, 1, 2), expected: "Servicenachweis x 2027-01-02.pdf"),
    // empty title falls back to the app name
    .init(title: "", plate: "W 1", date: day(2027, 1, 2), expected: "Pitlog W-1 2027-01-02.pdf"),
]

@Test(arguments: recordFileNameCases) func fileNameReplacesInvalidCharacters(_ testCase: RecordFileNameCase) {
    #expect(ServiceRecordFileName.make(title: testCase.title, plate: testCase.plate, date: testCase.date) == testCase.expected)
}

@Test func fileNameIsLimitedInLength() {
    let name = ServiceRecordFileName.make(
        title: "Servicenachweis", plate: String(repeating: "A", count: 400), date: day(2027, 1, 2))
    #expect(name.hasSuffix(".pdf"))
    #expect(name.count <= ServiceRecordFileName.maximumLength + 4)
}
