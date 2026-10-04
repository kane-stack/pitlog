# Prompts für lokale Recherche-Sessions

Die Cloud-Umgebung erreicht RIS und Parlament nicht. Diese Prompts in einer **lokalen**
Claude-Code-Session im Repo `pitlog` ausführen. Ergebnis als Commit auf demselben Branch pushen.

---

## Teil 1: Pickerl-Regeln (Primärquellen)

```
Lies docs/rules/AT-57a-KFG.md. Jede Regel mit Status SEKUNDÄR oder OFFEN soll gegen
Primärquellen geprüft werden.

Primärquellen (in dieser Reihenfolge):
1. BGBl. I Nr. 79/2026 (42. KFG-Novelle), PDF:
   https://www.ris.bka.gv.at/Dokumente/BgblAuth/BGBLA_2026_I_79/BGBLA_2026_I_79.pdf
2. § 57a KFG konsolidiert (alte und, falls schon eingearbeitet, neue Fassung):
   https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10011384&Paragraf=57a
3. § 132 KFG konsolidiert (Abs. 37) und § 135 KFG (Inkrafttreten)
4. Parlamentsmaterialien: Initiativantrag 952/A XXVIII. GP, Ausschussbericht und
   Abänderungsantrag aus dem Verkehrsausschuss vom 02.07.2026 (Erläuterungen, Beispiele)
5. Prüf- und Begutachtungsstellenverordnung (PBStV), konsolidiert, und Entwürfe 2026
6. Danach erst ÖAMTC, ARBÖ, WKO

Vorgehen:
- Lege unter docs/sources/ die relevanten Gesetzesstellen als wörtlichen Text ab
  (österreichische Gesetzestexte sind nach § 7 UrhG frei), je Datei mit URL und Abrufdatum.
  Dateinamen z. B. BGBl-I-2026-79_Art1.md, KFG_57a_alt.md, KFG_132_Abs37.md.
- Aktualisiere docs/rules/AT-57a-KFG.md: Status pro Regel auf PRIMÄR setzen, mit genauer
  Fundstelle (§, Abs., Z, Satz). Widersprüche zu den bisherigen Angaben ausdrücklich
  vermerken, nichts still überschreiben.
- Löse besonders AT-53, AT-54, AT-56 (Übergangsfenster 2027) und AT-43 (Reichweite des
  −4/0-Fensters). Wenn der Text mehrdeutig bleibt, formuliere die möglichen Lesarten
  und markiere sie als OFFEN.
- Übernimm Beispiele aus den Erläuterungen als Testfälle in einen Abschnitt
  „Beispiele aus den Materialien“ (Eingabe → erwartetes Ergebnis, mit Fundstelle).
- Nicht an Code unter Packages/ oder App/ arbeiten.
- Commit-Nachricht: "docs(rules): verify AT-57a rules against primary sources"
```

---

## Teil 2: Zulassungsschein (für den Scan in M5)

Kann in derselben Session nach Teil 1 laufen oder separat. Eigener Commit.

```
Recherchiere den österreichischen Zulassungsschein als Grundlage für einen On-Device-Scan
(Vision-OCR, Extraktion anhand der Feldcodes). Hintergrund: CLAUDE.md, Umfang Punkt 5 und ADR-13.

Fragen:
1. Welche Formate sind aktuell gültig und im Umlauf? Papier-Zulassungsschein (Teil I),
   Scheckkartenformat (seit wann, optional oder Pflicht?), digitale Variante (z. B. in der
   App „eAusweise“: Gibt es einen digitalen Zulassungsschein, und kann man ihn exportieren,
   teilen oder fotografieren?). Gibt es ältere Formate, die noch gültig sind?
2. Welche Felder trägt jedes Format, mit Code und Bezeichnung? Mindestens A, B, E, J,
   D.1, D.2, D.3, F.2, und welche zusätzlichen nationalen Felder es gibt. Wie wird
   das Datum in Feld B geschrieben (Format, Trennzeichen)? Wie sieht die Fahrzeugklasse in
   Feld J aus (z. B. „M1“, „L3e“, „O1“, „N1“; Varianten wie „M1G“ oder Zusätze)?
3. Rechtsgrundlage der Felder: Richtlinie 1999/37/EG, Anhang I (EUR-Lex), sowie die
   österreichische Umsetzung (KFG / Zulassungsstellenverordnung bzw. Kraftfahrgesetz-
   Durchführungsverordnung, Anlage zum Zulassungsschein). Fundstellen mit URL.
4. Gibt es Unterschiede zur deutschen Zulassungsbescheinigung Teil I, die für einen
   gemeinsamen Parser wichtig sind? Nur kurz, DE ist nicht V1.

Bilder:
- Suche OFFIZIELLE Muster bzw. Specimen-Abbildungen (Behörden wie BMI, BMIMI,
  oesterreich.gv.at, Österreichische Staatsdruckerei, EU) und Bilder auf Wikimedia
  Commons mit freier Lizenz.
- Lege Bilder nur unter docs/sources/registration/ ab, wenn die Lizenz die Ablage im
  Repo eindeutig erlaubt (gemeinfrei, CC0, CC BY, CC BY-SA oder amtliches
  Werk nach § 7 UrhG). Zu jedem Bild gehört eine .md-Datei mit Quelle-URL, Abrufdatum,
  Lizenz und Urheber.
- Bei unklarer Lizenz NICHT herunterladen, nur den Link mit einer Beschreibung notieren.
- KEINE Fotos echter Zulassungsscheine von Privatpersonen (Foren, Kleinanzeigen,
  Social Media), auch nicht geschwärzt.

Ergebnis:
- docs/sources/registration/README.md (Deutsch) mit:
  - Formaten, Feldtabelle (Code, Bezeichnung, Beispielwert, Schreibweise) und Quellen
  - einem Abschnitt „Hinweise für den Parser“: Layout, Reihenfolge der Felder,
    mehrzeilige Felder, typische Verwechslungen
  - einem Abschnitt „Offene Punkte“
- Nicht an Code unter Packages/ oder App/ arbeiten.
- Commit-Nachricht: "docs(sources): research Austrian registration certificate formats"
```
