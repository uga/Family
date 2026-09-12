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

# Effect 36 is LEARN_SPELL and effect 24 is CREATE_ITEM. Numeric and the same on every build.
LEARN_SPELL = 36
CREATE_ITEM = 24
PRIMARY_CATEGORY = "11"

# Cooking and First Aid are category 9, not 11, and that is why the two lanes above have never
# had a word to say about them: they are built from the primary skill lines only. The third
# table below is the one that has to reach them, so it asks both.
PROFESSION_CATEGORIES = {"9", "11"}

# ...and it is emitted for Classic Era alone. A trade skill record there carries the product's
# item id and no spell (DATASOURCES section 2), while Mists answers with both - measured, 8
# smelting recipes with a spell id and an item id each. The claim that Burning Crusade behaves
# as Mists does was measured on smelting and is wrong for enchanting; the RecipeProducts lane
# below answers on every build, and MadeBy reads it backwards, so this table stays as it was.
MADE_BY_BUILDS = {"Classic Era"}

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
    teaches, makes, madeby, spell_makes = {}, {}, {}, {}
    shared = 0

    for game, build_id in BUILDS.items():
        skill_lines = read("SkillLine", build_id)
        professions = {int(r["ID"]) for r in skill_lines
                       if r.get("CategoryID") == PRIMARY_CATEGORY}
        taught = {int(r["Spell"]) for r in read("SkillLineAbility", build_id)
                  if int(r["SkillLine"]) in professions}

        # Every profession, primary and secondary, for the third table only.
        every = {int(r["ID"]) for r in skill_lines
                 if r.get("CategoryID") in PROFESSION_CATEGORIES}
        craftable = {int(r["Spell"]) for r in read("SkillLineAbility", build_id)
                     if int(r["SkillLine"]) in every}

        # Both halves of the join come out of one pass: which spell a spell teaches, and
        # which item a spell makes.
        learns, made = {}, {}
        for row in read("SpellEffect", build_id):
            effect = int(row.get("Effect") or 0)

            if effect == LEARN_SPELL:
                trigger = int(row.get("EffectTriggerSpell") or 0)
                if trigger:
                    learns.setdefault(int(row["SpellID"]), trigger)

            elif effect == CREATE_ITEM:
                product = int(row.get("EffectItemType") or 0)
                if product:
                    spell = int(row["SpellID"])
                    made.setdefault(spell, set()).add(product)

                    # And the same rows read the other way round, for the table that
                    # answers a record holding a product and nothing else. Only where a
                    # profession teaches the spell, so that quest rewards, consumables and
                    # everything else that creates an item stay out of it. Lowest spell id
                    # where two make the same thing, so two runs of this tool agree.
                    if game in MADE_BY_BUILDS and spell in craftable:
                        here = madeby.setdefault(EXPANSION[game], {})
                        if product not in here or spell < here[product]:
                            here[product] = spell

        # **The spell a recipe row holds -> the item it makes**, on every build.
        #
        # Read from play 2026-09-12 on Burning Crusade: an enchanting recipe that makes a thing -
        # Lesser Magic Wand - showed as a spell, so none of Family's blocks about the thing
        # appeared: who holds one, what it takes, what it is worth. The row had the spell and no
        # item, which is what the Craft frame gives. The comment beside MADE_BY_BUILDS says
        # Burning Crusade records carry both ids; for enchanting they plainly do not, and that
        # claim was measured on smelting.
        #
        # So this lane is emitted for all three, from the same rows as the one below it. Only
        # spells a profession teaches, as there. **A spell that creates more than one thing is
        # left out** rather than given one of them: it has no single product, and the build is
        # not refused over it either, because it says nothing about any other spell.
        for spell, things in made.items():
            if spell not in craftable:
                continue
            if len(things) != 1:
                shared += 1
                continue
            spell_makes.setdefault(EXPANSION[game], {})[spell] = next(iter(things))

        # Two shapes, and only one of them was handled at first - which is why two builds out
        # of three came back with nothing at all.
        #
        # On Classic Era the item's spell *teaches* another: effect 36 with a trigger, and the
        # trigger is the recipe. On Burning Crusade and Mists a recipe item carries two rows -
        # a generic 483 "Learning" with no trigger, and the craft spell itself. So the taught
        # spell is either the row's own spell where a profession teaches it, or the trigger of
        # an effect-36 row where a profession teaches that.
        here, products_here = 0, 0
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

            # And what that spell makes, which is the other lane of the same join.
            #
            # A Classic Era trade skill record carries the product's item id and no spell
            # at all (DATASOURCES section 2), so the spell above cannot reach it and this
            # can. Measured at the pinned builds: 908 of Era's 1008 recipe items name a
            # product, and of the hundred that do not, 96 are enchanting - which is the
            # half the spell lane already answers.
            products = made.get(lesson) or set()
            if len(products) > 1:
                sys.exit("spell %d makes %s on %s - a recipe that makes two different "
                         "things has no single product, and picking one would be guessing"
                         % (lesson, sorted(products), game))
            if products:
                makes.setdefault(EXPANSION[game], {})[item] = next(iter(products))
                products_here += 1

        print("  %-30s %4d recipe items, %4d of them naming what they make"
              % (game, here, products_here))

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
        "--",
        "-- Two lanes, because the clients disagree about which id a recipe record carries.",
        "-- Classic Era's trade skill window gives the item a recipe makes and no spell at",
        "-- all; its Craft frame gives the enchant's spell and no item. So a recipe item is",
        "-- matched by the spell it teaches where the record has one, and by the item that",
        "-- spell makes where it has the other - and the name test is left for neither.",
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

    lines += [
        "-- recipe item -> the item that recipe makes",
        "--",
        "-- The same join read to its end. A Classic Era trade skill record carries this id",
        "-- and no spell, so this is the lane that answers there - measured at the pinned",
        "-- build: 908 of Era's 1008 recipe items name a product, and 96 of the hundred that",
        "-- do not are enchanting, which the spell lane above already answers.",
        "Family.RecipeMakes = {",
    ]
    for xpac in sorted(EXPANSION.values()):
        lines.append("\t[%d] = {" % xpac)
        for item in sorted(makes.get(xpac, {})):
            lines.append("\t\t[%d] = %d," % (item, makes[xpac][item]))
        lines.append("\t},")
    lines += ["}", ""]

    lines += [
        "-- the item a recipe makes -> the spell that makes it",
        "--",
        "-- The two lanes above are keyed by the **recipe item** - the pattern in somebody's",
        "-- bags. A Classic Era trade skill record holds neither: it holds the *product* and no",
        "-- spell at all. So a professions row on that client knew what a recipe makes and not",
        "-- what makes it, and the CTRL swap between the two readings had nothing to swap to -",
        "-- reported from play on 2026-09-05 as broken when it was doing what it was told.",
        "--",
        "-- Inverting RecipeMakes answers for a recipe an item taught and not for one a trainer",
        "-- taught, which is why cooking and first aid stayed silent while leatherworking",
        "-- worked. This is built from SpellEffect directly, so a trainer's recipe is in it too,",
        "-- and it asks the **secondary** skill lines as well - Cooking and First Aid are",
        "-- category 9, and every other table here reads category 11.",
        "--",
        "-- Classic Era only. The other two builds are answered by RecipeProducts at the end of",
        "-- this file, read backwards: the claim that they carry both ids on every record was",
        "-- measured on smelting and is wrong for enchanting (DATASOURCES, 2026-09-12).",
        "Family.RecipeMadeBy = {",
    ]
    for xpac in sorted(EXPANSION.values()):
        if xpac not in madeby:
            continue
        lines.append("\t[%d] = {" % xpac)
        for item in sorted(madeby[xpac]):
            lines.append("\t\t[%d] = %d," % (item, madeby[xpac][item]))
        lines.append("\t},")
    lines += ["}", ""]

    lines += [
        "-- the spell a recipe is -> the one item it makes",
        "--",
        "-- On every build. An enchanting recipe that makes a thing - a wand, a rod, an oil - is",
        "-- recorded from the Craft frame with its spell and no item, on Burning Crusade as well as",
        "-- on Era: read from play 2026-09-12, where Lesser Magic Wand showed as a spell and so",
        "-- carried none of what Family says about a thing. This names the thing. A spell that",
        "-- creates more than one item is not in it, having no single product to name.",
        "Family.RecipeProducts = {",
    ]
    for xpac in sorted(EXPANSION.values()):
        if xpac not in spell_makes:
            continue
        lines.append("\t[%d] = {" % xpac)
        for spell in sorted(spell_makes[xpac]):
            lines.append("\t\t[%d] = %d," % (spell, spell_makes[xpac][spell]))
        lines.append("\t},")
    lines += ["}", ""]

    if not spell_makes:
        sys.exit("no spell named a product - CREATE_ITEM or a column has moved, and an empty "
                 "table would look like a quiet success")

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    print("\n  %d recipe items across %d expansions, %d of them naming what they make"
          % (sum(len(v) for v in teaches.values()), len(teaches),
             sum(len(v) for v in makes.values())))
    print("  %d products naming what makes them, on %d build(s)"
          % (sum(len(v) for v in madeby.values()), len(madeby)))
    print("  %d recipe spells naming the one thing they make, on %d build(s); %d making more "
          "than one thing, left out" % (sum(len(v) for v in spell_makes.values()), len(spell_makes),
                                       shared))


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    build()
