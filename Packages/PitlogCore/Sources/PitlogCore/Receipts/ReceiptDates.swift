import Foundation

/// Service date and invoice date (README §5, §6.2, decision E-2).
enum ReceiptDates {
    enum Role {
        case service
        case invoice
        /// "Rechnung vom ...": may also refer to another invoice (credit notes), so it only counts
        /// if no explicit "Datum" exists.
        case invoiceWeak
        /// Due date, order date, acceptance, first registration, "next service" ...: never used.
        case other
    }

    struct Found {
        let date: DayDate
        /// `nil`: no label in front of the date.
        let role: Role?
        let line: ParsedLine
    }

    private static let months: [String: Int] = [
        "jan": 1, "janner": 1, "jaenner": 1, "januar": 1, "jaen": 1,
        "feb": 2, "feber": 2, "februar": 2,
        "mar": 3, "marz": 3, "maerz": 3, "mrz": 3,
        "apr": 4, "april": 4,
        "mai": 5,
        "jun": 6, "juni": 6,
        "jul": 7, "juli": 7,
        "aug": 8, "august": 8,
        "sep": 9, "sept": 9, "september": 9,
        "okt": 10, "oktober": 10, "oct": 10,
        "nov": 11, "november": 11,
        "dez": 12, "dezember": 12, "dec": 12,
    ]

    private static let otherSubstrings = [
        "fallig", "zahlbar", "zahlungsziel", "skonto", "annahme", "auftrag", "termin", "nachst", "naechst",
        "erstzul", "gultig", "angebot", "bestell", "geburt", "ablauf", "fertig", "abhol", "ruckgabe", "zulassung",
        "kostenvoranschlag", "lieferschein", "anzahlung", "akonto",
    ]
    private static let otherWords: Set<String> = ["bis", "ez", "hu", "ab", "ende"]
    private static let serviceSubstrings = ["leistung", "lieferdatum", "lieferung", "ausgefuhrt", "durchgefuhrt", "erbracht"]
    private static let invoiceStrongSubstrings = ["belegdatum", "ausstell"]
    private static let invoiceWeakSubstrings = ["rechnung", "beleg", "kassenbon"]

    // MARK: Words

    /// Words of the line with ":" treated as a separator and OCR digit confusions repaired in
    /// date-like words.
    static func dateWords(_ line: ParsedLine) -> [String] {
        let spaced = line.folded.replacingOccurrences(of: ":", with: " ")
        return ReceiptText.words(spaced).map { normalizeNumericWord($0) }
    }

    /// "O5.1O.2O26" -> "05.10.2026": only words made of digits, separators and OCR look-alikes,
    /// with at least two real digits.
    private static func normalizeNumericWord(_ w: String) -> String {
        var genuine = 0
        var separators = 0
        var out = ""
        for ch in w {
            if ReceiptText.isDigit(ch) {
                genuine += 1
                out.append(ch)
            } else if ch == "." || ch == "/" || ch == "-" {
                separators += 1
                out.append(ch)
            } else if let mapped = ReceiptText.ocrDigit(ch), ch != "i" {
                out.append(mapped)
            } else {
                return w
            }
        }
        return genuine >= 2 && separators >= 1 ? out : w
    }

    // MARK: Scanning

    static func scan(_ ws: [String]) -> [(date: DayDate, index: Int)] {
        var out: [(date: DayDate, index: Int)] = []
        var i = 0
        while i < ws.count {
            if let date = parseNumericDate(ws[i]) {
                out.append((date: date, index: i))
                i += 1
            } else if let named = parseNamedDate(ws, i) {
                out.append((date: named.date, index: i))
                i += named.used
            } else {
                i += 1
            }
        }
        return out
    }

    private static func trimmed(_ w: String) -> String {
        w.trimmingCharacters(in: CharacterSet(charactersIn: ",;()"))
    }

    /// `05.10.2026`, `5.10.2026`, `05.10.26`, `2026-10-05`, `05/10/2026`.
    static func parseNumericDate(_ raw: String) -> DayDate? {
        let word = trimmed(raw)
        let hasDot = word.contains(".")
        let hasSlash = word.contains("/")
        let hasDash = word.contains("-")
        let separator: Character
        if hasDot, !hasSlash, !hasDash {
            separator = "."
        } else if hasSlash, !hasDot, !hasDash {
            separator = "/"
        } else if hasDash, !hasDot, !hasSlash {
            separator = "-"
        } else {
            return nil
        }
        let parts = word.split(separator: separator, omittingEmptySubsequences: true).map { String($0) }
        guard parts.count == 3, parts.allSatisfy({ ReceiptText.allDigits($0) }) else { return nil }
        if parts[0].count == 4 {
            guard parts[1].count <= 2, parts[2].count <= 2,
                let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
            else { return nil }
            return DayDate(year: y, month: m, day: d)
        }
        // A dash only separates ISO dates; "12-34-56" is more likely an article number.
        guard separator != "-", parts[0].count <= 2, parts[1].count <= 2,
            parts[2].count == 4 || parts[2].count == 2,
            let d = Int(parts[0]), let m = Int(parts[1]), let y = Int(parts[2])
        else { return nil }
        return DayDate(year: parts[2].count == 2 ? 2000 + y : y, month: m, day: d)
    }

    private static func yearValue(_ s: String) -> Int? {
        guard ReceiptText.allDigits(s) else { return nil }
        if s.count == 4 { return Int(s) }
        if s.count == 2, let v = Int(s) { return 2000 + v }
        return nil
    }

    private static func isDay(_ s: String) -> Bool {
        ReceiptText.allDigits(s) && s.count <= 2
    }

