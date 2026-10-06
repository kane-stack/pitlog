# UI-Audit: offene Befunde nach M3

Stand: Branch `claude/m3-reminders`, Commit `1c608de`, Lauf <https://github.com/kane-stack/pitlog/actions/runs/37281000549> (UI-Job rot, Unit-Tests grün).
Der Audit ist `performAccessibilityAudit()` auf dem iOS-26-Simulator (Job `ui-tests`, nur manuell). Es wurde **nichts gefiltert oder abgeschaltet** außer den zwei bekannten Fällen aus CLAUDE.md (Navigationsleisten-Buttons: Dynamic Type, deaktiviertes „Sichern“: Kontrast). Diese Datei ist die Eingabe für den Barrierefreiheits-Durchgang in M6 mit dem Accessibility Inspector auf einem echten Gerät.

## Grün (neue M3-Bildschirme)

Upcoming-Tab mit Erinnerungen (EN, ans Listenende gescrollt), Einstellungen → Mitteilungen (EN, DE). Der Upcoming-Test prüft den Zustand am Listenende, weil die schwebende Tab-Leiste sonst Zeilen überdeckt (Kontrast-Befund an der Leiste, nicht an einer Textfarbe).

## Offene Befunde

Alle sieben Tests melden „Dynamic Type font sizes are partially unsupported“ (`XCUIAccessibilityAuditType.dynamicType`) auf **genau einem** reinen SwiftUI-Textelement (Typ 48 = StaticText). Das Element wechselt von Lauf zu Lauf (siehe Spalte „Lauf-Verlauf“).

| # | Bildschirm | Element im letzten Lauf | Weitere Elemente in früheren Läufen | Bewertung | Vorschlag |
|---|---|---|---|---|---|
| 1 | Fahrzeugdetail (EN) | „Reminders“ (Zusammenfassungszeile, y≈707) | „Winter tyres · in 27 days“, „Inspection reminders“ | vermutlich Systemartefakt (siehe unten) | in M6 mit Accessibility Inspector und Dynamic-Type-Stufen prüfen |
| 2 | Fahrzeugdetail (DE) | „Winterreifen · in 27 Tagen“ (y≈748) | „Erinnerungen“, „Pickerl-Erinnerungen“ | wie 1 | wie 1 |
| 3 | Erinnerungsliste (EN) | „Allow notifications“ (y≈718) | „Add reminder“, „Reminders“, „When the window opens …“ | wie 1; zusätzlich Button-Befund, siehe Experiment 5 | Zeile als eigene Hinweiszeile statt Button-Zeile, mit Inspector prüfen |
| 4 | Erinnerungsliste (DE) | „Mitteilungen erlauben“ | „Erinnerung hinzufügen“ | wie 3 | wie 3 |
| 5 | Editor Service (EN) | „14 days“ (Wert einer Menü-Auswahlzeile, y≈574) | „Repeat by distance“, „Repeat by time“, Fußnotenzeilen | wie 1 | wie 1 |
| 6 | Editor Eigene (EN) | „Repeat“ (Auswahlzeile, y≈493) | „Never“, Fußnote | wie 1 | wie 1 |
| 7 | Editor Vignette (DE) | „Erinnerung vorher“ (Auswahlzeile, y≈506) | „25 Tage“, „Du bekommst am …“ (Text clipped) | wie 1 | wie 1 |

Nicht gezählt, weil gefiltert nach CLAUDE.md: „Cancel“/„Save“ der Navigationsleiste (die Roh-Ausgabe `AUDIT[...]` im Log zeigt sie trotzdem, der Test bricht dort nicht).

## Warum Systemartefakt?

Isolations-Experimente (temporär, wieder entfernt; Läufe 37276481563 und 37279466832) mit minimalen Bildschirmen ohne eigene Logik:

- Nur Textzeilen, Toggles, die Menü-Auswahlzeile (`MenuPickerRow`), `DatePicker`, gemischtes Formular, Formular im Sheet, Liste aus `NavigationLink`-Zeilen mit zusammengefasstem Label: **alle grün**.
- Liste mit zwei einfachen `Button`-Zeilen (`Label`): **rot**, „Text clipped“ auf dem Text des Buttons. Mit `HStack` statt `Label`: rot, „Label duplicates traits“. Das sind Systemsteuerelemente ohne Sonderlogik.

