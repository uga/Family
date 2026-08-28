-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Who in the family can do anything with a recipe item.
--
-- The question is asked of a pattern, plan, formula or schematic sitting in a bag or on the
-- auction house: which of my characters already knows this, which could learn it now, and
-- which will be able to later. It is the question that decides whether a recipe is worth
-- buying, and answering it by logging into six characters is exactly what an alt manager is
-- for.
--
--------------------------------------------------------------------------------------------
-- What is known, and what is worked out
--------------------------------------------------------------------------------------------
--
-- Two of the three things this needs are already recorded, and the third is not:
--
--   professions and ranks    In meta, for every member, always current (Professions.lua).
--   recipes already learnt   In the payload, as of the last time that member opened that
--                            profession's window. §2.2 applies: never having opened it is
--                            not the same as not knowing the recipe, and the two are kept
--                            apart below rather than merged into a confident "no".
--   the skill a recipe needs Nowhere. The client has no call for it. It is written on the
--                            item's own tooltip, which is where the interface reads it
--                            from and hands it in here.
--
-- Which profession an item belongs to comes from the client, as the item's subtype - already
-- in the player's language, and comparable directly against the profession names Family
-- recorded from the same client's skill list. No table of professions in eleven languages.
--
-- Which recipe an item teaches is the one guess in here, and it is made by the tail of the
-- name: "Pattern: Frostweave Bag" ends with "Frostweave Bag" and a German one ends with the
-- German recipe name, because it is the prefix that changes between languages and not the
-- tail. The proper answer is a table generated from the client's own `ItemEffect` rows
-- (DATASOURCES.md §3) - which would also supply the skill requirement above, and would
-- replace both halves of this at once. Until then, this is what can be answered without one.

local _, Family = ...

local Recipes = {}
Family.Recipes = Recipes

-- The item class the game gives recipes. Numeric and the same in every language, unlike the
-- class name beside it.
local RECIPE_CLASS = 9

--------------------------------------------------------------------------------------------

-- Every profession name Family has seen on anybody, in this client's words.
--
-- The item's subtype arrives in the client's own language, so the comparison has to be made
-- in that language. Members are filed by skill line id, which is the same number in all
-- five - so the id is turned back into a word here, and the word the recording client used
-- is kept alongside it for the professions that have no id at all.
local function knownProfessions()
	local names = {}

	for _, entry in pairs(Family.Database:Members()) do
		for id, skill in pairs((entry.meta or {}).skills or {}) do
			names[Family:ProfessionName(id, skill.name)] = true
			if skill.name then names[skill.name] = true end
		end
	end

	return names
end

-- The profession an item belongs to, the level it needs, and whether the client actually
-- said this is a recipe.
--
-- That last one matters: trade goods have subclasses named after professions too - a pile of
-- arcane dust is "Enchanting" - so a subtype matching a profession is not on its own enough.
-- Where the client answers with the class as a number, that settles it. Where it does not,
-- the caller has to have found a skill requirement on the tooltip before believing it, which
-- is something a stack of dust does not carry.
function Recipes:ItemProfession(itemID)
	local name, _, _, _, minLevel, _, subType, _, _, _, _, classID =
		Family:TryCall(GetItemInfo, itemID)

	if type(name) ~= "string" or type(subType) ~= "string" then return nil end
	if not knownProfessions()[subType] then return nil end

	if not classID and GetItemInfoInstant then
		classID = select(6, Family:TryCall(GetItemInfoInstant, itemID))
	end

	return subType, tonumber(minLevel) or 0, tonumber(classID) == RECIPE_CLASS, name
end

