# Österreichischer Zulassungsschein (Zulassungsbescheinigung Teil I)

Recherche als Grundlage für den Scan in M5 (`RegistrationDocumentParser`, ADR-13 in `CLAUDE.md`
auf `claude/practical-edison-jhlpos`; Umfang V1, Punkt „Zulassungsschein-Scan“). Stand
04.10.2026. Primärquellen sind KFG, Zulassungsstellenverordnung (ZustV) samt Anlagen und die
Richtlinie 1999/37/EG. Wo nur Sekundärquellen vorliegen, steht das dabei.

**Kurzfassung für den Parser**

- Drei Formate sind im Umlauf: **Papier** (gelbes Faltblatt, Standard), **Chipkarte**
  (Scheckkarte, auf Antrag, seit 2011) und **digital** in der App „eAusweise“ (seit Februar 2024,
  freiwillig). Dazu gelten **ältere Zulassungsscheine** aus der Zeit vor 1998 weiter.
- Papier und Chipkarte tragen die EU-Feldcodes, aber **ohne einheitliche Schreibweise**: auf
  Papier `C1.1`, `D1`, `F2`; auf der Kartenvorderseite `C.1.1`; auf der Kartenrückseite `D1`,
  `F2`, `S1/2`. Der Parser muss Codes normalisieren (Punkte und Leerzeichen ignorieren).
- Für V1 relevant: A (Kennzeichen), B (Erstzulassung), E (FIN), J (Fahrzeugklasse), D.1/D.2/D.3,
  F.2. Zusätzlich nützlich: A.4 (Verwendungsbestimmung als Kennziffer, z. B. 25 = Taxi).
- Häufigste Falle: **B** (erstmalige Zulassung) gegen **I** (Datum der aktuellen Zulassung) und
  gegen weitere Daten (A.6 Genehmigungsdatum, A.3 Geburtsdatum, H gültig bis).
- Die digitale Variante ist kein Dokument zum Scannen; ob Screenshot oder Export möglich ist,
  ist offen.

---

## 1. Formate

| Format | Status | Seit | Rechtsgrundlage | Muster |
|---|---|---|---|---|
| **Zulassungsbescheinigung Teil I, Papier** („Zulassungsschein“) | Standard, wird bei jeder Zulassung ausgestellt; Teil I ist mitzuführen | ZustV in Kraft spätestens 31.12.1998 (älteste im RIS dokumentierte Fassung des § 13) | § 41 KFG; § 13 Abs. 1 und 2 ZustV | ZustV Anlage 6 (aktuelle Innenseiten idF BGBl. II Nr. 282/2023, Varianten natürliche und juristische Person) |
| **Zulassungsbescheinigung Teil I im Chipkartenformat** (amtlich auch „Chipkartenzulassungsbescheinigung“, „Scheckkartenzulassungsschein“) | **optional, auf Antrag**, „anstelle“ des Papiers; Kostenersatz 31,10 € (seit 09.03.2026, davor 29,50 €) | beantragbar ab 01.12.2010, Erstausgabe ab 01.01.2011 | § 41a KFG; § 13 Abs. 1a ZustV; § 14 Abs. 4 ZustV | ZustV Anlage 7 (Kartenbild) und Anlage 7a (Felddefinitionen). Drei Designs: 2010, 25.09.2023, 03.01.2025 |
| Befristete Papierausfertigung | Bis zur Zustellung der Chipkarte, höchstens 8 Wochen | – | § 41a Abs. 1 Satz 3 und 4 KFG | wie Papier |
| **Digitaler Zulassungsschein** („Digitaler Dokumentennachweis“) in der App „eAusweise“ | freiwillig, zusätzlich zu Papier/Karte; befreit im Bundesgebiet von der Mitführpflicht; **nur in Österreich** anerkannt (laut ÖAMTC) | App-Angebot seit Mitte Februar 2024 (Bundeskanzleramt); Gesetz § 102e KFG in der RIS-Fassung ab 21.04.2023 | § 102e KFG | kein Muster; Kontrolle über QR-Code und Dateneinsicht in die zentrale Zulassungsevidenz |
| **Ältere Zulassungsscheine** (vor der Zulassungsbescheinigung) | bleiben gültig | – | § 41 Abs. 2 letzter Satz KFG („Vor Inkrafttreten dieser Bestimmung ausgestellte Zulassungsscheine bleiben weiter gültig.“), eingefügt mit der Fassung ab 01.03.1998 (BGBl. I Nr. 103/1997) | kein amtliches Muster gefunden; Aufbau und Felder nicht recherchiert (siehe Offene Punkte) |
| Zulassungsbescheinigung **Teil II** | nicht mitzuführen, wird mit dem Genehmigungsnachweis verbunden; nur Papier | wie Teil I | § 13 Abs. 2 ZustV, § 13a ZustV | ZustV Anlage 6 (rechte Spalte der Innenseite) |
| **Überstellungsfahrtschein** auf Vordruck Teil I | Sonderfall für Überstellungsfahrten | ab 02.11.2026 | § 13 Abs. 7 ZustV idF BGBl. II Nr. 38/2026; Anlage 8 | „Transport Permit“, Nummer im Muster `Ü 00000000` |

