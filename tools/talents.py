#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/TalentSpells.lua from the client's own Talent and TalentTab tables.

Talents were the one thing Family stored as a word instead of an id, and the reason was
sound while it stood: GetTalentInfo answers only for the class you are playing, so a mage
cannot ask what the third talent in a warlock's second tree is called - and showing another
member's talents is the whole point of that panel. A member recorded on a German client
therefore showed German talent names on an English one.

What breaks the deadlock is that a talent *is* a spell. `Talent.SpellRank_0` is the spell id
of its first rank, and the client answers about any spell id, for any class, without loading
anything first (DATASOURCES section 2). So the table below carries no names at all: it maps a
talent's position to a spell id, and every reader's own client says what that spell is called -
in all eleven languages the game ships in rather than the five Family writes.

    tools/talents.py --fetch     download the CSVs into a cache
    tools/talents.py             build the Lua from what is cached

Two things measured rather than assumed, both of which decide the shape of this:

  The client counts tiers and columns from one and the table counts from zero. Taken from
  Family_UI/Talents.lua, which places a cell at (tier - 1) * CELL and draws a grid that has
  been looked at in the game.

  Era and Burning Crusade disagree about 32 of the 419 positions they share - Blizzard moved
  talents between them - so one merged table would name 32 talents wrongly on one of the two
  clients. They are kept apart, keyed by expansion, which Family.Capabilities already knows
  from the interface number.

