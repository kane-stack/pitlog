/// Austrian inspection rules (§ 57a KFG, 42. KFG-Novelle). The algorithm is documented in
/// `docs/rules/AT-57a-KFG.md`, section 9. Every rule ID below refers to that document.
///
/// Rules follow the primary sources of 2026-10-04; open legal questions use the conservative
/// reading and are flagged with a `RuleNote` (ADR-8).
public struct AustriaInspectionRules: InspectionRuleSet {
    /// Day on which the amended § 57a Abs. 3 and § 132 Abs. 37 enter into force (AT-02).
    public static let cutoffDay = DayDate(uncheckedYear: 2027, month: 5, day: 19)

    /// Version of the interpretation, shown next to every deadline.
    public static let ruleVersion = "AT-2026-10-primary"

    /// AT-56: a due month of January 2027 ends the day before the cutoff (the previous law's
    /// grace period lapses with the law, § 132 Abs. 37 Z 3 does not cover January).
    static let januaryTransitionCap = DayDate(uncheckedYear: 2027, month: 5, day: 18)
    /// AT-56: due months August to October 2027 are extended to this day (§ 132 Abs. 37 Z 3 Satz 2).
    static let transitionExtensionEnd = DayDate(uncheckedYear: 2027, month: 11, day: 30)

    /// Last due month for which the previous law's window applies unchanged (AT-40, AT-56).
    static let lastPreviousLawDueMonth = YearMonth(uncheckedYear: 2026, month: 12)
    static let januaryTransitionDueMonth = YearMonth(uncheckedYear: 2027, month: 1)
    static let lastDeferredWindowDueMonth = YearMonth(uncheckedYear: 2027, month: 7)
    static let lastExtendedDueMonth = YearMonth(uncheckedYear: 2027, month: 10)
    /// Registrations up to and including this month count as previous law (AT-02, conservative).
    static let lastPreviousLawRegistrationMonth = YearMonth(uncheckedYear: 2027, month: 5)
    /// D-11: a last inspection derived from the plaque must lie before this month.
    static let derivedInspectionLimit = YearMonth(uncheckedYear: 2027, month: 5)
    /// D-06: the exchange plaque exists from 2027-05-19, so plaques from this month on qualify.
    static let firstExchangeDueMonth = YearMonth(uncheckedYear: 2027, month: 2)

    public init() {}

    public var country: CountryCode { .austria }
    public var ruleVersion: String { Self.ruleVersion }

    public var supportedCategories: Set<VehicleCategory> {
        [.passengerCar, .motorcycle, .lightTrailer, .lightCommercial, .taxiOrAmbulance, .historic]
    }

    // MARK: - Public API

    public func status(
        for input: InspectionInput,
        today: DayDate
    ) throws(InspectionRuleError) -> InspectionStatus {
        try validate(input)
        var notes: [RuleNote] = []

        let dueMonth: YearMonth
        let source: DueMonthSource
        if let plaque = input.plaque {
            dueMonth = plaque
            source = .plaque
        } else {
            dueMonth = try estimatedDueMonth(for: input, today: today)
            source = .estimatedFromFirstRegistration
            notes.append(RuleNote(ruleID: "AT-10", kind: .checkPlaque))
        }

        let resolved = resolveWindow(for: dueMonth, category: input.category)

        var suggestion: YearMonth?
        if source == .plaque, let plaque = input.plaque,
           let exchange = exchangePlaqueSuggestion(for: input, plaque: plaque) {
            suggestion = exchange.dueMonth
            notes.append(RuleNote(ruleID: "AT-53", kind: .openLegalQuestion))
            if exchange.derivedLastInspection {
                notes.append(RuleNote(ruleID: "AT-53", kind: .derivedLastInspection))
            }
        }

        return InspectionStatus(
            dueMonth: dueMonth,
            dueMonthSource: source,
            window: resolved.window,
            phase: Self.phase(of: resolved.window, today: today),
            regime: resolved.regime,
            notes: RuleNote.normalized(notes),
            exchangePlaqueSuggestion: suggestion,
            ruleVersion: Self.ruleVersion
        )
    }

