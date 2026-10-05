import Foundation
import PitlogCore
import Testing

@testable import Pitlog

private func day(_ y: Int, _ m: Int, _ d: Int) -> DayDate { DayDate(year: y, month: m, day: d)! }

private func eur(_ minor: Int64) -> Money { Money(amountMinor: minor, currencyCode: "EUR") }

private func candidate<V: Hashable & Sendable>(_ value: V, _ source: ReceiptSource, _ snippet: String? = "line")
    -> ReceiptCandidate<V>
{
    ReceiptCandidate(value: value, source: source, snippet: snippet)
}

private func field<V: Hashable & Sendable>(
    _ value: V, _ confidence: FieldConfidence, _ agreement: ReceiptAgreement = .single,
    extra: [ReceiptCandidate<V>] = []
) -> MergedField<V> {
    MergedField(
        value: value, confidence: confidence, agreement: agreement,
        candidates: [candidate(value, .heuristic)] + extra)
}

private let locale = Locale(identifier: "en_US")

struct ReceiptReviewTests {
    private let golf = ReceiptVehicleInfo(id: UUID(), displayName: "Golf", plate: "W 12345 A")
    private let fiat = ReceiptVehicleInfo(id: UUID(), displayName: "Fiat", plate: "G 4711 K")

    private func merge(
        date: MergedField<DayDate>? = nil, gross: MergedField<Money>? = nil, km: MergedField<Int>? = nil,
        plate: MergedField<String>? = nil, vin: MergedField<String>? = nil, workshop: MergedField<String>? = nil
    ) -> ReceiptMerge {
        ReceiptMerge(
            date: date, gross: gross, workshop: workshop, odometerKm: km, plate: plate, vin: vin, category: nil,
            workItems: nil, suggestedPlaque: nil, isCreditNote: false, modelRan: true)
    }

    private func makeReview(_ merge: ReceiptMerge, fixed: Bool = false, context: UUID? = nil) -> ReceiptReview {
        ReceiptReview(
            merge: merge, vehicles: [golf, fiat], contextVehicleID: context, vehicleIsFixed: fixed, locale: locale)
    }

    // MARK: Defaults

    @Test(arguments: [FieldConfidence.high, .medium, .low])
    func defaultSelectionFollowsTheConfidence(confidence: FieldConfidence) {
        let review = makeReview(merge(gross: field(eur(1_200), confidence)))
        #expect(review.item(.amount)?.included == (confidence != .low))
        #expect(review.item(.amount)?.confidence == confidence)
    }

    @Test func aConflictIsUncheckedAndOffersBothReadings() throws {
        let conflict = field(
            eur(1_000), .low, .conflict, extra: [candidate(eur(2_000), .model, nil)])
        let review = makeReview(merge(gross: conflict))
        let item = try #require(review.item(.amount))
        #expect(!item.included)
        #expect(item.choices.count == 2)
        #expect(item.choices.map(\.source) == [.heuristic, .model])
        #expect(item.text == "10.00")
    }

    @Test func choosingAReadingTakesItOverAndSwitchesTheFieldOn() throws {
        var review = makeReview(
            merge(gross: field(eur(1_000), .low, .conflict, extra: [candidate(eur(2_000), .model, nil)])))
        review.choose(1, for: .amount)
        let item = try #require(review.item(.amount))
        #expect(item.included)
        #expect(item.selectedChoice == 1)
        #expect(review.application.amount == eur(2_000))
        review.choose(7, for: .amount)  // out of range: ignored
        #expect(review.item(.amount)?.selectedChoice == 1)
    }

    @Test func itemsFollowTheOrderOfTheForm() {
        let all = merge(
            date: field(day(2026, 3, 12), .high), gross: field(eur(100), .high), km: field(70_000, .high),
            workshop: field("Huber", .high))
        #expect(makeReview(all).items.map(\.field) == [.date, .amount, .workshop, .odometer])
    }

    // MARK: Application