Weitere Merkmale aus dem KFG, die auf Papier oder Karte auftauchen können:

- **Zweitausfertigung:** Auf Antrag zwei gleichlautende Ausfertigungen; Vermerk auf der
  Zweitausfertigung, bei der Karte „Zweitkarte“ (§ 41 Abs. 3 KFG). Bei mehreren Karten gilt nur
  die mit der höchsten Seriennummer (§ 41 Abs. 4).
- Karte mit Vermerk **„Besitzgemeinschaft“** (§ 41a Abs. 5), **„Beiblatt“** (§ 41a Abs. 6),
  **„Teilbescheid“** (§ 41a Abs. 7).
- **Wechselkennzeichen:** ein Zulassungsschein pro Fahrzeug (§ 41 Abs. 7), also dasselbe
  Kennzeichen A auf mehreren Dokumenten möglich.
- Jede Änderung der Daten auf der Karte erfordert eine neue Karte (§ 13 Abs. 6 ZustV). Nach
  Abmeldung wird die Karte gelocht (Chip bleibt heil) und zurückgegeben; eine gelochte Karte ist
  ungültig.

### Digitaler Zulassungsschein im Detail

- Voraussetzung: ID Austria, Apps „Digitales Amt“ und „eAusweise“, Fahrzeug in Österreich auf
  die eigene Person zugelassen (auch Besitzgemeinschaft). Funktioniert auch ohne Chipkarte.
  (oesterreich.gv.at, ÖAMTC, Bundeskanzleramt)
- Die Daten kommen aus der zentralen Zulassungsevidenz (§ 102e Abs. 1 und 2 KFG), nicht aus
  einem Dokument. Sie dürfen höchstens zwölf Monate zwischengespeichert werden; die App zeigt,
  wann sie zuletzt aktualisiert wurden (§ 102e Abs. 5).
- **Teilen:** Der Zulassungsbesitzer darf die Nutzung Dritten zur Verfügung stellen (§ 102e
  Abs. 3), laut oesterreich.gv.at nur an andere eAusweise-Nutzer, mit frei wählbarer Dauer;
  danach werden die Daten beim Empfänger automatisch entfernt.
- **Kontrolle:** QR-Code in der App, den das Gegenüber scannt (autorevue.at, sekundär).
  Kann das Gerät die Daten nicht zeigen, gilt das als Nichtmitführen (§ 102e Abs. 1 Satz 2).
- **Export, PDF, Screenshot:** In keiner geprüften Quelle erwähnt. Ob die App Screenshots
  sperrt und ob ein Foto des Bildschirms die Feldcodes zeigt, ist **offen**.

## 2. Felder

### 2.1 Felder für V1

Beispielwerte sind **erfunden** und dienen nur zur Illustration der Form. Die Schreibweise der
Werte auf echten Dokumenten ist ohne Belegmuster nicht geprüft (siehe Offene Punkte).

