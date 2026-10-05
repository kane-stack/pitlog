# Holdout-Belege (M5b)

25 synthetische österreichische Werkstattbelege als **Holdout-Set** für den Belegparser. Das Set wurde
unabhängig vom Parser und von dessen eigenen Fixtures geschrieben (nur aus `docs/sources/receipts/README.md`
und `CLAUDE.md`). Es misst, wie gut der Parser auf unbekannte, unordentliche Belege verallgemeinert.
**Nicht zum Tunen des Parsers verwenden.**

Alle Namen, Adressen, UIDs (`ATU` + 8 Ziffern, ohne gültige Prüfziffer), FINs und Kennzeichen sind erfunden.
Prüfung von JSON, Formaten und Rechnung (Netto + 20 % = Brutto auf den Cent):
`python3 scripts/check_receipt_holdout.py`.

## Dateien

- `NN-name.txt`: Text, wie OCR ihn liefert (eine Zeile je visueller Zeile; Spalten teils zusammengezogen,
  teils getrennt; Beträge teils auf eigener Zeile; Zeilen teils vertauscht).
- `NN-name.expected.json`: erwartete Werte mit genau diesen Schlüsseln: `grossTotalMinor`, `currency`,
  `serviceDate`, `invoiceDate`, `historyDate`, `workshopName`, `workshopUID`, `odometerKm`, `plate`, `vin`, `category`.

## Konventionen der Sollwerte

- **E-1:** `grossTotalMinor` = Rechnungsbetrag brutto, nie der Restbetrag nach Anzahlung/Akonto.
- **E-2:** `serviceDate` nur bei ausdrücklichem Leistungs-/Lieferdatum, sonst `null`. `historyDate` = `serviceDate`, sonst `invoiceDate`.
- `null` heißt: fehlt oder mehrdeutig. Ein korrekter Parser muss dort `nil` liefern.
- **Kennzeichen** stehen kompakt (nur Großbuchstaben und Ziffern, z. B. `L48123K`). Die Belege schreiben
  sie als `L-48123K`, `L 48123 K`, `GU - 451AB` usw.: beim Vergleich Leerzeichen und Bindestriche entfernen.
- **Werkstattname:** Schreibweise wie gedruckt (Großschreibung der Bons ist normalisiert); Vergleich ohne Beachtung der Groß-/Kleinschreibung.
- **UID:** Sollwert ist die wahre UID; OCR-Fehler (`ATU 6O118342`) im Text sind Absicht.
- **Gutschrift (08):** `grossTotalMinor` ist **negativ** (-15816). Das ist eine Festlegung des Sets; der Koordinator kann sie ändern, falls Gutschriften anders behandelt werden sollen.
- Heutiges Datum im Set: 05.10.2026, kein Datum liegt danach.

## Verteilung

| Fehlerniveau | Anzahl | Belege |
|---|---|---|
| sauber | 8 | 01, 05, 07, 10, 13, 17, 24, 25 |
| mittel | 10 | 02, 04, 08, 09, 11, 14, 16, 18, 19, 22 |
| stark | 7 | 03, 06, 12, 15, 20, 21, 23 |

| Kategorie | Anzahl | Belege |
|---|---|---|
| inspection | 5 | 01, 10, 13, 18, 23 |
| service | 6 | 03, 05, 07, 09, 11, 22 |
| repair | 8 | 04, 06, 08, 14, 15, 16, 20, 25 |
| tyres | 4 | 02, 12, 19, 24 |
| otherWorkshop | 2 | 17, 21 |

Summe: 5 + 6 + 8 + 4 + 2 = 25.

## Layouts

Bons (01, 11, 20, 23, 24), A4-Rechnungen von Vertragswerkstätten/Autohäusern (03 zweiseitig, 04, 14, 22),
kleine freie Werkstätten (05, 07, 15, 16, 25), Reifenbetriebe (02, 12, 19, 24), Prüfstellen (01, 10, 13, 18, 23),
Händler mit Anzahlung/Akonto (04, 16), Gutschrift (08), Sammelrechnung für zwei Fahrzeuge (09), B2B (06).

## Fallen je Beleg