Gegen reinen Systemartefakt spricht, dass die Auswahlzeilen in den Editoren rot sind, obwohl dieselben Bausteine im Experiment grün waren; Unterschiede zu den Experimenten sind Sheet-Präsentation über einer Liste, mehrere Abschnitte und der Zustand nach `onAppear`. Wahrscheinlicher ist ein zeitabhängiger Messfehler beim Wechsel der Inhaltsgröße (Element wird mit alter Größe gemessen). Eine Pause von 1,5 s vor dem Audit (Übergänge abschließen) änderte nichts. Belegt ist das nicht; deshalb „vermutlich“.

Lauf-Verlauf (Anzahl rote UI-Tests): erster Lauf 11, danach 9, 9, 8, 7. Änderungen dazwischen: Texte mit `fixedSize` statt Abschneiden, Erläuterungen als Zeilen statt Abschnittsfüße (diese verwenden eine sekundäre Farbe: Kontrast), Menüs statt Stepper, Erinnerungen auf eigener Seite, Zeilen mit Tippgeste statt `Button`, State im `init`.

## Echte Probleme, die dabei behoben wurden

- Abschnittsköpfe und -füße im Formular verwenden eine sekundäre Farbe und fallen im Kontrast durch. Erläuterungen sind jetzt Zeilen mit `.footnote` und Primärfarbe (wie schon im Fahrzeugformular).
- `Stepper`-Beschriftungen und `Button`-Zeilen mit `Label` in Listen lieferten Befunde. Ersetzt durch Menü-Auswahlzeilen und Tippzeilen mit Button-Merkmal und `accessibilityAction`.
- Das Fahrzeugdetail ist eine `List` mit einer Zusammenfassungszeile; die Erinnerungen liegen auf eigener Seite (kurze Liste, keine Konkurrenz mit der Pickerl-Karte).
- Der deutsche Text der Navigationsleiste „Neue Erinnerung“ wurde abgeschnitten; der Titel heißt jetzt „Erinnerung“.

## Offen für M6 (Accessibility Inspector, echtes Gerät)

1. Fahrzeugdetail, Erinnerungsliste und Editoren bei Dynamic Type bis AX5 durchgehen (Text umbricht, nichts wird abgeschnitten, Zeilen wachsen).
2. VoiceOver: Erinnerungszeilen (kombiniertes Label, Hinweis, Aktionen „Erledigt“, „Bearbeiten“, „Löschen“ über Wischen), Hinzufügen-Zeile, Berechtigungszeile.
3. Prüfen, ob Zeilen mit Tippgeste und `.isButton` für Switch Control und Sprachsteuerung ausreichen oder ob echte `Button`s mit eigener Formatierung nötig sind.
4. Die vier Befunde nach Einzelprüfung entweder beheben oder als dokumentierte Systemartefakte aus den Audit-Tests herausnehmen (dafür Freigabe der Koordination, siehe CLAUDE.md „Gefiltert werden genau zwei Dinge“).

## M4: Historie, Kosten, Eintragseditor

Stand: Branch `claude/m4-history`, Commit `a820f74`. Läufe (UI-Job, `screenshots: true`): 37295131418, 37297451248, 37299940021, jeweils rot, Unit-Tests grün. Es wurde **nichts zusätzlich gefiltert**; die zwei Filter aus CLAUDE.md gelten unverändert.

Neue Tests (je EN und DE): Kosten-Diagramm, Kosten-Tabelle, Zeitleiste (ans Ende gescrollt), Eintragseditor. Im letzten Lauf laufen alle bis zum Audit durch. Die ersten Läufe scheiterten an Test-Setup (Zeile „Eintrag hinzufügen“ lag in DE unter dem Falz, Timeouts auf der langsamen Runner-Maschine, ID an einem `ForEach`); das ist behoben.

### Befunde (letzter Lauf)

| Test | Befund | Element | Bewertung |
|---|---|---|---|
| Diagramm EN / DE | Dynamic Type „partially unsupported“ | EN „Repair“ (Legende), DE „€ 509,00“ | Systemartefakt, siehe unten |
| Tabelle EN / DE | wie oben | EN „CHF 180.00“, DE „Gesamt 2026“ | wie oben |
| Eintragseditor EN / DE | wie oben | „Add from Photos“ / „Aus Fotos hinzufügen“ (Tippzeile, wie „Add reminder“ in M3); DE zusätzlich „Sichern“ der Navigationsleiste (kein Filter-Treffer, schwankt) | wie oben |
| Zeitleiste EN | Dynamic Type „unsupported“, **ohne Element** | gescrollter Zustand | Artefakt des Scrollens, siehe unten |
| Zeitleiste DE | Kontrast, **ohne Element** | gescrollter Zustand | wie oben |

