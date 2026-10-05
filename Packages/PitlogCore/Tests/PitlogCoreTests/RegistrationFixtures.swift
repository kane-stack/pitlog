import Testing
@testable import PitlogCore

/// What a fixture must produce.
struct ExpectedRegistration: Sendable {
    var plate: String?
    var firstRegistration: DayDate?
    var vin: String?
    var vehicleClass: String?
    var category: VehicleCategory?
    var make: String?
    var type: String?
    var commercialName: String?
    var maxMassKg: Int?
    var usageCode: String?
}

/// A synthetic registration certificate. Layout and field codes follow the official specimens
/// (ZustV Anlage 6 and 7); every value is invented.
struct RegistrationFixture: Sendable, CustomTestStringConvertible {
    let name: String
    /// One array of lines per scanned page, in reading order, as the text recognizer returns them.
    let pages: [[String]]
    let expected: ExpectedRegistration
    /// Text of the holder that must never show up anywhere in the draft.
    let holderStrings: [String]

    var testDescription: String { name }
}

enum RegistrationFixtures {
    // MARK: Paper (Anlage 6)

    /// Natural person, passenger car. Inside rows, two fields share one line (B / A6, I / H, ...).
    static let paperNaturalPerson = RegistrationFixture(
        name: "paper, natural person, M1",
        pages: [[
            "A1 Zulassungsstelle 1234",
            "A Kennzeichen W 12345 A",
            "I Zugelassen am: 20.03.2024 H gültig bis:",
            "C1.1 Familienname MUSTERMANN",
            "C1.2 Vorname / A3 Geb.datum MAXIMILIAN 01.02.1985",
            "C1.3 Anschrift BEISPIELGASSE 1 1010 WIEN",
            "C4 Antragsteller ist: Zulassungsbesitzer",
            "A4 Verwendungsbestimmung 01",
            "E FIN WBX1A23456B789012",
            "B Erstmalige Zulassung am: 15.03.2020 A6 Genehmigungsdatum 10.03.2020",
            "A5 Genehmigungsgrundlage ABC",
            "K Genehmigungsnummer e1*2007/46*0001*00",
            "A7 Nationaler Code 12345",
            "J Klasse / Fahrzeugart M1 Personenkraftwagen",
            "D1 Marke BEISPIELMARKE",
            "D3 Handelsbezeichnung Beispiel 1.5",
            "D2 Type/Variante/Version ABC1 / XYZ / 1.0",
            "A8 Aufbau Limousine",
            "R Farbe Blau A16 Beg.Plakette",
            "G Eigengewicht 1450 S1/S2 Sitz-/Stehplätze 5/0",
            "F1 Techn. zul. Gesamtmasse 2100",
            "F2 Höchste(s) zulässige(s) Gesamtgewicht 1950",
            "A10 Nutzlast 500",
            "A12 Stütz-/Sattellast 0",
            "O1 Anhängelast gebr. 1500 O2 ungebremst 750",
            "P5 Motortype ABC123",
            "P3 Antriebsart Benzin",
            "T Höchstgeschw. 200 P1 Hubraum 1498",
        ]],
        expected: ExpectedRegistration(
            plate: "W 12345 A", firstRegistration: day(2020, 3, 15), vin: "WBX1A23456B789012",
            vehicleClass: "M1", category: .passengerCar, make: "BEISPIELMARKE", type: "ABC1 / XYZ / 1.0",
            commercialName: "Beispiel 1.5", maxMassKg: 1950, usageCode: "01"),
        holderStrings: ["MUSTERMANN", "MAXIMILIAN", "BEISPIELGASSE", "01.02.1985", "1010 WIEN"])

