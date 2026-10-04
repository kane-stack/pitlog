# Österreich: Wiederkehrende Begutachtung („Pickerl“, § 57a KFG 1967)

> **Status dieses Dokuments: GEGEN PRIMÄRQUELLEN GEPRÜFT (Stand 04.10.2026).**
> Am 04.10.2026 wurden BGBl. I Nr. 79/2026, § 57a KFG (alte und neue Fassung), § 132 Abs. 37,
> § 135 Abs. 51, die PBStV und der Ausschussbericht 581 d.B. im Wortlaut gelesen. Die
> Wortlaute liegen unter `docs/sources/`. Die Fundstellen stehen pro Regel in der Spalte
> „Fundstelle“. Wo der Primärtext von der bisherigen Darstellung abweicht, steht das in der
> Spalte „Befund“; die bisherige Formulierung der Regel ist dort bewusst stehen geblieben.
> Die Engine (Regelversion `AT-2026-10-primary`, § 9) ist an die Primärquellen angepasst. Die
> Abweichungen, die dabei behoben wurden, und ihr Status stehen in § 10.
>
> Anders als in `CLAUDE.md` („Recherche“) vermerkt, waren ris.bka.gv.at, parlament.gv.at und
> oeamtc.at am 04.10.2026 aus der Cloud-Umgebung per Shell erreichbar.

## Status-Legende

| Status | Bedeutung |
|---|---|
| `PRIMÄR` | Wortlaut im RIS/BGBl. gelesen, Fundstelle (§, Abs., Z, Satz) angegeben |
| `SEKUNDÄR` | Mehrere unabhängige Sekundärquellen (ÖAMTC, ARBÖ, WKO, Parlamentskorrespondenz) stimmen überein |
| `OFFEN` | Quellen widersprechen sich oder fehlen, oder der Wortlaut lässt mehrere Lesarten zu; die Engine wendet die **konservative Auslegung** an |

**Konservative Auslegung** heißt hier: Im Zweifel zeigt die App den **früheren** spätesten
Begutachtungstermin. Ein zu frühes Datum kostet den Nutzer schlimmstenfalls eine
etwas frühere Begutachtung. Ein zu spätes Datum kann zu Strafen und Versicherungsproblemen führen.

Jede Regel hat eine ID (`AT-xx`). Tests in `PitlogCore` referenzieren diese IDs.

**Zählweise der Sätze in § 57a Abs. 3:** Satz 1 = Einleitung mit Z 1 bis 5 („Die wiederkehrende
Begutachtung ist jeweils zum Jahrestag …“), Satz 2 = „Über Antrag des Zulassungsbesitzers …“,
Satz 3 = „Die Begutachtung kann – ohne Wirkung … –“, Satz 4 = „Wurde der Nachweis …“,
Satz 5 = „Als wiederkehrende Begutachtung gilt auch …“. Das BGBl. I Nr. 79/2026 (Z 15) zählt
genauso („§ 57a Abs. 3 dritter Satz lautet“). „aF“ = Fassung bis 18.05.2027, „nF“ = Fassung ab
19.05.2027.

---

## Quellen

### Primärquellen (gelesen am 04.10.2026)

| Kürzel | Quelle | Ablage |
|---|---|---|
| Q-BGBL | BGBl. I Nr. 79/2026 (42. KFG-Novelle), ausgegeben 29.07.2026, amtssigniert. PDF: https://www.ris.bka.gv.at/Dokumente/BgblAuth/BGBLA_2026_I_79/BGBLA_2026_I_79.pdf, ELI: https://www.ris.bka.gv.at/eli/bgbl/I/2026/79 | `docs/sources/BGBl-I-2026-79_Art1.md` (Z 14–18, 42, 43) |
| Q-RIS57a-aF | § 57a KFG, Fassung 30.07.2026–18.05.2027: https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10011384&FassungVom=2027-05-18&Paragraf=57a | `docs/sources/KFG_57a_alt.md` |
| Q-RIS57a-2019 | § 57a KFG, Fassung 07.03.2019–29.02.2020 (vor Aufnahme der Klasse L in Z 3) | Anhang in `docs/sources/KFG_57a_alt.md` |
| Q-RIS57a-nF | § 57a KFG, Fassung ab 19.05.2027: https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10011384&FassungVom=2027-05-19&Paragraf=57a | `docs/sources/KFG_57a_neu.md` |
| Q-RIS132 | § 132 Abs. 37 KFG: https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10011384&FassungVom=2027-05-19&Paragraf=132 | `docs/sources/KFG_132_Abs37.md` |
| Q-RIS135 | § 135 Abs. 51 KFG: https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10011384&FassungVom=2027-05-19&Paragraf=135 | `docs/sources/KFG_135_Abs51.md` |
| Q-PBStV | Prüf- und Begutachtungsstellenverordnung, § 9: https://www.ris.bka.gv.at/GeltendeFassung.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10012794 (letzte Änderung BGBl. II Nr. 181/2023) | `docs/sources/PBStV_9.md` |
| Q-AB581 | 581 d.B. XXVIII. GP, Ausschussbericht Verkehr und Mobilität vom 02.07.2026 mit Begründung des Abänderungsantrags: https://www.parlament.gv.at/dokument/XXVIII/I/581/fname_1768810.pdf | `docs/sources/Materialien_AB581_Auszug.md` |
| Q-IA952 | Initiativantrag 952/A XXVIII. GP, eingebracht 11.06.2026: https://www.parlament.gv.at/dokument/XXVIII/A/952/fname_1764430.pdf (ursprünglich Inkrafttreten 01.10.2026, ohne Übergangsfenster) | nur Hinweis in `Materialien_AB581_Auszug.md` |
| Q-RIS102 | § 102 Abs. 8a KFG (Winterausrüstung) | `docs/sources/KFG_102_Abs8a.md` |
| Q-BStMG | Bundesstraßen-Mautgesetz 2002, § 11 Abs. 1 und 2, § 15 Abs. 2 Z 8 | `docs/sources/BStMG_11_15.md` |

### Sekundärquellen

| Kürzel | Quelle | Abgerufen |
|---|---|---|
| Q-OEAMTC-RECHNER | ÖAMTC-Pickerlrechner (API `p57a-calc`, Version 1.0.0), Abfrage von 26 Fällen | 04.10.2026, Ergebnisse in `docs/sources/OEAMTC_Pickerlrechner_2026-10-04.md` |
| Q-OEAMTC2 | ÖAMTC, Neue §57a-Regelung / Fristen berechnen (mit FAQ): https://www.oeamtc.at/thema/pickerl/neue-57a-pickerl-regelung-in-oesterreich-jetzt-intervall-fristen-berechnen-89430229 | gelesen, 04.10.2026 |
| Q-OTS-RECHNER | ÖAMTC-Pickerlrechner, OTS 02.10.2026: https://www.ots.at/presseaussendung/OTS_20261002_OTS0014/oeamtc-pickerlrechner-beantwortet-offene-fragen-zur-neuen-57a-regelung | gelesen, 04.10.2026 |
| Q-JUS | § 57a KFG bei JUSLINE: https://www.jusline.at/gesetz/kfg/paragraf/57a | Suchtreffer, 04.10.2026 (durch Q-RIS57a-aF ersetzt) |
| Q-PK0667 | Parlamentskorrespondenz Verkehrsausschuss 02.07.2026: https://www.parlament.gv.at/aktuelles/pk/jahr_2026/pk0667 | Suchtreffer, 04.10.2026 |
| Q-PK0691 | Parlamentskorrespondenz Nationalrat 06.07.2026: https://www.parlament.gv.at/aktuelles/pk/jahr_2026/pk0691 | Suchtreffer, 04.10.2026 |
| Q-ME105 | Ministerialentwurf 105/ME: https://www.parlament.gv.at/gegenstand/XXVIII/SNME/4372 | Suchtreffer, 04.10.2026 |
| Q-BR994 | Bundesrat 994. Sitzung, 16.07.2026, kein Einspruch: https://www.parlament.gv.at/gegenstand/BR/BRSITZ/994 | Suchtreffer, 04.10.2026 |
| Q-BMF | BMF-Fachinformation „Kostenersatz für Austauschplakette gem § 132 Abs 37 Z 5 KFG“: https://www.bmf.gv.at/rechtsnews/steuern-rechtsnews/aktuelle-infos-und-erlaesse/fachinformationen---umsatzsteuer/kostenersatz-fuer-austauschplakette-gem-%C2%A7-132-abs-37-z-5-kfg.html | Suchtreffer, 04.10.2026 |
| Q-OEAMTC1 | ÖAMTC, Längere Pickerl-Intervalle: https://www.oeamtc.at/thema/pickerl/laengere-pickerl-intervalle-57a-87229599 | Suchtreffer, 04.10.2026 |
| Q-OEAMTC-L | ÖAMTC, Änderung der Begutachtungsfrist Klasse L (2020): https://www.oeamtc.at/mitgliedschaft/pruefdienst-leistungen/57a-begutachtung-pickerl/aenderung-der-begutachtungsfrist-fuer-fahrzeugklasse-l-24217497 | Suchtreffer, 04.10.2026 |
| Q-ARBOE | ARBÖ: https://www.arboe.at/medien/news/arboe-verlaengerung-der-pickerl-intervalle-bringt-vor-und-nachteile | Suchtreffer, 04.10.2026 |
| Q-WKO1 | WKO, Begutachtungsintervalle/-zeitpunkt: https://wko.at/branchen/gewerbe-handwerk/fahrzeugtechnik/begutachtungsintervalle-begutachtungszeitpunkt.html | Suchtreffer, 04.10.2026 |
| Q-WKO2 | WKO Transport, Pickerl: https://www.wko.at/transport/pickerl-ueberpruefung-begutachtung-57a-kfg | Suchtreffer, 04.10.2026 |
| Q-STD | derStandard: https://www.derstandard.at/story/3000000328157/warum-die-regierung-die-pickerl-nachfrist-abschaffen-will | Suchtreffer, 04.10.2026 |
| Q-FUERB | fuerboeck.at, 42. KFG-Novelle: https://www.fuerboeck.at/verkehrsrecht/kfg/novellen/42/ | Suchtreffer, 04.10.2026 |

