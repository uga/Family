#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/MadeByItem.lua - things made by using an item rather than a recipe.

Refined Deeprock Salt is not on anybody's recipe list. It comes out of a Salt Shaker, which is
an item with a four-day cooldown, and asking *who can make me one* means asking who owns a Salt
Shaker and whether theirs is ready. Family knew both halves - it indexes who owns what, and it
already watches items that go on cooldown - and had nothing joining them, so hovering the salt
said who had some and nothing about who could make more. Reported from play.

**The chain, in the client's own tables.** `ItemEffect.ParentItemID` gives the item, its
`SpellID` gives the spell that item casts, and `SpellEffect` with `Effect` 24 - create item -
gives what that spell makes in `EffectItemType`. Measured 2026-08-31; nothing in the client's
API exposes it, so it is generated here.

**Only the ones on a cooldown**, which is the whole of the filter and is what keeps this
useful. 584 items on Classic Era create another item and most are noise - a Staff of Conjuring
makes a Conjured Muffin, a Muisek Vessel makes a Muisek - and being told which of your
characters owns a Lei of Lilies when you hover a Lily Root answers nothing anybody asked. A
cooldown is what makes an item a thing you go to a particular character for, which is the
question this addon exists to answer. That takes Era from 584 to 58.

Several items can legitimately make one thing, so each entry is a list rather than a single
maker - two OLDCeremonial Clubs both make Broken Tools, and refusing that was the first thing
this tool did. Nothing is filtered by name: an "OLD" prefix is a judgement about what matters,
encoded in a generator, and it goes stale the day one of them comes back.

    tools/made-by-item.py --fetch     download what is missing into a cache
    tools/made-by-item.py             build the Lua from what is cached

