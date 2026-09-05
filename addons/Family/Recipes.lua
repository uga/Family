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

-- Case folded far enough for the five languages Family speaks, which `string.lower` is not.
--
-- `string.lower` is ASCII. The game is not: a Russian client calls the book `Рецепт: похлебка
-- Западного Края` and the thing it makes `Похлебка Западного Края`, and the only difference
-- between them is a letter `string.lower` will not touch. Measured against the client's own
-- `ItemSparse` at the pinned Era build, over every item whose name reads like a recipe:
--
--     client   the two names agree in case   they differ
--     enUS                            1015             4
--     deDE                            1007             0
--     frFR                             856           105
--     esES                               6           920
--     ruRU                              24          1006
--
-- So on a Spanish or a Russian client this comparison answered *no* for very nearly every
-- recipe in the game, and English and German are why nobody saw it.
--
-- Three ranges and no more, because those are the alphabets the five locales use: ASCII,
-- the Latin-1 supplement that carries the accented letters, and Cyrillic. Every one of them
-- folds without changing the number of bytes, which the arithmetic below depends on.
local function fold(text)
	local out, index, last = {}, 1, #text

	while index <= last do
		local byte = text:byte(index)

		if byte < 0x80 then
			out[#out + 1] = string.char(byte >= 65 and byte <= 90 and byte + 32 or byte)
			index = index + 1

		-- À-Þ, minus × at 0x97, which is a multiplication sign and not a letter.
		elseif byte == 0xC3 and index < last then
			local second = text:byte(index + 1)
			if second >= 0x80 and second <= 0x9E and second ~= 0x97 then
				second = second + 0x20
			end
			out[#out + 1] = string.char(0xC3, second)
			index = index + 2

		-- А-Я, which straddles a lead byte: the first sixteen fold within 0xD0 and the rest
		-- carry into 0xD1. Ё is filed on its own, away from the run, and folds to ё.
		elseif byte == 0xD0 and index < last then
			local second = text:byte(index + 1)
			if second >= 0x90 and second <= 0x9F then
				out[#out + 1] = string.char(0xD0, second + 0x20)
			elseif second >= 0xA0 and second <= 0xAF then
				out[#out + 1] = string.char(0xD1, second - 0x20)
			elseif second == 0x81 then
				out[#out + 1] = string.char(0xD1, 0x91)
			else
				out[#out + 1] = string.char(byte, second)
			end
			index = index + 2

		else
			out[#out + 1] = string.char(byte)
			index = index + 1
		end
	end

	return table.concat(out)
end

-- Which spell a recipe item teaches, from the client's own tables.
--
-- The name test below is the fallback and was the only test. It compares the item's name
-- against the names in a member's recipe list, and for enchanting those never agree: the trade
-- skill window abbreviates. A French client lists `Ench. de bottes (Agilite superieure)` and
-- names the formula `Formule : Enchantement de bottes (Agilite superieure)`, so the suffix
-- test failed and an enchanter who had known it for a year was offered it as one to learn.
-- Reported from play.
--
-- The ids were on both sides the whole time. `RecipeTeaches.lua` is the join, generated from
-- ItemEffect and SpellEffect, and matching on it is exact: no abbreviation, no language, no
-- suffix rule. Per expansion, because the builds disagree about a few items.
function Recipes:TaughtBy(itemID)
	if not itemID then return nil end

	local expansion = Family.Capabilities and Family.Capabilities.expansion
	local here = expansion and (Family.RecipeTeaches or {})[expansion]

	return here and here[itemID] or nil
end

-- And which item it makes, which is the other lane of the same join.
--
-- One table would not do, because the clients disagree about which id a recipe record
-- carries. Measured (DATASOURCES §2): a Classic Era trade skill record holds the item a
-- recipe makes and no spell at all, while the Craft frame beside it holds the enchant's spell
-- and no item. So the spell above answers for enchanting and this answers for everything else
-- on that client, and between them the name test is left with the few items neither table has
-- heard of.
function Recipes:Makes(itemID)
	if not itemID then return nil end

	local expansion = Family.Capabilities and Family.Capabilities.expansion
	local here = expansion and (Family.RecipeMakes or {})[expansion]

	return here and here[itemID] or nil
end

-- Whether this item is the one that teaches that recipe.
--
-- The character before the match has to be something other than a letter or a digit, so that
-- the tail cannot land in the middle of a word: "Pattern: Frostweave Bag" does not teach a
-- recipe called "weave Bag". It does *not* stop a one-word recipe matching the last word of a
-- longer name - "Bag" is preceded by a space and a space is not a letter - and the comment
-- here claimed for a long time that it did, using that exact example. Checked both ways now.
--
-- Compared folded, because a client does not capitalise the name inside the book the same way
-- it capitalises the thing itself, and which of the two is capitalised differs by language.
-- The lengths are taken from the unfolded strings on purpose: folding preserves every byte
-- count above, and the boundary test reads a byte of the original either way.
local function teaches(itemName, recipeName)
	if type(itemName) ~= "string" or type(recipeName) ~= "string" then return false end
	if recipeName == "" or #recipeName > #itemName then return false end

	local item, recipe = fold(itemName), fold(recipeName)
	if item:sub(-#recipe) ~= recipe then return false end
	if #recipe == #item then return true end

	return item:sub(-#recipe - 1, -#recipe - 1):match("[%w]") == nil
end

-- Who in the family knows one particular recipe, found by its identifier and by nothing else.
--
-- `Crafters` above answers a different and larger question - who has the profession, and how
-- each of them stands with a recipe named like this - and it needs the item's name and its
-- skill requirement read off a tooltip to do it. This needs neither: given the spell, it is a
-- lookup, and the answer is a plain fact rather than a judgement.
--
-- Which is what a recipe's own tooltip wants. An enchant has no item to be named after, no
-- subtype to be recognised by and no skill line written on it, so the route that answers for
-- a crafted object cannot answer for it at all - and the panel two inches away was listing
-- the very people the tooltip left out.
function Recipes:KnowersOf(spellID, itemID, itemName)
	-- Where the caller has only the item, the client's tables often know which spell it
	-- teaches - and an id settles it where a name cannot.
	spellID = spellID or self:TaughtBy(itemID)

	if not ((spellID and spellID ~= 0) or (itemID and itemID ~= 0) or itemName) then
		return {}
	end

	local found = {}

	-- One line per member, not one per profession that can make it.
	--
	-- Some things are made two ways: a Truesilver Bar is smelted by a miner and transmuted by
	-- an alchemist, and a character with both trades matched twice - the `break` below leaves
	-- the recipe loop and the profession loop went on. The count at the top of the block
	-- counted them twice, and since the block shows five names and then says how many more
	-- there are, a duplicate took a visible place from somebody real. Reported from play, on a
	-- Truesilver Bar, as alchemists missing from a list that had room for them.
	--
	-- Where both trades match, the entry that says more is kept: one carrying a cooldown over
	-- one that does not, and the higher rank between two of a kind. A transmute on a timer is
	-- the answer somebody wants; "smelts it, rank 300" is true and says less.
	local best = {}

	local function better(new_, old_)
		if not old_ then return true end
		local newTimer = new_.cooldown and 1 or 0
		local oldTimer = old_.cooldown and 1 or 0
		if newTimer ~= oldTimer then return newTimer > oldTimer end
		return (new_.rank or 0) > (old_.rank or 0)
	end

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		local payload = Family.Database:Payload(key)

		for profession, record in pairs((payload or {}).professions or {}) do
			for _, recipe in ipairs(record.recipes or {}) do
				-- Either identifier, and the name only where neither is present -
				-- which on Classic Era is most of enchanting. The name is this
				-- client's word for the recipe against this client's word for the
				-- item, so both sides are in one language (§2.1).
				local matched = (spellID and spellID ~= 0
						and recipe.spellID == spellID)
					or (itemID and itemID ~= 0 and recipe.itemID == itemID)

				if not matched and itemName and not recipe.itemID then
					matched = teaches(itemName, Family.Names:Recipe(recipe, nil, nil,
						record.locale))
				end

				if matched then
					-- Whether this one is on a timer, and whether it has come back.
					--
					-- A recipe carries hasCooldown only once Family has watched it
					-- run (Scanners/Professions.lua), so its presence is what makes
					-- "ready" sayable at all - and its absence is not a claim that
					-- there is no cooldown, only that none has been seen. A craft
					-- reading ready is evidence, because using one needs the window
					-- Family scans.
					local cooldown
					if recipe.hasCooldown then
						local ready = not recipe.readyAt or recipe.readyAt <= time()
						cooldown = { ready = ready,
							readyAt = (not ready) and recipe.readyAt or nil }
					end

					local candidate = {
						key = key,
						name = meta.name or key,
						classFile = meta.classFile,
						realm = meta.realm,
						faction = meta.faction,
						rank = (meta.skills or {})[profession]
							and meta.skills[profession].rank or nil,
						cooldown = cooldown,
					}

					if better(candidate, best[key]) then best[key] = candidate end
					break
				end
			end
		end
	end

	for _, who in pairs(best) do found[#found + 1] = who end

	-- Whoever cannot do it yet goes last, soonest of them first, and everybody else keeps
	-- the old order: highest skill, then by name - the same order the whole-family search
	-- puts them in, so the two do not disagree about who to ask first. For a transmute the
	-- rank is not the question and the timer is (§4.5), and the guild's half of this block
	-- sorts by exactly the same rule.
	table.sort(found, function(a, b)
		local aWaiting = (a.cooldown and not a.cooldown.ready) and 1 or 0
		local bWaiting = (b.cooldown and not b.cooldown.ready) and 1 or 0
		if aWaiting ~= bWaiting then return aWaiting < bWaiting end

		if aWaiting == 1 and (a.cooldown.readyAt or 0) ~= (b.cooldown.readyAt or 0) then
			return (a.cooldown.readyAt or 0) < (b.cooldown.readyAt or 0)
		end

		if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) > (b.rank or 0) end
		return tostring(a.name) < tostring(b.name)
	end)

	return found
end

-- Whether an item is the thing a recipe of this name produces, or the book that teaches it.
--
-- Exposed because guild crafters needs the same test: what crosses from a guild is an id, the
-- name is worked out from it *here*, and the item under the cursor is named here too - so both
-- sides of the comparison are in the reader's language and §2.1 is kept rather than broken.
function Recipes:Teaches(itemName, recipeName)
	return teaches(itemName, recipeName)
end

-- The same question asked of the guild (§7.1), as a second source on the same rows rather
-- than a second search on a second screen. One box, one question, two answers.
--
-- **Guild lists hold identifiers and not one word**, so a name has to be found for each id
-- before it can be matched against what somebody typed. That is the point rather than the
-- price: the name comes from *this* client, so a list recorded on a French client is found by
-- somebody typing German, and neither end has ever held a word the other could read. Nothing
-- else in Family shows what §2.1 buys quite as plainly.
--
-- Bounded, because this runs on every keystroke and a guild of Family users can hold some
-- thousands of ids. The ceiling is far above a real guild and exists so that a client sending
-- something absurd cannot make the search box stutter.
local GUILD_CEILING = 20000

local function guildCrafters(byName, order, needle, limit)
	local Guild = Family.Guild
	if not (Guild and Guild:Enabled()) then return end

	local guildKey = Guild:Current()
	if not guildKey then return end

	local known, looked = Guild:Known(guildKey), 0

	for memberKey, perLine in pairs(Guild:AllRecipes(guildKey)) do
		local entry = known[memberKey]
		local meta = (entry or {}).meta or {}

		for line, list in pairs(perLine) do
			for index, spellID in ipairs(list.spells or {}) do
				looked = looked + 1
				if looked > GUILD_CEILING then return end

				local itemID = (list.items or {})[index]

				-- What this client calls it. The item is preferred where there is one,
				-- because the thing a player types is usually the thing being made
				-- rather than the spell that makes it - and on Classic Era it is the
				-- only id most recipes have at all (DATASOURCES §2).
				local name, icon
				if itemID and itemID ~= 0 then
					name = Family.Names:CachedItem(itemID)
					icon = Family:TryCall(GetItemIcon, itemID)
				end

				if spellID ~= 0 then
					-- The client's own picture for the spell, which is the only one a
					-- guild row can have: an icon is not an identifier and does not
					-- cross the wire, so a recipe nobody at home knows had nothing to
					-- draw and came up as a question mark. The same call that names it
					-- hands back its picture.
					local spellName, spellIcon = Family.Names:Spell(spellID)
					name = name or spellName
					icon = icon or spellIcon
				end

				if name and name:lower():find(needle, 1, true) then
					-- Keyed exactly as the family's rows are, so a recipe somebody at
					-- home and somebody in the guild both know is one row carrying
					-- both answers rather than two rows saying half each. Either id
					-- may be the one a row has, and which it is differs by client.
					local id = (spellID ~= 0) and ("spell:" .. spellID)
						or ("item:" .. tostring(itemID))

					if not byName[id] and #order < limit then
						byName[id] = {
							name = name,
							id = spellID,
							profession = line,
							icon = icon,
							spellID = (spellID ~= 0) and spellID or nil,
							itemID = (itemID and itemID ~= 0) and itemID or nil,
							members = {},
							guild = {},
						}
						order[#order + 1] = byName[id]
					end

					local row = byName[id]
					if row then
						-- A row the family put there has its own picture; one that has
						-- none takes this.
						row.icon = row.icon or icon
						row.guild = row.guild or {}

						-- One entry per character, because a character is what can
						-- make the thing and every one of them is in this guild -
						-- which means every one of them is on the roster the reader
						-- can see, and either whisperable or visibly offline. Two of
						-- one player's alts knowing it are two characters worth
						-- naming, not one guildmate mentioned twice.
						local seen = false
						for _, who in ipairs(row.guild) do
							if who.key == memberKey then seen = true end
						end

						if not seen then
							local age = list.at
							if list.seen and list.seen < age then age = list.seen end

							row.guild[#row.guild + 1] = {
								player = list.from
									or (entry and entry.from) or "?",
								key = memberKey,
								name = meta.name or memberKey,
								classFile = meta.classFile,
								at = age,
								-- Asked by their ids for this row rather than by
								-- the row's, for the same reason the tooltip's
								-- half asks that way: which of the two ids a
								-- client hands over differs by expansion.
								cooldown = Guild:CooldownOn(entry, line,
									spellID, itemID),
							}
						end
					end
				end
			end
		end
	end

	-- Whoever cannot do it yet last, soonest of them first, and by name for everybody else -
	-- the same rule the tooltip's guild block sorts by, because it is the same list read on
	-- a different surface and the two disagreeing about who to ask would be worse than
	-- either order (§4.5).
	for _, row in ipairs(order) do
		if row.guild then
			table.sort(row.guild, function(a, b)
				local aWaiting = (a.cooldown and not a.cooldown.ready) and 1 or 0
				local bWaiting = (b.cooldown and not b.cooldown.ready) and 1 or 0
				if aWaiting ~= bWaiting then return aWaiting < bWaiting end

				if aWaiting == 1
					and (a.cooldown.readyAt or 0) ~= (b.cooldown.readyAt or 0) then
					return (a.cooldown.readyAt or 0) < (b.cooldown.readyAt or 0)
				end

				return tostring(a.name) < tostring(b.name)
			end)
		end
	end
end

-- Every recipe anybody in the family knows whose name matches, and who knows it.
--
-- This reads payloads, unlike most things - there is no index of recipes and building one
-- would be a copy of what is already stored. It is only ever done in answer to somebody
-- typing, so the cost lands where it was asked for.
--
-- **Siblings too**, since 2026-09-05. This walked `Database:Members` alone, which has never
-- heard of a borrowed key, so a linked family's characters could not appear in the search
-- however much they had shared and however loudly the panel said *whole family*. Reported from
-- play, and it is L-052's class for the fourth time - a reader that knows only our own records,
-- answering a question about everybody, with nothing saying it had answered half.
--
-- Siblings and not everyone a link shares, which is the same population every other whole-family
-- list uses: a sibling is the decision that somebody belongs in my lists beside my own (§6), and
-- this is a list. `Family/Index.lua` already reaches for them the same way from this layer.
function Recipes:Search(needle, limit)
	if type(needle) ~= "string" or needle == "" then return {} end

	needle = needle:lower()
	limit = limit or 200

	local byName, order = {}, {}

	-- Gathered first rather than looped over twice, because the body below is long and two
	-- copies of it would be two answers to "who can make this" the day one of them is edited.
	local searched = {}
	for key, entry in pairs(Family.Database:Members()) do
		searched[#searched + 1] = { key = key, meta = entry.meta or {},
			payload = Family.Database:Payload(key) }
	end
	for _, sibling in ipairs(Family.Wide and Family.Wide:Siblings() or {}) do
		-- Their payload is already a table - it arrived as one and only what we store is
		-- compressed - so it is read straight rather than through the database, which has
		-- never heard of the key it is filed under.
		searched[#searched + 1] = { key = sibling.key, meta = sibling.meta or {},
			payload = sibling.payload, familyName = sibling.familyName }
	end

	for _, who in ipairs(searched) do
		local key, meta, payload = who.key, who.meta, who.payload

		for profession, record in pairs((payload or {}).professions or {}) do
			for _, recipe in ipairs(record.recipes or {}) do
				-- The name this client uses, falling back to the one recorded. Both are
				-- searched: a family holds lists read on other people's clients, and
				-- somebody typing their own language should not find fewer of them.
				local name = Family.Names:Recipe(recipe, nil, nil, record.locale)
				local was = recipe.name
				if name and (name:lower():find(needle, 1, true)
					or (was and was:lower():find(needle, 1, true))) then
					-- Keyed by the recipe's spell where it has one, so the same
					-- enchant recorded on a French client and an English one is one
					-- line rather than two - the id is the same in every language and
					-- the name is not (§2.1, and the reason it matters).
					--
					-- Where there is no id, by recipe and profession together: two
					-- professions can make things of the same name, and "who can make
					-- this" is a different answer for each of them.
					--
					-- Or by the item it makes where the client gave no spell, which on
					-- Classic Era is most recipes (DATASOURCES §2). Without that rung
					-- an Era row keyed by its word could never meet a guild row keyed
					-- by an id, and the same recipe appeared twice on one screen.
					local id = recipe.spellID and ("spell:" .. recipe.spellID)
						or recipe.itemID and ("item:" .. recipe.itemID)
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
							-- Who is already on this row. One member is one answer to
							-- "who can make this", however many times their record
							-- happens to say so.
							listed = {},
						}
						order[#order + 1] = byName[id]
					end

					-- Whether this one is on a timer, worked out exactly as
					-- KnowersOf works it out: a recipe is marked as having a cooldown
					-- only once Family has watched it run, and a moment that has passed
					-- is the craft being ready rather than a gap.
					local cooldown
					if recipe.hasCooldown then
						local ready = not recipe.readyAt or recipe.readyAt <= time()
						cooldown = { ready = ready,
							readyAt = (not ready) and recipe.readyAt or nil }
					end

					-- **Once each.** This was a plain insert, and a member whose record
					-- holds the same recipe twice - which a stored list can, because the
					-- scanner writes back every row the client's window listed - was
					-- drawn twice on one line. Reported from play as "Smith, Smith" on a
					-- transmute, with the realm on both because two identical names in
					-- one list is exactly what makes `NamesOf` add it.
					--
					-- Fixed where two becomes visible rather than where two comes from:
					-- what the client's window listed twice is a question this cannot
					-- answer, and the scanner now says so in the debug log instead of
					-- being made to guess.
					local row = byName[id]
					local already = row.listed[key]

					if already then
						-- The timer is the one thing worth taking from a second copy,
						-- and "has a cooldown" is not the test. A record with
						-- `hasCooldown` and no `readyAt` answers *ready*, so the first
						-- copy already carries one and the second's real timer would be
						-- thrown away - the row saying a transmute is ready that is
						-- three hours off. Taken when we had none, or when what we have
						-- claims ready and this one knows better. Never the other way:
						-- ready must not be able to overwrite a running timer.
						if cooldown and (not already.cooldown
							or (already.cooldown.ready and not cooldown.ready)) then
							already.cooldown = cooldown
						end
					else
						local member = {
							key = key,
							name = meta.name or key,
							classFile = meta.classFile,
							realm = meta.realm,
							faction = meta.faction,
							-- Whose character it is, where it is not one of ours.
							-- The same reason the possessions search carries it: a
							-- name on a list of who can make something is read as
							-- *somebody I can log in on*, and for a linked family's
							-- character that is not true - they are somebody to ask.
							familyName = who.familyName,
							rank = (meta.skills or {})[profession]
								and meta.skills[profession].rank or nil,
							cooldown = cooldown,
						}
						row.listed[key] = member
						table.insert(row.members, member)
					end
				end
			end
		end
	end

	-- The guild's answer onto the same rows, and rows of its own for anything only a
	-- guildmate knows - which is the case the whole feature exists for.
	guildCrafters(byName, order, needle, limit)

	-- Whoever cannot do it yet last, soonest of them first: the same rule the guild half
	-- above sorts by and the same rule both tooltip blocks sort by, so the four surfaces
	-- that answer "who can make this" never disagree about who to ask.
	for _, found in ipairs(order) do
		table.sort(found.members, function(a, b)
			local aWaiting = (a.cooldown and not a.cooldown.ready) and 1 or 0
			local bWaiting = (b.cooldown and not b.cooldown.ready) and 1 or 0
			if aWaiting ~= bWaiting then return aWaiting < bWaiting end

			if aWaiting == 1
				and (a.cooldown.readyAt or 0) ~= (b.cooldown.readyAt or 0) then
				return (a.cooldown.readyAt or 0) < (b.cooldown.readyAt or 0)
			end

			return a.name < b.name
		end)
	end

	table.sort(order, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		-- Two professions can hold the same word, and a guild row's profession is a skill
		-- line while an unidentified family row's is the word the client used. Compared as
		-- strings so that a number never meets a word in a comparison the sort cannot make.
		return tostring(a.profession) < tostring(b.profession)
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
function Recipes:Crafters(profession, itemName, required, minLevel, itemID)
	local found = {}

	-- Which branch this recipe belongs to, if any. Nil for the great majority of recipes,
	-- which anybody with the profession can learn.
	local needs = itemID and (Family.RecipeNeeds or {})[itemID] or nil

	-- And which spell it teaches, and which item that spell makes, where the client's tables
	-- know. An id beats every name test below it: the spell is what makes this right for
	-- enchanting, and the product is what makes it right for a Classic Era trade skill, whose
	-- record carries no spell to compare against at all.
	local taught = self:TaughtBy(itemID)
	local made = self:Makes(itemID)

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
					if taught and recipe.spellID == taught then
						knows = true
						break
					end

					if made and recipe.itemID == made then
						knows = true
						break
					end

					-- Both sides of this in the same language. itemName comes from the
					-- client and is therefore in the reader's, and the recorded recipe
					-- name is in whoever scanned it - so this compared a French item
					-- against an English recipe and matched nothing.
					if teaches(itemName, Family.Names:Recipe(recipe, nil, nil,
						record.locale)) then
						knows = true
						break
					end
				end
			end

			-- Whether this member is on the branch the recipe belongs to. Only asked of
			-- recipes that have one.
			local onBranch = true
			if needs then
				if not meta.specsSeen then
					-- Never asked. Not the same as "took a different branch", and saying
					-- so would be inventing an answer for every member recorded before
					-- Family knew to ask (§2.2). Fills in at their next login.
					onBranch = nil
				else
					onBranch = false
					for _, spell in ipairs(meta.specs or {}) do
						if spell == needs then onBranch = true break end
					end
				end
			end

			-- The order these are decided in is the order they are true in. A member who
			-- knows it is not also short of skill; one whose recipes have never been read
			-- is not reported as able to learn something they may have learnt years ago.
			--
			-- The branch sits above skill and level because it is the one that never
			-- changes: another twenty points of blacksmithing will come, and an armoursmith
			-- will still never make a sword.
			local state
			if knows then
				state = "knows"
			elseif not recipes then
				state = "unknown"
			elseif onBranch == nil then
				state = "unknown"
			elseif onBranch == false then
				state = "branch"
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
				-- What they would have had to take. Carried as the spell's id; the word for
				-- it is the client's to supply, in the language of whoever is reading.
				needs = needs,
			}
		end
	end

	-- Knows it, then can, then the ones that are only a matter of time, then the ones
	-- nothing can be said about, and last the ones for whom it is never going to happen.
	-- Highest skill first inside each, which is the order somebody deciding who to send is
	-- reading them in.
	--
	-- A state missing from here sorts as nil and throws inside table.sort, which is how the
	-- branch state announced itself the moment it was first returned. Anything added above
	-- has to be added here.
	local ORDER = { knows = 1, can = 2, later = 3, level = 4, unknown = 5, branch = 6 }

	table.sort(found, function(a, b)
		if a.state ~= b.state then return (ORDER[a.state] or 99) < (ORDER[b.state] or 99) end
		if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) > (b.rank or 0) end
		return a.name < b.name
	end)

	return found
end
