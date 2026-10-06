import Testing
@testable import PitlogCore

private let today = day(2026, 10, 5)

private func lines(_ texts: [String]) -> [RecognizedLine] {
    texts.map { RecognizedLine(text: $0) }
}

private func parse(_ pages: [[String]]) -> RegistrationDraft {
    RegistrationDocumentParser().parse(pages: pages.map(lines), today: today)
}

/// Deterministic shuffle (Fisher-Yates with a linear congruential generator), so failures are reproducible.
private func shuffled<T>(_ items: [T], seed: UInt64) -> [T] {
    var state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    var result = items
    guard result.count > 1 else { return result }
    for index in stride(from: result.count - 1, to: 0, by: -1) {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let other = Int((state >> 33) % UInt64(index + 1))
        result.swapAt(index, other)
    }
    return result
}

// MARK: Checks

private enum Check {
    /// The value is right and the confidence at least `minimum`; `nil` expected means nothing was read.
    case exact(ScanConfidence)
    /// Better nothing than wrong: absent, right, or flagged `.low`.
    case lenient
}

private func check<Value: Hashable & Sendable>(
    _ field: ScannedField<Value>?, _ expected: Value?, _ name: String, _ mode: Check,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    switch mode {
    case .exact(let minimum):
        #expect(field?.value == expected, "\(name): \(String(describing: field))", sourceLocation: sourceLocation)
        if expected != nil, let field {
            #expect(field.confidence >= minimum, "\(name) confidence \(field.confidence)", sourceLocation: sourceLocation)
        }
    case .lenient:
        if let field, field.confidence > .low {
            #expect(field.value == expected, "\(name): confident but wrong: \(field)", sourceLocation: sourceLocation)
        }
    }
}

private func check(
    _ draft: RegistrationDraft, _ expected: ExpectedRegistration, _ mode: Check,
    skipCategory: Bool = false, sourceLocation: SourceLocation = #_sourceLocation
) {
    check(draft.plate, expected.plate, "plate", mode, sourceLocation: sourceLocation)
    check(draft.firstRegistration, expected.firstRegistration, "firstRegistration", mode, sourceLocation: sourceLocation)
    check(draft.vin, expected.vin, "vin", mode, sourceLocation: sourceLocation)
    check(draft.vehicleClass, expected.vehicleClass, "vehicleClass", mode, sourceLocation: sourceLocation)
    if !skipCategory { check(draft.category, expected.category, "category", mode, sourceLocation: sourceLocation) }
    check(draft.make, expected.make, "make", mode, sourceLocation: sourceLocation)
    check(draft.type, expected.type, "type", mode, sourceLocation: sourceLocation)
    check(draft.commercialName, expected.commercialName, "commercialName", mode, sourceLocation: sourceLocation)
    check(draft.maxMassKg, expected.maxMassKg, "maxMassKg", mode, sourceLocation: sourceLocation)
    check(draft.usageCode, expected.usageCode, "usageCode", mode, sourceLocation: sourceLocation)
}

// MARK: Fixtures

@Suite("RegistrationDocumentParser fixtures")
struct RegistrationFixtureTests {
    @Test("clean text", arguments: RegistrationFixtures.all)
    func clean(fixture: RegistrationFixture) {
        check(parse(fixture.pages), fixture.expected, .exact(.medium))
    }

    @Test("clean text: the anchored fields are high")
    func cleanConfidence() {
        let draft = parse(RegistrationFixtures.paperNaturalPerson.pages)
        #expect(draft.plate?.confidence == .high)
        #expect(draft.firstRegistration?.confidence == .high)
        #expect(draft.vin?.confidence == .high)
        #expect(draft.vehicleClass?.confidence == .high)
        #expect(draft.category?.confidence == .high)
        #expect(draft.make?.confidence == .high)
        #expect(draft.commercialName?.confidence == .high)
        #expect(draft.maxMassKg?.confidence == .high)
        // D.2 can run over several lines, so it is never more than medium.
        #expect(draft.type?.confidence == .medium)
    }

    @Test("shuffled line order, no boxes", arguments: RegistrationFixtures.all, [1, 2, 3, 4] as [UInt64])
    func shuffledOrder(fixture: RegistrationFixture, seed: UInt64) {
        let pages = fixture.pages.enumerated().map { shuffled($0.element, seed: seed &+ UInt64($0.offset)) }
        check(parse(pages), fixture.expected, .exact(.medium))
    }

    @Test("OCR noise: O for 0, I for 1, B for 8, codes without dots")
    func ocrNoise() {
        let draft = parse(RegistrationFixtures.paperNoisy)
        check(draft, RegistrationFixtures.paperNaturalPerson.expected, .exact(.medium))
        // Corrected values are never high.
        #expect(draft.firstRegistration?.confidence == .medium)
        #expect(draft.vin?.confidence == .medium)
        #expect(draft.maxMassKg?.confidence == .medium)
    }

