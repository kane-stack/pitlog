import Foundation
import Testing
@testable import PitlogCore

private let today = day(2026, 10, 5)
private let context = ReceiptContext(today: today, firstRegistration: ym(2018, 4))

private func draft(_ lines: [String], context: ReceiptContext = context) -> ReceiptDraft {
    HeuristicReceiptExtractor().draft(lines: lines.map { ReceiptLine($0) }, context: context)
}

private func parsed(_ lines: [String]) -> [ParsedLine] {
    lines.enumerated().map { ParsedLine(index: $0.offset, original: $0.element) }
}

// MARK: Amount formats

struct AmountWordCase: Sendable {
    let text: String
    let allowInteger: Bool
    let minor: Int64?
    init(_ text: String, _ minor: Int64?, integer: Bool = false) {
        self.text = text
        self.minor = minor
        self.allowInteger = integer
    }
}

@Test(arguments: [
    AmountWordCase("1.234,56", 123_456), AmountWordCase("1234,56", 123_456), AmountWordCase("123,45", 12_345),
    AmountWordCase("1,234.56", 123_456), AmountWordCase("123.45", 12_345), AmountWordCase("0,99", 99),
    AmountWordCase("120,-", 12_000), AmountWordCase("120,--", 12_000), AmountWordCase("2,-", 200),
    AmountWordCase("-12,50", -1_250), AmountWordCase("12,50-", -1_250), AmountWordCase("(12,50)", -1_250),
    // OCR confusions (the text is folded, so lower case)
    AmountWordCase("12o,5o", 12_050), AmountWordCase("l2,50", 1_250), AmountWordCase("s9,9o", 5_990), AmountWordCase("b,90", 890), AmountWordCase("b,9o", nil),
    // no amounts
    AmountWordCase("05.10.2026", nil), AmountWordCase("05.10.26", nil), AmountWordCase("87.456", nil), AmountWordCase("5w-30", nil),
    AmountWordCase("4,5", nil), AmountWordCase("10/2027", nil), AmountWordCase("abc", nil), AmountWordCase("14:23", nil),
    AmountWordCase("1.23.456,78", nil), AmountWordCase("", nil),
    // integers only next to a currency symbol
    AmountWordCase("1.234", 123_400, integer: true), AmountWordCase("129", 12_900, integer: true), AmountWordCase("129", nil),
])
func parsesAmountWords(_ c: AmountWordCase) {
    #expect(ReceiptText.parseAmount(c.text, allowInteger: c.allowInteger) == c.minor, "\(c.text)")
}

struct LineAmountsCase: Sendable {
    let text: String
    let merge: Bool
    let minors: [Int64]
    init(_ text: String, _ minors: [Int64], merge: Bool = true) {
        self.text = text
        self.minors = minors
        self.merge = merge
    }
}

@Test(arguments: [
    LineAmountsCase("gesamt € 98,50", [9_850]), LineAmountsCase("gesamt 98,50 eur", [9_850]),
    LineAmountsCase("gesamt e 98,50", [9_850]), LineAmountsCase("gesamt €98,50", [9_850]),
    LineAmountsCase("gesamt 98,50€", [9_850]), LineAmountsCase("summe eur 1.234,56", [123_456]),
    LineAmountsCase("summe 1 234,56", [123_456]), LineAmountsCase("summe 1 234,56", [23_456], merge: false),
    LineAmountsCase("ust 20,00 % 16,42", [1_642]), LineAmountsCase("20 % ust 16,42", [1_642]),
    LineAmountsCase("ölfilter 1,00 stk 18,50", [1_850]), LineAmountsCase("kassa 120,-", [12_000]),
    LineAmountsCase("kilometerstand 87.456 km", []), LineAmountsCase("tel. 0732 123456", []),
    LineAmountsCase("rabatt -31,10", [-3_110]),
])
func findsAmountsInLines(_ c: LineAmountsCase) {
    #expect(ReceiptText.amounts(inFolded: ReceiptText.fold(c.text), mergeThousands: c.merge).map(\.minor) == c.minors)
}

