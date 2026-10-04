import Testing
@testable import PitlogCore

// status(for:today:): estimation, plaque precedence, phases, exchange suggestion, notes, errors.

// MARK: Phases (AT-41, AT-56)

struct PhaseCase: Sendable {
    let rules: String
    let today: DayDate
    let expected: InspectionPhase
}

// Due month 2028-03 in the amended law: opens 2027-11-01, closes 2028-03-31.
let phaseCases: [PhaseCase] = [
    .init(rules: "AT-41", today: day(2027, 10, 31), expected: .notYetOpen),
    .init(rules: "AT-41", today: day(2027, 11, 1), expected: .open),
    .init(rules: "AT-41", today: day(2028, 2, 29), expected: .open),
    .init(rules: "AT-41", today: day(2028, 3, 1), expected: .closesThisMonth),
    .init(rules: "AT-41", today: day(2028, 3, 31), expected: .closesThisMonth),
    .init(rules: "AT-41", today: day(2028, 4, 1), expected: .overdue),
]

@Test(arguments: phaseCases)
func phaseRelativeToToday(_ c: PhaseCase) throws {
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2020, 3), plaque: ym(2028, 3))
    #expect(try austria.status(for: input, today: c.today).phase == c.expected, "\(c.rules) \(c.today)")
}

// MARK: Estimation (AT-10)

struct EstimateCase: Sendable {
    let rules: String
    let category: VehicleCategory
    let firstRegistration: YearMonth
    let today: DayDate
    let expected: YearMonth
    let noteIDs: [String]
}

let estimateCases: [EstimateCase] = [
    // Anchor 6: registered under the amended law, 4 years.
    .init(rules: "AT-10 AT-30", category: .passengerCar, firstRegistration: ym(2028, 3),
          today: day(2028, 4, 1), expected: ym(2032, 3), noteIDs: ["AT-10"]),
    // May 2027 counts as previous law (conservative), June 2027 as amended law.
    .init(rules: "AT-02 AT-10", category: .passengerCar, firstRegistration: ym(2027, 5),
          today: day(2027, 6, 1), expected: ym(2030, 5), noteIDs: ["AT-10"]),
    .init(rules: "AT-02 AT-10", category: .passengerCar, firstRegistration: ym(2027, 6),
          today: day(2027, 7, 1), expected: ym(2031, 6), noteIDs: ["AT-10"]),
    // 2023-03, 2025-03, 2026-03 are past; 2027-03 still open (closes 2027-07-31).
    .init(rules: "AT-10 AT-20 AT-56", category: .passengerCar, firstRegistration: ym(2020, 3),
          today: day(2026, 10, 4), expected: ym(2027, 3), noteIDs: ["AT-10"]),
    // Estimation follows the law at registration even if the amended law would give a later date.
    .init(rules: "AT-10 AT-56", category: .passengerCar, firstRegistration: ym(2024, 6),
          today: day(2026, 10, 4), expected: ym(2027, 6), noteIDs: ["AT-10"]),
    // Past the old schedule: next due follows the amended sequence (age 8 -> 10).
    .init(rules: "AT-10 AT-20 AT-30", category: .passengerCar, firstRegistration: ym(2020, 3),
          today: day(2028, 4, 1), expected: ym(2030, 3), noteIDs: ["AT-10"]),
    .init(rules: "AT-10 AT-23 AT-42", category: .lightCommercial, firstRegistration: ym(2024, 1),
          today: day(2026, 10, 4), expected: ym(2027, 1), noteIDs: ["AT-10"]),
    .init(rules: "AT-10 AT-25 AT-43", category: .historic, firstRegistration: ym(1980, 5),
          today: day(2026, 10, 4), expected: ym(2028, 5), noteIDs: ["AT-10"]),
    .init(rules: "AT-10 AT-24", category: .taxiOrAmbulance, firstRegistration: ym(2026, 9),
          today: day(2026, 10, 4), expected: ym(2027, 9), noteIDs: ["AT-10"]),
]