    @Test("broken lines: right, or flagged low, never wrong")
    func brokenLines() {
        let draft = parse(RegistrationFixtures.paperBroken)
        check(draft, RegistrationFixtures.paperNaturalPerson.expected, .lenient)
        // Values on the line after their label are read. Free text only as `.low`; a date has a shape that
        // anchors it, so it is `.medium` and switched on in the review.
        #expect(draft.firstRegistration?.value == day(2020, 3, 15))
        #expect(draft.firstRegistration?.confidence == .medium)
        #expect(draft.make?.confidence == .low)
        #expect(draft.vin?.value == "WBX1A23456B789012")
        #expect(draft.plate?.value == "W 12345 A")
    }

    @Test("broken lines in shuffled order: nothing confident and wrong", arguments: [1, 2, 3, 4, 5, 6] as [UInt64])
    func brokenLinesShuffled(seed: UInt64) {
        let page = shuffled(RegistrationFixtures.paperBroken[0], seed: seed)
        check(parse([page]), RegistrationFixtures.paperNaturalPerson.expected, .lenient)
    }

    @Test("OCR noise in shuffled order", arguments: [1, 2, 3, 4] as [UInt64])
    func noiseShuffled(seed: UInt64) {
        let page = shuffled(RegistrationFixtures.paperNoisy[0], seed: seed)
        check(parse([page]), RegistrationFixtures.paperNaturalPerson.expected, .exact(.medium))
    }

    /// The fields a test can drop, with the codes of their lines.
    enum Field: CaseIterable, Sendable {
        case plate, firstRegistration, vin, vehicleClass, make, type, commercialName, maxMass, usage

        var codes: [String] {
            switch self {
            case .plate: ["A"]
            case .firstRegistration: ["B"]
            case .vin: ["E"]
            case .vehicleClass: ["J"]
            case .make: ["D1"]
            case .type: ["D2"]
            case .commercialName: ["D3"]
            case .maxMass: ["F2"]
            case .usage: ["A4"]
            }
        }
    }

    @Test("missing fields: that field is nil, the others stay right", arguments: RegistrationFixtures.all, Field.allCases)
    func missingField(fixture: RegistrationFixture, field: Field) {
        let pages = fixture.pages.map { page in
            page.filter { line in
                guard let first = ScanText.tokens(line).first else { return true }
                return !field.codes.contains(ScanText.codeKey(first))
            }
        }
        var expected = fixture.expected
        switch field {
        case .plate: expected.plate = nil
        case .firstRegistration: expected.firstRegistration = nil
        case .vin: expected.vin = nil
        case .vehicleClass: expected.vehicleClass = nil
        case .make: expected.make = nil
        case .type: expected.type = nil
        case .commercialName: expected.commercialName = nil
        case .maxMass: expected.maxMassKg = nil
        case .usage: expected.usageCode = nil
        }
        let draft = parse(pages)
        // The category depends on J and A.4.
        check(draft, expected, .exact(.medium), skipCategory: field == .vehicleClass || field == .usage)
    }

    @Test("everything missing: an empty draft", arguments: RegistrationFixtures.all)
    func everythingMissing(fixture: RegistrationFixture) {
        let codes = Set(Field.allCases.flatMap(\.codes))
        let pages = fixture.pages.map { page in
            page.filter { line in
                guard let first = ScanText.tokens(line).first else { return true }
                return !codes.contains(ScanText.codeKey(first))
            }
        }
        #expect(parse(pages).isEmpty)
    }

    // MARK: Privacy (C.1.x, A.3)

    @Test("holder name, address and date of birth appear nowhere in the draft",
          arguments: RegistrationFixtures.all, [0, 1, 2] as [UInt64])
    func holderDataIsDropped(fixture: RegistrationFixture, seed: UInt64) {
        let pages = seed == 0 ? fixture.pages : fixture.pages.map { shuffled($0, seed: seed) }
        let dump = String(describing: parse(pages))
        for holder in fixture.holderStrings {
            #expect(!dump.contains(holder), "\(holder) leaked")
        }
    }

    @Test("holder data is not read even where a value line follows an empty field")
    func holderLineIsNotAValue() {
        let draft = parse([[
            "D1 Marke",
            "Familienname MUSTERMANN",
            "B Erstmalige Zulassung am:",
            "C1.2 Vorname / A3 Geb.datum MAX 01.02.1985",
        ]])
        #expect(draft.make == nil)
        #expect(draft.firstRegistration == nil)
        #expect(!String(describing: draft).contains("MUSTERMANN"))
        #expect(!String(describing: draft).contains("1985"))
    }

    @Test("the date of birth is never taken for the first registration")
    func dateOfBirthIsNotB() {
        let draft = parse([[
            "A Kennzeichen W 12345 A",
            "C1.2 Vorname / A3 Geb.datum MAX 01.02.1985",
            "B Erstmalige Zulassung am: A6 Genehmigungsdatum 10.03.2020",
        ]])
        #expect(draft.plate?.value == "W 12345 A")
        #expect(draft.firstRegistration == nil)
    }
}

// MARK: B against I, A.6, H

@Suite("RegistrationDocumentParser dates")
struct RegistrationDateTests {
    @Test("B is taken from its own code, never from I, A6 or H", arguments: [
        // line, expected B
        ("B Erstmalige Zulassung am: 15.03.2020 A6 Genehmigungsdatum 10.03.2019", day(2020, 3, 15) as DayDate?),
        ("B Erstmalige Zulassung am: A6 Genehmigungsdatum 10.03.2019", nil),
        ("I Zugelassen am: 20.03.2024 H gültig bis: 31.12.2030", nil),
        ("B 15.03.2020", day(2020, 3, 15)),
        ("B 15.03.2020 I 20.03.2024", day(2020, 3, 15)),
    ])
    func firstRegistration(line: String, expected: DayDate?) {
        #expect(parse([[line]]).firstRegistration?.value == expected)
    }

