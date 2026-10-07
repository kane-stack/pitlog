# Zulassungsschein-Scan (M5a)

Umsetzung von ADR-13 und Umfang V1, Punkt 5. Grundlage für die Felder und Formate ist
`docs/sources/registration/README.md`. Dieses Dokument beschreibt, wie der Code damit umgeht und was ungeprüft ist.

## Ablauf

1. Quelle wählen: Dokumentenkamera (VisionKit), Foto aus der Mediathek oder Datei (Bild oder PDF).
   Auf dem Simulator gibt es keine Kamera, dort bleiben Fotos und Dateien.
2. Jede Seite wird mit Vision erkannt (`TextRecognizer`, genaue Stufe, Deutsch vor Englisch, ohne
   Sprachkorrektur, weil sie FIN und Feldcodes „verbessert“). Ergebnis sind Textzeilen mit normalisierten Boxen.
3. `RegistrationDocumentParser` (PitlogCore, nur Foundation) liest daraus einen `RegistrationDraft`.
4. Der Review-Bildschirm zeigt jedes Feld mit Wert, Textausschnitt und Verlässlichkeit. „Übernehmen“ füllt das
   Formular, gespeichert wird erst mit „Sichern“ im Formular.
5. Das Bild wird nicht gespeichert. Es lebt nur im Speicher, solange erkannt wird. Alles läuft auf dem Gerät.

Bei Karten werden Vorder- und Rückseite als zwei Seiten gelesen und zusammengeführt; liegt nur eine Seite vor, weist
der Review darauf hin.

## Parser

- **Zeilen:** Haben alle Zeilen eine Box, werden Zellen auf gleicher Höhe zu einer Tabellenzeile zusammengesetzt
  (Code-Zelle, Wert-Zelle). Ohne Boxen ist jede Zeile eine Zeile; Code und Wert müssen dann in einer Zeile stehen
  (oder der Wert in der Zeile darunter, siehe unten).
- **Codes:** Punkte und Leerzeichen werden ignoriert (`C1.1` = `C.1.1`, `F2` = `F.2`). Ein Code gilt nur, wenn
  sein Etikett folgt, oder am Zellenanfang ein Wert in der richtigen Form. Innerhalb einer Zelle zählt nur das
  Etikett, damit Handelsbezeichnungen wie `Audi A4 40 TDI` nicht zerlegt werden. Beginnt eine Wertzelle wie ein
  Code (`D3` leer, daneben `A4 25`), wird sie als Wert behandelt und das Feld nur mit niedriger Verlässlichkeit
  geliefert.
- **Verlässlichkeit:** *hoch* nur bei gefundenem Code, passender Form und ohne Korrektur. *mittel* bei
  OCR-Korrekturen (O/0, I/1, B/8), Code aus Variante (`DI` für `D1`), VIN ohne Code und freiem Text D.2 (kann
  mehrzeilig sein). *niedrig* bei Freitext aus der Folgezeile, bei Widersprüchen (B nach I, F.2 über
  F.1) und bei VIN mit falscher Länge. Niedrige Werte sind im Review standardmäßig abgewählt. Ein Datum aus der Folgezeile ist *mittel* (siehe Feld B) und damit vorausgewählt.
- **Besser nichts als falsch:** Zwei verschiedene Werte für dasselbe Feld heben sich auf. Ein Kennzeichen, das mit
  weiteren Buchstaben weitergeht, wird nicht abgeschnitten. Ein Erstzulassungsdatum in der Zukunft oder vor 1900
  wird verworfen.
- **Datenschutz:** C.1.1 bis C.1.3, C.4 und A.3 werden erkannt, aber nie gelesen. Sie dienen nur dazu, das Ende des
  Nachbarfelds zu finden. Jedes Feld trägt nur den Text seines eigenen Werts, nie die ganze Zeile. Tests prüfen,
  dass Name, Anschrift und Geburtsdatum nirgends im Entwurf vorkommen.
