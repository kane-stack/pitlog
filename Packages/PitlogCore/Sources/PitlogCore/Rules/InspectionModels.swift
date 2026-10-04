/// What the user knows about a vehicle. The plaque is authoritative (ADR-5).
public struct InspectionInput: Hashable, Codable, Sendable {
    public var category: VehicleCategory
    public var firstRegistration: YearMonth
    /// The punched due month and year on the inspection plaque.
    public var plaque: YearMonth?
    public var lastInspection: DayDate?

    public init(
        category: VehicleCategory,
        firstRegistration: YearMonth,
        plaque: YearMonth? = nil,
        lastInspection: DayDate? = nil
    ) {
        self.category = category
        self.firstRegistration = firstRegistration
        self.plaque = plaque
        self.lastInspection = lastInspection
    }
}

/// Days on which an inspection counts for the due month, both inclusive.
public struct InspectionWindow: Hashable, Codable, Sendable {
    public var opens: DayDate
    public var closes: DayDate

    public init(opens: DayDate, closes: DayDate) {
        self.opens = opens
        self.closes = closes
    }
}

public enum InspectionPhase: String, Hashable, Codable, Sendable {
    case notYetOpen
    case open
    case closesThisMonth
    case overdue
}

public enum LegalRegime: String, Hashable, Codable, Sendable {
    case previousLaw
    /// 42. KFG-Novelle.
    case amendedLaw
    case transition
}

public enum DueMonthSource: String, Hashable, Codable, Sendable {
    case plaque
    case estimatedFromFirstRegistration
}

public enum RuleNoteKind: Hashable, Codable, Sendable {
    case openLegalQuestion
    case possibleExtension(until: DayDate)
    case checkPlaque
    case outsideWindowRepunch

    var sortOrder: Int {
        switch self {
        case .openLegalQuestion: 0
        case .possibleExtension: 1
        case .checkPlaque: 2
        case .outsideWindowRepunch: 3
        }
    }
}

/// A hint the UI must show next to a result, tied to a rule in `docs/rules/AT-57a-KFG.md`.
public struct RuleNote: Hashable, Codable, Sendable {
    public var ruleID: String
    public var kind: RuleNoteKind

    public init(ruleID: String, kind: RuleNoteKind) {
        self.ruleID = ruleID
        self.kind = kind
    }

    /// Removes duplicates and sorts by rule ID (then kind) so results are stable.
    static func normalized(_ notes: [RuleNote]) -> [RuleNote] {
        var unique: [RuleNote] = []
        for note in notes where !unique.contains(note) {
            unique.append(note)
        }
        return unique.sorted { lhs, rhs in
            if lhs.ruleID != rhs.ruleID { return lhs.ruleID < rhs.ruleID }
            return lhs.kind.sortOrder < rhs.kind.sortOrder
        }
    }
}

public struct InspectionStatus: Hashable, Codable, Sendable {
    public var dueMonth: YearMonth
    public var dueMonthSource: DueMonthSource
    public var window: InspectionWindow
    public var phase: InspectionPhase
    public var regime: LegalRegime
    public var notes: [RuleNote]
    /// Non-binding hint about an optional exchange plaque with a later due month.
    public var exchangePlaqueSuggestion: YearMonth?
    public var ruleVersion: String

    public init(
        dueMonth: YearMonth,
        dueMonthSource: DueMonthSource,
        window: InspectionWindow,
        phase: InspectionPhase,
        regime: LegalRegime,
        notes: [RuleNote],
        exchangePlaqueSuggestion: YearMonth?,
        ruleVersion: String
    ) {
        self.dueMonth = dueMonth
        self.dueMonthSource = dueMonthSource
        self.window = window
        self.phase = phase
        self.regime = regime
        self.notes = notes
        self.exchangePlaqueSuggestion = exchangePlaqueSuggestion
        self.ruleVersion = ruleVersion
    }
}

/// Result of `InspectionRuleSet.nextDue`.
public struct NextInspectionDue: Hashable, Codable, Sendable {
    public var dueMonth: YearMonth
    public var notes: [RuleNote]

    public init(dueMonth: YearMonth, notes: [RuleNote]) {
        self.dueMonth = dueMonth
        self.notes = notes
    }
}

public enum InspectionRuleError: Error, Hashable, Sendable {
    case unsupportedCategory(VehicleCategory)
    case invalidInput(String)
}