| Code (EU) | Papier | Karte | Bezeichnung (AT, laut Muster bzw. Anlage 7a) | Beispielwert (erfunden) | Schreibweise und Hinweise |
|---|---|---|---|---|---|
| A | `A` | `A` (Vorderseite) | Kennzeichen | `W-12345X` | Format auf dem Dokument (Bindestrich, Leerzeichen) **offen**. Bezirkskennung nach KDV Anlage 5d. |
| B | `B` „Erstmalige Zulassung am:“ | `B` (Vorderseite) | Datum der Erstzulassung des Fahrzeugs | `15.03.2020` | Datum der erstmaligen Zulassung **im In- oder Ausland** (§ 41 Abs. 2 Z 2 KFG). Format ist in keiner Rechtsquelle festgelegt; österreichische Konvention TT.MM.JJJJ wird angenommen, **offen**. |
| E | `E` „FIN“ | `E` (Rückseite) | Fahrzeug-Identifizierungsnummer | `WAUZZZ8V0KA000000` | 17 Zeichen, nach ISO 3779 ohne `I`, `O`, `Q` (Allgemeinwissen, nicht im AT-Recht geprüft). Erlaubt OCR-Korrektur O→0, I→1. |
| J | `J` „Klasse / Fahrzeugart“ | `J` (Rückseite) | Fahrzeugklasse/Fahrzeugart | `M1` | Feld trägt Klasse **und** Fahrzeugart; wie beides kombiniert geschrieben wird, ist **offen**. Siehe 2.4. |
| D.1 | `D1` „Marke“ | `D1` | Marke | `BEISPIELMARKE` | einzeilig |
| D.2 | `D2` „Type/Variante/Version“ | `D2` | Typ/Variante/Version | `ABC1 / XYZ / 1.0` | auf Papier **doppelt hohe Zeile**, also mehrzeilig möglich |
| D.3 | `D3` „Handelsbezeichnung“ | `D3` | Handelsbezeichnung | `Beispiel 1.5` | auf Papier **vor** D2 angeordnet |
| F.2 | `F2` „Gesamtgewicht“ (Block „Höchste(s) zulässige(s)“) | `F2` | Höchstes zulässiges Gesamtgewicht | `1950` | Zahl in kg, Einheit vermutlich nicht im Feld; **offen** |

### 2.2 Weitere Felder mit EU-Code

Quelle: ZustV Anlage 7a (Felddefinitionen, Spalten „Visuell“ und „Chip“) und Anlage 6.
„Karte sichtbar“ = laut Anlage 7a mit freiem Auge lesbar (bzw. auf dem Kartenmuster zu sehen).
Felder, die nur im Chip stehen, sind auf der Karte nicht lesbar.

| Code | Bezeichnung (AT) | Papier | Karte sichtbar | Hinweis |
|---|---|---|---|---|
| C.1.1 | Name oder Firmenname (Papier: „Familienname“ bzw. „Firmenname“) | ja | ja (`C.1.1`) | Personendaten, für die App nicht nötig |
| C.1.2 | Vorname | ja (gemeinsame Zeile mit A3) | ja | |
| C.1.3 | Anschrift | ja, mehrzeilig | ja | mehrzeilig |
| C.4 | Antragsteller („Dies ist kein Eigentumsnachweis“) | ja („Antragsteller ist:“) | ja | |
| F.1 | Technisch zulässige Gesamtmasse | ja | ja | **Verwechslung mit F.2** |
| G | Eigengewicht | ja | ja | |
| H | Gültigkeitsdauer, falls nicht unbegrenzt („gültig bis“) | ja | ja | meist leer; ein Datum |
| I | Datum der Zulassung („Zugelassen am“) | ja | ja (Vorderseite, rechts neben A/B) | **Verwechslung mit B** |
| K | Genehmigungsnummer | ja | ja | |
| N.1–N.4 | Höchste zulässige Achslast Achse 1–4 (kg) | ja (Block „N höchste zulässige Achslasten 1–4“) | ja | |
| O.1 / O.2 | Höchste zulässige Anhängelast gebremst / ungebremst (kg) | ja | ja | **Code O1/O2 sieht aus wie Wert 01/02** |
| P.1 | Hubraum (cm³) | ja | ja | |
| P.2 | Leistung (kW) | ja | ja | |
| P.3 | Antriebsart | ja | ja | |
| P.4 | Drehzahl (min⁻¹) | ja („bei Drehzahl“) | laut Anlage 7a ja, im Kartenmuster aber kein eigenes Feld | Widerspruch zwischen Anlage 7 und 7a |
| P.5 | Motortyp | ja | ja | |
| Q | Leistung/Gewicht (kW/kg) | ja | ja | |
| R | Farbe des Fahrzeugs | ja | nein (nur Chip) | |
| S.1 / S.2 | Sitz-/Stehplätze | ja (`S1/S2`) | ja (`S1/2`, gemeinsames Feld) | |
| T | Höchstgeschwindigkeit (km/h) | ja | ja | |
| U.1 / U.2 | Standgeräusch dB(A) / bei Drehzahl | ja | ja | |
| U.3 | Fahrgeräusch | nein | nein (Chip; seit 1.4.2020 leer) | |
| V.1–V.5 | Schadstoffwerte | nein | nein (Chip; seit 1.4.2020 leer) | |
| V.6 | Korrigierter Absorptionskoeffizient | ja | nein (Chip) | |
| V.7 | CO2 (g/km) | ja | nein (Chip) | |
| V.8 | Kraftstoffverbrauch NEFZ | ja | nein (Chip) | |
| V.9 | Abgasverhalten nach Stufe | ja („Abgasklasse/-verhalten nach“) | ja | |
| – | Seriennummer | (fortlaufende Nummer, § 13 Abs. 4 ZustV) | ja | |
| – | Name des Mitgliedstaates | Deckblatt | ja („Republik Österreich“) | |

