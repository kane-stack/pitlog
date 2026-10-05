import Foundation

/// Reads the fields of an Austrian registration certificate (paper, Anlage 6, or chip card, Anlage 7) from
/// recognized text lines. Pure heuristics on the EU field codes (ADR-13): A, B, E, J, D.1, D.2, D.3, F.2, A.4.
///
/// The guiding principle is: better nothing than wrong. A value is only returned when its code was found
/// and its text has the shape the field needs; doubtful values come back with `.low` confidence.
/// Holder name, address and date of birth (C.1.x, A.3) are never read: those fields are recognized only to
/// know where the neighbouring field ends.
public struct RegistrationDocumentParser: Sendable {
    public init() {}

    /// One page. `today` bounds the first registration (it cannot lie in the future).
    public func parse(_ lines: [RecognizedLine], today: DayDate) -> RegistrationDraft {
        parse(pages: [lines], today: today)
    }

    /// Several pages of the same document (front and back of the chip card, the two sides of the paper).
    /// Every page is read on its own, so lines of different pages never mix.
    public func parse(pages: [[RecognizedLine]], today: DayDate) -> RegistrationDraft {
        var draft = RegistrationDraft()
        var signals = PageSignals()
        for page in pages {
            let result = parsePage(page, today: today)
            draft = draft.merging(result.draft)
            signals.formUnion(result.signals)
        }
        if signals.transferPermit {
            return RegistrationDraft(notices: [.transferPermit])
        }
        var notices: Set<RegistrationScanNotice> = []
        if signals.partTwo { notices.insert(.partTwo) }
        let hasFront = draft.plate != nil || draft.firstRegistration != nil
        let hasBack = draft.vin != nil || draft.vehicleClass != nil || draft.make != nil || draft.type != nil
            || draft.commercialName != nil || draft.maxMassKg != nil
        if signals.cardFront, !hasBack { notices.insert(.cardBackSideMissing) }
        if signals.cardBack, !hasFront { notices.insert(.cardFrontSideMissing) }
        draft.notices = notices
        return draft
    }

    // MARK: Page

    private struct PageSignals {
        var cardFront = false
        var cardBack = false
        var partTwo = false
        var transferPermit = false

        mutating func formUnion(_ other: PageSignals) {
            cardFront = cardFront || other.cardFront
            cardBack = cardBack || other.cardBack
            partTwo = partTwo || other.partTwo
            transferPermit = transferPermit || other.transferPermit
        }
    }

    private struct Candidate<Value: Hashable & Sendable> {
        var value: Value
        var rawText: String
        var confidence: ScanConfidence
    }

    /// Fields that may stand on the line after their code (code and value in separate lines).
    private static let pairableCodes: Set<String> = ["A", "B", "E", "J", "D1", "D2", "D3", "F2", "A4"]

