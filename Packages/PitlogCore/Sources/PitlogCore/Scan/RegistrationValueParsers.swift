import Foundation

/// Parsers for the values of single fields. Each one returns `nil` rather than a guess.

// MARK: Dates

enum DateScan {
    struct Match {
        let date: DayDate
        let corrected: Bool
        /// Index of the first token of the date.
        let tokenIndex: Int
    }

    /// The first date in the tokens. Dates are `TT.MM.JJJJ` (assumed, see the README); other separators and
    /// letters that look like digits are accepted but flagged as corrected.
    static func firstDate(in tokens: [String]) -> Match? {
        for start in tokens.indices {
            for width in 1...3 where start + width <= tokens.count {
                let candidate = tokens[start..<(start + width)].joined(separator: " ")
                if let parsed = parseWhole(candidate) {
                    return Match(date: parsed.date, corrected: parsed.corrected || width > 1, tokenIndex: start)
                }
            }
        }
        return nil
    }

    static func parseWhole(_ text: String) -> (date: DayDate, corrected: Bool)? {
        var groups: [[Int]] = []
        var current: [Int] = []
        var corrected = false
        var realDigits = 0
        var previous: Character = "x"
        for character in text {
            if let digit = ScanText.digit(of: character) {
                if digit.confusable { corrected = true } else { realDigits += 1 }
                current.append(digit.value)
            } else if character == "." || character == "-" || character == "/" || character == "," || character == " " {
                if !current.isEmpty {
                    groups.append(current)
                    current = []
                }
                if character != "." && !(character == " " && previous == ".") { corrected = true }
            } else if character == ":" || character == ";" || character == "(" || character == ")" {
                corrected = true
            } else {
                return nil
            }
            previous = character
        }
        if !current.isEmpty { groups.append(current) }
        guard realDigits >= 4 else { return nil }

        let day: [Int]
        let month: [Int]
        let year: [Int]
        if groups.count == 3 {
            day = groups[0]
            month = groups[1]
            year = groups[2]
        } else if groups.count == 1, groups[0].count == 8 {
            day = Array(groups[0][0..<2])
            month = Array(groups[0][2..<4])
            year = Array(groups[0][4..<8])
            corrected = true
        } else {
            return nil
        }
        guard (1...2).contains(day.count), (1...2).contains(month.count), year.count == 4 else { return nil }
        let toInt: ([Int]) -> Int = { digits in digits.reduce(0) { total, digit in total * 10 + digit } }
        guard let date = DayDate(year: toInt(year), month: toInt(month), day: toInt(day)) else { return nil }
        return (date, corrected)
    }
}

// MARK: VIN

enum VINScan {
    static let validCharacters = Set("ABCDEFGHJKLMNPRSTUVWXYZ0123456789")

    /// Upper-case letters and digits. O and Q become 0, I becomes 1 (those letters do not occur in a VIN).
    static func normalized(_ text: String) -> (value: String, corrected: Bool) {
        var result = ""
        var corrected = false
        for character in text.uppercased() where ScanText.isASCIIAlphanumeric(character) {
            switch character {
            case "O", "Q":
                result.append("0")
                corrected = true
            case "I":
                result.append("1")
                corrected = true
            default:
                result.append(character)
            }
        }
        return (result, corrected)
    }

    static func digitCount(_ value: String) -> Int {
        value.filter { ScanText.isASCIIDigit($0) }.count
    }

    static func isValidShape(_ value: String) -> Bool {
        value.count == 17 && value.allSatisfy { validCharacters.contains($0) } && digitCount(value) >= 3
    }

    /// A complete VIN in the first tokens (a VIN broken over up to three tokens is joined).
    static func parseExact(_ tokens: [String]) -> (value: String, corrected: Bool, tokenCount: Int)? {
        for start in 0..<min(2, tokens.count) {
            for width in 1...3 where start + width <= tokens.count {
                let normalized = normalized(tokens[start..<(start + width)].joined())
                if isValidShape(normalized.value) {
                    return (normalized.value, normalized.corrected, width)
                }
            }
        }
        return nil
    }

