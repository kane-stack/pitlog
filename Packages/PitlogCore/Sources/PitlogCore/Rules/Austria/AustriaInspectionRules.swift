/// Austrian inspection rules (§ 57a KFG, 42. KFG-Novelle). The algorithm is documented in
/// `docs/rules/AT-57a-KFG.md`, section 9. Every rule ID below refers to that document.
///
/// All results are interpretations pending verification against primary sources (ADR-8).
public struct AustriaInspectionRules: InspectionRuleSet {
    /// Day on which the amended § 57a Abs. 3 and § 132 Abs. 37 enter into force (AT-02).
    public static let cutoffDay = DayDate(uncheckedYear: 2027, month: 5, day: 19)

    /// Version of the interpretation, shown next to every deadline.
    public static let ruleVersion = "AT-2026-10-draft"

    /// AT-56: conservative cap for a due month of January 2027 (day before the cutoff).
    static let januaryTransitionCap = DayDate(uncheckedYear: 2027, month: 5, day: 18)
    /// AT-56: a source says the January 2027 window might run until the end of May 2027.
    static let januaryPossibleExtension = DayDate(uncheckedYear: 2027, month: 5, day: 31)
    /// AT-56: a source says due months August to October 2027 might be extended to this day.
    static let transitionPossibleExtension = DayDate(uncheckedYear: 2027, month: 11, day: 30)

    /// Last due month for which the previous law's window applies unchanged (AT-40, AT-56).
    static let lastPreviousLawDueMonth = YearMonth(uncheckedYear: 2026, month: 12)
    static let januaryTransitionDueMonth = YearMonth(uncheckedYear: 2027, month: 1)
    static let lastDeferredWindowDueMonth = YearMonth(uncheckedYear: 2027, month: 7)
    static let lastExtendedDueMonth = YearMonth(uncheckedYear: 2027, month: 10)
    /// Registrations up to and including this month count as previous law (AT-02, conservative).
    static let lastPreviousLawRegistrationMonth = YearMonth(uncheckedYear: 2027, month: 5)

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
        var notes = categoryNotes(for: input.category)

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
        notes += resolved.notes

