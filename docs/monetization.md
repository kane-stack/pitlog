# Wagemo Pro: Umsetzung (M6a)

Entscheidung und Begründung: ADR-11 in `CLAUDE.md`, Recherche in `docs/research/monetization.md` (Abschnitt 9).
Dieses Dokument beschreibt, wie es umgesetzt ist, wie man es testet und was Christopher in App Store Connect einrichten muss.

## 1. Umsetzung

| Baustein | Ort | Aufgabe |
|---|---|---|
| `AccessPolicy`, `Tier`, `ProFeature`, `VehicleKey` | `Packages/PitlogCore/.../Access/AccessPolicy.swift` | Reine Regeln: Fahrzeuglimit, welche Fahrzeuge bearbeitbar sind, welche Erinnerungsarten geplant werden, welche Kostenjahre sichtbar sind |
| `ProEntitlementEvaluator`, `ProStatus`, `PurchaseRecord`, `ProProduct` | `.../Access/ProEntitlement.swift` | Berechnet aus den StoreKit-Berechtigungen den Pro-Status (Lifetime, Abo, Kulanzfrist, Widerruf, Family Sharing); `resolve` sperrt nie wegen Verifikationsproblemen |
| `Entitlements` | `App/Sources/Services/Entitlements.swift` | Protokoll für die Views: `isPro`, `vehicleLimit`, `canScanReceipts`, `canUseProReminders`, `canViewMultiYearCosts`, `canExportServiceRecord`. Fakes: `UnlimitedEntitlements`, `NoReceiptScanEntitlements`, `FreeEntitlements`, `TierEntitlements` |
| `StoreService` | `App/Sources/Services/Store/StoreService.swift` | `@MainActor @Observable`: Produkte, Kauf, Wiederherstellen, `Transaction.updates`, Status-Cache |
| `StoreBackend` | `.../Store/StoreBackend.swift`, `StoreKitBackend.swift`, `StubStoreBackend.swift` (nur Debug) | Dünne Schicht über StoreKit; austauschbar durch Fakes |
| Paywall, Pro-Kennzeichen, Hinweise | `App/Sources/Features/Store/` | `PaywallView`, `ProBadge`, `ActionRow`, `ReadOnlyBanner`, `ProSettingsSection` |

**Status nie in CloudKit.** Der Pro-Status liegt nur im Speicher und als JSON in den `UserDefaults` des Geräts (Schlüssel `proStatusCache`). Er steht in keinem SwiftData-Modell. Jedes Gerät fragt StoreKit selbst (Family Sharing und dieselbe Apple-ID liefern dort dieselben Berechtigungen).

**Nie wegen Netzfehlern sperren.** Beim Start gilt sofort der zwischengespeicherte Status. `Transaction.currentEntitlements` arbeitet mit lokal signierten Transaktionen. Liefert StoreKit eine Berechtigung, die nicht verifiziert werden kann, und keine verifizierte, bleibt der gespeicherte Pro-Status erhalten. Nur eine verifizierte Antwort ohne Berechtigung setzt auf Gratis zurück.

**Kulanzfrist.** Ein Abo, das bis zu 16 Tage vor „jetzt“ endete, aber noch in `currentEntitlements` steht (Zahlungsproblem, App Store versucht erneut), bleibt Pro. Die Einstellungen weisen darauf hin.

### Gates

| Funktion | Gratis | Pro |
|---|---|---|
| Fahrzeuge | 1 bearbeitbar (das früheste nach Erstellungsdatum, ID als Tiebreaker) | unbegrenzt |
| Pickerl-Frist und -Erinnerungen | immer, für alle Fahrzeuge | immer |
| Reifen-, Service-, Vignette-, eigene Erinnerungen | nicht geplant, gespeichert, in der Liste mit Schloss und „Pro“ | geplant |
| Zulassungsschein-Scan, Historie, manuelle Einträge, Belege als Foto/Datei | ja | ja |
| Belegscan | Zeile mit „Pro“, Tippen öffnet die Paywall | ja |
| Kosten | laufendes Jahr | alle Jahre, Diagramm und Tabelle über Jahre |
| PDF-Servicenachweis | Zeile mit „Pro“, Tippen öffnet die Paywall | ja (`docs/service-record.md`) |

Ohne Pro versteckt die Übersicht „Anstehend“ die nicht geplanten Pro-Erinnerungen; in der Erinnerungsliste des Fahrzeugs bleiben sie sichtbar.

### Verhalten über dem Limit

Läuft das Abo aus oder kommen per iCloud weitere Fahrzeuge von einem anderen Gerät, **wird nichts gelöscht**.