    static func parse(_ tokens: [String]) -> (value: String, confidence: ScanConfidence)? {
        if let exact = parseExact(tokens) {
            return (exact.value, !exact.corrected && exact.tokenCount == 1 ? .high : .medium)
        }
        // Not a VIN, but close: show it so the user can fix it, unchecked.
        let partial = normalized(tokens.prefix(3).joined())
        if (12...20).contains(partial.value.count), digitCount(partial.value) >= 3 {
            return (partial.value, .low)
        }
        return nil
    }

    /// A token that is a valid VIN as it stands (no correction), for documents where the code was not found.
    static func standalone(in tokens: [String]) -> String? {
        for token in tokens {
            let key = ScanText.codeKey(token)
            guard key.count == 17, key == token.uppercased(), isValidShape(key) else { continue }
            return key
        }
        return nil
    }
}

// MARK: Plate

enum PlateScan {
    /// Austrian plates: district code of one or two letters, then digits with up to two letters
    /// (`W 12345 A`, `L-777BX`, old `W 123.456`) or a personalized combination of up to seven characters.
    static func parse(_ tokens: [String]) -> (value: String, corrected: Bool, standard: Bool)? {
        var best: (value: String, corrected: Bool, standard: Bool, count: Int)?
        for count in 1...min(4, max(tokens.count, 1)) where count <= tokens.count {
            if let parsed = parseWhole(tokens.prefix(count).joined(separator: " ")) {
                best = (parsed.value, parsed.corrected, parsed.standard, count)
            }
        }
        guard let best else { return nil }
        // A short token right behind the plate that is no field code could be part of it (`W 12345 ABC`):
        // the plate is then not clear, and a truncated plate would be wrong.
        if best.count < tokens.count {
            let next = tokens[best.count]
            if next.count <= 4, next.allSatisfy({ ScanText.isASCIIAlphanumeric($0) }),
               !RowSegmenter.knownCodes.contains(ScanText.codeKey(next))
            {
                return nil
            }
        }
        return (best.value, best.corrected, best.standard)
    }

    static func parseWhole(_ raw: String) -> (value: String, corrected: Bool, standard: Bool)? {
        var text = raw.uppercased().trimmingCharacters(in: CharacterSet(charactersIn: " ,;:|_\"'"))
        text = text.replacingOccurrences(of: "\u{2013}", with: "-").replacingOccurrences(of: "\u{2014}", with: "-")
        let chars = Array(text)
        guard !chars.isEmpty, chars.count <= 12 else { return nil }

        var index = 0
        while index < chars.count, ScanText.isASCIILetter(chars[index]) { index += 1 }
        let districtLength = index
        guard (1...2).contains(districtLength) else { return nil }

        var separatorLength = 0
        var sawHyphen = false
        while index < chars.count, chars[index] == " " || chars[index] == "-", separatorLength < 3 {
            if chars[index] == "-" { sawHyphen = true }
            separatorLength += 1
            index += 1
        }
        let body = Array(chars[index...])
        guard !body.isEmpty else { return nil }

        let district = String(chars[0..<districtLength])
        let separator = sawHyphen ? "-" : (separatorLength > 0 ? " " : "")
        let corrected = separatorLength != 1

        if isStandardBody(body) {
            return (district + separator + String(body), corrected, true)
        }
        // Personalized plates always have a separator; letters only are allowed (`W-HAUS`).
        guard separatorLength > 0 else { return nil }
        let alphanumeric = body.filter { ScanText.isASCIIAlphanumeric($0) }
        guard (1...7).contains(alphanumeric.count),
              body.allSatisfy({ ScanText.isASCIIAlphanumeric($0) || $0 == " " }),
              body.contains(where: { ScanText.isASCIILetter($0) })
        else { return nil }
        return (district + separator + String(body), corrected, false)
    }

