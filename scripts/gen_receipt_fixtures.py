#!/usr/bin/env python3
"""Generates the synthetic receipt fixtures for PitlogCore (M5b).

Writes Packages/PitlogCore/Tests/PitlogCoreTests/Fixtures/Receipts/<id>/{clean,noisy,shuffled}.txt
and expected.json. All names, addresses, UIDs (deliberately wrong check digit), VINs and plates are
fictitious. Run: python3 scripts/gen_receipt_fixtures.py
"""
import json
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Packages/PitlogCore/Tests/PitlogCoreTests/Fixtures/Receipts"
PAGE = "=== PAGE ==="


def uid(base7: str) -> str:
    """ATU + 7 digits + a deliberately WRONG check digit (never a real UID)."""
    digits = [int(c) for c in base7]
    total = 0
    for i, d in enumerate(digits):
        if i % 2 == 0:
            total += d
        else:
            p = d * 2
            total += p - 9 if p > 9 else p
    correct = (96 - total) % 10
    return f"ATU{base7}{(correct + 3) % 10}"


U1, U2, U3, U4 = uid("4711220"), uid("5522331"), uid("6633442"), uid("7744553")
U7, U8, U9, U10, U11 = uid("1122334"), uid("2233445"), uid("3344556"), uid("4455667"), uid("5566778")
UCUST = uid("8899001")

VIN_A = "WVWZZZ1KZAW123456"
VIN_B = "WAUZZZ8V5KA654321"
assert len(VIN_A) == 17 and len(VIN_B) == 17

FIXTURES = []


def add(id, lines, expected, today="2026-10-05", first_reg="2018-04", last_km=None, known_plates=(), known_vins=()):
    FIXTURES.append(dict(id=id, lines=lines, expected=expected, context=dict(
        today=today, firstRegistration=first_reg, lastKnownOdometerKm=last_km,
        knownPlates=list(known_plates), knownVINs=list(known_vins))))


# 1. Pickerl cash receipt, small-amount invoice, plaque line, date and time, km
add("kassenbon-pickerl", [
    "Kfz-Meisterbetrieb Huber e.U.",
    "Linzer Straße 12, 4020 Linz",
    "Tel. 0732 123456",
    f"UID: {U1}",
    "KASSENBON",
    "Bon-Nr. 2026-10-0231",
    "Datum: 02.10.2026 14:23",
    "Kennzeichen: L 12345 A",
    "KM-Stand: 87.456",
    "Begutachtung gem. § 57a KFG   79,90",
    "Plakette   2,30",
    "Entsorgungspauschale   7,70",
    "Gesamt € 89,90 inkl. 20 % USt",
    "Bankomat € 89,90",
    "Plakette gelocht: 10/2027",
    "Vielen Dank für Ihren Besuch!",
], dict(gross=8990, vatRate=20, invoiceDate="2026-10-02", workshopName="Kfz-Meisterbetrieb Huber e.U.",
        workshopUID=U1, odometerKm=87456, plate="L 12345 A", category="inspection", plaque="2027-10",
        isSmall=True, workItems=["Begutachtung", "Plakette", "Entsorgungspauschale"]), last_km=85000)

# 2. Tyre change with storage, Bankomat, no km reading
add("raederwechsel", [
    "Reifen & Räder Kral KG",
    "Industriestraße 5, 8020 Graz",
    f"Tel. 0316 987654 · UID: {U2}",
    "Beleg-Nr. 2026/4711",
    "Datum: 21.09.2026 09:41",
    "Kennz.: G 456 AB",
    "Räderwechsel Sommer auf Winter, 4 Stk   79,00",
    "Einlagerung Räder, Saison 2026/27   40,00",
    "Ventile erneuert, 4 Stk   10,00",
    "Summe EUR 129,00",
    "inkl. 20 % USt",
    "Bankomat 129,00",
    "Zahlung mit Karte erfolgt",
], dict(gross=12900, vatRate=20, invoiceDate="2026-09-21", workshopName="Reifen & Räder Kral KG",
        workshopUID=U2, plate="G 456 AB", category="tyres", isSmall=True,
        workItems=["Räderwechsel", "Einlagerung", "Ventile"]))

