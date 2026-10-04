import Testing
@testable import PitlogCore

// Window table C (reform classes) and D (other classes), AT-40/41/42/43/56.

struct ReformWindowCase: Sendable {
    /// Rule IDs from docs/rules/AT-57a-KFG.md exercised by the case.
    let rules: String
    let dueMonth: YearMonth
    let opens: DayDate
    let closes: DayDate
    let regime: LegalRegime
    let notes: [RuleNote]
}

let reformWindowCases: [ReformWindowCase] = [
    // AT-40 previous law, -1/+4
    .init(rules: "AT-40", dueMonth: ym(2026, 1), opens: day(2025, 12, 1), closes: day(2026, 5, 31),
          regime: .previousLaw, notes: []),
    .init(rules: "AT-40", dueMonth: ym(2026, 12), opens: day(2026, 11, 1), closes: day(2027, 4, 30),
          regime: .previousLaw, notes: []),
    // AT-56 January 2027: capped at the day before the cutoff
    .init(rules: "AT-56", dueMonth: ym(2027, 1), opens: day(2026, 12, 1), closes: day(2027, 5, 18),
          regime: .transition, notes: [note("AT-56", .possibleExtension(until: day(2027, 5, 31)))]),
    // AT-56 February to July 2027: -1/+4
    .init(rules: "AT-56", dueMonth: ym(2027, 2), opens: day(2027, 1, 1), closes: day(2027, 6, 30),
          regime: .transition, notes: [note("AT-56")]),
    .init(rules: "AT-56", dueMonth: ym(2027, 5), opens: day(2027, 4, 1), closes: day(2027, 9, 30),
          regime: .transition, notes: [note("AT-56")]),
    .init(rules: "AT-56", dueMonth: ym(2027, 6), opens: day(2027, 5, 1), closes: day(2027, 10, 31),
          regime: .transition, notes: [note("AT-56")]),
    .init(rules: "AT-56", dueMonth: ym(2027, 7), opens: day(2027, 5, 19), closes: day(2027, 11, 30),
          regime: .transition, notes: [note("AT-56")]),
    // AT-56 August to October 2027: end of the due month
    .init(rules: "AT-56", dueMonth: ym(2027, 8), opens: day(2027, 5, 19), closes: day(2027, 8, 31),
          regime: .transition, notes: [note("AT-56", .possibleExtension(until: day(2027, 11, 30)))]),
    .init(rules: "AT-56", dueMonth: ym(2027, 9), opens: day(2027, 5, 19), closes: day(2027, 9, 30),
          regime: .transition, notes: [note("AT-56", .possibleExtension(until: day(2027, 11, 30)))]),
    .init(rules: "AT-56", dueMonth: ym(2027, 10), opens: day(2027, 6, 1), closes: day(2027, 10, 31),
          regime: .transition, notes: [note("AT-56", .possibleExtension(until: day(2027, 11, 30)))]),
    // AT-41 amended law, -4/0
    .init(rules: "AT-41", dueMonth: ym(2027, 11), opens: day(2027, 7, 1), closes: day(2027, 11, 30),
          regime: .amendedLaw, notes: []),
    .init(rules: "AT-41", dueMonth: ym(2028, 1), opens: day(2027, 9, 1), closes: day(2028, 1, 31),
          regime: .amendedLaw, notes: []),
    .init(rules: "AT-41", dueMonth: ym(2028, 2), opens: day(2027, 10, 1), closes: day(2028, 2, 29),
          regime: .amendedLaw, notes: []),
]

@Test(arguments: reformWindowCases, [VehicleCategory.passengerCar, .motorcycle, .lightTrailer])
func reformWindow(_ c: ReformWindowCase, category: VehicleCategory) {
    let resolved = austria.resolveWindow(for: c.dueMonth, category: category)
    #expect(resolved.window.opens == c.opens, "\(c.rules) opens for \(c.dueMonth)")
    #expect(resolved.window.closes == c.closes, "\(c.rules) closes for \(c.dueMonth)")
    #expect(resolved.regime == c.regime, "\(c.rules) regime for \(c.dueMonth)")
    #expect(resolved.notes == c.notes, "\(c.rules) notes for \(c.dueMonth)")
}

