#!/usr/bin/env python3
"""Validate the receipt holdout fixtures (JSON schema, formats, arithmetic).

Usage: python3 scripts/check_receipt_holdout.py
Amounts are minor units (cents). Run from the repository root.
"""
import json, re, sys
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

DIR = Path("Packages/PitlogCore/Tests/PitlogCoreTests/Fixtures/ReceiptsHoldout")
TODAY = date(2026, 10, 5)
KEYS = ["grossTotalMinor", "currency", "serviceDate", "invoiceDate", "historyDate",
        "workshopName", "workshopUID", "odometerKm", "plate", "vin", "category"]
CATS = {"service", "repair", "tyres", "inspection", "otherWorkshop"}

# error level per receipt
LEVEL = {}
for ids, lvl in (("01 05 07 10 13 17 24 25", "clean"),
                 ("02 04 08 09 11 14 16 18 19 22", "moderate"),
                 ("03 06 12 15 20 21 23", "heavy")):
    for i in ids.split():
        LEVEL[i] = lvl

# net = sum(items) - less; vat = 20 % of net; gross = net + vat.
# "gross_items": item prices already include VAT (till receipts); "vat": printed VAT.
# "sign": -1 for credit notes. No entry for 15 (handwritten, only a gross sum, no VAT shown).
ARITH = {
    "01": dict(gross=8990, net=7492, vat=1498),
    "02": dict(gross_items=[7400, 4500, 1000], net=10750, vat=2150),
    "03": dict(items=[40080, 10020, 5010, 8127, 2460, 280, 2140, 2990, 1450]),
    "04": dict(items=[96200, 68900, 84250, 3960], less=15711, gross_expected=285119),
    "05": dict(items=[4500, 3150, 1450], no_vat=True),
    "06": dict(items=[694400, 156800, 124000, 138640, 84290, 112360, 9635]),
    "07": dict(items=[81000, 7250, 1980, 2850, 2200, 7200, 400]),
    "08": dict(items=[7680, 5500], sign=-1),
    "09": dict(items=[23800, 2400, 23800, 3150]),
    "10": dict(gross=8990, net=7492, vat=1498),
    "11": dict(gross_items=[4200, 1680, 2400, 500], net=7317, vat=1463),
    "12": dict(items=[39400, 4800, 3600, 1400, 1000, 7900]),
    "13": dict(gross_items=[7470, 230], net=6417, vat=1283),
    "14": dict(items=[48300, 17480, 6490, 1230, 1950, 610]),
    "16": dict(items=[214000, 137500, 7680, 5840]),
    "17": dict(items=[12000, 8500, 29000]),
    "18": dict(items=[8200, 2100, 650]),
    "19": dict(gross_items=[5900, 4900, 1200], net=10000, vat=2000),
    "20": dict(gross_items=[13900, 2500], net=13667, vat=2733),
    "21": dict(items=[52000, 51000]),
    "22": dict(items=[31140, 7040, 1890, 190, 2650, 800]),
    "23": dict(gross_items=[9170, 230], net=7833, vat=1567),
    "24": dict(gross_items=[6600, 600], net=6000, vat=1200),
    "25": dict(items=[29400, 24500], less=2695),
}

def rnd(x):
    return int(Decimal(x).quantize(Decimal(1), rounding=ROUND_HALF_UP))

errors = []
def err(n, msg):
    errors.append(f"{n}: {msg}")

def iso(s):
    return date.fromisoformat(s)

files = sorted(DIR.glob("*.expected.json"))
if len(files) != 25:
    err("set", f"expected 25 receipts, found {len(files)}")
