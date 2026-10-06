# Datenschutz: Label, Manifest, Erklärung (Entwurf)

Stand: M6c. **Alles hier ist ein Entwurf und keine Rechtsberatung.** Die Texte für Datenschutzerklärung und Impressum
müssen vor der Veröffentlichung von Christopher geprüft, ergänzt und ggf. rechtlich gegengelesen werden.

## 1. Privacy Manifest (`App/Resources/PrivacyInfo.xcprivacy`)

Geprüft per `grep` über `App/` und `Packages/` (Swift-Quellen, Stand M6c).

| Eintrag | Ergebnis | Beleg |
|---|---|---|
| `NSPrivacyTracking` | `false` | Kein Tracking, keine Werbe-ID, kein Drittanbieter-SDK (ADR-12). |
| `NSPrivacyTrackingDomains` | leer | Keine Netzwerkaufrufe außer CloudKit und StoreKit (beides System). |
| `NSPrivacyCollectedDataTypes` | leer | Keine Daten verlassen das Gerät Richtung Anbieter; siehe Abschnitt 2. |
| `NSPrivacyAccessedAPICategoryUserDefaults` | **eingetragen, Grund `CA92.1`** | `UserDefaults`/`@AppStorage` in `RootView`, `NotificationSettingsView`, `ReminderSettings`, `ReminderCoordinator` (Ledger „Pickerl überfällig“), `StoreService` (Cache des Pro-Status, nur lokal). Es sind ausschließlich Werte der App selbst. `CA92.1` = Lesen und Schreiben von Informationen, die nur die App selbst sieht. |
| Dateizeitstempel (`NSPrivacyAccessedAPICategoryFileTimestamp`) | nicht nötig | Kein Zugriff auf `creationDate`, `modificationDate`, `fileSize`, `stat`, `resourceValues` o. ä. Die App nutzt `FileManager` nur für Anlegen und Löschen im Temp-Ordner (PDF-Export, Belegvorschau). |
| Systemstartzeit (`SystemBootTime`) | nicht nötig | Kein `systemUptime`, `mach_absolute_time`, `mach_continuous_time`. |
| Freier Speicher (`DiskSpace`) | nicht nötig | Kein `volumeAvailableCapacity…`, `systemFreeSize`. |
| Aktive Tastaturen (`ActiveKeyboards`) | nicht nötig | Kein `UITextInputMode.activeInputModes`. |

Hinweise:

- Die Prüfung ist eine statische Suche. Apple wertet beim Hochladen auch die Bibliotheken aus; die App hat keine Drittanbieter-Abhängigkeiten, die Systemframeworks (SwiftData, CloudKit, StoreKit, Vision, VisionKit, FoundationModels, PDFKit) bringen ihre eigenen Manifeste mit.
- Kommt eine neue API hinzu (z. B. Dateigrößen für einen Belegimport), zuerst hier und im Manifest ergänzen. Das ist auch in `CLAUDE.md` (Konventionen, Datenschutz) so festgelegt.
- `PitlogCore` importiert nur Foundation und nutzt keine der genannten APIs.

## 2. App-Store-Datenschutzlabel: „Keine Daten erfasst“

Apple definiert „erfassen“ als: Daten werden **vom Gerät an den Entwickler oder einen Drittanbieter übertragen**, sodass sie über das Echtzeit-Verarbeiten hinaus gespeichert werden können. Daten, die nur auf dem Gerät bleiben oder nur im privaten iCloud-Konto des Nutzers liegen, zählen nicht.