    public func nextDue(
        after inspection: DayDate,
        dueMonth: YearMonth,
        input: InspectionInput
    ) throws(InspectionRuleError) -> NextInspectionDue {
        try requireSupported(input.category)
        guard dueMonth >= input.firstRegistration else {
            throw .invalidInput("Due month \(dueMonth) is before the first registration \(input.firstRegistration)")
        }

        var notes: [RuleNote] = []
        let window = resolveWindow(for: dueMonth, category: input.category).window
        let law = Self.law(on: inspection)

        if inspection >= window.opens && inspection <= window.closes {
            // AT-20 ... AT-30, D-05: age-based step from the due month.
            let ageAtDue = Self.age(at: dueMonth, firstRegistration: input.firstRegistration)
            let step = Self.yearsUntilNextInspection(
                afterAge: ageAtDue, category: input.category, law: law)
            notes += Self.openQuestionNotes(age: ageAtDue, category: input.category, law: law)
            return NextInspectionDue(
                dueMonth: dueMonth.adding(years: step),
                notes: RuleNote.normalized(notes))
        }

        // AT-12, D-09: the law does not regulate this case. The earliest plausible due month only
        // prefills the plaque picker; the user enters the punch from the new plaque.
        let inspectionMonth = inspection.yearMonth
        guard inspectionMonth >= input.firstRegistration else {
            throw .invalidInput("Inspection \(inspection) is before the first registration \(input.firstRegistration)")
        }
        notes.append(RuleNote(ruleID: "AT-12", kind: .outsideWindowRepunch))
        let earliest: YearMonth
        switch law {
        case .amended:
            earliest = dueMonth.adding(years: 1)
        case .previous:
            let ageAtInspection = Self.age(at: inspectionMonth, firstRegistration: input.firstRegistration)
            let ageAtDue = Self.age(at: dueMonth, firstRegistration: input.firstRegistration)
            let fromInspection = inspectionMonth.adding(
                years: Self.yearsUntilNextInspection(afterAge: ageAtInspection, category: input.category, law: .previous))
            let fromDue = dueMonth.adding(
                years: Self.yearsUntilNextInspection(afterAge: ageAtDue, category: input.category, law: .previous))
            earliest = min(fromInspection, fromDue)
        }
        return NextInspectionDue(dueMonth: earliest, notes: RuleNote.normalized(notes))
    }

    // MARK: - Law and age

    enum Law: Sendable {
        case previous
        case amended
    }

    static func law(on day: DayDate) -> Law {
        day < cutoffDay ? .previous : .amended
    }

    /// Completed years between the first registration and `month`.
    static func age(at month: YearMonth, firstRegistration: YearMonth) -> Int {
        floorDivide(month.months(from: firstRegistration), 12)
    }

    static func isReformCategory(_ category: VehicleCategory) -> Bool {
        switch category {
        case .passengerCar, .motorcycle, .lightTrailer: true
        case .lightCommercial, .taxiOrAmbulance, .historic, .other: false
        }
    }

    /// § 57a Abs. 3 Z 3 to 5 (-1/+4 under the previous law): cars, L, light trailers, historic.
    /// The other supported categories belong to Z 1 and Z 2 (-3/0 under the previous law).
    static func isZ35Group(_ category: VehicleCategory) -> Bool {
        switch category {
        case .passengerCar, .motorcycle, .lightTrailer, .historic: true
        case .lightCommercial, .taxiOrAmbulance, .other: false
        }
    }

    /// AT-54a: under the amended law the step from age 9 to 10 is one year for a reform vehicle,
    /// which reading A of "im zehnten Jahr" gives. Reported only at age 9 at the due month.
    static func openQuestionNotes(age: Int, category: VehicleCategory, law: Law) -> [RuleNote] {
        guard law == .amended, isReformCategory(category), age == 9 else { return [] }
        return [RuleNote(ruleID: "AT-54a", kind: .openLegalQuestion)]
    }

