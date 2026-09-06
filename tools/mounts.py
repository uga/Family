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

# Flying is a second number on the same spell, not a faster mount. An Ebon Gryphon carries aura 32
# at +60% for the ground and aura 207 at +60% for the air, and an epic flyer carries 100 and 280.
# Reading only the first is what made a character with a gryphon and an epic ground mount report
# 100% and say nothing about being able to fly at all - reported from play 2026-09-06.
#
# Measured: Era has none of these at all, which is right - there is no flying in vanilla. Burning
# Crusade has 49, at 60%, 280% and **310%**, that last being the rare ones. Mists adds 150% and
# 500%.
FLIGHT_SPEED = 207

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

# From Cataclysm the mount stopped carrying its speed and the riding skill started carrying all of
# it. Alberto asked whether Master Riding upgrades the mounts you already own; MountCapability says
# it does, and MountTypeXCapability says the same thing from the other side - a mount has a type,
# and the type is what holds the rungs. The ground type has rungs for riding 75 and 150 and none
# above; the flying type has all five. So there is no such thing as a 310% mount: a flyer bought at
# Expert flies at 150% and that same flyer flies at 310% once Master Riding is learned.
#
# Read only from the build that works this way. Era and Burning Crusade have no such table and want
# none: there the mount carries the speed and this file's first two tables answer.
LADDER_TABLES = ["MountCapability", "MountTypeXCapability", "Mount"]
LADDER_BUILDS = {"Mists of Pandaria Classic"}

MOUNTED_SPEED_AURA = 32


def ladder_of(build_id, effects):
    """The five rungs, and which mount types can use the flying ones."""
    caps, ladder = {}, {}

    for row in read("MountCapability", build_id):
        rank = int(row.get("ReqRidingSkill") or 0)
        aura = int(row.get("ModSpellAuraID") or 0)

        ground = air = 0
        for kind, points in effects.get(aura, ()):
            if kind == MOUNTED_SPEED_AURA:
                ground = max(ground, points)
            elif kind == FLIGHT_SPEED:
                air = max(air, points)
        caps[row["ID"]] = (rank, ground, air)

        if not rank:
            continue

        # The base rungs are the ones with no condition on them at all. The rest are variants -
        # a particular zone, a particular aura known - and several of them carry a different
        # ground speed, which is what made a first pass read Expert as 150% on the ground.
        if (row.get("ReqMapID") not in ("-1", "") or row.get("ReqAreaID") not in ("0", "")
                or row.get("ReqSpellAuraID") not in ("0", "")
                or row.get("ReqSpellKnownID") not in ("0", "")
                or row.get("PlayerConditionID") not in ("0", "")):
            continue

        # And where two unconditioned rows share a rank, the lower id is the original - the
        # same tie-break Names:AreaFor keeps, and for the same reason.
        held = ladder.get(rank)
        if held is None or int(row["ID"]) < held[0]:
            ladder[rank] = (int(row["ID"]), ground, air)

    flying_types = set()
    for row in read("MountTypeXCapability", build_id):
        if caps.get(row["MountCapabilityID"], (0, 0, 0))[2] > 0:
            flying_types.add(row["MountTypeID"])

    flies = {}
    for row in read("Mount", build_id):
        spell = int(row.get("SourceSpellID") or 0)
        if spell and row.get("MountTypeID") in flying_types:
            flies[spell] = True

    return {rank: (g, a) for rank, (_, g, a) in ladder.items()}, flies


def path_for(table, build):
    return os.path.join(CACHE, "%s-%s.csv" % (table, build))


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for game, build in BUILDS.items():
        for table in TABLES + (LADDER_TABLES if game in LADDER_BUILDS else []):
            target = path_for(table, build)
            if os.path.exists(target):
                print("  have     %s %s" % (game, table))
                continue
            folder, shape = BORROW.get(table, (None, None))
            source = folder and os.path.join(folder, shape % {"build": build})
            if source and os.path.exists(source):
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
    speeds, flight, items, dropped = {}, {}, {}, 0
    ladder, flies = {}, {}

    for game, build_id in BUILDS.items():
        here, air = {}, {}
        for row in read("SpellEffect", build_id):
            if int(row.get("Effect") or 0) != APPLY_AURA:
                continue

            aura = int(row.get("EffectAura") or 0)
            if aura != MOUNTED_SPEED and aura != FLIGHT_SPEED:
                continue

            spell = int(row["SpellID"])
            percent = int(row.get("EffectBasePoints") or 0) + BUMP[game]
            into = here if aura == MOUNTED_SPEED else air
            if percent > into.get(spell, 0):
                into[spell] = percent

        for spell, percent in air.items():
            if percent >= SLOWEST_MOUNT and percent > flight.get(spell, 0):
                flight[spell] = percent

        if game in LADDER_BUILDS:
            effects = {}
            for row in read("SpellEffect", build_id):
                if int(row.get("Effect") or 0) != APPLY_AURA:
                    continue
                effects.setdefault(int(row["SpellID"]), []).append(
                    (int(row.get("EffectAura") or 0),
                     int(row.get("EffectBasePoints") or 0)))
            ladder, flies = ladder_of(build_id, effects)

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
            if item and (spell in speeds or spell in flight):
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
        "-- summoning spell -> how much faster than running, in the air",
        "--",
        "-- A second number on the same spell rather than a faster mount: an Ebon Gryphon is +60%",
        "-- on the ground and +60% in the air, and an epic flyer is +100% and +280%. Reading only",
        "-- the first made a character with a gryphon and an epic ground mount report 100% and say",
        "-- nothing about flying - reported from play.",
        "--",
        "-- Empty on Classic Era, which is right: there is no flying in vanilla.",
        "--",
        "-- **A druid's flight forms are not in here**, and cannot be: on Burning Crusade the form",
        "-- carries aura 201 (enable flight) and a shapeshift, with the speed nowhere in the spell.",
        "Family.MountFlight = {",
    ]
    for spell in sorted(flight):
        lines.append("\t[%d] = %d," % (spell, flight[spell]))
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

    if ladder:
        lines += [
            "-- riding skill rank -> how fast, on the ground and in the air",
            "--",
            "-- From Cataclysm the mount stopped carrying its speed and the riding skill started",
            "-- carrying all of it. So on those builds neither table above answers and this one",
            "-- does - and Master Riding upgrades every mount already owned, because the mount",
            "-- never held the number.",
            "--",
            "-- The five unconditioned rungs. The rest of MountCapability is variants - a zone, an",
            "-- aura known - and several carry a different ground speed, which is what made a",
            "-- first pass read Expert as 150% on the ground.",
            "Family.RidingLadder = {",
        ]
        for rank in sorted(ladder):
            ground, air = ladder[rank]
            lines.append("\t[%d] = { %d, %s }," % (rank, ground, air or "nil"))
        lines += ["}", ""]

        lines += [
            "-- summoning spell -> its mount can fly, on the builds where the skill sets the speed",
            "--",
            "-- Not a speed: the type is what says which rungs a mount can use, and the rank says",
            "-- how fast. A ground mount stops at Journeyman's 100% however high the skill goes,",
            "-- because its type has no rung above 150.",
            "Family.MountFlies = {",
        ]
        for spell in sorted(flies):
            lines.append("\t[%d] = true," % spell)
        lines += ["}", ""]

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    print("\n  %d mounts, %d of them carried as an item, %d speed auras dropped as not mounts"
          % (len(speeds), len(items), dropped))
    print("  %d of them fly" % len(flight))
    if ladder:
        print("  %d riding rungs, %d mounts whose type can fly" % (len(ladder), len(flies)))


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    build()
