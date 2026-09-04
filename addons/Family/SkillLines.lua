-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What each client calls each profession. GENERATED - see tools/skill-lines.py.
--
-- The Era skill list gives a profession's name and rank and no identifier, so Family
-- keyed professions by name. A name is one language, and a member is only re-read when
-- somebody logs in on them, so a client set to Spanish read a French-recorded character
-- and matched nothing - and the panel reported professions it was holding recipes for
-- as never opened (L-015). This is the identity that was missing.
--
-- Every name below came out of the client's own SkillLine table, for that locale, at
-- the builds DATASOURCES.md section 3 pins. None of it was typed from memory: getting
-- "Erste Hilfe" and "Erstehilfe" the wrong way round is invisible from outside the game
-- and breaks silently for exactly the players who cannot be asked to check it.
--
-- A locale can carry more than one spelling and both are kept. The builds genuinely
-- disagree: Spanish calls skill 197 Costura on Era and Sastreria on Burning Crusade,
-- and Russian skill 393 begins with a Latin C on one build and a Cyrillic ES on the
-- other - identical to the eye, different bytes, and a hand-written table would have
-- got that wrong every time and failed silently for the players who could not be
-- asked to check it.
--
-- Primary or secondary comes from the table too, which settles a question the scanner
-- had been answering by asking whether a skill can be unlearned and then patching up
-- the three that cannot.

local _, Family = ...

Family.SkillLines = {
	[129] = {
		key = "First Aid",
		primary = false,
		names = {
			enUS = { "First Aid" },
			deDE = { "Erste Hilfe" },
			frFR = { "Secourisme" },
			esES = { "Primeros auxilios" },
			ruRU = { "Первая помощь" },
		},
	},
	[164] = {
		key = "Blacksmithing",
		primary = true,
		names = {
			enUS = { "Blacksmithing" },
			deDE = { "Schmiedekunst" },
			frFR = { "Forge" },
			esES = { "Herrería" },
			ruRU = { "Кузнечное дело" },
		},
	},
	[165] = {
		key = "Leatherworking",
		primary = true,
		names = {
			enUS = { "Leatherworking" },
			deDE = { "Lederverarbeitung" },
			frFR = { "Travail du cuir" },
			esES = { "Marroquinería", "Peletería" },
			ruRU = { "Кожевничество" },
		},
	},
	[171] = {
		key = "Alchemy",
		primary = true,
		names = {
			enUS = { "Alchemy" },
			deDE = { "Alchimie" },
			frFR = { "Alchimie" },
			esES = { "Alquimia" },
			ruRU = { "Алхимия" },
		},
	},
	[182] = {
		key = "Herbalism",
		primary = true,
		names = {
			enUS = { "Herbalism" },
			deDE = { "Kräuterkunde" },
			frFR = { "Herboristerie" },
			esES = { "Botánica" },
			ruRU = { "Травничество" },
		},
	},
	[185] = {
		key = "Cooking",
		primary = false,
		names = {
			enUS = { "Cooking" },
			deDE = { "Kochkunst" },
			frFR = { "Cuisine" },
			esES = { "Cocina" },
			ruRU = { "Кулинария" },
		},
	},
	[186] = {
		key = "Mining",
		primary = true,
		names = {
			enUS = { "Mining" },
			deDE = { "Bergbau" },
			frFR = { "Minage" },
			esES = { "Minería" },
			ruRU = { "Горное дело" },
		},
	},
	[197] = {
		key = "Tailoring",
		primary = true,
		names = {
			enUS = { "Tailoring" },
			deDE = { "Schneiderei" },
			frFR = { "Couture" },
			esES = { "Costura", "Sastrería" },
			ruRU = { "Портняжное дело" },
		},
	},
	[202] = {
		key = "Engineering",
		primary = true,
		names = {
			enUS = { "Engineering" },
			deDE = { "Ingenieurskunst" },
			frFR = { "Ingénierie" },
			esES = { "Ingeniería" },
			ruRU = { "Инженерное дело" },
		},
	},
	[333] = {
		key = "Enchanting",
		primary = true,
		names = {
			enUS = { "Enchanting" },
			deDE = { "Verzauberkunst" },
			frFR = { "Enchantement" },
			esES = { "Encantamiento" },
			ruRU = { "Наложение чар" },
		},
	},
	[356] = {
		key = "Fishing",
		primary = false,
		names = {
			enUS = { "Fishing" },
			deDE = { "Angeln" },
			frFR = { "Pêche" },
			esES = { "Pesca" },
			ruRU = { "Рыбная ловля" },
		},
	},
	[393] = {
		key = "Skinning",
		primary = true,
		names = {
			enUS = { "Skinning" },
			deDE = { "Kürschnerei" },
			frFR = { "Dépeçage" },
			esES = { "Desollar" },
			ruRU = { "Снятие шкур", "Cнятие шкур" },
		},
	},
	[633] = {
		key = "Lockpicking",
		primary = false,
		class = true,
		names = {
			enUS = { "Lockpicking" },
			deDE = { "Schlossknacken" },
			frFR = { "Crochetage" },
			esES = { "Ganzúa" },
			ruRU = { "Вскрытие замков" },
		},
	},
	[755] = {
		key = "Jewelcrafting",
		primary = true,
		names = {
			enUS = { "Jewelcrafting" },
			deDE = { "Juwelenschleifen" },
			frFR = { "Joaillerie" },
			esES = { "Joyería" },
			ruRU = { "Ювелирное дело" },
		},
	},
	[773] = {
		key = "Inscription",
		primary = true,
		names = {
			enUS = { "Inscription" },
			ruRU = { "Начертание" },
		},
	},
	[794] = {
		key = "Archaeology",
		primary = false,
		names = {
			enUS = { "Archaeology" },
			ruRU = { "Археология" },
		},
	},
}

-- The other direction, built once: what this client calls a profession, to its id.
-- Every language is indexed rather than only the one running, so a member recorded on
-- a German client resolves on a French one without either of them being reloaded.
Family.SkillLineByName = {}
for id, entry in pairs(Family.SkillLines) do
	for _, names in pairs(entry.names) do
		for _, name in ipairs(names) do
			Family.SkillLineByName[name] = id
		end
	end
end

--------------------------------------------------------------------------------------------

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
