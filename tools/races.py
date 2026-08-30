#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/Races.lua from the client's own ChrRaces table.

Races had the same fault professions had (L-015): a member's race was shown from the word the
recording client happened to use, so a character last logged in on a French client read
"Gnome" in French on a Spanish one, and a borrowed Wide Family member read in whatever their
owner was running. The identity was there all along - UnitRace's second return is a
language-neutral file string - and there was nothing to turn it back into a word with.

The data is Blizzard's own, served per build by wago.tools, which DATASOURCES.md section 3
pins builds for. Nothing here is typed from memory.

    tools/races.py --fetch     download the CSVs into a cache
    tools/races.py             build the Lua from what is cached

Two things this file exists to get right, both of which a hand-written table gets wrong:

  Playable is read from PlayableRaceBit, not decided. ClientFileString is not unique - race
  23 is also "Human", the Gilnean one - so a file-string map built from every row names every
  human "Gilnean" on a Mists client. PlayableRaceBit is -1 for that row and for every other
  race a player cannot be.

  Both forms of the name are kept, base first - not to choose between them, but to recognise
  a word some client already wrote. Era genders race names in Russian and not in German,
  French or Spanish; Burning Crusade and Mists gender all four. Era wins where they disagree,
  because Era is what most of this family plays and a word its client does not use is worse
  than the plain one.
"""

import csv, io, os, sys, urllib.request

# Era first: it is what most of the family plays, so it wins where two builds disagree.
# wago.tools answers 403 to Python's default User-Agent, measured 2026-08-30: the same URL is
# 200 to curl, 403 to a bare urlopen, and 200 again the moment any header is set. This tool ran
# for months without one because its cache was already full - the fetch path is only reached at
# a new build, which is exactly when nobody wants to debug the fetcher.
AGENT = "Family-addon-tools (+https://github.com/uga/Family)"

BUILDS = {
    "Classic Era": "1.15.9.69109",
    "Burning Crusade Anniversary": "2.5.6.69110",
    "Mists of Pandaria Classic": "5.5.4.69078",
}
LOCALES = ["enUS", "deDE", "frFR", "esES", "ruRU"]

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".races-cache")


def path_for(build, locale):
    return os.path.join(CACHE, "%s-%s.csv" % (build, locale))


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for game, build in BUILDS.items():
        for locale in LOCALES:
            target = path_for(build, locale)
            if os.path.exists(target) and os.path.getsize(target) > 0:
                print("  have   %s %s" % (game, locale))
                continue
            url = "https://wago.tools/db2/ChrRaces/csv?build=%s&locale=%s" % (build, locale)
            print("  fetch  %s %s" % (game, locale))
            request = urllib.request.Request(url, headers={"User-Agent": AGENT})
            with urllib.request.urlopen(request, timeout=300) as response:
                open(target, "wb").write(response.read())


def rows_of(build, locale):
    target = path_for(build, locale)
    if not os.path.exists(target) or os.path.getsize(target) == 0:
        return None
    text = open(target, encoding="utf-8").read()
    return list(csv.DictReader(io.StringIO(text)))


def build_table():
    # id -> {"key": ClientFileString, "names": {locale: [male, female]}}
    races = {}
    complaints = []
    report = []

    for game, build in BUILDS.items():
        for locale in LOCALES:
            rows = rows_of(build, locale)
            if rows is None:
                # Missing is survivable and is reported rather than guessed at. wago serves
                # no German ChrRaces for Burning Crusade at all - the request succeeds and
                # returns nothing - and it costs us nothing, because every race on that build
                # is named in German by Era or by Mists.
                complaints.append("missing: %s %s" % (game, locale))
                continue

            for row in rows:
                if int(row["PlayableRaceBit"]) < 0:
                    continue

                race_id = int(row["ID"])
                male = row["Name_lang"].strip()
                female = row["Name_female_lang"].strip() or male
                if not male:
                    continue

                entry = races.setdefault(race_id, {"key": row["ClientFileString"].strip(),
                                                   "names": {}})
                have = entry["names"].get(locale)
                if have is None:
                    entry["names"][locale] = [male, female]
                elif have != [male, female]:
                    # Kept from the earlier build rather than overwritten, and said out loud.
                    # Silently taking the last build's answer is how an Era player ends up
                    # reading a word their client does not use.
                    report.append("%d %s: %s says %r/%r, keeping %r/%r"
                                  % (race_id, locale, game, male, female, have[0], have[1]))

    # Three pandaren rows share one file string - neutral, Alliance and Horde - so the
    # file-string map has to pick one. Harmless only for as long as they agree, which is
    # checked rather than assumed.
    by_file = {}
    for race_id in sorted(races):
        key = races[race_id]["key"]
        if key in by_file:
            first = races[by_file[key]]["names"]
            if first != races[race_id]["names"]:
                report.append("%s: races %d and %d share a file string and disagree"
                              % (key, by_file[key], race_id))
        else:
            by_file[key] = race_id

    return races, by_file, complaints, report


# Emitted rather than hand-written into the generated file afterwards. tools/skill-lines.py
# had its accessors added that way and the next --fetch would have deleted them without a
# word, leaving an addon that loads and then fails at the first profession.
ACCESSORS = """
-- What to call a race, in the language of whoever is reading.
--
-- In order, and the order is the whole of it:
--
-- 1. The word the recording client used, when that word is one this reader's own language
--    uses. It is the game's own answer for that character - already right about gender,
--    which no table here can be - and it is recognised two ways: by the language recorded
--    beside it, and by simply being one of the two words this language has for that race.
--    The second is what carries every record written before the language was recorded with
--    it, and without it a Russian player's female gnome would stop being a Gnomka until
--    somebody logged in on her.
-- 2. This table, by identity. Right whoever recorded the member and whatever they were
--    running - which is the fault this file was written to fix. The base form, because
--    which of the two words a foreign record meant is not a question this can answer.
-- 3. The client, for a language this table does not ship. Family runs wherever the game
--    does, and five locales is not all of them.
-- 4. Whatever the recorder called it, then English. A word in the wrong language still
--    tells a player which character they are looking at; a blank does not.
function Family:RaceName(meta)
	if type(meta) ~= "table" then return nil end

	local recorded = meta.race
	if recorded == "" then recorded = nil end

	if recorded and meta.raceLocale == Family.locale then return recorded end

	local id = meta.raceID or (meta.raceFile and Family.RaceByFile[meta.raceFile])
	local entry = id and Family.Races[id]
	local names = entry and entry.names[Family.locale]

	if names then
		if recorded and (recorded == names[1] or recorded == names[2]) then return recorded end
		return names[1]
	end

	if id and C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
		local info = Family:TryCall(C_CreatureInfo.GetRaceInfo, id)
		if type(info) == "table" and type(info.raceName) == "string" and info.raceName ~= ""
		then
			return info.raceName
		end
	end

	if recorded then return recorded end

	local english = entry and entry.names.enUS
	return english and english[1] or nil
