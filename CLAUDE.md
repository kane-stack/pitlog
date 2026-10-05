# Pitlog (Arbeitsname)

Fahrzeug-Wartungsheft fürs iPhone: Fristen, Erinnerungen und Wartungshistorie für die eigenen
Autos an einem Ort. Startmarkt ist Österreich: Die Pickerl-Reform (§ 57a KFG, 42. KFG-Novelle)
gilt ab **19.05.2027**. Die App ist international gedacht; Österreich ist das erste Länder-Modul,
später folgen DE (HU) und UK (MOT).

- **Ziel:** App-Store-reif bis **Ende März 2027**, rechtzeitig vor dem Stichtag.
- **Apple-Featuring:** Die App soll dafür nominiert werden. Barrierefreiheit, Lokalisierung
  und Datenschutz sind deshalb Pflicht und keine Kür.

## Kommunikation und Sprache

- **Mit Christopher:** Deutsch.
- **Code, Kommentare, Commit-Nachrichten, Bezeichner:** Englisch.
- **Doku unter `docs/`:** Deutsch, weil sie sich auf österreichisches Recht bezieht.
  Fachbegriffe im Code: `inspection` = Begutachtung/Pickerl, `plaque` = Plakette,
  `firstRegistration` = Erstzulassung, `window` = Begutachtungsfenster.

## Umfang Version 1

1. Fahrzeuge verwalten (mehrere): Kennzeichen, Erstzulassung, Fahrzeugart, Kilometerstand, Foto optional
2. Pickerl-Frist (AT-Modul) mit Regel-Engine, Erinnerungen mit Vorlauf
3. Erinnerungen: Reifenwechsel, Service (Datum und/oder km), Vignette, eigene
4. Belegscan (VisionKit, Vision-OCR, Extraktion mit Bestätigung), Beleg verknüpft mit Historieneintrag
5. **Zulassungsschein-Scan:** füllt Fahrzeugdaten vor. Genutzt werden die EU-harmonisierten Feldcodes
   A (Kennzeichen), B (Erstzulassung), E (FIN), J (Fahrzeugklasse), D.1/D.3 (Marke, Typ) und
   F.2 (Gesamtgewicht). Gleiche Pipeline wie der Belegscan, der Nutzer bestätigt. Die Lochung der Plakette und
   der Kilometerstand bleiben manuell. Für die Lochung gibt es ein Auswahlfeld, das wie die Plakette aussieht.
6. Historie pro Fahrzeug, Kosten pro Jahr

**Nicht in V1:** Tank-Tracking, Länder-Module außer AT, Widgets (vorgemerkt), Teilen von Fahrzeugen,
Online-Abfragen von FIN oder Kennzeichen. Externe FIN-Datenbanken würden Daten an Dritte senden (ADR-12).

## Architekturentscheidungen

