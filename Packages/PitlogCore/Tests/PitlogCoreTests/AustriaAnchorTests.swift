import Testing
@testable import PitlogCore

// The 15 anchor cases of docs/rules/AT-57a-KFG.md section 9.6, one test per anchor.

@Test func anchor01_passengerCarTransitionWindow() throws { // AT-56, AT-40
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2020, 3), plaque: ym(2027, 3))
    let status = try austria.status(for: input, today: day(2027, 2, 15))
    #expect(status.window == InspectionWindow(opens: day(2027, 2, 1), closes: day(2027, 7, 31)))
    #expect(status.regime == .transition)
    #expect(status.phase == .open)
    #expect(status.notes == [note("AT-56")])
    #expect(status.dueMonthSource == .plaque)
}

@Test func anchor02_nextDueAcrossTheCutoff() throws { // AT-20, AT-30, AT-54
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2020, 3), plaque: ym(2027, 3))
    let before = try austria.nextDue(after: day(2027, 3, 10), dueMonth: ym(2027, 3), input: input)
    #expect(before.dueMonth == ym(2028, 3))
    #expect(before.notes.isEmpty)
    let after = try austria.nextDue(after: day(2027, 6, 10), dueMonth: ym(2027, 3), input: input)
    #expect(after.dueMonth == ym(2028, 3))
    #expect(after.notes == [note("AT-54")])
}

@Test func anchor03_neverInspectedExchangeSuggestion() throws { // AT-53, AT-56
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2024, 6), plaque: ym(2027, 6))
    let status = try austria.status(for: input, today: day(2027, 4, 1))
    #expect(status.window == InspectionWindow(opens: day(2027, 5, 1), closes: day(2027, 10, 31)))
    #expect(status.phase == .notYetOpen)
    #expect(status.exchangePlaqueSuggestion == ym(2028, 6))
    #expect(status.notes == [note("AT-53"), note("AT-56")])
}

@Test func anchor04_oeamtcExample() throws { // AT-53, AT-20, AT-30
    let input = InspectionInput(
        category: .passengerCar, firstRegistration: ym(2021, 4),
        plaque: ym(2027, 4), lastInspection: day(2026, 4, 12))
    let status = try austria.status(for: input, today: day(2027, 1, 1))
    #expect(status.exchangePlaqueSuggestion == ym(2028, 4))
    let previous = try austria.nextDue(after: day(2027, 4, 5), dueMonth: ym(2027, 4), input: input)
    #expect(previous.dueMonth == ym(2028, 4))
    let amended = try austria.nextDue(after: day(2027, 6, 1), dueMonth: ym(2027, 4), input: input)
    #expect(amended.dueMonth == ym(2029, 4))
}

@Test func anchor05_amendedLawNoSuggestion() throws { // AT-41, AT-53
    let input = InspectionInput(
        category: .passengerCar, firstRegistration: ym(2023, 9),
        plaque: ym(2028, 9), lastInspection: day(2026, 9, 20))
    let status = try austria.status(for: input, today: day(2028, 6, 1))
    #expect(status.window == InspectionWindow(opens: day(2028, 5, 1), closes: day(2028, 9, 30)))
    #expect(status.regime == .amendedLaw)
    #expect(status.phase == .open)
    #expect(status.exchangePlaqueSuggestion == nil)
}

@Test func anchor06_estimateWithoutPlaque() throws { // AT-10, AT-30
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2028, 3))
    let status = try austria.status(for: input, today: day(2028, 4, 1))
    #expect(status.dueMonth == ym(2032, 3))
    #expect(status.dueMonthSource == .estimatedFromFirstRegistration)
    #expect(status.notes == [note("AT-10", .checkPlaque)])
}

@Test func anchor07_overdueInTransition() throws { // AT-56
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2015, 7), plaque: ym(2027, 8))
    let status = try austria.status(for: input, today: day(2027, 9, 1))
    #expect(status.window.closes == day(2027, 8, 31))
    #expect(status.phase == .overdue)
    #expect(status.notes == [note("AT-56", .possibleExtension(until: day(2027, 11, 30)))])
}

