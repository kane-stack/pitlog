import Foundation

/// Receipt extraction with heuristics only (ADR-10): labels, formats and plausibility checks, no
/// machine learning. Principle: better `nil` than a wrong value; every value carries its
/// confidence and source line. See `docs/receipt-parser.md`.
public struct HeuristicReceiptExtractor: ReceiptExtractor {
    public init() {}

    public func extract(lines: [ReceiptLine], context: ReceiptContext) async -> ReceiptDraft {
        draft(lines: lines, context: context)
    }

    /// The synchronous implementation behind `extract(lines:context:)`.
    public func draft(lines: [ReceiptLine], context: ReceiptContext) -> ReceiptDraft {
        var draft = ReceiptDraft()
        let rksv = Self.findRKSV(lines: lines, context: context)
        // The QR payload is machine-readable and must not be analysed as text.
        let texts = lines.map(\.text).filter { !$0.contains("_R1-AT") }
        let parsed = Self.mergeSplitLines(texts).enumerated().map { ParsedLine(index: $0.offset, original: $0.element) }

        func put<V: Sendable>(_ field: ReceiptField, _ pick: Pick<V>?, _ assign: (V) -> Void) {
            guard let pick else { return }
            assign(pick.value)
            draft.evidence[field] = FieldEvidence(confidence: pick.confidence, source: pick.source)
        }

        // Amounts
        let amounts = ReceiptAmounts.extract(lines: parsed)
        put(.grossTotal, amounts.gross) { draft.grossTotal = $0 }
        put(.netTotal, amounts.net) { draft.netTotal = $0 }
        put(.vatAmount, amounts.vat) { draft.vatAmount = $0 }
        put(.vatRate, amounts.rate) { draft.vatRate = $0 }
        draft.isVATExempt = amounts.isExempt
        if let source = amounts.creditNoteSource {
            draft.isCreditNote = true
            draft.evidence[.grossTotal] = FieldEvidence(confidence: .low, source: source)
        }

        // Dates
        let dates = ReceiptDates.select(found: ReceiptDates.find(lines: parsed), context: context)
        put(.serviceDate, dates.service) { draft.serviceDate = $0 }
        put(.invoiceDate, dates.invoice) { draft.invoiceDate = $0 }

        // The RKSV QR code takes precedence for date and gross total.
        if let rksv {
            if rksv.isCancellation || rksv.grossTotal.amountMinor <= 0 {
                draft.isCreditNote = true
                draft.grossTotal = nil
                draft.evidence[.grossTotal] = FieldEvidence(confidence: .low, source: "RKSV QR code (cancellation)")
            } else {
                draft.isCreditNote = false
                draft.grossTotal = rksv.grossTotal
                draft.evidence[.grossTotal] = FieldEvidence(confidence: .high, source: "RKSV QR code")
            }
            draft.invoiceDate = rksv.date
            draft.evidence[.invoiceDate] = FieldEvidence(confidence: .high, source: "RKSV QR code")
            let rates = rksv.amounts.filter { $0.amount.amountMinor != 0 && $0.ratePercent > 0 }.map(\.ratePercent)
            if draft.vatRate == nil, rates.count == 1, let rate = rates.first {
                draft.vatRate = rate
                draft.evidence[.vatRate] = FieldEvidence(confidence: .high, source: "RKSV QR code")
            }
        }

        // Workshop and vehicle
        put(.workshopName, ReceiptIdentifiers.workshopName(lines: parsed)) { draft.workshopName = $0 }
        put(.workshopUID, ReceiptIdentifiers.workshopUID(lines: parsed)) { draft.workshopUID = $0 }
        put(.odometerKm, ReceiptOdometer.extract(lines: parsed, context: context)) { draft.odometerKm = $0 }
        put(.plate, ReceiptIdentifiers.plate(lines: parsed, context: context)) { draft.plate = $0 }
        put(.vin, ReceiptIdentifiers.vin(lines: parsed, context: context)) { draft.vin = $0 }

        // Content
        put(.category, ReceiptPositions.category(lines: parsed)) { draft.suggestedCategory = $0 }
        put(.plaque, ReceiptPositions.plaque(lines: parsed, context: context)) { draft.suggestedPlaque = $0 }
        draft.workItems = ReceiptPositions.workItems(lines: parsed)
        if !draft.workItems.isEmpty {
            draft.evidence[.workItems] = FieldEvidence(confidence: .medium, source: "position lines")
        }

        // Invoice kind
        if let gross = draft.grossTotal {
            draft.isSmallAmountInvoice =
                gross.amountMinor <= 40_000 && draft.netTotal == nil && draft.vatAmount == nil && !draft.isVATExempt
        }
        if amounts.isSmallKeyword { draft.isSmallAmountInvoice = true }
        return draft
    }

    /// OCR often puts a label and its amount on two lines ("Gesamtbetrag" / "15 841,50"). A label
    /// line without an amount followed by a line with nothing but an amount becomes one line.
    static func mergeSplitLines(_ texts: [String]) -> [String] {
        var out: [String] = []
        var i = 0
        while i < texts.count {
            if i + 1 < texts.count {
                let label = ParsedLine(index: i, original: texts[i])
                let next = ParsedLine(index: i + 1, original: texts[i + 1])
                if ReceiptAmounts.isLabelOnlyLine(label), ReceiptAmounts.isAmountOnlyLine(next) {
                    out.append(texts[i] + " " + texts[i + 1])
                    i += 2
                    continue
                }
            }
            out.append(texts[i])
            i += 1
        }
        return out
    }

    // MARK: RKSV

    /// The first usable RKSV QR code: from the context or printed as text in a line. Training
    /// receipts and codes with an implausible date are ignored.
    static func findRKSV(lines: [ReceiptLine], context: ReceiptContext) -> RKSVReceipt? {
        var payloads = context.rksvPayloads
        for line in lines {
            guard let range = line.text.range(of: "_R1-AT") else { continue }
            let tail = line.text[range.lowerBound...]
            let payload = tail.split(whereSeparator: { $0.isWhitespace }).first.map { String($0) } ?? String(tail)
            payloads.append(payload)
        }
        for payload in payloads {
            guard let receipt = parseRKSVCode(payload), !receipt.isTraining,
                ReceiptDates.isPlausible(receipt.date, context: context)
            else { continue }
            return receipt
        }
        return nil
    }
}