    private static func isStandardBody(_ body: [Character]) -> Bool {
        var digits = 0
        while digits < body.count, ScanText.isASCIIDigit(body[digits]) { digits += 1 }
        guard (1...5).contains(digits) else { return false }
        if digits == body.count { return true }
        let remainder = Array(body[digits...])
        // Old numeric plates: `123.456`.
        if digits <= 3, remainder.count == 4, remainder[0] == ".", remainder.dropFirst().allSatisfy({ ScanText.isASCIIDigit($0) }) {
            return true
        }
        let letters = remainder.first == " " ? Array(remainder.dropFirst()) : remainder
        return (1...2).contains(letters.count) && letters.allSatisfy { ScanText.isASCIILetter($0) }
    }
}

// MARK: Vehicle class (J)

enum ClassScan {
    /// The first class code in the first three tokens (`M1`, `N1G`, `L3e-A1`, `O2`, `T1`, ...).
    static func parse(_ tokens: [String]) -> (code: String, corrected: Bool, tokenIndex: Int)? {
        for index in 0..<min(3, tokens.count) {
            if let parsed = parseToken(tokens[index]) { return (parsed.code, parsed.corrected, index) }
            if index + 1 < tokens.count, tokens[index].count == 1,
               let parsed = parseToken(tokens[index] + tokens[index + 1])
            {
                return (parsed.code, parsed.corrected, index)
            }
        }
        return nil
    }

    static func parseToken(_ raw: String) -> (code: String, corrected: Bool)? {
        let trimmed = raw.uppercased().trimmingCharacters(in: CharacterSet(charactersIn: ",;:()."))
        let chars = Array(trimmed)
        guard chars.count >= 2, chars.count <= 8 else { return nil }
        var corrected = false
        var letter = chars[0]
        if letter == "0" {
            letter = "O"
            corrected = true
        }
        var digitCharacter = chars[1]
        if digitCharacter == "I" || digitCharacter == "L" || digitCharacter == "!" {
            digitCharacter = "1"
            corrected = true
        }
        guard ScanText.isASCIIDigit(digitCharacter), let digit = digitCharacter.wholeNumberValue else { return nil }
        let rest = String(chars.dropFirst(2))

        switch letter {
        case "M", "N":
            guard (1...3).contains(digit), ["", "G", "SA", "GSA"].contains(rest) else { return nil }
            return ("\(letter)\(digit)\(rest)", corrected)
        case "O":
            guard (1...4).contains(digit), ["", "G", "SA", "GSA"].contains(rest) else { return nil }
            return ("\(letter)\(digit)\(rest)", corrected)
        case "L":
            guard (1...7).contains(digit), rest.hasPrefix("E") else { return nil }
            let tail = Array(rest.dropFirst())
            if tail.isEmpty { return ("L\(digit)e", corrected) }
            guard tail[0] == "-", (2...3).contains(tail.count),
                  ["A", "B", "C"].contains(String(tail[1])),
                  tail.count == 2 || ScanText.isASCIIDigit(tail[2])
            else { return nil }
            return ("L\(digit)e" + String(tail), corrected)
        case "T":
            guard (1...5).contains(digit), rest.count <= 2, rest.allSatisfy({ ScanText.isASCIIAlphanumeric($0) }) else {
                return nil
            }
            return ("T\(digit)\(rest)", corrected)
        case "R":
            guard (1...4).contains(digit), rest.count <= 2, rest.allSatisfy({ ScanText.isASCIIAlphanumeric($0) }) else {
                return nil
            }
            return ("R\(digit)\(rest)", corrected)
        default:
            return nil
        }
    }

    /// M1 passenger car, L motorcycle, N1 light commercial, O1/O2 light trailer, everything else `other`.
    static func category(of code: String) -> VehicleCategory {
        if code.hasPrefix("M1") { return .passengerCar }
        if code.hasPrefix("N1") { return .lightCommercial }
        if code.hasPrefix("O1") || code.hasPrefix("O2") { return .lightTrailer }
        if code.hasPrefix("L") { return .motorcycle }
        return .other
    }

    /// The vehicle type in clear text says "trailer" (`Anhänger`) but the class code is unreadable.
    static func mentionsTrailer(_ tokens: [String]) -> Bool {
        tokens.contains { token in
            let word = ScanLabels.word(token)
            return ScanLabels.matches(word, "anhänger") || ScanLabels.matches(word, "anhaenger")
        }
    }
}

