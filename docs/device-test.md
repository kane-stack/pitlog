# Gerätetest (Checkliste für Christopher)

Was nur auf einem echten iPhone mit iOS 26 geklärt werden kann. Kurz, abhakbar. Hintergrund und bisherige Befunde:
`docs/accessibility-audit.md`. Der Simulator-Audit (`performAccessibilityAudit`) ist grün bis auf die dort dokumentierten
Reste; er ersetzt den Durchgang hier nicht.

Vorbereitung: Debug- oder TestFlight-Build, iCloud angemeldet, Mitteilungen erlaubt. Zweites Gerät für den Sync.

## 1. Accessibility Inspector (Xcode → Open Developer Tool, iPhone per Kabel)

- [ ] Audit auf jedem Hauptbildschirm laufen lassen: Fahrzeugliste, Fahrzeugdetail, Pickerl-Karte, Erinnerungen, Verlauf/Kosten, Einstellungen, Paywall.
- [ ] Die wechselnden Befunde „Dynamic Type partially unsupported“ einzeln prüfen: Gibt es sie auch auf dem Gerät? (Ergebnis in `docs/accessibility-audit.md`, Abschnitt M6c, nachtragen.)
- [ ] `history-list` „Contrast failed“: Verlauf ohne Scrollen und gescrollt prüfen, Element benennen.

## 2. Dynamic Type bis AX5 (Einstellungen → Bedienungshilfen → Anzeige & Textgröße → Größerer Text)

Sprache Deutsch und Englisch. Text umbricht an Trennstellen, nichts wird abgeschnitten oder verkleinert.

- [ ] Fahrzeugdetail mit Pickerl-Karte und Rechtshinweis „Ohne Gewähr. Maßgeblich ist …“ (kein Wort mitten abgeschnitten, Trennstrich nur am Zeilenende)
- [ ] Fahrzeugformular, Plaketten-Auswahl (ab AX-Größen zwei Standard-Picker)
- [ ] Erinnerungsliste und Editoren (Service, Vignette, Eigene)
- [ ] Verlauf, Diagramm und Legende, Kostentabelle, Eintragseditor
- [ ] Paywall inkl. Kaufen-Button und Abo-Hinweis
- [ ] Servicenachweis: Optionen-Sheet (Titel umbricht)
- [ ] Erstes Starten: Hinweis „Bevor du loslegst“

## 3. VoiceOver (je Bildschirm einmal durchwischen)

- [ ] Trennstriche werden **nicht** vorgelesen („Begutachtungsfenster“ am Stück, kein „Strich“)
- [ ] Fahrzeugliste und -detail: Pickerl-Karte als ein Element (Fälligkeitsmonat, letzter Tag, Status, Rechtshinweis)
- [ ] Plaketten-Auswahl: einstellbar mit Hoch/Runter, Jahr-Buttons, Wert „nicht gesetzt“
- [ ] Erinnerungen: kombiniertes Label, Hinweis, Aktionen Erledigt/Bearbeiten/Löschen, Hinzufügen-Zeile, Berechtigungszeile (`docs/reminders.md`)
- [ ] Verlauf: Zeilen, Wischaktionen, Diagramm mit Audio Graph (`accessibilityChartDescriptor`), Beleg-Vorschau und Teilen
- [ ] Paywall: Reihenfolge Kontext, Funktionen, Karten, Kaufen, Wiederherstellen, Links
- [ ] Gesperrte Zeilen („Pro“) und Banner „Nur lesbar“
- [ ] Servicenachweis-Vorschau: Zusammenfassung wird gelesen, „Teilen“ ist erreichbar
- [ ] Switch Control und Sprachsteuerung: Tippzeilen („Erinnerung hinzufügen“, „Aus Fotos hinzufügen“, Pro-Zeilen) sind ansprechbar

## 4. Kamera und Scan (`docs/registration-scan.md`, `docs/receipt-parser.md`)

