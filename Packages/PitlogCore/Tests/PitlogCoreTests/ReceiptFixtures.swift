import Foundation
import Testing
@testable import PitlogCore

/// Expected values of one synthetic receipt (`Fixtures/Receipts/expected.json`). Fields that are
/// absent must stay `nil` in the draft.
struct ExpectedReceipt: Codable, Sendable {
    var gross: Int64?
    var net: Int64?
    var vat: Int64?
    var vatRate: Int?
    var serviceDate: String?
    var invoiceDate: String?
    var workshopName: String?
    var workshopUID: String?
    var odometerKm: Int?
    var plate: String?
    var vin: String?
    var category: String?
    var plaque: String?
    var isSmall: Bool?
    var isExempt: Bool?
    var isCreditNote: Bool?
    /// Each entry must occur in one of the extracted positions.
    var workItems: [String]?
}

private struct ContextJSON: Codable {
    var today: String
    var firstRegistration: String?
    var lastKnownOdometerKm: Int?
    var knownPlates: [String]
    var knownVINs: [String]
}

private struct EntryJSON: Codable {
    var context: ContextJSON
    var expected: ExpectedReceipt
}

struct ReceiptFixture: Sendable, CustomTestStringConvertible {
    let id: String
    /// "clean", "noisy" (OCR confusions) or "shuffled" (line order).
    let variant: String
    let lines: [RecognizedLine]
    let context: ReceiptContext
    let expected: ExpectedReceipt

    var testDescription: String { "\(id) (\(variant))" }
}

enum ReceiptFixtures {
    static let variants = ["clean", "noisy", "shuffled"]

    static let all: [ReceiptFixture] = load()

    static func parseDay(_ s: String) -> DayDate {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, let d = DayDate(year: p[0], month: p[1], day: p[2]) else {
            preconditionFailure("Bad fixture date \(s)")
        }
        return d
    }

    static func parseMonth(_ s: String) -> YearMonth {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count >= 2, let m = YearMonth(year: p[0], month: p[1]) else {
            preconditionFailure("Bad fixture month \(s)")
        }
        return m
    }

    private static func load() -> [ReceiptFixture] {
        let base = Bundle.module.resourceURL ?? Bundle.module.bundleURL
        let root = base.appendingPathComponent("Fixtures/Receipts")
        guard let data = try? Data(contentsOf: root.appendingPathComponent("expected.json")),
            let entries = try? JSONDecoder().decode([String: EntryJSON].self, from: data)
        else { return [] }
        var result: [ReceiptFixture] = []
        for id in entries.keys.sorted() {
            guard let entry = entries[id] else { continue }
            let context = ReceiptContext(
                today: parseDay(entry.context.today),
                firstRegistration: entry.context.firstRegistration.map(parseMonth),
                lastKnownOdometerKm: entry.context.lastKnownOdometerKm,
                knownPlates: entry.context.knownPlates,
                knownVINs: entry.context.knownVINs)
            for variant in variants {
                let url = root.appendingPathComponent("\(id)/\(variant).txt")
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                result.append(
                    ReceiptFixture(
                        id: id, variant: variant, lines: lines(from: text), context: context,
                        expected: entry.expected))
            }
        }
        return result
    }

    /// One line per text line; a line `=== PAGE ===` starts the next page.
    static func lines(from text: String) -> [RecognizedLine] {
        var page = 1
        var out: [RecognizedLine] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            if line == "=== PAGE ===" {
                page += 1
            } else {
                out.append(RecognizedLine(line, page: page))
            }
        }
        return out
    }
}

// MARK: Comparison

enum FieldOutcome: String, Sendable {
    case correct
    /// Expected a value, got `nil`.
    case missing
    /// Got a value that differs from the expectation (or a value where `nil` was expected).
    case wrong
}

struct FieldResult: Sendable {
    let field: String
    let outcome: FieldOutcome
    let expected: String?
    let actual: String?
}

enum ReceiptComparison {
    static let fieldNames = [
        "grossTotal", "netTotal", "vatAmount", "vatRate", "serviceDate", "invoiceDate", "historyDate",
        "workshopName", "workshopUID", "odometerKm", "plate", "vin", "category", "plaque",
        "isSmallAmountInvoice", "isVATExempt", "isCreditNote",
    ]

    static func compare(_ draft: ReceiptDraft, to e: ExpectedReceipt) -> [FieldResult] {
        func money(_ m: Money?) -> String? { m.map { "\($0.amountMinor) \($0.currencyCode)" } }
        func expMoney(_ v: Int64?) -> String? { v.map { "\($0) EUR" } }
        let history = e.serviceDate ?? e.invoiceDate
        let pairs: [(String, String?, String?)] = [
            ("grossTotal", expMoney(e.gross), money(draft.grossTotal)),
            ("netTotal", expMoney(e.net), money(draft.netTotal)),
            ("vatAmount", expMoney(e.vat), money(draft.vatAmount)),
            ("vatRate", e.vatRate.map(String.init), draft.vatRate.map(String.init)),
            ("serviceDate", e.serviceDate, draft.serviceDate.map(\.description)),
            ("invoiceDate", e.invoiceDate, draft.invoiceDate.map(\.description)),
            ("historyDate", history, draft.historyDate.map(\.description)),
            ("workshopName", e.workshopName, draft.workshopName),
            ("workshopUID", e.workshopUID, draft.workshopUID),
            ("odometerKm", e.odometerKm.map(String.init), draft.odometerKm.map(String.init)),
            ("plate", e.plate, draft.plate),
            ("vin", e.vin, draft.vin),
            ("category", e.category, draft.suggestedCategory?.rawValue),
            ("plaque", e.plaque, draft.suggestedPlaque.map(\.description)),
            ("isSmallAmountInvoice", String(e.isSmall ?? false), String(draft.isSmallAmountInvoice)),
            ("isVATExempt", String(e.isExempt ?? false), String(draft.isVATExempt)),
            ("isCreditNote", String(e.isCreditNote ?? false), String(draft.isCreditNote)),
        ]
        return pairs.map { name, expected, actual in
            let outcome: FieldOutcome
            if expected == actual {
                outcome = .correct
            } else if actual == nil {
                outcome = .missing
            } else {
                outcome = .wrong
            }
            return FieldResult(field: name, outcome: outcome, expected: expected, actual: actual)
        }
    }

    /// Expected position texts that were not found in the extracted work items.
    static func missingWorkItems(_ draft: ReceiptDraft, _ e: ExpectedReceipt) -> [String] {
        (e.workItems ?? []).filter { expected in
            !draft.workItems.contains { $0.contains(expected) }
        }
    }
}
