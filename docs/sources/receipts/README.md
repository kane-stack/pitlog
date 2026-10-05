# Werkstattrechnungen (AT): Recherche für Testdaten und Parser (M5b)

> **Stand 05.10.2026.** Recherche aus der Cloud-Session. WebFetch war für alle getesteten Hosts
> gesperrt, deshalb stammen alle Angaben aus Suchergebnissen und deren Auszügen.
> - **[Q]**: belegt durch Suchergebnisse, Volltext nicht gelesen.
> - **[A]**: allgemeines Fachwissen, keine geprüfte Quelle.
>
> Bevor eine [Q]-Angabe rechtlich verwendet wird, muss der Volltext lokal geprüft werden.
> **Es gibt keine öffentlichen österreichischen Werkstattrechnungen als Muster.** Die Testdaten
> sind deshalb synthetisch (Abschnitt 8). Christophers echte Belege von 2 Werkstätten dienen als
> Gegentest.

## 1. Pflichtangaben auf Rechnungen in Österreich (§ 11 UStG)

### 1.1 Normale Rechnung (über 400 € brutto) [Q]

1. Name und Anschrift des leistenden Unternehmers
2. Name und Anschrift des Leistungsempfängers
3. Menge und handelsübliche Bezeichnung bzw. Art und Umfang der Leistung
4. Tag oder Zeitraum der Leistung
5. Entgelt (netto) und Steuersatz
6. Steuerbetrag
7. Ausstellungsdatum
8. Fortlaufende, einmalige Nummer
9. UID des Leistenden („ATU…“)
10. Über 10.000 € brutto zusätzlich die UID des Empfängers, nur bei Leistungen an Unternehmen

**Quellen:**
- https://www.wtkufstein.at/downloadcontent/Rechnungsmerkmale.pdf
- https://www.Salzburg.gv.at/gesellschaft_/Documents/Integration/Dokumente/Rechnungsmerkmale.pdf
- https://freefinance.at/fakturierung/rechnung-schreiben.html
- https://www.usp.gv.at/themen/steuern-finanzen/umsatzsteuer-ueberblick/weitere-informationen-zur-umsatzsteuer/umsaetze-mit-auslandsbezug/umsatzsteuer-identifikationsnummer.html

### 1.2 Kleinbetragsrechnung (bis 400 € inkl. USt) [Q]

**Pflichtangaben:**
- Name und Anschrift des Leistenden
- Menge und Bezeichnung der Leistung
- Tag oder Zeitraum der Leistung
- Bruttobetrag
- Steuersatz
- Ausstellungsdatum

**Nicht nötig:** Empfänger, UID, Netto, Steuerbetrag.

**Quellen:**
- https://freefinance.at/fakturierung/kleinbetragsrechnung.html
- https://www.everbill.com/rechnung-schreiben-vorlage/

**Wichtig für uns:** Pickerl (ca. 60 bis 160 €) und Räderwechsel (ca. 66 bis 174 €) liegen praktisch
immer unter 400 €. Solche Belege haben deshalb oft weder Netto noch USt-Betrag noch UID, zum
Beispiel „Gesamt € 89,90 inkl. 20 % USt“.

### 1.3 Kassenbelege (§ 132a BAO, RKSV) [Q]

**Mindestinhalt:**
- Unternehmen
- fortlaufende Nummer
- Datum
- Menge und Bezeichnung
- Betrag

**Bei Registrierkassen zusätzlich:**
- Kassen-ID
- Datum **und Uhrzeit**
- Beträge nach Steuersätzen
- **QR-Code** nach RKSV Anlage 1: enthält Kassen-ID, Belegnummer, Datum/Uhrzeit (ISO 8601) und Beträge je Steuersatz. Welche Teile davon im Klartext stehen, ist offen.

**Quellen:**
- https://www.usp.gv.at/themen/steuern-finanzen/steuerliche-rechte-und-pflichten/registrierkassen/kassenbelege.html
- https://www.bmf.gv.at/themen/steuern/fuer-unternehmen/registrierkassen.html
- https://www.jusline.at/gesetz/rksv/paragraf/anlage1.pdf

**Idee für M5b:** Wenn ein RKSV-QR-Code vorhanden ist, liefert er Datum und Betrag sehr
zuverlässig. Vision erkennt QR-Codes.

### 1.4 Kleinunternehmer [Q]

Seit 01.01.2025 gilt eine Umsatzgrenze von 55.000 €. Kleinunternehmer stellen Rechnungen ohne USt
aus, mit Hinweis „Umsatzsteuerfrei aufgrund der Kleinunternehmerregelung“ bzw. „§ 6 Abs. 1 Z 27
UStG“. Die genaue Formulierung ist nicht geprüft.