    private func parsePage(_ lines: [RecognizedLine], today: DayDate) -> (draft: RegistrationDraft, signals: PageSignals) {
        var signals = PageSignals()
        let allText = lines.map(\.text).joined(separator: " ").uppercased()
        signals.cardFront = allText.contains("ZULASSUNGSBESCHEINIGUNG")
            && (allText.contains("TEIL1") || allText.contains("TEIL 1") || allText.contains("TEIL I"))
        signals.transferPermit = allText.contains("TRANSPORT PERMIT") || allText.contains("ÜBERSTELLUNG")
            || allText.contains("UBERSTELLUNG")

        let rows = RowBuilder.rows(from: lines)
        // The legend at the bottom of the chip card back lists all codes with labels. It is not field content.
        var skipped = Set<Int>()
        for (index, row) in rows.enumerated() where row.text.filter({ $0 == ";" }).count >= 2 {
            skipped.insert(index)
            signals.cardBack = true
        }
        let segmentsByRow: [[Segment]] = rows.indices.map { skipped.contains($0) ? [] : RowSegmenter.segments(in: rows[$0]) }
        for segments in segmentsByRow where segments.contains(where: { $0.code == "A21" || $0.code == "A22" }) {
            signals.partTwo = true
        }

        var plate: [Candidate<String>] = []
        var firstRegistration: [Candidate<DayDate>] = []
        var currentRegistration: [Candidate<DayDate>] = []
        var vin: [Candidate<String>] = []
        var vehicleClass: [Candidate<String>] = []
        var make: [Candidate<String>] = []
        var type: [Candidate<String>] = []
        var commercialName: [Candidate<String>] = []
        var maxMass: [Candidate<Int>] = []
        var technicalMass: [Candidate<Int>] = []
        var usage: [Candidate<String>] = []
        var trailerWordSeen = false

        for index in rows.indices where !skipped.contains(index) {
            let segments = segmentsByRow[index]
            for (position, segment) in segments.enumerated() {
                var tokens = ScanLabels.strip(segment.tokens, code: segment.code)
                var orphan = false
                if tokens.isEmpty, position == segments.count - 1, Self.pairableCodes.contains(segment.code),
                   index + 1 < rows.count, !skipped.contains(index + 1), segmentsByRow[index + 1].isEmpty,
                   !ScanLabels.startsWithLabel(rows[index + 1].tokens)
                {
                    tokens = rows[index + 1].tokens
                    orphan = true
                }
                guard !tokens.isEmpty else { continue }
                let raw = String(tokens.joined(separator: " ").prefix(80))

                func confidence(_ base: ScanConfidence, corrected: Bool, orphanCap: ScanConfidence) -> ScanConfidence {
                    var result = base
                    if corrected || segment.viaVariant { result = min(result, .medium) }
                    if orphan { result = min(result, orphanCap) }
                    if segment.ambiguous { result = .low }
                    return result
                }

                switch segment.code {
                case "A":
                    if let parsed = PlateScan.parse(tokens) {
                        let base: ScanConfidence = parsed.standard ? .high : .medium
                        plate.append(Candidate(
                            value: parsed.value, rawText: raw,
                            confidence: confidence(base, corrected: parsed.corrected, orphanCap: .medium)))
                    }
                case "B", "I":
                    guard let match = DateScan.firstDate(in: tokens) else { break }
                    let corrected = match.corrected || match.tokenIndex > 0
                    let candidate = Candidate(
                        value: match.date, rawText: raw,
                        confidence: confidence(.high, corrected: corrected, orphanCap: .low))
                    if segment.code == "B" {
                        // The first registration lies between 1900 and today.
                        if match.date.year >= 1900, match.date <= today { firstRegistration.append(candidate) }
                    } else {
                        currentRegistration.append(candidate)
                    }
                case "E":
                    if let parsed = VINScan.parse(tokens) {
                        vin.append(Candidate(
                            value: parsed.value, rawText: raw,
                            confidence: confidence(parsed.confidence, corrected: false, orphanCap: .medium)))
                    }
                case "J":
                    if let parsed = ClassScan.parse(tokens) {
                        let base: ScanConfidence = parsed.tokenIndex <= 1 ? .high : .medium
                        vehicleClass.append(Candidate(
                            value: parsed.code, rawText: raw,
                            confidence: confidence(base, corrected: parsed.corrected, orphanCap: .medium)))
                    } else if ClassScan.mentionsTrailer(tokens) {
                        trailerWordSeen = true
                    }
                case "D1", "D2", "D3":
                    guard let parsed = TextScan.parse(tokens) else { break }
                    let base: ScanConfidence = segment.code == "D2" ? .medium : .high
                    let candidate = Candidate(
                        value: parsed.value, rawText: raw,
                        confidence: confidence(base, corrected: parsed.corrected, orphanCap: .low))
                    switch segment.code {
                    case "D1": make.append(candidate)
                    case "D2": type.append(candidate)
                    default: commercialName.append(candidate)
                    }
                case "F1", "F2":
                    guard let parsed = MassScan.parse(tokens) else { break }
                    let candidate = Candidate(
                        value: parsed.value, rawText: raw,
                        confidence: confidence(.high, corrected: parsed.corrected, orphanCap: .medium))
                    if segment.code == "F2" { maxMass.append(candidate) } else { technicalMass.append(candidate) }
                case "A4":
                    if let parsed = UsageScan.parse(tokens) {
                        usage.append(Candidate(
                            value: parsed.code, rawText: raw,
                            confidence: confidence(.high, corrected: parsed.corrected, orphanCap: .medium)))
                    }
                default:
                    break
                }
            }
        }

        // The VIN is distinctive enough to be found without its code; medium, because nothing anchors it.
        if vin.isEmpty {
            for (index, row) in rows.enumerated() where !skipped.contains(index) {
                if let value = VINScan.standalone(in: row.tokens) {
                    vin.append(Candidate(value: value, rawText: value, confidence: .medium))
                    break
                }
            }
        }

        var draft = RegistrationDraft()
        draft.plate = Self.resolve(plate)
        draft.vin = Self.resolve(vin)
        draft.make = Self.resolve(make)
        draft.type = Self.resolve(type)
        draft.commercialName = Self.resolve(commercialName)
        draft.vehicleClass = Self.resolve(vehicleClass)

        draft.firstRegistration = Self.resolve(firstRegistration)
        // B cannot be later than I. If it is, one of the two was misread.
        if let first = draft.firstRegistration, let current = Self.resolve(currentRegistration),
           first.value > current.value
        {
            draft.firstRegistration?.confidence = .low
        }

        draft.maxMassKg = Self.resolve(maxMass)
        // F.2 cannot exceed F.1 (technically permissible mass). If it does, the two were mixed up.
        if let max = draft.maxMassKg, let technical = Self.resolve(technicalMass), max.value > technical.value {
            draft.maxMassKg?.confidence = .low
        }

        draft.usageCode = Self.resolve(usage)
        draft.category = Self.category(
            vehicleClass: draft.vehicleClass, usage: draft.usageCode, trailerWordSeen: trailerWordSeen,
            maxMass: draft.maxMassKg)
        return (draft, signals)
    }

