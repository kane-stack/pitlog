# Beleg-Parser (M5b-Core)

Heuristischer Parser für österreichische Werkstattbelege in `Packages/PitlogCore/Sources/PitlogCore/Receipts/`
(ADR-3, ADR-10). Nur Foundation, Linux-kompatibel. Spezifikation: `docs/sources/receipts/README.md`.
Die App-Anbindung (Scan-Pipeline, Foundation Models hinter `ReceiptExtractor`) kommt später.

**Leitprinzip: lieber `nil` als falsch.** Jedes Feld hat eine Konfidenz (`high`/`medium`/`low`) und die
Quellzeile (`ReceiptDraft.evidence`). Alle Werte sind Vorschläge, der Nutzer bestätigt.

## Aufbau

| Datei | Inhalt |
|---|---|
| `ReceiptModels.swift` | `ReceiptLine`, `ReceiptContext`, `ReceiptDraft`, Protokoll `ReceiptExtractor` |
| `HeuristicReceiptExtractor.swift` | Zusammenspiel; RKSV-Code hat Vorrang |
| `ReceiptText.swift` | Normalisierung (Kleinbuchstaben, Umlaute), Beträge, OCR-Verwechslungen |
| `ReceiptAmounts.swift` | Gesamtbetrag, Netto, USt, Steuersatz, Gutschrift, Kleinunternehmer |
| `ReceiptDates.swift` | Datumsformate und Rollen (Leistung, Rechnung, sonstige) |
| `ReceiptOdometer.swift` | Kilometerstand nur neben einer Bezeichnung |
| `ReceiptIdentifiers.swift` | Kennzeichen, FIN, UID, Werkstattname |
| `ReceiptPositions.swift` | Positionen, Kategorie, vorgeschlagene Plakette |
| `RKSV.swift` | `parseRKSVCode(_:)` für den Kassen-QR-Code |

Der Parser rechnet nur auf Text: Zeilen werden einmal gefaltet (klein, Umlaute ersetzt) und in
Wörter und Beträge zerlegt. Die Reihenfolge der Zeilen ist für die Felder unerheblich; Bezeichnung
und Betrag müssen in derselben Zeile stehen.

## Beträge (E-1: Rechnungsbetrag brutto)

- Formate: `1.234,56`, `1 234,56` (nur in Summenzeilen), `120,-`, `€ 123,45`, `123,45 EUR`, `-12,50`,
  `12,50-`, `(12,50)`. Ganze Zahlen ohne Dezimalstellen zählen nur neben einem Währungssymbol.
- OCR: O→0, l/I→1, S→5, B→8, `€` als `E`/`C`. Nur in Wörtern, die sonst numerisch sind und mehr echte
  Ziffern als Verwechslungen haben.
- **Rangfolge der Bezeichnungen:**
  1. stark: `zu zahlen`, `Zahlbetrag`, `Endbetrag`, `Rechnungsbetrag`, `Gesamtbetrag`, `Gesamt brutto`,
     `Summe brutto`
  2. schwach: `Summe`, `Gesamt`, `Total`, `Brutto`, `Betrag`
- **Nie Gesamtbetrag:** Zeilen mit `netto`, `Zwischensumme`, `Übertrag`, USt/MwSt (außer „inkl. USt“),
  `gegeben`, `Rückgeld`, `Anzahlung`, `Skonto`, Lohn-/Teile-Blocksummen.
- **Anzahlung (E-1):** Steht irgendwo Anzahlung/Akonto, fallen „zu zahlen“, „Zahlbetrag“ und „Restbetrag“
  als Kandidaten weg. Der Gesamtbetrag bleibt.
- Plausibilität: Netto + USt = Brutto (±0,02 €). Bestätigt → `high`; passt nichts zusammen → `low`.
  Mehrere verschiedene Werte in der besten Stufe ohne Bestätigung → `nil`.
- Schwache Bezeichnung ohne Bestätigung → `medium`, mit gleichem Betrag in einer Zahlungszeile (Bankomat,
  Bar) → `high`.
- Kleinbetragsrechnung: nur Brutto plus „inkl. 20 % USt“; Netto und USt bleiben `nil`. Gilt bis 400 €.
- Gutschrift/Storno (Stichwort oder negativer Gesamtbetrag): `grossTotal = nil`, Konfidenz `low`, `isCreditNote`.
- Kleinunternehmer: `isVATExempt`, kein Steuersatz.
- Fehlt jeder Gesamtbetrag, aber Netto und USt sind eindeutig und passen zu einem Steuersatz, wird die
  Summe als `medium` abgeleitet.