struct OtherWindowCase: Sendable {
    let rules: String
    let category: VehicleCategory
    let dueMonth: YearMonth
    let opens: DayDate
    let closes: DayDate
    let regime: LegalRegime
    let noteID: String
}

let otherWindowCases: [OtherWindowCase] = [
    .init(rules: "AT-42", category: .taxiOrAmbulance, dueMonth: ym(2026, 3), opens: day(2026, 2, 1),
          closes: day(2026, 3, 31), regime: .previousLaw, noteID: "AT-42"),
    .init(rules: "AT-42", category: .lightCommercial, dueMonth: ym(2027, 2), opens: day(2027, 1, 1),
          closes: day(2027, 2, 28), regime: .previousLaw, noteID: "AT-42"),
    .init(rules: "AT-42", category: .historic, dueMonth: ym(2027, 5), opens: day(2027, 4, 1),
          closes: day(2027, 5, 31), regime: .previousLaw, noteID: "AT-42"),
    .init(rules: "AT-43", category: .lightCommercial, dueMonth: ym(2027, 6), opens: day(2027, 5, 1),
          closes: day(2027, 6, 30), regime: .amendedLaw, noteID: "AT-43"),
    .init(rules: "AT-43", category: .historic, dueMonth: ym(2028, 4), opens: day(2028, 3, 1),
          closes: day(2028, 4, 30), regime: .amendedLaw, noteID: "AT-43"),
    .init(rules: "AT-43", category: .lightCommercial, dueMonth: ym(2028, 2), opens: day(2028, 1, 1),
          closes: day(2028, 2, 29), regime: .amendedLaw, noteID: "AT-43"),
    .init(rules: "AT-43", category: .taxiOrAmbulance, dueMonth: ym(2028, 1), opens: day(2027, 12, 1),
          closes: day(2028, 1, 31), regime: .amendedLaw, noteID: "AT-43"),
]

@Test(arguments: otherWindowCases)
func otherCategoryWindow(_ c: OtherWindowCase) {
    let resolved = austria.resolveWindow(for: c.dueMonth, category: c.category)
    #expect(resolved.window.opens == c.opens, "\(c.rules) opens")
    #expect(resolved.window.closes == c.closes, "\(c.rules) closes")
    #expect(resolved.regime == c.regime, "\(c.rules) regime")
    #expect(resolved.notes == [note(c.noteID)], "\(c.rules) note")
}

struct OpensExampleCase: Sendable {
    let dueMonth: YearMonth
    let opens: DayDate
}

let opensExamples: [OpensExampleCase] = [
    .init(dueMonth: ym(2027, 8), opens: day(2027, 5, 19)),
    .init(dueMonth: ym(2027, 6), opens: day(2027, 5, 1)),
    .init(dueMonth: ym(2028, 1), opens: day(2027, 9, 1)),
]

@Test(arguments: opensExamples)
func opensExamplesFromSpec(_ c: OpensExampleCase) {
    // AT-40/AT-41: earliest day inside the window under the law in force on that day.
    #expect(austria.resolveWindow(for: c.dueMonth, category: .passengerCar).window.opens == c.opens)
}

@Test(arguments: [ym(2026, 12), ym(2027, 1), ym(2027, 2), ym(2027, 7), ym(2027, 8),
                  ym(2027, 10), ym(2027, 11), ym(2028, 1), ym(2030, 6)])
func windowIsNeverEmpty(_ dueMonth: YearMonth) {
    // AT-40/41/56
    let window = austria.resolveWindow(for: dueMonth, category: .passengerCar).window
    #expect(window.opens <= window.closes)
}
