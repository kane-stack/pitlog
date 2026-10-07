import Foundation
import PDFKit
import PitlogCore
import SwiftData
import Testing
import UIKit

@testable import Pitlog

private func day(_ y: Int, _ m: Int, _ d: Int) -> DayDate { DayDate(year: y, month: m, day: d)! }

private let english = Locale(identifier: "en_US")
private let german = Locale(identifier: "de_AT")

private let golf = ServiceRecordVehicle(
    licensePlate: "W 12345 A", name: "Golf", make: "Volkswagen", model: "Golf", vin: "WVWZZZ1KZAW000001",
    category: .passengerCar, firstRegistration: YearMonth(year: 2020, month: 6), plaque: YearMonth(year: 2027, month: 6))

private func entry(
    _ id: String, _ date: DayDate, km: Int? = nil, amount: Int64? = nil, workshop: String? = nil,
    work: [String] = ["Oil change"], receipts: Int = 0
) -> ServiceRecordEntry {
    ServiceRecordEntry(
        id: id, date: date, odometerKm: km, category: .service, workshop: workshop ?? "Autohaus Müller",
        workItems: work, money: amount.map { Money(amountMinor: $0, currencyCode: "EUR") }, receiptCount: receipts)
}

private func record(
    _ entries: [ServiceRecordEntry], options: ServiceRecordOptions = .init(), vehicle: ServiceRecordVehicle = golf
) -> ServiceRecord {
    ServiceRecord(
        vehicle: vehicle, odometerReadings: [OdometerStatement(kilometers: 68_400, date: day(2026, 7, 3))],
        entries: entries, options: options, today: day(2027, 3, 1))
}

private func render(
    _ record: ServiceRecord, locale: Locale = english, receipts: [String: [ServiceRecordReceiptFile]] = [:]
) -> ServiceRecordPDFRenderer.Output {
    ServiceRecordPDFRenderer(record: record, texts: ServiceRecordTexts(locale: locale), receipts: receipts).render()
}

