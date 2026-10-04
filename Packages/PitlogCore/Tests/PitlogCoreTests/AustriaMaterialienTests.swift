import Testing
@testable import PitlogCore

// Examples M-01 ... M-12 of docs/rules/AT-57a-KFG.md section 11 with their "Erwartetes Ergebnis".
// Values that the sources do not give (first registration, day of month) are chosen to fit.

struct NextDueStep: Sendable {
    let inspection: DayDate
    let dueMonth: YearMonth
    let expected: YearMonth
}

struct MaterialCase: Sendable {
    /// "M-01" ... "M-12" and the rule IDs the example rests on.
    let id: String
    let input: InspectionInput
    var today: DayDate = day(2027, 1, 1)
    var window: InspectionWindow?
    var phase: InspectionPhase?
    /// `.some(nil)` asserts that there is no exchange plaque suggestion, `nil` skips the check.
    var exchange: YearMonth??
    var steps: [NextDueStep] = []
}

let materialCases: [MaterialCase] = [
    // M-01 (AT-56, AT-40): plaque June 2027 keeps six months, May to October.
    .init(id: "M-01 AT-56",
          input: .init(category: .passengerCar, firstRegistration: ym(2020, 6), plaque: ym(2027, 6)),
          window: .init(opens: day(2027, 5, 1), closes: day(2027, 10, 31))),
    // M-02 (AT-53): never inspected, first inspection four years after registration.
    .init(id: "M-02 AT-53",
          input: .init(category: .passengerCar, firstRegistration: ym(2024, 6), plaque: ym(2027, 6)),
          exchange: .some(ym(2028, 6))),
    // M-03 (AT-53, D-05): exchange plaque 2028-04, then 2030-04, 2031-04 (age 10), then yearly.
    .init(id: "M-03 AT-53 D-05",
          input: .init(category: .passengerCar, firstRegistration: ym(2021, 4), plaque: ym(2027, 4),
                       lastInspection: day(2026, 4, 15)),
          exchange: .some(ym(2028, 4)),
          steps: [
              .init(inspection: day(2028, 4, 10), dueMonth: ym(2028, 4), expected: ym(2030, 4)),
              .init(inspection: day(2030, 4, 10), dueMonth: ym(2030, 4), expected: ym(2031, 4)),
              .init(inspection: day(2031, 4, 10), dueMonth: ym(2031, 4), expected: ym(2032, 4)),
          ]),
    // M-04 (AT-53): the plaque is already two years after the first inspection.
    .init(id: "M-04 AT-53",
          input: .init(category: .passengerCar, firstRegistration: ym(2023, 9), plaque: ym(2028, 9),
                       lastInspection: day(2026, 9, 15)),
          exchange: .some(nil)),
    // M-05 (AT-54a reading A): age 8 at the last inspection, exchange plaque at age 10, then yearly.
    .init(id: "M-05 AT-54a",
          input: .init(category: .passengerCar, firstRegistration: ym(2018, 9), plaque: ym(2027, 9),
                       lastInspection: day(2026, 9, 15)),
          exchange: .some(ym(2028, 9)),
          steps: [.init(inspection: day(2028, 9, 10), dueMonth: ym(2028, 9), expected: ym(2029, 9))]),
    // M-06 (AT-54a): age 9 at the last inspection, no exchange plaque.
    .init(id: "M-06 AT-54a",
          input: .init(category: .passengerCar, firstRegistration: ym(2017, 5), plaque: ym(2027, 5),
                       lastInspection: day(2026, 5, 15)),
          exchange: .some(nil)),
    // M-07 (AT-53, D-05): inspected at the old punched due month, age 7 -> two years, then age 9 -> one year.
    .init(id: "M-07 D-05",
          input: .init(category: .passengerCar, firstRegistration: ym(2020, 3), plaque: ym(2027, 3)),
          steps: [
              .init(inspection: day(2027, 6, 10), dueMonth: ym(2027, 3), expected: ym(2029, 3)),
              .init(inspection: day(2029, 3, 10), dueMonth: ym(2029, 3), expected: ym(2030, 3)),
          ]),
    // M-08 (D-05): age 10 at the due month -> one year.
    .init(id: "M-08 D-05",
          input: .init(category: .passengerCar, firstRegistration: ym(2017, 6), plaque: ym(2027, 6)),
          steps: [.init(inspection: day(2027, 6, 10), dueMonth: ym(2027, 6), expected: ym(2028, 6))]),
    // M-09 (AT-51): without inspection or exchange the old punch stays; closes 2027-08-31.
    .init(id: "M-09 AT-51",
          input: .init(category: .passengerCar, firstRegistration: ym(2021, 4), plaque: ym(2027, 4)),
          today: day(2027, 9, 1),
          window: .init(opens: day(2027, 3, 1), closes: day(2027, 8, 31)),
          phase: .overdue),
    // M-10 (AT-41, D-02): four months before the due month for all vehicles.
    .init(id: "M-10 AT-41 D-02",
          input: .init(category: .lightCommercial, firstRegistration: ym(2020, 2), plaque: ym(2028, 2)),
          window: .init(opens: day(2027, 10, 1), closes: day(2028, 2, 29))),
    // M-11 (AT-56, D-01): due August 2027 is extended to the end of November 2027.
    .init(id: "M-11 AT-56 D-01",
          input: .init(category: .passengerCar, firstRegistration: ym(2015, 7), plaque: ym(2027, 8)),
          today: day(2027, 9, 1),
          window: .init(opens: day(2027, 5, 19), closes: day(2027, 11, 30)),
          phase: .open),
    // M-12 (AT-40, AT-56, D-04): historic vehicles keep -1/+4 for due month March 2027.
    .init(id: "M-12 AT-40 D-04",
          input: .init(category: .historic, firstRegistration: ym(1985, 3), plaque: ym(2027, 3)),
          window: .init(opens: day(2027, 2, 1), closes: day(2027, 7, 31))),
]

@Test(arguments: materialCases)
func materialExample(_ c: MaterialCase) throws {
    let status = try austria.status(for: c.input, today: c.today)
    if let window = c.window {
        #expect(status.window == window, "\(c.id) window")
    }
    if let phase = c.phase {
        #expect(status.phase == phase, "\(c.id) phase")
    }
    if let exchange = c.exchange {
        #expect(status.exchangePlaqueSuggestion == exchange, "\(c.id) exchange plaque")
    }
    for step in c.steps {
        let next = try austria.nextDue(after: step.inspection, dueMonth: step.dueMonth, input: c.input)
        #expect(next.dueMonth == step.expected, "\(c.id) nextDue after \(step.inspection)")
    }
}