- Alle aktiven Fahrzeuge bleiben sichtbar. Nur das erste nach stabilem Schlüssel (Erstellungsdatum, dann ID) ist bearbeitbar. Der Schlüssel ist auf allen Geräten gleich; ein später synchronisiertes Fahrzeug nimmt dem ersten den Platz nicht weg.
- Die anderen sind nur lesbar: Die Liste zeigt „Nur lesbar“ mit Schloss, die Detailseite, Historie und Erinnerungen zeigen einen Hinweis. Ändernde Aktionen (Bearbeiten, Kilometerstand, Pickerl erfassen, Eintrag anlegen/bearbeiten/löschen, Erinnerungen ändern) öffnen die Paywall statt einer Änderung.
- Archivierte Fahrzeuge zählen nicht zum Limit. „Wiederherstellen“ zählt als Hinzufügen und öffnet über dem Limit die Paywall.
- Pickerl-Erinnerungen laufen für alle Fahrzeuge weiter, auch die schreibgeschützten.
- Pro-Erinnerungen werden bei Ablauf nicht mehr geplant (Filter in `ReminderCoordinator.replan`), bleiben gespeichert und werden mit Pro wieder geplant. Ein Wechsel des Status (`StoreService.tier`) löst eine Neuplanung aus.

### Paywall

Eigene SwiftUI-Ansicht statt `SubscriptionStoreView`: Die Preise und Laufzeiten kommen aus `Product` (`displayPrice`), der Gratiszeitraum wird nur gezeigt, wenn `isEligibleForIntroOffer` wahr ist. Sie zeigt die Pro-Funktionen als Liste, hebt die Funktion hervor, die der Nutzer wollte (Rahmen und Text, nicht nur Farbe), nennt, was gratis bleibt, und enthält die Angaben nach Richtlinie 3.1.2: Preis, Laufzeit, automatische Verlängerung, Kündigung, „Käufe wiederherstellen“, Links zu Nutzungsbedingungen (Apples Standard-EULA) und Datenschutzerklärung. Familienfreigabe wird erwähnt. Hinweise auf Pro erscheinen nur an gesperrten Stellen, nie beim Start.

**Offener Punkt:** Die Datenschutzerklärung-URL ist ein Platzhalter (`AppLinks.privacyPolicy`, `https://example.com/pitlog/privacy`). Vor der Einreichung durch die echte URL ersetzen (auch in App Store Connect eintragen).

### Datenschutz

Keine neuen Netzwerkaufrufe außer StoreKit (Apples eigener Dienst, keine Drittanbieter). `PrivacyInfo.xcprivacy` enthält den UserDefaults-Grund `CA92.1` bereits (Status-Cache und Einstellungen). StoreKit braucht keinen weiteren Eintrag.

## 2. Testen

### Automatisch
- `PitlogCore tests` (Linux): `AccessPolicyTests`, `ProEntitlementTests`, parametrisiert.
- `Build and unit tests`: `StoreServiceTests` (Fake-Transaktionsquelle: Ablauf, Widerruf, Family Sharing, Kulanzfrist, Offline-Cache, Kauf, Ausstehend, Wiederherstellen, Updates) und `AccessTests` (Lesezugriff, Planung ohne Pro-Arten).
- UI-Tests (nur manuell, Job `ui-tests`): Debug-Builds ersetzen StoreKit durch `StubStoreBackend`. `-UITestFree` und `-UITestPro` legen den Tarif fest. Mit `-UITestSampleData` allein (und in Unit-Tests) gilt Pro, damit die übrigen Tests unverändert laufen. `-UITestNoReceiptScan` gibt feste Berechtigungen ohne Belegscan.

### Im Simulator mit StoreKit-Konfiguration
1. `scripts/bootstrap.sh`, `Pitlog.xcodeproj` öffnen. Das Schema „Pitlog“ nutzt `App/StoreKit/Pitlog.storekit` (Storefront AUT, EUR; die Datei liegt außerhalb der Quellordner und kommt nicht ins App-Bundle).
2. Mit dem Schema ausführen: Die Paywall (Einstellungen → „Wagemo Pro holen“) zeigt die Produkte aus der Datei, den Gratiszeitraum und kauft ohne App Store Connect.
3. Debug → StoreKit → Transaction Manager: Käufe ansehen, **Refund** (Widerruf), **Expire Subscription**, „Enable Billing Retry“ bzw. Grace Period, „Ask to Buy“, Zeit beschleunigen (Abo läuft in Minuten ab). Die App sollte nach `Transaction.updates` bzw. beim Aktivieren neu bewerten.
4. Einstellungen → Entwickler (nur Debug) → „Pro status override“ schaltet die Gates ohne Kauf (nur im Speicher, wird beim Neustart zurückgesetzt).
5. Gegenprobe: Abo ablaufen lassen, prüfen: Fahrzeuge bleiben sichtbar, nur das erste ist bearbeitbar, Pro-Erinnerungen tragen Schloss und werden nicht mehr geplant, Pickerl-Erinnerungen laufen weiter.

