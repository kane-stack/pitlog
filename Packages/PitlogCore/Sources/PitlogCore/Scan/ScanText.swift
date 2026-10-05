import Foundation

/// Character and word helpers for the registration parser.
enum ScanText {
    /// Whitespace-separated tokens. Table borders that OCR reads as `|` count as whitespace.
    static func tokens(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            if character == " " || character == "\t" || character == "\n" || character == "\r"
                || character == "\u{00A0}" || character == "|" || character == "\u{00A6}"
            {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    static func isASCIIDigit(_ character: Character) -> Bool {
        guard let value = character.asciiValue else { return false }
        return value >= 48 && value <= 57
    }

    static func isASCIILetter(_ character: Character) -> Bool {
        guard let value = character.asciiValue else { return false }
        return (value >= 65 && value <= 90) || (value >= 97 && value <= 122)
    }

    static func isASCIIAlphanumeric(_ character: Character) -> Bool {
        isASCIIDigit(character) || isASCIILetter(character)
    }

    static func hasAlphanumeric(_ token: String) -> Bool {
        token.contains { $0.isLetter || $0.isNumber }
    }

    /// Letters and digits only, upper case: the comparison form of a field code (`C.1.1` becomes `C11`).
    static func codeKey(_ token: String) -> String {
        var result = ""
        for character in token.uppercased() where isASCIIAlphanumeric(character) {
            result.append(character)
        }
        return result
    }

    /// A digit, or a letter OCR commonly mistakes for one. `confusable` is true for the letters.
    static func digit(of character: Character) -> (value: Int, confusable: Bool)? {
        if isASCIIDigit(character), let value = character.wholeNumberValue {
            return (value, false)
        }
        switch character {
        case "O", "o": return (0, true)
        case "I", "i", "l": return (1, true)
        case "Z", "z": return (2, true)
        case "S", "s": return (5, true)
        case "B": return (8, true)
        default: return nil
        }
    }

    static func distance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = Array(repeating: 0, count: b.count + 1)
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[b.count]
    }
}

/// The printed labels next to the field codes, matched loosely because OCR garbles them.
enum ScanLabels {
    static let byCode: [String: [String]] = [
        "A": ["kennzeichen"],
        "B": ["erstmalige", "erstmaligen", "zulassung"],
        "E": ["fin", "fahrgestellnummer"],
        "J": ["klasse", "fahrzeugart", "fzg", "art"],
        "D1": ["marke"],
        "D2": ["type", "typ", "variante", "version", "vers"],
        "D3": ["handelsbezeichnung", "handelsb", "handelsbez"],
        "F1": ["techn", "tech", "zul", "gesamtmasse", "gesamt"],
        "F2": ["höchste", "höchstes", "zulässige", "zulässiges", "hz", "gesamtgewicht", "gesamtgew"],
        "I": ["zugelassen"],
        "H": ["gültig", "gueltig", "gült"],
        "A3": ["geb", "datum", "geburtsdatum", "firmenbuchnummer", "gebdatum"],
        "A4": ["verwendungsbestimmung", "verw", "best"],
        "A6": ["genehmigungsdatum", "genehm", "datum"],
    ]

    /// Labels of the other fields, used where a code has no entry of its own.
    static let others: [String] = [
        "zulassungsstelle", "familienname", "firmenname", "vorname", "anschrift", "antragsteller",
        "genehmigungsgrundlage", "genehmigungsnummer", "nationaler", "aufbau", "farbe", "eigengewicht",
        "nutzlast", "stütz", "sattellast", "anhängelast", "gebr", "ungebremst", "motortype", "antriebsart",
        "höchstgeschw", "hubraum", "leistung", "drehzahl", "standgeräusch", "abgasklasse", "verhalten",
        "kraftstoffverbrauch", "vermerke", "räder", "bereifung", "auflagen", "behördliche", "eintragungen",
        "anmerkungen", "anlage", "anzahl", "vorzulassungen", "sitz", "stehplätze", "achslasten", "beg",
        "plakette", "elektromotor", "fahrzeuguntergruppe", "absorptionskoeffizient", "nefz", "wltp", "wmtc",
        "leistung/gewicht", "dvr", "achslast", "höchstgeschwindigkeit", "gewicht", "nutzl", "sattel",
        "motortyp", "antrieb", "stehpl", "sitzpl", "abgaskl", "standger", "drehz",
    ]

    static let all: [String] = Array(byCode.values.joined()) + others

    /// Words that appear inside labels without being labels themselves.
    static let fillers: [String] = ["am", "bis", "kg", "des", "der", "ist", "nat", "code"]

    static func vocabulary(for code: String) -> [String] {
        byCode[code] ?? all
    }

    /// Lower-case letters of a token. Digits that OCR reads for letters are mapped back
    /// (`F1N` becomes `fin`), but only in tokens that contain a letter, so numbers never turn into words.
    static func word(_ text: String) -> String {
        let lowered = text.lowercased()
        guard lowered.contains(where: { $0.isLetter }) else { return "" }
        var result = ""
        for character in lowered {
            switch character {
            case "1": result.append("i")
            case "0": result.append("o")
            case "8": result.append("b")
            case "5": result.append("s")
            default:
                if character.isLetter { result.append(character) }
            }
        }
        return result
    }

    static func matches(_ word: String, _ vocabulary: String) -> Bool {
        if word == vocabulary { return true }
        if word.count >= 4, vocabulary.hasPrefix(word) { return true }
        let limit = vocabulary.count >= 8 ? 2 : (vocabulary.count >= 5 ? 1 : 0)
        guard limit > 0, abs(word.count - vocabulary.count) <= limit else { return false }
        return ScanText.distance(word, vocabulary) <= limit
    }

    /// True if every part of the token (split at `/`, `-`, `.`, ...) is a label word of `vocabulary`.
    static func isLabel(_ token: String, vocabulary: [String]) -> Bool {
        let cleaned = token.replacingOccurrences(of: "(s)", with: "")
        let separators: Set<Character> = ["/", "-", ".", ",", ":", ";", "(", ")"]
        let parts = cleaned.split(whereSeparator: { separators.contains($0) }).map { word(String($0)) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return false }
        return parts.allSatisfy { part in
            fillers.contains(part) || vocabulary.contains { matches(part, $0) }
        }
    }

    /// The tokens without the leading label of `code` (and loose punctuation).
    static func strip(_ tokens: [String], code: String) -> [String] {
        let vocabulary = vocabulary(for: code)
        var index = 0
        while index < tokens.count,
              !ScanText.hasAlphanumeric(tokens[index]) || isLabel(tokens[index], vocabulary: vocabulary)
        {
            index += 1
        }
        return Array(tokens[index...])
    }

    static func startsWithLabel(_ tokens: [String]) -> Bool {
        guard let first = tokens.first else { return false }
        return isLabel(first, vocabulary: all)
    }
}