    /// Years from the due month to the next one, for a vehicle of `age` completed years at the
    /// due month (AT-20 ... AT-30, D-05).
    ///
    /// Reform classes: previous law 3, 5, 6, 7, ...; amended law 4 - age below 4, min(2, 10 - age)
    /// from 4 to 9, then 1. N1 and taxi: 1. Historic: a fixed two years (AT-25).
    static func yearsUntilNextInspection(afterAge age: Int, category: VehicleCategory, law: Law) -> Int {
        switch category {
        case .passengerCar, .motorcycle, .lightTrailer:
            switch law {
            case .previous:
                let nextAge = [3, 5, 6].first(where: { $0 > age }) ?? age + 1
                return nextAge - age
            case .amended:
                if age < 4 { return 4 - age }
                if age < 10 { return min(2, 10 - age) }
                return 1
            }
        case .lightCommercial, .taxiOrAmbulance, .other:
            return 1
        case .historic:
            return 2
        }
    }

    // MARK: - Window

    struct ResolvedWindow: Sendable {
        var window: InspectionWindow
        var regime: LegalRegime
    }

    /// Window for due month `dueMonth`, see section 9.3 of the rules document.
    func resolveWindow(for dueMonth: YearMonth, category: VehicleCategory) -> ResolvedWindow {
        let isZ35 = Self.isZ35Group(category)
        let closes: DayDate
        let regime: LegalRegime

        if dueMonth <= Self.lastPreviousLawDueMonth {
            // AT-40 (-1/+4) for Z 3 to 5, AT-42 (-3/0) for Z 1 and 2.
            closes = isZ35 ? dueMonth.adding(months: 4).lastDay : dueMonth.lastDay
            regime = .previousLaw
        } else if dueMonth == Self.januaryTransitionDueMonth {
            // AT-56: not covered by § 132 Abs. 37 Z 3, the previous grace period ends on 2027-05-18.
            closes = isZ35 ? Self.januaryTransitionCap : dueMonth.lastDay
            regime = .transition
        } else if dueMonth <= Self.lastDeferredWindowDueMonth {
            // AT-56 (Z 3 Satz 1): the previous law's window still applies.
            closes = isZ35 ? dueMonth.adding(months: 4).lastDay : dueMonth.lastDay
            regime = .transition
        } else if dueMonth <= Self.lastExtendedDueMonth {
            // AT-56 (Z 3 Satz 2): extended to the end of November 2027, all categories.
            closes = Self.transitionExtensionEnd
            regime = .transition
        } else {
            // AT-41: -4/0 for all vehicles.
            closes = dueMonth.lastDay
            regime = .amendedLaw
        }

        // Earliest valid candidate. The old candidate (previous law) counts only before the cutoff,
        // the new one (four months before, but not before the cutoff) only if it is not after `closes`.
        // D-03: for N1 and taxi due August 2027 the old candidate (D-3 = 2027-05-01) is valid, so the
        // window opens on 2027-05-01 although the OeAMTC calculator says 2027-05-19.
        var opens: DayDate?
        let oldCandidate = isZ35 ? dueMonth.previous.firstDay : dueMonth.adding(months: -3).firstDay
        if oldCandidate < Self.cutoffDay {
            opens = oldCandidate
        }
        let newCandidate = max(dueMonth.adding(months: -4).firstDay, Self.cutoffDay)
        if newCandidate <= closes {
            opens = min(opens ?? newCandidate, newCandidate)
        }

        return ResolvedWindow(
            window: InspectionWindow(opens: opens ?? oldCandidate, closes: closes),
            regime: regime)
    }

    static func phase(of window: InspectionWindow, today: DayDate) -> InspectionPhase {
        if today < window.opens { return .notYetOpen }
        if today > window.closes { return .overdue }
        if window.closes.yearMonth == today.yearMonth { return .closesThisMonth }
        return .open
    }

    // MARK: - Estimation and exchange plaque