---

## 1. Rechtsgrundlage und Zeitpunkt

| ID | Regel (bisherige Formulierung) | Status | Fundstelle | Befund |
|---|---|---|---|---|
| AT-01 | Die Reform ist die 42. KFG-Novelle, BGBl. I Nr. 79/2026, ausgegeben am 29.07.2026. | PRIMÄR | BGBl. I Nr. 79/2026, Kopf | bestätigt |
| AT-02 | § 57a Abs. 3 in der neuen Fassung und § 132 Abs. 37 treten am **19.05.2027** in Kraft. Ursprünglich war Oktober 2026 geplant, der Termin wurde im Verkehrsausschuss verschoben. | PRIMÄR | § 135 Abs. 51 Z 2 | bestätigt. Der ursprüngliche Termin 01.10.2026 steht im Initiativantrag 952/A (Q-IA952). Ergänzung: § 57a Abs. 4 und 6 nF gelten schon seit 30.07.2026 (§ 135 Abs. 51 Z 1), sie betreffen nicht die Fristen. |
| AT-03 | Die Inkrafttretensbestimmung steht angeblich in § 135 Abs. 51. | PRIMÄR | § 135 Abs. 51 | bestätigt |
| AT-04 | Die Übergangsbestimmungen stehen in **§ 132 Abs. 37**. | PRIMÄR | § 132 Abs. 37 Z 1 bis 5 | bestätigt |

Für die Engine gilt als Stichtag `2027-05-19`. Die Engine arbeitet monatsgenau. Der
Stichtag fällt mitten in den Mai, deshalb muss für Mai 2027 tagesgenau entschieden werden,
welche Fassung gilt (siehe AT-41). Bestätigt: § 57a Abs. 3 aF gilt bis 18.05.2027, nF ab 19.05.2027
(RIS-Fassungsliste und § 135 Abs. 51 Z 2).

## 2. Bezugsmonat (Lochung)

| ID | Regel (bisherige Formulierung) | Status | Fundstelle | Befund |
|---|---|---|---|---|
| AT-10 | Gelocht wird grundsätzlich der **Monat der Erstzulassung**. Er bleibt der Bezugsmonat, auch wenn innerhalb des Fensters früher oder später begutachtet wird. | PRIMÄR | § 57a Abs. 3 Satz 1 aF/nF („jeweils zum Jahrestag der ersten Zulassung, auch wenn diese im Ausland erfolgte“); Satz 3 aF/nF („ohne Wirkung für den Zeitpunkt der nächsten Begutachtung“); PBStV § 9 Abs. 1 (Lochung von Jahr und Monat der nächsten Begutachtung) | bestätigt. Präzisierung: Das Gesetz spricht vom **Jahrestag**, die Plakette zeigt nur **Monat und Jahr**. |
| AT-11 | Auf Antrag bei der Zulassungsbehörde kann ein anderer Begutachtungsmonat festgesetzt werden. | PRIMÄR | § 57a Abs. 3 Satz 2 | bestätigt. Wortlaut: „einen anderen **Tag** als den Jahrestag der ersten Zulassung“. |
| AT-12 | Eine Begutachtung **außerhalb** des Fensters (z. B. verspätet) führt zu einer neuen Lochung ab dem Begutachtungsmonat. | OFFEN | nicht geregelt | Weder § 57a noch § 132 Abs. 37 noch die PBStV regeln die verspätete Begutachtung. Lesart A: Neue Lochung ab dem Begutachtungsmonat (bisherige Annahme, so verbreitete Praxis, nicht primär belegt). Lesart B: Der Jahrestag (Satz 1) bleibt maßgeblich, die Frist zählt weiter vom gelochten Monat; das ergibt den **früheren** nächsten Termin. Entscheidung (D-09, ADR-8): Die Engine liefert den **frühesten plausiblen** Fälligkeitsmonat und füllt damit nur die Plakettenauswahl vor; der Nutzer trägt die tatsächliche Lochung ein (siehe § 9.2, § 10). |
| AT-13 | (neu) Fehlt der Nachweis der Erstzulassung, setzt die Behörde den Zeitpunkt der ersten Begutachtung fest. | PRIMÄR | § 57a Abs. 3 Satz 4 | neu aufgenommen, für die Engine ohne Folgen (Plakette ist führend) |

**Konsequenz für die App:** Maßgeblich ist der auf der Plakette gelochte Monat und das Jahr.
Die App fragt beides ab. Die Berechnung aus der Erstzulassung ist nur ein Vorschlag.
Bestätigt durch § 132 Abs. 37 Z 2 und PBStV § 9 Abs. 1.

## 3. Intervalle bis 18.05.2027 (alte Fassung)

| ID | Kategorie | Intervall (bisherige Formulierung) | Status | Fundstelle | Befund |
|---|---|---|---|---|---|
| AT-20 | M1 (Pkw), ohne Taxi, Rettung, Krankentransport | 3-2-1: erste nach 3 Jahren, zweite 2 Jahre danach, dann jährlich | PRIMÄR | § 57a Abs. 3 Z 3 lit. a sublit. bb aF | bestätigt. Der Wortlaut zählt **Begutachtungen**, nicht Fahrzeugjahre: „drei Jahre nach der ersten Zulassung, zwei Jahre nach der ersten Begutachtung und ein Jahr nach der zweiten und nach jeder weiteren Begutachtung“. |
| AT-21 | Klasse L (Moped, Motorrad, Quad, Leichtkraftfahrzeug) | 3-2-1 seit 01.03.2020; davor anders, nicht recherchiert | PRIMÄR | § 57a Abs. 3 Z 3 lit. a sublit. aa aF; Fassung bis 29.02.2020 (Q-RIS57a-2019) | bestätigt. Klasse L fällt erst seit der Fassung ab 01.03.2020 (BGBl. I Nr. 78/2019) unter Z 3; davor galt für sie Z 1 (**jährlich**). Erfasst ist die ganze Klasse L. |
| AT-22 | Anhänger bis 3.500 kg höchstzulässiges Gesamtgewicht (O1/O2) | 3-2-1 | PRIMÄR | § 57a Abs. 3 Z 3 lit. d aF | bestätigt mit Präzisierung: Das Gesetz nennt keine Klassen O1/O2, sondern „Anhänger, mit denen eine Geschwindigkeit von 25 km/h überschritten werden darf und die ein höchstes zulässiges Gesamtgewicht von nicht mehr als 3.500 kg aufweisen“. Anhänger bis 25 km/h sind ganz ausgenommen (§ 57a Abs. 1 Z 1). |
| AT-23 | N1 (leichte Lkw, auch Kastenwagen) | jährlich, erste nach 1 Jahr | PRIMÄR | § 57a Abs. 3 Z 1 aF/nF | bestätigt: „bei Kraftfahrzeugen, ausgenommen solche nach Z 3 und historische Kraftfahrzeuge gemäß Z 4, jährlich“, gezählt ab dem Jahrestag der ersten Zulassung (Satz 1). Gilt für alle N (N1 bis N3) und für M2/M3. |
| AT-24 | Taxi, Rettung, Krankentransport | jährlich | PRIMÄR | § 57a Abs. 3 Z 3 lit. a sublit. bb (Ausnahme) i. V. m. Z 1 | bestätigt: Diese M1 sind aus Z 3 ausgenommen und fallen unter Z 1. |
| AT-25 | Historische Fahrzeuge | alle 2 Jahre | PRIMÄR | § 57a Abs. 3 Z 4 aF/nF | bestätigt: „bei historischen Fahrzeugen alle zwei Jahre“. Der Wortlaut bindet das an das Intervall, nicht an ein gerades Fahrzeugalter (siehe § 10, D-10). |
| AT-26 | Kfz und Anhänger über 3,5 t, Busse | jährlich | PRIMÄR | § 57a Abs. 3 Z 1 (Kfz) und Z 2 (Anhänger) aF/nF | bestätigt |
| AT-27 | (neu) Landwirtschaftliche Anhänger über 25 bis 40 km/h | 3-2-2: drei Jahre nach EZ, zwei nach der ersten Begutachtung, danach alle zwei Jahre | PRIMÄR | § 57a Abs. 3 Z 5 aF/nF | neu aufgenommen; von der Novelle nicht geändert. Die Engine unterstützt diese Kategorie nicht. |

## 4. Intervalle ab 19.05.2027 (neue Fassung)