### Belege für Systemartefakt

- **Das Element wechselt von Lauf zu Lauf**, die Bildschirme sind gleich. Diagramm EN: „CHF 180.00“ (Lauf 1), „Total 2026“ (Lauf 2), „Repair“ (Lauf 3). Tabelle EN: „CHF 180.00“, „2026“, „CHF 180.00“. Tabelle DE: „Gesamt 2026“. Immer genau **ein** `StaticText` pro Bildschirm, immer mit reinen Text-Styles (`.headline`, `.subheadline`, `.footnote`), nie mit fester Größe. Dasselbe Muster wie die sieben Befunde aus M3 (Tabelle oben, Lauf-Verlauf).
- Die Screenshots der Läufe zeigen die Texte in den erwarteten Größen; die Zeilen wachsen bei großen Schriftgrößen (`AmountLayout` wechselt ab den Accessibility-Größen auf eine vertikale Anordnung, nichts nutzt `minimumScaleFactor`).
- **Zeitleiste ohne Element:** der Audit läuft im gescrollten Zustand. Dort liegen Inhalte unter der durchscheinenden Navigationsleiste (im Screenshot sichtbar: „Total 2026“ unscharf hinter der Leiste). Das ist dieselbe Ursache wie der Kontrast-Befund an der Tab-Leiste in M3 und der schon dokumentierte Fall „gescrollt, Zeile am Bildschirmrand“ im Test `testEditVehicleFormPassesAccessibilityAudit`. Ein Element nennt der Audit nicht.

### Offen für M6 (Accessibility Inspector, echtes Gerät)

1. Diagramm und Legende bei Dynamic Type bis AX5; Audio Graph (`accessibilityChartDescriptor`) mit VoiceOver anhören (eine Serie je Kategorie plus Gesamt).
2. Die Zeitleiste ohne Scrollen prüfen (z. B. mit Kategorie-Filter, der die Kosten nach oben nicht verändert) oder auf dem Gerät.
3. Zeilen der Historie mit Wischaktionen (Bearbeiten, Löschen mit Bestätigung) in VoiceOver; Vorschau (QuickLook) und Teilen eines Belegs.
4. Die Tippzeilen „Aus Dateien / Aus Fotos hinzufügen“ für Switch Control (siehe M3, Punkt 3).

## M5a: Review-Bildschirm des Zulassungsschein-Scans

Stand: Branch `claude/m5a-registration-scan`, Lauf <https://github.com/kane-stack/pitlog/actions/runs/37308204907>. Geprüft: Review (EN, DE, EN mit größter Schrift, Klasse „Sonstige“). Es wurde nichts zusätzlich gefiltert.

- **Behoben:** „Contrast nearly passed“ (alle Review-Tests im ersten Lauf, `no element`). Ursache war der Textausschnitt in `.secondary`. Er steht jetzt in `.primary`; der Befund ist weg.
- **Grün:** EN mit größter Schrift (nur die gefilterten Navigationsleisten-Buttons), Review-Unit-Flows (Standardauswahl, Übernehmen, Abwählen, Abbrechen).
- **Offen, vermutlich Systemartefakt:** „Dynamic Type font sizes are partially unsupported“ auf **genau einem** reinen SwiftUI-Text, der von Lauf zu Lauf wechselt (EN: „Type“, DE: „Pkw“, beide in der `MenuPickerRow`-Zeile der Fahrzeugart). Dasselbe Muster wie bei den Befunden 1 bis 4 oben. Mit dem Accessibility Inspector auf einem Gerät in M6 prüfen. Die Navigationsleisten-Buttons „Apply“/„Cancel“ meldet der Audit ebenfalls (UIKit), sie werden wie bisher gefiltert.

## M5b: Review-Bildschirm des Belegscans

UI-Audit-Läufe: https://github.com/kane-stack/pitlog/actions/runs/37317325504 (mit Screenshots, Branch
`ci-screenshots/run-37317325504`) und https://github.com/kane-stack/pitlog/actions/runs/37324715519.
Vergleichslauf auf dem M5a-Stand (`claude/practical-edison-jhlpos`, Commit `511cdb9`):
https://github.com/kane-stack/pitlog/actions/runs/37321386084.

**Der Gesamtlauf ist auch auf dem M5a-Stand rot.** Auf nahezu allen Bildschirmen meldet der Audit „Dynamic Type font
sizes are (partially) unsupported“ für Textzeilen (type=48) und Bar-Buttons, auch für Bildschirme, die vor M5b
unverändert sind (Erinnerungen, Fahrzeugdetail, Formular). Das ist nicht durch M5b entstanden; die Ursache liegt
vermutlich in der Runner-/Xcode-Umgebung, ist aber nicht belegt. Zu klären in M6 (Accessibility Inspector, Gerät).

