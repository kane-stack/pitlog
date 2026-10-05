import Foundation
import PitlogCore

/// Seam for the on-device language model (ADR-10): the real implementation needs Apple Intelligence and cannot
/// run in the CI simulator, so tests and UI tests inject a fake.
protocol ReceiptModelExtracting: Sendable {
    /// `false` if the model cannot be used: device without Apple Intelligence, model not downloaded yet, setting off.
    var isAvailable: Bool { get }
    /// The draft the model read, already validated; `nil` if it could not produce a result (error, refusal,
    /// context window).
    func extractDraft(lines: [RecognizedLine], context: ReceiptContext) async -> ExtractedReceipt?
}

/// Where the text of a language-model request comes from, and how much of it fits.
enum ReceiptPromptBuilder {
    /// Characters of receipt text per request. The context window of the on-device model is 4096 tokens, shared
    /// by instructions, schema, receipt text and answer; German text is about three characters per token.
    static let characterBudget = 5_000

    /// The text of the receipt, if necessary shortened: the header and the footer stay (workshop, totals,
    /// VAT ID), in between only lines with amounts or dates. Order is kept; gaps are marked with "…".
    static func text(lines: [String], budget: Int = characterBudget) -> String {
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if cleaned.reduce(0, { $0 + $1.count + 1 }) <= budget { return cleaned.joined(separator: "\n") }

        let headCount = min(12, cleaned.count)
        let tailCount = min(15, max(0, cleaned.count - headCount))
        var keep = Set(0..<headCount)
        keep.formUnion((cleaned.count - tailCount)..<cleaned.count)
        var used = keep.reduce(0) { $0 + cleaned[$1].count + 1 }
        // Header and footer alone may exceed a small budget: shorten them from the inside.
        if used > budget {
            let ordered = keep.sorted()
            for index in ordered.reversed() where used > budget && index >= headCount / 2 && index < cleaned.count - tailCount / 2 {
                keep.remove(index)
                used -= cleaned[index].count + 1
            }
        }
        for index in headCount..<(cleaned.count - tailCount) where hasAmountOrDate(cleaned[index]) {
            let cost = cleaned[index].count + 1
            if used + cost > budget { continue }
            keep.insert(index)
            used += cost
        }

        var output: [String] = []
        var previous = -1
        for index in keep.sorted() {
            if index != previous + 1 { output.append("…") }
            output.append(cleaned[index])
            previous = index
        }
        if previous < cleaned.count - 1 { output.append("…") }
        return output.joined(separator: "\n")
    }

    /// A digit and a separator that makes it an amount, a date or a time ("12,50", "05.10.2026", "2026-10-05").
    static func hasAmountOrDate(_ line: String) -> Bool {
        line.contains { $0.isNumber } && line.contains { ",./-€%:".contains($0) }
    }
}

#if canImport(FoundationModels)
import FoundationModels

/// What the model fills in. Everything is optional: `nil` means "not on the receipt".
@Generable
struct GeneratedReceipt {
    @Guide(description: "Invoice total including VAT (gross), in cents as an integer, for example 12050 for 120.50. The total of the whole invoice, not the amount still due after a deposit. null if not clearly printed.")
    var grossTotalMinorUnits: Int?
    @Guide(description: "ISO 4217 currency code, EUR if the receipt shows € or no currency.")
    var currencyCode: String?
    @Guide(description: "Date of the service or delivery (Leistungsdatum), as yyyy-MM-dd. null if not clearly printed.")
    var serviceDate: String?
    @Guide(description: "Date of the invoice (Rechnungsdatum), as yyyy-MM-dd. Never a due date. null if not clearly printed.")
    var invoiceDate: String?
    @Guide(description: "Name of the workshop or business that issued the invoice, usually in the header or the footer. Never the customer.")
    var workshopName: String?
    @Guide(description: "Odometer reading in km at the time of the service, as an integer. Never a service interval or the next service. null if not printed.")
    var odometerKm: Int?
    @Guide(description: "License plate of the vehicle as printed, for example W 12345 A. null if not printed.")
    var licensePlate: String?
    @Guide(description: "Vehicle identification number (VIN, Fahrgestellnummer), 17 characters. null if not printed.")
    var vin: String?
    @Guide(description: "What kind of workshop visit this is.")
    var category: GeneratedReceiptCategory?
    @Guide(description: "Short descriptions of the work and parts, without prices, quantities or article numbers.", .maximumCount(10))
    var workItems: [String]
}

@Generable
enum GeneratedReceiptCategory {
    case service
    case repair
    case tyres
    case inspection
    case otherWorkshop
}