end
"""


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def emit(races, by_file, out_path):
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
    add("-- What each client calls each race. GENERATED - see tools/races.py.")
    add('--')
    add('-- The same fault professions had, and the same fix. A member is only re-read when')
    add('-- somebody logs in on them, so the word their client used is the word Family had:')
    add('-- a character last played on a French client stayed French on a Spanish one, and a')
    add('-- borrowed Wide Family member was named in whatever their owner was running.')
    add('--')
    add("-- Unlike professions the identity was never missing - UnitRace's second return is a")
    add('-- language-neutral file string and Family has always recorded it - so nothing has to')
    add('-- be migrated and no rescan is needed. What was missing was a way to turn it back')
    add('-- into a word, which is this file.')
    add('--')
    add('-- Two things here that a hand-written table gets wrong:')
    add('--')
    add('-- The file string is not unique. Race 23 is "Human" too - the Gilnean one - so a map')
    add('-- built from every row names every human Gilnean on a Mists client. Only the rows the')
    add("-- table itself marks playable are here, and that row is not one of them.")
    add('--')
    add('-- Both forms of the name are below, base first. Not so that this file can choose')
    add('-- between them - it has no way to know which one a foreign record meant - but so that')
    add('-- it can recognise the word a client already wrote. A Russian gnome is a Gnom or a')
    add('-- Gnomka, and a record made before Family wrote the language down beside the word has')
    add('-- nothing else to identify that Gnomka as Russian by.')
    add('--')
    add('-- Note also that the file string is not the name even in English: the undead are')
    add('-- "Scourge" in the file string and "Undead" on the character sheet. Falling back to')
    add('-- the file string, which is what Family did until this file existed, shows a player a')
    add('-- word their game never uses.')
    add('')
    add('local _, Family = ...')
    add('')
    add('Family.Races = {')

    for race_id in sorted(races):
        entry = races[race_id]
        add('\t[%d] = {' % race_id)
        add('\t\tkey = %s,' % lua_string(entry["key"]))
        add('\t\tnames = {')
        for locale in LOCALES:
            names = entry["names"].get(locale)
            if names:
                add('\t\t\t%s = { %s, %s },'
                    % (locale, lua_string(names[0]), lua_string(names[1])))
        add('\t\t},')
        add('\t},')

    add('}')
    add('')
    add("-- The other direction: the file string UnitRace hands back, to the race it is.")
    add('-- Written out rather than built at load, because three pandaren rows share one file')
    add('-- string and which of them answers has to be a decision somebody made and checked,')
    add('-- not whatever pairs() happened to reach last.')
    add('Family.RaceByFile = {')
    for key in sorted(by_file):
        add('\t[%s] = %d,' % (lua_string(key), by_file[key]))
    add('}')
    add('')
    add('-' * 92)
    add('')
    add(ACCESSORS.strip())
    open(out_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()

    races, by_file, complaints, report = build_table()
    if report:
        print("worth reading before trusting this run:")
        print("\n".join("  . " + line for line in report))
    if complaints:
        print("\n".join("  ! " + c for c in complaints))
    if not races:
        print("nothing built - run with --fetch first")
        sys.exit(1)

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "addons", "Family", "Races.lua")
    emit(races, by_file, os.path.normpath(out))
    print("%d playable races, %d locales -> addons/Family/Races.lua"
          % (len(races), len(LOCALES)))
