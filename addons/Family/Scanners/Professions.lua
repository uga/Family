-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Professions: what each member can make, and how good they are at it.
--
-- Two halves, on two different schedules, and the difference matters to what the interface
-- may claim (§2.2):
--
--   ranks    Every skill the character has, with its current and maximum value. Available
--            at any time from the skill list, so it is read at login and kept current.
--   recipes  What a profession can actually make. Only readable while that profession's
--            window is open, so it is as old as the last time the member opened it, and
--            says so.
--
-- Never opening a profession is therefore not the same as having no recipes, and the two
-- must not look alike.
--
--------------------------------------------------------------------------------------------
-- Names again
--------------------------------------------------------------------------------------------
--
-- Professions are stored by name, the same exception talents make and for a related reason:
-- the skill list gives a name and a rank and no identifier, so on Era and Burning Crusade
-- there is nothing else to key them by. The fix is the same one - the client's own SkillLine
-- table, which wago.tools serves per build and which DATASOURCES.md §3 already names - and it
-- would fix both at once. Recipes are better off: a recipe is a spell, and a spell has an id
-- that resolves in any language, so those are stored by id wherever the client hands one over.

local _, Family = ...

local Professions = {}
Family.Professions = Professions

-- Professions Family has seen a trade skill window for, remembered across sessions.
--
-- This exists because "can it be unlearned" identifies a primary profession and nothing
-- else. Cooking, First Aid and Fishing cannot be given up any more than Swords can, so that
-- test alone loses all three - which is exactly what it did, and why the secondary column
-- stayed empty on a character who plainly had them.
--
-- Matching the names instead would need a list of them in every language. Opening the window
-- says so in the player's own words, for free, and is a thing they were going to do anyway.
-- Kept per account rather than per member: cooking is cooking whoever opened it.
local function seenProfessions()
	FamilyDB.professionNames = FamilyDB.professionNames or {}
	return FamilyDB.professionNames
end

-- The three secondaries, in the client's own words. These are Blizzard's own globals, so they
-- are already in whatever language the member plays in and need no list of our own.
--
-- They do two jobs. They place a profession in the secondary column rather than the primary
-- one, and - since none of the three can be unlearned - they are how a secondary is
-- recognised as a profession at all. Without that, cooking was refused as a profession until
-- its window had been opened, and the window was refused because cooking was not a
-- profession: a deadlock that left every secondary permanently invisible.
local SECONDARY_HINTS = {
	[_G.PROFESSIONS_FIRST_AID or "\1"] = true,
	[_G.PROFESSIONS_COOKING or "\2"] = true,
	[_G.PROFESSIONS_FISHING or "\3"] = true,
}

--------------------------------------------------------------------------------------------
-- Ranks, from the skill list
--
-- The list only reports what is visible, so a collapsed header hides its skills entirely.
-- Everything is expanded before reading and put back afterwards - leaving somebody's skill
-- window rearranged because an addon looked at it is rude.
--------------------------------------------------------------------------------------------

local function collapsedHeaders()
	local collapsed = {}
	local count = Family:TryCall(GetNumSkillLines) or 0

	for index = 1, count do
		local name, isHeader, isExpanded = Family:TryCall(GetSkillLineInfo, index)
		if name and isHeader and not isExpanded then
			collapsed[name] = true
		end
	end

	return collapsed
end

-- Walked backwards and bounded by the count, for the same two reasons the faction list is:
-- collapsing one header must not move another that has not been reached, and a client that
-- answers for an index past the end would make a `while true` run until the game killed it.
local function restore(collapsed)
	if not next(collapsed) then return end

	local count = Family:TryCall(GetNumSkillLines) or 0
	for index = count, 1, -1 do
		local name, isHeader = Family:TryCall(GetSkillLineInfo, index)
		if name and isHeader and collapsed[name] then
			Family:TryCall(CollapseSkillHeader, index)
		end
	end
end

