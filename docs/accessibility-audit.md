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
