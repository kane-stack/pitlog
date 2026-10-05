import PitlogCore
import Testing

@testable import Pitlog

/// The step between the parser and the form: which scanned values are switched on, and what "Apply" hands over.
struct RegistrationReviewTests {
    private func field<Value: Hashable & Sendable>(_ value: Value, _ confidence: ScanConfidence, raw: String = "raw") -> ScannedField<Value> {
        ScannedField(value: value, rawText: raw, confidence: confidence)
    }

    private func item(_ field: RegistrationReviewField, in review: RegistrationReview) -> RegistrationReviewItem? {
        review.items.first { $0.field == field }
    }

    // MARK: Default selection

    @Test(arguments: [ScanConfidence.high, .medium, .low])
    func defaultSelectionFollowsTheConfidence(confidence: ScanConfidence) {
        let review = RegistrationReview(draft: RegistrationDraft(plate: field("W 12345 A", confidence)))
        #expect(review.items.count == 1)
        #expect(review.items.first?.included == (confidence != .low))
        #expect(review.items.first?.confidence == confidence)
    }

    @Test func everyFieldGetsItsOwnDefault() {
        let draft = RegistrationDraft(
            plate: field("W 12345 A", .high), firstRegistration: field(DayDate(year: 2020, month: 3, day: 15)!, .low),
            vin: field("WBX1A23456B789012", .medium), category: field(.passengerCar, .high),
            make: field("DEMO", .low))
        let review = RegistrationReview(draft: draft)
        #expect(item(.licensePlate, in: review)?.included == true)
        #expect(item(.firstRegistration, in: review)?.included == false)
        #expect(item(.vin, in: review)?.included == true)
        #expect(item(.category, in: review)?.included == true)
        #expect(item(.make, in: review)?.included == false)
    }

