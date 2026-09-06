#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds addons/Family/SkillLines.lua from the client's own SkillLine table.

A profession has no identifier in the Era skill list, so Family keyed professions by their
name - and a name is one language, which is how a Spanish client came to list five French
professions as never opened (L-015). This turns the name back into an identity.

The data is Blizzard's own, served per build by wago.tools, which DATASOURCES.md section 3
already pins builds for and reasons out the licence position of. Nothing here is typed from
memory: every name in the generated file came out of the client's table for that locale.

    tools/skill-lines.py --fetch     download the CSVs into a cache
    tools/skill-lines.py             build the Lua from what is cached

Re-run at a new build, and check the report: it says when two builds disagree about a name,
which is the only thing that could quietly make the table wrong.
"""

import csv, io, os, sys, urllib.request

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

# Category 11 is the primary professions and is exactly right on every build. Category 9 is
# "secondary skills" and is a mixed bag - racials, riding, swimming - so the four professions
# in it are named by id rather than taken wholesale.
PRIMARY_CATEGORY = "11"
SECONDARY_IDS = {129, 185, 356, 794, 40}
# 40 is Poisons, which is category 7 with the class skills and not category 9 at all - but a rogue
# makes things with it through a window of its own, so it belongs with cooking and first aid rather
# than with lockpicking. Carried here so that it has an identity and a picture instead of being
# filed under whatever word the client that read it was set to.

# And riding, which is in that same mixed category and was left out of it until Alberto noticed
# it missing from the panel - it is on the character's skill sheet beside Cooking and Fishing,
# it has a rank and a maximum, and it is the one skill in there a player spends gold on.
#
# Era has one line per mount type and no general one: a dwarf reads "Ram Riding" and a troll
# "Raptor Riding", so all of them are carried and a character has exactly one. Burning Crusade
# adds 762 "Riding" and keeps the old rows beside it, so that is carried too and whichever the
# client answers with is the one that gets recorded.
#
# Like lockpicking, these teach nothing: there is no recipe list behind a riding skill, and the
# panel already draws such a profession as a rank without one.
RIDING_IDS = {148, 149, 150, 152, 533, 553, 554, 713, 762}

# And the weapon skills, which are category 6 and are the game's own third bucket: its windows say
# Professions, Secondary Skills and Weapon Skills, and calling a sword a secondary profession would
# file it beside cooking. Taken wholesale, because unlike category 9 that one holds nothing else -
# eighteen rows on Era, all of them weapons or the two that go with them, Defense and Dual Wield.
WEAPON_CATEGORY = "6"

# The picture each one gets, and where it comes from.
#
# `SkillLine.SpellIconFileID` answers for most professions on Mists and for almost none on Era: that
# build names three of its nine primaries and hands back 136235 - a generic - for the rest, and
# every weapon skill on every build answers a generic too (136235 on Era, 136243 on Mists). So the
# file id is taken from the newest build that gives a real one, and the generics are refused.
GENERIC_ICONS = {136235, 136243}

# ...and what is left has to be chosen, which is the one kind of fact this project cannot check
# from inside the client: a path that does not exist draws nothing and GetTexture hands back
# whatever it was given, so a typo and a good path are the same answer. Every one of these was drawn
# on a live Era client through tools/FamilyIconSheet and looked at - see DATASOURCES.md.
#
# Unarmed is 132298, a bare hand striking. The gauntleted fist was turned down for being gauntleted.
# Engineering keeps the generic on purpose: no build has anything better for it.
CHOSEN_ICONS = {
    43:  "Interface\\Icons\\INV_Sword_04",              # Swords
    55:  "Interface\\Icons\\INV_Sword_27",              # Two-Handed Swords
    44:  "Interface\\Icons\\INV_Axe_01",                # Axes
    172: "Interface\\Icons\\INV_Axe_09",                # Two-Handed Axes
    54:  "Interface\\Icons\\INV_Mace_01",               # Maces
    160: "Interface\\Icons\\INV_Hammer_16",             # Two-Handed Maces
    173: "Interface\\Icons\\INV_Weapon_ShortBlade_05",  # Daggers
    136: "Interface\\Icons\\INV_Staff_08",              # Staves
    229: "Interface\\Icons\\INV_Spear_06",              # Polearms
    473: "Interface\\Icons\\INV_Gauntlets_04",          # Fist Weapons
    162: 132298,                                        # Unarmed - a bare hand
    45:  "Interface\\Icons\\INV_Weapon_Bow_07",         # Bows
    226: "Interface\\Icons\\INV_Weapon_Crossbow_01",    # Crossbows
    46:  "Interface\\Icons\\INV_Weapon_Rifle_01",       # Guns
    228: "Interface\\Icons\\INV_Wand_01",               # Wands
    176: "Interface\\Icons\\INV_ThrowingKnife_02",      # Thrown
    95:  "Interface\\Icons\\INV_Shield_06",             # Defense
    118: "Interface\\Icons\\Ability_DualWield",         # Dual Wield
    202: 136243,                                        # Engineering - nothing better exists
    633: 134237,                                        # Lockpicking - inv_misc_key_03
    40:  136242,                                        # Poisons - trade_brewpoison
}

# Riding is one idea however many animals it is named after, so every riding line takes the picture
# the modern build gives the single Riding skill. A kodo among seven generic saddles would read as a
# distinction that is not there.
RIDING_ICON = 132164

# Lockpicking, which is neither. It sits in category 7 with the class skills, it has a rank and
# a maximum like a profession, and it teaches nothing - a shape this table did not hold before.
#
# **It exists on Classic Era and Burning Crusade and not on Mists**, measured here rather than
# remembered: the 5.5.4 SkillLine table has 175 rows and no 633, which matches the skill being
# taken out of the game after Cataclysm. Nothing needs saying about that in the generator - a
# build whose table does not carry it simply contributes no name - but it is why the Lua below
# carries names for two builds and not three, and why a check that demanded five locales for
# every entry would be wrong.
CLASS_IDS = {633}

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".skill-lines-cache")


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
            url = ("https://wago.tools/db2/SkillLine/csv?build=%s&locale=%s"
                   % (build, locale))
            print("  fetch  %s %s" % (game, locale))
            request = urllib.request.Request(url, headers={"User-Agent": AGENT})
            with urllib.request.urlopen(request, timeout=300) as response:
                open(target, "wb").write(response.read())


def rows_of(build, locale):
    target = path_for(build, locale)
    if not os.path.exists(target):
        return None
    text = open(target, encoding="utf-8").read()
    return list(csv.DictReader(io.StringIO(text)))


def build_table():
    # id -> {"key": English name, "primary": bool, "names": {locale: name}}
    professions = {}
    complaints = []
    report = []

    for game, build in BUILDS.items():
        for locale in LOCALES:
            rows = rows_of(build, locale)
            if rows is None:
                # Mists is the one build that does not need this table: GetProfessions
                # there hands back a name and its skill line id together, so nothing has to
                # be looked up by name. Its English row is worth having for the two
                # professions that exist nowhere else; the rest is optional, which is
                # fortunate because wago serves that build slowly enough to time out.
                if game.startswith("Mists") and locale != "enUS":
                    continue
                complaints.append("missing: %s %s" % (game, locale))
                continue

            for row in rows:
                skill_id = int(row["ID"])
                is_primary = row["CategoryID"] == PRIMARY_CATEGORY
                is_class = skill_id in CLASS_IDS
                is_weapon = row["CategoryID"] == WEAPON_CATEGORY
                if (not is_primary and not is_weapon and skill_id not in SECONDARY_IDS
                        and skill_id not in RIDING_IDS and not is_class):
                    continue

                name = row["DisplayName_lang"].strip()
                if not name:
                    continue

                entry = professions.setdefault(skill_id,
                                               {"names": {}, "primary": is_primary,
                                                "class": is_class, "weapon": is_weapon})

                # The newest build that names a real one wins, and BUILDS is read oldest first,
                # so a later build simply overwrites an earlier answer.
                icon = int(row.get("SpellIconFileID") or 0)
                if icon and icon not in GENERIC_ICONS:
                    entry["icon"] = icon
                seen = entry["names"].setdefault(locale, [])
                if name not in seen:
                    if seen:
                        # Not a fault: the builds genuinely disagree, and both spellings are
                        # real words on real clients. Reported so that a new one is noticed
                        # rather than absorbed, and kept so that both of them resolve.
                        report.append("%d %s: %r on %s, also %s"
                                      % (skill_id, locale, name, game,
                                         ", ".join(repr(x) for x in seen)))
                    seen.append(name)

    for skill_id, entry in professions.items():
        english = entry["names"].get("enUS") or []
        entry["key"] = english[0] if english else str(skill_id)

        if skill_id in RIDING_IDS:
            entry["icon"] = RIDING_ICON
            # Said out loud rather than inferred from the picture, because a reader needs to
            # tell riding from a profession and two lines sharing an icon is not an identity.
            entry["riding"] = True
        elif skill_id in CHOSEN_ICONS:
            entry["icon"] = CHOSEN_ICONS[skill_id]

    return professions, complaints, report


# Emitted rather than left in the file to be preserved by hand. They were written into the
# generated file once and the generator knew nothing about them, so the next --fetch would
# have deleted Family:ProfessionName and Family:SkillLineFor without a word and left an addon
# that loads and then fails at the first profession. Everything the file needs is here.
ACCESSORS = """
-- What to call a profession, in the language of whoever is reading.
--
-- The identity is the skill line id, so the answer is right whoever recorded the member and
-- whatever they were running at the time: a French client reads a German-recorded character
-- and sees its own word. Where the id is not known - a skill from a client newer than this
-- table - the name the recording client used is all there is, which is still better than a
-- blank and is the same exception talent names make.
function Family:ProfessionName(id, recorded)
	-- A record made before professions were keyed by identity is filed under a word, and a
	-- member is only re-keyed when somebody logs in on them. That word is one this table
	-- knows, whatever language it was written in, so it is worth a lookup before falling back
	-- to printing it as it was recorded: a family halfway through rescanning would otherwise
	-- read half in the language of whoever is looking and half in whoever last played them.
	if type(id) == "string" then
		id = Family.SkillLineByName[id] or id
	end

	local entry = id and Family.SkillLines[id]
	if entry then
		local names = entry.names[Family.locale] or entry.names.enUS
		if names and names[1] then return names[1] end
	end
	return recorded or (entry and entry.key) or tostring(id or "?")
