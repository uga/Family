#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/Areas.lua from the client's own AreaTable.

Family records where a member's hearthstone is bound by storing the word GetBindLocation hands
back, which is the fault professions had (L-015) and races had after them: a word is one
language, and here it is not even that.

A French player on Burning Crusade reads "Forgefer". The same area, on a French Era client, is
"Ironforge" - Era's French AreaTable leaves a great many names in English, and appends the
English in brackets to a great many more ("Terres ingrates (Badlands)"). So two clients set to
the same language disagree, which no amount of recording the locale beside the word can fix.
Only an id can, and DATASOURCES.md section 3 already named the table it comes from.

    tools/areas.py --fetch     download the CSVs into a cache
    tools/areas.py             build the Lua from what is cached

Two things this file exists to get right:

  The answer depends on the build as well as the language, which is new here - Races.lua could
  let one build win because a race is called the same thing across all of them. An area is not,
  so the most recent build's name is the base and the older builds carry overrides where they
  differ. Overrides are about a tenth of the rows, so this costs little and is the only way an
  Era reader and a Mists reader can both be told the truth.

  An area whose name is identical in every locale and every build is left out entirely. There
  is nothing to translate: whatever client recorded it wrote the word every other client would
  have written. Carrying those rows would be carrying weight to say nothing.

WHAT THIS TOOL MEASURED, AND WHY ITS OUTPUT IS NOT SHIPPED
----------------------------------------------------------

Run against all fifteen CSVs on 2026-08-29 it produces **876 KB** of Lua, against an addon that
is 2,120 KB in total. A 41% increase to translate one column is not a trade worth making, so
Areas.lua is not in the tree and not in the .toc.

The trim above is worth almost nothing, which is the part worth knowing before anybody tries
this again. It removes **46 areas out of 4,215**. Measured on French alone it had looked like it
removed 1,628 of 1,774 - because French Era leaves so much untranslated that the two French
builds agree far more often than five languages ever will. German, Spanish and Russian translate
nearly every place name, so nearly every area varies and nearly every area has to be carried.

That leaves the size problem exactly where it started, and it means the question is no longer
about data. Every way of fixing the hearthstone column that does not ship 876 KB depends on
whether a client can turn an area id back into a word by itself - and that is a capability, not
a fact in a file. See L-020: the data question was answered here, and answering it is what
proved the remaining question is a different kind.

The tool is kept because the measurement cost fifteen fetches and because a narrowed table -
were there ever a defensible way to say which areas can be bound to - would start from here.
"""

import csv, io, os, sys, time, urllib.request

# wago.tools answers 403 to a request that does not say who is asking. urllib sends its own
# name by default and that is not enough, so the tool identifies itself and links to the
# project. tools/races.py and tools/skill-lines.py were written before this started being
# enforced and will need the same before their next --fetch.
AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

# Newest first: the most recent build's names are the base, older builds carry the overrides.
BUILDS = [
    ("Mists of Pandaria Classic", "5.5.4.69078", 5),
    ("Burning Crusade Anniversary", "2.5.6.69110", 2),
    ("Classic Era", "1.15.9.69109", 1),
]
LOCALES = ["enUS", "deDE", "frFR", "esES", "ruRU"]

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".areas-cache")


def path_for(build, locale):
    return os.path.join(CACHE, "%s-%s.csv" % (build, locale))


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for game, build, _ in BUILDS:
        for locale in LOCALES:
            target = path_for(build, locale)
            if os.path.exists(target) and os.path.getsize(target) > 0:
                print("  have   %s %s" % (game, locale))
                continue
            url = "https://wago.tools/db2/AreaTable/csv?build=%s&locale=%s" % (build, locale)
            print("  fetch  %s %s" % (game, locale))
            try:
                request = urllib.request.Request(url, headers={"User-Agent": AGENT})
                with urllib.request.urlopen(request, timeout=600) as response:
                    open(target, "wb").write(response.read())
                # Somebody else's server, asked fifteen times in a row. A second between
                # them costs this tool nothing and is the difference between a fetch and a
                # hammering.
                time.sleep(1)
            except Exception as why:
                print("  !      %s %s: %s" % (game, locale, why))


def rows_of(build, locale):
    target = path_for(build, locale)
    if not os.path.exists(target) or os.path.getsize(target) == 0:
        return None
    return list(csv.DictReader(io.StringIO(open(target, encoding="utf-8").read())))


def build_table():
    # names[expansion][locale][id] = name
    names, complaints = {}, []

    for game, build, expansion in BUILDS:
        for locale in LOCALES:
            rows = rows_of(build, locale)
            if rows is None:
                complaints.append("missing: %s %s" % (game, locale))
                continue
            here = names.setdefault(expansion, {}).setdefault(locale, {})
            for row in rows:
                name = row["AreaName_lang"].strip()
                if name:
                    here[int(row["ID"])] = name

    base_expansion = BUILDS[0][2]
    base = names.get(base_expansion, {})

    every_id = set()
    for per_locale in names.values():
        for ids in per_locale.values():
            every_id.update(ids)

    areas, skipped = {}, 0
    for area_id in sorted(every_id):
        # Every name any supported client has for this area. One distinct spelling means
        # nothing to translate and no reason to carry the row.
        spellings = set()
        for per_locale in names.values():
            for ids in per_locale.values():
                if area_id in ids:
                    spellings.add(ids[area_id])
        if len(spellings) <= 1:
            skipped += 1
            continue

        entry = {"base": {}, "overrides": {}}
        for locale in LOCALES:
            word = base.get(locale, {}).get(area_id)
            if word:
                entry["base"][locale] = word

        for _, _, expansion in BUILDS:
            if expansion == base_expansion:
                continue
            for locale in LOCALES:
                word = names.get(expansion, {}).get(locale, {}).get(area_id)
                if word and word != entry["base"].get(locale):
                    entry["overrides"].setdefault(expansion, {})[locale] = word

        if entry["base"] or entry["overrides"]:
            areas[area_id] = entry

    return areas, skipped, complaints


ACCESSORS = """
-- What to call the place a hearthstone is bound, in the words of whoever is reading.
--
-- In order:
--
-- 1. This table, by identity, for the reader's language AND the reader's expansion. Both are
--    needed and the second is what makes this file different from Races.lua: a French Era
--    client says "Ironforge" and a French Burning Crusade client says "Forgefer", so the
--    language alone does not settle it.
-- 2. The word that was recorded. Right when this client is the one that wrote it, and the
--    only thing there is for an area this table left out - which is most of them, because an
--    area every client spells the same way needs no entry here.
-- 3. English, then nothing. A place in the wrong language still tells a player where their
--    hearthstone is; a blank does not.
function Family:AreaName(id, recorded)
	if type(id) == "string" then
		id = Family.AreaByName[id] or id
	end

	local entry = type(id) == "number" and Family.Areas[id]
	if entry then
		local override = entry.by and entry.by[Family.Capabilities.expansion]
		if override and override[Family.locale] then return override[Family.locale] end
		if entry.names[Family.locale] then return entry.names[Family.locale] end
	end

	if recorded and recorded ~= "" then return recorded end
	return entry and entry.names.enUS or nil
