"""Generate lib/data/inter_clan_fixture_seed.dart from the verified spreadsheet."""
import zipfile
import xml.etree.ElementTree as ET
import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path

XLSX = Path(r"C:\Users\Drake\Downloads\Inter_Clan_Games_2026 (10).xlsx")
OUT = Path(__file__).resolve().parent.parent / "lib" / "data" / "inter_clan_fixture_seed.dart"
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def main():
    fixtures = []
    with zipfile.ZipFile(XLSX) as z:
        ss = []
        root = ET.fromstring(z.read("xl/sharedStrings.xml"))
        for si in root.findall(".//m:si", NS):
            t = "".join(
                t.text or ""
                for t in si.iter(
                    "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t"
                )
            )
            ss.append(t)

        wb = ET.fromstring(z.read("xl/workbook.xml"))
        sheets = [
            (
                sh.get("name"),
                sh.get(
                    "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
                ),
            )
            for sh in wb.findall(".//m:sheet", NS)
        ]
        rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
        rid_to_target = {r.get("Id"): r.get("Target") for r in rels}

        def col_row(cell_ref):
            m = re.match(r"([A-Z]+)(\d+)", cell_ref)
            return m.group(1), int(m.group(2))

        def cell_val(c):
            t = c.get("t")
            v = c.find("m:v", NS)
            if v is None:
                return ""
            if t == "s":
                return ss[int(v.text)]
            return v.text

        for name, rid in sheets:
            if name != "Results Entry":
                continue
            target = rid_to_target[rid]
            if not target.startswith("xl/"):
                target = "xl/" + target.lstrip("/")
            ws = ET.fromstring(z.read(target))
            rows = defaultdict(dict)
            for c in ws.findall(".//m:c", NS):
                col, row = col_row(c.get("r"))
                rows[row][col] = cell_val(c)
            for r in sorted(rows):
                if r < 3:
                    continue
                row = rows[r]
                vals = [row.get(c, "") for c in ["A", "B", "C", "D", "E", "F", "G"]]
                if not vals[0]:
                    continue
                md = int(vals[0])
                dt = datetime.strptime(vals[1], "%d-%b-%Y")
                game = vals[2]
                category = vals[3]
                slot = vals[4]
                team_a = vals[5]
                team_b = vals[6]
                if "Team" in category:
                    ts = (
                        "FixtureTimeSlot.slot1_4pm"
                        if "Slot 1" in slot
                        else "FixtureTimeSlot.slot2_5pm"
                    )
                    cat = "GameCategory.teamSport"
                else:
                    ts = "FixtureTimeSlot.mind_3pm"
                    cat = "GameCategory.mindGame"
                slot_suffix = (
                    "g1" if "Group 1" in slot or "Slot 1" in slot else "g2"
                )
                fid = f"md{md}-{game.lower()}-{slot_suffix}"
                fixtures.append(
                    (fid, md, dt, game, cat, ts, slot, team_a, team_b)
                )

    lines = [
        "// AUTO-GENERATED from Inter_Clan_Games_2026 (10).xlsx Results Entry sheet.",
        "// DO NOT regenerate fixtures algorithmically — edit only if the spreadsheet changes.",
        "",
        "import '../models/tournament_model.dart';",
        "",
        "class InterClanFixtureSeed {",
        "  static List<Map<String, dynamic>> get rawFixtures => _fixtures;",
        "",
        "  static List<TournamentFixture> build(String tournamentId) {",
        "    return _fixtures.map((f) {",
        "      final parts = (f['date'] as String).split('-');",
        "      final date = DateTime(",
        "        int.parse(parts[0]),",
        "        int.parse(parts[1]),",
        "        int.parse(parts[2]),",
        "      );",
        "      return TournamentFixture(",
        "        id: f['id'] as String,",
        "        tournamentId: tournamentId,",
        "        game: f['game'] as String,",
        "        matchDay: f['matchDay'] as int,",
        "        round: f['matchDay'] as int,",
        "        category: f['category'] as GameCategory,",
        "        timeSlot: f['timeSlot'] as FixtureTimeSlot,",
        "        stage: f['stage'] as String,",
        "        date: date,",
        "        homeClan: f['homeClan'] as String,",
        "        awayClan: f['awayClan'] as String,",
        "      );",
        "    }).toList();",
        "  }",
        "",
        "  static const _fixtures = [",
    ]
    for fid, md, dt, game, cat, ts, slot, ta, tb in fixtures:
        lines.append(
            "    {"
            f"'id': '{fid}', 'matchDay': {md}, 'date': '{dt.strftime('%Y-%m-%d')}', "
            f"'game': '{game}', 'category': {cat}, 'timeSlot': {ts}, "
            f"'stage': '{slot}', 'homeClan': '{ta}', 'awayClan': '{tb}'"
            "},"
        )
    lines.extend(["  ];", "}", ""])

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {len(fixtures)} fixtures to {OUT}")


if __name__ == "__main__":
    main()