-- Mists does not have the skill list at all. Professions moved to their own call, which is
-- better in every way: it says which slots are primary by position, and it hands back the
-- skill line id, so this is the one path that does not have to key a profession by its name.
local function readModernProfessions()
	if type(GetProfessions) ~= "function" then return nil end

	-- prof1, prof2, archaeology, fishing, cooking, first aid - primaries first, by position.
	local slots = { Family:TryCall(GetProfessions) }
	if not next(slots) then return nil end

	local skills = {}

	for position = 1, 6 do
		local index = slots[position]
		if index then
			-- The picture is the client's own and comes back with everything else, so it
			-- costs nothing to keep and is right in every language - which a table of
			-- paths keyed by "Blacksmithing" would not be (§2.1). The older skill list
			-- has no equivalent, and a profession read that way simply has no picture:
			-- §2.3 again, a client that will not say gets no invented answer.
			local name, icon, rank, maxRank, _, _, skillLine, modifier =
				Family:TryCall(GetProfessionInfo, index)

			if name and (tonumber(maxRank) or 0) > 1 then
				skills[name] = {
					rank = tonumber(rank) or 0,
					maxRank = tonumber(maxRank) or 0,
					modifier = tonumber(modifier) or 0,
					skillLine = tonumber(skillLine),
					icon = icon,
					secondary = position > 2,
				}
			end
		end
	end

	if not next(skills) then return nil end
	return skills
end

-- Two lists, and the difference between them matters.
--
--   skills     the professions, which is what the panels show.
--   everything every skill line the member has, professions or not.
--
-- The second exists because a trade window has to be checked against something before its
-- contents are believed - the Craft frame is shared with a hunter's pet training - and
-- checking it against the professions is what deadlocked the secondaries.
function Professions:ReadRanks()
	local modern = readModernProfessions()
	if modern then
		local everything = {}
		for name in pairs(modern) do everything[name] = true end
		return modern, everything
	end

	local skills, everything = {}, {}

	local wasCollapsed = collapsedHeaders()
	Family:TryCall(ExpandSkillHeader, 0)

	local count = Family:TryCall(GetNumSkillLines) or 0
	for index = 1, count do
		local name, isHeader, _, rank, _, modifier, maxRank, isAbandonable =
			Family:TryCall(GetSkillLineInfo, index)

		-- What separates a profession from a weapon skill is that you can give it up.
		-- Swords caps at 300 for a level 60 character and so does an artisan profession,
		-- so a ceiling proves nothing - but the game will let you unlearn Blacksmithing
		-- and will not let you unlearn Swords or Common. That flag is the client's own
		-- and needs no word in any language.
		--
		-- ...but only a primary one. Cooking, first aid and fishing cannot be given up any
		-- more than swords can, so they are recognised by the client's own names for them,
		-- and anything else by having had its window opened at least once.
		--
		-- The proper answer is the SkillLine table's category, which distinguishes them
		-- outright; it arrives with the generated tables that talent names also want.
		local known = name and seenProfessions()[name] or false
		local isProfession = (isAbandonable or SECONDARY_HINTS[name] or known)
			and (tonumber(maxRank) or 0) > 1

		if name and not isHeader then everything[name] = true end

		if name and not isHeader and isProfession then
			skills[name] = {
				rank = tonumber(rank) or 0,
				maxRank = tonumber(maxRank) or 0,
				modifier = tonumber(modifier) or 0,
				-- A skill that cannot be unlearned but has been opened is a
				-- secondary: that is exactly what distinguishes the two.
				secondary = SECONDARY_HINTS[name] or (not isAbandonable) or false,
			}
		end
	end

	restore(wasCollapsed)
	return skills, everything
end

--------------------------------------------------------------------------------------------
-- Recipes, from an open trade skill window
--------------------------------------------------------------------------------------------

