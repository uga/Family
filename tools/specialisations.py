#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/Specialisations.lua - which recipes a specialisation gates.

Blacksmiths choose between armour and weapons, leatherworkers between dragonscale, elemental
and tribal, engineers between gnomish and goblin, and TBC tailors between spellfire, shadoweave
and mooncloth. A recipe belonging to one of those cannot be learnt by a character who took a
different branch - so Family telling somebody they "can learn it" is a claim that is simply
false for most of the family, which is what this exists to stop.

**Where it comes from.** An item that needs a specialisation says so in its own row:
`ItemSparse.RequiredAbility` is the spell the character must already know. That is the whole
relation. `SkillLineAbility` does NOT carry it - measured 2026-08-31, a Gnomish Death Ray row
and a Copper Chain Belt row are identical in every column - and specialisations are not child
skill lines either: `ParentSkillLineID` is empty for every profession on Era and Burning
Crusade, and on Mists names only the cooking ways.

**RequiredAbility is not only specialisations**, which is the one trap here. It carries riding
skills - 514 mount items on Mists alone - and battle pet training. So an ability counts only if
it is *itself* a spell taught under a primary profession's skill line, which is a question the
client's own tables answer. Nothing below is a hand-written list of specialisations.

**What it cannot cover:** a specialisation recipe taught only by a trainer has no item and no
row here. That is the right shape for the tooltip - there is nothing to hover - and it is a
real gap for any other question.

    tools/specialisations.py --fetch     download what is missing into a cache
    tools/specialisations.py             build the Lua from what is cached