### 2.3 Nationale Felder (A.x)

Nach Art. 3 und Anhang I der Richtlinie 1999/37/EG dürfen Mitgliedstaaten eigene Codes
ergänzen. Österreich nutzt dafür `A.1` bis `A.27` (Anlage 7a, Anlage 6).

| Code | Bezeichnung | Papier | Karte sichtbar | Hinweis |
|---|---|---|---|---|
| A.1 | Zulassungsstelle (Zulassungsstellennummer) | ja | nein (Chip; sichtbar bei C.4 mit Behörde) | |
| A.2 | DVR-Nr. | nein | nein (seit 1.4.2020 leer) | |
| A.3 | Geburtsdatum bzw. Firmenbuchnummer | ja (Zeile mit C1.2 oder eigene Zeile) | nein (Chip) | **Datum, Verwechslung mit B** |
| A.4 | Verwendungsbestimmung | ja | ja (`A4`) | Kennziffer nach ZustV Anlage 4, z. B. `01` keine besondere Verwendung, `25` Taxigewerbe, `62` Rettungsdienst (Gebietskörperschaft/Sanitätergesetz), `64` privater Rettungsdienst. **Für die Pickerl-Kategorie Taxi/Rettung nutzbar.** |
| A.5 | Genehmigungsgrundlage | ja | nein (Chip) | |
| A.6 | Datum der Genehmigung | ja | nein (Chip) | **Datum, gleiche Zeile wie B** |
| A.7 | Nationaler Code | ja | ja | |
| A.8 | Aufbau | ja | nein (Chip) | |
| A.10 | Höchste zulässige Nutzlast (kg) | ja | ja | |
| A.12 | Höchste zulässige Stütz-/Sattellast | ja | ja | |
| A.13, A.17–A.20 | Räder/Bereifung, Auflagen, Behördliche Eintragungen, Anmerkungen, Anlage (ein gemeinsames Feld) | ja, großes Freitextfeld | nein (Chip) | mehrzeiliger Freitext |
| A.16 | Begutachtungsplakette | ja („Beg.Plakette“) | nein (Chip) | Inhalt unklar (Plakettennummer?). **Nicht** die Lochung. Offen. |
| A.21 | Anlage | nur Teil II | – | Kennzeichen für Teil II |
| A.22 | Anzahl der Vorzulassungen | nur Teil II | – | Kennzeichen für Teil II |
| A.23 | Vermerke | ja | ja | |
| A.24 | CO2 nach WLTP/WMTC | ja | nein (Chip) | |
| A.25 | Kraftstoffverbrauch WLTP/WMTC | ja | nein (Chip) | |
| A.26 | Leistung Elektromotor | ja | nein (Chip) | |
| A.27 | Fahrzeuguntergruppe | ja (seit 2023) | ja (seit Design 2023) | möglicherweise Unterklassen wie `L3e-A2`; **offen** |

### 2.4 Fahrzeugklasse in Feld J

Rechtlich steht fest: Feld J heißt in Österreich „Fahrzeugklasse/Fahrzeugart“ (Anlage 7a), auf
Papier „Klasse / Fahrzeugart“. Belegmuster mit Werten gibt es nicht. Erwartbare Klassencodes nach
EU-Typgenehmigungsrecht (Allgemeinwissen, nicht primär geprüft):

- `M1`, `M2`, `M3`, `N1`, `N2`, `N3`, `O1` bis `O4`
- Klasse L: `L1e` bis `L7e`, mit Unterklassen wie `L1e-B`, `L3e-A1`, `L3e-A2`, `L5e-A`,
  `L6e-B`, `L7e-A` (möglicherweise eher in A.27)
- Geländefahrzeuge mit Suffix `G` (`M1G`, `N1G`)
- Sonderfahrzeuge (z. B. Wohnmobil) möglicherweise mit Zusatz (`SA`)
- Land- und forstwirtschaftliche Zugmaschinen `T…`, Anhänger `R…`

