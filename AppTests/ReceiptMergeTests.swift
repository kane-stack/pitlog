import PitlogCore
import Testing

@testable import Pitlog

private func day(_ y: Int, _ m: Int, _ d: Int) -> DayDate { DayDate(year: y, month: m, day: d)! }

private func eur(_ minor: Int64) -> Money { Money(amountMinor: minor, currencyCode: "EUR") }

/// A draft with the given fields and evidence of the given confidence.
private func draft(
    gross: Int64? = nil, date: DayDate? = nil, workshop: String? = nil, km: Int? = nil, plate: String? = nil,
    category: MaintenanceCategory? = nil, items: [String] = [], confidence: FieldConfidence = .high,
    source: String = "line"
) -> ExtractedReceipt {
    var result = ExtractedReceipt()
    func note(_ field: ReceiptField) {
        result.evidence[field] = FieldEvidence(confidence: confidence, source: source)
    }
    if let gross { result.grossTotal = eur(gross); note(.grossTotal) }
    if let date { result.serviceDate = date; note(.serviceDate) }
    if let workshop { result.workshopName = workshop; note(.workshopName) }
    if let km { result.odometerKm = km; note(.odometerKm) }
    if let plate { result.plate = plate; note(.plate) }
    if let category { result.suggestedCategory = category; note(.category) }
    if !items.isEmpty { result.workItems = items; note(.workItems) }
    return result
}

// Constructed RKSV payload (see PitlogCore RKSVTests): 14 March 2026, 74.92 EUR.
private let rksvPayload =
    "_R1-AT1_KASSE01_2041_2026-03-14T14:23:11_74,92_0,00_0,00_0,00_0,00_eHl6Xw==_1A2B3C_dGVzdHNpZ25hdHVyZQ"
private let rksvCancellation =
    "_R1-AT1_K_1_2026-03-14T09:00:00_-1,00_0,00_0,00_0,00_U1RP_y_z"

struct ReceiptMergeTests {
    // MARK: Both extractors ran

    @Test func agreeingReadingsGetHighConfidence() {
        let h = draft(gross: 37_990, date: day(2026, 3, 12), km: 69_150, confidence: .medium)
        let m = draft(gross: 37_990, date: day(2026, 3, 12), km: 69_150, confidence: .medium)
        let merge = ReceiptMerger.merge(heuristic: h, model: m, rksv: nil)
        #expect(merge.gross?.confidence == .high)
        #expect(merge.gross?.agreement == .agreed)
        #expect(merge.date?.confidence == .high)
        #expect(merge.odometerKm?.confidence == .high)
        #expect(merge.gross?.isIncludedByDefault == true)
        #expect(merge.modelRan)
    }

    @Test func aValueOnOneSideGetsMediumConfidence() {
        // The heuristic is sure about the total, but nobody confirms it: medium. The model alone: medium too.
        let h = draft(gross: 37_990, confidence: .high)
        let m = draft(workshop: "Kfz Huber", confidence: .high)
        let merge = ReceiptMerger.merge(heuristic: h, model: m, rksv: nil)
        #expect(merge.gross?.confidence == .medium)
        #expect(merge.gross?.agreement == .single)
        #expect(merge.gross?.candidates.map(\.source) == [.heuristic])
        #expect(merge.workshop?.confidence == .medium)
        #expect(merge.workshop?.candidates.map(\.source) == [.model])
        #expect(merge.workshop?.isIncludedByDefault == true)
    }

    @Test func aLowSourceStaysLowEvenIfItIsTheOnlyReading() {
        let h = draft(km: 100, confidence: .low)
        let merge = ReceiptMerger.merge(heuristic: h, model: ExtractedReceipt(), rksv: nil)
        #expect(merge.odometerKm?.confidence == .low)
        #expect(merge.odometerKm?.isIncludedByDefault == false)
    }

    @Test func disagreeingReadingsAreLowAndUncheckedWithBothValuesOffered() throws {
        let h = draft(gross: 37_990, workshop: "Autohaus Beispiel GmbH", confidence: .high)
        let m = draft(gross: 31_658, workshop: "Kfz Technik Muster", confidence: .medium)
        let merge = ReceiptMerger.merge(heuristic: h, model: m, rksv: nil)
        let gross = try #require(merge.gross)
        #expect(gross.confidence == .low)
        #expect(gross.agreement == .conflict)
        #expect(!gross.isIncludedByDefault)
        // The heuristic's value is preselected, the model's is the alternative.
        #expect(gross.value == eur(37_990))
        #expect(gross.candidates.map(\.source) == [.heuristic, .model])
        #expect(gross.candidates.map(\.value) == [eur(37_990), eur(31_658)])
        #expect(merge.workshop?.agreement == .conflict)
    }

    @Test func plateComparisonIgnoresSpacesAndCase() {
        let h = draft(plate: "W 12345 A")
        let m = draft(plate: "w-12345-a")
        #expect(ReceiptMerger.merge(heuristic: h, model: m, rksv: nil).plate?.agreement == .agreed)
    }

    @Test func workshopNamesAgreeIfOneContainsTheOther() {
        let h = draft(workshop: "Müller Kfz")
        let m = draft(workshop: "MUELLER KFZ GmbH")
        #expect(ReceiptMerger.merge(heuristic: h, model: m, rksv: nil).workshop?.agreement == .agreed)
    }

