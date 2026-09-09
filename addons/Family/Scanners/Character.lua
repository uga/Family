-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What a member is wearing, who they are liked by, and what they can cast.
--
-- Three subjects in one file because they share a schedule: all of them are readable at any
-- time, from the character, with no window to open. That makes them the easy half of §3, and
-- keeping them together avoids three files that would each be forty lines of the same shape.

local _, Family = ...

local Character = {}
Family.Character = Character

-- Head through to the ranged/relic slot. The bag slots above are containers and are the bag
-- scanner's business, not gear.
local FIRST_SLOT = _G.INVSLOT_FIRST_EQUIPPED or 1
local LAST_SLOT = _G.INVSLOT_LAST_EQUIPPED or 19

--------------------------------------------------------------------------------------------
-- Equipment
--------------------------------------------------------------------------------------------

local function itemLevelOf(link)
	if not link then return nil end

	-- The detailed call accounts for upgrades and scaling where the client has it; the
	-- plain one is the fourth return of GetItemInfo everywhere else.
	if C_Item and C_Item.GetDetailedItemLevelInfo then
		local level = Family:TryCall(C_Item.GetDetailedItemLevelInfo, link)
		if level then return level end
	end

	local _, _, _, level = Family:TryCall(GetItemInfo, link)
	return level
end

function Character:ReadEquipment()
	local worn = {}
	local total, counted = 0, 0

	for slot = FIRST_SLOT, LAST_SLOT do
		local id = Family:TryCall(GetInventoryItemID, "player", slot)

		if id then
			local link = Family:TryCall(GetInventoryItemLink, "player", slot)
			local level = itemLevelOf(link)

			-- The item string out of the link, and not only the item's id.
			--
			-- An id names the item somebody bought. What they are wearing is that item
			-- plus the enchant on it, the gems in it and the patch sewn onto it, and none
			-- of that is in the id - so a tooltip drawn from the id alone describes a
			-- weapon nobody owns. The item string carries all of it.
			--
			-- Ids the whole way, so this is no exception to §2.1: an item string is
			-- "item:" and a row of numbers. The rest of the link is a colour and the
			-- item's name in the language of whoever was wearing it, and that is exactly
			-- the part left behind.
			-- The shared reader (Core.lua) is where this rule is written down now, and the
			-- bags, the bank, the guild bank and the mailbox all read it from there too. It
			-- answers only for items whose id does not describe them; worn gear keeps its
			-- string either way, because a weapon nobody enchanted is still worth
			-- describing exactly.
			local worth = Family:ItemString(link)
				or (type(link) == "string" and link:match("|H(item[%-%d:]+)|h")) or nil

			worn[slot] = { id = id, itemLevel = level, item = worth }

			-- A tabard and a shirt have item levels and contribute nothing to how
			-- geared somebody is, so they are recorded and not counted.
			local isCosmetic = slot == (_G.INVSLOT_BODY or 4)
				or slot == (_G.INVSLOT_TABARD or 19)

			if level and level > 0 and not isCosmetic then
				total = total + level
				counted = counted + 1
			end
		end
	end

	local average
	if counted > 0 then
		average = math.floor((total / counted) * 10 + 0.5) / 10
	end

	return worn, average, counted
end

--------------------------------------------------------------------------------------------
-- Reputations
--
-- The faction list hides everything under a collapsed header, exactly as the skill list
-- does, so it is expanded to read and put back afterwards.
--------------------------------------------------------------------------------------------

local function collapsedFactions()
	local collapsed = {}
	local count = Family:TryCall(GetNumFactions) or 0

	for index = 1, count do
		local name, _, _, _, _, _, _, _, isHeader, isCollapsed =
			Family:TryCall(GetFactionInfo, index)
		if name and isHeader and isCollapsed then collapsed[name] = true end
	end

	return collapsed
end