## Datum (E-2: Leistungsdatum, sonst Rechnungsdatum)

- Formate: `05.10.2026`, `5.10.2026`, `05.10.26`, `2026-10-05`, `5. Okt. 2026`, `5. Jän. 2027`, `Jänner`,
  `Feber`, `5.Okt.2026`, mit Uhrzeit, mit OCR-Ziffern. Ein Bindestrich trennt nur ISO-Daten.
- Die Rolle ergibt sich aus der nächsten Bezeichnung vor dem Datum (höchstens 6 Wörter, nicht über ein
  anderes Datum hinweg): so bekommen zwei Daten in einer Zeile ihre eigene Rolle.
  - Leistung: `Leistungsdatum`, `Lieferdatum`, `ausgeführt`
  - Rechnung: `Datum`, `Rechnungsdatum`, `Belegdatum`; schwach: „Rechnung vom“, „Beleg“
  - **verworfen:** `fällig`, `zahlbar`, `Skonto`, `Annahme`, `Auftrag`, `Termin`, `nächst…`, `Erstzulassung`,
    `gültig`, `bis`, `Anzahlung`, `Fertigstellung`
- Nicht nach `today` (injiziert, ADR-7) und nicht vor der Erstzulassung.
- Zwei verschiedene Daten derselben Rolle → `nil`. Ein Datum ohne Bezeichnung: mit Uhrzeit `medium`
  (Kassenbon), sonst nur wenn es das einzige ist, `low`.
- `ReceiptDraft.historyDate` = Leistungsdatum, sonst Rechnungsdatum.

## Übrige Felder

- **Kilometerstand:** nur direkt hinter `Kilometerstand`, `km-Stand`, `Laufleistung`, `Tachostand`, `KM`.
  Zeilen mit „nächst…“, Intervallen und Reifen-/Ölangaben zählen nie. Kleiner als der letzte bekannte
  Stand (oder 200 000 km darüber): Wert bleibt, Konfidenz `low`. Verschiedene Werte → `nil`.
- **Kennzeichen:** hinter `Kennzeichen`/`Kennz.`/`Kz`, Form `W 12345 A` (1–2 Buchstaben, 1–5 Ziffern,
  1–3 Buchstaben). Bekannte Kennzeichen aus dem Kontext werden auch ohne Bezeichnung erkannt.
- **FIN:** 17 Zeichen ohne I, O, Q; I/O/Q werden als 1/0/0 gelesen (dann `low`). Mit Bezeichnung `high`.
- **UID:** `ATU` + 8 Ziffern mit Leerzeichen und OCR-Toleranz. Eine UID in einer Kundenzeile
  (`Kunde`, `Empfänger`, `Ihre UID`) oder eine zweite UID ist nie die der Werkstatt. Die Prüfziffer
  (`AustrianUID.isChecksumValid`) senkt bei Fehlschlag nur die Konfidenz auf `medium`.
- **Werkstatt:** Zeile ohne Betrag mit Rechtsform (GmbH, KG, OG, e.U., AG) und/oder Kfz-Stichwort
  (Kfz, Auto, Werkstatt, Reifen, Service …), abgeschnitten an Adresse/Telefon/UID. Zeilen des Kundenblocks
  (`Herrn`, `Frau`, `Empfänger`) zählen nie. Gleichstand verschiedener Namen → `nil`.
- **Kategorie:** Stichwörter in den Positionen (README §6.7), die Kategorie mit der höchsten Betragssumme
  gewinnt. Hinweise („Nächstes Service“) zählen nicht.
- **Plakette:** nur aus einer Zeile mit `Plakette`/`Lochung`/`gelocht`/`Pickerl` und Monat/Jahr, nie aus
  „nächste Begutachtung“. Nur ein Vorschlag (ADR-5), im Bereich heute bis 4 Jahre.
- **Positionen:** Zeilen mit Betrag, ohne Summen, Steuer und Zahlung. Beschreibung ohne Positionsnummer,
  Menge, Einheit und Preis.

## RKSV-QR-Code

