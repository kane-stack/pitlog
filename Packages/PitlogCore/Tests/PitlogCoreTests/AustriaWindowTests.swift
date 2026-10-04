import Testing
@testable import PitlogCore

// Window by due month, AT-40/41/56, D-01 to D-04, D-07. Z3-5 group: passenger car, motorcycle, light
// trailer, historic (-1/+4 under the previous law). Z1-2 group: N1, taxi (-3/0 under the previous law).

struct WindowCase: Sendable {
    /// Rule IDs from docs/rules/AT-57a-KFG.md exercised by the case.
    let rules: String
    let dueMonth: YearMonth
    let opens: DayDate
    let closes: DayDate
    let regime: LegalRegime
}

let z35Categories: [VehicleCategory] = [.passengerCar, .motorcycle, .lightTrailer, .historic]
let z12Categories: [VehicleCategory] = [.lightCommercial, .taxiOrAmbulance]

let z35WindowCases: [WindowCase] = [
    // AT-40 previous law, -1/+4
    .init(rules: "AT-40", dueMonth: ym(2026, 1), opens: day(2025, 12, 1), closes: day(2026, 5, 31), regime: .previousLaw),
    .init(rules: "AT-40", dueMonth: ym(2026, 12), opens: day(2026, 11, 1), closes: day(2027, 4, 30), regime: .previousLaw),
    // AT-56 January 2027: the previous law's grace period ends with the law on 2027-05-18
    .init(rules: "AT-56", dueMonth: ym(2027, 1), opens: day(2026, 12, 1), closes: day(2027, 5, 18), regime: .transition),
    // AT-56 February to July 2027: -1/+4 continues (D-04 for historic vehicles as well)
    .init(rules: "AT-56", dueMonth: ym(2027, 2), opens: day(2027, 1, 1), closes: day(2027, 6, 30), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 3), opens: day(2027, 2, 1), closes: day(2027, 7, 31), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 5), opens: day(2027, 4, 1), closes: day(2027, 9, 30), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 6), opens: day(2027, 5, 1), closes: day(2027, 10, 31), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 7), opens: day(2027, 5, 19), closes: day(2027, 11, 30), regime: .transition),
    // AT-56 August to October 2027: extended to the end of November 2027 (D-01)
    .init(rules: "AT-56", dueMonth: ym(2027, 8), opens: day(2027, 5, 19), closes: day(2027, 11, 30), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 9), opens: day(2027, 5, 19), closes: day(2027, 11, 30), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 10), opens: day(2027, 6, 1), closes: day(2027, 11, 30), regime: .transition),
    // AT-41 amended law, -4/0
    .init(rules: "AT-41", dueMonth: ym(2027, 11), opens: day(2027, 7, 1), closes: day(2027, 11, 30), regime: .amendedLaw),
    .init(rules: "AT-41", dueMonth: ym(2028, 1), opens: day(2027, 9, 1), closes: day(2028, 1, 31), regime: .amendedLaw),
    .init(rules: "AT-41", dueMonth: ym(2028, 2), opens: day(2027, 10, 1), closes: day(2028, 2, 29), regime: .amendedLaw),
]

@Test(arguments: z35WindowCases, z35Categories)
func z35Window(_ c: WindowCase, category: VehicleCategory) {
    let resolved = austria.resolveWindow(for: c.dueMonth, category: category)
    #expect(resolved.window.opens == c.opens, "\(c.rules) opens for \(c.dueMonth)")
    #expect(resolved.window.closes == c.closes, "\(c.rules) closes for \(c.dueMonth)")
    #expect(resolved.regime == c.regime, "\(c.rules) regime for \(c.dueMonth)")
}