    @Test("B later than I: one of them is misread, so B is flagged low")
    func firstRegistrationAfterCurrent() {
        let draft = parse([["B 20.03.2024", "I 15.03.2020"]])
        #expect(draft.firstRegistration?.value == day(2024, 3, 20))
        #expect(draft.firstRegistration?.confidence == .low)
    }

    @Test("a first registration in the future or before 1900 is rejected")
    func implausibleFirstRegistration() {
        #expect(parse([["B 15.03.2030"]]).firstRegistration == nil)
        #expect(parse([["B 15.03.1850"]]).firstRegistration == nil)
        #expect(parse([["B 05.10.2026"]]).firstRegistration?.value == day(2026, 10, 5))
    }

    @Test("date formats", arguments: [
        // text, expected, corrected
        ("15.03.2020", day(2020, 3, 15) as DayDate?, false),
        ("1.3.2020", day(2020, 3, 1), false),
        ("15-03-2020", day(2020, 3, 15), true),
        ("15/03/2020", day(2020, 3, 15), true),
        ("15 03 2020", day(2020, 3, 15), true),
        ("15032020", day(2020, 3, 15), true),
        ("15.O3.2O2O", day(2020, 3, 15), true),
        ("l5.03.2020", day(2020, 3, 15), true),
        ("29.02.2020", day(2020, 2, 29), false),
        ("29.02.2021", nil, false),
        ("31.04.2020", nil, false),
        ("00.01.2020", nil, false),
        ("15.13.2020", nil, false),
        ("15.03.20", nil, false),
        ("2020-03-15", nil, false),
        ("BIS.SOS.OOZ", nil, false),
    ])
    func dateFormats(text: String, expected: DayDate?, corrected: Bool) {
        let parsed = DateScan.parseWhole(text)
        #expect(parsed?.date == expected, "\(text)")
        if expected != nil { #expect(parsed?.corrected == corrected, "\(text)") }
    }
}

// MARK: Field B in real-world layouts

struct FirstRegistrationCase: Sendable, CustomTestStringConvertible {
    let lines: [String]
    let expected: DayDate?
    /// Lowest confidence the date may arrive with (`.medium` = switched on in the review).
    let minimum: ScanConfidence

    init(_ lines: [String], _ expected: DayDate?, _ minimum: ScanConfidence = .medium) {
        self.lines = lines
        self.expected = expected
        self.minimum = minimum
    }

    var testDescription: String { lines.joined(separator: " ⏎ ") }
}

private let march2015 = day(2015, 3, 12)

private func box(_ x: Double, _ y: Double, _ w: Double = 0.2) -> Rect {
    Rect(x: x, y: y, w: w, h: 0.02)
}

@Suite("RegistrationDocumentParser field B")
struct RegistrationFieldBTests {
    @Test("B in many spellings and with OCR errors", arguments: [
        // spelling of the code
        FirstRegistrationCase(["B 12.03.2015"], march2015, .high),
        FirstRegistrationCase(["B: 12.03.2015"], march2015, .high),
        FirstRegistrationCase(["B. 12.03.2015"], march2015, .high),
        FirstRegistrationCase(["B12.03.2015"], march2015),
        FirstRegistrationCase(["B:12.03.2015"], march2015),
        FirstRegistrationCase(["b 12.03.2015"], march2015),
        FirstRegistrationCase(["B Erstmalige Zulassung am: 12.03.2015"], march2015, .high),
        FirstRegistrationCase(["A Kennzeichen W 12345 A B Erstmalige Zulassung am: 12.03.2015"], march2015),
        // blanks and OCR errors inside the date
        FirstRegistrationCase(["B 12 .03. 2015"], march2015),
        FirstRegistrationCase(["B 12. 03. 2015"], march2015),
        FirstRegistrationCase(["B 12 . 03 . 2015"], march2015),
        FirstRegistrationCase(["B 12,03.2015"], march2015),
        FirstRegistrationCase(["B 12,03,2015"], march2015),
        FirstRegistrationCase(["B l2.O3.2O15"], march2015),
        FirstRegistrationCase(["B 12O32015"], march2015),
        FirstRegistrationCase(["8 12.03.2015"], march2015),
        // two-digit years: up to the current year the 2000s, above it the 1900s
        FirstRegistrationCase(["B 12.03.15"], march2015),
        FirstRegistrationCase(["B 12.03.98"], day(1998, 3, 12)),
        FirstRegistrationCase(["B 12.03.26"], day(2026, 3, 12)),
        FirstRegistrationCase(["B 12.03.27"], day(1927, 3, 12)),
        // value below the label, also behind the label text
        FirstRegistrationCase(["B", "12.03.2015"], march2015),
        FirstRegistrationCase(["B Erstmalige Zulassung am:", "12.03.2015"], march2015),
        FirstRegistrationCase(["B", "Erstmalige Zulassung am:", "12.03.2015"], march2015),
        FirstRegistrationCase(["B Erstmalige Zulassung am:", "12 .03. 2015"], march2015),
        FirstRegistrationCase(["B Erstmalige Zulassung am:", "12.03.2015 A4 01"], march2015),
        FirstRegistrationCase(["B Erstmalige Zulassung am: I Zugelassen am:", "12.03.2015 20.03.2024"], march2015),
        // B wins over the other date fields, wherever they stand
        FirstRegistrationCase(["I Zugelassen am: 20.03.2024", "B Erstmalige Zulassung am: 12.03.2015"], march2015, .high),
        FirstRegistrationCase(["B Erstmalige Zulassung am: 12.03.2015 A6 Genehmigungsdatum 10.03.2015"], march2015, .high),
        FirstRegistrationCase(["B 12.03.2015 H gültig bis: 31.12.2030", "I 20.03.2024"], march2015),
        // B missing: nothing is guessed
        FirstRegistrationCase(["I Zugelassen am: 20.03.2024", "H gültig bis: 31.12.2030"], nil),
        FirstRegistrationCase(["A6 Genehmigungsdatum 10.03.2015", "I 20.03.2024"], nil),
        FirstRegistrationCase(["B Erstmalige Zulassung am:", "Familienname MUSTERMANN", "I Zugelassen am: 20.03.2024"], nil),
        FirstRegistrationCase(["B Erstmalige Zulassung am: I Zugelassen am:", "20.03.2024"], nil),
        FirstRegistrationCase(["B Erstmalige Zulassung am: I Zugelassen am:", "12.03.2015 20.03.2024 31.12.2030"], nil),
        FirstRegistrationCase(["Erstmalige Zulassung am: 12.03.2015"], nil),
        // implausible
        FirstRegistrationCase(["B 12.03.2030"], nil),
        FirstRegistrationCase(["B 12.03.1850"], nil),
    ])
    func spellings(testCase: FirstRegistrationCase) {
        let field = parse([testCase.lines]).firstRegistration
        #expect(field?.value == testCase.expected, "\(testCase.testDescription): \(String(describing: field))")
        if testCase.expected != nil, let field {
            #expect(field.confidence >= testCase.minimum, "\(testCase.testDescription): \(field.confidence)")
        }
    }