**Quellen:**
- https://www.usp.gv.at/themen/steuern-finanzen/umsatzsteuer-ueberblick/weitere-informationen-zur-umsatzsteuer/weitere-steuertatbestaende-und-befreiungen/kleinunternehmen.html
- https://www.usp.gv.at/aktuelles/newsliste/kleinunternehmerregelung-ab-2025.html

### 1.5 UID [Q]

Format: `ATU` plus 8 Ziffern, die letzte Ziffer ist eine Prüfziffer. Oft mit Leerzeichen geschrieben: `ATU 12345678`.

**Quellen:**
- https://freefinance.at/steuern/uid-nummer.html
- https://www.wko.at/steuern/uid-nummer-umsatzsteuer-identifikationsnummer

Den Prüfziffer-Algorithmus haben wir noch nicht aus einer Primärquelle geprüft.

### 1.6 Steuersatz und Bezeichnungen [A]

Werkstattleistungen und Teile werden mit 20 % versteuert.

| Bedeutung | Übliche Bezeichnungen |
|---|---|
| Netto | Netto, Nettobetrag, Summe netto, Zwischensumme, Entgelt |
| Steuer | USt, Ust., MwSt, MWSt., 20 % USt, Umsatzsteuer 20 % |
| Brutto | Gesamtbetrag, Rechnungsbetrag, Endbetrag, Summe, Gesamt, Total, Brutto, zu zahlen, Zahlbetrag |
| Zahlung | Bar, Bankomat, Kreditkarte, gegeben, Rückgeld |

## 2. Aufbau einer Werkstattrechnung

### 2.1 Kopf- und Fahrzeugdaten

- **Fahrzeugdaten [Q]:** Kennzeichen, FIN, km-Stand bei Annahme, Erstzulassung und Auftragsnummer. Quelle (DE): https://kfz-dietrich.com/blog/auto-werkstatt-rechnung-werkstatt-pflichtangaben-verstehen/
- **Feldbezeichnungen [A]:**
  - Re.-Nr., Beleg-Nr., Auftrags-Nr., Kunden-Nr.
  - Annahme, Fertigstellung, Leistungsdatum, Rechnungsdatum, Fällig am
  - Kennzeichen/Kz., FIN/Fgst.-Nr./VIN, EZ
  - Kilometerstand, km-Stand, KM, Laufleistung, Tachostand
  - Serviceberater
- **Keine Feldcodes [A]:** Codes wie beim Zulassungsschein (A, B, E …) gibt es auf Rechnungen nicht.

### 2.2 Positionen

- **Arbeitswerte (AW) [Q]:** Werkstätten rechnen Arbeitszeit oft in Arbeitswerten. Ein AW entspricht 5 oder 6 Minuten, je nach Hersteller.
  - https://kfz-dietrich.com/blog/stundenverrechnungssatz-arbeitswerte-aw-verstehen/
  - https://www.autobild.de/artikel/werkstattrechnung-38427.html
- **WKO-Preisverzeichnis [Q]:** Es nennt Stundensätze, Entsorgungskosten und Abstellgebühr.
  - https://www.wko.at/oe/gewerbe-handwerk/fahrzeugtechnik/preisverzeichnis-kraftfahrzeugtechnik.pdf
- **Gliederung [A]:**
  - Blöcke: „Arbeitslohn“ und „Teile/Material“, oft mit eigenen Zwischensummen.
  - Spalten: Pos., Art.-Nr., Bezeichnung, Menge/AW/Std., Einheit (Stk, l, AW, Std, pausch.), Einzelpreis, Rabatt %, Betrag.
- **Typische Positionen [A]:**
  - Service laut Herstellervorgabe, Inspektion
  - Motoröl 5W-30 4,5 l, Ölfilter, Dichtring
  - Luft-, Pollen- und Kraftstofffilter, Zündkerzen
  - Bremsflüssigkeit DOT 4, Bremsbeläge, Bremsscheiben
  - Wischerblätter
  - **§ 57a Begutachtung/Pickerl, Plakette**
  - Räderwechsel/Umstecken, Wuchten, Ventile, Reifeneinlagerung/Räderhotel, Reifenwäsche
  - Altöl-/Entsorgungs-/Umweltpauschale, Kleinmaterial
  - Fehlerspeicher auslesen, Probefahrt, Serviceintervall rückgestellt

### 2.3 Preise in Österreich

**AK Wien, Erhebung März 2026, 32 Wiener Werkstätten [Q]:**
- Pickerl Pkw: 60,30 bis 156,40 € inkl. Plakette, im Schnitt ca. 94 €.
- Mitgliederpreise: ÖAMTC 60,30 €, ARBÖ 69,90 €.
- Stundensatz Service: 144 bis 334 €, im Schnitt 188 €.
- Stundensatz Reparatur: 150 bis 338 €, im Schnitt 196 €.