@Test(arguments: estimateCases)
func estimatedDueMonth(_ c: EstimateCase) throws {
    let input = InspectionInput(category: c.category, firstRegistration: c.firstRegistration)
    let status = try austria.status(for: input, today: c.today)
    #expect(status.dueMonth == c.expected, "\(c.rules)")
    #expect(status.dueMonthSource == .estimatedFromFirstRegistration)
    #expect(ruleIDs(status.notes) == c.noteIDs, "\(c.rules) notes")
    #expect(status.exchangePlaqueSuggestion == nil)
    #expect(status.window.closes >= c.today, "estimate never lies in the past")
}

// MARK: Plaque precedence (AT-51, ADR-5)

@Test func plaqueTakesPrecedenceOverEstimate() throws { // AT-51
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2015, 1), plaque: ym(2028, 9))
    let status = try austria.status(for: input, today: day(2028, 1, 1))
    #expect(status.dueMonth == ym(2028, 9))
    #expect(status.dueMonthSource == .plaque)
    #expect(!ruleIDs(status.notes).contains("AT-10"))
    #expect(status.ruleVersion == "AT-2026-10-primary")
}

// MARK: Exchange plaque suggestion (AT-52/53/54)

struct ExchangeCase: Sendable {
    let rules: String
    let input: InspectionInput
    let expected: YearMonth?
}