    @Test("a date behind the label of another date field is not B")
    func foreignLabelBeforeDate() {
        let field = parse([["B Erstmalige Zulassung am: Zugelassen am: 20.03.2024"]]).firstRegistration
        #expect((field?.confidence ?? .low) == .low)
    }

    @Test("a two-digit year is not read as a date elsewhere")
    func twoDigitYearsOnlyForDates() {
        #expect(DateScan.parseWhole("15.03.20") == nil)
        #expect(DateScan.parseWhole("15.03.20", twoDigitPivot: 2026)?.date == day(2020, 3, 15))
        #expect(DateScan.parseWhole("15.03.20", twoDigitPivot: 2026)?.corrected == true)
    }

    @Test("with boxes: label and date in one table row, in cells")
    func boxedCells() {
        let draft = RegistrationDocumentParser().parse(
            [
                RecognizedLine(text: "A", box: box(0.05, 0.20, 0.03)),
                RecognizedLine(text: "W 12345 A", box: box(0.40, 0.20)),
                RecognizedLine(text: "B", box: box(0.05, 0.30, 0.03)),
                RecognizedLine(text: "Erstmalige Zulassung am:", box: box(0.10, 0.30, 0.25)),
                RecognizedLine(text: "12.03.2015", box: box(0.40, 0.30)),
                RecognizedLine(text: "I", box: box(0.05, 0.40, 0.03)),
                RecognizedLine(text: "20.03.2024", box: box(0.40, 0.40)),
            ], today: today)
        #expect(draft.firstRegistration?.value == march2015)
        #expect(draft.firstRegistration?.confidence == .high)
    }

    @Test("with boxes: the date one table row below the label")
    func boxedRowBelow() {
        let draft = RegistrationDocumentParser().parse(
            [
                RecognizedLine(text: "B Erstmalige Zulassung am:", box: box(0.05, 0.30, 0.30)),
                RecognizedLine(text: "I Zugelassen am:", box: box(0.55, 0.30, 0.30)),
                RecognizedLine(text: "12.03.2015", box: box(0.05, 0.34)),
                RecognizedLine(text: "20.03.2024", box: box(0.55, 0.34)),
            ], today: today)
        #expect(draft.firstRegistration?.value == march2015)
        #expect(draft.firstRegistration?.confidence != .low)
    }

