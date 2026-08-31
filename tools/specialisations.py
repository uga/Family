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
}

TABLES = ["ItemSparse", "SkillLine", "SkillLineAbility"]


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

        print("  %-30s %4d gated items, %2d specialisations"
              % (game, here, len({gates[i] for i in gates})))

    lines = [
        "-- Generated by tools/specialisations.py. Do not edit.",
        "--",
        "-- Which recipes a profession specialisation gates, and which profession each",
        "-- specialisation belongs to. From ItemSparse.RequiredAbility, filtered to abilities",
        "-- that are themselves taught under a primary profession - see DATASOURCES.md.",
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
    lines += ["}", "", "-- recipe item -> the specialisation it needs", "Family.RecipeNeeds = {"]
    for item in sorted(gates):
        lines.append("\t[%d] = %d," % (item, gates[item]))
    lines += ["}", ""]

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

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
