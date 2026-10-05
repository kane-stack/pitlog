import Foundation
import PitlogCore
import SwiftData
import Testing
import UIKit

@testable import Pitlog

private func day(_ y: Int, _ m: Int, _ d: Int) -> DayDate { DayDate(year: y, month: m, day: d)! }

// MARK: Customer block

struct CustomerBlockTests {
    @Test func removesTheCustomerLineButKeepsVehicleDatesAndAmounts() {
        let lines = [
            "Autohaus Kerschbaumer GmbH & Co KG",
            "Marktplatz 4, 6700 Bludenz",
            "UID ATU 48820716  FN 188305 f",
            "Rechnung Nr. 26-3318",
            "Kunde: Elisabeth Moosbrugger, Alpenstr. 9, 6700 Bludenz",
            "Fahrzeug  VW Caddy  Kz. VB-345CD",
            "Kilometerstand 112.340",
            "Rechnungsbetrag brutto 2.851,19",
        ]
        let kept = CustomerBlock.removing(from: lines)
        #expect(!kept.contains { $0.contains("Moosbrugger") })
        #expect(!kept.contains { $0.contains("Alpenstr") })
        #expect(kept.contains("Autohaus Kerschbaumer GmbH & Co KG"))
        #expect(kept.contains { $0.contains("Kilometerstand") })
        #expect(kept.contains { $0.contains("2.851,19") })
        #expect(kept.contains { $0.contains("VB-345CD") })
    }

    @Test func removesTheAddressLinesBehindARecipientLabel() {
        let lines = [
            "Kfz-Werkstatt Gruber e.U.",
            "Rechnungsempfänger",
            "Herr Max Mustermann",
            "Beispielgasse 5",
            "1010 Wien",
            "Rechnungsdatum 05.10.2026",
            "Gesamtbetrag 120,00",
        ]
        let kept = CustomerBlock.removing(from: lines)
        #expect(kept == ["Kfz-Werkstatt Gruber e.U.", "Rechnungsdatum 05.10.2026", "Gesamtbetrag 120,00"])
    }

    @Test func removesTheNameBehindASalutationAndStopsAtTheNextField() {
        let lines = ["Frau", "Anna Beispiel", "Hauptplatz 1", "Datum 01.02.2026", "Summe 10,00"]
        #expect(CustomerBlock.removing(from: lines) == ["Datum 01.02.2026", "Summe 10,00"])
    }

    @Test func removesTheLinesAboveACustomerVATID() {
        let lines = [
            "Bahnhofstr. 22", "5020 Salzburg", "UID-Nr. Kunde: ATU 66778899", "RECHNUNG 2026-0731", "Km-Stand 48.220",
        ]
        #expect(CustomerBlock.removing(from: lines) == ["RECHNUNG 2026-0731", "Km-Stand 48.220"])
    }

    @Test func aWorkshopReceiptWithoutACustomerStaysComplete() {
        let lines = ["Kfz Huber GmbH", "Hauptstraße 3, 8010 Graz", "Ölwechsel 89,90", "Kundendienst Mo-Fr 8-17 Uhr"]
        #expect(CustomerBlock.removing(from: lines) == lines)
    }

    @Test func aCustomerNumberDoesNotSwallowTheNextLines() {
        let lines = ["Kundennr. 4711", "Datum 01.02.2026"]
        #expect(CustomerBlock.removing(from: lines) == ["Datum 01.02.2026"])
    }

    @Test func storedTextOfAScanHasNoCustomerAndNoQRPayload() {
        let scan = ReceiptScan(
            lines: [
                RecognizedLine("Kfz Huber GmbH", page: 1),
                RecognizedLine("Kunde: Max Mustermann, Gasse 1", page: 1),
                RecognizedLine("_R1-AT1_K_1_2026-03-14T09:00:00_1,00_0,00_0,00_0,00_0,00_x_y_z", page: 1),
                RecognizedLine("Gesamtbetrag 10,00", page: 2),
            ], rksvPayloads: [], pageCount: 2)
        #expect(scan.storedText == "Kfz Huber GmbH\n\nGesamtbetrag 10,00")
    }
}

// MARK: Pipeline

private struct FakeRecognizer: TextRecognizing {
    let pages: [[RecognizedLine]]
    func recognizeLines(in page: ScanPage) async throws -> [RecognizedLine] {
        // The fake page's data is its index.
        pages[Int(page.data.first ?? 0)]
    }
}