Befunde, die M5b selbst betrafen, und was daraus wurde:

| Befund | Ursache | Umgang |
|---|---|---|
| Kontrast „EUR“-Label im Review | sekundäre Farbe neben dem Betragsfeld | behoben (`.primary`), im Folgelauf weg |
| „Text clipped“ Debug-Zeile „Receipt extraction comparison“ | Zeile umbrach nicht | behoben (`fixedSize`), im Folgelauf weg |
| Settings-Test griff die Debug-Zeile statt „Legal“ | Zeile stand vor „Legal“ | behoben: Developer-Abschnitt steht zuletzt |
| „Text clipped“ Titel „Check the receipt“ bei xxxl | zu langer Titel in der Navigationsleiste | Titel auf „Receipt“/„Beleg“ gekürzt, **nicht erneut gemessen** |
| Dynamic Type „Scan receipt“, „EUR“, „Eintrag hinzufügen“, Bar-Buttons | wie überall (siehe oben) | Befund der Umgebung, nichts gefiltert |
| `history-list-de`: „Contrast failed“ ohne Element | unklar; im M5a-Lauf dort „Dynamic Type, no element“ | **offen**, Screenshot im Branch `ci-screenshots/run-37317325504` ansehen |

Gefiltert wird weiterhin nichts außer den beiden dokumentierten Bar-Button-Fällen.

## M6a: Pitlog Pro (Paywall, gesperrte Funktionen, nur lesbare Fahrzeuge)

Stand: Branch `claude/m6a-storekit`, Commit `27a1192`, Lauf <https://github.com/kane-stack/pitlog/actions/runs/37351011635> (`screenshots: true`; Unit-Tests grün, UI-Job rot). Es wurde **nichts gefiltert**, nur die zwei Fälle aus CLAUDE.md (Bar-Buttons). Neue Tests (je EN/DE, Paywall auch mit größter Schrift): Paywall, gesperrte Erinnerungen, nur lesbares Fahrzeug (Detail und Liste), Einstellungen mit Pro-Abschnitt (gratis und Pro), Kosten im Gratis-Tarif.

### Echte Befunde, behoben (Folgelauf siehe unten)

| Befund | Ursache | Behebung |
|---|---|---|
| Erklärung unter „Pickerl-Erinnerungen“ blieb in DE englisch (und „Text clipped“ im Test `reminders-locked-de`) | Der Quelltext des Strings stimmte nicht mit dem Schlüssel im String Catalog überein (seit M3) | Quelltext an den Katalogschlüssel angepasst |
| `readOnlyUnlockRow` war für die UI-Tests nicht auffindbar (3 Tests) | `accessibilityIdentifier("readOnlyBanner")` am Container überschrieb die Kennungen der Kinder | Kennung am Container entfernt |
| Pro-Kennzeichen in Erinnerungszeilen zog sich über die Zeilenbreite | Label ohne `fixedSize` in der Zeile mit `Spacer` | `fixedSize()` am Kennzeichen |
| `testWithoutProTheReceiptScanOpensThePaywall` scheiterte im Aufbau | Test wartete auf den Kosten-Umschalter, den der Gratis-Tarif nicht zeigt | Test navigiert selbst und wartet auf die gesperrte Kostenzeile |

### Offene Befunde

