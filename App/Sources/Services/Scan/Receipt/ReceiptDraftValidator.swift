import Foundation
import PitlogCore

/// Plausibility checks for the output of a language model (ADR-10). They are the same as the heuristic's own
/// (date not in the future, odometer not below the last known value, gross ≈ net + VAT), plus a grounding check:
/// plate, VIN and workshop must occur in the scanned text. A value that fails becomes `nil`: better nothing than
/// wrong. The heuristic's draft needs none of this, its extractors check these themselves.
enum ReceiptDraftValidator {
    /// A receipt above this gross amount (in minor units) is not a workshop receipt of a private car.
    static let maximumGrossMinor: Int64 = 10_000_000
    static let maximumOdometerKm = 2_000_000

    static func validated(_ draft: ExtractedReceipt, lines: [RecognizedLine], context: ReceiptContext) -> ExtractedReceipt {
        var result = draft
        let text = lines.map(\.text).joined(separator: "\n")
        let compactText = compact(text)
        let foldedText = TextNormalizer.folded(text)

        // Dates: not in the future, not before the first registration.
        for field in [ReceiptField.serviceDate, .invoiceDate] {
            let day = field == .serviceDate ? result.serviceDate : result.invoiceDate
            guard let day else { continue }
            let tooLate = day > context.today
            let tooEarly = context.firstRegistration.map { day < $0.firstDay } ?? false
            if tooLate || tooEarly || day.year < 1990 { clear(field, in: &result) }
        }

        // Odometer: positive, not below the last known reading.
        if let km = result.odometerKm {
            let belowLast = context.lastKnownOdometerKm.map { km < $0 } ?? false
            if km <= 0 || km > maximumOdometerKm || belowLast { clear(.odometerKm, in: &result) }
        }

        // Amounts: positive and not absurd; gross, net and VAT must add up if all three are there.
        for field in [ReceiptField.grossTotal, .netTotal, .vatAmount] {
            let money = value(of: field, in: result)
            if let money, money.amountMinor <= 0 || money.amountMinor > maximumGrossMinor { clear(field, in: &result) }
        }
        if let gross = result.grossTotal, let net = result.netTotal, let vat = result.vatAmount,
           gross.currencyCode == net.currencyCode, net.currencyCode == vat.currencyCode,
           abs(gross.amountMinor - (net.amountMinor + vat.amountMinor)) > 2
        {
            clear(.grossTotal, in: &result)
            clear(.netTotal, in: &result)
            clear(.vatAmount, in: &result)
        }
        if let rate = result.vatRate, ![0, 5, 7, 10, 13, 19, 20].contains(rate) { clear(.vatRate, in: &result) }

        // Grounding: identifiers must be in the text.
        if let plate = result.plate, !compactText.contains(compact(plate)) || compact(plate).count < 3 {
            clear(.plate, in: &result)
        }
        if let vin = result.vin, !(isVIN(vin) && compactText.contains(compact(vin))) { clear(.vin, in: &result) }
        if let name = result.workshopName {
            let folded = TextNormalizer.folded(name)
            if folded.count < 3 || !foldedText.contains(folded) { clear(.workshopName, in: &result) }
        }
        return result
    }

    private static func value(of field: ReceiptField, in draft: ExtractedReceipt) -> Money? {
        switch field {
        case .grossTotal: draft.grossTotal
        case .netTotal: draft.netTotal
        case .vatAmount: draft.vatAmount
        default: nil
        }
    }

    private static func clear(_ field: ReceiptField, in draft: inout ExtractedReceipt) {
        switch field {
        case .grossTotal: draft.grossTotal = nil
        case .netTotal: draft.netTotal = nil
        case .vatAmount: draft.vatAmount = nil
        case .vatRate: draft.vatRate = nil
        case .serviceDate: draft.serviceDate = nil
        case .invoiceDate: draft.invoiceDate = nil
        case .workshopName: draft.workshopName = nil
        case .workshopUID: draft.workshopUID = nil
        case .odometerKm: draft.odometerKm = nil
        case .plate: draft.plate = nil
        case .vin: draft.vin = nil
        case .category: draft.suggestedCategory = nil
        case .plaque: draft.suggestedPlaque = nil
        case .workItems: draft.workItems = []
        }
        draft.evidence[field] = nil
    }

    /// 17 letters and digits without I, O and Q.
    static func isVIN(_ text: String) -> Bool {
        let vin = compact(text)
        return vin.count == 17 && !vin.contains { "IOQ".contains($0) }
    }

    /// Upper case letters and digits only: "W 12345 A" and "W-12345-A" compare equal.
    static func compact(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber })
    }
}

enum TextNormalizer {
    /// Lower case, umlauts and ß replaced, nothing but letters and digits: for comparing names across sources.
    static func folded(_ text: String) -> String {
        var result = text.lowercased()
        for (from, to) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss"), ("é", "e"), ("è", "e")] {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return String(result.filter { $0.isLetter || $0.isNumber })
    }
}