| ID | Kategorie | Intervall (bisherige Formulierung) | Status | Fundstelle | Befund |
|---|---|---|---|---|---|
| AT-30 | M1 (ohne Taxi, Rettung, Krankentransport), L, O1/O2 | **4-2-2-2-1**: erste 4 Jahre nach Erstzulassung, dann dreimal 2 Jahre (Jahr 6, 8, 10), danach jährlich (Jahr 11, 12, …) | PRIMÄR | § 57a Abs. 3 Z 3 nF (geändert durch BGBl. I Nr. 79/2026 Z 14) | bestätigt. Wortlaut: „vier Jahre nach der ersten Zulassung, jeweils zwei Jahre nach der ersten, zweiten und dritten Begutachtung und ein Jahr nach der vierten und nach jeder weiteren Begutachtung“. Auch hier wird nach **Begutachtungen** gezählt. Bei regulärem Verlauf ergibt das die Jahre 4, 6, 8, 10, 11, … Die Materialien (Q-AB581) sprechen von „4:2:2:2:1“ und jährlicher Prüfung „für Fahrzeuge älter als zehn Jahre“. |
| AT-31 | Zusätzlich erfasst: land- und forstwirtschaftliche Zugmaschinen und Anhänger, ggf. Motorkarren und selbstfahrende Arbeitsmaschinen bis 40 km/h | — | PRIMÄR | § 57a Abs. 3 Z 3 lit. b bis e aF/nF | **Widerspruch zur bisherigen Angabe:** Diese Fahrzeuge sind nicht „zusätzlich“ erfasst; sie standen schon in Z 3 aF und bekommen mit ihr das neue Intervall: Zugmaschinen und Motorkarren über 25 bis 40 km/h (lit. b), selbstfahrende Arbeitsmaschinen und Transportkarren über 30 bis 40 km/h (lit. c), landwirtschaftliche Anhänger über 40 km/h (lit. e). Landwirtschaftliche Anhänger über 25 bis 40 km/h bleiben bei Z 5 (AT-27). |
| AT-32 | **Nicht** erfasst: N (auch N1), Taxi, Rettung, Krankentransport, historische Fahrzeuge. Für sie bleiben die Intervalle unverändert. | PRIMÄR | § 57a Abs. 3 Z 1, 2 und 4 nF (unverändert) | bestätigt für die **Intervalle**. Das **Fenster** ändert sich für diese Fahrzeuge aber sehr wohl (siehe AT-43). |
| AT-33 | Einzelne Medien nennen „4-2-2-1“ bzw. „jährlich ab 8 Jahren“. Parlament, ÖAMTC und ARBÖ sagen 4-2-2-2-1. Wir halten „4-2-2-1“ für falsch. | PRIMÄR | § 57a Abs. 3 Z 3 nF | erledigt: „4-2-2-1“ ist falsch, es sind drei Zweijahresabstände (nach der ersten, zweiten und dritten Begutachtung). |

## 5. Begutachtungsfenster

| ID | Regel (bisherige Formulierung) | Status | Fundstelle | Befund |
|---|---|---|---|---|
| AT-40 | **Alte Fassung, M1/L/O1/O2:** Begutachtung ab Beginn des Monats **vor** dem gelochten Monat bis zum Ablauf des **vierten** Monats danach (−1/+4). Wortlaut laut Suchtreffer: „in der Zeit vom Beginn des dem vorgesehenen Zeitpunkt vorausgehenden Kalendermonates bis zum Ablauf des vierten darauffolgenden Kalendermonates“. Eine Begutachtung im Fenster ändert den Bezugsmonat nicht. | PRIMÄR | § 57a Abs. 3 Satz 3 aF, zweiter Fall | Wortlaut bestätigt. **Erweiterung:** −1/+4 gilt für alle „in Z 3 bis Z 5 genannten Fahrzeuge“, also auch für **historische Fahrzeuge (Z 4)** und landwirtschaftliche Anhänger nach Z 5. |
| AT-41 | **Neue Fassung:** Begutachtung bis zu **vier Monate vor** dem gelochten Monat, ohne Wirkung auf den nächsten Termin. Die viermonatige Nachfrist **entfällt**. Spätester Termin ist das **Ende des gelochten Monats** (−4/0). Wortlaut laut Suchtreffer: „Die Begutachtung kann – ohne Wirkung für den Zeitpunkt der nächsten Begutachtung – auch in einem Zeitraum von vier Monaten vor dem vorgesehenen Begutachtungsmonat vorgenommen werden.“ | PRIMÄR | § 57a Abs. 3 Satz 3 nF (BGBl. I Nr. 79/2026 Z 15) | Wortlaut bestätigt. „Zeitraum von vier Monaten vor dem … Begutachtungsmonat“ = die vier Kalendermonate D−4 bis D−1. Zum spätesten Tag siehe AT-45. |
| AT-42 | **Alte Fassung, N und schwere Fahrzeuge:** −3/0 | PRIMÄR | § 57a Abs. 3 Satz 3 aF, erster Fall | bestätigt: „bei den in Z 1 und Z 2 genannten Fahrzeugen auch in einem Zeitraum von drei Monaten vor dem vorgesehenen Begutachtungsmonat“. Das betrifft alle Kfz nach Z 1 (N, Taxi, Rettung, Krankentransport, M2/M3, Kfz über 3,5 t) und Anhänger nach Z 2, **nicht** aber historische Fahrzeuge (Z 4, siehe AT-40). |
| AT-43 | Gilt das neue Fenster −4/0 für **alle** Fahrzeuge (auch N, Taxi, historische) oder nur für die 4-2-2-2-1-Klassen? | PRIMÄR | § 57a Abs. 3 Satz 3 nF; Q-AB581 (Begründung zu Z 14 und 15) | **Gelöst: für alle Fahrzeuge.** Satz 3 nF unterscheidet nicht mehr nach Z 1 bis 5. Die Materialien sagen ausdrücklich, der Toleranzzeitraum werde „für alle Fahrzeuge“ vereinheitlicht. Der ÖAMTC-Rechner rechnet für N, Taxi und historische Fahrzeuge ebenso −4/0. |
| AT-44 | Ein Antrag, die Nachfrist für historische Fahrzeuge und Motorräder zu behalten, fand keine Mehrheit. | SEKUNDÄR | — | Im Ausschussbericht 581 d.B. steht nur ein abgelehnter **Vertagungsantrag**. Ein Antrag zur Nachfrist für historische Fahrzeuge und Motorräder kommt dort nicht vor; das Stenographische Protokoll der NR-Sitzung (85. Sitzung) wurde nicht geprüft. Für die Engine ohne Folgen. |
| AT-45 | (neu) Spätester Tag des Fensters nach neuer Fassung ist der letzte Tag des gelochten Monats. | OFFEN | § 57a Abs. 3 Satz 1 und 3 nF; PBStV § 9 Abs. 1; § 57a Abs. 6 Satz 2 | Lesart A (Engine, ÖAMTC): letzter Tag des Begutachtungsmonats. Dafür spricht, dass Satz 3 vom „Begutachtungsmonat“ spricht und die Plakette nur Monat und Jahr zeigt; die Materialien rechnen im Juni-Beispiel mit ganzen Monaten (§ 11, M-01). Lesart B: Der Jahrestag der Erstzulassung (Satz 1) ist der späteste Tag. Kein Text sagt ausdrücklich „bis zum Ende des Begutachtungsmonats“. Risiko gering, da die Kontrolle nach Plakette (Monat) erfolgt. |

## 6. Übergang (§ 132 Abs. 37)