- **Dynamic Type „(partially) unsupported“ auf je einem Textelement** bzw. an Bar-Buttons („Cancel“/„Save“/„Close“ der Navigationsleiste von Paywall, Formularen und Reviews) in nahezu allen Tests, auch in den Bildschirmen aus M2 bis M5, die in M6a nicht angefasst wurden (Fahrzeugdetail, Formulare, Historie, Reviews). Neu hinzugekommen sind nur „Get Pitlog Pro“/„Pitlog Pro holen“ (Tippzeile in den Einstellungen) und der Bar-Button „Close“/„Schließen“ der Paywall. Das ist dasselbe Muster wie in M3 bis M5 (siehe oben): ein wechselndes `StaticText`, in den Screenshots in der erwarteten Größe. Die Bar-Buttons „Close“/„Schließen“ der Paywall fallen **nicht** unter den Filter, weil dieser an die Label der Navigationsleisten-Buttons gebunden ist, der Befund tritt hier aber mit `type=9` auf: Er wird also gemeldet, nicht gefiltert. Zu klären in M6 mit Accessibility Inspector auf einem Gerät.
- **`paywall-de`: „Text clipped“** am Satz „14 Tage gratis, danach €4.99 pro Jahr. Jederzeit kündbar.“ (Rahmen 267 × 38 pt). Der Screenshot zeigt den Text vollständig, zweizeilig, in der Karte. Vermutlich derselbe Messfehler wie bei den früheren „Text clipped“-Befunden, nicht belegt. Zu prüfen auf dem Gerät.
- `history-list-de` „Contrast failed“ und `history-list-en` „Dynamic Type“ ohne Element (gescrollter Zustand): wie in M4/M5 dokumentiert.
- `testReceiptReviewPassesAccessibilityAudit` (vorhandener Test) scheiterte im Aufbau (`recordInspectionButton` nach 5 s nicht da, Zeitüberschreitung auf dem Runner); die anderen Review-Tests liefen durch. Vermutlich Flake des Runners.

### Bildschirme ohne eigenen Befund im Lauf

Paywall EN und mit größter Schrift (nur der Bar-Button „Close“, siehe oben), Einstellungen mit Pro-Abschnitt in Pro (der Test brach in der Schleife beim Gratis-Zustand ab, der Pro-Zustand wurde dadurch nicht geprüft: Test in zwei aufgeteilt), Fahrzeugliste mit gesperrten Fahrzeugen (grün).

### Offen für M6 (Gerät, Accessibility Inspector)

1. Paywall mit VoiceOver: Reihenfolge (Kontext-Hinweis, Funktionsliste, Karten, Kaufen-Buttons, Wiederherstellen, Links), hervorgehobene Funktion („Die Funktion, die du gerade wolltest“), Dynamic Type bis AX5 inkl. Kaufen-Button.
2. Gesperrte Zeilen („Pro“-Kennzeichen, Hinweis, Aktion „Öffnet Pitlog Pro“) und das Banner „Nur lesbar“ mit VoiceOver, Switch Control und Sprachsteuerung.
3. Die Tippzeilen mit `ActionRow` (wie „Add reminder“ in M3, Punkt 3).

### Zweiter Lauf (Commit `1b9b136`, Lauf <https://github.com/kane-stack/pitlog/actions/runs/37356065732>)

Behoben und im Lauf bestätigt: die Kennung am Lesemodus-Banner (Tests „nur lesbares Fahrzeug“ laufen bis zum Audit), der Gratis-Belegscan-Test, der deutsche Erinnerungstext (`reminders-locked-de` ohne „Text clipped“). Neu: Die drei Tests mit gesperrten Erinnerungen scheiterten im Aufbau, weil die Zeile „Erinnerung hinzufügen“ durch die zusätzliche Hinweiszeile je gesperrter Erinnerung unter den Falz rutscht und der Test sie am Listenanfang erwartete. Die Tests warten jetzt auf den Pickerl-Schalter und scrollen zur Zeile. Befunde sonst unverändert: je ein wechselndes `StaticText`/Bar-Button mit „Dynamic Type“ auf fast allen Bildschirmen (auch den unveränderten); „Text clipped“ wandert zwischen Elementen der Paywall DE („14 Tage gratis …“ im ersten, „Mit Familienfreigabe“ im zweiten Lauf, im Screenshot jeweils vollständig) und `settings-pro-pro-en` ohne Element: Messartefakte, nicht belegt, für die Geräteprüfung in M6 vorgemerkt.

### Dritter Lauf (Commit `0289464`, Lauf <https://github.com/kane-stack/pitlog/actions/runs/37359498681>)

Keine funktionalen Testfehler mehr (alle `XCTAssert`-Aufbauten laufen durch, auch die Tests mit gesperrten Erinnerungen, nur lesbarem Fahrzeug und dem Belegscan-Tipp auf die Paywall). Rot bleibt der Audit selbst, mit denselben Befunden wie in M3 bis M5: je ein wechselndes `StaticText` oder ein Bar-Button mit „Dynamic Type (partially) unsupported“, ohne Element in `history-list-*` und `registration-review-de`. „Text clipped“ erscheint weiter wechselnd an anderen Elementen (`paywall-de`: „Frühere Jahre und das Diagramm über alle Jahre.“, `reminders-locked-de`: „Pickerl-Erinnerungen“, `settings-pro-pro-en` ohne Element); in den Screenshots sind die Texte vollständig. Das Element wechselt von Lauf zu Lauf, was für einen Messartefakt spricht (nicht belegt). Prüfung mit dem Accessibility Inspector auf dem Gerät bleibt in M6.

