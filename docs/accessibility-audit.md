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