    @Test func theApplicationContainsOnlySwitchedOnValues() {
        var review = makeReview(
            merge(
                date: field(day(2026, 3, 12), .high), gross: field(eur(37_990), .medium),
                km: field(70_000, .low), workshop: field(" Huber ", .high)))
        let application = review.application
        #expect(application.date == day(2026, 3, 12))
        #expect(application.amount == eur(37_990))
        #expect(application.workshop == "Huber")
        // The odometer is low confidence: not applied until the user switches it on.
        #expect(application.odometerKm == nil)

        review.items[review.items.firstIndex { $0.field == .odometer }!].included = true
        #expect(review.application.odometerKm == 70_000)
        review.items[review.items.firstIndex { $0.field == .date }!].included = false
        #expect(review.application.date == nil)
    }

    @Test func aGermanAmountIsReadBackInTheLocale() {
        let german = ReceiptReview(
            merge: merge(gross: field(eur(123_456), .high)), vehicles: [golf], contextVehicleID: golf.id,
            vehicleIsFixed: true, locale: Locale(identifier: "de_AT"))
        #expect(german.item(.amount)?.text == "1234,56")
        #expect(german.application.amount == eur(123_456))
    }

    @Test func anInvalidAmountBlocksApplyUntilItIsFixed() {
        var review = makeReview(merge(gross: field(eur(1_000), .high)), context: golf.id)
        review.items[0].text = "abc"
        #expect(review.hasInvalidAmount)
        #expect(!review.canApply)
        review.items[0].text = "12.50"
        #expect(!review.hasInvalidAmount)
        #expect(review.canApply)
        #expect(review.application.amount == eur(1_250))
    }

    @Test func aNonPositiveOdometerIsNeverApplied() {
        let review = makeReview(merge(km: field(0, .high)), context: golf.id)
        #expect(review.application.odometerKm == nil)
    }

    @Test func nothingSwitchedOnMeansNothingToApply() {
        let review = makeReview(merge(gross: field(eur(1_000), .low)), context: golf.id)
        #expect(!review.hasSelection)
        #expect(!review.canApply)
    }

    // MARK: Vehicle

    @Test func aMatchingPlatePreselectsTheVehicle() {
        let review = makeReview(merge(plate: field("W-12345-A", .high)), context: fiat.id)
        #expect(review.vehicleID == golf.id)
        #expect(review.vehicleStatus == .matches(.plate))
    }

    @Test func aMatchingVINIsStrongerThanTheContextVehicle() {
        let withVIN = ReceiptVehicleInfo(
            id: UUID(), displayName: "Caddy", plate: "", vin: "WVWZZZ2KZAX123456")
        let review = ReceiptReview(
            merge: merge(vin: field("WVWZZZ2KZAX123456", .high)), vehicles: [golf, withVIN],
            contextVehicleID: golf.id, vehicleIsFixed: false, locale: locale)
        #expect(review.vehicleID == withVIN.id)
        #expect(review.vehicleStatus == .matches(.vin))
    }

    @Test func withoutAMatchTheContextVehicleIsPreselectedAndTheReceiptIsFlagged() {
        let review = makeReview(merge(plate: field("B 999 ZZ", .high)), context: golf.id)
        #expect(review.vehicleID == golf.id)
        #expect(review.vehicleStatus == .differs)
    }

    @Test func withoutPlateOrVINTheStatusIsUnknownAndNoVehicleIsChosenWithoutContext() {
        let review = makeReview(merge(date: field(day(2026, 3, 12), .high)))
        #expect(review.vehicleID == nil)
        #expect(review.vehicleStatus == .unknown)
        #expect(!review.canApply)
    }

    @Test func aFixedVehicleStaysEvenIfTheReceiptNamesAnother() {
        let review = makeReview(merge(plate: field("G 4711 K", .high)), fixed: true, context: golf.id)
        #expect(review.vehicleID == golf.id)
        #expect(review.vehicleStatus == .differs)
    }

    @Test func theUserCanSwitchTheVehicleAndTheStatusFollows() {
        var review = makeReview(merge(plate: field("W 12345 A", .high)), context: fiat.id)
        #expect(review.vehicleID == golf.id)
        review.vehicleID = fiat.id
        #expect(review.vehicleStatus == .differs)
    }
}