## M6b: PDF-Servicenachweis (Optionen-Sheet, Vorschau, gesperrter Einstieg)

Stand: Branch `claude/m6b-service-record`. Läufe (UI-Job, `screenshots: true`): 37362070137 (Commit `0655cbd`), 37378648685 (`6a6f61c`), 37383228969 (`5de446a`, Merge von `claude/practical-edison-jhlpos`), 37386280665 (`cf0b837`), jeweils rot, Unit-Tests grün. Zwei weitere Läufe (37365716944, 37372129475) wurden nach 15 Minuten abgebrochen, ohne dass der UI-Job einen Runner bekam; das ist kein Workflow-Timeout (dort stehen 60 Minuten). **Nichts wurde gefiltert**, es gelten nur die zwei Filter aus CLAUDE.md.

Neue Tests: Optionen-Sheet (EN, DE, größte Schrift EN und DE), Vorschau (EN, DE, größte Schrift EN), gesperrte Historienzeile im Gratis-Tarif (EN, DE), Tippen ohne Pro öffnet die Paywall (grün).

### Echte Befunde, behoben

| Befund | Ursache | Behebung |
|---|---|---|
| Zwei Tests (Pro) fanden die Zeile „Servicenachweis exportieren“ nicht | Die Zeile liegt unter dem Diagramm; eine `List` legt sie erst beim Scrollen an | Test wartet nicht mehr auf die Zeile, sondern scrollt; im größten deutschen Schriftgrad wartet er auf die Zurück-Taste |
| `service-record-options-xxxl-de`: „Text clipped“ am Navigationstitel „Servicenachweis“ | Der Inline-Titel passt bei AX3 nicht zwischen „Abbrechen“ und „Erstellen“ | Großer Titel (`.large`), der umbricht. Im Lauf 37386280665 bestätigt: der Befund ist weg |

### Befunde, nicht von M6b verursacht oder nicht behebbar

- **Dynamic Type „(partially) unsupported“ auf je einem Textelement** (Typ 48) in den Optionen (EN und DE), in der gesperrten Historie (EN und DE) und an den Navigationsleisten-Buttons „Cancel“/„Create“ (gefiltert, siehe CLAUDE.md). Das Element wechselt von Lauf zu Lauf (Toggle-Beschriftung, Fußnote, Jahresüberschrift). Dasselbe Muster zeigt der Lauf auf allen älteren Bildschirmen (siehe M5b und M6a oben), auch auf Bildschirmen, die M6b nicht berührt. Offen für den Durchgang mit dem Accessibility Inspector in M6.
- **Vorschau DE: „Hit area is too small“** an `UICGPDFNodeAccessibilityElement` mit dem Label „Nr.“ (Tabellenkopf, Rahmen 12,5 × 7,5 pt auf dem Bildschirm). PDFKit macht jedes Textstück einer Seite zu einem Zugänglichkeitselement; kleine Schrift (8 pt im Druckdokument) ergibt kleine Trefferflächen. In EN meldete der Audit das nicht (anderes Element, anderer Lauf). Das ist eine Eigenschaft von PDFKit und der Schriftgröße im PDF, nicht der App-Oberfläche. Nicht behoben; Optionen: größere Schrift im PDF (wäre dann mehr Seiten) oder eigene VoiceOver-Beschreibung der Vorschau. Beides ist eine Entscheidung für M6.
- `history-list-*` „Contrast failed“ und die Dynamic-Type-Befunde der älteren Bildschirme: wie in M4 bis M6a dokumentiert.

### Offen für M6 (Gerät)

1. Vorschau mit VoiceOver: liest PDFKit den Seitentext sinnvoll (ohne Tabellenstruktur, das PDF ist nicht getaggt)? Ist „Teilen“ erreichbar?
2. Optionen-Sheet mit VoiceOver und Dynamic Type bis AX5 auf dem Gerät; Menü „Zeitraum“ und Datumsauswahl.
3. Geteiltes PDF in Mail, Dateien und Vorschau öffnen (Dateiname, Seitenzahlen, Umlaute).

## M6c: weiche Trennung, Vorschau, Datenschutz-Zeile

Stand: Branch `claude/m6c-a11y-privacy`. Vergleichsläufe des UI-Jobs (`screenshots: true` nur auf dem Branch):

