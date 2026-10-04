@testable import PitlogCore

/// Test helpers that build validated values from literals.
func ym(_ year: Int, _ month: Int) -> YearMonth {
    guard let value = YearMonth(year: year, month: month) else {
        preconditionFailure("Invalid test month \(year)-\(month)")
    }
    return value
}

func day(_ year: Int, _ month: Int, _ day: Int) -> DayDate {
    guard let value = DayDate(year: year, month: month, day: day) else {
        preconditionFailure("Invalid test day \(year)-\(month)-\(day)")
    }
    return value
}

func note(_ ruleID: String, _ kind: RuleNoteKind = .openLegalQuestion) -> RuleNote {
    RuleNote(ruleID: ruleID, kind: kind)
}

func ruleIDs(_ notes: [RuleNote]) -> [String] {
    notes.map(\.ruleID)
}

let austria = AustriaInspectionRules()
