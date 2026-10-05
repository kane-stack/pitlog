# Erinnerungen und Benachrichtigungen (M3)

Stand: Meilenstein M3. Alle Benachrichtigungen sind lokal (ADR-9): Jedes Gerät plant selbst, es gibt kein Backend.
Die Regeln stehen in `docs/rules/AT-57a-KFG.md` §7, die Quellentexte in `docs/sources/`.

## Standardregeln Österreich

| ID | Regel | Quelle | Standard in der App |
|---|---|---|---|
| AT-72 | Winterreifen: 1. November bis 15. April (für M1/N1 situativ bei winterlichen Fahrbahnverhältnissen) | § 102 Abs. 8a KFG (`KFG_102_Abs8a.md`), PRIMÄR | Winter: Erinnerung 14 Tage vor dem 1. 11. (also 18. 10.). Sommer: 14 Tage vor dem 15. 4. (also 1. 4.). Datum und Vorlauf sind änderbar. |
| AT-70 | Jahresvignette gilt vom 1. Dezember des Vorjahres bis 31. Jänner des Folgejahres; ab 1. 12. 2026 nur digital | § 11 Abs. 1 und 2 BStMG (`BStMG_11_15.md`), PRIMÄR | Erinnerung am 1. 12. („neue Vignette verfügbar“) und 25 Tage vor dem 31. 1. (also 6. 1.). |
| AT-71 | Online-Kauf (Fernabsatz): Gültigkeit frühestens ab dem 18. Tag nach dem Kauf | § 15 Abs. 2 Z 8 BStMG, SEKUNDÄR (Einzelheiten in der ASFINAG-Mautordnung, nicht geprüft) | Der Text der 25-Tage-Erinnerung weist darauf hin. 25 Tage = 18 Tage + 7 Tage Puffer. |

Abweichung vom Auftrag: Das Gesetz spricht von Erwerb „im Fernabsatz“, nicht von „Verbrauchern“, und nennt nur die Eintagesvignette als Ausnahme. Die App formuliert deshalb vorsichtig („gilt womöglich erst ab dem 18. Tag“). Die Daten der Winterperiode stimmen mit der Quelle überein.

Der Vorlauf von 14 bzw. 25 Tagen und die Uhrzeit 09:00 sind Produktentscheidungen, keine Rechtsregeln.

## Pickerl-Erinnerungen

Abgeleitet aus dem `InspectionStatus`, nie gespeichert. Pro Fahrzeug abschaltbar. Termine (doppelte Tage werden zusammengelegt, vergangene verworfen):

1. Das Begutachtungsfenster öffnet (`window.opens`).
2. Der erste Tag des Monats vor dem Fälligkeitsmonat.
3. Der erste Tag des Fälligkeitsmonats.
4. Sieben Tage vor `window.closes`.

Beispiel Übergangsrecht (AT-56), Fälligkeit 2027-08, Fenster 19.05.2027 bis 30.11.2027: 19.05., 01.07., 01.08., 23.11.2027. Ist das Fenster geschlossen (überfällig), wird nichts geplant. Jeder Text endet mit „Datum auf der Plakette prüfen.“ (ADR-5, ADR-8).

## Weitere Arten

- **Reifenwechsel, Vignette:** jährlich. „Erledigt“ schiebt das Datum um ein Jahr.
- **Service:** nach Datum und/oder Kilometerstand, optional wiederholend (Monate und/oder km, gerechnet ab dem tatsächlichen Service). Der Termin nach Kilometern ist eine **Schätzung**: lineare Hochrechnung aus den Kilometerständen (mindestens zwei, mindestens 14 Tage auseinander), Vorlauf 500 km. Ohne Schätzung wird nichts geplant, die UI fordert einen Kilometerstand an.
- **Eigene:** Datum, Vorlauf, Wiederholung nie, jährlich oder alle N Monate.

## Planung

`NotificationPlanner` (PitlogCore) verwirft vergangene Tage, sortiert nach Datum und begrenzt auf 60 (iOS erlaubt 64). Die App ersetzt alle ausstehenden Anfragen mit dem Präfix `pitlog.reminder.` durch den neuen Plan. Neu geplant wird beim Aktivwerden der App, nach Speichern (entprellt), bei geänderten Einstellungen und über einen `BGAppRefreshTask` (`com.kane.pitlog.refresh-reminders`, ungefähr täglich, iOS entscheidet). Mitteilungen werden nur geplant, wenn die Erlaubnis vorliegt. Gefragt wird erst beim ersten Erstellen oder Einschalten einer Erinnerung, nach einer kurzen Erklärung.
