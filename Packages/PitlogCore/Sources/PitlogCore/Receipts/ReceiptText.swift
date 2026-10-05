import Foundation

/// A value together with how sure the parser is and where it came from.
struct Pick<Value: Sendable>: Sendable {
    let value: Value
    let confidence: FieldConfidence
    let source: String
}

/// An amount found in a line, in minor units (negative for credits).
struct AmountToken: Hashable, Sendable {
    let minor: Int64
    /// Index into `ParsedLine.words`.
    let wordIndex: Int
    /// A currency marker (€, EUR, ...) directly next to the number.
    let hasCurrency: Bool
}

/// A receipt line with its folded text and the amounts in it, computed once.
struct ParsedLine: Sendable {
    let index: Int
    let original: String
    /// Lower case, umlauts and ß replaced, dashes and no-break spaces normalized.
    let folded: String
    /// Words of `folded`.
    let words: [String]
    let hasClockTime: Bool
    /// Amounts with "1 234,56" (space as thousands separator) merged into one amount.
    let amounts: [AmountToken]
    /// Amounts without merging; used for positions, where "2 120,00" means quantity 2.
    let itemAmounts: [AmountToken]

    init(index: Int, original: String) {
        let f = ReceiptText.fold(original)
        self.index = index
        self.original = original
        self.folded = f
        self.words = ReceiptText.words(f)
        self.hasClockTime = ReceiptText.hasClockTime(f)
        self.amounts = ReceiptText.amounts(inFolded: f, mergeThousands: true)
        self.itemAmounts = ReceiptText.amounts(inFolded: f, mergeThousands: false)
    }

    var snippet: String { ReceiptText.snippet(original) }

    /// The words without surrounding punctuation.
    var cleanWords: [String] { words.map { ReceiptText.cleanWord($0) } }

    func hasAnyWord(_ set: Set<String>) -> Bool {
        cleanWords.contains { set.contains($0) }
    }

    func containsAny(_ needles: [String]) -> Bool {
        ReceiptText.containsAny(folded, needles)
    }
}

enum ReceiptText {
    // MARK: Folding and words

    private static let foldingTable: [(String, String)] = [
        ("ä", "a"), ("ö", "o"), ("ü", "u"), ("ß", "ss"), ("é", "e"), ("è", "e"),
        ("–", "-"), ("—", "-"), ("−", "-"), ("\u{00A0}", " "), ("\u{2009}", " "), ("\u{202F}", " "),
        ("\t", " "),
    ]

    static func fold(_ text: String) -> String {
        var s = text.lowercased()
        for (from, to) in foldingTable where s.contains(from) {
            s = s.replacingOccurrences(of: from, with: to)
        }
        return s
    }

    static func words(_ s: String) -> [String] {
        s.split(separator: " ", omittingEmptySubsequences: true).map { String($0) }
    }

    static func cleanWord(_ w: String) -> String {
        w.trimmingCharacters(in: CharacterSet(charactersIn: ".,:;()[]\"'"))
    }

    static func isDigit(_ c: Character) -> Bool {
        guard let a = c.asciiValue else { return false }
        return a >= 48 && a <= 57
    }

    static func allDigits(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { isDigit($0) }
    }

    static func containsAny(_ s: String, _ needles: [String]) -> Bool {
        needles.contains { s.contains($0) }
    }

    static func snippet(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.count > 100 ? String(t.prefix(100)) + "…" : t
    }

    /// "dd:dd" somewhere in the line (a time of day, as on cash register receipts).
    static func hasClockTime(_ s: String) -> Bool {
        let c = Array(s)
        guard c.count >= 5 else { return false }
        for i in 0...(c.count - 5) {
            if isDigit(c[i]), isDigit(c[i + 1]), c[i + 2] == ":", isDigit(c[i + 3]), isDigit(c[i + 4]) {
                return true
            }
        }
        return false
    }

    /// Maps characters OCR commonly reads instead of digits. Only meant for words that are
    /// otherwise numeric.
    static func ocrDigit(_ c: Character) -> Character? {
        if isDigit(c) { return c }
        switch c {
        case "o": return "0"
        case "l", "i", "|": return "1"
        case "s": return "5"
        case "b": return "8"
        default: return nil
        }
    }

