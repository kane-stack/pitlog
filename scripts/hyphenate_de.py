#!/usr/bin/env python3
"""Inserts soft hyphens (U+00AD) into long German words of the `de` translations in Localizable.xcstrings.

Why: SwiftUI Text breaks at U+00AD and shows the hyphen only at the line end, so long compounds wrap at
accessibility text sizes instead of being cut or scaled down. Strings that are only spoken (VoiceOver
comment) are skipped; code that uses a string outside a view strips the soft hyphens again
(`String.withoutSoftHyphens`). Idempotent: existing soft hyphens are removed first. Run: scripts/hyphenate_de.py
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "App/Resources/Localizable.xcstrings"
SHY = "­"

# Lowercase word -> syllable breaks marked with "-". Every part has at least two letters.
HYPHENATION = """
archivieren=ar-chi-vie-ren archivierte=ar-chi-vier-te archivierten=ar-chi-vier-ten
austauschplakette=aus-tausch-pla-ket-te begutachtung=be-gut-ach-tung begutachtungen=be-gut-ach-tun-gen
begutachtungsfenster=be-gut-ach-tungs-fens-ter bestimmungen=be-stim-mun-gen
datenschutzerklärung=da-ten-schutz-er-klä-rung durchgeführte=durch-ge-führ-te
einstellungen=ein-stel-lun-gen erinnerungen=er-in-ne-run-gen erinnerung=er-in-ne-rung
erstzulassung=erst-zu-las-sung fahrbahnverhältnissen=fahr-bahn-ver-hält-nis-sen fahrzeugart=fahr-zeug-art
fahrzeugdaten=fahr-zeug-da-ten fahrzeughalter=fahr-zeug-hal-ter fahrzeuge=fahr-zeu-ge fahrzeugen=fahr-zeu-gen
familienfreigabe=fa-mi-li-en-frei-ga-be familienmitglied=fa-mi-li-en-mit-glied fälligkeitsmonat=fäl-lig-keits-mo-nat
gespeichert=ge-spei-chert gratiszeitraum=gra-tis-zeit-raum haftungsausschluss=haf-tungs-aus-schluss
historisches=his-to-ri-sches kennzeichen=kenn-zei-chen kilometerstand=ki-lo-me-ter-stand
kilometerstände=ki-lo-me-ter-stän-de kilometerständen=ki-lo-me-ter-stän-den kostenloser=kos-ten-lo-ser
kostenlosen=kos-ten-lo-sen krankentransport=kran-ken-trans-port nutzfahrzeug=nutz-fahr-zeug
nutzungsbedingungen=nut-zungs-be-din-gun-gen rechtliches=recht-li-ches rechtsfrage=rechts-fra-ge
rechtsinformationssystem=rechts-in-for-ma-ti-ons-sys-tem regelversion=re-gel-ver-si-on
reifenwechsel=rei-fen-wech-sel reparaturen=re-pa-ra-tu-ren reparatur=re-pa-ra-tur
servicenachweis=ser-vice-nach-weis sommerreifen=som-mer-rei-fen sprachmodell=sprach-mo-dell
unterstützung=un-ter-stüt-zung unverbindlich=un-ver-bind-lich voraussichtlich=vor-aus-sicht-lich
vorderseite=vor-der-sei-te vorlaufzeit=vor-lauf-zeit vorlaufzeiten=vor-lauf-zei-ten
wartungshistorie=war-tungs-his-to-rie werkstattbesuche=werk-statt-be-su-che
werkstattkosten=werk-statt-kos-ten werkstattrechnung=werk-statt-rech-nung wiederherstellen=wie-der-her-stel-len
wiederholen=wie-der-ho-len winterperiode=win-ter-pe-ri-ode winterreifen=win-ter-rei-fen
winterreifenperiode=win-ter-rei-fen-pe-ri-ode zahlungsmethode=zah-lungs-me-tho-de
zulassungsbescheinigung=zu-las-sungs-be-schei-ni-gung zulassungsschein=zu-las-sungs-schein
angezeigten=an-ge-zeig-ten aufgeführten=auf-ge-führ-ten ausgeschaltet=aus-ge-schal-tet
automatisch=au-to-ma-tisch bearbeitest=be-ar-bei-test begutachtet=be-gut-ach-tet
eingegebenen=ein-ge-ge-be-nen eingeschaltet=ein-ge-schal-tet eingeschaltete=ein-ge-schal-te-te
einschließen=ein-schlie-ßen exportieren=ex-por-tie-ren fehlgeschlagen=fehl-ge-schla-gen
geschlossen=ge-schlos-sen hinzugefügt=hin-zu-ge-fügt kostenpflichtige=kos-ten-pflich-ti-ge
möglicherweise=mög-li-cher-wei-se rechtlichen=recht-li-chen stattdessen=statt-des-sen
unabhängige=un-ab-hän-gi-ge wiederhergestellt=wie-der-her-ge-stellt winterlichen=win-ter-li-chen
überstellungsfahrtschein=über-stel-lungs-fahrt-schein
maßgeblich=maß-geb-lich kategorie=ka-te-go-rie berechnung=be-rech-nung belegscan=be-leg-scan
"""
TABLE = {}
for pair in HYPHENATION.split():
    word, _, parts = pair.partition("=")
    assert parts.replace("-", "") == word, f"hyphenation does not match its word: {pair}"
    assert all(len(p) >= 2 for p in parts.split("-")), f"part shorter than two letters: {pair}"
    TABLE[word] = parts.replace("-", SHY)

WORD = re.compile(r"[A-Za-zÄÖÜäöüß]{10,}")


def hyphenate(text: str) -> str:
    def repl(match: re.Match) -> str:
        word = match.group(0)
        soft = TABLE.get(word.lower())
        if soft is None:
            return word
        # Restore the original capitalisation; soft hyphens do not shift letters.
        out, i = [], 0
        for ch in soft:
            if ch == SHY:
                out.append(ch)
            else:
                out.append(word[i])
                i += 1
        return "".join(out)
    return WORD.sub(repl, text)


def is_display_only(entry: dict) -> bool:
    """Strings with a VoiceOver comment are only spoken, never shown. Everything else may be hyphenated:
    the places that read a string for a non-view purpose (notifications, PDF, spoken labels) call
    `withoutSoftHyphens`."""
    return not entry.get("comment", "").startswith("VoiceOver")


def main() -> int:
    data = json.loads(CATALOG.read_text())
    changed = skipped = 0

    def process(unit: dict) -> bool:
        value = unit["value"]
        new = hyphenate(value.replace(SHY, ""))
        if new != value:
            unit["value"] = new
            return True
        return False

    for key, entry in data["strings"].items():
        de = entry.get("localizations", {}).get("de")
        if not de:
            continue
        units = []
        if "stringUnit" in de:
            units.append(de["stringUnit"])
        for variation in de.get("variations", {}).values():
            units.extend(v["stringUnit"] for v in variation.values() if "stringUnit" in v)
        display = is_display_only(entry)
        for unit in units:
            if display:
                changed += process(unit)
            else:
                skipped += 1
                unit["value"] = unit["value"].replace(SHY, "")
    # Same formatting Xcode uses: two spaces, " : " separator.
    CATALOG.write_text(json.dumps(data, indent=2, ensure_ascii=False, separators=(",", " : ")) + "\n")
    print(f"hyphenated {changed} strings, left {skipped} spoken-only strings untouched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
