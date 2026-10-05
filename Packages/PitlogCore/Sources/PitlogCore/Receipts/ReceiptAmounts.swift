import Foundation

/// Gross total, net, VAT and VAT rate (README §6.1, §7). Principle: better `nil` than wrong.
enum ReceiptAmounts {
    struct Result {
        var gross: Pick<Money>?
        var net: Pick<Money>?
        var vat: Pick<Money>?
        var rate: Pick<Int>?
        /// Set for credit notes, cancellations and negative totals; the source line.
        var creditNoteSource: String?
        var isExempt = false
        var isSmallKeyword = false
    }

    private struct Candidate {
        let minor: Int64
        let tier: Int
        let line: ParsedLine
    }

    // MARK: Label tables

    /// Strong total labels (README §6.1: preferred over "Summe", "Gesamt", "Total").
    private static let strongTotalPhrases = [
        "zu zahlen", "zahlbetrag", "zahlungsbetrag", "endbetrag", "endsumme", "rechnungsbetrag", "rechnungssumme",
        "gesamtbetrag", "gesamtsumme", "gesamt brutto", "summe brutto", "bruttosumme", "bruttobetrag", "total brutto",
    ]
    private static let weakTotalWords: Set<String> = [
        "summe", "gesamt", "total", "brutto", "betrag", "gesamtpreis", "endpreis", "gesamtkosten",
    ]
    /// Amounts due after a deposit. With a deposit on the receipt they are not the invoice total (E-1).
    private static let dueMarkers = ["zu zahlen", "zahlbetrag", "zahlungsbetrag", "restbetrag", "offener betrag", "noch offen"]
    private static let depositMarkers = [
        "anzahlung", "akonto", "a-conto", "aconto", "vorauszahlung", "angezahlt", "bereits bezahlt", "bereits geleistet",
    ]
    private static let excludedForGross = [
        "netto", "zwischensumme", "zwischensum", "ubertrag", "gegeben", "ruckgeld", "wechselgeld", "skonto",
        "anzahlung", "akonto", "a-conto", "aconto", "vorauszahlung", "angezahlt", "restbetrag", "bezahlt am",
        "bereits bezahlt", "bereits geleistet", "offener betrag", "noch offen",
    ]
    private static let blockWords: Set<String> = [
        "lohn", "arbeitslohn", "teile", "ersatzteile", "material", "arbeit", "lohnkosten", "arbeitszeit", "fremdleistung",
        "fremdleistungen",
    ]
    private static let paymentWords: Set<String> = [
        "bar", "bankomat", "bankomatkarte", "karte", "kreditkarte", "maestro", "visa", "mastercard", "ec-karte", "ec",
    ]
    private static let creditKeywords = [
        "gutschrift", "storno", "rechnungskorrektur", "korrekturrechnung", "kreditnote", "stornierung",
    ]
    private static let exemptKeywords = [
        "kleinunternehmer", "umsatzsteuerfrei", "steuerbefreit", "keine umsatzsteuer", "ohne umsatzsteuer",
        "abs. 1 z 27", "abs 1 z 27",
    ]
    private static let validRates: Set<Int> = [10, 13, 19, 20]

    // MARK: Entry point