end

-- The id behind whatever this client just called a place.
--
-- Used where the client hands back a name and nothing else, which for a bind location is
-- always: GetBindLocation returns a word and there is no call that returns its id.
function Family:AreaFor(name)
	if type(name) ~= "string" or name == "" then return nil end
	return Family.AreaByName[name]
end
"""


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def emit(areas, out_path):
    lines = []
    add = lines.append
    add('-- Family - an alt manager for World of Warcraft Classic')
    add('-- Copyright (C) 2026 Alberto Pittaluga')
    add('--')
    add('-- This program is free software: you can redistribute it and/or modify it under the')
    add('-- terms of the GNU General Public License as published by the Free Software')
    add('-- Foundation, either version 3 of the License, or (at your option) any later version.')
    add('-- See the LICENSE file at the root of this repository.')
    add('')
    add('-- What each client calls each place. GENERATED - see tools/areas.py.')
    add('--')
    add("-- Family records a hearthstone's home as the word GetBindLocation hands back, and a")
    add('-- word is one language. Here it is not even that: a French Era client calls area 1537')
    add('-- "Ironforge" and a French Burning Crusade client calls it "Forgefer", so two clients')
    add('-- set to the same language disagree and recording the language beside the word cannot')
    add('-- help. Era leaves a great many French names in English and brackets the English onto')
    add('-- a great many more - "Terres ingrates (Badlands)" where Burning Crusade says "Terres')
    add('-- ingrates". Only the id settles it.')
    add('--')
    add('-- So the base names below are the most recent build\'s, and the older builds carry')
    add('-- overrides where they differ. A reader is answered for their language and their')
    add('-- expansion, not just their language.')
    add('--')
    add('-- Areas every supported client spells identically are not here at all. There is')
    add('-- nothing to translate for them: whichever client recorded one wrote the word every')
    add('-- other client would have written, and the recorded word is used as it stands.')
    add('')
    add('local _, Family = ...')
    add('')
    add('Family.Areas = {')

    for area_id in sorted(areas):
        entry = areas[area_id]
        add('\t[%d] = {' % area_id)
        add('\t\tnames = { %s },' % ", ".join(
            "%s = %s" % (locale, lua_string(word))
            for locale, word in sorted(entry["base"].items())))
        if entry["overrides"]:
            add('\t\tby = {')
            for expansion in sorted(entry["overrides"]):
                add('\t\t\t[%d] = { %s },' % (expansion, ", ".join(
                    "%s = %s" % (locale, lua_string(word))
                    for locale, word in sorted(entry["overrides"][expansion].items()))))
            add('\t\t},')
        add('\t},')

    add('}')
    add('')
    add("-- The other direction, built once: what any client calls a place, to its id. Every")
    add('-- language and every build is indexed, because the word being resolved was written by')
    add('-- somebody else\'s client and there is nothing in it to say which.')
    add('Family.AreaByName = {}')
    add('for id, entry in pairs(Family.Areas) do')
    add('\tfor _, word in pairs(entry.names) do')
    add('\t\tFamily.AreaByName[word] = id')
    add('\tend')
    add('\tfor _, words in pairs(entry.by or {}) do')
    add('\t\tfor _, word in pairs(words) do')
    add('\t\t\tFamily.AreaByName[word] = id')
    add('\t\tend')
    add('\tend')
    add('end')
    add('')
    add('-' * 92)
    add('')
    add(ACCESSORS.strip())
    open(out_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()

    areas, skipped, complaints = build_table()
    if complaints:
        print("\n".join("  ! " + c for c in complaints))
    if not areas:
        print("nothing built - run with --fetch first")
        sys.exit(1)

    out = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                        "..", "addons", "Family", "Areas.lua"))
    emit(areas, out)
    print("%d areas carried, %d left out as spelled the same everywhere -> %s (%.0f KB)"
          % (len(areas), skipped, os.path.relpath(out), os.path.getsize(out) / 1024))