private struct FakeBarcodes: BarcodeReading {
    let payloads: [[String]]
    func payloads(in page: ScanPage) async -> [String] { payloads[Int(page.data.first ?? 0)] }
}

struct ReceiptScanServiceTests {
    private func box(_ x: Double, _ y: Double) -> Rect { Rect(x: x, y: y, w: 0.2, h: 0.02) }

    @Test func numbersThePagesJoinsRowsAndKeepsOnlyRKSVCodes() async throws {
        let first = [
            RecognizedLine(text: "Gesamtbetrag", box: box(0.1, 0.5)),
            RecognizedLine(text: "120,00", box: box(0.7, 0.5)),
        ]
        let second = [RecognizedLine(text: "Seite 2", box: box(0.1, 0.1))]
        let service = ReceiptScanService(
            recognizer: FakeRecognizer(pages: [first, second]),
            barcodes: FakeBarcodes(payloads: [["https://example.com", "_R1-AT1_K_1_x"], ["_R1-AT1_K_1_x"]]))
        let scan = try await service.read([ScanPage(data: Data([0])), ScanPage(data: Data([1]))])
        #expect(scan.lines.map(\.text) == ["Gesamtbetrag 120,00", "Seite 2"])
        #expect(scan.lines.map(\.page) == [1, 2])
        // Duplicates and non-RKSV payloads are dropped.
        #expect(scan.rksvPayloads == ["_R1-AT1_K_1_x"])
        #expect(scan.pageCount == 2)
    }

    @Test func extractionServiceRunsBothAndMergesWithTheFakeModel() async {
        let lines = ReceiptScanFixtures.lines
        let context = ReceiptExtractionService.context(
            today: day(2026, 10, 5), vehicles: [], primary: nil, rksvPayloads: [])
        let extraction = await ReceiptExtractionService(model: FakeReceiptModel()).extract(
            lines: lines, context: context)
        #expect(extraction.modelAvailable)
        #expect(extraction.model != nil)
        #expect(extraction.modelDuration != nil)
        #expect(extraction.merge.modelRan)
        // Agreement on amount and date, disagreement on the workshop name.
        #expect(extraction.merge.gross?.value == Money(amountMinor: 37_990, currencyCode: "EUR"))
        #expect(extraction.merge.gross?.agreement == .agreed)
        #expect(extraction.merge.date?.value == day(2026, 3, 12))
        #expect(extraction.merge.workshop?.agreement == .conflict)
    }

    @Test func withoutAModelOnlyTheHeuristicRuns() async {
        let context = ReceiptExtractionService.context(
            today: day(2026, 10, 5), vehicles: [], primary: nil, rksvPayloads: [])
        let extraction = await ReceiptExtractionService(model: nil).extract(
            lines: ReceiptScanFixtures.lines, context: context)
        #expect(!extraction.modelAvailable)
        #expect(extraction.model == nil)
        #expect(!extraction.merge.modelRan)
        #expect(extraction.merge.gross?.agreement == .single)
        #expect(extraction.merge.gross?.value == Money(amountMinor: 37_990, currencyCode: "EUR"))
    }

    @Test func anUnavailableModelIsNeverCalled() async {
        let context = ReceiptExtractionService.context(
            today: day(2026, 10, 5), vehicles: [], primary: nil, rksvPayloads: [])
        let extraction = await ReceiptExtractionService(model: UnavailableReceiptModel()).extract(
            lines: ReceiptScanFixtures.lines, context: context)
        #expect(!extraction.modelAvailable)
        #expect(extraction.modelDuration == nil)
    }

    @Test func theContextCarriesTheVehicleFactsAndEveryPlate() {
        let golf = ReceiptVehicleInfo(
            id: UUID(), displayName: "Golf", plate: "W 12345 A", vin: "WVWZZZ1KZAW123456",
            firstRegistration: YearMonth(year: 2020, month: 6), lastKnownOdometerKm: 68_400)
        let fiat = ReceiptVehicleInfo(id: UUID(), displayName: "Fiat", plate: "G 4711 K")
        let context = ReceiptExtractionService.context(
            today: day(2026, 10, 5), vehicles: [golf, fiat], primary: golf.id, rksvPayloads: ["_R1"])
        #expect(context.lastKnownOdometerKm == 68_400)
        #expect(context.firstRegistration == YearMonth(year: 2020, month: 6))
        #expect(context.knownPlates == ["W 12345 A", "G 4711 K"])
        #expect(context.knownVINs == ["WVWZZZ1KZAW123456"])
        #expect(context.rksvPayloads == ["_R1"])
    }
}