-- Whether this item is the one that teaches that recipe.
--
-- The character before the match has to be something other than a letter or a digit, so a
-- recipe called "Bag" is not taken to be what "Pattern: Frostweave Bag" teaches.
local function teaches(itemName, recipeName)
	if type(itemName) ~= "string" or type(recipeName) ~= "string" then return false end
	if recipeName == "" or #recipeName > #itemName then return false end
	if itemName:sub(-#recipeName) ~= recipeName then return false end
	if #recipeName == #itemName then return true end

	return itemName:sub(-#recipeName - 1, -#recipeName - 1):match("[%w]") == nil
end

-- Every recipe anybody in the family knows whose name matches, and who knows it.
--
-- This reads payloads, unlike most things - there is no index of recipes and building one
-- would be a copy of what is already stored. It is only ever done in answer to somebody
-- typing, so the cost lands where it was asked for.
function Recipes:Search(needle, limit)
	if type(needle) ~= "string" or needle == "" then return {} end

	needle = needle:lower()
	limit = limit or 200

	local byName, order = {}, {}

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		local payload = Family.Database:Payload(key)

		for profession, record in pairs((payload or {}).professions or {}) do
			for _, recipe in ipairs(record.recipes or {}) do
				local name = recipe.name
				if name and name:lower():find(needle, 1, true) then
					-- Keyed by the recipe's spell where it has one, so the same
					-- enchant recorded on a French client and an English one is one
					-- line rather than two - the id is the same in every language and
					-- the name is not (§2.1, and the reason it matters).
					--
					-- Where there is no id, by recipe and profession together: two
					-- professions can make things of the same name, and "who can make
					-- this" is a different answer for each of them.
					local id = recipe.spellID
						and ("spell:" .. recipe.spellID)
						or (profession .. "\0" .. name)
					-- Where the same recipe is held under two professions - a real one
					-- and something that is not in the client's table, like a rogue's
					-- poisons or a death knight's runeforging - the identified one is the
					-- better label. "Copper Chain Belt, Runeforging" is not wrong only in
					-- a harness.
					if byName[id] and type(byName[id].profession) ~= "number"
						and type(profession) == "number" then
						byName[id].profession = profession
					end

					if not byName[id] then
						byName[id] = {
							name = name,
							id = recipe.spellID,
							profession = profession,
							icon = recipe.icon,
							spellID = recipe.spellID,
							itemID = recipe.itemID,
							members = {},
						}
						order[#order + 1] = byName[id]
					end

					table.insert(byName[id].members, {
						key = key,
						name = meta.name or key,
						classFile = meta.classFile,
						realm = meta.realm,
						faction = meta.faction,
						rank = (meta.skills or {})[profession]
							and meta.skills[profession].rank or nil,
					})
				end
			end
		end
	end

	for _, found in ipairs(order) do
		table.sort(found.members, function(a, b) return a.name < b.name end)
	end

	table.sort(order, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		return a.profession < b.profession
	end)

	while #order > limit do table.remove(order) end
	return order
end

-- Everybody who has the profession, and what they can do about this recipe. Only them: a
-- member without the profession has nothing to say about a pattern and is left off entirely.
--
-- `required` is the skill the recipe needs, read off the item's own tooltip, and may be nil -
-- in which case nobody is told they cannot learn it yet, because nothing is known about what
-- it would take. Guessing there would be worse than the gap.
function Recipes:Crafters(profession, itemName, required, minLevel)
	local found = {}

	-- The item's subtype is a word in this client's language; members are filed by identity.
	-- Resolving it here is what lets a French client's Couture find a member whose window
	-- was opened in English - which it could not do while both sides were words.
	local wanted = Family:SkillLineFor(profession) or profession

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		local skill = (meta.skills or {})[wanted]

		if skill then
			local payload = Family.Database:Payload(key)
			local record = payload and payload.professions
				and payload.professions[wanted]
			local recipes = record and record.recipes

			local knows = false
			if recipes then
				for _, recipe in ipairs(recipes) do
					if teaches(itemName, recipe.name) then
						knows = true
						break
					end
				end
			end

			-- The order these are decided in is the order they are true in. A member who
			-- knows it is not also short of skill; one whose recipes have never been read
			-- is not reported as able to learn something they may have learnt years ago.
			local state
			if knows then
				state = "knows"
			elseif not recipes then
				state = "unknown"
			elseif required and (skill.rank or 0) < required then
				state = "later"
			elseif minLevel and minLevel > 0 and (meta.level or 0) < minLevel then
				state = "level"
			else
				state = "can"
			end

			found[#found + 1] = {
				key = key,
				name = meta.name or key,
				classFile = meta.classFile,
				realm = meta.realm,
				faction = meta.faction,
				rank = skill.rank,
				maxRank = skill.maxRank,
				level = meta.level,
				state = state,
			}
		end
	end

	-- Knows it, then can, then the ones that are only a matter of time, then the ones
	-- nothing can be said about. Highest skill first inside each, which is the order
	-- somebody deciding who to send is reading them in.
	local ORDER = { knows = 1, can = 2, later = 3, level = 4, unknown = 5 }

	table.sort(found, function(a, b)
		if a.state ~= b.state then return ORDER[a.state] < ORDER[b.state] end
		if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) > (b.rank or 0) end
		return a.name < b.name
	end)

	return found
end