let z12WindowCases: [WindowCase] = [
    // AT-42 previous law, -3/0
    .init(rules: "AT-42", dueMonth: ym(2026, 3), opens: day(2025, 12, 1), closes: day(2026, 3, 31), regime: .previousLaw),
    .init(rules: "AT-42", dueMonth: ym(2026, 12), opens: day(2026, 9, 1), closes: day(2026, 12, 31), regime: .previousLaw),
    // AT-56 transition: the previous law's -3/0 still applies up to due month July 2027
    .init(rules: "AT-56", dueMonth: ym(2027, 1), opens: day(2026, 10, 1), closes: day(2027, 1, 31), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 2), opens: day(2026, 11, 1), closes: day(2027, 2, 28), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 5), opens: day(2027, 2, 1), closes: day(2027, 5, 31), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 6), opens: day(2027, 3, 1), closes: day(2027, 6, 30), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 7), opens: day(2027, 4, 1), closes: day(2027, 7, 31), regime: .transition),
    // AT-56 August to October 2027: extended to 2027-11-30 (D-01). August: old candidate D-3 is
    // still before the cutoff, so the window opens on 2027-05-01 (D-03).
    .init(rules: "AT-56 D-03", dueMonth: ym(2027, 8), opens: day(2027, 5, 1), closes: day(2027, 11, 30), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 9), opens: day(2027, 5, 19), closes: day(2027, 11, 30), regime: .transition),
    .init(rules: "AT-56", dueMonth: ym(2027, 10), opens: day(2027, 6, 1), closes: day(2027, 11, 30), regime: .transition),
    // AT-41/AT-43 amended law, -4/0 for all vehicles (D-02)
    .init(rules: "AT-43", dueMonth: ym(2027, 11), opens: day(2027, 7, 1), closes: day(2027, 11, 30), regime: .amendedLaw),
    .init(rules: "AT-43", dueMonth: ym(2028, 1), opens: day(2027, 9, 1), closes: day(2028, 1, 31), regime: .amendedLaw),
    .init(rules: "AT-43", dueMonth: ym(2028, 2), opens: day(2027, 10, 1), closes: day(2028, 2, 29), regime: .amendedLaw),
]

@Test(arguments: z12WindowCases, z12Categories)
func z12Window(_ c: WindowCase, category: VehicleCategory) {
    let resolved = austria.resolveWindow(for: c.dueMonth, category: category)
    #expect(resolved.window.opens == c.opens, "\(c.rules) opens for \(c.dueMonth)")
    #expect(resolved.window.closes == c.closes, "\(c.rules) closes for \(c.dueMonth)")
    #expect(resolved.regime == c.regime, "\(c.rules) regime for \(c.dueMonth)")
}

struct OpensExampleCase: Sendable {
    let category: VehicleCategory
    let dueMonth: YearMonth
    let opens: DayDate
}

let opensExamples: [OpensExampleCase] = [
    .init(category: .passengerCar, dueMonth: ym(2027, 8), opens: day(2027, 5, 19)),
    .init(category: .passengerCar, dueMonth: ym(2027, 6), opens: day(2027, 5, 1)),
    .init(category: .passengerCar, dueMonth: ym(2028, 1), opens: day(2027, 9, 1)),
    // D-03: the law (-3/0 under the previous law) opens on 2027-05-01, the OeAMTC calculator on 2027-05-19.
    .init(category: .lightCommercial, dueMonth: ym(2027, 8), opens: day(2027, 5, 1)),
    .init(category: .lightCommercial, dueMonth: ym(2028, 2), opens: day(2027, 10, 1)),
]

@Test(arguments: opensExamples)
func opensExamplesFromSpec(_ c: OpensExampleCase) {
    // AT-40/AT-41/AT-42: earliest day inside the window under the law in force on that day.
    #expect(austria.resolveWindow(for: c.dueMonth, category: c.category).window.opens == c.opens)
}

@Test(arguments: [ym(2026, 12), ym(2027, 1), ym(2027, 2), ym(2027, 7), ym(2027, 8),
                  ym(2027, 10), ym(2027, 11), ym(2028, 1), ym(2030, 6)],
      z35Categories + z12Categories)
func windowIsNeverEmpty(_ dueMonth: YearMonth, category: VehicleCategory) {
    // AT-40/41/42/56
    let window = austria.resolveWindow(for: dueMonth, category: category).window
    #expect(window.opens <= window.closes)
}