| Kategorie | Antwort | Begründung |
|---|---|---|
| Kontaktinfo, Gesundheit, Finanzen, Standort, Sensible Daten, Kontakte | nicht erfasst | Die App fragt diese Daten nicht ab. Kein Standortzugriff, kein Kontaktezugriff. |
| Nutzerinhalte (Fotos, Belege, Fahrzeugdaten, Notizen) | nicht erfasst | Alles liegt lokal in SwiftData. Bei aktivem iCloud wird es über **CloudKit im privaten Container** des Nutzers synchronisiert (`iCloud.com.kane.pitlog`). Der Entwickler hat darauf keinen Zugriff und kein Backend. Das ist Apples Infrastruktur im Konto des Nutzers, keine Übertragung an den Entwickler. |
| Kennungen (Geräte-ID, Nutzer-ID) | nicht erfasst | Keine IDFA, keine eigene Nutzerkennung, keine Konten. |
| Kaufverlauf | nicht erfasst | StoreKit 2 prüft Käufe auf dem Gerät und bei Apple. Der Pro-Status wird nur lokal gecacht (UserDefaults) und nie nach CloudKit geschrieben. Der Entwickler erhält keine Kaufdaten, außer den aggregierten Berichten von App Store Connect (die Apple liefert, ohne Personenbezug). |
| Nutzungsdaten (Produktinteraktion, Werbung) | nicht erfasst | Keine Analytics, keine Absturzberichte eines Drittanbieters, keine Werbung. Die anonymisierten Absturz-/Nutzungsdaten, die Nutzer in iOS **freiwillig** mit Entwicklern teilen, liefert Apple; sie sind kein Erfassen durch die App. |
| Diagnose (Abstürze, Leistung) | nicht erfasst | Kein eigenes Diagnose-SDK. |
| Suchverlauf, Browserverlauf | nicht erfasst | Es gibt keine Suche im Netz. |
| OCR und Belegextraktion | nicht erfasst | **Vision** und **VisionKit** laufen auf dem Gerät. **Foundation Models** läuft auf dem Gerät (nicht Private Cloud Compute). Bilder und Texte werden nicht gesendet. |
| Tracking | nein | Kein Tracking, keine Datenweitergabe an Datenhändler (siehe `NSPrivacyTracking`). |

Voraussetzungen, damit die Antwort wahr bleibt (bei jeder Änderung prüfen):

1. Keine Drittanbieter-SDKs (ADR-12), keine eigenen Server.
2. Keine Netzwerkaufrufe außer CloudKit und StoreKit. Links (Datenschutz, Nutzungsbedingungen, `manageSubscriptionsSheet`) öffnen den Browser oder ein System-Sheet; die App selbst fragt nichts ab. Im Code gibt es kein `URLSession`.
3. Die Online-Abfrage von FIN oder Kennzeichen bleibt aus V1 draußen (ADR-12).
4. Der Debug-Vergleich der Belegextraktion (`ReceiptComparisonView`) existiert nur in Debug-Builds.

Antwort im App Store Connect: **„Daten werden nicht erfasst“**.

## 3. Entwurf der Datenschutzerklärung

> ENTWURF, keine Rechtsberatung. Platzhalter in `[ECKIGEN KLAMMERN]` ausfüllen. Vor der Veröffentlichung prüfen lassen.
> Der Text soll auf der Cloudflare-Seite unter `[DOMAIN]/privacy` (de) und `[DOMAIN]/privacy/en` (en) stehen. Diese
> Adresse in `AppLinks.privacyPolicy` und in App Store Connect eintragen.

### Deutsch

**Datenschutzerklärung für [APP-NAME]**
Stand: [DATUM]

**Verantwortlicher:** [NAME / FIRMA], [ANSCHRIFT], [E-MAIL]. (Angaben wie im Impressum.)

**Kurz gesagt:** [APP-NAME] sammelt keine personenbezogenen Daten. Es gibt kein Benutzerkonto, keine Werbung, keine Analyse- oder Tracking-Dienste und keine Server des Anbieters. Alles, was du einträgst, bleibt auf deinen Geräten und in deinem eigenen iCloud-Konto.

**1. Welche Daten die App verarbeitet.** Fahrzeugdaten (Kennzeichen, Erstzulassung, Fahrzeugart, FIN, Kilometerstände, Fotos), Fristen und Erinnerungen, Einträge der Wartungshistorie mit Kosten und Belegen (Fotos, PDF). Diese Daten gibst du selbst ein oder scannst sie.

**2. Wo die Daten liegen.** Auf deinem iPhone. Wenn du iCloud nutzt, synchronisiert Apple sie über CloudKit in einem privaten Bereich deines iCloud-Kontos zwischen deinen Geräten. [ANBIETER] hat darauf keinen Zugriff und kann sie nicht einsehen. Es gibt kein Teilen mit anderen Personen. Du kannst die Synchronisierung in den iOS-Einstellungen (Apple-Account → iCloud) abschalten. Es gilt die Datenschutzerklärung von Apple.

