import Foundation

/// Finds the customer's name and address on a receipt, so the stored recognized text does not contain them.
///
/// The extractors read the full text (they need the customer lines to tell the workshop from the customer); only
/// what is kept with the receipt is stripped. Heuristic: lines that start a customer block (`Kunde:`,
/// `Rechnungsempfänger`, `Herrn`, `Frau`, `Familie`) go, together with up to three address-like lines after a
/// label-only anchor, and the lines above a customer's VAT ID. Vehicle lines, dates and amounts stay.
enum CustomerBlock {
    /// Indices of the lines that belong to the customer.
    static func indices(in lines: [String]) -> Set<Int> {
        let folded = lines.map(fold)
        var block: Set<Int> = []
        for (index, line) in folded.enumerated() {
            let words = line.split(whereSeparator: { $0 == " " }).map { clean(String($0)) }
            guard let first = words.first else { continue }

            if customerUID(line) {
                block.insert(index)
                for above in stride(from: index - 1, through: max(0, index - 3), by: -1) {
                    guard addressLike(folded[above]) else { break }
                    block.insert(above)
                }
                continue
            }
            if recipientLabels.contains(first) || line.contains("rechnungsempf") || line.contains("auftraggeber") {
                block.insert(index)
                // A label with the name behind it ("Kunde: Elisabeth Moosbrugger, Alpenstr. 9") is one line;
                // a bare label is followed by the address lines.
                if words.count == 1 { markFollowing(after: index, in: folded, into: &block) }
            } else if salutations.contains(first) {
                block.insert(index)
                markFollowing(after: index, in: folded, into: &block)
            }
        }
        return block
    }

    static func removing(from lines: [String]) -> [String] {
        let block = indices(in: lines)
        return lines.enumerated().filter { !block.contains($0.offset) }.map(\.element)
    }

    // MARK: Rules

    private static let recipientLabels: Set<String> = [
        "kunde", "kundin", "kunden", "empfaenger", "rechnungsempfaenger", "auftraggeber", "kundenadresse",
        "kundennr", "kunden-nr", "kundennummer",
    ]
    private static let salutations: Set<String> = ["herr", "herrn", "frau", "familie"]
    /// Words that mark a receipt's own field line, which is never part of an address.
    private static let stopWords: Set<String> = [
        "km", "pos", "pos.", "vin", "fin", "uid", "ust", "mwst", "tel", "tel.", "fax", "mail", "www", "iban", "fn",
        "total", "netto", "brutto", "bar", "bon", "beleg", "kassa", "ihre", "kz", "kz.", "atu",
    ]
    private static let stopPrefixes = [
        "rechnung", "datum", "kennz", "fahrzeug", "fahrgest", "auftrag", "summe", "gesamt", "betrag", "telefon",
        "zahlbar", "leistung", "position", "kassenbon", "e-mail",
    ]

    private static func markFollowing(after index: Int, in lines: [String], into block: inout Set<Int>) {
        var taken = 0
        var next = index + 1
        while taken < 3, next < lines.count, addressLike(lines[next]) {
            block.insert(next)
            taken += 1
            next += 1
        }
    }

    /// A customer's UID: a VAT ID on a line that names the customer ("UID-Nr. Kunde:", "Ihre UID").
    private static func customerUID(_ line: String) -> Bool {
        guard line.contains("atu") || line.contains("uid") || line.contains("ust-id") else { return false }
        return line.contains("kunde") || line.contains("ihre uid") || line.contains("ihre ust")
            || line.contains("ihr uid") || line.contains("empfaenger")
    }

    /// Short, no label, no amount, not one of the receipt's own fields: a name or an address line.
    private static func addressLike(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 48, !trimmed.contains(":") else { return false }
        for word in trimmed.split(separator: " ").map({ clean(String($0)) }) {
            if stopWords.contains(word) || stopPrefixes.contains(where: { word.hasPrefix($0) }) { return false }
        }
        if hasAmount(trimmed) { return false }
        return trimmed.contains { $0.isLetter }
    }

    /// "12,50" or "1.234,00": digits, a separator and two digits.
    private static func hasAmount(_ text: String) -> Bool {
        let characters = Array(text)
        guard characters.count >= 4 else { return false }
        for index in 1..<(characters.count - 2) where characters[index] == "," || characters[index] == "." {
            if characters[index - 1].isASCIIDigit, characters[index + 1].isASCIIDigit, characters[index + 2].isASCIIDigit {
                let rest = characters.dropFirst(index + 1).prefix(3)
                // 12,50 (two digits) is an amount; 1.234 or a street number like "9" is not.
                if rest.count < 3 || !(rest.last?.isASCIIDigit ?? false) { return true }
            }
        }
        return false
    }

    private static func fold(_ text: String) -> String {
        var result = text.lowercased()
        for (from, to) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")] {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result.replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private static func clean(_ word: String) -> String {
        word.trimmingCharacters(in: CharacterSet(charactersIn: ".,:;()"))
    }
}

private extension Character {
    var isASCIIDigit: Bool {
        guard let value = asciiValue else { return false }
        return value >= 48 && value <= 57
    }
}
