# ÖAMTC-Pickerlrechner, Abfrage vom 04.10.2026

| | |
|---|---|
| Quelle | ÖAMTC-Pickerlrechner (Sekundärquelle, Rechenwerkzeug eines Vereins, keine Rechtsquelle) |
| Seite | https://www.oeamtc.at/pickerlrechner (leitet weiter auf https://www.oeamtc.at/thema/pickerl/neue-57a-pickerl-regelung-in-oesterreich-jetzt-intervall-fristen-berechnen-89430229) |
| Schnittstelle | `POST https://www.oeamtc.at/api/spunq-proxy/1.0/api/p57a-calc/calculate`, Version laut `GET …/p57a-calc/version`: `1.0.0` |
| Abgerufen | 04.10.2026, ca. 20:00 MESZ |
| Hinweis | Es sind nur unsere Eingaben und die zurückgelieferten Werte wiedergegeben, keine Texte des ÖAMTC. |

Der Rechner kennt nur diese Eingaben: Fahrzeugklasse (`M1`, `O1`, `O2`, `N`, `L`), „historisch“,
„Taxi, Rettung oder Krankentransport“, Erstzulassung (Monat/Jahr) und Lochung (Monat/Jahr, optional).
Er kennt **kein** Datum der letzten Begutachtung und **kein** „heute“. Ob ein Fahrzeug schon
begutachtet wurde, leitet er offenbar aus Erstzulassung und Lochung ab.

¹ „Sonderfall“: Der Rechner meldet, dass die Austauschplakette innerhalb der Übergangsfrist im
Toleranzzeitraum ausgegeben würde. Der Zeitraum, in dem er die Austauschplakette für möglich hält,
beginnt immer am 19.05.2027 und endet mit dem Toleranzzeitraum der vorhandenen Plakette.

Fallnamen `A…` entsprechen den Ankerfällen in `docs/rules/AT-57a-KFG.md` § 9.6, `X…` sind
zusätzliche Grenzfälle.

