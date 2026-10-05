import Foundation
import PitlogCore

/// Who read a value.
enum ReceiptSource: String, Hashable, Sendable {
    /// The rules in PitlogCore (`HeuristicReceiptExtractor`).
    case heuristic
    /// The on-device language model (Foundation Models).
    case model
    /// The RKSV QR code of a cash register receipt.
    case qrCode
}

/// How the sources relate for one field.
enum ReceiptAgreement: Hashable, Sendable {
    /// One source only (or only one extractor ran): the value stands on its own.
    case single
    /// Both extractors read the same value.
    case agreed
    /// The extractors read different values; the user picks.
    case conflict
    /// The QR code decided.
    case qrCode
}

/// One reading of a field.
struct ReceiptCandidate<Value: Hashable & Sendable>: Hashable, Sendable {
    let value: Value
    let source: ReceiptSource
    /// The source line the value came from; `nil` for the model, which has no source line.
    let snippet: String?
}

/// A field after merging: the value that is preselected, how sure we are, and all readings.
struct MergedField<Value: Hashable & Sendable>: Hashable, Sendable {
    var value: Value
    var confidence: FieldConfidence
    var agreement: ReceiptAgreement
    /// Every distinct reading; the preselected one first.
    var candidates: [ReceiptCandidate<Value>]
    var snippet: String? { candidates.first?.snippet }
    /// Low confidence is unchecked until the user turns it on.
    var isIncludedByDefault: Bool { confidence != .low }
}

/// The result of combining the heuristic, the language model and the QR code (ADR-10).
struct ReceiptMerge: Sendable {
    var date: MergedField<DayDate>?
    var gross: MergedField<Money>?
    var workshop: MergedField<String>?
    var odometerKm: MergedField<Int>?
    var plate: MergedField<String>?
    var vin: MergedField<String>?
    var category: MergedField<MaintenanceCategory>?
    var workItems: MergedField<[String]>?
    /// From a § 57a receipt, heuristic only. A hint, never applied by itself (ADR-5).
    var suggestedPlaque: YearMonth?
    var isCreditNote: Bool
    /// The language model took part.
    var modelRan: Bool
}

enum ReceiptMerger {
    /// Combines the drafts per field.
    ///
    /// - Both extractors agree: high confidence.
    /// - Only one has a value: that value, medium confidence (low stays low).
    /// - They differ: the heuristic's value, low confidence, so unchecked by default; both are kept as candidates.
    /// - The RKSV QR code decides date and gross total (high); different readings stay as candidates.
    /// Without a model result the heuristic's own confidence is kept: there is nothing to agree with.
    static func merge(
        heuristic: ExtractedReceipt, model: ExtractedReceipt?, rksv: RKSVReceipt?
    ) -> ReceiptMerge {
        let modelRan = model != nil
        func candidate<V: Hashable & Sendable>(
            _ value: V?, _ source: ReceiptSource, _ draft: ExtractedReceipt?, _ evidence: [ReceiptField]
        ) -> (ReceiptCandidate<V>, FieldConfidence)? {
            guard let value, let draft else { return nil }
            let found = evidence.compactMap { draft.evidence[$0] }.first
            let snippet = source == .model ? nil : found?.source
            return (ReceiptCandidate(value: value, source: source, snippet: snippet), found?.confidence ?? .medium)
        }

        func field<V: Hashable & Sendable>(
            _ keyPath: KeyPath<ExtractedReceipt, V?>, _ evidence: [ReceiptField],
            same: (V, V) -> Bool = { $0 == $1 }
        ) -> MergedField<V>? {
            combine(
                candidate(heuristic[keyPath: keyPath], .heuristic, heuristic, evidence),
                candidate(model?[keyPath: keyPath], .model, model, evidence),
                modelRan: modelRan, same: same)
        }

        var result = ReceiptMerge(
            date: combine(
                candidate(heuristic.historyDate, .heuristic, heuristic, [.serviceDate, .invoiceDate]),
                candidate(model?.historyDate, .model, model, [.serviceDate, .invoiceDate]),
                modelRan: modelRan, same: { $0 == $1 }),
            gross: field(\.grossTotal, [.grossTotal]),
            workshop: field(\.workshopName, [.workshopName], same: sameName),
            odometerKm: field(\.odometerKm, [.odometerKm]),
            plate: field(\.plate, [.plate], same: { compact($0) == compact($1) }),
            vin: field(\.vin, [.vin], same: { compact($0) == compact($1) }),
            category: field(\.suggestedCategory, [.category]),
            workItems: combine(
                candidate(heuristic.workItems.isEmpty ? nil : heuristic.workItems, .heuristic, heuristic, [.workItems]),
                candidate(model.flatMap { $0.workItems.isEmpty ? nil : $0.workItems }, .model, model, [.workItems]),
                modelRan: modelRan, same: sameItems),
            suggestedPlaque: heuristic.suggestedPlaque,
            isCreditNote: heuristic.isCreditNote,
            modelRan: modelRan)

        if let rksv {
            result.date = qrWins(
                result.date, value: rksv.date, snippet: "RKSV QR code")
            if rksv.isCancellation || rksv.grossTotal.amountMinor <= 0 {
                result.isCreditNote = true
                result.gross = nil
            } else {
                result.isCreditNote = false
                result.gross = qrWins(result.gross, value: rksv.grossTotal, snippet: "RKSV QR code")
            }
        }
        // A credit note has no amount to log, whoever read one.
        if result.isCreditNote { result.gross = nil }
        return result
    }

