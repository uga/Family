-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Talents, for both specialisations, on all three clients.
--
-- Two entirely different systems live behind one panel:
--
--   trees    Era and Burning Crusade. Three tabs per class, points spent into ranked
--            talents arranged in tiers and columns.
--   choices  Mists. Six tiers, three mutually exclusive choices each, plus a
--            specialisation chosen separately.
--
-- Which one is in use is a capability question, not a guess (Capabilities.lua), and the two
-- readers below share nothing but their output shape.
--
--------------------------------------------------------------------------------------------
-- The one place Family stores a name, and why
--------------------------------------------------------------------------------------------
--
-- §2.1 says ids are stored and names are resolved from the client at display time. Talents
-- are the one thing that cannot obey it, and the reason is worth writing down so nobody
-- "fixes" it back:
--
--   **The client will only talk about your own class's talents.** GetTalentInfo answers for
--   the character you are playing. There is no call that asks what the third talent in a
--   warlock's second tree is called while you are on a mage - and showing another member's
--   talents from a different class is the entire point of the panel.
--
-- Mists is better off: a specialisation has an id and GetSpecializationInfoByID answers for
-- any class, so that half stores an id like everything else. It is the tree talents that
-- have nothing resolvable.
--
-- So a tree talent carries its name and icon alongside its position and rank, recorded from
-- the client that could see it, in that client's language. Consequences, stated rather than
-- discovered later: a member recorded on a German client shows German talent names on an
-- English one, and a linked family (§6) shows whatever language its owner plays in.
--
-- **The proper fix is a generated talent table.** The client's own TalentTab and Talent
-- tables are in its DB2 files and wago.tools serves them per build, which is exactly the
-- route DATASOURCES.md §3 already endorses and already uses for craft levels. Then a talent
-- is an id, the name comes from the table in eleven languages, and this exception
-- disappears. Until that exists, the cached name is the difference between a working panel
-- and no panel.

local _, Family = ...

local L = Family.L

local Talents = {}
Family.Talents = Talents

local MAX_GROUPS = 2          -- dual specialisation, everywhere (§2.3)
local MOP_COLUMNS = 3         -- three choices per tier

--------------------------------------------------------------------------------------------
-- How many specialisations this character has, and which is live
--------------------------------------------------------------------------------------------

-- Both of these exist on all three clients and throw on the ones that do not support them,
-- so each is attempted rather than tested for (Core.lua, Family:TryCall). Anniversary has
-- GetNumSpecGroups and answers "API unsupported in this version" when it is called.
local function groupCount()
	local count = Family:TryCall(GetNumSpecGroups) or Family:TryCall(GetNumTalentGroups)
	return math.min(tonumber(count) or 1, MAX_GROUPS)
end

local function activeGroup()
	local active = Family:TryCall(GetActiveSpecGroup) or Family:TryCall(GetActiveTalentGroup)
	return tonumber(active) or 1
end

--------------------------------------------------------------------------------------------
-- Era and Burning Crusade: trees
--------------------------------------------------------------------------------------------

-- GetTalentTabInfo does not return the same things in the same order on all of these
-- clients. Anniversary hands back something whose third value is not the points spent, which
-- is how a character with 53 points in a tree was recorded as having none - and, because a
-- specialisation with no points is taken to be one that was never activated, how a fully
-- specced tree came to be reported as never visited and drawn as a note instead.
--
-- So the returns are inspected rather than unpacked by position. The name is the first
-- string that is not a texture, the icon the first thing that looks like one. Both are
-- optional; neither is load bearing, because the points are summed from the ranks (below)
-- which is the one thing every version of this call agrees about.
local function tabIdentity(...)
	local name, icon

	for index = 1, select("#", ...) do
		local value = select(index, ...)

		if type(value) == "string" then
			if value:find("\\", 1, true) or value:find("/", 1, true) then
				icon = icon or value
			elseif not name then
				name = value
			end
		elseif type(value) == "number" and value > 100000 then
			icon = icon or value                     -- a file id rather than a path
		end
	end

	return name, icon
end

