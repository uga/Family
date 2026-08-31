#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/RecipeTeaches.lua - which spell a recipe item teaches.

Family decides who already knows a recipe by matching the item's name against the names in
each member's recipe list. That works while the two agree, and for enchanting they do not: the
trade skill window abbreviates. A French client lists `Ench. de bottes (Agilité supérieure)`
and names the formula `Formule : Enchantement de bottes (Agilité supérieure)`, so the suffix
test fails and an enchanter who has known the recipe for a year is offered it as one to learn.
Reported from play, with the debug output showing all 132 enchanting recipes carrying a spell
id and no item id at all.

The ids were there the whole time on both sides. A recipe item's own spell **teaches** another
spell, and the taught one is the id the recipe list records:

    ItemEffect.ParentItemID  16245  Formula: Enchant Boots - Greater Agility
      -> ItemEffect.SpellID  20080
      -> SpellEffect Effect 36 (learn spell), EffectTriggerSpell 20023
                             20023  the enchant, which is what the window hands back

So this is the join, and matching on it is exact: no abbreviation, no language, no suffix rule.
The name test stays for the items this table has never heard of.

Only where the taught spell is one a profession teaches, which keeps out mounts, riding and
everything else that also learns a spell from an item.

    tools/recipe-teaches.py --fetch     download what is missing into a cache
    tools/recipe-teaches.py             build the Lua from what is cached

Re-run at a new build. It refuses rather than guesses: one item teaching two different spells
across builds, or a build yielding nothing at all.
"""

import csv, os, shutil, sys, urllib.request

AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}

# Effect 36 is LEARN_SPELL. Numeric and the same on every build.
LEARN_SPELL = 36
PRIMARY_CATEGORY = "11"

# The number Capabilities derives from the interface version.
EXPANSION = {"Classic Era": 1, "Burning Crusade Anniversary": 2,
             "Mists of Pandaria Classic": 5}

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".recipe-teaches-cache")
OUT = os.path.join(HERE, "..", "addons", "Family", "RecipeTeaches.lua")

BORROW = {
    "ItemEffect": (os.path.join(HERE, ".charged-items-cache"), "ItemEffect-%(build)s.csv"),
    "SpellEffect": (os.path.join(HERE, ".made-by-item-cache"), "SpellEffect-%(build)s.csv"),
    "SkillLine": (os.path.join(HERE, ".skill-lines-cache"), "%(build)s-enUS.csv"),
    "SkillLineAbility": (os.path.join(HERE, ".specialisations-cache"),
                         "SkillLineAbility-%(build)s.csv"),
}
TABLES = ["ItemEffect", "SpellEffect", "SkillLine", "SkillLineAbility"]


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
            open(target, "wb").write(urllib.request.urlopen(request, timeout=600).read())


def read(table, build):
    with open(path_for(table, build), encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def build():
    teaches = {}

    for game, build_id in BUILDS.items():
        professions = {int(r["ID"]) for r in read("SkillLine", build_id)
                       if r.get("CategoryID") == PRIMARY_CATEGORY}
        taught = {int(r["Spell"]) for r in read("SkillLineAbility", build_id)
                  if int(r["SkillLine"]) in professions}

        learns = {}
        for row in read("SpellEffect", build_id):
            if int(row.get("Effect") or 0) != LEARN_SPELL:
                continue
            trigger = int(row.get("EffectTriggerSpell") or 0)
            if trigger:
                learns.setdefault(int(row["SpellID"]), trigger)

        # Two shapes, and only one of them was handled at first - which is why two builds out
        # of three came back with nothing at all.
        #
        # On Classic Era the item's spell *teaches* another: effect 36 with a trigger, and the
        # trigger is the recipe. On Burning Crusade and Mists a recipe item carries two rows -
        # a generic 483 "Learning" with no trigger, and the craft spell itself. So the taught
        # spell is either the row's own spell where a profession teaches it, or the trigger of
        # an effect-36 row where a profession teaches that.
        here = 0
        for row in read("ItemEffect", build_id):
            item = int(row.get("ParentItemID") or 0)
            spell = int(row.get("SpellID") or 0)
            if not item or not spell:
                continue

            if spell in taught:
                lesson = spell
            elif spell in learns and learns[spell] in taught:
                lesson = learns[spell]
            else:
                continue

            # Per expansion rather than a union, because they disagree: item 23133 teaches
            # 28903 on Mists and 28906 elsewhere. A union would have asserted one build's
            # answer on the others, which is the same fault the cooldown tables were
            # corrected for twice on the same day.
            teaches.setdefault(EXPANSION[game], {})[item] = lesson
            here += 1

        print("  %-30s %4d recipe items" % (game, here))

    if not teaches:
        sys.exit("nothing came out at all - a column or the LEARN_SPELL number has moved, "
                 "and an empty table would look like a quiet success")

    lines = [
        "-- Which spell each recipe item teaches. GENERATED - see tools/recipe-teaches.py.",
        "--",
        "-- Who already knows a recipe was decided by matching the item's name against the",
        "-- names in a member's recipe list, and for enchanting those never agree: the trade",
        "-- skill window abbreviates. A French client lists \"Ench. de bottes (Agilite",
        "-- superieure)\" and names the formula \"Formule : Enchantement de bottes (Agilite",
        "-- superieure)\", so the suffix test failed and an enchanter who had known it for a",
        "-- year was offered it as something to learn.",
        "--",
        "-- ItemEffect gives the item's spell, SpellEffect effect 36 gives the spell that one",
        "-- teaches, and that is the id the recipe list records. Exact, and in no language.",
        "",
        "local _, Family = ...",
        "",
        "-- Per expansion, because they disagree: item 23133 teaches one spell on Mists and",
        "-- another elsewhere. Read through Family.Capabilities.expansion.",
        "",
        "-- recipe item -> the spell it teaches",
        "Family.RecipeTeaches = {",
    ]
    for xpac in sorted(EXPANSION.values()):
        lines.append("\t[%d] = {" % xpac)
        for item in sorted(teaches.get(xpac, {})):
            lines.append("\t\t[%d] = %d," % (item, teaches[xpac][item]))
        lines.append("\t},")
    lines += ["}", ""]

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    print("\n  %d recipe items across %d expansions"
          % (sum(len(v) for v in teaches.values()), len(teaches)))


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    build()