    /// AT-10: due month estimated from the first registration, advanced until its window has not
    /// closed before `today`.
    private func estimatedDueMonth(
        for input: InspectionInput,
        today: DayDate
    ) throws(InspectionRuleError) -> YearMonth {
        let registrationLaw: Law =
            input.firstRegistration <= Self.lastPreviousLawRegistrationMonth ? .previous : .amended
        var dueMonth = input.firstRegistration.adding(
            years: Self.yearsUntilNextInspection(afterAge: 0, category: input.category, law: registrationLaw))

        // Each step moves the due month forward by at least one year, so this ends quickly.
        for _ in 0..<1_000 {
            let window = resolveWindow(for: dueMonth, category: input.category).window
            if window.closes >= today { return dueMonth }
            // May 2027 counts as previous law (conservative); other months use the law on their first day.
            let law = Self.law(on: dueMonth.firstDay)
            let ageAtDue = Self.age(at: dueMonth, firstRegistration: input.firstRegistration)
            dueMonth = dueMonth.adding(
                years: Self.yearsUntilNextInspection(afterAge: ageAtDue, category: input.category, law: law))
        }
        throw .invalidInput("Could not estimate a due month for first registration \(input.firstRegistration)")
    }

    struct ExchangePlaqueSuggestion: Sendable {
        var dueMonth: YearMonth
        /// The last inspection was derived from the plaque, not entered (D-11).
        var derivedLastInspection: Bool
    }

    /// AT-52/53, D-06, D-11: suggested due month on an exchange plaque, or `nil` if there is none.
    /// Only for reform classes; the suggestion is shown only if it is later than the plaque.
    private func exchangePlaqueSuggestion(
        for input: InspectionInput,
        plaque: YearMonth
    ) -> ExchangePlaqueSuggestion? {
        guard Self.isReformCategory(input.category) else { return nil }
        let firstRegistration = input.firstRegistration
        let firstInspectionMonth = firstRegistration.adding(years: 3)

        var lastInspection: YearMonth?
        var derived = false
        if let last = input.lastInspection {
            guard last < Self.cutoffDay else { return nil }
            lastInspection = last.yearMonth
        } else if plaque > firstInspectionMonth {
            // D-11: derive the last inspection from the previous law's sequence 3, 5, 6, 7, ...
            let ageAtPlaque = Self.age(at: plaque, firstRegistration: firstRegistration)
            let candidate: YearMonth
            switch ageAtPlaque {
            case 5: candidate = plaque.adding(years: -2)
            case 6...: candidate = plaque.adding(years: -1)
            default: return nil
            }
            guard candidate < Self.derivedInspectionLimit else { return nil }
            lastInspection = candidate
            derived = true
        }

        let dueMonth: YearMonth
        if let lastInspection {
            guard Self.age(at: lastInspection, firstRegistration: firstRegistration) <= 8 else { return nil }
            dueMonth = lastInspection.adding(years: 2)
        } else if plaque <= firstInspectionMonth, plaque >= Self.firstExchangeDueMonth {
            // D-06: never inspected, first inspection four years after the first registration.
            dueMonth = firstRegistration.adding(years: 4)
        } else {
            return nil
        }
        guard dueMonth > plaque else { return nil }
        return ExchangePlaqueSuggestion(dueMonth: dueMonth, derivedLastInspection: derived)
    }

    // MARK: - Validation and notes

    private func requireSupported(_ category: VehicleCategory) throws(InspectionRuleError) {
        guard supportedCategories.contains(category) else {
            throw .unsupportedCategory(category)
        }
    }

    private func validate(_ input: InspectionInput) throws(InspectionRuleError) {
        try requireSupported(input.category)
        if let plaque = input.plaque, plaque < input.firstRegistration {
            throw .invalidInput("Plaque \(plaque) is before the first registration \(input.firstRegistration)")
        }
        if let last = input.lastInspection, last.yearMonth < input.firstRegistration {
            throw .invalidInput("Last inspection \(last) is before the first registration \(input.firstRegistration)")
        }
    }
}