function Character:ReadReputations()
	local wasCollapsed = collapsedFactions()

	-- Expanding is one header at a time here; there is no expand-all for factions. The list
	-- grows underneath as each one opens, so the same index is looked at again after an
	-- expansion - and a limit is kept, because a client that never stops reporting a header
	-- as collapsed would otherwise spin for ever.
	local index, guard = 1, 0
	while guard < 500 do
		guard = guard + 1

		local name, _, _, _, _, _, _, _, isHeader, isCollapsed =
			Family:TryCall(GetFactionInfo, index)
		if not name then break end

		if isHeader and isCollapsed then
			Family:TryCall(ExpandFactionHeader, index)
		else
			index = index + 1
		end
	end

	local factions = {}
	local count = Family:TryCall(GetNumFactions) or 0

	-- The header a faction sits under is the game's own grouping - Alliance, Steamwheedle
	-- Cartel, the expansion's factions - and it is what anybody would want to sort by. It is
	-- only knowable by remembering what header was passed on the way down the list, so it is
	-- carried along rather than looked up.
	local category

	for position = 1, count do
		local name, _, standing, barMin, barMax, barValue, _, _, isHeader, _, hasRep,
			_, _, factionID = Family:TryCall(GetFactionInfo, position)

		if name and isHeader and not hasRep then
			category = name
		end

		-- Not "hasRep and not isHeader". hasRep is false for ordinary factions - it marks
		-- the unusual case of a *header* that itself has a standing, which is why the
		-- game's own code asks `not isHeader or hasRep`. Getting it backwards excluded
		-- every normal faction and left the panel empty on a fully played character.
		if name and ((not isHeader) or hasRep) then
			factions[#factions + 1] = {
				id = tonumber(factionID),
				name = name,
				category = category,
				standing = tonumber(standing) or 0,
				value = (tonumber(barValue) or 0) - (tonumber(barMin) or 0),
				maximum = (tonumber(barMax) or 0) - (tonumber(barMin) or 0),
			}
		end
	end

	-- Put back what was found collapsed, walking backwards so that collapsing one header
	-- cannot shift the position of another that has not been reached yet.
	--
	-- Bounded by the count rather than by waiting for a nil. The first version was a
	-- `while true` that stopped when the client ran out of factions, and a client that
	-- answers for an index past the end never runs out - which is how this ended as
	-- "script ran too long" rather than as a wrong answer.
	local total = Family:TryCall(GetNumFactions) or 0
	for position = total, 1, -1 do
		local name, _, _, _, _, _, _, _, isHeader = Family:TryCall(GetFactionInfo, position)
		if name and isHeader and wasCollapsed[name] then
			Family:TryCall(CollapseFactionHeader, position)
		end
	end

	return factions
end

--------------------------------------------------------------------------------------------
-- The spellbook
--------------------------------------------------------------------------------------------