/// The text of a page or of the whole document with all white space folded into single spaces, so line breaks
/// inside cells do not matter.
private func flattened(_ text: String?) -> String {
    (text ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

private func text(of output: ServiceRecordPDFRenderer.Output) -> String {
    flattened(PDFDocument(data: output.data)?.string)
}

private func jpeg(color: UIColor = .systemRed) -> Data {
    let size = CGSize(width: 400, height: 600)
    return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

private func pdfReceipt(pages: Int) -> Data {
    let bounds = CGRect(x: 0, y: 0, width: 300, height: 400)
    return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
        for page in 1...pages {
            context.beginPage()
            ("Receipt page \(page)" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: nil)
        }
    }
}

private func occurrences(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
}

struct ServiceRecordAmountCase: Sendable {
    let locale: Locale
    let amountText: String
    let totalLabel: String
}

let serviceRecordAmountCases: [ServiceRecordAmountCase] = [
    .init(locale: Locale(identifier: "en_US"), amountText: "245.90", totalLabel: "Total"),
    .init(locale: Locale(identifier: "de_AT"), amountText: "245,90", totalLabel: "Gesamt"),
]

struct ServiceRecordPDFTests {
    // MARK: Content

    @Test func englishRecordContainsVehicleEntriesAndFooter() {
        let output = render(record([entry("a", day(2026, 3, 14), km: 66_300)]))
        let text = text(of: output)
        #expect(output.pageCount == 1)
        #expect(text.contains("Service record"))
        #expect(text.contains("W 12345 A"))
        #expect(text.contains("Volkswagen Golf"))
        #expect(text.contains("Autohaus Müller"))
        #expect(text.contains("Oil change"))
        #expect(text.contains("3/14/2026"))
        #expect(text.contains("Entered by the vehicle owner, not verified. Created with Wagemo."))
        #expect(text.contains("Page 1 of 1"))
    }

    @Test func germanRecordIsLocalized() {
        let output = render(record([entry("a", day(2026, 3, 14))]), locale: german)
        let text = text(of: output)
        #expect(text.contains("Servicenachweis"))
        #expect(text.contains("Kennzeichen"))
        #expect(text.contains("Erstzulassung"))
        #expect(text.contains("14.3.2026"))
        #expect(text.contains("Angaben vom Fahrzeughalter erfasst, nicht geprüft. Erstellt mit Wagemo."))
        #expect(text.contains("Seite 1 von 1"))
    }

    @Test func recordShowsThePunchedMonthAndNoCalculatedDeadline() {
        let text = text(of: render(record([])))
        #expect(text.contains("June 2027"))
        #expect(text.contains("The sticker on the vehicle is authoritative."))
        #expect(!text.contains("deadline"))
    }

    @Test func recordShowsTheLatestOdometerWithItsDate() {
        let text = text(of: render(record([entry("a", day(2026, 3, 14), km: 66_300)])))
        #expect(text.contains("68,400 km (as of July 3, 2026)"))
    }

    @Test func emptyHistoryStillGivesAOnePageRecord() {
        let output = render(record([]))
        #expect(output.pageCount == 1)
        #expect(text(of: output).contains("No entries in the selected period."))
    }

    @Test func missingVehicleFieldsAreMarked() {
        let bare = ServiceRecordVehicle(licensePlate: "", category: .other)
        let text = text(of: render(record([], vehicle: bare)))
        #expect(text.contains("Not recorded"))
    }

    // MARK: Options

    @Test(arguments: [true, false]) func vinFollowsTheOption(_ include: Bool) {
        let text = text(of: render(record([entry("a", day(2026, 3, 14))], options: .init(includeVIN: include))))
        #expect(text.contains("WVWZZZ1KZAW000001") == include)
    }

    @Test(arguments: serviceRecordAmountCases) func amountsAndSumsFollowTheOption(_ testCase: ServiceRecordAmountCase) {
        let entries = [entry("a", day(2026, 3, 14), amount: 24_590)]
        let withAmounts = text(
            of: render(record(entries, options: .init(includeAmounts: true)), locale: testCase.locale))
        #expect(withAmounts.contains(testCase.amountText))
        #expect(withAmounts.contains(testCase.totalLabel))

        let without = text(of: render(record(entries), locale: testCase.locale))
        #expect(!without.contains(testCase.amountText))
        #expect(!without.contains(testCase.totalLabel))
    }

    @Test func periodLimitsTheListedEntries() {
        let entries = [
            entry("old", day(2024, 1, 5), workshop: "Old Garage"), entry("new", day(2026, 1, 5), workshop: "New Garage"),
        ]
        let text = text(of: render(record(entries, options: .init(period: .since(day(2025, 1, 1))))))
        #expect(text.contains("New Garage"))
        #expect(!text.contains("Old Garage"))
        #expect(text.contains("from January 1, 2025"))
    }

    @Test func receiptColumnTellsWhetherAReceiptExists() {
        let entries = [entry("a", day(2026, 3, 14), receipts: 1)]
        let plain = text(of: render(record(entries)))
        #expect(plain.contains("Yes"))
        let attached = text(
            of: render(
                record(entries, options: .init(includeReceiptAttachments: true)),
                receipts: ["a": [ServiceRecordReceiptFile(data: jpeg(), isPDF: false)]]))
        #expect(attached.contains("Attached"))
    }

    // MARK: Pagination

    @Test func longHistoryRunsOverSeveralPagesWithNumbersAndARepeatedHeader() throws {
        let entries = (1...150).map { index -> ServiceRecordEntry in
            let name = "Workshop-" + String(format: "%03d", index)
            return entry(
                "e\(index)", day(2020 + index / 40, 1 + index % 12, 1 + index % 28), km: 1_000 * index,
                amount: Int64(index * 100), workshop: name, work: ["Oil change", "Brake fluid", "Air filter"])
        }
        let output = render(record(entries, options: .init(includeAmounts: true)))
        #expect(output.pageCount >= 4)

        let document = try #require(PDFDocument(data: output.data))
        #expect(document.pageCount == output.pageCount)
        let total = output.pageCount
        for index in 0..<total {
            let page = flattened(document.page(at: index)?.string)
            #expect(page.contains("Page \(index + 1) of \(total)"))
            #expect(page.contains("Workshop and work"), "table header missing on page \(index + 1)")
        }
        // Every entry appears exactly once: no row is lost or drawn twice at a page break.
        let all = flattened(document.string)
        for index in 1...150 {
            #expect(occurrences(of: "Workshop-" + String(format: "%03d ", index), in: all + " ") == 1)
        }
    }

    @Test func aHugeEntryNeverOverflowsAPage() throws {
        let lines = (1...400).map { "Work item \($0)" }
        let output = render(record([entry("a", day(2026, 3, 14), work: lines), entry("b", day(2026, 3, 1))]))
        let document = try #require(PDFDocument(data: output.data))
        #expect(document.pageCount == output.pageCount)
        #expect(output.pageCount <= 3)
        #expect(flattened(document.string).contains("Work item 1 "))
    }

    // MARK: Attachments

    @Test func attachmentsAddOnePagePerReceiptPage() throws {
        let entries = [entry("a", day(2026, 3, 14), receipts: 1), entry("b", day(2026, 2, 1), receipts: 1)]
        let plain = render(record(entries))
        let files: [String: [ServiceRecordReceiptFile]] = [
            "a": [ServiceRecordReceiptFile(data: jpeg(), isPDF: false)],
            "b": [ServiceRecordReceiptFile(data: pdfReceipt(pages: 2), isPDF: true)],
        ]
        let withReceipts = render(record(entries, options: .init(includeReceiptAttachments: true)), receipts: files)
        // one image page, two pages of the PDF receipt
        #expect(withReceipts.pageCount == plain.pageCount + 3)

        let document = try #require(PDFDocument(data: withReceipts.data))
        let last = flattened(document.page(at: document.pageCount - 1)?.string)
        #expect(last.contains("Receipt for entry 2"))
        #expect(last.contains("Receipt 1 of 1, page 2 of 2"))
        #expect(last.contains("Page \(withReceipts.pageCount) of \(withReceipts.pageCount)"))
    }

    @Test func receiptsStayOutWhenTheOptionIsOff() {
        let entries = [entry("a", day(2026, 3, 14), receipts: 1)]
        let files = ["a": [ServiceRecordReceiptFile(data: jpeg(), isPDF: false)]]
        let output = render(record(entries), receipts: files)
        #expect(output.pageCount == 1)
    }

    @Test func aReceiptThatCannotBeShownGetsAPlaceholderPage() {
        let entries = [entry("a", day(2026, 3, 14), receipts: 2)]
        let files = ["a": [ServiceRecordReceiptFile(data: Data([1, 2, 3]), isPDF: false)]]
        let output = render(record(entries, options: .init(includeReceiptAttachments: true)), receipts: files)
        #expect(output.pageCount == 3)
        #expect(text(of: output).contains("This receipt could not be shown."))
    }

    // MARK: Metadata

    @Test func metadataHasTitleAndCreatorButNoAuthor() throws {
        let output = render(record([entry("a", day(2026, 3, 14))]))
        let attributes = try #require(PDFDocument(data: output.data)?.documentAttributes)
        func value(_ key: PDFDocumentAttribute) -> String? {
            (attributes[key] ?? attributes[key.rawValue]) as? String
        }
        #expect(value(.titleAttribute) == "Service record")
        #expect(value(.creatorAttribute) == "Wagemo")
        let author = value(.authorAttribute)
        #expect(author == nil || author == "")
    }
}

// MARK: - From the model

@MainActor
struct ServiceRecordFactoryTests {
    private func makeVehicle(in context: ModelContext) -> Vehicle {
        let vehicle = Vehicle(
            name: "Golf", licensePlate: " W 12345 A ", category: .passengerCar,
            firstRegistration: YearMonth(year: 2020, month: 6), plaque: YearMonth(year: 2027, month: 6))
        vehicle.vin = "WVWZZZ1KZAW000001"
        vehicle.make = "Volkswagen"
        vehicle.model = "Golf"
        context.insert(vehicle)
        context.insert(OdometerReading(
            date: CalendarDay.date(from: day(2026, 7, 3), in: .current), kilometers: 68_400, vehicle: vehicle))

        let recent = MaintenanceEntry(date: day(2026, 3, 14), category: .repair, vehicle: vehicle)
        recent.workshop = " Autohaus Müller "
        recent.workItems = "Brake pads\n\nBrake discs"
        recent.amountMinor = 24_590
        recent.odometerKm = 66_300
        context.insert(recent)
        context.insert(ReceiptDocument(data: jpeg(), contentType: ReceiptDocument.jpegType, entry: recent))
        // A receipt whose file is not on this device yet does not count.
        context.insert(ReceiptDocument(data: nil, entry: recent))

        let old = MaintenanceEntry(date: day(2024, 1, 5), vehicle: vehicle)
        old.workshop = "Old Garage"
        context.insert(old)
        return vehicle
    }

    @Test func preparedRecordMapsTheModel() throws {
        let context = ModelContext(try ModelContainerFactory.inMemory())
        let vehicle = makeVehicle(in: context)
        let prepared = ServiceRecordFactory.prepare(
            vehicle: vehicle, options: .init(includeAmounts: true), today: day(2027, 3, 1))
        let record = prepared.record
        #expect(record.vehicle.licensePlate == "W 12345 A")
        #expect(record.vehicle.vin == "WVWZZZ1KZAW000001")
        #expect(record.vehicle.plaque == YearMonth(year: 2027, month: 6))
        #expect(record.odometer == OdometerStatement(kilometers: 68_400, date: day(2026, 7, 3)))
        #expect(record.items.map(\.entry.workshop) == ["Autohaus Müller", "Old Garage"])
        #expect(record.items[0].entry.workItems == ["Brake pads", "Brake discs"])
        #expect(record.items[0].entry.money == Money(amountMinor: 24_590, currencyCode: "EUR"))
        #expect(record.items[0].entry.receiptCount == 1)
        #expect(record.costs.first?.total.amountMinor == 24_590)
        #expect(prepared.receipts.isEmpty)
    }

    @Test func receiptFilesAreReadOnlyWhenAttached() throws {
        let context = ModelContext(try ModelContainerFactory.inMemory())
        let vehicle = makeVehicle(in: context)
        let prepared = ServiceRecordFactory.prepare(
            vehicle: vehicle, options: .init(includeReceiptAttachments: true), today: day(2027, 3, 1))
        let id = try #require(prepared.record.attachmentItems.first?.entry.id)
        #expect(prepared.receipts[id]?.count == 1)
        #expect(prepared.receipts.count == 1)
    }

    @Test func optionsHideVinAmountsAndOldEntries() throws {
        let context = ModelContext(try ModelContainerFactory.inMemory())
        let vehicle = makeVehicle(in: context)
        let options = ServiceRecordOptions(period: .since(day(2025, 1, 1)), includeAmounts: false, includeVIN: false)
        let record = ServiceRecordFactory.prepare(vehicle: vehicle, options: options, today: day(2027, 3, 1)).record
        #expect(record.vehicle.vin == nil)
        #expect(record.items.count == 1)
        #expect(record.items[0].entry.money == nil)
        #expect(record.costs.isEmpty)
    }
}

// MARK: - Export and temporary files

@MainActor
@Suite(.serialized)
struct ServiceRecordExportTests {
    @Test func exportWritesAReadablePdfWithASanitizedName() async throws {
        defer { ServiceRecordTempFiles.sweep() }
        let context = ModelContext(try ModelContainerFactory.inMemory())
        let vehicle = Vehicle(name: "Golf", licensePlate: "W 12345 A", category: .passengerCar)
        context.insert(vehicle)
        let entry = MaintenanceEntry(date: day(2026, 3, 14), category: .service, vehicle: vehicle)
        entry.workshop = "Autohaus Müller"
        context.insert(entry)

        let prepared = ServiceRecordFactory.prepare(vehicle: vehicle, options: .init(), today: day(2027, 3, 1))
        let file = try await ServiceRecordExporter.export(prepared, locale: english)
        #expect(file.fileName == "Service record W-12345-A 2027-03-01.pdf")
        #expect(file.url.lastPathComponent == file.fileName)
        #expect(FileManager.default.fileExists(atPath: file.url.path))
        let document = try #require(PDFDocument(url: file.url))
        #expect(document.pageCount == file.pageCount)
        #expect(flattened(document.string).contains("Autohaus Müller"))
    }

    @Test func germanFileNameUsesTheGermanTitle() async throws {
        defer { ServiceRecordTempFiles.sweep() }
        let prepared = ServiceRecordFactory.Prepared(record: record([]), receipts: [:])
        let file = try await ServiceRecordExporter.export(prepared, locale: german)
        #expect(file.fileName == "Servicenachweis W-12345-A 2027-03-01.pdf")
    }

    @Test func sweepRemovesEveryExportedFile() throws {
        let url = try ServiceRecordTempFiles.write(Data([1]), named: "a.pdf")
        #expect(FileManager.default.fileExists(atPath: url.path))
        ServiceRecordTempFiles.sweep()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(!FileManager.default.fileExists(atPath: ServiceRecordTempFiles.root.path))
    }
}