// MARK: Validation of model output

struct ReceiptDraftValidatorTests {
    private let context = ReceiptContext(
        today: day(2026, 10, 5), firstRegistration: YearMonth(year: 2020, month: 6), lastKnownOdometerKm: 68_400)
    private let lines = [
        "Kfz Huber GmbH", "Kennzeichen W 12345 A", "FIN WVWZZZ1KZAW123456", "Gesamtbetrag 120,00",
    ].map { RecognizedLine($0) }

    private func validated(_ edit: (inout ExtractedReceipt) -> Void) -> ExtractedReceipt {
        var draft = ExtractedReceipt()
        edit(&draft)
        return ReceiptDraftValidator.validated(draft, lines: lines, context: context)
    }

    @Test func aDateInTheFutureOrBeforeTheFirstRegistrationBecomesNil() {
        let result = validated {
            $0.serviceDate = day(2026, 12, 1)
            $0.invoiceDate = day(2019, 1, 1)
        }
        #expect(result.serviceDate == nil)
        #expect(result.invoiceDate == nil)
        #expect(validated { $0.serviceDate = day(2026, 10, 5) }.serviceDate == day(2026, 10, 5))
    }

    @Test func anOdometerBelowTheLastKnownOneBecomesNil() {
        #expect(validated { $0.odometerKm = 68_399 }.odometerKm == nil)
        #expect(validated { $0.odometerKm = 68_400 }.odometerKm == 68_400)
        #expect(validated { $0.odometerKm = 0 }.odometerKm == nil)
        #expect(validated { $0.odometerKm = 9_999_999 }.odometerKm == nil)
    }

    @Test func grossNetAndVATThatDoNotAddUpAreDropped() {
        let bad = validated {
            $0.grossTotal = Money(amountMinor: 12_000, currencyCode: "EUR")
            $0.netTotal = Money(amountMinor: 10_000, currencyCode: "EUR")
            $0.vatAmount = Money(amountMinor: 1_000, currencyCode: "EUR")
        }
        #expect(bad.grossTotal == nil && bad.netTotal == nil && bad.vatAmount == nil)
        let good = validated {
            $0.grossTotal = Money(amountMinor: 12_000, currencyCode: "EUR")
            $0.netTotal = Money(amountMinor: 10_000, currencyCode: "EUR")
            $0.vatAmount = Money(amountMinor: 2_000, currencyCode: "EUR")
        }
        #expect(good.grossTotal?.amountMinor == 12_000)
    }

    @Test func aNegativeOrAbsurdAmountIsDropped() {
        #expect(validated { $0.grossTotal = Money(amountMinor: -500, currencyCode: "EUR") }.grossTotal == nil)
        #expect(validated { $0.grossTotal = Money(amountMinor: 0, currencyCode: "EUR") }.grossTotal == nil)
        #expect(validated { $0.grossTotal = Money(amountMinor: 99_999_999_999, currencyCode: "EUR") }.grossTotal == nil)
    }

    @Test func identifiersThatAreNotInTheTextAreDropped() {
        let invented = validated {
            $0.plate = "B 999 ZZ"
            $0.vin = "WBAXXXXXXXXXXXXXX"
            $0.workshopName = "Garage Phantasie"
        }
        #expect(invented.plate == nil && invented.vin == nil && invented.workshopName == nil)
        let real = validated {
            $0.plate = "W-12345-A"
            $0.vin = "WVWZZZ1KZAW123456"
            $0.workshopName = "Kfz Huber GmbH"
        }
        #expect(real.plate != nil && real.vin != nil && real.workshopName != nil)
    }

    @Test func aFailedFieldAlsoLosesItsEvidence() {
        let result = validated {
            $0.odometerKm = 10
            $0.evidence[.odometerKm] = FieldEvidence(confidence: .medium, source: "x")
        }
        #expect(result.evidence[.odometerKm] == nil)
    }
}

// MARK: Prompt

struct ReceiptPromptBuilderTests {
    @Test func aShortReceiptIsSentComplete() {
        let text = ReceiptPromptBuilder.text(lines: ["Kfz Huber", "", "Gesamtbetrag 10,00"])
        #expect(text == "Kfz Huber\nGesamtbetrag 10,00")
    }