# 3. Annual service at a franchise workshop: AW, labour and parts blocks, net/VAT/gross over 400 EUR
add("jahresservice", [
    "Autohaus Berger GmbH",
    "Hauptstraße 100, 1100 Wien",
    "Tel. +43 1 5551234 | Fax +43 1 5551299",
    f"FN 123456a | UID: {U3}",
    "IBAN AT61 1904 3002 3457 3201 | BIC BKAUATWW",
    "Herrn",
    "Max Mustermann",
    "Musterweg 1",
    "4020 Linz",
    "RECHNUNG Nr. 2026-0815",
    "Rechnungsdatum: 02.10.2026",
    "Leistungsdatum: 01.10.2026",
    "Annahme: 30.09.2026",
    "Fällig am: 16.10.2026",
    "Auftrags-Nr. 55123 vom 30.09.2026",
    "Kennzeichen: LL 123 AB",
    f"FIN: {VIN_A}",
    "Erstzulassung: 04/2019",
    "Kilometerstand: 87.456 km",
    "Arbeitslohn",
    "Pos. Bezeichnung Menge Preis Betrag",
    "1 Großes Service laut Herstellervorgabe 12,0 AW 18,80 225,60",
    "2 Bremsflüssigkeit wechseln 1,5 AW 18,80 28,20",
    "3 Fehlerspeicher auslesen, Serviceintervall zurückgesetzt 1,0 AW 18,80 18,80",
    "Teile und Material",
    "4 Motoröl 5W-30 VW 504 00 5,5 l 12,90 70,95",
    "5 Ölfilter 04E 115 561 AC 1 Stk 18,50 18,50",
    "6 Dichtring Ölablassschraube 1 Stk 2,40 2,40",
    "7 Pollenfilter 1 Stk 24,90 24,90",
    "8 Bremsflüssigkeit DOT 4 1,0 l 14,20 14,20",
    "9 Entsorgungspauschale Altöl pausch. 6,50",
    "Summe Arbeitslohn netto 272,60",
    "Summe Teile und Material netto 137,45",
    "Gesamt netto 410,05",
    "20 % USt 82,01",
    "Rechnungsbetrag brutto 492,06",
    "Zahlbar innerhalb von 14 Tagen ohne Abzug.",
    "Nächstes Service bei 102.000 km oder in 12 Monaten.",
], dict(gross=49206, net=41005, vat=8201, vatRate=20, serviceDate="2026-10-01", invoiceDate="2026-10-02",
        workshopName="Autohaus Berger GmbH", workshopUID=U3, odometerKm=87456, plate="LL 123 AB", vin=VIN_A,
        category="service", workItems=["Großes Service", "Motoröl", "Ölfilter", "Pollenfilter"]),
    first_reg="2019-04", last_km=80000, known_vins=[VIN_A])

# 4. Repair with discount and deposit: "zu zahlen" differs from the total
add("reparatur-anzahlung", [
    "Kfz-Technik Maier GmbH",
    "Gewerbestraße 8, 5020 Salzburg",
    f"Tel. 0662 445566 · FN 98765x · UID: {U4}",
    "Frau Anna Beispiel",
    "Beispielgasse 3",
    "5020 Salzburg",
    "Rechnung Nr. 2026-1042",
    "Datum: 28.09.2026",
    "Auftrag Nr. 8812 vom 22.09.2026",
    "Kennzeichen: S 987 AB",
    "km-Stand: 143.120",
    "Pos. Bezeichnung Menge Preis Betrag",
    "1 Bremsbeläge vorne, Satz 1 Stk 118,00 118,00",
    "2 Bremsscheiben vorne 2 Stk 96,50 193,00",
    "3 Arbeitszeit Bremsen vorne erneuern 2,0 Std. 190,00 380,00",
    "Zwischensumme netto 691,00",
    "Rabatt 10 % auf Teile -31,10",
    "Summe netto nach Rabatt 659,90",
    "20 % USt 131,98",
    "Gesamtbetrag 791,88",
    "abzgl. Anzahlung vom 22.09.2026 -300,00",
    "zu zahlen 491,88",
    "Vielen Dank für Ihren Auftrag!",
], dict(gross=79188, net=65990, vat=13198, vatRate=20, invoiceDate="2026-09-28",
        workshopName="Kfz-Technik Maier GmbH", workshopUID=U4, odometerKm=143120, plate="S 987 AB",
        category="repair", workItems=["Bremsbeläge", "Bremsscheiben"]), last_km=140000)

