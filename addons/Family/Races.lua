-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What each client calls each race. GENERATED - see tools/races.py.
--
-- The same fault professions had, and the same fix. A member is only re-read when
-- somebody logs in on them, so the word their client used is the word Family had:
-- a character last played on a French client stayed French on a Spanish one, and a
-- borrowed Wide Family member was named in whatever their owner was running.
--
-- Unlike professions the identity was never missing - UnitRace's second return is a
-- language-neutral file string and Family has always recorded it - so nothing has to
-- be migrated and no rescan is needed. What was missing was a way to turn it back
-- into a word, which is this file.
--
-- Two things here that a hand-written table gets wrong:
--
-- The file string is not unique. Race 23 is "Human" too - the Gilnean one - so a map
-- built from every row names every human Gilnean on a Mists client. Only the rows the
-- table itself marks playable are here, and that row is not one of them.
--
-- Both forms of the name are below, base first. Not so that this file can choose
-- between them - it has no way to know which one a foreign record meant - but so that
-- it can recognise the word a client already wrote. A Russian gnome is a Gnom or a
-- Gnomka, and a record made before Family wrote the language down beside the word has
-- nothing else to identify that Gnomka as Russian by.
--
-- Note also that the file string is not the name even in English: the undead are
-- "Scourge" in the file string and "Undead" on the character sheet. Falling back to
-- the file string, which is what Family did until this file existed, shows a player a
-- word their game never uses.

local _, Family = ...

Family.Races = {
	[1] = {
		key = "Human",
		names = {
			enUS = { "Human", "Human" },
			deDE = { "Mensch", "Mensch" },
			frFR = { "Humain", "Humain" },
			esES = { "Humano", "Humano" },
			ruRU = { "Человек", "Человек" },
		},
	},
	[2] = {
		key = "Orc",
		names = {
			enUS = { "Orc", "Orc" },
			deDE = { "Orc", "Orc" },
			frFR = { "Orc", "Orc" },
			esES = { "Orco", "Orco" },
			ruRU = { "Орк", "Орчиха" },
		},
	},
	[3] = {
		key = "Dwarf",
		names = {
			enUS = { "Dwarf", "Dwarf" },
			deDE = { "Zwerg", "Zwerg" },
			frFR = { "Nain", "Nain" },
			esES = { "Enano", "Enano" },
			ruRU = { "Дворф", "Дворфийка" },
		},
	},
	[4] = {
		key = "NightElf",
		names = {
			enUS = { "Night Elf", "Night Elf" },
			deDE = { "Nachtelf", "Nachtelf" },
			frFR = { "Elfe de la nuit", "Elfe de la nuit" },
			esES = { "Elfo de la noche", "Elfo de la noche" },
			ruRU = { "Ночной эльф", "Ночная эльфийка" },
		},
	},
	[5] = {
		key = "Scourge",
		names = {
			enUS = { "Undead", "Undead" },
			deDE = { "Untoter", "Untoter" },
			frFR = { "Mort-vivant", "Mort-vivant" },
			esES = { "No-muerto", "No-muerto" },
			ruRU = { "Нежить", "Нежить" },
		},
	},
	[6] = {
		key = "Tauren",
		names = {
			enUS = { "Tauren", "Tauren" },
			deDE = { "Tauren", "Tauren" },
			frFR = { "Tauren", "Tauren" },
			esES = { "Tauren", "Tauren" },
			ruRU = { "Таурен", "Тауренка" },
		},
	},
	[7] = {
		key = "Gnome",
		names = {
			enUS = { "Gnome", "Gnome" },
			deDE = { "Gnom", "Gnom" },
			frFR = { "Gnome", "Gnome" },
			esES = { "Gnomo", "Gnomo" },
			ruRU = { "Гном", "Гномка" },
		},
	},
	[8] = {
		key = "Troll",
		names = {
			enUS = { "Troll", "Troll" },
			deDE = { "Troll", "Troll" },
			frFR = { "Troll", "Troll" },
			esES = { "Trol", "Trol" },
			ruRU = { "Тролль", "Тролль" },
		},
	},
	[9] = {
		key = "Goblin",
		names = {
			enUS = { "Goblin", "Goblin" },
			deDE = { "Goblin", "Goblin" },
			frFR = { "Gobelin", "Gobelin" },
			esES = { "Goblin", "Goblin" },
			ruRU = { "Гоблин", "Гоблин" },
		},
	},
	[10] = {
		key = "BloodElf",
		names = {
			enUS = { "Blood Elf", "Blood Elf" },
			deDE = { "Blutelf", "Blutelfe" },
			frFR = { "Elfe de sang", "Elfe de sang" },
			esES = { "Elfo de sangre", "Elfa de sangre" },
			ruRU = { "Эльф крови", "Эльфийка крови" },
		},
	},
	[11] = {
		key = "Draenei",
		names = {
			enUS = { "Draenei", "Draenei" },
			deDE = { "Draenei", "Draenei" },
			frFR = { "Draeneï", "Draeneï" },
			esES = { "Draenei", "Draenei" },
			ruRU = { "Дреней", "Дренейка" },
		},
	},
	[22] = {
		key = "Worgen",
		names = {
			enUS = { "Worgen", "Worgen" },
			deDE = { "Worgen", "Worgenfrau" },
			frFR = { "Worgen", "Worgen" },
			esES = { "Huargen", "Huargen" },
			ruRU = { "Ворген", "Ворген" },
		},
	},
	[24] = {
		key = "Pandaren",
		names = {
			enUS = { "Pandaren", "Pandaren" },
			deDE = { "Pandaren", "Pandarin" },
			frFR = { "Pandaren", "Pandarène" },
			esES = { "Pandaren", "Pandaren" },
			ruRU = { "Пандарен", "Пандарен" },
		},
	},
	[25] = {
		key = "Pandaren",
		names = {
			enUS = { "Pandaren", "Pandaren" },
			deDE = { "Pandaren", "Pandarin" },
			frFR = { "Pandaren", "Pandarène" },
			esES = { "Pandaren", "Pandaren" },
			ruRU = { "Пандарен", "Пандарен" },
		},
	},
	[26] = {
		key = "Pandaren",
		names = {
			enUS = { "Pandaren", "Pandaren" },
			deDE = { "Pandaren", "Pandarin" },
			frFR = { "Pandaren", "Pandarène" },
			esES = { "Pandaren", "Pandaren" },
			ruRU = { "Пандарен", "Пандарен" },
		},
	},
}

-- The other direction: the file string UnitRace hands back, to the race it is.
-- Written out rather than built at load, because three pandaren rows share one file
-- string and which of them answers has to be a decision somebody made and checked,
-- not whatever pairs() happened to reach last.
Family.RaceByFile = {
	["BloodElf"] = 10,
	["Draenei"] = 11,
	["Dwarf"] = 3,
	["Gnome"] = 7,
	["Goblin"] = 9,
	["Human"] = 1,
	["NightElf"] = 4,
	["Orc"] = 2,
	["Pandaren"] = 24,
	["Scourge"] = 5,
	["Tauren"] = 6,
	["Troll"] = 8,
	["Worgen"] = 22,
}

--------------------------------------------------------------------------------------------

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
