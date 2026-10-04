import PitlogCore
import Testing

@testable import Pitlog

struct InspectionServiceTests {
    private let service = InspectionService()
    private let today = DayDate(year: 2027, month: 4, day: 1) ?? DayDate(year: 2000, month: 1, day: 1)!

    private func ym(_ year: Int, _ month: Int) -> YearMonth {
        YearMonth(year: year, month: month) ?? YearMonth(year: 2000, month: 1)!
    }

    @Test func mapsAllFieldsToInput() {
        let vehicle = Vehicle(
            name: "Golf", licensePlate: "W 1 A", category: .lightCommercial,
            firstRegistration: ym(2020, 6), plaque: ym(2027, 6))
        vehicle.lastInspection = DayDate(year: 2025, month: 6, day: 10)
        let input = service.input(for: vehicle)
        #expect(input?.category == .lightCommercial)
        #expect(input?.firstRegistration == ym(2020, 6))
        #expect(input?.plaque == ym(2027, 6))
        #expect(input?.lastInspection == DayDate(year: 2025, month: 6, day: 10))
    }

    @Test func missingFieldsMapToNil() {
        let vehicle = Vehicle(name: "Golf", firstRegistration: ym(2020, 6))
        let input = service.input(for: vehicle)
        #expect(input?.plaque == nil)
        #expect(input?.lastInspection == nil)
        #expect(service.input(for: Vehicle(name: "No registration")) == nil)
    }

    @Test func partialComponentsAreIgnored() {
        let vehicle = Vehicle(name: "Golf", firstRegistration: ym(2020, 6))
        vehicle.plaqueYear = 2027  // month missing
        vehicle.lastInspectionYear = 2025
        vehicle.lastInspectionMonth = 2
        vehicle.lastInspectionDay = 30  // not a real day
        #expect(vehicle.plaque == nil)
        #expect(vehicle.lastInspection == nil)
    }

    @Test func plaqueIsAuthoritative() {
        let vehicle = Vehicle(name: "Golf", firstRegistration: ym(2020, 6), plaque: ym(2027, 6))
        let status = service.evaluate(vehicle, today: today).status
        #expect(status?.dueMonth == ym(2027, 6))
        #expect(status?.dueMonthSource == .plaque)
    }

    @Test func withoutPlaqueTheDueMonthIsAnEstimate() {
        let vehicle = Vehicle(name: "Fiat", firstRegistration: ym(2018, 9))
        let status = service.evaluate(vehicle, today: today).status
        #expect(status?.dueMonthSource == .estimatedFromFirstRegistration)
        let estimate = service.estimatedDueMonth(
            countryCode: "AT", category: .passengerCar, firstRegistration: ym(2018, 9), today: today)
        #expect(estimate == status?.dueMonth)
    }

    @Test("Status is unavailable with a reason", arguments: [
        ("missing first registration", UnavailableCase.missingRegistration),
        ("unsupported category", UnavailableCase.otherCategory),
        ("unsupported country", UnavailableCase.germany),
        ("plaque before first registration", UnavailableCase.plaqueBeforeRegistration),
    ])
    func unavailable(_ name: String, _ unavailableCase: UnavailableCase) {
        let vehicle = unavailableCase.vehicle
        let reason = service.evaluate(vehicle, today: today).unavailableReason
        switch unavailableCase {
        case .missingRegistration: #expect(reason == .missingFirstRegistration)
        case .otherCategory: #expect(reason == .unsupportedCategory)
        case .germany: #expect(reason == .unsupportedCountry)
        case .plaqueBeforeRegistration:
            if case .invalidInput = reason {} else { Issue.record("Expected invalidInput, got \(String(describing: reason))") }
        }
    }

    @Test func estimateIsNilWithoutRegistrationOrForOtherCategory() {
        #expect(service.estimatedDueMonth(countryCode: "AT", category: .passengerCar, firstRegistration: nil, today: today) == nil)
        #expect(service.estimatedDueMonth(countryCode: "AT", category: .other, firstRegistration: ym(2018, 9), today: today) == nil)
    }

    @Test func nextDueAfterInspectionInsideTheWindow() {
        let vehicle = Vehicle(name: "Golf", firstRegistration: ym(2020, 6), plaque: ym(2027, 3))
        let inspection = DayDate(year: 2027, month: 3, day: 10) ?? today
        let result = service.nextDue(for: vehicle, inspectedOn: inspection, today: inspection)
        #expect((try? result.get().dueMonth) != nil)
    }

    @Test func nextDueFailsWithoutRegistration() {
        let result = service.nextDue(for: Vehicle(name: "x"), inspectedOn: today, today: today)
        if case .failure(let reason) = result {
            #expect(reason == .missingFirstRegistration)
        } else {
            Issue.record("Expected failure")
        }
    }

    @Test func ruleNoteTextsHaveAGenericFallback() {
        let locale = Locale(identifier: "en_US")
        for note in [
            RuleNote(ruleID: "AT-10", kind: .checkPlaque),
            RuleNote(ruleID: "AT-12", kind: .outsideWindowRepunch),
            RuleNote(ruleID: "AT-53", kind: .openLegalQuestion),
            RuleNote(ruleID: "AT-54a", kind: .openLegalQuestion),
            RuleNote(ruleID: "AT-99", kind: .openLegalQuestion),
        ] {
            #expect(!RuleNoteText.text(for: note, locale: locale).isEmpty)
        }
        let until = DayDate(year: 2027, month: 5, day: 31) ?? today
        let extended = RuleNote(ruleID: "AT-56", kind: .possibleExtension(until: until))
        #expect(RuleNoteText.text(for: extended, locale: locale).contains("2027"))
    }
}

enum UnavailableCase: Sendable {
    case missingRegistration, otherCategory, germany, plaqueBeforeRegistration

    @MainActor
    var vehicle: Vehicle {
        let registration = YearMonth(year: 2020, month: 6)
        switch self {
        case .missingRegistration:
            return Vehicle(name: "a")
        case .otherCategory:
            return Vehicle(name: "b", category: .other, firstRegistration: registration)
        case .germany:
            let vehicle = Vehicle(name: "c", firstRegistration: registration)
            vehicle.countryCode = "DE"
            return vehicle
        case .plaqueBeforeRegistration:
            return Vehicle(name: "d", firstRegistration: registration, plaque: YearMonth(year: 2019, month: 1))
        }
    }
}