# 5. Kleinunternehmer without VAT, service date = invoice date
add("kleinunternehmer", [
    "Gruber Autoservice e.U.",
    "Dorfplatz 2, 3100 St. Pölten",
    "Tel. 02742 334455",
    "Rechnung Nr. 17",
    "Datum: 12.09.2026",
    "Leistungsdatum: 12.09.2026",
    "Herrn Karl Beispiel, Musterstraße 5, 3100 St. Pölten",
    "Kennzeichen: P 4567 AC",
    "Kilometerstand: 64.210",
    "Ölwechsel inkl. Ölfilter 1 Stk 129,00",
    "Wischerblätter vorne Satz 1 Stk 24,00",
    "Gesamtbetrag 153,00",
    "Umsatzsteuerfrei aufgrund der Kleinunternehmerregelung (§ 6 Abs. 1 Z 27 UStG).",
    "Zahlbar bar bei Abholung.",
], dict(gross=15300, serviceDate="2026-09-12", invoiceDate="2026-09-12", workshopName="Gruber Autoservice e.U.",
        odometerKm=64210, plate="P 4567 AC", category="service", isExempt=True,
        workItems=["Ölwechsel", "Wischerblätter"]), first_reg="2015-06", last_km=60000)

# 6. B2B over 10,000 EUR with two UIDs (the second is the customer's)
add("b2b-ueber-10000", [
    "Autohaus Berger GmbH",
    "Hauptstraße 100, 1100 Wien",
    "Tel. +43 1 5551234",
    f"FN 123456a | UID: {U3}",
    "Rechnungsempfänger:",
    "Muster Transport GmbH",
    "Gewerbepark 7, 4600 Wels",
    f"UID Kunde: {UCUST}",
    "RECHNUNG Nr. 2026-0999",
    "Rechnungsdatum: 30.09.2026",
    "Leistungsdatum: 29.09.2026",
    "Kennzeichen: WL 123 AB",
    f"FIN: {VIN_B}",
    "km-Stand: 212.340",
    "1 Austauschmotor 2,2 l Diesel inkl. Einbau 1 Stk 8.490,00 8.490,00",
    "2 Arbeitslohn Motortausch 14,0 Std. 190,00 2.660,00",
    "3 Kühlmittel, Kleinteile pauschal 285,00",
    "Summe netto 11.435,00",
    "20 % USt 2.287,00",
    "Gesamtbetrag brutto 13.722,00",
    "Zahlungsziel: 14 Tage netto.",
], dict(gross=1372200, net=1143500, vat=228700, vatRate=20, serviceDate="2026-09-29", invoiceDate="2026-09-30",
        workshopName="Autohaus Berger GmbH", workshopUID=U3, odometerKm=212340, plate="WL 123 AB", vin=VIN_B,
        category="repair", workItems=["Austauschmotor", "Arbeitslohn"]), first_reg="2017-03", last_km=200000)

# 7a/b/c. Date and amount formats
add("formats-a", [
    "Autoservice Pichler GmbH",
    "Bahnhofstraße 3, 6020 Innsbruck",
    f"Tel. 0512 778899 · UID: {U7}",
    "Rechnung Nr. 2027-0003",
    "Rechnungsdatum: 5. Jän. 2027",
    "Kennzeichen: I 4321 AB",
    "Kilometerstand: 41.280 km",
    "Winterreifen 205/55 R16 91H, 4 Stk à € 215,00 € 860,00",
    "Radschrauben-Set 1 Stk € 100,00",
    "Montage inkl. Wuchten, 4 Stk à € 12,50 € 50,00",
    "Ventile, 4 Stk à € 3,20 € 12,80",
    "Altreifenentsorgung, 4 Stk à € 1,50 € 6,00",
    "Summe netto € 1.028,80",
    "20 % USt € 205,76",
    "Gesamtbetrag € 1.234,56",
], dict(gross=123456, net=102880, vat=20576, vatRate=20, invoiceDate="2027-01-05",
        workshopName="Autoservice Pichler GmbH", workshopUID=U7, odometerKm=41280, plate="I 4321 AB",
        category="tyres", workItems=["Winterreifen", "Montage"]),
    today="2027-02-10", first_reg="2021-06", last_km=38000)