- **Legende der Kartenrückseite:** Zeilen mit mindestens zwei Strichpunkten werden verworfen.
- **Kategorie:** J → `VehicleCategory` (M1 → Pkw, L1e bis L7e → Motorrad, O1/O2 → leichter Anhänger,
  N1 → leichtes Nutzfahrzeug, alles andere → `other`). A.4 = 25, 62 oder 64 macht aus M1 `taxiOrAmbulance`. Steht
  in J nur „Anhänger“, entscheidet F.2 (bis 3500 kg leicht). Bei `other` zeigt der Review den vorhandenen Hinweis,
  dass das Datum von Hand einzugeben ist.
- **Teil II, Überstellungsfahrtschein:** Teil II (A21/A22) wird gelesen, mit Hinweis. Der Überstellungsfahrtschein
  („Transport Permit“) liefert nichts und wird als Sonderfall gemeldet.

## Feld B (Erstzulassung), Gerätetest M6d

Im ersten Gerätetest wurde die Erstzulassung nie übernommen, alles andere schon. Vermutete Ursachen, die der Parser
jetzt abdeckt (synthetische Tests in `RegistrationFieldBTests`, keine echten Daten):

- **Datum unter dem Etikett.** Das Papier setzt den Wert in die Zeile unter „Erstmalige Zulassung am:“. Solche
  Folgezeilen-Daten waren *niedrig* und damit im Review abgewählt. Jetzt sind sie *mittel* (vorausgewählt, im
  Review mit Hinweis „bitte prüfen“): Die Form eines vollständigen Datums ist selbst ein starker Anker. Das
  Datum darf auch hinter einer Zeile stehen, die nur den Etikett-Text enthält (`B` / `Erstmalige Zulassung am:` / Datum).
  Stehen `B` und `I` nebeneinander und darunter zwei Daten, werden sie von links nach rechts zugeordnet; stimmen die
  Anzahlen nicht, wird nichts gelesen. Als Snippet dient nur das Datum, nie der Rest der Zeile.
- **Code und Datum zusammengeklebt:** `B12.03.2015`, `B:12.03.2015` werden vor der Zeilenbildung getrennt.
- **Leerzeichen und OCR-Fehler im Datum:** `12 .03. 2015`, `12 . 03 . 2015`, `12,03.2015`, `l2.O3.2O15`
  (alle *mittel*, weil korrigiert).
- **Zweistellige Jahre** (`12.03.15`): bis zum aktuellen Jahr 2000er, darüber 1900er (`27` ist 1927, nie 2027).
  Immer *mittel*. Nur für B und I; sonst bleiben zweistellige Jahre ungültig.
- **Vorrang von B:** Ein Datum wird nur von seinem eigenen Code gelesen. Steht vor dem Datum das Etikett eines anderen
  Datumsfelds („Zugelassen am“, „gültig bis“, „Datum“), ist es *niedrig*. Fehlt B, wird nichts geraten (I, H, A.6,
  Ausstellungsdatum werden nie ersatzweise genommen). B nach I bleibt *niedrig*; Zukunft und vor 1900 werden verworfen.
- **Vorauswahl im Review:** *hoch* und *mittel* sind an, nur *niedrig* ist aus. Ein plausibles Datum aus B ist damit
  wie die anderen sicheren Felder vorausgewählt. Die UI-Fixture `mixed` zeigt den *niedrigen* Fall jetzt über B nach I.

### Scheckkarte: Vorderseite und Hinweise (zweiter Gerätetest)

Beim Test mit der Karte meldete das Review „Nur die Rückseite wurde gelesen“, obwohl beide Seiten gescannt waren
(der Zähler zeigte 2). Die Meldung hing nur daran, dass weder Kennzeichen noch Erstzulassung gelesen wurden, und
behauptete damit, die Vorderseite fehle. Jetzt gilt:

- **Hinweise:** *Fehlt* eine Seite wirklich (nur eine nicht leere Seite gescannt), bleibt der alte Hinweis
  („Nur die Rückseite/Vorderseite wurde gelesen …“). Wurde die andere Seite gescannt, aber nichts gelesen, lautet er:
  „Auf der Vorderseite konnten Kennzeichen und Erstzulassung nicht gelesen werden. Versuch es mit besserem Licht
  oder trag sie selbst ein.“ bzw. für die Rückseite (FIN, Marke, Modell). Die Rückseite erkennt der Parser an der
  Legende, die Vorderseite am Titel; als gescannt zählt jede Seite mit Text, die nicht die Legendenseite ist.
  Neue Notices `cardFrontUnreadable` und `cardBackUnreadable`.
