import Testing
@testable import PitlogCore

// nextDue(after:dueMonth:input:), AT-12/20/21/22/23/24/25/30/54.

struct NextDueCase: Sendable {
    let rules: String
    let category: VehicleCategory
    let firstRegistration: YearMonth
    let dueMonth: YearMonth
    let inspection: DayDate
    let expected: YearMonth
    /// Complete, sorted list of the rule IDs of the returned notes.
    let noteIDs: [String]
}

let nextDueCases: [NextDueCase] = [
    // Anchor 2: previous law and amended law on the same vehicle.
    .init(rules: "AT-20", category: .passengerCar, firstRegistration: ym(2020, 3), dueMonth: ym(2027, 3),
          inspection: day(2027, 3, 10), expected: ym(2028, 3), noteIDs: []),
    .init(rules: "AT-30 AT-54", category: .passengerCar, firstRegistration: ym(2020, 3), dueMonth: ym(2027, 3),
          inspection: day(2027, 6, 10), expected: ym(2028, 3), noteIDs: ["AT-54"]),
    // Window boundaries of due month 2027-03 (opens 2027-02-01, closes 2027-07-31).
    .init(rules: "AT-40", category: .passengerCar, firstRegistration: ym(2020, 3), dueMonth: ym(2027, 3),
          inspection: day(2027, 2, 1), expected: ym(2028, 3), noteIDs: []),
    .init(rules: "AT-56 AT-54", category: .passengerCar, firstRegistration: ym(2020, 3), dueMonth: ym(2027, 3),
          inspection: day(2027, 7, 31), expected: ym(2028, 3), noteIDs: ["AT-54"]),
    // Outside the window, one day too late / too early (AT-12).
    .init(rules: "AT-12", category: .passengerCar, firstRegistration: ym(2020, 3), dueMonth: ym(2027, 3),
          inspection: day(2027, 8, 1), expected: ym(2028, 8), noteIDs: ["AT-12"]),
    .init(rules: "AT-12", category: .passengerCar, firstRegistration: ym(2020, 3), dueMonth: ym(2027, 3),
          inspection: day(2027, 1, 31), expected: ym(2028, 1), noteIDs: ["AT-12"]),
    // Previous law sequence 3, 5, 6, 7, 8, ...
    .init(rules: "AT-20", category: .passengerCar, firstRegistration: ym(2023, 3), dueMonth: ym(2026, 3),
          inspection: day(2026, 3, 15), expected: ym(2028, 3), noteIDs: []),
    .init(rules: "AT-20", category: .passengerCar, firstRegistration: ym(2021, 3), dueMonth: ym(2026, 3),
          inspection: day(2026, 4, 1), expected: ym(2027, 3), noteIDs: []),
    .init(rules: "AT-20", category: .passengerCar, firstRegistration: ym(2018, 3), dueMonth: ym(2026, 3),
          inspection: day(2026, 3, 15), expected: ym(2027, 3), noteIDs: []),
    .init(rules: "AT-22", category: .lightTrailer, firstRegistration: ym(2022, 2), dueMonth: ym(2026, 2),
          inspection: day(2026, 2, 10), expected: ym(2027, 2), noteIDs: []),
    // Amended law sequence 4, 6, 8, 10, 11, ...
    .init(rules: "AT-30", category: .passengerCar, firstRegistration: ym(2023, 6), dueMonth: ym(2027, 6),
          inspection: day(2027, 6, 1), expected: ym(2029, 6), noteIDs: []),
    .init(rules: "AT-30", category: .passengerCar, firstRegistration: ym(2021, 6), dueMonth: ym(2027, 6),
          inspection: day(2027, 7, 1), expected: ym(2029, 6), noteIDs: []),
    .init(rules: "AT-30", category: .passengerCar, firstRegistration: ym(2019, 11), dueMonth: ym(2027, 11),
          inspection: day(2027, 10, 15), expected: ym(2029, 11), noteIDs: []),
    // AT-54: age 9 -> 10 is only one year, possibly two.
    .init(rules: "AT-30 AT-54", category: .passengerCar, firstRegistration: ym(2018, 11), dueMonth: ym(2027, 11),
          inspection: day(2027, 11, 10), expected: ym(2028, 11), noteIDs: ["AT-54"]),
    // Age 10 and above: yearly, no AT-54 note.
    .init(rules: "AT-30", category: .passengerCar, firstRegistration: ym(2017, 11), dueMonth: ym(2027, 11),
          inspection: day(2027, 11, 10), expected: ym(2028, 11), noteIDs: []),
    // Anchor 14
    .init(rules: "AT-30", category: .passengerCar, firstRegistration: ym(2010, 3), dueMonth: ym(2028, 3),
          inspection: day(2028, 3, 15), expected: ym(2029, 3), noteIDs: []),
    // Anchor 4
    .init(rules: "AT-20", category: .passengerCar, firstRegistration: ym(2021, 4), dueMonth: ym(2027, 4),
          inspection: day(2027, 4, 5), expected: ym(2028, 4), noteIDs: []),
    .init(rules: "AT-30", category: .passengerCar, firstRegistration: ym(2021, 4), dueMonth: ym(2027, 4),
          inspection: day(2027, 6, 1), expected: ym(2029, 4), noteIDs: []),
    // Anchor 8 and the cutoff day itself (law changes at 2027-05-19).
    .init(rules: "AT-21", category: .motorcycle, firstRegistration: ym(2019, 5), dueMonth: ym(2027, 5),
          inspection: day(2027, 5, 10), expected: ym(2028, 5), noteIDs: []),
    .init(rules: "AT-02 AT-21", category: .motorcycle, firstRegistration: ym(2019, 5), dueMonth: ym(2027, 5),
          inspection: day(2027, 5, 18), expected: ym(2028, 5), noteIDs: []),
    .init(rules: "AT-02 AT-30", category: .motorcycle, firstRegistration: ym(2019, 5), dueMonth: ym(2027, 5),
          inspection: day(2027, 5, 19), expected: ym(2029, 5), noteIDs: []),
    .init(rules: "AT-30", category: .motorcycle, firstRegistration: ym(2019, 5), dueMonth: ym(2027, 5),
          inspection: day(2027, 5, 25), expected: ym(2029, 5), noteIDs: []),
    // N1 (AT-23) is yearly under both laws.
    .init(rules: "AT-23 AT-42", category: .lightCommercial, firstRegistration: ym(2026, 2), dueMonth: ym(2027, 2),
          inspection: day(2027, 2, 10), expected: ym(2028, 2), noteIDs: ["AT-23"]),
    .init(rules: "AT-23 AT-43", category: .lightCommercial, firstRegistration: ym(2025, 8), dueMonth: ym(2028, 8),
          inspection: day(2028, 8, 1), expected: ym(2029, 8), noteIDs: ["AT-23"]),
    // Taxi (AT-24)
    .init(rules: "AT-24", category: .taxiOrAmbulance, firstRegistration: ym(2020, 5), dueMonth: ym(2027, 5),
          inspection: day(2027, 5, 10), expected: ym(2028, 5), noteIDs: ["AT-24"]),
    // Historic (AT-25): every two years under both laws.
    .init(rules: "AT-25 AT-43", category: .historic, firstRegistration: ym(1976, 4), dueMonth: ym(2028, 4),
          inspection: day(2028, 4, 20), expected: ym(2030, 4), noteIDs: ["AT-25"]),
    .init(rules: "AT-25", category: .historic, firstRegistration: ym(1980, 6), dueMonth: ym(2026, 6),
          inspection: day(2026, 6, 2), expected: ym(2028, 6), noteIDs: ["AT-25"]),
    // Anchor 15 and further AT-12 cases.
    .init(rules: "AT-12", category: .passengerCar, firstRegistration: ym(2020, 6), dueMonth: ym(2027, 6),
          inspection: day(2027, 12, 1), expected: ym(2028, 12), noteIDs: ["AT-12"]),
    .init(rules: "AT-12", category: .passengerCar, firstRegistration: ym(2017, 6), dueMonth: ym(2027, 6),
          inspection: day(2027, 12, 1), expected: ym(2028, 12), noteIDs: ["AT-12"]),
    .init(rules: "AT-12 AT-20", category: .passengerCar, firstRegistration: ym(2020, 3), dueMonth: ym(2026, 3),
          inspection: day(2026, 9, 10), expected: ym(2027, 9), noteIDs: ["AT-12"]),
    .init(rules: "AT-12 AT-30", category: .passengerCar, firstRegistration: ym(2023, 1), dueMonth: ym(2027, 1),
          inspection: day(2027, 8, 1), expected: ym(2029, 8), noteIDs: ["AT-12"]),
    .init(rules: "AT-12 AT-23", category: .lightCommercial, firstRegistration: ym(2022, 1), dueMonth: ym(2026, 1),
          inspection: day(2026, 3, 5), expected: ym(2027, 3), noteIDs: ["AT-12", "AT-23"]),
]