- [ ] Eigener Zulassungsschein: Felder A, B, E, J, D.1/D.3, F.2 erkannt, Review je Feld, Übernehmen; Lochung und Kilometerstand bleiben manuell
- [ ] Zulassungsschein Vorder- und Rückseite einzeln (Hinweis bei nur einer Seite)
- [ ] Belege von **zwei Werkstätten**: Datum (Leistungsdatum), Betrag brutto, Werkstatt, Kategorie, Arbeiten, Kilometerstand
- [ ] Kassenbon mit RKSV-QR-Code
- [ ] Kamerazugriff abgelehnt: verständliche Meldung, Foto/Datei als Alternative
- [ ] Foundation-Models-Vergleich (Einstellungen → Entwickler, nur Debug): 15–20 anonymisierte Belege, Heuristik gegen Sprachmodell; Ergebnis in `docs/receipt-parser.md`
- [ ] Gerät ohne Apple Intelligence (oder Funktion aus): Heuristik allein funktioniert

## 5. StoreKit (`docs/monetization.md`)

Erst mit lokaler Datei `App/StoreKit/Pitlog.storekit` (Scheme „Pitlog“, Debug), dann in der Sandbox/TestFlight.

- [ ] Jahresabo kaufen (14 Tage gratis), Pro-Funktionen frei
- [ ] Einmalkauf (Lifetime)
- [ ] Abo-Ablauf (Xcode → Debug → StoreKit → Transaction Manager: beschleunigt ablaufen lassen): Kulanzfrist, danach nur lesbar, nichts gelöscht
- [ ] Familienfreigabe (zweites Apple-Konto in der Familie)
- [ ] Käufe wiederherstellen (neu installiert), „Nichts zum Wiederherstellen“-Meldung
- [ ] Abo verwalten (System-Sheet), Kauf abbrechen, „Ask to Buy“ (ausstehend)
- [ ] Flugmodus: App startet, Pro-Status aus dem lokalen Cache

## 6. Servicenachweis teilen (`docs/service-record.md`)

- [ ] Optionen (Zeitraum, Belege), Vorschau, Seitenzahl stimmt
- [ ] Teilen an Mail, Dateien, Nachrichten; Dateiname, Umlaute, Seitenzahlen
- [ ] PDF in Vorschau/Dateien öffnen, Text auswählbar, deutsch und englisch (keine Trennstriche im PDF-Text)

## 7. iCloud-Sync zwischen zwei Geräten

- [ ] Fahrzeug, Plakette, Erinnerung und Historieneintrag mit Beleg auf Gerät A anlegen, erscheinen auf Gerät B
- [ ] Änderung auf B, löschen auf A, Konflikt (beide offline ändern)
- [ ] Jedes Gerät plant seine Mitteilungen selbst (ADR-9): auf B nach dem Sync neu geplant
- [ ] Pro-Status wird **nicht** synchronisiert (nur lokal)
- [ ] Vor dem App-Store-Start: CloudKit-Schema nach Production deployen (CLAUDE.md, Offene Fragen 7)

## 8. Mitteilungen (`docs/reminders.md`)

- [ ] Berechtigung anfragen, erlauben, ablehnen, später in iOS-Einstellungen ändern (Hinweiszeile folgt)
- [ ] Pickerl-Erinnerung zur eingestellten Uhrzeit, Text auf Deutsch ohne Trennstriche, Tippen öffnet das Fahrzeug
- [ ] „Pickerl überfällig“ erscheint genau einmal
- [ ] Erinnerungen für Reifen, Service, Vignette, eigene; ohne Pro nicht geplant, mit Pro wieder
- [ ] App neu starten, Datum/Zeitzone ändern: Planung bleibt richtig; Limit 64 Mitteilungen

## 9. Datenschutz (`docs/privacy.md`)

- [ ] Einstellungen → „Datenschutzerklärung“ öffnet die Seite (solange Platzhalter: example.com)
- [ ] Netzwerk-Check (z. B. Proxy/Charles oder Einstellungen → Datenschutz → App-Aktivität aufzeichnen): außer iCloud/App Store keine Verbindungen
- [ ] Xcode → Product → Archive → Generate Privacy Report: leer bzw. nur UserDefaults `CA92.1`