// MARK: Mass (F.1, F.2)

enum MassScan {
    /// The first plausible mass in kilograms (50 ... 99 999): `1950`, `1.950`, `1 950`, `1950 kg`.
    static func parse(_ tokens: [String]) -> (value: Int, corrected: Bool, tokenIndex: Int)? {
        var index = 0
        while index < tokens.count {
            if let parsed = parseToken(tokens[index]) { return (parsed.value, parsed.corrected, index) }
            if index + 1 < tokens.count, let parsed = parseSplit(tokens[index], tokens[index + 1]) {
                return (parsed, true, index)
            }
            index += 1
        }
        return nil
    }

    private static func parseToken(_ raw: String) -> (value: Int, corrected: Bool)? {
        var text = raw
        if text.lowercased().hasSuffix("kg") { text = String(text.dropLast(2)) }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
        guard !text.isEmpty else { return nil }

        let separators: Set<Character> = [".", ","]
        let parts = text.split(omittingEmptySubsequences: false, whereSeparator: { separators.contains($0) })
            .map(String.init)
        guard (1...2).contains(parts.count) else { return nil }
        var corrected = parts.count > 1
        var realDigits = 0
        var number = 0
        for (index, part) in parts.enumerated() {
            guard !part.isEmpty else { return nil }
            if parts.count > 1 {
                guard index == 0 ? part.count <= 3 : part.count == 3 else { return nil }
            }
            for character in part {
                guard let digit = ScanText.digit(of: character) else { return nil }
                if digit.confusable { corrected = true } else { realDigits += 1 }
                number = number * 10 + digit.value
            }
        }
        guard realDigits >= 2, (50...99_999).contains(number) else { return nil }
        return (number, corrected)
    }

    private static func parseSplit(_ first: String, _ second: String) -> Int? {
        guard (1...3).contains(first.count), second.count == 3,
              first.allSatisfy({ ScanText.isASCIIDigit($0) }), second.allSatisfy({ ScanText.isASCIIDigit($0) }),
              let high = Int(first), let low = Int(second)
        else { return nil }
        let number = high * 1000 + low
        return (50...99_999).contains(number) ? number : nil
    }
}

// MARK: Usage code (A.4)

enum UsageScan {
    /// Intended-use codes documented in the README: no special use, taxi, public and private ambulance.
    static let documentedCodes: Set<String> = ["01", "25", "62", "64"]
    static let taxiOrAmbulance: Set<String> = ["25", "62", "64"]

    static func parse(_ tokens: [String]) -> (code: String, corrected: Bool)? {
        guard let first = tokens.first else { return nil }
        let characters = Array(first.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:")))
        guard characters.count == 2 else { return nil }
        var code = ""
        var corrected = false
        var realDigits = 0
        for character in characters {
            guard let digit = ScanText.digit(of: character) else { return nil }
            if digit.confusable { corrected = true } else { realDigits += 1 }
            code.append(String(digit.value))
        }
        guard realDigits >= 1, documentedCodes.contains(code) else { return nil }
        return (code, corrected)
    }
}

// MARK: Free text (D.1, D.2, D.3)

enum TextScan {
    /// The text of a free-text field. If a VIN or a date follows in the same segment (a code that was not
    /// recognized), the text is cut there and flagged as corrected.
    static func parse(_ tokens: [String]) -> (value: String, corrected: Bool)? {
        var work = tokens
        var corrected = false
        if let cut = work.firstIndex(where: { VINScan.standalone(in: [$0]) != nil || DateScan.parseWhole($0) != nil }) {
            work = Array(work[..<cut])
            corrected = true
            while let last = work.last, last.count <= 5, RowSegmenter.knownCodes.contains(ScanText.codeKey(last)) {
                work.removeLast()
            }
        }
        let value = work.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;:|_"))
        guard !value.isEmpty, value.count <= 80, !value.contains(";"),
              value.contains(where: { $0.isLetter || $0.isNumber })
        else { return nil }
        if work.allSatisfy({ ScanLabels.isLabel($0, vocabulary: ScanLabels.all) }) { return nil }
        return (value, corrected)
    }
}
