# PDF-Servicenachweis (M6b)

Ein PDF pro Fahrzeug mit Fahrzeugdaten und Wartungshistorie, z. B. für den Verkauf des Autos. Pro-Funktion (ADR-11, `ProFeature.serviceRecordExport`, `Entitlements.canExportServiceRecord`).
Alles läuft auf dem Gerät: keine Netzwerkaufrufe, keine Drittanbieter (ADR-12). Das PDF verlässt das Gerät erst, wenn der Nutzer es teilt.

## 1. Ablauf

1. Historie → Zeile **„Servicenachweis exportieren“** (mit Pro-Kennzeichen ohne Pro; Tippen öffnet dann die Paywall mit Kontext `serviceRecordExport`).
2. **Optionen-Sheet** (siehe 3), Knopf „Erstellen“.
3. Das PDF wird im Hintergrund erzeugt (Fortschrittsanzeige), dann öffnet die **Vorschau** (PDFKit, `PDFView`).
4. **Teilen** (`ShareLink`) übergibt die Datei, z. B. an AirDrop, Mail oder Dateien.
5. Schließt der Nutzer das Sheet, wird der Ordner mit den temporären Dateien gelöscht (`ServiceRecordTempFiles.sweep()`). Beim App-Start wird er ebenfalls geleert, falls die App mitten im Export beendet wurde.

Der Einstieg liegt nur in der Historie, nicht zusätzlich im Fahrzeugdetail. Ein Fahrzeug über dem Gratis-Limit ist lesbar; der Export ist dort wie überall Pro.

## 2. Inhalt des PDFs (A4, Seiten „Seite x von y“)

1. **Kopf:** Titel „Servicenachweis“ / „Service record“, Erstellungsdatum.
2. **Fahrzeug:** Kennzeichen, Marke und Typ (Name in Klammern, wenn er abweicht), FIN (optional), Erstzulassung (Monat und Jahr), Fahrzeugart, **letzter bekannter Kilometerstand mit Datum**, Pickerl: **der gelochte Monat und das Jahr der Plakette** mit dem Hinweis „Maßgeblich ist die Plakette am Fahrzeug“ (ADR-5). Das PDF zeigt **keine berechnete Frist**.
   Fehlende Werte stehen als „Nicht erfasst“.
3. **Historie** als Tabelle: Nr., Datum, km, Kategorie, Werkstatt und Arbeiten, Betrag (optional), Beleg.
4. **Kosten** (nur mit Beträgen): Summe je Jahr und gesamt, **je Währung getrennt**, nie umgerechnet (`Money`, `Int64` in Minor Units, kein `Double`).
5. **Anhang** (optional): die Belege (Fotos und PDF-Seiten), je Eintrag mit Kopfzeile „Beleg zu Eintrag 3: 14. März 2026, Service, Autohaus Müller“.
6. **Fuß auf jeder Seite:** „Angaben vom Fahrzeughalter erfasst, nicht geprüft. Erstellt mit Pitlog.“ und „Seite x von y“.

PDF-Metadaten: Titel, Creator „Pitlog“, **kein Autor**.

### Reihenfolge: neueste zuerst

Die Einträge stehen **absteigend nach Datum** (neuester Eintrag = Nr. 1). Gründe: Ein Käufer will zuerst die letzte Arbeit sehen (letzte Wartung, letzter Reifenwechsel), auch wenn er nur die erste Seite liest. Es ist dieselbe Reihenfolge wie in der Historie der App. Am selben Tag gilt der höhere Kilometerstand zuerst, dann die Eingabereihenfolge. Die Nummer in der Tabelle ist die Position in dieser Liste; Anhänge verweisen darauf.

### Formate

Datum, Zahlen und Beträge nur über `FormatStyle` in der App-Sprache (en/de, mit Region, z. B. `de_AT`). Alle Texte stehen im String Catalog (`ServiceRecordTexts`). Das PDF ist ein Druckdokument: feste Schriftgrößen und feste Farben (kein Dark Mode, keine Dynamic Type).

## 3. Optionen

| Option | Standard | Wirkung |
|---|---|---|
| Zeitraum | Alle Einträge | „Ab einem Datum“: Einträge ab diesem Tag (inklusive). Der Kilometerstand im Kopf kommt immer aus der ganzen Historie. |
| Beträge einschließen | **aus** | Betragsspalte und Kostensummen. Aus: kein Betrag im PDF. |
| FIN einschließen | an | Zeile „FIN“. Aus: Die Zeile fehlt ganz. |
| Belege als Anhang | **aus** | Die Belege folgen auf eigenen Seiten. Hinweis im Sheet: Belege können Name und Anschrift enthalten, **Pitlog schwärzt nichts**. |

Die Spalte „Beleg“ zeigt „Ja“ (Beleg vorhanden) bzw. „Angehängt“. Es zählen nur Belege, deren Datei auf dem Gerät liegt (CloudKit lädt `externalStorage` nachträglich).

## 4. Dateiname

`Servicenachweis W-12345-A 2027-03-01.pdf` bzw. `Service record W-12345-A 2027-03-01.pdf`. Leerzeichen im Kennzeichen werden zu Bindestrichen, ungültige Zeichen (`/ \ : * ? " < > | %`, Steuerzeichen) zu Bindestrichen, mehrfache Trenner werden zusammengefasst, führende Punkte entfallen, die Länge ist auf 100 Zeichen begrenzt (`ServiceRecordFileName`). Ohne Kennzeichen dient der Fahrzeugname, sonst entfällt der Teil.

## 5. Umsetzung