-- A recipe link is a spell; the thing it makes is an item. Both carry an id in the link, and
-- an id is what gets stored (§2.1).
-- The id in a link, whichever kind of link this client hands back.
--
-- A trade skill recipe was read as an enchant link, which is what these clients were said to
-- return and what the fixtures were written from. A live Era client returned nothing this
-- could read at all: a hundred and fifty leatherworking recipes with an item id each and not
-- one spell id between them, which is why a French client went on showing English recipe
-- names long after it had been taught to ask.
--
-- So the kinds are tried in turn rather than assumed. Where none of them answers, the recipe
-- still has the item it makes, and that is what names it.
local function idFromLink(link, ...)
	if type(link) ~= "string" then return nil end

	local kinds = { ... }
	for index = 1, #kinds do
		local id = link:match(kinds[index] .. ":(%d+)")
		if id then return tonumber(id) end
	end
	return nil
end

--------------------------------------------------------------------------------------------
-- A recipe window lists what it shows, not what the character knows
--
-- The same fault as the skill list, in the window the recipes are actually in, and it went
-- unguarded for longer because it is one function further down. A collapsed sub-class header
-- hides every recipe under it, and the count is of rows on screen - so a window whose headers
-- are collapsed reads back as no recipes at all. Both readers below return nil for that,
-- which the professions panel renders as **never opened**: a profession opened twice, and
-- still reported as never seen.
--
-- Expanded before reading and put back afterwards, exactly as collapsedHeaders and restore do
-- for the skill list. Leaving somebody's window rearranged because an addon looked at it is
-- rude, and it is also how a player learns not to trust the addon.
--------------------------------------------------------------------------------------------

-- Expanding a header moves everything below it, so the list is read again after each one
-- rather than trusting an index taken before the move.
--
-- Bounded rather than a `while`, for the reason `restore` is walked backwards: a client that
-- answers for an index past the end would otherwise spin until the game killed it. Forty is
-- far more sub-classes than any profession has and far fewer than a hang.
local function expandRows(rows, collapsedAt, expand)
	local collapsed = {}

	for _ = 1, 40 do
		local found, name
		for index = 1, rows() do
			name = collapsedAt(index)
			if name then found = index break end
		end

		if not found then break end

		collapsed[name] = true
		Family:TryCall(expand, found)
	end

	return collapsed
end

local function restoreRows(collapsed, rows, headerAt, collapse)
	if not next(collapsed) then return end

	-- Backwards, so that collapsing one header does not move another that has not been
	-- reached yet.
	for index = rows(), 1, -1 do
		local name = headerAt(index)
		if name and collapsed[name] then Family:TryCall(collapse, index) end
	end
end

local function tradeSkillRows() return Family:TryCall(GetNumTradeSkills) or 0 end

local function tradeSkillHeaderAt(index)
	local name, kind = Family:TryCall(GetTradeSkillInfo, index)
	if name and kind == "header" then return name end
	return nil
end

local function collapsedTradeSkillAt(index)
	local name, kind, _, isExpanded = Family:TryCall(GetTradeSkillInfo, index)
	if name and kind == "header" and not isExpanded then return name end
	return nil
end

local function craftRows() return Family:TryCall(GetNumCrafts) or 0 end

local function craftHeaderAt(index)
	local name, _, kind = Family:TryCall(GetCraftInfo, index)
	if name and kind == "header" then return name end
	return nil
end

local function collapsedCraftAt(index)
	local name, _, kind, _, isExpanded = Family:TryCall(GetCraftInfo, index)
	if name and kind == "header" and not isExpanded then return name end
	return nil
end