counts = {"clean": 0, "moderate": 0, "heavy": 0}
for f in files:
    stem = f.name[:-len(".expected.json")]
    num = stem[:2]
    txt = DIR / f"{stem}.txt"
    if not txt.exists():
        err(stem, "txt missing"); continue
    text = txt.read_text(encoding="utf-8")
    if "\t" in text or not text.strip():
        err(stem, "tab or empty text")
    counts[LEVEL.get(num, "?")] = counts.get(LEVEL.get(num, "?"), 0) + 1
    try:
        e = json.loads(f.read_text(encoding="utf-8"))
    except Exception as ex:
        err(stem, f"invalid JSON: {ex}"); continue
    if list(e.keys()) != KEYS:
        err(stem, f"keys {list(e.keys())}")
        continue
    if not isinstance(e["grossTotalMinor"], int) or isinstance(e["grossTotalMinor"], bool):
        err(stem, "grossTotalMinor not int")
    if e["currency"] != "EUR": err(stem, "currency")
    for k in ("serviceDate", "invoiceDate", "historyDate"):
        if e[k] is not None:
            try:
                if iso(e[k]) > TODAY: err(stem, f"{k} in the future")
            except ValueError:
                err(stem, f"{k} not ISO")
    if e["invoiceDate"] is None: err(stem, "invoiceDate null")
    if e["historyDate"] != (e["serviceDate"] or e["invoiceDate"]): err(stem, "historyDate rule (E-2)")
    if e["serviceDate"] and e["invoiceDate"] and iso(e["serviceDate"]) > iso(e["invoiceDate"]):
        err(stem, "serviceDate after invoiceDate")
    if e["category"] not in CATS: err(stem, "category")
    if not e["workshopName"]: err(stem, "workshopName")
    if e["workshopUID"] is not None and not re.fullmatch(r"ATU\d{8}", e["workshopUID"]): err(stem, "UID format")
    if e["vin"] is not None and not re.fullmatch(r"[A-HJ-NPR-Z0-9]{17}", e["vin"]): err(stem, "VIN format")
    if e["plate"] is not None and not re.fullmatch(r"[A-Z]{1,2}\d{1,5}[A-Z]{1,3}", e["plate"]): err(stem, "plate format")
    if e["odometerKm"] is not None and not (1000 <= e["odometerKm"] <= 500000): err(stem, "odometer range")
    # plausibility of the expected values against the text (clean receipts must contain them verbatim)
    if LEVEL.get(num) == "clean":
        gross = f"{abs(e['grossTotalMinor']) // 100:,}".replace(",", ".") + f",{abs(e['grossTotalMinor']) % 100:02d}"
        alt = gross.replace(".", "")
        if gross not in text and alt not in text: err(stem, f"gross {gross} not in clean text")
        if e["workshopUID"] and e["workshopUID"][3:] not in text.replace(" ", ""): err(stem, "UID not in clean text")
    # arithmetic
    a = ARITH.get(num)
    if a is None:
        if num != "15": err(stem, "no ARITH entry")
        continue
    sign = a.get("sign", 1)
    if "items" in a:
        net = sum(a["items"]) - a.get("less", 0)
        if a.get("no_vat"):
            vat = 0
        else:
            vat = rnd(Decimal(net) * Decimal("0.2"))
        gross = net + vat
    else:
        gross = sum(a["gross_items"]) if "gross_items" in a else a["gross"]
        net, vat = a["net"], a["vat"]
        if net + vat != gross: err(stem, f"net+vat {net + vat} != gross {gross}")
        if abs(Decimal(net) * Decimal("1.2") - gross) > 2: err(stem, "net*1.2 off by more than 0.02")
    if gross * sign != e["grossTotalMinor"]:
        err(stem, f"gross {gross * sign} != expected {e['grossTotalMinor']}")
    if a.get("gross_expected") and a["gross_expected"] != e["grossTotalMinor"]: err(stem, "gross_expected")

if counts != {"clean": 8, "moderate": 10, "heavy": 7}:
    err("set", f"level distribution {counts}")
print(f"{len(files)} receipts, levels {counts}")
if errors:
    print("\n".join(errors)); sys.exit(1)
print("OK")
