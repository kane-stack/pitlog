import Foundation

/// Odometer reading, taken only next to a label (README §6.5, §7).
enum ReceiptOdometer {
    private static let labels = [
        "kilometerstand", "kilometerleistung", "kilometer-stand", "km-stand", "km stand", "kmstand", "laufleistung",
        "tachostand", "odometer", "kilometer",
    ]
    /// Lines about the next service or intervals never carry the current reading.
    private static let rejectedLineMarkers = [
        "nachst", "naechst", "intervall", "spatestens", "fallig", "wieder", "alle ", "empfehl", "next ",
    ]

    static func extract(lines: [ParsedLine], context: ReceiptContext) -> Pick<Int>? {
        var found: [(km: Int, line: ParsedLine)] = []
        for line in lines {
            if line.containsAny(rejectedLineMarkers) { continue }
            var values: [Int] = []
            for label in labels.sorted(by: { $0.count > $1.count }) {
                var searchStart = line.folded.startIndex
                while let range = line.folded.range(of: label, range: searchStart..<line.folded.endIndex) {
                    let tail = String(line.folded[range.upperBound...])
                    if let km = parseNumber(tail), !values.contains(km) { values.append(km) }
                    searchStart = range.upperBound
                }
            }
            // A standalone "km" word followed by the number: "KM 87.456".
            let ws = line.cleanWords
            for (i, w) in ws.enumerated() where w == "km" && i + 1 < line.words.count {
                let tail = line.words[(i + 1)...].joined(separator: " ")
                if let km = parseNumber(tail), !values.contains(km) { values.append(km) }
            }
            for km in values { found.append((km: km, line: line)) }
        }
        let distinct = Set(found.map { $0.km })
        guard distinct.count == 1, let first = found.first else { return nil }
        var confidence = FieldConfidence.high
        if let last = context.lastKnownOdometerKm {
            // Never change the value; only distrust it.
            if first.km < last || first.km > last + 200_000 { confidence = .low }
        }
        if first.km > 500_000, confidence > .low { confidence = .medium }
        return Pick(value: first.km, confidence: confidence, source: first.line.snippet)
    }

    /// The number at the start of `tail` (after `:`, spaces), `87.456`, `87 456`, `87456`, with an
    /// optional `km`. `nil` for anything that looks like part of something else (tyre sizes,
    /// decimals, dates, words).
    static func parseNumber(_ tail: String) -> Int? {
        let c = Array(tail)
        var i = 0
        while i < c.count, c[i] == " " || c[i] == ":" || c[i] == "=" || c[i] == "." || c[i] == "-" { i += 1 }
        var groups: [String] = []
        var genuine = 0
        var confusables = 0
        var end = i
        var j = i
        while j < c.count {
            var group = ""
            var k = j
            while k < c.count, let d = digitOrLookalike(c[k]) {
                group.append(d)
                if ReceiptText.isDigit(c[k]) { genuine += 1 } else { confusables += 1 }
                k += 1
            }
            if group.isEmpty { break }
            if groups.isEmpty {
                groups.append(group)
            } else if group.count == 3, groups.first.map({ $0.count <= 3 }) == true {
                groups.append(group)
            } else {
                break
            }
            end = k
            // a separator (space or dot) followed by another group of exactly three digits
            if k < c.count, c[k] == " " || c[k] == ".", k + 1 < c.count, digitOrLookalike(c[k + 1]) != nil {
                j = k + 1
            } else {
                break
            }
        }
        guard !groups.isEmpty, genuine >= 1, genuine >= confusables else { return nil }
        // What follows the number decides whether it is a reading.
        var p = end
        if p < c.count {
            let next = c[p]
            if next == "/" || next == "," { return nil }
            if next == "-", p + 1 < c.count, ReceiptText.isDigit(c[p + 1]) { return nil }
            if next == ".", p + 1 < c.count, ReceiptText.isDigit(c[p + 1]) { return nil }
        }
        while p < c.count, c[p] == " " { p += 1 }
        if p < c.count, c[p].isLetter {
            // Only "km" may follow.
            guard p + 1 < c.count, c[p] == "k", c[p + 1] == "m" else { return nil }
            if p + 2 < c.count, c[p + 2].isLetter { return nil }
        }
        let digits = groups.joined()
        guard digits.count <= 6, let value = Int(digits), value >= 1 else { return nil }
        return value
    }

    private static func digitOrLookalike(_ c: Character) -> Character? {
        if ReceiptText.isDigit(c) { return c }
        if c == "o" { return "0" }
        if c == "l" { return "1" }
        return nil
    }
}
