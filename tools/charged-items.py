#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/ChargedItems.lua from the client's own ItemEffect table.

An item with charges - a Wizard Oil, a Bag of Marbles - does not say how many are left
through any container call. `GetContainerItemInfo` returns twelve fields on Mists and
`stackCount` is 1, not the charge count, measured 2026-08-30 (DATASOURCES.md section 2).
The remaining count is only in the tooltip, behind ITEM_SPELL_CHARGES.

Reading a tooltip per bag slot is not free, and a bag is eighty slots of mostly cloth. So
this generates the set of items that *can* carry more than one charge, and the scanner
reads a tooltip only for a slot holding one of them. `ItemEffect.Charges` is where the
maximum lives; it is negative by the game's own convention, meaning the use spends one.

**Items with exactly one charge are left out on purpose.** There are four to ten thousand
of them per build - every potion and scroll in the game - they show no charges line at all,
and including them would mean tooltipping half of every bag to learn nothing.

The data is Blizzard's own, served per build by wago.tools, whose builds and licence
position DATASOURCES.md section 3 already sets out.

    tools/charged-items.py --fetch     download the CSVs into a cache
    tools/charged-items.py             build the Lua from what is cached

Re-run at a new build. The report says how many ids each build contributed and how many
were new, which is the only signal that the table has gone stale.
"""

import csv, io, os, sys, urllib.request

# wago.tools answers 403 to Python's default User-Agent, measured 2026-08-30 - see L-024 and
# the note in tools/skill-lines.py. The fetch path is only reached at a new build, which is
# exactly when nobody wants to be debugging the fetcher.
AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}

# Two or more. One is every consumable in the game and shows no charge line.
LEAST = 2

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".charged-items-cache")


def path_for(build):
    return os.path.join(CACHE, "ItemEffect-%s.csv" % build)


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for game, build in BUILDS.items():
        target = path_for(build)
        if os.path.exists(target):
            print("  have   %s" % game)
            continue
        url = "https://wago.tools/db2/ItemEffect/csv?build=%s" % build
        print("  fetch  %s" % game)
        request = urllib.request.Request(url, headers={"User-Agent": AGENT})
        with urllib.request.urlopen(request, timeout=300) as response:
            open(target, "wb").write(response.read())


def build_table():
    """Every item id that can carry two or more charges, on any build, with the largest
    number of charges seen for it.

    The union rather than a table per build: an id means the same item everywhere it
    exists, the set is small, and a per-build table would have to be chosen between at
    runtime by a client check this project does not make.
    """
    charges, seen, report = {}, {}, []

    for game, build in BUILDS.items():
        path = path_for(build)
        if not os.path.exists(path):
            report.append("%s: nothing cached" % game)
            continue

        rows = csv.DictReader(io.StringIO(open(path, encoding="utf-8").read()))
        found, fresh = 0, 0
        for row in rows:
            item = (row.get("ParentItemID") or "").strip()
            if not item or item == "0":
                continue
            try:
                count = abs(int(row.get("Charges") or 0))
            except ValueError:
                continue
            if count < LEAST:
                continue

            found += 1
            if item not in charges:
                fresh += 1
            if count > charges.get(item, 0):
                charges[item] = count
            seen.setdefault(item, []).append(game)

        report.append("%-28s %4d with %d+ charges, %4d of them new"
                      % (game, found, LEAST, fresh))

    return charges, report


HEADER = """-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Which items can carry more than one charge. GENERATED - see tools/charged-items.py.
--
-- No container call says how many charges are left: GetContainerItemInfo answers twelve
-- fields and stackCount is 1, not the count (DATASOURCES section 2). The remaining number
-- is only in the tooltip, behind ITEM_SPELL_CHARGES, and reading a tooltip per slot is not
-- free when a bag is eighty slots of mostly cloth.
--
-- So this is the gate: a slot whose item is not in here is never tooltipped. The value is
-- the largest maximum seen across the three builds, which is not what is displayed - what
-- is displayed is read from the item in the bag - but it says what to expect and makes the
-- table readable by a person.
--
-- **Items with exactly one charge are deliberately absent.** Four to ten thousand per build,
-- every potion and scroll in the game, and they show no charges line at all.
--
-- The union of the three builds rather than one table each: an id means the same item
-- wherever it exists, the set is small, and choosing between per-build tables would need a
-- client check this project does not make.
"""


def emit(charges, out_path):
    lines = [HEADER.rstrip(), ""]
    lines.append("local _, Family = ...")
    lines.append("")
    lines.append("Family.ChargedItems = {")

    # By id, so a diff between two builds reads as a list of what was added.
    for item in sorted(charges, key=int):
        lines.append("\t[%s] = %d," % (item, charges[item]))

    lines.append("}")
    open(out_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()

    charges, report = build_table()
    print("\n".join("  . " + line for line in report))

    if not charges:
        print("nothing built - run with --fetch first")
        sys.exit(1)

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "addons", "Family", "ChargedItems.lua")
    emit(charges, os.path.normpath(out))
    print("%d items -> addons/Family/ChargedItems.lua" % len(charges))
