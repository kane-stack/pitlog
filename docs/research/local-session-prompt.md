# Prompt für eine lokale Recherche-Session (Primärquellen)

Die Cloud-Umgebung erreicht RIS und Parlament nicht. Diesen Prompt in einer **lokalen**
Claude-Code-Session im Repo `pitlog` ausführen. Ergebnis als Commit auf demselben Branch pushen.

---

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