    /// `5. Jän. 2027`, `5.Okt.2026`, `12 Feber 27`.
    private static func parseNamedDate(_ ws: [String], _ i: Int) -> (date: DayDate, used: Int)? {
        let word = trimmed(ws[i])
        let parts = word.split(separator: ".", omittingEmptySubsequences: true).map { String($0) }
        if parts.count == 3, isDay(parts[0]), let m = months[parts[1]], let y = yearValue(parts[2]),
            let d = Int(parts[0]), let date = DayDate(year: y, month: m, day: d)
        {
            return (date: date, used: 1)
        }
        if parts.count == 2, isDay(parts[0]), let m = months[parts[1]], i + 1 < ws.count,
            let y = yearValue(trimmed(ws[i + 1])), let d = Int(parts[0]), let date = DayDate(year: y, month: m, day: d)
        {
            return (date: date, used: 2)
        }
        if parts.count == 1, isDay(parts[0]), i + 2 < ws.count {
            let monthWord = trimmed(ws[i + 1]).trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if let m = months[monthWord], let y = yearValue(trimmed(ws[i + 2])), let d = Int(parts[0]),
                let date = DayDate(year: y, month: m, day: d)
            {
                return (date: date, used: 3)
            }
        }
        return nil
    }

    /// Month and year only: `10/2027`, `10.2027`, `10/27`, `2027-10`, `Okt 2027`, `Oktober 2027`.
    static func scanMonthYear(_ ws: [String]) -> [YearMonth] {
        var out: [YearMonth] = []
        for (i, raw) in ws.enumerated() {
            let word = trimmed(raw)
            if let named = months[word.trimmingCharacters(in: CharacterSet(charactersIn: "."))], i + 1 < ws.count,
                let y = yearValue(trimmed(ws[i + 1])), let ym = YearMonth(year: y, month: named)
            {
                out.append(ym)
                continue
            }
            for separator: Character in ["/", ".", "-"] {
                let parts = word.split(separator: separator, omittingEmptySubsequences: true).map { String($0) }
                guard parts.count == 2, parts.allSatisfy({ ReceiptText.allDigits($0) }) else { continue }
                if parts[0].count == 4, parts[1].count <= 2, let y = Int(parts[0]), let m = Int(parts[1]),
                    let ym = YearMonth(year: y, month: m)
                {
                    out.append(ym)
                } else if parts[0].count <= 2, parts[1].count == 4 || (parts[1].count == 2 && separator == "/"),
                    let m = Int(parts[0]), let y = yearValue(parts[1]), let ym = YearMonth(year: y, month: m)
                {
                    out.append(ym)
                }
            }
        }
        return out
    }

    // MARK: Roles

    static func role(ofWord w: String) -> Role? {
        let c = ReceiptText.cleanWord(w)
        guard !c.isEmpty else { return nil }
        if otherWords.contains(c) || otherSubstrings.contains(where: { c.contains($0) }) { return .other }
        if serviceSubstrings.contains(where: { c.contains($0) }) { return .service }
        if c == "datum" || c.hasSuffix("datum") || invoiceStrongSubstrings.contains(where: { c.contains($0) }) {
            return .invoice
        }
        if invoiceWeakSubstrings.contains(where: { c.contains($0) }) { return .invoiceWeak }
        return nil
    }

    /// Role of the nearest label before the date in the same line (at most 6 words back, not
    /// across another date).
    private static func role(forDateAt index: Int, words ws: [String], dateIndices: Set<Int>) -> Role? {
        var j = index - 1
        var steps = 0
        while j >= 0, steps < 6 {
            if dateIndices.contains(j) { return nil }
            if let found = role(ofWord: ws[j]) { return found }
            j -= 1
            steps += 1
        }
        return nil
    }

    static func find(lines: [ParsedLine]) -> [Found] {
        var out: [Found] = []
        for line in lines {
            let ws = dateWords(line)
            let dates = scan(ws)
            let indices = Set(dates.map { $0.index })
            for entry in dates {
                let labelRole = role(forDateAt: entry.index, words: ws, dateIndices: indices)
                out.append(Found(date: entry.date, role: labelRole, line: line))
            }
        }
        return out
    }

    // MARK: Selection

    static func isPlausible(_ date: DayDate, context: ReceiptContext) -> Bool {
        guard date <= context.today, date.year >= 1990 else { return false }
        if let first = context.firstRegistration, date < first.firstDay { return false }
        return true
    }

    private static func unique(_ list: [Found], confidence: FieldConfidence) -> Pick<DayDate>? {
        guard let first = list.first, Set(list.map { $0.date }).count == 1 else { return nil }
        return Pick(value: first.date, confidence: confidence, source: first.line.snippet)
    }

    static func select(
        found: [Found], context: ReceiptContext
    ) -> (service: Pick<DayDate>?, invoice: Pick<DayDate>?) {
        let plausible = found.filter { isPlausible($0.date, context: context) }
        let service = unique(plausible.filter { $0.role == .service }, confidence: .high)
        var invoice = unique(plausible.filter { $0.role == .invoice }, confidence: .high)
        if !plausible.contains(where: { $0.role == .invoice }) {
            invoice = unique(plausible.filter { $0.role == .invoiceWeak }, confidence: .medium)
        }
        if invoice == nil, !plausible.contains(where: { $0.role == .invoice || $0.role == .invoiceWeak }) {
            let unlabeled = plausible.filter { $0.role == nil }
            let withTime = unlabeled.filter { $0.line.hasClockTime }
            if !withTime.isEmpty {
                invoice = unique(withTime, confidence: .medium)
            } else {
                invoice = unique(unlabeled, confidence: .low)
            }
        }
        return (service, invoice)
    }
}