add("formats-b", [
    "Kfz-Werkstätte Bauer OG",
    "Wiener Straße 21, 3500 Krems",
    f"Tel. 02732 667788 · UID: {U8}",
    "Rechnung Nr. 118",
    "Datum: 05.01.27",
    "Kennzeichen: KR 777 AB",
    "KM-Stand: 118.050",
    "Zahnriemensatz inkl. Wasserpumpe 1 Stk 640,00 EUR",
    "Arbeitszeit Zahnriemenwechsel 2,0 Std. 188,00 376,00 EUR",
    "Kleinmaterial pauschal 12,80 EUR",
    "Summe netto 1028,80 EUR",
    "USt 20 % 205,76 EUR",
    "Gesamtbetrag 1234,56 EUR",
], dict(gross=123456, net=102880, vat=20576, vatRate=20, invoiceDate="2027-01-05",
        workshopName="Kfz-Werkstätte Bauer OG", workshopUID=U8, odometerKm=118050, plate="KR 777 AB",
        category="repair", workItems=["Zahnriemensatz", "Arbeitszeit"]),
    today="2027-02-10", first_reg="2019-04", last_km=110000)

add("formats-c", [
    "Pickerl-Station Lang e.U.",
    "Marktplatz 4, 9020 Klagenfurt",
    "Tel. 0463 112233",
    "Kassenbeleg",
    "Datum: 12. Feber 2027",
    "Kennzeichen: KL 89 AB",
    "Km-Stand: 56.300",
    "Begutachtung § 57a KFG, Pkw ...... 118,-",
    "Plakette ...... 2,-",
    "Gesamt € 120,-",
    "inkl. 20 % USt",
], dict(gross=12000, vatRate=20, invoiceDate="2027-02-12", workshopName="Pickerl-Station Lang e.U.",
        odometerKm=56300, plate="KL 89 AB", category="inspection", isSmall=True,
        workItems=["Begutachtung", "Plakette"]),
    today="2027-03-01", first_reg="2020-02", last_km=50000)

# Edge case: total vs. lower "zu zahlen" after the deposit (E-1)
add("deposit-total", [
    "Autohaus Steiner GmbH",
    "Ringstraße 14, 8700 Leoben",
    f"Tel. 03842 998877 | UID: {U9}",
    "Rechnung Nr. 2026-0733",
    "Rechnungsdatum: 15.09.2026",
    "Kennzeichen: LN 321 AB",
    "Kilometerstand: 99.870",
    "Auspuffanlage hinten erneuert 1 Stk 380,00",
    "Montage Auspuff 1,0 Std. 100,00",
    "Summe netto 480,00",
    "20 % USt 96,00",
    "Gesamtbetrag 576,00",
    "abzgl. Anzahlung 200,00",
    "zu zahlen 376,00",
], dict(gross=57600, net=48000, vat=9600, vatRate=20, invoiceDate="2026-09-15",
        workshopName="Autohaus Steiner GmbH", workshopUID=U9, odometerKm=99870, plate="LN 321 AB",
        category="repair", workItems=["Auspuffanlage", "Montage"]), last_km=95000)

# Edge case: service date differs from invoice date (E-2), both on one line
add("service-date", [
    "Reifen- und Autoservice Wallner KG",
    "Hauptplatz 9, 4910 Ried im Innkreis",
    "Tel. 07752 112233",
    f"UID: {U10}",
    "Rechnung Nr. 5521",
    "Rechnungsdatum: 02.10.2026 Leistungsdatum: 28.09.2026",
    "Kennzeichen: RI 555 AB",
    "Kilometerstand: 45.020",
    "Räderwechsel Winter auf Sommer 4 Stk 69,00",
    "Wuchten 4 Stk 16,00",
    "Summe netto 85,00",
    "20 % USt 17,00",
    "Gesamtbetrag 102,00",
], dict(gross=10200, net=8500, vat=1700, vatRate=20, serviceDate="2026-09-28", invoiceDate="2026-10-02",
        workshopName="Reifen- und Autoservice Wallner KG", workshopUID=U10, odometerKm=45020, plate="RI 555 AB",
        category="tyres", workItems=["Räderwechsel", "Wuchten"]), last_km=40000)