    @Test func aLongReceiptKeepsHeaderFooterAndLinesWithAmountsOrDates() {
        var lines = (0..<12).map { "Kopf \($0)" }
        lines += (0..<400).map { "Beschreibung ohne Zahlen \($0)x" }
        lines += ["Position 12,50", "Leistungsdatum 05.10.2026"]
        lines += (0..<400).map { "Noch mehr Text \($0)x" }
        lines += (0..<15).map { "Fuss \($0)" }
        let text = ReceiptPromptBuilder.text(lines: lines, budget: 1_500)
        #expect(text.count <= 1_500 + 200)
        #expect(text.contains("Kopf 0"))
        #expect(text.contains("Fuss 14"))
        #expect(text.contains("Position 12,50"))
        #expect(text.contains("Leistungsdatum 05.10.2026"))
        #expect(!text.contains("Beschreibung ohne Zahlen 200x"))
        #expect(text.contains("…"))
    }

    @Test func linesKeepTheirOrder() {
        var lines = (0..<10).map { "Kopf \($0)" }
        lines += (0..<300).map { "Fülltext \($0)x" }
        lines += ["Mitte 1,00"]
        lines += (0..<20).map { "Fuss \($0)" }
        let text = ReceiptPromptBuilder.text(lines: lines, budget: 1_000)
        let head = text.range(of: "Kopf 0")?.lowerBound
        let middle = text.range(of: "Mitte 1,00")?.lowerBound
        let foot = text.range(of: "Fuss 19")?.lowerBound
        #expect(head != nil && middle != nil && foot != nil)
        if let head, let middle, let foot {
            #expect(head < middle && middle < foot)
        }
    }

    @Test func parsesISODates() {
        #expect(DayDate.fromISO("2026-03-12") == day(2026, 3, 12))
        #expect(DayDate.fromISO("2026-03-12T10:00:00") == day(2026, 3, 12))
        #expect(DayDate.fromISO("12.03.2026") == nil)
        #expect(DayDate.fromISO("2026-02-30") == nil)
        #expect(day(2026, 3, 2).isoString == "2026-03-02")
    }
}

#if canImport(FoundationModels)
struct FoundationModelsMappingTests {
    @Test func mapsTheGeneratedFieldsIntoADraftWithModelEvidence() {
        let generated = GeneratedReceipt(
            grossTotalMinorUnits: 37_990, currencyCode: "EUR", serviceDate: "2026-03-12", invoiceDate: "kaputt",
            workshopName: " Kfz Huber ", odometerKm: 69_150, licensePlate: "null", vin: "wvwzzz1kzaw123456",
            category: .repair, workItems: ["Ölwechsel", "  "])
        let draft = FoundationModelsReceiptExtractor.draft(from: generated)
        #expect(draft.grossTotal == Money(amountMinor: 37_990, currencyCode: "EUR"))
        #expect(draft.serviceDate == day(2026, 3, 12))
        #expect(draft.invoiceDate == nil)
        #expect(draft.workshopName == "Kfz Huber")
        #expect(draft.odometerKm == 69_150)
        #expect(draft.plate == nil)
        #expect(draft.vin == "WVWZZZ1KZAW123456")
        #expect(draft.suggestedCategory == .repair)
        #expect(draft.workItems == ["Ölwechsel"])
        #expect(draft.evidence[.grossTotal]?.source == ReceiptEvidenceSource.model)
    }
}
#endif

// MARK: Attachment and entry

