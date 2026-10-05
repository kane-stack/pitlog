import Foundation

/// Position lines, category from keywords and the new plaque punch (README §6.7, §7).
enum ReceiptPositions {
    private static let excludedWords: Set<String> = [
        "summe", "gesamt", "total", "netto", "brutto", "ust", "mwst", "zwischensumme", "ubertrag", "bar", "bankomat",
        "gegeben", "ruckgeld", "anzahlung", "akonto", "skonto", "uid", "iban", "tel", "seite", "karte", "kreditkarte",
        "wechselgeld", "bankomatkarte", "maestro",
    ]
    private static let excludedPhrases = [
        "zu zahlen", "zahlbetrag", "endbetrag", "rechnungsbetrag", "gesamtbetrag", "umsatzsteuer", "mehrwertsteuer",
        "rabatt", "fallig", "restbetrag", "a-conto", "nachst", "naechst",
    ]
    private static let unitWords: Set<String> = [
        "stk", "stk.", "st", "st.", "l", "ltr", "liter", "std", "std.", "h", "aw", "pausch", "pausch.", "psch", "psch.",
        "x", "pcs", "%", "eur", "€", "a", "à", "je", "satz",
    ]

    // Category keywords on folded text, in priority order for a line that matches several.
    private static let categoryKeywords: [(MaintenanceCategory, [String])] = [
        (.inspection, ["57a", "pickerl", "begutachtung", "plakette"]),
        (.tyres, ["raderwechsel", "reifenwechsel", "umstecken", "wuchten", "einlagerung", "raderhotel", "reifen", "radwechsel"]),
        (.service, [
            "service", "inspektion", "olwechsel", "motorol", "olfilter", "wartung", "luftfilter", "pollenfilter",
            "kraftstofffilter", "zundkerzen", "bremsflussigkeit",
        ]),
        (.repair, [
            "reparatur", "bremsbelag", "bremsbelage", "bremsscheibe", "stossdampfer", "auspuff", "kupplung", "zahnriemen",
            "lichtmaschine", "anlasser", "getriebe", "wasserpumpe", "spurstange", "tausch", "erneuer",
        ]),
    ]

    /// A position line: description and line total, without totals, taxes and payments.
    static func isItemLine(_ line: ParsedLine) -> Bool {
        guard !line.itemAmounts.isEmpty else { return false }
        if line.hasAnyWord(excludedWords) || line.containsAny(excludedPhrases) { return false }
        return true
    }

    static func workItems(lines: [ParsedLine]) -> [String] {
        var out: [String] = []
        for line in lines where isItemLine(line) {
            guard let first = line.itemAmounts.first else { continue }
            var end = first.wordIndex
            if end > 0, ["€", "eur", "e", "c"].contains(line.words[end - 1]) { end -= 1 }
            var ws = Array(line.original.replacingOccurrences(of: "\u{00A0}", with: " ").split(separator: " ").map { String($0) }.prefix(end))
            while let last = ws.last, isQuantityOrUnit(last) { ws.removeLast() }
            while let head = ws.first, isPositionToken(head) { ws.removeFirst() }
            let text = ws.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " .,:;-–"))
            guard text.filter({ $0.isLetter }).count >= 3, !out.contains(text) else { continue }
            out.append(text)
            if out.count >= 30 { break }
        }
        return out
    }

    private static func isQuantityOrUnit(_ word: String) -> Bool {
        let w = ReceiptText.fold(word)
        if unitWords.contains(w) { return true }
        let cleaned = w.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        return !cleaned.isEmpty && cleaned.allSatisfy { ReceiptText.isDigit($0) || $0 == "," || $0 == "." }
    }

    private static func isPositionToken(_ word: String) -> Bool {
        let w = ReceiptText.fold(word).trimmingCharacters(in: CharacterSet(charactersIn: ".:"))
        return w == "pos" || (ReceiptText.allDigits(w) && w.count <= 3)
    }

    // MARK: Category

    private static func matchCategory(_ folded: String) -> MaintenanceCategory? {
        for (category, keywords) in categoryKeywords where ReceiptText.containsAny(folded, keywords) {
            return category
        }
        return nil
    }

    /// The category with the highest sum of matching position amounts; keyword lines without a price
    /// are used if no position matches. Without any keyword: `.otherWorkshop` with low confidence, if there
    /// are positions at all.
    static func category(lines: [ParsedLine]) -> Pick<MaintenanceCategory>? {
        var sums: [MaintenanceCategory: Int64] = [:]
        var sources: [MaintenanceCategory: String] = [:]
        for line in lines where isItemLine(line) {
            guard let category = matchCategory(line.folded), let total = line.itemAmounts.last, total.minor > 0 else { continue }
            sums[category, default: 0] += total.minor
            if sources[category] == nil { sources[category] = line.snippet }
        }
        if let best = sums.max(by: { $0.value < $1.value }) {
            let tied = sums.filter { $0.value == best.value }.count > 1
            if tied { return nil }
            return Pick(value: best.key, confidence: sums.count == 1 ? .high : .medium, source: sources[best.key] ?? "")
        }
        var keywordOnly: Set<MaintenanceCategory> = []
        var keywordSource = ""
        for line in lines where !isHint(line) && !ReceiptIdentifiers.hasLegalForm(line) {
            if let category = matchCategory(line.folded), !line.containsAny(excludedPhrases) {
                keywordOnly.insert(category)
                if keywordSource.isEmpty { keywordSource = line.snippet }
            }
        }
        if keywordOnly.count == 1, let only = keywordOnly.first {
            return Pick(value: only, confidence: .medium, source: keywordSource)
        }
        if lines.contains(where: { isItemLine($0) }) {
            // Repair needs evidence; without a keyword the work is simply something else.
            return Pick(value: .otherWorkshop, confidence: .low, source: "no keyword")
        }
        return nil
    }

    /// Recommendations and reminders ("Nächstes Service ...") are not work that was done.
    private static func isHint(_ line: ParsedLine) -> Bool {
        line.containsAny(["nachst", "naechst", "erinner", "empfehl", "termin", "gerne"])
    }

    // MARK: Plaque

    private static let plaqueKeywords = ["plakette", "lochung", "gelocht", "pickerl"]

    /// The new punch, only from a line that names the plaque and a month/year, and not from
    /// "next inspection" hints. Always a suggestion (ADR-5).
    static func plaque(lines: [ParsedLine], context: ReceiptContext) -> Pick<YearMonth>? {
        var found: [(ym: YearMonth, line: ParsedLine)] = []
        let latest = context.today.yearMonth.adding(years: 4)
        for line in lines {
            guard line.containsAny(plaqueKeywords), !isHint(line), !line.containsAny(["fallig", "bis spatestens"]) else { continue }
            let ws = ReceiptDates.dateWords(line)
            for ym in ReceiptDates.scanMonthYear(ws) where ym >= context.today.yearMonth && ym <= latest {
                found.append((ym: ym, line: line))
            }
        }
        guard let first = found.first, Set(found.map { $0.ym }).count == 1 else { return nil }
        return Pick(value: first.ym, confidence: .medium, source: first.line.snippet)
    }
}