        var suggestion: YearMonth?
        if source == .plaque, let plaque = input.plaque,
           let candidate = exchangePlaqueCandidate(for: input), candidate > plaque {
            suggestion = candidate
            notes.append(RuleNote(ruleID: "AT-53", kind: .openLegalQuestion))
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

        var notes = categoryNotes(for: input.category)
        let window = resolveWindow(for: dueMonth, category: input.category).window
        let law = Self.law(on: inspection)

        if inspection >= window.opens && inspection <= window.closes {
            // AT-20 ... AT-30: age-based, never later than "2 years after the last inspection".
            let ageAtDue = Self.age(at: dueMonth, firstRegistration: input.firstRegistration)
            let step = Self.yearsUntilNextInspection(
                afterAge: ageAtDue, category: input.category, law: law)
            if law == .amended, Self.isReformCategory(input.category), ageAtDue < 10, step == 1 {
                notes.append(RuleNote(ruleID: "AT-54", kind: .openLegalQuestion))
            }
            return NextInspectionDue(
                dueMonth: dueMonth.adding(years: step),
                notes: RuleNote.normalized(notes))
        }

        // AT-12: inspection outside the window, the plaque is punched anew from that month.
        let inspectionMonth = inspection.yearMonth
        guard inspectionMonth >= input.firstRegistration else {
            throw .invalidInput("Inspection \(inspection) is before the first registration \(input.firstRegistration)")
        }
        let ageAtInspection = Self.age(at: inspectionMonth, firstRegistration: input.firstRegistration)
        let step = Self.yearsUntilNextInspection(
            afterAge: ageAtInspection, category: input.category, law: law)
        notes.append(RuleNote(ruleID: "AT-12", kind: .outsideWindowRepunch))
        return NextInspectionDue(
            dueMonth: inspectionMonth.adding(years: step),
            notes: RuleNote.normalized(notes))
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

    /// The smallest age in the category's interval sequence that is greater than `age`.
    ///
    /// Sequences (AT-20 ... AT-30): previous law 3, 5, 6, 7, ...; amended law 4, 6, 8, 10, 11, ...;
    /// N1 and taxi 1, 2, 3, ...; historic 2, 4, 6, ...
    static func nextSequenceAge(afterAge age: Int, category: VehicleCategory, law: Law) -> Int {
        switch category {
        case .passengerCar, .motorcycle, .lightTrailer:
            let fixed: [Int] = law == .previous ? [3, 5, 6] : [4, 6, 8, 10]
            return fixed.first(where: { $0 > age }) ?? age + 1
        case .lightCommercial, .taxiOrAmbulance, .other:
            return max(1, age + 1)
        case .historic:
            return (floorDivide(age, 2) + 1) * 2
        }
    }

    static func yearsUntilNextInspection(afterAge age: Int, category: VehicleCategory, law: Law) -> Int {
        nextSequenceAge(afterAge: age, category: category, law: law) - age
    }

    // MARK: - Window

    struct ResolvedWindow: Sendable {
        var window: InspectionWindow
        var regime: LegalRegime
        var notes: [RuleNote]
    }

    /// Window for due month `dueMonth`, see section 9.3 of the rules document.
    func resolveWindow(for dueMonth: YearMonth, category: VehicleCategory) -> ResolvedWindow {
        if Self.isReformCategory(category) {
            return resolveReformWindow(for: dueMonth)
        }
        // AT-42/AT-43: window from the start of the previous month to the end of the due month.
        let window = InspectionWindow(opens: dueMonth.previous.firstDay, closes: dueMonth.lastDay)
        let ruleID = dueMonth <= Self.lastPreviousLawRegistrationMonth ? "AT-42" : "AT-43"
        return ResolvedWindow(
            window: window,
            regime: Self.law(on: dueMonth.firstDay) == .previous ? .previousLaw : .amendedLaw,
            notes: [RuleNote(ruleID: ruleID, kind: .openLegalQuestion)])
    }

    private func resolveReformWindow(for dueMonth: YearMonth) -> ResolvedWindow {
        let closes: DayDate
        let regime: LegalRegime
        var notes: [RuleNote] = []

        if dueMonth <= Self.lastPreviousLawDueMonth {
            // AT-40: -1/+4.
            closes = dueMonth.adding(months: 4).lastDay
            regime = .previousLaw
        } else if dueMonth == Self.januaryTransitionDueMonth {
            // AT-56: only one source includes January; cap at the day before the cutoff.
            closes = Self.januaryTransitionCap
            regime = .transition
            notes.append(RuleNote(
                ruleID: "AT-56", kind: .possibleExtension(until: Self.januaryPossibleExtension)))
        } else if dueMonth <= Self.lastDeferredWindowDueMonth {
            // AT-56 (a)/(b): -1/+4 still applies.
            closes = dueMonth.adding(months: 4).lastDay
            regime = .transition
            notes.append(RuleNote(ruleID: "AT-56", kind: .openLegalQuestion))
        } else if dueMonth <= Self.lastExtendedDueMonth {
            // AT-56 (c): conservatively the end of the due month.
            closes = dueMonth.lastDay
            regime = .transition
            notes.append(RuleNote(
                ruleID: "AT-56", kind: .possibleExtension(until: Self.transitionPossibleExtension)))
        } else {
            // AT-41: -4/0.
            closes = dueMonth.lastDay
            regime = .amendedLaw
        }

        // Earliest day that lies inside the window under the law in force on that day.
        var opens: DayDate?
        let oldCandidate = dueMonth.previous.firstDay
        if oldCandidate < Self.cutoffDay {
            opens = oldCandidate
        }
        let newCandidate = max(dueMonth.adding(months: -4).firstDay, Self.cutoffDay)
        if newCandidate <= closes {
            opens = min(opens ?? newCandidate, newCandidate)
        }

        return ResolvedWindow(
            window: InspectionWindow(opens: opens ?? oldCandidate, closes: closes),
            regime: regime,
            notes: notes)
    }

    static func phase(of window: InspectionWindow, today: DayDate) -> InspectionPhase {
        if today < window.opens { return .notYetOpen }
        if today > window.closes { return .overdue }
        if window.closes.yearMonth == today.yearMonth { return .closesThisMonth }
        return .open
    }

    // MARK: - Estimation and exchange plaque

    /// AT-10: due month estimated from the first registration, advanced until its window has not
    /// closed before `today`. Hints produced by intermediate steps are discarded.
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

    /// AT-52/53/54: suggested due month on an exchange plaque, or `nil` if there is no candidate.
    private func exchangePlaqueCandidate(for input: InspectionInput) -> YearMonth? {
        guard Self.isReformCategory(input.category) else { return nil }
        if let last = input.lastInspection {
            let ageAtLast = Self.age(at: last.yearMonth, firstRegistration: input.firstRegistration)
            return ageAtLast <= 8 ? last.yearMonth.adding(years: 2) : nil
        }
        if input.firstRegistration.adding(years: 3) >= Self.lastPreviousLawRegistrationMonth {
            return input.firstRegistration.adding(years: 4)
        }
        return nil
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

    /// AT-23/24/25: intervals of these categories are only secondarily sourced.
    private func categoryNotes(for category: VehicleCategory) -> [RuleNote] {
        switch category {
        case .lightCommercial: [RuleNote(ruleID: "AT-23", kind: .openLegalQuestion)]
        case .taxiOrAmbulance: [RuleNote(ruleID: "AT-24", kind: .openLegalQuestion)]
        case .historic: [RuleNote(ruleID: "AT-25", kind: .openLegalQuestion)]
        case .passengerCar, .motorcycle, .lightTrailer, .other: []
        }
    }
}