    // MARK: Amounts

    private static let strongCurrencyWords: Set<String> = ["€", "eur", "euro", "eur."]
    private static let weakCurrencyWords: Set<String> = ["e", "c", "e.", "c."]
    private static let unitWords: Set<String> = [
        "stk", "stk.", "st", "st.", "l", "ltr", "liter", "std", "std.", "h", "aw", "x", "pcs", "km", "kg", "mm",
    ]

    /// All amounts in a folded line. Formats: `1.234,56`, `1 234,56`, `1234,56`, `120,-`, `€ 123,45`,
    /// `123,45 EUR`, `-12,50`, `12,50-`, `(12,50)`, with OCR confusions (O/0, l/1, S/5, B/8, € as E/C).
    /// Integers without decimals count only next to a currency symbol.
    static func amounts(inFolded folded: String, mergeThousands: Bool) -> [AmountToken] {
        let ws = words(folded)
        var result: [AmountToken] = []
        var i = 0
        while i < ws.count {
            let word = ws[i]
            if strongCurrencyWords.contains(word) || weakCurrencyWords.contains(word) {
                i += 1
                continue
            }
            var core = word
            var consumed = 1
            if mergeThousands, i + 1 < ws.count, isGroupHead(word), isThousandTail(ws[i + 1]) {
                core = word + ws[i + 1]
                consumed = 2
            }
            let stripped = stripCurrency(core)
            let nextIndex = i + consumed
            let strongBefore = i > 0 && strongCurrencyWords.contains(ws[i - 1])
            let strongAfter = nextIndex < ws.count && strongCurrencyWords.contains(ws[nextIndex])
            let weakBefore = i > 0 && weakCurrencyWords.contains(ws[i - 1])
            let weakAfter = nextIndex < ws.count && weakCurrencyWords.contains(ws[nextIndex])
            let strong = stripped.strong || strongBefore || strongAfter
            let marker = strong || stripped.letter || weakBefore || weakAfter
            if nextIndex < ws.count {
                let next = ws[nextIndex]
                if next.hasPrefix("%") || unitWords.contains(next) {
                    i += consumed
                    continue
                }
            }
            if let minor = parseAmount(stripped.core, allowInteger: strong) {
                result.append(AmountToken(minor: minor, wordIndex: i, hasCurrency: marker))
            }
            i += consumed
        }
        return result
    }

    private static func isGroupHead(_ w: String) -> Bool {
        allDigits(w) && w.count <= 3
    }

    /// "234,56", "234.56", "234,-": the rest of "1 234,56".
    private static func isThousandTail(_ s: String) -> Bool {
        let c = Array(s)
        guard c.count >= 5, c[0..<3].allSatisfy({ isDigit($0) }) else { return false }
        let rest = String(c[3...])
        if rest.count == 3, rest.first == "," || rest.first == ".", rest.dropFirst().allSatisfy({ isDigit($0) }) {
            return true
        }
        return rest == ",-" || rest == ",--"
    }

    private static func stripCurrency(_ word: String) -> (core: String, strong: Bool, letter: Bool) {
        var s = word
        var strong = false
        var letter = false
        for prefix in ["€", "euro", "eur"] where s.hasPrefix(prefix) && s.count > prefix.count {
            s.removeFirst(prefix.count)
            strong = true
            break
        }
        if !strong, let first = s.first, first == "e" || first == "c", s.count >= 4,
            let second = s.dropFirst().first, isDigit(second)
        {
            s.removeFirst()
            letter = true
        }
        for suffix in ["€", "euro", "eur"] where s.hasSuffix(suffix) && s.count > suffix.count {
            s.removeLast(suffix.count)
            strong = true
            break
        }
        if let last = s.last, last == "e" || last == "c", s.count >= 4,
            let previous = s.dropLast().last, isDigit(previous)
        {
            s.removeLast()
            letter = true
        }
        return (s, strong, letter)
    }