| ID | Regel (bisherige Formulierung) | Status | Fundstelle | Befund |
|---|---|---|---|---|
| AT-50 | Die neuen Intervalle gelten auch für Fahrzeuge, die **vor** dem 19.05.2027 zugelassen wurden. | PRIMÄR | § 132 Abs. 37 Z 1 Satz 1 | bestätigt |
| AT-51 | Bis eine neue Plakette angebracht ist, **gilt die Lochung der vorhandenen Plakette** weiter. | PRIMÄR | § 132 Abs. 37 Z 2 | bestätigt. Laut Materialien ist das Weiterfahren nach Ablauf ohne Begutachtung oder Austausch eine Übertretung nach § 36 lit. e KFG. |
| AT-52 | **Austauschplakette (optional):** Ergibt sich nach neuem Recht ein späterer Termin, kann der Halter bei einer berechtigten Stelle eine neu gelochte Plakette verlangen, ohne neue Begutachtung. Voraussetzung ist, dass das zuletzt gespeicherte Gutachten nicht negativ war (kein schwerer Mangel, keine Gefahr im Verzug). | PRIMÄR | § 132 Abs. 37 Z 1 Satz 2; Z 4 | bestätigt. Präzisierung zu Z 4: maßgeblich ist das letzte in der **Begutachtungsplakettendatenbank** gespeicherte Gutachten nach § 57a **oder § 56** mit schwerem Mangel oder Mangel mit Gefahr im Verzug. Wortlaut „nach dem 19. Mai 2027“; Z 1 tritt aber am 19.05.2027 in Kraft (§ 135 Abs. 51 Z 2), der ÖAMTC nennt den 19.05.2027 als ersten Tag. |
| AT-53 | **Lochung der Austauschplakette:** Bei einem Fahrzeug, das noch nie begutachtet wurde, ist der Termin 4 Jahre nach Erstzulassung. Bei allen anderen sind es **2 Jahre nach dem letzten Gutachten**. | PRIMÄR | § 132 Abs. 37 Z 1 Satz 3 und 4 | bestätigt, aber **unvollständig**: Satz 4 begrenzt die zwei Jahre: „wobei spätestens im zehnten Jahr nach der Erstzulassung und danach, jährlich eine Begutachtung zu erfolgen hat“. Nie begutachtete Fahrzeuge: erste Begutachtung 4 Jahre nach EZ, danach § 57a Abs. 3 Z 3 nF. Bereits begutachtete: nächste **und jede weitere** Begutachtung 2 Jahre nach der letzten, mit der Grenze des zehnten Jahres. Die Materialien ergänzen: Der Abstand zwischen erster und zweiter Begutachtung darf nicht über zwei Jahre wachsen. |
| AT-54 | Was bei Fahrzeugen in der jährlichen Phase gilt (über 10 Jahre) und an der Grenze zwischen den Phasen (9 bis 10 Jahre), ist unklar. Gibt AT-53 auch einem 12 Jahre alten Fahrzeug 2 Jahre? Das widerspräche AT-30. | PRIMÄR | § 132 Abs. 37 Z 1 Satz 4 und 5; Q-AB581 (Begründung zu Z 42) | **Gelöst:** Nein. Ab dem zehnten Jahr nach der Erstzulassung ist jährlich zu begutachten; ein 12 Jahre altes Fahrzeug bekommt keine längere Frist und damit keine Austauschplakette. **Neu und wichtig (Satz 5):** Wird trotzdem zum alten gelochten Termin begutachtet, folgt die nächste und jede weitere Begutachtung **zwei Jahre nach dieser Begutachtung**, ebenfalls mit der Grenze des zehnten Jahres. Die Materialien: „zweijähriges Intervall und ab zehn Jahren einjährig“. Zur Bedeutung von „im zehnten Jahr“ siehe AT-54a. |
| AT-54a | (neu) Was heißt „spätestens im zehnten Jahr nach der Erstzulassung“? | OFFEN | § 132 Abs. 37 Z 1 Satz 4 und 5 | Lesart A: spätestens zum 10. Jahrestag der Erstzulassung (Alter 10), danach jährlich. Dafür sprechen das Schema 4-2-2-2-1 (4. Begutachtung bei Alter 10), die Materialien („nach 10 Jahren eine jährliche Überprüfung“, „Fahrzeuge älter als zehn Jahre“, „ab zehn Jahren einjährig“) und der ÖAMTC-Rechner (Fall X5: EZ 2018-09 → Austauschplakette 2028-09, Alter 10). Lesart B: innerhalb des zehnten Jahres, also zwischen 9. und 10. Jahrestag; das ergäbe eine Begutachtung schon bei Alter 9. Die Engine folgt Lesart A. Lesart B wäre die konservativere, widerspricht aber dem 4-2-2-2-1-Schema. Empfehlung: Lesart A beibehalten, Hinweis `AT-54a` nur in diesem Grenzfall (Alter bei D = 9). |
| AT-55 | Kostenersatz für die Austauschplakette: höchstens 10 € zusätzlich zum Plakettenpreis (§ 132 Abs. 37 Z 5), umsatzsteuerpflichtig. | PRIMÄR (Betrag), SEKUNDÄR (USt) | § 132 Abs. 37 Z 5 | Betrag bestätigt; gilt nur für eine Ausgabe, die „nicht im Zuge einer Begutachtung erfolgt“. Die Umsatzsteuerpflicht steht nur in der BMF-Fachinformation (Q-BMF), nicht im KFG. |
| AT-56 | **Übergangsfenster 2027:** Es gibt drei unvereinbare Darstellungen. (a) Bei Fälligkeit Februar bis Juli 2027 gilt weiter −1/+4. (b) Bei Lochung Jänner bis Oktober 2027 gilt −1/+4, längstens bis 30.11.2027. (c) Bei Fälligkeit August bis Oktober 2027 wird bis November 2027 erstreckt; ab Ende November 2027 gibt es keine Überschreitung mehr. | PRIMÄR | § 132 Abs. 37 Z 3; § 57a Abs. 3 Satz 3 aF; § 135 Abs. 51 Z 2 | **Gelöst.** Richtig sind (a) und (c) zusammen, (b) ist falsch. Z 3 Satz 1: Stichtag **Februar bis Juli**: Für die Begutachtung 2027 gelten die Fristen des Satzes 3 **aF** weiter, also −1/+4 für Z 3 bis 5 (auch historische) und −3/0 für Z 1 und 2 (N, Taxi …). Z 3 Satz 2: Stichtag **August bis Oktober**: „zusätzlich eine Fristverlängerung bis inklusive November 2027“, also spätester Tag 30.11.2027. **Jänner 2027** ist nicht erfasst: Die Nachfrist aF endet mit Außerkrafttreten am 18.05.2027. Z 3 gilt für **alle Fahrzeuge**, nicht nur für Z 3-Fahrzeuge. „Stichtag“ ist in der App der gelochte Monat. |
| AT-57 | Die Novelle wurde nach der Kundmachung nicht mehr geändert (Stand 04.10.2026). Offen ist, ob eine PBStV-Novelle die Plakettenlochung oder die Austauschplakette regelt. | OFFEN | RIS: § 57a, § 132 (Fassungslisten); PBStV (letzte Änderung BGBl. II Nr. 181/2023) | Die Novelle ist laut RIS-Fassungsliste seither nicht geändert. Die PBStV ist seit BGBl. II Nr. 181/2023 unverändert und regelt die Austauschplakette nicht. Ein PBStV-Entwurf 2026 wurde per Websuche nicht gefunden; die RIS-Suche nach Begutachtungsentwürfen war per Shell nicht abfragbar (Weiterleitung). Bleibt OFFEN. |
| AT-58 | (neu) Die Austauschplakette kann erst ab 19.05.2027 ausgegeben werden. | PRIMÄR | § 135 Abs. 51 Z 2 (Inkrafttreten § 132 Abs. 37) | neu aufgenommen; ÖAMTC sagt dasselbe |

### Entscheidungen der Engine (Regelversion `AT-2026-10-primary`)

Stand 04.10.2026, nach Abgleich mit den Primärquellen. Wo das Gesetz eine Frage offenlässt,
gilt ADR-8 (konservative Auslegung, früherer spätester Termin) plus Hinweis in der UI. Die
Engine liefert eine `RuleNote` mit Regel-ID nur noch dort, wo wirklich etwas offen ist:

- **AT-56, Übergangsfenster 2027:** Fälligkeit Jänner: `closes` 2027-05-18 (Z3–5-Gruppe). Februar
  bis Juli: −1/+4 nach alter Fassung (spätestens 2027-11-30). August bis Oktober: `closes`
  2027-11-30 für alle Kategorien. Ab November 2027: −4/0. Keine Hinweise (D-01, D-07).
- **AT-40/42/43, Fensterbeginn:** Die Z3–5-Gruppe (Pkw, L, O1/O2, historisch) öffnet in der
  alten Fassung am Beginn des Vormonats, die Z1–2-Gruppe (N1, Taxi) drei Monate vorher; ab dem
  Stichtag gilt für alle vier Monate vor D. `opens` ist der früheste gültige Kandidat (§ 9.3).
  Keine Hinweise (D-02, D-03, D-04).
- **AT-53/54, Schritt nach einer Begutachtung:** Neue Fassung: `ageAtD < 4`: 4 − `ageAtD`;
  `4 ≤ ageAtD < 10`: min(2, 10 − `ageAtD`); sonst 1 (D-05, Lesart A von AT-54a). Hinweis
  `AT-54a openLegalQuestion` nur bei `ageAtD` = 9.
- **AT-53, Austauschplakette:** nur Hinweis, nie Fälligkeit, nur bei Pkw/L/O1/O2 und nur wenn
  der Kandidat nach der Plakette liegt. Letzte Begutachtung aus Eingabe oder abgeleitet (D-11,
  Hinweis `derivedLastInspection`); nie begutachtet: Erstzulassung + 4 Jahre ab Plakette 2027-02
  (D-06). Hinweis `AT-53 openLegalQuestion` bei jedem Vorschlag.
- **AT-12, Begutachtung außerhalb des Fensters (D-09, Entscheidung der koordinierenden Session
  nach ADR-8):** Das Gesetz regelt den Fall nicht, der Wert füllt nur die Plakettenauswahl vor.
  Die Engine liefert den **frühesten plausiblen** Fälligkeitsmonat (§ 9.2) und den Hinweis
  `outsideWindowRepunch`: „neue Lochung von der Plakette eintragen“.
- **AT-23/24/25:** Intervalle sind primär belegt, keine Hinweise (D-08). Historische Fahrzeuge
  haben ein festes Intervall von 2 Jahren ab dem Fälligkeitsmonat (D-10).
- **AT-26:** Schwere Fahrzeuge, Zugmaschinen und Ähnliches (`other`) unterstützt die Engine
  nicht. Sie meldet `unsupportedCategory`.

## 7. Weitere Fristen (für Erinnerungen, nicht Teil der Pickerl-Engine)

| ID | Regel (bisherige Formulierung) | Status | Fundstelle | Befund |
|---|---|---|---|---|
| AT-70 | Jahresvignette: gilt vom 1. Dezember des Vorjahres bis 31. Jänner des Folgejahres (Vignette 2027: 01.12.2026 bis 31.01.2028). Ab 2027 gibt es nur noch die digitale Vignette. | PRIMÄR | BStMG § 11 Abs. 1 Satz 1; § 11 Abs. 2 Satz 2 | bestätigt mit Präzisierung: Nur digital sind alle Jahres-, Zweimonats-, Zehntages- und Eintagesvignetten, „die ab dem 1. Dezember 2026 zur Benützung der Mautstrecken berechtigen“. Die Jahresvignette 2027 ist damit schon ab 01.12.2026 nur digital. |
| AT-71 | Digitale Jahres- und 2-Monats-Vignette, online von Verbrauchern gekauft: gültig erst ab dem 18. Tag nach dem Kauf (Rücktrittsrecht). | SEKUNDÄR | BStMG § 15 Abs. 2 Z 8 (Ermächtigung) | Das Gesetz erlaubt der Mautordnung nur, für den Erwerb „im Fernabsatz“ (außer Eintagesvignette) den ersten Gültigkeitstag frühestens auf den **achtzehnten Tag nach dem Erwerb** zu legen. Die konkrete Regel (wer, welche Vignetten) steht in der ASFINAG-Mautordnung, die nicht geprüft wurde. Achtung: Das Gesetz nennt auch die **Zehntagesvignette** nicht als Ausnahme. |
| AT-72 | Winterreifen: situative Pflicht vom 1. November bis 15. April für M1 und N1 bei winterlichen Fahrbahnverhältnissen (§ 102 Abs. 8a KFG, Absatz nicht primär geprüft). | PRIMÄR | § 102 Abs. 8a, Schlussteil („Weiters darf der Lenker …“) i. V. m. Z 1 | bestätigt. Erfasst sind auch vierrädrige Leichtkraftfahrzeuge mit geschlossenem, kabinenartigem Aufbau. Statt Winterreifen auf allen Rädern genügen Schneeketten auf mindestens zwei Antriebsrädern, wenn die Fahrbahn mit einer zusammenhängenden Schnee- oder Eisschicht bedeckt ist. |

