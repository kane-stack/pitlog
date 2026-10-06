import PitlogCore

/// Fake recognition results for the UI tests (`-UITestRegistrationScan`): the simulator has no document camera.
/// The lines go through the real parser. All values are invented.
enum RegistrationScanFixtures {
    /// Paper certificate read with one OCR slip (`O` for `0` in the VIN, so medium) and a first registration that
    /// is later than the date of the current registration (I, so one of the two is misread and B is low).
    /// B stands on the line below its label, which alone is only medium. The holder lines must not show up anywhere.
    static let mixed: [[RecognizedLine]] = [lines([
        "A1 Zulassungsstelle 1234",
        "A Kennzeichen W 12345 A",
        "I Zugelassen am: 20.03.2019 H gültig bis:",
        "C1.1 Familienname MUSTERMANN",
        "C1.2 Vorname / A3 Geb.datum MAXIMILIAN 01.02.1985",
        "C1.3 Anschrift BEISPIELGASSE 1 1010 WIEN",
        "A4 Verwendungsbestimmung 01",
        "E FIN WBX1A23456B789O12",
        "B Erstmalige Zulassung am:",
        "15.03.2020",
        "J Klasse / Fahrzeugart M1 Personenkraftwagen",
        "D1 Marke BEISPIELMARKE",
        "D3 Handelsbezeichnung Beispiel 1.5",
        "D2 Type/Variante/Version ABC1 / XYZ / 1.0",
        "F1 Techn. zul. Gesamtmasse 2100",
        "F2 Höchste(s) zulässige(s) Gesamtgewicht 1950",
    ])]

    /// A heavy truck (class N2), which the inspection rules do not cover yet.
    static let unsupportedClass: [[RecognizedLine]] = [lines([
        "A Kennzeichen LL 7788 X",
        "E FIN WXY2B34567C890123",
        "B Erstmalige Zulassung am: 30.11.2019",
        "J Klasse / Fahrzeugart N2 Lastkraftwagen",
        "D1 Marke DEMO",
        "D3 Handelsbezeichnung Probe 7500",
        "F2 Höchste(s) zulässige(s) Gesamtgewicht 7500",
    ])]

    private static func lines(_ texts: [String]) -> [RecognizedLine] {
        texts.map { RecognizedLine(text: $0) }
    }
}
