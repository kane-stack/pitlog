import Testing
@testable import PitlogCore

// Comparison with the OeAMTC Pickerlrechner, docs/rules/AT-57a-KFG.md section 12 and
// docs/sources/OEAMTC_Pickerlrechner_2026-10-04.md (cases A1 ... A15 and X1 ... X13).

struct OeamtcCase: Sendable {
    let id: String
    let input: InspectionInput
    var today: DayDate = day(2027, 1, 1)
    let opens: DayDate
    let closes: DayDate
    let exchange: YearMonth?
    /// Expected estimated due month if there is no plaque.
    var estimatedDueMonth: YearMonth?
}

private func pcar(_ fr: YearMonth, _ plaque: YearMonth, last: DayDate? = nil) -> InspectionInput {
    InspectionInput(category: .passengerCar, firstRegistration: fr, plaque: plaque, lastInspection: last)
}

let oeamtcCases: [OeamtcCase] = [
    .init(id: "A1 D-11", input: pcar(ym(2020, 3), ym(2027, 3)),
          opens: day(2027, 2, 1), closes: day(2027, 7, 31), exchange: ym(2028, 3)),
    .init(id: "A3", input: pcar(ym(2024, 6), ym(2027, 6)),
          opens: day(2027, 5, 1), closes: day(2027, 10, 31), exchange: ym(2028, 6)),
    .init(id: "A4", input: pcar(ym(2021, 4), ym(2027, 4)),
          opens: day(2027, 3, 1), closes: day(2027, 8, 31), exchange: ym(2028, 4)),
    .init(id: "A5", input: pcar(ym(2023, 9), ym(2028, 9)),
          opens: day(2028, 5, 1), closes: day(2028, 9, 30), exchange: nil),
    .init(id: "A6", input: .init(category: .passengerCar, firstRegistration: ym(2028, 3)),
          today: day(2028, 4, 1),
          opens: day(2031, 11, 1), closes: day(2032, 3, 31), exchange: nil, estimatedDueMonth: ym(2032, 3)),
    .init(id: "A7 D-01", input: pcar(ym(2015, 7), ym(2027, 8)),
          opens: day(2027, 5, 19), closes: day(2027, 11, 30), exchange: nil),
    .init(id: "A8 D-11", input: .init(category: .motorcycle, firstRegistration: ym(2019, 5), plaque: ym(2027, 5)),
          opens: day(2027, 4, 1), closes: day(2027, 9, 30), exchange: ym(2028, 5)),
    .init(id: "A9", input: .init(category: .lightTrailer, firstRegistration: ym(2025, 10), plaque: ym(2028, 10)),
          opens: day(2028, 6, 1), closes: day(2028, 10, 31), exchange: ym(2029, 10)),
    .init(id: "A10 D-03", input: .init(category: .lightCommercial, firstRegistration: ym(2026, 2), plaque: ym(2027, 2)),
          opens: day(2026, 11, 1), closes: day(2027, 2, 28), exchange: nil),
    .init(id: "A11 D-02", input: .init(category: .historic, firstRegistration: ym(1976, 4), plaque: ym(2028, 4)),
          opens: day(2027, 12, 1), closes: day(2028, 4, 30), exchange: nil),
    .init(id: "A13", input: pcar(ym(2022, 1), ym(2027, 1)),
          opens: day(2026, 12, 1), closes: day(2027, 5, 18), exchange: nil),
    .init(id: "A14", input: pcar(ym(2010, 3), ym(2028, 3)),
          opens: day(2027, 11, 1), closes: day(2028, 3, 31), exchange: nil),
    .init(id: "A15 D-11", input: pcar(ym(2020, 6), ym(2027, 6)),
          opens: day(2027, 5, 1), closes: day(2027, 10, 31), exchange: ym(2028, 6)),
    .init(id: "X1 D-03", input: .init(category: .taxiOrAmbulance, firstRegistration: ym(2024, 3), plaque: ym(2027, 3)),
          opens: day(2026, 12, 1), closes: day(2027, 3, 31), exchange: nil),
    // X2: the OeAMTC calculator opens on 2027-05-19. The law (-3/0 of the previous law for due
    // month August 2027, D-03) allows 2027-05-01; we follow the law.
    .init(id: "X2 D-03", input: .init(category: .lightCommercial, firstRegistration: ym(2020, 8), plaque: ym(2027, 8)),
          opens: day(2027, 5, 1), closes: day(2027, 11, 30), exchange: nil),
    .init(id: "X3", input: .init(category: .historic, firstRegistration: ym(1980, 10), plaque: ym(2027, 10)),
          opens: day(2027, 6, 1), closes: day(2027, 11, 30), exchange: nil),
    .init(id: "X4 D-04", input: .init(category: .historic, firstRegistration: ym(1985, 3), plaque: ym(2027, 3)),
          opens: day(2027, 2, 1), closes: day(2027, 7, 31), exchange: nil),
    .init(id: "X5 AT-54a", input: pcar(ym(2018, 9), ym(2027, 9)),
          opens: day(2027, 5, 19), closes: day(2027, 11, 30), exchange: ym(2028, 9)),
    .init(id: "X5 AT-54a with last inspection", input: pcar(ym(2018, 9), ym(2027, 9), last: day(2026, 9, 15)),
          opens: day(2027, 5, 19), closes: day(2027, 11, 30), exchange: ym(2028, 9)),
    .init(id: "X6 AT-54a", input: pcar(ym(2017, 5), ym(2027, 5)),
          opens: day(2027, 4, 1), closes: day(2027, 9, 30), exchange: nil),
    // X7: the OeAMTC calculator reports no exchange plaque. The algorithm (D-11) derives the last
    // inspection 2025-12 (age 7 at the plaque) and suggests 2027-12; we follow the algorithm.
    .init(id: "X7 D-11", input: pcar(ym(2019, 12), ym(2026, 12)),
          opens: day(2026, 11, 1), closes: day(2027, 4, 30), exchange: ym(2027, 12)),
    .init(id: "X8 D-02", input: .init(category: .lightCommercial, firstRegistration: ym(2021, 11), plaque: ym(2027, 11)),
          opens: day(2027, 7, 1), closes: day(2027, 11, 30), exchange: nil),
    // X9: the OeAMTC calculator derives a last inspection; we need it entered (age 4 at the plaque
    // is not derivable under the previous law).
    .init(id: "X9 AT-53",
          input: .init(category: .motorcycle, firstRegistration: ym(2023, 6), plaque: ym(2027, 6),
                       lastInspection: day(2026, 6, 10)),
          opens: day(2027, 5, 1), closes: day(2027, 10, 31), exchange: ym(2028, 6)),
    .init(id: "X9 AT-53 without last inspection",
          input: .init(category: .motorcycle, firstRegistration: ym(2023, 6), plaque: ym(2027, 6)),
          opens: day(2027, 5, 1), closes: day(2027, 10, 31), exchange: nil),
    .init(id: "X10 D-06", input: pcar(ym(2024, 3), ym(2027, 3)),
          opens: day(2027, 2, 1), closes: day(2027, 7, 31), exchange: ym(2028, 3)),
    .init(id: "X11", input: pcar(ym(2024, 1), ym(2027, 1)),
          opens: day(2026, 12, 1), closes: day(2027, 5, 18), exchange: nil),
    .init(id: "X12", input: pcar(ym(2021, 4), ym(2028, 4), last: day(2027, 4, 15)),
          opens: day(2027, 12, 1), closes: day(2028, 4, 30), exchange: ym(2029, 4)),
    .init(id: "X13 D-01", input: pcar(ym(2016, 4), ym(2027, 9)),
          opens: day(2027, 5, 19), closes: day(2027, 11, 30), exchange: nil),
]

@Test(arguments: oeamtcCases)
func oeamtcComparison(_ c: OeamtcCase) throws {
    let status = try austria.status(for: c.input, today: c.today)
    #expect(status.window == InspectionWindow(opens: c.opens, closes: c.closes), "\(c.id) window")
    #expect(status.exchangePlaqueSuggestion == c.exchange, "\(c.id) exchange plaque")
    if let estimated = c.estimatedDueMonth {
        #expect(status.dueMonth == estimated, "\(c.id) estimated due month")
        #expect(status.dueMonthSource == .estimatedFromFirstRegistration)
    }
}
