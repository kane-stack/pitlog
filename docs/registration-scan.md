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
  mehrzeilig sein). *niedrig* bei Werten aus der Folgezeile (Datum, Freitext), bei Widersprüchen (B nach I, F.2 über
  F.1) und bei VIN mit falscher Länge. Niedrige Werte sind im Review standardmäßig abgewählt.
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