    static func extract(lines: [ParsedLine]) -> Result {
        var result = Result()
        let currency = ReceiptText.currencyCode(in: lines)
        func money(_ minor: Int64) -> Money { Money(amountMinor: minor, currencyCode: currency) }

        if let line = lines.first(where: { $0.containsAny(creditKeywords) }) {
            result.creditNoteSource = line.snippet
        }
        result.isExempt = lines.contains { $0.containsAny(exemptKeywords) }
        result.isSmallKeyword = lines.contains { $0.containsAny(["kleinbetragsrechnung"]) }

        let hasDeposit = lines.contains { $0.containsAny(depositMarkers) }
        let (candidates, negativeSource) = grossCandidates(lines: lines, hasDeposit: hasDeposit)
        if result.creditNoteSource == nil, let negativeSource {
            result.creditNoteSource = negativeSource
        }
        if result.creditNoteSource != nil {
            return result
        }

        let nets = netCandidates(lines: lines)
        let vats = vatCandidates(lines: lines)
        let rates = rateValues(lines: lines)
        if rates.count == 1, let rate = rates.first {
            result.rate = Pick(value: rate.value, confidence: .high, source: rate.source)
        }

        func verifiedPair(for gross: Int64) -> (net: Int64, vat: Int64?, netLine: String, vatLine: String?)? {
            var best: (net: Int64, vat: Int64?, netLine: String, vatLine: String?)?
            for net in nets {
                for vat in vats where abs(net.minor + vat.minor - gross) <= 2 {
                    if best == nil || net.minor > best!.net {
                        best = (net.minor, vat.minor, net.line.snippet, vat.line.snippet)
                    }
                }
                if vats.isEmpty {
                    let candidateRates = result.rate.map { [$0.value] } ?? [20, 10, 13]
                    for rate in candidateRates {
                        let expected = (net.minor * Int64(100 + rate) + 50) / 100
                        if abs(expected - gross) <= 2, best == nil || net.minor > best!.net {
                            best = (net.minor, nil, net.line.snippet, nil)
                        }
                    }
                }
            }
            return best
        }

        let usable = hasDeposit ? candidates.filter { !isDue($0.line) } : candidates
        if let maxTier = usable.map(\.tier).max() {
            let top = usable.filter { $0.tier == maxTier }
            let distinct = Array(Set(top.map(\.minor))).sorted()
            var chosen: Int64?
            var confidence = FieldConfidence.medium
            var source = top[0].line.snippet
            if distinct.count == 1, let only = distinct.first {
                chosen = only
                source = top.first(where: { $0.minor == only })?.line.snippet ?? source
                let verified = verifiedPair(for: only) != nil
                let mismatch = !nets.isEmpty && !vats.isEmpty && !verified
                if verified {
                    confidence = .high
                } else if mismatch {
                    confidence = .low
                } else if maxTier == 2 {
                    confidence = .high
                } else if hasDeposit {
                    confidence = .medium
                } else if corroboratedByPayment(only, lines: lines) {
                    confidence = .high
                } else {
                    confidence = .medium
                }
            } else {
                let verified = distinct.filter { verifiedPair(for: $0) != nil }
                if verified.count == 1, let only = verified.first {
                    chosen = only
                    confidence = .high
                    source = top.first(where: { $0.minor == only })?.line.snippet ?? source
                }
            }
            if let chosen, isPlausibleTotal(chosen) {
                result.gross = Pick(value: money(chosen), confidence: confidence, source: source)
            }
        } else if nets.count == 1, vats.count == 1, let net = nets.first, let vat = vats.first {
            // No labelled total (e.g. only "zu zahlen" after a deposit): net + VAT, if the VAT is
            // consistent with a known rate.
            let rateOK = [10, 13, 19, 20].contains { rate in
                abs((net.minor * Int64(rate) + 50) / 100 - vat.minor) <= 2
            }
            let sum = net.minor + vat.minor
            if rateOK, isPlausibleTotal(sum) {
                result.gross = Pick(
                    value: money(sum), confidence: .medium, source: "\(net.line.snippet) + \(vat.line.snippet)")
            }
        }

        // Net and VAT: confirmed against the gross total, or the only candidate.
        if let gross = result.gross, let pair = verifiedPair(for: gross.value.amountMinor) {
            result.net = Pick(value: money(pair.net), confidence: .high, source: pair.netLine)
            if let vat = pair.vat, let vatLine = pair.vatLine {
                result.vat = Pick(value: money(vat), confidence: .high, source: vatLine)
            }
        } else {
            let distinctNets = Set(nets.map(\.minor))
            if distinctNets.count == 1, let net = nets.first {
                result.net = Pick(value: money(net.minor), confidence: .medium, source: net.line.snippet)
            }
            let distinctVats = Set(vats.map(\.minor))
            if distinctVats.count == 1, let vat = vats.first {
                result.vat = Pick(value: money(vat.minor), confidence: .medium, source: vat.line.snippet)
            }
        }
        if result.isExempt {
            result.vat = nil
            result.rate = nil
        }
        return result
    }

    // MARK: Candidates

    private static func isPlausibleTotal(_ minor: Int64) -> Bool {
        minor > 0 && minor < 100_000_000
    }

    private static func isDue(_ line: ParsedLine) -> Bool {
        line.containsAny(dueMarkers)
    }

    static func hasVATWord(_ line: ParsedLine) -> Bool {
        line.cleanWords.contains { w in
            w == "ust" || w == "mwst" || w == "m.w.st" || w == "mwst." || w.hasPrefix("ust-")
                || w.hasPrefix("umsatzsteuer") || w.hasPrefix("mehrwertsteuer") || w.hasPrefix("mwst")
        }
    }

    /// The line states that VAT is included in a total (and is not itself a VAT line).
    private static func isInclusive(_ line: ParsedLine) -> Bool {
        line.containsAny(["inkl", "enthalten", "brutto"])
    }

