"""Dump all sheets from the Inter-Clan Games 2026 workbook using only stdlib."""
import zipfile
import xml.etree.ElementTree as ET
import re
from collections import defaultdict

XLSX = r"C:\Users\Drake\Downloads\Inter_Clan_Games_2026 (10).xlsx"
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def col_num(ref):
    m = re.match(r"([A-Z]+)(\d+)", ref)
    col, row = m.group(1), int(m.group(2))
    n = 0
    for ch in col:
        n = n * 26 + (ord(ch) - 64)
    return row, n


def col_letter(n):
    s = ""
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


with zipfile.ZipFile(XLSX) as z:
    ss = []
    root = ET.fromstring(z.read("xl/sharedStrings.xml"))
    for si in root.findall(".//m:si", NS):
        t = "".join(
            t.text or ""
            for t in si.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t")
        )
        ss.append(t)

    wb = ET.fromstring(z.read("xl/workbook.xml"))
    sheets = [
        (sh.get("name"),
         sh.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"))
        for sh in wb.findall(".//m:sheet", NS)
    ]
    rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    rid_map = {r.get("Id"): r.get("Target") for r in rels}

    def cell_val(c):
        t = c.get("t")
        v = c.find("m:v", NS)
        if v is None:
            return ""
        if t == "s":
            return ss[int(v.text)]
        return v.text

    print("### SHEETS:", [n for n, _ in sheets])

    for name, rid in sheets:
        print("\n\n========== SHEET:", name, "==========")
        target = rid_map[rid]
        if not target.startswith("xl/"):
            target = "xl/" + target.lstrip("/")
        ws = ET.fromstring(z.read(target))
        grid = defaultdict(dict)
        maxrow = 0
        maxcol = 0
        for c in ws.findall(".//m:c", NS):
            row, coln = col_num(c.get("r"))
            grid[row][coln] = cell_val(c)
            maxrow = max(maxrow, row)
            maxcol = max(maxcol, coln)
        for r in range(1, maxrow + 1):
            vals = [grid[r].get(cn, "") for cn in range(1, maxcol + 1)]
            if any(str(v).strip() for v in vals):
                print(f"R{r}: " + " | ".join(repr(v) for v in vals))