-- Which branches of a profession this character took, out of the spellbook already read.
--
-- **Read here rather than asked for.** `IsSpellKnown` would answer this in one call each, and
-- it is a call nothing in Family has ever made on three clients - where the book is already
-- open in front of us and the shipped table says which of its spells are branches. A
-- specialisation is a spell a character has or has not, so §2.2 is satisfied by the book
-- itself: no book, no answer.
--
-- Ids alone, the way the spellbook is stored and for the reason written beside `Names:Spell` -
-- the client answers about any spell id straight away, in the reader's own language, without
-- having to load anything first.
--
-- Sorted, so that two scans of an unchanged character write an identical list and the record
-- does not churn. `pairs` over a set would not.
function Character:ReadSpecialisations(book)
	local known = Family.Specialisations or {}
	local found = {}

	for _, school in ipairs(book or {}) do
		for _, spellID in ipairs(school.spells or {}) do
			if known[spellID] then found[#found + 1] = spellID end
		end
	end

	if #found == 0 then return nil end
	table.sort(found)
	return found
end

-- **The rows the spellbook draws that the character has not got.**
--
-- The first return of `GetSpellBookItemInfo` says what kind of row this is, and it was thrown
-- away for as long as Family has read a spellbook - so every row the window draws was stored as
-- something the character knows. Reported from play 2026-09-09 and then measured on the
-- character that reported it, a hunter of level three or four on Mists of Pandaria:
--
--     20 FUTURESPELL 33388     36 FUTURESPELL 5116      31  FLYOUT 9
--     23 FUTURESPELL 90267     44 FUTURESPELL 781       81  FLYOUT 9
--     27 FUTURESPELL 130487    76 FUTURESPELL 121818    199 FLYOUT 9
--
-- Fifty-two rows, all of them wrong. `FUTURESPELL` is the greyed row the game draws to say
-- *you will learn this at level 60* - which is why a level three hunter's abilities page listed
-- Stampede and Trueshot Aura - and `FLYOUT` is a group of spells rather than a spell, carrying a
-- flyout's id where a spell id is expected. Nothing can name flyout 9, which is the **Spell #9**
-- with no icon that reported this.
--
-- **Written as a refusal of the two kinds that were read, not as an acceptance of the one that
-- was.** Only Mists has answered this call anywhere in this repository. If Era or Burning Crusade
-- were to answer with some other word for an ordinary spell, keeping only `SPELL` would empty
-- every spellbook on those clients - a far worse fault than the one being fixed, and exactly the
-- shape §2.2 refuses. So a kind that is neither measured nor `SPELL` is kept and narrated once,
-- which is how the next reading arrives without anybody going to look for it.
local NOT_HELD = { FUTURESPELL = true, FLYOUT = true }

local function heldByCharacter(kind, told)
	if type(kind) ~= "string" or kind == "SPELL" then return true end
	if NOT_HELD[kind] then return false end

	if not told[kind] then
		told[kind] = true
		Family:Debug("spellbook: a row of kind %s was kept because that kind has never "
			.. "been measured - worth reporting", kind)
	end

	return true
end

function Character:ReadSpells()
	local tabs = Family:TryCall(GetNumSpellTabs) or 0
	if tabs == 0 then return nil end

	local book = {}
	local told = {}

	for tab = 1, tabs do
		local name, _, offset, count = Family:TryCall(GetSpellTabInfo, tab)
		if name and count and count > 0 then
			local school = { name = name, spells = {} }

			for position = offset + 1, offset + count do
				-- A spell has an id, so this is one of the places nothing has to be
				-- stored by name at all (§2.1). What the id is *of* is the first
				-- return, and a book holds rows that are not this character's spells.
				local kind, spellID =
					Family:TryCall(GetSpellBookItemInfo, position, "spell")
				if spellID and heldByCharacter(kind, told) then
					school.spells[#school.spells + 1] = spellID
				end
			end

			if #school.spells > 0 then book[#book + 1] = school end
		end
	end

	if #book == 0 then return nil end
	return book
end

--------------------------------------------------------------------------------------------
-- Achievements
--
-- Mists only, and gated on the capability table rather than on the calls existing - which is
-- the whole point of §2.3, since Anniversary carries GetAchievementInfo and has no
-- achievements to report.
--
-- The full list is thousands of entries and would dwarf everything else in a member's
-- record, so not all of it is kept. What is stored is every achievement that is finished,
-- and every unfinished one that has been *started* - the ones worth going back for. An
-- achievement at nought of ten is the same fact as not having it, and there are thousands of
-- those.
--
-- Ids only, as everywhere else (§2.1): the name, the description, the points and the icon
-- all come back from the client for any achievement, in whatever language it is running in.
-- What cannot be asked for later, and so is recorded, is which category it was under and how
-- far through it this member is.
--------------------------------------------------------------------------------------------

-- How many of an achievement's criteria are done. Answers nothing for one with no criteria
-- at all, which is common: plenty are a single event with nothing to count.
local function criteriaProgress(id)
	local total = Family:TryCall(GetAchievementNumCriteria, id) or 0
	if total == 0 then return nil end

	local done = 0
	for index = 1, total do
		local _, _, completed = Family:TryCall(GetAchievementCriteriaInfo, id, index)
		if completed then done = done + 1 end
	end

	return done, total
end

function Character:ReadAchievements()
	if not Family.Capabilities:Has("achievements") then return nil end

	local points = Family:TryCall(GetTotalAchievementPoints)
	local categories = Family:TryCall(GetCategoryList)
	if not categories then return nil end

	local earned = {}          -- ids only, and the order the index answers with
	local list = {}
	local count = 0

	for _, category in ipairs(categories) do
		local total = Family:TryCall(GetCategoryNumAchievements, category) or 0

		for index = 1, total do
			local id, _, achievementPoints, completed =
				Family:TryCall(GetAchievementInfo, category, index)

			if id then
				local done, criteria = criteriaProgress(id)

				if completed then
					count = count + 1
					earned[#earned + 1] = id
					list[#list + 1] = {
						id = id,
						category = category,
						points = tonumber(achievementPoints) or 0,
						done = true,
					}
				elseif done and done > 0 then
					-- Started but not finished: the ones an alt manager is for.
					list[#list + 1] = {
						id = id,
						category = category,
						points = tonumber(achievementPoints) or 0,
						criteria = criteria,
						completed = done,
					}
				end
			end
		end
	end

	if count == 0 and not points then return nil end

	return {
		earned = earned,
		list = list,
		count = count,
		points = tonumber(points) or 0,
		seen = time(),
	}
end

--------------------------------------------------------------------------------------------

-- Opening and closing faction headers makes the game announce that factions changed, and
-- that announcement is one of the things that asks for a scan. Left alone, a scan schedules
-- the next scan for ever. The flag is not about re-entrancy - the deferred runner would not
-- re-enter anyway - it is about not answering an event this scanner caused itself.
local scanning = false

function Character:IsScanning()
	return scanning
end

function Character:Scan()
	if scanning then return end
	scanning = true

	local ok, err = pcall(function() self:ScanNow() end)

	scanning = false
	if not ok then error(err, 0) end
end

function Character:ScanNow()
	local key = Family:CurrentMember()
	local payload = Family.Database:Payload(key) or {}

	local worn, average, counted = self:ReadEquipment()
	payload.equipment = { worn = worn, itemLevel = average, counted = counted }

	local factions = self:ReadReputations()
	if factions and #factions > 0 then payload.reputations = factions end

	local book = self:ReadSpells()
	if book then payload.spells = book end

	local branches = book and self:ReadSpecialisations(book) or nil

	local achievements = self:ReadAchievements()
	if achievements then payload.achievements = achievements end

	Family.Database:SetPayload(key, payload)

	-- How fast this character can travel, worked out from what was just written. Both
	-- scanners that can change the answer call it, so whichever ran last leaves it right -
	-- and it is a number rather than a spellbook, which is what lets a sibling have one.
	Family.Mounts:Recompute(key)

	Family.Database:SetMeta(key, {
		-- **Meta and not the payload**, though it is read out of the payload's own
		-- spellbook. The summary reads meta and nothing else - that is what lets it cost the
		-- same for forty members as for four - and a branch is three numbers where a
		-- spellbook is a thousand. `Family.CLEAR` rather than nil when the book was read and
		-- held none: a character who never chose is a different fact from a character
		-- nobody has looked at, and leaving the old value would say Weaponsmith for ever
		-- about somebody who has since unlearnt the trade.
		specialisations = book and (branches or Family.CLEAR) or nil,
		itemLevel = average or Family.CLEAR,
		reputationCount = factions and #factions or nil,
		achievementPoints = achievements and achievements.points or nil,
		achievementCount = achievements and achievements.count or nil,
	})

	Family:Debug("scanned character: ilvl %s, %d factions, %s achievements",
		tostring(average), factions and #factions or 0,
		achievements and tostring(achievements.count) or "no")
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("character", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "character", function()
		-- Later than the other scanners: item levels need the client to have loaded the
		-- items, and asking too early gets a nil for half of them.
		Family:After(6, "character", function() Character:Scan() end)
	end)

	for _, event in ipairs {
		"PLAYER_EQUIPMENT_CHANGED",
		"UPDATE_FACTION",
		"LEARNED_SPELL_IN_TAB",
		"SPELLS_CHANGED",
	} do
		Family:RegisterEvent(event, "character", function()
			-- UPDATE_FACTION is fired by this scanner's own expanding and collapsing,
			-- so an announcement arriving mid-scan is ignored rather than booking the
			-- next one.
			if Character:IsScanning() then return end
			Family:After(2, "character", function() Character:Scan() end)
		end)
	end
end)
