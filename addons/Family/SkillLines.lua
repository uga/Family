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
-- Which of the three the game itself puts a skill in comes from the table too, which
-- settles a question the scanner had been answering by asking whether a skill can be
-- unlearned and then patching up the ones that cannot. The windows say Professions,
-- Secondary Skills and Weapon Skills, and a sword cannot be unlearned any more than
-- cooking can - so that test alone would file one beside the other.

local _, Family = ...

Family.SkillLines = {
	[40] = {
		key = "Poisons",
		primary = false,
		icon = 136242,
		names = {
			enUS = { "Poisons" },
			deDE = { "Gifte" },
			frFR = { "Poisons" },
			esES = { "Venenos" },
			ruRU = { "Яды" },
		},
	},
	[43] = {
		key = "Swords",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Sword_04",
		names = {
			enUS = { "Swords" },
			deDE = { "Schwerter" },
			frFR = { "Epées" },
			esES = { "Espadas" },
			ruRU = { "Мечи" },
		},
	},
	[44] = {
		key = "Axes",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Axe_01",
		names = {
			enUS = { "Axes" },
			deDE = { "Äxte" },
			frFR = { "Haches" },
			esES = { "Hachas" },
			ruRU = { "Топоры" },
		},
	},
	[45] = {
		key = "Bows",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Weapon_Bow_07",
		names = {
			enUS = { "Bows" },
			deDE = { "Bogen", "Bögen" },
			frFR = { "Arcs" },
			esES = { "Arcos" },
			ruRU = { "Луки" },
		},
	},
	[46] = {
		key = "Guns",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Weapon_Rifle_01",
		names = {
			enUS = { "Guns" },
			deDE = { "Schusswaffen" },
			frFR = { "Armes à feu" },
			esES = { "Armas de fuego" },
			ruRU = { "Огнестрельное оружие", "Ружья" },
		},
	},
	[54] = {
		key = "Maces",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Mace_01",
		names = {
			enUS = { "Maces" },
			deDE = { "Streitkolben" },
			frFR = { "Masse" },
			esES = { "Mazas" },
			ruRU = { "Дробящее оружие" },
		},
	},
	[55] = {
		key = "Two-Handed Swords",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Sword_27",
		names = {
			enUS = { "Two-Handed Swords" },
			deDE = { "Zweihandschwerter" },
			frFR = { "Epées à deux mains" },
			esES = { "Espadas de dos manos" },
			ruRU = { "Двуручные мечи" },
		},
	},
	[95] = {
		key = "Defense",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Shield_06",
		names = {
			enUS = { "Defense" },
			deDE = { "Verteidigung" },
			frFR = { "Défense" },
			esES = { "Defensa" },
			ruRU = { "Защита" },
		},
	},
	[118] = {
		key = "Dual Wield",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\Ability_DualWield",
		names = {
			enUS = { "Dual Wield" },
			deDE = { "Beidhändigkeit" },
			frFR = { "Ambidextrie" },
			esES = { "Empuñadura dual", "Doble empuñadura" },
			ruRU = { "Бой двумя руками", "Бой двумя оружиями" },
		},
	},
	[129] = {
		key = "First Aid",
		primary = false,
		icon = 135966,
		names = {
			enUS = { "First Aid" },
			deDE = { "Erste Hilfe" },
			frFR = { "Secourisme" },
			esES = { "Primeros auxilios" },
			ruRU = { "Первая помощь" },
		},
	},
	[136] = {
		key = "Staves",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Staff_08",
		names = {
			enUS = { "Staves" },
			deDE = { "Stäbe" },
			frFR = { "Bâtons" },
			esES = { "Bastones" },
			ruRU = { "Посохи" },
		},
	},
	[148] = {
		key = "Horse Riding",
		primary = false,
		riding = true,
		icon = 132164,
		names = {
			enUS = { "Horse Riding" },
			deDE = { "Pferdreiten" },
			frFR = { "Equitation" },
			esES = { "Montar caballos" },
			ruRU = { "Езда на лошадях", "Верховая езда: конь" },
		},
	},
	[149] = {
		key = "Wolf Riding",
		primary = false,
		riding = true,
		icon = 132164,
		names = {
			enUS = { "Wolf Riding" },
			deDE = { "Wolfreiten" },
			frFR = { "Monte de loup" },
			esES = { "Montar lobos" },
			ruRU = { "Езда на волках", "Верховая езда: волк" },
		},
	},
	[150] = {
		key = "Tiger Riding",
		primary = false,
		riding = true,
		icon = 132164,
		names = {
			enUS = { "Tiger Riding" },
			deDE = { "Tigerreiten" },
			frFR = { "Monte de tigre" },
			esES = { "Montar tigres" },
			ruRU = { "Езда на тиграх", "Верховая езда: тигр" },
		},
	},
	[152] = {
		key = "Ram Riding",
		primary = false,
		riding = true,
		icon = 132164,
		names = {
			enUS = { "Ram Riding" },
			deDE = { "Widderreiten" },
			frFR = { "Monte de bélier" },
			esES = { "Montar carneros" },
			ruRU = { "Езда на баранах", "Верховая езда: баран" },
		},
	},
	[160] = {
		key = "Two-Handed Maces",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Hammer_16",
		names = {
			enUS = { "Two-Handed Maces" },
			deDE = { "Zweihandstreitkolben" },
			frFR = { "Masses à deux mains" },
			esES = { "Mazas de dos manos" },
			ruRU = { "Двуручное дробящее оружие", "Двуручное ударное оружие" },
		},
	},
	[162] = {
		key = "Unarmed",
		primary = false,
		weapon = true,
		icon = 132298,
		names = {
			enUS = { "Unarmed" },
			deDE = { "Unbewaffnet" },
			frFR = { "Mains nues" },
			esES = { "Sin armas" },
			ruRU = { "Рукопашный бой" },
		},
	},
	[164] = {
		key = "Blacksmithing",
		primary = true,
		icon = 136241,
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
		icon = 136247,
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
		icon = 136240,
		names = {
			enUS = { "Alchemy" },
			deDE = { "Alchimie" },
			frFR = { "Alchimie" },
			esES = { "Alquimia" },
			ruRU = { "Алхимия" },
		},
	},
	[172] = {
		key = "Two-Handed Axes",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Axe_09",
		names = {
			enUS = { "Two-Handed Axes" },
			deDE = { "Zweihandäxte" },
			frFR = { "Haches à deux mains" },
			esES = { "Hachas de dos manos" },
			ruRU = { "Двуручные топоры" },
		},
	},
	[173] = {
		key = "Daggers",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Weapon_ShortBlade_05",
		names = {
			enUS = { "Daggers" },
			deDE = { "Dolche" },
			frFR = { "Dagues" },
			esES = { "Dagas" },
			ruRU = { "Кинжалы" },
		},
	},
	[176] = {
		key = "Thrown",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_ThrowingKnife_02",
		names = {
			enUS = { "Thrown" },
			deDE = { "Wurfwaffen" },
			frFR = { "Armes de jet" },
			esES = { "Armas arrojadizas" },
			ruRU = { "Метательное оружие" },
		},
	},
	[182] = {
		key = "Herbalism",
		primary = true,
		icon = 136246,
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
		icon = 133971,
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
		icon = 134708,
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
		icon = 136249,
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
		icon = 136243,
		names = {
			enUS = { "Engineering" },
			deDE = { "Ingenieurskunst" },
			frFR = { "Ingénierie" },
			esES = { "Ingeniería" },
			ruRU = { "Инженерное дело" },
		},
	},
	[226] = {
		key = "Crossbows",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Weapon_Crossbow_01",
		names = {
			enUS = { "Crossbows" },
			deDE = { "Armbrüste" },
			frFR = { "Arbalètes" },
			esES = { "Ballestas" },
			ruRU = { "Арбалеты" },
		},
	},
	[228] = {
		key = "Wands",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Wand_01",
		names = {
			enUS = { "Wands" },
			deDE = { "Zauberstäbe" },
			frFR = { "Baguettes" },
			esES = { "Varitas" },
			ruRU = { "Жезлы" },
		},
	},
	[229] = {
		key = "Polearms",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Spear_06",
		names = {
			enUS = { "Polearms" },
			deDE = { "Stangenwaffen" },
			frFR = { "Armes d'hast" },
			esES = { "Armas de asta" },
			ruRU = { "Древковое оружие" },
		},
	},
	[333] = {
		key = "Enchanting",
		primary = true,
		icon = 136244,
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
		icon = 136245,
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
		icon = 134366,
		names = {
			enUS = { "Skinning" },
			deDE = { "Kürschnerei" },
			frFR = { "Dépeçage" },
			esES = { "Desollar" },
			ruRU = { "Снятие шкур", "Cнятие шкур" },
		},
	},
	[473] = {
		key = "Fist Weapons",
		primary = false,
		weapon = true,
		icon = "Interface\\Icons\\INV_Gauntlets_04",
		names = {
			enUS = { "Fist Weapons" },
			deDE = { "Faustwaffen" },
			frFR = { "Armes de pugilat" },
			esES = { "Armas de puño" },
			ruRU = { "Кистевое оружие" },
		},
	},
	[533] = {
		key = "Raptor Riding",
		primary = false,
		riding = true,
		icon = 132164,
		names = {
			enUS = { "Raptor Riding" },
			deDE = { "Raptorreiten" },
			frFR = { "Monte de raptor" },
			esES = { "Montar raptor" },
			ruRU = { "Езда на рапторах", "Верховая езда: ящер" },
		},
	},
	[553] = {
		key = "Mechanostrider Piloting",
		primary = false,
		riding = true,
		icon = 132164,
		names = {
			enUS = { "Mechanostrider Piloting" },
			deDE = { "Roboschreiterlenken" },
			frFR = { "Pilotage de mécanotrotteur" },
			esES = { "Montar mecazancudos" },
			ruRU = { "Вождение механострауса", "Езда на механодолгоноге" },
		},
	},
	[554] = {
		key = "Undead Horsemanship",
		primary = false,
		riding = true,
		icon = 132164,
		names = {
			enUS = { "Undead Horsemanship" },
			deDE = { "Untoten-Reitkunst" },
			frFR = { "Monte de cheval squelette" },
			esES = { "Equitación para no-muertos" },
			ruRU = { "Верховая езда нежити" },
		},
	},
	[633] = {
		key = "Lockpicking",
		primary = false,
		class = true,
		icon = 134237,
		names = {
			enUS = { "Lockpicking" },
			deDE = { "Schlossknacken" },
			frFR = { "Crochetage" },
			esES = { "Ganzúa" },
			ruRU = { "Вскрытие замков" },
		},
	},
	[713] = {
		key = "Kodo Riding",
		primary = false,
		riding = true,
		icon = 132164,
		names = {
			enUS = { "Kodo Riding" },
			deDE = { "Kodoreiten" },
			frFR = { "Monte de kodo" },
			esES = { "Montar kodos" },
			ruRU = { "Езда на кодо", "Верховая езда: кодо" },
		},
	},
	[755] = {
		key = "Jewelcrafting",
		primary = true,
		icon = 134071,
		names = {
			enUS = { "Jewelcrafting" },
			deDE = { "Juwelenschleifen" },
			frFR = { "Joaillerie" },
			esES = { "Joyería" },
			ruRU = { "Ювелирное дело" },
		},
	},
	[762] = {
		key = "Riding",
		primary = false,
		riding = true,
		icon = 132164,
		names = {
			enUS = { "Riding" },
			deDE = { "Reiten" },
			frFR = { "Monte" },
			esES = { "Equitación" },
			ruRU = { "Верховая езда" },
		},
	},
	[773] = {
		key = "Inscription",
		primary = true,
		icon = 237171,
		names = {
			enUS = { "Inscription" },
			ruRU = { "Начертание" },
		},
	},
	[794] = {
		key = "Archaeology",
		primary = false,
		icon = 441139,
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

-- Whether a skill line is one of the game's many names for riding.
--
-- By this table and never by the word: Era has one line per animal, so a dwarf reads *Ram
-- Riding* where a troll reads *Raptor Riding* and a French client reads *Monte de belier* -
-- matching on "Riding" would be wrong in every language and most races.
--
-- Two panels ask, which is why it is here rather than a local in one of them. Riding is a real
-- skill with a real rank and it belongs on neither: the summary's professions set answers *what
-- can this character make* and the professions panel answers *what have they got a window for*,
-- and riding is not an answer to either. How fast somebody travels is the Overview's mount cell.
--
-- Takes whatever key a record is filed under, because a record written before that profession
-- had an identity is filed under a word.
function Family:IsRidingSkill(id)
	if type(id) == "string" then id = Family.SkillLineByName[id] or id end
	local entry = id and Family.SkillLines[id]
	return (entry and entry.riding) == true
end