## 3. App Store Connect: Schritt für Schritt (Christopher)

1. **Vereinbarungen:** App Store Connect → Business (Vereinbarungen, Steuer, Bank): Vertrag „Paid Apps“ akzeptieren, Bankverbindung und Steuerformulare ausfüllen. Ohne ihn lassen sich keine Käufe testen oder veröffentlichen.
2. **Small Business Program:** Auf developer.apple.com/app-store/small-business-program anmelden (15 % statt 30 % Provision, solange der Umsatz unter 1 Mio. US-$ im Jahr bleibt). Die Anmeldung muss vor den ersten Umsätzen bestätigt sein.
3. **App anlegen:** Apps → „+“ → Neue App: Plattform iOS, Name „Wagemo“ (Arbeitsname, vorher Markenrecherche, siehe Offene Fragen Nr. 8), Hauptsprache Deutsch (Österreich) oder Englisch, Bundle-ID `com.kane.pitlog` (muss unter Zertifikate, Identifier bereits existieren), SKU frei, z. B. `pitlog-ios`.
4. **Abo-Gruppe:** App → Monetarisierung → Abonnements → Gruppe anlegen, Referenzname „Wagemo Pro“. Anzeigename der Gruppe (en: „Wagemo Pro“, de: „Wagemo Pro“).
5. **Jahresabo:** In der Gruppe ein Abo anlegen: Referenzname „Wagemo Pro Yearly“, **Produkt-ID `com.kane.pitlog.pro.yearly`** (nicht änderbar), Dauer 1 Jahr, **Preis 4,99 €** (Österreich als Basis, die übrigen Länder übernehmen die Preisstufen).
6. **Einführungsangebot:** Im Abo → Abonnementpreise → Einführungsangebot: Typ „Gratis“, Dauer 2 Wochen, Länder alle, Neukunden. Die App zeigt den Gratiszeitraum nur, wenn der Nutzer dafür berechtigt ist.
7. **Familienfreigabe:** Im Abo „Familienfreigabe aktivieren“ einschalten (nach dem Aktivieren nicht mehr abschaltbar).
8. **Lifetime-Kauf:** Monetarisierung → In-App-Käufe → „+“: Typ **Nicht verbrauchbar**, Referenzname „Wagemo Pro Lifetime“, **Produkt-ID `com.kane.pitlog.pro.lifetime`**, **Preis 14,99 €**, Familienfreigabe aktivieren.
9. **Lokalisierung der Produktnamen (en und de):** Pro Produkt und für die Abo-Gruppe Anzeigename und Beschreibung eintragen.
   - Jahresabo: en „Wagemo Pro“ / „Yearly subscription: more vehicles, reminders, receipt scan and costs over the years.“; de „Wagemo Pro“ / „Jahresabo: mehr Fahrzeuge, Erinnerungen, Belegscan und Kosten über die Jahre.“
   - Lifetime: en „Wagemo Pro Lifetime“ / „One purchase, no subscription.“; de „Wagemo Pro Lifetime“ / „Einmal kaufen, kein Abo.“
10. **Review-Screenshot und Hinweise:** Bei beiden Produkten einen Screenshot der Paywall (Einstellungen → Wagemo Pro holen) hochladen und im Review-Hinweis erklären, wo man sie findet. Die Produkte müssen mit der ersten App-Version zur Prüfung eingereicht werden.
11. **Datenschutzerklärung und App-Informationen:** Eine öffentliche Datenschutzerklärung veröffentlichen (Hinweis: keine Daten erfasst, CloudKit privat, StoreKit durch Apple), die URL in App Store Connect (App-Informationen → Datenschutzerklärung-URL) eintragen und in `AppLinks.privacyPolicy` ersetzen. Nutzungsbedingungen: Apples Standard-EULA reicht (Link ist in der Paywall); die Abo-Angaben stehen bereits in der App-Beschreibung zu ergänzen („Wagemo Pro: Jahresabo 4,99 €, verlängert sich automatisch …“, Link zu Datenschutz und Nutzungsbedingungen).
12. **App-Datenschutz:** „Daten werden nicht erfasst“ (ADR-12).
13. **Test mit Sandbox/TestFlight:** Unter Benutzer und Zugriff einen Sandbox-Tester anlegen; auf dem Gerät Kauf, Wiederherstellen und Ablauf prüfen (Sandbox verkürzt die Abo-Laufzeit). Vor dem Release das CloudKit-Schema nach Production deployen (Offene Frage Nr. 7).
