#!/usr/bin/env python3
"""What a gathering node in the world can be about, as ids and nothing else.

Backlog 96. Family puts its possessions block on a herb node's or a mining vein's tooltip, and
a node hands over **a name and nothing else** - no id, on any of the three clients, measured
four ways across two builds. So the name has to be turned into an item, and the only honest way
to do that is to compare it against names the client itself gives for ids this file ships.

Ids and nothing else. Alberto's rule for this entry, in as many words: *locale words must come
from official game vocabulary, not our translations.* A name typed here would be somebody's
reading of the game rather than the game's own word, and `SkillLines.lua` exists because
"Erste Hilfe" and "Erstehilfe" are indistinguishable from outside it.

**Herbs** are every item a recipe of Herbalism's two customers consumes - Alchemy (171) and
Inscription (773). That over-collects: Crystal Vial and Deviate Fish are in the Era list too.
It costs nothing, because a herb node is matched by its name **exactly** - a herb node is named
exactly what the herb is named, measured on Liferoot, Plaguebloom, Dreamfoil, Silverleaf and
Peacebloom - and no node in the game is called Crystal Vial.

**Ores** are narrower, because a vein is *not* named after its ore and has to be scored rather
than matched. So only the smelts that take exactly one thing, whose one thing is not itself
smelted from something else: that is ore -> bar and nothing else. Bronze takes two bars and
Elementium four things, and neither is in the ground; dropping them drops Coal, Fiery Core and
Elemental Flux with them, which were the closest wrong answers while they were in.

Read rather than re-fetched: the reagents and products come from `RecipeReagents.lua` and
`RecipeTeaches.lua` as this addon actually ships them, so this table cannot disagree with the
tables it is read beside. Only the skill each spell belongs to is fetched, from
`SkillLineAbility`, which no shipped table carries.

Re-run at a new build. It refuses rather than guesses: a build that yields nothing at all means
a column has moved, and an empty table would look like a quiet success.
"""

import os, re, sys, urllib.request

AGENT = "Family-addon-tools (+https://github.com/uga/Family)"
BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}
EXPANSION = {"Classic Era": 1, "Burning Crusade Anniversary": 2,
             "Mists of Pandaria Classic": 5}

HERB_CUSTOMERS = (171, 773)     # Alchemy, Inscription
SMELTING = 186                  # Mining's own window

# The five Family ships. A name that collides in any one of them is excluded in all of them:
# the table is ids, and which of them collides is a fact about a locale rather than about a node.
LOCALES = ("enUS", "deDE", "frFR", "esES", "ruRU")

# The rule as `Family_UI/Tooltip.lua` applies it. Written twice on purpose, and the harness
# holds the two against each other: a generator that scored differently from the addon would
# quietly ship the wrong exceptions.
ORE_FLOOR, ORE_MARGIN, ORE_RUN = 0.55, 0.27, 4

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".gathered-cache")
ADDON = os.path.join(HERE, "..", "addons", "Family")
OUT = os.path.join(ADDON, "Gathered.lua")

# Already in another generator's cache at the same builds. Copied rather than asked for twice:
# same file, same server, and that server is given away for nothing.
BORROW = [os.path.join(HERE, ".specialisations-cache"), os.path.join(HERE, ".recipe-reagents-cache")]


def skill_lines(build):
    """spellID -> the skill line that teaches it. The one thing no shipped table carries."""
    os.makedirs(CACHE, exist_ok=True)
    target = os.path.join(CACHE, "SkillLineAbility-%s.csv" % build)
    if not os.path.exists(target):
        for folder in BORROW:
            for shape in ("SkillLineAbility-%s.csv" % build, "SkillLineAbility_%s.csv" % build):
                source = os.path.join(folder, shape)
                if os.path.exists(source):
                    open(target, "wb").write(open(source, "rb").read())
                    break
    if not os.path.exists(target):
        url = "https://wago.tools/db2/SkillLineAbility/csv?build=%s" % build
        print("  fetch    SkillLineAbility %s" % build)
        request = urllib.request.Request(url, headers={"User-Agent": AGENT})
        open(target, "wb").write(urllib.request.urlopen(request, timeout=900).read())

    import csv
    rows = list(csv.DictReader(open(target, encoding="utf-8")))
    if not rows:
        raise SystemExit("SkillLineAbility came back empty for %s" % build)
    spell = "Spell" if "Spell" in rows[0] else "SpellID"
    if spell not in rows[0] or "SkillLine" not in rows[0]:
        raise SystemExit("the columns of SkillLineAbility have moved at %s" % build)

    out = {}
    for row in rows:
        if row[spell] and row["SkillLine"]:
            out.setdefault(int(row["SkillLine"]), set()).add(int(row[spell]))
    return out