    @Test("only the date's own text is kept as the snippet")
    func snippetIsOnlyTheDate() {
        let draft = parse([["B Erstmalige Zulassung am:", "12.03.2015 A4 01"]])
        #expect(draft.firstRegistration?.rawText == "12.03.2015")
    }
}

// MARK: Plate, VIN, class, mass, usage

@Suite("RegistrationDocumentParser values")
struct RegistrationValueTests {
    @Test("Austrian plate formats", arguments: [
        ("W-12345X", "W-12345X" as String?),
        ("W 12345 A", "W 12345 A"),
        ("L 777 BX", "L 777 BX"),
        ("G-4711K", "G-4711K"),
        ("w 12345 a", "W 12345 A"),
        ("W 123.456", "W 123.456"),
        ("KL-42", "KL-42"),
        ("W-HAUS", "W-HAUS"),
        ("W 1 ABC", "W 1 ABC"),
        ("W12345X", "W12345X"),
        ("W\u{2014}12345X", "W-12345X"),
        ("12345", nil),
        ("Kennzeichen", nil),
        ("WXYZ-1", nil),
        ("W", nil),
        ("W-123456", nil),
        ("W 12345 ABC", nil),
        ("15.03.2020", nil),
    ])
    func plates(text: String, expected: String?) {
        #expect(PlateScan.parse(ScanText.tokens(text))?.value == expected, "\(text)")
    }

    @Test("only a standard plate with separator is high")
    func plateConfidence() {
        #expect(parse([["A Kennzeichen W-12345X"]]).plate?.confidence == .high)
        #expect(parse([["A Kennzeichen W12345X"]]).plate?.confidence == .medium)
        #expect(parse([["A Kennzeichen W-HAUS"]]).plate?.confidence == .medium)
    }