## 8. Offene Punkte (Checkliste für die Primärquellen-Prüfung)

- [x] AT-02/03: Inkrafttretensbestimmung wörtlich (§ 135 Abs. 51 Z 2) und genaue Zeitpunkte
- [x] AT-10/11: Norm für den Bezugsmonat (§ 57a Abs. 3 Satz 1 und 2)
- [ ] AT-12: Wirkung einer verspäteten Begutachtung auf die Lochung — gesetzlich nicht geregelt, bleibt OFFEN
- [x] AT-23/24/25/26: Intervalle für N1, Taxi, historische und schwere Fahrzeuge primär bestätigt
- [x] AT-30/31/33: Wortlaut § 57a Abs. 3 neu, Aufzählung der Klassen, Schema 4-2-2-2-1 (AT-31 korrigiert)
- [x] AT-40/41/42/43: Wortlaut der Fenster alt und neu, Geltungsbereich des −4/0-Fensters (alle Fahrzeuge)
- [x] AT-52/53/54: Wortlaut § 132 Abs. 37 Z 1 bis 5; offen bleibt nur die Wortbedeutung „im zehnten Jahr“ (AT-54a)
- [x] AT-56: Übergangsfenster 2027
- [ ] AT-57: PBStV-Novelle(n) zur Umsetzung — keine gefunden, weiter beobachten
- [ ] AT-45: spätester Tag nach neuer Fassung (Monatsende oder Jahrestag)
- [ ] AT-44: Stenographisches Protokoll der 85. NR-Sitzung prüfen (nur der Vollständigkeit halber)
- [x] Erläuterungen (Begründung des Abänderungsantrags im Ausschussbericht 581 d.B.) auf Beispiele geprüft, siehe § 11
- [x] ÖAMTC-Pickerlrechner mit unseren Testfällen gegengeprüft, siehe § 12
- [x] Engine an § 10 anpassen (Regelversion `AT-2026-10-primary`; Reihenfolge Doc, Test, Code)

## 9. Algorithmus der Engine

Implementierung: `Packages/PitlogCore/Sources/PitlogCore/Rules/Austria/`. Regelversion
`AT-2026-10-primary`, Stichtag `cutoffDay = 2027-05-19` (AT-02). Die Engine rechnet in
Kalendermonaten (`YearMonth`) und Tagen (`DayDate`) mit reiner Ganzzahlarithmetik, `today`
wird injiziert. Notation: **D** = gelochter Fälligkeitsmonat. **Alter bei D** (`ageAtD`) =
`floor(Monate von der Erstzulassung bis D / 12)`. **Geltendes Recht an einem Tag T:** alte
Fassung, wenn T vor dem Stichtag liegt, sonst neue Fassung. Der Algorithmus folgt den
Primärquellen (Stand 04.10.2026); die Entscheidungen dazu stehen in § 10.

### 9.1 Kategoriegruppen und Intervalle

Gruppen nach § 57a Abs. 3 Z 1 bis 5. Sie bestimmen nur das **Fenster** (§ 9.3):

| Gruppe | Kategorien | Grundlage |
|---|---|---|
| **Z3–5-Gruppe** | `passengerCar`, `motorcycle`, `lightTrailer`, `historic` | § 57a Abs. 3 Satz 3 aF: −1/+4 für „Z 3 bis Z 5“ (AT-40); Z 4 = historische Fahrzeuge |
| **Z1–2-Gruppe** | `lightCommercial`, `taxiOrAmbulance` | § 57a Abs. 3 Satz 3 aF: −3/0 für „Z 1 und Z 2“ (AT-42) |

Die **Intervalle** hängen von der Kategorie ab. Schritt = Anzahl Jahre von D bis zur nächsten
Fälligkeit:

| Kategorie | Alte Fassung | Neue Fassung | Regel |
|---|---|---|---|
| Pkw, Klasse L, Anhänger O1/O2 | Folge 3, 5, 6, 7, 8, …: kleinstes Folgenelement größer als `ageAtD`, ab Alter 6 jährlich | `ageAtD < 4`: 4 − `ageAtD`; `4 ≤ ageAtD < 10`: min(2, 10 − `ageAtD`); `ageAtD ≥ 10`: 1 | AT-20/21/22, AT-30, AT-53/54 (D-05) |
| N1 | jährlich | jährlich | AT-23 |
| Taxi, Rettung, Krankentransport | jährlich | jährlich | AT-24 |
| Historisch | fest 2 Jahre ab D | fest 2 Jahre ab D | AT-25 |
| Sonstige (`other`) | nicht unterstützt | nicht unterstützt | AT-26 |

Die Schrittfunktion der neuen Fassung deckt reguläre Neufahrzeuge (Alter 0, 4, 6, 8, 10, 11, …)
und Übergangsfahrzeuge nach § 132 Abs. 37 Z 1 Satz 4/5 ab (Lesart A von AT-54a: Grenze ist das
10. Lebensjahr, danach jährlich).

### 9.2 Nächste Fälligkeit (`nextDue`) nach einer Begutachtung am Tag T

- **T liegt im Fenster von D:** Ergebnis = D plus Schritt(`ageAtD`) Jahre nach dem Recht an T
  (§ 9.1). Historische Fahrzeuge: immer D + 2 Jahre. Hinweis `AT-54a openLegalQuestion` nur,
  wenn die neue Fassung gilt, die Kategorie Pkw/L/O1/O2 ist und `ageAtD` = 9 (Schritt 1 bis
  Alter 10, Lesart A). Sonst keine Hinweise.
- **T liegt außerhalb des Fensters (AT-12, D-09):** Das Gesetz regelt die verspätete oder zu
  frühe Begutachtung nicht. Die Engine liefert den **frühesten plausiblen** Fälligkeitsmonat; er
  füllt nur die Plakettenauswahl vor, der Nutzer trägt die tatsächliche Lochung ein.
  - Neue Fassung an T: D + 1 Jahr.
  - Alte Fassung an T: min(`Monat(T)` + Schritt(`Alter bei Monat(T)`), D + Schritt(`ageAtD`)),
    beide Schritte nach der alten Fassung.

  Hinweis `AT-12 outsideWindowRepunch` („neue Lochung von der Plakette eintragen“). Kein
  AT-54a-Hinweis, weil das Ergebnis nicht vom Schritt bis Alter 10 abhängt.

### 9.3 Fenster für den Fälligkeitsmonat D

`closes` nach D, für alle unterstützten Kategorien:

| D | Z3–5-Gruppe | Z1–2-Gruppe | Regime |
|---|---|---|---|
| bis 2026-12 | letzter Tag von D+4 | letzter Tag von D | alte Fassung |
| 2027-01 | 2027-05-18 | letzter Tag von D | Übergang |
| 2027-02 bis 2027-07 | letzter Tag von D+4 | letzter Tag von D | Übergang |
| 2027-08 bis 2027-10 | 2027-11-30 | 2027-11-30 | Übergang |
| ab 2027-11 | letzter Tag von D | letzter Tag von D | neue Fassung |

`opens` ist der früheste gültige Kandidat von:

- **alter Kandidat:** Z3–5-Gruppe: erster Tag von D−1 Monat; Z1–2-Gruppe: erster Tag von D−3
  Monate. Gültig nur, wenn er vor dem Stichtag liegt.
- **neuer Kandidat:** das spätere von „erster Tag von D−4 Monate“ und Stichtag. Gültig nur,
  wenn er nicht nach `closes` liegt.

Beispiele: Pkw D = 2027-08 → 2027-05-19; Pkw D = 2027-06 → 2027-05-01; Pkw D = 2028-01 →
2027-09-01; N1 D = 2028-02 → 2027-10-01; N1 D = 2027-08 → **2027-05-01** (alter Kandidat D−3,
gültig, weil vor dem Stichtag; der ÖAMTC-Rechner nennt 2027-05-19, siehe D-03 und § 12, X2).
Es gibt keine Fensterhinweise mehr (AT-42, AT-43, AT-56 entfallen, D-07/D-08).

### 9.4 Phase relativ zu heute

heute vor `opens`: `notYetOpen`. Heute nach `closes`: `overdue`. Monat von `closes` ist der
heutige Monat: `closesThisMonth`. Sonst `open`.

### 9.5 Status (`status(for:today:)`)

- **Mit Plakette:** D = Plakette, Quelle `plaque` (AT-51, ADR-5).
- **Ohne Plakette (Schätzung, Hinweis AT-10 `checkPlaque`):** Erste Fälligkeit nach dem Recht
  bei der Erstzulassung (Erstzulassung bis Mai 2027 zählt als alte Fassung, Mai 2027
  konservativ ebenfalls) plus erstes Folgenelement. Danach wird wiederholt der Schritt (§ 9.1)
  mit dem Recht am ersten Tag von D angewendet, bis das `closes` des Fensters nicht vor heute
  liegt.