    /// One amount word (without currency marker) in minor units; `nil` if it is not an amount.
    static func parseAmount(_ raw: String, allowInteger: Bool) -> Int64? {
        var s = raw
        while s.hasSuffix(".") || s.hasSuffix(";") || s.hasSuffix(":") { s.removeLast() }
        guard !s.isEmpty else { return nil }
        var negative = false
        if s.hasPrefix("("), s.hasSuffix(")"), s.count > 2 {
            negative = true
            s = String(s.dropFirst().dropLast())
        }
        if s.hasPrefix("-") {
            negative = true
            s.removeFirst()
        }
        var dashCents = false
        for suffix in [",--", ",-", ".--", ".-"] where s.hasSuffix(suffix) {
            s.removeLast(suffix.count)
            dashCents = true
            break
        }
        if !dashCents, s.count > 1, s.hasSuffix("-") {
            negative = true
            s.removeLast()
        }
        var chars: [Character] = []
        var genuine = 0
        var confusables = 0
        for ch in s {
            if isDigit(ch) {
                chars.append(ch)
                genuine += 1
            } else if ch == "," || ch == "." {
                chars.append(ch)
            } else if let mapped = ocrDigit(ch) {
                chars.append(mapped)
                confusables += 1
            } else {
                return nil
            }
        }
        guard genuine >= 1, genuine >= confusables else { return nil }
        let text = String(chars)
        let integerPart: String
        var cents: Int64 = 0
        if dashCents {
            integerPart = text
        } else if let sep = text.lastIndex(where: { $0 == "," || $0 == "." }) {
            let after = String(text[text.index(after: sep)...])
            if after.count == 2 {
                guard let c = Int64(after) else { return nil }
                cents = c
                integerPart = String(text[..<sep])
            } else if after.count == 3, allowInteger {
                integerPart = text
            } else {
                return nil
            }
        } else {
            guard allowInteger else { return nil }
            integerPart = text
        }
        guard let whole = groupedInteger(integerPart) else { return nil }
        let minor = whole * 100 + cents
        return negative ? -minor : minor
    }

    /// "1.234", "1,234", "1234", "12": digits with consistent 3-digit groups.
    private static func groupedInteger(_ s: String) -> Int64? {
        guard !s.isEmpty else { return nil }
        let separators = s.filter { $0 == "," || $0 == "." }
        if separators.isEmpty {
            return s.count <= 9 ? Int64(s) : nil
        }
        guard Set(separators).count == 1, let separator = separators.first else { return nil }
        let groups = s.split(separator: separator, omittingEmptySubsequences: false).map { String($0) }
        guard let head = groups.first, (1...3).contains(head.count) else { return nil }
        for group in groups.dropFirst() where group.count != 3 { return nil }
        let joined = groups.joined()
        return joined.count <= 9 ? Int64(joined) : nil
    }

    static func currencyCode(in lines: [ParsedLine]) -> String {
        let table: [(String, String)] = [("chf", "CHF"), ("gbp", "GBP"), ("usd", "USD"), ("huf", "HUF"), ("pln", "PLN"), ("czk", "CZK")]
        for line in lines {
            let ws = line.cleanWords
            for (word, code) in table where ws.contains(word) { return code }
        }
        return "EUR"
    }

    // MARK: Percentages

    /// Values of all "20 %", "20%", "20,00 %" in a folded line.
    static func percentValues(in folded: String) -> [Int] {
        let c = Array(folded)
        var out: [Int] = []
        for (i, ch) in c.enumerated() where ch == "%" {
            var j = i - 1
            while j >= 0, c[j] == " " { j -= 1 }
            var digits: [Character] = []
            while j >= 0, isDigit(c[j]) || c[j] == "," || c[j] == "." {
                digits.insert(c[j], at: 0)
                j -= 1
            }
            let parts = String(digits).split(whereSeparator: { $0 == "," || $0 == "." }).map { String($0) }
            guard let first = parts.first, first.count <= 2, let value = Int(first) else { continue }
            let allZero = parts.dropFirst().allSatisfy { part in part.allSatisfy { $0 == "0" } }
            guard allZero else { continue }
            out.append(value)
        }
        return out
    }
}