Re-run at a new build. It refuses rather than guesses: a build that yields nothing at all means
a column or an effect number has moved, and an empty table would look like a quiet success.
"""

import csv, os, shutil, sys, urllib.request

AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}

# Effect 24 is CREATE_ITEM. Numeric and the same on every build, unlike anything named.
CREATE_ITEM = 24

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".made-by-item-cache")
OUT = os.path.join(HERE, "..", "addons", "Family", "MadeByItem.lua")

# ItemEffect is already sitting in the charged-items cache at the same builds. Copied rather
# than fetched again: same file, same server, and that server is given away for nothing.
BORROW = {
    "ItemEffect": (os.path.join(HERE, ".charged-items-cache"), "ItemEffect-%(build)s.csv"),
    "ItemSparse": (os.path.join(HERE, ".game-words-cache"), "ItemSparse-%(build)s-enUS.csv"),
    "SkillLine": (os.path.join(HERE, ".skill-lines-cache"), "%(build)s-enUS.csv"),
    "SkillLineAbility": (os.path.join(HERE, ".specialisations-cache"),
                         "SkillLineAbility-%(build)s.csv"),
}
TABLES = ["ItemEffect", "SpellEffect", "ItemSparse", "SkillLine", "SkillLineAbility",
          "SpellReagents"]

PRIMARY_CATEGORY = "11"


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
    makers, seen_in = {}, {}

    for game, build_id in BUILDS.items():
        # What each maker demands of whoever picks it up. A Salt Shaker is no use to a
        # character who owns one and has 200 leatherworking, so the table carries the
        # condition and not only the join. Reported from play, and the client's own table
        # had it all along.
        needs = {}
        for row in read("ItemSparse", build_id):
            skill = int(row.get("RequiredSkill") or 0)
            if skill:
                needs[int(row["ID"])] = (skill, int(row.get("RequiredSkillRank") or 0))

        creates = {}
        for row in read("SpellEffect", build_id):
            if int(row.get("Effect") or 0) != CREATE_ITEM:
                continue
            made = int(row.get("EffectItemType") or 0)
            if made:
                creates.setdefault(int(row["SpellID"]), made)

        # Which of these makers a profession itself makes.
        #
        # A Chronoboon Displacer creates a Supercharged one and has an hour's cooldown, so it
        # is a maker like any other - and it turned up as a column on the **Crafting** panel
        # beside Alchemy and Salt Shaker, which is not what that panel is about. Reported from
        # play. A crafting cooldown belongs to something a profession makes: of 147 makers,
        # three are - the Salt Shaker, the SnowMaster 9000 and a Heavy Leather Ball - and the
        # Chronoboon is not among them.
        #
        # Marked rather than dropped, because the other use of this table is "who can make me
        # one of these", and there the Chronoboon belongs perfectly well.
        professions = {int(r["ID"]) for r in read("SkillLine", build_id)
                       if r.get("CategoryID") == PRIMARY_CATEGORY}
        taught = {int(r["Spell"]) for r in read("SkillLineAbility", build_id)
                  if int(r["SkillLine"]) in professions}
        # Which profession spells make which item. Kept as a set per item rather than a flag,
        # because the reagent test below has to be able to ignore them.
        craftedBy = {}
        for row in read("SpellEffect", build_id):
            if int(row.get("Effect") or 0) == CREATE_ITEM and int(row["SpellID"]) in taught:
                made = int(row.get("EffectItemType") or 0)
                if made:
                    craftedBy.setdefault(made, set()).add(int(row["SpellID"]))

        # And which products a profession actually uses.
        #
        # "Crafted by a profession" was not enough on its own. A Super Snapper FX is an
        # engineering item with a cooldown that makes something, and it turned up as a column
        # on the Crafting panel - reported from play, right after a Chronoboon Displacer did.
        # What separates a salt shaker from a toy is not how the maker was obtained but what
        # the thing it makes is *for*: Refined Deeprock Salt and Snowballs are reagents in
        # somebody's recipe, and a Snapshot of Gammerita is not.
        usedBy = {}
        for row in read("SpellReagents", build_id):
            spell = int(row["SpellID"])
            if spell not in taught:
                continue
            for column, value in row.items():
                if column.startswith("Reagent_") and not column.startswith("ReagentCount"):
                    item = int(value or 0)
                    if item:
                        usedBy.setdefault(item, set()).add(spell)

        here = 0
        for row in read("ItemEffect", build_id):
            parent = int(row.get("ParentItemID") or 0)
            spell = int(row.get("SpellID") or 0)
            if not parent or spell not in creates:
                continue

            # A cooldown of its own, or a shared category cooldown. Either makes the item a
            # thing somebody has to go to a particular character for.
            waits = (int(row.get("CoolDownMSec") or 0) > 0
                     or int(row.get("CategoryCoolDownMSec") or 0) > 0)
            if not waits:
                continue

            made = creates[spell]
            skill, rank = needs.get(parent, (0, 0))
            # A profession makes the maker, and something *other than the maker's own recipe*
            # uses what it makes.
            #
            # That last clause is not fussiness. Without it a SnowMaster 9000 qualifies: the
            # engineering recipe that builds one takes Snowballs, and a SnowMaster makes
            # Snowballs, so the product is a reagent of the very recipe that makes the thing
            # producing it. Reported from play - "in how far is a Snowball a profession
            # reagent" - and the loop is the whole of the answer. Excluding it leaves exactly
            # one item on Classic Era: a Salt Shaker, whose Refined Deeprock Salt goes into
            # Cured Rugged Hide.
            was = makers.setdefault(made, {}).get(parent)
            elsewhere = usedBy.get(made, set()) - craftedBy.get(parent, set())
            useful = bool(craftedBy.get(parent)) and bool(elsewhere)
            makers[made][parent] = (skill, rank, useful or bool(was and was[2]))
            seen_in.setdefault(made, set()).add(game)
            here += 1

        print("  %-30s %3d things made by an item on a cooldown" % (game, here))

    if not makers:
        sys.exit("nothing came out at all - a column or the CREATE_ITEM number has moved, and "
                 "an empty table would look like a quiet success")

    lines = [
        "-- Generated by tools/made-by-item.py. Do not edit.",
        "--",
        "-- What is made by *using an item* rather than by a recipe, for the items that make",
        "-- somebody wait. Refined Deeprock Salt comes out of a Salt Shaker and is on nobody's",
        "-- recipe list, so the question \"who can make me one\" is really \"who owns the",
        "-- shaker, and is theirs ready\" - and Family already knows both halves.",
        "--",
        "-- From ItemEffect and SpellEffect - see DATASOURCES.md. Ids throughout.",
        "",
        "local _, Family = ...",
        "",
        "-- what is made -> the items that make it, each with what it demands of its owner",
        "Family.MadeByItem = {",
    ]
    for made in sorted(makers):
        parts = []
        for parent in sorted(makers[made]):
            skill, rank, madeByHand = makers[made][parent]
            bits = ["item = %d" % parent]
            if skill:
                bits.append("skill = %d" % skill)
                bits.append("rank = %d" % rank)
            if madeByHand:
                # Made by a profession, and what it makes is a reagent in one. Both, because
                # either alone lets a toy through - see the note above the reagent scan.
                bits.append("crafting = true")
            parts.append("{ %s }" % ", ".join(bits))
        lines.append("\t[%d] = { %s }," % (made, ", ".join(parts)))
    lines += ["}", ""]

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    everywhere = len([m for m in seen_in if len(seen_in[m]) == len(BUILDS)])
    gated = len([m for m in makers if any(v[0] for v in makers[m].values())])
    print("\n  %d things in the union, %d of them on all three builds, %d whose maker "
          "demands a profession" % (len(makers), everywhere, gated))


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    build()