    @Test func workItemsAgreeIfTheyShareAPosition() {
        let h = draft(items: ["Ölwechsel mit Filter", "Bremsbeläge vorne"])
        let m = draft(items: ["Ölwechsel"])
        #expect(ReceiptMerger.merge(heuristic: h, model: m, rksv: nil).workItems?.agreement == .agreed)
        let other = draft(items: ["Klimaservice"])
        #expect(ReceiptMerger.merge(heuristic: h, model: other, rksv: nil).workItems?.agreement == .conflict)
    }

    @Test func bothEmptyGiveNoField() {
        let merge = ReceiptMerger.merge(heuristic: ExtractedReceipt(), model: ExtractedReceipt(), rksv: nil)
        #expect(merge.gross == nil && merge.date == nil && merge.workshop == nil && merge.workItems == nil)
    }

    // MARK: Heuristic only

    @Test func withoutAModelTheHeuristicsOwnConfidenceStays() {
        let h = draft(gross: 37_990, date: day(2026, 3, 12), confidence: .high)
        let merge = ReceiptMerger.merge(heuristic: h, model: nil, rksv: nil)
        #expect(!merge.modelRan)
        #expect(merge.gross?.confidence == .high)
        #expect(merge.gross?.agreement == .single)
        #expect(merge.date?.value == day(2026, 3, 12))
    }

    // MARK: RKSV QR code

    @Test func theQRCodeWinsDateAndTotalOverBothReaders() throws {
        let rksv = try #require(parseRKSVCode(rksvPayload))
        let h = draft(gross: 7_000, date: day(2026, 3, 1))
        let m = draft(gross: 7_000, date: day(2026, 3, 1))
        let merge = ReceiptMerger.merge(heuristic: h, model: m, rksv: rksv)
        let gross = try #require(merge.gross)
        #expect(gross.value == eur(7_492))
        #expect(gross.confidence == .high)
        #expect(gross.agreement == .qrCode)
        // What the readers saw stays available, behind the QR value.
        #expect(gross.candidates.map(\.source) == [.qrCode, .heuristic])
        #expect(merge.date?.value == day(2026, 3, 14))
        #expect(merge.date?.agreement == .qrCode)
        #expect(merge.date?.isIncludedByDefault == true)
    }

    @Test func theQRCodeWinsEvenAgainstAConflict() throws {
        let rksv = try #require(parseRKSVCode(rksvPayload))
        let h = draft(gross: 7_000)
        let m = draft(gross: 8_000)
        let gross = ReceiptMerger.merge(heuristic: h, model: m, rksv: rksv).gross
        #expect(gross?.value == eur(7_492))
        #expect(gross?.confidence == .high)
        #expect(gross?.candidates.count == 3)
    }

    @Test func aCancellationQRCodeMakesACreditNoteWithoutAnAmount() throws {
        let rksv = try #require(parseRKSVCode(rksvCancellation))
        let h = draft(gross: 100)
        let merge = ReceiptMerger.merge(heuristic: h, model: nil, rksv: rksv)
        #expect(merge.isCreditNote)
        #expect(merge.gross == nil)
    }

    @Test func aCreditNoteNeverKeepsAnAmountFromTheModel() {
        var h = ExtractedReceipt()
        h.isCreditNote = true
        let m = draft(gross: 5_000)
        let merge = ReceiptMerger.merge(heuristic: h, model: m, rksv: nil)
        #expect(merge.isCreditNote)
        #expect(merge.gross == nil)
    }

    // MARK: Plaque

    @Test func theSuggestedPlaqueIsOnlyAHint() {
        var h = ExtractedReceipt()
        h.suggestedPlaque = YearMonth(year: 2027, month: 3)
        let merge = ReceiptMerger.merge(heuristic: h, model: nil, rksv: nil)
        #expect(merge.suggestedPlaque == YearMonth(year: 2027, month: 3))
    }
}

struct ReceiptVehicleMatcherTests {
    private let golf = ReceiptVehicleInfo(
        id: UUID(), displayName: "Golf", plate: "W 12345 A", vin: "WVWZZZ1KZAW123456")
    private let fiat = ReceiptVehicleInfo(id: UUID(), displayName: "Fiat", plate: "G 4711 K")
    private let noPlate = ReceiptVehicleInfo(id: UUID(), displayName: "Traktor", plate: "")

    @Test func matchesAPlateIgnoringSpacesAndCase() {
        let match = ReceiptVehicleMatcher.match(plate: "w-12345-a", vin: nil, in: [fiat, golf])
        #expect(match == ReceiptVehicleMatcher.Match(vehicleID: golf.id, evidence: .plate))
    }

    @Test func theVINIsStrongerThanThePlate() {
        let match = ReceiptVehicleMatcher.match(plate: "G 4711 K", vin: "wvwzzz1kzaw123456", in: [fiat, golf])
        #expect(match == ReceiptVehicleMatcher.Match(vehicleID: golf.id, evidence: .vin))
    }

    @Test func noMatchWithoutEvidenceOrWithAnUnknownPlate() {
        #expect(ReceiptVehicleMatcher.match(plate: nil, vin: nil, in: [golf, fiat]) == nil)
        #expect(ReceiptVehicleMatcher.match(plate: "B 999 ZZ", vin: nil, in: [golf, fiat]) == nil)
    }

    @Test func aVehicleWithoutAPlateIsNeverMatchedByAnEmptyPlate() {
        #expect(ReceiptVehicleMatcher.match(plate: "", vin: "", in: [noPlate]) == nil)
    }

    @Test func aPlateSharedByTwoVehiclesIsNoMatch() {
        let twin = ReceiptVehicleInfo(id: UUID(), displayName: "Golf (old)", plate: "W12345A")
        #expect(ReceiptVehicleMatcher.match(plate: "W 12345 A", vin: nil, in: [golf, twin]) == nil)
    }
}