# Edge case: credit note
add("credit-note", [
    "Autohaus Berger GmbH",
    "Hauptstraße 100, 1100 Wien",
    f"UID: {U3}",
    "GUTSCHRIFT Nr. G-2026-0012",
    "zu Rechnung 2026-0815 vom 02.10.2026",
    "Datum: 03.10.2026",
    "Kennzeichen: LL 123 AB",
    "Bremsbeläge retour 1 Stk -100,00",
    "Summe netto -100,00",
    "20 % USt -20,00",
    "Gutschriftsbetrag brutto -120,00",
], dict(invoiceDate="2026-10-03", workshopName="Autohaus Berger GmbH", workshopUID=U3, plate="LL 123 AB",
        category="repair", isCreditNote=True, workItems=["Bremsbeläge"]), first_reg="2019-04")

# Edge case: "next service" hint with month and km must not become a date or odometer reading
add("next-service", [
    "Kfz-Meisterbetrieb Huber e.U.",
    "Linzer Straße 12, 4020 Linz",
    f"UID: {U1}",
    "Rechnung Nr. 331",
    "Datum: 18.09.2026",
    "Kennzeichen: L 12345 A",
    "Km-Stand: 87.100",
    "Ölwechsel mit Ölfilter, Motoröl 5W-30 4,5 l 1 Stk 119,00",
    "Luftfilter 1 Stk 22,50",
    "Arbeitszeit 0,5 Std. 188,00 94,00",
    "Summe netto 235,50",
    "20 % USt 47,10",
    "Gesamtbetrag 282,60",
    "Nächstes Service: 10/2027 oder 30.000 km",
], dict(gross=28260, net=23550, vat=4710, vatRate=20, invoiceDate="2026-09-18",
        workshopName="Kfz-Meisterbetrieb Huber e.U.", workshopUID=U1, odometerKm=87100, plate="L 12345 A",
        category="service", workItems=["Ölwechsel", "Luftfilter"]), last_km=80000)

# Edge case: two pages, total on the last page
add("two-page", [
    "Autohaus Berger GmbH",
    "Hauptstraße 100, 1100 Wien",
    f"UID: {U3}",
    "RECHNUNG Nr. 2026-0901",
    "Rechnungsdatum: 01.10.2026",
    "Leistungsdatum: 30.09.2026",
    "Kennzeichen: W 45678 K",
    "Kilometerstand: 120.400 km",
    "1 Zahnriemen-Satz mit Wasserpumpe 1 Stk 420,00 420,00",
    "2 Arbeitslohn Zahnriemenwechsel 5,0 Std. 190,00 950,00",
    "3 Kühlmittel G12 5,0 l 9,00 45,00",
    "Übertrag 1.415,00",
    "Seite 1 von 2",
    PAGE,
    "Autohaus Berger GmbH - Rechnung 2026-0901 - Seite 2 von 2",
    "Übertrag 1.415,00",
    "4 Keilrippenriemen 1 Stk 38,00 38,00",
    "5 Entsorgungspauschale pausch. 7,50",
    "Summe netto 1.460,50",
    "20 % USt 292,10",
    "Rechnungsbetrag brutto 1.752,60",
    "Zahlbar innerhalb von 14 Tagen.",
], dict(gross=175260, net=146050, vat=29210, vatRate=20, serviceDate="2026-09-30", invoiceDate="2026-10-01",
        workshopName="Autohaus Berger GmbH", workshopUID=U3, odometerKm=120400, plate="W 45678 K",
        category="repair", workItems=["Zahnriemen-Satz", "Keilrippenriemen"]), first_reg="2018-05", last_km=110000)