**3. Scannen und Texterkennung.** Die Kamera wird nur verwendet, wenn du einen Zulassungsschein oder einen Beleg scannst. Texterkennung (Vision) und, wenn dein Gerät Apple Intelligence unterstützt, die Auswertung durch das Sprachmodell von Apple (Foundation Models) laufen **auf dem Gerät**. Bilder und Texte werden nicht an [ANBIETER] oder Dritte gesendet. Die Ergebnisse speichert die App erst, wenn du sie bestätigst.

**4. Mitteilungen.** Erinnerungen sind lokale Mitteilungen, die dein Gerät selbst plant. Es gibt keine Push-Server des Anbieters.

**5. Käufe.** [APP-NAME] Pro (Jahresabo oder Einmalkauf) wird über Apple abgewickelt (App Store, StoreKit). Zahlungsdaten verarbeitet ausschließlich Apple. [ANBIETER] erhält keine Zahlungs- oder Kontodaten. Ob Pro aktiv ist, merkt sich die App nur lokal auf dem Gerät.

**6. Keine Weitergabe, kein Tracking.** Es werden keine Daten verkauft oder an Dritte weitergegeben. Die App enthält keine Drittanbieter-Software für Werbung oder Analyse.

**7. Weitergabe durch dich.** Wenn du einen Servicenachweis (PDF) oder einen Beleg teilst, entscheidest du über Empfänger und Weg. Das PDF enthält die von dir ausgewählten Fahrzeug- und Historiendaten.

**8. Speicherdauer und Löschen.** Du löschst Daten jederzeit in der App. Löschst du die App, werden die lokalen Daten entfernt; Daten in iCloud verwaltest du in den iOS-Einstellungen (iCloud → Speicher verwalten).

**9. Deine Rechte.** Du hast die Rechte nach DSGVO (Auskunft, Berichtigung, Löschung, Einschränkung, Widerspruch, Datenübertragbarkeit). Da [ANBIETER] keine personenbezogenen Daten von dir erhält, kann es dazu in der Regel keine Auskunft geben. Beschwerden kannst du an die Datenschutzbehörde richten ([BEHÖRDE, z. B. Österreichische Datenschutzbehörde, dsb.gv.at]).

**10. Webseite.** [Hinweis auf Hosting/Logs der Cloudflare-Seite ergänzen: Cloudflare kann technisch bedingt IP-Adressen verarbeiten. Hier ggf. ergänzen.]

**11. Änderungen.** Wir passen diese Erklärung an, wenn sich die App ändert. Das Datum oben zeigt den Stand.

**Kontakt:** [E-MAIL]

### English

**Privacy Policy for [APP NAME]**
Last updated: [DATE]

**Controller:** [NAME / COMPANY], [ADDRESS], [EMAIL]. (Same details as the legal notice.)

**In short:** [APP NAME] does not collect personal data. There is no account, no advertising, no analytics or tracking service and no server run by the provider. Everything you enter stays on your devices and in your own iCloud account.

**1. What the app processes.** Vehicle data (license plate, first registration, vehicle type, VIN, odometer readings, photos), deadlines and reminders, maintenance history entries with costs and receipts (photos, PDF). You enter or scan this data yourself.

**2. Where the data lives.** On your iPhone. If you use iCloud, Apple syncs it between your devices through CloudKit in a private area of your iCloud account. [PROVIDER] has no access to it. Nothing is shared with other people. You can turn sync off in iOS Settings (Apple Account → iCloud). Apple's privacy policy applies to iCloud.

**3. Scanning and text recognition.** The camera is only used when you scan a registration certificate or a receipt. Text recognition (Vision) and, on devices with Apple Intelligence, the analysis by Apple's language model (Foundation Models) run **on the device**. Images and text are not sent to [PROVIDER] or third parties. The app only saves the results after you confirm them.

**4. Notifications.** Reminders are local notifications that your device schedules itself. The provider runs no push servers.

**5. Purchases.** [APP NAME] Pro (yearly subscription or one-time purchase) is handled by Apple (App Store, StoreKit). Only Apple processes payment data. [PROVIDER] receives no payment or account data. The app stores whether Pro is active only locally on the device.

