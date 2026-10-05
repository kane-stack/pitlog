import Foundation
import Testing
@testable import PitlogCore

/// Holdout set written independently of the parser (`Fixtures/ReceiptsHoldout`). This test only
/// reports; it fails on crashes and unreadable files, never on accuracy.
private struct HoldoutExpected: Codable {
    var grossTotalMinor: Int64?
    var currency: String?
    var serviceDate: String?
    var invoiceDate: String?
    var historyDate: String?
    var workshopName: String?
    var workshopUID: String?
    var odometerKm: Int?
    var plate: String?
    var vin: String?
    var category: String?
}

private struct HoldoutReceipt {
    let name: String
    let lines: [ReceiptLine]
    let expected: HoldoutExpected
}

private func loadHoldout() -> [HoldoutReceipt] {
    let base = Bundle.module.resourceURL ?? Bundle.module.bundleURL
    let dir = base.appendingPathComponent("Fixtures/ReceiptsHoldout")
    let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
        .filter { $0.hasSuffix(".txt") }.sorted()
    var out: [HoldoutReceipt] = []
    for file in names {
        let stem = String(file.dropLast(4))
        guard let text = try? String(contentsOf: dir.appendingPathComponent(file), encoding: .utf8),
            let data = try? Data(contentsOf: dir.appendingPathComponent("\(stem).expected.json")),
            let expected = try? JSONDecoder().decode(HoldoutExpected.self, from: data)
        else { continue }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map { ReceiptLine(String($0)) }
        out.append(HoldoutReceipt(name: stem, lines: lines, expected: expected))
    }
    return out
}

@Test func holdoutReport() {
    let receipts = loadHoldout()
    #expect(receipts.count == 25, "holdout files unreadable or missing")
    let context = ReceiptContext(today: day(2026, 10, 5))
    let extractor = HeuristicReceiptExtractor()
    let fields = [
        "grossTotalMinor", "currency", "serviceDate", "invoiceDate", "historyDate", "workshopName", "workshopUID",
        "odometerKm", "plate", "vin", "category",
    ]
    var counts: [String: [FieldOutcome: Int]] = [:]
    var details: [String] = []

    func compactPlate(_ s: String?) -> String? {
        s.map { String($0.uppercased().filter { $0.isLetter || $0.isNumber }) }
    }

    for receipt in receipts {
        let d = extractor.draft(lines: receipt.lines, context: context)
        let e = receipt.expected
        let pairs: [(String, String?, String?)] = [
            ("grossTotalMinor", e.grossTotalMinor.map { String($0) }, d.grossTotal.map { String($0.amountMinor) }),
            ("currency", e.currency, d.grossTotal?.currencyCode),
            ("serviceDate", e.serviceDate, d.serviceDate.map(\.description)),
            ("invoiceDate", e.invoiceDate, d.invoiceDate.map(\.description)),
            ("historyDate", e.historyDate, d.historyDate.map(\.description)),
            ("workshopName", e.workshopName?.lowercased(), d.workshopName?.lowercased()),
            ("workshopUID", e.workshopUID, d.workshopUID),
            ("odometerKm", e.odometerKm.map { String($0) }, d.odometerKm.map { String($0) }),
            ("plate", compactPlate(e.plate), compactPlate(d.plate)),
            ("vin", e.vin, d.vin),
            ("category", e.category, d.suggestedCategory?.rawValue),
        ]
        for (field, expected, actual) in pairs {
            let outcome: FieldOutcome
            if expected == actual {
                outcome = .correct
            } else if actual == nil {
                outcome = .missing
            } else {
                outcome = .wrong
            }
            counts[field, default: [:]][outcome, default: 0] += 1
            if outcome != .correct {
                details.append("\(outcome.rawValue) \(field) [\(receipt.name)]: expected \(expected ?? "nil"), got \(actual ?? "nil")")
            }
        }
    }

    func pad(_ s: String, _ n: Int) -> String { s + String(repeating: " ", count: max(0, n - s.count)) }
    func pct(_ part: Int, _ whole: Int) -> String {
        whole == 0 ? "-" : String(format: "%.1f %%", Double(part) * 100 / Double(whole))
    }
    var lines = ["", "HOLDOUT ACCURACY (\(receipts.count) receipts)"]
    lines.append(pad("field", 18) + pad("n", 5) + pad("correct", 10) + pad("missing", 10) + pad("wrong", 8))
    var totals: [FieldOutcome: Int] = [:]
    for field in fields {
        let c = counts[field]?[.correct] ?? 0
        let m = counts[field]?[.missing] ?? 0
        let w = counts[field]?[.wrong] ?? 0
        totals[.correct, default: 0] += c
        totals[.missing, default: 0] += m
        totals[.wrong, default: 0] += w
        let n = c + m + w
        lines.append(pad(field, 18) + pad("\(n)", 5) + pad(pct(c, n), 10) + pad(pct(m, n), 10) + pad(pct(w, n), 8))
    }
    let n = (totals[.correct] ?? 0) + (totals[.missing] ?? 0) + (totals[.wrong] ?? 0)
    lines.append(
        pad("ALL FIELDS", 18) + pad("\(n)", 5) + pad(pct(totals[.correct] ?? 0, n), 10)
            + pad(pct(totals[.missing] ?? 0, n), 10) + pad(pct(totals[.wrong] ?? 0, n), 8))
    lines.append(contentsOf: details.map { "  " + $0 })
    print(lines.joined(separator: "\n"))
}
