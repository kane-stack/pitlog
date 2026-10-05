import Foundation
import Testing
@testable import PitlogCore

private let extractor = HeuristicReceiptExtractor()

@Test func fixturesAreLoaded() {
    // 15 receipts, 3 variants each
    #expect(ReceiptFixtures.all.count == 45)
    #expect(Set(ReceiptFixtures.all.map(\.id)).count == 15)
}

@Test func fixtureUIDsAreNeverRealOnes() {
    // Fictitious receipts must not carry valid UIDs (README §8).
    for fixture in ReceiptFixtures.all {
        if let uid = fixture.expected.workshopUID {
            #expect(!AustrianUID.isChecksumValid(uid), "\(fixture.testDescription): \(uid)")
        }
    }
}

/// Clean receipts must be extracted completely and correctly; noisy and shuffled ones must at
/// least never produce a wrong value.
@Test(arguments: ReceiptFixtures.all)
func fixtureIsExtracted(_ fixture: ReceiptFixture) async {
    let draft = await extractor.extract(lines: fixture.lines, context: fixture.context)
    let results = ReceiptComparison.compare(draft, to: fixture.expected)
    let wrong = results.filter { $0.outcome == .wrong }
    for r in wrong {
        Issue.record("wrong \(r.field): expected \(r.expected ?? "nil"), got \(r.actual ?? "nil") [\(fixture.testDescription)]")
    }
    if fixture.variant == "clean" {
        for r in results where r.outcome == .missing {
            Issue.record("missing \(r.field): expected \(r.expected ?? "nil") [\(fixture.testDescription)]")
        }
        let missing = ReceiptComparison.missingWorkItems(draft, fixture.expected)
        #expect(missing.isEmpty, "missing work items \(missing) [\(fixture.testDescription)] in \(draft.workItems)")
    }
}

/// Accuracy over the whole fixture set, printed as a table for `docs/receipt-parser.md`.
/// The wrong-value rate is the important metric; its target is 0 %.
@Test func accuracyReport() async {
    var counts: [String: [FieldOutcome: Int]] = [:]
    var perVariant: [String: [FieldOutcome: Int]] = [:]
    var workItemsTotal = 0
    var workItemsFound = 0
    var mismatches: [String] = []
    for fixture in ReceiptFixtures.all {
        let draft = await extractor.extract(lines: fixture.lines, context: fixture.context)
        for r in ReceiptComparison.compare(draft, to: fixture.expected) {
            counts[r.field, default: [:]][r.outcome, default: 0] += 1
            perVariant[fixture.variant, default: [:]][r.outcome, default: 0] += 1
            if r.outcome != .correct {
                mismatches.append(
                    "\(r.outcome.rawValue) \(r.field) [\(fixture.testDescription)]: expected \(r.expected ?? "nil"), got \(r.actual ?? "nil")")
            }
        }
        let expectedItems = fixture.expected.workItems ?? []
        workItemsTotal += expectedItems.count
        workItemsFound += expectedItems.count - ReceiptComparison.missingWorkItems(draft, fixture.expected).count
    }
    func pad(_ s: String, _ n: Int) -> String { s + String(repeating: " ", count: max(0, n - s.count)) }
    func pct(_ part: Int, _ whole: Int) -> String {
        whole == 0 ? "-" : String(format: "%.1f %%", Double(part) * 100 / Double(whole))
    }
    var lines = ["", "RECEIPT PARSER ACCURACY (\(ReceiptFixtures.all.count) fixtures)"]
    lines.append(pad("field", 24) + pad("n", 5) + pad("correct", 10) + pad("missing", 10) + pad("wrong", 8))
    var totalCorrect = 0, totalMissing = 0, totalWrong = 0
    for name in ReceiptComparison.fieldNames {
        let c = counts[name]?[.correct] ?? 0
        let m = counts[name]?[.missing] ?? 0
        let w = counts[name]?[.wrong] ?? 0
        totalCorrect += c; totalMissing += m; totalWrong += w
        lines.append(pad(name, 24) + pad("\(c + m + w)", 5) + pad(pct(c, c + m + w), 10) + pad(pct(m, c + m + w), 10) + pad(pct(w, c + m + w), 8))
    }
    let n = totalCorrect + totalMissing + totalWrong
    lines.append(pad("ALL FIELDS", 24) + pad("\(n)", 5) + pad(pct(totalCorrect, n), 10) + pad(pct(totalMissing, n), 10) + pad(pct(totalWrong, n), 8))
    lines.append("workItems (expected entries found): \(workItemsFound)/\(workItemsTotal)")
    for variant in ReceiptFixtures.variants {
        let c = perVariant[variant]?[.correct] ?? 0
        let m = perVariant[variant]?[.missing] ?? 0
        let w = perVariant[variant]?[.wrong] ?? 0
        lines.append(pad("variant \(variant)", 24) + pad("\(c + m + w)", 5) + pad(pct(c, c + m + w), 10) + pad(pct(m, c + m + w), 10) + pad(pct(w, c + m + w), 8))
    }
    lines.append(contentsOf: mismatches.map { "  " + $0 })
    print(holdoutReportText().0)
    print(lines.joined(separator: "\n"))
    #expect(totalWrong == 0, "wrong values must be 0 %")
}