| Fall | Klasse | EZ | Lochung | Fällig | Toleranzzeitraum | Austausch | neue Lochung | Fenster neue Lochung | Sonderfall¹ |
|---|---|---|---|---|---|---|---|---|---|
| A1 | M1 | 2020-03 | 2027-03 | 2027-03 | 2027-02-01 bis 2027-07-31 | ja | 2028-03 | 2027-11-01 bis 2028-03-31 | ja |
| A3 | M1 | 2024-06 | 2027-06 | 2027-06 | 2027-05-01 bis 2027-10-31 | ja | 2028-06 | 2028-02-01 bis 2028-06-30 |  |
| A4 | M1 | 2021-04 | 2027-04 | 2027-04 | 2027-03-01 bis 2027-08-31 | ja | 2028-04 | 2027-12-01 bis 2028-04-30 | ja |
| A5 | M1 | 2023-09 | 2028-09 | 2028-09 | 2028-05-01 bis 2028-09-30 | nein | – | – |  |
| A6 | M1 | 2028-03 | – | 2032-03 | 2031-11-01 bis 2032-03-31 | nein | – | – |  |
| A7 | M1 | 2015-07 | 2027-08 | 2027-08 | 2027-05-19 bis 2027-11-30 | nein | – | – |  |
| A8 | L | 2019-05 | 2027-05 | 2027-05 | 2027-04-01 bis 2027-09-30 | ja | 2028-05 | 2028-01-01 bis 2028-05-31 | ja |
| A9 | O1 | 2025-10 | 2028-10 | 2028-10 | 2028-06-01 bis 2028-10-31 | ja | 2029-10 | 2029-06-01 bis 2029-10-31 |  |
| A10 | N | 2026-02 | 2027-02 | 2027-02 | 2026-11-01 bis 2027-02-28 | nein | – | – |  |
| A11 | M1 historisch | 1976-04 | 2028-04 | 2028-04 | 2027-12-01 bis 2028-04-30 | nein | – | – |  |
| A13 | M1 | 2022-01 | 2027-01 | 2027-01 | 2026-12-01 bis 2027-05-18 | nein | – | – |  |
| A14 | M1 | 2010-03 | 2028-03 | 2028-03 | 2027-11-01 bis 2028-03-31 | nein | – | – |  |
| A15 | M1 | 2020-06 | 2027-06 | 2027-06 | 2027-05-01 bis 2027-10-31 | ja | 2028-06 | 2028-02-01 bis 2028-06-30 |  |
| X1 Taxi | M1 Taxi/Rettung | 2024-03 | 2027-03 | 2027-03 | 2026-12-01 bis 2027-03-31 | nein | – | – |  |
| X2 N Aug | N | 2020-08 | 2027-08 | 2027-08 | 2027-05-19 bis 2027-11-30 | nein | – | – |  |
| X3 hist Okt | M1 historisch | 1980-10 | 2027-10 | 2027-10 | 2027-06-01 bis 2027-11-30 | nein | – | – |  |
| X4 hist Mar | M1 historisch | 1985-03 | 2027-03 | 2027-03 | 2027-02-01 bis 2027-07-31 | nein | – | – |  |
| X5 Alter9 | M1 | 2018-09 | 2027-09 | 2027-09 | 2027-05-19 bis 2027-11-30 | ja | 2028-09 | 2028-05-01 bis 2028-09-30 |  |
| X6 Alter10 | M1 | 2017-05 | 2027-05 | 2027-05 | 2027-04-01 bis 2027-09-30 | nein | – | – |  |
| X7 Dez26 | M1 | 2019-12 | 2026-12 | 2026-12 | 2026-11-01 bis 2027-04-30 | nein | – | – |  |
| X8 N Nov27 | N | 2021-11 | 2027-11 | 2027-11 | 2027-07-01 bis 2027-11-30 | nein | – | – |  |
| X9 L Jun | L | 2023-06 | 2027-06 | 2027-06 | 2027-05-01 bis 2027-10-31 | ja | 2028-06 | 2028-02-01 bis 2028-06-30 |  |
| X10 nie begutachtet, Lochung Mär | M1 | 2024-03 | 2027-03 | 2027-03 | 2027-02-01 bis 2027-07-31 | ja | 2028-03 | 2027-11-01 bis 2028-03-31 | ja |
| X11 Lochung Jän | M1 | 2024-01 | 2027-01 | 2027-01 | 2026-12-01 bis 2027-05-18 | nein | – | – |  |
| X12 Lochung 2028 | M1 | 2021-04 | 2028-04 | 2028-04 | 2027-12-01 bis 2028-04-30 | ja | 2029-04 | 2028-12-01 bis 2029-04-30 | ja |
| X13 Alter 10, abw. Monat | M1 | 2016-04 | 2027-09 | 2027-09 | 2027-05-19 bis 2027-11-30 | nein | – | – |  |

## Antwortformat (Beispiel A1)

```json
{
  "nextDueDate": {
    "month": 3,
    "year": 2027
  },
  "tolerancePeriod": {
    "startDate": "2027-02-01",
    "endDate": "2027-07-31",
    "ruleDescription": null
  },
  "replacementSticker": {
    "isEligible": true,
    "isSpecial": true,
    "startDate": "2027-05-19",
    "endDate": "2027-07-31",
    "newPunchDate": {
      "month": 3,
      "year": 2028
    },
    "tolerancePeriod": {
      "startDate": "2027-11-01",
      "endDate": "2028-03-31",
      "ruleDescription": null
    },
    "description": "ACHTUNG Sonderfall: Die Ausgabe einer Austauschplakette erfolgt innerhalb der Übergangsfrist im Toleranzzeitraum."
  }
}
```

Im Feld `description` steht ein kurzer deutscher Hinweistext; er ist hier nicht übernommen.