@Test(arguments: nextDueCases)
func nextDue(_ c: NextDueCase) throws {
    let input = InspectionInput(category: c.category, firstRegistration: c.firstRegistration)
    let result = try austria.nextDue(after: c.inspection, dueMonth: c.dueMonth, input: input)
    #expect(result.dueMonth == c.expected, "\(c.rules): \(c.inspection) for due month \(c.dueMonth)")
    #expect(ruleIDs(result.notes) == c.noteIDs, "\(c.rules): notes")
}

@Test func nextDueNoteKinds() throws {
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2018, 11))
    let inside = try austria.nextDue(after: day(2027, 11, 10), dueMonth: ym(2027, 11), input: input)
    #expect(inside.notes == [note("AT-54", .openLegalQuestion)])

    let outside = try austria.nextDue(after: day(2028, 3, 1), dueMonth: ym(2027, 11), input: input)
    #expect(outside.notes == [note("AT-12", .outsideWindowRepunch)])
}

@Test func nextDueRejectsUnsupportedCategory() {
    // Anchor 12
    let input = InspectionInput(category: .other, firstRegistration: ym(2020, 1))
    #expect(throws: InspectionRuleError.unsupportedCategory(.other)) {
        try austria.nextDue(after: day(2027, 1, 10), dueMonth: ym(2027, 1), input: input)
    }
}

@Test func nextDueRejectsDueMonthBeforeRegistration() {
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2024, 1))
    #expect(throws: InspectionRuleError.self) {
        try austria.nextDue(after: day(2023, 1, 10), dueMonth: ym(2023, 1), input: input)
    }
}

@Test func nextDueRejectsInspectionBeforeRegistrationOutsideWindow() {
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2024, 1))
    #expect(throws: InspectionRuleError.self) {
        try austria.nextDue(after: day(2023, 6, 1), dueMonth: ym(2027, 1), input: input)
    }
}