**6. No sharing, no tracking.** No data is sold or passed on to third parties. The app contains no third-party advertising or analytics software.

**7. Sharing by you.** If you share a service record (PDF) or a receipt, you decide who receives it and how. The PDF contains the vehicle and history data you selected.

**8. Retention and deletion.** You can delete data in the app at any time. If you delete the app, local data is removed; you manage data in iCloud in iOS Settings (iCloud → Manage Storage).

**9. Your rights.** You have the rights under the GDPR (access, rectification, erasure, restriction, objection, portability). As [PROVIDER] does not receive personal data from you, there is usually nothing to disclose. You can complain to a supervisory authority ([AUTHORITY, e.g. the Austrian Data Protection Authority, dsb.gv.at]).

**10. Website.** [Add a note about hosting and logs of the Cloudflare site: Cloudflare may technically process IP addresses.]

**11. Changes.** We update this policy when the app changes. The date above shows the current version.

**Contact:** [EMAIL]

## 4. Impressum: Angaben, die Christopher ausfüllt

Quelle: § 5 E-Commerce-Gesetz (ECG), § 25 Mediengesetz (MedienG). Entwurf, keine Rechtsberatung; vor der Veröffentlichung prüfen (z. B. WKO-Impressum-Check oder Rechtsberatung). Welche Punkte zutreffen, hängt von der Rechtsform ab (Einzelunternehmen, GmbH, …).

Pflicht nach § 5 ECG (Diensteanbieter):

- [ ] Name oder Firma (bei Unternehmen: Rechtsform)
- [ ] Geografische Anschrift des Niederlassungsorts (kein Postfach)
- [ ] Kontaktdaten für schnelle, direkte Kommunikation: E-Mail-Adresse (Telefonnummer empfohlen)
- [ ] Gegebenenfalls Firmenbuchnummer und Firmenbuchgericht
- [ ] Gegebenenfalls zuständige Aufsichtsbehörde
- [ ] Gegebenenfalls Kammer, Berufsverband, Berufsbezeichnung und Staat der Verleihung, Hinweis auf die Gewerbeordnung (Link zur anwendbaren Regelung)
- [ ] Gegebenenfalls Umsatzsteuer-Identifikationsnummer (UID)

Zusätzlich nach § 25 MedienG (Offenlegung), falls die Seite als Medium gilt (Websites mit mehr als bloßer Darstellung des persönlichen Lebensbereichs):

- [ ] Name oder Firma, Unternehmensgegenstand, Wohnort oder Sitz des Medieninhabers
- [ ] Gegebenenfalls Namen der Geschäftsführung, Aufsichtsrat/Beirat, Gesellschafter mit über 25 % Beteiligung
- [ ] Grundlegende Richtung der Website (Blattlinie), z. B.: „Information über die App [APP-NAME]“

Für den App Store:

- [ ] Als Händler („Trader“) im Rahmen des DSA: Name, Adresse, Telefonnummer und E-Mail werden in App Store Connect hinterlegt und öffentlich angezeigt. Entscheiden, ob dafür eine eigene Geschäftsadresse/Telefonnummer genutzt wird.
- [ ] Datenschutz-URL und Support-URL (Seite auf der eigenen Domain) in App Store Connect eintragen.

## 5. Was in der App steht

- `AppLinks.privacyPolicy` (`App/Sources/Services/AppLinks.swift`) ist die **einzige** Stelle für die Adresse (derzeit Platzhalter `https://example.com/pitlog/privacy`). Sie wird in der Paywall und in Einstellungen → „Datenschutzerklärung“ geöffnet.
- `Info.plist`-Nutzungstext: `NSCameraUsageDescription` in `App/Resources/InfoPlist.xcstrings` (en, de, „du“). Weitere Nutzungstexte sind nicht nötig: Fotos kommen über `PhotosPicker` (läuft außerhalb der App, ohne Berechtigung), Dateien über den Dateiimport, Mitteilungen fragt das System ohne Info.plist-Eintrag ab. Kommt Standort, Mikrofon oder Fotos-Schreiben hinzu, zuerst den Text in en und de ergänzen.
