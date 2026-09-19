-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Who knows which recipe, answered without reading anybody's record.
--
-- `Index.lua` does this for what the family owns; this does it for what the family can make. The
-- recipe search, a tooltip's *who can make it* and a pattern's crafters used to walk every
-- member's professions and name every recipe again on every question - a name that, for a list
-- recorded in another language, has to be asked of the client. Measured on Alberto's Era client
-- 2026-09-13 with every record already read: a two-letter search 10-15 ms, a tooltip's question
-- 1-2 ms; data-path review, step 5. Cheap once warm, and paid again on every keystroke and every
-- hover, for answers that change only when a record is written.
--
-- **One part per member**, holding that member's recipe lists in the order the record holds them,
-- each recipe with the name resolved for the reader once - with the list's own language, as the
-- readers resolved it - and the facts the readers ask about. What depends on the clock (whether a
-- craft is ready) and what lives in `meta` (rank, name, class, level) is read when asked, as the
-- walk read it, so a part never has to be rebuilt because time passed or a summary field moved.
--
-- **Kept per member rather than per recipe**, because the answers have to be the walk's answers row
-- for row, and the walk's order - members, then lists, then recipes - decides which of two records
-- names a row first. The readers in `Recipes.lua` walk the parts in exactly that order; they only
-- stop reading records and naming recipes to do it.
--
-- **A name the client learns after a part is built** reaches it through the recipe-name walk
-- (`Family_UI/Slash.lua`), which drops a member's part when it has read them and when a name it
-- asked for arrives. Not through a callback here: that would ask the client for every recipe of
-- every list in another language in one step, which is what the walk exists to spread.
--
-- **Built a member a step after logging in**, the way `Database:WarmPayloads` spread its decoding,
-- and completed on the spot at the first question for whoever the steps have not reached - which
-- since backlog 74 is reading tables, not decoding anything.
--
-- **Dropped per member whenever that member changes** - any `Database:Changed(key)`, which a record
-- write, a summary write and a `Forget` all announce - and whole when a linked family's records
-- change (`Changed("wide")`), because those messages do not say which member. Not only on a record
-- write: which lists count at all depends on the skills in `meta` (`Recipes:StillHeld`), and the
-- professions scan writes those after the record.
--
-- Nothing here is saved, for `Index.lua`'s reason: it is derived entirely from what is stored, and
-- a saved copy would only be one more thing that could disagree with the records it came from.

local _, Family = ...

local RecipeIndex = {}
Family.RecipeIndex = RecipeIndex

-- memberKey -> { lists = { { profession =, recipes = entries or nil }, ... },
--                byProfession = { [profession] = list } }
local parts = {}