- **Austauschplakette (AT-52/53, D-06, D-11):** nur Pkw/L/O1/O2 und nur mit Quelle `plaque`.
  Zuerst wird die letzte Begutachtung L bestimmt:
  1. `lastInspection` gesetzt: L = diese. Voraussetzung `L < 2027-05-19`, sonst kein Vorschlag.
  2. Sonst, wenn Plakette P > Erstzulassung + 3 Jahre: L aus der alten Folge ableiten (D-11):
     Alter bei P = 5 → L = P − 2 Jahre; Alter bei P ≥ 6 → L = P − 1 Jahr; sonst keine
     Ableitung. Voraussetzung `L < 2027-05`. Zusätzlicher Hinweis `AT-53 derivedLastInspection`.

  Existiert L: Alter bei L ≤ 8 → Kandidat = Monat(L) + 2 Jahre; Alter bei L ≥ 9 → kein Kandidat.
  Existiert kein L (nie begutachtet: P ≤ Erstzulassung + 3 Jahre) und P ≥ 2027-02: Kandidat =
  Erstzulassung + 4 Jahre. Angezeigt wird der Kandidat nur, wenn er nach P liegt, mit Hinweis
  `AT-53 openLegalQuestion` (immer bei einem Vorschlag). Die App zeigt ihn nur als **Hinweis**,
  nie als Fälligkeit, „unverbindlich, bei der Prüfstelle klären“.
- Hinweise werden dedupliziert und nach Regel-ID sortiert.
- Eingaben mit Plakette oder letzter Begutachtung vor der Erstzulassung sind ungültig
  (`invalidInput`).

### 9.6 Ankerfälle (als Tests umgesetzt, `AustriaAnchorTests`)

| # | Eingabe | heute | Erwartet |
|---|---|---|---|
| 1 | Pkw, EZ 2020-03, Plakette 2027-03 | 2027-02-15 | opens 2027-02-01, closes 2027-07-31, Übergang, open; Austauschvorschlag 2028-03 (abgeleitete letzte Begutachtung), Hinweise AT-53 `openLegalQuestion` und `derivedLastInspection` |
| 2 | wie 1 | – | nextDue(nach 2027-03-10) = 2028-03 (alt, Alter 7 → 8); nextDue(nach 2027-06-10) = 2029-03 (neu, Alter 7, Schritt 2), keine Hinweise |
| 3 | Pkw, EZ 2024-06, Plakette 2027-06, nie begutachtet | 2027-04-01 | opens 2027-05-01, closes 2027-10-31, notYetOpen, Austauschvorschlag 2028-06, Hinweis AT-53 |
| 4 | Pkw, EZ 2021-04, letzte Begutachtung 2026-04-12, Plakette 2027-04 | – | Austauschvorschlag 2028-04 (ÖAMTC-Beispiel); nextDue(nach 2027-04-05) = 2028-04; nextDue(nach 2027-06-01) = 2029-04 |
| 5 | Pkw, EZ 2023-09, letzte Begutachtung 2026-09-20, Plakette 2028-09 | 2028-06-01 | opens 2028-05-01, closes 2028-09-30, neue Fassung, open, kein Austauschvorschlag |
| 6 | Pkw, EZ 2028-03, keine Plakette | 2028-04-01 | geschätzt 2032-03, AT-10 |
| 7 | Pkw, EZ 2015-07, Plakette 2027-08 | 2027-09-01 | closes **2027-11-30**, Phase **open**, keine Hinweise |
| 8 | Motorrad, EZ 2019-05, Plakette 2027-05 | – | closes 2027-09-30; nextDue(nach 2027-05-10) = 2028-05; nextDue(nach 2027-05-25) = 2029-05 |
| 9 | Leichtanhänger, EZ 2025-10, nie begutachtet, Plakette 2028-10 | – | opens 2028-06-01, closes 2028-10-31, Austauschvorschlag 2029-10 |
| 10 | N1, EZ 2026-02, Plakette 2027-02 | – | opens **2026-11-01**, closes 2027-02-28, keine Hinweise; nextDue(nach 2027-02-10) = 2028-02 |
| 11 | historisch, EZ 1976-04, Plakette 2028-04 | – | opens **2027-12-01**, closes 2028-04-30, keine Hinweise, nextDue +2 Jahre |
| 12 | Kategorie `other` | – | wirft `unsupportedCategory(.other)` |
| 13 | Pkw, EZ 2022-01, Plakette 2027-01 | – | closes 2027-05-18, **keine Hinweise** |
| 14 | Pkw, EZ 2010-03, Plakette 2028-03 | – | nextDue(nach 2028-03-15) = 2029-03 (Alter 18, jährlich) |
| 15 | Pkw, EZ 2020-06, Plakette 2027-06 | – | nextDue(nach 2027-12-01): außerhalb des Fensters (closes 2027-10-31), neue Fassung → D + 1 Jahr = **2028-06**, Hinweis AT-12 |

Bei 11 und 15 war die Erstzulassung in der Vorgabe nicht genannt; gewählt wurden Werte, die
zur Plakette passen.

### 9.7 Auffälligkeiten

- **Schätzung ohne Plakette:** Ein Fahrzeug mit Erstzulassung 2024-06 wird als fällig 2027-06
  geschätzt (alte Fassung bei Erstzulassung), obwohl die neue Fassung 2028-06 ergäbe
  (Austauschplakette, AT-52). Das ist gewollt konservativ, deshalb gilt die Plakette (ADR-5).
- **Historische Fahrzeuge außerhalb des Fensters:** Der Wert D + 1 Jahr (neue Fassung, § 9.2)
  gilt für alle Kategorien und liegt bei historischen Fahrzeugen unter dem Intervall von zwei
  Jahren. Er ist der früheste plausible Wert für die Vorbelegung, keine Fälligkeit.
- **X7 (ÖAMTC: keine Austauschplakette):** Plakette 2026-12, Erstzulassung 2019-12: Die Engine
  leitet die letzte Begutachtung 2025-12 ab und schlägt 2027-12 vor; der ÖAMTC-Rechner nicht
  (siehe § 12).

## 10. Abweichungen Engine vs. Gesetz

Stand 04.10.2026, geprüft gegen § 57a Abs. 3 aF/nF, § 132 Abs. 37 und § 135 Abs. 51 (Wortlaute in
`docs/sources/`). Die Spalten „Gesetz sagt“ und „Engine macht“ beschreiben den Stand der Engine
**vor** der Anpassung (`AT-2026-10-draft`); „Vorschlag“ ist das, was die Engine
`AT-2026-10-primary` umsetzt (§ 9). „früher“ hieß: Die Engine zeigte einen früheren spätesten
Termin als das Gesetz (konservativ, aber falsch). „später“ hieß: Die Engine zeigte einen
späteren Termin als das Gesetz (Haftungsrisiko).

Status: **done** = in Doc, Tests und Code umgesetzt; **decided** = Entscheidung getroffen, Gesetz
regelt den Fall nicht; **open** = Rechtsfrage offen.