let exchangeCases: [ExchangeCase] = [
    // Never inspected and first inspection falls after the cutoff: first registration + 4 years.
    .init(rules: "AT-53", input: .init(category: .passengerCar, firstRegistration: ym(2024, 6), plaque: ym(2027, 6)),
          expected: ym(2028, 6)),
    // FR + 3 years == 2027-05 is the boundary, still a candidate.
    .init(rules: "AT-53", input: .init(category: .passengerCar, firstRegistration: ym(2024, 5), plaque: ym(2027, 5)),
          expected: ym(2028, 5)),
    // FR + 3 years before 2027-05: the first inspection was due under the previous law.
    // D-06: any never-inspected vehicle with a plaque from 2027-02 on (the exchange plaque exists from 2027-05-19).
    .init(rules: "AT-53 D-06", input: .init(category: .passengerCar, firstRegistration: ym(2024, 4), plaque: ym(2027, 4)),
          expected: ym(2028, 4)),
    .init(rules: "AT-53 D-06", input: .init(category: .passengerCar, firstRegistration: ym(2024, 3), plaque: ym(2027, 3)),
          expected: ym(2028, 3)),
    .init(rules: "AT-53 D-06", input: .init(category: .passengerCar, firstRegistration: ym(2024, 2), plaque: ym(2027, 2)),
          expected: ym(2028, 2)),
    // Plaque 2027-01 ends before the exchange plaque exists.
    .init(rules: "AT-53 D-06", input: .init(category: .passengerCar, firstRegistration: ym(2024, 1), plaque: ym(2027, 1)),
          expected: nil),
    .init(rules: "AT-53", input: .init(category: .passengerCar, firstRegistration: ym(2015, 7), plaque: ym(2027, 8)),
          expected: nil),
    // Last inspection + 2 years, only up to age 8 at the last inspection.
    .init(rules: "AT-53", input: .init(category: .passengerCar, firstRegistration: ym(2021, 4), plaque: ym(2027, 4),
                                       lastInspection: day(2026, 4, 12)),
          expected: ym(2028, 4)),
    .init(rules: "AT-53 AT-54", input: .init(category: .passengerCar, firstRegistration: ym(2018, 3), plaque: ym(2027, 3),
                                             lastInspection: day(2026, 3, 5)),
          expected: ym(2028, 3)),
    .init(rules: "AT-54", input: .init(category: .passengerCar, firstRegistration: ym(2017, 3), plaque: ym(2027, 3),
                                       lastInspection: day(2026, 3, 5)),
          expected: nil),
    // Candidate not later than the plaque.
    .init(rules: "AT-53", input: .init(category: .passengerCar, firstRegistration: ym(2023, 9), plaque: ym(2028, 9),
                                       lastInspection: day(2026, 9, 20)),
          expected: nil),
    // Other reform classes.
    .init(rules: "AT-22 AT-53", input: .init(category: .lightTrailer, firstRegistration: ym(2025, 10), plaque: ym(2028, 10)),
          expected: ym(2029, 10)),
    .init(rules: "AT-21 AT-53", input: .init(category: .motorcycle, firstRegistration: ym(2025, 2), plaque: ym(2028, 2)),
          expected: ym(2029, 2)),
    // AT-52/53: only plaques punched under the previous law.
    // Regression: last inspection under the amended law, plaque 2029-04 must not yield 2029-06.
    .init(rules: "AT-52 AT-53", input: .init(category: .passengerCar, firstRegistration: ym(2021, 4), plaque: ym(2029, 4),
                                             lastInspection: day(2027, 6, 10)),
          expected: nil),
    .init(rules: "AT-52 AT-53", input: .init(category: .passengerCar, firstRegistration: ym(2021, 4), plaque: ym(2027, 4),
                                             lastInspection: day(2027, 5, 19)),
          expected: nil),
    .init(rules: "AT-52 AT-53", input: .init(category: .passengerCar, firstRegistration: ym(2021, 4), plaque: ym(2027, 4),
                                             lastInspection: day(2027, 5, 18)),
          expected: ym(2029, 5)),
    // D-11: derived last inspection. Age 5 at the plaque: L = P - 2 years; age >= 6: L = P - 1 year.
    .init(rules: "AT-53 D-11", input: .init(category: .passengerCar, firstRegistration: ym(2022, 3), plaque: ym(2027, 3)),
          expected: nil), // L = 2025-03 (age 3), candidate 2027-03 is not later than the plaque
    .init(rules: "AT-53 D-11", input: .init(category: .passengerCar, firstRegistration: ym(2020, 3), plaque: ym(2027, 3)),
          expected: ym(2028, 3)), // L = 2026-03
    .init(rules: "AT-53 D-11", input: .init(category: .motorcycle, firstRegistration: ym(2019, 5), plaque: ym(2027, 5)),
          expected: ym(2028, 5)), // L = 2026-05
    .init(rules: "AT-53 D-11", input: .init(category: .passengerCar, firstRegistration: ym(2018, 9), plaque: ym(2027, 9)),
          expected: ym(2028, 9)), // L = 2026-09 (age 8)
    .init(rules: "AT-53 D-11", input: .init(category: .passengerCar, firstRegistration: ym(2017, 5), plaque: ym(2027, 5)),
          expected: nil), // L = 2026-05 (age 9)
    // Derived L must lie before 2027-05: plaque 2028-06, age 5 -> L = 2026-06 -> candidate 2028-06, not later.
    .init(rules: "AT-53 D-11", input: .init(category: .passengerCar, firstRegistration: ym(2023, 6), plaque: ym(2028, 6)),
          expected: nil),
    // L = P - 1 year = 2027-06 is not before 2027-05: no derivation, no suggestion.
    .init(rules: "AT-53 D-11", input: .init(category: .passengerCar, firstRegistration: ym(2020, 6), plaque: ym(2028, 6)),
          expected: nil),
    // Age 4 at the plaque (> FR + 3 years): no derivation.
    .init(rules: "AT-53 D-11", input: .init(category: .passengerCar, firstRegistration: ym(2023, 6), plaque: ym(2027, 6)),
          expected: nil),
    // Never inspected but the plaque is no longer the original first-inspection punch.
    .init(rules: "AT-52 AT-53", input: .init(category: .passengerCar, firstRegistration: ym(2024, 6), plaque: ym(2028, 6)),
          expected: nil),
    // Categories outside AT-30 never get a suggestion.
    .init(rules: "AT-32", input: .init(category: .lightCommercial, firstRegistration: ym(2026, 2), plaque: ym(2027, 2)),
          expected: nil),
    .init(rules: "AT-32", input: .init(category: .taxiOrAmbulance, firstRegistration: ym(2026, 2), plaque: ym(2027, 2)),
          expected: nil),
    .init(rules: "AT-32", input: .init(category: .historic, firstRegistration: ym(2026, 2), plaque: ym(2027, 2)),
          expected: nil),
]