| Nr. | Fallen |
|---|---|
| 01 | Bon: Datum und Uhrzeit, Telefon/PLZ (4020), „davon 20 % USt 14,98“ ≠ Summe; Plakettenzeile; „Nächste Begutachtung 06/2028“ (nur Vorschlag, kein Leistungsdatum); kein Leistungsdatum, daher `serviceDate` null. |
| 02 | UID mit O statt 0; Betrag `129,0O`; Reifendimension 205/55 R16 91V, Lager-Nr. 20458, Profil 4,2 mm als Nicht-km; km nur als „Tachostand“; Beträge auf eigener Zeile; „inkl. USt 21,50“ ≠ Gesamt. |
| 03 | Zwei Seiten, Summe nur auf Seite 2; „Übertrag 551,10“ und Zwischensummen Lohn/Teile; `0` als `O` im Kopf und bei Beträgen (`87O,68`); Auftrags-Nr. 45120, Teilenummern, `5W-30 VW 504 00`; viele Daten (Auftrag, Annahme, Fertigstellung, Leistung, Rechnung, Fällig, Skonto bis, Erstzulassung 14.03.2019); „Nächster Service bei 75.000 km oder 09/2028“; IBAN/FN im Fuß; Kunde Privatperson. |
| 04 | Anzahlung 1.000,00 und „Noch zu zahlen 1.851,19“: erwartet ist der Bruttobetrag 2.851,19 (E-1); Rabatt 10 % auf Teile; Auftrag-, Anzahlungs-, Fertigstellungs-, Leistungs- und Rechnungsdatum; Kunde mit Adresse. |
| 05 | Kleinunternehmer ohne USt und UID, „Km: 143 200“ mit Leerzeichen, Telefonnummer, kurzer Text, kein Leistungsdatum. |
| 06 | Zwei UIDs: die Kunden-UID steht zuerst, die der Werkstatt nur im Fuß (erwartet); Kundenblock „Autohaus Mayrhofer …“ ist **nicht** die Werkstatt, die Werkstatt steht nur im Fuß; Schaden-Nr. 26/48200 und PLZ nahe an km; FIN mit `O`/`I` statt `0`/`1`; Beträge über 10.000 € als `15 841,5O` (Leerzeichen als Tausendertrenner); Schadens-, Auftrags-, Leistungs- und Rechnungsdatum. |
| 07 | „Jänner“, Betrag `€ 1.234,56` in der Kopfzeile, `1234,56 EUR` unten, Stundensatz `135,-`; Erstzulassung `02/2020`; „Nächstes Service 01/2027 oder 15.000 km“. |
| 08 | Gutschrift: Verweis „Rechnung vom 12.03.2026“ darf nicht als Datum gelten (`serviceDate` null, `invoiceDate` 22.04.2026); Beträge `-131,80` und `158,16-` (nachgestelltes Minus); erwartet negativer Betrag; keine km (null). |
| 09 | Zwei Kennzeichen, zwei km-Stände: `plate`, `odometerKm` und `vin` sind mehrdeutig, daher null; Kundenblock mit „Autohaus-Gasse“; Positionen mit Kennzeichen darin. |
| 10 | Kleinbetrag nur „EUR 89,90 inkl. 20% MwSt.“ (kein Netto, keine UID, daher UID null); Prüf-Nr. 220817 sieht aus wie Datum/km; Leistungsdatum (17.08.) ≠ Rechnungsdatum (18.08.); „Nächste Begutachtung 09/2027“. |
| 11 | Bon: „gegeben 100,00“ und „Rückgeld 12,20“ sind nicht der Gesamtbetrag; „Nächster Service bei 171.000 km“; Uhrzeit; Beträge auf eigener Zeile. |
| 12 | `UlD`, `H1NTERBERGER`, `O` statt `0` in Beträgen und im Datum, `E 697,2O` statt `€`; „Laufleistung Reifen lt. Hersteller 40.000 km“ (kein Fahrzeug-km) neben „Fzg.-Kilometerstand“; 205/55 R16, Telefon, PLZ. |
| 13 | Prüfstelle: „Plakette gelocht 06/2028“, „Vorherige Plakette 06/2026“, Erstzulassung 05/2016; Positionsbeträge 74,70 und 2,30 vor der Summe; Netto, USt und Gesamt. |
| 14 | Auftrags-, Annahme-, Fertigstellungs-, Leistungs-, Rechnungs- und Fälligkeitsdatum, „Skonto 2 % bis 22.07.2026 = 894,47“ (nicht der Gesamtbetrag), „Nächstes Service 03/2028“, EZ 03.03.2018; Zwischensummen Lohn/Teile. |
| 15 | Handzettel: `I20,-` statt `120,-`, `Sch|osserei`, kurzer Text, Datum `3.7.26`, `GU - 451AB`; keine UID, kein km, keine Kleinunternehmer-Angabe. |
| 16 | Akonto -1.500,00 und „Zahlbetrag 2.880,24“: erwartet 4.380,24 (E-1); Akonto-Rechnung vom 03.06.2026 ist kein Datum der Rechnung; km 203.918, Rechnungsdatum (25.06.) ≠ Leistungsdatum (24.06.). |
| 17 | Sonstige Werkstatt (Aufbereitung); sauber, nur Kategorie nicht aus Service-Stichwörtern ableitbar. |
| 18 | Pickerl mit behobenem Mangel und Glühlampe als Extra-Position (Kategorie bleibt inspection); FIN mit Nullen; „Plakette zugeteilt 03/2027“; Beträge auf eigener Zeile. |
| 19 | Zweistellige Jahre (`08.04.26`, `07.04.26`, `22.04.26`), „Leistung“ statt „Leistungsdatum“; `120,--`; „km 66 480“; USt nur als „darin enthalten“; `49,OO`; Räder-Nr. 7731 und „bis 10/26“ (kein Datum). |
| 20 | Bon: stark verrauscht: `ELEKTR0`, `l64,00` für `164,00`, `58O…`, `Bon 2218` und Art-Nr. 570 412 064; Summe steht vor den Positionen (Reihenfolge vertauscht); „14.FEB.2026“; Kartenzahlung; Gesamtbetrag nur am Anfang und bei der Zahlung. |
| 21 | „Angebot vom 15. Jänner 2026“ ist nicht das Rechnungsdatum; UID mit Leerzeichen und `O`; `Fol1en`; `1.O3O,00`; „zu zahlen“; km `31.7OO`. |
| 22 | km-Fallen: Auftrags-Nr. 87456, „Nächster Service bei 45.000 km“, `5W-30 VW 504 00`, Teilenummern, PLZ 3100/3500; Erstzulassung 21.09.2021; breite Spaltentabelle; Kundenname mit „Mag.“. |
| 23 | Bon, stark: `O2.1O.2O26 O8:11`, `5I482O93` (I statt 1), `9l,70`, `5 57A` statt `§57A`, `94,OO`; Zeilen auseinandergerissen; „Nächste Begutachtung 10/2027“. |
| 24 | Bon sauber: „gegeben 80,00“ und „Rückgeld 8,00“; „nach 50 km nachziehen“ (kein km-Stand); kein Kilometerstand (null). |
| 25 | Rabatt 5 % auf die Zwischensumme (539,00 → 512,05 netto); „Zu zahlen“ = Brutto; km als „Tachostand: 171.460 km“; FIN. |