| Nr | Regel-ID | Gesetz sagt | Engine macht | Vorschlag | Status |
|---|---|---|---|---|---|
| D-01 | AT-56 | § 132 Abs. 37 Z 3 Satz 2: Stichtag August bis Oktober 2027 → „Fristverlängerung bis inklusive November 2027“, spätester Tag **30.11.2027**. Gilt für **alle** Fahrzeuge, auch N, Taxi, historische. | § 9.3: `closes` = letzter Tag von D (2027-08-31 … 2027-10-31), Hinweis `possibleExtension(until: 2027-11-30)`. Für N1/Taxi/historisch ebenfalls letzter Tag von D. **früher** (um 1 bis 3 Monate). | `closes` = 2027-11-30 für D = 2027-08 bis 2027-10, alle unterstützten Kategorien. Hinweis entfällt. Ankerfall 7 ändert sich: heute 2027-09-01 → `open` statt `overdue`. | done |
| D-02 | AT-43, AT-41 | § 57a Abs. 3 Satz 3 nF: −4/0 für **alle** Fahrzeuge (Materialien: „für alle Fahrzeuge“). | § 9.3: N1, Taxi/Rettung, historisch: `opens` = erster Tag des Vormonats (−1/0). Engine öffnet **3 Monate zu spät**; eine Begutachtung in D−4 bis D−2 wird als „außerhalb des Fensters“ behandelt und löst AT-12 (`outsideWindowRepunch`) aus, obwohl sie „ohne Wirkung“ ist. | Für diese Kategorien dieselbe `opens`-Logik wie für Pkw (−4, frühestens 19.05.2027). Hinweis AT-43 entfällt. | done |
| D-03 | AT-42 | § 57a Abs. 3 Satz 3 aF, erster Fall: Z 1 und Z 2 (N, Taxi, Rettung, Krankentransport) → „drei Monate vor dem vorgesehenen Begutachtungsmonat“ (−3/0). Über § 132 Abs. 37 Z 3 Satz 1 gilt das für Stichtag Februar bis Juli 2027 weiter. | `opens` = erster Tag des Vormonats (−1/0). Folge wie D-02. `closes` stimmt (letzter Tag von D). | Alte Fassung für N1/Taxi: `opens` = erster Tag von D−3. Für D = 2027-08: alter Kandidat 2027-05-01 liegt vor dem Stichtag und ist an diesem Tag gültig (−3); der ÖAMTC nennt dagegen 2027-05-19 (siehe § 12). | done (Abweichung vom ÖAMTC bei N1/N, Fälligkeit 2027-08, bewusst: Gesetzestext, siehe § 12, X2) |
| D-04 | AT-40, AT-25 | § 57a Abs. 3 Satz 3 aF, zweiter Fall: −1/+4 gilt für „Z 3 bis Z 5“, also auch für **historische Fahrzeuge (Z 4)**. Über § 132 Abs. 37 Z 3 Satz 1 auch für Stichtag Februar bis Juli 2027. | Historische Fahrzeuge: `closes` = letzter Tag von D, auch nach alter Fassung. **früher** (um 4 Monate bis 2027-07, z. B. D = 2027-03: Engine 2027-03-31, Gesetz 2027-07-31). | Historische Fahrzeuge in der alten Fassung und im Übergang wie Pkw/L/O behandeln (Tabelle § 9.3 oben). Ab Stichtag November 2027 −4/0 wie alle. | done |
| D-05 | AT-54, AT-53 | § 132 Abs. 37 Z 1 Satz 4 und 5: Für Fahrzeuge, die schon nach altem Recht begutachtet wurden, folgt nach der Austauschplakette **und** nach einer Begutachtung zum alten gelochten Termin (ab 19.05.2027) jede weitere Begutachtung **2 Jahre nach der letzten**, spätestens im zehnten Jahr nach der Erstzulassung, danach jährlich. Materialien: „zweijähriges Intervall und ab zehn Jahren einjährig“. | § 9.2: altersbasiert, nächstes Folgenelement aus 4, 6, 8, 10, 11, … größer als das Alter bei D. Bei ungeradem Alter bei D (5, 7, 9 aus der alten 3-2-1-Folge) ergibt das +1 statt +2. **früher** um 1 Jahr. Beispiele: Ankerfall 2 (`nextDue` nach 2027-06-10): Engine 2028-03, Gesetz 2029-03. ÖAMTC-Beispiel EZ 2021, Austauschplakette 2028: Engine danach 2029, Gesetz 2030. | Für Übergangsfahrzeuge (EZ vor 19.05.2027, mindestens eine Begutachtung nach altem Recht), Pkw/L/O, Recht an T = neue Fassung: `nextDue` = D + min(2, 10 − Alter bei D) Jahre, bei Alter bei D ≥ 10: D + 1 Jahr. Alle anderen Fälle wie bisher. Hinweis AT-54 nur noch für die Lesartfrage AT-54a (Alter 9/10). Wie sich der Monat verhält, wenn innerhalb des Fensters, aber nicht im gelochten Monat begutachtet wird, ist im Gesetz nicht gesagt („zwei Jahre nach dieser Begutachtung“); konservativ D + 2, nicht Begutachtungsmonat + 2. | done (Lesart A; AT-54a bleibt open, Hinweis bei Alter bei D = 9) |
| D-06 | AT-53 | § 132 Abs. 37 Z 1 Satz 3: Austauschplakette mit erster Begutachtung 4 Jahre nach EZ für **jedes** Fahrzeug, das „bislang noch keine erste Begutachtung absolviert“ hat (und für das ab 19.05.2027 eine längere Frist gilt). | § 9.5: nur, wenn EZ + 3 Jahre nicht vor 2027-05 liegt. Fahrzeuge mit erster Fälligkeit Februar bis April 2027, die wegen der Übergangsnachfrist (bis Juni bis August 2027) noch nicht begutachtet sind, bekommen **keinen** Vorschlag. Beispiel EZ 2024-03, Plakette 2027-03: ÖAMTC und Gesetz → Austausch 2028-03, Engine → keiner. Keine Fristverkürzung, nur ein fehlender Hinweis. | Bedingung ersetzen: „noch nie begutachtet und D ≥ 2027-02“ (bei D = 2027-01 endet die Frist am 18.05.2027, vor Inkrafttreten der Austauschplakette). | done |
| D-07 | AT-56 | § 132 Abs. 37 Z 3 erfasst Jänner 2027 **nicht**; die Nachfrist aF endet mit 18.05.2027. Für Februar bis Juli ist −1/+4 ausdrücklich angeordnet. | Jänner: Hinweis `possibleExtension(until: 2027-05-31)`; Februar bis Juli: Hinweis `openLegalQuestion`. Termine selbst stimmen. | Beide Hinweise streichen (Jänner: Verlängerung ist durch den Wortlaut nicht gedeckt; die App sollte sie nicht in Aussicht stellen). | done |
| D-08 | AT-23, AT-24, AT-25 | Intervalle sind primär belegt (§ 57a Abs. 3 Z 1 und Z 4). | Hinweis `openLegalQuestion` für N1, Taxi, historisch. Termine stimmen (jährlich bzw. alle 2 Jahre, siehe aber D-10). | Hinweise streichen. | done |
| D-09 | AT-12 | Gesetz regelt die verspätete Begutachtung nicht (siehe AT-12, Lesarten A/B). Seit 19.05.2027 gibt es keine Nachfrist mehr; eine Begutachtung außerhalb des Fensters ist eine verspätete. | § 9.2: neue Fälligkeit ab dem **Begutachtungsmonat** (Lesart A). Das ist die Lesart mit dem **späteren** Termin und widerspricht ADR-8. Beispiel Ankerfall 15 (EZ 2020-06, Plakette 2027-06, Begutachtung 2027-12-01): Engine 2028-12; Lesart B mit der Zählweise des § 57a Abs. 3 Z 3 nF (vierte Begutachtung → ein Jahr) 2028-06. **später** (möglich). | Keine Gesetzesabweichung im engeren Sinn, aber gegen ADR-8: entweder Lesart B (Bezugsmonat bleibt) rechnen oder nur noch `outsideWindowRepunch` ausgeben und keinen Termin berechnen, bis die neue Lochung eingetragen ist. Vor M2 entscheiden. | decided (D-09: earliest plausible, prefill only) |
| D-10 | AT-25 | § 57a Abs. 3 Z 4: „alle zwei Jahre“ (Intervall). | § 9.1/9.2: Folge 2, 4, 6, … nach Alter; liegt D bei ungeradem Alter (z. B. nach AT-11), ergibt sich +1 statt +2. **früher** um 1 Jahr. Schon in § 9.7 als Zweifel notiert. | `nextDue` = D + 2 Jahre für historische Fahrzeuge. **Erledigt** mit Commit 8a2029e (Review-Fix M1). | done |
| D-11 | AT-53 (Eingabemodell, keine Gesetzesabweichung) | Ob eine Austauschplakette möglich ist, hängt von der letzten Begutachtung ab (§ 132 Abs. 37 Z 1). | § 9.5: Ohne eingetragene letzte Begutachtung schlägt die Engine nur bei nie begutachteten Fahrzeugen etwas vor. Der ÖAMTC leitet die letzte Begutachtung aus Erstzulassung und Plakette ab (Ankerfälle 1, 8, 15: Austausch 2028-03, 2028-05, 2028-06). | Optional: Ist keine letzte Begutachtung eingetragen, aber die Plakette liegt nach EZ + 3 Jahren, letzte Begutachtung = Plakette − 1 Jahr bzw. − 2 Jahre (nach alter Folge) annehmen und den Vorschlag als Schätzung kennzeichnen. Produktentscheidung. | done (letzte Begutachtung abgeleitet, Hinweis `derivedLastInspection`) |

Offene Rechtsfragen ohne D-Nummer (die Engine wendet die Annahme an, siehe ADR-8):

| Regel-ID | Frage | Status |
|---|---|---|
| AT-45 | Spätester Tag des Fensters nach neuer Fassung: Monatsende (Engine) oder Jahrestag | open |
| AT-54a | Bedeutung „spätestens im zehnten Jahr nach der Erstzulassung“ (Engine: Lesart A, Alter 10) | open |
| AT-57 | Folgeregelungen in der PBStV zur Plakettenlochung und Austauschplakette | open |

Keine Abweichung gefunden bei: Pkw/L/O-Fenster bis 2026-12 (−1/+4), Jänner 2027 (`closes`
2027-05-18), Februar bis Juli 2027 (−1/+4, spätestens 30.11.2027), ab November 2027 (−4/0, frühestens
19.05.2027), Intervallfolgen alt (3, 5, 6, 7, …) und neu bei regulärem Verlauf (4, 6, 8, 10, 11, …),
Austauschvorschlag für begutachtete Fahrzeuge mit Alter bei der letzten Begutachtung höchstens 8
(entspricht der Grenze des zehnten Jahres nach Lesart A), Austauschvorschlag nur, wenn später als
die Plakette (§ 132 Abs. 37 Z 1: „längere Frist“), Plakette ist führend (§ 132 Abs. 37 Z 2).

## 11. Beispiele aus den Materialien

Die Erläuterungen (Begründung des Abänderungsantrags im Ausschussbericht 581 d.B., Wortlaut in
`docs/sources/Materialien_AB581_Auszug.md`) enthalten nur **ein** Zahlenbeispiel (M-01). Die
übrigen Fälle setzen die dort beschriebenen Regeln mit von uns gewählten Werten um; sie sind als
„abgeleitet“ markiert. Spalte „Engine M1“: Ergebnis der Engine `AT-2026-10-draft`, von Hand gerechnet. Seit `AT-2026-10-primary` liefert die Engine in allen Zeilen das „Erwartete Ergebnis“ (Tests `AustriaMaterialienTests`).

