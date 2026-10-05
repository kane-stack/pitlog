import Foundation

/// Austrian VAT ID ("UID", `ATU` + 8 digits).
public enum AustrianUID {
    /// Check of the last digit.
    ///
    /// ASSUMPTION: the algorithm is reproduced from the widely used python-stdnum implementation
    /// (digits 1 to 7 weighted 1,2,1,2,1,2,1, digit sums of the products, check digit =
    /// (96 - sum) mod 10), not from a primary source (README, open point 3: BMF). The parser therefore
    /// only uses it to rate the confidence, never to reject a UID.
    /// TODO: confirm against the BMF specification.
    public static func isChecksumValid(_ uid: String) -> Bool {
        let compact = uid.uppercased().filter { !$0.isWhitespace }
        guard compact.hasPrefix("ATU") else { return false }
        let digits = compact.dropFirst(3).compactMap { $0.wholeNumberValue }
        guard digits.count == 8, compact.count == 11 else { return false }
        var sum = 0
        for (i, d) in digits.prefix(7).enumerated() {
            if i % 2 == 0 {
                sum += d
            } else {
                let p = d * 2
                sum += p > 9 ? p - 9 : p
            }
        }
        return (96 - sum) % 10 == digits[7]
    }
}

/// Plate, VIN, UID and workshop name (README §6.3, §6.4, §6.6).
enum ReceiptIdentifiers {
    // MARK: Plate

    private static let plateLabels = ["kennzeichen", "kennz", "kz", "nummerntafel"]
    private static let plateSuffixStoplist: Set<String> = ["km", "kw", "ps", "kg", "ccm", "fin", "vin", "uid", "fn", "tel", "nr"]

    static func plate(lines: [ParsedLine], context: ReceiptContext) -> Pick<String>? {
        let known = context.knownPlates.map { ($0, compact($0)) }.filter { $0.1.count >= 4 }
        for line in lines {
            let text = compact(line.original)
            for (original, normalized) in known where text.contains(normalized) {
                return Pick(value: original, confidence: .high, source: line.snippet)
            }
        }
        var found: [(plate: String, line: ParsedLine)] = []
        for line in lines {
            let ws = line.cleanWords
            for (i, w) in ws.enumerated() {
                guard plateLabels.contains(where: { w == $0 || w.hasPrefix($0 + "-") || (w.hasPrefix("kennz") && w != "kennzahl") })
                else { continue }
                let following = Array(ws[(i + 1)...].prefix(3))
                if let plate = plateFrom(words: following) { found.append((plate: plate, line: line)) }
            }
        }
        let distinct = Set(found.map { $0.plate })
        guard distinct.count == 1, let first = found.first else { return nil }
        return Pick(value: first.plate, confidence: .high, source: first.line.snippet)
    }