    @Test("VIN", arguments: [
        ("WBX1A23456B789012", "WBX1A23456B789012" as String?, ScanConfidence.high),
        ("wbx1a23456b789012", "WBX1A23456B789012", .high),
        ("WBX1A23456B789O12", "WBX1A23456B789012", .medium),
        ("WBX1A23456B789Q12", "WBX1A23456B789012", .medium),
        ("WBX1A23456B7890I2", "WBX1A23456B78901" + "2", .medium),
        ("WBX1A234 56B789012", "WBX1A23456B789012", .medium),
        ("WBX1A23456B78901", "WBX1A23456B78901", .low),
        ("WBX1A23456B7890123", "WBX1A23456B7890123", .low),
        ("FAHRGESTELLNUMMER", nil, .low),
        ("ABC", nil, .low),
    ])
    func vins(text: String, expected: String?, confidence: ScanConfidence) {
        let parsed = VINScan.parse(ScanText.tokens(text))
        #expect(parsed?.value == expected, "\(text)")
        if expected != nil { #expect(parsed?.confidence == confidence, "\(text)") }
    }

    @Test("a VIN is found without its code, with medium confidence")
    func standaloneVIN() {
        let draft = parse([["D1 BEISPIELMARKE E WBX1A23456B789012", "Beispiel"]])
        #expect(draft.vin?.value == "WBX1A23456B789012")
        #expect(draft.vin?.confidence == .medium)
        #expect(draft.make?.value == "BEISPIELMARKE")
    }

    @Test("vehicle class codes and their categories", arguments: [
        ("M1", "M1" as String?, VehicleCategory.passengerCar),
        ("M1G", "M1G", .passengerCar),
        ("M1SA", "M1SA", .passengerCar),
        ("M2", "M2", .other),
        ("M3", "M3", .other),
        ("N1", "N1", .lightCommercial),
        ("N1G", "N1G", .lightCommercial),
        ("N2", "N2", .other),
        ("N3", "N3", .other),
        ("O1", "O1", .lightTrailer),
        ("O2", "O2", .lightTrailer),
        ("O3", "O3", .other),
        ("O4", "O4", .other),
        ("L1e", "L1e", .motorcycle),
        ("L3e-A1", "L3e-A1", .motorcycle),
        ("L3E-A2", "L3e-A2", .motorcycle),
        ("L5e-A", "L5e-A", .motorcycle),
        ("L7e", "L7e", .motorcycle),
        ("T1", "T1", .other),
        ("R2", "R2", .other),
        ("Ml", "M1", .passengerCar),
        ("01", "O1", .lightTrailer),
        ("M4", nil, .other),
        ("X1", nil, .other),
        ("Pkw", nil, .other),
        ("L8e", nil, .other),
    ])
    func classes(text: String, expectedCode: String?, category: VehicleCategory) {
        let parsed = ClassScan.parseToken(text)
        #expect(parsed?.code == expectedCode, "\(text)")
        if let code = parsed?.code { #expect(ClassScan.category(of: code) == category, "\(text)") }
    }

    @Test("unsupported classes prefill category other, with the class kept")
    func unsupportedClass() {
        let draft = parse([["J Klasse / Fahrzeugart N2 Lastkraftwagen", "F2 Gesamtgewicht 7500"]])
        #expect(draft.vehicleClass?.value == "N2")
        #expect(draft.category?.value == .other)
        #expect(draft.category?.confidence == .high)
        #expect(draft.maxMassKg?.value == 7500)
    }

    @Test("a trailer without a readable class: F.2 up to 3500 kg is light, above is other", arguments: [
        ("750", VehicleCategory.lightTrailer as VehicleCategory?),
        ("3500", .lightTrailer),
        ("3501", .other),
        ("10000", .other),
    ])
    func trailerByMass(mass: String, expected: VehicleCategory?) {
        let draft = parse([["J Klasse / Fahrzeugart Anhänger", "F2 Gesamtgewicht \(mass)"]])
        #expect(draft.vehicleClass == nil)
        #expect(draft.category?.value == expected)
        #expect(draft.category?.confidence == .medium)
    }

    @Test("a trailer without class and without mass gives no category")
    func trailerWithoutMass() {
        #expect(parse([["J Klasse / Fahrzeugart Anhänger"]]).category == nil)
    }

    @Test("mass in kilograms", arguments: [
        (["1950"], 1950 as Int?),
        (["1.950"], 1950),
        (["1,950"], 1950),
        (["1", "950"], 1950),
        (["1950kg"], 1950),
        (["1950", "kg"], 1950),
        (["2O5O"], 2050),
        (["12.500"], 12500),
        (["750"], 750),
        (["12"], nil),
        (["abc"], nil),
        (["100000"], nil),
        (["BIS"], nil),
        (["1.95"], nil),
        (["kg"], nil),
    ])
    func masses(tokens: [String], expected: Int?) {
        #expect(MassScan.parse(tokens)?.value == expected, "\(tokens)")
    }

    @Test("F2 above F1 means the two were mixed up")
    func massOrder() {
        let swapped = parse([["F1 Techn. zul. Gesamtmasse 1950", "F2 Gesamtgewicht 2100"]])
        #expect(swapped.maxMassKg?.value == 2100)
        #expect(swapped.maxMassKg?.confidence == .low)
        let fine = parse([["F1 Techn. zul. Gesamtmasse 2100", "F2 Gesamtgewicht 1950"]])
        #expect(fine.maxMassKg?.confidence == .high)
    }

    @Test("A.4: taxi and ambulance codes turn a passenger car into taxiOrAmbulance", arguments: [
        ("25", VehicleCategory.taxiOrAmbulance), ("62", .taxiOrAmbulance), ("64", .taxiOrAmbulance),
        ("01", .passengerCar),
    ])
    func usageCodes(code: String, category: VehicleCategory) {
        let draft = parse([["J Klasse / Fahrzeugart M1 Personenkraftwagen", "A4 Verwendungsbestimmung \(code)"]])
        #expect(draft.usageCode?.value == code)
        #expect(draft.category?.value == category)
    }

    @Test("A.4 does not change other classes, and unknown codes are not read")
    func usageCodesElsewhere() {
        let van = parse([["J Klasse / Fahrzeugart N1 Lastkraftwagen", "A4 Verwendungsbestimmung 25"]])
        #expect(van.category?.value == .lightCommercial)
        #expect(parse([["A4 Verwendungsbestimmung 40"]]).usageCode == nil)
        #expect(parse([["A4 Verwendungsbestimmung 2S"]]).usageCode?.value == "25")
    }

    @Test("taxi without a readable class is a medium guess")
    func taxiWithoutClass() {
        let draft = parse([["A4 Verwendungsbestimmung 25"]])
        #expect(draft.category?.value == .taxiOrAmbulance)
        #expect(draft.category?.confidence == .medium)
    }
}

// MARK: Layout traps

@Suite("RegistrationDocumentParser layout")
struct RegistrationLayoutTests {
    @Test("codes are normalized: dots and spaces do not matter", arguments: [
        "D1 Marke DEMO", "D.1 Marke DEMO", "D 1 Marke DEMO", "d1 marke DEMO", "D1 DEMO", "D.1 DEMO",
    ])
    func codeSpelling(line: String) {
        #expect(parse([[line]]).make?.value == "DEMO", "\(line)")
    }

    @Test("F.2 in all spellings", arguments: ["F2 1950", "F.2 1950", "F 2 1950", "F2 Gesamtgewicht 1950"])
    func massSpelling(line: String) {
        #expect(parse([[line]]).maxMassKg?.value == 1950, "\(line)")
    }

    @Test("a model name that looks like a field code stays a model name")
    func modelNamesWithCodes() {
        let names = ["A4 Avant", "A3 Sportback", "Audi A4 40 TDI", "E 200", "A6 Allroad", "Q5 Sportback", "I3 Active"]
        for name in names {
            let draft = parse([["D3 Handelsbezeichnung \(name)", "J Klasse / Fahrzeugart M1"]])
            #expect(draft.commercialName?.value == name, "\(name)")
            #expect(draft.usageCode == nil, "\(name)")
            #expect(draft.category?.value == .passengerCar, "\(name)")
        }
    }

    @Test("the legend of the chip card back is not read as field content")
    func cardLegend() {
        let draft = parse([[
            "D1 Marke; D2 Type/Variante/Vers; D3 Handelsb; E FIN; F2 hz Gesamtgew;",
            "J Fzg-Klasse/Art; A4 Verw-Best; H gült bis",
        ]])
        #expect(draft.isEmpty)
        #expect(draft.notices == [.cardFrontSideMissing])
    }

    @Test("an orphan code does not take a line with another label")
    func orphanBeforeLabel() {
        #expect(parse([["D3 Handelsbezeichnung", "D1 Marke DEMO"]]).commercialName == nil)
        #expect(parse([["D1 Marke", "15.03.2020"]]).make == nil)
        #expect(parse([["D1 Marke", "WBX1A23456B789012"]]).make == nil)
    }

    @Test("D.2 is read before and after D.3 (the order on paper differs from the card)")
    func orderOfD() {
        let lines = ["D3 Handelsbezeichnung Beispiel 1.5", "D2 Type/Variante/Version ABC1"]
        #expect(parse([lines]).type?.value == "ABC1")
        #expect(parse([lines.reversed()]).commercialName?.value == "Beispiel 1.5")
    }

    @Test("two columns of one photo (part I and part II side by side) with the same values")
    func doubledColumns() {
        let draft = parse([["A Kennzeichen W 12345 A A Kennzeichen W 12345 A"]])
        // The second code sits inside the cell, without an own box: only its label makes it a code.
        #expect(draft.plate?.value == "W 12345 A")
    }

    @Test("two different plates cancel out")
    func conflictingPlates() {
        #expect(parse([["A Kennzeichen W 12345 A", "A Kennzeichen G 4711 K"]]).plate == nil)
    }

    @Test("empty and garbage input")
    func garbage() {
        #expect(parse([[]]).isEmpty)
        #expect(parse([["", "   ", "|||"]]).isEmpty)
        #expect(parse([["Hallo Welt", "Lorem ipsum 123", "A", "B", "E", "J"]]).isEmpty)
        #expect(parse([["ZULASSUNGSSCHEIN", "Kennzeichen: W 12345", "Marke: BEISPIEL", "Fahrgestell-Nr.: unleserlich"]]).isEmpty)
    }

    @Test("no field is read when only labels are there")
    func labelsOnly() {
        let draft = parse([[
            "A Kennzeichen", "B Erstmalige Zulassung am:", "E FIN", "J Klasse / Fahrzeugart",
            "D1 Marke", "D3 Handelsbezeichnung", "D2 Type/Variante/Version", "F2 Höchste(s) zulässige(s) Gesamtgewicht",
        ]])
        #expect(draft.isEmpty)
    }
}

// MARK: Document kinds

@Suite("RegistrationDocumentParser document kinds")
struct RegistrationKindTests {
    @Test("part II is read but flagged")
    func partTwo() {
        let draft = parse([[
            "A Kennzeichen W 12345 A",
            "J Klasse / Fahrzeugart M1 Personenkraftwagen",
            "A22 Anzahl der Vorzulassungen 1",
            "A21 Anlage",
        ]])
        #expect(draft.notices == [.partTwo])
        #expect(draft.plate?.value == "W 12345 A")
    }

    @Test("a transfer permit is not a registration certificate")
    func transferPermit() {
        let draft = parse([["Transport Permit", "Ü 00000000", "A Kennzeichen W 12345 A"]])
        #expect(draft.isEmpty)
        #expect(draft.notices == [.transferPermit])
    }

    @Test("the front of a chip card alone asks for the back, and the other way round")
    func cardSides() {
        let card = RegistrationFixtures.card2010.pages
        let front = parse([card[0]])
        #expect(front.notices == [.cardBackSideMissing])
        #expect(front.plate?.value == "K 5555 BX")
        let back = parse([card[1]])
        #expect(back.notices == [.cardFrontSideMissing])
        #expect(back.vin?.value == "WXY2B34567C890123")
        #expect(parse(card).notices.isEmpty)
    }

    @Test("pages are read on their own and merged")
    func mergePages() {
        let card = RegistrationFixtures.card2023.pages
        let merged = parse([card[1], card[0]])
        check(merged, RegistrationFixtures.card2023.expected, .exact(.medium))
        // The same as merging the two single-page drafts.
        let manual = parse([card[0]]).merging(parse([card[1]]))
        #expect(merged.plate == manual.plate)
        #expect(merged.vin == manual.vin)
    }

    @Test("merging: same value keeps the better confidence, different values cancel out")
    func mergeRules() {
        let high = ScannedField(value: "A", rawText: "A", confidence: .high)
        let low = ScannedField(value: "A", rawText: "A", confidence: .low)
        let other = ScannedField(value: "B", rawText: "B", confidence: .high)
        let otherLow = ScannedField(value: "B", rawText: "B", confidence: .low)
        #expect(RegistrationDraft(make: low).merging(RegistrationDraft(make: high)).make == high)
        #expect(RegistrationDraft(make: high).merging(RegistrationDraft(make: other)).make == nil)
        #expect(RegistrationDraft(make: high).merging(RegistrationDraft(make: otherLow)).make == high)
        #expect(RegistrationDraft(make: low).merging(RegistrationDraft()).make == low)
    }
}

// MARK: Geometry

@Suite("RegistrationDocumentParser geometry")
struct RegistrationGeometryTests {
    private typealias Cell = (text: String, x: Double, y: Double)

    private func boxed(_ cells: [Cell]) -> [RecognizedLine] {
        cells.map { RecognizedLine(text: $0.text, box: Rect(x: $0.x, y: $0.y, w: 0.1, h: 0.03)) }
    }

    /// Chip card front, codes and values in separate cells.
    private let front: [Cell] = [
        ("EUROPÄISCHE GEMEINSCHAFT", 0.30, 0.05), ("REPUBLIK ÖSTERREICH", 0.30, 0.08),
        ("ZULASSUNGSBESCHEINIGUNG TEIL1", 0.30, 0.11),
        ("I", 0.70, 0.18), ("20.03.2024", 0.78, 0.181),
        ("A", 0.30, 0.30), ("W-12345X", 0.40, 0.302),
        ("B", 0.30, 0.34), ("15.03.2020", 0.40, 0.341),
        ("C.1.1", 0.30, 0.38), ("MUSTERMANN", 0.40, 0.379),
        ("C.1.2", 0.30, 0.42), ("MAX", 0.40, 0.421),
        ("C.1.3", 0.30, 0.46), ("BEISPIELGASSE 1 1010 WIEN", 0.40, 0.461),
        ("A Kennzeichen", 0.05, 0.90), ("B Erstmalige Zulassung", 0.05, 0.93), ("I Zugelassen", 0.05, 0.96),
    ]

    /// Chip card back: E sits right of D1, A27 and A4 right of D3, A7 right of J.
    private let back: [Cell] = [
        ("D1", 0.05, 0.10), ("BEISPIELMARKE", 0.12, 0.101), ("E", 0.60, 0.100), ("WBX1A23456B789012", 0.66, 0.102),
        ("D2", 0.05, 0.14), ("ABC1 / XYZ / 1.0", 0.12, 0.141),
        ("D3", 0.05, 0.18), ("Beispiel 1.5", 0.12, 0.181), ("A27", 0.55, 0.18), ("A4", 0.80, 0.18), ("01", 0.86, 0.182),
        ("J", 0.05, 0.22), ("M1", 0.12, 0.221), ("A7", 0.80, 0.22), ("12345", 0.86, 0.221),
        ("F1", 0.35, 0.36), ("2100", 0.42, 0.361),
        ("F2", 0.35, 0.40), ("1950", 0.42, 0.401),
        ("A4 Verw-Best; A7 nat Code; A10 hz Nutzl; D1 Marke;", 0.05, 0.90),
        ("E FIN; F2 hz Gesamtgew; J Fzg-Klasse/Art", 0.05, 0.93),
    ]

    @Test("cells of one row are joined: codes and values in separate boxes")
    func frontWithBoxes() {
        let draft = RegistrationDocumentParser().parse(boxed(front), today: today)
        #expect(draft.plate?.value == "W-12345X")
        #expect(draft.plate?.confidence == .high)
        #expect(draft.firstRegistration?.value == day(2020, 3, 15))
        #expect(draft.firstRegistration?.confidence == .high)
        #expect(!String(describing: draft).contains("MUSTERMANN"))
    }

    @Test("the back of the card with several fields per row")
    func backWithBoxes() {
        let draft = RegistrationDocumentParser().parse(boxed(back), today: today)
        #expect(draft.make?.value == "BEISPIELMARKE")
        #expect(draft.vin?.value == "WBX1A23456B789012")
        #expect(draft.vin?.confidence == .high)
        #expect(draft.type?.value == "ABC1 / XYZ / 1.0")
        #expect(draft.commercialName?.value == "Beispiel 1.5")
        #expect(draft.vehicleClass?.value == "M1")
        #expect(draft.usageCode?.value == "01")
        #expect(draft.maxMassKg?.value == 1950)
    }

    @Test("the order of the lines does not matter when boxes are there", arguments: [1, 2, 3, 4, 5] as [UInt64])
    func boxesIgnoreOrder(seed: UInt64) {
        let parser = RegistrationDocumentParser()
        #expect(parser.parse(boxed(shuffled(front, seed: seed)), today: today)
            == parser.parse(boxed(front), today: today))
        #expect(parser.parse(boxed(shuffled(back, seed: seed)), today: today)
            == parser.parse(boxed(back), today: today))
    }