local function readTrees(group)
	if not (GetNumTalentTabs and GetTalentInfo and GetNumTalents) then return nil end

	local tabs = {}
	local numTabs = Family:TryCall(GetNumTalentTabs) or 0

	for tab = 1, numTabs do
		local name, icon = tabIdentity(
			Family:TryCall(GetTalentTabInfo, tab, false, false, group))

		local entry = {
			index = tab,
			name = name,          -- see the note at the top of this file
			icon = icon,
			points = 0,           -- summed from the ranks below, not asked for
			talents = {},
		}

		local numTalents = Family:TryCall(GetNumTalents, tab) or 0
		for index = 1, numTalents do
			local tName, tIcon, tier, column, rank, maxRank =
				Family:TryCall(GetTalentInfo, tab, index, false, false, group)

			if tName then
				local spent = tonumber(rank) or 0
				entry.talents[index] = {
					-- Where it sits in the client's own list, which is the only way to
					-- ask the game to describe it: a tree talent has no id of any kind
					-- on these clients, and GameTooltip:SetTalent takes the tab and the
					-- index it was found at.
					tab = tab,
					index = index,
					name = tName,
					icon = tIcon,
					tier = tonumber(tier) or 0,
					column = tonumber(column) or 0,
					rank = spent,
					maxRank = tonumber(maxRank) or 0,
				}
				entry.points = entry.points + spent
			end
		end

		tabs[tab] = entry
	end

	if numTabs == 0 then return nil end
	return { system = "trees", tabs = tabs }
end

--------------------------------------------------------------------------------------------
-- Mists: six tiers, three choices each, and a specialisation
--------------------------------------------------------------------------------------------

-- What one answer from the client's talent call actually said.
--
-- The first version unpacked four values by position - `talentID, name, icon, selected` - and
-- kept the talent only if the first was a number and the second a string. On Mists Classic it
-- recognised nothing, which is how a panel came to show a column of "nothing chosen" for a
-- character who plainly had talents. Positional unpacking has now been wrong here twice, for
-- the same reason it was wrong for GetTalentTabInfo, so the returns are inspected instead:
--
--   name      a string that is not a texture path. **Required** - without it there is
--             nothing to draw. Everything else is decoration.
--   icon      a path-looking string, or a number far too large to be anything else.
--   selected  the first boolean. Every shape puts `selected` before `available`.
--   id        a number too large to be a tier or a column. Optional, and deliberately so:
--             it is worth having for a tooltip and worth nothing for the list, and requiring
--             it is what threw away perfectly readable talents.
local function interpret(...)
	if select("#", ...) == 0 then return nil end

	local first = ...

	-- The newest shape answers with one table instead of a list of values.
	if type(first) == "table" then
		if type(first.name) ~= "string" then return nil end
		return {
			id = tonumber(first.talentID or first.id),
			name = first.name,
			icon = first.icon or first.texture or first.iconTexture,
			selected = (first.selected or first.known) and true or false,
		}
	end

	local id, name, icon, selected

	for index = 1, select("#", ...) do
		local value = select(index, ...)
		local kind = type(value)

		if kind == "string" then
			if value:find("\\", 1, true) or value:find("/", 1, true) then
				icon = icon or value
			elseif name == nil and value ~= "" then
				name = value
			end
		elseif kind == "number" then
			-- A tier is at most seven and a column at most three, so a larger number is
			-- an identifier of some kind and a much larger one is a texture file id.
			if value > 100000 then
				icon = icon or value
			elseif value > 20 then
				id = id or value
			end
		elseif kind == "boolean" then
			if selected == nil then selected = value end
		end
	end

	if type(name) ~= "string" then return nil end
	return { id = id, name = name, icon = icon, selected = selected and true or false }
end

-- Every way these clients are known to accept the same question. Which one a build wants is
-- settled by asking, not by deciding in advance - the last three attempts to decide in
-- advance were all wrong on at least one client.
local function talentReaders()
	local readers = {}
	local api = _G.C_SpecializationInfo

	if api and type(api.GetTalentInfo) == "function" then
		readers[#readers + 1] = {
			how = "C_SpecializationInfo.GetTalentInfo{tier, column, groupIndex}",
			call = function(tier, column, group)
				return api.GetTalentInfo({
					tier = tier, column = column, groupIndex = group, isInspect = false,
				})
			end,
		}
	end

	if type(GetTalentInfo) == "function" then
		readers[#readers + 1] = {
			how = "GetTalentInfo(tier, column, group)",
			call = function(tier, column, group)
				return GetTalentInfo(tier, column, group)
			end,
		}
		readers[#readers + 1] = {
			how = "GetTalentInfo(index, false, group)",
			call = function(_, _, group, index)
				return GetTalentInfo(index, false, group)
			end,
		}
		readers[#readers + 1] = {
			how = "GetTalentInfo(index, nil, group, 'player')",
			call = function(_, _, group, index)
				return GetTalentInfo(index, nil, group, "player")
			end,
		}
		readers[#readers + 1] = {
			how = "GetTalentInfo(tier, column, group, false, 'player')",
			call = function(tier, column, group)
				return GetTalentInfo(tier, column, group, false, "player")
			end,
		}
	end

	return readers