    /// Legal person, taxi (A.4 = 25). "Probe E" ends in a letter that is also a field code.
    static let paperLegalPersonTaxi = RegistrationFixture(
        name: "paper, legal person, taxi",
        pages: [[
            "A1 Zulassungsstelle 5678",
            "A Kennzeichen G 4711 K",
            "I Zugelassen am: 02.05.2023 H gültig bis:",
            "C1.1 Firmenname BEISPIEL HANDELS GMBH",
            "C1.2 Vorname / A3 Firmenbuchnummer FN 123456a",
            "C1.3 Anschrift MUSTERSTRASSE 5 8010 GRAZ",
            "C4 Antragsteller ist:",
            "A4 Verwendungsbestimmung 25",
            "E FIN WXY2B34567C890123",
            "B Erstmalige Zulassung am: 30.11.2021 A6 Genehmigungsdatum 25.11.2021",
            "J Klasse / Fahrzeugart M1 Personenkraftwagen",
            "D1 Marke DEMO",
            "D3 Handelsbezeichnung Probe E",
            "D2 Type/Variante/Version TX 2 / B",
            "F1 Techn. zul. Gesamtmasse 2300",
            "F2 Höchste(s) zulässige(s) Gesamtgewicht 2200",
        ]],
        expected: ExpectedRegistration(
            plate: "G 4711 K", firstRegistration: day(2021, 11, 30), vin: "WXY2B34567C890123",
            vehicleClass: "M1", category: .taxiOrAmbulance, make: "DEMO", type: "TX 2 / B",
            commercialName: "Probe E", maxMassKg: 2200, usageCode: "25"),
        holderStrings: ["BEISPIEL HANDELS", "MUSTERSTRASSE", "123456a", "8010 GRAZ"])

    // MARK: Chip card (Anlage 7), front and back as two pages

    private static let cardLegend = [
        "A4 Verw-Best; A7 nat Code; A10 hz Nutzl; A12 hz Stütz-/Sattellast; A23 Vermerke; D1 Marke;",
        "D2 Type/Variante/Vers; D3 Handelsb; E FIN; F1 tech zul Gesamt; F2 hz Gesamtgew; G Eigengew;",
        "H gült bis; J Fzg-Klasse/Art; K Genehm-Nr; N1-N4 hz Achslast; O1/O2 hz Anhängel gebremst/ungebremst;",
        "P1 Hubraum; P2 Leistung; P3 Antrieb; P5 Motortyp; Q Leist/Gew; S1/S2 Sitz-/Stehpl; T Höchstgeschw;",
        "U1/U2 Standger/Drehz; V9 Abgaskl",
    ]

    /// Design 2010: no `I` in the legend, no A.27. Light commercial vehicle.
    static let card2010 = RegistrationFixture(
        name: "chip card 2010, N1",
        pages: [
            [
                "EUROPÄISCHE GEMEINSCHAFT",
                "REPUBLIK ÖSTERREICH",
                "ZULASSUNGSBESCHEINIGUNG TEIL1",
                "A K 5555 BX",
                "B 01.07.2018",
                "C.1.1 MUSTER GMBH",
                "C.1.3 TESTWEG 9 9020 KLAGENFURT",
                "C.4 BEISPIELBEHÖRDE",
                "A Kennzeichen",
                "B Erstmalige Zulassung",
            ],
            [
                "D1 DEMOMARKE",
                "E WXY2B34567C890123",
                "D2 TESTTYP 12 / A",
                "D3 Demo Transporter",
                "A4 01",
                "J N1 Lastkraftwagen",
                "S1/2 3/0",
                "O1 1800",
                "O2 750",
                "N1 1500",
                "F1 3000",
                "F2 2800",
                "G 1900",
                "A10 1100",
                "A12 0",
                "U1 78",
                "U2 3000",
                "K e1*2007/46*0002*01",
                "P5 ABC987",
                "A23",
                "A7 12345",
                "V9 Euro 6",
                "Q 0.05",
                "T 160",
                "H",
                "P1 1968",
                "P2 90",
                "P3 Diesel",
            ] + cardLegend,
        ],
        expected: ExpectedRegistration(
            plate: "K 5555 BX", firstRegistration: day(2018, 7, 1), vin: "WXY2B34567C890123",
            vehicleClass: "N1", category: .lightCommercial, make: "DEMOMARKE", type: "TESTTYP 12 / A",
            commercialName: "Demo Transporter", maxMassKg: 2800, usageCode: "01"),
        holderStrings: ["MUSTER GMBH", "TESTWEG", "KLAGENFURT", "BEISPIELBEHÖRDE"])