Quellen:
- https://wien.arbeiterkammer.at/beratung/konsumentenschutz/auto/KFZ-Pickerlkosten-2026.pdf
- https://wien.arbeiterkammer.at/beratung/konsumentenschutz/auto/KFZ-Reparaturpreise-2026.pdf

**Räderwechsel, AK OÖ 2025 [Q]:**
- Umstecken und Wuchten: 66 bis 98 €.
- Komplett mit Einlagerung: 99 bis 174 €.

Quellen:
- https://www.tips.at/nachrichten/linz-land/wirtschaft-politik/679339-reifenwechsel-in-linz-und-linz-land-preisvergleich-der-ak-offenbart-grosse-unterschiede
- https://autorevue.at/ratgeber/reifenwechsel-einlagerung-preis-vergleich

**Service gesamt [A]:** Kleines Service ca. 200 bis 450 €, großes Service 400 bis über 900 €. Das ist nur ein Plausibilitätsrahmen.

**Plakettenpreis:** Die Angaben widersprechen sich (2,30 € bzw. 1,90 €) und sind ungeklärt.

## 3. Werkstattketten in AT (nur Geprüftes)

- **Forstinger:** 68 Fachwerkstätten. Quelle: https://www.karriere.at/f/forstinger-%C3%B6sterreich
- **Lucky Car:** größte freie Kette, 62 Standorte, bietet unter anderem § 57a an.
- **ÖAMTC und ARBÖ:** Prüfstellen.
- **Porsche Inter Auto:** Händlernetz.
- **Vergölst:** nur für Deutschland belegt.
- **Nicht geprüft:** Denzel, Birner, Pitstop.

**Öffentliche Musterbelege:** Für keine Kette gefunden. In den Testdaten verwenden wir deshalb nur
**erfundene** Werkstätten.

## 4. Öffentliche Muster und Vorlagen

Es gibt nur allgemeine Rechnungsvorlagen, keine österreichische Kfz-Werkstattrechnung:
- sevdesk Kfz-Rechnung: DE
- everbill-Vorlage: AT, allgemein
- WKO-Preisverzeichnis: Aushang, keine Rechnung

Nichts davon wurde heruntergeladen oder übernommen.

## 5. Formate [A]

- **Datum:**
  - `05.10.2026`, `5.10.2026`, `05.10.26`, `2026-10-05`
  - `5. Okt. 2026`, **„Jänner/Jän.“**, selten „Feber“
  - Kassen: `05.10.2026 14:23`
- **Zahlen:**
  - `1.234,56`, `1 234,56`, `120,-`, `120,--`
  - negativ: `-12,50`, `12,50-`, `(12,50)`
- **Beträge:** `€ 123,45` (in AT häufig), `123,45 €`, `EUR 123,45`, `123,45 EUR`
- **Mengen:** `4,5 l`, `1,0 Std.`, `12 AW`, `1 Stk`, `pausch.`
- **km:** `87.456 km`, `KM 87.456`, `km-Stand: 87 456`

## 6. Hinweise für den Parser

### 1. Gesamtbetrag
- **Bevorzugte Bezeichnungen:** „zu zahlen“, „Zahlbetrag“, „Endbetrag“, „Rechnungsbetrag“, „Gesamtbetrag“ vor „Summe“, „Gesamt“ und „Total“.
- **Nie der Gesamtbetrag:** „Netto“, „Zwischensumme“, „USt“ oder „MwSt“.
- **Plausibilität:** Netto + 20 % ≈ Brutto, mit ±0,02 € Toleranz.
- **Kleinbetragsrechnung:** nur Brutto mit „inkl. 20 % USt“.

### 2. Datum
- **Reihenfolge:** zuerst Leistungs-/Rechnungsdatum (Auswahl siehe Entscheidung E-2), danach Belegdatum.
- **Abwerten:** Fälligkeit, Annahme, Auftragsdatum, Termin und Empfehlungen wie „Nächstes Service 10/2027“.
- **Nicht in der Zukunft:** Das Datum darf nicht nach `today` liegen (injiziert, ADR-7).

### 3. Werkstatt
- **Wo:** Kopfzeilen.
- **Erkennungsmerkmale:** Rechtsform (GmbH, KG, OG, e.U., AG) sowie die Nähe zur UID, zur Firmenbuchnummer `FN \d+[a-z]`, zu Telefon und PLZ.
- **Nicht verwechseln mit dem Kundenblock:** Adressfenster, „Herrn/Frau“.