-- Era and Burning Crusade: a flat list of headers and skills, with the difficulty as one of
-- the client's own unlocalised keys - optimal, medium, easy, trivial.
local function readClassicRecipes()
	local name = Family:TryCall(GetTradeSkillLine)
	if not name or name == "UNKNOWN" then return nil end

	local wasCollapsed = expandRows(tradeSkillRows, collapsedTradeSkillAt,
		ExpandTradeSkillSubClass)

	local function putBack()
		restoreRows(wasCollapsed, tradeSkillRows, tradeSkillHeaderAt,
			CollapseTradeSkillSubClass)
	end

	local count = tradeSkillRows()

	-- **A window that is open and lists nothing is not a window nobody has opened**, and
	-- returning nil here made them the same thing: both were stored as no recipes at all,
	-- and the panel said "never opened" about a profession whose window was in front of the
	-- player. That is what an addon filtering or replacing the window looks like from in
	-- here, and it cost somebody an evening. The name is what proves the window was open, so
	-- the name goes back with an empty list rather than nothing going back at all.
	if count == 0 then
		putBack()
		return name, {}
	end

	local recipes = {}

	for index = 1, count do
		local skillName, skillType, numAvailable = Family:TryCall(GetTradeSkillInfo, index)

		if skillName and skillType and skillType ~= "header" then
			local recipe = {
				name = skillName,
				difficulty = skillType,
				available = tonumber(numAvailable) or 0,
			}

			recipe.spellID = idFromLink(Family:TryCall(GetTradeSkillRecipeLink, index),
				"enchant", "spell", "trade")
			recipe.itemID = idFromLink(Family:TryCall(GetTradeSkillItemLink, index), "item")

			-- The client's own icon for this row. Working one out afterwards from the
			-- recipe's spell or from what it makes looks reasonable and is not: the
			-- recipe spell of a bandage is not drawn as a bandage, so a whole first aid
			-- list came up wearing the same wrong picture.
			recipe.icon = Family:TryCall(GetTradeSkillIcon, index)

			local cooldown = Family:TryCall(GetTradeSkillCooldown, index)
			if cooldown and cooldown > 0 then
				recipe.readyAt = time() + cooldown
			end

			recipes[#recipes + 1] = recipe
		end
	end

	putBack()
	return name, recipes
end

-- Enchanting is not a trade skill on these clients. It lives behind the older Craft frame,
-- with its own set of calls that do the same job under different names - which is why
-- opening an enchanting window with recipes plainly on screen left Family reporting the
-- profession as never opened.
--
-- Three quite different things share this one frame, and telling them apart is the whole
-- difficulty:
--
--   Enchanting      a primary profession with a skill line and a bar.
--   Poisons         a rogue's own skill, which behaves the same way.
--   Beast Training  a hunter's pet abilities, which are not a profession at all.
--
-- The window itself says which. A craft window belonging to a skill line reports one, with
-- its rank; Beast Training has no skill, no bar and nothing to report. So the skill line is
-- asked for, and it is both the test and - for poisons, which a skill list does not always
-- carry - the only place the rank is stated.
--
-- The returns are inspected rather than unpacked, for the reason every other reader here
-- inspects them: this is one of the oldest calls in the game and its shape is not the same
-- everywhere.
local function craftSkillLine()
	if type(GetCraftDisplaySkillLine) ~= "function" then return nil end

	local returns = { Family:TryCall(GetCraftDisplaySkillLine) }
	local name, numbers = nil, {}

	for index = 1, 4 do
		local value = returns[index]
		if type(value) == "string" and not name and value ~= "" then
			name = value
		elseif type(value) == "number" then
			numbers[#numbers + 1] = value
		end
	end

	if not name then return nil end
	return { name = name, rank = numbers[1], maxRank = numbers[2] }
end

local function readCraftRecipes()
	local name = Family:TryCall(GetCraftName)
	if not name or name == "UNKNOWN" then return nil end

	local wasCollapsed = expandRows(craftRows, collapsedCraftAt, ExpandCraftSkillLine)

	local function putBack()
		restoreRows(wasCollapsed, craftRows, craftHeaderAt, CollapseCraftSkillLine)
	end

	local count = craftRows()
	if count == 0 then
		putBack()
		return name, {}
	end

	local recipes = {}

	for index = 1, count do
		local craftName, _, craftType, numAvailable = Family:TryCall(GetCraftInfo, index)

		if craftName and craftType and craftType ~= "header" then
			local recipe = {
				name = craftName,
				difficulty = craftType,
				available = tonumber(numAvailable) or 0,
			}

			-- Both ids are read from both links, because Era's Craft frame answers the
			-- item call with an enchant link and the recipe call with nothing at all.
			-- Measured on 1.15.9 with an enchanting window open: GetCraftRecipeLink was
			-- nil for every row and GetCraftItemLink returned enchant:20051 for a Runed
			-- Arcanite Rod - which does make an item. Reading only what each call is
			-- named after left a hundred and one enchanting recipes with no id at all.
			local craftLink = Family:TryCall(GetCraftItemLink, index)

			recipe.spellID = idFromLink(Family:TryCall(GetCraftRecipeLink, index),
					"enchant", "spell", "trade")
				or idFromLink(craftLink, "enchant", "spell")
			recipe.itemID = idFromLink(craftLink, "item")
			recipe.icon = Family:TryCall(GetCraftIcon, index)

			local cooldown = Family:TryCall(GetCraftCooldown, index)
			if cooldown and cooldown > 0 then
				recipe.readyAt = time() + cooldown
			end

			recipes[#recipes + 1] = recipe
		end
	end

	putBack()

	-- The skill line's own name is preferred where there is one: it is the profession, and
	-- GetCraftName is only what the window happens to be titled.
	local line = craftSkillLine()
	return (line and line.name) or name, recipes, line
end

-- Mists: recipes have ids of their own, which is the shape everything should have had.
local function readModernRecipes()
	if not C_TradeSkillUI then return nil end

	local name = Family:TryCall(C_TradeSkillUI.GetTradeSkillLine)
	local ids = Family:TryCall(C_TradeSkillUI.GetAllRecipeIDs)
	if not ids then return nil end

	local recipes = {}

	for _, id in ipairs(ids) do
		local info = Family:TryCall(C_TradeSkillUI.GetRecipeInfo, id)
		if type(info) == "table" and info.learned then
			-- The id of what it makes, asked for separately because this window hands
			-- back a recipe id and stops there. Without it every recipe on this client
			-- is a spell and nothing else, and "who can make one of these" has only the
			-- recipe's *name* to go on - which is the product's name for most trade
			-- skills and is not for the ones that are not named after what they make.
			-- Smelting says "Smelt Copper" and makes a Copper Bar.
			--
			-- Asked through TryCall and read back rather than assumed: a client without
			-- the call answers nothing, which leaves this exactly as it was.
			local made = idFromLink(
				Family:TryCall(C_TradeSkillUI.GetRecipeItemLink, id), "item")

			recipes[#recipes + 1] = {
				spellID = id,
				itemID = made,
				name = info.name,
				difficulty = info.relativeDifficulty or info.difficulty,
				available = info.numAvailable or 0,
				icon = info.icon or info.iconFileID,
			}
		end
	end

	return name, recipes
end

-- Returns the profession's name, its recipes, the skill line the window reported if it did,
-- and whether this came from the Craft frame.
--
-- That last one decides how much proof is wanted. The trade skill frame is not shared with
-- anything that is not a profession, so whatever it says is believed - which is what lets
-- runeforging be recorded on a death knight, a window full of things the character can make
-- and no skill line anywhere. The Craft frame is shared with a hunter's pet training, so it
-- has to say more than its own name before it is believed.
function Professions:ReadRecipes()
	local name, recipes, line

	if C_TradeSkillUI then
		name, recipes = readModernRecipes()
	end
	if not recipes then
		name, recipes = readClassicRecipes()
	end
	if recipes then
		if not name then return nil end
		-- The window's own name, which is also the name of the spell that opens it: you
		-- open smelting by casting Smelting. It is the one thing needed to offer a way
		-- back into a profession from inside Family, and it can only be learnt while the
		-- window is open - so it is written down while it is.
		return name, recipes, nil, false, type(name) == "string" and name or nil
	end

	local craftName = Family:TryCall(GetCraftName)
	name, recipes, line = readCraftRecipes()
	if not (name and recipes) then return nil end

	return name, recipes, line, true,
		type(craftName) == "string" and craftName ~= "UNKNOWN" and craftName or nil
end

--------------------------------------------------------------------------------------------

-- Expanding skill headers makes the game announce that skills changed, which is one of the
-- things that asks for a scan. Same trap as the faction list, same answer.
local scanning = false

function Professions:IsScanning()
	return scanning
end

function Professions:Scan(includeRecipes)
	if scanning then return end
	scanning = true

	local ok, err = pcall(function() self:ScanNow(includeRecipes) end)

	scanning = false
	if not ok then error(err, 0) end
end

function Professions:ScanNow(includeRecipes)
	local key = Family:CurrentMember()

	local skills, everything = self:ReadRanks()
	if not next(everything) and not includeRecipes then
		Family:Debug("no skills readable")
		return
	end

	local payload = Family.Database:Payload(key) or {}
	local stored = payload.professions or {}

	-- Recipes only when a window is actually open, and only for the one profession it is
	-- open on. Everything else keeps whatever it last saw.
	--
	-- Read before the ranks are filed, because a window can add a profession the skill list
	-- did not have: rogue poisons are a craft window with a skill bar of their own.
	-- Declared out here because the block below is not the only place they are used: what
	-- opens a profession is filed with the recipes further down, and a local declared inside
	-- an if is a different variable from the one read after it.
	local recipeName, recipes, openWith

	if includeRecipes then
		local line, fromCraftFrame
		recipeName, recipes, line, fromCraftFrame, openWith = self:ReadRecipes()

		-- Only the Craft frame has to prove itself, and it does so either by being a
		-- skill the member has or by reporting the skill line it belongs to. Beast
		-- Training is neither, and a hunter's pet abilities are not a profession however
		-- they arrive.
		--
		-- Checked against *every* skill rather than against the professions, which is
		-- what deadlocked the secondaries: cooking was not a profession until its window
		-- had been opened, and its window was refused because cooking was not a
		-- profession, so it stayed invisible for ever.
		if recipeName and fromCraftFrame and not (everything[recipeName] or line) then
			-- Not a profession - but not nothing, either. A hunter's pet training arrives
			-- through this window and is a real list of things that member can do, so it
			-- is filed as abilities rather than thrown away. The spellbook is where it
			-- belongs and where it is shown: it is not a profession, it has no rank, and
			-- it does not change with a specialisation.
			payload.crafts = payload.crafts or {}
			payload.crafts[recipeName] = { entries = recipes, seen = time() }

			Family:Debug("%s is not a profession - filed as abilities", recipeName)
			recipeName, recipes = nil, nil
		end

		if recipeName then
			-- Remembered whether or not it had recipes: a window opening is the proof
			-- that this is a profession, and skinning has no recipes to show for it.
			seenProfessions()[recipeName] = true

			-- A profession the skill list does not carry: rogue poisons, and a death
			-- knight's runeforging. Recorded from whatever the window itself said,
			-- which for runeforging is nothing at all - so it is kept with no rank
			-- rather than invented at nought out of nought.
			if not skills[recipeName] then
				skills[recipeName] = {
					rank = line and tonumber(line.rank) or nil,
					maxRank = line and tonumber(line.maxRank) or nil,
					modifier = 0,
					secondary = true,
				}
			end
		end
	end

	-- Everything above works in this client's words, because that is all the skill list
	-- offers. Everything below is keyed by the skill line id instead.
	--
	-- That is the whole of the fix for L-015: a name is one language, and a member is only
	-- re-read when somebody logs in on them, so a client set to Spanish met a
	-- French-recorded character and matched nothing. An id is the same number in all five.
	--
	-- What this client called each one is kept beside it, for the professions the table does
	-- not know - a client newer than this build, rogue poisons, a death knight's runeforging
	-- - which stay keyed by name and are no worse off than they were.
	local function byIdentity(named)
		local out = {}
		for name, skill in pairs(named) do
			local id = skill.skillLine or Family:SkillLineFor(name)
			skill.name = name

			-- Primary or secondary, from the client's own table where it knows. The test
			-- below it - can this be unlearned, and then a special case for the three that
			-- cannot - was the best answer available before this table existed.
			local entry = id and Family.SkillLines[id]
			if entry then skill.secondary = not entry.primary end

			out[id or name] = skill
		end
		return out
	end

	skills = byIdentity(skills)

	-- The same profession under its old name-shaped key, left behind by a version that had
	-- no ids. Dropped rather than left to sit beside the real one looking like a second
	-- profession nobody can account for.
	for key in pairs(stored) do
		if type(key) == "string" and Family:SkillLineFor(key) then stored[key] = nil end
	end

	for id, skill in pairs(skills) do
		local entry = stored[id] or {}
		entry.rank = skill.rank
		entry.maxRank = skill.maxRank
		entry.modifier = skill.modifier
		entry.secondary = skill.secondary
		entry.name = skill.name
		stored[id] = entry
	end

	local recipeKey = recipeName and (Family:SkillLineFor(recipeName) or recipeName)

	if recipeName and recipes then
		local entry = stored[recipeKey] or {}

		-- Which recipes have a cooldown at all is remembered, and it has to be, because the
		-- client will not say.
		--
		-- GetTradeSkillCooldown answers with the time remaining and answers nothing when
		-- there is none - so a transmute that is *ready* is indistinguishable from a
		-- bandage, which have nothing in common except that neither is on cooldown right
		-- now. Family therefore learns it: the first time a recipe is seen with a cooldown
		-- running, that recipe is marked as one that has a cooldown, for good.
		--
		-- The cost is stated rather than hidden (§2.2): a member is silent about their
		-- transmute until Family has seen it on cooldown once. Nothing else would be honest.
		-- What Family knows here is what it has watched.
		local known = {}
		for _, recipe in ipairs(entry.recipes or {}) do
			if recipe.hasCooldown and recipe.name then known[recipe.name] = true end
		end

		for _, recipe in ipairs(recipes) do
			if recipe.readyAt then
				recipe.hasCooldown = true
			elseif recipe.name and known[recipe.name] then
				recipe.hasCooldown = true
			end
		end

		entry.recipes = recipes
		entry.recipesSeen = time()
		entry.locale = Family.locale
		entry.openWith = openWith or entry.openWith
		stored[recipeKey] = entry
		Family:Debug("scanned %d recipes for %s", #recipes, recipeName)
	end

	payload.professions = stored
	Family.Database:SetPayload(key, payload)

	-- The summary wants ranks without decoding anybody's recipe list, so they go in meta.
	local summary = {}
	for id, skill in pairs(skills) do
		summary[id] = { rank = skill.rank, maxRank = skill.maxRank,
			secondary = skill.secondary,
			-- What this client called it, for the professions the table has no id for.
			name = skill.name,
			-- When that profession's recipes were last read. Small enough for meta, and
			-- the summary wants it: a rank is always current and a recipe list is not,
			-- so the two need saying apart on the one screen that shows every member.
			recipesSeen = stored[id] and stored[id].recipesSeen or nil }
	end
	-- The cooldowns, small and plain enough for meta - there are three or four of these on
	-- a busy character, not three hundred - so a broker tooltip can say who has a transmute
	-- ready without decoding anybody's recipe list.
	--
	-- Stored as the moment each becomes ready rather than as time remaining, so a record
	-- read tomorrow still says something true (the same reason mail expiry is).
	-- Only from professions this member still has.
	--
	-- `stored` is every profession Family has ever read for them, and it is kept that way on
	-- purpose: somebody who drops enchanting for a fortnight and takes it up again should not
	-- have lost the recipe list. But a cooldown out of a profession they no longer have is a
	-- reminder about something they cannot do, and it never goes away by itself - the entry
	-- is only rewritten when that profession's window is opened, and it never will be again.
	-- That is a login message announcing "crafting ready" for ever, about a transmute
	-- belonging to a profession the character gave up.
	--
	-- Guarded on the skill list having been read at all: a pass where it came back empty
	-- would otherwise take every real cooldown with it.
	local current = next(skills) and skills or nil

	-- Every crafting cooldown this member is known to have, whether it is running or not.
	--
	-- Running ones carry readyAt; ready ones carry none, and that absence is the answer
	-- rather than a gap - a recipe is in this list at all only because Family has watched it
	-- on cooldown at least once, which is what makes "ready" sayable rather than merely
	-- "not currently running, and possibly nothing to do with cooldowns".
	local cooldowns = {}

	-- Which items belong to which profession, for the ones that turn out to have cooldowns
	-- of their own. A salt shaker is a leatherworking cooldown wearing an item's clothes, and
	-- nothing in the client says so - but Family already records what each recipe *makes*, so
	-- an item with a cooldown that some recipe of ours produces belongs to that recipe's
	-- profession. Learned from the same scan, right in every language, and no table to keep.
	--
	-- Only for items actually seen on cooldown, so this stays a handful of entries rather
	-- than every item every profession can make.
	local meta = Family.Database:Meta(key) or {}

	local watched = {}
	for _, entry in ipairs(meta.itemCooldowns or {}) do
		if entry.id then watched[entry.id] = true end
	end

	local cooldownItems = meta.cooldownItems or {}

	for name, entry in pairs(stored) do
		if not current or current[name] then
			for _, recipe in ipairs(entry.recipes or {}) do
				if recipe.hasCooldown then
					cooldowns[#cooldowns + 1] = {
						name = recipe.name, profession = name, readyAt = recipe.readyAt,
					}
				end

				if recipe.itemID and watched[recipe.itemID] then
					cooldownItems[recipe.itemID] = name
				end
			end
		end
	end

	table.sort(cooldowns, function(a, b)
		return (a.readyAt or 0) < (b.readyAt or 0)
	end)

	Family.Database:SetMeta(key, {
		skills = summary,
		-- Which language these names are in.
		--
		-- A profession has no id on Era, so it is keyed by its name (see the top of this
		-- file) - and a name is one language. Switch the client and this member's skills
		-- keep the words they were recorded in until somebody logs in on them again, while
		-- the recipe lists keep whatever language *they* were opened in. When the two
		-- disagree the panel had no way to tell that from a profession nobody had ever
		-- opened, and said the wrong one of the two. Stamped so it can say the right one.
		skillsLocale = Family.locale,
		craftCooldowns = next(cooldowns) and cooldowns or Family.CLEAR,
		cooldownItems = next(cooldownItems) and cooldownItems or Family.CLEAR,
	})
end

--------------------------------------------------------------------------------------------
-- When to scan
--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("professions", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "professions", function()
		Family:After(4, "professions", function() Professions:Scan(false) end)
	end)

	Family:RegisterEvent("SKILL_LINES_CHANGED", "professions", function()
		-- Fired by this scanner's own expanding, so one arriving mid-scan is ignored.
		if Professions:IsScanning() then return end
		Family:After(1, "professions", function() Professions:Scan(false) end)
	end)

	-- The window is open: this is the only moment recipes can be read at all.
	for _, event in ipairs {
		"TRADE_SKILL_SHOW",
		"TRADE_SKILL_UPDATE",
		"TRADE_SKILL_LIST_UPDATE",
		-- Enchanting, and anything else still behind the older Craft frame.
		"CRAFT_SHOW",
		"CRAFT_UPDATE",
	} do
		Family:RegisterEvent(event, "professions", function()
			Family:After(0.5, "professions.recipes", function()
				Professions:Scan(true)
			end)
		end)
	end
end)