Mists is here too, in a shape of its own. Its talents are six tiers of three chosen one from
each and carry an id the client reports, which Family records - so there is no position to key
on and none is needed: the id maps straight to a spell. It uses `SpellID` rather than
`SpellRank_0`, which is the other way round from Era and Burning Crusade and is measured, not
assumed - the ranked column is zero for a third of the Mists rows and set for every one of the
Era ones.
"""

import csv, io, os, sys, urllib.request

BUILDS = {
    # expansion number, as Family.Capabilities derives it from the interface version
    1: ("Classic Era", "1.15.9.69109"),
    2: ("Burning Crusade Anniversary", "2.5.6.69110"),
}

# Mists is a different system and needs a different table. Its talents are six tiers of three
# with an id of their own, which the client reports and Family records - so it needs no
# position at all, only that id turned into the spell it is.
MISTS = ("Mists of Pandaria Classic", "5.5.4.69078")

TABLES = ["Talent", "TalentTab", "ChrClasses"]

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".talents-cache")


def path_for(table, build):
    return os.path.join(CACHE, "%s-%s.csv" % (table, build))


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for game, build in [MISTS]:
        target = path_for("Talent", build)
        if os.path.exists(target) and os.path.getsize(target) > 0:
            print("  have   %s Talent" % game)
        else:
            print("  fetch  %s Talent" % game)
            with urllib.request.urlopen(
                    "https://wago.tools/db2/Talent/csv?build=%s&locale=enUS" % build,
                    timeout=300) as response:
                open(target, "wb").write(response.read())

    for _, (game, build) in BUILDS.items():
        for table in TABLES:
            target = path_for(table, build)
            if os.path.exists(target) and os.path.getsize(target) > 0:
                print("  have   %s %s" % (game, table))
                continue
            url = ("https://wago.tools/db2/%s/csv?build=%s&locale=enUS" % (table, build))
            print("  fetch  %s %s" % (game, table))
            with urllib.request.urlopen(url, timeout=300) as response:
                open(target, "wb").write(response.read())


def rows_of(table, build):
    target = path_for(table, build)
    if not os.path.exists(target) or os.path.getsize(target) == 0:
        return None
    return list(csv.DictReader(io.StringIO(open(target, encoding="utf-8").read())))


def build_table():
    # expansion -> class file string -> tab -> tier -> column -> spell id
    out = {}
    complaints = []

    for expansion, (game, build) in BUILDS.items():
        talents = rows_of("Talent", build)
        tabs = rows_of("TalentTab", build)
        classes = rows_of("ChrClasses", build)

        if not (talents and tabs and classes):
            complaints.append("missing tables for %s" % game)
            continue

        # The class's own file string, which is what UnitClass answers with and what Family
        # records. Read from the client's table rather than from a list somebody remembered.
        by_class = {row["ID"]: row["Filename"] for row in classes}

        # A tab's place in its class's row of three. OrderIndex counts from zero and the
        # client's tab number counts from one.
        order = {row["ID"]: int(row["OrderIndex"]) + 1 for row in tabs}

        here = {}
        for row in talents:
            spell = row["SpellRank_0"]
            if not spell or spell == "0":
                continue

            name = by_class.get(row["ClassID"])
            tab = order.get(row["TabID"])
            if not name or not tab:
                continue

            # Both counted from one, as the client counts them and as the panel draws them.
            tier = int(row["TierID"]) + 1
            column = int(row["ColumnIndex"]) + 1

            here.setdefault(name, {}).setdefault(tab, {}).setdefault(tier, {})[column] = \
                int(spell)

        out[expansion] = here

    return out, complaints


def mists_table():
    """Mists talents, by the id the client reports them under.

    A different shape from the two above, because it is a different system: six tiers of three
    with an id of its own, so there is no position to key on and none is needed. SpellID rather
    than SpellRank_0 - the ranked column is zero for a third of these rows and SpellID is set
    for every one of them, which is the other way round from Era and Burning Crusade.
    """
    rows = rows_of("Talent", MISTS[1])
    if not rows:
        return {}, ["missing Talent for %s" % MISTS[0]]

    out = {}
    for row in rows:
        spell = row["SpellID"]
        if spell and spell != "0":
            out[int(row["ID"])] = int(spell)
    return out, []


def disagreements(out):
    """Where two expansions put different talents in the same place.

    Not a fault and not fixable - it is what Blizzard did - but it is the whole reason these
    are two tables instead of one, so a run says how many there are. A run that suddenly
    reports none has probably stopped reading one of the builds.
    """
    found = []
    if 1 not in out or 2 not in out:
        return found
    for name, tabs in out[1].items():
        for tab, tiers in tabs.items():
            for tier, columns in tiers.items():
                for column, spell in columns.items():
                    other = (out[2].get(name, {}).get(tab, {}).get(tier, {}).get(column))
                    if other and other != spell:
                        found.append("%s tab %d tier %d column %d: %d on Era, %d on Burning "
                                     "Crusade" % (name, tab, tier, column, spell, other))
    return found


ACCESSORS = """
-- What to call a talent, in the language of whoever is reading.
--
-- The position is what Family records - which tree, which tier, which column - and the table
-- above turns that into the spell the talent is. The client will name any spell, for any
-- class, which is the whole reason this works where asking about the talent itself does not.
--
-- Falls back to the word the recording client wrote, which is what every record made before
-- this table existed carries, and is still better than a blank.
function Family:TalentName(classFile, tab, tier, column, recorded)
\tlocal expansion = Family.Capabilities and Family.Capabilities.expansion
\tlocal byClass = expansion and Family.TalentSpells[expansion]
\tlocal tabs = byClass and classFile and byClass[classFile]
\tlocal tiers = tabs and tab and tabs[tab]
\tlocal columns = tiers and tier and tiers[tier]
\tlocal id = columns and column and columns[column]

\tif id then
\t\tlocal name = Family.Names:Spell(id)
\t\tif type(name) == "string" and name ~= "" then return name end
\tend

\treturn recorded
end

