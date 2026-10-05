import PitlogCore

/// Fake recognition result and fake language model for the UI tests (`-UITestReceiptScan`): the simulator has no
/// document camera and no Apple Intelligence. The lines go through the real heuristic and the real merge.
/// All values are invented. The plate is the one of the sample Golf.
enum ReceiptScanFixtures {
    static let lines: [RecognizedLine] = [
        "Autohaus Beispiel GmbH",
        "Musterstraße 1, 1010 Wien",
        "UID ATU12345674",
        "Rechnung Nr. 2026-1001",
        "Rechnungsdatum 14.03.2026",
        "Leistungsdatum 12.03.2026",
        "Kunde: Maximilian Mustermann",
        "Kennzeichen W 12345 A",
        "Km-Stand 69.150",
        "Ölwechsel mit Filter 99,90",
        "Bremsbeläge vorne 216,68",
        "Summe netto 316,58",
        "20 % USt 63,32",
        "Gesamtbetrag 379,90",
    ].map { RecognizedLine($0, page: 1) }

    /// Agrees on date, amount and plate, names the workshop differently, adds the category and no odometer.
    static let fakeModel: any ReceiptModelExtracting = FakeReceiptModel()
}

struct FakeReceiptModel: ReceiptModelExtracting {
    var isAvailable: Bool { true }

    func extractDraft(lines: [RecognizedLine], context: ReceiptContext) async -> ExtractedReceipt? {
        var draft = ExtractedReceipt()
        let medium = { (source: String) in FieldEvidence(confidence: .medium, source: source) }
        draft.grossTotal = Money(amountMinor: 37_990, currencyCode: "EUR")
        draft.evidence[.grossTotal] = medium(ReceiptEvidenceSource.model)
        draft.serviceDate = DayDate(year: 2026, month: 3, day: 12)
        draft.evidence[.serviceDate] = medium(ReceiptEvidenceSource.model)
        draft.workshopName = "Beispiel Kfz-Technik"
        draft.evidence[.workshopName] = medium(ReceiptEvidenceSource.model)
        draft.plate = "W 12345 A"
        draft.evidence[.plate] = medium(ReceiptEvidenceSource.model)
        draft.suggestedCategory = .service
        draft.evidence[.category] = medium(ReceiptEvidenceSource.model)
        return draft
    }
}
