#!/usr/bin/env python3
# Family - an alt manager for World of Warcraft Classic
# Copyright (C) 2026 Alberto Pittaluga
#
# This program is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# See the LICENSE file at the root of this repository.

"""The game's own word for every game noun Family's own text uses.

    tools/game-words.py --fetch     download the CSVs into a cache (large - see below)
    tools/game-words.py             check the locale files against what is cached

Family writes sentences that name things in the game: "transmutes, mooncloth, salt shakers".
Those nouns were **translated by hand**, and a hand-translated item name is a name no player
will recognise, because the word on their screen came from Blizzard and the word in our
sentence came from somebody's best guess. A French player found two of them - "etoffe de lune"
for Mooncloth, "saliere" for Salt Shaker - and finding them needed a French player.

Nobody was going to find the Spanish and Russian ones, so this asks the client's own tables
instead. Every noun below is an id; the id is looked up per locale; and each locale file is
searched for the answer. Which is §2.1 applied to our own prose rather than only to our data.

**What this deliberately does not check.** A spell name that is a verb phrase cannot be
pluralised into a sentence - the game says "Transmute: Arcanite", "Transmutieren: Arkanit",
"Transmutation d'arcanite", and our text says "transmutes" as an ordinary plural noun. There is
no game string for that, so forcing one would make the sentence worse rather than righter. The
same goes for "auction house", "mailbox" and "guild bank": those are places and panels, named
by Blizzard globals the client supplies at runtime rather than by anything in a DB2 - and they
are ordinary words in every language here. Only nouns with an id are checked.

**The cache is large**: ItemSparse is about nine megabytes per locale per build, so a full
fetch is roughly 130MB into tools/.game-words-cache/, once. It is gitignored.
"""

import csv, io, os, re, sys, unicodedata, urllib.request

BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}
LOCALES = ["enUS", "deDE", "frFR", "esES", "ruRU"]
TRANSLATED = ["deDE", "frFR", "esES", "ruRU"]

AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".game-words-cache")
LOCALE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "..", "addons", "Family", "Locales")

# Every noun from the game that Family's own sentences use, by id.
#
# Found rather than remembered: the whole of the English text was matched against ItemSparse's
# own name column, single words and phrases alike, and this is what came back. Re-run that scan
# when new prose is written - a noun that is not in this list is a noun nothing checks.
#
#   table, id, the English word as our text writes it
NOUNS = [
    ("ItemSparse", 14342, "mooncloth"),
    ("ItemSparse", 15846, "salt shaker"),
    ("ItemSparse", 4338, "mageweave"),
    ("ItemSparse", 6948, "hearthstone"),
]

NAME_COLUMN = {"ItemSparse": "Display_lang", "SpellName": "Name_lang"}


def path_for(table, build, locale):
    return os.path.join(CACHE, "%s-%s-%s.csv" % (table, build, locale))


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    tables = sorted({table for table, _, _ in NOUNS})

    for table in tables:
        for game, build in BUILDS.items():
            for locale in LOCALES:
                target = path_for(table, build, locale)
                if os.path.exists(target):
                    print("  have   %s %s %s" % (table, game, locale))
                    continue
                url = ("https://wago.tools/db2/%s/csv?build=%s&locale=%s"
                       % (table, build, locale))
                print("  fetch  %s %s %s" % (table, game, locale))

                # A User-Agent, because wago.tools answers 403 to Python's default one.
                # Measured 2026-08-30: the same URL is 200 to curl and 403 to a bare
                # urlopen, and 200 again the moment a header is set.
                #
                # Saying who we are rather than pretending to be curl. This is somebody
                # else's server given away for nothing, and a tool that lies about itself
                # in order to be served is not a tool to write.
                request = urllib.request.Request(url, headers={"User-Agent": AGENT})
                with urllib.request.urlopen(request, timeout=600) as response:
                    open(target, "wb").write(response.read())