    private static func compact(_ s: String) -> String {
        String(s.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func isLetters(_ s: String, _ range: ClosedRange<Int>) -> Bool {
        range.contains(s.count) && s.allSatisfy { $0.isASCII && $0.isLetter }
    }

    private static func isDigits(_ s: String, _ range: ClosedRange<Int>) -> Bool {
        range.contains(s.count) && ReceiptText.allDigits(s)
    }

    /// Letters (1 to 2), digits (1 to 5), letters (1 to 3), e.g. `w12345a`.
    private static func splitPlate(_ s: String) -> (String, String, String)? {
        let c = Array(s)
        var i = 0
        var prefix = ""
        while i < c.count, c[i].isASCII, c[i].isLetter { prefix.append(c[i]); i += 1 }
        var digits = ""
        while i < c.count, ReceiptText.isDigit(c[i]) { digits.append(c[i]); i += 1 }
        var suffix = ""
        while i < c.count, c[i].isASCII, c[i].isLetter { suffix.append(c[i]); i += 1 }
        guard i == c.count, isLetters(prefix, 1...2), isDigits(digits, 1...5), isLetters(suffix, 1...3),
            !plateSuffixStoplist.contains(suffix)
        else { return nil }
        return (prefix, digits, suffix)
    }

    /// `W 12345 A`, `W-12345A`, `W-12345 A`, `W 12345A` (words after the label).
    private static func plateFrom(words w: [String]) -> String? {
        func plain(_ s: String) -> String { s.replacingOccurrences(of: "-", with: "") }
        var parts: (String, String, String)?
        if w.count >= 3, isLetters(w[0], 1...2), isDigits(w[1], 1...5), isLetters(w[2], 1...3),
            !plateSuffixStoplist.contains(w[2])
        {
            parts = (w[0], w[1], w[2])
        }
        if parts == nil, w.count >= 2 {
            let a = plain(w[0])
            let b = plain(w[1])
            let boundaryOK = (isLetters(a, 1...2) && (b.first.map { ReceiptText.isDigit($0) } ?? false))
                || (a.last.map { ReceiptText.isDigit($0) } ?? false) && isLetters(b, 1...3)
            if boundaryOK { parts = splitPlate(a + b) }
        }
        if parts == nil, w.count >= 1 {
            parts = splitPlate(plain(w[0]))
        }
        guard let parts else { return nil }
        return "\(parts.0.uppercased()) \(parts.1) \(parts.2.uppercased())"
    }

    // MARK: VIN

    private static let vinLabels = ["fin", "vin", "fgst", "fgst.", "fahrgestell", "fahrgestellnummer", "fgstnr"]

    static func vin(lines: [ParsedLine], context: ReceiptContext) -> Pick<String>? {
        let known = Set(context.knownVINs.map { $0.uppercased() })
        var found: [(vin: String, confidence: FieldConfidence, line: ParsedLine)] = []
        for line in lines {
            let labelled = line.cleanWords.contains { w in vinLabels.contains(w) || w.hasPrefix("fahrgestell") || w.hasPrefix("fgst") }
            for raw in line.words {
                let word = ReceiptText.cleanWord(raw).uppercased()
                guard word.count == 17, word.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { continue }
                var vin = ""
                var substituted = false
                for ch in word {
                    switch ch {
                    case "O", "Q": vin.append("0"); substituted = true
                    case "I": vin.append("1"); substituted = true
                    default: vin.append(ch)
                    }
                }
                let letters = vin.filter { $0.isLetter }.count
                let numbers = vin.filter { $0.isNumber }.count
                guard letters >= 2, numbers >= 3 else { continue }
                var confidence: FieldConfidence = labelled ? .high : .medium
                if substituted { confidence = .low }
                if known.contains(vin) || known.contains(word) { confidence = .high }
                found.append((vin: known.contains(word) ? word : vin, confidence: confidence, line: line))
            }
        }
        let distinct = Set(found.map { $0.vin })
        guard distinct.count == 1, let first = found.first else { return nil }
        let best = found.map { $0.confidence }.max() ?? first.confidence
        return Pick(value: first.vin, confidence: best, source: first.line.snippet)
    }

    // MARK: UID

    private static let customerMarkers = [
        "kunde", "kunden", "empfanger", "auftraggeber", "ihre uid", "ihre ust", "ihr uid", "ihre steuer", "rechnungsempf",
    ]

    /// All `ATU` + 8 digits in a folded line, compact ("ATU12345678"), tolerating spaces and OCR confusions.
    static func uids(in line: ParsedLine) -> [String] {
        let c = Array(line.folded)
        var out: [String] = []
        var i = 0
        while i + 2 < c.count {
            if c[i] == "a", c[i + 1] == "t", c[i + 2] == "u", i == 0 || !c[i - 1].isLetter {
                var j = i + 3
                var digits = ""
                var steps = 0
                while j < c.count, digits.count < 8, steps < 14 {
                    if let d = ReceiptText.ocrDigit(c[j]) {
                        digits.append(d)
                    } else if c[j] == " " || c[j] == "." || c[j] == "-" {
                        // separators between digit groups
                    } else {
                        break
                    }
                    j += 1
                    steps += 1
                }
                if digits.count == 8, !(j < c.count && ReceiptText.isDigit(c[j])) {
                    out.append("ATU" + digits)
                    i = j
                    continue
                }
            }
            i += 1
        }
        return out
    }

    /// The workshop's UID. A UID on a customer line (or any second UID) is the customer's.
    static func workshopUID(lines: [ParsedLine]) -> Pick<String>? {
        var own: [(uid: String, labelled: Bool, line: ParsedLine)] = []
        for line in lines {
            let found = uids(in: line)
            guard !found.isEmpty else { continue }
            if line.containsAny(customerMarkers) { continue }
            let labelled = line.hasAnyWord(["uid", "ust-id", "ustid", "uid-nr", "uid-nummer", "ust-idnr"]) || line.containsAny(["uid", "ust-id"])
            for uid in found { own.append((uid: uid, labelled: labelled, line: line)) }
        }
        let distinct = Set(own.map { $0.uid })
        guard let first = own.first else { return nil }
        if distinct.count > 1 { return nil }
        let labelled = own.contains { $0.labelled }
        var confidence: FieldConfidence = labelled ? .high : .medium
        if !AustrianUID.isChecksumValid(first.uid) { confidence = min(confidence, .medium) }
        return Pick(value: first.uid, confidence: confidence, source: first.line.snippet)
    }

    // MARK: Workshop name

    private static let legalFormWords: Set<String> = [
        "gmbh", "ges.m.b.h.", "ges.m.b.h", "gesmbh", "e.u.", "e.u", "kg", "og", "ag", "co", "co.", "kg.", "og.", "gesellschaft",
    ]
    private static let digitSensitiveForms: Set<String> = ["kg", "og", "ag", "kg.", "og."]
    private static let automotiveKeywords = [
        "kfz", "auto", "werkstatt", "garage", "motor", "reifen", "karosserie", "fahrzeug", "tankstelle", "pickerl", "lackier",
        "service",
    ]
    private static let blockedFirstWords: Set<String> = [
        "rechnung", "herr", "herrn", "frau", "familie", "kunde", "kundin", "gutschrift", "kassenbon", "beleg", "datum",
        "kennzeichen", "kennz", "fin", "tel", "uid", "seite", "www", "iban", "bic", "bank", "fn", "an", "pos", "nr",
        "bon", "leistung", "nachstes", "nachste", "nachster", "plakette", "pickerl",
    ]
    private static let nameSeparators = [
        "·", "|", "•", " - ", " – ", " — ", ",", " tel.", " tel:", " tel ", " fax", " uid", " fn ", " e-mail", " www", "  ",
    ]
    private static let customerLineMarkers = ["herrn", "frau ", "familie", "kunde", "empfanger", "auftraggeber", "an:"]

    private struct NameCandidate {
        let name: String
        let score: Int
        let line: ParsedLine
    }

    static func workshopName(lines: [ParsedLine]) -> Pick<String>? {
        var candidates: [NameCandidate] = []
        for line in lines where line.amounts.isEmpty {
            let name = cutName(line.original)
            guard name.count >= 4, name.contains(where: { $0.isLetter }) else { continue }
            let folded = ReceiptText.fold(name)
            let firstWord = ReceiptText.cleanWord(ReceiptText.words(folded).first ?? "")
            if blockedFirstWords.contains(firstWord) || firstWord.hasPrefix("rechnung") { continue }
            if name.contains(":") { continue }
            if line.containsAny(customerLineMarkers) { continue }
            var score = 0
            let words = ReceiptText.words(folded)
            let hasDigits = name.contains { ReceiptText.isDigit($0) }
            let legal = words.contains { w in
                let cleaned = w.trimmingCharacters(in: CharacterSet(charactersIn: ",;()"))
                return legalFormWords.contains(cleaned) && !(digitSensitiveForms.contains(cleaned) && hasDigits)
            }
            if legal { score += 2 }
            if ReceiptText.containsAny(folded, automotiveKeywords) { score += 2 }
            if line.index < 6 { score += 1 }
            if score >= 2, legal || line.index < 8 { candidates.append(NameCandidate(name: name, score: score, line: line)) }
        }
        guard let top = candidates.max(by: { $0.score < $1.score }) else { return nil }
        let rivals = candidates.filter { $0.score == top.score && $0.name != top.name }
        guard rivals.isEmpty else { return nil }
        return Pick(value: top.name, confidence: top.score >= 4 ? .high : .medium, source: top.line.snippet)
    }

    /// The name part of a header line: cut at address, phone, UID etc.
    private static func cutName(_ original: String) -> String {
        let text = original.trimmingCharacters(in: .whitespacesAndNewlines)
        var cut = text.endIndex
        for separator in nameSeparators {
            if let range = text.range(of: separator, options: .caseInsensitive), range.lowerBound < cut {
                cut = range.lowerBound
            }
        }
        return String(text[..<cut]).trimmingCharacters(in: CharacterSet(charactersIn: " ,;:|·•–—-"))
    }
}