ASCII = bytes.maketrans(bytes(range(65, 91)), bytes(range(97, 123)))


def folded(text):
    """Lua's `lower`, which folds A to Z and nothing else, over Lua's bytes."""
    return text.encode("utf-8").translate(ASCII)


def shared_run(one, other):
    """The longest run of bytes two names share, and where it starts in the second (-1: none)."""
    one, other = folded(one), folded(other)
    best, at, previous = 0, -1, [0] * (len(other) + 1)
    for i in range(1, len(one) + 1):
        current = [0] * (len(other) + 1)
        for j in range(1, len(other) + 1):
            if one[i - 1] == other[j - 1]:
                current[j] = previous[j - 1] + 1
                if current[j] > best:
                    best, at = current[j], j - current[j]
        previous = current
    return best, at


# Space, hyphen and apostrophe, by byte - `atAWord` in Tooltip.lua tests the same three.
SEPARATORS = (32, 45, 39)


def at_a_word(name, at):
    """`atAWord`: the run begins the name, opens with a separator, or follows one."""
    if at < 0:
        return False
    if at == 0:
        return True
    name = folded(name)
    return name[at] in SEPARATORS or name[at - 1] in SEPARATORS


def scores_as_an_ore(name, ores):
    """Exactly what `oreScored` does, so the exceptions match what the addon will decide.

    Including the word rule of 2026-09-22: a candidate whose shared run starts inside one of its
    own words is not a candidate at all - neither the winner nor the runner-up the margin is
    measured against. Before this was carried here the tool scored places by the older rule, and
    the list it shipped was a superset of the places the addon would actually misread."""
    ranked = []
    for n in ores:
        run, at = shared_run(name, n)
        if run > 0 and at_a_word(n, at):
            ranked.append((run / len(folded(n)), run, n))
    ranked.sort(reverse=True)
    if not ranked:
        return False
    top = ranked[0]
    runner = ranked[1] if len(ranked) > 1 else (0.0, 0, "")
    kin = runner[2] and (folded(runner[2]) in folded(top[2]) or folded(top[2]) in folded(runner[2]))
    return top[0] >= ORE_FLOOR and top[1] >= ORE_RUN and (kin or (top[0] - runner[0]) >= ORE_MARGIN)


def table_for(name, build, locale=None):
    os.makedirs(CACHE, exist_ok=True)
    shape = "%s-%s%s.csv" % (name, build, "-" + locale if locale else "")
    target = os.path.join(CACHE, shape)
    if not os.path.exists(target):
        url = "https://wago.tools/db2/%s/csv?build=%s%s" % (
            name, build, "&locale=" + locale if locale else "")
        print("  fetch    %s %s %s" % (name, build, locale or ""), file=sys.stderr)
        request = urllib.request.Request(url, headers={"User-Agent": AGENT})
        open(target, "wb").write(urllib.request.urlopen(request, timeout=900).read())
    import csv
    return list(csv.DictReader(open(target, encoding="utf-8")))


def places_that_read_as_ore(build, ore_ids):
    """**Area ids whose name the vein rule would take for a metal.**

    Alberto, 2026-09-22, on being told that 11 of Era's 1,018 area names score as an ore:
    *just for the fact that you can know this, you can write an exception table.* Quite so -
    and it ships as **ids**, so the client names them and the exception holds in whatever
    language somebody plays in, which a table of names could not do.

    A name that collides in any one locale is excluded in all of them. Which locale it
    collides in is a fact about that language, and the id is the same node either way.
    """
    caught = set()
    for locale in LOCALES:
        items = table_for("ItemSparse", build, locale)
        ores = [r["Display_lang"] for r in items
                if int(r["ID"]) in ore_ids and r["Display_lang"]]
        # **A locale wago serves short scores against a short list and says nothing.**
        #
        # The Mists export for German returns 21,850 rows and for Spanish 15,640, against 88,746
        # for English - missing everything from Burning Crusade on, and the request succeeds.
        # Scored quietly, that locale contributes the collisions of the ores it happens to have
        # and none of the others, which is a table that looks complete and is not. Counted and
        # said out loud, per DATASOURCES section 3.
        if len(ores) < len(ore_ids):
            print("  %s %s: %d of %d ores named, so its collisions are only partly known"
                  % (build, locale, len(ores), len(ore_ids)), file=sys.stderr)
        if not ores:
            print("  %s %s: no ore names at all, so its collisions are unknown"
                  % (build, locale), file=sys.stderr)
            continue
        areas = table_for("AreaTable", build, locale)
        column = "AreaName_lang" if areas and "AreaName_lang" in areas[0] else None
        if not column:
            raise SystemExit("AreaTable has no AreaName_lang at %s - a column has moved" % build)
        for row in areas:
            name = row[column]
            if name and scores_as_an_ore(name, ores):
                caught.add(int(row["ID"]))
    return caught