Zusätzlich steht vermutlich eine österreichische Fahrzeugart im Klartext („Personenkraftwagen“,
„Motorrad“ …). Der Parser sollte das erste Token suchen, das auf
`^(M[1-3]|N[1-3]|O[1-4]|L[1-7]e(-[A-C][0-9]?)?|T[1-5]|R[1-4])G?$` passt, und den Rest als
Fahrzeugart behandeln. Muss mit echten Belegen geprüft werden.

## 3. Rechtsgrundlagen

| Norm | Inhalt | Fundstelle |
|---|---|---|
| Richtlinie 1999/37/EG über Zulassungsdokumente, Anhang I (Teil I), idF Richtlinie 2003/127/EG (Chipkarte) | harmonisierte Codes, zwingende und fakultative Angaben, nationale Zusatzcodes in Klammern, Format höchstens A4 bzw. A4-Faltblatt | https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX:31999L0037; RL 2003/127/EG: https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX:32003L0127. EUR-Lex war aus der Shell nicht abrufbar (Bot-Schutz); Anhang I nur über eine automatische Zusammenfassung gelesen, **nicht wörtlich geprüft**. |
| § 41 KFG 1967 | Zulassungsschein: Inhalt (Abs. 2), Verordnungsermächtigung, Gültigkeit alter Scheine, Zweitausfertigung, Ungültigkeit | https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10011384&Paragraf=41 |
| § 41a KFG 1967 | Chipkartenzulassungsbescheinigung (optional, befristete Papierausfertigung, Vermerke) | https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10011384&Paragraf=41a |
| § 102 Abs. 5 lit. b KFG | Mitführpflicht | https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10011384&Paragraf=102 |
| § 102e KFG | Digitaler Dokumentennachweis (digitaler Zulassungsschein) | https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10011384&Paragraf=102e |
| § 13 ZustV | Form, Farbe, Maße (Teil I 105 × 297 mm, Teil II 105 × 223 mm, gelb), Chipkarte, Seriennummer, Behördenname im Feld C.4 bzw. Stampiglie | https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10012863&Paragraf=13 |
| § 14 ZustV | Inkrafttreten (Chipkarte 2010/2011, Kartendesigns 2023 und 2025, Felder ab 2020 leer, Anlage 8 ab 02.11.2026) | https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10012863&Paragraf=14 |
| ZustV Anlage 4 | Kennziffern der Verwendungsbestimmung (Feld A.4) | https://www.ris.bka.gv.at/GeltendeFassung.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10012863 |
| ZustV Anlage 6 | Muster Papier | https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40255770/NOR40255770.html |
| ZustV Anlage 7 | Muster Chipkarte | https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40267683/NOR40267683.html |
| ZustV Anlage 7a | Felddefinitionen Chipkarte | https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40255772/II_282_2023_Anlage_7a.pdf |
| BGBl. II Nr. 38/2026 (16. Novelle zur ZustV) | Kostenersatz 31,10 €, Überstellungsfahrtschein (Anlage 8) | https://www.ris.bka.gv.at/Dokumente/BgblAuth/BGBLA_2026_II_38/BGBLA_2026_II_38.pdf |

Die frühere Annahme, die Anlage stehe in der Kraftfahrgesetz-Durchführungsverordnung, trifft
nicht zu: Die KDV 1967 enthält kein Muster des Zulassungsscheins. Maßgeblich ist die
Zulassungsstellenverordnung (Verordnungsermächtigung in § 41 Abs. 2 KFG).

## 4. Unterschiede zur deutschen Zulassungsbescheinigung Teil I (kurz, DE ist nicht V1)