end

-- The id behind whatever this client just called a profession.
--
-- Used on the clients that hand back a name and nothing else, and on item subtypes, which
-- arrive in the player's language and have to be matched against members recorded in
-- somebody else's.
function Family:SkillLineFor(name)
	if type(name) ~= "string" then return nil end
	return Family.SkillLineByName[name]
end
"""


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def emit(professions, out_path):
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
    add('-- What each client calls each profession. GENERATED - see tools/skill-lines.py.')
    add('--')
    add("-- The Era skill list gives a profession's name and rank and no identifier, so Family")
    add('-- keyed professions by name. A name is one language, and a member is only re-read when')
    add('-- somebody logs in on them, so a client set to Spanish read a French-recorded character')
    add('-- and matched nothing - and the panel reported professions it was holding recipes for')
    add('-- as never opened (L-015). This is the identity that was missing.')
    add('--')
    add("-- Every name below came out of the client's own SkillLine table, for that locale, at")
    add('-- the builds DATASOURCES.md section 3 pins. None of it was typed from memory: getting')
    add('-- "Erste Hilfe" and "Erstehilfe" the wrong way round is invisible from outside the game')
    add('-- and breaks silently for exactly the players who cannot be asked to check it.')
    add('--')
    add('-- A locale can carry more than one spelling and both are kept. The builds genuinely')
    add('-- disagree: Spanish calls skill 197 Costura on Era and Sastreria on Burning Crusade,')
    add('-- and Russian skill 393 begins with a Latin C on one build and a Cyrillic ES on the')
    add('-- other - identical to the eye, different bytes, and a hand-written table would have')
    add('-- got that wrong every time and failed silently for the players who could not be')
    add('-- asked to check it.')
    add('--')
    add('-- Which of the three the game itself puts a skill in comes from the table too, which')
    add('-- settles a question the scanner had been answering by asking whether a skill can be')
    add('-- unlearned and then patching up the ones that cannot. The windows say Professions,')
    add('-- Secondary Skills and Weapon Skills, and a sword cannot be unlearned any more than')
    add('-- cooking can - so that test alone would file one beside the other.')
    add('')
    add('local _, Family = ...')
    add('')
    add('Family.SkillLines = {')

    for skill_id in sorted(professions):
        entry = professions[skill_id]
        add('\t[%d] = {' % skill_id)
        add('\t\tkey = %s,' % lua_string(entry["key"]))
        add('\t\tprimary = %s,' % ("true" if entry["primary"] else "false"))
        # Written only where it is true. Every reader asks `not primary and not class`, which
        # answers the same for a missing key as for a false one, and fifteen `class = false`
        # lines would be fifteen lines saying nothing.
        if entry.get("class"):
            add('\t\tclass = true,')
        if entry.get("weapon"):
            add('\t\tweapon = true,')
        if entry.get("riding"):
            add('\t\triding = true,')
        icon = entry.get("icon")
        if icon is not None:
            add('\t\ticon = %s,'
                % (icon if isinstance(icon, int) else lua_string(icon)))
        add('\t\tnames = {')
        for locale in LOCALES:
            names = entry["names"].get(locale) or []
            if names:
                add('\t\t\t%s = { %s },'
                    % (locale, ", ".join(lua_string(n) for n in names)))
        add('\t\t},')
        add('\t},')

    add('}')
    add('')
    add('-- The other direction, built once: what this client calls a profession, to its id.')
    add('-- Every language is indexed rather than only the one running, so a member recorded on')
    add('-- a German client resolves on a French one without either of them being reloaded.')
    add('Family.SkillLineByName = {}')
    add('for id, entry in pairs(Family.SkillLines) do')
    add('\tfor _, names in pairs(entry.names) do')
    add('\t\tfor _, name in ipairs(names) do')
    add('\t\t\tFamily.SkillLineByName[name] = id')
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

    professions, complaints, report = build_table()
    if report:
        print("builds disagree, and both spellings are kept:")
        print("\n".join("  . " + line for line in report))
    if complaints:
        print("\n".join("  ! " + c for c in complaints))
    if not professions:
        print("nothing built - run with --fetch first")
        sys.exit(1)

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "addons", "Family", "SkillLines.lua")
    emit(professions, os.path.normpath(out))
    print("%d professions, %d locales -> addons/Family/SkillLines.lua"
          % (len(professions), len(LOCALES)))