@MainActor
struct ReceiptEntryTests {
    private func jpeg(color: UIColor) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 300))
        return renderer.jpegData(withCompressionQuality: 0.8) { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
        }
    }

    @Test func aSinglePageIsStoredAsJPEG() throws {
        let attachment = try #require(
            ReceiptAttachmentBuilder.make(
                pages: [ScanPage(data: jpeg(color: .red))], originalPDF: nil, recognizedText: "text"))
        #expect(attachment.contentType == ReceiptDocument.jpegType)
        #expect(attachment.pageCount == 1)
        #expect(attachment.recognizedText == "text")
    }

    @Test func severalPagesAreStoredAsOnePDF() throws {
        let pages = [UIColor.red, .green, .blue].map { ScanPage(data: jpeg(color: $0)) }
        let attachment = try #require(ReceiptAttachmentBuilder.make(pages: pages, originalPDF: nil, recognizedText: ""))
        #expect(attachment.contentType == ReceiptDocument.pdfType)
        #expect(attachment.pageCount == 3)
        #expect(attachment.data.prefix(5) == Data("%PDF-".utf8))
    }

    @Test func noPageGivesNoAttachment() {
        #expect(ReceiptAttachmentBuilder.make(pages: [], originalPDF: nil, recognizedText: "") == nil)
        #expect(ReceiptAttachmentBuilder.make(pages: [ScanPage(data: Data([1, 2]))], originalPDF: nil, recognizedText: "") == nil)
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainerFactory.inMemory())
    }

    @Test func createsTheEntryWithTheScanAsReceipt() throws {
        let context = try makeContext()
        let vehicle = Vehicle(name: "Golf", licensePlate: "W 12345 A")
        context.insert(vehicle)
        let attachment = ReceiptAttachment(
            data: Data([1, 2, 3]), contentType: ReceiptDocument.pdfType, pageCount: 2, recognizedText: "Gesamtbetrag 10,00")
        let application = ReceiptApplication(
            vehicleID: vehicle.id, date: day(2026, 3, 12), category: .service, workshop: "Kfz Huber",
            workItems: "Ölwechsel", amount: Money(amountMinor: 37_990, currencyCode: "EUR"), odometerKm: 69_150)

        let entry = ReceiptEntryWriter.createEntry(
            from: application, attachment: attachment, vehicle: vehicle, in: context, today: day(2026, 10, 5))

        #expect(entry.vehicle === vehicle)
        #expect(entry.date == day(2026, 3, 12))
        #expect(entry.category == .service)
        #expect(entry.workshop == "Kfz Huber")
        #expect(entry.workItems == "Ölwechsel")
        #expect(entry.money == Money(amountMinor: 37_990, currencyCode: "EUR"))
        #expect(entry.odometerKm == 69_150)
        let receipt = try #require(entry.receipts?.first)
        #expect(receipt.contentType == ReceiptDocument.pdfType)
        #expect(receipt.pageCount == 2)
        #expect(receipt.recognizedText == "Gesamtbetrag 10,00")
        #expect(receipt.data == Data([1, 2, 3]))
    }

    @Test func theOdometerBecomesAReadingOnlyIfItIsConfirmedAndNewer() throws {
        let context = try makeContext()
        let vehicle = Vehicle(name: "Golf")
        context.insert(vehicle)
        context.insert(OdometerReading(date: CalendarDay.date(from: day(2026, 1, 1), in: .current), kilometers: 68_400, vehicle: vehicle))

        // Switched off: the entry has no odometer and no reading is added.
        ReceiptEntryWriter.createEntry(
            from: ReceiptApplication(vehicleID: vehicle.id, date: day(2026, 3, 12)), attachment: nil,
            vehicle: vehicle, in: context, today: day(2026, 10, 5))
        #expect(vehicle.odometerReadings?.count == 1)

        // Confirmed but below the latest reading: kept on the entry, no reading (M4 rule).
        let below = ReceiptEntryWriter.createEntry(
            from: ReceiptApplication(vehicleID: vehicle.id, date: day(2026, 3, 12), odometerKm: 60_000),
            attachment: nil, vehicle: vehicle, in: context, today: day(2026, 10, 5))
        #expect(below.odometerKm == 60_000)
        #expect(vehicle.odometerReadings?.count == 1)

        // Confirmed and newer: a reading is added.
        ReceiptEntryWriter.createEntry(
            from: ReceiptApplication(vehicleID: vehicle.id, date: day(2026, 3, 12), odometerKm: 69_150),
            attachment: nil, vehicle: vehicle, in: context, today: day(2026, 10, 5))
        #expect(vehicle.odometerReadings?.count == 2)
        #expect(vehicle.currentOdometerKm == 69_150)
    }

    @Test func switchedOffValuesFallBackToTodayAndOtherWorkshop() throws {
        let context = try makeContext()
        let vehicle = Vehicle(name: "Golf")
        context.insert(vehicle)
        let entry = ReceiptEntryWriter.createEntry(
            from: ReceiptApplication(vehicleID: vehicle.id), attachment: nil, vehicle: vehicle, in: context,
            today: day(2026, 10, 5))
        #expect(entry.date == day(2026, 10, 5))
        #expect(entry.category == .otherWorkshop)
        #expect(entry.money == nil)
        #expect(entry.receipts?.isEmpty ?? true)
    }
}