def lua_table(path, opener):
    """One expansion-keyed generated table, read back out of the file the addon ships."""
    text = open(path, encoding="utf-8").read()
    start = text.index(opener)
    body = text[start:]
    out = {}
    for expansion in (1, 2, 5):
        key = "\t[%d] = {" % expansion
        if key not in body:
            continue
        at = body.index(key)
        after = [body.index("\t[%d] = {" % other) for other in (1, 2, 5)
                 if "\t[%d] = {" % other in body and body.index("\t[%d] = {" % other) > at]
        out[expansion] = body[at:min(after) if after else len(body)]
    if not out:
        raise SystemExit("no expansion blocks in %s - the generated shape has changed" % path)
    return out


def main():
    reagents_text = lua_table(os.path.join(ADDON, "RecipeReagents.lua"), "Family.RecipeReagents = {")
    products_text = lua_table(os.path.join(ADDON, "RecipeTeaches.lua"), "Family.RecipeProducts = {")

    lines = []
    for game, build in BUILDS.items():
        expansion = EXPANSION[game]
        by_skill = skill_lines(build)

        reagents = {}
        for match in re.finditer(r"\[(\d+)\]=\{([\d,]+)\}", reagents_text[expansion]):
            numbers = [int(n) for n in match.group(2).split(",")]
            reagents[int(match.group(1))] = numbers[0::2]

        products = {}
        for match in re.finditer(r"\[(\d+)\]\s*=\s*(\d+)", products_text[expansion]):
            products[int(match.group(1))] = int(match.group(2))

        herbs = set()
        for skill in HERB_CUSTOMERS:
            for spell in by_skill.get(skill, ()):
                herbs.update(reagents.get(spell, ()))

        smelts = by_skill.get(SMELTING, set())
        made = {products[spell] for spell in smelts if spell in products}
        ores = {reagents[spell][0] for spell in smelts
                if spell in products and len(reagents.get(spell, ())) == 1
                and reagents[spell][0] not in made}

        if not herbs or not ores:
            raise SystemExit("%s yielded %d herb(s) and %d ore(s) - a column has moved"
                             % (game, len(herbs), len(ores)))
        places = places_that_read_as_ore(build, ores)
        print("   %-28s %3d herbs, %2d ores, %2d places to refuse"
              % (game, len(herbs), len(ores), len(places)), file=sys.stderr)
        lines.append((expansion, game, sorted(herbs), sorted(ores), sorted(places)))

    with open(OUT, "w", encoding="utf-8") as out:
        out.write(HEADER)
        out.write("Family.Gathered = {\n")
        for expansion, game, herbs, ores, places in lines:
            out.write("\t-- %s\n\t[%d] = {\n" % (game, expansion))
            for name, ids in (("herbs", herbs), ("ores", ores), ("places", places)):
                out.write("\t\t%s = {\n" % name)
                for at in range(0, len(ids), 10):
                    out.write("\t\t\t" + ", ".join(str(i) for i in ids[at:at + 10]) + ",\n")
                out.write("\t\t},\n")
            out.write("\t},\n")
        out.write("}\n")
    print("wrote %s" % os.path.normpath(OUT), file=sys.stderr)


HEADER = '''-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What a gathering node in the world can be about. GENERATED - see tools/gathered.py.
--
-- Ids and nothing else, which is the whole point: a node hands over a name and no id, so the
-- name is compared against what the *client* calls these ids, in whatever language it is
-- running in. Not one word of any language is written down here.
--
-- Herbs are every item Alchemy and Inscription consume, which over-collects - Crystal Vial is
-- in it - and costs nothing, because a herb node is matched by its name exactly and no node in
-- the game is called Crystal Vial. A herb node is named exactly what the herb is named,
-- measured on Liferoot, Plaguebloom, Dreamfoil, Silverleaf and Peacebloom.
--
-- Ores are the smelts that take exactly one thing whose one thing is not itself smelted: ore to
-- bar and nothing else. A vein is not named after its ore - Copper Vein against Copper Ore - so
-- it is scored rather than matched, and Coal, Fiery Core and Elemental Flux in the running were
-- the closest wrong answers until they came out.

local _, Family = ...

-- expansion -> { herbs = { itemID, ... }, ores = { itemID, ... } }
'''

if __name__ == "__main__":
    main()