- **Format:** DE 210 × 105 mm, weiß, zweimal auf DIN A7 faltbar, Text dunkelgrün
  (FZV 2023 Anlage 6, Vorbemerkungen, https://www.gesetze-im-internet.de/fzv_2023/anlage_6.html).
  AT gelb, Teil I 105 × 297 mm; AT zusätzlich Chipkarte. DE kennt keine Chipkarte.
- **Codes:** Beide nutzen die EU-Codes. Österreich ergänzt `A.1`–`A.27`; Deutschland ergänzt nach
  allgemeiner Kenntnis **numerische** nationale Codes in Klammern (etwa `2.1` Herstellerschlüssel,
  `2.2` Typschlüssel). Das ist hier nicht primär geprüft. Für einen gemeinsamen Parser heißt das:
  In DE kann ein Code wie `2.1` wie ein Zahlenwert aussehen; in AT nicht.
- **Schreibweise der Codes:** in DE in der Regel mit Punkt (`D.1`), in AT gemischt (siehe oben).
  Normalisierung deckt beides ab.
- **Inhalt von J und B:** In DE ist J laut allgemeiner Kenntnis nur der Klassencode, die
  Aufbauart steht in nationalen Feldern; in AT trägt J Klasse und Fahrzeugart. Datum in B in
  beiden Ländern vermutlich TT.MM.JJJJ, nicht geprüft.
- **Sicherheitsmerkmale:** DE hat Druckstücknummer mit DataMatrix-Code und freirubbelbaren
  Sicherheitscode (FZV 2023 Anlage 6 Nr. 5 und 6); für den Parser ohne Bedeutung, aber
  DataMatrix-Codes nicht mit Feldinhalten verwechseln.

## 5. Hinweise für den Parser

### 5.1 Formaterkennung

- **Chipkarte:** Seitenverhältnis ID-1 (85,6 × 54 mm, ISO 7810), Titel
  „ZULASSUNGSBESCHEINIGUNG TEIL1“, Chip. Vorder- und Rückseite sind **zwei Scans**; die
  V1-Felder verteilen sich: A, B auf der Vorderseite; E, J, D.1–D.3, F.2 auf der Rückseite.
  Die App sollte beide Seiten anfordern.
- **Papier Teil I:** gelbes Faltblatt, Innenseite mit drei Tabellenblöcken; Außenseite enthält
  keine Felder. Gefaltet liegen Blöcke 1 und 2 oft auf getrennten Seiten. Teil I hat
  `A23 Vermerke` und den Block `A13 … A20`; Teil II hat stattdessen `A22 Anzahl der
  Vorzulassungen` und `A21 Anlage` sowie den blauen statt roten Unterrand.
  **Erkennt der Parser A22 oder A21, ist es Teil II** (nicht mitzuführen, gleiche Kerndaten,
  aber Hinweis an den Nutzer).
- **Überstellungsfahrtschein** (ab 02.11.2026): Aufdruck „Transport Permit“, Nummer mit `Ü`.
  Ablehnen oder als Sonderfall kennzeichnen.
- **Alte Zulassungsscheine (vor 1998):** keine EU-Codes zu erwarten; Parser findet nichts →
  manuelle Eingabe anbieten.
- **Digital:** kein Scan; manuelle Eingabe.

### 5.2 Layout und Reihenfolge

- **Papier (Anlage 6, Teil I = linke Spalte der Innenseite):** jede Zeile = Code (kursiv) +
  Bezeichnung in einer schmalen linken Zelle, Wert in der Zelle rechts daneben. Manche Zeilen
  tragen zwei Felder nebeneinander (`I`/`H`, `B`/`A6`, `R`/`A16`, `G`/`S1/S2`, `T`/`P1`,
  `P2`/`P4`, `Q`/`A26`, `U1`/`U2`, `V8`/`V7`, `A25`/`A24`, `V6`/`A27`).
  Reihenfolge Block 1: A1, A, I/H, C1.1, C1.2/A3 (bzw. A3 bei Firmen), C1.3, C4, A4, E, B/A6,
  A5, K, A7. Block 2: J, D1, D3, D2, A8, R/A16, G/S1/S2, F1/N, F2, A10, A12, O1/O2, P5, P3, T/P1.
  Block 3: P2/P4, Q/A26, U1/U2, V9, V8/V7, A25/A24, V6/A27, A23, A13–A20.
- **Chipkarte Vorderseite:** Codes A, B, C.1.1, C.1.2, C.1.3, C.4 untereinander, Werte rechts
  daneben; „I“ steht rechts oben neben dem Pkw-Piktogramm. Unten links eine Legende
  „A Kennzeichen / B Erstmalige Zulassung / I Zugelassen“ (bei 2010 ohne I).
- **Chipkarte Rückseite:** Raster aus drei Spalten (links D1, D2, D3, J, S1/2, O1, O2, N1–N4,
  P5, A23; Mitte F1, F2, G, A10, A12, U1, U2, K; rechts E, A27, A4, A7, V9, Q, T, H, P1, P2, P3).
  D1, D2, D3 und J sind breite Zeilen; rechts daneben stehen E (Zeile D1), A27 und A4 (Zeile D3)
  sowie A7 (Zeile J). Fußzeile mit **Legende aller Codes** in Kleinschrift
  („A4 Verw-Best; A7 nat Code; … V9 Abgaskl“). Diese Legende darf **nicht** als Feldinhalt
  gelesen werden; sie steht unterhalb des Rasters und enthält dieselben Codes.

### 5.3 Mehrzeilige Felder

C.1.3 Anschrift, D.2 Type/Variante/Version (Papier: doppelte Zeilenhöhe), der Freitextblock
A13/A17/A18/A19/A20, A23 Vermerke. Bei C.1.1 kann der Name umbrechen. Für V1 ist nur D.2
relevant: alle Zeilen bis zum nächsten erkannten Code übernehmen.

### 5.4 Normalisierung der Codes

Erkannte Codes vor dem Vergleich vereinheitlichen: Punkte, Leerzeichen und Kursivfehler
entfernen (`C.1.1` = `C1.1` = `C 1.1`; `D.1` = `D1`; `F.2` = `F2`); `S1/2` = `S1/S2`;
`N` mit Achsnummer 1–4 = `N.1`–`N.4`.

### 5.5 Typische Verwechslungen

| Gefahr | Ursache | Gegenmaßnahme |
|---|---|---|
| B ↔ I | beide Datum, beide auf der Kartenvorderseite, I = Datum der **aktuellen** Zulassung | strikt am Code verankern; B ≤ I prüfen |
| B ↔ A6 | gleiche Papierzeile („Erstmalige Zulassung am:“ / „Genehmigungsdatum“) | Wert links vom A6-Label nehmen |
| B ↔ A3 / H | weitere Daten (Geburtsdatum, gültig bis) | Plausibilität: B nicht vor 1900, nicht in der Zukunft |
| Code `O1`/`O2` ↔ Wert `01`/`02` | Buchstabe O vs. Ziffer 0; A.4-Kennziffer ist zweistellig (`01`) | Codes nur in der Labelspalte suchen |
| Code `I` ↔ `1`/`l` | OCR | `I` nur als Code mit nachfolgendem Datum akzeptieren |
| `B` ↔ `8`, `S` ↔ `5`, `G` ↔ `6`, `D` ↔ `0` | OCR | Codes gegen die bekannte Codeliste prüfen |
| F.1 ↔ F.2 | nebeneinander/untereinander, beide kg; F.1 technisch, F.2 höchstes zulässiges | F.2 ≤ F.1 als Plausibilitätsprüfung |
| D.2 ↔ D.3 | auf Papier steht D3 **vor** D2 | am Code verankern, nicht an der Reihenfolge |
| P.1/P.2/P.3 ↔ P.5 | Zahlen vs. Text | Typprüfung (P.1, P.2 numerisch) |
| Legende der Kartenrückseite | enthält alle Codes | Bereich unterhalb des Rasters ignorieren |
| E (FIN) | O/0, I/1 | 17 Zeichen, ohne I/O/Q; Prüfziffer nur bei nordamerikanischen FIN |

## 6. Bilder

### Abgelegt (amtliche Werke nach § 7 UrhG, Muster aus der ZustV)

| Datei | Inhalt |
|---|---|
| `ZustV_Anl7_Chipkarte_2025.png` | Chipkarte, aktuelles Design ab 03.01.2025, Vorder- und Rückseite |
| `ZustV_Anl7_Chipkarte_2023_Vorderseite.png`, `…_Rueckseite.png` | Chipkarte, Design 25.09.2023 bis 02.01.2025 |
| `ZustV_Anl7_Chipkarte_2010_Vorderseite.png`, `…_Rueckseite.png` | Chipkarte, erstes Design 2010 bis 2023 (ohne A27) |
| `ZustV_Anl6_Papier_Innenseite_natuerlichePerson_2023.png` | Papier, Innenseite, natürliche Person (links Teil I, rechts Teil II) |
| `ZustV_Anl6_Papier_Innenseite_juristischePerson_2023.png` | Papier, Innenseite, juristische Person |
| `ZustV_Anl6_Papier_Aussenseite_2020.png` | Papier, Außenseite (Deckblätter Teil I und II) |

Zu jedem Bild gibt es eine `.md`-Datei mit Quelle, Abrufdatum, Lizenz und Urheber. Alle Muster
sind leer; sie enthalten keine Personen- oder Fahrzeugdaten. Für OCR-Tests mit Werten sind sie
nur als Layoutvorlage brauchbar.

### Nicht abgelegt (Lizenz unklar)

| Link | Beschreibung | Grund |
|---|---|---|
| https://commons.wikimedia.org/wiki/File:Zulassungsbescheinigung_Republik_%C3%96sterreich_Deckblatt.png | Deckblatt der österreichischen Zulassungsbescheinigung | Lizenzangabe CC BY-SA 3.0 (aus GFDL migriert), aber **kein Urheber und keine Quelle** angegeben; vermutlich Scan eines echten Dokuments |
| https://commons.wikimedia.org/wiki/File:Zulassungsschein_Deckblatt_1986_indiziert.png | Deckblatt eines Zulassungsscheins von 1986 (altes Format) | wie oben; Datei steht zusätzlich in einer Kategorie für Schnelllöschung |

Fotos echter Zulassungsscheine von Privatpersonen wurden nicht gesucht und nicht verwendet.
Ein offizielles Muster der BMIMI, von oesterreich.gv.at oder der Österreichischen
Staatsdruckerei mit **ausgefüllten** Beispielwerten wurde nicht gefunden.

## 7. Offene Punkte

1. **Schreibweise der Werte:** Datumsformat in B (vermutlich `TT.MM.JJJJ`), Kennzeichen in A
   (Bindestrich/Leerzeichen), Einheit in F.2, Kombination von Klasse und Fahrzeugart in J.
   Nur mit echten Belegen klärbar: Vorschlag aus `CLAUDE.md` (Basisbranch, Offene Frage 5)
   umsetzen, also 2 bis 3 geschwärzte Fotos eigener Dokumente von Christopher (Papier und
   Karte). Nicht aus dem Internet.
2. **Inhalt von A.27 (Fahrzeuguntergruppe) und A.16 (Begutachtungsplakette):** Anlage 7a nennt
   nur die Bezeichnung.
3. **P.4 auf der Karte:** Anlage 7a sagt „visuell“, das Kartenmuster hat kein P4-Feld.
4. **Digitaler Zulassungsschein:** Screenshot-Sperre, Export, Darstellung der Feldcodes in der App
   nicht dokumentiert. Klären, ob ein Bildschirmfoto als Eingabe sinnvoll ist (vermutlich nicht).
5. **Alte Zulassungsscheine (vor 1998):** Aufbau und ob noch nennenswert im Umlauf. Bei
   Fahrzeugen, die seither umgemeldet wurden, gibt es sie nicht mehr; bei durchgehend
   zugelassenen Altfahrzeugen schon.
6. **Historische Fahrzeuge:** Wo ein Fahrzeug als historisch gekennzeichnet ist (A.23 Vermerke,
   A.4?), ist offen. Für die Pickerl-Kategorie wichtig.
7. **Richtlinie 1999/37/EG:** Anhang I wörtlich nachlesen (EUR-Lex war aus der Cloud-Umgebung
   gesperrt).
8. **Kartendesign 2025:** Das RIS-Bild ist klein (644 × 829 px). Eine höher aufgelöste
   amtliche Fassung (PDF der BGBl. II Nr. 1/2025) könnte die Legende besser lesbar machen.

## 8. Quellen

Primär (RIS, abgerufen 04.10.2026): § 41, § 41a, § 102, § 102e KFG 1967; ZustV §§ 13, 14,
Anlagen 4, 6, 7, 7a, 8; BGBl. II Nr. 38/2026; § 41 KFG Fassungen 28.02.1998 und 01.03.1998.

Sekundär (abgerufen 04.10.2026):

- oesterreich.gv.at, eAusweise: https://www.oesterreich.gv.at/de/eausweise.html
- Bundeskanzleramt, 300.000 digitale Zulassungsscheine (01.04.2024): https://www.bundeskanzleramt.gv.at/bundeskanzleramt/nachrichten-der-bundesregierung/2024/04/staatssekretaerin-claudia-plakolm-ueber-300000-digitale-zulassungsscheine-in-nur-40-tagen-ausgestellt.html
- Bundeskanzleramt, App eAusweise (08/2026, rund 1,3 Mio. geladene Zulassungsscheine): https://www.bundeskanzleramt.gv.at/bundeskanzleramt/nachrichten-der-bundesregierung/2026/08/app-eausweise-wird-noch-benutzerfreundlicher-bedienung-noch-einfacher-und-intuitiver.html
- ÖAMTC, Der digitale Zulassungsschein: https://www.oeamtc.at/thema/autokauf/der-digitale-zulassungsschein-in-oesterreich-67303687
- autorevue.at, Digitaler Zulassungsschein: https://autorevue.at/ratgeber/digitaler-zulassungsschein-in-oesterreich
- USP-Lexikon, Zulassungsbescheinigung: https://www.usp.gv.at/services/suchen-und-finden/lexikon/zulassungsbescheinigung-frueher-zulassungsschein.html
- FZV 2023 Anlage 6 (DE): https://www.gesetze-im-internet.de/fzv_2023/anlage_6.html
