#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/WorldBuffs.lua - the icon a world buff draws, back to its spell.

A Chronoboon holds world buffs, and what it holds is readable only as tooltip text
(DATASOURCES.md section 2). A row of that text looks like

    |T134153:24|t |cffffffffRallying Cry of the Dragonslayer (120m)|r

so the two things in it that are not English are the **icon's fileID** and the number of
minutes. Family records those two and nothing else: a fileID is an identifier, is the same
on every build that has the buff, and is distinct for each of the twelve a boon can hold.

**Nothing that records needs this table.** The scanner reads the fileID out of the escape and
stores an integer, so a thirteenth world buff added by Blizzard is recorded correctly by a
client nobody has regenerated. This table exists only so that a panel can put a *name* under
the icon, and the name itself is not in here either - the client is asked for it at draw time,
which is how it comes out in the language the player is reading.

The twelve were found by searching the client's own SpellName for the names Wowhead renders in
the Chronoboon's conditional block; the ids below are pinned from that search and the search is
re-run here as a check, so a bad pin is a failure rather than a silently wrong icon.

    tools/world-buffs.py --fetch     download the CSVs into a cache
    tools/world-buffs.py             build the Lua from what is cached

Re-run at a new build. It refuses rather than guesses: a name that no longer matches its id, or
two buffs sharing an icon, stops the build instead of emitting a table that would file one buff
under another's picture.
"""

import csv, io, os, sys, urllib.request

# wago.tools answers 403 to Python's default User-Agent, measured 2026-08-30 - see L-024 and
# the note in tools/charged-items.py.
AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}

# Pinned id, and the English name it must still carry. The name is the check, not the data:
# nothing below it is ever written to the Lua.
#
# Sayge's Dark Fortune is eight spells sharing one icon, so the icon says *a* Sayge's and not
# which one. One of the eight is pinned to stand for the family; any of them would give the
# same fileID, which is the whole reason this is keyed by icon.
BUFFS = [
    (22817,  "Fengus' Ferocity"),
    (22818,  "Mol'dar's Moxie"),
    (22820,  "Slip'kik's Savvy"),
    (22888,  "Rallying Cry of the Dragonslayer"),
    (16609,  "Warchief's Blessing"),
    (24425,  "Spirit of Zandalar"),
    (15366,  "Songflower Serenade"),
    (23768,  "Sayge's Dark Fortune of Damage"),
    # Season of Discovery, and on Classic Era alone - measured, not assumed.
    (430947, "Boon of Blackfathom"),
    (438536, "Spark of Inspiration"),
    (446695, "Fervor of the Temple Explorer"),
    (460939, "Might of Stormwind"),
]

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".world-buffs-cache")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "addons", "Family", "WorldBuffs.lua")


def path_for(table, build):
    return os.path.join(CACHE, "%s-%s.csv" % (table, build))


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for game, build in BUILDS.items():
        for table in ("SpellName", "SpellMisc"):
            target = path_for(table, build)
            if os.path.exists(target):
                print("  have   %s %s" % (game, table))
                continue
            url = "https://wago.tools/db2/%s/csv?build=%s" % (table, build)
            print("  fetch  %s %s" % (game, table))
            request = urllib.request.Request(url, headers={"User-Agent": AGENT})
            data = urllib.request.urlopen(request, timeout=300).read()
            open(target, "wb").write(data)


def read(table, build):
    with open(path_for(table, build), encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def build():
    icons, seen_in = {}, {}

    # A pin repeated is a buff missing. The table is keyed by what comes back from the client,
    # so two rows naming one spell collapse into one entry and the result is a table that is
    # one short and says nothing about it - caught here rather than by counting rows later.
    pinned, named = {}, {}
    for spell, english in BUFFS:
        if spell in pinned:
            sys.exit("spell %d is pinned twice, as %r and as %r"
                     % (spell, pinned[spell], english))
        if english in named:
            sys.exit("%r is pinned twice, as spell %d and as spell %d"
                     % (english, named[english], spell))
        pinned[spell], named[english] = english, spell

    for game, build_id in BUILDS.items():
        names = {int(row["ID"]): row["Name_lang"] for row in read("SpellName", build_id)}

        misc, column = {}, None
        for row in read("SpellMisc", build_id):
            spell = int(row.get("SpellID") or 0)
            if not spell:
                continue
            misc[spell] = row
            if column is None:
                found = [key for key in row if "Icon" in key]
                if not found:
                    sys.exit("SpellMisc on %s has no icon column" % game)
                column = found[0]

        for spell, english in BUFFS:
            if spell not in names:
                # Absent is a fact about the build, not a fault: four of the twelve are
                # Season of Discovery and exist on Classic Era alone.
                continue
            if names[spell] != english:
                sys.exit("%s: spell %d is %r and the pin says %r"
                         % (game, spell, names[spell], english))

            icon = int((misc.get(spell) or {}).get(column) or 0)
            if not icon:
                sys.exit("%s: spell %d has no icon" % (game, spell))

            if spell in icons and icons[spell] != icon:
                sys.exit("spell %d draws icon %d on %s and %d elsewhere - the key is not "
                         "build-independent and this table cannot be a union"
                         % (spell, icon, game, icons[spell]))

            icons[spell] = icon
            seen_in.setdefault(spell, []).append(game)

    # Two buffs sharing an icon would file one under the other's picture, silently. The whole
    # design rests on this being false, so it is a failure and not a warning.
    owner = {}
    for spell, icon in icons.items():
        if icon in owner:
            sys.exit("icon %d is drawn by spell %d and by spell %d - the icon cannot be the "
                     "key" % (icon, owner[icon], spell))
        owner[icon] = spell

    lines = [
        "-- Generated by tools/world-buffs.py. Do not edit.",
        "--",
        "-- The icon a world buff draws, back to the spell that draws it. A Chronoboon's",
        "-- contents are tooltip text and the only identifier in a row is the icon's fileID",
        "-- (DATASOURCES.md section 2), so this is what turns a recorded fileID into a name -",
        "-- by asking the client for the spell, in whatever language it is running in.",
        "--",
        "-- Nothing that *records* reads this table. A world buff Blizzard adds tomorrow is",
        "-- recorded correctly by a client that has never seen a regenerated copy of it; it",
        "-- would simply be drawn as its own icon with no name under it until this is re-run.",
        "",
        "local _, Family = ...",
        "",
        "Family.WorldBuffs = {",
    ]
    for spell, english in BUFFS:
        if spell not in icons:
            continue
        where = "all three builds" if len(seen_in[spell]) == len(BUILDS) \
            else ", ".join(seen_in[spell])
        lines.append("\t[%d] = %d, -- %s, %s" % (icons[spell], spell, english, where))
    lines.append("}")
    lines.append("")

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    print("  %d buffs, %d icons, all distinct" % (len(icons), len(owner)))
    for spell, english in BUFFS:
        if spell in icons:
            print("    %-38s spell %-7d icon %d (%s)"
                  % (english, spell, icons[spell], ", ".join(seen_in[spell])))
        else:
            print("    %-38s absent from every pinned build" % english)


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    build()