`parseRKSVCode(_:)` zerlegt `_R1-AT1_<Kassen-ID>_<Belegnr>_<yyyy-MM-ddTHH:mm:ss>_<5 Beträge>_…`.
Die fünf Beträge sind Brutto für 20 %, 10 %, 13 %, 0 %, 19 %. Bei fehlerhafter Eingabe gibt die Funktion
`nil` zurück, sie stürzt nie ab. Der Code kann über `ReceiptContext.rksvPayloads` oder als Textzeile kommen und hat
für Datum und Gesamtbetrag Vorrang (`high`). Trainingsbelege (`TRA`) und Codes mit Datum in der Zukunft
werden ignoriert, ein Storno (`STO`) ist eine Gutschrift.

**Annahmen, nicht an der Primärquelle geprüft** (README, offener Punkt 1): Feldreihenfolge und Beträge
nach RKSV Anlage 1 aus dem Gedächtnis; Kassen-ID ohne `_`; Base64-Kennungen `VFJB` (TRA) und `U1RP` (STO).
Das Format wird nur mit einem selbst konstruierten Beispiel getestet.

## Genauigkeit

Gemessen vom Test `accuracyReport` über 15 synthetische Belege in je 3 Varianten (sauber, OCR-Rauschen,
vertauschte Zeilen), insgesamt 45 Belege und 765 Felder. Stand: Core-CI auf Linux (`swift:6.2`).

| Feld | richtig | fehlend | **falsch** |
|---|---|---|---|
| Gesamtbetrag brutto | 100 % | 0 % | 0 % |
| Netto | 100 % | 0 % | 0 % |
| USt-Betrag | 100 % | 0 % | 0 % |
| Steuersatz | 100 % | 0 % | 0 % |
| Leistungsdatum | 100 % | 0 % | 0 % |
| Rechnungsdatum | 100 % | 0 % | 0 % |
| Historiendatum | 100 % | 0 % | 0 % |
| Werkstattname | 100 % | 0 % | 0 % |
| Werkstatt-UID | 100 % | 0 % | 0 % |
| Kilometerstand | 100 % | 0 % | 0 % |
| Kennzeichen | 100 % | 0 % | 0 % |
| FIN | 100 % | 0 % | 0 % |
| Kategorie | 100 % | 0 % | 0 % |
| Plakette (Vorschlag) | 100 % | 0 % | 0 % |
| Kleinbetragsrechnung | 100 % | 0 % | 0 % |
| Kleinunternehmer | 100 % | 0 % | 0 % |
| Gutschrift | 100 % | 0 % | 0 % |
| **Alle Felder** | **100 %** | **0 %** | **0 %** |

Positionen: 102 von 102 erwarteten Einträgen gefunden. Pro Variante gleich (je 255 Felder, 0 % falsch).

**Diese Zahl sagt wenig über echte Belege aus.** Die Fixtures hat dieselbe Person geschrieben, die den
Parser geschrieben hat, und das OCR-Rauschen ist ein einfaches Modell (O/l/S/B-Tausch, `€`→`E`). 100 %
heißt: Der Parser deckt die selbst gedachten Fälle ab. Die Gegenprobe sind Christophers echte Belege von
2 Werkstätten (README, offener Punkt 5).

## Grenzen

- Bezeichnung und Betrag müssen in derselben Zeile stehen. Zerlegt die OCR eine Tabelle in Spalten,
  bleiben die Felder `nil`. Eine Zuordnung über Zeilengeometrie wäre Aufgabe der Scan-Pipeline.
- Beschädigte Bezeichnungen (OCR liest „Gesamtbetrag“ als „Gesarntbetrag“) werden nicht repariert.
- Mehrere Fahrzeuge, mehrere Steuersätze (10 % und 20 %) und Rabatte auf Gesamtebene sind nur
  eingeschränkt abgedeckt; bei widersprüchlichen Beträgen lautet das Ergebnis `nil` oder `low`.
- Werkstattname: Ein Kundenname mit Rechtsform und Kfz-Stichwort würde konkurrieren; bei Gleichstand `nil`.
- Die UID-Prüfziffer ist nicht an der BMF-Quelle geprüft (README, offener Punkt 3).
- Fremdwährungen werden erkannt (CHF, GBP, USD, HUF, PLN, CZK), sonst gilt EUR.
- Nur deutsche Bezeichnungen. Andere Länder-Module brauchen eigene Tabellen.
- Der Parser prüft nicht, ob der Beleg zum Fahrzeug passt; das macht die App mit FIN/Kennzeichen.