    /// Total label strength: 2 strong, 1 weak, 0 none. "rn" is read as "m" ("Surnme" -> "Summe").
    private static func tier(of line: ParsedLine) -> Int {
        let alt = line.folded.replacingOccurrences(of: "rn", with: "m")
        if strongTotalPhrases.contains(where: { line.folded.contains($0) || alt.contains($0) }) { return 2 }
        let altWords = Set(ReceiptText.words(alt).map { ReceiptText.cleanWord($0) })
        if line.hasAnyWord(weakTotalWords) || !altWords.isDisjoint(with: weakTotalWords) { return 1 }
        if isAmountBeforeInclusiveVAT(line) { return 1 }
        return 0
    }

    /// "EUR 89,90 inkl. 20% MwSt.": the amount stands before "inkl." and a VAT word follows.
    private static func isAmountBeforeInclusiveVAT(_ line: ParsedLine) -> Bool {
        guard hasVATWord(line), let first = line.amounts.first,
            let inkl = line.words.firstIndex(where: { $0.hasPrefix("inkl") })
        else { return false }
        return first.wordIndex < inkl && !line.containsAny(["netto"])
    }

    /// A line that names a total, net or VAT amount but carries no amount itself.
    static func isLabelOnlyLine(_ line: ParsedLine) -> Bool {
        guard line.amounts.isEmpty, !line.containsAny(["bezeichnung", "menge"]) else { return false }
        return tier(of: line) > 0 || line.containsAny(["netto"]) || hasVATWord(line) || isDue(line)
    }

    /// A line made of one amount (and a currency marker) only.
    static func isAmountOnlyLine(_ line: ParsedLine) -> Bool {
        guard !line.amounts.isEmpty else { return false }
        return line.words.allSatisfy { ReceiptText.isCurrencyWord($0) || ReceiptText.looksNumeric($0) }
    }

    private static func grossCandidates(lines: [ParsedLine], hasDeposit: Bool) -> ([Candidate], String?) {
        var out: [Candidate] = []
        var negativeSource: String?
        for line in lines where !line.amounts.isEmpty {
            let tier = tier(of: line)
            guard tier > 0 else { continue }
            if line.containsAny(excludedForGross) { continue }
            if hasVATWord(line), !isInclusive(line) { continue }
            if tier < 2, line.hasAnyWord(blockWords) { continue }
            let useFirst = line.containsAny(["inkl", "davon"])
            guard let token = useFirst ? line.amounts.first : line.amounts.last else { continue }
            if token.minor < 0 {
                if negativeSource == nil { negativeSource = line.snippet }
                continue
            }
            guard token.minor > 0 else { continue }
            out.append(Candidate(minor: token.minor, tier: tier, line: line))
        }
        return (out, negativeSource)
    }

    private static func netCandidates(lines: [ParsedLine]) -> [Candidate] {
        var out: [Candidate] = []
        for line in lines where !line.amounts.isEmpty {
            guard line.containsAny(["netto", "nettobetrag", "nettosumme"]) else { continue }
            if line.containsAny(["brutto", "zwischensumme"]) || hasVATWord(line) { continue }
            guard let token = line.amounts.last, token.minor > 0 else { continue }
            out.append(Candidate(minor: token.minor, tier: 0, line: line))
        }
        return out
    }

    private static func vatCandidates(lines: [ParsedLine]) -> [Candidate] {
        var out: [Candidate] = []
        for line in lines where !line.amounts.isEmpty && hasVATWord(line) {
            if isInclusive(line) || line.containsAny(["netto"]) { continue }
            guard let token = line.amounts.last, token.minor > 0 else { continue }
            out.append(Candidate(minor: token.minor, tier: 0, line: line))
        }
        return out
    }

    private static func rateValues(lines: [ParsedLine]) -> [(value: Int, source: String)] {
        var seen: [Int: String] = [:]
        for line in lines where hasVATWord(line) {
            for value in ReceiptText.percentValues(in: line.folded) where validRates.contains(value) {
                if seen[value] == nil { seen[value] = line.snippet }
            }
        }
        return seen.keys.sorted().map { (value: $0, source: seen[$0] ?? "") }
    }

    /// A payment line ("Bankomat 89,90") with the same amount.
    private static func corroboratedByPayment(_ minor: Int64, lines: [ParsedLine]) -> Bool {
        lines.contains { line in
            line.hasAnyWord(paymentWords) && !line.containsAny(["gegeben", "ruckgeld"])
                && line.amounts.contains { $0.minor == minor }
        }
    }
}
