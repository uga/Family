#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/RecipeReagents.lua - what each recipe is made of, and which of those
materials nobody can buy.

Asked for 2026-09-12, twice over. A Professions row wants the materials drawn beside the
recipe (backlog 69), and an item tooltip wants what the thing costs to make (backlog 71) -
and both are the same table, so it is generated once.

**Why it cannot come out of the client.** `GetTradeSkillReagentInfo` answers for a recipe in a
window that is open, on the character who knows it. Family's whole point is answering about the
*other* forty characters, whose windows are shut and who are not logged in.

**`SpellReagents`, which wago serves for all three pinned builds.** Columns are `SpellID`,
`Reagent_0..7` and `ReagentCount_0..7`. Checked against a recipe somebody named rather than
against nothing: 29360 Smelt Felsteel gives 23445 x3 and 23447 x2 - Fel Iron Bar and Eternium
Bar, which is what the game's own window shows.

**Eight slots, and recipes use all eight.** On Burning Crusade 725 recipes need three reagents
and 81 need seven or eight, so anything drawn for three truncates a third of the list.

**Per expansion, and that is not caution.** 7,368 spells carry reagents across the three builds
and 475 of them carry *different* reagents on different builds. One merged table would be 219 KB
against 344, and wrong about 475 recipes - which is the confident wrong answer this project
refuses. Narrowed instead to the spells a trade skill actually teaches, which is what a recipe
is: 1,793 on Era, 2,304 on Burning Crusade, 5,333 on Mists.

**And which materials cost nothing because no money can buy them.** Alberto, 2026-09-12:

    componenti che sono bop drop (es Skin of Shadow, e altri non tradabili, cioè tali che lo
    debba farmare esclusivamente il crafter) sommano zero al totale non perché "valgano" zero,
    ma perché comunque non richiedono soldi per acquisirli

`ItemSparse.Bonding` is 1 for bind-on-pickup. Skin of Shadow is item 12753 and reads 1; every
ordinary reagent - Fel Iron Bar, Netherweave Cloth, Primal Fire - reads 0. Only the reagents are
listed, because that is the only place anything asks.

    tools/recipe-reagents.py --fetch     download what is missing into a cache
    tools/recipe-reagents.py             build the Lua from what is cached

Re-run at a new build. It refuses rather than guesses: a build that yields nothing at all means
a column has moved, and an empty table would look like a quiet success.
"""

import csv, os, shutil, sys, urllib.request

AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}

# The number Capabilities derives from the interface version.
EXPANSION = {"Classic Era": 1, "Burning Crusade Anniversary": 2,
             "Mists of Pandaria Classic": 5}

# Bind on pickup, numeric and the same on every build unlike anything named.
BIND_ON_PICKUP = 1

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".recipe-reagents-cache")
OUT = os.path.join(HERE, "..", "addons", "Family", "RecipeReagents.lua")

# Already sitting in another generator's cache at the same builds. Copied rather than fetched
# again: same file, same server, and that server is given away for nothing.
BORROW = {
    "ItemSparse": (os.path.join(HERE, ".game-words-cache"), "ItemSparse-%(build)s-enUS.csv"),
    "SkillLineAbility": (os.path.join(HERE, ".specialisations-cache"),
                         "SkillLineAbility-%(build)s.csv"),
}
TABLES = ["SpellReagents", "SkillLineAbility", "ItemSparse"]


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
            url = "https://wago.tools/db2/%s/csv?build=%s" % (table, build)
            print("  fetch    %s %s" % (game, table))
            request = urllib.request.Request(url, headers={"User-Agent": AGENT})
            open(target, "wb").write(urllib.request.urlopen(request, timeout=900).read())


def read(table, build):
    with open(path_for(table, build), encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def column(rows, *names):
    """The first of these the table actually has. A column that has moved is a build change,
    and guessing at it is how a generator comes to ship an empty table quietly."""
    for name in names:
        if name in rows[0]:
            return name
    raise SystemExit("none of %s in this table - the columns have moved" % (names,))


def build():
    per_expansion = {}
    bound = {}

    for game, build_id in BUILDS.items():
        sla = read("SkillLineAbility", build_id)
        spell_col = column(sla, "Spell", "SpellID")
        taught = set(int(row[spell_col]) for row in sla if row[spell_col])

        reagents = {}
        for row in read("SpellReagents", build_id):
            spell = int(row["SpellID"])
            if spell not in taught:
                continue
            pairs = []
            for slot in range(8):
                item = int(row.get("Reagent_%d" % slot) or 0)
                count = int(row.get("ReagentCount_%d" % slot) or 0)
                if item > 0 and count > 0:
                    pairs.append((item, count))
            if pairs:
                reagents[spell] = pairs

        if not reagents:
            raise SystemExit("%s yielded no reagents at all - a column has moved" % game)

        per_expansion[EXPANSION[game]] = reagents

        # Only the materials, because that is the only place anything asks - and the whole
        # of ItemSparse's binding column would be tens of thousands of rows nobody reads.
        wanted = set()
        for pairs in reagents.values():
            for item, _ in pairs:
                wanted.add(item)

        sparse = read("ItemSparse", build_id)
        bind_col = column(sparse, "Bonding")
        here = set()
        for row in sparse:
            item = int(row["ID"])
            if item in wanted and int(row.get(bind_col) or 0) == BIND_ON_PICKUP:
                here.add(item)

        bound[EXPANSION[game]] = here
        print("  %-28s %5d recipe(s), %4d material(s), %3d of them bind on pickup"
              % (game, len(reagents), len(wanted), len(here)))

    lines = []
    add = lines.append
    add("-- Generated by tools/recipe-reagents.py. Do not edit.")
    add("--")
    add("-- What each recipe is made of, and which of those materials no money can buy.")
    add("--")
    add("-- From SpellReagents and ItemSparse.Bonding, narrowed to the spells a trade skill")
    add("-- teaches - see DATASOURCES.md. Ids throughout, so this file has no language in it.")
    add("--")
    add("-- Per expansion because 475 spells carry different reagents on different builds, and")
    add("-- one merged table would be smaller and wrong about every one of them.")
    add("")
    add("local _, Family = ...")
    add("")
    add("-- expansion -> spell -> { itemID, count, itemID, count, ... }")
    add("Family.RecipeReagents = {")
    for expansion in sorted(per_expansion):
        add("\t[%d] = {" % expansion)
        for spell in sorted(per_expansion[expansion]):
            flat = ",".join("%d,%d" % pair for pair in per_expansion[expansion][spell])
            add("\t\t[%d]={%s}," % (spell, flat))
        add("\t},")
    add("}")
    add("")
    add("-- expansion -> material -> true, for the ones that bind on pickup. A crafter farms")
    add("-- these; they add nothing to what a recipe costs, and that is not the same as being")
    add("-- worth nothing.")
    add("Family.BoundReagents = {")
    for expansion in sorted(bound):
        add("\t[%d] = {" % expansion)
        row = []
        for item in sorted(bound[expansion]):
            row.append("[%d]=true," % item)
            if len(row) == 8:
                add("\t\t" + "".join(row))
                row = []
        if row:
            add("\t\t" + "".join(row))
        add("\t},")
    add("}")
    add("")

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    print("  wrote %s (%d KB)" % (os.path.relpath(OUT, HERE), os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    if not os.path.isdir(CACHE):
        raise SystemExit("no cache - run with --fetch first")
    build()