| # | Entscheidung | Begründung |
|---|---|---|
| ADR-1 | **SwiftData** mit CloudKit, nur privater Container, kein Teilen | Christopher will kein Teilen. SwiftData kann kein CKShare. Kommt Teilen doch, ist ein Wechsel auf Core Data nötig. |
| ADR-2 | **Minimum iOS 26**, nur iPhone | Foundation Models API vorhanden; Fallback für Geräte ohne Apple Intelligence |
| ADR-3 | Fachlogik in **`Packages/PitlogCore`**, nur Foundation, Linux-kompatibel | Tests laufen ohne Xcode (CI auf Linux); erzwingt reine Funktionen |
| ADR-4 | Xcode-Projekt per **XcodeGen** (`project.yml`). `.xcodeproj` wird nicht eingecheckt. | Wird in der Cloud ohne Xcode erstellt, keine Merge-Konflikte in pbxproj |
| ADR-5 | **Plakette ist führend.** Die App speichert den gelochten Monat und das Jahr. Die Berechnung aus der Erstzulassung ist nur ein Vorschlag. | Übergangsrecht (§ 132 Abs. 37): Die alte Lochung gilt weiter, die Austauschplakette ist optional. Haftung. |
| ADR-6 | Länder-Modul = Protokoll `InspectionRuleSet` plus Registry nach Land | DE und UK ohne Umbau |
| ADR-7 | Rechnen in **Kalendermonaten** (`YearMonth`, `DayDate`), nicht mit `Date` | Keine Zeitzonen- oder Monatsende-Fehler; `today` wird injiziert |
| ADR-8 | Offene Rechtsfragen = **konservative Auslegung** (früherer spätester Termin) plus Hinweis in der UI | Haftung |
| ADR-9 | Benachrichtigungen: reine Planung in Core, App plant die nächsten N neu (Limit 64). Jedes Gerät plant selbst. | Kein Backend; CloudKit synchronisiert nur Daten |
| ADR-10 | Belegextraktion über das Protokoll `ReceiptExtractor`: Foundation Models (falls verfügbar), sonst Heuristik in Core | On-device, Datenschutz, testbar |
| ADR-13 | Zulassungsschein-Extraktion als reine Heuristik in Core (`RegistrationDocumentParser`), die anhand der Feldcodes A/B/E/J/D/F.2 arbeitet. OCR über dieselbe Scan-Pipeline wie bei Belegen. | Feldcodes machen die Heuristik zuverlässig; Linux-testbar; DE nutzt dieselben Codes |
| ADR-11 | Monetarisierung: **„Pitlog Pro“ als Jahresabo 4,99 € (14 Tage gratis, Einführungsangebot) oder Lifetime-Kauf 14,99 €** (StoreKit 2, Family Sharing, **keine Werbung**). Abo begründet durch laufende Regel-Updates (Gesetzesänderungen, später DE/UK). Gratis: 1 Fahrzeug, Pickerl-Frist mit ihren Erinnerungen, Zulassungsschein-Scan, Historie, Belege als Foto, Kosten des laufenden Jahres. Pro: mehr Fahrzeuge, Erinnerungen für Reifen, Service, Vignette und eigene, Belegscan, mehrjähriger Kostenverlauf, PDF-Servicenachweis. Endet das Abo: nichts löschen, alles lesbar. Gating über das Protokoll `Entitlements`; Status nur lokal aus StoreKit, nie in CloudKit. Über dem Limit nie löschen, nur Lesezugriff. Pickerl-Erinnerungen laufen immer (für alle Fahrzeuge); Pro-Erinnerungen werden ohne Pro nicht geplant, bleiben aber gespeichert und laufen mit Pro wieder. Eigene Pro-Hinweise statt Werbe-SDK. Recherche: `docs/research/monetization.md` | Werbe-SDK bräche ADR-12 und das Label „Keine Daten erfasst“, bei kaum Umsatz. Sync-sicher, keine Haftungslücke bei Fristen |
| ADR-12 | Keine Drittanbieter-Abhängigkeiten in der App | Ziel: Datenschutz-Label „Keine Daten erfasst“ |

## Struktur

```
CLAUDE.md
project.yml                     XcodeGen spec (generate with scripts/bootstrap.sh)
docs/rules/AT-57a-KFG.md        legal rules with IDs (AT-xx), sources, status
docs/research/                  prompts for local research sessions (cloud cannot reach RIS)
Packages/PitlogCore/            pure domain logic, Foundation only, Linux-compatible
App/Sources/                    SwiftUI app (Model, Features, Services)
App/Resources/                  String Catalogs, assets, privacy manifest
AppTests/, AppUITests/          app-level tests (Xcode only)
.github/workflows/              CI: PitlogCore tests on Linux
```

## Konventionen

- **Swift 6** Language Mode, strikte Concurrency.
- **Tests:** Swift Testing (`import Testing`), keine XCTest-Unit-Tests. Die UI-Tests bleiben bei
  XCTest/XCUITest und nutzen `performAccessibilityAudit()`.
- **Regeltests:** Jeder Testfall der Fristen-Engine nennt die Regel-ID aus
  `docs/rules/AT-57a-KFG.md` (z. B. `// AT-41`). Tests sind tabellengetrieben (parametrisiert).
  Ändert sich eine Regel, wird zuerst das Doc aktualisiert, dann der Test, dann der Code.
- **PitlogCore:** keine Imports außer Foundation, keine Apple-only-APIs (kein SwiftData,
  SwiftUI, Vision). Alles `Sendable`, Werttypen bevorzugt.
- **SwiftData mit CloudKit:**
  - Alle Attribute optional oder mit Default.
  - Keine `.unique`-Attribute.
  - Beziehungen optional und mit Inverse.
  - Große Daten mit `.externalStorage`.
  - Schemaänderungen nur über `VersionedSchema` und `SchemaMigrationPlan`.
- **Geld:** als `Int` in Minor Units plus ISO-Währungscode. Kein `Double` für Beträge.
- **Lokalisierung:**
  - String Catalogs (`Localizable.xcstrings`, `InfoPlist.xcstrings`), Basissprache `en`,
    `de` immer vollständig. `de-AT` nur für abweichende Begriffe.
  - Schlüssel = englischer Quelltext. Jeder neue String bekommt einen `comment:` für Übersetzer.
  - Datums- und Zahlenformate nur über `FormatStyle`, nie selbst zusammensetzen.
  - Deutsche Ansprache mit „du“, wie Apple in seinen eigenen Apps.