    // MARK: Resolution

    /// One value per field. The same value twice keeps the higher confidence. Different values cancel out
    /// unless exactly one is at least `.medium` and the others are `.low`.
    private static func resolve<Value: Hashable & Sendable>(_ candidates: [Candidate<Value>]) -> ScannedField<Value>? {
        var best: [Value: Candidate<Value>] = [:]
        for candidate in candidates {
            if let existing = best[candidate.value], existing.confidence >= candidate.confidence { continue }
            best[candidate.value] = candidate
        }
        let ranked = best.values.sorted { $0.confidence > $1.confidence }
        guard let top = ranked.first else { return nil }
        if ranked.count > 1 {
            guard top.confidence >= .medium, ranked[1].confidence == .low else { return nil }
        }
        return ScannedField(value: top.value, rawText: top.rawText, confidence: top.confidence)
    }

    private static func category(
        vehicleClass: ScannedField<String>?, usage: ScannedField<String>?, trailerWordSeen: Bool,
        maxMass: ScannedField<Int>?
    ) -> ScannedField<VehicleCategory>? {
        var result: ScannedField<VehicleCategory>?
        if let vehicleClass {
            result = ScannedField(
                value: ClassScan.category(of: vehicleClass.value), rawText: vehicleClass.rawText,
                confidence: vehicleClass.confidence)
        } else if trailerWordSeen, let maxMass {
            // J says "trailer" but not which class: O1/O2 up to 3.5 t, O3/O4 above.
            result = ScannedField(
                value: maxMass.value <= 3500 ? .lightTrailer : .other, rawText: maxMass.rawText,
                confidence: min(maxMass.confidence, .medium))
        }
        if let usage, UsageScan.taxiOrAmbulance.contains(usage.value),
           result == nil || result?.value == .passengerCar
        {
            let base = result?.confidence ?? .medium
            result = ScannedField(
                value: .taxiOrAmbulance, rawText: usage.rawText, confidence: min(base, usage.confidence))
        }
        return result
    }
}

// MARK: Rows

/// A table row of the document: its tokens, and where a new cell (a separately recognized text line) begins.
struct ScanRow {
    var tokens: [String]
    var cellStarts: Set<Int>

    var text: String { tokens.joined(separator: " ") }
}