// MARK: Dates

struct DateCase: Sendable {
    let text: String
    let date: DayDate?
    let role: ReceiptDates.Role?
    init(_ text: String, _ date: DayDate?, _ role: ReceiptDates.Role? = nil) {
        self.text = text
        self.date = date
        self.role = role
    }
}

@Test(arguments: [
    DateCase("Datum: 05.10.2026", day(2026, 10, 5), .invoice),
    DateCase("Rechnungsdatum 5.10.2026", day(2026, 10, 5), .invoice),
    DateCase("Datum: 05.10.26", day(2026, 10, 5), .invoice),
    DateCase("Datum: 2026-10-05", day(2026, 10, 5), .invoice),
    DateCase("05.10.2026 14:23", day(2026, 10, 5), nil),
    DateCase("Datum: 5. Okt. 2026", day(2026, 10, 5), .invoice),
    DateCase("Datum: 5. Jän. 2027", day(2027, 1, 5), .invoice),
    DateCase("Datum: 5 Jänner 2027", day(2027, 1, 5), .invoice),
    DateCase("Datum: 12. Feber 2027", day(2027, 2, 12), .invoice),
    DateCase("Datum: 5.Okt.2026", day(2026, 10, 5), .invoice),
    DateCase("Datum: O5.1O.2O26", day(2026, 10, 5), .invoice),
    DateCase("Leistungsdatum: 01.10.2026", day(2026, 10, 1), .service),
    DateCase("Fällig am: 16.10.2026", day(2026, 10, 16), .other),
    DateCase("Zahlbar bis 16.10.2026", day(2026, 10, 16), .other),
    DateCase("Auftrag Nr. 8812 vom 22.09.2026", day(2026, 9, 22), .other),
    DateCase("Annahme: 30.09.2026", day(2026, 9, 30), .other),
    DateCase("Erstzulassung: 03.05.2019", day(2019, 5, 3), .other),
    DateCase("Rechnung Nr. 5 vom 03.10.2026", day(2026, 10, 3), .invoiceWeak),
    DateCase("Datum: 31.02.2026", nil),
    DateCase("Nächstes Service: 10/2027", nil),
    DateCase("Re-Nr. 2026-0815", nil),
    DateCase("Artikel 12-34-56", nil),
])
func findsDates(_ c: DateCase) {
    let found = ReceiptDates.find(lines: parsed([c.text]))
    #expect(found.first?.date == c.date, "\(c.text)")
    if c.date != nil { #expect(found.first?.role == c.role, "\(c.text)") }
}

@Test func twoDatesInOneLineGetTheirOwnLabels() {
    let found = ReceiptDates.find(lines: parsed(["Rechnungsdatum: 02.10.2026 Leistungsdatum: 28.09.2026"]))
    #expect(found.map(\.date) == [day(2026, 10, 2), day(2026, 9, 28)])
    #expect(found.map(\.role) == [.invoice, .service])
}

@Test func futureAndPreRegistrationDatesAreRejected() {
    #expect(draft(["Datum: 06.10.2026"]).invoiceDate == nil)
    #expect(draft(["Datum: 05.10.2026"]).invoiceDate == day(2026, 10, 5))
    #expect(draft(["Datum: 31.03.2018"]).invoiceDate == nil)
    #expect(draft(["Datum: 01.04.2018"]).invoiceDate == day(2018, 4, 1))
}

@Test func serviceDateWinsForTheHistory() {
    let d = draft(["Rechnungsdatum: 02.10.2026", "Leistungsdatum: 28.09.2026"])
    #expect(d.historyDate == day(2026, 9, 28))
    let onlyInvoice = draft(["Rechnungsdatum: 02.10.2026"])
    #expect(onlyInvoice.historyDate == day(2026, 10, 2))
}

@Test func conflictingInvoiceDatesGiveNil() {
    #expect(draft(["Datum: 02.10.2026", "Rechnungsdatum: 03.10.2026"]).invoiceDate == nil)
}

@Test func unlabeledDateWithTimeIsAMediumGuess() {
    let d = draft(["02.10.2026 14:23:11"])
    #expect(d.invoiceDate == day(2026, 10, 2))
    #expect(d.confidence(of: .invoiceDate) == .medium)
}

// MARK: Totals

@Test func depositKeepsTheGrossTotal() {
    let d = draft(["Gesamtbetrag 791,88", "abzgl. Anzahlung 300,00", "zu zahlen 491,88"])
    #expect(d.grossTotal?.amountMinor == 79_188)
}

@Test func dueAmountAloneIsTheTotalWithoutDeposit() {
    #expect(draft(["zu zahlen 98,50"]).grossTotal?.amountMinor == 9_850)
}

@Test func dueAmountAfterDepositIsNotTheTotal() {
    #expect(draft(["Anzahlung 50,00", "zu zahlen 48,50"]).grossTotal == nil)
}

@Test func derivesGrossFromNetAndVatWhenNoTotalIsLabelled() {
    let d = draft(["Summe netto 100,00", "20 % USt 20,00", "Anzahlung 50,00", "zu zahlen 70,00"])
    #expect(d.grossTotal?.amountMinor == 12_000)
    #expect(d.confidence(of: .grossTotal) == .medium)
}

@Test func netAndVatAreNeverTheTotal() {
    let d = draft(["Summe netto 82,08", "20 % USt 16,42"])
    #expect(d.grossTotal?.amountMinor == 9_850)
    #expect(d.netTotal?.amountMinor == 8_208)
    #expect(d.vatAmount?.amountMinor == 1_642)
}

@Test func totalsThatDoNotAddUpAreDistrusted() {
    let d = draft(["Summe netto 80,00", "20 % USt 16,00", "Gesamtbetrag 98,50"])
    #expect(d.grossTotal?.amountMinor == 9_850)
    #expect(d.confidence(of: .grossTotal) == .low)
}

@Test func conflictingTotalsGiveNil() {
    #expect(draft(["Gesamtbetrag 98,50", "Rechnungsbetrag 99,50"]).grossTotal == nil)
}

@Test func paymentLinesAreNotTotals() {
    let d = draft(["Bar 100,00", "Rückgeld 10,20", "Gegeben 100,00"])
    #expect(d.grossTotal == nil)
}

@Test func smallAmountInvoice() {
    let d = draft(["Gesamt € 89,90 inkl. 20 % USt"])
    #expect(d.grossTotal?.amountMinor == 8_990)
    #expect(d.vatRate == 20)
    #expect(d.isSmallAmountInvoice)
    #expect(d.netTotal == nil)
}

@Test func creditNoteHasNoTotal() {
    let d = draft(["GUTSCHRIFT Nr. 12", "Gutschriftsbetrag brutto -120,00"])
    #expect(d.isCreditNote)
    #expect(d.grossTotal == nil)
    #expect(d.confidence(of: .grossTotal) == .low)
}

@Test func negativeTotalIsFlaggedEvenWithoutKeyword() {
    let d = draft(["Gesamtbetrag -45,00"])
    #expect(d.isCreditNote)
    #expect(d.grossTotal == nil)
}

@Test func kleinunternehmerIsVATExempt() {
    let d = draft(["Gesamtbetrag 153,00", "Umsatzsteuerfrei aufgrund der Kleinunternehmerregelung"])
    #expect(d.isVATExempt)
    #expect(d.vatRate == nil)
    #expect(!d.isSmallAmountInvoice)
}

@Test func foreignCurrencyIsKept() {
    #expect(draft(["Gesamtbetrag 98,50 CHF"]).grossTotal?.currencyCode == "CHF")
    #expect(draft(["Gesamtbetrag 98,50"]).grossTotal?.currencyCode == "EUR")
}

// MARK: Odometer

struct OdometerCase: Sendable {
    let line: String
    let km: Int?
    init(_ line: String, _ km: Int?) {
        self.line = line
        self.km = km
    }
}

@Test(arguments: [
    OdometerCase("Kilometerstand: 87.456 km", 87_456), OdometerCase("km-Stand: 87 456", 87_456),
    OdometerCase("KM-Stand 87456", 87_456), OdometerCase("KM 87.456", 87_456), OdometerCase("Laufleistung: 87456 km", 87_456),
    OdometerCase("Tachostand 12.345", 12_345), OdometerCase("Kilometerstand: 87.45O km", 87_450),
    OdometerCase("Kilometerstand: 87456km", 87_456),
    OdometerCase("Nächster Service bei 30.000 km", nil), OdometerCase("Nächstes Service: 10/2027 oder 30.000 km", nil),
    OdometerCase("Reifen 205/55 R16 91V", nil), OdometerCase("Motoröl 5W-30 VW 504 00", nil),
    OdometerCase("Auftrags-Nr. 123456", nil), OdometerCase("87.456 km", nil),
    OdometerCase("Kilometerstand: 87.456,5", nil), OdometerCase("Kilometerstand: 87 l", nil),
    OdometerCase("Kilometerpauschale 25,00", nil), OdometerCase("PLZ 4020 Linz", nil),
])
func readsTheOdometerOnlyNextToALabel(_ c: OdometerCase) {
    #expect(draft([c.line]).odometerKm == c.km, "\(c.line)")
}

@Test func odometerBelowTheLastKnownReadingIsKeptButDistrusted() {
    let ctx = ReceiptContext(today: today, lastKnownOdometerKm: 90_000)
    let d = draft(["Kilometerstand: 87.456"], context: ctx)
    #expect(d.odometerKm == 87_456)
    #expect(d.confidence(of: .odometerKm) == .low)
}

@Test func odometerAboveTheLastKnownReadingIsTrusted() {
    let ctx = ReceiptContext(today: today, lastKnownOdometerKm: 80_000)
    #expect(draft(["Kilometerstand: 87.456"], context: ctx).confidence(of: .odometerKm) == .high)
}

@Test func conflictingOdometerReadingsGiveNil() {
    #expect(draft(["Kilometerstand: 87.456", "km-Stand: 87.999"]).odometerKm == nil)
}

// MARK: Plate, VIN, UID

struct StringCase: Sendable {
    let line: String
    let expected: String?
    init(_ line: String, _ expected: String?) {
        self.line = line
        self.expected = expected
    }
}

@Test(arguments: [
    StringCase("Kennzeichen: W 12345 A", "W 12345 A"), StringCase("Kennz.: W-12345A", "W 12345 A"),
    StringCase("Kennzeichen W-12345 A", "W 12345 A"), StringCase("Kz: G 456 AB", "G 456 AB"),
    StringCase("Pol. Kennzeichen: LL 123 AB", "LL 123 AB"), StringCase("Kennzeichen: W 12345 A  FIN: X", "W 12345 A"),
    StringCase("Kennzeichen W 12345 KM-Stand 80000", nil), StringCase("Kennzeichen: -", nil),
    StringCase("W 12345 A", nil),
])
func readsThePlateNextToALabel(_ c: StringCase) {
    #expect(draft([c.line]).plate == c.expected, "\(c.line)")
}

@Test func knownPlateIsRecognizedWithoutLabel() {
    let ctx = ReceiptContext(today: today, knownPlates: ["W-12345 A"])
    let d = draft(["Fahrzeug W 12345 A Service"], context: ctx)
    #expect(d.plate == "W-12345 A")
}

@Test(arguments: [
    StringCase("FIN: WVWZZZ1KZAW123456", "WVWZZZ1KZAW123456"), StringCase("Fgst.-Nr. wvwzzz1kzaw123456", "WVWZZZ1KZAW123456"),
    StringCase("VIN WAUZZZ8V5KA654321", "WAUZZZ8V5KA654321"), StringCase("FIN: WVWZZZ1KZAW12345O", "WVWZZZ1KZAW123450"),
    StringCase("FIN: WVWZZZ1KZAW12345", nil), StringCase("Herstellervorgabe Service", nil),
])
func readsTheVIN(_ c: StringCase) {
    #expect(draft([c.line]).vin == c.expected, "\(c.line)")
}

@Test func vinWithSubstitutedLettersIsLowConfidence() {
    #expect(draft(["FIN: WVWZZZ1KZAW12345O"]).confidence(of: .vin) == .low)
    #expect(draft(["FIN: WVWZZZ1KZAW123456"]).confidence(of: .vin) == .high)
}

@Test(arguments: [
    StringCase("UID: ATU47112203", "ATU47112203"), StringCase("UID-Nr.: ATU 4711 2203", "ATU47112203"),
    StringCase("UID ATU 47112203", "ATU47112203"), StringCase("UID: ATU4711220O", "ATU47112200"),
    StringCase("UID: ATU4711l2O3", "ATU47111203"), StringCase("UID: ATU4711220", nil), StringCase("UID: DE123456789", nil),
])
func readsTheWorkshopUID(_ c: StringCase) {
    #expect(draft([c.line]).workshopUID == c.expected, "\(c.line)")
}

@Test func secondUIDIsTheCustomers() {
    let d = draft(["UID: ATU47112203", "UID Kunde: ATU88990015"])
    #expect(d.workshopUID == "ATU47112203")
    let onlyCustomer = draft(["Ihre UID: ATU88990015"])
    #expect(onlyCustomer.workshopUID == nil)
    let ambiguous = draft(["UID: ATU47112203", "UID: ATU88990015"])
    #expect(ambiguous.workshopUID == nil)
}

@Test func uidChecksum() {
    // Example number from the python-stdnum documentation (see AustrianUID.isChecksumValid).
    #expect(AustrianUID.isChecksumValid("ATU13585627"))
    #expect(AustrianUID.isChecksumValid("atu 1358 5627"))
    #expect(!AustrianUID.isChecksumValid("ATU13585628"))
    #expect(!AustrianUID.isChecksumValid("ATU1358562"))
    #expect(!AustrianUID.isChecksumValid("DE13585627"))
}

@Test func invalidChecksumLowersTheUIDConfidenceButKeepsTheValue() {
    let valid = draft(["UID: ATU13585627"])
    #expect(valid.workshopUID == "ATU13585627")
    #expect(valid.confidence(of: .workshopUID) == .high)
    let invalid = draft(["UID: ATU13585628"])
    #expect(invalid.workshopUID == "ATU13585628")
    #expect(invalid.confidence(of: .workshopUID) == .medium)
}

// MARK: Workshop

@Test(arguments: [
    StringCase("Autohaus Berger GmbH", "Autohaus Berger GmbH"),
    StringCase("Kfz-Meisterbetrieb Huber e.U.", "Kfz-Meisterbetrieb Huber e.U."),
    StringCase("Autohaus Berger GmbH, Hauptstraße 100, 1100 Wien", "Autohaus Berger GmbH"),
    StringCase("Autohaus Berger GmbH · Tel. 01 5551234", "Autohaus Berger GmbH"),
    StringCase("Reifen Express Telfs OG", "Reifen Express Telfs OG"),
    StringCase("Herrn Max Mustermann GmbH", nil), StringCase("Max Mustermann", nil),
    StringCase("Nächstes Service: 10/2027", nil), StringCase("Service laut Plan 120,00", nil),
])
func readsTheWorkshopName(_ c: StringCase) {
    #expect(draft([c.line]).workshopName == c.expected, "\(c.line)")
}

@Test func customerCompanyIsNotTheWorkshop() {
    let d = draft(["Rechnungsempfänger:", "Muster Transport GmbH", "Autohaus Berger GmbH"])
    #expect(d.workshopName == "Autohaus Berger GmbH")
    let onlyCustomer = draft(["Herrn", "Muster Transport GmbH Wels"])
    #expect(onlyCustomer.workshopName == "Muster Transport GmbH Wels")
}

// MARK: Category and plaque

struct CategoryCase: Sendable {
    let lines: [String]
    let category: MaintenanceCategory?
}

@Test(arguments: [
    CategoryCase(lines: ["Pickerl § 57a 79,90", "Plakette 2,30"], category: .inspection),
    CategoryCase(lines: ["Räderwechsel mit Wuchten 79,00"], category: .tyres),
    CategoryCase(lines: ["Ölwechsel mit Ölfilter 119,00"], category: .service),
    CategoryCase(lines: ["Bremsbeläge vorne 118,00"], category: .repair),
    CategoryCase(lines: ["Service 250,00", "Pickerl § 57a 80,00"], category: .service),
    CategoryCase(lines: ["Nächstes Service: 10/2027"], category: nil),
    CategoryCase(lines: ["Sonderteil Xyz 50,00"], category: .repair),
    CategoryCase(lines: ["Gesamt 50,00"], category: nil),
])
func suggestsACategoryFromKeywords(_ c: CategoryCase) {
    #expect(draft(c.lines).suggestedCategory == c.category, "\(c.lines)")
}

@Test func plaqueOnlyFromAnExplicitPunchLine() {
    #expect(draft(["Pickerl § 57a 79,90", "Plakette gelocht: 10/2027"]).suggestedPlaque == ym(2027, 10))
    #expect(draft(["Neue Plakette: Okt. 2027"]).suggestedPlaque == ym(2027, 10))
    #expect(draft(["Lochung 10/27"]).suggestedPlaque == ym(2027, 10))
    // "next inspection" is a recommendation, not the punch
    #expect(draft(["Nächste Begutachtung Plakette 10/2027"]).suggestedPlaque == nil)
    #expect(draft(["Nächstes Service: 10/2027"]).suggestedPlaque == nil)
    // implausible: in the past or far in the future
    #expect(draft(["Plakette gelocht: 10/2020"]).suggestedPlaque == nil)
    #expect(draft(["Plakette gelocht: 10/2040"]).suggestedPlaque == nil)
    // two different punches
    #expect(draft(["Plakette: 10/2027", "Lochung: 11/2027"]).suggestedPlaque == nil)
}

// MARK: Work items

@Test func workItemsHaveNoPricesQuantitiesOrPositionNumbers() {
    let d = draft([
        "1 Großes Service laut Herstellervorgabe 12,0 AW 18,80 225,60",
        "4 Motoröl 5W-30 VW 504 00 5,5 l 12,90 70,95",
        "Entsorgungspauschale pausch. 6,50",
        "Summe netto 410,05",
        "20 % USt 82,01",
        "Gesamtbetrag 492,06",
        "Bankomat 492,06",
    ])
    #expect(d.workItems == ["Großes Service laut Herstellervorgabe", "Motoröl 5W-30 VW", "Entsorgungspauschale"])
}

// MARK: Protocol

@Test func extractorConformsToTheProtocol() async {
    let any: any ReceiptExtractor = HeuristicReceiptExtractor()
    let result = await any.extract(lines: [ReceiptLine("Gesamtbetrag 10,00")], context: context)
    #expect(result.grossTotal?.amountMinor == 1_000)
}

@Test func emptyAndGarbageInputNeverCrashes() {
    #expect(draft([]).grossTotal == nil)
    let garbage = ["", "   ", "€€€", ",,,", "---", "()", "\u{0}\u{1}", "9999999999999999999999,99", "_R1-AT", "ATU", "%", "1 2 3 4"]
    let d = draft(garbage)
    #expect(d.grossTotal == nil)
    #expect(d.workItems.isEmpty)
}