| Lauf | Stand | Ergebnis |
|---|---|---|
| 37388399223 | **vorher**: Basis `claude/practical-edison-jhlpos` (`3d46b85`) | 35 rote UI-Tests |
| 37388396867 | M6c `a7cbdeb` (weiche Trennung, Vorschau-Zusammenfassung, Datenschutz-Zeile) | 35 rote UI-Tests |
| 37393145074 | M6c `c58531e` (Rechtshinweis mit Label ohne Trennzeichen, Titel als Überschrift) | rot, 35 UI-Tests |
| 37397257305 | M6c `56ed436` (Rechtshinweis ohne Trennzeichen, Datenschutz-Zeile als `Link` in Primärfarbe) | rot, 35 UI-Tests |
| 37400853421 | M6c `b101837` (Datenschutz-Zeile als `ActionRow`, Trennung im Rechtshinweis wieder drin; ohne Screenshots) | rot, 35 UI-Tests (Build und Unit-Tests grün) |

Build und Unit-Tests waren in allen Läufen grün (Push-Läufe 37388386871, 37393140152). Unverändert gelten nur die zwei Filter aus CLAUDE.md (Bar-Buttons).

### Hypothese: kommen die Dynamic-Type-Befunde von `minimumScaleFactor`?

**Nein.** `wrapsLongWords()` (mit `minimumScaleFactor(0.6)`) war nur an vier Stellen im Einsatz (`FirstLaunchNoticeView`, `LegalView`, `InfoRow`). Nach dem Entfernen (jetzt `wrapsText()`, nur `fixedSize`) bleibt das Muster aus M3 bis M6b unverändert:

- Je Test meldet der Audit „Dynamic Type font sizes are (partially) unsupported“ an **genau einem** Element, das von Lauf zu Lauf wechselt (Beispiele: `reminders-*` „Add reminder“ / „Allow notifications“ / „Er·in·ne·rung hinzufügen“; `registration-review-de` „Kennzeichen“, „Pkw“, „Art“; `history-chart-en` „CHF 180.00“, „Repair“). Das sind Elemente, die `wrapsLongWords` nie benutzt haben.
- Dieselben Befunde stehen im Vorher-Lauf auf der Basis (z. B. „Erinnerungen“, „VIN (optional)“, „Mitteilungen erlauben“). Die Zahl der roten Tests ist vorher und nachher gleich (35).
- Die Bar-Buttons (Typ 9) melden weiter, soweit sie nicht unter den Filter fallen („Close“/„Schließen“ der Paywall, „Add entry“, „Apply“, „Cancel“, „Create“).

Damit ist belegt, dass `minimumScaleFactor` nicht die Ursache ist. Die Ursache der wechselnden Befunde bleibt ungeklärt (Messartefakt des Audits oder der Runner-Umgebung, nicht belegt). Prüfung mit dem Accessibility Inspector auf dem Gerät: `docs/device-test.md`, Abschnitt 1.

### Was sich geändert hat

| Befund | vorher | nachher |
|---|---|---|
| `service-record-preview-de`: „Hit area is too small“ (PDFKit-Element „Nr.“) | rot | **weg**: Die Vorschau ist ein einziges VoiceOver-Element mit Zusammenfassung (Seitenzahl, Hinweis auf Teilen). Begründung: Die kleinen Flächen sind PDFKit-Elemente für jedes Textstück eines nicht getaggten PDFs. Größere Schrift im PDF hätte das Dokument verändert (mehr Seiten) und die Elemente blieben winzig. Wer VoiceOver nutzt, liest das Dokument über Teilen in einer App, die PDFs lesen kann (Vorschau, Bücher). |
| `service-record-options-xxxl-de`: „Text clipped“ ohne Element | rot | **weg**: Der große Navigationstitel „Servicenachweis“ wurde bei AX3 als „Servicenac…“ abgeschnitten (Screenshot). Weiche Trennstriche greifen in Navigationstiteln nicht. Der Titel ist jetzt eine umbrechende Überschrift im Formular. |
| `history-list-*` „Contrast failed“ ohne Element | wechselnd | **offen**, weiter nicht einem Element zuordenbar (gescrollter Zustand, Tab-Leiste); im ersten M6c-Lauf stand dort stattdessen ein Dynamic-Type-Befund mit Element, im letzten wieder „Contrast failed“. Spricht für einen Zustandsartefakt. |
| Dynamic-Type-Befunde (siehe Hypothese) | 35 rote Tests | 35 rote Tests |

### Sichtkontrolle der weichen Trennung