- **Barrierefreiheit:**
  - Status nie nur über Farbe.
  - Jede Fristangabe bekommt ein ausformuliertes VoiceOver-Label.
  - Dynamic Type bis zu den Accessibility-Größen.
  - Diagramme mit `accessibilityChartDescriptor`.
- **Rechtlicher Hinweis:** Wo die App eine Pickerl-Frist zeigt, steht sichtbar „ohne Gewähr,
  maßgeblich ist die Plakette“.
- **Datenschutz:** Keine Netzwerkaufrufe außer CloudKit. Neue Required-Reason-APIs in
  `App/Resources/PrivacyInfo.xcprivacy` eintragen.
- **Kennungen (final, nicht mehr ändern):** Team `ZXBCH8F6UU`, Bundle-ID `com.kane.pitlog`, CloudKit-Container
  `iCloud.com.kane.pitlog`, Produkt-IDs `com.kane.pitlog.pro.yearly` (Jahresabo) und `com.kane.pitlog.pro.lifetime`.

## Bauen und Testen

- **Core-Tests:** `swift test --package-path Packages/PitlogCore` (lokal mit Xcode 26 oder
  Swift 6.2). In der Cloud-Umgebung ist kein Swift-Toolchain verfügbar (download.swift.org
  ist gesperrt). Dort laufen die Tests nur über GitHub Actions (`.github/workflows/core-tests.yml`).
- **App-Build in der Cloud:** `.github/workflows/app-build.yml` (macOS-Runner `macos-26`) erzeugt
  das Projekt mit XcodeGen und führt `xcodebuild test -only-testing:PitlogTests` auf einem
  automatisch gewählten iPhone-Simulator aus (`CODE_SIGNING_ALLOWED=NO`). Er startet bei Pushes auf
  `claude/**`, wenn `App/**`, `AppTests/**`, `AppUITests/**`, `project.yml` oder `Packages/**`
  geändert wurden, und ist die einzige Möglichkeit, die App ohne Xcode zu kompilieren.
  Die UI-Tests mit Accessibility-Audit laufen nur manuell (`workflow_dispatch`, Job `ui-tests`).
  Der UI-Audit-Lauf ist grün. Der Artefakt-Download (`productionresultssa11.blob.core.windows.net`) ist in der
  Cloud gesperrt; mit `screenshots: true` committet der Job stattdessen verkleinerte PNGs und den
  Audit-Bericht nach `ci-screenshots/run-<id>/` auf den Branch (nach der Sichtung wieder löschen). Zusätzlich
  gibt er `AUDIT[...]`-Zeilen im Log aus. Gefiltert werden genau zwei Dinge, beide nur für Buttons der
  System-Navigationsleiste (Label wie in `app.navigationBars.buttons`): Dynamic-Type-Befunde (UIKit-Bar-Buttons
  skalieren nicht) und der Kontrast eines deaktivierten „Sichern“ (WCAG 1.4.3). Das Formular wird leer
  (Sichern deaktiviert) und als Bearbeiten-Formular (gültig) geprüft, nicht mit Tastaturfokus.
  Die App startet in Tests und mit `-UITestSampleData` mit einem In-Memory-Store ohne CloudKit.
- **App:** `scripts/bootstrap.sh` (braucht `xcodegen`, `brew install xcodegen`), dann
  `Pitlog.xcodeproj` öffnen.

## Arbeitsweise

- **Coding-Sessions:** Jeder Meilenstein bzw. jedes Coding-Paket läuft als **eigene Cloud-Session
  mit Sonnet**. Die koordinierende Session plant, prüft und merged.
- **Branches:** Pro Paket ein eigener Branch `claude/<meilenstein>-<thema>`, Basis ist
  `claude/practical-edison-jhlpos`.
- **Ergebnis:** Die Coding-Session pusht nur auf ihren Branch, wartet auf grüne CI
  (`PitlogCore tests`) und erstellt **keinen** Pull Request ohne ausdrücklichen Auftrag.
- **CI-Status abfragen:** über die GitHub-MCP-Tools (`actions_list`/`get_job_logs`) oder
  `curl https://api.github.com/repos/kane-stack/pitlog/actions/runs?branch=<branch>`.

## Recherche

Die Cloud-Umgebung erreicht ris.bka.gv.at, parlament.gv.at, oeamtc.at, arboe.at und wko.at
**nicht**. Recherche zu Primärquellen läuft in einer lokalen Session,
Prompt: `docs/research/local-session-prompt.md`.

## Meilensteine