    @Test func itemsFollowTheOrderOfTheForm() {
        let draft = RegistrationDraft(
            plate: field("W 12345 A", .high), firstRegistration: field(DayDate(year: 2020, month: 3, day: 15)!, .high),
            vin: field("WBX1A23456B789012", .high), category: field(.passengerCar, .high),
            make: field("DEMO", .high), commercialName: field("Probe", .high))
        #expect(RegistrationReview(draft: draft).items.map(\.field)
            == [.licensePlate, .category, .make, .model, .vin, .firstRegistration])
    }

    // MARK: Mapping to the form

    @Test func fullDraftFillsEveryFormField() {
        let draft = RegistrationDraft(
            plate: field("W 12345 A", .high), firstRegistration: field(DayDate(year: 2020, month: 3, day: 15)!, .high),
            vin: field("WBX1A23456B789012", .high), category: field(.lightCommercial, .high),
            make: field("BEISPIELMARKE", .high), commercialName: field("Beispiel 1.5", .high))
        let prefill = RegistrationReview(draft: draft).prefill
        #expect(prefill.licensePlate == "W 12345 A")
        #expect(prefill.category == .lightCommercial)
        #expect(prefill.make == "BEISPIELMARKE")
        #expect(prefill.model == "Beispiel 1.5")
        #expect(prefill.vin == "WBX1A23456B789012")
        // The form stores month and year; the day is dropped.
        #expect(prefill.firstRegistration == YearMonth(year: 2020, month: 3))
    }

    @Test func lowConfidenceValuesStayOutOfTheFormUntilSwitchedOn() {
        let draft = RegistrationDraft(
            plate: field("W 12345 A", .high), make: field("DEMO", .low))
        var review = RegistrationReview(draft: draft)
        #expect(review.prefill.make == nil)
        #expect(review.prefill.licensePlate == "W 12345 A")
        review.items[review.items.firstIndex { $0.field == .make }!].included = true
        #expect(review.prefill.make == "DEMO")
    }

    @Test func theModelIsTheCommercialNameElseTheType() {
        let both = RegistrationReview(draft: RegistrationDraft(
            type: field("ABC1 / XYZ", .medium), commercialName: field("Beispiel 1.5", .high)))
        #expect(item(.model, in: both)?.text == "Beispiel 1.5")
        #expect(item(.model, in: both)?.source == "D.3")
        let typeOnly = RegistrationReview(draft: RegistrationDraft(type: field("ABC1 / XYZ", .medium)))
        #expect(item(.model, in: typeOnly)?.text == "ABC1 / XYZ")
        #expect(item(.model, in: typeOnly)?.source == "D.2")
    }

    @Test func editedValuesAreTheOnesApplied() {
        var review = RegistrationReview(draft: RegistrationDraft(
            plate: field("W 12345 A", .medium), vin: field("WBX1A23456B789012", .medium),
            firstRegistration: field(DayDate(year: 2020, month: 3, day: 15)!, .medium)))
        review.items[0].text = "  W 54321 B  "
        review.items[1].text = "wbx1a23456b789 999"
        review.items[2].month = 11
        review.items[2].year = 2019
        let prefill = review.prefill
        #expect(prefill.licensePlate == "W 54321 B")
        #expect(prefill.vin == "WBX1A23456B789999")
        #expect(prefill.firstRegistration == YearMonth(year: 2019, month: 11))
    }

    @Test func aClearedValueIsNotApplied() {
        var review = RegistrationReview(draft: RegistrationDraft(make: field("DEMO", .high)))
        review.items[0].text = "   "
        #expect(review.prefill.make == nil)
        #expect(!review.hasSelection)
    }

    @Test func discardedValuesAreNotApplied() {
        var review = RegistrationReview(draft: RegistrationDraft(
            plate: field("W 12345 A", .high), make: field("DEMO", .high)))
        for index in review.items.indices { review.items[index].included = false }
        #expect(review.prefill == RegistrationPrefill())
        #expect(!review.hasSelection)
    }

    @Test func aFirstRegistrationWithoutMonthIsNotApplied() {
        var review = RegistrationReview(draft: RegistrationDraft(
            firstRegistration: field(DayDate(year: 2020, month: 3, day: 15)!, .high)))
        review.items[0].month = nil
        #expect(review.prefill.firstRegistration == nil)
    }

    // MARK: Unsupported category

    @Test func anUnsupportedClassPrefillsOther() {
        let review = RegistrationReview(draft: RegistrationDraft(
            vehicleClass: field("N2", .high), category: field(.other, .high)))
        #expect(review.categoryIsUnsupported)
        #expect(review.prefill.category == .other)
        #expect(review.hasSelection)
    }

    @Test func aSupportedClassIsNotFlagged() {
        let review = RegistrationReview(draft: RegistrationDraft(category: field(.passengerCar, .high)))
        #expect(!review.categoryIsUnsupported)
    }

    // MARK: Empty and notices

    @Test func anEmptyDraftHasNothingToReview() {
        let review = RegistrationReview(draft: RegistrationDraft())
        #expect(review.isEmpty)
        #expect(!review.hasSelection)
    }

    @Test func noticesAreCarriedOver() {
        let review = RegistrationReview(draft: RegistrationDraft(
            plate: field("W 12345 A", .high), notices: [.cardBackSideMissing]))
        #expect(review.notices == [.cardBackSideMissing])
    }

    // MARK: From recognized lines to the form (the UI test fixtures)

    @Test func theMixedFixtureShowsEveryConfidenceLevel() throws {
        let draft = RegistrationScanService.draft(from: RegistrationScanFixtures.mixed, today: DayDate(year: 2026, month: 10, day: 5)!)
        let review = RegistrationReview(draft: draft)
        // Clear: plate. Check: VIN with an O for 0. Uncertain: the date on the line below its label.
        #expect(item(.licensePlate, in: review)?.confidence == .high)
        #expect(item(.licensePlate, in: review)?.included == true)
        #expect(item(.vin, in: review)?.confidence == .medium)
        #expect(item(.vin, in: review)?.included == true)
        #expect(item(.firstRegistration, in: review)?.confidence == .low)
        #expect(item(.firstRegistration, in: review)?.included == false)
        #expect(review.prefill.firstRegistration == nil)
        #expect(review.prefill.vin == "WBX1A23456B789012")
        #expect(review.prefill.model == "Beispiel 1.5")
        #expect(review.prefill.category == .passengerCar)
        // The holder is not in the review at all.
        let everything = String(describing: review)
        #expect(!everything.contains("MUSTERMANN"))
        #expect(!everything.contains("BEISPIELGASSE"))
        #expect(!everything.contains("1985"))
    }

    @Test func theUnsupportedFixturePrefillsOther() throws {
        let draft = RegistrationScanService.draft(
            from: RegistrationScanFixtures.unsupportedClass, today: DayDate(year: 2026, month: 10, day: 5)!)
        let review = RegistrationReview(draft: draft)
        #expect(review.categoryIsUnsupported)
        #expect(review.prefill.category == .other)
        #expect(review.prefill.licensePlate == "LL 7788 X")
        #expect(review.prefill.firstRegistration == YearMonth(year: 2019, month: 11))
    }
}