    @Test("a value cell that starts like a code is a value, not a new field")
    func valueCellLooksLikeCode() {
        for name in ["A4 Avant", "A3 Sportback", "A4 40 TDI", "A6 Allroad"] {
            let cells: [Cell] = [("D3", 0.05, 0.18), (name, 0.12, 0.181), ("J", 0.05, 0.22), ("M1", 0.12, 0.221)]
            let draft = RegistrationDocumentParser().parse(boxed(cells), today: today)
            #expect(draft.commercialName?.value == name, "\(name)")
            #expect(draft.usageCode == nil, "\(name)")
        }
    }

    @Test("an ambiguous value cell (A4 25) is a low-confidence name and never makes a taxi")
    func ambiguousValueCell() {
        let cells: [Cell] = [("D3", 0.05, 0.18), ("A4 25", 0.12, 0.181), ("J", 0.05, 0.22), ("M1", 0.12, 0.221)]
        let draft = RegistrationDocumentParser().parse(boxed(cells), today: today)
        #expect(draft.commercialName?.confidence == .low)
        #expect(draft.usageCode == nil)
        #expect(draft.category?.value == .passengerCar)
    }

    @Test("without a box on every line the geometry is ignored")
    func partialBoxes() {
        let lines = [
            RecognizedLine(text: "A Kennzeichen W 12345 A", box: Rect(x: 0, y: 0.1, w: 0.5, h: 0.03)),
            RecognizedLine(text: "D1 Marke DEMO"),
        ]
        let draft = RegistrationDocumentParser().parse(lines, today: today)
        #expect(draft.plate?.value == "W 12345 A")
        #expect(draft.make?.value == "DEMO")
    }
}