| Nr | Fundstelle | Aussage der Materialien | Eingabe | Erwartetes Ergebnis | Engine M1 |
|---|---|---|---|---|---|
| M-01 | Q-AB581, zu Z 42, Absatz „Um Härtefälle …“ | Stichtag Juni: Ohne Übergangsregel blieben statt sechs Monaten nur zwei Monate; deshalb gilt die alte Frist weiter. | Pkw, Plakette 2027-06 | `opens` 2027-05-01, `closes` 2027-10-31 (sechs Monate Mai bis Oktober) | ✓ (Ankerfall 3) |
| M-02 | Q-AB581, zu Z 42; § 132 Abs. 37 Z 1 Satz 3 | War die erste Begutachtung noch nicht fällig: erste Begutachtung 4 Jahre nach EZ. (abgeleitet) | Pkw, EZ 2024-06, nie begutachtet, Plakette 2027-06 | Austauschplakette 2028-06 | ✓ (Ankerfall 3) |
| M-03 | Q-AB581, zu Z 42; § 132 Abs. 37 Z 1 Satz 4 | Nach Begutachtung(en) nach altem Recht: ein-, zwei- oder dreimal Zweijahresabstand, jedenfalls im zehnten Jahr und danach jährlich. (abgeleitet) | Pkw, EZ 2021-04, Begutachtungen 2024-04 und 2026-04, Plakette 2027-04 | Austauschplakette 2028-04; danach 2030-04, 2031-04 (Alter 10), dann jährlich | Austausch ✓; danach ✗ 2029-04 (D-05) |
| M-04 | Q-AB581, zu Z 42 | Abstand zwischen erster und zweiter Begutachtung höchstens zwei Jahre. (abgeleitet) | Pkw, EZ 2023-09, erste Begutachtung 2026-09, Plakette 2028-09 | keine Austauschplakette (Plakette ist schon 2 Jahre nach der ersten) | ✓ (Ankerfall 5) |
| M-05 | § 132 Abs. 37 Z 1 Satz 4; AT-54a Lesart A | Grenze zehntes Jahr. (abgeleitet) | Pkw, EZ 2018-09, letzte Begutachtung 2026-09 (Alter 8), Plakette 2027-09 | Austauschplakette 2028-09 (Alter 10), danach 2029-09 | ✓ Austausch; danach ✓ (Alter 10 → 11) |
| M-06 | § 132 Abs. 37 Z 1 Satz 4 | Grenze zehntes Jahr. (abgeleitet) | Pkw, EZ 2017-05, letzte Begutachtung 2026-05 (Alter 9), Plakette 2027-05 | keine Austauschplakette | ✓ |
| M-07 | Q-AB581, zu Z 42; § 132 Abs. 37 Z 1 Satz 5 | Begutachtung trotzdem zum alten gelochten Termin: nächste nach neuer Regel, zweijährig, ab zehn Jahren einjährig. (abgeleitet) | Pkw, EZ 2020-03, Plakette 2027-03, Begutachtung 2027-06-10 | `nextDue` 2029-03 (Alter 9); danach 2030-03 (Alter 10) | ✗ 2028-03 (D-05, Ankerfall 2) |
| M-08 | wie M-07 | wie M-07, Alter bei D = 10. (abgeleitet) | Pkw, EZ 2017-06, Plakette 2027-06, Begutachtung 2027-06-10 | `nextDue` 2028-06 | ✓ |
| M-09 | Q-AB581, zu Z 42, Absatz „Weiters wird klargestellt …“; § 132 Abs. 37 Z 2 | Ohne Begutachtung oder Austausch gilt die alte Lochung; danach Übertretung nach § 36 lit. e. (abgeleitet) | Pkw, EZ 2021-04, Plakette 2027-04, keine Austauschplakette, heute 2027-09-01 | `overdue` (`closes` 2027-08-31), obwohl neues Recht 2028-04 ergäbe | ✓ |
| M-10 | Q-AB581, zu Z 14 und 15 | Toleranzzeitraum „für alle Fahrzeuge“ vier Monate vor dem Begutachtungsmonat. (abgeleitet) | N1, Plakette 2028-02 | `opens` 2027-10-01, `closes` 2028-02-29 | ✗ `opens` 2028-01-01 (D-02) |
| M-11 | § 132 Abs. 37 Z 3 Satz 2 (Gesetzestext, nicht Materialien) | Stichtag August bis Oktober: Verlängerung bis inklusive November 2027. | Pkw, EZ 2015-07, Plakette 2027-08, heute 2027-09-01 | `opens` 2027-05-19, `closes` 2027-11-30, `open` | ✗ `closes` 2027-08-31, `overdue` (D-01, Ankerfall 7) |
| M-12 | § 57a Abs. 3 Satz 3 aF i. V. m. § 132 Abs. 37 Z 3 Satz 1 (Gesetzestext) | Historische Fahrzeuge: −1/+4 bis Stichtag Juli 2027. | historisch, EZ 1985-03, Plakette 2027-03 | `opens` 2027-02-01, `closes` 2027-07-31 | ✗ `closes` 2027-03-31 (D-04) |

## 12. Abgleich mit dem ÖAMTC-Pickerlrechner

Abfrage am 04.10.2026 über die Schnittstelle des Rechners (Version 1.0.0). Alle Eingaben und
Antworten stehen in `docs/sources/OEAMTC_Pickerlrechner_2026-10-04.md`. Der Rechner kennt kein
„heute“ und kein Datum der letzten Begutachtung; Phase (`open`, `overdue` …) und `nextDue` lassen
sich daher nicht vergleichen. Die Ankerfälle 2 und 12 sind nicht abfragbar.

| Fall | Engine (§ 9.6 bzw. nach § 9 gerechnet) | ÖAMTC | Abgleich |
|---|---|---|---|
| 1 | Fenster 2027-02-01 bis 2027-07-31; kein Austauschvorschlag (keine letzte Begutachtung eingetragen) | Fenster gleich; Austausch 2028-03 („Sonderfall“: Ausgabe im laufenden Toleranzzeitraum) | Fenster ✓; Austausch: Eingabemodell (D-11) |
| 3 | 2027-05-01 bis 2027-10-31; Austausch 2028-06 | gleich; Austausch 2028-06 | ✓ |
| 4 | 2027-03-01 bis 2027-08-31; Austausch 2028-04 | gleich; Austausch 2028-04 | ✓ |
| 5 | 2028-05-01 bis 2028-09-30; kein Austausch | gleich | ✓ |
| 6 | geschätzt 2032-03 | fällig 2032-03, Fenster 2031-11-01 bis 2032-03-31 | ✓ |
| 7 | 2027-05-19 bis **2027-08-31** | 2027-05-19 bis **2027-11-30** | ✗ D-01; ÖAMTC entspricht dem Gesetz |
| 8 | 2027-04-01 bis 2027-09-30; kein Austauschvorschlag | gleich; Austausch 2028-05 | Fenster ✓; Austausch: D-11 |
| 9 | 2028-06-01 bis 2028-10-31; Austausch 2029-10 | gleich | ✓ |
| 10 (N1) | **2027-01-01** bis 2027-02-28 | **2026-11-01** bis 2027-02-28 | ✗ D-03; ÖAMTC entspricht dem Gesetz (−3/0 aF) |
| 11 (historisch) | **2028-03-01** bis 2028-04-30 | **2027-12-01** bis 2028-04-30 | ✗ D-02 |
| 13 | 2026-12-01 bis 2027-05-18 | gleich | ✓ |
| 14 | 2027-11-01 bis 2028-03-31; kein Austausch | gleich | ✓ |
| 15 | 2027-05-01 bis 2027-10-31; kein Austauschvorschlag | gleich; Austausch 2028-06 | Fenster ✓; Austausch: D-11 |
| X1 Taxi, Plakette 2027-03 | **2027-02-01** bis 2027-03-31 | **2026-12-01** bis 2027-03-31 | ✗ D-03 |
| X2 N, Plakette 2027-08 | **2027-07-01** bis **2027-08-31** | **2027-05-19** bis **2027-11-30** | ✗ D-01, D-02. Beim Beginn weicht auch der ÖAMTC vom Gesetz ab: nach −3/0 aF wäre am 01.05.2027 schon begutachtbar (D-03). |
| X3 historisch, Plakette 2027-10 | **2027-09-01** bis **2027-10-31** | **2027-06-01** bis **2027-11-30** | ✗ D-01, D-02 |
| X4 historisch, Plakette 2027-03 | 2027-02-01 bis **2027-03-31** | 2027-02-01 bis **2027-07-31** | ✗ D-04 |
| X5 EZ 2018-09, Plakette 2027-09 | 2027-05-19 bis **2027-09-30**; mit letzter Begutachtung 2026-09: Austausch 2028-09 | 2027-05-19 bis **2027-11-30**; Austausch 2028-09 | Fenster ✗ D-01; Austausch ✓ (Lesart A von AT-54a) |
| X6 EZ 2017-05, Plakette 2027-05 | 2027-04-01 bis 2027-09-30; kein Austausch | gleich | ✓ |
| X7 Plakette 2026-12 | 2026-11-01 bis 2027-04-30 | gleich | ✓ |
| X8 N, Plakette 2027-11 | **2027-10-01** bis 2027-11-30 | **2027-07-01** bis 2027-11-30 | ✗ D-02 |
| X9 L, Plakette 2027-06 | 2027-05-01 bis 2027-10-31; Austausch nur mit eingetragener letzter Begutachtung | gleich; Austausch 2028-06 | Fenster ✓ |
| X10 EZ 2024-03, nie begutachtet, Plakette 2027-03 | 2027-02-01 bis 2027-07-31; **kein** Austauschvorschlag | gleich; Austausch **2028-03** | ✗ D-06 |
| X11 EZ 2024-01, Plakette 2027-01 | 2026-12-01 bis 2027-05-18; kein Austausch | gleich | ✓ |
| X12 EZ 2021-04, Plakette 2028-04, letzte Begutachtung 2027-04 | 2027-12-01 bis 2028-04-30; Austausch 2029-04 | gleich | ✓ |
| X13 EZ 2016-04, Plakette 2027-09 | 2027-05-19 bis **2027-09-30**; kein Austausch | 2027-05-19 bis **2027-11-30**; kein Austausch | ✗ D-01 |

**Ergebnis:** Der ÖAMTC-Rechner stimmt in allen geprüften Punkten mit unserer Lesart des
Gesetzes überein, mit einer Ausnahme beim Fensterbeginn für N im August 2027 (X2). Alle
Abweichungen der früheren Engine sind in § 10 erfasst und behoben (Tests `AustriaOeamtcTests`). Die Spalte „Engine“ zeigt den Stand `AT-2026-10-draft`. Verbleibende Unterschiede der Engine `AT-2026-10-primary`: X2 (`opens` 2027-05-01 statt 2027-05-19, D-03) und X7 (Engine schlägt eine Austauschplakette 2027-12 vor, ÖAMTC keine, siehe § 9.7). Eine Abweichung, bei der die Engine einen
**späteren** Termin zeigt als der ÖAMTC, wurde nicht gefunden.