    // MARK: Per field

    private static func combine<V: Hashable & Sendable>(
        _ heuristic: (ReceiptCandidate<V>, FieldConfidence)?,
        _ model: (ReceiptCandidate<V>, FieldConfidence)?,
        modelRan: Bool,
        same: (V, V) -> Bool
    ) -> MergedField<V>? {
        switch (heuristic, model) {
        case (nil, nil):
            return nil
        case (let h?, nil):
            // The model ran but found nothing, or did not run at all.
            let confidence = modelRan ? min(h.1, .medium) : h.1
            return MergedField(value: h.0.value, confidence: confidence, agreement: .single, candidates: [h.0])
        case (nil, let m?):
            return MergedField(value: m.0.value, confidence: min(m.1, .medium), agreement: .single, candidates: [m.0])
        case (let h?, let m?):
            if same(h.0.value, m.0.value) {
                return MergedField(value: h.0.value, confidence: .high, agreement: .agreed, candidates: [h.0])
            }
            return MergedField(
                value: h.0.value, confidence: .low, agreement: .conflict, candidates: [h.0, m.0])
        }
    }

    /// The QR value first and preselected; what the other readers saw stays as a candidate if it differs.
    private static func qrWins<V: Hashable & Sendable>(
        _ merged: MergedField<V>?, value: V, snippet: String
    ) -> MergedField<V> {
        let qr = ReceiptCandidate(value: value, source: .qrCode, snippet: snippet)
        let others = (merged?.candidates ?? []).filter { $0.value != value }
        return MergedField(value: value, confidence: .high, agreement: .qrCode, candidates: [qr] + others)
    }

    // MARK: Equality

    private static func compact(_ text: String) -> String { ReceiptDraftValidator.compact(text) }

    /// Equal after folding, or one name contains the other ("Müller Kfz" and "Müller Kfz GmbH").
    private static func sameName(_ lhs: String, _ rhs: String) -> Bool {
        let a = TextNormalizer.folded(lhs)
        let b = TextNormalizer.folded(rhs)
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        let (short, long) = a.count <= b.count ? (a, b) : (b, a)
        return short.count >= 4 && long.contains(short)
    }

    /// The lists share at least one position (by normalized text, or one contains the other).
    private static func sameItems(_ lhs: [String], _ rhs: [String]) -> Bool {
        let a = lhs.map(TextNormalizer.folded).filter { $0.count >= 3 }
        let b = rhs.map(TextNormalizer.folded).filter { $0.count >= 3 }
        return a.contains { x in b.contains { y in x == y || x.contains(y) || y.contains(x) } }
    }
}