| Baustein | Ort | Aufgabe |
|---|---|---|
| `ServiceRecord`, `ServiceRecordOptions`, `ServiceRecordFileName` | `Packages/PitlogCore/.../ServiceRecord/` | Reines Modell: Zeitraum filtern, sortieren, nummerieren, Summen je Jahr und Währung, Feldauswahl (FIN, Beträge), Dateiname. Linux-testbar. |
| `ServiceRecordTexts` | `App/Sources/Services/ServiceRecord/` | Alle Texte und Formate für eine `Locale` |
| `ServiceRecordPDFRenderer` | dito | Layout mit `UIGraphicsPDFRenderer` und `NSAttributedString` (A4 595 × 842 pt) |
| `ServiceRecordFactory`, `ServiceRecordExporter`, `ServiceRecordTempFiles` | dito | `Vehicle` → reine Werte, Rendern im Hintergrund, temporäre Datei |
| `ServiceRecordExportView`, `ServiceRecordPreviewView` | `App/Sources/Features/History/ServiceRecord/` | Optionen-Sheet, Vorschau, Teilen |

**Seitenumbruch:** Das Layout läuft zweimal. Der erste Durchgang zählt die Seiten, der zweite zeichnet die Fußzeilen mit „Seite x von y“. Zeilen werden nie getrennt; der Tabellenkopf wiederholt sich auf jeder Folgeseite; Überschriften bleiben mit Tabellenkopf und erster Zeile zusammen. Eine einzelne Zeile, die höher als eine Seite ist (z. B. ein Eintrag mit mehreren hundert Arbeitszeilen), wird am Seitenende abgeschnitten.

**Belege im Anhang:** Fotos werden eingepasst auf eine Seite gezeichnet. PDF-Belege werden Seite für Seite als JPEG-Bild der Seite eingebettet (dreifache Auflösung der Zielgröße, Qualität 0,8), damit Drehung und Zuschnitt stimmen. Der Text solcher Belege ist im Servicenachweis daher nicht mehr durchsuchbar. Ein Beleg, der nicht gelesen werden kann oder dessen Datei noch nicht auf dem Gerät ist, bekommt eine Platzhalterseite.

## 6. Datenschutz

- Keine Netzwerkaufrufe, keine Drittanbieter, kein Eintrag im Privacy Manifest nötig (keine Required-Reason-API).
- Das PDF liegt nur im temporären Ordner der App (`…/tmp/ServiceRecords/<UUID>/`, Dateischutz bis zur ersten Entsperrung) und wird beim Schließen des Sheets und beim App-Start gelöscht. Was der Nutzer teilt, liegt danach beim Empfänger.
- **Belege können personenbezogene Daten Dritter oder des Nutzers enthalten (Name, Anschrift).** Pitlog schwärzt nichts; deshalb ist der Anhang standardmäßig aus und das Sheet warnt.
- Beträge sind standardmäßig aus, die FIN standardmäßig an, weil ein Käufer sie mit dem Fahrzeug abgleicht. Wer das nicht will, schaltet sie aus.
- Der Zweck (Haftung): Der Fuß sagt auf jeder Seite, dass die Angaben vom Halter stammen und nicht geprüft sind. Das PDF enthält keine berechnete Pickerl-Frist.

## 7. Grenzen

- **Kein getaggtes PDF.** `UIGraphicsPDFRenderer` erzeugt keine Strukturinformation (keine Überschriften, Tabellen oder Sprachangabe). VoiceOver liest den Text der Seiten über PDFKit, aber ohne Tabellenstruktur. Ein barrierefreies (PDF/UA) Dokument bräuchte einen eigenen PDF-Schreiber; das ist für V1 nicht vorgesehen. Die Optionen und die Vorschau sind in der App voll bedienbar (Dynamic Type, VoiceOver).
- Nur lateinische Schrift in der Systemschrift; kein Schriftwechsel für andere Schriftsysteme.
- Kein Schwärzen von Belegen.
- Eine Zeile, die höher als eine Seite ist, wird abgeschnitten (siehe oben).
- Ein Fahrzeug ohne Einträge ergibt ein PDF mit den Fahrzeugdaten und dem Hinweis „Keine Einträge im gewählten Zeitraum“.
- Die Preise in den UI-Tests stammen aus dem Debug-Stub (`StubStoreBackend`), nicht aus `Pitlog.storekit`. Die StoreKit-Konfiguration hat schon `_locale: de_AT` und Storefront AUT, dort erscheint der Preis wie bei Apple. Der Stub zeigte „€4.99“ im deutschen Text und formatiert jetzt in der Sprache der App.

## 8. Tests

- `PitlogCore tests` (Linux): `ServiceRecordTests` (parametrisiert): leere Historie, fehlende Felder, mehrere Währungen, Zeitraumgrenzen (inklusive Start), Sortierung und Nummerierung, FIN aus, Beträge aus, Kilometerstand aus Ablesungen und Einträgen, Dateinamen.
- `Build and unit tests`: `ServiceRecordTests` in `AppTests`: PDF aus Beispieldaten mit PDFKit prüfen (Seitenzahl, Text, Kennzeichen, FIN an/aus, Beträge an/aus, en und de), lange Historie (mehrere Seiten, „Seite x von y“, Tabellenkopf auf jeder Seite, jeder Eintrag genau einmal), Anhänge fügen Seiten hinzu (Foto, mehrseitiges PDF, Platzhalter), Metadaten, Modell → Werte, Export in eine Datei, Aufräumen.
- UI-Audit (manuell, Job `ui-tests`): Optionen-Sheet und Vorschau in en, de und mit größter Schrift; gesperrter Einstieg im Gratis-Tarif in en und de; Tippen ohne Pro öffnet die Paywall. Ergebnisse: `docs/accessibility-audit.md`.