-- One member's part, from their meta and record. `recipes` on a list stays nil where the record
-- held a profession with no recipe list at all, which the crafters block says apart from an empty
-- one.
local function build(meta, payload)
	local part = { lists = {}, byProfession = {} }

	for profession, record in pairs((payload or {}).professions or {}) do
		local list = { profession = profession, held = Family.Recipes:StillHeld(meta, profession) }

		if type(record) == "table" and record.recipes then
			local entries = {}
			for index, recipe in ipairs(record.recipes) do
				entries[index] = {
					name = Family.Names:Recipe(recipe, nil, nil, record.locale),
					was = recipe.name,
					spellID = recipe.spellID,
					itemID = recipe.itemID,
					icon = recipe.icon,
					hasCooldown = recipe.hasCooldown,
					readyAt = recipe.readyAt,
				}
			end
			list.recipes = entries
		end

		part.lists[#part.lists + 1] = list
		part.byProfession[profession] = list
	end

	return part
end

-- Our own member's part, built now if it is not there.
local function ours(key, meta)
	local part = parts[key]
	if not part then
		part = build(meta, Family.Database:Payload(key))
		parts[key] = part
	end
	return part
end

-- **Everybody the recipe readers answer about, in the order the walk visited them**: our own
-- members as `Database:Members` lists them, then the siblings a linked family shares. Each with the
-- meta the reader needs and the part it reads instead of a record; a part missing is built here,
-- which is the only way a question pays for anything.
function RecipeIndex:Everybody()
	local everybody = {}

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		everybody[#everybody + 1] = { key = key, meta = meta, part = ours(key, meta) }
	end

	for _, sibling in ipairs(Family.Wide and Family.Wide:Siblings() or {}) do
		local part = parts[sibling.key]
		if not part then
			part = build(sibling.meta or {}, sibling.payload)
			parts[sibling.key] = part
		end
		everybody[#everybody + 1] = { key = sibling.key, meta = sibling.meta or {}, part = part,
			familyName = sibling.familyName }
	end

	return everybody
end

-- Whether a member's part is built. For the checks, and for the step below.
function RecipeIndex:Built(key)
	return parts[key] ~= nil
end

-- **What our own members can make**, as two sets: recipe spells, and the items those recipes make.
--
-- For the crafting cost, which counts making a material only where somebody in the family can -
-- Alberto, 2026-09-19, *in-house crafting cost*. The bill of materials comes from the shipped
-- tables and covers every recipe in the game, so knowing what a thing is made of says nothing
-- about whether anybody here can make it. Our own members only, not a linked family's: theirs is
-- somebody else's work to ask for.
--
-- Built once and dropped with any part, so a tooltip asking about thirty materials walks the
-- lists once rather than thirty times.
local makes

function RecipeIndex:OursMake()
	if makes then return makes end

	makes = { spells = {}, items = {} }
	for key, entry in pairs(Family.Database:Members()) do
		for _, list in ipairs(ours(key, entry.meta or {}).lists) do
			-- Not a list they have unlearnt: the record keeps it and the skill is gone.
			for _, recipe in ipairs(list.held and list.recipes or {}) do
				if recipe.spellID and recipe.spellID ~= 0 then makes.spells[recipe.spellID] = true end
				if recipe.itemID and recipe.itemID ~= 0 then makes.items[recipe.itemID] = true end
			end
		end
	end

	return makes
end

function RecipeIndex:Invalidate(key)
	makes = nil
	if key then
		parts[key] = nil
	else
		wipe(parts)
	end
end

Family.Database:OnChanged("recipeindex", function(key)
	if key == "wide" then
		RecipeIndex:Invalidate()
	elseif key ~= nil then
		RecipeIndex:Invalidate(key)
	end
end)

--------------------------------------------------------------------------------------------
-- Built a member a step after logging in
--------------------------------------------------------------------------------------------

RecipeIndex.WARM_STEP = RecipeIndex.WARM_STEP or 0.3

-- Builds the next of our own members with no part, the character being played first. Answers
-- whether any were left. Siblings are left to the first question: `Wide:Siblings` builds a list
-- each time it is asked, and there are none on most accounts.
function RecipeIndex:WarmStep()
	if not (Family.Database.usable and type(FamilyDB) == "table") then return false end

	local keys = {}
	for key in pairs(Family.Database:Members()) do
		if not parts[key] then keys[#keys + 1] = key end
	end
	if #keys == 0 then return false end

	table.sort(keys)
	local playing = Family:CurrentMember()
	local pick = keys[1]
	for _, key in ipairs(keys) do
		if key == playing then pick = key break end
	end

	local entry = Family.Database:Members()[pick]
	ours(pick, (entry and entry.meta) or {})
	return #keys > 1
end

Family:OnDatabaseReady("recipeindex.warm", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "recipeindex.warm", function()
		local function step()
			if RecipeIndex:WarmStep() then
				Family:After(RecipeIndex.WARM_STEP, "recipeindex.warm", step)
			end
		end
		-- After the records still stored the old way have been rewritten (`Database`, three
		-- seconds and a step each), so a part is built from a table rather than paying for that
		-- decode itself.
		Family:After(5, "recipeindex.warm", step)
	end)
end)