def names_in(table, build, locale, wanted):
    """{id: name} for the ids asked about, or None where that CSV is not cached."""
    target = path_for(table, build, locale)
    if not os.path.exists(target):
        return None

    column = NAME_COLUMN[table]
    found = {}
    with open(target, encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            try:
                identifier = int(row["ID"])
            except (KeyError, ValueError):
                continue
            if identifier in wanted:
                found[identifier] = row.get(column, "")
    return found


def locale_text(code):
    with open(os.path.join(LOCALE_DIR, "%s.lua" % code), encoding="utf-8") as handle:
        return handle.read()


def main():
    if "--fetch" in sys.argv:
        fetch()
        print()

    wanted = {}
    for table, identifier, _ in NOUNS:
        wanted.setdefault(table, set()).add(identifier)

    # **Every** name each build gives, not one. Two builds disagreeing is a real thing -
    # skill-lines.py found Spanish renaming a profession between Era and Burning Crusade -
    # and where they do, a locale file using either of them is using the game's word for
    # somebody, which is what this is for. The disagreement is reported so that whoever
    # writes the sentence knows it is there.
    resolved, missing = {}, False

    for table, ids in wanted.items():
        for locale in LOCALES:
            for game, build in BUILDS.items():
                got = names_in(table, build, locale, ids)
                if got is None:
                    missing = True
                    continue
                for identifier, name in got.items():
                    if name:
                        resolved.setdefault((locale, identifier), []).append((game, name))

    if missing:
        print("some CSVs are not cached - run with --fetch first")
        print()

    def variants(code, identifier):
        seen, out = set(), []
        for _, name in resolved.get((code, identifier), []):
            if name not in seen:
                seen.add(name)
                out.append(name)
        return out

    width = max(len(word) for _, _, word in NOUNS)
    print("%-*s  %s" % (width, "our word", "  ".join("%-26s" % c for c in TRANSLATED)))
    for _, identifier, word in NOUNS:
        cells = ["%-26s" % (" / ".join(variants(code, identifier)) or "?")
                 for code in TRANSLATED]
        print("%-*s  %s" % (width, word, "  ".join(cells)))

    disagreed = [(code, identifier, word) for _, identifier, word in NOUNS
                 for code in TRANSLATED if len(variants(code, identifier)) > 1]
    if disagreed:
        print()
        print("builds disagree about these, so either word is the game's word to somebody:")
        for code, identifier, word in disagreed:
            for game, name in resolved[(code, identifier)]:
                print("  %s %d (%s): %s says %r" % (code, identifier, word, game, name))

    # And the half that makes this a check rather than a listing: does each locale file
    # actually say what the client says?
    #
    # Two things the comparison has to allow, both found by it crying wolf about a line that
    # was right. **Accents on capitals**: the table says "Etoffe lunaire" where a French
    # sentence says "etoffe lunaire", and dropping the accent on a capital is a French
    # convention rather than a different word. **Inflection**: our sentences list these in the
    # plural, and Russian makes a plural by changing the ending, so "solonka" has to match
    # "solonki". A stem is compared for that reason, and a stem match is reported as one so
    # that nobody reads it as an exact hit.
    def flatten(text):
        text = unicodedata.normalize("NFD", text.lower())
        return "".join(c for c in text if not unicodedata.combining(c))

    print()
    wrong = 0
    for code in TRANSLATED:
        text = flatten(locale_text(code))
        for _, identifier, word in NOUNS:
            options = variants(code, identifier)
            if not options:
                continue

            exact = [n for n in options if flatten(n) in text]
            stems = [n for n in options
                     if len(flatten(n)) > 4 and flatten(n)[:-2] in text]

            if exact:
                continue
            if stems:
                print("  %s uses an inflected form of %r (id %d) - read it and be sure"
                      % (code, stems[0], identifier))
                continue

            wrong += 1
            print("  %s uses none of %s (id %d, our word %r)"
                  % (code, " / ".join(repr(n) for n in options), identifier, word))

    if wrong == 0 and not missing:
        print("  every locale uses the game's own word for every noun above")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
