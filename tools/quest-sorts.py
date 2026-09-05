#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/QuestSorts.lua - what the game calls a quest category that is not a zone.

A quest log groups by heading, and Family records the heading as a word. Most headings are
zones, and a zone has an id: the log carries one per heading since 2026-09-05, so a French
sibling's quests file under the reader's own word for the same place.

The headings that are **not** zones had nothing. A class quest sits under "Demoniste" on a
French client and "Warlock" on an English one, and so do the profession headings - which are
not the profession names either: the French for Cooking is "Cuisine" and the heading says
"Cuisinier". They come from QuestSort, which is its own small table.

    tools/quest-sorts.py --fetch     download the CSVs into a cache
    tools/quest-sorts.py             build the Lua from what is cached

Small enough that there is nothing to weigh: 36 rows on Era, 55 on Mists, under 1 KB of CSV
per locale. This is the case the 876 KB of area names was not (L-020).

Every build's names are merged into one row per id rather than kept apart. Nothing here is
recorded by id - the reader is handed a word and asks which row holds it - so a sort renamed
between builds wants **both** words pointing at the same row, which is exactly what a family
playing across two clients needs.

The dead rows are dropped. Blizzard leaves the retired ones in place as "REUSE - old wailing
caverns" and those are not names anybody's client will draw.
"""

import csv, os, sys, urllib.request

AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}
LOCALES = ["enUS", "deDE", "frFR", "esES", "ruRU"]

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".quest-sorts-cache")
OUT = os.path.join(HERE, "..", "addons", "Family", "QuestSorts.lua")


def path_for(build, locale):
    return os.path.join(CACHE, "%s-%s.csv" % (build, locale))


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for game, build in BUILDS.items():
        for locale in LOCALES:
            target = path_for(build, locale)
            if os.path.exists(target):
                print("  have   %s %s" % (game, locale))
                continue
            url = ("https://wago.tools/db2/QuestSort/csv?build=%s&locale=%s"
                   % (build, locale))
            print("  fetch  %s %s" % (game, locale))
            request = urllib.request.Request(url, headers={"User-Agent": AGENT})
            open(target, "wb").write(urllib.request.urlopen(request, timeout=600).read())


def build():
    # names[id][locale] = [word, ...] in the order the builds were read
    names, dead = {}, set()

    for game, build_id in BUILDS.items():
        for locale in LOCALES:
            target = path_for(build_id, locale)
            if not os.path.exists(target):
                sys.exit("no cache for %s %s - run with --fetch" % (game, locale))

            for row in csv.DictReader(open(target, encoding="utf-8")):
                sort = int(row["ID"])
                word = (row.get("SortName_lang") or "").strip()
                if not word:
                    continue

                # Retired rows, named after what they used to be. Marked from the English
                # only, because that is where Blizzard writes the note.
                if locale == "enUS" and word.upper().startswith("REUSE"):
                    dead.add(sort)
                    continue

                here = names.setdefault(sort, {}).setdefault(locale, [])
                if word not in here:
                    here.append(word)

    for sort in dead:
        names.pop(sort, None)

    if not names:
        sys.exit("nothing came out at all - a column has moved, and an empty table would "
                 "look like a quiet success")

    lines = [
        "-- What the game calls a quest category that is not a zone. GENERATED - see",
        "-- tools/quest-sorts.py.",
        "--",
        "-- A quest log groups by heading, and a heading is a word. Most of them are zones and a",
        "-- zone has an id, so those already read in the language of whoever is looking. The rest",
        "-- had nothing: a warlock's quests sit under \"Demoniste\" on a French client and",
        "-- \"Warlock\" on an English one, and so did the profession headings - which are not the",
        "-- profession names either, the French for Cooking being \"Cuisine\" while the heading",
        "-- says \"Cuisinier\".",
        "--",
        "-- Read by the **word**, not by an id: nothing records one of these, so what a reader has",
        "-- is whatever the recording client wrote. Every build's names sit in one row for that",
        "-- reason - a sort renamed between builds wants both words finding the same row.",
        "",
        "local _, Family = ...",
        "",
        "Family.QuestSorts = {",
    ]
    for sort in sorted(names):
        lines.append("\t[%d] = {" % sort)
        for locale in LOCALES:
            words = names[sort].get(locale)
            if words:
                lines.append("\t\t%s = { %s },"
                             % (locale, ", ".join('"%s"' % w.replace('"', '\\"')
                                                  for w in words)))
        lines.append("\t},")
    lines += ["}", ""]

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    print("  %d sorts, %d retired rows dropped" % (len(names), len(dead)))


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    build()