enum RowBuilder {
    /// Without geometry (or if any line lacks a box) every line is a row. With boxes everywhere, lines on the same
    /// height are joined left to right, so label and value cells of one table row become one row again.
    static func rows(from lines: [RecognizedLine]) -> [ScanRow] {
        let usable = lines.filter { !ScanText.tokens($0.text).isEmpty }
        let allBoxed = !usable.isEmpty && usable.allSatisfy { $0.box != nil }
        guard allBoxed else {
            return usable.map { ScanRow(tokens: ScanText.tokens($0.text), cellStarts: [0]) }
        }

        struct Group {
            var middle: Double
            var height: Double
            var lines: [(x: Double, text: String)]
        }
        let sorted = usable.compactMap { line -> (box: Rect, text: String)? in
            line.box.map { ($0, line.text) }
        }.sorted { ($0.box.midY, $0.box.x) < ($1.box.midY, $1.box.x) }

        var groups: [Group] = []
        for entry in sorted {
            if let last = groups.last, abs(entry.box.midY - last.middle) <= 0.5 * min(entry.box.h, last.height) {
                var group = last
                let count = Double(group.lines.count)
                group.middle = (group.middle * count + entry.box.midY) / (count + 1)
                group.height = (group.height * count + entry.box.h) / (count + 1)
                group.lines.append((entry.box.x, entry.text))
                groups[groups.count - 1] = group
            } else {
                groups.append(Group(middle: entry.box.midY, height: entry.box.h, lines: [(entry.box.x, entry.text)]))
            }
        }
        return groups.map { group in
            var tokens: [String] = []
            var starts: Set<Int> = []
            for line in group.lines.sorted(by: { $0.x < $1.x }) {
                starts.insert(tokens.count)
                tokens.append(contentsOf: ScanText.tokens(line.text))
            }
            return ScanRow(tokens: tokens, cellStarts: starts)
        }
    }
}

// MARK: Segments

/// A field code and the tokens up to the next code.
struct Segment {
    var code: String
    var viaVariant: Bool
    var tokens: [String]
    /// The previous field was empty and this "code" may be its value (a model name like `A4 Avant`).
    var ambiguous = false
}

enum RowSegmenter {
    /// Normalized codes (letters and digits only): `C.1.1` is `C11`, `S1/2` is `S12`.
    static let knownCodes: Set<String> = [
        "A", "B", "E", "G", "H", "I", "J", "K", "Q", "R", "T",
        "A1", "A3", "A4", "A5", "A6", "A7", "A8", "A10", "A12", "A13", "A16", "A17", "A18", "A19", "A20",
        "A21", "A22", "A23", "A24", "A25", "A26", "A27",
        "C11", "C12", "C13", "C4",
        "D1", "D2", "D3", "F1", "F2",
        "N", "N1", "N2", "N3", "N4", "O1", "O2", "P1", "P2", "P3", "P4", "P5",
        "S1", "S2", "S12", "S1S2", "U1", "U2", "V6", "V7", "V8", "V9",
    ]

    private static let freeTextCodes: Set<String> = ["D1", "D2", "D3"]

    private struct CodeCandidate {
        var code: String
        var consumed: Int
        var variant: Bool
    }

    static func segments(in row: ScanRow) -> [Segment] {
        var result: [Segment] = []
        var index = 0
        while index < row.tokens.count {
            switch detect(in: row, at: index, previous: result.last) {
            case .code(let segment, let consumed):
                result.append(segment)
                index += consumed
            case .value(let markPreviousAmbiguous):
                if !result.isEmpty {
                    result[result.count - 1].tokens.append(row.tokens[index])
                    if markPreviousAmbiguous { result[result.count - 1].ambiguous = true }
                }
                index += 1
            }
        }
        return result
    }

    private enum Detection {
        case code(Segment, consumed: Int)
        case value(markPreviousAmbiguous: Bool)
    }

    private static func detect(in row: ScanRow, at index: Int, previous: Segment?) -> Detection {
        let tokens = row.tokens
        let atCellStart = row.cellStarts.contains(index) || index == 0
            || tokens[..<index].allSatisfy { !ScanText.hasAlphanumeric($0) }
        for candidate in candidates(tokens, at: index) {
            let rest = Array(tokens[(index + candidate.consumed)...])
            guard accepts(candidate.code, rest: rest, atCellStart: atCellStart) else { continue }
            // "D3 A4 40 TDI": a code-like start of the value of a free-text field that has nothing yet is
            // the value, not a new field. Only a bare code or a code with its label starts a new field.
            if let previous, freeTextCodes.contains(previous.code),
               ScanLabels.strip(previous.tokens, code: previous.code).isEmpty,
               !rest.isEmpty, !labelFollows(candidate.code, rest)
            {
                return .value(markPreviousAmbiguous: true)
            }
            return .code(
                Segment(code: candidate.code, viaVariant: candidate.variant, tokens: []), consumed: candidate.consumed)
        }
        return .value(markPreviousAmbiguous: false)
    }