Re-run at a new build. It refuses rather than guesses: an item gated by two different
specialisations across builds, or a specialisation taught by two professions, stops it.
"""

import csv, os, shutil, sys, urllib.request

AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}

# The professions, as the skill list files them. Category 11 is exactly the primaries on every
# build - the same constant tools/skill-lines.py leans on and for the same reason.
PRIMARY_CATEGORY = "11"

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".specialisations-cache")
OUT = os.path.join(HERE, "..", "addons", "Family", "Specialisations.lua")

# Two of the three tables are already sitting in other generators' caches at the same builds.
# Copied rather than re-fetched: it is the same file from the same server, and asking a server
# given away for nothing to send nine megabytes we already have is not a good way to use it.
BORROW = {
    "ItemSparse": (os.path.join(HERE, ".game-words-cache"), "ItemSparse-%(build)s-enUS.csv"),
    "SkillLine": (os.path.join(HERE, ".skill-lines-cache"), "%(build)s-enUS.csv"),
    "SpellEffect": (os.path.join(HERE, ".recipe-teaches-cache"), "SpellEffect-%(build)s.csv"),
}

TABLES = ["ItemSparse", "SkillLine", "SkillLineAbility", "SpellEffect"]

# SpellEffect.Effect 47 is "grants a trade skill". Every specialisation on all three builds is
# one of these and so is every *rank* of a profession - Apprentice through Artisan - which is
# what the rest of the sieve below is for.
GRANTS_TRADE_SKILL = "47"

# **The picture each branch draws**, given by Alberto from his own three clients on 2026-09-06
# and keyed here by spell id rather than by name.
#
# Hand data in a generated file, which is the same arrangement `tools/skill-lines.py` has for
# the professions and is here for the same reason: a texture cannot be probed - the client hands
# back whatever path it was given - so the only honest source is somebody looking at one. What a
# table *can* answer is which id carries which name, and it was asked, because the names and the
# ids do not line up the way anybody would guess: **17040 is Master Hammersmith and 17041 is
# Master Axesmith**, and the items they gate say the opposite - 17041 gates *The Planar Edge*.
# The mapping below is wago's `SpellName` at build 2.5.6.69110, not a reading of item names and
# not a memory.
#
# A branch with no picture here simply keeps its profession's, which is what the panel drew
# before any of this - so a build that adds one is a missing icon rather than a broken cell.
ICONS = {
    9787: 135326,   # Weaponsmith
    9788: 132739,   # Armorsmith
    17039: 135351,  # Master Swordsmith
    17040: 133060,  # Master Hammersmith
    17041: 132396,  # Master Axesmith
    10656: 134305,  # Dragonscale Leatherworking
    10658: 135830,  # Elemental Leatherworking
    10660: 136069,  # Tribal Leatherworking
    20219: 132996,  # Gnomish Engineer
    20222: 135826,  # Goblin Engineer
    26797: 135880,  # Spellfire Tailoring
    26798: 132895,  # Mooncloth Tailoring
    26801: 132888,  # Shadoweave Tailoring
    28672: 136050,  # Transmutation Master
    28675: 134756,  # Potion Master
    28677: 134734,  # Elixir Master
}

# **How deep a branch is**, for the one profession that has two levels of them: a blacksmith
# takes Weaponsmith first and may then take one of the three masteries under it. Alberto asked
# for the deeper one to cover the shallower, so the cell draws the axe rather than the sword-
# and-hammer of the branch it grew out of.
#
# A hand list of three, and it is a hand list because nothing in the client's tables says so.
# `SupercedesSpell` is empty on all five - it chains Apprentice to Artisan and nothing else -
# and `SkillLineAbility` gives the masteries and Weaponsmith identical rows in every column.
# Anything absent is depth 1, so this stays three entries however many branches are added.
DEPTH = {
    17039: 2,  # Master Swordsmith
    17040: 2,  # Master Hammersmith
    17041: 2,  # Master Axesmith
}


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

            if table in BORROW:
                folder, shape = BORROW[table]
                source = os.path.join(folder, shape % {"build": build})
                if os.path.exists(source):
                    shutil.copyfile(source, target)
                    print("  borrowed %s %s" % (game, table))
                    continue

            url = "https://wago.tools/db2/%s/csv?build=%s&locale=enUS" % (table, build)
            print("  fetch    %s %s" % (game, table))
            request = urllib.request.Request(url, headers={"User-Agent": AGENT})
            open(target, "wb").write(urllib.request.urlopen(request, timeout=600).read())


def read(table, build):
    with open(path_for(table, build), encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def build():
    gates, taught_by, seen_in, names = {}, {}, {}, {}

    for game, build_id in BUILDS.items():
        professions = set()
        for row in read("SkillLine", build_id):
            if row.get("CategoryID") == PRIMARY_CATEGORY:
                professions.add(int(row["ID"]))
                names[int(row["ID"])] = row["DisplayName_lang"]

        # Which spell is taught under which profession. A specialisation is one of these; a
        # riding skill is not, which is the whole of the filter.
        under = {}
        for row in read("SkillLineAbility", build_id):
            line = int(row["SkillLine"])
            if line in professions:
                under.setdefault(int(row["Spell"]), set()).add(line)

        # **The specialisations that gate nothing.**
        #
        # The item route below finds a specialisation only if some recipe *item* requires it,
        # and two of Burning Crusade's three alchemy masteries gate no item at all - their
        # recipes come from a trainer. Those two were missing from this table for as long as it
        # existed, which did not matter while the only question was "can this character learn
        # this recipe" and matters now that the panel names a character's branches.
        #
        # The sieve, measured on all three builds rather than reasoned about: a specialisation
        # is a spell taught under a primary profession, at rank 1, learnt rather than trained
        # into (AcquireMethod 0), in no recipe category, granting one skill-up, outside the
        # Apprentice-to-Artisan chain in either direction, and carrying SpellEffect 47.
        #
        # Each clause is doing work. Without the supercedes test the profession ranks come
        # through - Artisan Blacksmithing is a spell that grants a trade skill at rank 1 like
        # any specialisation. Without effect 47 it lets in Prospecting, Herb Gathering and two
        # others that are abilities a profession grants rather than branches it offers. With
        # both, the three builds answer 10, 16 and 5 - and the five on Mists are exactly
        # engineering's two and alchemy's three, which is the right answer for a build where
        # the smithing, leatherworking and tailoring branches were taken out of the game.
        grants = set()
        for row in read("SpellEffect", build_id):
            if row.get("Effect") == GRANTS_TRADE_SKILL and row.get("SpellID"):
                grants.add(int(row["SpellID"]))

        rows = read("SkillLineAbility", build_id)
        chained = set()
        for row in rows:
            if int(row["SkillLine"]) in professions:
                previous = int(row.get("SupercedesSpell") or 0)
                if previous:
                    chained.add(previous)
                    chained.add(int(row["Spell"]))

        branches = 0
        for row in rows:
            line = int(row["SkillLine"])
            spell = int(row["Spell"])
            if (line in professions and spell in grants and spell not in chained
                    and row["MinSkillLineRank"] == "1" and row["AcquireMethod"] == "0"
                    and row["TrivialSkillLineRankHigh"] == "0"
                    and row["TradeSkillCategoryID"] == "0" and row["NumSkillUps"] == "1"):
                if spell in taught_by and taught_by[spell] != line:
                    sys.exit("%s: spell %d is under skill line %d here and %d on another "
                             "build" % (game, spell, line, taught_by[spell]))
                taught_by[spell] = line
                seen_in.setdefault(spell, set()).add(game)
                branches += 1

        here = 0
        for row in read("ItemSparse", build_id):
            ability = int(row.get("RequiredAbility") or 0)
            if not ability or ability not in under:
                continue

            item = int(row["ID"])
            lines = under[ability]
            if len(lines) > 1:
                sys.exit("%s: spell %d is taught by %d professions - it cannot be a "
                         "specialisation" % (game, ability, len(lines)))
            line = next(iter(lines))

            if item in gates and gates[item] != ability:
                sys.exit("%s: item %d needs spell %d here and %d on another build"
                         % (game, item, ability, gates[item]))
            if ability in taught_by and taught_by[ability] != line:
                sys.exit("%s: spell %d is under skill line %d here and %d on another build"
                         % (game, ability, line, taught_by[ability]))

            gates[item] = ability
            taught_by[ability] = line
            seen_in.setdefault(ability, set()).add(game)
            here += 1

        print("  %-30s %4d gated items, %2d branches on this build"
              % (game, here, branches))

    lines = [
        "-- Generated by tools/specialisations.py. Do not edit.",
        "--",
        "-- Which recipes a profession specialisation gates, and which profession each",
        "-- specialisation belongs to. The branches come from SkillLineAbility sieved against",
        "-- SpellEffect 47; the gated recipes from ItemSparse.RequiredAbility, filtered to",
        "-- abilities taught under a primary profession - see DATASOURCES.md.",
        "--",
        "-- Ids throughout: the specialisation is a spell a character either knows or does not,",
        "-- and the client answers that in any language.",
        "",
        "local _, Family = ...",
        "",
        "-- specialisation spell -> the profession's skill line",
        "Family.Specialisations = {",
    ]
    for ability in sorted(taught_by):
        lines.append("\t[%d] = %d," % (ability, taught_by[ability]))
    # Emitted for every branch the sieve found rather than for every icon named, so an icon for
    # a spell that is not a branch is a mistake this refuses to carry into the addon.
    lines += ["}", "", "-- specialisation spell -> the picture it draws in place of its "
              + "profession's", "Family.SpecialisationIcons = {"]
    for ability in sorted(taught_by):
        if ability in ICONS:
            lines.append("\t[%d] = %d," % (ability, ICONS[ability]))

    lines += ["}", "",
              "-- specialisation spell -> how deep a branch it is; absent means the first level",
              "Family.SpecialisationDepth = {"]
    for ability in sorted(taught_by):
        if ability in DEPTH:
            lines.append("\t[%d] = %d," % (ability, DEPTH[ability]))

    lines += ["}", "", "-- recipe item -> the specialisation it needs", "Family.RecipeNeeds = {"]
    for item in sorted(gates):
        lines.append("\t[%d] = %d," % (item, gates[item]))
    lines += ["}", ""]

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    # Said out loud rather than left to be noticed: a branch drawn with its profession's picture
    # is not wrong, but it is not what was asked for either.
    without = [a for a in sorted(taught_by) if a not in ICONS]
    if without:
        print("\n  %d branches with no picture of their own: %s"
              % (len(without), ", ".join(str(a) for a in without)))

    print("\n  %d gated items, %d specialisations across %d professions"
          % (len(gates), len(taught_by), len(set(taught_by.values()))))
    for ability in sorted(taught_by, key=lambda a: (taught_by[a], a)):
        where = sorted(seen_in[ability])
        count = len([i for i in gates if gates[i] == ability])
        print("    spell %-7d %-16s %3d items   %s"
              % (ability, names.get(taught_by[ability], "?"), count,
                 ", ".join(w.split()[0] for w in where)))


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    build()