| # | Zeitraum | Inhalt | Status |
|---|---|---|---|
| M0 | Okt 2026 | Gerüst, CLAUDE.md, Regeldoku, XcodeGen, PitlogCore, CI | erledigt |
| M1 | Okt–Nov | Fristen-Engine und Tests (final erst nach Primärquellen-Abgleich) | Engine an Primärquellen angepasst |
| M2 | Nov | Datenmodell (inkl. FIN-Feld), Fahrzeugverwaltung, Plaketten-Auswahl, Pickerl-Karte, Hinweis, Lokalisierung | erledigt (UI-Audit grün auf `claude/m2-vehicles`) |
| M3 | Dez | Erinnerungen und Benachrichtigungen (siehe `docs/reminders.md`) | implementiert; UI-Audit-Reste dokumentiert in `docs/accessibility-audit.md` (M6) |
| M4 | Jan 2027 | Historie, manuelle Einträge, Kosten pro Jahr | implementiert: Core `Money`/`CostSummary`, Historie mit Diagramm und Tabelle, Eintragseditor mit Belegen (ohne OCR), Angebote nach Pickerl und Service, einmalige „Pickerl überfällig“-Mitteilung. UI-Audit-Reste in `docs/accessibility-audit.md` (M6) |
| M5 | Jan–Feb | Scan-Pipeline: Zulassungsschein-Scan, Spike Belegextraktion, dann Belegscan | M5a + M5b implementiert: Zulassungsschein-Scan (`docs/registration-scan.md`), Belegscan mit Heuristik, Foundation Models und RKSV-QR, Review mit Bestätigung je Feld, Debug-Vergleichsansicht nur in Debug-Builds (`docs/receipt-parser.md`). Offen: Gerätetest (eigener Zulassungsschein, Belege von 2 Werkstätten, Foundation Models) |
| M6 | Feb | **M6a umgesetzt** (`claude/m6a-storekit`, `docs/monetization.md`): StoreKit-2-Gating nach ADR-11 (Abo + Lifetime, eigene Paywall, Kulanzfrist, Gates, nur lesbare Fahrzeuge). Offen: M6b PDF-Servicenachweis, Datenschutz-URL (Platzhalter), App Store Connect (Anleitung in `docs/monetization.md`), Durchgang Barrierefreiheit, TestFlight. Offen aus M2.1: `wrapsLongWords()` nutzt `minimumScaleFactor(0.6)` und verkleinert damit lange deutsche Texte inkl. Rechtshinweis bei großen Schriftgrößen. Ersetzen durch weiche Trennung (Soft Hyphens in den Strings) | |
| M7 | März | Beta, rechtlicher Re-Check, Featuring-Nominierung, Einreichung | |

## Offene Fragen

1. **Primärquellen:** Weitgehend gelöst. Die Pickerl-Regeln sind gegen BGBl. I Nr. 79/2026, § 57a,
   § 132 Abs. 37 und § 135 Abs. 51 geprüft (`docs/rules/AT-57a-KFG.md`, Quellen unter
   `docs/sources/`), die Engine ist angepasst (Regelversion `AT-2026-10-primary`). Offen bleiben
   nur AT-45 (spätester Tag nach neuer Fassung), AT-54a (Bedeutung „im zehnten Jahr“) und AT-57
   (PBStV-Folgeregelungen).
2. **Übergangsfenster 2027 (AT-56):** Gelöst (§ 132 Abs. 37 Z 3), in der Engine umgesetzt.
3. **Lochung der Austauschplakette für Fahrzeuge über 10 Jahre (AT-53/54):** Weitgehend gelöst:
   ab dem zehnten Jahr jährlich, keine Austauschplakette. Rest: AT-54a.
4. **Reichweite des −4/0-Fensters (AT-43):** Gelöst: gilt für alle Fahrzeuge (N1, Taxi,
   historische), in der Engine umgesetzt.
5. **Belegscan (M5b):** Recherche in `docs/sources/receipts/README.md`. Es gibt keine öffentlichen AT-Werkstattbelege.
   Die Tests nutzen synthetische Belege, Christopher liefert Belege von 2 Werkstätten als Gegentest. Entschieden:
   E-1 Kosten = **Rechnungsbetrag brutto** (nicht Restbetrag nach Anzahlung); E-2 Historiendatum = **Leistungsdatum**,
   ersatzweise Rechnungsdatum.
6. **Foundation Models:** Qualität bei deutschsprachigen Werkstattrechnungen erst im Spike
   (M5) bewerten, mit 15 bis 20 echten, anonymisierten Belegen.
7. **Bundle-ID, Team und CloudKit-Container:** Gelöst, siehe Konventionen, Kennungen. Vor dem App-Store-Start das CloudKit-Schema in der CloudKit Console nach Production deployen.
8. **App-Name:** „Pitlog“ ist ein Arbeitsname. Markenrecherche vor der Einreichung.