/// ADR-10: receipt extraction with Foundation Models, on the device. The instructions state the decisions of the
/// receipt parser (E-1 gross invoice total, E-2 service date) and forbid guessing.
struct FoundationModelsReceiptExtractor: ReceiptModelExtracting, ReceiptExtractor {
    static let instructions = """
        You read workshop invoices and receipts for cars, mostly Austrian, in German or English. The text comes from \
        text recognition and may contain mistakes. Fill in only what is clearly printed. Never guess: return null for \
        every field you are not sure about.
        Rules:
        - grossTotalMinorUnits is the invoice total including VAT (Rechnungsbetrag brutto, Gesamtbetrag) in cents. \
        It is the total of the whole invoice, not the amount still due after a deposit (Anzahlung, Akonto, \
        "noch zu zahlen"), not the net amount, not the cash given and not the change.
        - serviceDate is the date of the service or delivery (Leistungsdatum, Lieferdatum). invoiceDate is the date \
        of the invoice (Rechnungsdatum, Datum). Dates are yyyy-MM-dd.
        - Ignore the customer's name, address and VAT ID. Ignore due dates (fällig, zahlbar bis), discount dates, \
        the next service or next inspection date and values for the next service. workshopName is the business that \
        issued the invoice.
        - odometerKm is the reading at the visit (Kilometerstand, km-Stand), never an interval.
        - workItems are short descriptions without prices.

        Du liest Werkstattrechnungen und Belege für Autos, meist aus Österreich. Der Text stammt aus einer \
        Texterkennung und kann Fehler enthalten. Fülle nur aus, was eindeutig dasteht. Rate nie: Gib null zurück, \
        wenn du dir nicht sicher bist. Betrag = Rechnungsbetrag brutto in Cent (nicht der Restbetrag nach Anzahlung), \
        Datum = Leistungsdatum, Rechnungsdatum getrennt. Ignoriere Kundenname, Kundenadresse, Fälligkeitsdatum und \
        Werte für das nächste Service.
        """

    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func extract(lines: [RecognizedLine], context: ReceiptContext) async -> ExtractedReceipt {
        await extractDraft(lines: lines, context: context) ?? ExtractedReceipt()
    }

    func extractDraft(lines: [RecognizedLine], context: ReceiptContext) async -> ExtractedReceipt? {
        guard isAvailable else { return nil }
        // The text is shortened again if the first try exceeds the context window.
        for budget in [ReceiptPromptBuilder.characterBudget, ReceiptPromptBuilder.characterBudget / 2] {
            let text = ReceiptPromptBuilder.text(lines: lines.map(\.text), budget: budget)
            let session = LanguageModelSession(instructions: Self.instructions)
            do {
                let response = try await session.respond(
                    to: "Receipt text:\n\(text)",
                    generating: GeneratedReceipt.self,
                    options: GenerationOptions(sampling: .greedy))
                return ReceiptDraftValidator.validated(
                    Self.draft(from: response.content), lines: lines, context: context)
            } catch let error as LanguageModelSession.GenerationError {
                if case .exceededContextWindowSize = error { continue }
                return nil
            } catch {
                return nil
            }
        }
        return nil
    }

    /// The model's answer as a draft, before validation. Confidence is medium for everything: the model gives no
    /// confidence of its own, and a value the heuristic does not confirm should not look certain.
    static func draft(from generated: GeneratedReceipt) -> ExtractedReceipt {
        var draft = ExtractedReceipt()
        let source = ReceiptEvidenceSource.model

        func note(_ field: ReceiptField) {
            draft.evidence[field] = FieldEvidence(confidence: .medium, source: source)
        }

        let currency = (generated.currencyCode ?? "EUR").trimmingCharacters(in: .whitespaces)
        if let minor = generated.grossTotalMinorUnits {
            draft.grossTotal = Money(amountMinor: Int64(minor), currencyCode: currency.isEmpty ? "EUR" : currency)
            note(.grossTotal)
        }
        if let day = generated.serviceDate.flatMap(DayDate.fromISO) {
            draft.serviceDate = day
            note(.serviceDate)
        }
        if let day = generated.invoiceDate.flatMap(DayDate.fromISO) {
            draft.invoiceDate = day
            note(.invoiceDate)
        }
        if let name = clean(generated.workshopName) {
            draft.workshopName = name
            note(.workshopName)
        }
        if let km = generated.odometerKm {
            draft.odometerKm = km
            note(.odometerKm)
        }
        if let plate = clean(generated.licensePlate) {
            draft.plate = plate
            note(.plate)
        }
        if let vin = clean(generated.vin) {
            draft.vin = vin.uppercased().filter { !$0.isWhitespace }
            note(.vin)
        }
        if let category = generated.category {
            let mapped: MaintenanceCategory
            switch category {
            case .service: mapped = .service
            case .repair: mapped = .repair
            case .tyres: mapped = .tyres
            case .inspection: mapped = .inspection
            case .otherWorkshop: mapped = .otherWorkshop
            }
            draft.suggestedCategory = mapped
            note(.category)
        }
        draft.workItems = generated.workItems.compactMap { clean($0) }
        if !draft.workItems.isEmpty { note(.workItems) }
        return draft
    }

    private static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              trimmed.lowercased() != "null"
        else { return nil }
        return trimmed
    }
}
#endif

/// The evidence text a language-model draft carries instead of a source line.
enum ReceiptEvidenceSource {
    static let model = "language model"
}

extension DayDate {
    /// "2026-10-05" (a time part is ignored); `nil` for anything else.
    static func fromISO(_ text: String) -> DayDate? {
        let day = text.trimmingCharacters(in: .whitespaces).prefix(10)
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, day.count == 10 else { return nil }
        return DayDate(year: parts[0], month: parts[1], day: parts[2])
    }

    /// "2026-10-05", for exports and fixtures.
    var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

/// The model of a device without Apple Intelligence, and of every test: never available.
struct UnavailableReceiptModel: ReceiptModelExtracting {
    var isAvailable: Bool { false }
    func extractDraft(lines: [RecognizedLine], context: ReceiptContext) async -> ExtractedReceipt? { nil }
}

enum ReceiptModelProvider {
    /// The model to use in the app: Foundation Models where the framework exists, otherwise none.
    static func systemModel() -> (any ReceiptModelExtracting)? {
        #if canImport(FoundationModels)
        let model = FoundationModelsReceiptExtractor()
        return model.isAvailable ? model : nil
        #else
        return nil
        #endif
    }
}