@Test func anchor08_motorcycle() throws { // AT-21, AT-30, AT-56
    let input = InspectionInput(category: .motorcycle, firstRegistration: ym(2019, 5), plaque: ym(2027, 5))
    let status = try austria.status(for: input, today: day(2027, 5, 1))
    #expect(status.window.closes == day(2027, 9, 30))
    let previous = try austria.nextDue(after: day(2027, 5, 10), dueMonth: ym(2027, 5), input: input)
    #expect(previous.dueMonth == ym(2028, 5))
    let amended = try austria.nextDue(after: day(2027, 5, 25), dueMonth: ym(2027, 5), input: input)
    #expect(amended.dueMonth == ym(2029, 5))
}

@Test func anchor09_lightTrailerWindowAndSuggestion() throws { // AT-22, AT-41, AT-53
    let input = InspectionInput(category: .lightTrailer, firstRegistration: ym(2025, 10), plaque: ym(2028, 10))
    let status = try austria.status(for: input, today: day(2028, 1, 1))
    #expect(status.window == InspectionWindow(opens: day(2028, 6, 1), closes: day(2028, 10, 31)))
    #expect(status.exchangePlaqueSuggestion == ym(2029, 10))
}

@Test func anchor10_lightCommercial() throws { // AT-23, AT-42
    let input = InspectionInput(category: .lightCommercial, firstRegistration: ym(2026, 2), plaque: ym(2027, 2))
    let status = try austria.status(for: input, today: day(2027, 1, 15))
    #expect(status.window == InspectionWindow(opens: day(2027, 1, 1), closes: day(2027, 2, 28)))
    #expect(ruleIDs(status.notes).contains("AT-42"))
    let next = try austria.nextDue(after: day(2027, 2, 10), dueMonth: ym(2027, 2), input: input)
    #expect(next.dueMonth == ym(2028, 2))
}

@Test func anchor11_historic() throws { // AT-25, AT-43
    let input = InspectionInput(category: .historic, firstRegistration: ym(1976, 4), plaque: ym(2028, 4))
    let status = try austria.status(for: input, today: day(2028, 1, 1))
    #expect(status.window.closes == day(2028, 4, 30))
    #expect(ruleIDs(status.notes).contains("AT-43"))
    let next = try austria.nextDue(after: day(2028, 4, 10), dueMonth: ym(2028, 4), input: input)
    #expect(next.dueMonth == ym(2030, 4))
}

@Test func anchor12_unsupportedCategory() { // AT-26
    let input = InspectionInput(category: .other, firstRegistration: ym(2020, 1), plaque: ym(2027, 1))
    #expect(throws: InspectionRuleError.unsupportedCategory(.other)) {
        try austria.status(for: input, today: day(2027, 1, 1))
    }
}

@Test func anchor13_januaryTransitionCap() throws { // AT-56
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2022, 1), plaque: ym(2027, 1))
    let status = try austria.status(for: input, today: day(2027, 1, 10))
    #expect(status.window.closes == day(2027, 5, 18))
    #expect(status.notes == [note("AT-56", .possibleExtension(until: day(2027, 5, 31)))])
}

@Test func anchor14_yearlyAfterTenYears() throws { // AT-30
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2010, 3), plaque: ym(2028, 3))
    let next = try austria.nextDue(after: day(2028, 3, 15), dueMonth: ym(2028, 3), input: input)
    #expect(next.dueMonth == ym(2029, 3))
}

@Test func anchor15_outsideTheWindow() throws { // AT-12
    // Due month 2027-06 closes on 2027-10-31, so 2027-12-01 is outside. Age in 2027-12 is 7, the
    // amended sequence continues with 8, so the plaque is punched for 2028-12.
    let input = InspectionInput(category: .passengerCar, firstRegistration: ym(2020, 6), plaque: ym(2027, 6))
    let next = try austria.nextDue(after: day(2027, 12, 1), dueMonth: ym(2027, 6), input: input)
    #expect(next.dueMonth == ym(2028, 12))
    #expect(next.notes == [note("AT-12", .outsideWindowRepunch)])
}