# Cash receipt with RKSV QR code (date and total come from the code)
add("kassenbon-rksv", [
    "Tankstelle & Service Eder e.U.",
    "Salzburger Straße 40, 5071 Wals",
    f"Tel. 0662 887766 · UID: {U11}",
    "KASSENBON",
    "Kasse 01 · Bon 2041",
    "02.10.2026 14:23:11",
    "Kennzeichen: S 111 AB",
    "Motoröl 5W-30, 4,5 l 48,60",
    "Ölfilter 14,90",
    "Arbeitszeit Ölwechsel 11,42",
    "Summe EUR 74,92",
    "inkl. 20 % USt",
    "Bankomat 74,92",
    "_R1-AT1_KASSE01_2041_2026-10-02T14:23:11_74,92_0,00_0,00_0,00_0,00_eHl6Xw==_1A2B3C_dGVzdHNpZ25hdHVyZQ",
], dict(gross=7492, vatRate=20, invoiceDate="2026-10-02", workshopName="Tankstelle & Service Eder e.U.",
        workshopUID=U11, plate="S 111 AB", category="service", isSmall=True,
        workItems=["Motoröl", "Ölfilter", "Arbeitszeit"]))


# ---------------------------------------------------------------- variants

AMOUNT_RE = re.compile(r"(?<![\w.,])(\d{1,3}(?:\.\d{3})*,\d{2}|\d+,\d{2})(?!\w)")
DATE_RE = re.compile(r"(?<!\d)\d{1,2}\.\d{1,2}\.\d{2,4}(?!\d)")
UID_RE = re.compile(r"ATU\d{8}")


def noisy_line(i: int, line: str) -> str:
    """OCR noise: O for 0, l for 1, S for 5, B for 8 in numbers; E/C for €; em dash in '120,-'."""
    if line == PAGE or "_R1-AT" in line:
        return line
    mode = i % 4

    def amount(m: re.Match) -> str:
        t = m.group(1)
        if mode == 0 and "0" in t:
            k = t.rfind("0")
            return t[:k] + "O" + t[k + 1:]
        if mode == 1 and "1" in t:
            k = t.find("1")
            return t[:k] + "l" + t[k + 1:]
        if mode == 2 and "5" in t:
            return t.replace("5", "S", 1)
        if mode == 3 and "8" in t:
            return t.replace("8", "B", 1)
        return t

    out = AMOUNT_RE.sub(amount, line)
    if i % 3 == 0:
        out = out.replace("€ ", "E ")
    elif i % 3 == 1:
        out = out.replace("€ ", "€")
    if i % 2 == 0:
        out = DATE_RE.sub(lambda m: m.group(0).replace("0", "O"), out)
        out = re.sub(r",-(?=\s|$)", ",—", out)
    if UID_RE.search(out):
        def uid_noise(m: re.Match) -> str:
            t = m.group(0)
            for old, new in (("0", "O"), ("1", "l")):
                k = t.find(old, 3)
                if k > 0:
                    return t[:k] + new + t[k + 1:]
            return t
        out = UID_RE.sub(uid_noise, out)
    low = out.lower()
    if "km-stand" in low or "kilometerstand" in low:
        k = out.rfind("0")
        if k > 0:
            out = out[:k] + "O" + out[k + 1:]
    return out


def split_pages(lines):
    pages, cur = [], []
    for line in lines:
        if line == PAGE:
            pages.append(cur)
            cur = []
        else:
            cur.append(line)
    pages.append(cur)
    return pages


def join_pages(pages):
    out = []
    for i, p in enumerate(pages):
        if i:
            out.append(PAGE)
        out.extend(p)
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    expected = {}
    for fx in FIXTURES:
        d = OUT / fx["id"]
        d.mkdir(exist_ok=True)
        clean = fx["lines"]
        noisy = [noisy_line(i, l) for i, l in enumerate(clean)]
        rng = random.Random(fx["id"])
        pages = split_pages(clean)
        for p in pages:
            rng.shuffle(p)
        shuffled = join_pages(pages)
        for name, lines in (("clean", clean), ("noisy", noisy), ("shuffled", shuffled)):
            (d / f"{name}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
        expected[fx["id"]] = dict(context=fx["context"], expected=fx["expected"])
    (OUT / "expected.json").write_text(
        json.dumps(expected, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{len(FIXTURES)} fixtures x 3 variants -> {OUT}")


if __name__ == "__main__":
    main()