    /// Design 2023 (with A.27) and 2025 look the same for the fields read here. Motorcycle, plate with hyphen.
    static let card2023 = RegistrationFixture(
        name: "chip card 2023, L3e",
        pages: [
            [
                "EUROPÄISCHE GEMEINSCHAFT",
                "REPUBLIK ÖSTERREICH",
                "ZULASSUNGSBESCHEINIGUNG TEIL 1",
                "A S-4455AA",
                "B 10.06.2022",
                "I 11.06.2022",
                "C.1.1 BEISPIEL",
                "C.1.2 ERIKA",
                "C.1.3 PROBEGASSE 7 5020 SALZBURG",
                "C.4 BEISPIELBEHÖRDE",
                "A Kennzeichen",
                "B Erstmalige Zulassung",
                "I Zugelassen",
            ],
            [
                "D1 BEISPIELMOTO",
                "E ZXY3C45678D901234",
                "D2 MX 300 / A2",
                "D3 Beispiel 300",
                "A27 L3e-A2",
                "A4 01",
                "J L3e-A2 Motorrad",
                "S1/2 2/0",
                "F1 450",
                "F2 450",
                "G 180",
                "P5 MX300",
                "A23",
            ] + cardLegend,
        ],
        expected: ExpectedRegistration(
            plate: "S-4455AA", firstRegistration: day(2022, 6, 10), vin: "ZXY3C45678D901234",
            vehicleClass: "L3e-A2", category: .motorcycle, make: "BEISPIELMOTO", type: "MX 300 / A2",
            commercialName: "Beispiel 300", maxMassKg: 450, usageCode: "01"),
        holderStrings: ["ERIKA", "PROBEGASSE", "SALZBURG", "BEISPIELBEHÖRDE"])

    static let all: [RegistrationFixture] = [paperNaturalPerson, paperLegalPersonTaxi, card2010, card2023]

    // MARK: OCR noise and broken lines (paper, natural person)

    /// The same document as `paperNaturalPerson`, read with typical OCR errors: O for 0, l for 1, B read as 8,
    /// I read as 1, D1 as DI, codes without dots.
    static let paperNoisy: [[String]] = [[
        "A1 Zulassungsstelle 1234",
        "A Kennzeichen W 12345 A",
        "1 Zugelassen am: 2O.O3.2O24 H gültig bis:",
        "C11 Familienname MUSTERMANN",
        "C12 Vorname / A3 Geb.datum MAXIMILIAN 01.02.1985",
        "C13 Anschrift BEISPIELGASSE 1 1010 WIEN",
        "C4 Antragsteller ist: Zulassungsbesitzer",
        "A4 Verwendungsbestimmung O1",
        "E FIN WBX1A23456B789O12",
        "8 Erstmalige Zulassung am: 15.O3.2O2O A6 Genehmigungsdatum 10.03.2020",
        "J Klasse / Fahrzeugart Ml Personenkraftwagen",
        "DI Marke BEISPIELMARKE",
        "D3 Handelsbezeichnung Beispiel 1.5",
        "D2 Type/Variante/Version ABC1 / XYZ / 1.0",
        "F1 Techn. zul. Gesamtmasse 21OO",
        "F2 Höchste(s) zulässige(s) Gesamtgewicht 195O",
    ]]

    /// Label and value in separate lines (the text recognizer split the table cells), still in reading order.
    static let paperBroken: [[String]] = [[
        "A Kennzeichen",
        "W 12345 A",
        "I Zugelassen am: 20.03.2024",
        "C1.1 Familienname",
        "MUSTERMANN",
        "A4 Verwendungsbestimmung",
        "01",
        "E FIN",
        "WBX1A23456B789012",
        "B Erstmalige Zulassung am:",
        "15.03.2020",
        "J Klasse / Fahrzeugart",
        "M1 Personenkraftwagen",
        "D1 Marke",
        "BEISPIELMARKE",
        "D3 Handelsbezeichnung",
        "Beispiel 1.5",
        "F2 Höchste(s) zulässige(s) Gesamtgewicht",
        "1950",
    ]]
}