    private static func candidates(_ tokens: [String], at index: Int) -> [CodeCandidate] {
        var result: [CodeCandidate] = []
        let token = tokens[index]
        guard token.count <= 6 else { return result }
        let key = ScanText.codeKey(token)
        guard !key.isEmpty else { return result }
        let next = index + 1 < tokens.count ? tokens[index + 1] : nil

        // OCR variants whose label gives them away: D1 read as 01/O1, D2 as 02/O2, D3 as 03/O3.
        if let next {
            if ["O1", "01", "DI", "DL"].contains(key), ScanLabels.isLabel(next, vocabulary: ["marke"]) {
                result.append(CodeCandidate(code: "D1", consumed: 1, variant: key != "D1"))
            }
            if ["O2", "02"].contains(key), ScanLabels.isLabel(next, vocabulary: ScanLabels.vocabulary(for: "D2")) {
                result.append(CodeCandidate(code: "D2", consumed: 1, variant: true))
            }
            if ["O3", "03"].contains(key), ScanLabels.isLabel(next, vocabulary: ScanLabels.vocabulary(for: "D3")) {
                result.append(CodeCandidate(code: "D3", consumed: 1, variant: true))
            }
        }
        // A single letter and a number apart: `C 1.1`, `D 1`, `F 2`.
        if let next, key.count == 1, ScanText.isASCIILetter(key.first ?? " "), next.count <= 4,
           let firstOfNext = next.first, ScanText.isASCIIDigit(firstOfNext) || firstOfNext == "."
        {
            let joined = key + ScanText.codeKey(next)
            if knownCodes.contains(joined) {
                result.append(CodeCandidate(code: joined, consumed: 2, variant: false))
            }
        }
        if knownCodes.contains(key) {
            result.append(CodeCandidate(code: key, consumed: 1, variant: false))
        }
        // Code B read as 8, code I read as 1 or l: only with the shape of their value behind them.
        if key == "8" { result.append(CodeCandidate(code: "B", consumed: 1, variant: true)) }
        if key == "1" || key == "L" { result.append(CodeCandidate(code: "I", consumed: 1, variant: true)) }
        if key == "DI" || key == "DL" { result.append(CodeCandidate(code: "D1", consumed: 1, variant: true)) }
        return result
    }

    private static func labelFollows(_ code: String, _ rest: [String]) -> Bool {
        guard let first = rest.first else { return false }
        return ScanLabels.isLabel(first, vocabulary: ScanLabels.vocabulary(for: code))
    }

    /// A code counts only if its surroundings fit: its label follows, or (at the start of a cell) a value of
    /// the right shape, or nothing at all (the value is in the next line). Inside a cell, only the label counts,
    /// so a model name such as `Audi A4 40 TDI` is not cut into fields.
    private static func accepts(_ code: String, rest: [String], atCellStart: Bool) -> Bool {
        if rest.isEmpty { return atCellStart }
        if labelFollows(code, rest) { return true }
        guard atCellStart else { return false }
        switch code {
        case "B", "I", "H", "A6", "A3":
            return DateScan.firstDate(in: Array(rest.prefix(3)))?.tokenIndex == 0
        case "A":
            return PlateScan.parse(Array(rest.prefix(4))) != nil
        case "E":
            return VINScan.parseExact(Array(rest.prefix(3))) != nil
        case "J":
            return ClassScan.parse(Array(rest.prefix(3))) != nil
        case "A4":
            return UsageScan.parse(rest) != nil
        case "F1", "F2":
            return MassScan.parse(Array(rest.prefix(4))) != nil
        case "D1", "D2", "D3":
            return true
        default:
            // Other single letters (G, K, T, ...) need a number behind them; longer codes are unambiguous.
            if code.count == 1 { return rest[0].first.map { ScanText.isASCIIDigit($0) } ?? false }
            return true
        }
    }
}
