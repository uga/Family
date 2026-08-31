#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/RecipeCooldowns.lua - which recipes have a cooldown, per expansion.

`GetTradeSkillCooldown` answers with the time remaining and answers nothing when there is
none, so a transmute that is *ready* is indistinguishable from a bandage. Family therefore
learned it by watching: the first time a recipe was seen counting down, it was marked as one
that has a cooldown, for good. That is honest and it is slow - a character had to be caught
mid-transmute once before the Crafting panel would ever mention them, and the panel says so in
its own footer.

The client's own tables know. `SpellCooldowns` carries `RecoveryTime` and, for the ones that
share a timer, `CategoryRecoveryTime` - measured 2026-09-01:

    Mooncloth                        RecoveryTime          96h
    Transmute: Arcanite              CategoryRecoveryTime  48h
    Transmute: Iron to Gold          CategoryRecoveryTime  24h

**Per expansion, and this is not optional.** The same spell has a different cooldown on each
build, and on the newest one it usually has none: Transmute: Mithril to Truesilver is 48 hours
on Classic Era, 20 on Burning Crusade and one second on Mists. A union would tell a Mists
alchemist they have a two-day cooldown that does not exist. So the table is keyed by expansion
and read through `Family.Capabilities.expansion`, exactly as `TalentSpells.lua` is.

**Keyed twice, by spell and by what the recipe makes.** A recipe on Classic Era often has no
spell id at all - measured on a French client, all 111 alchemy recipes came back with an item
id and no spell - so a table keyed only by spell would miss precisely the case this exists for.
The item is reached through the same chain `made-by-item.py` uses: the spell's `SpellEffect`
with effect 24 names what it creates.

    tools/recipe-cooldowns.py --fetch     download what is missing into a cache
    tools/recipe-cooldowns.py             build the Lua from what is cached

Re-run at a new build. It refuses rather than guesses: a build that yields nothing means a
column or a table has moved, and an empty table would look like a quiet success.
"""

import csv, os, shutil, sys, urllib.request

AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

# Keyed by the number Capabilities derives from the interface version, so the Lua can be read
# without a second table mapping one to the other.
BUILDS = {
    1: ("Classic Era", "1.15.9.69109"),
    2: ("Burning Crusade Anniversary", "2.5.6.69110"),
    5: ("Mists of Pandaria Classic", "5.5.4.69078"),
}

PRIMARY_CATEGORY = "11"
CREATE_ITEM = 24

# An hour. Everything this is for is a day or longer; what sits below the line is the vanilla
# transmutes on Mists, which are a second because that expansion removed them. A recipe
# somebody uses several times an hour is not a recipe anybody logs in for.
#
# The floor is the second filter and not the first. **A crafting recipe makes something**, so
# a spell that creates no item is not one, whatever it costs to use - which is what keeps out
# the engineering trinkets, whose summon spells are filed under Engineering too and whose use
# cooldowns are an hour and would have sailed over any floor. A Mechanical Dragonling at one
# hour was in the first version of this table and is not a recipe cooldown at all.
FLOOR_MS = 60 * 60 * 1000

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".recipe-cooldowns-cache")
OUT = os.path.join(HERE, "..", "addons", "Family", "RecipeCooldowns.lua")

BORROW = {
    "SkillLine": (os.path.join(HERE, ".skill-lines-cache"), "%(build)s-enUS.csv"),
    "SkillLineAbility": (os.path.join(HERE, ".specialisations-cache"),
                         "SkillLineAbility-%(build)s.csv"),
    "SpellEffect": (os.path.join(HERE, ".made-by-item-cache"), "SpellEffect-%(build)s.csv"),
}
TABLES = ["SkillLine", "SkillLineAbility", "SpellEffect", "SpellCooldowns"]


def path_for(table, build):
    return os.path.join(CACHE, "%s-%s.csv" % (table, build))


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for _, (game, build) in sorted(BUILDS.items()):
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
    lines = [
        "-- Which recipes have a cooldown, and how long. GENERATED - see",
        "-- tools/recipe-cooldowns.py. Do not edit.",
        "--",
        "-- From the client's own SpellCooldowns, so a recipe is known to have a cooldown",
        "-- before anybody has watched one run - which is what GetTradeSkillCooldown cannot",
        "-- say while it is ready. Seconds, not milliseconds.",
        "--",
        "-- **Keyed by expansion**, because the same spell differs: Transmute: Mithril to",
        "-- Truesilver is 48 hours on Classic Era, 20 on Burning Crusade and gone on Mists.",
        "-- Read through Family.Capabilities.expansion, as TalentSpells.lua is.",
        "--",
        "-- Keyed twice within that: by spell, and by the item the recipe makes, because a",
        "-- recipe on Classic Era often arrives with an item id and no spell at all.",
        "",
        "local _, Family = ...",
        "",
        "Family.RecipeCooldowns = {",
    ]

    total = 0
    for xpac in sorted(BUILDS):
        game, build_id = BUILDS[xpac]

        professions = {int(r["ID"]) for r in read("SkillLine", build_id)
                       if r.get("CategoryID") == PRIMARY_CATEGORY}
        taught = {int(r["Spell"]) for r in read("SkillLineAbility", build_id)
                  if int(r["SkillLine"]) in professions}

        creates = {}
        for row in read("SpellEffect", build_id):
            if int(row.get("Effect") or 0) == CREATE_ITEM:
                made = int(row.get("EffectItemType") or 0)
                if made:
                    creates.setdefault(int(row["SpellID"]), made)

        bySpell, byItem = {}, {}
        for row in read("SpellCooldowns", build_id):
            spell = int(row.get("SpellID") or 0)
            if spell not in taught:
                continue

            made = creates.get(spell)
            if not made:
                continue

            longest = max(int(row.get("RecoveryTime") or 0),
                          int(row.get("CategoryRecoveryTime") or 0))
            if longest < FLOOR_MS:
                continue

            seconds = longest // 1000
            bySpell[spell] = max(bySpell.get(spell, 0), seconds)
            byItem[made] = max(byItem.get(made, 0), seconds)

        print("  %-30s %3d recipes with a cooldown, %3d of them by what they make"
              % (game, len(bySpell), len(byItem)))
        total += len(bySpell)

        lines.append("\t[%d] = {" % xpac)
        lines.append("\t\tspell = {")
        for spell in sorted(bySpell):
            lines.append("\t\t\t[%d] = %d," % (spell, bySpell[spell]))
        lines.append("\t\t},")
        lines.append("\t\titem = {")
        for made in sorted(byItem):
            lines.append("\t\t\t[%d] = %d," % (made, byItem[made]))
        lines.append("\t\t},")
        lines.append("\t},")

    lines += ["}", ""]

    if total == 0:
        sys.exit("nothing came out at all - a column or a table has moved, and an empty "
                 "table would look like a quiet success")

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    print("\n  %d entries across %d expansions" % (total, len(BUILDS)))


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    build()