-- The same question on Mists, where a talent has an id of its own and needs no position at
-- all: the id is the spell. The client names any spell for any class, so this is the same
-- answer as the grid above by a shorter road.
function Family:TalentNameByID(id, recorded)
\tlocal spell = id and Family.TalentSpellByID[id]
\tif spell then
\t\tlocal name = Family.Names:Spell(spell)
\t\tif type(name) == "string" and name ~= "" then return name end
\tend
\treturn recorded
end
"""


def emit(out, mists, path):
    lines = []
    add = lines.append
    add('-- Family - an alt manager for World of Warcraft Classic')
    add('-- Copyright (C) 2026 Alberto Pittaluga')
    add('--')
    add('-- This program is free software: you can redistribute it and/or modify it under the')
    add('-- terms of the GNU General Public License as published by the Free Software')
    add('-- Foundation, either version 3 of the License, or (at your option) any later version.')
    add('-- See the LICENSE file at the root of this repository.')
    add('')
    add('-- Which spell each talent is. GENERATED - see tools/talents.py.')
    add('--')
    add('-- Talents were the one thing Family stored as a word rather than an id, because')
    add('-- GetTalentInfo answers only for the class being played: a mage cannot ask what the')
    add("-- third talent in a warlock's second tree is called, and showing another member's")
    add('-- talents is the whole point of that panel. So a member recorded on a German client')
    add('-- showed German talent names on an English one.')
    add('--')
    add('-- A talent is a spell, and the client will name any spell for any class without')
    add('-- loading anything first. So there are no names here at all: a position maps to the')
    add("-- spell id of the talent's first rank, and every reader's own client says what it is")
    add('-- called - in all eleven languages the game ships in, not the five Family writes.')
    add('--')
    add('-- Mists is the same idea in a different shape and is below, keyed by the talent id')
    add('-- its client reports rather than by a position: it is six tiers of three chosen one')
    add('-- from each, and the id is what Family records.')
    add('--')
    add('-- Keyed by expansion, because Era and Burning Crusade disagree about 32 of the 419')
    add('-- positions they share: Blizzard moved talents between them, and one merged table')
    add('-- would name those 32 wrongly on one of the two clients.')
    add('--')
    add('-- Tiers and columns count from one here, as the client reports them and as the panel')
    add('-- draws them. The table they came from counts from zero.')
    add('')
    add('local _, Family = ...')
    add('')
    add('Family.TalentSpells = {')

    for expansion in sorted(out):
        game = BUILDS[expansion][0]
        add('\t-- %s' % game)
        add('\t[%d] = {' % expansion)
        for name in sorted(out[expansion]):
            add('\t\t%s = {' % name)
            for tab in sorted(out[expansion][name]):
                add('\t\t\t[%d] = {' % tab)
                for tier in sorted(out[expansion][name][tab]):
                    columns = out[expansion][name][tab][tier]
                    inline = ", ".join("[%d] = %d" % (c, columns[c]) for c in sorted(columns))
                    add('\t\t\t\t[%d] = { %s },' % (tier, inline))
                add('\t\t\t},')
            add('\t\t},')
        add('\t},')
    add('}')
    add('')
    add('-- Mists, by the id the client reports. SpellID rather than the ranked column, which')
    add('-- is zero for a third of these rows where it is set for every one of them - the')
    add('-- other way round from the two tables above.')
    add('Family.TalentSpellByID = {')
    for talent in sorted(mists):
        add('\t[%d] = %d,' % (talent, mists[talent]))
    add('}')
    add('')
    add('-' * 92)
    add('')
    add(ACCESSORS.strip())
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()

    out, complaints = build_table()
    mists, more = mists_table()
    complaints.extend(more)
    if complaints:
        print("\n".join("  ! " + c for c in complaints))
    if not out:
        print("nothing built - run with --fetch first")
        sys.exit(1)

    moved = disagreements(out)
    print("%d position(s) hold a different talent on the two builds, which is why they are "
          "two tables" % len(moved))
    for line in moved[:5]:
        print("  . " + line)

    target = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "..", "addons", "Family", "TalentSpells.lua")
    emit(out, mists, os.path.normpath(target))
    print("%d Mists talents, by id" % len(mists))
    total = sum(len(c) for e in out.values() for t in e.values()
                for ti in t.values() for c in [ti])
    print("%d expansions -> addons/Family/TalentSpells.lua" % len(out))