Screenshot `service-record-options-xxxl-de` (AX3, Deutsch): Lange Wörter brechen an den Trennstellen („Histo-/rie“, „Fahr-/zeugs“, „ver-/lässt“), der Trennstrich steht nur am Zeilenende; nichts ist verkleinert. Die Wörterbuchliste enthält die langen Komposita (`scripts/hyphenate_de.py`, ca. 100 Wörter ab 10 Buchstaben); einzelne weitere Wörter trennt das System selbst.

### Neue Befunde durch M6c

- **`notice-de` „Text clipped“** am Rechtshinweis (Test `testFirstLaunchNoticePassesAccessibilityAuditInGerman`, der im Vorher-Lauf grün war). Der Screenshot zeigt den Text vollständig. Es ist **nicht** die weiche Trennung von „Maßgeblich“: Der Befund blieb in Lauf 37397257305 bestehen, obwohl dort keine Trennung im Rechtshinweis stand und das gesprochene Label ohne Trennzeichen gebaut war. Die einzige weitere Änderung an dieser Ansicht ist das Entfernen von `minimumScaleFactor`. Das passt zur Vermutung, dass der Audit den Text bei der Messung anders umbricht als SwiftUI ihn zeichnet, ist aber **nicht belegt**. Der Text steht in voller Höhe im Bildschirm. Zu prüfen auf dem Gerät.
- **Datenschutz-Zeile in den Einstellungen** (neu): Als `Link` in der Liste erzeugte sie „Contrast failed“ (`settings-pro-free-*`, ohne Element) und „Text clipped“ am Text „Privacy Policy“ (`settings-pro-pro-en`), auch in Primärfarbe. Das passt zu den früheren Experimenten (Systemsteuerelemente in Listen, siehe oben). Die Zeile ist jetzt die Tippzeile der App (`ActionRow`, öffnet dieselbe URL über `openURL`). Ergebnis siehe Abschluss unten.
- Die anderen Befunde im Lauf 37397257305 sind das bekannte wechselnde Muster (z. B. „Amount“, „Betrag“, „Art“, „Repeat“, „Allow notifications“); „Text clipped“ wandert weiter zwischen Elementen der Paywall (`paywall-de`), der gesperrten Erinnerungen (`reminders-locked-de`) und der Einstellungen.

### Offen (nur auf dem Gerät)

Siehe `docs/device-test.md`: Inspector-Audit, VoiceOver (liest keine Trennstriche vor? Die Labels der Pickerl-Karte, der Erinnerungen und der Historie sind ohne Trennzeichen gebaut; reine `Text("…")` verlassen sich auf die Systemvorlesung), AX5 in beiden Sprachen.

### Abschluss (Lauf 37400853421, `b101837`)

- **Datenschutz-Zeile:** Mit der Tippzeile (`ActionRow`) sind die Befunde „Contrast failed“ und „Text clipped“ am Element „Privacy Policy“ weg. In den drei Einstellungs-Tests (`settings-pro-free-de/-en`, `settings-pro-pro-en`) steht jetzt „Text clipped“ **ohne Element**. Diese Bildschirme waren auch vorher rot (Basis: „Dynamic Type“ an „Pitlog Pro holen“, „Text clipped“ an „About“); ob die neue Zeile etwas beiträgt, ist daher nicht trennbar und nicht belegt.
- **`notice-de` „Text clipped“:** besteht weiter, auch mit der Trennung im Rechtshinweis wieder drin und ohne sie (Lauf 37397257305). Sie ist also nicht die Ursache; der Screenshot zeigt den Text vollständig. Vermutlich Folge des entfernten `minimumScaleFactor` (Messung des Audits), nicht belegt. Auf dem Gerät prüfen.
- **Weitere schwankende Befunde:** `notification-settings-en` „Contrast failed“ an einer Fußnote (in M3 grün, in diesem Lauf rot), `history-list-*` je nach Lauf „Contrast failed“ oder „Dynamic Type“ ohne Element. Das passt zum bekannten Muster, dass der Audit je Lauf wechselnde Elemente meldet.
- **Fazit M6c:** 35 rote UI-Tests wie vorher. Behoben: PDF-Vorschau (Hit area), Servicenachweis-Titel (abgeschnitten). Neu rot: `testFirstLaunchNoticePassesAccessibilityAuditInGerman`. Die wechselnden Dynamic-Type-Befunde bleiben ungeklärt, `minimumScaleFactor` war nicht die Ursache. Weitere Audit-Läufe bringen in der Cloud keine neue Erkenntnis; der nächste Schritt ist der Inspector-Durchgang auf dem Gerät (`docs/device-test.md`).