end

-- The reader is chosen by asking it for a whole tier rather than for one talent, because
-- every shape above answers *something* when handed a 1, and a shape that means something
-- else by its arguments answers the same talent three times over. Agreeing with itself is
-- not evidence. Three different names in three columns is.
local function chooseReader(readers, group, numColumns)
	for _, candidate in ipairs(readers) do
		local names, distinct = {}, 0

		for column = 1, numColumns do
			local got = interpret(Family:TryCall(candidate.call, 1, column, group, column))
			if got and not names[got.name] then
				names[got.name] = true
				distinct = distinct + 1
			end
		end

		if distinct == numColumns then return candidate end
	end

	-- Nothing gave a clean first tier. Whichever reader said anything at all is still worth
	-- more than no talents, so it is used and the disagreement is left to the probe.
	for _, candidate in ipairs(readers) do
		if interpret(Family:TryCall(candidate.call, 1, 1, group, 1)) then return candidate end
	end

	return nil
end

-- Which specialisation a group is on.
--
-- Asked several ways rather than one, because the group-aware call answers for both groups on
-- some builds and only for the live one on others - which is how a paladin with two
-- specialisations came to have the inactive one reported as "none recorded" while its six
-- talents were listed perfectly well underneath it.
--
-- The calls that answer about the character rather than about a group are asked only when
-- the group in hand is the live one. A second specialisation labelled with the first one's
-- name is worse than no label at all.
local function specCandidates(group)
	local api = _G.C_SpecializationInfo
	local candidates = {}

	local function add(how, call) candidates[#candidates + 1] = { how = how, call = call } end

	add("GetSpecialization(false, false, group)",
		function() return GetSpecialization(false, false, group) end)
	add("GetSpecialization(nil, nil, group)",
		function() return GetSpecialization(nil, nil, group) end)

	if api and api.GetSpecialization then
		add("C_SpecializationInfo.GetSpecialization(false, false, group)",
			function() return api.GetSpecialization(false, false, group) end)
	end

	if group == activeGroup() then
		add("GetSpecialization()", function() return GetSpecialization() end)
		if api and api.GetSpecialization then
			add("C_SpecializationInfo.GetSpecialization()",
				function() return api.GetSpecialization() end)
		end
	end

	return candidates
end

-- A specialisation has an id, and GetSpecializationInfoByID answers for any class, so this
-- half of the record needs no cached name at all (§2.1).
local function specIDFor(group)
	local api = _G.C_SpecializationInfo

	for _, candidate in ipairs(specCandidates(group)) do
		-- An index into this class's specialisations, so a small positive number and
		-- nothing else. A call that answers a boolean or a table is answering a different
		-- question and is not the one wanted.
		-- Through a local first: a call that returns nothing at all hands tonumber no
		-- argument rather than a nil one, and that is an error rather than a nil.
		local answer = Family:TryCall(candidate.call)
		local index = tonumber(answer)

		if index and index > 0 and index < 20 then
			local id = Family:TryCall(GetSpecializationInfo, index)
			if not id and api then
				id = Family:TryCall(api.GetSpecializationInfo, index)
			end
			if id then return tonumber(id) end
		end
	end

	return nil
end

-- What each shape says, printed rather than guessed at. This exists because working out which
-- call a build wants has needed a round trip through a real client every single time.
function Talents:Probe()
	local readers = talentReaders()
	local numColumns = _G.NUM_TALENT_COLUMNS or MOP_COLUMNS

	Family:Print(L["talent readers available: %d"], #readers)

	-- Kept with its own length, because a call that answers `nil, "Frostbolt"` is exactly the
	-- kind of thing this is here to catch and a plain table would lose it.
	local function pack(...) return { n = select("#", ...), ... } end

	for _, candidate in ipairs(readers) do
		for column = 1, numColumns do
			local returns = pack(Family:TryCall(candidate.call, 1, column, 1, column))
			local parts = {}

			for index = 1, math.min(returns.n, 8) do
				local value = returns[index]
				parts[#parts + 1] = string.format("%s(%s)", type(value), tostring(value))
			end

			local got = interpret(unpack(returns, 1, returns.n))
			Family:Print(L["  %s [1,%d] -> %s |cff888888=> %s|r"], candidate.how, column,
				returns.n > 0 and table.concat(parts, ", ") or "nothing",
				got and got.name or "unreadable")
		end
	end

	-- And the other half of the question, which failed separately and for its own reasons.
	for group = 1, MAX_GROUPS do
		for _, candidate in ipairs(specCandidates(group)) do
			local answer = Family:TryCall(candidate.call)
			Family:Print(L["  spec %d: %s -> %s"], group, candidate.how, tostring(answer))
		end
	end
end

local function readChoices(group)
	-- Mists has no GetNumTalentTiers - that call arrived later - and states the shape of the
	-- grid in two constants instead. Asked for in that order, so a client that does have the
	-- function is still believed over a guess.
	local tiers = {}
	local numTiers = Family:TryCall(GetNumTalentTiers)
		or _G.MAX_TALENT_TIERS
		or 0
	local numColumns = _G.NUM_TALENT_COLUMNS or MOP_COLUMNS

	local reader = chooseReader(talentReaders(), group, numColumns)

	if not reader then
		Family:Debug("choices: no talent reader answered for group %d", group)
		numTiers = 0
	else
		Family:Debug("choices: reading talents with %s", reader.how)
	end

	for tier = 1, numTiers do
		local row = { tier = tier, choices = {} }

		for column = 1, numColumns do
			local index = ((tier - 1) * numColumns) + column
			local got = interpret(Family:TryCall(reader.call, tier, column, group, index))

			if got then
				row.choices[column] = got
				if got.selected then row.chosen = column end
			end
		end

		tiers[tier] = row
	end

	-- MAX_TALENT_TIERS is a ceiling rather than a count, and on a build where it is one
	-- higher than the number of tiers that exist the panel grew a permanent extra row
	-- reading "nothing chosen" - a talent nobody can ever take, reported as one they have
	-- not taken. Tiers the client had nothing at all to say about are dropped.
	for tier = #tiers, 1, -1 do
		if next(tiers[tier].choices) then break end
		tiers[tier] = nil
	end

	local result = { system = "choices", tiers = tiers }

	-- Glyphs belong with the specialisation they were slotted into, not with the character,
	-- which is why they are read here per group rather than once. A glyph is a spell, so it
	-- is kept as a spell id and needs no name (§2.1).
	if Family.Capabilities:Has("glyphs") then
		local sockets = Family:TryCall(GetNumGlyphSockets) or 0
		local glyphs = {}

		for socket = 1, sockets do
			local enabled, glyphType, _, spellID, icon =
				Family:TryCall(GetGlyphSocketInfo, socket, group)

			glyphs[socket] = {
				socket = socket,
				enabled = enabled and true or false,
				kind = tonumber(glyphType),
				spellID = tonumber(spellID),
				icon = icon,
			}
		end

		if next(glyphs) then result.glyphs = glyphs end
	end

	-- Mists asks two questions, not one: which specialisation, and then which talent on each
	-- tier. They are recorded independently because they fail independently - a tier read
	-- that comes back empty must not take the specialisation down with it, since knowing a
	-- member is Arcane is worth having on its own.
	--
	-- A specialisation has an id, and GetSpecializationInfoByID answers for any class, so
	-- this half needs no cached name at all.
	--
	result.specID = specIDFor(group)

	-- Enough to be worth keeping if *either* question was answered. Requiring tiers threw
	-- away a known specialisation whenever the grid could not be read, which is exactly the
	-- case where having anything at all matters most.
	if #tiers == 0 and not result.specID and not result.glyphs then
		Family:Debug("choices: no tiers, no spec, no glyphs for group %d", group)
		return nil
	end

	return result
end

--------------------------------------------------------------------------------------------

function Talents:Scan()
	local key = Family:CurrentMember()
	local useTrees = Family.Capabilities:Has("talentTrees")

	local groups = {}
	local count = groupCount()

	-- What was recorded last time, for the one thing that is worth keeping when a read
	-- comes back empty.
	local previous = (Family.Database:Payload(key) or {}).talents

	for group = 1, count do
		-- Written out rather than as `useTrees and readTrees(g) or readChoices(g)`,
		-- which quietly calls the wrong reader whenever the right one returns nil.
		local data
		if useTrees then
			data = readTrees(group)
		else
			data = readChoices(group)
		end

		-- §2.2: a specialisation never visited has nothing recorded, and is reported as
		-- unvisited rather than drawn as an empty tree. On these clients the second
		-- group reads as all-zero until it has been activated at least once.
		if data then
			data.group = group
			data.visited = true

			-- A specialisation that could not be read this time is not one that has gone
			-- away. Where the client would not say, whatever it last said stands - which
			-- is the difference between an inactive specialisation reading "Retribution"
			-- and reading "none recorded" beside six talents it plainly has.
			if data.system == "choices" and not data.specID and previous then
				local before = previous.groups and previous.groups[group]
				if before and before.specID then
					data.specID = before.specID
					Family:Debug("spec for group %d kept from the last scan", group)
				end
			end

			if data.system == "trees" then
				local total = 0
				for _, tab in pairs(data.tabs) do total = total + tab.points end
				data.pointsSpent = total
				if total == 0 and group ~= activeGroup() then data.visited = false end
			end

			groups[group] = data
		end
	end

	if not next(groups) then
		-- Loud, not a debug line. Reaching here means every reader declined, and a
		-- panel that silently shows nothing is the hardest kind of fault to report.
		Family:Print(L["|cffffaa00no talent data could be read on this client|r " ..
			"(%s, %d group(s)). Please report this with /family caps, and with " ..
			"/family talentprobe if it says choices."],
			useTrees and "trees" or "choices", count)
		Family:Debug("GetNumTalentTabs=%s GetNumTalents=%s GetTalentInfo=%s " ..
			"GetNumTalentTiers=%s",
			tostring(GetNumTalentTabs ~= nil), tostring(GetNumTalents ~= nil),
			tostring(GetTalentInfo ~= nil), tostring(GetNumTalentTiers ~= nil))
		return
	end

	-- Glyphs and a specialisation are enough to keep the record, so a grid that read as
	-- nothing at all no longer stops the scan - which means it would otherwise leave the
	-- panel looking merely empty rather than faulty. Said out loud instead.
	if not useTrees then
		local anyTiers = false
		for _, data in pairs(groups) do
			if data.tiers and #data.tiers > 0 then anyTiers = true end
		end

		if not anyTiers then
			Family:Print(L["|cffffaa00no talent grid could be read on this client.|r " ..
				"Please report what |cffffd700/family talentprobe|r prints."])
		end
	end

	-- What is still to spend, which is what makes the spent number mean anything: eight of
	-- fifty-one is a character nobody has finished, and eight of eight is a level eighteen.
	-- The client answers for the character rather than for a specialisation, and the
	-- allowance is the same for both, so it is kept once rather than per group.
	local unspent = tonumber(Family:TryCall(UnitCharacterPoints)) or 0
	local active = groups[activeGroup()]
	local total = (active and active.pointsSpent or 0) + unspent

	local payload = Family.Database:Payload(key) or {}
	payload.talents = {
		seen = time(),
		available = total > 0 and total or nil,
		system = useTrees and "trees" or "choices",
		activeGroup = activeGroup(),
		groupCount = count,
		groups = groups,
	}
	Family.Database:SetPayload(key, payload)

	-- Small enough for meta, and it is what a summary column would want: the points per
	-- tree for the live specialisation, or its specialisation id on Mists.
	local live = groups[activeGroup()]
	local summary = {}
	if live and live.system == "trees" then
		for tab = 1, #live.tabs do summary[tab] = live.tabs[tab].points end
		Family.Database:SetMeta(key, { talentPoints = summary, specID = nil })
	elseif live then
		Family.Database:SetMeta(key, { specID = live.specID, talentPoints = nil })
	end

	Family:Debug("scanned talents: %d group(s), %s", count, useTrees and "trees" or "choices")
end

--------------------------------------------------------------------------------------------
-- When to scan
--------------------------------------------------------------------------------------------

local function scanSoon(reason)
	Family:After(1, "talents", function()
		Family:Debug("talent scan (%s)", reason)
		Talents:Scan()
	end)
end

Family:OnDatabaseReady("talents", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "talents", function()
		Family:After(3, "talents", function() Talents:Scan() end)
	end)

	-- Not every one of these exists on every client, and RegisterEvent already copes with
	-- one that does not (Core.lua).
	for _, event in ipairs {
		"PLAYER_TALENT_UPDATE",
		"CHARACTER_POINTS_CHANGED",
		"ACTIVE_TALENT_GROUP_CHANGED",
		"PLAYER_SPECIALIZATION_CHANGED",
	} do
		Family:RegisterEvent(event, "talents", function() scanSoon(event) end)
	end
end)