### 4. UID
- **Muster:** `\bATU\s?\d{8}\b`, mit OCR-Toleranz.
- **Zwei UIDs:** Die zweite ist die UID des Kunden (B2B).

### 5. Kilometerstand
- **Nur mit Bezeichnung übernehmen:** „Kilometerstand“, „km-Stand“, „Laufleistung“ usw.
- **Plausibilität:** gegen den letzten bekannten Stand prüfen.
- **Bestätigung:** immer durch den Nutzer.

### 6. Fahrzeugzuordnung
Über FIN (17 Zeichen, ohne I, O, Q) oder Kennzeichen.

### 7. Kategorie aus Stichwörtern
- `57a|Pickerl|Begutachtung|Plakette` → Pickerl
- `Räderwechsel|Reifenwechsel|Umstecken|Wuchten|Einlagerung` → Reifen
- `Service|Inspektion|Ölwechsel|Motoröl|Ölfilter` → Service
- sonst Reparatur bzw. Sonstiges

## 7. Typische Fallstricke

### Beträge
- Netto, USt, Brutto und Zwischensummen stehen oft nebeneinander.
- Rabatt.
- **Anzahlung/Akonto**: Dann ist „zu zahlen“ kleiner als „Gesamtbetrag“ (siehe E-1).
- „gegeben“ und „Rückgeld“ auf Kassenbons.
- Einzelpreis gegenüber Betrag.
- Gutschrift oder Storno.
- Kleinunternehmer ohne USt.

### Datum
- Rechnungs-, Leistungs-, Annahme-, Fertigstellungs- und Fälligkeitsdatum.
- Empfehlung für das nächste Service.
- Erstzulassung.
- Skontofrist.

### Zahlen, die kein km-Stand sind
- Rechnungs-, Auftrags- und Kundennummer, Teilenummern.
- „Nächster Service bei 30.000 km“.
- PLZ, Telefon, IBAN, Firmenbuchnummer.
- ccm, kW/PS, Reifendimension `205/55 R16 91V`, Ölnorm `5W-30` / `VW 504 00`.

### Pickerl-Beleg
Auf dem Beleg steht oft die neue Lochung. Die App darf sie höchstens **vorschlagen**, nie automatisch setzen (ADR-5).

### OCR
- Verwechslungen: O↔0, l↔1, S↔5, B↔8, Komma↔Punkt; „€“ wird als „E“ oder „C“ gelesen.
- Thermopapier ist oft blass.
- Bei mehrseitigen Rechnungen steht die Summe auf der letzten Seite.

## 8. Synthetische Testbelege (Vorgabe für M5b)

1. Pickerl-Kassenbon, Kleinbetrag 89,90 € inkl. 20 % USt, Plakette als eigene Zeile, Datum und Uhrzeit, km.
2. Räderwechsel mit Einlagerung, 129,00 €, Bankomat.
3. Jahresservice einer Vertragswerkstatt in AW, Lohn- und Teileblock, Netto/USt/Brutto über 400 €, Fälligkeit, „Nächstes Service bei … km“.
4. Reparatur mit Rabatt und Anzahlung, „zu zahlen“ ≠ Gesamtbetrag.
5. Kleinunternehmer ohne USt.
6. B2B über 10.000 € mit zwei ATU-Nummern.
7. Datums- und Betragsvarianten: „5. Jän. 2027“, `05.01.27`, `€ 1.234,56`, `1234,56 EUR`, `120,-`.

**Für alle Testbelege gilt:**
- Jeder Beleg gibt es in drei Varianten: sauber, mit OCR-Rauschen und mit vertauschter Zeilenfolge.
- Namen, Adressen, UIDs (mit absichtlich falscher Prüfziffer), FINs und Kennzeichen sind fiktiv.

## Entscheidungen (offen, siehe CLAUDE.md)

- **E-1:** Als Kosten zählt der **Rechnungsbetrag brutto** oder der Restbetrag nach Anzahlung?
- **E-2:** Als Datum in der Historie gilt das **Leistungsdatum** oder das Rechnungsdatum?

## Offene Punkte

1. Volltexte lokal prüfen: § 11 UStG, USP-Seite „Kassenbelege“, RKSV Anlage 1 (Klartextfelder des QR-Codes), AK-PDFs.
2. Plakettenpreis.
3. Prüfziffer-Algorithmus der UID aus einer Primärquelle (BMF).
4. Präsenz von Vergölst, Birner, Pitstop und Denzel in AT.
5. Echte Belege: Christopher liefert Belege von 2 Werkstätten als Gegentest.
6. Wie viele Werkstattbelege einen RKSV-QR-Code tragen (vermutlich nur Kassenbons).
