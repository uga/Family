#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/MountSpeeds.lua - how fast a mount goes, by the spell that summons it.

Asked for from play: *has this alt got a mount, and is it the fast one?* Family already records
what it needs to answer - the spellbook by spell id and the bags by item id - and had nothing
that said what those ids mean.

WHY THE SPELL AND NOT THE RIDING SKILL
--------------------------------------

The riding skill looks like the answer and is not, and Classic Era is where that shows. There the
skill is a **permission**: its value is always 300 once you have it, a character can hold several
of them - a human exalted with Darnassus buys tiger riding and then a tiger - and a paladin or a
warlock has a mount from a class spell that teaches no riding skill at all. A panel keyed on the
skill would print "cannot ride" over a paladin on a horse.

From Burning Crusade the skill does become the ladder, but the mount is still the evidence: a
character with epic flying owns a 280% mount, and that mount is in this table. So one key works
on every build and the panel needs no branch.

WHAT IS READ, AND THE ONE THING THAT DIFFERS BETWEEN BUILDS
-----------------------------------------------------------

`SpellEffect`, effect 6 (apply aura) with aura 32 (mounted speed). The percentage is in
`EffectBasePoints`, and the convention is **not** the same on every build: Era and Burning Crusade
store 59 for +60%, Mists stores 60. Measured, and it is the whole reason the three builds appeared
to disagree about seven mounts - they agree exactly once the off-by-one is applied per build.

Anything under 50% is dropped. Those are not mounts: they are the other speed auras that share the
same aura number, and they measured at 0, 1, 10, 15, 20, 25 and 40. A real mount has never been
slower than 60%.

`ItemEffect` gives the item that casts each of those spells, which is what a mount is in the bags
on Classic Era.

    tools/mounts.py --fetch     download what is missing into a cache
    tools/mounts.py             build the Lua from what is cached
"""

import csv, os, shutil, sys, urllib.request

AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}

APPLY_AURA = 6
MOUNTED_SPEED = 32

# Era and Burning Crusade store one less than the percentage; Mists stores the percentage.
BUMP = {"Classic Era": 1, "Burning Crusade Anniversary": 1, "Mists of Pandaria Classic": 0}

# Below this it is not a mount. Measured: the values that fall out are 0, 1, 10, 15, 20, 25 and
# 40, all of them other things wearing the same aura.
SLOWEST_MOUNT = 50

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".mounts-cache")
OUT = os.path.join(HERE, "..", "addons", "Family", "MountSpeeds.lua")

BORROW = {
    "SpellEffect": (os.path.join(HERE, ".made-by-item-cache"), "SpellEffect-%(build)s.csv"),
    "ItemEffect": (os.path.join(HERE, ".made-by-item-cache"), "ItemEffect-%(build)s.csv"),
}
TABLES = ["SpellEffect", "ItemEffect"]


def path_for(table, build):
    return os.path.join(CACHE, "%s-%s.csv" % (table, build))


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for game, build in BUILDS.items():
        for table in TABLES:
            target = path_for(table, build)
            if os.path.exists(target):
                print("  have     %s %s" % (game, table))
                continue
            folder, shape = BORROW[table]
            source = os.path.join(folder, shape % {"build": build})
            if os.path.exists(source):
                shutil.copyfile(source, target)
                print("  borrowed %s %s" % (game, table))
                continue
            url = "https://wago.tools/db2/%s/csv?build=%s" % (table, build)
            print("  fetch    %s %s" % (game, table))
            request = urllib.request.Request(url, headers={"User-Agent": AGENT})
            open(target, "wb").write(urllib.request.urlopen(request, timeout=900).read())


def read(table, build):
    with open(path_for(table, build), encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def build():
    speeds, items, dropped = {}, {}, 0

    for game, build_id in BUILDS.items():
        here = {}
        for row in read("SpellEffect", build_id):
            if int(row.get("Effect") or 0) != APPLY_AURA:
                continue
            if int(row.get("EffectAura") or 0) != MOUNTED_SPEED:
                continue

            spell = int(row["SpellID"])
            percent = int(row.get("EffectBasePoints") or 0) + BUMP[game]
            if percent > here.get(spell, 0):
                here[spell] = percent

        kept = 0
        for spell, percent in here.items():
            if percent < SLOWEST_MOUNT:
                continue
            kept += 1
            # The builds agree once the convention above is applied; where one of them still
            # differs the faster reading wins, so a mount is never reported slower than it is.
            if percent > speeds.get(spell, 0):
                speeds[spell] = percent

        dropped += len(here) - kept
        print("  %-30s %4d mounted-speed spells, %4d of them mounts"
              % (game, len(here), kept))

        for row in read("ItemEffect", build_id):
            spell = int(row.get("SpellID") or 0)
            item = int(row.get("ParentItemID") or 0)
            if item and spell in speeds:
                items[item] = spell

    if not speeds:
        sys.exit("nothing came out at all - the aura number has moved, and an empty table "
                 "would look like a quiet success")

    lines = [
        "-- How fast a mount goes, by the spell that summons it. GENERATED - see tools/mounts.py.",
        "--",
        "-- The question is *has this alt got a mount, and is it the fast one*, and Family already",
        "-- records both halves of the answer: the spellbook by spell id, the bags by item id.",
        "-- This is what those ids mean.",
        "--",
        "-- Keyed on the mount and not on the riding skill, which is what Classic Era makes",
        "-- obvious: there the skill is a permission whose value is always 300, a character can",
        "-- hold several, and a paladin's or a warlock's mount teaches no riding skill at all - so",
        "-- a panel keyed on the skill would print \"cannot ride\" over a paladin on a horse. From",
        "-- Burning Crusade the skill is the ladder, but the mount is still the evidence, so one",
        "-- key works on every build and the panel needs no branch.",
        "--",
        "-- Percentages, and the builds do not store them the same way: Era and Burning Crusade",
        "-- keep one less than the number, Mists keeps the number. Applied per build here, which",
        "-- is why the three agree.",
        "",
        "local _, Family = ...",
        "",
        "-- summoning spell -> how much faster than running",
        "Family.MountSpeeds = {",
    ]
    for spell in sorted(speeds):
        lines.append("\t[%d] = %d," % (spell, speeds[spell]))
    lines += ["}", ""]

    lines += [
        "-- the item that casts one -> that spell",
        "--",
        "-- Which is what a mount is in the bags on Classic Era, where it is carried rather than",
        "-- learned.",
        "Family.MountItems = {",
    ]
    for item in sorted(items):
        lines.append("\t[%d] = %d," % (item, items[item]))
    lines += ["}", ""]

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    print("\n  %d mounts, %d of them carried as an item, %d speed auras dropped as not mounts"
          % (len(speeds), len(items), dropped))


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    build()