@Test(arguments: exchangeCases)
func exchangePlaqueSuggestion(_ c: ExchangeCase) throws {
    let status = try austria.status(for: c.input, today: day(2027, 1, 1))
    #expect(status.exchangePlaqueSuggestion == c.expected, "\(c.rules)")
    #expect(ruleIDs(status.notes).contains("AT-53") == (c.expected != nil), "\(c.rules) AT-53 note")
    // The derived-last-inspection hint appears exactly when a suggestion rests on a derived L.
    let derived = status.notes.contains(note("AT-53", .derivedLastInspection))
    #expect(!derived || c.expected != nil, "\(c.rules) derived note only with a suggestion")
}

@Test func derivedLastInspectionNoteOnlyWithoutLastInspection() throws { // AT-53, D-11
    let derived = InspectionInput(category: .passengerCar, firstRegistration: ym(2020, 3), plaque: ym(2027, 3))
    #expect(try austria.status(for: derived, today: day(2027, 1, 1)).notes
        == [note("AT-53"), note("AT-53", .derivedLastInspection)])
    let entered = InspectionInput(
        category: .passengerCar, firstRegistration: ym(2020, 3), plaque: ym(2027, 3),
        lastInspection: day(2026, 3, 10))
    #expect(try austria.status(for: entered, today: day(2027, 1, 1)).notes == [note("AT-53")])
    let neverInspected = InspectionInput(category: .passengerCar, firstRegistration: ym(2024, 3), plaque: ym(2027, 3))
    #expect(try austria.status(for: neverInspected, today: day(2027, 1, 1)).notes == [note("AT-53")])
}

// MARK: Notes (stable order, no duplicates)

@Test func categoriesWithoutOpenQuestionsHaveNoNotes() throws { // AT-23, AT-24, AT-25, D-08
    for category in [VehicleCategory.lightCommercial, .taxiOrAmbulance, .historic] {
        let input = InspectionInput(category: category, firstRegistration: ym(2020, 2), plaque: ym(2027, 2))
        #expect(try austria.status(for: input, today: day(2027, 1, 15)).notes.isEmpty, "\(category)")
    }
}

@Test func normalizedNotesDeduplicateAndSort() {
    let notes = [
        note("AT-53", .derivedLastInspection), note("AT-12", .outsideWindowRepunch), note("AT-53"),
        note("AT-53", .derivedLastInspection), note("AT-10", .checkPlaque),
    ]
    #expect(RuleNote.normalized(notes) == [
        note("AT-10", .checkPlaque), note("AT-12", .outsideWindowRepunch),
        note("AT-53"), note("AT-53", .derivedLastInspection),
    ])
}

// MARK: Errors

@Test(arguments: [VehicleCategory.other])
func unsupportedCategoryThrows(_ category: VehicleCategory) { // AT-26
    let input = InspectionInput(category: category, firstRegistration: ym(2020, 1))
    #expect(throws: InspectionRuleError.unsupportedCategory(category)) {
        try austria.status(for: input, today: day(2027, 1, 1))
    }
}

@Test func plaqueBeforeRegistrationIsInvalid() {
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2024, 6), plaque: ym(2024, 5))
    #expect(throws: InspectionRuleError.self) {
        try austria.status(for: input, today: day(2027, 1, 1))
    }
}

@Test func lastInspectionBeforeRegistrationIsInvalid() {
    let input = InspectionInput(
        category: .passengerCar, firstRegistration: ym(2024, 6),
        plaque: ym(2027, 6), lastInspection: day(2024, 5, 1))
    #expect(throws: InspectionRuleError.self) {
        try austria.status(for: input, today: day(2027, 1, 1))
    }
}

// MARK: Registry

@Test func registryContainsAustria() {
    let ruleSet = InspectionRuleRegistry.standard.ruleSet(for: .austria)
    #expect(ruleSet?.country == .austria)
    #expect(ruleSet?.ruleVersion == "AT-2026-10-primary")
    #expect(ruleSet?.supportedCategories.contains(.other) == false)
    #expect(InspectionRuleRegistry.standard.ruleSet(for: CountryCode(rawValue: "XX")) == nil)
}

@Test func cutoffDayIsStichtag() { // AT-02
    #expect(AustriaInspectionRules.cutoffDay == day(2027, 5, 19))
}