- **Titel der Vorderseite:** auch `TEIL1`, `TEIL I`, `TEILI`, `TEIL l` (OCR liest die 1 als I oder l).
- **A und B in einer Zeile ohne Boxen** (`A S-4455AA B 10.06.2022`, `A … I 11.06.2022 B 10.06.2022`): Ein schlichtes
  `B` oder `I` direkt vor einem vollständigen Datum beginnt auch mitten in der Zeile ein Feld. Nicht hinter D.1 bis D.3
  (dort ist `Typ B 10.06.2022` Text) und nicht als OCR-Variante (`8`). Mit Boxen trug das schon vorher.
- **Reihenfolge der Seiten:** Rückseite vor Vorderseite liefert dasselbe (Test).
- Ungeprüft bleibt, wie Vision die kleine Schrift der echten Karte liest. Die Layouts in `RegistrationCardFrontTests`
  sind Annahmen (Code und Wert in getrennten Zeilen, nebeneinander, mit und ohne Punkt, zusammengeklebt).
  Der Debug-Dump (jetzt mit Zeilenzahl je Seite und Leerzeile zwischen den Seiten) zeigt, was wirklich ankommt.

### Diagnose „Erkannte Zeilen kopieren“ (nur Debug)

Im Review des Zulassungsscheins steht in Debug-Builds (`#if DEBUG`, nicht im Release und ohne Katalogtexte, wie die
anderen Entwicklerwerkzeuge) ein Abschnitt „Debug“ mit dem Knopf „Copy recognized lines“. Er legt alle erkannten
Zeilen als Text in die Zwischenablage, je Zeile `x y w h | Text` (normalisiert, Ursprung oben links, drei
Nachkommastellen), pro Seite eine Überschrift. **Der Text kann Name und Anschrift des Halters enthalten** (der
Hinweis steht auch im Abschnitt). Vor dem Weitergeben schwärzen. Release-Builds halten die Zeilen nach dem Parsen
nicht mehr (`Presentation.recognizedPages` gibt es nur in Debug).

Ablauf für den nächsten Gerätetest: Debug-Build, Zulassungsschein scannen, im Review „Copy recognized lines“, Text
in eine Notiz einfügen, Name/Anschrift/Geburtsdatum schwärzen, an die Coding-Session geben. Daraus wird ein
synthetischer Testfall (nie die echten Daten einchecken).

## Nicht geprüft

Alles unten braucht ein Gerät und echte Dokumente. Offen bleibt der Test mit dem eigenen Zulassungsschein von
Christopher (Papier und Karte).

- Wie gut Vision die kleine Schrift der Karte und die Tabellenzellen des Papiers in der Praxis liest.
- Die tatsächliche Schreibweise der Werte (Datumsformat in B, Leerzeichen und Bindestrich im Kennzeichen, Einheit in
  F.2, Aufbau von J) – die Annahmen stehen im README, Abschnitt „Offene Punkte“.
- Ob die Zellen eines echten Papierscheins als getrennte Zeilen erkannt werden (dann trägt die Geometrie) oder als
  eine Zeile (dann tragen die Etiketten).
- Das Verhalten der Dokumentenkamera selbst (Kantenerkennung, mehrere Seiten).
- Alte Zulassungsscheine vor 1998 und die digitale Variante der App „eAusweise“ sind nicht unterstützt.
  Der Parser findet dort keine Codes; der Nutzer sieht „Es konnte nichts gelesen werden“.
- `RecognizeDocumentsRequest` (iOS 26) wurde nicht eingesetzt: Die Tabellenstruktur baut der Parser selbst aus den
  Boxen zusammen, und die Schnittstelle ließ sich ohne Gerät nicht prüfen.
